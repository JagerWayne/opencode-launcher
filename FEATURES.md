# OpenCode Launcher v3.0 - Feature Showcase

## Overview

OpenCode Launcher v3.0 brings **10 major enhancements** designed to make managing multiple projects effortless. Whether you have 5 or 500 projects, these features keep you productive.

---

## 🚀 Feature Highlights

### 1. **Pagination System** 📄

**Problem:** Large project lists were hard to navigate.

**Solution:** 
- Shows 9 projects per page
- Navigate with `>` (Next) and `<` (Previous)
- Also works with `.` and `,` for one-handed navigation
- Shows "Page 2 of 5" indicator

**Example:**
```
PROJECTS - Page 2 of 5
[1] Project10
[2] Project11
...
[9] Project18

[<] Previous Page     [>] Next Page
```

---

### 2. **Search Projects** 🔍

**Problem:** Finding a specific project in a long list was tedious.

**Solution:**
- Press `/` to search
- Type partial name (case-insensitive)
- Instant filtered results
- Press number to open, ESC to cancel

**Example:**
```
Search (Enter to cancel): game

Found 3 project(s) matching 'game':
[1] GameEngine
[2] GameMod
[3] Minigames
```

---

### 3. **Recent Projects** 🕒

**Problem:** Opening the same 3-5 projects repeatedly took multiple clicks.

**Solution:**
- Automatically tracks last 5 opened projects
- Shows on **main menu** with keys **1-5**
- Displays relative time: "2h ago", "3d ago", "just now"
- One keypress to reopen

**Example (Main Menu):**
```
RECENT PROJECTS
[1] GameMod          2h ago
[2] Website          1d ago
[3] ImageTest        just now
```

**Usage:**
- Just opened GameMod? Press `1` from main menu to reopen instantly
- No need to navigate through Projects menu
- Recent list updates automatically every time you open a project

---

### 4. **Favorites/Stars** ⭐

**Problem:** Important projects buried in alphabetical list.

**Solution:**
- Press `*` in Quick Actions to star/unstar
- Favorites automatically sorted to top
- Shows **★** indicator
- Stored in settings, persists across sessions

**Example:**
```
PROJECTS
[1] ★ ImportantWork     [●2]  45 items, 2026-10-14
[2] ★ MainProject             82 items, 2026-10-13
[3] ArchiveProject            12 items, 2026-08-01
```

**Tip:** Star your active projects to keep them at the top!

---

### 5. **Quick Actions Menu** ⚡

**Problem:** Opening a project took multiple steps; other operations required separate tools.

**Solution:**
When you select a project number, you now get a submenu with 8 actions:

```
Project Actions
   Project: GameMod

[O] Open in OpenCode       open with session selection
[E] Open in Explorer       file manager
[T] Open in Terminal       PowerShell window
[V] Open in VS Code        if installed
[I] Inspect project        show details
[*] Toggle favorite        add star
[R] Rename                 change folder name
[D] Delete                 to Recycle Bin

[ESC] Cancel
```

**Benefits:**
- One number press → full action menu
- Open in multiple tools (OpenCode, Explorer, Terminal, VS Code)
- Quick favorite/rename/delete without going through separate menus
- Context-aware (only shows VS Code option if installed)

---

### 6. **Git Integration** 📊

**Problem:** No visibility into Git status of projects.

**Solution:**
- Press `[G]` to toggle Git indicators on/off
- Shows inline status for each project:
  - `[●3]` — 3 uncommitted changes
  - `[↑2]` — 2 commits ahead of remote
  - `[↓1]` — 1 commit behind remote
- Only shown if git is installed and project has `.git` folder
- Performance optimized (cached per render)

**Example:**
```
PROJECTS
[1] ★ GameMod [●2][↑1]     67 items, 2026-10-14
[2] Website [↓3]           31 items, 2026-10-12
[3] CleanProject           19 items, 2026-10-11
```

