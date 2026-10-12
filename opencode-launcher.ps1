#requires -Version 5.1
<#
  opencode-launcher.ps1 - OpenCode Launcher v2.

  A coloured, keypress-driven menu for common opencode actions:
  run, resume, run-in-folder, web server, update, install/repair, uninstall,
  and backup / restore.

  Entry point: the "oc" shim (oc.cmd on your PATH, created by option [O]),
  or run this file directly:
      powershell -NoProfile -ExecutionPolicy Bypass -File opencode-launcher.ps1
#>

param([switch]$NoMenu)

$ErrorActionPreference = "Continue"
try { $Host.UI.RawUI.WindowTitle = "OpenCode Launcher" } catch {}

$LauncherVersion = "2.0"

# ----- locations -------------------------------------------------------------

$LauncherDir = $PSScriptRoot
if (-not $LauncherDir) { $LauncherDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

$NodeScript   = Join-Path $LauncherDir "install-node.ps1"
$BackupScript = Join-Path $LauncherDir "opencode-backup.ps1"
$ShimDir      = Join-Path $env:USERPROFILE ".local\bin"
$ShimPath     = Join-Path $ShimDir "oc.cmd"
$OpenCodePkg  = "@opencode/cli"

# ----- colours / theme -------------------------------------------------------

$C_Section = "DarkGray"
$C_Key     = "Yellow"
$C_Label   = "White"
$C_Hint    = "DarkGray"
$C_Good    = "Green"
$C_Bad     = "Red"
$C_Warn    = "Yellow"
$C_Back    = "DarkGray"

# ----- helpers ---------------------------------------------------------------

function Read-MenuKey {
  $k = [Console]::ReadKey($true)
  if ($k.Key -eq [ConsoleKey]::Escape) { return "ESC" }
  return ([string]$k.KeyChar).ToUpper()
}

function Pause-Menu {
  Write-Host ""
  Write-Host "  Press any key to return to the menu..." -ForegroundColor $C_Hint
  [void][Console]::ReadKey($true)
}

function Test-Command {
  param([string]$Name)
  return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-Status {
  $hasOC  = Test-Command "opencode"
  $ocVer  = ""
  if ($hasOC) { try { $ocVer = ((& opencode --version 2>$null) | Select-Object -First 1) } catch {} }
  $hasNpm = Test-Command "npm"
  $node   = ""
  if (Test-Command "node") { try { $node = (& node --version 2>$null) } catch {} }
  return [pscustomobject]@{ HasOC = $hasOC; OCVer = $ocVer; HasNpm = $hasNpm; Node = $node }
}
$script:Status = Get-Status
function Refresh-Status { $script:Status = Get-Status }

# ----- drawing ---------------------------------------------------------------

function Write-Title {
  param([string]$Title)
  $bar = "   " + $Title
  $ver = "v$LauncherVersion"
  $pad = 60 - $bar.Length - $ver.Length
  if ($pad -lt 1) { $pad = 1 }
  Write-Host ""
  Write-Host ($bar + (" " * $pad) + $ver + " ") -BackgroundColor DarkCyan -ForegroundColor White
  Write-Host ""
}

function Write-StatusLine {
  Write-Host "   OpenCode " -NoNewline -ForegroundColor $C_Hint
  if ($script:Status.HasOC) {
    Write-Host $script:Status.OCVer -NoNewline -ForegroundColor $C_Good
  } else {
    Write-Host "not installed" -NoNewline -ForegroundColor $C_Bad
  }
  Write-Host "     Node " -NoNewline -ForegroundColor $C_Hint
  if ($script:Status.HasNpm) {
    Write-Host $script:Status.Node -NoNewline -ForegroundColor $C_Good
  } else {
    Write-Host "missing" -NoNewline -ForegroundColor $C_Bad
  }
  Write-Host ""
}

function Write-Section {
  param([string]$Name)
  Write-Host ""
  Write-Host "   " -NoNewline
  Write-Host (" " + $Name + " ") -NoNewline -BackgroundColor DarkGray -ForegroundColor White
  $used = $Name.Length + 5
  $len = 54 - $used
  if ($len -lt 1) { $len = 1 }
  Write-Host (" " + ("-" * $len)) -ForegroundColor $C_Section
}

function Write-Item {
  param([string]$Key, [string]$Label, [string]$Hint = "")
  Write-Host "   [" -NoNewline -ForegroundColor $C_Section
  Write-Host $Key -NoNewline -ForegroundColor $C_Key
  Write-Host "] " -NoNewline -ForegroundColor $C_Section
  if ($Hint) {
    Write-Host $Label.PadRight(34) -NoNewline -ForegroundColor $C_Label
    Write-Host $Hint -ForegroundColor $C_Hint
  } else {
    Write-Host $Label -ForegroundColor $C_Label
  }
}

function Write-Back {
  Write-Host ""
  Write-Host "   [ESC] Back" -ForegroundColor $C_Back
  Write-Host ""
}

function Write-Note {
  param([string]$Text, [string]$Color = "DarkGray")
  Write-Host "   $Text" -ForegroundColor $Color
}

# ----- running opencode ------------------------------------------------------

function Invoke-OpenCode {
  param([string[]]$Arguments, [string]$Dir)
  if (-not (Test-Command "opencode")) {
    Write-Host ""
    Write-Note "opencode is not installed or not on PATH." $C_Bad
    Write-Note "Use Manage -> [I] Install / Repair OpenCode." $C_Hint
    Pause-Menu
    return
  }
  if ($Dir) { Push-Location $Dir }
  try {
    Write-Host ""
    Write-Note "Starting opencode..." $C_Good
    Start-Sleep -Milliseconds 350
    & opencode @Arguments
  }
  finally {
    if ($Dir) { Pop-Location }
  }
  Pause-Menu
}

# ----- user PATH helpers (for the "oc" shortcut) -----------------------------

function Test-DirOnUserPath {
  param([string]$Dir)
  $p = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $p) { return $false }
  return (($p -split ";") -contains $Dir)
}

function Add-DirToUserPath {
  param([string]$Dir)
  if (Test-DirOnUserPath $Dir) { return $false }
  $p = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $p) { $p = "" }
  [Environment]::SetEnvironmentVariable("Path", ($p.TrimEnd(";") + ";" + $Dir), "User")
  return $true
}

