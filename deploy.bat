@echo off
REM ============================================================
REM HARMAALWALE - ONE-CLICK DEPLOY (FIXED)
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

if %errorlevel% equ 0 (
    echo [OK] Pushed to GitHub
) else (
    echo [ERROR] GitHub push failed
)

echo.
echo [STEP 3] Syncing to cPanel
echo.

REM Deploy to cPanel via git pull
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "cd /home/harmakko/public_html; git pull origin main; chmod -R 755 .; find . -type f -exec chmod 644 {} \; 2>/dev/null"

if %errorlevel% equ 0 (
    echo [OK] cPanel synced
) else (
    echo [ERROR] cPanel sync failed
)

echo.
echo ============================================================
echo DEPLOYMENT COMPLETE
echo ============================================================
echo.
echo GitHub:  https://github.com/harmaalwale/harmaalwale
echo Live:    https://harmaalwale.com
echo.
echo Changes live in 5 seconds
echo.

:ASK
set /p INPUT="Type 'x' to close: "
if /i "%INPUT%"=="x" exit
goto ASK
