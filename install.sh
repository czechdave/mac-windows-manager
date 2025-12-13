#!/usr/bin/env bash

# Install mac-windows-manager
# Symlinks config files and scripts to their expected locations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing mac-windows-manager..."

# Create ~/scripts if it doesn't exist
mkdir -p ~/scripts

# Backup existing files if they exist and aren't symlinks
backup_if_exists() {
    if [ -e "$1" ] && [ ! -L "$1" ]; then
        echo "Backing up $1 to $1.backup"
        mv "$1" "$1.backup"
    fi
}

# Symlink config files
backup_if_exists ~/.yabairc
backup_if_exists ~/.skhdrc
ln -sf "$SCRIPT_DIR/yabairc" ~/.yabairc
ln -sf "$SCRIPT_DIR/skhdrc" ~/.skhdrc
echo "Linked yabairc and skhdrc"

# Symlink scripts
for script in "$SCRIPT_DIR"/yabai-scripts/*.sh; do
    name=$(basename "$script")
    backup_if_exists ~/scripts/"$name"
    ln -sf "$script" ~/scripts/"$name"
done
echo "Linked scripts to ~/scripts/"

# Make scripts executable
chmod +x "$SCRIPT_DIR"/yabai-scripts/*.sh

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "1. Install yabai and skhd:"
echo "   brew install koekeishiya/formulae/yabai koekeishiya/formulae/skhd"
echo ""
echo "2. Grant Accessibility permissions in System Settings → Privacy & Security → Accessibility"
echo "   Add: /opt/homebrew/bin/yabai and /opt/homebrew/bin/skhd"
echo ""
echo "3. Start services:"
echo "   yabai --start-service"
echo "   skhd --start-service"
