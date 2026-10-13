<#
  launcher.Tests.ps1 - regression tests for the OpenCode Launcher.

  Run with:
      Invoke-Pester .\tests\launcher.Tests.ps1

  These cover the bugs that actually shipped:
    - Write-OcShim emitted a malformed 3->5 line shim (comma binds tighter than '+')
    - Uninstall could delete a git checkout (.git included)
    - Uninstall removed $LauncherDir from PATH instead of $ShimDir
    - PATH membership was case/trailing-slash sensitive
    - $LauncherVersion and VERSION could drift apart
    - non-ASCII install paths were silently mangled in the shim
    - a corrupt or stale status cache was trusted

  Assertions are plain functions rather than Pester's Should operators: those
  changed syntax between Pester 3 (`Should Be`) and Pester 5 (`Should -Be`),
  and this suite has to run on both - Windows PowerShell 5.1 ships Pester 3.4.
  A throwing assertion still fails the enclosing It block on any version.
#>

$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $RepoRoot 'opencode-launcher.ps1') -NoMenu

# Redirect the status cache to a scratch path so tests never touch the real one.
$StatusCachePath = Join-Path $env:TEMP 'oc-launcher-test-status.json'
Remove-Item $StatusCachePath -Force -ErrorAction SilentlyContinue

function Assert-Equal($actual, $expected, $what) {
  if ($actual -ne $expected) {
    throw "$what -- expected <$expected> but got <$actual>"
  }
}

function Assert-True($condition, $what) {
  if (-not $condition) { throw "$what -- expected true" }
}

function Assert-Match($value, $pattern, $what) {
  if ($value -notmatch $pattern) {
    throw "$what -- <$value> does not match /$pattern/"
  }
}

