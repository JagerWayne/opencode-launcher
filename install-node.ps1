# ---------------------------------------------------------------------------
#  install-node.ps1
#  Fallback Node.js LTS installer for opencode-launcher.cmd.
#  Used only when winget is not available on the machine.
#  Downloads the latest LTS MSI from nodejs.org and installs it.
# ---------------------------------------------------------------------------
$ErrorActionPreference = 'Stop'

try {
    Write-Host 'Looking up the latest Node.js LTS release ...'
    $index = Invoke-RestMethod -Uri 'https://nodejs.org/dist/index.json' -UseBasicParsing
    $lts = $index | Where-Object { $_.lts } | Select-Object -First 1
    if (-not $lts) { throw 'Could not determine the latest LTS version.' }

    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $msi  = "node-$($lts.version)-$arch.msi"
    $url  = "https://nodejs.org/dist/$($lts.version)/$msi"
    $out  = Join-Path $env:TEMP $msi

    Write-Host "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing

    Write-Host 'Installing Node.js (Windows may ask for administrator permission) ...'
    $proc = Start-Process msiexec.exe `
        -ArgumentList '/i', "`"$out`"", '/qb', '/norestart' `
        -Verb RunAs -Wait -PassThru

    Remove-Item $out -ErrorAction SilentlyContinue

    if ($proc.ExitCode -ne 0) { throw "Installer exited with code $($proc.ExitCode)." }
    Write-Host 'Node.js installed.'
    exit 0
}
catch {
    Write-Host "Node.js install failed: $($_.Exception.Message)"
    exit 1
}
