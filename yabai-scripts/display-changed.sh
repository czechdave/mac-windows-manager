#!/usr/bin/env bash

# Handle display focus changes
# Distinguishes between pure refocus and window drag scenarios
#
# yabai provides these environment variables:
#   $YABAI_DISPLAY_ID - new display ID
#   $YABAI_DISPLAY_INDEX - new display index
#   $YABAI_RECENT_DISPLAY_ID - previous display ID
#   $YABAI_RECENT_DISPLAY_INDEX - previous display index

set -euo pipefail

STATE_DIR="/tmp/yabai-display-state"
mkdir -p "$STATE_DIR"

# Get display indices from yabai environment
PREV_DISPLAY="${YABAI_RECENT_DISPLAY_INDEX:-}"
CURR_DISPLAY="${YABAI_DISPLAY_INDEX:-}"

# Validate we have the needed info
if [ -z "$PREV_DISPLAY" ] || [ -z "$CURR_DISPLAY" ]; then
    exit 0
fi

# Skip if same display (shouldn't happen but be safe)
if [ "$PREV_DISPLAY" = "$CURR_DISPLAY" ]; then
    exit 0
fi

# Record display transition
echo "$PREV_DISPLAY" > "$STATE_DIR/previous_display_index"
echo "$CURR_DISPLAY" > "$STATE_DIR/current_display_index"

# Mark pending retile with timestamp
date +%s%N > "$STATE_DIR/pending_retile"

# Fork background process for deferred retile
# This will be cancelled if window_moved fires (indicating a drag)
(
    sleep 0.3  # 300ms delay

    # Check if drag started during the wait
    if [ -f "$STATE_DIR/drag_in_progress" ]; then
        exit 0
    fi

    # Check if this pending_retile is still valid
    if [ ! -f "$STATE_DIR/pending_retile" ]; then
        exit 0
    fi

    # Clear pending flag
    rm -f "$STATE_DIR/pending_retile"

    # Pure refocus case: retile both displays
    PREV=$(cat "$STATE_DIR/previous_display_index" 2>/dev/null || echo "")
    CURR=$(cat "$STATE_DIR/current_display_index" 2>/dev/null || echo "")

    SCRIPT_DIR="$(dirname "$0")"

    if [ -n "$PREV" ]; then
        "$SCRIPT_DIR/tile-display.sh" "$PREV" &
    fi
    if [ -n "$CURR" ] && [ "$CURR" != "$PREV" ]; then
        "$SCRIPT_DIR/tile-display.sh" "$CURR" &
    fi
    wait
) &

disown
