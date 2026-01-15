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
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Paths
CONFIG_DIR="$HOME/.config/$APP_NAME"
BIN_DIR="$HOME/.local/bin"
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

# Step 4: Process and install launchd plist
print_step "Installing launch agent..."

# Unload existing agent if present
if launchctl list | grep -q "com.$APP_NAME.organizer"; then
    launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
fi

mkdir -p "$LAUNCH_AGENTS_DIR"

# Replace __HOME__ placeholder with actual home directory
sed "s|__HOME__|$HOME|g" "$SCRIPT_DIR/config/$PLIST_NAME" > "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

print_success "Launch agent installed to $LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Step 5: Load the launch agent
print_step "Loading launch agent..."
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
print_success "Launch agent loaded"

# Step 6: Copy toggle scripts
print_step "Installing toggle scripts..."
SHORTCUTS_DEST="$HOME/.config/$APP_NAME/shortcuts"
mkdir -p "$SHORTCUTS_DEST"
cp "$SCRIPT_DIR/shortcuts/"*.command "$SHORTCUTS_DEST/" 2>/dev/null || true
chmod +x "$SHORTCUTS_DEST/"*.command 2>/dev/null || true
print_success "Toggle scripts installed to $SHORTCUTS_DEST"

# Step 7: Run OASIS once to organize existing files
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
echo "OASIS is now running and will organize your Downloads folder"
echo "automatically every day at midnight."
echo ""
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
echo -e "${BLUE}For Spotlight integration:${NC}"
echo "  See shortcuts/SETUP.md for instructions on creating"
echo "  macOS Shortcuts for Spotlight access."
echo ""
echo -e "${BLUE}Logs:${NC}"
echo "  cat $CONFIG_DIR/oasis.log"
echo ""
echo -e "${BLUE}To uninstall:${NC}"
echo "  ./uninstall.sh"
echo ""
