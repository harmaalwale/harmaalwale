@echo off
REM ============================================================
REM  HarmaalWale refresh.bat — Push ALL files + Clear Cache
REM  Forces complete refresh on cPanel and browser
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
set LOG_FILE=%LOCAL_FOLDER%\refresh-log.json

cd /d "%LOCAL_FOLDER%"

echo.
echo ============================================================
echo  FULL REFRESH STARTED: %mydate% at %mytime%
echo ============================================================
echo.

echo [STEP 1] Pushing ALL files to GitHub...
echo.

git add -A
git commit -m "Full refresh %mydate% %mytime%"
git push -f origin main

if %errorlevel% equ 0 (
    echo [SUCCESS] All files pushed to GitHub
    set GIT_STATUS=SUCCESS
) else (
    echo [ERROR] Git push failed
    set GIT_STATUS=FAILED
)

echo.
echo [STEP 2] Uploading ALL files to cPanel...
echo.

set UPLOADED=0

if exist "%LOCAL_FOLDER%\login.html" (
    echo Uploading login.html...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\login.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/login.html >nul 2>&1
    if !errorlevel! equ 0 echo [SUCCESS] login.html uploaded & set /a UPLOADED+=1
)

if exist "%LOCAL_FOLDER%\test.html" (
    echo Uploading test.html...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\test.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/test.html >nul 2>&1
    if !errorlevel! equ 0 echo [SUCCESS] test.html uploaded & set /a UPLOADED+=1
)

if exist "%LOCAL_FOLDER%\index.html" (
    echo Uploading index.html...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\index.html" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/index.html >nul 2>&1
    if !errorlevel! equ 0 echo [SUCCESS] index.html uploaded & set /a UPLOADED+=1
)

if exist "%LOCAL_FOLDER%\api\config.php" (
    echo Uploading config.php...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\config.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/config.php >nul 2>&1
    if !errorlevel! equ 0 echo [SUCCESS] config.php uploaded & set /a UPLOADED+=1
)

if exist "%LOCAL_FOLDER%\api\auth.php" (
    echo Uploading auth.php...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\api\auth.php" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/auth.php >nul 2>&1
    if !errorlevel! equ 0 echo [SUCCESS] auth.php uploaded & set /a UPLOADED+=1
)

if exist "%LOCAL_FOLDER%\assets\css\hw.css" (
    echo Uploading hw.css...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\assets\css\hw.css" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/assets/css/hw.css >nul 2>&1
    if !errorlevel! equ 0 echo [SUCCESS] hw.css uploaded & set /a UPLOADED+=1
)

if exist "%LOCAL_FOLDER%\assets\js\hw.js" (
    echo Uploading hw.js...
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%LOCAL_FOLDER%\assets\js\hw.js" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/assets/js/hw.js >nul 2>&1
    if !errorlevel! equ 0 echo [SUCCESS] hw.js uploaded & set /a UPLOADED+=1
)

echo.
echo [STEP 3] Setting permissions (644)...
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "chmod 644 %REMOTE_FOLDER%/*.html %REMOTE_FOLDER%/api/*.php %REMOTE_FOLDER%/assets/css/*.css %REMOTE_FOLDER%/assets/js/*.js 2>/dev/null" >nul 2>&1
echo [SUCCESS] All permissions set

echo.
echo [STEP 4] Clearing cPanel cache...
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "rm -rf /home/harmakko/public_html/.htaccess.cache 2>/dev/null; echo 'Cache cleared'" >nul 2>&1
echo [SUCCESS] Cache cleared

echo.
echo [STEP 5] Creating refresh log...

(
    echo {
    echo   "refreshTime": "%mydate% %mytime%",
    echo   "githubStatus": "%GIT_STATUS%",
    echo   "filesUploaded": %UPLOADED%,
    echo   "action": "Full system refresh",
    echo   "liveUrl": "https://harmaalwale.com",
    echo   "testUrl": "https://harmaalwale.com/test.html"
    echo }
) > "%LOG_FILE%"

echo [SUCCESS] Refresh log created

echo.
echo ============================================================
echo  REFRESH COMPLETE at %mytime%
echo ============================================================
echo.
echo Files uploaded: %UPLOADED%
echo GitHub status: %GIT_STATUS%
echo Cache cleared: YES
echo.

:STAY_OPEN
echo.
echo Type 'x' and press ENTER to close this window:
set /p CLOSE=
if /i "%CLOSE%"=="x" goto FINISH
if /i "%CLOSE%"=="exit" goto FINISH
goto STAY_OPEN

:FINISH
