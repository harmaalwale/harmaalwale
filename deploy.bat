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

echo [2] Pushing to GitHub...
git add -A
git commit -m "Deploy %mydate% %mytime%"
if %errorlevel% equ 0 (
    echo [SUCCESS] Commit created
) else (
    echo [INFO] No changes to commit
)

git push origin main
if %errorlevel% equ 0 (
    echo [SUCCESS] Pushed to GitHub
    echo.
    echo [3] GitHub Actions will auto-deploy to cPanel in 30 seconds
    echo.
) else (
    echo [ERROR] Push failed - check GitHub connection
)

echo ============================================================
echo DONE! Changes sync to cPanel automatically
echo ============================================================
echo.

:ASK
set /p INPUT="Type 'x' to close: "
if /i "%INPUT%"=="x" exit
goto ASK