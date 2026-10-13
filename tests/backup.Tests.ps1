<#
  backup.Tests.ps1 - regression tests for opencode-backup.ps1.

  Run with:
      Invoke-Pester .\tests\backup.Tests.ps1

  Covers:
    - Archives must use '/' entry separators. Windows PowerShell's
      Compress-Archive writes '\', which breaks the ZIP spec and makes every
      entry read as one flat filename on Linux, macOS and Python. Note that
      ZipFile::CreateFromDirectory is NOT a fix on .NET Framework - it also
      writes '\'. Only building the entries by hand is correct.
    - The session database must never be copied while another process holds it.
      Copying a live db + WAL interleaves pages and frames from different
      instants and produces an archive SQLite may refuse to open.
    - Restoring into a machine that has never run opencode must work.

  Plain assertion helpers (not Pester's Should operators) so the suite runs on
  both Pester 3.4 (bundled with Windows PowerShell) and Pester 5.
#>

$RepoRoot = Split-Path -Parent $PSScriptRoot

# Dot-source without running a backup: -List against an empty root returns
# immediately, after the functions are defined.
$EmptyRoot = Join-Path $env:TEMP 'oc-backup-test-empty'
Remove-Item $EmptyRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory $EmptyRoot -Force | Out-Null
. (Join-Path $RepoRoot 'opencode-backup.ps1') -List -BackupRoot $EmptyRoot

function Assert-Equal($actual, $expected, $what) {
  if ($actual -ne $expected) { throw "$what -- expected <$expected> but got <$actual>" }
}

function Assert-True($condition, $what) {
  if (-not $condition) { throw "$what -- expected true" }
}

function Assert-Throws($block, $what) {
  $threw = $false
  try { & $block } catch { $threw = $true }
  if (-not $threw) { throw "$what -- expected an error but none was thrown" }
}

# Builds a structurally valid minimal SQLite file: magic + page size + page count.
function New-TestSqliteDb {
  param([string]$Path, [int]$PageSize = 1024, [int]$Pages = 4)
  $b = New-Object byte[] ($PageSize * $Pages)
  [Array]::Copy([Text.Encoding]::ASCII.GetBytes("SQLite format 3`0"), 0, $b, 0, 16)
  $b[16] = [byte]($PageSize -shr 8); $b[17] = [byte]($PageSize -band 0xFF)
  $b[30] = [byte](($Pages -shr 8) -band 0xFF); $b[31] = [byte]($Pages -band 0xFF)
  [System.IO.File]::WriteAllBytes($Path, $b)
  return $b.Length
}

Describe "New-SpecCompliantZip" {
  It "writes '/' separators and never '\'" {
    $root = Join-Path $env:TEMP 'oc-zip-test'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    $src = Join-Path $root 'src'
    $sub = Join-Path $src 'sessions'
    New-Item -ItemType Directory $sub -Force | Out-Null
    'x' | Set-Content (Join-Path $src 'manifest.json')
    New-TestSqliteDb -Path (Join-Path $sub 'opencode.db') | Out-Null

    # Destination sits outside the source, as in real use (TEMP -> archives).
    $zip = Join-Path $root 'out.zip'
    New-SpecCompliantZip -SourceDir $src -Destination $zip

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
    try {
      Assert-True (@($z.Entries | Where-Object { $_.FullName -match '\\' }).Count -eq 0) 'no backslash entries'
      Assert-True (@($z.Entries | Where-Object { $_.FullName -match '/' }).Count -gt 0) 'has slash entries'
      $names = @($z.Entries | ForEach-Object { $_.FullName })
      Assert-True ($names -contains 'sessions/opencode.db') 'nested entry uses /'
    } finally { $z.Dispose() }
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
  }

  It "skips its own output file if the destination is inside the source" {
    $root = Join-Path $env:TEMP 'oc-zip-self'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory (Join-Path $root 'sub') -Force | Out-Null
    'x' | Set-Content (Join-Path $root 'sub\a.txt')
    $zip = Join-Path $root 'out.zip'
    New-SpecCompliantZip -SourceDir $root -Destination $zip
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
    try {
      $names = @($z.Entries | ForEach-Object { $_.FullName })
      Assert-True ($names -contains 'sub/a.txt') 'real file archived'
      Assert-True (@($names | Where-Object { $_ -like '*out.zip*' }).Count -eq 0) 'archive did not archive itself'
    } finally { $z.Dispose() }
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe "SQLite header validation" {
  It "accepts a valid database" {
    $root = Join-Path $env:TEMP 'oc-sqlite-test'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $root -Force | Out-Null
    $db = Join-Path $root 'opencode.db'
    $size = New-TestSqliteDb -Path $db
    $info = Assert-SqliteHeader $db
    Assert-Equal $info.Magic 'SQLite format 3' 'magic'
    Assert-Equal $info.PageSize 1024 'page size'
    Assert-Equal $info.PageCount 4 'page count'
    Assert-Equal (Get-Item $db).Length $size 'file size'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
  }

  It "rejects a file that is not a database" {
    # This is what a torn or truncated copy looks like.
    $root = Join-Path $env:TEMP 'oc-sqlite-test2'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $root -Force | Out-Null
    $bad = Join-Path $root 'opencode.db'
    [System.IO.File]::WriteAllBytes($bad, (New-Object byte[] 2048))
    Assert-Throws { Assert-SqliteHeader $bad } 'garbage database'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe "Test-DbIsFree" {
  It "is true for a closed database" {
    $root = Join-Path $env:TEMP 'oc-free-test'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $root -Force | Out-Null
    $db = Join-Path $root 'opencode.db'
    New-TestSqliteDb -Path $db | Out-Null
    Assert-Equal (Test-DbIsFree $db) $true 'closed db'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
  }

  It "is false while another process holds the file" {
    $root = Join-Path $env:TEMP 'oc-busy-test'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory $root -Force | Out-Null
    $db = Join-Path $root 'opencode.db'
    New-TestSqliteDb -Path $db | Out-Null
    # SQLite holds the db open with share-read/write, so emulate that.
    $holder = [System.IO.File]::Open($db, [System.IO.FileMode]::Open,
              [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    try {
      Assert-Equal (Test-DbIsFree $db) $false 'held db'
    } finally { $holder.Dispose() }
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe "Copy-ClosedSqliteSet" {
  It "copies the db and its journals together" {
    $root = Join-Path $env:TEMP 'oc-copy-test'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    $src = Join-Path $root 'src'; $dst = Join-Path $root 'dst'
    New-Item -ItemType Directory $src, $dst -Force | Out-Null
    $db = Join-Path $src 'opencode.db'
    $size = New-TestSqliteDb -Path $db
    'wal' | Set-Content (Join-Path $src 'opencode.db-wal')
    $journals = Copy-ClosedSqliteSet -Db $db -DestDir $dst
    Assert-True ($journals -contains '-wal') 'wal journal reported'
    Assert-Equal (Get-Item (Join-Path $dst 'opencode.db')).Length $size 'db copied byte-identical'
    Assert-True (Test-Path (Join-Path $dst 'opencode.db-wal')) 'wal copied'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
  }

  It "refuses to copy a database that is in use" {
    $root = Join-Path $env:TEMP 'oc-copy-busy'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    $src = Join-Path $root 'src'; $dst = Join-Path $root 'dst'
    New-Item -ItemType Directory $src, $dst -Force | Out-Null
    $db = Join-Path $src 'opencode.db'
    New-TestSqliteDb -Path $db | Out-Null
    $holder = [System.IO.File]::Open($db, [System.IO.FileMode]::Open,
              [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    try {
      Assert-Throws { Copy-ClosedSqliteSet -Db $db -DestDir $dst } 'busy database must throw'
    } finally { $holder.Dispose() }
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Describe "Backup and restore round trip" {
  It "restores a full backup into empty folders" {
    $root = Join-Path $env:TEMP 'oc-roundtrip'
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    $cfg = Join-Path $root 'config'
    $dat = Join-Path $root 'data'
    $bk  = Join-Path $root 'bkroot'
    New-Item -ItemType Directory $cfg, $dat -Force | Out-Null
    '{"theme":"dark"}' | Set-Content (Join-Path $cfg 'opencode.jsonc')
    New-Item -ItemType Directory (Join-Path $cfg 'command') -Force | Out-Null
    '# rules' | Set-Content (Join-Path $cfg 'command\help.md')
    '{"token":"secret"}' | Set-Content (Join-Path $dat 'auth.json')
    $dbSize = New-TestSqliteDb -Path (Join-Path $dat 'opencode.db')
    'wal' | Set-Content (Join-Path $dat 'opencode.db-wal')

    # Snapshot the user environment: restore writes env vars back from the archive.
    $snap = @{}
    [Environment]::GetEnvironmentVariables('User').GetEnumerator() | ForEach-Object { $snap[$_.Key] = $_.Value }
    try {
      $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'opencode-backup.ps1') `
             -Backup -ConfigDir $cfg -DataDir $dat -BackupRoot $bk 2>&1
      Assert-Equal $LASTEXITCODE 0 "backup exit code: $out"

      $zip = (Get-ChildItem $bk -Recurse -Filter *.zip | Select-Object -First 1).FullName
      Assert-True ([bool]$zip) 'archive was created'

      Add-Type -AssemblyName System.IO.Compression.FileSystem
      $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
      try {
        Assert-Equal (@($z.Entries | Where-Object { $_.FullName -match '\\' }).Count) 0 'backslash entries'
      } finally { $z.Dispose() }

      # Wipe the source, then restore into folders that do not exist at all.
      Remove-Item $cfg, $dat -Recurse -Force
      $out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $RepoRoot 'opencode-backup.ps1') `
              -Restore -Path $zip -ConfigDir $cfg -DataDir $dat -BackupRoot $bk 2>&1
      Assert-Equal $LASTEXITCODE 0 "restore exit code: $out2"

      Assert-Equal ((Get-Content (Join-Path $cfg 'opencode.jsonc') -Raw).Trim()) '{"theme":"dark"}' 'config file'
      Assert-Equal ((Get-Content (Join-Path $cfg 'command\help.md') -Raw).Trim()) '# rules' 'nested config file'
      Assert-Equal ((Get-Content (Join-Path $dat 'auth.json') -Raw).Trim()) '{"token":"secret"}' 'auth.json'
      Assert-True (Test-Path (Join-Path $dat 'opencode.db-wal')) 'wal restored'
      # Regression: restoring auth.json used to fail when the data folder was absent.
      Assert-Equal (Get-Item (Join-Path $dat 'opencode.db')).Length $dbSize 'db size'
      $info = Get-SqliteHeaderInfo (Join-Path $dat 'opencode.db')
      Assert-Equal $info.Magic 'SQLite format 3' 'restored db header'
    }
    finally {
      # Put the user environment back exactly as it was.
      $now = [Environment]::GetEnvironmentVariables('User')
      foreach ($k in $now.Keys) {
        if (-not $snap.ContainsKey($k)) { [Environment]::SetEnvironmentVariable($k, $null, 'User') }
      }
      foreach ($k in $snap.Keys) {
        if ($now[$k] -cne $snap[$k]) { [Environment]::SetEnvironmentVariable($k, $snap[$k], 'User') }
      }
      Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
}