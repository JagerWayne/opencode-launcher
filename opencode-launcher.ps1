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

$LauncherVersion = "3.0"
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

# User preferences (the Default Working Directory, etc.). Kept beside the
# status cache rather than in the launcher folder so it survives the launcher
# being moved or re-installed.
$SettingsDir  = $StatusCacheDir
$SettingsPath = Join-Path $SettingsDir "settings.json"

# The Default Working Directory: the single folder that holds every project.
# Empty until the user picks one, which the Projects menu asks for on first use.
$script:ProjectsDir = ""

# ----- project pagination & caching ------------------------------------------

$script:ProjectsPage = 0
$script:ProjectsPageSize = 9
$script:ProjectListCache = $null
$script:ProjectCacheTime = $null
$script:ProjectCacheTTL = 30  # seconds

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
$C_Favorite = "Cyan"
$C_Recent  = "Magenta"
$C_Git     = "DarkYellow"

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

# --- project sessions --------------------------------------------------------

function Get-ProjectSessions {
  # Returns the project's top-level sessions (newest first) for a folder, or @().
  param([string]$Dir)
  $out = @()
  Push-Location $Dir
  try {
    $raw = & opencode session list --format json 2>$null
    if ($LASTEXITCODE -eq 0 -and $raw) {
      # Assign before wrapping: a JSON array through the pipeline comes back as
      # one nested object under Windows PowerShell 5.1.
      try { $parsed = ($raw -join "`n") | ConvertFrom-Json; $out = @($parsed) } catch { $out = @() }
    }
  } catch { $out = @() }
  finally { Pop-Location }
  if (-not $out) { return @() }
  return $out
}

function Select-ProjectSession {
  # Shows a folder's sessions and returns the chosen session id, "NEW" to start
  # a new session, or $null if the user cancels with ESC.
  param([string]$Dir, [object[]]$Sessions)
  while ($true) {
    Write-Title "Open a project"
    Write-Host "   Folder " -NoNewline -ForegroundColor $C_Hint
    Write-Host $Dir -ForegroundColor $C_Hint
    Write-Section "SESSIONS"
    Write-Note "Resume a session, or start a new one:" $C_Hint
    Write-Host ""
    for ($i = 0; $i -lt $Sessions.Count; $i++) {
      $s = $Sessions[$i]
      $title = "$($s.title)"
      if ([string]::IsNullOrWhiteSpace($title)) { $title = "(untitled)" }
      $when = ""
      if ($s.updated) {
        try { $when = ([DateTimeOffset]::FromUnixTimeMilliseconds([int64]$s.updated)).LocalDateTime.ToString("yyyy-MM-dd HH:mm") } catch {}
      }
      Write-Host "   [" -NoNewline -ForegroundColor $C_Section
      Write-Host ($i + 1) -NoNewline -ForegroundColor $C_Key
      Write-Host "] " -NoNewline -ForegroundColor $C_Section
      Write-Host $title -NoNewline -ForegroundColor $C_Label
      if ($when) { Write-Host ("    " + $when) -ForegroundColor $C_Hint } else { Write-Host "" }
    }
    Write-Host ""
    Write-Host "   [" -NoNewline -ForegroundColor $C_Section
    Write-Host "N" -NoNewline -ForegroundColor $C_Key
    Write-Host "] " -NoNewline -ForegroundColor $C_Section
    Write-Host "New session" -ForegroundColor $C_Label
    Write-Host ""
    Write-Host "   [ESC] Cancel" -ForegroundColor $C_Back
    Write-Host ""

    $k = Read-MenuKey
    if ($k -eq "ESC") { return $null }
    if ($k -eq "N") { return "NEW" }
    if ($k -match '[0-9]') {
      $n = Complete-IndexKey $k
      if ($n -ge 1 -and $n -le $Sessions.Count) { return $Sessions[$n - 1].id }
    }
  }
}

function Open-Project {
  # Opens a project folder in opencode, first offering its existing sessions.
  param([string]$Dir)
  
  # Track this as a recent project
  Add-RecentProject -Path $Dir
  
  if (Test-Command "opencode") {
    $sessions = @(Get-ProjectSessions -Dir $Dir)
    if ($sessions.Count -gt 0) {
      $choice = Select-ProjectSession -Dir $Dir -Sessions $sessions
      if ($null -eq $choice) { return }                      # cancelled -> back
      if ($choice -eq "NEW") { Invoke-OpenCode -Arguments @($Dir) -Dir $Dir; return }
      Invoke-OpenCode -Arguments @("--session", $choice, $Dir) -Dir $Dir
      return
    }
  }
  Invoke-OpenCode -Arguments @($Dir) -Dir $Dir
}

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
  Open-Project -Dir $full
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

function Get-OpenCodeProcess {
  # opencode runs as a process named "opencode" (or opencode-<platform>).
  param([string]$NameFilter = "opencode*")
  return @(Get-Process -ErrorAction SilentlyContinue |
           Where-Object { $_.ProcessName -like $NameFilter })
}

function Stop-OpenCodeForBackup {
  # Closes any running opencode and waits for it to actually exit, so the
  # session database's file handles are released before it is copied.
  # Returns $true when nothing is left running.
  param([string]$NameFilter = "opencode*", [int]$TimeoutSeconds = 20)
  $procs = @(Get-OpenCodeProcess -NameFilter $NameFilter)
  if ($procs.Count -eq 0) { return $true }

  foreach ($p in $procs) {
    try {
      # Ask politely first - a console app usually ignores this, but it costs
      # nothing to try and it lets a GUI build close cleanly.
      [void]$p.CloseMainWindow()
    } catch {}
  }
  Start-Sleep -Milliseconds 600

  foreach ($p in @(Get-OpenCodeProcess -NameFilter $NameFilter)) {
    Write-Host "   stopping process $($p.ProcessName) (pid $($p.Id))..." -ForegroundColor $C_Hint
    try { Stop-Process -Id $p.Id -Force -ErrorAction Stop } catch {
      Write-Note "Could not stop pid $($p.Id): $($_.Exception.Message)" $C_Bad
    }
  }

  # Wait for the handles to be released rather than assuming an instant exit.
  $sw = [Diagnostics.Stopwatch]::StartNew()
  while ($sw.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
    if (@(Get-OpenCodeProcess -NameFilter $NameFilter).Count -eq 0) { return $true }
    Start-Sleep -Milliseconds 250
  }
  return (@(Get-OpenCodeProcess -NameFilter $NameFilter).Count -eq 0)
}

