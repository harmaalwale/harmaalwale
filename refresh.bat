@echo off
REM ============================================================
REM HarmaalWale Refresh.bat - FORCE REFRESH ALL FILES
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
echo FULL REFRESH: %mydate% %mytime%
echo ============================================================
echo.

echo [1] Force push ALL files to GitHub...
git add -A
git commit -m "Force refresh %mydate% %mytime%" 2>nul
git push -f origin main 2>nul
echo [SUCCESS] GitHub synced

echo.
echo [2] Uploading ALL files to cPanel...

REM Upload ALL HTML files
for %%f in (*.html) do (
    echo - %%f
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %%f %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/%%f 2>nul
)

REM Upload ALL API files
for %%f in (api\*.php) do (
    echo - api\%%~nf
    scp -P %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no api\%%~nf %CPANEL_USER%@%CPANEL_HOST%:%REMOTE_FOLDER%/api/%%~nf 2>nul
)

echo [SUCCESS] All files uploaded

echo.
echo [3] Clearing cache...
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "rm -rf %REMOTE_FOLDER%/.cache %REMOTE_FOLDER%/.htaccess.cache 2>/dev/null; cd %REMOTE_FOLDER%; find . -type f -name '*.html' -o -name '*.php' | head -1 | xargs touch 2>/dev/null" 2>nul
echo [SUCCESS] Cache cleared

echo.
echo [4] Setting permissions...
ssh -p %CPANEL_PORT% -i "%SSH_KEY%" -o StrictHostKeyChecking=no %CPANEL_USER%@%CPANEL_HOST% "find %REMOTE_FOLDER% -type d -exec chmod 755 {} \; 2>/dev/null; find %REMOTE_FOLDER% -type f -exec chmod 644 {} \; 2>/dev/null" 2>nul
echo [SUCCESS] Permissions set

echo.
echo ============================================================
echo REFRESH COMPLETE
echo ============================================================
echo.
echo Live: https://harmaalwale.com
echo.

:ASK
set /p INPUT="Type 'x' to close: "
if /i "%INPUT%"=="x" exit
goto ASK