@echo off
setlocal enabledelayedexpansion
 
echo ╔════════════════════════════════════════════════════════╗
echo ║         HarmaalWale - Force Refresh v2.0               ║
echo ╚════════════════════════════════════════════════════════╝
echo.
 
set host=harmakko@harmaalwale.com
set port=2222
set remote=/public_html/
 
echo [1/4] Uploading ALL HTML files...
set /a html_count=0
for /r . %%f in (*.html) do (
  set "filepath=%%f"
  set "filepath=!filepath:%CD%\=!"
  if not "!filepath!"=="node_modules*" (
    set /a html_count+=1
    scp -P %port% -q "%%f" "%host%:%remote%!filepath!" 2>nul && echo ├─ !filepath!
  )
)
echo ✓ Uploaded !html_count! HTML files
 
echo.
echo [2/4] Uploading ALL PHP files...
set /a php_count=0
for /r api %%f in (*.php) do (
  set /a php_count+=1
  scp -P %port% -q "%%f" "%host%:%remote%api/" 2>nul && echo ├─ %%~nxf
)
echo ✓ Uploaded !php_count! PHP files
 
echo.
echo [3/4] Uploading assets...
xcopy /E /I /Y assets temp_assets >nul
scp -P %port% -rq temp_assets/* "%host%:%remote%assets/" 2>nul && echo ✓ Assets synced
rmdir /S /Q temp_assets
 
echo.
echo [4/4] Clearing cache + permissions...
ssh -p %port% "%host%" "find /public_html -name '.cache' -delete; chmod -R 755 /public_html; chmod 644 /public_html/*.html /public_html/*.php" 2>nul && echo ✓ Done
 
echo.
echo ╔════════════════════════════════════════════════════════╗
echo ║            ✓ Refresh Complete!                         ║
echo ╚════════════════════════════════════════════════════════╝
pause