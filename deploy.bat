@echo off
REM ============================================================
REM  HarmaalWale Deploy.bat — Smart Deployment
REM  Manual close only (no auto-close)
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

set DEPLOYMENT_SUCCESS=1
set DEPLOYMENT_ERRORS=

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
echo Changed files:
type "%TEMP%\changed_files.txt"

echo.

REM ── STEP 2: GIT PUSH ───────────────────────────────────────
echo [STEP 2] Pushing to GitHub...
echo.

git add -A
git commit -m "Auto-deploy %mydate% %mytime%"
git push origin main

if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ Code pushed to GitHub at %mytime%
    set GIT_STATUS=SUCCESS
    set GIT_TIME=%mytime%
) else (
    echo [ERROR] ✗ Git push failed
    set GIT_STATUS=FAILED
    set GIT_TIME=%mytime%
    set DEPLOYMENT_SUCCESS=0
    set DEPLOYMENT_ERRORS=!DEPLOYMENT_ERRORS!Git push failed. Check GitHub credentials.
)

echo.

REM ── STEP 3: UPLOAD ONLY CHANGED FILES ──────────────────────
echo [STEP 3] Uploading CHANGED files to cPanel...
echo.

set CPANEL_STATUS=SUCCESS
set CPANEL_TIME=%mytime%
set DEPLOYED_FILES=

REM Check and upload login.html if changed
findstr /M "login.html" "%TEMP%\changed_files.txt" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%LOCAL_FOLDER%\login.html" (
        echo Uploading login.html (CHANGED)...
        scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\login.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/login.html >nul 2>&1
        if %errorlevel% equ 0 (
            echo [SUCCESS] ✓ login.html → Pushed to cPanel
            set DEPLOYED_FILES=!DEPLOYED_FILES!    {^
      "name": "login.html",^
      "status": "deployed",^
      "time": "%mytime%",^
      "location": "%REMOTE_FOLDER%/login.html"^
    },
        ) else (
            echo [ERROR] ✗ login.html upload FAILED
            set DEPLOYMENT_SUCCESS=0
            set DEPLOYMENT_ERRORS=!DEPLOYMENT_ERRORS!login.html upload failed. 
        )
    )
) else (
    echo [SKIP] login.html - No changes
)

REM Check and upload test.html if changed
findstr /M "test.html" "%TEMP%\changed_files.txt" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%LOCAL_FOLDER%\test.html" (
        echo Uploading test.html (CHANGED)...
        scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\test.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/test.html >nul 2>&1
        if %errorlevel% equ 0 (
            echo [SUCCESS] ✓ test.html → Pushed to cPanel
            set DEPLOYED_FILES=!DEPLOYED_FILES!    {^
      "name": "test.html",^
      "status": "deployed",^
      "time": "%mytime%",^
      "location": "%REMOTE_FOLDER%/test.html"^
    },
        ) else (
            echo [ERROR] ✗ test.html upload FAILED
            set DEPLOYMENT_SUCCESS=0
            set DEPLOYMENT_ERRORS=!DEPLOYMENT_ERRORS!test.html upload failed. 
        )
    )
) else (
    echo [SKIP] test.html - No changes
)

REM Check and upload config.php if changed
findstr /M "config.php" "%TEMP%\changed_files.txt" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%LOCAL_FOLDER%\api\config.php" (
        echo Uploading config.php (CHANGED)...
        scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\config.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/config.php >nul 2>&1
        if %errorlevel% equ 0 (
            echo [SUCCESS] ✓ config.php → Pushed to cPanel
            set DEPLOYED_FILES=!DEPLOYED_FILES!    {^
      "name": "config.php",^
      "status": "deployed",^
      "time": "%mytime%",^
      "location": "%REMOTE_FOLDER%/api/config.php"^
    },
        ) else (
            echo [ERROR] ✗ config.php upload FAILED
            set DEPLOYMENT_SUCCESS=0
            set DEPLOYMENT_ERRORS=!DEPLOYMENT_ERRORS!config.php upload failed. 
        )
    )
) else (
    echo [SKIP] config.php - No changes
)

