<#
  opencode-backup.ps1

  Back up and restore your opencode setup, including API keys.

  What gets backed up:
    - config  : ~/.config/opencode  (opencode.jsonc / opencode.json, service.json, package.json, AGENTS.md)
    - secrets : ~/.local/share/opencode/auth.json  (provider API keys)
    - sessions: ~/.local/share/opencode  (opencode.db session database + WAL/SHM,
                plus the storage and snapshot folders)
    - env     : user-scope environment variables whose name looks like a key
                (FAL_KEY, *_API_KEY, *_TOKEN, *_SECRET, ...)

  Usage (from any PowerShell window):
    .\opencode-backup.ps1                 # make a timestamped backup
    .\opencode-backup.ps1 -Backup         # same
    .\opencode-backup.ps1 -List           # list existing backups
    .\opencode-backup.ps1 -Restore        # restore the newest backup
    .\opencode-backup.ps1 -Restore <file> # restore a specific backup zip

  NOTE: the backup zip contains your API keys in plain text. Keep it somewhere
  private. Pass -Password to encrypt it with a password instead.
#>

[CmdletBinding()]
param(
  [switch]$Backup,
  [switch]$Restore,
  [switch]$List,
  [string]$Path,
  [string]$Password,
  [string]$BackupRoot = "$env:USERPROFILE\.config\opencode\backup",
  # Overridable so the round trip can be tested without touching real data.
  [string]$ConfigDir  = "$env:USERPROFILE\.config\opencode",
  [string]$DataDir    = "$env:USERPROFILE\.local\share\opencode"
)

$ErrorActionPreference = "Stop"

$AuthFile   = Join-Path $DataDir "auth.json"
$ArchiveDir = Join-Path $BackupRoot "archives"

function Show-Usage {
  Write-Host "opencode-backup.ps1"
  Write-Host "  -Backup            make a new timestamped backup (default)"
  Write-Host "  -List              list existing backups"
  Write-Host "  -Restore [zip]     restore the newest, or a specific, backup"
  Write-Host "  -Password <pw>     encrypt (backup) / decrypt (restore) with a password"
  Write-Host ""
  Write-Host "Archives: $ArchiveDir"
}

function Get-KeyEnvNames {
  $userVars = [Environment]::GetEnvironmentVariables("User")
  $userVars.Keys | Where-Object { $_ -match 'KEY|TOKEN|SECRET' -and $_ -notmatch '^ps' }
}

# ----- session database helpers ------------------------------------------------

