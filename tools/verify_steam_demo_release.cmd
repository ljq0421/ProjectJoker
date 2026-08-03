@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify_steam_demo_release.ps1" %*
exit /b %errorlevel%
