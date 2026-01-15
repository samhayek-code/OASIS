# Setting Up macOS Shortcuts

You can control OASIS from Spotlight using macOS Shortcuts. Here's how to set them up:

## Option 1: Use the .command Files

The `.command` files in this folder can be double-clicked to run:
- `Enable OASIS.command` - Turn on automatic organization
- `Disable OASIS.command` - Turn off automatic organization
- `Toggle OASIS.command` - Switch between on/off

You can drag these to your Dock for quick access.

## Option 2: Create macOS Shortcuts (Spotlight Integration)

To enable commands via Spotlight (e.g., type "Toggle OASIS"):

### Create "Toggle OASIS" Shortcut

1. Open the **Shortcuts** app
2. Click **+** to create a new shortcut
3. Search for "Run Shell Script" and add it
4. Enter this script:
   ```
   ~/.local/bin/oasis toggle
   ```
5. Name the shortcut "Toggle OASIS"
6. Done! Now type "Toggle OASIS" in Spotlight

### Create "Enable OASIS" Shortcut

Same steps, but use:
```
~/.local/bin/oasis enable
```

### Create "Disable OASIS" Shortcut

Same steps, but use:
```
~/.local/bin/oasis disable
```

## Option 3: Keyboard Shortcuts

After creating the Shortcuts above, you can assign keyboard shortcuts:

1. Open **System Settings** → **Keyboard** → **Keyboard Shortcuts**
2. Click **Services** in the sidebar
3. Find your OASIS shortcuts
4. Click "Add Shortcut" and press your desired key combination

## Terminal Commands

You can also control OASIS directly from Terminal:

```bash
oasis enable    # Turn on
oasis disable   # Turn off
oasis toggle    # Switch
oasis status    # Check current state
oasis run       # Run organization now
oasis help      # Show help
```