function Manage-Backup {
  Write-Title "Back Up OpenCode"
  if (-not (Test-Path $BackupScript)) {
    Write-Note "Backup script not found: $BackupScript" $C_Bad
    Pause-Menu; return
  }

  # The session database is a live SQLite file with an active write-ahead log.
  # It is only safe to copy while opencode is closed, so check first and offer
  # to close it rather than failing after the user has already committed to a
  # backup.
  $running = @(Get-OpenCodeProcess)
  if ($running.Count -gt 0) {
    $names = ($running | ForEach-Object { $_.ProcessName } | Sort-Object -Unique) -join ", "
    Write-Host ""
    Write-Note "opencode is running ($names)." $C_Warn
    Write-Note "Its session database can only be copied safely once it has" $C_Hint
    Write-Note "closed, otherwise the archive may not restore." $C_Hint
    Write-Host ""
    Write-Note "Any unsaved opencode work in those windows will be lost." $C_Warn
    Write-Host ""
    $ans = Read-Host "   Close opencode and continue? Type YES"
    if ($ans -ne "YES") {
      Write-Host ""
      Write-Note "Cancelled. Quit opencode yourself, then press [B] again." $C_Warn
      Pause-Menu
      return
    }
    Write-Host ""
    Write-Note "Closing opencode..." $C_Hint
    if (-not (Stop-OpenCodeForBackup)) {
      Write-Host ""
      Write-Note "opencode is still running, so the backup was not started." $C_Bad
      Write-Note "Close it manually, then press [B] again." $C_Hint
      Pause-Menu
      return
    }
    Write-Note "opencode closed." $C_Good
  }

  Write-Host ""
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

function Manage-CreateDesktopShortcut {
  Write-Title "Add a Desktop Shortcut"
  $desktop = [Environment]::GetFolderPath("Desktop")
  if (-not $desktop -or -not (Test-Path $desktop)) {
    Write-Host ""
    Write-Note "Could not find your Desktop folder." $C_Bad
    Pause-Menu
    return
  }
  $scriptPath = Join-Path $LauncherDir "opencode-launcher.ps1"
  $lnkPath    = Join-Path $desktop "OpenCode Launcher.lnk"
  Write-Note "Creates a shortcut on your Desktop that opens this launcher."
  Write-Note "  $lnkPath" $C_Label
  Write-Host ""
  if (Test-Path $lnkPath) {
    $ans = Read-Host "   A shortcut already exists there. Overwrite it? Type YES"
    if ($ans -ne "YES") { return }
  }
  $psExe = Join-Path $PSHOME "powershell.exe"
  if (-not (Test-Path $psExe)) {
    $psExe = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
  }
  try {
    $shell = New-Object -ComObject WScript.Shell
    $sc = $shell.CreateShortcut($lnkPath)
    $sc.TargetPath       = $psExe
    $sc.Arguments        = '-NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '"'
    $sc.WorkingDirectory = $LauncherDir
    $sc.WindowStyle      = 1
    $sc.Description      = "OpenCode Launcher"
    $sc.Save()
    [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell)
    Write-Host ""
    Write-Note "Created: $lnkPath" $C_Good
  } catch {
    Write-Host ""
    Write-Note "Could not create the shortcut: $($_.Exception.Message)" $C_Bad
  }
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
  # status.json and settings.json are the launcher's own data files and live
  # beside it when installed under %LOCALAPPDATA%, so they are not "unexpected".
  $known = @{}
  foreach ($f in $UpdateFiles) { $known[$f] = $true }
  $known["status.json"] = $true
  $known["settings.json"] = $true
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
    Write-Item "D" "Add a desktop shortcut"       "launch from the Desktop"
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
      "D"   { Manage-CreateDesktopShortcut }
      "L"   { Manage-UninstallLauncher }
      "ESC" { return }
    }
  }
}

# ----- settings ---------------------------------------------------------------

function Read-Settings {
  try {
    if (-not (Test-Path $SettingsPath)) { return @{} }
    $json = Get-Content $SettingsPath -Raw | ConvertFrom-Json
    $h = @{}
    foreach ($p in $json.PSObject.Properties) { $h[$p.Name] = $p.Value }
    return $h
  } catch { return @{} }
}

function Write-Settings {
  param([hashtable]$Values)
  try {
    if (-not (Test-Path $SettingsDir)) {
      New-Item -ItemType Directory -Path $SettingsDir -Force | Out-Null
    }
    ($Values | ConvertTo-Json) | Set-Content $SettingsPath -Encoding UTF8
    return $true
  } catch { return $false }
}

function Get-ProjectsDir {
  # Returns the configured Default Working Directory, or $null if it has never
  # been set or no longer exists on disk.
  if ($script:ProjectsDir -and (Test-Path $script:ProjectsDir -PathType Container)) {
    return $script:ProjectsDir
  }
  $s = Read-Settings
  if ($s.ContainsKey("ProjectsDir") -and $s.ProjectsDir) {
    if (Test-Path $s.ProjectsDir -PathType Container) {
      $script:ProjectsDir = $s.ProjectsDir
      return $script:ProjectsDir
    }
  }
  return $null
}

function Set-ProjectsDir {
  param([string]$Path)
  $full = (Resolve-Path $Path).Path
  $s = Read-Settings
  $s["ProjectsDir"] = $full
  [void](Write-Settings $s)
  $script:ProjectsDir = $full
  return $full
}

function Test-ValidProjectName {
  # Returns an error message, or $null when the name can be used.
  param([string]$Name, [string]$Root)
  if ([string]::IsNullOrWhiteSpace($Name)) { return "Enter a folder name." }
  $trimmed = $Name.Trim()
  if ($trimmed -match '[<>:"/\\|?*]') {
    return 'A folder name cannot contain  < > : " / \ | ? *'
  }
  if ($trimmed.EndsWith(".") -or $trimmed.EndsWith(" ")) {
    return "A folder name cannot end with a dot or a space."
  }
  if ($trimmed -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
    return "'$trimmed' is a reserved Windows device name."
  }
  if ($Root -and (Test-Path (Join-Path $Root $trimmed))) {
    return "'$trimmed' already exists there."
  }
  return $null
}

