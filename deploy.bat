@echo off
setlocal enabledelayedexpansion

echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║         HarmaalWale - Smart Deploy v3.0                        ║
echo ║         GitHub: harmaalwale/harmaalwale.git                    ║
echo ║         cPanel: harmaalwale.com                                ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

REM Configuration
set GITHUB_REPO=https://github.com/harmaalwale/harmaalwale.git
set SSH_HOST=harmakko@harmaalwale.com
set SSH_PORT=2222
set REMOTE_PATH=/public_html

echo [STEP 1/5] Git Configuration & Sync
echo ════════════════════════════════════════════════════════════════
echo.

REM ============================================================================
REM STEP 1: GIT SETUP AND OPERATIONS
REM ============================================================================

echo Checking Git remote...
git remote -v > git_remote.txt 2>nul

findstr /C:"harmaalwale/harmaalwale" git_remote.txt >nul
if errorlevel 1 (
    echo Setting up GitHub remote...
    git remote remove origin 2>nul
    git remote add origin %GITHUB_REPO%
    echo ✓ Remote set to: %GITHUB_REPO%
) else (
    echo ✓ Remote already configured
)

del git_remote.txt 2>nul

echo.
echo Checking for changes...
git status --porcelain > git_status.txt
for /f %%i in ('type git_status.txt ^| find /c /v ""') do set CHANGES=%%i

if %CHANGES% GTR 0 (
    echo ✓ Found %CHANGES% changed files
    echo.
    type git_status.txt
    echo.
    
    echo Pulling from GitHub (harmaalwale/harmaalwale)...
    git pull origin main 2>nul
    if errorlevel 1 (
        git pull origin master 2>nul
    )
    
    echo Adding all changes...
    git add -A
    
    set /p COMMIT_MSG="Commit message (Enter for auto): "
    if "!COMMIT_MSG!"=="" set COMMIT_MSG=Deploy: %date% %time:~0,5%
    
    echo Committing with message: !COMMIT_MSG!
    git commit -m "!COMMIT_MSG!"
    
    echo Pushing to GitHub (harmaalwale/harmaalwale)...
    git push -u origin main 2>nul
    if errorlevel 1 (
        git push -u origin master 2>nul
    )
    
    if errorlevel 1 (
        echo [ERROR] Git push failed!
        echo Possible reasons:
        echo   - Check your GitHub credentials
        echo   - Verify repository access
        echo   - Check internet connection
        pause
        exit /b 1
    )
    
    echo ✓ GitHub synced
) else (
    echo ℹ No local changes
    echo Pulling latest from GitHub...
    git pull origin main 2>nul
    if errorlevel 1 (
        git pull origin master 2>nul
    )
)

del git_status.txt 2>nul

echo.
echo [STEP 2/5] Scan Local Files
echo ════════════════════════════════════════════════════════════════
echo.

REM ============================================================================
REM STEP 2: CREATE FILE LIST
REM ============================================================================

if exist files_to_upload.txt del files_to_upload.txt

echo Detecting changed files...

REM Get changed files from last commit
git diff --name-only HEAD~1 HEAD > changed_files.txt 2>nul

REM Count changed files
set /a FILE_COUNT=0
for /f "delims=" %%f in (changed_files.txt) do (
    if exist "%%f" (
        echo %%f >> files_to_upload.txt
        set /a FILE_COUNT+=1
        echo   → %%f
    )
)

REM If no git changes, upload critical files
if %FILE_COUNT%==0 (
    echo ℹ No changes in git history
    echo Adding critical files...
    echo index.html >> files_to_upload.txt
    echo support.html >> files_to_upload.txt
    echo coming-soon.html >> files_to_upload.txt
    echo faq.html >> files_to_upload.txt
    echo .htaccess >> files_to_upload.txt
    
    REM Check which files actually exist
    set /a FILE_COUNT=0
    for /f "delims=" %%f in (files_to_upload.txt) do (
        if exist "%%f" (
            set /a FILE_COUNT+=1
        )
    )
)

echo.
echo ✓ Files to upload: %FILE_COUNT%

if %FILE_COUNT%==0 (
    echo ℹ No files to upload
    echo Everything is up to date!
    goto :cleanup
)

echo.
echo [STEP 3/5] Check cPanel
echo ════════════════════════════════════════════════════════════════
echo.

REM ============================================================================
REM STEP 3: VERIFY CPANEL CONNECTION
REM ============================================================================

