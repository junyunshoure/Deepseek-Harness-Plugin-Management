@echo off
chcp 65001 >nul
setlocal
title DeepSeek Harness 插件整合包 v2.1.2 —— 回滚到安装前的状态
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Action rollback %*
echo.
pause
