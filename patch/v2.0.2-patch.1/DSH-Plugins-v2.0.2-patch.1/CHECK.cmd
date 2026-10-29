@echo off
setlocal
set "HERE=%~dp0"
echo.
echo  DSH-Plugins v2.0.2-patch.1  -  CHECK ONLY (nothing is written)
echo  ---------------------------------------------------------------
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%apply.ps1" -CheckOnly %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
