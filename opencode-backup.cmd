@echo off
setlocal
set "PS=%~dp0opencode-backup.ps1"

if not exist "%PS%" (
  echo [backup] script not found: %PS%
  exit /b 1
)

if "%~1"==""            goto :backup
if /i "%~1"=="backup"   goto :backup
if /i "%~1"=="list"     goto :list
if /i "%~1"=="restore"  goto :restore
if /i "%~1"=="-h"       goto :help
if /i "%~1"=="--help"   goto :help
if /i "%~1"=="help"     goto :help

echo Unknown option: %~1
goto :help

:backup
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS%" -Backup %2 %3 %4 %5 %6
goto :done

:list
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS%" -List
goto :done

:restore
if "%~2"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PS%" -Restore
  goto :done
)
rem If the next arg starts with "-" it is a flag (e.g. -Password), not a zip path.
echo %~2 | findstr /b /c:"-" >nul
if errorlevel 1 (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PS%" -Restore -Path "%~2" %3 %4 %5 %6 %7
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%PS%" -Restore %2 %3 %4 %5 %6 %7
)
goto :done

:help
echo.
echo   opencode-backup.cmd                   make a timestamped backup
echo   opencode-backup.cmd backup            same as above
echo   opencode-backup.cmd list              list existing backups
echo   opencode-backup.cmd restore           restore the newest backup
echo   opencode-backup.cmd restore ^<zip^>   restore a specific backup
echo   opencode-backup.cmd backup -Password pw     encrypt a new backup
echo   opencode-backup.cmd restore ^<zip^> -Password pw   restore an encrypted backup
echo.

:done
endlocal