# ----- Phase 1: Caching & Performance ----------------------------------------

function Get-CachedProjectList {
  param([string]$Root, [switch]$Force)
  $now = Get-Date
  if (-not $Force -and $script:ProjectListCache -and $script:ProjectCacheTime) {
    $age = ($now - $script:ProjectCacheTime).TotalSeconds
    if ($age -lt $script:ProjectCacheTTL) {
      return $script:ProjectListCache
    }
  }
  $folders = @(Get-ChildItem $Root -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name)
  $script:ProjectListCache = $folders
  $script:ProjectCacheTime = $now
  return $folders
}

function Invalidate-ProjectCache {
  $script:ProjectListCache = $null
  $script:ProjectCacheTime = $null
}

function Get-ProjectFolder {
  # Every folder directly inside the Default Working Directory is a project.
  param([string]$Root, [switch]$NoCache)
  if (-not $Root -or -not (Test-Path $Root -PathType Container)) { return @() }
  if ($NoCache) {
    return @(Get-ChildItem $Root -Directory -Force -ErrorAction SilentlyContinue | Sort-Object Name)
  }
  return @(Get-CachedProjectList -Root $Root)
}

# ----- Phase 1: Recent Projects ----------------------------------------------

function Add-RecentProject {
  param([string]$Path)
  $s = Read-Settings
  if (-not $s.ContainsKey("RecentProjects")) {
    $s["RecentProjects"] = @()
  }
  $recent = @($s["RecentProjects"])
  $entry = @{
    path = $Path
    opened = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  }
  # Remove existing entry for this path
  $recent = @($recent | Where-Object { $_.path -ne $Path })
  # Add to front
  $recent = @($entry) + $recent
  # Keep only last 5
  if ($recent.Count -gt 5) {
    $recent = $recent[0..4]
  }
  $s["RecentProjects"] = $recent
  [void](Write-Settings $s)
}

function Get-RecentProjects {
  $s = Read-Settings
  if (-not $s.ContainsKey("RecentProjects")) { return @() }
  $recent = @($s["RecentProjects"])
  # Filter out projects that no longer exist
  return @($recent | Where-Object { Test-Path $_.path -PathType Container })
}

function Format-RelativeTime {
  param([int64]$UnixTimeMs)
  try {
    $dt = [DateTimeOffset]::FromUnixTimeMilliseconds($UnixTimeMs).LocalDateTime
    $diff = (Get-Date) - $dt
    if ($diff.TotalMinutes -lt 1) { return "just now" }
    if ($diff.TotalMinutes -lt 60) { return "$([int]$diff.TotalMinutes)m ago" }
    if ($diff.TotalHours -lt 24) { return "$([int]$diff.TotalHours)h ago" }
    if ($diff.TotalDays -lt 7) { return "$([int]$diff.TotalDays)d ago" }
    return $dt.ToString("MMM dd")
  } catch {
    return ""
  }
}

# ----- Phase 1: Favorites ----------------------------------------------------

function Get-FavoriteProjects {
  $s = Read-Settings
  if (-not $s.ContainsKey("FavoriteProjects")) { return @() }
  return @($s["FavoriteProjects"] | Where-Object { Test-Path $_ -PathType Container })
}

function Test-IsFavorite {
  param([string]$Path)
  $favs = @(Get-FavoriteProjects)
  $normalized = ConvertTo-ComparablePath $Path
  foreach ($f in $favs) {
    if ((ConvertTo-ComparablePath $f) -eq $normalized) { return $true }
  }
  return $false
}

function Toggle-ProjectFavorite {
  param([string]$Path)
  $s = Read-Settings
  if (-not $s.ContainsKey("FavoriteProjects")) {
    $s["FavoriteProjects"] = @()
  }
  $favs = @($s["FavoriteProjects"])
  $normalized = ConvertTo-ComparablePath $Path
  $found = $false
  $newFavs = @()
  foreach ($f in $favs) {
    if ((ConvertTo-ComparablePath $f) -eq $normalized) {
      $found = $true
    } else {
      $newFavs += $f
    }
  }
  if (-not $found) {
    $newFavs += $Path
  }
  $s["FavoriteProjects"] = $newFavs
  [void](Write-Settings $s)
  return (-not $found)
}

# ----- Phase 2: Git Integration ----------------------------------------------

function Get-ProjectGitStatus {
  param([string]$Path)
  if (-not (Test-Command "git")) { return $null }
  if (-not (Test-Path (Join-Path $Path ".git"))) { return $null }
  try {
    Push-Location $Path
    $status = & git status --porcelain --branch 2>$null
    $ahead = 0
    $behind = 0
    $changes = 0
    if ($status) {
      foreach ($line in $status) {
        if ($line -match '##.*\[ahead (\d+).*behind (\d+)\]') {
          $ahead = [int]$matches[1]
          $behind = [int]$matches[2]
        } elseif ($line -match '##.*\[ahead (\d+)\]') {
          $ahead = [int]$matches[1]
        } elseif ($line -match '##.*\[behind (\d+)\]') {
          $behind = [int]$matches[1]
        } elseif ($line -match '^[MADRCU?!]') {
          $changes++
        }
      }
    }
    Pop-Location
    return @{ Ahead = $ahead; Behind = $behind; Changes = $changes }
  } catch {
    Pop-Location
    return $null
  }
}

function Format-GitIndicator {
  param($GitStatus)
  if (-not $GitStatus) { return "" }
  $parts = @()
  if ($GitStatus.Changes -gt 0) {
    $parts += "[$([char]0x25CF)$($GitStatus.Changes)]"
  }
  if ($GitStatus.Ahead -gt 0) {
    $parts += "[$([char]0x2191)$($GitStatus.Ahead)]"
  }
  if ($GitStatus.Behind -gt 0) {
    $parts += "[$([char]0x2193)$($GitStatus.Behind)]"
  }
  return ($parts -join "")
}

# ----- Phase 3: Project Inspector --------------------------------------------