function Test-DbIsFree {
  # True when no process currently holds the database open. SQLite opens the
  # file with share-read/share-write, so an exclusive open only succeeds when
  # the database is genuinely closed.
  param([string]$Path)
  try {
    $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open,
          [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $fs.Dispose()
    return $true
  } catch { return $false }
}

function Get-OpenCodeProcessName {
  $p = @(Get-Process -ErrorAction SilentlyContinue |
         Where-Object { $_.ProcessName -like "opencode*" })
  if ($p.Count -gt 0) { return $p[0].ProcessName }
  return $null
}

function Get-SqliteHeaderInfo {
  param([string]$Path)
  $fs = [System.IO.File]::OpenRead($Path)
  try {
    $hdr = New-Object byte[] 100
    [void]$fs.Read($hdr, 0, 100)
  } finally { $fs.Dispose() }
  $pageSize = [int]$hdr[16] * 256 + [int]$hdr[17]
  if ($pageSize -eq 1) { $pageSize = 65536 }
  return [pscustomobject]@{
    Magic     = [Text.Encoding]::ASCII.GetString($hdr, 0, 16).TrimEnd([char]0)
    PageSize  = $pageSize
    PageCount = [int]$hdr[28] * 16777216 + [int]$hdr[29] * 65536 +
                [int]$hdr[30] * 256 + [int]$hdr[31]
  }
}

function Assert-SqliteHeader {
  # Catches the classic failure of archiving a half-copied database.
  param([string]$Path)
  $info = Get-SqliteHeaderInfo $Path
  if ($info.Magic -ne "SQLite format 3") {
    throw "The copied session database is not a valid SQLite file (header was '$($info.Magic)'). No archive was written."
  }
  if ($info.PageSize -lt 512 -or ($info.PageSize -band ($info.PageSize - 1)) -ne 0) {
    throw "The copied session database reports an invalid page size ($($info.PageSize)). No archive was written."
  }
  return $info
}

function Copy-ClosedSqliteSet {
  # Copies db + -wal + -shm as one set, but only when the database is closed.
  # Copying while another process writes interleaves DB pages and WAL frames
  # from different instants; SQLite can then refuse to open the result or
  # silently drop recent sessions.
  param([string]$Db, [string]$DestDir)

  if (-not (Test-DbIsFree $Db)) {
    $proc = Get-OpenCodeProcessName
    if ($proc) {
      throw "opencode (process '$proc') is running and is using the session database." + `
            "`nClose it (quit the running opencode session or this launcher), then run the backup again." + `
            "`nRefusing to write an archive that would probably not restore."
    }
    throw "The session database is in use by another process." + `
          "`nClose anything using opencode, then run the backup again." + `
          "`nRefusing to write an archive that would probably not restore."
  }

  Copy-Item $Db (Join-Path $DestDir "opencode.db") -Force
  $journals = @()
  foreach ($suffix in @("-wal", "-shm")) {
    $f = "$Db$suffix"
    if (Test-Path $f) {
      Copy-Item $f (Join-Path $DestDir ("opencode.db" + $suffix)) -Force
      $journals += $suffix
    }
  }
  return $journals
}

function New-SpecCompliantZip {
  # Builds the archive entry by entry, normalising the path separator to '/'.
  #
  # Neither Compress-Archive nor ZipFile::CreateFromDirectory can be used here:
  # on .NET Framework (what Windows PowerShell 5.1 runs on) both write '\' into
  # entry names, which breaks the ZIP spec. Linux unzip, macOS Archive Utility
  # and Python's zipfile then treat "sessions\opencode.db" as a single flat
  # filename instead of a path, so the archive restores to garbage. Only
  # .NET Core writes '/' by default, and the launcher must run on 5.1.
  param([string]$SourceDir, [string]$Destination)

  Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
  Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue

  if (Test-Path $Destination) { Remove-Item $Destination -Force }
  $fs = [System.IO.File]::Open($Destination, [System.IO.FileMode]::CreateNew)
  try {
    $archive = New-Object System.IO.Compression.ZipArchive(
                   $fs, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
      # Explicit directory entries keep empty folders and show the shape.
      foreach ($d in (Get-ChildItem -LiteralPath $SourceDir -Recurse -Directory -Force)) {
        $rel = $d.FullName.Substring($SourceDir.Length).TrimStart('\', '/') -replace '\\', '/'
        [void]$archive.CreateEntry($rel + '/')
      }
      foreach ($f in (Get-ChildItem -LiteralPath $SourceDir -Recurse -File -Force)) {
        # Never archive the archive we are writing.
        if ($f.FullName -eq $Destination) { continue }
        $rel = $f.FullName.Substring($SourceDir.Length).TrimStart('\', '/') -replace '\\', '/'
        $entry = $archive.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
        # The zip epoch is 1980; anything older is rejected.
        if ($f.LastWriteTime -ge [datetime]"1980-01-01") {
          try { $entry.LastWriteTime = $f.LastWriteTime } catch {}
        }
        # Stream rather than ReadAllBytes: the session database is ~110 MB.
        $src = $null
        $dst = $null
        try {
          $src = [System.IO.File]::OpenRead($f.FullName)
          $dst = $entry.Open()
          $src.CopyTo($dst)
        } finally {
          if ($dst) { $dst.Dispose() }
          if ($src) { $src.Dispose() }
        }
      }
    } finally { $archive.Dispose() }
  } finally { $fs.Dispose() }
}

function Invoke-Backup {
  if (-not (Test-Path $ArchiveDir)) { New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null }

  $stamp   = Get-Date -Format "yyyyMMdd-HHmmss"
  $tempDir = Join-Path $env:TEMP "opencode-backup-$stamp"
  New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

  # 1. config folder (everything except node_modules, package-lock and the backups themselves)
  $cfgDir = Join-Path $tempDir "config"
  New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null
  $copiedConfig = @()
  Get-ChildItem $ConfigDir -Force | Where-Object {
    $_.Name -notin @("node_modules", "backup", "package-lock.json")
  } | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $cfgDir $_.Name) -Recurse -Force
    $copiedConfig += $_.Name
  }

  # 2. auth.json (provider keys)
  $copiedAuth = $false
  if (Test-Path $AuthFile) {
    Copy-Item $AuthFile (Join-Path $tempDir "auth.json") -Force
    $copiedAuth = $true
  }

  # 3. sessions / state (the session database plus its journals, and JSON state)
  $sessDir = Join-Path $tempDir "sessions"
  New-Item -ItemType Directory -Path $sessDir -Force | Out-Null
  $copiedSessions = @()
  $db = Join-Path $DataDir "opencode.db"
  $dbInfo = $null
  if (Test-Path $db) {
    try {
      $sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
      if ($sqlite) {
        # SQLite's online backup: safe to run while opencode is writing.
        & $sqlite.Source $db ".backup '$sessDir\opencode.db'"
      }
      else {
        $journals = Copy-ClosedSqliteSet -Db $db -DestDir $sessDir
        if ($journals.Count -gt 0) {
          Write-Host "  session database copied while closed (journal: $($journals -join ', '))"
        }
      }
      $dbInfo = Assert-SqliteHeader (Join-Path $sessDir "opencode.db")
      $copiedSessions += "opencode.db"
    }
    catch {
      # Don't leave a half-copied tree (with your keys in it) in TEMP.
      Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
      throw
    }
  }
  foreach ($d in @("storage", "snapshot")) {
    $src = Join-Path $DataDir $d
    if (Test-Path $src) {
      Copy-Item $src (Join-Path $sessDir $d) -Recurse -Force
      $copiedSessions += $d
    }
  }
  $sessSize = (Get-ChildItem $sessDir -Recurse -Force -File -ErrorAction SilentlyContinue |
      Measure-Object Length -Sum).Sum
  if (-not $sessSize) { $sessSize = 0 }

  # 4. key-like user env vars
  $envNames = @(Get-KeyEnvNames)
  $envMap = [ordered]@{}
  foreach ($n in $envNames) {
    $val = [Environment]::GetEnvironmentVariable($n, "User")
    if ($val) { $envMap[$n] = $val }
  }
  ($envMap | ConvertTo-Json) | Set-Content (Join-Path $tempDir "env.json") -Encoding UTF8

  # manifest (no secret values)
  $manifest = [ordered]@{
    created    = (Get-Date).ToString("o")
    machine    = $env:COMPUTERNAME
    user       = $env:USERNAME
    config     = $copiedConfig
    authFile   = $copiedAuth
    sessions   = $copiedSessions
    envKeys    = @($envMap.Keys)
    dbPageSize = $(if ($dbInfo) { $dbInfo.PageSize } else { $null })
    dbPages    = $(if ($dbInfo) { $dbInfo.PageCount } else { $null })
  }
  ($manifest | ConvertTo-Json) | Set-Content (Join-Path $tempDir "manifest.json") -Encoding UTF8

  # 5. zip it
  $zip = Join-Path $ArchiveDir "opencode-backup-$stamp.zip"
  New-SpecCompliantZip -SourceDir $tempDir -Destination $zip

  if ($Password) {
    $enc = "$zip.enc"
    $salt = New-Object byte[] 16
    (New-Object System.Security.Cryptography.RNGCryptoServiceProvider).GetBytes($salt)
    $key = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $salt, 100000)
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key.GetBytes(32); $aes.IV = $key.GetBytes(16)
    $plain = [System.IO.File]::ReadAllBytes($zip)
    $out = [System.IO.File]::Create($enc)
    $out.Write($salt, 0, $salt.Length)
    $out.Write($aes.IV, 0, $aes.IV.Length)
    $cs = New-Object System.Security.Cryptography.CryptoStream($out, $aes.CreateEncryptor(), [System.Security.Cryptography.CryptoStreamMode]::Write)
    $cs.Write($plain, 0, $plain.Length); $cs.FlushFinalBlock(); $cs.Close(); $out.Close()
    Remove-Item $zip -Force
    $zip = $enc
  }

  Remove-Item $tempDir -Recurse -Force

  Write-Host "Backup written: $zip"
  Write-Host "  config files : $($copiedConfig -join ', ')"
  Write-Host "  auth.json    : $(if ($copiedAuth) { 'yes' } else { 'not found' })"
  Write-Host "  sessions     : $(if ($copiedSessions.Count) { ($copiedSessions -join ', ') + " ($([math]::Round($sessSize / 1MB, 1)) MB)" } else { 'not found' })"
  if ($dbInfo) {
    Write-Host "  db verified  : SQLite header ok, $($dbInfo.PageCount) pages of $($dbInfo.PageSize) bytes"
  }
  Write-Host "  env keys     : $($envMap.Keys -join ', ')"
  if (-not $Password) { Write-Host "  (unencrypted - contains secrets; keep it private)" }
}