function Remove-DirFromUserPath {
  param([string]$Dir)
  $p = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $p) { return $false }
  $kept = $p -split ";" | Where-Object { $_ -ne "" -and $_ -ne $Dir }
  [Environment]::SetEnvironmentVariable("Path", ($kept -join ";"), "User")
  return $true
}

function Write-OcShim {
  if (-not (Test-Path $ShimDir)) { New-Item -ItemType Directory -Path $ShimDir -Force | Out-Null }
  $scriptPath = Join-Path $LauncherDir "opencode-launcher.ps1"
  $lines = @(
    '@echo off',
    'rem Launches the OpenCode Launcher. Managed by opencode-launcher.ps1.',
    'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '" %*'
  )
  Set-Content -Path $ShimPath -Value $lines -Encoding ASCII
}

# ----- main-menu actions -----------------------------------------------------

function Action-Run      { Invoke-OpenCode -Arguments @() -Dir (Get-Location).Path }
function Action-Continue { Invoke-OpenCode -Arguments @("--continue") -Dir (Get-Location).Path }

function Action-Folder {
  Write-Title "Run in a specific folder"
  Write-Note "Enter a folder path (you can drag a folder onto this window),"
  Write-Note "or press Enter to cancel."
  Write-Host ""
  $path = Read-Host "   Folder"
  if ([string]::IsNullOrWhiteSpace($path)) { return }
  $path = $path.Trim('"')
  if (-not (Test-Path $path -PathType Container)) {
    Write-Host ""
    Write-Note "Folder not found: $path" $C_Bad
    Pause-Menu
    return
  }
  $full = (Resolve-Path $path).Path
  Invoke-OpenCode -Arguments @($full) -Dir $full
}

function Action-Web {
  if (-not (Test-Command "opencode")) {
    Write-Host ""
    Write-Note "opencode is not installed. Use Manage -> [I] Install / Repair." $C_Bad
    Pause-Menu
    return
  }
  Write-Host ""
  Write-Note "Starting the web server in a separate window..." $C_Good
  Write-Note "Look there for the URL; close that window to stop." $C_Hint
  Start-Process -FilePath "cmd" -ArgumentList '/k', "title OpenCode Web && opencode web" | Out-Null
  Start-Sleep -Milliseconds 600
}

# ----- Manage actions --------------------------------------------------------

function Manage-Update {
  Write-Title "Update OpenCode"
  if (-not (Test-Command "opencode")) {
    Write-Host ""
    Write-Note "opencode is not installed. Use [I] Install / Repair." $C_Bad
    Pause-Menu; return
  }
  Write-Note "Running: opencode upgrade" $C_Hint
  Write-Host ""
  & opencode upgrade
  Refresh-Status
  Pause-Menu
}