function Get-ProjectStats {
  param([string]$Path)
  $files = @(Get-ChildItem $Path -Recurse -Force -File -ErrorAction SilentlyContinue)
  $size = ($files | Measure-Object Length -Sum).Sum
  if (-not $size) { $size = 0 }
  $types = @{}
  foreach ($f in $files) {
    $ext = $f.Extension.ToLower()
    if (-not $ext) { $ext = "(no ext)" }
    if (-not $types.ContainsKey($ext)) { $types[$ext] = 0 }
    $types[$ext]++
  }
  $sessions = @()
  if (Test-Command "opencode") {
    $sessions = @(Get-ProjectSessions -Dir $Path)
  }
  return @{
    FileCount = $files.Count
    Size = $size
    Types = $types
    SessionCount = $sessions.Count
  }
}

function Projects-Inspect {
  param([string]$Root)
  $folders = @(Get-ProjectFolder $Root)
  if ($folders.Count -eq 0) {
    Write-Title "Inspect Project"
    Write-Host ""
    Write-Note "No projects to inspect." $C_Warn
    Pause-Menu
    return
  }
  $chosen = Show-ProjectPicker -Folders $folders -Title "Inspect a Project" -Heading "Choose a project to inspect:"
  if (-not $chosen) { return }
  
  Write-Title "Project Details"
  Write-Note "Analyzing project..." $C_Hint
  $stats = Get-ProjectStats -Path $chosen.FullName
  $git = Get-ProjectGitStatus -Path $chosen.FullName
  
  Write-Host ""
  Write-Host "   Name: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $chosen.Name -ForegroundColor $C_Label
  Write-Host "   Path: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $chosen.FullName -ForegroundColor $C_Hint
  Write-Host "   Size: " -NoNewline -ForegroundColor $C_Hint
  Write-Host "$([math]::Round($stats.Size / 1MB, 2)) MB" -ForegroundColor $C_Label
  Write-Host "   Files: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $stats.FileCount -ForegroundColor $C_Label
  Write-Host "   Modified: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $chosen.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor $C_Label
  Write-Host "   Sessions: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $stats.SessionCount -ForegroundColor $C_Label
  
  if ($git) {
    Write-Host ""
    Write-Host "   Git Status:" -ForegroundColor $C_Git
    Write-Host "     Uncommitted: " -NoNewline -ForegroundColor $C_Hint
    Write-Host $git.Changes -ForegroundColor $C_Label
    Write-Host "     Ahead: " -NoNewline -ForegroundColor $C_Hint
    Write-Host $git.Ahead -ForegroundColor $C_Label
    Write-Host "     Behind: " -NoNewline -ForegroundColor $C_Hint
    Write-Host $git.Behind -ForegroundColor $C_Label
  }
  
  Write-Host ""
  Write-Host "   File Types:" -ForegroundColor $C_Hint
  $top = $stats.Types.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
  foreach ($t in $top) {
    Write-Host "     $($t.Key): " -NoNewline -ForegroundColor $C_Hint
    Write-Host $t.Value -ForegroundColor $C_Label
  }
  
  Pause-Menu
}

# ----- Phase 4: Project Statistics -------------------------------------------

function Projects-Statistics {
  param([string]$Root)
  Write-Title "Project Statistics"
  Write-Note "Analyzing all projects..." $C_Hint
  
  $folders = @(Get-ProjectFolder $Root)
  if ($folders.Count -eq 0) {
    Write-Host ""
    Write-Note "No projects to analyze." $C_Warn
    Pause-Menu
    return
  }
  
  $totalSize = 0
  $totalFiles = 0
  $withSessions = 0
  $largest = $null
  $largestSize = 0
  $newest = $null
  $newestTime = [DateTime]::MinValue
  
  foreach ($f in $folders) {
    $files = @(Get-ChildItem $f.FullName -Recurse -Force -File -ErrorAction SilentlyContinue)
    $size = ($files | Measure-Object Length -Sum).Sum
    if (-not $size) { $size = 0 }
    $totalSize += $size
    $totalFiles += $files.Count
    
    if ($size -gt $largestSize) {
      $largestSize = $size
      $largest = $f
    }
    
    if ($f.LastWriteTime -gt $newestTime) {
      $newestTime = $f.LastWriteTime
      $newest = $f
    }
    
    if (Test-Command "opencode") {
      $sessions = @(Get-ProjectSessions -Dir $f.FullName)
      if ($sessions.Count -gt 0) { $withSessions++ }
    }
  }
  
  Write-Host ""
  Write-Host "   Total Projects: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $folders.Count -ForegroundColor $C_Label
  Write-Host "   Total Size: " -NoNewline -ForegroundColor $C_Hint
  Write-Host "$([math]::Round($totalSize / 1GB, 2)) GB" -ForegroundColor $C_Label
  Write-Host "   Total Files: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $totalFiles -ForegroundColor $C_Label
  Write-Host "   With Sessions: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $withSessions -ForegroundColor $C_Label
  Write-Host "   Never Opened: " -NoNewline -ForegroundColor $C_Hint
  Write-Host ($folders.Count - $withSessions) -ForegroundColor $C_Warn
  
  if ($largest) {
    Write-Host ""
    Write-Host "   Largest Project:" -ForegroundColor $C_Hint
    Write-Host "     $($largest.Name)" -NoNewline -ForegroundColor $C_Label
    Write-Host " - $([math]::Round($largestSize / 1MB, 1)) MB" -ForegroundColor $C_Hint
  }
  
  if ($newest) {
    Write-Host ""
    Write-Host "   Most Recent:" -ForegroundColor $C_Hint
    Write-Host "     $($newest.Name)" -NoNewline -ForegroundColor $C_Label
    Write-Host " - $($newest.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor $C_Hint
  }
  
  Pause-Menu
}

function Complete-IndexKey {
  # Turns an already-read key into a list index. Accepts 1-9, or two digits for
  # lists longer than nine, by peeking for an already-buffered second key so a
  # single press still returns immediately.
  param([string]$FirstKey)
  if ($FirstKey -eq "ESC") { return -1 }
  $s = $FirstKey
  if ($s -notmatch '[0-9]') { return -1 }
  try {
    if ([Console]::KeyAvailable) {
      $k2 = [Console]::ReadKey($true)
      $s2 = [string]$k2.KeyChar
      if ($s2 -match '[0-9]') { $s = $s + $s2 }
    }
  } catch {}
  $n = 0
  if ([int]::TryParse($s, [ref]$n)) { return $n }
  return -1
}

