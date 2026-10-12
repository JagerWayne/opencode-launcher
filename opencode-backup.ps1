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
  [string]$BackupRoot = "$env:USERPROFILE\.config\opencode\backup"
)

$ErrorActionPreference = "Stop"

$ConfigDir  = "$env:USERPROFILE\.config\opencode"
$DataDir    = "$env:USERPROFILE\.local\share\opencode"
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
  if (Test-Path $db) {
    $sqlite = Get-Command sqlite3 -ErrorAction SilentlyContinue
    if ($sqlite) {
      # Consistent snapshot via SQLite's online backup (safe while opencode runs).
      & $sqlite.Source $db ".backup '$sessDir\opencode.db'"
    }
    else {
      # No sqlite3 CLI: copy the database and its journal files as one set.
      Copy-Item $db (Join-Path $sessDir "opencode.db") -Force
      foreach ($suffix in @("-wal", "-shm")) {
        $f = "$db$suffix"
        if (Test-Path $f) { Copy-Item $f (Join-Path $sessDir ("opencode.db" + $suffix)) -Force }
      }
    }
    $copiedSessions += "opencode.db"
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
  }
  ($manifest | ConvertTo-Json) | Set-Content (Join-Path $tempDir "manifest.json") -Encoding UTF8

  # 5. zip it
  $zip = Join-Path $ArchiveDir "opencode-backup-$stamp.zip"
  Compress-Archive -Path (Join-Path $tempDir "*") -DestinationPath $zip -Force

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

  # 2. auth.json
  $authSrc = Join-Path $tempDir "auth.json"
  if (Test-Path $authSrc) {
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
