# mac-windows-manager

A lightweight window tiling manager for macOS using [yabai](https://github.com/koekeishiya/yabai) and [skhd](https://github.com/koekeishiya/skhd). Automatically tiles windows as columns with variable widths and persistent ordering.

## Features

- **Auto-tiling**: Windows automatically tile as columns when created, closed, minimized, or shown
- **Variable width**: Increase or decrease individual window widths
- **Persistent ordering**: Window order is remembered and preserved across changes
- **Multi-display**: Windows retile correctly when dragged between displays
- **No SIP modification**: No System Integrity Protection changes needed

## Keyboard Shortcuts

All shortcuts use the Hyper key (Cmd + Ctrl + Alt + Shift):

| Shortcut | Action |
|----------|--------|
| `Hyper + ↑` | Increase focused window width by 1 unit |
| `Hyper + ↓` | Decrease focused window width by 1 unit |
| `Hyper + ←` | Swap focused window with the one to its left |
| `Hyper + →` | Swap focused window with the one to its right |

## Prerequisites

```bash
brew install koekeishiya/formulae/yabai koekeishiya/formulae/skhd
```

## Setup

```bash
git clone https://github.com/czechdave/mac-windows-manager.git
cd mac-windows-manager
./install.sh
```

Grant Accessibility permissions to both `/opt/homebrew/bin/yabai` and `/opt/homebrew/bin/skhd` in System Settings → Privacy & Security → Accessibility, then:

```bash
yabai --start-service
skhd --start-service
```

## Files

- `yabairc` - yabai configuration
- `skhdrc` - keyboard shortcut bindings
- `yabai-scripts/` - tiling shell scripts

## How It Works

- Windows are tiled as columns across the screen
- Each window has a "unit" width (default: 1 unit)
- Total screen width is divided proportionally by units
- Window order and widths are persisted per space

## License

MIT