**Interpretation:**
- GameMod: 2 uncommitted changes, 1 commit ahead (needs push)
- Website: 3 commits behind (needs pull)
- CleanProject: No Git changes

**Toggle:** Press `[G]` to show/hide (useful when Git checks slow things down)

---

### 7. **Project Inspector** 🔍

**Problem:** No way to see project details without opening it.

**Solution:**
Press `[I]` to inspect any project:

```
Project Details

   Name: GameMod
   Path: C:\coding\GameMod
   Size: 245.67 MB
   Files: 1,234
   Modified: 2026-10-14 14:32:15
   Sessions: 8

   Git Status:
     Uncommitted: 2
     Ahead: 1
     Behind: 0

   Top File Types:
     .js: 456
     .json: 89
     .md: 23
     .ts: 187
     .css: 67
```

**Use Cases:**
- Check project size before cleanup
- See session count (has anyone worked on this?)
- Verify Git status without opening project
- Quick file type breakdown

---

### 8. **Statistics Dashboard** 📈

**Problem:** No overview of workspace health.

**Solution:**
Press `[T]` for workspace-wide statistics:

```
Project Statistics

   Total Projects: 47
   Total Size: 12.34 GB
   Total Files: 45,678
   With Sessions: 23
   Never Opened: 24

   Largest Project:
     GameEngine - 1,234.5 MB

   Most Recent:
     GameMod - 2026-10-14 14:32
```

**Insights:**
- How much disk space are projects using?
- Which projects have never been opened? (cleanup candidates)
- What's the largest project? (size optimization target)
- What was I working on most recently?

**Use Cases:**
- Quarterly workspace cleanup
- Identify abandoned projects
- Disk space management
- Team onboarding (show project landscape)

---

### 9. **Performance Caching** ⚡

**Problem:** Large project folders caused menu lag.

**Solution:**
- Project list cached in memory for 30 seconds
- Auto-invalidates after New/Rename/Delete operations
- Manual refresh on cache timeout
- **~100ms faster** menu rendering

**Technical:**
```powershell
# Before: Scanned disk every redraw
Get-ChildItem $Root -Directory  # 150ms for 100 projects

# After: Cached for 30 seconds
Get-CachedProjectList           # 2ms on cache hit
```

**User Impact:**
- Instant menu redraws
- Smooth navigation between pages
- Responsive on network drives

---

### 10. **Help System** ❓

**Problem:** Users didn't know about advanced shortcuts.

**Solution:**
Press `[?]` in Projects menu for interactive help:

```
Projects Menu Help

   NAVIGATION:
  1-9        Open project by number
  10-99      Type two digits quickly
  > or .     Next page
  < or ,     Previous page

   ACTIONS:
  /          Search for a project
  *          Toggle favorite
  N          New project
  R          Rename
  D          Delete
  I          Inspect
  T          Statistics
  G          Toggle Git
  W          Working folder
  ESC        Back

   TIPS:
  ★ = Favorite project
  [●2] = 2 uncommitted changes
  [↑1] = 1 commit ahead
  [↓1] = 1 commit behind
```

**Benefits:**
- Discoverability of features
- No need to read full README
- Context-sensitive (only in Projects menu)
- Shows indicator meanings

---

## 🎯 Use Case Scenarios

### Scenario 1: Daily Developer Workflow

**Morning:**
1. Type `oc` to launch
2. See recent projects on main menu
3. Press `1` to open yesterday's work (GameMod)
4. Continue session automatically

**Afternoon:**
1. Press `ESC` to main menu
2. Press `P` for Projects
3. Press `/` to search "website"
4. Press `1` to open Website project

**Evening:**
1. Press `G` to check Git status
2. See `[●3]` on GameMod — 3 uncommitted changes
3. Select GameMod → Quick Actions → `[T]` Terminal
4. Commit and push changes

**Time Saved:** ~5 minutes/day = 20+ hours/year

---

### Scenario 2: Project Manager

