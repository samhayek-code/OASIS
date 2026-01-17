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
├── January 2026/                     # Monthly archive
│   ├── Week 1 (Jan 1-5)/             # Weekly container
│   │   ├── Jan 1/                    # Daily folder
│   │   │   ├── Images/               # Photos, graphics
│   │   │   ├── Documents/            # PDFs, Office docs
│   │   │   ├── Videos/               # Video files
│   │   │   ├── Audio/                # Music, podcasts
│   │   │   └── Other/                # Everything else
│   │   └── Jan 2/
│   ├── Week 2 (Jan 6-12)/
│   └── ...
└── Jan 14/                           # Current day (not rolled up yet)
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
oasis run       # Organize Downloads now
oasis enable    # Turn on automatic organization
oasis disable   # Turn off automatic organization
oasis toggle    # Switch between on/off
oasis status    # Check if enabled or disabled
oasis help      # Show help
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

1. **Daily at midnight** (or on wake/login if asleep), OASIS:
   - Moves loose files from Downloads into today's dated folder
   - Sorts them into category subfolders (Images, Documents, etc.)
   - Rolls up yesterday's folder into the current week folder
   - Rolls up completed weeks into monthly folders

2. **Week structure** is aligned to Mon-Sun:
   - Week 1 = 1st of month through first Sunday
   - Week 2+ = Full Monday-Sunday weeks
   - Final week may be partial

3. **Smart handling**:
   - Skips hidden files and partially downloaded files
   - Empty category folders aren't created
   - File conflicts handled with numeric suffixes

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

## License

MIT License — see [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please open an issue or PR.
