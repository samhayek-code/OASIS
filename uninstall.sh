#!/bin/bash

# =============================================================================
# OASIS Uninstaller
# =============================================================================

# Configuration
APP_NAME="oasis"
APP_DISPLAY_NAME="OASIS"

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

# =============================================================================
# Uninstallation Steps
# =============================================================================

echo ""
echo -e "${YELLOW}╔═══════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║      OASIS Downloads Organizer        ║${NC}"
echo -e "${YELLOW}║           Uninstallation              ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════╝${NC}"
echo ""

# Step 1: Unload launch agent
print_step "Stopping OASIS..."
if launchctl list | grep -q "com.$APP_NAME.organizer"; then
    launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
    print_success "Launch agent stopped"
else
    print_warning "Launch agent was not running"
fi

# Step 2: Remove launch agent plist
print_step "Removing launch agent..."
if [[ -f "$LAUNCH_AGENTS_DIR/$PLIST_NAME" ]]; then
    rm "$LAUNCH_AGENTS_DIR/$PLIST_NAME"
    print_success "Launch agent removed"
else
    print_warning "Launch agent plist not found"
fi

# Step 3: Remove script
print_step "Removing OASIS script..."
if [[ -f "$BIN_DIR/$APP_NAME" ]]; then
    rm "$BIN_DIR/$APP_NAME"
    print_success "Script removed from $BIN_DIR"
else
    print_warning "Script not found"
fi

# Step 4: Remove OASIS app
print_step "Removing OASIS app..."
if [[ -d "$APP_DIR/$APP_DISPLAY_NAME.app" ]]; then
    rm -rf "$APP_DIR/$APP_DISPLAY_NAME.app"
    print_success "App removed from $APP_DIR"
    # Also remove the app directory if empty
    rmdir "$APP_DIR" 2>/dev/null || true
else
    print_warning "App not found"
fi

# Step 5: Remove config directory
print_step "Removing configuration..."
if [[ -d "$CONFIG_DIR" ]]; then
    rm -rf "$CONFIG_DIR"
    print_success "Configuration removed"
else
    print_warning "Configuration directory not found"
fi

# Step 6: Note about Full Disk Access and Shortcuts
print_step "Note about manual cleanup..."
print_warning "You may want to remove OASIS from Full Disk Access in System Settings."
echo "        System Settings → Privacy & Security → Full Disk Access"
echo ""
print_step "Note about Shortcuts..."
print_warning "macOS Shortcuts must be removed manually if desired."
echo "        Open Shortcuts app and delete: Enable/Disable/Toggle OASIS"

# =============================================================================
# Success Message
# =============================================================================

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Uninstallation Complete!         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "OASIS has been removed from your system."
echo ""
echo -e "${BLUE}Note:${NC} Your organized Downloads folders have NOT been deleted."
echo "      You can keep them as-is or reorganize manually."
echo ""
