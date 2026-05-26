# ============================================================
# build-and-deploy.ps1
# Pipeline: .sb3.zip download --> index.html --> Azure Web App
# Gebruik: .\build-and-deploy.ps1 [-Environment Sandbox] [-InputZip "bestandsnaam.sb3.zip"] [-WhatIf]
#          Zonder -Environment: default = Sandbox
#          Zonder -InputZip: pakt automatisch de nieuwste uit de input\ folder
# ============================================================
param(
    [ValidateSet("Sandbox", "Ontwikkel", "Test", "Acceptatie", "Productie")]
    [string]$Environment = "Sandbox",

    [string]$InputZip = "",   # bestandsnaam of volledig pad; leeg = auto-detect uit input\
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

# ── Config laden ──────────────────────────────────────────────
. "$PSScriptRoot\__config.ps1"
$cfg           = Get-EnvironmentConfig -Environment $Environment

$appName       = $cfg.WebAppName
$resourceGroup = $cfg.ResourceGroup

Write-Host "`nOmgeving: $($cfg.Name)" -ForegroundColor White

$rootDir        = "d:\tmp\game1"
$inputDir       = "$rootDir\input"
$archiveRoot    = "$rootDir\archive"
$sb3File        = "$rootDir\_GAME_pkg.sb3"
$outputDir      = "$rootDir\output"
$outputHtml     = "$outputDir\index.html"
$deployZip      = "$rootDir\deploy_game.zip"

# ── Functies ──────────────────────────────────────────────────

function Resolve-InputFile {
    param([string]$Path)

    if (-not $Path) {
        # Auto-detect: pik de nieuwste .sb3.zip of .sb3 uit de input\ folder
        $candidates = @(Get-ChildItem -Path "$inputDir\*.sb3.zip") +
                      @(Get-ChildItem -Path "$inputDir\*.sb3") |
                      Sort-Object LastWriteTime -Descending

        if (-not $candidates) {
            Write-Error "Geen .sb3.zip of .sb3 gevonden in $inputDir.`nGebruik: .\build-and-deploy.ps1 -InputZip 'bestandsnaam.sb3.zip'"
            exit 1
        }

        if ($candidates.Count -gt 1) {
            Write-Host "      --> $($candidates.Count) bestanden gevonden in input, nieuwste wordt gebruikt:" -ForegroundColor Yellow
            $candidates | ForEach-Object {
                $marker = if ($_ -eq $candidates[0]) { " << geselecteerd" } else { "" }
                Write-Host "            $($_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))  $($_.Name)$marker" -ForegroundColor DarkGray
            }
        }

        $Path = $candidates[0].FullName
        Write-Host "      --> Automatisch gevonden: $(Split-Path $Path -Leaf)" -ForegroundColor Yellow
        return $Path
    }

    # Alleen bestandsnaam opgegeven (zonder mappad) - zoek in input
    if (-not [System.IO.Path]::IsPathRooted($Path) -and -not $Path.Contains('\')) {
        $candidate = Join-Path $inputDir $Path
        if (Test-Path $candidate) {
            Write-Host "      --> Gevonden in input: $Path" -ForegroundColor Yellow
            return $candidate
        }
    }

    # Volledig pad opgegeven
    if (-not (Test-Path $Path)) {
        Write-Error "Bestand niet gevonden: $Path"
        exit 1
    }

    return $Path
}

function Invoke-Prepare {
    param([string]$SourceZip)

    if (Test-Path $sb3File) { Remove-Item $sb3File -Force }
    Copy-Item $SourceZip $sb3File

    if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }

    Write-Host "      --> $sb3File klaar." -ForegroundColor Green
}

function Invoke-Packaging {
    Push-Location $rootDir
    node package-sb3.js $sb3File
    Pop-Location

    if (-not (Test-Path $outputHtml)) {
        Write-Error "Packaging mislukt: $outputHtml niet gevonden."
        exit 1
    }

    $sizeMB = [math]::Round((Get-Item $outputHtml).Length / 1MB, 2)
    Write-Host "      --> $outputHtml ($sizeMB MB)" -ForegroundColor Green
}

function Invoke-Deploy {
    if (Test-Path $deployZip) { Remove-Item $deployZip -Force }
    Compress-Archive -Path $outputHtml -DestinationPath $deployZip

    Write-Host "      --> Inloggen als service principal..." -ForegroundColor DarkGray
    az login --service-principal `
        --username   $cfg.ClientId `
        --password   $cfg.ClientSecret `
        --tenant     $cfg.TenantId | Out-Null

    az account set --subscription $cfg.SubscriptionId | Out-Null

    # Controleer of de web app bestaat; zo niet, aanmaken met Free-tier plan
    $ErrorActionPreference = "Continue"
    $exists = az webapp show --name $appName --resource-group $resourceGroup --query "name" -o tsv 2>$null
    $webAppFound = ($LASTEXITCODE -eq 0 -and $exists)
    $ErrorActionPreference = "Stop"

    if (-not $webAppFound) {
        Write-Host "      --> Web app '$appName' bestaat niet, wordt aangemaakt..." -ForegroundColor Yellow

        $planName = "$appName-plan"
        az appservice plan create `
            --name           $planName `
            --resource-group $resourceGroup `
            --sku            F1

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Aanmaken van App Service Plan '$planName' mislukt."
            exit 1
        }

        az webapp create `
            --name           $appName `
            --resource-group $resourceGroup `
            --plan           $planName

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Aanmaken van web app '$appName' mislukt."
            exit 1
        }

        Write-Host "      --> Web app '$appName' aangemaakt (Free tier)." -ForegroundColor Green
    }

    az webapp deploy `
        --name           $appName `
        --resource-group $resourceGroup `
        --src-path       $deployZip `
        --type           zip `
        --async          false
}

