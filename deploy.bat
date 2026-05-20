@echo off
setlocal enabledelayedexpansion
 
echo ╔════════════════════════════════════════════════════════╗
echo ║         HarmaalWale - Complete Deploy v2.0             ║
echo ╚════════════════════════════════════════════════════════╝
echo.
 
set host=harmakko@harmaalwale.com
set port=2222
set remote=/public_html/
 
echo [1/4] Git Operations...
git pull origin main 2>nul
git add -A
git diff --cached --name-only > changed_files.txt
for /f %%i in ('type changed_files.txt ^| find /c /v ""') do set count=%%i
if %count% gtr 0 (
  git commit -m "Deploy: %date% %time%"
  git push origin main
  echo ✓ Pushed %count% files
) else (
  echo ℹ No changes
)
del changed_files.txt
 
echo.
echo [2/4] Scanning ALL changed files...
git diff --name-only HEAD~1 HEAD > deploy_files.txt
set /a file_count=0
for /f "delims=" %%f in (deploy_files.txt) do (
  if exist "%%f" (
    set /a file_count+=1
    echo ├─ Uploading %%f...
    scp -P %port% -q "%%f" "%host%:%remote%%%f" 2>nul && echo │  └─ ✓ || echo │  └─ ✗
  )
)
echo ✓ Uploaded !file_count! files
del deploy_files.txt
 
echo.
echo [3/4] Uploading critical files...
for %%f in (index.html login.html account.html support.html faq.html) do (
  if exist "%%f" (
    scp -P %port% -q "%%f" "%host%:%remote%" 2>nul && echo ├─ ✓ %%f
  )
)
 
echo.
echo [4/4] Setting permissions...
ssh -p %port% "%host%" "chmod -R 755 /public_html; chmod 644 /public_html/*.html" 2>nul && echo ✓ Done
 
echo.
echo ╔════════════════════════════════════════════════════════╗
echo ║              ✓ Deployment Complete!                   ║
echo ╚════════════════════════════════════════════════════════╝
pause