Describe "Repository files" {
  It "parses without syntax errors" {
    foreach ($f in @('opencode-launcher.ps1', 'opencode-backup.ps1', 'install.ps1', 'run.ps1')) {
      $errors = $null
      [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $RepoRoot $f), [ref]$null, [ref]$errors) | Out-Null
      Assert-Equal ($errors | Measure-Object).Count 0 "$f syntax errors"
    }
  }

  It "reports the same version in the launcher and in VERSION" {
    $declared = ((Select-String -Path (Join-Path $RepoRoot 'opencode-launcher.ps1') `
      -Pattern '^\$LauncherVersion\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value)
    $onDisk = (Get-Content (Join-Path $RepoRoot 'VERSION') -Raw).Trim()
    Assert-Equal $onDisk $declared 'VERSION vs $LauncherVersion'
  }

  It "keeps .cmd and .bat files on CRLF" {
    # raw.githubusercontent.com serves the committed bytes verbatim, so these
    # must be stored CRLF or cmd's goto/labels break.
    foreach ($f in (Get-ChildItem $RepoRoot -Include '*.cmd', '*.bat' -Recurse -File)) {
      $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
      for ($i = 0; $i -lt $bytes.Length; $i++) {
        if ($bytes[$i] -eq 10) {
          Assert-True ($i -gt 0 -and $bytes[$i - 1] -eq 13) "$($f.Name) contains a bare LF"
        }
      }
    }
  }
}

Describe "Write-OcShim" {
  It "writes exactly three lines" {
    # Regression: building the run line inline inside @(...) split it into five
    # array elements because ',' binds tighter than '+' in PowerShell.
    $ShimDir = Join-Path $env:TEMP 'oc-shim-test'
    $ShimPath = Join-Path $ShimDir 'oc.cmd'
    $LauncherDir = $RepoRoot
    Write-OcShim
    Assert-Equal @(Get-Content $ShimPath).Count 3 'shim line count'
    Remove-Item $ShimDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  It "keeps the -File path and %* on one unbroken line" {
    $ShimDir = Join-Path $env:TEMP 'oc-shim-test'
    $ShimPath = Join-Path $ShimDir 'oc.cmd'
    $LauncherDir = $RepoRoot
    Write-OcShim
    Assert-Match (Get-Content $ShimPath -Raw) '-File "[^"]+\.ps1" %\*' 'shim run line'
    Remove-Item $ShimDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  It "uses %LOCALAPPDATA% and stays pure ASCII for the default install folder" {
    $ShimDir = Join-Path $env:TEMP 'oc-shim-test'
    $ShimPath = Join-Path $ShimDir 'oc.cmd'
    $LauncherDir = Join-Path $env:LOCALAPPDATA 'OpenCodeLauncher'
    Write-OcShim
    Assert-Match (Get-Content $ShimPath -Raw) '%LOCALAPPDATA%\\OpenCodeLauncher\\opencode-launcher\.ps1' 'shim target'
    foreach ($b in [System.IO.File]::ReadAllBytes($ShimPath)) {
      Assert-True ($b -le 127) "shim byte $b is not ASCII"
    }
    Remove-Item $ShimDir -Recurse -Force -ErrorAction SilentlyContinue
  }

  It "writes CRLF line endings" {
    $ShimDir = Join-Path $env:TEMP 'oc-shim-test'
    $ShimPath = Join-Path $ShimDir 'oc.cmd'
    $LauncherDir = $RepoRoot
    Write-OcShim
    Assert-True ([System.IO.File]::ReadAllBytes($ShimPath) -contains 13) 'shim has CRLF'
    Remove-Item $ShimDir -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe "Uninstall safety" {
  It "detects a git checkout so uninstall can refuse to delete it" {
    # Regression: Remove-Item -Recurse -Force on $PSScriptRoot used to take
    # .git, README and LICENSE with it when run from the source folder.
    Assert-Equal (Get-SourceCheckoutMarker) '.git' 'git checkout marker'
  }

  It "reports nothing for an installed folder holding only launcher files" {
    $saved = $LauncherDir
    $LauncherDir = Join-Path $env:TEMP 'oc-clean-install'
    New-Item -ItemType Directory $LauncherDir -Force | Out-Null
    foreach ($f in $UpdateFiles) { New-Item -ItemType File (Join-Path $LauncherDir $f) -Force | Out-Null }
    Assert-Equal @(Get-UnexpectedLauncherItems).Count 0 'unexpected items'
    Assert-Equal ([string](Get-SourceCheckoutMarker)) '' 'checkout markers'
    Remove-Item $LauncherDir -Recurse -Force -ErrorAction SilentlyContinue
    $LauncherDir = $saved
  }

  It "lists files the launcher did not create" {
    $saved = $LauncherDir
    $LauncherDir = Join-Path $env:TEMP 'oc-mixed-install'
    New-Item -ItemType Directory $LauncherDir -Force | Out-Null
    foreach ($f in $UpdateFiles) { New-Item -ItemType File (Join-Path $LauncherDir $f) -Force | Out-Null }
    New-Item -ItemType File (Join-Path $LauncherDir 'my-notes.txt') -Force | Out-Null
    Assert-Equal @(Get-UnexpectedLauncherItems).Count 1 'unexpected item count'
    Remove-Item $LauncherDir -Recurse -Force -ErrorAction SilentlyContinue
    $LauncherDir = $saved
  }
}

Describe "PATH normalisation" {
  It "strips trailing backslashes" {
    Assert-Equal (ConvertTo-ComparablePath 'C:\Users\Wayne\.local\bin\') 'C:\Users\Wayne\.local\bin' 'trailing slash'
  }

  It "resolves relative and dotted forms to the same value" {
    Assert-Equal (ConvertTo-ComparablePath '.\bin') (ConvertTo-ComparablePath 'bin') 'dotted path'
  }

  It "compares case-insensitively" {
    # Regression: ($p -split ";") -contains $Dir was case sensitive, so [O]
    # appended a duplicate PATH entry on every run.
    Assert-Equal (ConvertTo-ComparablePath 'C:\Users\Wayne\.local\BIN') `
                 (ConvertTo-ComparablePath 'C:\Users\Wayne\.local\bin') 'case-insensitive compare'
  }

  It "returns empty for blank input" {
    Assert-Equal (ConvertTo-ComparablePath '   ') '' 'blank input'
  }
}

Describe "Backup preflight (opencode must be closed)" {
  It "finds no processes for a name that does not exist" {
    # Deliberately a name nothing matches, so running this test can never
    # stop the opencode session the suite itself is running inside.
    Assert-Equal @(Get-OpenCodeProcess -NameFilter 'oc-no-such-process-*').Count 0 'no matches'
  }

  It "reports success immediately when nothing is running" {
    $ok = Stop-OpenCodeForBackup -NameFilter 'oc-no-such-process-*' -TimeoutSeconds 2
    Assert-Equal $ok $true 'nothing to stop'
  }

  It "returns a real list for the default filter" {
    # opencode may or may not be running; either answer is valid, but the
    # function must return a collection and must not throw.
    $p = @(Get-OpenCodeProcess)
    foreach ($proc in $p) {
      Assert-True ($proc.ProcessName -like 'opencode*') "unexpected match $($proc.ProcessName)"
    }
  }

  It "stops a matching process and waits for it to go" {
    # Uses a disposable copy of cmd.exe named so the filter matches it. This
    # exercises the real detect -> close -> force -> wait path without ever
    # touching the opencode session the suite is running inside.
    $dummy = Join-Path $env:TEMP 'opencode-testproc.exe'
    $dummyProc = $null
    try {
      Copy-Item $env:ComSpec $dummy -Force
      $dummyProc = Start-Process -FilePath $dummy -WindowStyle Hidden -PassThru `
                             -ArgumentList '/c', 'ping -n 30 127.0.0.1 >nul'
      Start-Sleep -Milliseconds 800

      Assert-True (@(Get-OpenCodeProcess -NameFilter 'opencode-testproc*').Count -ge 1) 'dummy detected'
      $ok = Stop-OpenCodeForBackup -NameFilter 'opencode-testproc*' -TimeoutSeconds 15
      Assert-Equal $ok $true 'stop reported success'
      Assert-Equal @(Get-OpenCodeProcess -NameFilter 'opencode-testproc*').Count 0 'dummy gone'
    }
    finally {
      if ($dummyProc) { Stop-Process -Id $dummyProc.Id -Force -ErrorAction SilentlyContinue }
      Remove-Item $dummy -Force -ErrorAction SilentlyContinue
    }
  }
}

Describe "Status cache" {
  It "returns nothing when there is no cache file" {
    Remove-Item $StatusCachePath -Force -ErrorAction SilentlyContinue
    Assert-Equal ([string](Read-StatusCache)) '' 'missing cache'
  }

  It "round-trips a status object" {
    $s = [pscustomobject]@{ HasOC = $true; OCVer = '2.0.0'; HasNpm = $true; Node = 'v20.0.0' }
    Write-StatusCache $s
    $r = Read-StatusCache
    Assert-Equal $r.HasOC   $true     'cached HasOC'
    Assert-Equal $r.OCVer   '2.0.0'  'cached OCVer'
    Assert-Equal $r.HasNpm  $true     'cached HasNpm'
    Assert-Equal $r.Node    'v20.0.0' 'cached Node'
  }

  It "ignores a cache older than the TTL" {
    $s = [pscustomobject]@{ HasOC = $true; OCVer = 'stale'; HasNpm = $true; Node = 'v20' }
    Write-StatusCache $s
    (Get-Item $StatusCachePath).LastWriteTime = (Get-Date).AddSeconds(-($StatusCacheTTL + 60))
    Assert-Equal ([string](Read-StatusCache)) '' 'stale cache'
  }

  It "ignores a corrupt cache file" {
    'this is not json' | Set-Content $StatusCachePath -Encoding ASCII
    Assert-Equal ([string](Read-StatusCache)) '' 'corrupt cache'
    Remove-Item $StatusCachePath -Force -ErrorAction SilentlyContinue
  }
}

Remove-Item $StatusCachePath -Force -ErrorAction SilentlyContinue