function Write-ProjectRow {
  param($Folder, [int]$Index, [switch]$ShowGit, [switch]$ShowIndicators)
  
  # Build the line parts
  Write-Host "   [" -NoNewline -ForegroundColor $C_Section
  Write-Host $Index -NoNewline -ForegroundColor $C_Key
  Write-Host "] " -NoNewline -ForegroundColor $C_Section
  
  # Show favorite star
  if ($ShowIndicators -and (Test-IsFavorite $Folder.FullName)) {
    Write-Host "$([char]0x2605) " -NoNewline -ForegroundColor $C_Favorite
  }
  
  Write-Host $Folder.Name -NoNewline -ForegroundColor $C_Label
  
  # Show git status if enabled
  if ($ShowGit) {
    $git = Get-ProjectGitStatus -Path $Folder.FullName
    if ($git) {
      $indicator = Format-GitIndicator $git
      if ($indicator) {
        Write-Host " $indicator" -NoNewline -ForegroundColor $C_Git
      }
    }
  }
  
  # Show item count and date
  $count = @(Get-ChildItem $Folder.FullName -Force -ErrorAction SilentlyContinue).Count
  Write-Host ("    {0} items, {1}" -f $count, $Folder.LastWriteTime.ToString("yyyy-MM-dd HH:mm")) -ForegroundColor $C_Hint
}

function Show-ProjectPicker {
  # Draws a paginated (9 per page) numbered project list and returns the chosen
  # folder, or $null if cancelled with ESC. Keys are always 1-9: the page never
  # lists more than nine rows, so two-digit entry is not accepted.
  param([object[]]$Folders, [string]$Title, [string]$Heading, [switch]$ShowIndicators)
  if (-not $Folders -or $Folders.Count -eq 0) { return $null }
  $pageSize = $script:ProjectsPageSize
  $page = 0
  while ($true) {
    Write-Title $Title
    Write-Host ""
    Write-Note $Heading $C_Hint
    Write-Host ""

    $totalPages = [Math]::Max(1, [int][Math]::Ceiling($Folders.Count / $pageSize))
    if ($page -ge $totalPages) { $page = $totalPages - 1 }
    if ($page -lt 0) { $page = 0 }

    $start = $page * $pageSize
    $end = [Math]::Min($start + $pageSize - 1, $Folders.Count - 1)
    $slice = @($Folders[$start..$end])

    for ($i = 0; $i -lt $slice.Count; $i++) {
      Write-ProjectRow $slice[$i] ($i + 1) -ShowIndicators:$ShowIndicators
    }

    if ($totalPages -gt 1) {
      Write-Host ""
      if ($page -gt 0) { Write-Host '   [<] Previous Page' -NoNewline -ForegroundColor $C_Section }
      if ($page -lt $totalPages - 1) {
        if ($page -gt 0) { Write-Host "     " -NoNewline }
        Write-Host '[>] Next Page' -ForegroundColor $C_Section
      } else { Write-Host "" }
    }
    Write-Back

    $k = Read-MenuKey
    if ($k -eq "ESC") { return $null }
    if ($k -match '^[1-9]$') {
      $n = [int]$k
      if ($n -ge 1 -and $n -le $slice.Count) { return $slice[$n - 1] }
      continue
    }
    if ($k -eq ">" -or $k -eq ".") { if ($page -lt $totalPages - 1) { $page++ }; continue }
    if ($k -eq "<" -or $k -eq ",") { if ($page -gt 0) { $page-- }; continue }
  }
}

function Set-ProjectsDirInteractive {
  # Asks for the Default Working Directory, offering to create it if missing.
  Write-Title "Default Working Directory"
  Write-Note "One folder that holds all your project folders." $C_Hint
  Write-Note "The [P] Projects menu simply lists whatever is inside it." $C_Hint
  $current = Get-ProjectsDir
  if ($current) {
    Write-Host ""
    Write-Note "Current: $current" $C_Label
  }
  Write-Host ""
  $p = Read-Host "   Folder path (Enter to cancel)"
  if ([string]::IsNullOrWhiteSpace($p)) { Pause-Menu; return $false }
  $p = $p.Trim().Trim('"')

  if (-not (Test-Path $p)) {
    Write-Host ""
    Write-Note "That folder does not exist yet: $p" $C_Warn
    $make = Read-Host "   Create it? Type YES"
    if ($make -eq "YES") {
      try {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
        [void](Set-ProjectsDir $p)
        Write-Note "Now using: $p" $C_Good
        Pause-Menu
        return $true
      } catch {
        Write-Host ""
        Write-Note "Could not create it: $($_.Exception.Message)" $C_Bad
      }
    }
    Pause-Menu
    return $false
  }
  if (-not (Test-Path $p -PathType Container)) {
    Write-Host ""
    Write-Note "That is a file, not a folder." $C_Bad
    Pause-Menu
    return $false
  }
  [void](Set-ProjectsDir $p)
  Write-Note "Now using: $p" $C_Good
  Pause-Menu
  return $true
}

# ----- Phase 1: Search Projects ----------------------------------------------

function Projects-Search {
  param([string]$Root)
  Write-Title "Search Projects"
  Write-Host ""
  $query = Read-Host "   Search (Enter to cancel)"
  if ([string]::IsNullOrWhiteSpace($query)) { return }
  
  $folders = @(Get-ProjectFolder $Root)
  $matches = @($folders | Where-Object { $_.Name -like "*$query*" })
  
  if ($matches.Count -eq 0) {
    Write-Host ""
    Write-Note "No projects match '$query'." $C_Warn
    Pause-Menu
    return
  }
  
  $chosen = Show-ProjectPicker -Folders $matches -Title "Search Results" -Heading "Found $($matches.Count) project(s) matching '$query':" -ShowIndicators
  if ($chosen) { Open-Project -Dir $chosen.FullName }
}

# ----- Phase 2: Quick Actions ------------------------------------------------

