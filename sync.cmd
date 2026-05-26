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

set SCRIPT_DIR=%~dp0
set COMMIT_MSG=%~1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$tokenFile = '%SCRIPT_DIR%__git-token.txt'; " ^
    "if (Test-Path $tokenFile) { $token = (Get-Content $tokenFile).Trim() } else { $token = Read-Host 'GitHub PAT token' }; " ^
    "git add -A; " ^
    "git commit -m '%COMMIT_MSG%'; " ^
    "git remote set-url origin \"https://muratbalasar:$token@github.com/muratbalasar/for-kids-scratch-game-shark-001.git\"; " ^
    "git push; " ^
    "git remote set-url origin 'https://github.com/muratbalasar/for-kids-scratch-game-shark-001.git'"
