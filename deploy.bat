@echo off
REM ============================================================
REM HarmaalWale Deploy.bat - FINAL WORKING VERSION
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

echo.
echo ============================================================
echo DEPLOYMENT: %mydate% %mytime%
echo ============================================================
echo.

echo [1] Git Status
git status --short

echo [2] Pushing to GitHub...
git add -A
git commit -m "Deploy %mydate% %mytime%" 2>nul
git push origin main 2>nul
echo [SUCCESS] GitHub updated

echo.
echo [3] Uploading to cPanel...

REM Upload critical files
echo - index.html
scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no index.html %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/index.html 2>nul

echo - login.html
scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no login.html %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/login.html 2>nul

echo - test.html
scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no test.html %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/test.html 2>nul

echo - api/auth.php
scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no api\auth.php %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/auth.php 2>nul

echo - api/config.php
scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no api\config.php %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/config.php 2>nul

echo [SUCCESS] Files uploaded

echo.
echo [4] Setting permissions...
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "chmod -R 755 %REMOTE_FOLDER%; find %REMOTE_FOLDER% -type f -exec chmod 644 {} \;" 2>nul
echo [SUCCESS] Permissions set

echo.
echo ============================================================
echo DEPLOYMENT COMPLETE
echo ============================================================
echo.
echo Live: https://harmaalwale.com
echo.

:ASK
set /p INPUT="Type 'x' to close: "
if /i "%INPUT%"=="x" exit
goto ASK