function Show-ProjectActions {
  param($Folder)
  
  while ($true) {
    Write-Title "Project Actions"
    Write-Host "   Project: " -NoNewline -ForegroundColor $C_Hint
    Write-Host $Folder.Name -ForegroundColor $C_Label
    Write-Host ""
    Write-Item "O" "Open in OpenCode"       "open with session selection"
    Write-Item "E" "Open in Explorer"       "file manager"
    Write-Item "T" "Open in Terminal"       "PowerShell window"
    if (Test-Command "code") {
      Write-Item "V" "Open in VS Code"      "if installed"
    }
    Write-Item "I" "Inspect project"        "show details"
    Write-Item "*" "Toggle favorite"        (if (Test-IsFavorite $Folder.FullName) { "remove star" } else { "add star" })
    Write-Item "R" "Rename"                 "change folder name"
    Write-Item "D" "Delete"                 "to Recycle Bin"
    Write-Back
    
    $k = Read-MenuKey
    if ($k -eq "ESC") { return }
    
    switch ($k) {
      "O" {
        Open-Project -Dir $Folder.FullName
        return
      }
      "E" {
        Start-Process "explorer.exe" -ArgumentList $Folder.FullName
        return
      }
      "T" {
        Start-Process "powershell" -ArgumentList "-NoExit", "-Command", "cd '$($Folder.FullName)'"
        return
      }
      "V" {
        if (Test-Command "code") {
          Start-Process "code" -ArgumentList $Folder.FullName
          return
        }
      }
      "I" {
        Show-ProjectDetails -Folder $Folder
      }
      "*" {
        $added = Toggle-ProjectFavorite -Path $Folder.FullName
        Write-Host ""
        if ($added) {
          Write-Note "Added to favorites." $C_Good
        } else {
          Write-Note "Removed from favorites." $C_Hint
        }
        Start-Sleep -Milliseconds 800
      }
      "R" {
        # Return to rename flow
        return "RENAME"
      }
      "D" {
        # Return to delete flow
        return "DELETE"
      }
    }
  }
}

function Show-ProjectDetails {
  param($Folder)
  
  Write-Title "Project Details"
  Write-Note "Analyzing..." $C_Hint
  $stats = Get-ProjectStats -Path $Folder.FullName
  $git = Get-ProjectGitStatus -Path $Folder.FullName
  
  Write-Host ""
  Write-Host "   Name: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $Folder.Name -ForegroundColor $C_Label
  Write-Host "   Path: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $Folder.FullName -ForegroundColor $C_Hint
  Write-Host "   Size: " -NoNewline -ForegroundColor $C_Hint
  Write-Host "$([math]::Round($stats.Size / 1MB, 2)) MB" -ForegroundColor $C_Label
  Write-Host "   Files: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $stats.FileCount -ForegroundColor $C_Label
  Write-Host "   Modified: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $Folder.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") -ForegroundColor $C_Label
  Write-Host "   Sessions: " -NoNewline -ForegroundColor $C_Hint
  Write-Host $stats.SessionCount -ForegroundColor $C_Label
  
  if ($git) {
    Write-Host ""
    Write-Host "   Git Status:" -ForegroundColor $C_Git
    Write-Host "     Uncommitted: " -NoNewline -ForegroundColor $C_Hint
    Write-Host $git.Changes -ForegroundColor $C_Label
    Write-Host "     Ahead: " -NoNewline -ForegroundColor $C_Hint
    Write-Host $git.Ahead -ForegroundColor $C_Label
    Write-Host "     Behind: " -NoNewline -ForegroundColor $C_Hint
    Write-Host $git.Behind -ForegroundColor $C_Label
  }
  
  Write-Host ""
  Write-Host "   Top File Types:" -ForegroundColor $C_Hint
  $top = $stats.Types.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
  foreach ($t in $top) {
    Write-Host "     $($t.Key): " -NoNewline -ForegroundColor $C_Hint
    Write-Host $t.Value -ForegroundColor $C_Label
  }
  
  Pause-Menu
}

# ----- Phase 3: Help ---------------------------------------------------------

function Show-ProjectsHelp {
  Write-Title "Projects Menu Help"
  Write-Host ""
  Write-Host "   NAVIGATION:" -ForegroundColor $C_Section
  Write-Note "  1-9        Open project by number (max 9 per page)"
  Write-Note "  > or .     Next page"
  Write-Note "  < or ,     Previous page"
  Write-Host ""
  Write-Host "   ACTIONS:" -ForegroundColor $C_Section
  Write-Note "  /          Search for a project by name"
  Write-Note "  *          Toggle favorite on selected project"
  Write-Note "  N          Create new project folder"
  Write-Note "  R          Rename a project"
  Write-Note "  D          Delete a project (to Recycle Bin)"
  Write-Note "  I          Inspect project details"
  Write-Note "  T          View statistics for all projects"
  Write-Note "  W          Change working folder"
  Write-Note "  G          Toggle Git status indicators"
  Write-Note "  ESC        Back to main menu"
  Write-Host ""
  Write-Host "   TIPS:" -ForegroundColor $C_Section
  Write-Note "  $([char]0x2605) = Favorite project"
  Write-Note "  [$([char]0x25CF)2] = 2 uncommitted changes"
  Write-Note "  [$([char]0x2191)1] = 1 commit ahead of remote"
  Write-Note "  [$([char]0x2193)1] = 1 commit behind remote"
  Pause-Menu
}

function Projects-New {
  param([string]$Root)
  Write-Title "New Project Folder"
  Write-Note "Created inside: $Root" $C_Hint
  Write-Host ""
  $name = Read-Host "   Folder name"
  $err = Test-ValidProjectName $name $Root
  if ($err) {
    Write-Host ""
    Write-Note $err $C_Bad
    Pause-Menu
    return
  }
  $target = Join-Path $Root $name.Trim()
  try {
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Invalidate-ProjectCache
  } catch {
    Write-Host ""
    Write-Note "Could not create it: $($_.Exception.Message)" $C_Bad
    Pause-Menu
    return
  }
  Write-Host ""
  Write-Note "Created: $target" $C_Good
  Write-Host ""
  $go = Read-Host "   Open it in OpenCode now? Type YES"
  if ($go -eq "YES") {
    Invoke-OpenCode -Arguments @($target) -Dir $target
  } else {
    Pause-Menu
  }
}