function Invoke-Archive {
    param([string]$SourceZip)

    $timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $archiveDir = "$archiveRoot\$timestamp"
    New-Item -ItemType Directory -Path $archiveDir | Out-Null

    Copy-Item $SourceZip  "$archiveDir\$(Split-Path $SourceZip -Leaf)"
    Copy-Item $outputHtml "$archiveDir\index.html"

    Remove-Item $sb3File   -Force
    Remove-Item $deployZip -Force
    Remove-Item $SourceZip -Force

    Write-Host "      --> Gearchiveerd in: $archiveDir" -ForegroundColor DarkGray
}

# ── Uitvoering ────────────────────────────────────────────────

Write-Host "`n[1/3] Voorbereiden van het .sb3 bestand..." -ForegroundColor Cyan
$InputZip = Resolve-InputFile -Path $InputZip
Invoke-Prepare -SourceZip $InputZip

Write-Host "`n[2/3] Packager uitvoeren (node package-sb3.js)..." -ForegroundColor Cyan
Invoke-Packaging

Write-Host "`n[3/3] Deployen naar Azure ($appName)..." -ForegroundColor Cyan

if ($WhatIf) {

    Write-Host "`n[WhatIf] Zou uitvoeren voor $($cfg.Name):" -ForegroundColor Magenta
    Write-Host "  az login --service-principal --username $($cfg.ClientId) --tenant $($cfg.TenantId)" -ForegroundColor Magenta
    Write-Host "  az account set --subscription $($cfg.SubscriptionId)" -ForegroundColor Magenta
    Write-Host "  [check] az webapp show --name $appName --resource-group $resourceGroup" -ForegroundColor Magenta
    Write-Host "  [indien niet bestaat] az appservice plan create --name $appName-plan --resource-group $resourceGroup --sku F1" -ForegroundColor Magenta
    Write-Host "  [indien niet bestaat] az webapp create --name $appName --resource-group $resourceGroup --plan $appName-plan" -ForegroundColor Magenta
    Write-Host "  az webapp deploy --name $appName --resource-group $resourceGroup --src-path $deployZip --type zip --async false" -ForegroundColor Magenta
    Write-Host "`n[WhatIf] Geen wijzigingen doorgevoerd.`n" -ForegroundColor Magenta

} else {

    Invoke-Deploy
    Invoke-Archive -SourceZip $InputZip
    Write-Host "`nKlaar! Game is live op: https://$appName.azurewebsites.net`n" -ForegroundColor Green
}
