<#
  install.ps1 - Install the OpenCode Launcher locally.

  One-liner (no git required):
      irm https://raw.githubusercontent.com/JagerWayne/opencode-launcher/main/install.ps1 | iex

  Or, if you already cloned the repo:
      ./install.ps1

  Options:
      -InstallDir <path>   Where the launcher files go.
                           Default: %LOCALAPPDATA%\OpenCodeLauncher
      -BinDir <path>       Where the oc.cmd shortcut goes.
                           Default: %USERPROFILE%\.local\bin
      -Repo <owner/name>   Source repository.  Default: JagerWayne/opencode-launcher
      -Branch <name>       Source branch.      Default: main
      -NoPath              Do not modify the user PATH.
      -Launch              Run the launcher once when finished.
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA 'OpenCodeLauncher'),
    [string]$BinDir     = (Join-Path $env:USERPROFILE '.local\bin'),
    [string]$Repo       = 'JagerWayne/opencode-launcher',
    [string]$Branch     = 'main',
    [switch]$NoPath,
    [switch]$Launch
)

$ErrorActionPreference = 'Stop'

# Use TLS 1.2 for the download on older PowerShell hosts.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

function Write-Info($m) { Write-Host "  $m" }
function Write-Ok($m)   { Write-Host "  $m" -ForegroundColor Green }

$rawBase = "https://raw.githubusercontent.com/$Repo/$Branch"
$files   = @('opencode-launcher.ps1', 'opencode-backup.ps1', 'opencode-backup.cmd')

Write-Host ''
Write-Host 'OpenCode Launcher installer' -ForegroundColor Cyan
Write-Host '===========================' -ForegroundColor Cyan
Write-Host ''
Write-Info "Install folder: $InstallDir"
Write-Info "Shim folder:    $BinDir"
Write-Host ''

# 1. Create the folders if needed.
foreach ($d in @($InstallDir, $BinDir)) {
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Write-Info "Created $d"
    }
}

# 2. Download the launcher files from the repo.
foreach ($f in $files) {
    $url = "$rawBase/$f"
    $out = Join-Path $InstallDir $f
    Write-Info "Downloading $f ..."
    $text = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
    # Ensure CRLF: raw endpoints may serve LF-only, and .cmd files need CRLF.
    $text = ($text -replace "`r`n", "`n") -replace "`n", "`r`n"
    [IO.File]::WriteAllText($out, $text, (New-Object Text.UTF8Encoding($false)))
}
Write-Ok 'Launcher files downloaded.'

# 3. Create the "oc" shim pointing at the launcher.
$launcher = Join-Path $InstallDir 'opencode-launcher.ps1'
$shim     = Join-Path $BinDir 'oc.cmd'
$shimBody = @"
@echo off
rem Launches the OpenCode Launcher. Created by install.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "$launcher" %*
"@
Set-Content -LiteralPath $shim -Value $shimBody -Encoding ASCII
Write-Ok "Created shortcut: $shim"

# 4. Make sure the shim folder is on the user PATH.
if (-not $NoPath) {
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $userPath) { $userPath = '' }
    $entries = $userPath.Split(';') | Where-Object { $_ -ne '' }
    if ($entries -notcontains $BinDir) {
        [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $BinDir), 'User')
        Write-Ok "Added $BinDir to your user PATH (works in new command windows)."
    } else {
        Write-Info "$BinDir is already on PATH."
    }
    if ($env:Path.Split(';') -notcontains $BinDir) { $env:Path += ";$BinDir" }
}

Write-Host ''
Write-Ok 'Done.'
Write-Host ''
Write-Host '  Type  oc  in a command window to open the launcher.' -ForegroundColor Cyan
Write-Host ''

if ($Launch) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $launcher
}
