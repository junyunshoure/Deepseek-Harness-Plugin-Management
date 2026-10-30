@echo off
chcp 65001 >nul
setlocal
title DeepSeek Harness 插件整合包 v2.1.2 —— 环境体检（找 Desktop / 看插件行 / 查端口）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Action doctor %*
echo.
pause
