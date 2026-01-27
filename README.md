# OASIS

**Organized Automatic Sorting & Intelligent Structure**

A lightweight macOS utility that automatically organizes your Downloads folder into a clean, hierarchical structure.

## What It Does

OASIS automatically sorts files in your Downloads folder into:
- **Daily folders** (e.g., `Jan 14/`) with category subfolders
- **Weekly folders** (e.g., `Week 2 (Jan 6-12)/`) containing daily folders
- **Monthly folders** (e.g., `January 2026/`) containing weekly folders

### Folder Structure

```
~/Downloads/
├── January 2026/                     # Month folder (created at start of month)
│   ├── Week 1 (Jan 1-5)/             # Completed weeks roll into month
│   │   ├── Jan 1/                    # Daily folder
│   │   │   ├── Images/               # Photos, graphics
│   │   │   ├── Documents/            # PDFs, Office docs
│   │   │   ├── Videos/               # Video files
│   │   │   ├── Audio/                # Music, podcasts
│   │   │   └── Other/                # Everything else
│   │   └── Jan 2/
│   └── Week 2 (Jan 6-12)/            # Rolled in once Jan 13 arrives
├── Week 3 (Jan 13-19)/               # Current week (stays at root)
│   ├── Jan 13/                       # Completed days in current week
│   └── Jan 14/
└── photo.png, doc.pdf, ...           # Today's downloads (stay loose)
```

### File Categories

| Category | Extensions |
|----------|------------|
| Images | jpg, jpeg, png, gif, webp, svg, heic, psd, ai, etc. |
| Documents | pdf, doc, docx, xls, xlsx, ppt, txt, md, csv, etc. |
| Videos | mp4, mov, avi, mkv, webm, m4v, etc. |
| Audio | mp3, wav, aac, flac, ogg, m4a, etc. |
| Other | Everything else (dmg, zip, pkg, etc.) |

## Installation

### Quick Install

```bash
git clone https://github.com/samhayek-code/OASIS.git
cd OASIS
./install.sh
```

### One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/samhayek-code/OASIS/main/install.sh | bash
```

### Granting Full Disk Access

After installation, you'll be prompted to grant Full Disk Access to the OASIS app. This is required for the automatic midnight organization to work (macOS restricts background processes from accessing ~/Downloads).

1. Open **System Settings → Privacy & Security → Full Disk Access**
2. Click the **+** button
3. Press **Cmd+Shift+G** and paste: `~/.local/share/oasis`
4. Select **OASIS.app** and click **Open**

This is a one-time setup. The installer will offer to open System Settings for you.

### Updating

To update OASIS, simply re-run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/samhayek-code/OASIS/main/install.sh | bash
```

## Usage

### Terminal Commands

```bash
oasis run              # Organize Downloads now
oasis run --dry-run    # Preview what would be organized (no changes made)
oasis enable           # Turn on automatic organization
oasis disable          # Turn off automatic organization
oasis toggle           # Switch between on/off
oasis status           # Check if enabled or disabled
oasis version          # Show version number
oasis help             # Show help
```

### Quick Toggle Scripts

After installation, double-clickable scripts are available at:
```
~/.config/oasis/shortcuts/
├── Enable OASIS.command
├── Disable OASIS.command
└── Toggle OASIS.command
```

Drag these to your Dock for quick access.

### Spotlight Integration

You can create macOS Shortcuts to control OASIS from Spotlight. See `shortcuts/SETUP.md` for detailed instructions.

## How It Works

1. **Progressive organization** — OASIS builds your folder structure as time passes:
   - **Month folder** is created at the start of each month (or when you first run OASIS)
   - **Week folders** are moved into the month folder once the week completes
   - **Day folders** are moved into their week folder once the day completes
   - **Loose files** stay in Downloads during the day, then get organized at midnight

2. **Daily at midnight** (or on wake/login if asleep), OASIS:
   - Sorts loose files into dated folders based on **when the file was downloaded** (not when the script runs)
   - Files from yesterday go into yesterday's folder, even if organized this morning
   - Today's files stay loose until the next midnight run
   - Completed days roll into week folders, completed weeks roll into the month folder

3. **Week structure** is aligned to Mon-Sun:
   - Week 1 = 1st of month through first Sunday
   - Week 2+ = Full Monday-Sunday weeks
   - Final week may be partial

4. **Smart handling**:
   - Skips hidden files and partially downloaded files (`.crdownload`, `.part`, `.tmp`, etc.)
   - Empty category folders aren't created
   - File conflicts handled with numeric suffixes
   - Folder merging when organizing overlapping date ranges
   - Automatic log rotation (keeps last 1000 entries)
   - Timezone-aware date detection using Spotlight metadata

## Uninstallation

```bash
cd OASIS
./uninstall.sh
```

This removes OASIS but **preserves your organized folder structure**.

## Configuration

Config files are stored at `~/.config/oasis/`:

| File | Purpose |
|------|---------|
| `enabled` | Contains `true` or `false` |
| `oasis.log` | Activity log |
| `stdout.log` | Launch agent output |
| `stderr.log` | Launch agent errors |

The OASIS app is stored at `~/.local/share/oasis/OASIS.app`.

## Requirements

- macOS 10.15 (Catalina) or later
- Bash (included with macOS)

## Security

OASIS is designed with security in mind:
- Runs entirely in user space (no sudo required)
- Only operates on `~/Downloads` — never touches other directories
- Handles filenames with spaces and special characters safely
- No network access, no external dependencies
- Open source — inspect the code yourself

## Changelog

### v1.1.0
- **Fixed**: Timezone bug where evening downloads were dated incorrectly (UTC→local conversion)
- **Fixed**: Folder merge conflicts now handled properly (no more duplicate week folders)
- **Fixed**: Year detection for files from previous years
- **Added**: `--dry-run` flag to preview changes without making them
- **Added**: `version` command
- **Added**: Log rotation (keeps last 1000 entries)
- **Improved**: Single date lookup per file (4x fewer system calls)
- **Improved**: Better partial download detection (`.tmp`, `~` suffix, etc.)
- **Improved**: Long filename handling (truncates to fit macOS limits)

### v1.0.0
- Initial release

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please open an issue or PR.
