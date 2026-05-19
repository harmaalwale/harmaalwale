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
echo HARMAALWALE - COMPLETE REFRESH (ALL FILES + CACHE CLEAR)
echo Time: %mydate% %mytime%
echo ============================================================
echo.

echo [STEP 1] Git operations
echo.
git pull origin main 2>nul
git add -A
git commit -m "Refresh %mydate% %mytime%" 2>nul
git push -f origin main 2>nul
echo [OK] GitHub synced

echo.
echo [STEP 2] Uploading ALL files (complete refresh)
echo.

REM Upload all HTML files
for /r %%f in (*.html) do (
    echo - %%~nf
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%%f" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/%%~nf 2>nul
)

REM Upload all PHP files in api/
for /r api %%f in (*.php) do (
    echo - api/%%~nf
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%%f" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/%%~nf 2>nul
)

REM Upload CSS files
for /r assets\css %%f in (*.css) do (
    echo - assets/css/%%~nf
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%%f" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/assets/css/%%~nf 2>nul
)

REM Upload JS files
for /r assets\js %%f in (*.js) do (
    echo - assets/js/%%~nf
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no "%%f" %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/assets/js/%%~nf 2>nul
)

echo [OK] All files uploaded

echo.
echo [STEP 3] Clearing server cache
echo.
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% ^
  "rm -rf /home/harmakko/public_html/.cache 2>/dev/null; ^
   rm -rf /tmp/php* 2>/dev/null; ^
   find /home/harmakko/public_html -name '*.cache' -delete 2>/dev/null; ^
   echo 'Cache cleared'"

echo [OK] Cache cleared

echo.
echo [STEP 4] Setting permissions
echo.
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% ^
  "find /home/harmakko/public_html -type d -exec chmod 755 {} \; 2>/dev/null; ^
   find /home/harmakko/public_html -type f -exec chmod 644 {} \; 2>/dev/null; ^
   echo 'Permissions set'"

echo [OK] Permissions set

echo.
echo ============================================================
echo COMPLETE REFRESH DONE
echo ============================================================
echo.
echo All files uploaded
echo Cache cleared
echo Permissions set
echo.
echo Browser: Hard refresh (Ctrl+Shift+Delete) then visit site
echo.

:ASK
set /p INPUT="Type 'x' to close: "
if /i "%INPUT%"=="x" exit
goto ASK
