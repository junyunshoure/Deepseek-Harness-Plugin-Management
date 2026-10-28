@echo off
chcp 65001 >nul
setlocal
title DeepSeek Harness 插件整合包 v2.0.0 —— 只校验包完整性
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Action verify %*
echo.
pause
