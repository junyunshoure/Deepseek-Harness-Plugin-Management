@echo off
chcp 65001 >nul
setlocal
title DeepSeek Harness 插件整合包 v2.1.0 —— 安装
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Action install %*
echo.
pause
