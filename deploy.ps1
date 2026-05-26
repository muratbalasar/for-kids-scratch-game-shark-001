# ============================================================
# deploy.ps1
# Shortcut: bouwen en deployen naar Sandbox
# Gebruik: .\deploy.ps1 [-InputZip "bestandsnaam.sb3.zip of .sb3"]
# ============================================================
param(
    [string]$InputZip = ""
)

& "$PSScriptRoot\build-and-deploy.ps1" -Environment Sandbox @PSBoundParameters