echo Testing connection to %SSH_HOST%:%SSH_PORT%...
ssh -p %SSH_PORT% -o ConnectTimeout=10 "%SSH_HOST%" "echo Connected" 2>nul

if errorlevel 1 (
    echo [ERROR] Cannot connect to cPanel
    echo.
    echo Please check:
    echo   - SSH host: %SSH_HOST%
    echo   - SSH port: %SSH_PORT%
    echo   - Network connection
    echo   - Firewall settings
    echo.
    pause
    exit /b 1
)

echo ✓ Connected to cPanel

echo.
echo [STEP 4/5] Compare Files
echo ════════════════════════════════════════════════════════════════
echo.

REM ============================================================================
REM STEP 4: CHECK REMOTE FILES
REM ============================================================================

echo Checking remote files...

set /a NEEDS_UPLOAD=0

for /f "delims=" %%f in (files_to_upload.txt) do (
    if exist "%%f" (
        set "file=%%f"
        set "remotefile=!file:\=/!"
        
        REM Check if file exists remotely
        ssh -p %SSH_PORT% "%SSH_HOST%" "test -f %REMOTE_PATH%/!remotefile! && echo EXISTS || echo MISSING" > check_result.txt 2>nul
        
        set /p RESULT=<check_result.txt
        
        if "!RESULT!"=="MISSING" (
            echo   → %%f [NEW]
        ) else (
            echo   → %%f [UPDATE]
        )
        set /a NEEDS_UPLOAD+=1
    )
)

del check_result.txt 2>nul

echo.
echo ✓ Files needing upload: %NEEDS_UPLOAD%

echo.
echo [STEP 5/5] Upload to cPanel
echo ════════════════════════════════════════════════════════════════
echo.

REM ============================================================================
REM STEP 5: UPLOAD FILES
REM ============================================================================

set /a UPLOADED=0
set /a FAILED=0

for /f "delims=" %%f in (files_to_upload.txt) do (
    if exist "%%f" (
        set "file=%%f"
        set "remotefile=!file:\=/!"
        
        echo Uploading: %%f
        
        REM Create directory structure on remote
        for %%d in ("%%~dpf") do (
            set "dir=%%~d"
            set "dir=!dir:\=/!"
            ssh -p %SSH_PORT% "%SSH_HOST%" "mkdir -p %REMOTE_PATH%/!dir!" 2>nul
        )
        
        REM Upload file
        scp -P %SSH_PORT% -q "%%f" "%SSH_HOST%:%REMOTE_PATH%/!remotefile!" 2>nul
        
        if errorlevel 1 (
            echo   ✗ Failed
            set /a FAILED+=1
        ) else (
            echo   ✓ Success
            set /a UPLOADED+=1
        )
    )
)

echo.
echo Setting permissions...
ssh -p %SSH_PORT% "%SSH_HOST%" "cd %REMOTE_PATH% && chmod -R 755 . && find . -type f \( -name '*.html' -o -name '*.php' \) -exec chmod 644 {} \; && chmod 644 .htaccess 2>/dev/null" 2>nul
echo ✓ Permissions set

:summary
echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║                    DEPLOYMENT SUMMARY                          ║
echo ╠════════════════════════════════════════════════════════════════╣
echo ║  GitHub Repo:        harmaalwale/harmaalwale.git              ║
echo ║  Git Status:         Synced ✓                                 ║
echo ║  Files Uploaded:     %UPLOADED%                                           ║
if %FAILED% GTR 0 echo ║  Failed Uploads:     %FAILED%                                           ║
echo ║  cPanel Status:      Synced ✓                                 ║
echo ╠════════════════════════════════════════════════════════════════╣
echo ║  Website:            https://harmaalwale.com                  ║
echo ║  GitHub:             https://github.com/harmaalwale/harmaalwale║
echo ║  Time:               %date% %time:~0,8%                        ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

:cleanup
REM Cleanup temp files
del changed_files.txt 2>nul
del files_to_upload.txt 2>nul

if %FAILED% GTR 0 (
    echo [WARNING] Some uploads failed
    echo Run deploy.bat again to retry
) else if %UPLOADED% GTR 0 (
    echo ✓ Deployment Complete!
) else (
    echo ℹ Everything up to date!
)

echo.
echo Repository: https://github.com/harmaalwale/harmaalwale
echo Website: https://harmaalwale.com
echo.
pause