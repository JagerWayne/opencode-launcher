# OpenCode Launcher

**Version 2.0 — By Wayne Scicluna**

A colourful, keypress-driven Windows menu for [OpenCode](https://opencode.ai). Instead of
remembering subcommands and flags, you get one window with a key for each common action —
run, resume, run-in-a-folder, web server, update, install/repair, uninstall, and **backup /
restore** of your config, API keys and sessions.

It is a single PowerShell script (`opencode-launcher.ps1`) that runs on the **Windows
PowerShell** that already ships with Windows 10/11 — no Node, Python or extra runtime needed
for the launcher itself. Colours are used throughout (title bar, section headers, a live status
line, and green/red indicators), and it falls back gracefully if the console is tiny or plain.

```
   OPENCODE LAUNCHER                                        v2.0

   OpenCode opencode v2.0.27     Node v24.17.0
   Folder C:\Users\You

    RUN  ----------------------------------------------
   [R] Run OpenCode                      this folder
   [C] Continue last session             --continue
   [F] Run in a specific folder          prompt for a path
   [S] Launch Web Server                 opencode web

    MANAGE  -------------------------------------------
   [M] Manage                            update, backup, restore...

    EXIT  ---------------------------------------------
   [Q] Quit
```

> The title bar and the `RUN` / `MANAGE` / `EXIT` section labels are drawn as coloured bars,
> the keys are yellow, and the status line is green when things are healthy and red when not.

> **Quick install (PowerShell):** `irm https://lc.cx/opencode | iex`

---

## Contents

- [Requirements](#requirements)
- [Files in this repo](#files-in-this-repo)
- [Getting started](#getting-started)
  - [Install with one PowerShell command](#install-with-one-powershell-command)
  - [Run it directly (no install)](#run-it-directly-no-install)
- [Launch it by typing `oc`](#launch-it-by-typing-oc)
- [Menu options explained](#menu-options-explained)
  - [Main menu](#main-menu)
    - [[R] Run OpenCode](#r-run-opencode)
    - [[C] Continue last session](#c-continue-last-session)
    - [[F] Run in a specific folder](#f-run-in-a-specific-folder)
    - [[S] Launch Web Server](#s-launch-web-server)
    - [[M] Manage](#m-manage)
  - [Manage menu](#manage-menu)
    - [[U] Update OpenCode](#u-update-opencode)
    - [[I] Install / repair OpenCode](#i-install--repair-opencode)
    - [[X] Uninstall OpenCode](#x-uninstall-opencode)
    - [[B] Backup](#b-backup)
    - [[R] Restore](#r-restore)
    - [[O] Set up the "oc" command shortcut](#o-set-up-the-oc-command-shortcut)
    - [[L] Uninstall Launcher](#l-uninstall-launcher)
  - [[Q] Quit](#q-quit)
- [Backup and restore](#backup-and-restore)
- [The status line](#the-status-line)
- [How the internals work](#how-the-internals-work)
- [Customising](#customising)
- [License](#license)

---

## Requirements

- **Windows** with **Windows PowerShell 5.1** (included in Windows 10/11). The launcher is a
  `.ps1` file; the `oc.cmd` shim runs it with `powershell -NoProfile -ExecutionPolicy Bypass`.
- **Node.js / npm** to install and run OpenCode — but only if you don't already have OpenCode.
  The launcher's **[I] Install** option can install Node.js for you.
- **`winget`** is used to install Node.js automatically when it's missing. If `winget` is not
  available, the bundled `install-node.ps1` downloads the official Node.js LTS installer
  instead.

No Python and no Node dependency for the launcher itself — just the PowerShell that ships with
Windows.

---

## Files in this repo

| File | Description |
| --- | --- |
| `opencode-launcher.ps1` | The launcher. All menus, colours and actions live here. |
| `opencode-backup.ps1` | Backup/restore of opencode config, API keys and sessions. |
| `opencode-backup.cmd` | Thin batch wrapper so you can run the backup from a terminal by name. |
| `install-node.ps1` | Fallback Node.js LTS installer, used only when `winget` is unavailable. |
| `install.ps1` | One-line installer that downloads the launcher and creates the `oc` shortcut. |
| `run.ps1` | One-line runner that downloads and opens the menu without installing anything. |
| `README.md` | This document. |
| `LICENSE` | MIT licence. |

The backup feature writes timestamped archives under
`%USERPROFILE%\.config\opencode\backup\archives` (never inside this repo).

---

## Getting started

### Install with one PowerShell command

On any Windows machine, open PowerShell and run:

```powershell
irm https://lc.cx/opencode | iex
```

`https://lc.cx/opencode` is a short link to `install.ps1` in this repo. It downloads the
launcher to `%LOCALAPPDATA%\OpenCodeLauncher`, creates the `oc` shortcut, and puts it on your
`PATH`. Then just type `oc` in any command window. No git or clone needed.

The full URL, if you prefer it or want to verify the target:

```powershell
irm https://raw.githubusercontent.com/JagerWayne/opencode-launcher/main/install.ps1 | iex
```

### Run it directly (no install)

To open the menu right away without installing anything, run this in PowerShell:

```powershell
irm https://raw.githubusercontent.com/JagerWayne/opencode-launcher/main/run.ps1 | iex
```

It downloads the launcher (cached in `%LOCALAPPDATA%\OpenCodeLauncher`) and opens the menu.
It does **not** create a shortcut or change your `PATH`. If you're offline it falls back to the
cached copy from a previous run.

`install.ps1` accepts a few options if you run it as a file:

| Option | Default | Meaning |
| --- | --- | --- |
| `-InstallDir <path>` | `%LOCALAPPDATA%\OpenCodeLauncher` | Where the launcher files are downloaded. |
| `-BinDir <path>` | `%USERPROFILE%\.local\bin` | Where the `oc.cmd` shortcut is written. |
| `-NoPath` | off | Don't modify the user `PATH`. |
| `-Launch` | off | Open the launcher when the install finishes. |

```powershell
./install.ps1 -InstallDir "C:\tools\opencode-launcher" -Launch
```

### Or use the repo directly

1. Download / clone this repo to any folder, e.g. `C:\coding\OpenCodeLauncher`.
2. Run `opencode-launcher.ps1` (right-click → *Run with PowerShell*), or from a terminal:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\opencode-launcher.ps1
   ```
3. If OpenCode isn't installed yet, press **I** and let it set everything up.
4. Press **O** to create the `oc` shortcut so you can launch it by typing `oc`.

You can also make a desktop shortcut to `opencode-launcher.ps1` and pin it to the Start menu or
taskbar. Because everything is relative to the script's own folder (`$PSScriptRoot`), you can
move the folder anywhere you like — just re-run **O** if you move it after creating the `oc`
shim.

---

## Launch it by typing `oc`

Option **[O]** creates a tiny shim (`oc.cmd`) that calls the launcher, and makes sure its folder
is on your user `PATH`. After that, typing:

```cmd
oc
```

in any command window opens the launcher menu. The shim it writes is:

```bat
@echo off
rem Launches the OpenCode Launcher. Managed by opencode-launcher.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\opencode-launcher.ps1" %*
```

It drops the shim in `%USERPROFILE%\.local\bin` (a common personal-scripts folder) and creates
that folder if needed. A newly added `PATH` entry takes effect in command windows opened
**after** the change — already-open windows keep their old `PATH` until restarted.

---

## Menu options explained

The main menu is grouped into **RUN**, **MANAGE** and **EXIT**; **[M]** opens a second menu. Every
entry is a single keypress. `ESC` goes back (or quits from the main menu), and every destructive
action asks you to type `YES` first.

### Main menu

#### [R] Run OpenCode

Runs OpenCode in the folder the launcher was started from.

- Under the hood: `opencode`
- OpenCode's positional argument is a directory, so with no argument it uses the current
  working directory. When you exit OpenCode you return to the menu, not the prompt.

#### [C] Continue last session

Resumes your most recent OpenCode session.

- Under the hood: `opencode --continue`
- Handy when you close the terminal and want to jump straight back into what you were doing.

#### [F] Run in a specific folder

Starts OpenCode in a folder you choose, without moving the launcher.

- Prompts `Folder:` — type a path, or **drag a folder from Explorer onto the window** to paste
  its path (surrounding quotes are stripped automatically).
- Press **Enter** on an empty prompt to cancel.
- Validates the folder exists; if not, it prints `Folder not found: <path>` and returns to the
  menu instead of launching with a bad path.
- Under the hood: `opencode "<folder>"`.

#### [S] Launch Web Server

Starts OpenCode's built-in web/server interface.

- Under the hood: `opencode web`
- It opens in a **separate window** so the launcher stays usable and you can start/stop the
  server independently.
- The server window prints the URL to open in your browser. Close that window (or press
  **Ctrl+C** in it) to stop it.

#### [M] Manage

Opens the **Manage** submenu (see below). `ESC` returns to the main menu.

### Manage menu

```
   OPENCODE ------------------------------------------
  [U] Update OpenCode                   opencode upgrade
  [I] Install / Repair OpenCode         npm install -g
  [X] Uninstall OpenCode                keeps config + keys

   DATA ----------------------------------------------
  [B] Backup                            config, keys, launcher
  [R] Restore                           pick a backup

   LAUNCHER ------------------------------------------
  [O] Set up the "OC" shortcut
  [L] Uninstall Launcher

  [ESC] Back
```

#### [U] Update OpenCode

Updates OpenCode to the latest version using its own updater.

- Under the hood: `opencode upgrade`
- OpenCode detects how it was installed (npm, bun, curl, brew, …) and updates accordingly.
- Requires OpenCode to be installed; otherwise it tells you to use **[I]** first.

#### [I] Install / repair OpenCode

Installs OpenCode, ensuring the prerequisites are present first.

1. **Detects prerequisites.** If `npm` is present it skips straight to step 3.
2. **Installs Node.js if needed** — via `winget install --id OpenJS.NodeJS.LTS`, or (if
   `winget` is unavailable) the bundled `install-node.ps1`, which downloads the latest LTS MSI
   from nodejs.org and installs it (Windows will prompt for administrator permission via UAC).
   If Node.js still isn't available afterwards, it tells you to install it from
   <https://nodejs.org/> and stops.
3. **Installs OpenCode.** Runs `npm install -g @opencode/cli@latest`. If OpenCode is already
   present it simply refreshes the install.

> **Note on npm 11+:** recent npm versions warn that `@opencode/cli` has a `postinstall` script
> not covered by the new `allow-scripts` policy. The install still completes and OpenCode works.

#### [X] Uninstall OpenCode

Removes OpenCode while keeping your sessions, configuration, API keys and state.

- Asks `Type YES to uninstall` and only proceeds on an explicit **YES**.
- If the `opencode` command is available it runs `opencode uninstall`, then falls back to
  `npm uninstall -g @opencode/cli`.
- Back up first with **[B]** if you want a safe copy.

#### [B] Backup

Backs up your opencode setup into a timestamped archive. See
[Backup and restore](#backup-and-restore).

#### [R] Restore

Lists your backups as a numbered pick-list (newest first, with size and date). Press the number
to choose one, then type `YES` to confirm. `ESC` goes back.

#### [O] Set up the "oc" command shortcut

Creates the `oc.cmd` shim (see [Launch it by typing `oc`](#launch-it-by-typing-oc)) and ensures
`%USERPROFILE%\.local\bin` is on your user `PATH`. Run it again any time you move the launcher
folder or on a new machine.

#### [L] Uninstall Launcher

Removes the `oc` shortcut and the launcher files (`opencode-launcher.ps1`,
`opencode-backup.ps1`, `opencode-backup.cmd`, `install-node.ps1`) and drops the launcher folder
from your user `PATH`. OpenCode itself and your config/backups are **not** touched.

- Asks `Type YES to remove the launcher` and only proceeds on an explicit **YES**.

### [Q] Quit

Closes the launcher window.

---

## Backup and restore

**[B] Backup** writes a timestamped archive to
`%USERPROFILE%\.config\opencode\backup\archives`. Each archive contains:

| Item | What |
| --- | --- |
| `config/` | `%USERPROFILE%\.config\opencode` — `opencode.jsonc`/`opencode.json`, custom commands, agents, skills, plugins, and the launcher (minus `node_modules` and the backups themselves). |
| `auth.json` | `%USERPROFILE%\.local\share\opencode\auth.json` — your provider **API keys**. |
| `sessions/` | `opencode.db` (snapshotted via SQLite's online backup when `sqlite3` is available) plus the `storage` and `snapshot` folders. |
| `env.json` | User environment variables whose name looks like a key (`FAL_KEY`, `*_API_KEY`, `*_TOKEN`, `*_SECRET`). |
| `manifest.json` | A summary (host, time, what was included) with no secret values. |

Restore puts the config back, restores `auth.json`, restores the session database and state, and
re-sets the environment variables. **Restart opencode (and open a new terminal) after a restore.**

The same script can be driven from a terminal:

```powershell
# backup
.\opencode-backup.ps1 -Backup
# or, via the wrapper
opencode-backup.cmd backup

# list
opencode-backup.cmd list

# restore newest
opencode-backup.cmd restore
# restore a specific archive
opencode-backup.cmd restore "C:\...\opencode-backup-20260101-120000.zip"
```

The archives contain your **API keys in plain text**. Keep them somewhere private, or encrypt
them — pass `-Password` on backup and restore:

```powershell
opencode-backup.cmd backup -Password "my secret"
opencode-backup.cmd restore "C:\...\opencode-backup-20260101-120000.zip.enc" -Password "my secret"
```

---

## The status line

The line just under the title is refreshed every time a menu is drawn:

```
   OpenCode opencode v2.0.27     Node v24.17.0
```

- **OpenCode** — the installed version (green) or `not installed` (red).
- **Node** — the Node/npm version (green) or `missing` (red).

This lets you see at a glance whether you need to run **[I]** first. If OpenCode isn't installed,
the run/update actions print a reminder to choose **[I]** instead of failing.

---

## How the internals work

A quick tour for anyone wanting to read or extend the launcher:

- **`param([switch]$NoMenu)`** — lets the script be dot-sourced for tests without drawing the
  menu.
- **`$PSScriptRoot`** — the folder the script lives in. Everything (the backup script, the Node
  fallback, the `oc` shim target) is resolved relative to it, so the folder is relocatable.
- **`Read-MenuKey`** — reads one key with `[Console]::ReadKey($true)`; returns `ESC` for the
  Escape key, otherwise the uppercase character. This is what gives single-keypress navigation
  and an `ESC`-to-go-back that batch `choice` can't do.
- **Drawing** — `Write-Title`, `Write-Section`, `Write-Item` and `Write-StatusLine` render the
  theme using `Write-Host -ForegroundColor` / `-BackgroundColor`. The title bar and section
  labels are drawn as coloured bars (background colour), which render correctly on any console
  font — no box-drawing glyphs that can break on the raster font.
- **`Get-Status` / `Refresh-Status`** — the status line, cached at startup and refreshed after
  update/install/uninstall.
- **`Invoke-OpenCode`** — checks OpenCode is present, warns and returns to the menu if not,
  otherwise runs `opencode` (with optional arguments) in the chosen folder and returns to the
  menu when it exits.
- **`Show-MainMenu` / `Show-ManageMenu`** — `while ($true)` loops that draw the menu and switch
  on the key. `ESC` returns; `Q` (main menu only) exits.
- **`Write-OcShim` / `Add-DirToUserPath`** — write the `oc.cmd` shim and edit the **user**
  `PATH` with `[Environment]::SetEnvironmentVariable` (which, unlike `setx`, does not truncate a
  long `PATH`).
- **`install-node.ps1`** — queries `https://nodejs.org/dist/index.json` for the newest LTS
  release, picks the right MSI for `x64`/`arm64`, downloads it to `%TEMP%`, installs it with an
  elevated `msiexec`, and exits non-zero on failure.
- **Line endings matter for the `.cmd` shim:** it is written with `Set-Content -Encoding ASCII`,
  and `install.ps1`/`run.ps1` normalise downloaded files to CRLF. `.gitattributes` keeps `*.cmd`
  bytes as committed and checks `*.ps1` out as CRLF.

---

## Customising

- **Add a menu item:** add a `Write-Item "X" "Label" "hint"` line and a matching `"X" { ... }`
  case in the relevant `switch (Read-MenuKey)` block.
- **Change the theme:** edit the `$C_*` colour variables near the top (title, sections, keys,
  good/bad/warn).
- **Change the default current folder for [R]:** edit the `Get-Location` call in `Action-Run`,
  or use **[F]** to pick a folder each time.
- **Change the launcher version shown:** edit `$LauncherVersion`.

---

## License

MIT — see [LICENSE](LICENSE).

Version 2.0 — By Wayne Scicluna.
