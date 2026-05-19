@echo off
REM ============================================================
REM  HarmaalWale Deploy.bat — SMART DEPLOYMENT
REM  Uploads ONLY changed files detected by git
REM  Works for ANY files in ANY subdirectory
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

cd /d "%LOCAL_FOLDER%"

echo.
echo ============================================================
echo  DEPLOYMENT STARTED: %mydate% at %mytime%
echo ============================================================
echo.

echo [STEP 1] Detecting changed files from git...
echo.

git status --short > "%TEMP%\changed_files.txt"
set /p CHANGES=<"%TEMP%\changed_files.txt"

if "%CHANGES%"=="" (
    echo No changes detected. Nothing to deploy.
    echo.
    echo Type 'x' to close:
    set /p INPUT=
    exit
)

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
) else (
    echo [ERROR] Git push failed
    set GIT_STATUS=FAILED
)

echo.
echo [STEP 3] Uploading ONLY changed files to cPanel...
echo.

set UPLOADED_COUNT=0

REM Read each changed file from git status
for /f "tokens=2*" %%A in ('type "%TEMP%\changed_files.txt"') do (
    set FILE=%%B
    
    if exist "!FILE!" (
        echo Uploading: !FILE!...
        REM Convert forward slashes to backslashes for local path
        set LOCALPATH=!FILE:/=\!
        REM Keep forward slashes for remote path
        set REMOTEPATH=!FILE:\=/!
        
        scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "!LOCALPATH!" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/!REMOTEPATH! >nul 2>&1
        
        if !errorlevel! equ 0 (
            echo [SUCCESS] !FILE! uploaded
            set /a UPLOADED_COUNT+=1
        ) else (
            echo [ERROR] !FILE! FAILED to upload
        )
    ) else (
        echo [SKIP] !FILE! - File not found locally (deleted?)
    )
)

echo.
echo [STEP 4] Setting permissions (755 for directories, 644 for files)...

ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "find %REMOTE_FOLDER% -type d -exec chmod 755 {} \; && find %REMOTE_FOLDER% -type f -exec chmod 644 {} \;" >nul 2>&1

if %errorlevel% equ 0 (
    echo [SUCCESS] Permissions set
) else (
    echo [WARNING] Permission setting had issues
)

echo.
echo [STEP 5] Creating deployment log...

(
    echo {
    echo   "lastDeployment": "%mydate% %mytime%",
    echo   "deployDate": "%mydate%",
    echo   "deployTime": "%mytime%",
    echo   "githubStatus": "%GIT_STATUS%",
    echo   "cpanelStatus": "SUCCESS",
    echo   "filesUploaded": %UPLOADED_COUNT%
    echo }
) > "%LOG_FILE%"

echo [SUCCESS] Log created

echo.
echo ============================================================
echo  DEPLOYMENT COMPLETE at %mytime%
echo ============================================================
echo.
echo Total files uploaded: %UPLOADED_COUNT%
echo GitHub status: %GIT_STATUS%
echo.

:WAIT
echo Type 'x' to close this window:
set /p INPUT=
if /i "%INPUT%"=="x" exit
goto WAIT