# OpenCode Launcher

**Version 1.0 — By Wayne Scicluna**

A tiny, dependency-free Windows launcher for [OpenCode](https://opencode.ai) that turns the
raw `opencode` CLI into a friendly menu. Instead of remembering subcommands and flags, you
get one window with a keypress for each common action — run, resume, install, update, serve,
and more.

It is written as a plain batch file (`opencode-launcher.cmd`) so it works on any Windows
machine with no runtime to install. A companion PowerShell script is used only as a fallback
for setting up Node.js on machines that don't have `winget`.

```
==========================================
            OpenCode Launcher
         Version 1.0  -  By Wayne Scicluna
==========================================

   OpenCode: installed    Node/npm: found

   [R]  Run OpenCode (current folder)
   [C]  Continue last session  (--continue)
   [D]  Run in a specific folder...
   [S]  Launch v2 web / server   (opencode serve)
   [U]  Update OpenCode
   [T]  Check for updates before each run:  OFF
   [I]  Install / repair OpenCode  (installs Node.js if needed)
   [O]  Set up the "oc" command shortcut
   [X]  Uninstall OpenCode
   [Q]  Quit

 Select an option [R, C, D, S, U, T, I, O, X, Q]:
```

---

## Contents

- [Requirements](#requirements)
- [Files in this repo](#files-in-this-repo)
- [Getting started](#getting-started)
  - [Run it directly (no install)](#run-it-directly-no-install)
  - [Install with one PowerShell command](#install-with-one-powershell-command)
- [Launch it by typing `oc`](#launch-it-by-typing-oc)
- [Menu options explained](#menu-options-explained)
  - [[R] Run OpenCode (current folder)](#r-run-opencode-current-folder)
  - [[C] Continue last session](#c-continue-last-session)
  - [[D] Run in a specific folder](#d-run-in-a-specific-folder)
  - [[S] Launch v2 web / server](#s-launch-v2-web--server)
  - [[U] Update OpenCode](#u-update-opencode)
  - [[T] Check for updates before each run](#t-check-for-updates-before-each-run)
  - [[I] Install / repair OpenCode](#i-install--repair-opencode)
  - [[O] Set up the "oc" command shortcut](#o-set-up-the-oc-command-shortcut)
  - [[X] Uninstall OpenCode](#x-uninstall-opencode)
  - [[Q] Quit](#q-quit)
- [The status line](#the-status-line)
- [Configuration file](#configuration-file)
- [How the internals work](#how-the-internals-work)
- [Customising](#customising)
- [License](#license)

---

## Requirements

- **Windows** (cmd; also works when launched from PowerShell or Windows Terminal).
- **Node.js / npm** to install and run OpenCode — but you only need this *if* you don't
  already have OpenCode. The launcher's **[I] Install** option can install Node.js for you.
- **`winget`** is used to install Node.js automatically when it's missing. If `winget` is not
  available, the bundled `install-node.ps1` downloads the official Node.js LTS installer
  instead.

No Python, no Node dependency for the launcher itself — it's just batch.

---

## Files in this repo

| File | Description |
| --- | --- |
| `opencode-launcher.cmd` | The launcher. All menus and actions live here. |
| `install-node.ps1` | Fallback Node.js LTS installer, used only when `winget` is unavailable. |
| `install.ps1` | One-line installer that downloads the launcher and creates the `oc` shortcut. |
| `run.ps1` | One-line runner that downloads and opens the menu without installing anything. |
| `README.md` | This document. |
| `LICENSE` | MIT licence. |

The launcher also creates one file at runtime:

| File | Description |
| --- | --- |
| `opencode-launcher.cfg` | Stores your remembered settings (currently the "check for updates before each run" toggle). Created on first toggle; safe to delete. |

---

## Getting started

### Run it directly (no install)

To open the menu right away without installing anything, run this in PowerShell:

```powershell
irm https://raw.githubusercontent.com/JagerWayne/opencode-launcher/main/run.ps1 | iex
```

It downloads the launcher (cached in `%LOCALAPPDATA%\OpenCodeLauncher`) and opens the menu.
It does **not** create a shortcut or change your `PATH`. If you're offline it falls back to the
cached copy from a previous run.

### Install with one PowerShell command

On any Windows machine, open PowerShell and run:

```powershell
irm https://raw.githubusercontent.com/JagerWayne/opencode-launcher/main/install.ps1 | iex
```

That downloads the launcher to `%LOCALAPPDATA%\OpenCodeLauncher`, creates the `oc` shortcut,
and puts it on your `PATH`. Then just type `oc` in any command window. No git or clone needed.

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
2. Double-click `opencode-launcher.cmd` (or run it from a terminal).
3. If OpenCode isn't installed yet, press **I** and let it set everything up.
4. Press **O** to create the `oc` shortcut so you can launch it by typing `oc`.

You can also make a desktop shortcut to `opencode-launcher.cmd` and pin it to the Start menu
or taskbar. Because everything is relative to the script's own folder (`%~dp0`), you can move
the folder anywhere you like — just re-run **O** if you move it after creating the `oc` shim.

---

## Launch it by typing `oc`

Option **[O]** creates a one-line shim (`oc.cmd`) that calls the launcher, and makes sure its
folder is on your user `PATH`. After that, typing:

```cmd
oc
```

in any command window opens the launcher menu. It prefers to drop the shim in
`%USERPROFILE%\.local\bin` (a common personal-scripts folder); if that folder doesn't exist it
puts the shim next to the launcher and adds *that* folder to `PATH` instead.

A newly added `PATH` entry takes effect in command windows opened **after** the change —
already-open windows keep their old `PATH` until restarted.

---

## Menu options explained

Each option below lists the key you press, what it does, and the exact OpenCode command it
runs.

### [R] Run OpenCode (current folder)

Runs OpenCode in the folder the launcher lives in.

- Under the hood: `opencode`
- OpenCode's positional argument is a directory, so with no argument it uses the current
  working directory (the launcher's folder).
- When it checks for updates first (see **[T]**), that check runs before OpenCode starts.
- When you exit OpenCode you are returned to the menu, not dumped back to the prompt.

### [C] Continue last session

Resumes your most recent OpenCode session.

- Under the hood: `opencode --continue`
- Handy when you close the terminal and want to jump straight back into what you were doing.
- Also runs the update check first if enabled, then returns to the menu on exit.

### [D] Run in a specific folder

Starts OpenCode in a folder you choose, without moving the launcher.

- Prompts `Folder:` — type a path, or **drag a folder from Explorer onto the window** to paste
  its path (surrounding quotes are stripped automatically).
- Press **Enter** on an empty prompt to cancel.
- Validates the folder exists; if not, it prints `Folder not found: <path>` and returns to the
  menu instead of launching with a bad path.
- Under the hood: `opencode "<folder>"` (the directory is passed as OpenCode's positional
  argument).

### [S] Launch v2 web / server

Starts OpenCode's built-in server so you can use the web/API interface.

- Under the hood: `opencode serve`
- It opens in a **separate window** (`start ... cmd /k opencode serve`) so the launcher stays
  usable and you can start/stop the server independently.
- The server window prints the URL to open in your browser.
- Close that window (or press **Ctrl+C** in it) to stop the server. The launcher does **not**
  run the update check before this, since it isn't an interactive run.

### [U] Update OpenCode

Updates OpenCode to the latest version using its own updater.

- Under the hood: `opencode upgrade`
- OpenCode detects how it was installed (npm, bun, curl, brew, …) and updates accordingly.
- Runs in the launcher window and returns to the menu when done.
- Requires OpenCode to be installed; otherwise it tells you to use **[I]** first.

### [T] Check for updates before each run

Toggles a remembered on/off setting. When **ON**, every run action (**R**, **C**, **D**) first
checks whether a newer OpenCode exists and offers to update before launching.

The check itself:

- Reads your installed version with `opencode --version`.
- Reads the latest published version with `npm view @opencode/cli version`.
- If they match: prints `You are up to date (vX.Y.Z).` and continues.
- If a newer version exists: prints `A newer OpenCode is available: vOld -> vNew` and asks
  `Update now before running? [Y, N]`. **Y** runs `opencode upgrade`; **N** skips and runs.
- If npm is offline or unreachable: it says so and simply continues — it never blocks you.

The setting is stored in `opencode-launcher.cfg` next to the script, so it persists between
launches. It only affects the interactive runs (R/C/D); **[S]** and **[U]** are unaffected.
Updating requires network access, so on a disconnected machine the check is skipped gracefully.

### [I] Install / repair OpenCode

Installs OpenCode, ensuring the prerequisites are present first.

1. **Detects prerequisites.** It checks for `npm`. If `npm` is present, it skips straight to
   step 3.
2. **Installs Node.js if needed.** If `npm` is missing it installs Node.js LTS:
   - via `winget`: `winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements`, then adds `%ProgramFiles%\nodejs` to `PATH` for the current session, **or**
   - if `winget` is unavailable, by running the bundled `install-node.ps1`, which downloads the
     latest LTS MSI from nodejs.org and installs it (Windows will prompt for administrator
     permission via UAC).
   - If Node.js still isn't available afterwards, it tells you to install it from
     <https://nodejs.org/> and stops.
3. **Installs OpenCode.** Runs `npm install -g @opencode/cli`. If OpenCode is already present
   it prints `reinstalling / repairing` and simply refreshes the install.

> **Note on npm 11+:** recent npm versions warn that `@opencode/cli` has a `postinstall`
> script not covered by the new `allow-scripts` policy. The install still completes and
> OpenCode works. If you ever want to explicitly allow it, run
> `npm install -g --allow-scripts=@opencode/cli`.

### [O] Set up the "oc" command shortcut

Creates a small `oc.cmd` shim and puts it on your `PATH` so you can open the launcher by
typing `oc`.

- Chooses a location: `%USERPROFILE%\.local\bin` if it exists, otherwise the launcher's own
  folder.
- Writes a shim that calls the launcher by its absolute path:
  ```bat
  @echo off
  rem Launches the OpenCode Launcher menu. Created by opencode-launcher.cmd.
  call "C:\path\to\opencode-launcher.cmd" %*
  ```
- Ensures the shim's folder is on your **user** `PATH` (using PowerShell's
  `[Environment]::SetEnvironmentVariable`, which — unlike `setx` — does not truncate a long
  `PATH`).
- If an `oc.cmd` already exists there it asks `Overwrite it? [Y, N]` before replacing it.

Run this again any time you move the launcher folder (so the shim points at the new path) or
on a new machine.

### [X] Uninstall OpenCode

Removes OpenCode while keeping your sessions, configuration and state.

- Asks `Proceed with uninstall? [Y, N]` and only proceeds on an explicit **Y**. (The prompt is
  hardened so an unexpected keypress can never trigger removal.)
- If the `opencode` command is available, it runs `opencode uninstall --force` (OpenCode's own
  uninstaller detects the install method).
- Otherwise it falls back to `npm uninstall -g @opencode/cli`.
- Your session data, config and state are preserved — only the program is removed.

### [Q] Quit

Closes the launcher window.

---

## The status line

The line just under the title is refreshed every time the menu is drawn:

```
   OpenCode: installed    Node/npm: found
```

- **OpenCode** — `installed` or `NOT installed`, based on whether `opencode` is on your `PATH`.
- **Node/npm** — `found` or `missing`, based on whether `npm` is on your `PATH`.

This lets you see at a glance whether you need to run **[I]** first. If OpenCode isn't
installed, the run/update actions print a reminder to choose **[I]** instead of failing.

---

## Configuration file

Settings are stored in `opencode-launcher.cfg`, created next to the launcher the first time you
toggle a setting:

```ini
autocheck=0
```

| Key | Values | Meaning |
| --- | --- | --- |
| `autocheck` | `0` / `1` | `1` = check for updates before each run (**T**); `0` = off. |

You can edit it by hand or delete it to reset to defaults (`autocheck=0`).

---

## How the internals work

A quick tour for anyone wanting to read or extend the script:

- **`setlocal EnableExtensions`** — enables extended batch syntax (`%~dp0`, `for /f`, etc.)
  and scopes any variables the script sets.
- **`%~dp0`** — the drive + path of the script, with a trailing backslash. Everything
  (config path, fallback script path, the `oc` shim target) is resolved relative to this, which
  is why the folder is relocatable.
- **`:menu`** — clears the screen, calls `:detect`, renders the list, then waits for a single
  keypress.
- **`choice /c RCDSUTIOXQ`** — waits for one of the listed keys. `choice` sets `ERRORLEVEL` to
  the **1-based position** of the pressed key in the list, so the script dispatches with a chain
  of `if errorlevel N goto ...` checks, **highest number first** (batch evaluates `if errorlevel`
  as "greater than or equal to"). Any unexpected value falls through to `goto :menu`, so a stray
  key can never trigger an action.
- **`:detect`** — sets `hasopencode` and `hasnpm` using `where ... >nul 2>&1` (output
  suppressed) and `&&`.
- **`:needoc`** — guard that warns and returns to the menu if OpenCode isn't installed; called
  by every action that needs the CLI.
- **`:installnode`** — prefers `winget`; falls back to running `install-node.ps1`; otherwise
  advises a manual install.
- **`:prerun` / `:checkupdate`** — the optional pre-run update check (see **[T]**). Version
  strings are read with `for /f` over the command output, and compared with `if /i "%cur%"=="%latest%"`.
- **Yes/No prompts** — each one stores the result as `set "ans=%errorlevel%"` and only acts when
  `ans` is exactly `1`, so an error/empty response is treated as "No" rather than defaulting to a
  destructive action.
- **`install-node.ps1`** — queries `https://nodejs.org/dist/index.json` for the newest LTS
  release, picks the right MSI for `x64`/`arm64`, downloads it to `%TEMP%`, installs it with an
  elevated `msiexec`, and exits non-zero on failure.

---

## Customising

- **Add a menu item:** add a key to the `choice /c ...` string, add an `echo    [X]  ...` line,
  and add a matching `if errorlevel N goto :label` in the right order (remember the
  highest-first rule). Then add the label.
- **Change the default current folder for [R]:** edit the `opencode` line in `:run`, or use
  **[D]** to pick a folder each time.
- **Change the update-check source:** the `npm view @opencode/cli version` line in
  `:checkupdate` can point at any source you trust.

---

## License

MIT — see [LICENSE](LICENSE).

Version 1.0 — By Wayne Scicluna.
