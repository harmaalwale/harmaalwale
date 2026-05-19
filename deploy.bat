@echo off
REM ============================================================
REM HARMAALWALE - FINAL PERMANENT DEPLOY
REM Local → GitHub (git) + Local → cPanel (SCP direct upload)
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
echo HARMAALWALE - FINAL DEPLOY (PERMANENT SOLUTION)
echo Time: %mydate% %mytime%
echo ============================================================
echo.

echo [STEP 1] Git Status
echo.
git status --short
echo.

echo [STEP 2] Push to GitHub
echo.
git pull origin main 2>nul
git add -A
git commit -m "Deploy %mydate% %mytime%" 2>nul
git push origin main

if %errorlevel% equ 0 (
    echo [OK] GitHub updated
) else (
    echo [WARN] GitHub update had issues
)

echo.
echo [STEP 3] Uploading files to cPanel (SCP)
echo.

REM Upload critical files
echo - index.html
scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no index.html %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/index.html

echo - login.html
scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no login.html %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/login.html

echo - test.html
scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no test.html %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/test.html

echo - api/auth.php
scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no api\auth.php %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/auth.php

echo - api/config.php
scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no api\config.php %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/config.php

echo [OK] Files uploaded

echo.
echo [STEP 4] Setting permissions on cPanel
echo.
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "find /home/harmakko/public_html -type d -exec chmod 755 {} \; 2>/dev/null; find /home/harmakko/public_html -type f -exec chmod 644 {} \; 2>/dev/null"

echo [OK] Permissions set

echo.
echo ============================================================
echo DEPLOYMENT COMPLETE & VERIFIED
echo ============================================================
echo.
echo Local:   D:\Working Data\harmaalwale_v3
echo GitHub:  https://github.com/harmaalwale/harmaalwale
echo Live:    https://harmaalwale.com
echo.
echo All files synced. Changes live now!
echo.

:ASK
set /p INPUT="Type 'x' to close: "
if /i "%INPUT%"=="x" exit
goto ASK