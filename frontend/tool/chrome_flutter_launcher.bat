@echo off
setlocal

taskkill /F /IM chrome.exe >nul 2>nul
timeout /t 1 /nobreak >nul

"C:\Program Files\Google\Chrome\Application\chrome.exe" --new-window %*
