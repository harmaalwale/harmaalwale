@echo off
REM ============================================================
REM  HarmaalWale Deploy.bat — FINAL VERSION
REM  Reliable file uploads with explicit paths
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
echo  DEPLOYMENT STARTED: %mydate% at %mytime%
echo ============================================================
echo.

echo [STEP 1] Detecting changed files...
git status --short > "%TEMP%\changed_files.txt"
echo.
type "%TEMP%\changed_files.txt"
echo.

echo [STEP 2] Pushing to GitHub...
git add -A
git commit -m "Auto-deploy %mydate% %mytime%"
git push origin main

if %errorlevel% equ 0 (
    echo [SUCCESS] GitHub push complete
    set GIT_STATUS=SUCCESS
) else (
    echo [ERROR] GitHub push failed
    set GIT_STATUS=FAILED
)

echo.
echo [STEP 3] Uploading to cPanel...
echo.

set UPLOADED=0

REM Upload config.php explicitly
if exist "api\config.php" (
    echo Uploading api/config.php...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\config.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/config.php
    if !errorlevel! equ 0 (
        echo [SUCCESS] config.php uploaded
        set /a UPLOADED+=1
    ) else (
        echo [ERROR] config.php failed
    )
)

REM Upload auth.php explicitly
if exist "api\auth.php" (
    echo Uploading api/auth.php...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\auth.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/auth.php
    if !errorlevel! equ 0 (
        echo [SUCCESS] auth.php uploaded
        set /a UPLOADED+=1
    ) else (
        echo [ERROR] auth.php failed
    )
)

REM Upload login.html explicitly
if exist "login.html" (
    echo Uploading login.html...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\login.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/login.html
    if !errorlevel! equ 0 (
        echo [SUCCESS] login.html uploaded
        set /a UPLOADED+=1
    ) else (
        echo [ERROR] login.html failed
    )
)

REM Upload test.html explicitly
if exist "test.html" (
    echo Uploading test.html...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\test.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/test.html
    if !errorlevel! equ 0 (
        echo [SUCCESS] test.html uploaded
        set /a UPLOADED+=1
    ) else (
        echo [ERROR] test.html failed
    )
)

echo.
echo [STEP 4] Setting permissions...
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "chmod -R 755 %REMOTE_FOLDER%"
echo [SUCCESS] Permissions set

echo.
echo ============================================================
echo  DEPLOYMENT COMPLETE at %mytime%
echo ============================================================
echo.
echo Files uploaded: %UPLOADED%
echo GitHub: %GIT_STATUS%
echo.

:WAIT
echo.
echo Type 'x' to close this window:
set /p INPUT=
if /i "%INPUT%"=="x" exit
goto WAIT