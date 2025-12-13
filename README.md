# mac-windows-manager

A lightweight window tiling manager for macOS using [yabai](https://github.com/koekeishiya/yabai) and [skhd](https://github.com/koekeishiya/skhd). Automatically tiles windows as columns with variable widths and persistent ordering.

## Features

- **Auto-tiling**: Windows automatically tile as columns when created, closed, minimized, or shown
- **Variable width**: Increase or decrease individual window widths
- **Persistent ordering**: Window order is remembered and preserved across changes
- **No SIP modification**: Uses float layout with manual tiling (no System Integrity Protection changes needed)

## Keyboard Shortcuts

All shortcuts use the Hyper key (Cmd + Ctrl + Alt + Shift):

| Shortcut | Action |
|----------|--------|
| `Hyper + ↑` | Increase focused window width by 1 unit |
| `Hyper + ↓` | Decrease focused window width by 1 unit |
| `Hyper + ←` | Swap focused window with the one to its left |
| `Hyper + →` | Swap focused window with the one to its right |

## Installation

### Prerequisites

Install yabai and skhd via Homebrew:

```bash
brew install koekeishiya/formulae/yabai koekeishiya/formulae/skhd
```

### Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/czechdave/mac-windows-manager.git
   cd mac-windows-manager
   ```

2. Run the install script:
   ```bash
   ./install.sh
   ```

3. Grant Accessibility permissions:
   - Open **System Settings → Privacy & Security → Accessibility**
   - Add and enable `/opt/homebrew/bin/yabai` and `/opt/homebrew/bin/skhd`

4. Start the services:
   ```bash
   yabai --start-service
   skhd --start-service
   ```

## How It Works

- Windows are tiled as columns across the screen
- Each window has a "unit" width (default: 1 unit)
- Total screen width is divided proportionally by units
- Window order and widths are stored per-space in `~/.yabai-order/`
- yabai signals automatically retile on window changes

## Files

- `yabairc` - yabai configuration (float layout + signals)
- `skhdrc` - keyboard shortcut bindings
- `yabai-scripts/` - tiling scripts
  - `tile-equal.sh` - main tiling logic
  - `tile-width-increase.sh` - increase window width
  - `tile-width-decrease.sh` - decrease window width
  - `tile-swap-left.sh` - swap window left
  - `tile-swap-right.sh` - swap window right

## License

MIT
