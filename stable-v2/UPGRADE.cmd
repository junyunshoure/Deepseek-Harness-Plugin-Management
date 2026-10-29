@echo off
chcp 65001 >nul
setlocal
title DeepSeek Harness 插件整合包 v2.1.0 —— 升级（把旧载荷的插件重指向本包）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Action upgrade %*
echo.
pause
