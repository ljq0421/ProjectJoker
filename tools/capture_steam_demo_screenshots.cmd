@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0capture_steam_demo_screenshots.ps1" %*
exit /b %errorlevel%
