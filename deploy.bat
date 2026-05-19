@echo off
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
echo HARMAALWALE - SMART DEPLOY (ALL CHANGED FILES)
echo Time: %mydate% %mytime%
echo ============================================================
echo.

echo [STEP 1] Scanning ALL changed files
echo.

REM Get list of all changed files from git
git diff --name-only HEAD > "%TEMP%\changed_files.txt"
git ls-files -o --exclude-standard >> "%TEMP%\changed_files.txt"

echo Changed files detected:
type "%TEMP%\changed_files.txt"
echo.

echo [STEP 2] Git operations
echo.
git pull origin main 2>nul
git add -A
git commit -m "Deploy %mydate% %mytime%" 2>nul
git push origin main

if %errorlevel% equ 0 (
    echo [OK] Pushed to GitHub
) else (
    echo [WARN] GitHub update had issues
)

echo.
echo [STEP 3] Uploading ALL changed files to cPanel
echo.

set COUNT=0

for /f "delims=" %%F in (type "%TEMP%\changed_files.txt") do (
    set FILE=%%F
    if exist "!FILE!" (
        echo - !FILE!
        scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "!FILE!" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/!FILE! 2>nul
        set /a COUNT+=1
    )
)

echo [OK] Uploaded !COUNT! files

echo.
echo [STEP 4] Setting permissions
echo.
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "find /home/harmakko/public_html -type d -exec chmod 755 {} \; 2>/dev/null; find /home/harmakko/public_html -type f -exec chmod 644 {} \; 2>/dev/null"

echo [OK] Permissions set

echo.
echo ============================================================
echo DEPLOYMENT COMPLETE
echo ============================================================
echo.
echo GitHub:  https://github.com/harmaalwale/harmaalwale
echo Live:    https://harmaalwale.com
echo.

:ASK
set /p INPUT="Type 'x' to close: "
if /i "%INPUT%"=="x" exit
goto ASK
