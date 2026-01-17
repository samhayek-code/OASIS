#!/bin/bash

# =============================================================================
# OASIS Installer
# =============================================================================

set -e  # Exit on error

# Safety check
if [[ -z "$HOME" ]] || [[ ! -d "$HOME" ]]; then
    echo "Error: HOME directory not set or does not exist" >&2
    exit 1
fi

# Configuration
APP_NAME="oasis"
APP_DISPLAY_NAME="OASIS"
REPO_URL="https://raw.githubusercontent.com/samhayek-code/OASIS/main"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Detect if running from repo or via curl pipe
if [[ -f "$SCRIPT_DIR/src/oasis.sh" ]]; then
    INSTALL_MODE="local"
else
    INSTALL_MODE="remote"
    SCRIPT_DIR=$(mktemp -d)
    trap "rm -rf '$SCRIPT_DIR'" EXIT

    mkdir -p "$SCRIPT_DIR/src" "$SCRIPT_DIR/config" "$SCRIPT_DIR/shortcuts"

    echo "Downloading OASIS files..."
    curl -fsSL "$REPO_URL/src/oasis.sh" -o "$SCRIPT_DIR/src/oasis.sh" || { echo "Failed to download oasis.sh"; exit 1; }
    curl -fsSL "$REPO_URL/config/com.oasis.plist" -o "$SCRIPT_DIR/config/com.oasis.plist" || { echo "Failed to download plist"; exit 1; }
    curl -fsSL "$REPO_URL/shortcuts/Enable%20OASIS.command" -o "$SCRIPT_DIR/shortcuts/Enable OASIS.command" 2>/dev/null || true
    curl -fsSL "$REPO_URL/shortcuts/Disable%20OASIS.command" -o "$SCRIPT_DIR/shortcuts/Disable OASIS.command" 2>/dev/null || true
    curl -fsSL "$REPO_URL/shortcuts/Toggle%20OASIS.command" -o "$SCRIPT_DIR/shortcuts/Toggle OASIS.command" 2>/dev/null || true
fi

# Paths
CONFIG_DIR="$HOME/.config/$APP_NAME"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/$APP_NAME"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.$APP_NAME.plist"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# =============================================================================
# Installation Steps
# =============================================================================

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      OASIS Downloads Organizer        ║${NC}"
echo -e "${GREEN}║            Installation               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""

# Step 1: Create config directory
print_step "Creating config directory..."
mkdir -p "$CONFIG_DIR"
print_success "Config directory created at $CONFIG_DIR"

# Step 2: Set enabled to true
print_step "Enabling OASIS..."
echo "true" > "$CONFIG_DIR/enabled"
print_success "OASIS enabled"

# Step 3: Create bin directory and copy script
print_step "Installing OASIS script..."
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/src/oasis.sh" "$BIN_DIR/$APP_NAME"
chmod +x "$BIN_DIR/$APP_NAME"
print_success "Script installed to $BIN_DIR/$APP_NAME"

# Step 4: Create AppleScript app wrapper
# This app is needed because macOS restricts launchd agents from accessing
# ~/Downloads directly. The app can be granted Full Disk Access to work around this.
print_step "Creating OASIS app..."
mkdir -p "$APP_DIR"

# Remove existing app if present
rm -rf "$APP_DIR/$APP_DISPLAY_NAME.app" 2>/dev/null || true

# Create AppleScript app that runs the oasis script
osacompile -o "$APP_DIR/$APP_DISPLAY_NAME.app" -e "do shell script \"$BIN_DIR/$APP_NAME run\""

print_success "App created at $APP_DIR/$APP_DISPLAY_NAME.app"

# Step 5: Process and install launchd plist
print_step "Installing launch agent..."

# Unload existing agent if present
if launchctl list | grep -q "com.$APP_NAME.organizer"; then
    launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
fi

mkdir -p "$LAUNCH_AGENTS_DIR"

# Replace __HOME__ placeholder with actual home directory
sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/config/$PLIST_NAME" > "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

print_success "Launch agent installed to $LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Step 6: Load the launch agent
print_step "Loading launch agent..."
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
print_success "Launch agent loaded"

# Step 7: Copy toggle scripts
print_step "Installing toggle scripts..."
SHORTCUTS_DEST="$HOME/.config/$APP_NAME/shortcuts"
mkdir -p "$SHORTCUTS_DEST"
cp "$SCRIPT_DIR/shortcuts/"*.command "$SHORTCUTS_DEST/" 2>/dev/null || true
chmod +x "$SHORTCUTS_DEST/"*.command 2>/dev/null || true
print_success "Toggle scripts installed to $SHORTCUTS_DEST"

# Step 8: Run OASIS once to organize existing files
print_step "Running initial organization..."
"$BIN_DIR/$APP_NAME"
print_success "Initial organization complete"

# =============================================================================
# Success Message
# =============================================================================

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Installation Complete!           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""

# =============================================================================
# Full Disk Access Setup
# =============================================================================

echo -e "${YELLOW}╔═══════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║   IMPORTANT: Grant Full Disk Access   ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "For OASIS to work automatically at midnight, you need to grant"
echo "the OASIS app Full Disk Access. This is a one-time setup."
echo ""
echo -e "${BLUE}Steps:${NC}"
echo "  1. Open System Settings → Privacy & Security → Full Disk Access"
echo "  2. Click the + button"
echo "  3. Press Cmd+Shift+G and paste: $APP_DIR"
echo "  4. Select OASIS.app and click Open"
echo ""
echo -e "${BLUE}Or run this command to open the settings:${NC}"
echo "  open 'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles'"
echo ""

# Ask user if they want to open System Settings now
read -p "Would you like to open Full Disk Access settings now? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
    echo ""
    print_warning "After granting access, OASIS will work automatically at midnight."
    echo ""
fi

echo -e "${BLUE}Terminal commands:${NC}"
echo "  oasis run       Run organization now"
echo "  oasis enable    Turn on automatic organization"
echo "  oasis disable   Turn off automatic organization"
echo "  oasis toggle    Switch between on/off"
echo "  oasis status    Check current status"
echo ""
echo -e "${BLUE}Quick toggle scripts:${NC}"
echo "  Double-click these files to toggle OASIS:"
echo "  $SHORTCUTS_DEST/"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo "  cat $CONFIG_DIR/oasis.log"
echo ""
echo -e "${BLUE}To uninstall:${NC}"
echo "  ./uninstall.sh"
echo ""
