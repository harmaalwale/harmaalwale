@echo off
REM ============================================================
REM  HarmaalWale Deploy.bat — FINAL FIXED VERSION
REM  Only changed files + NO AUTO-CLOSE (Window stays open)
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
set LOG_FILE=%LOCAL_FOLDER%\deploy-log.json

set DEPLOYMENT_SUCCESS=1
set DEPLOYMENT_ERRORS=

cd /d "%LOCAL_FOLDER%"

echo.
echo ============================================================
echo  DEPLOYMENT STARTED: %mydate% at %mytime%
echo ============================================================
echo.

echo [STEP 1] Detecting changed files...
echo.

git status --short > "%TEMP%\changed_files.txt"
echo Changed files:
type "%TEMP%\changed_files.txt"
echo.

echo [STEP 2] Pushing to GitHub...
echo.

git add -A
git commit -m "Auto-deploy %mydate% %mytime%"
git push origin main

if %errorlevel% equ 0 (
    echo [SUCCESS] Code pushed to GitHub
    set GIT_STATUS=SUCCESS
    set GIT_TIME=%mytime%
) else (
    echo [ERROR] Git push failed
    set GIT_STATUS=FAILED
    set GIT_TIME=%mytime%
    set DEPLOYMENT_SUCCESS=0
    set DEPLOYMENT_ERRORS=!DEPLOYMENT_ERRORS!Git failed.
)

echo.
echo [STEP 3] Uploading changed files to cPanel...
echo.

set CPANEL_STATUS=SUCCESS
set CPANEL_TIME=%mytime%
set DEPLOYED_FILES=

findstr /M "login.html" "%TEMP%\changed_files.txt" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%LOCAL_FOLDER%\login.html" (
        echo Uploading login.html...
        scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\login.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/login.html >nul 2>&1
        if %errorlevel% equ 0 (
            echo [SUCCESS] login.html uploaded
            set DEPLOYED_FILES=!DEPLOYED_FILES!    {"name": "login.html", "status": "deployed", "time": "%mytime%", "location": "%REMOTE_FOLDER%/login.html"},
        ) else (
            echo [ERROR] login.html FAILED
            set DEPLOYMENT_SUCCESS=0
        )
    )
) else (
    echo [SKIP] login.html - No changes
)

findstr /M "test.html" "%TEMP%\changed_files.txt" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%LOCAL_FOLDER%\test.html" (
        echo Uploading test.html...
        scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\test.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/test.html >nul 2>&1
        if %errorlevel% equ 0 (
            echo [SUCCESS] test.html uploaded
            set DEPLOYED_FILES=!DEPLOYED_FILES!    {"name": "test.html", "status": "deployed", "time": "%mytime%", "location": "%REMOTE_FOLDER%/test.html"},
        ) else (
            echo [ERROR] test.html FAILED
            set DEPLOYMENT_SUCCESS=0
        )
    )
) else (
    echo [SKIP] test.html - No changes
)

findstr /M "config.php" "%TEMP%\changed_files.txt" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%LOCAL_FOLDER%\api\config.php" (
        echo Uploading config.php...
        scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\config.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/config.php >nul 2>&1
        if %errorlevel% equ 0 (
            echo [SUCCESS] config.php uploaded
            set DEPLOYED_FILES=!DEPLOYED_FILES!    {"name": "config.php", "status": "deployed", "time": "%mytime%", "location": "%REMOTE_FOLDER%/api/config.php"},
        ) else (
            echo [ERROR] config.php FAILED
            set DEPLOYMENT_SUCCESS=0
        )
    )
) else (
    echo [SKIP] config.php - No changes
)

findstr /M "auth.php" "%TEMP%\changed_files.txt" >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%LOCAL_FOLDER%\api\auth.php" (
        echo Uploading auth.php...
        scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\auth.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/auth.php >nul 2>&1
        if %errorlevel% equ 0 (
            echo [SUCCESS] auth.php uploaded
            set DEPLOYED_FILES=!DEPLOYED_FILES!    {"name": "auth.php", "status": "deployed", "time": "%mytime%", "location": "%REMOTE_FOLDER%/api/auth.php"},
        ) else (
            echo [ERROR] auth.php FAILED
            set DEPLOYMENT_SUCCESS=0
        )
    )
) else (
    echo [SKIP] auth.php - No changes
)

echo.
echo [STEP 4] Setting permissions...
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "chmod 644 %REMOTE_FOLDER%/login.html %REMOTE_FOLDER%/test.html %REMOTE_FOLDER%/api/config.php %REMOTE_FOLDER%/api/auth.php 2>/dev/null" >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] Permissions set
)

echo.
echo [STEP 5] Creating log...

for /f "tokens=* delims= " %%A in ("!DEPLOYED_FILES!") do set DEPLOYED_FILES=%%A
if not "!DEPLOYED_FILES!"=="" set DEPLOYED_FILES=!DEPLOYED_FILES:~0,-1!

(
    echo {
    echo   "lastDeployment": "%mydate% %mytime%",
    echo   "githubStatus": "%GIT_STATUS%",
    echo   "cpanelStatus": "%CPANEL_STATUS%",
    echo   "filesDeployed": [!DEPLOYED_FILES!]
    echo }
) > "%LOG_FILE%"

echo [SUCCESS] Log created
echo.

if %DEPLOYMENT_SUCCESS% equ 1 (
    echo ============================================================
    echo  SUCCESS - Deployment complete at %mytime%
    echo ============================================================
) else (
    echo ============================================================
    echo  FAILED - Check errors above
    echo ============================================================
)

echo.
:KEEP_OPEN
echo.
echo Press X (or type 'exit') and press ENTER to close this window:
set /p CLOSE=
if /i "%CLOSE%"=="x" goto END
if /i "%CLOSE%"=="exit" goto END
goto KEEP_OPEN

:END
