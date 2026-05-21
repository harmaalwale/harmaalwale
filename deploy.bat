@echo off
setlocal enabledelayedexpansion
title HarmaalWale Deployment

REM Prevent editor popups during git operations
set "GIT_MERGE_AUTOEDIT=no"

REM ============================================================
REM CONFIGURATION
REM ============================================================
set "GITHUB_REPO=https://github.com/harmaalwale/harmaalwale.git"
set "GITHUB_BRANCH=main"
set "SSH_HOST=harmakko@harmaalwale.com"
set "SSH_PORT=2222"
set "REMOTE_PATH=/public_html"
set "DEPLOY_MARKER=.last_deployed"

REM Counters
set /a UPLOADED=0
set /a DELETED=0
set /a FAILED=0
set /a NEW_COUNT=0
set /a MOD_COUNT=0
set /a DEL_COUNT=0

cls
echo.
echo =================================================================
echo            HARMAALWALE DEPLOYMENT v5.0
echo =================================================================
echo  Repo:    harmaalwale/harmaalwale
echo  Branch:  %GITHUB_BRANCH%
echo  Server:  %SSH_HOST%:%SSH_PORT%
echo  Path:    %REMOTE_PATH%
echo =================================================================
echo.

REM ============================================================
REM [1/7] VERIFY ENVIRONMENT
REM ============================================================
echo [1/7] Verifying environment...

where git >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] Git not installed
    echo   Install from: https://git-scm.com/download/win
    goto :END
)

where ssh >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] SSH not found
    echo   Enable OpenSSH Client in Windows Optional Features
    goto :END
)

where scp >nul 2>&1
if errorlevel 1 (
    echo   [ERROR] SCP not found
    goto :END
)

if not exist ".git" (
    echo   [ERROR] Not a Git repository
    echo   Run: git init
    goto :END
)

echo   [OK] All tools present
echo.

REM ============================================================
REM [2/7] CONFIGURE GITHUB REMOTE
REM ============================================================
echo [2/7] Configuring GitHub remote...

git remote get-url origin >nul 2>&1
if errorlevel 1 (
    git remote add origin "%GITHUB_REPO%"
) else (
    git remote set-url origin "%GITHUB_REPO%"
)
echo   [OK] Remote: %GITHUB_REPO%
echo.

REM ============================================================
REM [3/7] SCAN LOCAL CHANGES
REM ============================================================
echo [3/7] Scanning local changes...
echo.

git status --porcelain > "%TEMP%\hw_status.txt"

set "HAS_CHANGES=0"
for /f "usebackq tokens=*" %%a in ("%TEMP%\hw_status.txt") do (
    set "HAS_CHANGES=1"
    set "LINE=%%a"
    set "CODE=!LINE:~0,2!"
    set "FILEPATH=!LINE:~3!"
    
    if "!CODE!"=="??" (
        echo   [NEW] !FILEPATH!
        set /a NEW_COUNT+=1
    ) else if "!CODE:~0,1!"=="A" (
        echo   [ADD] !FILEPATH!
        set /a NEW_COUNT+=1
    ) else if "!CODE:~0,1!"=="D" (
        echo   [DEL] !FILEPATH!
        set /a DEL_COUNT+=1
    ) else if "!CODE:~1,1!"=="D" (
        echo   [DEL] !FILEPATH!
        set /a DEL_COUNT+=1
    ) else (
        echo   [MOD] !FILEPATH!
        set /a MOD_COUNT+=1
    )
)

if "!HAS_CHANGES!"=="1" (
    echo.
    echo   Total: !NEW_COUNT! new, !MOD_COUNT! modified, !DEL_COUNT! deleted
) else (
    echo   No local changes detected
)
echo.

REM ============================================================
REM [4/7] COMMIT CHANGES
REM ============================================================
echo [4/7] Committing changes...

if "!HAS_CHANGES!"=="0" (
    echo   [SKIP] Nothing to commit
    echo.
    goto :PUSH
)

set "COMMIT_MSG="
set /p "COMMIT_MSG=Commit message (Enter for auto): "
if "!COMMIT_MSG!"=="" set "COMMIT_MSG=Deploy: %date% %time:~0,5%"

git add -A
git commit -m "!COMMIT_MSG!" >nul 2>&1
if errorlevel 1 (
    echo   [INFO] Nothing new to commit
) else (
    echo   [OK] Committed: !COMMIT_MSG!
)
echo.

