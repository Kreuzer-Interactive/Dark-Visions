@echo off
rem Launch the Dark Visions hit-area web editor (local server + browser).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
echo.
echo Server stopped.
pause
