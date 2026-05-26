# ============================================================
# build.ps1
# Shortcut: alleen packagen voor Sandbox (geen deploy)
# Gebruik: .\build.ps1 [-InputZip "bestandsnaam.sb3.zip"]
# ============================================================
param(
    [string]$InputZip = ""
)

& "$PSScriptRoot\build-and-deploy.ps1" -Environment Sandbox -WhatIf @PSBoundParameters