:PUSH
REM ============================================================
REM [5/7] PUSH TO GITHUB
REM ============================================================
echo [5/7] Syncing with GitHub...

echo   Pulling latest...
git pull origin %GITHUB_BRANCH% --no-rebase --no-edit >nul 2>&1

echo   Pushing to %GITHUB_BRANCH%...
git push origin %GITHUB_BRANCH% 2>nul
if errorlevel 1 (
    git push -u origin %GITHUB_BRANCH%
    if errorlevel 1 (
        echo   [WARN] GitHub push failed
        echo.
        set "CONTINUE="
        set /p "CONTINUE=Continue with cPanel sync anyway? [Y/N]: "
        if /i not "!CONTINUE!"=="Y" goto :END
    ) else (
        echo   [OK] Pushed to GitHub
    )
) else (
    echo   [OK] Pushed to GitHub
)
echo.

REM ============================================================
REM [6/7] TEST CPANEL CONNECTION
REM ============================================================
echo [6/7] Testing cPanel connection...

ssh -p %SSH_PORT% -o ConnectTimeout=15 -o BatchMode=no "%SSH_HOST%" "echo HW_CONNECTED" > "%TEMP%\hw_test.txt" 2>&1
findstr /C:"HW_CONNECTED" "%TEMP%\hw_test.txt" >nul
if errorlevel 1 (
    echo   [ERROR] Cannot connect to cPanel
    type "%TEMP%\hw_test.txt"
    del "%TEMP%\hw_test.txt" 2>nul
    goto :END
)
del "%TEMP%\hw_test.txt" 2>nul
echo   [OK] Connected to %SSH_HOST%
echo.

REM ============================================================
REM [7/7] SYNC FILES TO CPANEL
REM ============================================================
echo [7/7] Syncing files to cPanel...
echo.

REM Get current commit hash
for /f "delims=" %%h in ('git rev-parse HEAD') do set "CURRENT_COMMIT=%%h"

REM Get last deployed commit
set "LAST_COMMIT="
if exist "%DEPLOY_MARKER%" set /p LAST_COMMIT=<"%DEPLOY_MARKER%"

REM Build upload and delete lists
set "UPLOAD_LIST=%TEMP%\hw_upload.txt"
set "DELETE_LIST=%TEMP%\hw_delete.txt"

if "!LAST_COMMIT!"=="" (
    echo   First deployment - uploading all tracked files
    git ls-files > "%UPLOAD_LIST%"
    type nul > "%DELETE_LIST%"
) else (
    echo   Comparing against last deploy: !LAST_COMMIT:~0,8!
    git diff --name-only --diff-filter=ACMR !LAST_COMMIT! HEAD > "%UPLOAD_LIST%"
    git diff --name-only --diff-filter=D !LAST_COMMIT! HEAD > "%DELETE_LIST%"
)

REM Count files
set /a UP_COUNT=0
set /a DEL_COUNT2=0
for /f %%i in ('type "%UPLOAD_LIST%" ^| find /c /v ""') do set /a UP_COUNT=%%i
for /f %%i in ('type "%DELETE_LIST%" ^| find /c /v ""') do set /a DEL_COUNT2=%%i

if !UP_COUNT! EQU 0 if !DEL_COUNT2! EQU 0 (
    echo   Server is already up to date
    echo.
    goto :SUMMARY
)

echo   To upload: !UP_COUNT! file(s)
echo   To delete: !DEL_COUNT2! file(s)
echo.

REM ----- BATCH CREATE REMOTE DIRECTORIES -----
if !UP_COUNT! GTR 0 (
    echo   Creating remote directories...
    
    > "%TEMP%\hw_dirs.txt" (
        for /f "usebackq tokens=*" %%f in ("%UPLOAD_LIST%") do (
            set "FP=%%f"
            set "FP=!FP:/=\!"
            for %%a in ("!FP!") do (
                set "DIR=%%~dpa"
                set "DIR=!DIR:%CD%\=!"
                set "DIR=!DIR:%CD%=!"
                set "DIR=!DIR:\=/!"
                if not "!DIR!"=="" if not "!DIR!"=="/" echo !DIR!
            )
        )
    )
    
    REM Dedupe
    if exist "%TEMP%\hw_dirs.txt" (
        sort "%TEMP%\hw_dirs.txt" /unique /o "%TEMP%\hw_dirs_u.txt" 2>nul
        if not exist "%TEMP%\hw_dirs_u.txt" copy "%TEMP%\hw_dirs.txt" "%TEMP%\hw_dirs_u.txt" >nul
        
        REM Build single mkdir command
        set "MK_CMD=cd %REMOTE_PATH%"
        for /f "usebackq tokens=*" %%d in ("%TEMP%\hw_dirs_u.txt") do (
            set "MK_CMD=!MK_CMD! && mkdir -p '.%%d'"
        )
        
        if not "!MK_CMD!"=="cd %REMOTE_PATH%" (
            ssh -p %SSH_PORT% "%SSH_HOST%" "!MK_CMD!" >nul 2>&1
        )
    )
    
    echo   [OK] Directories ready
    echo.
)