function Manage-Install {
  Write-Title "Install / Repair OpenCode"
  if (-not (Test-Command "npm")) {
    Write-Host ""
    Write-Note "npm was not found. Node.js is required and will be installed first." $C_Warn
    Write-Host ""
    if (Test-Command "winget") {
      Write-Note "Using winget..." $C_Hint
      & winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
      $env:Path = "$env:ProgramFiles\nodejs;" + $env:Path
    } elseif (Test-Path $NodeScript) {
      Write-Note "winget not found - downloading Node.js directly..." $C_Hint
      & powershell -NoProfile -ExecutionPolicy Bypass -File $NodeScript
      $env:Path = "$env:ProgramFiles\nodejs;" + $env:Path
    } else {
      Write-Host ""
      Write-Note "Node.js is missing and could not be installed automatically." $C_Bad
      Write-Note "Install it from https://nodejs.org/ and run this again." $C_Hint
      Pause-Menu; return
    }
    if (-not (Test-Command "npm")) {
      Write-Host ""
      Write-Note "npm is still unavailable. Install Node.js manually from https://nodejs.org/" $C_Bad
      Pause-Menu; return
    }
  }
  Write-Host ""
  Write-Note "Running: npm install -g $OpenCodePkg@latest" $C_Hint
  Write-Host ""
  & npm install -g "$OpenCodePkg@latest"
  Write-Host ""
  if ($LASTEXITCODE -eq 0) { Write-Note "Done. opencode should now be installed." $C_Good }
  else { Write-Note "npm exited with code $LASTEXITCODE." $C_Bad }
  Refresh-Status
  Pause-Menu
}

function Manage-Uninstall {
  Write-Title "Uninstall OpenCode"
  Write-Note "Removes the opencode CLI." $C_Warn
  Write-Note "Your config, sessions and API keys are NOT touched." $C_Hint
  Write-Note "(Back them up first with [B] if you want a safe copy.)" $C_Hint
  Write-Host ""
  $ans = Read-Host "   Type YES to uninstall"
  if ($ans -ne "YES") { return }
  Write-Host ""
  if (Test-Command "opencode") {
    Write-Note "Running: opencode uninstall" $C_Hint
    & opencode uninstall
  }
  Write-Note "Running: npm uninstall -g $OpenCodePkg" $C_Hint
  & npm uninstall -g $OpenCodePkg
  Write-Host ""
  if (-not (Test-Command "opencode")) { Write-Note "opencode removed." $C_Good }
  else { Write-Note "opencode is still on PATH; check the output above." $C_Warn }
  Refresh-Status
  Pause-Menu
}

function Manage-Backup {
  Write-Title "Backup opencode"
  if (-not (Test-Path $BackupScript)) {
    Write-Note "Backup script not found: $BackupScript" $C_Bad
    Pause-Menu; return
  }
  Write-Note "Running backup..." $C_Hint
  Write-Host ""
  & $BackupScript -Backup
  Pause-Menu
}

function Manage-RestoreMenu {
  $archiveDir = Join-Path $env:USERPROFILE ".config\opencode\backup\archives"
  while ($true) {
    Write-Title "Restore opencode"
    $archives = @()
    if (Test-Path $archiveDir) {
      $archives = @(Get-ChildItem $archiveDir -Filter "opencode-backup-*" -File | Sort-Object LastWriteTime -Descending)
    }
    if ($archives.Count -eq 0) {
      Write-Note "No backups found." $C_Warn
      Pause-Menu; return
    }
    Write-Note "Select a backup to restore:" $C_Hint
    Write-Host ""
    for ($i = 0; $i -lt $archives.Count; $i++) {
      $a = $archives[$i]
      $kb = [math]::Round($a.Length / 1KB, 1)
      Write-Host "   [" -NoNewline -ForegroundColor $C_Section
      Write-Host ($i + 1) -NoNewline -ForegroundColor $C_Key
      Write-Host "] " -NoNewline -ForegroundColor $C_Section
      Write-Host ("{0}  ({1} KB, {2})" -f $a.Name, $kb, $a.LastWriteTime.ToString("yyyy-MM-dd HH:mm")) -ForegroundColor $C_Label
    }
    Write-Back

    $k = Read-MenuKey
    if ($k -eq "ESC") { return }

    $idx = 0
    if ([int]::TryParse($k, [ref]$idx)) {
      if ($idx -ge 1 -and $idx -le $archives.Count) {
        $chosen = $archives[$idx - 1]
        Write-Host ""
        $ans = Read-Host ("   Restore '" + $chosen.Name + "'? Type YES to confirm")
        if ($ans -eq "YES") {
          Write-Host ""
          & $BackupScript -Restore -Path $chosen.FullName
          Pause-Menu
        }
      }
    }
  }
}

