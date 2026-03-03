#!/usr/bin/env bash

# Tile the visible space on a specific display
# Usage: tile-display.sh <display_index>
# This is a thin wrapper that finds the space and delegates to tile-space.sh

set -euo pipefail

DISPLAY_INDEX="${1:-}"

if [ -z "$DISPLAY_INDEX" ]; then
    echo "Usage: tile-display.sh <display_index>" >&2
    exit 1
fi

# Find the visible space on this display
SPACE=$(yabai -m query --spaces --display "$DISPLAY_INDEX" 2>/dev/null | jq -r '.[] | select(.["is-visible"] == true) | .index' || echo "")

if [ -z "$SPACE" ] || [ "$SPACE" = "null" ]; then
    exit 0
fi

exec "$(dirname "$0")/tile-space.sh" "$SPACE"
