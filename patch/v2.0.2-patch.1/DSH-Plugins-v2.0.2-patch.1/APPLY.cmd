@echo off
setlocal
chcp 65001 >nul
set "HERE=%~dp0"
echo.
echo  DSH-Plugins v2.0.2-patch.1  -  environment maintenance (CL-001 .. CL-007)
echo  ---------------------------------------------------------------
echo  Writes are backed up. Ctrl+C to abort.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%apply.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (echo  FAILED with exit code %RC%) else (echo  Finished.)
echo.
pause
exit /b %RC%
