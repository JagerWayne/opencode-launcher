@echo off
setlocal EnableExtensions
title OpenCode Launcher

rem ---------------------------------------------------------------------------
rem  OpenCode Launcher
rem  Version 1.0  -  By Wayne Scicluna
rem  A small selector for common OpenCode actions.
rem  Setting is remembered in opencode-launcher.cfg next to this script.
rem  If winget is unavailable, install-node.ps1 (beside this script) is used to
rem  fetch Node.js LTS directly.
rem ---------------------------------------------------------------------------

set "cfg=%~dp0opencode-launcher.cfg"
set "psfallback=%~dp0install-node.ps1"

rem Default: do not auto-check. Load override from config file if present.
set "autocheck=0"
if exist "%cfg%" (
    for /f "usebackq tokens=1,2 delims==" %%a in ("%cfg%") do (
        if /i "%%a"=="autocheck" set "autocheck=%%b"
    )
)

:menu
cls
call :detect
set "acstate=OFF"
if "%autocheck%"=="1" set "acstate=ON"
if "%hasopencode%"=="1" (set "ocstat=installed") else (set "ocstat=NOT installed")
if "%hasnpm%"=="1" (set "npmstat=found") else (set "npmstat=missing")

echo ==========================================
echo             OpenCode Launcher
echo          Version 1.0  -  By Wayne Scicluna
echo ==========================================
echo.
echo    OpenCode: %ocstat%    Node/npm: %npmstat%
echo.
echo    [R]  Run OpenCode (current folder)
echo    [C]  Continue last session  (--continue)
echo    [D]  Run in a specific folder...
echo    [S]  Launch v2 web / server   (opencode serve)
echo    [U]  Update OpenCode
echo    [T]  Check for updates before each run:  %acstate%
echo    [I]  Install / repair OpenCode  (installs Node.js if needed)
echo    [O]  Set up the "oc" command shortcut
echo    [X]  Uninstall OpenCode
echo    [Q]  Quit
echo.
choice /c RCDSUTIOXQ /n /m " Select an option [R, C, D, S, U, T, I, O, X, Q]: "
if errorlevel 10 goto :quit
if errorlevel 9 goto :uninstall
if errorlevel 8 goto :setupoc
if errorlevel 7 goto :install
if errorlevel 6 goto :toggle
if errorlevel 5 goto :update
if errorlevel 4 goto :serve
if errorlevel 3 goto :dir
if errorlevel 2 goto :cont
if errorlevel 1 goto :run
goto :menu

:run
call :needoc
call :prerun
cls
call opencode
goto :menu

:cont
call :needoc
call :prerun
cls
call opencode --continue
goto :menu

:dir
cls
echo ==========================================
echo         Run in a specific folder
echo ==========================================
echo.
echo Enter a folder path (you can also drag a folder
echo onto this window), or press Enter to cancel.
echo.
set "target="
set /p "target= Folder: "
rem Strip surrounding quotes from drag-and-drop.
set "target=%target:"=%"
if "%target%"=="" goto :menu
if not exist "%target%\" if not exist "%target%" (
    echo.
    echo   Folder not found: %target%
    echo.
    pause
    goto :menu
)
call :needoc
call :prerun
cls
call opencode "%target%"
goto :menu

:serve
call :needoc
cls
echo ==========================================
echo           OpenCode v2 web / server
echo ==========================================
echo.
echo Starting the server in a separate window.
echo Look there for the URL to open in your browser.
echo Close that window (or press Ctrl+C in it) to stop.
echo.
start "OpenCode v2 Server" cmd /k opencode serve
goto :menu

:toggle
set "newval=1"
if "%autocheck%"=="1" set "newval=0"
set "autocheck=%newval%"
> "%cfg%" echo autocheck=%autocheck%
goto :menu

:update
call :needoc
cls
echo ==========================================
echo             Updating OpenCode
echo ==========================================
echo.
call opencode upgrade
echo.
echo Done. Press any key to return to the menu.
pause >nul
goto :menu

:install
cls
echo ==========================================
echo        Install / Repair OpenCode
echo ==========================================
echo.
call :detect
if "%hasnpm%"=="0" (
    echo npm was not found. Node.js is required and will be installed first.
    echo.
    call :installnode
    call :detect
    if "%hasnpm%"=="0" (
        echo.
        echo   Node.js / npm could not be installed automatically.
        echo   Install it manually from https://nodejs.org/ and run this again.
        echo.
        pause
        goto :menu
    )
)
if "%hasopencode%"=="1" echo OpenCode is already installed - reinstalling / repairing.
echo Installing OpenCode via npm ...
echo.
call npm install -g @opencode/cli
echo.
echo Done. Press any key to return to the menu.
pause >nul
goto :menu