function Projects-Rename {
  param([string]$Root)
  $folders = @(Get-ProjectFolder $Root)
  if ($folders.Count -eq 0) {
    Write-Title "Rename a Project Folder"
    Write-Host ""
    Write-Note "No project folders to rename." $C_Warn
    Pause-Menu
    return
  }
  Write-Title "Rename a Project Folder"
  $chosen = Show-ProjectPicker -Folders $folders -Title "Rename a Project Folder" -Heading "Choose the project to rename:"
  if (-not $chosen) { return }
  Write-Host ""
  $name = Read-Host ("   New name for '" + $chosen.Name + "'")
  $err = Test-ValidProjectName $name $Root
  if ($err) {
    Write-Host ""
    Write-Note $err $C_Bad
    Pause-Menu
    return
  }
  try {
    Rename-Item -LiteralPath $chosen.FullName -NewName $name.Trim() -ErrorAction Stop
    Invalidate-ProjectCache
    Write-Host ""
    Write-Note ("Renamed '{0}' to '{1}'." -f $chosen.Name, $name.Trim()) $C_Good
  } catch {
    Write-Host ""
    Write-Note "Could not rename it: $($_.Exception.Message)" $C_Bad
  }
  Pause-Menu
}

function Move-ToRecycleBin {
  # Returns $true on success. Throws if the Recycle Bin cannot be used, rather
  # than silently deleting for good.
  param([string]$Path)
  Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue
  [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
    $Path,
    [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
    [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin,
    [Microsoft.VisualBasic.FileIO.UICancelOption]::DoNothing)
  return (-not (Test-Path $Path))
}

function Test-SafeToDeleteProject {
  # Returns a reason string if the folder must not be deleted, or $null if it
  # is safe. Protects the launcher's own folder (and any folder containing it,
  # such as a source checkout's parent).
  param([string]$Path)
  if (-not $Path) { return "No folder given." }
  $launcherPath = ConvertTo-ComparablePath $LauncherDir
  $targetPath  = ConvertTo-ComparablePath $Path
  if (-not $targetPath) { return "No folder given." }
  if ($targetPath -eq $launcherPath) {
    return "That is the folder the launcher is running from ($LauncherDir)."
  }
  if ($launcherPath.StartsWith($targetPath + "\", [StringComparison]::OrdinalIgnoreCase)) {
    return "That folder contains the running launcher ($LauncherDir)."
  }
  return $null
}

function Projects-Delete {
  param([string]$Root)
  $folders = @(Get-ProjectFolder $Root)
  if ($folders.Count -eq 0) {
    Write-Title "Delete a Project Folder"
    Write-Host ""
    Write-Note "No project folders to delete." $C_Warn
    Pause-Menu
    return
  }
  Write-Title "Delete a Project Folder"
  $chosen = Show-ProjectPicker -Folders $folders -Title "Delete a Project Folder" -Heading "Choose the project to delete:"
  if (-not $chosen) { return }

  # Never delete the launcher itself, or a folder that contains it.
  $unsafe = Test-SafeToDeleteProject $chosen.FullName
  if ($unsafe) {
    Write-Host ""
    Write-Note "Refusing to delete that project." $C_Bad
    Write-Note $unsafe $C_Hint
    Pause-Menu
    return
  }

  $files = @(Get-ChildItem $chosen.FullName -Recurse -Force -File -ErrorAction SilentlyContinue)
  $size = ($files | Measure-Object Length -Sum).Sum
  if (-not $size) { $size = 0 }
  Write-Host ""
  Write-Note "Folder : $($chosen.FullName)" $C_Label
  Write-Note "Contents: $($files.Count) files, $([math]::Round($size / 1MB, 1)) MB" $C_Label
  Write-Note "Changed : $($chosen.LastWriteTime)" $C_Label
  Write-Host ""
  Write-Note "This moves the folder to the Recycle Bin, so it can be undone." $C_Warn
  Write-Note "Windows deletes it for good if the Recycle Bin is off or full." $C_Hint
  Write-Host ""
  $ans = Read-Host ("   Type DELETE to send '" + $chosen.Name + "' to the Recycle Bin")
  if ($ans -ne "DELETE") {
    Write-Host ""
    Write-Note "Cancelled." $C_Hint
    Pause-Menu
    return
  }

  try {
    if (Move-ToRecycleBin $chosen.FullName) {
      Invalidate-ProjectCache
      Write-Host ""
      Write-Note ("'{0}' moved to the Recycle Bin." -f $chosen.Name) $C_Good
      Pause-Menu
    } else {
      Write-Host ""
      Write-Note "The folder is still there; nothing was deleted." $C_Warn
      Pause-Menu
    }
  } catch {
    Write-Host ""
    Write-Note "The Recycle Bin could not be used: $($_.Exception.Message)" $C_Bad
    Write-Note "Nothing was deleted." $C_Good
    Pause-Menu
  }
}

function Show-ProjectsMenu {
  $root = Get-ProjectsDir
  if (-not $root) {
    # First run: there is no Default Working Directory yet, so ask for one.
    if (-not (Set-ProjectsDirInteractive)) { return }
    $root = Get-ProjectsDir
    if (-not $root) { return }
  }

  $script:ProjectsPage = 0
  $showGit = $false

  while ($true) {
    Write-Title "Projects"
    Write-Host "   Working folder " -NoNewline -ForegroundColor $C_Hint
    Write-Host $root -ForegroundColor $C_Label
    
    # Get all folders and apply favorites sorting
    $allFolders = @(Get-ProjectFolder $root)
    $favs = @(Get-FavoriteProjects)
    $favorites = @($allFolders | Where-Object { Test-IsFavorite $_.FullName })
    $regular = @($allFolders | Where-Object { -not (Test-IsFavorite $_.FullName) })
    $folders = @($favorites) + @($regular)
    
    if ($folders.Count -eq 0) {
      Write-Host ""
      Write-Note "Nothing in here yet - press [N] to create a project." $C_Warn
    } else {
      # Calculate pagination
      $totalPages = [Math]::Ceiling($folders.Count / $script:ProjectsPageSize)
      if ($script:ProjectsPage -ge $totalPages) { $script:ProjectsPage = $totalPages - 1 }
      if ($script:ProjectsPage -lt 0) { $script:ProjectsPage = 0 }
      
      $start = $script:ProjectsPage * $script:ProjectsPageSize
      $end = [Math]::Min($start + $script:ProjectsPageSize - 1, $folders.Count - 1)
      $pageProjects = @($folders[$start..$end])
      
      # Show recent projects if on first page
      if ($script:ProjectsPage -eq 0) {
        $recent = @(Get-RecentProjects)
        if ($recent.Count -gt 0) {
          Write-Section "RECENT"
          $displayed = 0
          foreach ($r in $recent) {
            if ($displayed -ge 3) { break }
            $folder = Get-Item $r.path -ErrorAction SilentlyContinue
            if ($folder) {
              $when = Format-RelativeTime $r.opened
              Write-Host "     " -NoNewline
              Write-Host $folder.Name -NoNewline -ForegroundColor $C_Recent
              Write-Host "  ($when)" -ForegroundColor $C_Hint
              $displayed++
            }
          }
        }
      }
      
      # Show projects
      Write-Section "PROJECTS $(if ($totalPages -gt 1) { "- Page $($script:ProjectsPage + 1) of $totalPages" })"
      for ($i = 0; $i -lt $pageProjects.Count; $i++) {
        Write-ProjectRow $pageProjects[$i] ($i + 1) -ShowGit:$showGit -ShowIndicators
      }
      
      # Pagination controls
      if ($totalPages -gt 1) {
        Write-Host ""
        if ($script:ProjectsPage -gt 0) {
          Write-Host '   [<] Previous Page' -NoNewline -ForegroundColor $C_Section
        }
        if ($script:ProjectsPage -lt $totalPages - 1) {
          if ($script:ProjectsPage -gt 0) { Write-Host "     " -NoNewline }
          Write-Host '[>] Next Page' -ForegroundColor $C_Section
        } else {
          Write-Host ""
        }
      }
    }
    
    Write-Section "ACTIONS"
    Write-Item "/" "Search projects"         "find by name"
    Write-Item "N" "New project folder"      "create a folder here"
    Write-Item "R" "Rename a project"        "rename the folder"
    Write-Item "D" "Delete a project"        "to the Recycle Bin"
    Write-Item "I" "Inspect a project"       "show details"
    Write-Item "T" "Statistics"              "all projects summary"
    Write-Item "G" "Toggle Git indicators"   (if ($showGit) { "hide" } else { "show" })
    Write-Item "W" "Set the working folder"  "where projects live"
    Write-Item "?" "Help"                    "keyboard shortcuts"
    Write-Back

    $k = Read-MenuKey
    if ($k -eq "ESC") { return }
    
    switch ($k) {
      "/"   { Projects-Search $root; Invalidate-ProjectCache; continue }
      "N"   { Projects-New $root; continue }
      "R"   { Projects-Rename $root; continue }
      "D"   { Projects-Delete $root; continue }
      "I"   { Projects-Inspect $root; continue }
      "T"   { Projects-Statistics $root; continue }
      "G"   { $showGit = -not $showGit; continue }
      "W"   { [void](Set-ProjectsDirInteractive); $root = Get-ProjectsDir; Invalidate-ProjectCache; continue }
      "?"   { Show-ProjectsHelp; continue }
      ">"   { if ($script:ProjectsPage -lt ([Math]::Ceiling($folders.Count / $script:ProjectsPageSize) - 1)) { $script:ProjectsPage++; continue } }
      "<"   { if ($script:ProjectsPage -gt 0) { $script:ProjectsPage--; continue } }
      "."   { if ($script:ProjectsPage -lt ([Math]::Ceiling($folders.Count / $script:ProjectsPageSize) - 1)) { $script:ProjectsPage++; continue } }
      ","   { if ($script:ProjectsPage -gt 0) { $script:ProjectsPage--; continue } }
    }
    
    # A number loads that project: offer its sessions or quick actions.
    # The page lists at most nine rows, so keys are 1-9 only.
    if ($k -match '^[1-9]$') {
      $n = [int]$k
      if ($n -ge 1 -and $n -le $pageProjects.Count) {
        $chosen = $pageProjects[$n - 1]
        # Show quick actions menu
        $action = Show-ProjectActions -Folder $chosen
        if ($action -eq "RENAME") {
          Projects-Rename $root
        } elseif ($action -eq "DELETE") {
          Projects-Delete $root
        }
      }
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
    
    # Show recent projects
    $recent = @(Get-RecentProjects)
    if ($recent.Count -gt 0) {
      Write-Section "RECENT PROJECTS"
      $shown = [Math]::Min($recent.Count, 5)
      for ($i = 0; $i -lt $shown; $i++) {
        $r = $recent[$i]
        $folder = Get-Item $r.path -ErrorAction SilentlyContinue
        if ($folder) {
          $when = Format-RelativeTime $r.opened
          Write-Host "   [" -NoNewline -ForegroundColor $C_Section
          Write-Host ($i + 1) -NoNewline -ForegroundColor $C_Key
          Write-Host "] " -NoNewline -ForegroundColor $C_Section
          Write-Host $folder.Name -NoNewline -ForegroundColor $C_Recent
          Write-Host "  ($when)" -ForegroundColor $C_Hint
        }
      }
    }
    
    Write-Section "START"
    Write-Item "R" "Run OpenCode here"            "this folder"
    Write-Item "C" "Resume last session"          "picks up where you left off"
    Write-Item "F" "Open a folder..."             "choose a project folder"
    Write-Item "S" "Open web interface"           "opencode web"
    Write-Section "PROJECTS"
    Write-Item "P" "Pick a project..."            "from your working folder"
    Write-Item "W" "Set the working folder..."    "where projects live"
    Write-Section "MANAGE"
    Write-Item "M" "Manage"                       "update, back up, restore..."
    Write-Section "EXIT"
    Write-Item "Q" "Quit"
    Write-Host ""

    $k = Read-MenuKey
    
    # Handle recent project selection (1-5)
    if ($recent.Count -gt 0 -and $k -match '^[1-5]$') {
      $idx = [int]$k - 1
      if ($idx -lt $recent.Count) {
        $r = $recent[$idx]
        if (Test-Path $r.path -PathType Container) {
          Open-Project -Dir $r.path
          continue
        }
      }
    }
    
    switch ($k) {
      "R"   { Action-Run }
      "C"   { Action-Continue }
      "F"   { Action-Folder }
      "S"   { Action-Web }
      "P"   { Show-ProjectsMenu }
      "W"   { [void](Set-ProjectsDirInteractive) }
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
