@echo off
REM ============================================================
REM  HarmaalWale Deploy.bat — Local → GitHub → cPanel
REM ============================================================

setlocal enabledelayedexpansion

REM ── CONFIGURATION ──────────────────────────────────────────
set LOCAL_FOLDER=C:\Users\kauti\harmaalwale_v3
set GITHUB_REPO=https://github.com/your_username/harmaalwale.git
set CPANEL_HOST=harmaalwale.com
set CPANEL_USER=harmakko
set CPANEL_PASS=your_cpanel_password
set REMOTE_PATH=/home/harmakko/public_html

REM ── STEP 1: GIT PUSH ───────────────────────────────────────
echo.
echo ===== STEP 1: Pushing to GitHub =====
cd %LOCAL_FOLDER%
git add -A
git commit -m "Deploy %date% %time%"
git push origin main
if %errorlevel% neq 0 (
    echo ERROR: Git push failed
    pause
    exit /b 1
)
echo SUCCESS: Code pushed to GitHub

REM ── STEP 2: UPLOAD TO CPANEL VIA SFTP ─────────────────────
echo.
echo ===== STEP 2: Uploading to cPanel =====

REM Create SFTP batch file
(
    echo lcd %LOCAL_FOLDER%
    echo open sftp://%CPANEL_USER%:%CPANEL_PASS%@%CPANEL_HOST%:22
    echo cd %REMOTE_PATH%
    echo put login.html login.html
    echo put config.php api/config.php
    echo put api/auth.php api/auth.php
    echo quit
) > sftp_commands.txt

REM Run SFTP (requires WinSCP or similar)
REM Using PuTTY PSCP (if installed)
pscp -P 2222 -pw %CPANEL_PASS% %LOCAL_FOLDER%\login.html %CPANEL_USER%@%CPANEL_HOST%:/home/%CPANEL_USER%/public_html/
pscp -P 2222 -pw %CPANEL_PASS% %LOCAL_FOLDER%\config.php %CPANEL_USER%@%CPANEL_HOST%:/home/%CPANEL_USER%/public_html/api/
pscp -P 2222 -pw %CPANEL_PASS% %LOCAL_FOLDER%\api\auth.php %CPANEL_USER%@%CPANEL_HOST%:/home/%CPANEL_USER%/public_html/api/

echo SUCCESS: Files uploaded to cPanel

REM ── STEP 3: SET PERMISSIONS ───────────────────────────────
echo.
echo ===== STEP 3: Setting Permissions =====
REM