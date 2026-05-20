@echo off
echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║         HarmaalWale - GitHub Setup                             ║
echo ║         Configure Git Repository                               ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

REM Configuration
set GITHUB_REPO=https://github.com/harmaalwale/harmaalwale.git

echo This script will configure your Git repository.
echo Repository: %GITHUB_REPO%
echo.
pause

echo.
echo [STEP 1] Checking Git installation...
git --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git is not installed!
    echo Please install Git from: https://git-scm.com/download/win
    pause
    exit /b 1
)
echo ✓ Git is installed

echo.
echo [STEP 2] Checking current directory...
if not exist "index.html" (
    echo [ERROR] Not in correct directory!
    echo Please run this from: D:\Working Data\harmaalwale_v3\
    pause
    exit /b 1
)
echo ✓ Correct directory

echo.
echo [STEP 3] Git configuration...

REM Set user name and email
set /p GIT_NAME="Enter your name (for commits): "
set /p GIT_EMAIL="Enter your email (for commits): "

git config --global user.name "%GIT_NAME%"
git config --global user.email "%GIT_EMAIL%"

echo ✓ Git user configured

echo.
echo [STEP 4] Repository setup...

REM Check if .git exists
if not exist ".git" (
    echo Initializing Git repository...
    git init
    echo ✓ Repository initialized
) else (
    echo ℹ Repository already initialized
)

REM Remove existing remote if any
git remote remove origin 2>nul

REM Add new remote
echo Adding GitHub remote...
git remote add origin %GITHUB_REPO%
echo ✓ Remote added: %GITHUB_REPO%

echo.
echo [STEP 5] Initial commit and push...

REM Create .gitignore if doesn't exist
if not exist ".gitignore" (
    echo node_modules/ > .gitignore
    echo .env >> .gitignore
    echo *.log >> .gitignore
    echo .DS_Store >> .gitignore
    echo Thumbs.db >> .gitignore
    echo ✓ Created .gitignore
)

echo Adding all files...
git add -A

echo Creating initial commit...
git commit -m "Initial commit: HarmaalWale website" 2>nul
if errorlevel 1 (
    echo ℹ Repository already has commits
)

echo.
echo Pushing to GitHub...
echo This may ask for your GitHub credentials.
echo.

git branch -M main
git push -u origin main 2>nul
if errorlevel 1 (
    echo.
    echo [ERROR] Push failed!
    echo.
    echo Possible reasons:
    echo 1. You need to authenticate with GitHub
    echo 2. Repository doesn't exist on GitHub
    echo 3. You don't have access to the repository
    echo.
    echo To fix:
    echo 1. Go to: https://github.com/harmaalwale/harmaalwale
    echo 2. Make sure repository exists
    echo 3. Add your GitHub account to the repository
    echo 4. Run this script again
    echo.
    pause
    exit /b 1
)

echo.
echo ╔════════════════════════════════════════════════════════════════╗
echo ║                    SETUP COMPLETE!                             ║
echo ╠════════════════════════════════════════════════════════════════╣
echo ║  Git User:           %GIT_NAME%                                ║
echo ║  Git Email:          %GIT_EMAIL%                               ║
echo ║  Repository:         harmaalwale/harmaalwale.git              ║
echo ║  Branch:             main                                     ║
echo ╠════════════════════════════════════════════════════════════════╣
echo ║  Next Steps:                                                  ║
echo ║  1. Make changes to your files                                ║
echo ║  2. Run deploy.bat                                            ║
echo ║  3. Changes will sync to GitHub and cPanel                    ║
echo ╚════════════════════════════════════════════════════════════════╝
echo.

echo Repository URL: https://github.com/harmaalwale/harmaalwale
echo.
pause
