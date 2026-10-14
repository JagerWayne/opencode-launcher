# OpenCode Launcher Changelog

## Version 3.1 - Uniform 1-9 lists

Every numbered list in the launcher is now capped at nine rows per page and
navigated with keys `1`-`9`; two-digit entry is gone.

- **Project folders** - the Rename / Delete / Inspect picker and the search
  results now page at nine per page (previously listed every folder as 1..N).
- **Sessions** - the "Open a project" session picker now pages at nine per page.
- **Backups** - the Restore list now pages at nine per page.
- `[<]`/`[>]` (or `,`/`.`) move between pages everywhere a list is shown.
- Removed the now-unused two-digit index helper.
- The `ProjectsPageSize` cap (9) is covered by a regression test.

## Version 3.0 - Major Enhancement Release

### 🎉 Phase 1: Core Improvements (Completed)

#### ✅ Pagination System
- Projects list now shows 9 projects per page
- Navigate with `>` (Next) and `<` (Previous) keys
- Also works with `.` (Next) and `,` (Previous)
- Page indicator shows "Page X of Y"
- Automatic page bounds handling

#### ✅ Search & Filter
- Press `/` to search projects by name
- Case-insensitive partial matching
- Instant results with numbered selection
- Shows match count

#### ✅ Performance Caching
- Project list cached in memory for 30 seconds
- Auto-invalidates after New/Rename/Delete operations
- Manual refresh with cache timeout
- Reduces filesystem scans by ~100ms per redraw

### 🚀 Phase 2: Power User Features (Completed)

#### ✅ Recent Projects
- Tracks last 5 opened projects automatically
- Shows on main menu with keys 1-5
- Displays relative time ("2h ago", "3d ago", "just now")
- Also shown in Projects menu (first page, top 3)
- Stored in settings.json with timestamps
- Opens directly from main menu

#### ✅ Favorites/Pinned Projects
- Press `*` in quick actions to star/unstar projects
- Favorites sorted to top of list
- Shows ★ indicator next to favorite projects
- Stored in settings.json
- Persists across sessions

#### ✅ Quick Actions Menu
When you select a project (1-9), you now get a submenu:
- `[O]` Open in OpenCode (with session selection)
- `[E]` Open in Explorer (file manager)
- `[T]` Open in Terminal (PowerShell)
- `[V]` Open in VS Code (if installed)
- `[I]` Inspect project (detailed stats)
- `[*]` Toggle favorite (star/unstar)
- `[R]` Rename
- `[D]` Delete
- `[ESC]` Cancel

### 🎨 Phase 3: Polish Features (Completed)

#### ✅ Git Integration
- Press `[G]` to toggle Git status indicators
- Shows on each project line:
  - `[●2]` - 2 uncommitted changes
  - `[↑1]` - 1 commit ahead of remote
  - `[↓1]` - 1 commit behind remote
- Only shown if git is installed and project has .git folder
- Cached per-render for performance

#### ✅ Project Inspector
- Press `[I]` to inspect any project
- Shows:
  - Full path
  - Total size (MB/GB)
  - File count
  - Last modified timestamp
  - Number of OpenCode sessions
  - Git status (uncommitted, ahead, behind)
  - Top 5 file types with counts
- Non-blocking, press any key to return

#### ✅ Help System
- Press `[?]` for keyboard shortcuts guide
- Shows all available keys and their actions
- Tips for navigation and features
- Explains indicator symbols (★, ●, ↑, ↓)

### 📊 Phase 4: Advanced Features (Completed)

#### ✅ Project Statistics Dashboard
- Press `[T]` for overview of ALL projects:
  - Total project count
  - Total disk usage (GB)
  - Total file count
  - Projects with sessions vs never opened
  - Largest project by size
  - Most recently modified project
- Useful for workspace management

---

## New Settings Schema

Your `settings.json` now supports:

```json
{
  "ProjectsDir": "C:\\Projects",
  "RecentProjects": [
    {
      "path": "C:\\Projects\\GameMod",
      "opened": 1697234567890
    }
  ],
  "FavoriteProjects": [
    "C:\\Projects\\Important",
    "C:\\Projects\\Work"
  ]
}
```

---

## Keyboard Shortcuts Reference

### Main Menu
- `1-5` - Open recent project directly
- `R` - Run OpenCode here
- `C` - Resume last session
- `F` - Open a folder
- `S` - Open web interface
- `P` - Pick a project (Projects menu)
- `M` - Manage (update, backup, etc.)
- `Q` or `ESC` - Quit

### Projects Menu
- `1-9` - Select project (opens quick actions); at most nine rows per page
- `>` or `.` - Next page
- `<` or `,` - Previous page
- `/` - Search projects
- `N` - New project folder
- `R` - Rename a project
- `D` - Delete a project
- `I` - Inspect a project
- `T` - Statistics dashboard
- `G` - Toggle Git indicators
- `W` - Set working folder
- `?` - Help
- `ESC` - Back to main menu

### Quick Actions (After Selecting Project)
- `O` - Open in OpenCode
- `E` - Open in Explorer
- `T` - Open in Terminal
- `V` - Open in VS Code
- `I` - Inspect details
- `*` - Toggle favorite
- `R` - Rename
- `D` - Delete
- `ESC` - Cancel

---

## Visual Indicators

- `★` - Favorite/starred project
- `[●3]` - 3 uncommitted changes (Git)
- `[↑2]` - 2 commits ahead of remote (Git)
- `[↓1]` - 1 commit behind remote (Git)
- Magenta text - Recent projects
- Cyan star - Favorite marker
- Yellow brackets - Git status

---

## Performance Improvements

1. **Project List Caching**: 30-second cache reduces disk I/O
2. **Pagination**: Only renders 9 items at a time
3. **Lazy Git Status**: Only checked when toggled on
4. **Smart Invalidation**: Cache cleared only when needed

---

## Breaking Changes

None! All new features are opt-in and backward compatible.

---

## Upgrade Instructions

1. **Backup your current launcher** (optional but recommended)
2. **Download the new version** or pull from git
3. **Run the launcher** - all settings preserved
4. **Try the new features**:
   - Open a project to add it to recent list
   - Press `*` in quick actions to star your favorites
   - Press `?` in Projects menu for help

---

## Compatibility

- Requires PowerShell 5.1+ (same as v2.8)
- Windows 10/11 (same as v2.8)
- Git is optional (for Git indicators)
- VS Code is optional (for quick actions)

---

## Known Limitations

1. Git status scanning adds ~50ms per project when enabled
2. Recent projects limited to 5 (design choice)
3. Pagination fixed at 9 items per page (optimal for console)
4. Search is case-insensitive partial match only (no regex)

---

## Future Enhancements (v3.1+)

Possible additions based on user feedback:

1. **Project Templates** - Scaffold new projects with predefined structures
2. **Color Coding** - Visual categories for projects
3. **Bulk Operations** - Archive/export multiple projects
4. **Multi-Root Support** - Multiple working folders
5. **Session Health Indicators** - Show crashed sessions
6. **Project Icons** - Detect project type (Python, JS, etc.)

---

## Credits

- **Original Author**: Wayne Scicluna
- **Enhancement Release**: v3.0
- **Contributors**: Community feedback and testing

---

## Support

- **Issues**: Report bugs via GitHub issues
- **Feature Requests**: Open a discussion
- **Documentation**: See README.md

---

## License

Same as original OpenCode Launcher (check LICENSE file)
