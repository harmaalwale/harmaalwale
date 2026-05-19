@echo off
REM ============================================================
REM HARMAALWALE - ULTIMATE ONE-CLICK DEPLOY
REM Local → GitHub + Local → cPanel (simultaneously)
REM ============================================================
setlocal enabledelayedexpansion

for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)

set LOCAL_FOLDER=D:\Working Data\harmaalwale_v3
set CPANEL_HOST=harmaalwale.com
set CPANEL_USER=harmakko
set CPANEL_PORT=2222
set REMOTE_FOLDER=/home/harmakko/public_html
set SSH_KEY=%USERPROFILE%\.ssh\id_rsa

cd /d "%LOCAL_FOLDER%"

cls
echo.
echo ============================================================
echo HARMAALWALE - ONE-CLICK DEPLOY
echo Time: %mydate% %mytime%
echo ============================================================
echo.

echo [STEP 1] Checking Git Status
echo.
git status --short
echo.

echo [STEP 2] Syncing with GitHub
echo.
git pull origin main 2>nul
git add -A
git commit -m "Deploy %mydate% %mytime%" 2>nul
git push origin main

if !errorlevel! equ 0 (
    echo [✓] Pushed to GitHub
) else (
    echo [✗] GitHub push failed
)

echo.
echo [STEP 3] Syncing to cPanel (pulling latest)
echo.

REM SSH to cPanel and git pull
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% ^
  "cd %REMOTE_FOLDER% && ^
   git pull origin main && ^
   find . -type d -exec chmod 755 {} \; 2>/dev/null && ^
   find . -type f -exec chmod 644 {} \; 2>/dev/null && ^
   echo 'cPanel synced successfully'"

if !errorlevel! equ 0 (
    echo [✓] cPanel synced
) else (
    echo [✗] cPanel sync had issues
)

echo.
echo ============================================================
echo [✓] DEPLOYMENT COMPLETE
echo ============================================================
echo.
echo GitHub:  https://github.com/harmaalwale/harmaalwale
echo Live:    https://harmaalwale.com
echo.

:ASK
set /p INPUT="Type 'x' to close: "
if /i "%INPUT%"=="x" exit
goto ASK