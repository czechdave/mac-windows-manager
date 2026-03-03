#!/usr/bin/env bash

# Detect cross-display window moves and retile affected displays
# Uses a per-window display cache to independently detect when a window
# changes displays, without relying on display_changed events.
#
# yabai provides:
#   $YABAI_WINDOW_ID - the window that moved

set -euo pipefail

WINDOW_ID="${YABAI_WINDOW_ID:-}"
[ -z "$WINDOW_ID" ] && exit 0

CACHE_DIR="/tmp/yabai-window-display"
STATE_DIR="/tmp/yabai-display-state"
mkdir -p "$CACHE_DIR" "$STATE_DIR"

# Get the window's current display
CURRENT_DISPLAY=$(yabai -m query --windows --window "$WINDOW_ID" 2>/dev/null | jq -r '.display // empty' || echo "")
[ -z "$CURRENT_DISPLAY" ] && exit 0

# Check cached display for this window
CACHED_DISPLAY=$(cat "$CACHE_DIR/$WINDOW_ID" 2>/dev/null || echo "")
echo "$CURRENT_DISPLAY" > "$CACHE_DIR/$WINDOW_ID"

# Record movement timestamp (for settlement detection)
date +%s%N > "$STATE_DIR/last_moved"

# Detect cross-display move
if [ -n "$CACHED_DISPLAY" ] && [ "$CACHED_DISPLAY" != "$CURRENT_DISPLAY" ]; then
    echo "$CACHED_DISPLAY:$CURRENT_DISPLAY" > "$STATE_DIR/retile_displays"
fi

# If there's a pending retile, schedule a settlement check
[ ! -f "$STATE_DIR/retile_displays" ] && exit 0

SCRIPT_DIR="$(dirname "$0")"

(
    sleep 0.3

    # Check if movement has settled (no moves for ~300ms)
    LAST=$(cat "$STATE_DIR/last_moved" 2>/dev/null || echo "0")
    NOW=$(date +%s%N)
    DIFF=$(( (NOW - LAST) / 1000000 ))
    [ "$DIFF" -lt 280 ] && exit 0

    # Movement settled - consume the retile request and tile both displays
    DISPLAYS=$(cat "$STATE_DIR/retile_displays" 2>/dev/null || echo "")
    rm -f "$STATE_DIR/retile_displays"
    [ -z "$DISPLAYS" ] && exit 0

    OLD="${DISPLAYS%%:*}"
    NEW="${DISPLAYS#*:}"
    [ -n "$OLD" ] && "$SCRIPT_DIR/tile-display.sh" "$OLD" &
    [ -n "$NEW" ] && [ "$NEW" != "$OLD" ] && "$SCRIPT_DIR/tile-display.sh" "$NEW" &
    wait
) &
disown
