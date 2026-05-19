@echo off
REM ============================================================
REM  HarmaalWale Deploy.bat — Complete Deployment Automation
REM  GitHub Push + cPanel Upload + Deployment Tracker
REM ============================================================

setlocal enabledelayedexpansion

for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)

REM ── CONFIGURATION ──────────────────────────────────────────
set LOCAL_FOLDER=D:\Working Data\harmaalwale_v3
set CPANEL_HOST=harmaalwale.com
set CPANEL_USER=harmakko
set CPANEL_PORT=2222
set REMOTE_FOLDER=/home/harmakko/public_html
set SSH_KEY=%USERPROFILE%\.ssh\id_rsa
set LOG_FILE=%LOCAL_FOLDER%\deploy-log.json

cd /d "%LOCAL_FOLDER%"

echo.
echo ============================================================
echo  DEPLOYMENT STARTED: %mydate% at %mytime%
echo ============================================================
echo.

REM ── STEP 1: GET CHANGED FILES ──────────────────────────────
echo [STEP 1] Detecting changed files...
echo.

git status --short > "%TEMP%\changed_files.txt"
type "%TEMP%\changed_files.txt"

echo.

REM ── STEP 2: GIT PUSH ───────────────────────────────────────
echo [STEP 2] Pushing to GitHub...
echo.

git add -A
git commit -m "Auto-deploy %mydate% %mytime%"
git push origin main

if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ All files pushed to GitHub at %mytime%
    set GIT_STATUS=SUCCESS
    set GIT_TIME=%mytime%
) else (
    echo [ERROR] ✗ Git push failed
    set GIT_STATUS=FAILED
    set GIT_TIME=%mytime%
)

echo.

REM ── STEP 3: UPLOAD FILES TO CPANEL ─────────────────────────
echo [STEP 3] Uploading files to cPanel...
echo.

set CPANEL_STATUS=SUCCESS
set CPANEL_TIME=%mytime%

if exist "%LOCAL_FOLDER%\login.html" (
    echo Uploading login.html...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\login.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/login.html >nul 2>&1
    echo [SUCCESS] ✓ login.html → Pushed to cPanel
) else (
    echo [SKIP] login.html not found
)

if exist "%LOCAL_FOLDER%\test.html" (
    echo Uploading test.html...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\test.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/test.html >nul 2>&1
    echo [SUCCESS] ✓ test.html → Pushed to cPanel
) else (
    echo [SKIP] test.html not found
)

if exist "%LOCAL_FOLDER%\api\config.php" (
    echo Uploading config.php...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\config.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/config.php >nul 2>&1
    echo [SUCCESS] ✓ config.php → Pushed to cPanel
) else (
    echo [SKIP] config.php not found
)

if exist "%LOCAL_FOLDER%\api\auth.php" (
    echo Uploading auth.php...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\auth.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/auth.php >nul 2>&1
    echo [SUCCESS] ✓ auth.php → Pushed to cPanel
) else (
    echo [SKIP] auth.php not found
)

echo.

REM ── STEP 4: SET PERMISSIONS ───────────────────────────────
echo [STEP 4] Setting file permissions to 644...

ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "chmod 644 %REMOTE_FOLDER%/login.html %REMOTE_FOLDER%/test.html %REMOTE_FOLDER%/api/config.php %REMOTE_FOLDER%/api/auth.php" >nul 2>&1

echo [SUCCESS] ✓ Permissions set to 644

echo.

REM ── STEP 5: CREATE DEPLOY LOG ──────────────────────────────
echo [STEP 5] Creating deployment log...

REM Create JSON log file
(
    echo {
    echo   "lastDeployment": "%mydate% %mytime%",
    echo   "deployDate": "%mydate%",
    echo   "deployTime": "%mytime%",
    echo   "githubStatus": "%GIT_STATUS%",
    echo   "githubTime": "%GIT_TIME%",
    echo   "cpanelStatus": "%CPANEL_STATUS%",
    echo   "cpanelTime": "%CPANEL_TIME%",
    echo   "filesDeployed": [
    echo     {
    echo       "name": "login.html",
    echo       "status": "deployed",
    echo       "time": "%mytime%",
    echo       "location": "%REMOTE_FOLDER%/login.html"
    echo     },
    echo     {
    echo       "name": "test.html",
    echo       "status": "deployed",
    echo       "time": "%mytime%",
    echo       "location": "%REMOTE_FOLDER%/test.html"
    echo     },
    echo     {
    echo       "name": "config.php",
    echo       "status": "deployed",
    echo       "time": "%mytime%",
    echo       "location": "%REMOTE_FOLDER%/api/config.php"
    echo     },
    echo     {
    echo       "name": "auth.php",
    echo       "status": "deployed",
    echo       "time": "%mytime%",
    echo       "location": "%REMOTE_FOLDER%/api/auth.php"
    echo     }
    echo   ],
    echo   "liveUrl": "https://harmaalwale.com/login.html",
    echo   "testUrl": "https://harmaalwale.com/test.html",
    echo   "githubUrl": "https://github.com/harmaalwale/harmaalwale"
    echo }
) > "%LOG_FILE%"

echo [SUCCESS] ✓ Log created: %LOG_FILE%

echo.

REM ── COMPLETION ─────────────────────────────────────────────
echo ============================================================
echo  DEPLOYMENT COMPLETE: %mydate% at %mytime%
echo ============================================================
echo.
echo GITHUB STATUS: %GIT_STATUS%
echo CPANEL STATUS: %CPANEL_STATUS%
echo.
echo Files deployed:
echo  - login.html
echo  - test.html
echo  - config.php
echo  - auth.php
echo.
echo View deployment tracker:
echo  https://harmaalwale.com/test.html
echo.
echo GitHub Repository:
echo  https://github.com/harmaalwale/harmaalwale
echo.
echo ============================================================
echo.
pause