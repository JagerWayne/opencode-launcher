@echo off
rem Runs run.ps1 (download + launch the OpenCode Launcher menu) from this folder.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run.ps1" %*
