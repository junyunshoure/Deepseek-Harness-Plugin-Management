@echo off
setlocal
cd /d "%~dp0"
echo Dry run only - verifies SHA-256, shows what would change, writes nothing.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply.ps1" -CheckOnly %*
echo.
pause
exit /b 0
