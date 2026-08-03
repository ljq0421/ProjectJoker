@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0summarize_steam_demo_playtests.ps1" %*
exit /b %errorlevel%
