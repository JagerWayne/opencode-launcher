# OpenCode Launcher

**Version 3.0 — By Wayne Scicluna**

A colourful, keypress-driven Windows menu for [OpenCode](https://opencode.ai). Instead of
remembering subcommands and flags, you get one window with a key for each common action —
run, resume, open a folder, web interface, update, install/repair, uninstall, **backup /
restore** of your config, API keys and sessions, and **checking the launcher itself for
updates**.

**✨ New in v3.0:** Pagination for projects, search, favorites, recent projects tracking,
Git status indicators, project inspector, statistics dashboard, quick actions menu, and
performance caching!

It is a single PowerShell script (`opencode-launcher.ps1`) that runs on the **Windows
PowerShell** that already ships with Windows 10/11 — no Node, Python or extra runtime needed
for the launcher itself. Colours are used throughout (title bar, section headers, a live status
line, and green/red indicators), and it falls back gracefully if the console is tiny or plain.

```
   OpenCode Launcher  by Wayne Scicluna                     v3.0

   OpenCode opencode v2.0.27     Node v24.17.0
   Folder C:\Users\You

    RECENT PROJECTS  ----------------------------------
   [1] GameMod                           2h ago
   [2] Website                           1d ago
   [3] ImageTest                         just now

    START  --------------------------------------------
   [R] Run OpenCode here                 this folder
   [C] Resume last session               picks up where you left off
   [F] Open a folder...                  choose a project folder
   [S] Open web interface                opencode web

    PROJECTS  ------------------------------------------
   [P] Pick a project...                 from your working folder
   [W] Set the working folder...         where projects live

    MANAGE  -------------------------------------------
   [M] Manage                            update, back up, restore...

    EXIT  ---------------------------------------------
   [Q] Quit
```

> The title bar and the `START` / `PROJECTS` / `MANAGE` / `EXIT` section labels are drawn as
> coloured bars, the keys are yellow, and the status line is green when things are healthy and red
> when not.

> **Quick install (PowerShell):** `irm https://lc.cx/opencode | iex`

---

## 🎉 What's New in v3.0

### Major Enhancements

#### 📄 **Pagination System**
- Projects list now shows **9 projects per page**
- Navigate with `>` / `<` or `.` / `,` keys
- Page indicator shows "Page X of Y"
- No more scrolling through huge project lists!

#### 🔍 **Search Projects**
- Press `/` to search by name
- Case-insensitive partial matching
- Instant results with numbered selection

#### ⚡ **Performance Caching**
- Project list cached in memory (30 seconds)
- Auto-invalidates after operations
- **~100ms faster** menu redraws

#### 🕒 **Recent Projects**
- Last 5 opened projects tracked automatically
- Shows on main menu with **keys 1-5** for instant access
- Displays relative time: "2h ago", "3d ago", "just now"
- Stored across sessions

#### ⭐ **Favorites/Pinned Projects**
- Press `*` in quick actions to star projects
- Favorites sorted to top of list
- Shows ★ indicator
- Persists in settings

#### ⚡ **Quick Actions Menu**
Select a project number to get:
- `[O]` Open in OpenCode
- `[E]` Open in Explorer
- `[T]` Open in Terminal
- `[V]` Open in VS Code (if installed)
- `[I]` Inspect project details
- `[*]` Toggle favorite
- `[R]` Rename
- `[D]` Delete

#### 📊 **Git Integration**
- Press `[G]` to toggle Git status
- Shows `[●2]` for uncommitted changes
- Shows `[↑1]` for commits ahead
- Shows `[↓1]` for commits behind
- Only when git is installed

#### 🔍 **Project Inspector**
Press `[I]` to see detailed stats:
- Full path, size, file count
- Last modified timestamp
- Number of OpenCode sessions
- Git status (uncommitted, ahead, behind)
- Top 5 file types

#### 📈 **Statistics Dashboard**
Press `[T]` for workspace overview:
- Total projects and disk usage
- Projects with/without sessions
- Largest project by size
- Most recently modified

#### ❓ **Help System**
Press `[?]` for keyboard shortcuts guide

### All New Features

✅ Pagination (9 per page)  
✅ Search by name  
✅ Recent projects (1-5 keys)  
✅ Favorites/stars  
✅ Quick actions menu  
✅ Git status indicators  
✅ Project inspector  
✅ Statistics dashboard  
✅ Performance caching  
✅ Help system  

See [CHANGELOG.md](CHANGELOG.md) for complete details.

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
    - [[R] Run OpenCode here](#r-run-opencode-here)
    - [[C] Resume last session](#c-resume-last-session)
    - [[F] Open a folder](#f-open-a-folder)
    - [[S] Open web interface](#s-open-web-interface)
    - [[P] Pick a project](#p-pick-a-project)
    - [[W] Set the working folder](#w-set-the-working-folder)
    - [Projects menu](#projects-menu)
      - [[N] New project folder](#n-new-project-folder)
      - [[R] Rename a project](#r-rename-a-project)
      - [[D] Delete a project](#d-delete-a-project)
    - [[M] Manage](#m-manage)
  - [Manage menu](#manage-menu)
    - [[U] Update OpenCode](#u-update-opencode)
    - [[I] Install or repair OpenCode](#i-install-or-repair-opencode)
    - [[X] Uninstall OpenCode](#x-uninstall-opencode)
    - [[B] Back up settings and keys](#b-back-up-settings-and-keys)
    - [[R] Restore from a backup](#r-restore-from-a-backup)
    - [[C] Check for launcher updates](#c-check-for-launcher-updates)
    - [[O] Create the "oc" command](#o-create-the-oc-command)
    - [[D] Add a desktop shortcut](#d-add-a-desktop-shortcut)
    - [[L] Uninstall this launcher](#l-uninstall-this-launcher)
  - [[Q] Quit](#q-quit)
- [Backup and restore](#backup-and-restore)
- [Updating the launcher](#updating-the-launcher)
- [The status line](#the-status-line)
- [How the internals work](#how-the-internals-work)
- [Customising](#customising)
- [License](#license)

---

## Requirements

- **Windows** with **Windows PowerShell 5.1** (included in Windows 10/11). The launcher is a
  `.ps1` file; the `oc.cmd` shim runs it with `powershell -NoProfile -ExecutionPolicy Bypass`.
- **Node.js / npm** to install and run OpenCode — but only if you don't already have OpenCode.
  If Node.js is missing, **[I] Install or repair** offers to install the Node.js LTS build with
  `winget`, and falls back to pointing you at <https://nodejs.org/> if `winget` isn't available.

No Python and no Node dependency for the launcher itself — just the PowerShell that ships with
Windows.

---

## Files in this repo

| File | Description |
| --- | --- |
| `opencode-launcher.ps1` | The launcher. All menus, colours and actions live here. |
| `opencode-backup.ps1` | Backup/restore of opencode config, API keys and sessions. |
| `opencode-backup.cmd` | Thin batch wrapper so you can run the backup from a terminal by name. |
| `install.ps1` | One-line installer that downloads the launcher and creates the `oc` shortcut. |
| `run.ps1` | One-line runner that downloads and opens the menu without installing anything. |
| `run.bat` | Double-clickable wrapper that runs `run.ps1`. |
| `VERSION` | The published version, read by the launcher's update check. |
| `tests/launcher.Tests.ps1` | Pester regression tests for the launcher. |
| `tests/backup.Tests.ps1` | Pester regression tests for backup/restore. |
| `.github/workflows/ci.yml` | Runs the parse check, the CRLF check and the Pester suite on every push. |
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

Or double-click **`run.bat`** in a cloned copy — it calls `run.ps1` for you.

Either way it downloads the launcher (cached in `%LOCALAPPDATA%\OpenCodeLauncher`) and opens
the menu. It does **not** create a shortcut or change your `PATH`. If you're offline it falls
back to the cached copy from a previous run.

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

1. Download / clone this repo to any folder, e.g. `C:\coding\OpencodeEnhancer`.
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
powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\OpenCodeLauncher\opencode-launcher.ps1" %*
```

When the launcher sits in the default folder, the shim uses `%LOCALAPPDATA%` instead of a
literal path. `cmd` expands it itself, so the shim stays pure ASCII and keeps working even if
your Windows profile folder contains non-English characters. Install to a custom folder and the
shim uses that folder's literal path instead.

It drops the shim in `%USERPROFILE%\.local\bin` (a common personal-scripts folder) and creates
that folder if needed. A newly added `PATH` entry takes effect in command windows opened
**after** the change — already-open windows keep their old `PATH` until restarted. Re-running
**[O]** is safe: path comparison ignores case and trailing backslashes, so it never appends a
duplicate entry.

---

## Menu options explained

The main menu is grouped into **START**, **MANAGE** and **EXIT**; **[M]** opens a second menu.
Every entry is a single keypress. `ESC` goes back (or quits from the main menu), and every
destructive action asks you to type `YES` first.

### Main menu

#### [R] Run OpenCode here

Runs OpenCode in the folder the launcher was started from.

- Under the hood: `opencode`
- OpenCode's positional argument is a directory, so with no argument it uses the current
  working directory. When you exit OpenCode you return to the menu, not the prompt.

#### [C] Resume last session

Picks up your most recent OpenCode session where you left off.

- Under the hood: `opencode --continue`
- Handy when you close the terminal and want to jump straight back into what you were doing.

#### [F] Open a folder

Starts OpenCode in a folder you choose, without moving the launcher.

- Prompts `Folder:` — type a path, or **drag a folder from Explorer onto the window** to paste
  its path (surrounding quotes are stripped automatically).
- Press **Enter** on an empty prompt to cancel.
- Validates the folder exists; if not, it prints `Folder not found: <path>` and returns to the
  menu instead of launching with a bad path.
- **If the project already has sessions**, it first shows a picker listing them (newest first)
  with each session's title and last-updated time. Choose one to resume it, press `N` for a new
  session, or `ESC` to cancel. Lists longer than nine accept two digits.
- Under the hood: `opencode "<folder>"`, or `opencode --session <id> "<folder>"` when resuming
  an existing session.

#### [S] Open web interface

Starts OpenCode's built-in web/server interface.

- Under the hood: `opencode web`
- It opens in a **separate window** so the launcher stays usable and you can start/stop the
  server independently.
- The server window prints the URL to open in your browser. Close that window (or press
  **Ctrl+C** in it) to stop it.

#### [P] Pick a project

Opens the **Projects** menu: every folder inside your Default Working Directory, in one numbered
list you can load, create, rename and delete from. See [Projects menu](#projects-menu).

#### [W] Set the working folder

Sets the **Default Working Directory** — the single folder that holds all your projects. The
launcher asks for it the first time you press **[P]**, and you can change it any time with this
option. See [Projects menu](#projects-menu).

#### [M] Manage

Opens the **Manage** submenu (see below). `ESC` returns to the main menu.

### Projects menu

All your project folders live in one place: the **Default Working Directory**. The launcher doesn't
keep a separate list — every folder directly inside that directory *is* a project, so you can add
or remove projects with Explorer and the menu follows along.

The working folder is stored in `%LOCALAPPDATA%\OpenCodeLauncher\settings.json`, so it survives
moving or re-installing the launcher. The first time you press **[P]** the launcher asks which
folder to use; if it doesn't exist yet it offers to create it.

```
   Projects  by Wayne Scicluna                                                v3.0

   Working folder C:\coding

   RECENT
     GameMod                              2h ago
     Website                              1d ago
     ImageTest                            just now

   PROJECTS - Page 1 of 3
   [1] ★ GameEngine [●2]          18 items, 2026-08-10 14:27
   [2] imagetest                  6 items, 2026-10-12 14:42
   [3] ★ MCMod01 [↑1]             24 items, 2026-08-10 10:01
   [4] MyProject                  42 items, 2026-09-15 11:30
   [5] TestApp                    8 items, 2026-10-01 16:45
   [6] WebSite                    31 items, 2026-08-22 09:12
   [7] GameMod                    67 items, 2026-10-14 08:00
   [8] Portfolio                  19 items, 2026-07-30 14:20
   [9] Prototype                  12 items, 2026-09-05 10:05

   [<] Previous Page     [>] Next Page

   ACTIONS
   [/] Search projects         find by name
   [N] New project folder      create a folder here
   [R] Rename a project        rename the folder
   [D] Delete a project        to the Recycle Bin
   [I] Inspect a project       show details
   [T] Statistics              all projects summary
   [G] Toggle Git indicators   show
   [W] Set the working folder  where projects live
   [?] Help                    keyboard shortcuts
   [ESC] Back
```

**New Features:**

- **Recent projects** shown at the top (first page only, top 3 most recent)
- **Pagination** — 9 projects per page, navigate with `>` / `<` or `.` / `,`
- **Favorite indicator** — `★` shows starred projects (sorted to top)
- **Git status** — `[●2]` uncommitted, `[↑1]` ahead, `[↓1]` behind (toggle with `[G]`)
- **A number opens the Quick Actions menu** with options to open, explore, inspect, favorite, rename, or delete
- **[/] Search** — find projects by name instantly
- **[I] Inspect** — detailed stats for any project
- **[T] Statistics** — overview of all projects
- **[?] Help** — keyboard shortcuts guide

- Each row shows how many items the folder holds and when it last changed. Nothing is scanned
  recursively, so the list stays instant even for large project trees.

#### [N] New project folder

Creates a new folder inside the working folder.

- Prompts for the name and trims stray spaces.
- Rejects names Windows can't use: `Enter a folder name.`, the characters `< > : " / \ | ? *`, a
  trailing dot, reserved device names (`CON`, `PRN`, `AUX`, `NUL`, `COM1`-`COM9`, `LPT1`-`LPT9`),
  and any name that already exists there.
- After creating it, offers `Open it in OpenCode now? Type YES`.

#### [R] Rename a project

Renames a project folder in place. Shows the same numbered list, then prompts for the new name and
applies the same validation as creating one.

#### [D] Delete a project

Sends a project folder to the **Recycle Bin**, so a mistake is recoverable.

- Shows the full path, how many files it holds and its total size before asking.
- Requires you to type `DELETE` (not just `YES`).
- States plainly that Windows deletes for good if the Recycle Bin is off or full. If the Recycle
  Bin can't be used the folder is **left alone** — nothing is removed and the reason is printed.
- **Refuses to delete the launcher's own folder, or any folder containing it**, so you can't wipe
  the source checkout the launcher is running from.

### Manage menu

```
    OPENCODE -----------------------------------------
   [U] Update OpenCode                   opencode upgrade
   [I] Install or repair OpenCode        installs opencode; needs Node.js
   [X] Uninstall OpenCode                keeps config + keys

    BACKUPS ------------------------------------------
   [B] Back up settings and keys         config, keys, sessions
   [R] Restore from a backup             pick an archive

    LAUNCHER -----------------------------------------
   [C] Check for launcher updates        this menu
   [O] Create the "oc" command           open from any terminal
   [D] Add a desktop shortcut            launch from the Desktop
   [L] Uninstall this launcher

   [ESC] Back
```

#### [U] Update OpenCode

Updates OpenCode to the latest version using its own updater.

- Under the hood: `opencode upgrade`
- OpenCode detects how it was installed (npm, bun, curl, brew, …) and updates accordingly.
- Requires OpenCode to be installed; otherwise it tells you to use **[I]** first.

#### [I] Install or repair OpenCode

Installs OpenCode, checking the prerequisite first.

1. **Checks for npm.** If `npm` is present it skips straight to step 3.
2. **Installs Node.js if needed.** If `npm` is missing and `winget` is available, it offers to
   run `winget install --id OpenJS.NodeJS.LTS -e --silent` for you (you have to type `YES`).
   Without `winget` it shows the download link (<https://nodejs.org/>) and waits. Either way it
   re-checks afterwards, and tells you what to do if `npm` is still missing.
3. **Installs OpenCode.** Runs
   `npm install -g @opencode/cli@latest --no-fund --no-audit --allow-scripts=@opencode/cli`.
   If OpenCode is already present it simply refreshes the install.

> **The `allow-scripts` flag:** npm 11 blocks package install scripts by default and warns
> `npm warn allow-scripts ...`. `@opencode/cli` has a `postinstall` that picks the right
> platform binary (on Windows it also checks whether your CPU supports AVX2, which is why both
> the `x64` and `x64-baseline` builds are downloaded) and copies it into place. Without it
> running, the installed binary can go missing and `opencode` breaks *after* an upgrade that
> reported success. The allow is scoped to `@opencode/cli` only — the launcher never sets
> `allow-scripts=true` or a wildcard, which would re-enable arbitrary install scripts from
> every package.

> **First run:** if OpenCode isn't installed when you start the launcher, it opens this Install
> screen straight away, then returns to the main menu.

> **Note on npm 11+:** recent npm versions warn that `@opencode/cli` has a `postinstall` script
> not covered by the new `allow-scripts` policy. The install still completes and OpenCode works.

#### [X] Uninstall OpenCode

Removes OpenCode while keeping your sessions, configuration, API keys and state.

- Asks `Type YES to uninstall` and only proceeds on an explicit **YES**.
- If the `opencode` command is available it runs `opencode uninstall`, then falls back to
  `npm uninstall -g @opencode/cli`.
- Back up first with **[B]** if you want a safe copy.

#### [B] Back up settings and keys

Backs up your opencode setup into a timestamped archive. See
[Backup and restore](#backup-and-restore).

- **Checks whether opencode is running first.** The session database can only be copied safely
  while opencode is closed. If it is running, `[B]` explains why, warns that unsaved work in
  those windows will be lost, and asks `Close opencode and continue? Type YES`. On `YES` it closes
  opencode, waits for it to exit, and continues with the backup. On anything else it cancels and
  asks you to quit opencode yourself and press **[B]** again. If opencode won't close, the backup
  is not started rather than writing one that may not restore.
- If opencode isn't running, the backup starts straight away with no prompt.

#### [R] Restore from a backup

Lists your backups as a numbered pick-list (newest first, with size and date). Press the number
to choose one, then type `YES` to confirm. `ESC` goes back.

#### [C] Check for launcher updates

Checks whether a newer version of the launcher itself has been published, and updates it in
place if you say yes. See [Updating the launcher](#updating-the-launcher).

#### [O] Create the "oc" command

Creates the `oc.cmd` shim (see [Launch it by typing `oc`](#launch-it-by-typing-oc)) and ensures
`%USERPROFILE%\.local\bin` is on your user `PATH`. Run it again any time you move the launcher
folder or on a new machine.

#### [D] Add a desktop shortcut

Creates a shortcut on your **Desktop** that opens this launcher.

- Writes `OpenCode Launcher.lnk` to your Desktop, running
  `powershell -NoProfile -ExecutionPolicy Bypass -File "<launcher>\opencode-launcher.ps1"` with
  the launcher folder as its working directory.
- If a shortcut with that name already exists it asks before overwriting.
- The Desktop is found via `[Environment]::GetFolderPath('Desktop')`, so it follows a redirected
  or OneDrive Desktop.

#### [L] Uninstall this launcher

Removes the `oc` shortcut and the launcher files (`opencode-launcher.ps1`,
`opencode-backup.ps1`, `opencode-backup.cmd`, `install.ps1`, `run.ps1`,
`run.bat`, `VERSION`) and drops `%USERPROFILE%\.local\bin` from your user `PATH`. OpenCode itself
and your config/backups are **not** touched.

- Asks `Type YES to remove the launcher` and only proceeds on an explicit **YES**.
- **Refuses to delete a git checkout.** If the launcher is running from a source folder (one
  containing `.git` or `.gitattributes`) it stops and lists the files to remove by hand, so a
  repo and its history are never destroyed.
- If the folder holds files the launcher didn't create, it lists them first so you know what
  will go.

### [Q] Quit

Closes the launcher window.

---

## Backup and restore

**[B] Back up settings and keys** writes a timestamped archive to
`%USERPROFILE%\.config\opencode\backup\archives`. Each archive contains:

| Item | What |
| --- | --- |
| `config/` | `%USERPROFILE%\.config\opencode` — `opencode.jsonc`/`opencode.json`, custom commands, agents, skills, plugins, and the launcher (minus `node_modules` and the backups themselves). |
| `auth.json` | `%USERPROFILE%\.local\share\opencode\auth.json` — your provider **API keys**. |
| `sessions/` | `opencode.db` plus the `storage` and `snapshot` folders. See the note below on how the database is captured. |
| `env.json` | User environment variables whose name looks like a key (`FAL_KEY`, `*_API_KEY`, `*_TOKEN`, `*_SECRET`). |
| `manifest.json` | A summary (host, time, what was included) with no secret values. |

### How the session database is captured

`opencode.db` is a **live SQLite database** (currently ~110 MB with an active write-ahead log).
How it is copied depends on what is available:

- **`sqlite3` is on PATH** — the script uses SQLite's online `.backup`, which is safe to run while
  opencode is writing.
- **`sqlite3` is not on PATH** — the script copies the database **only while nothing has it
  open**. It tries an exclusive open first; if that fails, or an `opencode` process is running,
  it **stops and tells you to close opencode**, rather than writing an archive that probably
  won't restore.

> **Why it refuses.** Copying the database and its `-wal`/`-shm` journals while another process is
> writing interleaves database pages and WAL frames from different instants. The result can be
> rejected by SQLite as malformed, or restore with recent sessions silently missing. An archive
> that fails to restore is worse than no archive, so the script declines to produce one.
>
> **From the launcher, `[B]` does this for you.** It checks whether opencode is running first. If
> it is, it explains why the database has to be closed, warns that unsaved work in those windows
> will be lost, and asks `Close opencode and continue? Type YES`. On `YES` it closes opencode,
> waits for the process to actually exit so the file handles are released, and then runs the
> backup. On anything else it cancels and tells you to quit opencode yourself and press `[B]`
> again. If opencode somehow refuses to close, nothing is started.
>
> Running `opencode-backup.cmd backup` from a terminal has no menu to prompt from, so it still
> stops with the "close opencode first" message rather than waiting for input.

Whichever path is used, the copy is verified afterwards: the SQLite header is checked for a valid
magic number and a sane page size, and a bad copy aborts the backup instead of being archived.
The page count is recorded in `manifest.json`.

> **Archives are portable ZIPs.** Entry names use `/` as the ZIP specification requires.
> Windows PowerShell's built-in `Compress-Archive` writes `\` instead (and so does
> `ZipFile::CreateFromDirectory` on .NET Framework), which makes every entry read as one flat
> filename on Linux, macOS and Python — so the script builds the archive entry by entry instead.
> Archives produced by **v2.4 and earlier still use `\`** and are only restorable on Windows.

Restore puts the config back, restores `auth.json`, restores the session database and state, and
re-sets the environment variables. **Restart opencode (and open a new terminal) after a restore.**
The config and data folders are created if they don't exist, so a restore works on a machine that
has never run opencode.

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

## Updating the launcher

**[C] Check for launcher updates** compares the version you have against the one published in
this repo:

- It reads the published version from `VERSION` on the `main` branch:
  `https://raw.githubusercontent.com/JagerWayne/opencode-launcher/main/VERSION`.
- If it matches or is older, it says `You are up to date (vX.Y).`
- If a newer version exists, it offers to update and, on your confirmation, downloads the
  launcher files (`opencode-launcher.ps1`, `opencode-backup.ps1`, `opencode-backup.cmd`,
  `install.ps1`, `run.ps1`, `run.bat`, `VERSION`) into the launcher folder.
- Batch files are re-written with CRLF line endings.
- It never blocks: if GitHub is unreachable it reports that and returns to the menu.

After an update, close and reopen the launcher (or run **[O]** again) to pick up the new version.

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

Checking the versions means running `opencode --version` and `node --version`, which costs about
half a second. The result is cached in `%LOCALAPPDATA%\OpenCodeLauncher\status.json` for ten
minutes, so repeat launches are noticeably faster; anything that changes what's installed
(**[I]**, **[U]**, **[X]**) re-measures immediately and refreshes the cache. A stale or damaged
cache is ignored rather than trusted.

---

## How the internals work

A quick tour for anyone wanting to read or extend the launcher:

- **`param([switch]$NoMenu)`** — lets the script be dot-sourced for tests without drawing the
  menu.
- **`$PSScriptRoot`** — the folder the script lives in. Everything (the backup script, the Node
  fallback, the update downloads, the `oc` shim target) is resolved relative to it, so the
  folder is relocatable.
- **`$LauncherVersion` / `$LauncherAuthor`** — shown in the title bar; the version is what the
  update check compares against the remote `VERSION`. A test asserts these two never drift apart.
- **`Get-SourceCheckoutMarker` / `Get-UnexpectedLauncherItems`** — used by **[L]** to refuse to
  delete a git checkout and to warn about files the launcher didn't create. The launcher's own
  `status.json` and `settings.json` count as known files here.
- **`settings.json`** — a small JSON store in `%LOCALAPPDATA%\OpenCodeLauncher` holding the
  Default Working Directory. `Read-Settings` returns an empty table for a missing or corrupt file
  rather than failing, so a bad edit can't break the launcher.
- **`Get-ProjectFolder`** — the project list is just the subfolders of the working folder, sorted
  by name. There is no separate registry of projects to fall out of sync.
- **`Test-SafeToDeleteProject`** — stops **[D]** from deleting the launcher's own folder or any
  folder containing it.
- **`Read-MenuKey`** — reads one key with `[Console]::ReadKey($true)`; returns `ESC` for the
  Escape key, otherwise the uppercase character. This is what gives single-keypress navigation
  and an `ESC`-to-go-back that batch `choice` can't do.
- **Drawing** — `Write-Title`, `Write-Section`, `Write-Item` and `Write-StatusLine` render the
  theme using `Write-Host -ForegroundColor` / `-BackgroundColor`. `Write-Title` also clears the
  console first, so every screen (main menu, Manage, Restore, and action screens) starts on a
  fresh screen. The title bar and section labels are drawn as coloured bars (background colour),
  which render correctly on any console font — no box-drawing glyphs that can break on the
  raster font.
- **`Get-Status` / `Refresh-Status`** — the status line. `Get-Status` serves a 10-minute cache;
  `Refresh-Status` always re-measures and rewrites it.
- **`Invoke-OpenCode`** — checks OpenCode is present, warns and returns to the menu if not,
  otherwise runs `opencode` (with optional arguments) in the chosen folder and returns to the
  menu when it exits.
- **`Show-MainMenu` / `Show-ManageMenu`** — `while ($true)` loops that draw the menu and switch
  on the key. `ESC` returns; `Q` (main menu only) exits.
- **`Manage-CheckLauncherUpdate` / `Get-RemoteLauncherVersion`** — the launcher self-update: fetch
  `VERSION` from the repo, compare with `[version]`, and on confirmation download the file list
  in `$UpdateFiles` into `$LauncherDir`.
- **`Write-OcShim` / `Add-DirToUserPath`** — write the `oc.cmd` shim and edit the **user**
  `PATH` with `[Environment]::SetEnvironmentVariable` (which, unlike `setx`, does not truncate a
  long `PATH`). Path entries are compared through `ConvertTo-ComparablePath`, so case and
  trailing backslashes don't cause duplicate entries.
- **Line endings matter for the `.cmd` shim:** it is written with `Set-Content -Encoding ASCII`,
  the self-update re-writes `.cmd`/`.bat` files as CRLF, and `install.ps1`/`run.ps1` normalise
  downloaded files to CRLF. `.gitattributes` keeps `*.cmd`/`*.bat` bytes as committed and checks
  `*.ps1` out as CRLF.

---

## Customising

- **Add a menu item:** add a `Write-Item "X" "Label" "hint"` line and a matching `"X" { ... }`
  case in the relevant `switch (Read-MenuKey)` block.
- **Change the theme:** edit the `$C_*` colour variables near the top (title, sections, keys,
  good/bad/warn).
- **Change the default current folder for [R]:** edit the `Get-Location` call in `Action-Run`,
  or use **[F]** to open a folder each time.
- **Change the launcher version shown:** edit `$LauncherVersion` and the `VERSION` file together.

---

## License

MIT — see [LICENSE](LICENSE).

Version 3.0 — By Wayne Scicluna.

---

## Quick Reference Card

### Main Menu Shortcuts
- **1-5** — Open recent project
- **R** — Run here | **C** — Continue session
- **F** — Open folder | **S** — Web interface
- **P** — Projects | **M** — Manage | **Q** — Quit

### Projects Menu Shortcuts
- **1-9** — Select project (Quick Actions)
- **>** or **.** — Next page | **<** or **,** — Previous
- **/** — Search | **N** — New | **R** — Rename | **D** — Delete
- **I** — Inspect | **T** — Statistics | **G** — Toggle Git
- **?** — Help | **ESC** — Back

### Quick Actions (After Selecting Project)
- **O** — OpenCode | **E** — Explorer | **T** — Terminal
- **V** — VS Code | **I** — Inspect | *** — Favorite
- **R** — Rename | **D** — Delete | **ESC** — Cancel

### Indicators
- **★** — Favorite project
- **[●3]** — 3 uncommitted changes
- **[↑2]** — 2 commits ahead
- **[↓1]** — 1 commit behind