:setupoc
cls
echo ==========================================
echo          Set up the "oc" command
echo ==========================================
echo.
echo This creates an "oc" shortcut so typing "oc" in any
echo command window opens this launcher.
echo.

rem Prefer a folder that is already on the PATH; otherwise use this folder.
set "targetdir=%USERPROFILE%\.local\bin"
if not exist "%targetdir%\" set "targetdir=%~dp0"
if "%targetdir:~-1%"=="\" set "targetdir=%targetdir:~0,-1%"
set "shim=%targetdir%\oc.cmd"

if exist "%shim%" (
    echo An "oc.cmd" already exists at:
    echo   %shim%
    choice /c YN /n /m " Overwrite it? [Y, N]: "
    set "ans=%errorlevel%"
    if not "%ans%"=="1" goto :menu
)

> "%shim%" (
    echo @echo off
    echo rem Launches the OpenCode Launcher menu. Created by opencode-launcher.cmd.
    echo call "%~dp0opencode-launcher.cmd" %%*
)
echo.
echo Created: %shim%
echo.

rem Make sure the shim's folder is on the user PATH.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$d='%targetdir%'; $p=[Environment]::GetEnvironmentVariable('Path','User'); if(-not $p){$p=''}; $a=$p.Split(';'); if($a -notcontains $d){ [Environment]::SetEnvironmentVariable('Path',($p.TrimEnd(';')+';'+$d),'User'); Write-Host 'Added to your user PATH (works in new command windows).' } else { Write-Host 'Folder is already on PATH.' }"

echo.
echo Type  oc  in a command window to launch this menu.
echo.
pause
goto :menu

:uninstall
cls
echo ==========================================
echo            Uninstall OpenCode
echo ==========================================
echo.
call :detect
if "%hasopencode%"=="0" if "%hasnpm%"=="0" (
    echo OpenCode does not appear to be installed.
    echo.
    pause
    goto :menu
)
echo This removes OpenCode but keeps your sessions, configuration and state.
echo.
choice /c YN /n /m " Proceed with uninstall? [Y, N]: "
set "ans=%errorlevel%"
if not "%ans%"=="1" goto :menu
echo.
if "%hasopencode%"=="1" (
    call opencode uninstall --force
) else (
    echo Removing npm package @opencode/cli ...
    call npm uninstall -g @opencode/cli
)
echo.
echo Done. Press any key to return to the menu.
pause >nul
goto :menu

rem ---------------------------------------------------------------------------
rem  Helpers
rem ---------------------------------------------------------------------------

:detect
set "hasopencode=0"
set "hasnpm=0"
where opencode >nul 2>&1 && set "hasopencode=1"
where npm      >nul 2>&1 && set "hasnpm=1"
goto :eof

:needoc
if not "%hasopencode%"=="1" (
    echo.
    echo   OpenCode is not installed yet. Choose [I] Install first.
    echo.
    pause
    goto :menu
)
goto :eof

:installnode
echo Attempting to install Node.js LTS ...
echo.
where winget >nul 2>&1
if not errorlevel 1 (
    echo Using winget ...
    winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
    rem winget installs to Program Files\nodejs; make it visible in this session.
    set "PATH=%ProgramFiles%\nodejs;%PATH%"
    goto :eof
)
if exist "%psfallback%" (
    echo winget not found - downloading Node.js directly ...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%psfallback%"
    set "PATH=%ProgramFiles%\nodejs;%PATH%"
    goto :eof
)
echo   winget was not found and install-node.ps1 is missing.
echo   Please install Node.js manually from https://nodejs.org/
goto :eof

:prerun
if not "%autocheck%"=="1" goto :eof
call :checkupdate
goto :eof

:checkupdate
echo Checking for updates...
set "cur="
for /f "tokens=2" %%v in ('opencode --version 2^>nul') do set "cur=%%v"
if defined cur set "cur=%cur:v=%"
set "latest="
for /f "delims=" %%v in ('npm view @opencode/cli version 2^>nul') do set "latest=%%v"
if not defined latest (
    echo Could not reach the update service; skipping check.
    echo.
    goto :eof
)
if not defined cur (
    echo Could not read the installed version; skipping check.
    echo.
    goto :eof
)
if /i "%cur%"=="%latest%" (
    echo You are up to date ^(v%cur%^).
    echo.
    goto :eof
)
echo A newer OpenCode is available: v%cur%  -^>  v%latest%
choice /c YN /n /m " Update now before running? [Y, N]: "
set "ans=%errorlevel%"
if not "%ans%"=="1" goto :eof
call opencode upgrade
echo.
goto :eof

:quit
endlocal
exit /b 0
