@echo off
:: ============================================================
:: sync.cmd
:: Gebruik: sync.cmd "commit bericht"
::          Leest GitHub PAT uit __git-token.txt (gitignored)
:: ============================================================

if "%~1"=="" (
    echo Gebruik: sync.cmd "commit bericht"
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$msg = '%~1'; " ^
    "$tokenFile = Join-Path $PSScriptRoot '__git-token.txt'; " ^
    "if (Test-Path $tokenFile) { $token = (Get-Content $tokenFile).Trim() } else { $token = Read-Host 'GitHub PAT token' }; " ^
    "git add -A; " ^
    "git commit -m $msg; " ^
    "git remote set-url origin \"https://muratbalasar:$token@github.com/muratbalasar/for-kids-scratch-game-shark-001.git\"; " ^
    "git push; " ^
    "git remote set-url origin 'https://github.com/muratbalasar/for-kids-scratch-game-shark-001.git'"
