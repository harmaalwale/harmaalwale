@echo off
REM ============================================================
REM  HarmaalWale Deploy.bat — GitHub Push + SCP Upload
REM ============================================================

setlocal enabledelayedexpansion

REM Get timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)

REM ── CONFIGURATION ──────────────────────────────────────────
set LOCAL_FOLDER=D:\Working Data\harmaalwale_v3
set CPANEL_HOST=harmaalwale.com
set CPANEL_USER=harmakko
set CPANEL_PORT=2222
set REMOTE_FOLDER=/home/harmakko/public_html

echo.
echo ============================================================
echo  DEPLOYMENT STARTED: %mydate% at %mytime%
echo ============================================================
echo.

REM ── STEP 1: GIT PUSH ───────────────────────────────────────
echo [STEP 1] Pushing to GitHub...
cd %LOCAL_FOLDER%

git add -A
git commit -m "Auto-deploy %mydate% %mytime%"
git push origin main

if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ Code pushed to GitHub at %mytime%
    echo.
) else (
    echo [ERROR] ✗ Git push failed
    echo.
    pause
    exit /b 1
)

REM ── STEP 2: UPLOAD FILES VIA SCP ───────────────────────────
echo [STEP 2] Uploading files to cPanel via SCP...
echo.

REM Upload login.html
echo Uploading login.html...
scp -P %CPANEL_PORT% -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\login.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/login.html

if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ login.html uploaded
) else (
    echo [ERROR] ✗ login.html upload FAILED
    pause
    exit /b 1
)

REM Upload config.php
echo Uploading config.php...
scp -P %CPANEL_PORT% -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\config.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/config.php

if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ config.php uploaded
) else (
    echo [ERROR] ✗ config.php upload FAILED
    pause
    exit /b 1
)

REM Upload auth.php
echo Uploading auth.php...
scp -P %CPANEL_PORT% -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\auth.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/auth.php

if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ auth.php uploaded
) else (
    echo [ERROR] ✗ auth.php upload FAILED
    pause
    exit /b 1
)

echo.

REM ── STEP 3: SET PERMISSIONS ────────────────────────────────
echo [STEP 3] Setting file permissions to 644...

ssh -p %CPANEL_PORT% -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "chmod 644 %REMOTE_FOLDER%/login.html %REMOTE_FOLDER%/api/config.php %REMOTE_FOLDER%/api/auth.php"

if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ Permissions set to 644
) else (
    echo [ERROR] ✗ Permission change FAILED
)

echo.

REM ── STEP 4: VERIFY UPLOADS ─────────────────────────────────
echo [STEP 4] Verifying files on server...

ssh -p %CPANEL_PORT% -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "ls -lh %REMOTE_FOLDER%/login.html %REMOTE_FOLDER%/api/config.php %REMOTE_FOLDER%/api/auth.php"

echo.

REM ── COMPLETION ─────────────────────────────────────────────
echo ============================================================
echo  DEPLOYMENT COMPLETE: %mydate% %mytime%
echo ============================================================
echo.
echo [✓] GitHub:     PUSHED
echo [✓] login.html: UPLOADED to cPanel
echo [✓] config.php: UPLOADED to cPanel
echo [✓] auth.php:   UPLOADED to cPanel
echo [✓] Permissions: SET (644)
echo.
echo Live URL: https://harmaalwale.com/login.html
echo.
echo ============================================================
echo Press any key to close...
pause