@echo off
echo.
echo This will reset the deployment marker.
echo Next deploy will upload ALL files again.
echo.
set /p CONFIRM="Are you sure? [Y/N]: "
if /i not "%CONFIRM%"=="Y" exit /b 0

if exist ".last_deployed" del ".last_deployed"
echo Done. Marker removed.
echo.
pause
