@echo off
REM ============================================================
REM  HarmaalWale Deploy.bat — COMPLETE DIRECTORY SCAN
REM  Uploads ALL changed files (entire directory tree)
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

echo [STEP 1] Detecting ALL changed files...
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
    echo [SUCCESS] All files pushed to GitHub
    set GIT_STATUS=SUCCESS
    set GIT_TIME=%mytime%
) else (
    echo [ERROR] Git push failed
    set GIT_STATUS=FAILED
    set GIT_TIME=%mytime%
)

echo.
echo [STEP 3] Uploading ALL changed files to cPanel...
echo.

set CPANEL_STATUS=SUCCESS
set CPANEL_TIME=%mytime%
set UPLOADED_COUNT=0

REM Read each changed file and upload
for /f "tokens=2*" %%A in ('type "%TEMP%\changed_files.txt"') do (
    set FILE=%%B
    set FILE=!FILE:/=\!
    
    if exist "!FILE!" (
        echo Uploading: !FILE!...
        scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "!FILE!" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/!FILE! >nul 2>&1
        if !errorlevel! equ 0 (
            echo [SUCCESS] !FILE! uploaded
            set /a UPLOADED_COUNT+=1
        ) else (
            echo [ERROR] !FILE! FAILED to upload
        )
    )
)

echo.
echo [STEP 4] Setting permissions (644) for all files...

ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "find %REMOTE_FOLDER% -type f \( -name '*.html' -o -name '*.php' -o -name '*.css' -o -name '*.js' -o -name '*.json' \) -exec chmod 644 {} \;" >nul 2>&1

if %errorlevel% equ 0 (
    echo [SUCCESS] Permissions set on all files
) else (
    echo [WARNING] Permission setting had issues (may be normal)
)

echo.
echo [STEP 5] Creating deployment log...

(
    echo {
    echo   "lastDeployment": "%mydate% %mytime%",
    echo   "githubStatus": "%GIT_STATUS%",
    echo   "cpanelStatus": "%CPANEL_STATUS%",
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
echo cPanel status: %CPANEL_STATUS%
echo.

:KEEP_OPEN
echo.
echo Type 'x' and press ENTER to close this window:
set /p CLOSE=
if /i "%CLOSE%"=="x" goto END
if /i "%CLOSE%"=="exit" goto END
goto KEEP_OPEN

:END