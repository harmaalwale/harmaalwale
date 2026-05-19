@echo off
setlocal enabledelayedexpansion

for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)

set LOCAL_FOLDER=D:\Working Data\harmaalwale_v3
cd /d "%LOCAL_FOLDER%"

cls
echo.
echo ============================================================
echo DEPLOYMENT: %mydate% %mytime%
echo ============================================================
echo.

echo [1] Git Status
git status --short
echo.

echo [2] Pulling latest from GitHub...
git pull origin main
if %errorlevel% equ 0 (
    echo [SUCCESS] Synced with GitHub
) else (
    echo [ERROR] Pull failed
    pause
    exit /b 1
)

echo.
echo [3] Committing local changes...
git add -A
git commit -m "Deploy %mydate% %mytime%"
if %errorlevel% equ 0 (
    echo [SUCCESS] Changes committed
) else (
    echo [INFO] No new changes to commit
)

echo.
echo [4] Pushing to GitHub...
git push origin main
if %errorlevel% equ 0 (
    echo [SUCCESS] Pushed to GitHub
    echo.
    echo [5] GitHub Actions auto-deploying to cPanel...
    echo.
    echo ============================================================
    echo DONE! cPanel will sync in 30-60 seconds
    echo ============================================================
) else (
    echo [ERROR] Push failed
)

echo.

:ASK
set /p INPUT="Type 'x' to close: "
if /i "%INPUT%"=="x" exit
goto ASK