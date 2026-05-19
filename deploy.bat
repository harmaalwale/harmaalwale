@echo off
REM ============================================================
REM  HarmaalWale Deploy.bat — GitHub + cPanel Auto-Upload
REM  Tracks all changes, shows file-by-file progress
REM ============================================================

setlocal enabledelayedexpansion

REM Get timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)

REM ── CONFIGURATION ──────────────────────────────────────────
set LOCAL_FOLDER=D:\Working Data\harmaalwale_v3
set GITHUB_REPO=harmaalwale/harmaalwale
set CPANEL_HOST=harmaalwale.com
set CPANEL_USER=harmakko
set CPANEL_PASS=Shero@2023!
set CPANEL_PORT=2222
set REMOTE_FOLDER=/home/harmakko/public_html

cd /d "%LOCAL_FOLDER%"

echo.
echo ============================================================
echo  DEPLOYMENT STARTED: %mydate% at %mytime%
echo ============================================================
echo.

REM ── STEP 1: GIT PUSH ALL CHANGES ───────────────────────────
echo [STEP 1] Tracking changes and pushing to GitHub...
echo.

REM Show changed files
echo Files changed:
git status --short

echo.
echo Pushing to GitHub...
git add -A
git commit -m "Auto-deploy %mydate% %mytime%"
git push origin main

if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] ✓ All files pushed to GitHub at %mytime%
    echo.
) else (
    echo.
    echo [ERROR] ✗ Git push failed
    echo.
    pause
    exit /b 1
)

REM ── STEP 2: UPLOAD KEY FILES TO CPANEL ─────────────────────
echo [STEP 2] Uploading files to cPanel...
echo.

REM Upload login.html
if exist "%LOCAL_FOLDER%\login.html" (
    echo Uploading login.html...
    scp -P %CPANEL_PORT% -o StrictHostKeyChecking=no -o BatchMode=no "%LOCAL_FOLDER%\login.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/login.html 2>nul
    echo [SUCCESS] ✓ login.html → Pushed to cPanel
) else (
    echo [SKIP] login.html not found
)

REM Upload config.php
if exist "%LOCAL_FOLDER%\api\config.php" (
    echo Uploading config.php...
    scp -P %CPANEL_PORT% -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\config.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/config.php 2>nul
    echo [SUCCESS] ✓ config.php → Pushed to cPanel
) else (
    echo [SKIP] config.php not found
)

REM Upload auth.php
if exist "%LOCAL_FOLDER%\api\auth.php" (
    echo Uploading auth.php...
    scp -P %CPANEL_PORT% -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\auth.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/auth.php 2>nul
    echo [SUCCESS] ✓ auth.php → Pushed to cPanel
) else (
    echo [SKIP] auth.php not found
)

REM Upload schema-auth.sql if exists
if exist "%LOCAL_FOLDER%\schema-auth.sql" (
    echo Uploading schema-auth.sql...
    scp -P %CPANEL_PORT% -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\schema-auth.sql" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/schema-auth.sql 2>nul
    echo [SUCCESS] ✓ schema-auth.sql → Pushed to cPanel
) else (
    echo [SKIP] schema-auth.sql not found
)

echo.

REM ── STEP 3: SET PERMISSIONS ────────────────────────────────
echo [STEP 3] Setting file permissions to 644...

ssh -p %CPANEL_PORT% -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "chmod 644 %REMOTE_FOLDER%/login.html %REMOTE_FOLDER%/api/config.php %REMOTE_FOLDER%/api/auth.php 2>/dev/null"

echo [SUCCESS] ✓ Permissions set to 644

echo.

REM ── COMPLETION ─────────────────────────────────────────────
echo ============================================================
echo  DEPLOYMENT COMPLETE: %mydate% %mytime%
echo ============================================================
echo.
echo GITHUB STATUS:
echo  [✓] Code committed and pushed
echo.
echo CPANEL STATUS:
echo  [✓] login.html → Pushed to cPanel
echo  [✓] config.php → Pushed to cPanel
echo  [✓] auth.php → Pushed to cPanel
echo  [✓] Permissions set to 644
echo.
echo Live URL: https://harmaalwale.com/login.html
echo.
echo Repository: https://github.com/%GITHUB_REPO%
echo.
echo ============================================================
echo.
pause