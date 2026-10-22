@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "migration_result=%errorlevel%"
echo.
if not "%migration_result%"=="0" echo Installation stopped. See the messages above and README.md.
pause
exit /b %migration_result%
