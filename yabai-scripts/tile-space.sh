#!/usr/bin/env bash

# Tile all visible windows on a specific space as proportional columns
# Usage: tile-space.sh <space_index>
# Order file format: window_id:units (default 1 unit per window)

set -euo pipefail

SPACE="${1:-}"

if [ -z "$SPACE" ]; then
    echo "Usage: tile-space.sh <space_index>" >&2
    exit 1
fi

# === LOCK AND DEBOUNCE MECHANISM (per-space) ===
LOCK_FILE="/tmp/tile-space-$SPACE.lock"

cleanup() {
    rm -rf "$LOCK_FILE"
}

acquire_lock() {
    if mkdir "$LOCK_FILE" 2>/dev/null; then
        trap cleanup EXIT INT TERM
        return 0
    fi
    return 1
}

check_stale_lock() {
    if [ -d "$LOCK_FILE" ]; then
        lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo 0) ))
        if [ "$lock_age" -gt 5 ]; then
            rm -rf "$LOCK_FILE"
            return 0
        fi
        return 1
    fi
    return 0
}

check_stale_lock
if ! acquire_lock; then
    exit 0
fi

sleep 0.1  # Debounce: coalesce rapid signals
# === END LOCK AND DEBOUNCE ===

ORDER_DIR="$HOME/.yabai-order"
mkdir -p "$ORDER_DIR"

ORDER_FILE="$ORDER_DIR/space-$SPACE"
DISPLAY_INFO=$(yabai -m query --displays --space "$SPACE")

# Get display frame
DISPLAY_X=$(echo "$DISPLAY_INFO" | jq '.frame.x')
DISPLAY_Y=$(echo "$DISPLAY_INFO" | jq '.frame.y')
DISPLAY_W=$(echo "$DISPLAY_INFO" | jq '.frame.w')
DISPLAY_H=$(echo "$DISPLAY_INFO" | jq '.frame.h')

# Get padding values
TOP_PAD=$(yabai -m config top_padding)
BOTTOM_PAD=$(yabai -m config bottom_padding)
LEFT_PAD=$(yabai -m config left_padding)
RIGHT_PAD=$(yabai -m config right_padding)
GAP=$(yabai -m config window_gap)

# Calculate usable area
USABLE_X=$(echo "$DISPLAY_X + $LEFT_PAD" | bc)
USABLE_Y=$(echo "$DISPLAY_Y + $TOP_PAD" | bc)
USABLE_W=$(echo "$DISPLAY_W - $LEFT_PAD - $RIGHT_PAD" | bc)
USABLE_H=$(echo "$DISPLAY_H - $TOP_PAD - $BOTTOM_PAD" | bc)

# Get only main application windows (AXStandardWindow)
# Excludes: dialogs, popups, settings panels, system UI, floating windows
WINDOWS=$(yabai -m query --windows --space "$SPACE" | jq '[.[] | select(
  .["is-visible"] == true and
  .["is-minimized"] == false and
  .["is-sticky"] == false and
  .subrole == "AXStandardWindow" and
  .frame.w >= 100 and
  .frame.h >= 100
)]')

CURRENT_IDS=$(echo "$WINDOWS" | jq -r '.[].id' | sort -n)

if [ -z "$CURRENT_IDS" ]; then
    rm -f "$ORDER_FILE"
    exit 0
fi

# Build ordered list with units: saved order first, then new windows
# Format: "id:units id:units ..."
ORDERED=""

# Load saved order (id:units format)
declare_saved() {
    SAVED_IDS=""
    SAVED_UNITS=""
    if [ -f "$ORDER_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            id="${line%%:*}"
            units="${line#*:}"
            # Default to 1 if no units specified (backward compat)
            [ "$units" = "$id" ] && units=1
            if echo "$CURRENT_IDS" | grep -qx "$id"; then
                ORDERED="$ORDERED $id:$units"
                SAVED_IDS="$SAVED_IDS $id"
            fi
        done < "$ORDER_FILE"
    fi
}
declare_saved

# Find new windows not in saved order, sorted by x position
NEW_WITH_POS=""
for cid in $CURRENT_IDS; do
    if ! echo "$SAVED_IDS" | grep -qw "$cid"; then
        x_pos=$(echo "$WINDOWS" | jq -r ".[] | select(.id == $cid) | .frame.x")
        NEW_WITH_POS="$NEW_WITH_POS
$x_pos:$cid"
    fi
done

# Sort new windows by x position and append with 1 unit
if [ -n "$NEW_WITH_POS" ]; then
    SORTED_NEW=$(echo "$NEW_WITH_POS" | grep -v '^$' | sort -t: -k1 -n | cut -d: -f2)
    for nid in $SORTED_NEW; do
        ORDERED="$ORDERED $nid:1"
    done
fi

ORDERED=$(echo "$ORDERED" | xargs)

# Save updated order
echo "$ORDERED" | tr ' ' '\n' > "$ORDER_FILE"

WIN_COUNT=$(echo "$ORDERED" | wc -w | xargs)

if [ "$WIN_COUNT" -eq 0 ]; then
    exit 0
fi

# Single window: make it full width/height
if [ "$WIN_COUNT" -eq 1 ]; then
    WIN_ID="${ORDERED%%:*}"
    yabai -m window "$WIN_ID" --move abs:"$USABLE_X":"$USABLE_Y" 2>/dev/null || true
    yabai -m window "$WIN_ID" --resize abs:"$USABLE_W":"$USABLE_H" 2>/dev/null || true
    exit 0
fi

# Calculate total units
TOTAL_UNITS=0
for entry in $ORDERED; do
    units="${entry#*:}"
    TOTAL_UNITS=$((TOTAL_UNITS + units))
done

# Calculate dimensions
TOTAL_GAPS=$(echo "($WIN_COUNT - 1) * $GAP" | bc)
AVAILABLE_W=$(echo "$USABLE_W - $TOTAL_GAPS" | bc)
UNIT_WIDTH=$(echo "$AVAILABLE_W / $TOTAL_UNITS" | bc)
WIN_HEIGHT=$USABLE_H

# Position each window according to saved order and units
# Last window gets remaining width to avoid rounding gaps
CURRENT_X=$USABLE_X
RIGHT_EDGE=$(echo "$USABLE_X + $USABLE_W" | bc)
WIN_INDEX=0

for entry in $ORDERED; do
    WIN_ID="${entry%%:*}"
    units="${entry#*:}"
    WIN_INDEX=$((WIN_INDEX + 1))

    if [ "$WIN_INDEX" -eq "$WIN_COUNT" ]; then
        # Last window: use remaining space to fill to edge
        WIN_WIDTH=$(echo "$RIGHT_EDGE - $CURRENT_X" | bc)
    else
        WIN_WIDTH=$(echo "$UNIT_WIDTH * $units" | bc)
    fi

    yabai -m window "$WIN_ID" --move abs:"$CURRENT_X":"$USABLE_Y" 2>/dev/null || true
    yabai -m window "$WIN_ID" --resize abs:"$WIN_WIDTH":"$WIN_HEIGHT" 2>/dev/null || true

    CURRENT_X=$(echo "$CURRENT_X + $WIN_WIDTH + $GAP" | bc)
done
