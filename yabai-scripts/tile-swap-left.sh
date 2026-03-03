#!/usr/bin/env bash

# Swap focused window with the one to its left in the order

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
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

# Read order into space-separated string (preserving id:units format)
ORDER=$(cat "$ORDER_FILE" | tr '\n' ' ' | xargs)

# Convert to positional params
set -- $ORDER

# Find position of focused window (1-indexed)
POS=0
i=1
for entry in "$@"; do
    id="${entry%%:*}"
    if [ "$id" = "$FOCUSED_ID" ]; then
        POS=$i
        break
    fi
    i=$((i + 1))
done

# Can't swap if first or not found
if [ "$POS" -le 1 ]; then
    exit 0
fi

# Build new order with swap (swap entire id:units entries)
PREV=$((POS - 1))
NEW_ORDER=""
i=1
for entry in "$@"; do
    if [ $i -eq $PREV ]; then
        eval "NEW_ORDER=\"\$NEW_ORDER \$$POS\""
    elif [ $i -eq $POS ]; then
        eval "NEW_ORDER=\"\$NEW_ORDER \$$PREV\""
    else
        NEW_ORDER="$NEW_ORDER $entry"
    fi
    i=$((i + 1))
done

# Save and retile
echo "$NEW_ORDER" | xargs | tr ' ' '\n' > "$ORDER_FILE"
exec "$SCRIPT_DIR/tile-equal.sh"
