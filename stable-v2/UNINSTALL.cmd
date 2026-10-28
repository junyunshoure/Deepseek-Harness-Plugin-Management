@echo off
chcp 65001 >nul
setlocal
title DeepSeek Harness 插件整合包 v2.0.0 —— 卸载整合包插件（保留你自己的其它插件）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Action uninstall %*
echo.
pause
