#requires -Version 5.1
<#
  opencode-launcher.ps1 - OpenCode Launcher v2.

  A coloured, keypress-driven menu for common opencode actions:
  run, resume, open-a-folder, web server, update, install/repair, uninstall,
  backup / restore, and checking the launcher itself for updates.

  Entry point: the "oc" shim (oc.cmd on your PATH, created by option [O]),
  or run this file directly:
      powershell -NoProfile -ExecutionPolicy Bypass -File opencode-launcher.ps1
#>

param([switch]$NoMenu)

$ErrorActionPreference = "Continue"
try { $Host.UI.RawUI.WindowTitle = "OpenCode Launcher" } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$LauncherVersion = "2.5"
$LauncherAuthor  = "Wayne Scicluna"

# ----- locations -------------------------------------------------------------

$LauncherDir = $PSScriptRoot
if (-not $LauncherDir) { $LauncherDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

$BackupScript = Join-Path $LauncherDir "opencode-backup.ps1"
$ShimDir      = Join-Path $env:USERPROFILE ".local\bin"
$ShimPath     = Join-Path $ShimDir "oc.cmd"
$OpenCodePkg  = "@opencode/cli"

# Probing opencode/node costs ~0.6s (it spawns a process per probe), so the
# result is cached for a short while. Refresh-Status recomputes and rewrites.
$StatusCacheDir = Join-Path $env:LOCALAPPDATA "OpenCodeLauncher"
$StatusCachePath = Join-Path $StatusCacheDir "status.json"
$StatusCacheTTL  = 600   # seconds

# Where to look for launcher updates, and which files to refresh.
$UpdateRepo   = "JagerWayne/opencode-launcher"
$UpdateBranch = "main"
$UpdateRaw    = "https://raw.githubusercontent.com/$UpdateRepo/$UpdateBranch"
$UpdateFiles  = @(
  "VERSION",
  "opencode-backup.ps1",
  "opencode-backup.cmd",
  "install.ps1",
  "run.ps1",
  "run.bat",
  "opencode-launcher.ps1"
)

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
  if (Get-Command $Name -ErrorAction SilentlyContinue) { return $true }
  # Get-Command can cache PATH lookups; where.exe rescans the current PATH.
  return [bool](& where.exe $Name 2>$null)
}

function Update-SessionPath {
  # Refresh this process's PATH from the machine + user environment so a
  # freshly installed Node.js is found without reopening the launcher.
  try {
    $machine = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $user    = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ";"
  } catch {}
}

# The expensive version: actually runs the probes.
function Measure-Status {
  $hasOC  = Test-Command "opencode"
  $ocVer  = ""
  if ($hasOC) { try { $ocVer = ((& opencode --version 2>$null) | Select-Object -First 1) } catch {} }
  $hasNpm = Test-Command "npm"
  $node   = ""
  if (Test-Command "node") { try { $node = (& node --version 2>$null) } catch {} }
  return [pscustomobject]@{ HasOC = $hasOC; OCVer = $ocVer; HasNpm = $hasNpm; Node = $node }
}

function Read-StatusCache {
  try {
    if (-not (Test-Path $StatusCachePath)) { return $null }
    $age = ((Get-Date) - (Get-Item $StatusCachePath).LastWriteTime).TotalSeconds
    if ($age -gt $StatusCacheTTL) { return $null }
    $c = Get-Content $StatusCachePath -Raw | ConvertFrom-Json
    return [pscustomobject]@{
      HasOC = [bool]$c.HasOC; OCVer = [string]$c.OCVer
      HasNpm = [bool]$c.HasNpm; Node = [string]$c.Node
    }
  } catch { return $null }
}

function Write-StatusCache {
  param($Status)
  try {
    if (-not (Test-Path $StatusCacheDir)) {
      New-Item -ItemType Directory -Path $StatusCacheDir -Force | Out-Null
    }
    ($Status | ConvertTo-Json) | Set-Content $StatusCachePath -Encoding ASCII
  } catch {}
}

