@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -CheckOnly %*
set "migration_result=%errorlevel%"
echo.
pause
exit /b %migration_result%
