#!/usr/bin/env bash

# Increase focused window width by 1 unit

set -euo pipefail

ORDER_DIR="$HOME/.yabai-order"
SPACE=$(yabai -m query --spaces --space | jq '.index')
ORDER_FILE="$ORDER_DIR/space-$SPACE"
FOCUSED_ID=$(yabai -m query --windows --window | jq '.id')

if [ -z "$FOCUSED_ID" ] || [ "$FOCUSED_ID" = "null" ]; then
    exit 1
fi

if [ ! -f "$ORDER_FILE" ]; then
    # No order file yet, run tile-equal first to create it
    "$HOME/scripts/tile-equal.sh"
    [ ! -f "$ORDER_FILE" ] && exit 0
fi

# Read and update units for focused window
NEW_ORDER=""
FOUND=0
while IFS= read -r line || [ -n "$line" ]; do
    id="${line%%:*}"
    units="${line#*:}"
    [ "$units" = "$id" ] && units=1

    if [ "$id" = "$FOCUSED_ID" ]; then
        units=$((units + 1))
        FOUND=1
    fi
    NEW_ORDER="$NEW_ORDER $id:$units"
done < "$ORDER_FILE"

if [ $FOUND -eq 0 ]; then
    exit 0
fi

# Save and retile
echo "$NEW_ORDER" | xargs | tr ' ' '\n' > "$ORDER_FILE"
exec "$HOME/scripts/tile-equal.sh"