function Get-LatestArchive {
  Get-ChildItem $ArchiveDir -Filter "opencode-backup-*" -File |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Invoke-Restore {
  $source = $Path
  if (-not $source) {
    $latest = Get-LatestArchive
    if (-not $latest) { throw "No backups found in $ArchiveDir" }
    $source = $latest.FullName
  }
  if (-not (Test-Path $source)) { throw "Backup not found: $source" }
  $source = (Resolve-Path $source).Path

  $tempDir = Join-Path $env:TEMP ("opencode-restore-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
  New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

  $zip = $source
  if ($source -like "*.enc") {
    if (-not $Password) { throw "This backup is encrypted; pass -Password <pw>" }
    $all = [System.IO.File]::ReadAllBytes($source)
    $salt = [byte[]]$all[0..15]; $iv = [byte[]]$all[16..31]; $data = [byte[]]$all[32..($all.Length-1)]
    $key = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $salt, 100000)
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $key.GetBytes(32); $aes.IV = $iv
    $ms = [System.IO.MemoryStream]::new([byte[]]$data)
    $cs = New-Object System.Security.Cryptography.CryptoStream($ms, $aes.CreateDecryptor(), [System.Security.Cryptography.CryptoStreamMode]::Read)
    $plain = [System.IO.MemoryStream]::new()
    $cs.CopyTo($plain); $plain.Position = 0
    $zip = Join-Path $tempDir "decrypted.zip"
    [System.IO.File]::WriteAllBytes($zip, $plain.ToArray())
  }

  Expand-Archive -Path $zip -DestinationPath $tempDir -Force

  # 1. config folder (recursive, merging into existing folders)
  $cfgSrc = Join-Path $tempDir "config"
  if (Test-Path $cfgSrc) {
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
    Get-ChildItem $cfgSrc -Force | ForEach-Object {
      $dest = Join-Path $ConfigDir $_.Name
      if ($_.PSIsContainer) {
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
        Copy-Item (Join-Path $_.FullName "*") $dest -Recurse -Force
      }
      else {
        Copy-Item $_.FullName $dest -Force
      }
      Write-Host "  restored config/$($_.Name)"
    }
  }

  # 2. auth.json. The data folder may not exist on a machine that has never run
  #    opencode, so create it before copying into it.
  $authSrc = Join-Path $tempDir "auth.json"
  if (Test-Path $authSrc) {
    if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
    Copy-Item $authSrc $AuthFile -Force
    Write-Host "  restored auth.json"
  }

  # 3. sessions / state
  $sessSrc = Join-Path $tempDir "sessions"
  if (Test-Path $sessSrc) {
    if (-not (Test-Path $DataDir)) { New-Item -ItemType Directory -Path $DataDir -Force | Out-Null }
    Get-ChildItem $sessSrc -Force | ForEach-Object {
      try {
        Copy-Item $_.FullName (Join-Path $DataDir $_.Name) -Recurse -Force
        Write-Host "  restored sessions/$($_.Name)"
      }
      catch {
        Write-Host "  could not restore sessions/$($_.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  (close opencode completely, then restore again)" -ForegroundColor Yellow
      }
    }
  }

  # 4. env vars
  $envSrc = Join-Path $tempDir "env.json"
  if (Test-Path $envSrc) {
    $map = Get-Content $envSrc -Raw | ConvertFrom-Json
    foreach ($p in $map.PSObject.Properties) {
      [Environment]::SetEnvironmentVariable($p.Name, $p.Value, "User")
      Write-Host "  set env $($p.Name)"
    }
  }

  Remove-Item $tempDir -Recurse -Force
  Write-Host "Restore complete from: $source"
  Write-Host "Restart opencode (and open a new terminal) for changes to take effect."
}

if ($List) {
  if (-not (Test-Path $ArchiveDir)) { Write-Host "No backups yet."; return }
  Get-ChildItem $ArchiveDir -Filter "opencode-backup-*" -File |
    Sort-Object LastWriteTime -Descending |
    Format-Table Name, @{ n = "Size(KB)"; e = { [math]::Round($_.Length / 1KB, 1) } }, LastWriteTime -AutoSize
  return
}

if ($Restore) { Invoke-Restore; return }
Invoke-Backup
