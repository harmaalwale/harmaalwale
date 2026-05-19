@echo off
:: HarmaalWale — Windows Deploy
:: Double-click this file OR run from Command Prompt
:: Requires Git Bash installed (comes with Git for Windows)

set SCRIPT_DIR=%~dp0

:: Find Git Bash
set BASH=C:\Program Files\Git\bin\bash.exe
if not exist "%BASH%" set BASH=C:\Program Files (x86)\Git\bin\bash.exe

if not exist "%BASH%" (
    echo ERROR: Git Bash not found.
    echo Install Git for Windows from https://git-scm.com/download/win
    pause
    exit /b 1
)

echo Starting HarmaalWale Deploy...
echo.

cd /d "%SCRIPT_DIR%"
"%BASH%" --login -i -c "cd '%SCRIPT_DIR%' && bash deploy.sh"

echo.
echo Done. Press any key to close.
pause > nul
