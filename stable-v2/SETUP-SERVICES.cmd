@echo off
chcp 65001 >nul
setlocal
title DeepSeek Harness 插件整合包 v2.1.0 —— 安装本地记忆服务（ReMe / OpenViking / Hindsight / WeKnora）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Action services %*
echo.
pause
