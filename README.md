# Scratch Game — Build & Deploy Pipeline

Pipeline om een Scratch-project vanuit de **Scratch UI** te packagen naar een standalone `index.html` en te deployen naar een Azure Web App.

---

## Vereisten

### 1. Node.js installeren

Installeer Node.js **LTS** via een van de onderstaande methoden.

#### Windows — handmatig

Download de installer via [https://nodejs.org](https://nodejs.org) en volg de installatie-wizard.

#### Windows — Chocolatey

```powershell
choco install nodejs-lts
```

#### Windows — winget

```powershell
winget install OpenJS.NodeJS.LTS
```

#### Linux — apt (Debian / Ubuntu)

```bash
sudo apt update
sudo apt install nodejs npm
```

#### Linux — dnf (Fedora / RHEL)

```bash
sudo dnf install nodejs
```

#### Linux — pacman (Arch)

```bash
sudo pacman -S nodejs npm
```

Controleer de installatie na het installeren:

```bash
node --version
npm --version
```

### 2. Dependencies installeren

Navigeer naar de projectfolder en installeer de Node.js dependencies:

**Windows:**
```powershell
cd <pad-naar-projectfolder>
npm install
```

**Linux / macOS:**
```bash
cd /pad/naar/projectfolder
npm install
```

Dit installeert onder andere [`@turbowarp/packager`](https://github.com/TurboWarp/packager) (v3.13.0) — de library die een Scratch `.sb3` bestand omzet naar een zelfstandige HTML-pagina.

### 3. Configuratie instellen

Maak een `__config.ps1` aan in de projectfolder (staat in `.gitignore` — wordt nooit ingecheckt). Dit bestand bevat de Azure-credentials en instellingen per omgeving:

```powershell
function Get-EnvironmentConfig {
    param(
        [ValidateSet("Sandbox", "Ontwikkel", "Test", "Acceptatie", "Productie")]
        [string]$Environment
    )
    $configs = @{
        Ontwikkel = @{
            Name           = "ONTWIKKEL (O)"
            ClientId       = "<app-registration-client-id>"
            ClientSecret   = "<client-secret>"
            TenantId       = "<tenant-id>"
            SubscriptionId = "<subscription-id>"
            WebAppName     = "<app-name>"
            ResourceGroup  = "<resource-group>"
        }
        # ... overige omgevingen
    }
    return $configs[$Environment]
}
```

> De service principal heeft minimaal de rol **Website Contributor** nodig op de Web App.

---

## Hoe het mechanisme werkt

```
Scratch UI  →  input\*.sb3.zip  →  SHARK_GAME_pkg.sb3  →  output/index.html  →  Azure Web App
```

| Stap | Wat er gebeurt |
|------|----------------|
| **1. Input** | Je downloadt je project vanuit de Scratch UI als `.sb3.zip` (bijv. `SHARK GAME_v0.2.sb3.zip`) en zet dit in de `input\` folder. Een `.sb3` bestand is intern een gewone zip met `project.json` en alle assets. Bij meerdere bestanden wordt automatisch de nieuwste (op basis van `LastWriteTime`) geselecteerd. |
| **2. Voorbereiding** | Het script kopieert het gedownloade bestand als `SHARK_GAME_pkg.sb3` — geen uitpakken nodig. |
| **3. Packaging** | `package-sb3.js` roept `@turbowarp/packager` aan. De packager leest het `.sb3` bestand, laadt het Scratch-project en genereert een volledig standalone `output/index.html` (inclusief de Scratch runtime van TurboWarp). |
| **4. Deploy** | De gegenereerde `index.html` wordt ingepakt als `deploy_game.zip` en via de Azure CLI (`az webapp deploy`) gepusht naar de Azure Web App. |
| **5. Archief** | Na een succesvolle deploy worden het originele `.sb3.zip` en `index.html` gekopieerd naar `archive\<timestamp>\`. Tijdelijke artifacts worden opgeruimd. |

---

## Werkwijze

1. Download het project vanuit de Scratch UI als `.sb3.zip`
2. Zet het bestand in de `input\` folder
3. Kies de doelomgeving en roep het script aan (zie smaken hieronder)

> Bij meerdere bestanden in `input\` wordt altijd de nieuwste gekozen op basis van `LastWriteTime`. Het script toont een overzicht met timestamps en markeert het geselecteerde bestand.

---

## Omgevingen

`-Environment` is optioneel. De **default waarde is `Sandbox`**. Beschikbare waarden:

| Waarde | Omschrijving | Default |
|---|---|---|
| `Sandbox` | Persoonlijke sandbox omgeving | ✅ ja |
| `Ontwikkel` | Ontwikkelomgeving | |
| `Test` | Testomgeving | |
| `Acceptatie` | Acceptatieomgeving | |
| `Productie` | Productieomgeving | |

---

## Sandbox shortcuts

Voor dagelijks gebruik met de Sandbox omgeving zijn er twee shortcut scripts:

| Script | Equivalent |
|---|---|
| `build.ps1` | `build-and-deploy.ps1 -Environment Sandbox -WhatIf` |
| `deploy.ps1` | `build-and-deploy.ps1 -Environment Sandbox` |

```powershell
# Alleen bouwen (geen deploy)
.\build.ps1
.\build.ps1 -InputZip "SHARK GAME_v0.2.sb3.zip"

# Bouwen en deployen naar Sandbox
.\deploy.ps1
.\deploy.ps1 -InputZip "SHARK GAME_v0.2.sb3.zip"
```

---

## Aanroep — smaken

### Zonder environment (default = Sandbox)

```powershell
.\build-and-deploy.ps1                                         # auto-detect, Sandbox
.\build-and-deploy.ps1 -WhatIf                                 # alleen bouwen, Sandbox
.\build-and-deploy.ps1 -InputZip "SHARK GAME_v0.2.sb3.zip"    # specifiek bestand, Sandbox
```

Of via de shortcuts:

```powershell
.\build.ps1                                                    # alleen bouwen, Sandbox
.\build.ps1 -InputZip "SHARK GAME_v0.2.sb3.zip"
.\deploy.ps1                                                   # bouwen + deployen, Sandbox
.\deploy.ps1 -InputZip "SHARK GAME_v0.2.sb3.zip"
```

### Volledige run (build + deploy) met omgeving

Automatisch de nieuwste `*.sb3.zip` uit `input\` detecteren en deployen:

```powershell
.\build-and-deploy.ps1 -Environment Ontwikkel
```

### Specifiek bestand opgeven (bestandsnaam)

Pak een specifiek bestand uit de `input\` folder:

```powershell
.\build-and-deploy.ps1 -Environment Ontwikkel -InputZip "SHARK GAME_v0.2.sb3.zip"
```

### Specifiek bestand opgeven (volledig pad)

Gebruik een bestand buiten de `input\` folder:

```powershell
.\build-and-deploy.ps1 -Environment Ontwikkel -InputZip "C:\Downloads\SHARK GAME_v0.2.sb3.zip"
```

### WhatIf — alleen builden, niet deployen

Voert stap 1 t/m 3 volledig uit (inclusief packaging), maar slaat de `az webapp deploy` over. Handig om te controleren of de build slaagt:

```powershell
.\build-and-deploy.ps1 -Environment Ontwikkel -WhatIf
```

### Combinatie — specifiek bestand, niet deployen

```powershell
.\build-and-deploy.ps1 -Environment Acceptatie -InputZip "SHARK GAME_v0.2.sb3.zip" -WhatIf
```

---

## Folder structuur

| Folder / Bestand | Omschrijving | In git? |
|---|---|---|
| `__config.ps1` | Azure credentials per omgeving (service principal) | ❌ nee |
| `input\` | Hier zet je de gedownloade `.sb3.zip` bestanden | ❌ nee |
| `output\index.html` | Standalone game — gegenereerd door packager | ❌ nee |
| `archive\<timestamp>\` | Archief per deploy — originele zip + index.html | ❌ nee |
| `SHARK_GAME_pkg.sb3` | Tijdelijk artifact — wordt na deploy verwijderd | ❌ nee |
| `deploy_game.zip` | Deployment artifact — wordt na deploy verwijderd | ❌ nee |
| `SHARK GAME.sb3\project.json` | Bronbestand van het spel | ✅ ja |
| `package-sb3.js` | Packager script | ✅ ja |
| `build.ps1` | Sandbox shortcut — alleen bouwen | ✅ ja |
| `deploy.ps1` | Sandbox shortcut — bouwen + deployen | ✅ ja |
| `build-and-deploy.ps1` | Pipeline script | ✅ ja |

---

## Azure

De credentials en Azure-instellingen worden per omgeving geladen uit `__config.ps1`. De service principal logt automatisch in via `az login --service-principal` voor de deploy.

| Instelling | Geconfigureerd in |
|------------|-------------------|
| App name | `__config.ps1` → `WebAppName` |
| Resource group | `__config.ps1` → `ResourceGroup` |
| Subscription | `__config.ps1` → `SubscriptionId` |
| Tenant | `__config.ps1` → `TenantId` |
| Service principal | `__config.ps1` → `ClientId` / `ClientSecret` |

De URL van de live applicatie is `https://<WebAppName>.azurewebsites.net` — afhankelijk van de gekozen omgeving.

---

## GitHub Actions workflow

De pipeline is volledig geautomatiseerd via `.github/workflows/build-and-deploy.yml`. De workflow is een 1-op-1 equivalent van `build-and-deploy.ps1` en draait op een Linux runner in GitHub.

### Triggers

| Trigger | Omgeving | Beschrijving |
|---|---|---|
| Push naar `main` met wijziging in `input/**.sb3.zip` | `sandbox` | Automatisch na inchecken van een nieuw `.sb3.zip` bestand |
| Handmatig via _Actions → Run workflow_ | Keuze | Deploy naar een specifieke omgeving met optioneel bestandsnaam |

### Authenticatie — OIDC (geen wachtwoord)

De workflow gebruikt **Workload Identity Federation (OIDC)** — er wordt geen `clientSecret` opgeslagen. GitHub authenticeert direct bij Azure via een short-lived token.

**Eenmalige setup in Azure** per environment:

1. Ga naar **Azure Portal → App Registrations → jouw app → Certificates & secrets → Federated credentials**
2. Klik **Add credential** → kies **GitHub Actions**
3. Vul in:
   - Organization: `muratbalasar`
   - Repository: `for-kids-scratch-game-shark-001`
   - Entity type: **Environment**
   - Environment name: `sandbox` _(herhaal voor elke omgeving)_

### GitHub environments

Maak in GitHub (**Settings → Environments**) de volgende environments aan:

| Environment | Azure omgeving |
|---|---|
| `sandbox` | SANDBOX (S) |
| `ontwikkel` | ONTWIKKEL (O) |
| `test` | TEST (T) |
| `acceptatie` | ACCEPTATIE (A) |
| `productie` | PRODUCTIE (P) |

### Secrets & variables per environment

Stel per environment de volgende waarden in. De waarden zijn terug te vinden in `__config.ps1`.

**Secrets** (_Settings → Environments → [env] → Secrets_):

| Secret | Waarde uit `__config.ps1` |
|---|---|
| `AZURE_CLIENT_ID` | `ClientId` |
| `AZURE_TENANT_ID` | `TenantId` |
| `AZURE_SUBSCRIPTION_ID` | `SubscriptionId` |
| `AZURE_RESOURCE_GROUP` | `ResourceGroup` |

**Variables** (_Settings → Environments → [env] → Variables_):

| Variable | Waarde uit `__config.ps1` |
|---|---|
| `AZURE_WEBAPP_NAME` | `WebAppName` |

### Pipeline stappen

```
input/*.sb3.zip  →  _GAME_pkg.sb3  →  node package-sb3.js  →  output/index.html  →  deploy_game.zip  →  Azure Web App
```

| Stap | Actie |
|---|---|
| **Find .sb3.zip** | Auto-detect nieuwste bestand in `input/`, of gebruik opgegeven bestandsnaam |
| **npm install** | Installeert `@turbowarp/packager` |
| **Package** | `node package-sb3.js` genereert `output/index.html` |
| **Azure Login** | OIDC-login — geen wachtwoord |
| **Ensure Web App** | Maakt Web App en App Service Plan (F1) aan als ze nog niet bestaan |
| **Deploy** | `az webapp deploy` pusht `deploy_game.zip` naar de Web App |
