@echo off
REM ============================================================
REM  HarmaalWale Deploy.bat — Local → GitHub → cPanel
REM  Pushes to GitHub + Shows Status (NO AUTO-CLOSE)
REM ============================================================

setlocal enabledelayedexpansion

REM Get timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)

REM ── CONFIGURATION ──────────────────────────────────────────
set LOCAL_FOLDER=C:\Users\kauti\harmaalwale_v3
set CPANEL_HOST=harmaalwale.com
set CPANEL_USER=harmakko

echo.
echo ============================================================
echo  DEPLOYMENT STARTED: %mydate% at %mytime%
echo ============================================================
echo.

REM ── STEP 1: GIT PUSH ───────────────────────────────────────
echo [STEP 1] Pushing to GitHub...
cd %LOCAL_FOLDER%

git add -A
git commit -m "Auto-deploy %mydate% %mytime%"
git push origin main

if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] ✓ Code pushed to GitHub at %mytime%
    echo.
) else (
    echo.
    echo [ERROR] ✗ Git push failed - check credentials
    echo.
)

REM ── STEP 2: MANUAL CPANEL UPLOAD REMINDER ──────────────────
echo [STEP 2] cPanel Upload Instructions:
echo.
echo 1. Open cPanel File Manager
echo 2. Navigate to: /public_html/api/
echo 3. Upload these files:
echo    - login.html (to /public_html/)
echo    - config.php (to /public_html/api/)
echo    - auth.php (to /public_html/api/)
echo 4. Set permissions: 644 for all files
echo.

REM ── COMPLETION ─────────────────────────────────────────────
echo ============================================================
echo  DEPLOYMENT STATUS: %mydate% %mytime%
echo ============================================================
echo.
echo [✓] GitHub: PUSHED
echo [○] cPanel: UPLOAD MANUALLY (see instructions above)
echo.
echo Press any key to close this window...
pause