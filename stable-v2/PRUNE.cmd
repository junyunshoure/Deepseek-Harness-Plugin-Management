@echo off
chcp 65001 >nul
setlocal
title DeepSeek Harness 插件整合包 v2.1.3 —— 清理旧载荷（保留 7 天 / 仍被引用的不删）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Action prune %*
echo.
pause