REM ----- UPLOAD FILES -----
if !UP_COUNT! GTR 0 (
    echo   --- UPLOADING ---
    for /f "usebackq tokens=*" %%f in ("%UPLOAD_LIST%") do (
        if exist "%%f" (
            set "F=%%f"
            set "RF=!F:\=/!"
            
            scp -P %SSH_PORT% -q "%%f" "%SSH_HOST%:%REMOTE_PATH%/!RF!" >nul 2>&1
            if errorlevel 1 (
                echo   [FAIL] %%f
                set /a FAILED+=1
            ) else (
                echo   [OK]   %%f
                set /a UPLOADED+=1
            )
        ) else (
            echo   [SKIP] %%f (not found locally)
        )
    )
    echo.
)

REM ----- DELETE FILES -----
if !DEL_COUNT2! GTR 0 (
    echo   --- DELETING ---
    for /f "usebackq tokens=*" %%f in ("%DELETE_LIST%") do (
        set "F=%%f"
        set "RF=!F:\=/!"
        
        ssh -p %SSH_PORT% "%SSH_HOST%" "rm -f '%REMOTE_PATH%/!RF!'" >nul 2>&1
        if errorlevel 1 (
            echo   [FAIL] %%f
            set /a FAILED+=1
        ) else (
            echo   [OK]   %%f (removed)
            set /a DELETED+=1
        )
    )
    echo.
)

REM ----- SET PERMISSIONS -----
echo   Setting file permissions...
ssh -p %SSH_PORT% "%SSH_HOST%" "cd %REMOTE_PATH% && find . -type d -exec chmod 755 {} + 2>/dev/null; find . -type f -exec chmod 644 {} + 2>/dev/null" >nul 2>&1
echo   [OK] Permissions: 755 dirs, 644 files

REM ----- SAVE DEPLOY MARKER -----
echo !CURRENT_COMMIT!>"%DEPLOY_MARKER%"

REM Ensure marker is gitignored
if exist ".gitignore" (
    findstr /C:"%DEPLOY_MARKER%" .gitignore >nul 2>&1
    if errorlevel 1 echo %DEPLOY_MARKER%>>.gitignore
) else (
    echo %DEPLOY_MARKER%>.gitignore
)

:SUMMARY
echo.
echo =================================================================
echo                       DEPLOYMENT SUMMARY
echo =================================================================
echo  GitHub:     synced (branch: %GITHUB_BRANCH%)
echo  Uploaded:   !UPLOADED! file(s)
echo  Deleted:    !DELETED! file(s)
if !FAILED! GTR 0 (
    echo  Failed:     !FAILED! operation(s)
)
echo.
echo  Website:    https://harmaalwale.com
echo  GitHub:     https://github.com/harmaalwale/harmaalwale
echo  Time:       %date% %time:~0,8%
echo =================================================================

if !FAILED! GTR 0 (
    echo.
    echo  [WARNING] Some operations failed. Re-run to retry.
) else if !UPLOADED! GTR 0 (
    echo.
    echo  [SUCCESS] Deployment complete!
) else if !DELETED! GTR 0 (
    echo.
    echo  [SUCCESS] Cleanup complete!
) else (
    echo.
    echo  [INFO] Everything was already up to date
)

REM Cleanup temp files
del "%TEMP%\hw_status.txt" 2>nul
del "%TEMP%\hw_upload.txt" 2>nul
del "%TEMP%\hw_delete.txt" 2>nul
del "%TEMP%\hw_dirs.txt" 2>nul
del "%TEMP%\hw_dirs_u.txt" 2>nul

:END
echo.
echo Press any key to close...
pause >nul
endlocal
exit /b 0