REM Check and upload auth.php if changed
findstr /M "auth.php" "%TEMP%\changed_files.txt" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%LOCAL_FOLDER%\api\auth.php" (
        echo Uploading auth.php (CHANGED)...
        scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\auth.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/auth.php >nul 2>&1
        if %errorlevel% equ 0 (
            echo [SUCCESS] ✓ auth.php → Pushed to cPanel
            set DEPLOYED_FILES=!DEPLOYED_FILES!    {^
      "name": "auth.php",^
      "status": "deployed",^
      "time": "%mytime%",^
      "location": "%REMOTE_FOLDER%/api/auth.php"^
    },
        ) else (
            echo [ERROR] ✗ auth.php upload FAILED
            set DEPLOYMENT_SUCCESS=0
            set DEPLOYMENT_ERRORS=!DEPLOYMENT_ERRORS!auth.php upload failed. 
        )
    )
) else (
    echo [SKIP] auth.php - No changes
)

echo.

REM ── STEP 4: SET PERMISSIONS FOR CHANGED FILES ──────────────
echo [STEP 4] Setting file permissions to 644...

ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "chmod 644 %REMOTE_FOLDER%/login.html %REMOTE_FOLDER%/test.html %REMOTE_FOLDER%/api/config.php %REMOTE_FOLDER%/api/auth.php 2>/dev/null" >nul 2>&1

if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ Permissions set to 644
) else (
    echo [ERROR] ✗ Permission change failed
    set DEPLOYMENT_SUCCESS=0
    set DEPLOYMENT_ERRORS=!DEPLOYMENT_ERRORS!Permission change failed. 
)

echo.

REM ── STEP 5: CREATE DEPLOY LOG ──────────────────────────────
echo [STEP 5] Creating deployment log...

REM Remove trailing comma from DEPLOYED_FILES
for /f "tokens=* delims= " %%A in ("!DEPLOYED_FILES!") do set DEPLOYED_FILES=%%A
set DEPLOYED_FILES=!DEPLOYED_FILES:~0,-1!

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
    echo     !DEPLOYED_FILES!
    echo   ],
    echo   "liveUrl": "https://harmaalwale.com/login.html",
    echo   "testUrl": "https://harmaalwale.com/test.html",
    echo   "githubUrl": "https://github.com/harmaalwale/harmaalwale"
    echo }
) > "%LOG_FILE%"

echo [SUCCESS] ✓ Log created: %LOG_FILE%

echo.

REM ── FINAL REPORT ───────────────────────────────────────────
if %DEPLOYMENT_SUCCESS% equ 1 (
    echo ============================================================
    echo  ✓ DEPLOYMENT SUCCESSFUL: %mydate% at %mytime%
    echo ============================================================
    echo.
    echo GITHUB STATUS: %GIT_STATUS%
    echo CPANEL STATUS: %CPANEL_STATUS%
    echo.
    echo View deployment tracker:
    echo  https://harmaalwale.com/test.html
    echo.
    echo GitHub Repository:
    echo  https://github.com/harmaalwale/harmaalwale
    echo.
) else (
    echo ============================================================
    echo  ✗ DEPLOYMENT FAILED: %mydate% at %mytime%
    echo ============================================================
    echo.
    echo ERRORS:
    echo  %DEPLOYMENT_ERRORS%
    echo.
    echo GITHUB STATUS: %GIT_STATUS%
    echo CPANEL STATUS: %CPANEL_STATUS%
    echo.
    echo Please check:
    echo  1. SSH key setup (test: ssh -p 2222 harmakko@harmaalwale.com)
    echo  2. GitHub credentials (test: git status)
    echo  3. cPanel connectivity (test: ping harmaalwale.com)
    echo  4. File permissions (should be 644)
    echo.
)

echo ============================================================
echo.
echo Press any key to close this window...
pause