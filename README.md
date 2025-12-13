# mac-windows-manager

A lightweight window tiling manager for macOS. Automatically tiles windows as columns with variable widths and persistent ordering.

**Two versions available:**
- **Native Swift app** (recommended) - Single app, one Accessibility permission
- **Shell scripts** - Uses yabai + skhd, requires two permissions

## Features

- **Auto-tiling**: Windows automatically tile as columns when created, closed, minimized, or shown
- **Variable width**: Increase or decrease individual window widths
- **Persistent ordering**: Window order is remembered and preserved across changes
- **No SIP modification**: No System Integrity Protection changes needed

## Keyboard Shortcuts

All shortcuts use the Hyper key (Cmd + Ctrl + Alt + Shift):

| Shortcut | Action |
|----------|--------|
| `Hyper + ↑` | Increase focused window width by 1 unit |
| `Hyper + ↓` | Decrease focused window width by 1 unit |
| `Hyper + ←` | Swap focused window with the one to its left |
| `Hyper + →` | Swap focused window with the one to its right |

---

## Option 1: Native Swift App (Recommended)

Single standalone app with only **one** Accessibility permission required.

### Build & Install

```bash
git clone https://github.com/czechdave/mac-windows-manager.git
cd mac-windows-manager/MacWindowManager
./build.sh
cp -r build/MacWindowManager.app /Applications/
```

### Run

1. Open **MacWindowManager.app** from Applications
2. Grant Accessibility permission when prompted (System Settings → Privacy & Security → Accessibility)
3. The app runs in the menu bar

### Menu Bar Options

- **Enabled** - Toggle auto-tiling on/off
- **Tile Now** - Manually trigger tiling
- **Reset Sizes** - Reset all windows to 1 unit width
- **Quit** - Exit the app

---

## Option 2: Shell Scripts (yabai + skhd)

Uses [yabai](https://github.com/koekeishiya/yabai) and [skhd](https://github.com/koekeishiya/skhd). Requires two separate Accessibility permissions.

### Prerequisites

```bash
brew install koekeishiya/formulae/yabai koekeishiya/formulae/skhd
```

### Setup

```bash
git clone https://github.com/czechdave/mac-windows-manager.git
cd mac-windows-manager
./install.sh
```

Grant Accessibility permissions to both `/opt/homebrew/bin/yabai` and `/opt/homebrew/bin/skhd`, then:

```bash
yabai --start-service
skhd --start-service
```

### Files

- `yabairc` - yabai configuration
- `skhdrc` - keyboard shortcut bindings
- `yabai-scripts/` - tiling shell scripts

---

## How It Works

- Windows are tiled as columns across the screen
- Each window has a "unit" width (default: 1 unit)
- Total screen width is divided proportionally by units
- Window order and widths are persisted

## License

MIT
