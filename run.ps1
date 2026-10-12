<#
  run.ps1 - Download and run the OpenCode Launcher menu immediately.

  One-liner:
      irm https://raw.githubusercontent.com/JagerWayne/opencode-launcher/main/run.ps1 | iex

  Unlike install.ps1, this does not create a shortcut or change your PATH - it just
  fetches the launcher and opens it. Files are cached in
  %LOCALAPPDATA%\OpenCodeLauncher so repeat runs work even if you go offline.
#>
$ErrorActionPreference = 'Stop'

try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$repo   = 'JagerWayne/opencode-launcher'
$branch = 'main'
$raw    = "https://raw.githubusercontent.com/$repo/$branch"
$dir    = Join-Path $env:LOCALAPPDATA 'OpenCodeLauncher'

New-Item -ItemType Directory -Path $dir -Force | Out-Null

foreach ($f in @('opencode-launcher.cmd', 'install-node.ps1')) {
    $out = Join-Path $dir $f
    try {
        Invoke-WebRequest -Uri "$raw/$f" -OutFile $out -UseBasicParsing
    } catch {
        if (Test-Path -LiteralPath $out) {
            Write-Host "  Offline - using cached copy of $f."
        } else {
            Write-Host "  Could not download $f and no cached copy exists." -ForegroundColor Red
            return
        }
    }
}

& (Join-Path $dir 'opencode-launcher.cmd')
