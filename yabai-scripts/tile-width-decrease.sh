#!/usr/bin/env bash

# Decrease focused window width by 1 unit
# If already at minimum (1), increase all OTHER windows instead

set -euo pipefail

ORDER_DIR="$HOME/.yabai-order"
SPACE=$(yabai -m query --spaces --space | jq '.index')
ORDER_FILE="$ORDER_DIR/space-$SPACE"
FOCUSED_ID=$(yabai -m query --windows --window | jq '.id')

if [ -z "$FOCUSED_ID" ] || [ "$FOCUSED_ID" = "null" ]; then
    exit 1
fi

if [ ! -f "$ORDER_FILE" ]; then
    exit 0
fi

# Read and update units for focused window
NEW_ORDER=""
FOUND=0
INCREASE_OTHERS=0
FOCUSED_UNITS=1

while IFS= read -r line || [ -n "$line" ]; do
    id="${line%%:*}"
    units="${line#*:}"
    [ "$units" = "$id" ] && units=1

    if [ "$id" = "$FOCUSED_ID" ]; then
        FOUND=1
        FOCUSED_UNITS=$units
        if [ "$units" -gt 1 ]; then
            # Normal case: decrease this window
            units=$((units - 1))
        else
            # At minimum: mark to increase others instead
            INCREASE_OTHERS=1
        fi
    fi
    NEW_ORDER="$NEW_ORDER $id:$units"
done < "$ORDER_FILE"

if [ $FOUND -eq 0 ]; then
    exit 0
fi

# If focused window was at minimum, increase all others instead
if [ "$INCREASE_OTHERS" -eq 1 ]; then
    FINAL_ORDER=""
    for entry in $NEW_ORDER; do
        id="${entry%%:*}"
        units="${entry#*:}"
        if [ "$id" != "$FOCUSED_ID" ]; then
            units=$((units + 1))
        fi
        FINAL_ORDER="$FINAL_ORDER $id:$units"
    done
    NEW_ORDER="$FINAL_ORDER"
fi

# Save and retile
echo "$NEW_ORDER" | xargs | tr ' ' '\n' > "$ORDER_FILE"
exec "$HOME/scripts/tile-equal.sh"
