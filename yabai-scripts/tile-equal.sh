#!/usr/bin/env bash

# Tile all visible windows on current space as proportional columns
# This is a wrapper that captures the current space and calls tile-space.sh

set -euo pipefail

SPACE=$(yabai -m query --spaces --space | jq '.index')

if [ -z "$SPACE" ] || [ "$SPACE" = "null" ]; then
    exit 0
fi

exec "$(dirname "$0")/tile-space.sh" "$SPACE"
