@echo off
setlocal
set "HERE=%~dp0"
echo.
echo  DSH-Plugins v2.0.2-patch.1  -  ROLLBACK (restore the newest backup set)
echo  ---------------------------------------------------------------------
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%HERE%apply.ps1" -Rollback %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