**Monthly Review:**
1. Launch Projects menu
2. Press `T` for Statistics
3. See: "24 projects never opened" → cleanup candidates
4. See: "Largest: GameEngine 1.2GB" → optimization target
5. Press `I` on suspicious project → Inspect details
6. Decide: Archive or keep?

**Quarterly Cleanup:**
1. Press `D` to delete old projects (Recycle Bin safety)
2. Use `*` to favorite active projects
3. Projects auto-sort: Active at top, old at bottom

---

### Scenario 3: Team Lead Onboarding New Dev

**Show Workspace:**
1. Press `T` — "We have 47 projects, 12GB total"
2. Press `G` — "Red indicators mean needs attention"
3. Navigate pages — "These are organized by type"
4. Press `*` on key projects — "Stars mark must-know projects"

**Quick Tour:**
1. Press `1` on ImportantProject
2. Quick Actions → `[I]` Inspect
3. Show: "8 sessions, 245MB, mostly TypeScript"
4. Quick Actions → `[O]` Open in OpenCode

---

## 🔧 Power User Tips

### Tip 1: Two-Digit Navigation
Projects 10-99 can be selected by typing digits quickly:
- Press `1` then `5` rapidly → Opens project 15
- Press `1` then wait → Opens project 1

### Tip 2: Keyboard Combos
- `P` → `/` → type name → `1` — Search and open in 4 keys
- `P` → `G` → `1-9` → `O` — Check Git, select project, open

### Tip 3: Favorites + Recent = Instant Access
- Star your top 5 projects
- Recent tracks your last 5 opened
- Combined: Top 10 projects always 1-2 keys away

### Tip 4: Offline Git Checks
Toggle Git indicators off (`[G]`) when:
- On slow network drive
- Working offline
- Need fastest possible menu

### Tip 5: Statistics for Automation
Export stats to decide:
- Which projects to back up (largest)
- Which to archive (never opened)
- Which need attention (Git status)

---

## 📊 Performance Metrics

| Operation | Before (v2.8) | After (v3.0) | Improvement |
|-----------|---------------|--------------|-------------|
| Menu Redraw (100 projects) | 150ms | 2-50ms | **75-97%** |
| Open Recent Project | 5 clicks | 1 key | **80%** |
| Find Project | Scroll + count | `/` + type | **instant** |
| Check Git Status | Manual | 1 key toggle | **automated** |
| Inspect Project | Open + explore | `[I]` | **5s → instant** |

---

## 🎨 Visual Indicators Guide

| Symbol | Meaning | Color |
|--------|---------|-------|
| ★ | Favorite/starred project | Cyan |
| [●3] | 3 uncommitted Git changes | Yellow |
| [↑2] | 2 commits ahead of remote | Yellow |
| [↓1] | 1 commit behind remote | Yellow |
| 2h ago | Last opened 2 hours ago | Magenta |
| [1] | Numeric selector | Yellow |

---

## 🔮 Future Possibilities (v3.1+)

Based on the v3.0 architecture, here are potential future additions:

1. **Project Templates** — Scaffold new projects from predefined structures
2. **Color Coding** — Visual categories (Work=Green, Personal=Blue, Archive=Gray)
3. **Bulk Operations** — Archive multiple projects at once
4. **Multi-Root Support** — Multiple working folders (Work, Personal, Experiments)
5. **Session Health** — Show crashed/corrupted sessions with ⚠️
6. **Project Icons** — Auto-detect type (🐍 Python, ⚛️ React, 🎮 Game)
7. **Export Report** — Generate HTML/CSV of all projects
8. **Team Sync** — Share favorites list via Git

---

## 📚 Related Documentation

- [CHANGELOG.md](CHANGELOG.md) — Full v3.0 release notes
- [README.md](README.md) — Complete user guide
- [LICENSE](LICENSE) — MIT license

---

## 🙏 Acknowledgments

Thanks to the OpenCode community for feedback and feature requests that shaped v3.0!

---

**OpenCode Launcher v3.0** — Making project management effortless.

By Wayne Scicluna | [GitHub](https://github.com/JagerWayne/opencode-launcher)