function Get-Status {
  $cached = Read-StatusCache
  if ($cached) { return $cached }
  $s = Measure-Status
  Write-StatusCache $s
  return $s
}
$script:Status = Get-Status
# Always re-measures - used after actions that can change what is installed.
function Refresh-Status {
  $script:Status = Measure-Status
  Write-StatusCache $script:Status
}

# ----- drawing ---------------------------------------------------------------

function Write-Title {
  param([string]$Title, [string]$Author = "")
  # Start every screen on a clean console.
  try { Clear-Host } catch {}
  $left = "   " + $Title
  if ($Author) { $left = $left + "  by " + $Author }
  $right = "v$LauncherVersion"
  $width = 64
  $pad = $width - $left.Length - $right.Length
  if ($pad -lt 1) { $pad = 1 }
  Write-Host ""
  Write-Host ($left + (" " * $pad) + $right + " ") -BackgroundColor DarkCyan -ForegroundColor White
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
    Write-Note "Use Manage -> [I] Install or repair OpenCode." $C_Hint
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

function ConvertTo-ComparablePath {
  # Normalise so a trailing backslash, a different case, or a .\. prefix does
  # not make an existing PATH entry look like a different directory.
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
  try { return [IO.Path]::GetFullPath($Path.Trim()).TrimEnd('\') }
  catch { return $Path.Trim().TrimEnd('\') }
}

function Get-UserPathRaw {
  # Returns the raw (unmodified) non-empty entries from the user PATH.
  $p = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $p) { return @() }
  return @($p -split ";" | Where-Object { $_ -and $_.Trim() })
}

function Test-DirOnUserPath {
  param([string]$Dir)
  $target = ConvertTo-ComparablePath $Dir
  if (-not $target) { return $false }
  foreach ($e in (Get-UserPathRaw)) {
    if ((ConvertTo-ComparablePath $e) -eq $target) { return $true }
  }
  return $false
}

function Add-DirToUserPath {
  param([string]$Dir)
  if (Test-DirOnUserPath $Dir) { return $false }
  $p = [Environment]::GetEnvironmentVariable("Path", "User")
  if (-not $p) { $p = "" }
  # Append the normalised form; existing entries are left exactly as they are.
  $target = ConvertTo-ComparablePath $Dir
  [Environment]::SetEnvironmentVariable("Path", ($p.TrimEnd(";") + ";" + $target), "User")
  return $true
}

function Remove-DirFromUserPath {
  param([string]$Dir)
  $target = ConvertTo-ComparablePath $Dir
  if (-not $target) { return $false }
  $raw = @(Get-UserPathRaw)
  # Keep each surviving entry verbatim, only dropping the one being removed.
  $kept = @($raw | Where-Object { (ConvertTo-ComparablePath $_) -ne $target })
  if ($kept.Count -eq $raw.Count) { return $false }
  [Environment]::SetEnvironmentVariable("Path", ($kept -join ";"), "User")
  return $true
}

function Write-OcShim {
  if (-not (Test-Path $ShimDir)) { New-Item -ItemType Directory -Path $ShimDir -Force | Out-Null }
  # Prefer an all-ASCII target. A .cmd file's bytes are interpreted using the
  # console code page, so a non-ASCII install path in the shim can be mangled
  # into an unopenable path. The default install folder is under
  # %LOCALAPPDATA%, which cmd expands itself and which is always ASCII.
  $defaultDir = Join-Path $env:LOCALAPPDATA "OpenCodeLauncher"
  $scriptPath = if ((ConvertTo-ComparablePath $LauncherDir) -eq (ConvertTo-ComparablePath $defaultDir)) {
    "%LOCALAPPDATA%\OpenCodeLauncher\opencode-launcher.ps1"
  } else {
    Join-Path $LauncherDir "opencode-launcher.ps1"
  }
  # Build the run line first: `,` binds tighter than `+`, so inlining the
  # concatenation inside @(...) would split it into separate array elements.
  $runLine = 'powershell -NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '" %*'
  $lines = @(
    '@echo off',
    'rem Launches the OpenCode Launcher. Managed by opencode-launcher.ps1.',
    $runLine
  )
  # WriteAllLines gives us CRLF, which cmd requires.
  [System.IO.File]::WriteAllLines($ShimPath, $lines, [System.Text.Encoding]::ASCII)
  if ($scriptPath -cmatch '[^\x00-\x7F]') {
    # cmd reads a .cmd using the console code page, so a non-ASCII install
    # path cannot survive in a shim. Say so instead of leaving a broken oc.
    Write-Host "   WARNING: the install path has non-ASCII characters, which" -ForegroundColor Yellow
    Write-Host "            cmd cannot pass reliably from a .cmd shim." -ForegroundColor Yellow
    Write-Host "            Install to a plain folder such as" -ForegroundColor Yellow
    Write-Host "            %LOCALAPPDATA%\OpenCodeLauncher to avoid this." -ForegroundColor Yellow
  }
}

# ----- main-menu actions -----------------------------------------------------

function Action-Run      { Invoke-OpenCode -Arguments @() -Dir (Get-Location).Path }
function Action-Continue { Invoke-OpenCode -Arguments @("--continue") -Dir (Get-Location).Path }

function Action-Folder {
  Write-Title "Open a folder"
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
    Write-Note "opencode is not installed. Use Manage -> [I] Install or repair." $C_Bad
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
    Write-Note "opencode is not installed. Use [I] Install or repair." $C_Bad
    Pause-Menu; return
  }
  Write-Note "Running: opencode upgrade" $C_Hint
  Write-Host ""
  & opencode upgrade
  Refresh-Status
  Pause-Menu
}

function Manage-Install {
  Write-Title "Install or Repair OpenCode"
  if (-not (Test-Command "npm")) {
    Write-Host ""
    Write-Note "Node.js (which provides npm) is required, but npm was not found." $C_Warn
    if (Test-Command "winget") {
      Write-Host ""
      Write-Note "Install Node.js LTS automatically with winget?" $C_Hint
      $go = Read-Host "   Type YES to install Node.js"
      if ($go -eq "YES") {
        Write-Host ""
        Write-Note "Running: winget install --id OpenJS.NodeJS.LTS -e --silent" $C_Hint
        Write-Host ""
        & winget install --id OpenJS.NodeJS.LTS -e --silent `
          --accept-package-agreements --accept-source-agreements
        Update-SessionPath
        Write-Host ""
      }
    }
    if (-not (Test-Command "npm")) {
      Write-Note "npm is still not available. Install the Node.js LTS build from:" $C_Hint
      Write-Host ""
      Write-Note "    https://nodejs.org/" $C_Label
      Write-Host ""
      Write-Note "then press any key to check again." $C_Hint
      [void][Console]::ReadKey($true)
      Update-SessionPath
      if (-not (Test-Command "npm")) {
        Write-Host ""
        Write-Note "npm is still missing. Install Node.js, open a new terminal," $C_Bad
        Write-Note "and choose Install again." $C_Hint
        Pause-Menu
        return
      }
    }
  }
  Write-Host ""
  Write-Note "Running: npm install -g $OpenCodePkg@latest --allow-scripts=$OpenCodePkg" $C_Hint
  Write-Host ""
  # npm 11 blocks install scripts by default and warns about it. opencode's
  # postinstall picks the right platform binary (it checks for AVX2 on Windows)
  # and copies it into place, so it has to run. The allow is scoped to this one
  # package instead of turning install scripts on globally.
  & npm install -g "$OpenCodePkg@latest" --no-fund --no-audit --allow-scripts="$OpenCodePkg"
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
  Write-Title "Back Up OpenCode"
  if (-not (Test-Path $BackupScript)) {
    Write-Note "Backup script not found: $BackupScript" $C_Bad
    Pause-Menu; return
  }
  Write-Note "Saving your config, API keys and sessions..." $C_Hint
  Write-Host ""
  & $BackupScript -Backup
  Pause-Menu
}

function Manage-RestoreMenu {
  $archiveDir = Join-Path $env:USERPROFILE ".config\opencode\backup\archives"
  while ($true) {
    Write-Title "Restore a Backup"
    $archives = @()
    if (Test-Path $archiveDir) {
      $archives = @(Get-ChildItem $archiveDir -Filter "opencode-backup-*" -File | Sort-Object LastWriteTime -Descending)
    }
    if ($archives.Count -eq 0) {
      Write-Note "No backups found." $C_Warn
      Pause-Menu; return
    }
    Write-Note "Choose a backup to restore (newest first):" $C_Hint
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

function Get-RemoteLauncherVersion {
  try {
    $resp = Invoke-WebRequest -Uri "$UpdateRaw/VERSION" -UseBasicParsing -TimeoutSec 15
    return ("$($resp.Content)").Trim()
  } catch {
    return $null
  }
}

function Manage-CheckLauncherUpdate {
  Write-Title "Check for Launcher Updates"
  Write-Note "Installed version: v$LauncherVersion" $C_Hint
  Write-Note "Checking GitHub for the latest version..." $C_Hint
  $remote = Get-RemoteLauncherVersion
  if (-not $remote) {
    Write-Host ""
    Write-Note "Could not reach GitHub (are you offline?). Try again later." $C_Warn
    Pause-Menu; return
  }
  $newer = $false
  try { $newer = ([version]$remote -gt [version]$LauncherVersion) } catch { $newer = $false }
  Write-Host ""
  if (-not $newer) {
    Write-Note "You are up to date (v$LauncherVersion)." $C_Good
    Pause-Menu; return
  }
  Write-Note "A newer launcher is available: v$LauncherVersion  ->  v$remote" $C_Warn
  Write-Host ""
  $ans = Read-Host "   Update the launcher now? Type YES to update"
  if ($ans -ne "YES") { return }

  Write-Host ""
  $ok = 0; $fail = 0
  foreach ($f in $UpdateFiles) {
    try {
      $text = (Invoke-WebRequest -Uri "$UpdateRaw/$f" -UseBasicParsing -TimeoutSec 30).Content
      if ($f -like "*.cmd" -or $f -like "*.bat") {
        $text = ($text -replace "`r`n", "`n") -replace "`n", "`r`n"
      }
      [IO.File]::WriteAllText((Join-Path $LauncherDir $f), $text, (New-Object Text.UTF8Encoding($false)))
      Write-Note "updated  $f" $C_Good
      $ok++
    } catch {
      Write-Note "failed   $f  ($($_.Exception.Message))" $C_Bad
      $fail++
    }
  }
  Write-Host ""
  if ($fail -eq 0) {
    Write-Note "Launcher updated to v$remote." $C_Good
    Write-Note "Close and reopen the launcher to use the new version." $C_Hint
  } else {
    Write-Note "Updated $ok file(s); $fail failed. Try again on a stable connection." $C_Warn
  }
  Pause-Menu
}

function Manage-SetupShortcut {
  Write-Title 'Set Up the "oc" Command'
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

function Get-SourceCheckoutMarker {
  # A launcher running out of a git checkout must never delete the checkout.
  # -Force would remove .git (hidden) along with README/LICENSE and the history.
  foreach ($marker in @(".git", ".gitattributes")) {
    if (Test-Path (Join-Path $LauncherDir $marker)) { return $marker }
  }
  return $null
}

function Get-UnexpectedLauncherItems {
  # Anything in the launcher folder that the launcher did not put there.
  $known = @{}
  foreach ($f in $UpdateFiles) { $known[$f] = $true }
  $found = @()
  if (Test-Path $LauncherDir) {
    $found = @(Get-ChildItem $LauncherDir -Force | Where-Object { -not $known.ContainsKey($_.Name) })
  }
  return $found
}

function Manage-UninstallLauncher {
  Write-Title "Uninstall This Launcher"
  Write-Note "Removes the oc shortcut and the launcher files:" $C_Warn
  Write-Note "  $ShimPath" $C_Hint
  Write-Note "  $LauncherDir" $C_Hint
  Write-Note "opencode itself, your config and backups are NOT touched." $C_Hint

  # Refuse outright when this is a source checkout: deleting it would destroy
  # the git history, not just the launcher.
  $marker = Get-SourceCheckoutMarker
  if ($marker) {
    Write-Host ""
    Write-Note "This folder looks like a source checkout (found '$marker')." $C_Bad
    Write-Note "Uninstall will not delete it, so your git history stays safe." $C_Good
    Write-Host ""
    Write-Note "To remove just the launcher, delete these files yourself:" $C_Hint
    foreach ($f in $UpdateFiles) { Write-Note "  $f" $C_Label }
    Write-Note "  and then the oc shim: $ShimPath" $C_Label
    Write-Host ""
    Pause-Menu
    return
  }

  $extra = Get-UnexpectedLauncherItems
  if ($extra.Count -gt 0) {
    Write-Host ""
    Write-Note "This folder also contains files the launcher did not create:" $C_Warn
    foreach ($e in $extra) { Write-Note "  $($e.Name)" $C_Label }
    Write-Note "They will be deleted too." $C_Warn
  }

  Write-Host ""
  $ans = Read-Host "   Type YES to remove the launcher"
  if ($ans -ne "YES") { return }

  Set-Location $env:USERPROFILE
  Remove-Item $ShimPath -Force -ErrorAction SilentlyContinue
  # A single recursive delete: if it fails nothing is half-removed.
  Remove-Item $LauncherDir -Force -Recurse -ErrorAction SilentlyContinue
  # Remove the directory that [O] actually added to PATH, not the install dir.
  Remove-DirFromUserPath $ShimDir | Out-Null

  Write-Host ""
  Write-Note "Launcher removed. You can close this window." $C_Good
  Write-Note "Open a new terminal for the PATH change to take effect." $C_Hint
  Write-Host ""
  [void][Console]::ReadKey($true)
  exit
}

function Show-ManageMenu {
  while ($true) {
    Write-Title "Manage"
    Write-StatusLine
    Write-Section "OPENCODE"
    Write-Item "U" "Update OpenCode"              "opencode upgrade"
    Write-Item "I" "Install or repair OpenCode"   "sets up Node if needed"
    Write-Item "X" "Uninstall OpenCode"           "keeps config + keys"
    Write-Section "BACKUPS"
    Write-Item "B" "Back up settings and keys"    "config, keys, sessions"
    Write-Item "R" "Restore from a backup"        "pick an archive"
    Write-Section "LAUNCHER"
    Write-Item "C" "Check for launcher updates"   "this menu"
    Write-Item "O" 'Create the "oc" command'      "open from any terminal"
    Write-Item "L" "Uninstall this launcher"
    Write-Back

    switch (Read-MenuKey) {
      "U"   { Manage-Update }
      "I"   { Manage-Install }
      "X"   { Manage-Uninstall }
      "B"   { Manage-Backup }
      "R"   { Manage-RestoreMenu }
      "C"   { Manage-CheckLauncherUpdate }
      "O"   { Manage-SetupShortcut }
      "L"   { Manage-UninstallLauncher }
      "ESC" { return }
    }
  }
}

# ----- main loop -------------------------------------------------------------

function Show-MainMenu {
  while ($true) {
    Write-Title "OpenCode Launcher" -Author $LauncherAuthor
    Write-StatusLine
    Write-Host "   Folder " -NoNewline -ForegroundColor $C_Hint
    Write-Host (Get-Location).Path -ForegroundColor $C_Hint
    Write-Section "START"
    Write-Item "R" "Run OpenCode here"            "this folder"
    Write-Item "C" "Resume last session"          "picks up where you left off"
    Write-Item "F" "Open a folder..."             "choose a project folder"
    Write-Item "S" "Open web interface"           "opencode web"
    Write-Section "MANAGE"
    Write-Item "M" "Manage"                       "update, back up, restore..."
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

if (-not $NoMenu) {
  if (-not $script:Status.HasOC) {
    # That may have come from the status cache - confirm before nagging.
    Refresh-Status
    if (-not $script:Status.HasOC) {
      # OpenCode isn't installed yet - drop straight into the Install screen.
      Manage-Install
    }
  }
  Show-MainMenu
}
