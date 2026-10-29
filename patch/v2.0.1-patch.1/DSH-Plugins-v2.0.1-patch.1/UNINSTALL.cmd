@echo off
setlocal
cd /d "%~dp0"
echo Removes ONLY the ALIGNMENT_PROTOCOL v1.0 block. Other AGENTS.md content stays.
echo A backup is written before the edit.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply.ps1" -Uninstall %*
echo.
pause
exit /b 0
