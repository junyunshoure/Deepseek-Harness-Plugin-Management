@echo off
setlocal
cd /d "%~dp0"
echo ============================================================
echo  DSH-Plugins v2.0.1-patch.1  ::  Alignment Protocol v1.0
echo ============================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0apply.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" goto failed
echo [OK] Protocol block installed. It takes effect in the NEXT DSH session.
pause
exit /b 0
:failed
echo [FAILED] exit code %RC% - read the message above. Nothing was left half-written.
pause
exit /b %RC%