function Manage-SetupShortcut {
  Write-Title 'Set up the "oc" command shortcut'
  Write-Note "Creates a small shim so typing  oc  opens this launcher:"
  Write-Note "  $ShimPath" $C_Label
  Write-Host ""
  $added = Add-DirToUserPath $ShimDir
  Write-OcShim
  Write-Note "Created: $ShimPath" $C_Good
  if ($added) {
    Write-Note "Added $ShimDir to your user PATH." $C_Good
  } else {
    Write-Note "$ShimDir was already on your PATH." $C_Hint
  }
  Write-Host ""
  Write-Note "Open a NEW terminal and type:  oc" $C_Hint
  Pause-Menu
}

function Manage-UninstallLauncher {
  Write-Title "Uninstall Launcher"
  Write-Note "Removes the oc shortcut and the launcher files:" $C_Warn
  Write-Note "  $ShimPath" $C_Hint
  Write-Note "  $LauncherDir" $C_Hint
  Write-Note "opencode itself, your config and backups are NOT touched." $C_Hint
  Write-Host ""
  $ans = Read-Host "   Type YES to remove the launcher"
  if ($ans -ne "YES") { return }

  Set-Location $env:USERPROFILE
  Remove-Item $ShimPath -Force -ErrorAction SilentlyContinue
  foreach ($f in @("opencode-launcher.ps1", "opencode-backup.ps1", "opencode-backup.cmd", "install-node.ps1")) {
    Remove-Item (Join-Path $LauncherDir $f) -Force -ErrorAction SilentlyContinue
  }
  Remove-Item $LauncherDir -Force -Recurse -ErrorAction SilentlyContinue
  Remove-DirFromUserPath $LauncherDir | Out-Null

  Write-Host ""
  Write-Note "Launcher removed. You can close this window." $C_Good
  Write-Note "Open a new terminal for the PATH change to take effect." $C_Hint
  Write-Host ""
  [void][Console]::ReadKey($true)
  exit
}

function Show-ManageMenu {
  while ($true) {
    Write-Title "Manage OpenCode"
    Write-StatusLine
    Write-Section "OPENCODE"
    Write-Item "U" "Update OpenCode"              "opencode upgrade"
    Write-Item "I" "Install / Repair OpenCode"    "npm install -g"
    Write-Item "X" "Uninstall OpenCode"           "keeps config + keys"
    Write-Section "DATA"
    Write-Item "B" "Backup"                       "config, keys, launcher"
    Write-Item "R" "Restore"                      "pick a backup"
    Write-Section "LAUNCHER"
    Write-Item "O" 'Set up the "OC" shortcut'
    Write-Item "L" "Uninstall Launcher"
    Write-Back

    switch (Read-MenuKey) {
      "U"   { Manage-Update }
      "I"   { Manage-Install }
      "X"   { Manage-Uninstall }
      "B"   { Manage-Backup }
      "R"   { Manage-RestoreMenu }
      "O"   { Manage-SetupShortcut }
      "L"   { Manage-UninstallLauncher }
      "ESC" { return }
    }
  }
}

# ----- main loop -------------------------------------------------------------

function Show-MainMenu {
  while ($true) {
    try { Clear-Host } catch {}
    Write-Title "OPENCODE LAUNCHER"
    Write-StatusLine
    Write-Host "   Folder " -NoNewline -ForegroundColor $C_Hint
    Write-Host (Get-Location).Path -ForegroundColor $C_Hint
    Write-Section "RUN"
    Write-Item "R" "Run OpenCode"                 "this folder"
    Write-Item "C" "Continue last session"        "--continue"
    Write-Item "F" "Run in a specific folder"     "prompt for a path"
    Write-Item "S" "Launch Web Server"            "opencode web"
    Write-Section "MANAGE"
    Write-Item "M" "Manage"                       "update, backup, restore..."
    Write-Section "EXIT"
    Write-Item "Q" "Quit"
    Write-Host ""

    switch (Read-MenuKey) {
      "R"   { Action-Run }
      "C"   { Action-Continue }
      "F"   { Action-Folder }
      "S"   { Action-Web }
      "M"   { Show-ManageMenu }
      "Q"   { return }
      "ESC" { return }
    }
  }
}

if (-not $NoMenu) { Show-MainMenu }
