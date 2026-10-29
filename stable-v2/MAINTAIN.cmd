@echo off
chcp 65001 >nul
setlocal
title DeepSeek Harness 插件整合包 v2.1.0 —— 环境维护（对齐协议 / 日志轮转 / 残留清理 / 环境变量）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Action maintain %*
echo.
pause
