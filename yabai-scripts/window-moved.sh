#!/usr/bin/env bash

# Track window movements to detect drag operations
# Cancels pending pure-refocus retile if window is being dragged
#
# yabai provides:
#   $YABAI_WINDOW_ID - the window that moved

set -euo pipefail

STATE_DIR="/tmp/yabai-display-state"
mkdir -p "$STATE_DIR"

WINDOW_ID="${YABAI_WINDOW_ID:-}"

if [ -z "$WINDOW_ID" ]; then
    exit 0
fi

# Get the window's current display
WINDOW_DISPLAY=$(yabai -m query --windows --window "$WINDOW_ID" 2>/dev/null | jq -r '.display // empty' || echo "")

if [ -z "$WINDOW_DISPLAY" ]; then
    exit 0
fi

# Check if we have a pending display change (potential drag)
if [ -f "$STATE_DIR/pending_retile" ]; then
    # This window_moved came right after display_changed
    # This indicates a drag operation!

    # Cancel the pending pure-refocus retile
    rm -f "$STATE_DIR/pending_retile"

    # Mark drag in progress
    touch "$STATE_DIR/drag_in_progress"
    echo "$WINDOW_ID" > "$STATE_DIR/dragged_window_id"

    # Record origin display
    if [ -f "$STATE_DIR/previous_display_index" ]; then
        cp "$STATE_DIR/previous_display_index" "$STATE_DIR/origin_display_index"
    fi
fi

# If drag is in progress, track it
if [ -f "$STATE_DIR/drag_in_progress" ]; then
    # Record last movement timestamp
    date +%s%N > "$STATE_DIR/last_window_moved"
    echo "$WINDOW_DISPLAY" > "$STATE_DIR/target_display_index"

    SCRIPT_DIR="$(dirname "$0")"

    # Debounce: schedule drag completion check
    (
        sleep 0.2  # Wait 200ms for potential additional moves

        # If no more moves happened, consider drag complete
        if [ -f "$STATE_DIR/drag_in_progress" ]; then
            LAST_MOVE=$(cat "$STATE_DIR/last_window_moved" 2>/dev/null || echo "0")
            NOW=$(date +%s%N)
            # Calculate difference in milliseconds
            DIFF=$(( (NOW - LAST_MOVE) / 1000000 ))

            if [ "$DIFF" -ge 180 ]; then
                # Drag appears complete (no movement for 180ms+)
                rm -f "$STATE_DIR/drag_in_progress"
                rm -f "$STATE_DIR/dragged_window_id"
                rm -f "$STATE_DIR/last_window_moved"
                rm -f "$STATE_DIR/pending_retile"

                # Retile both origin and target displays
                ORIGIN=$(cat "$STATE_DIR/origin_display_index" 2>/dev/null || echo "")
                TARGET=$(cat "$STATE_DIR/target_display_index" 2>/dev/null || echo "")

                if [ -n "$ORIGIN" ]; then
                    "$SCRIPT_DIR/tile-display.sh" "$ORIGIN" &
                fi
                if [ -n "$TARGET" ] && [ "$TARGET" != "$ORIGIN" ]; then
                    "$SCRIPT_DIR/tile-display.sh" "$TARGET" &
                fi
                wait

                # Cleanup
                rm -f "$STATE_DIR/origin_display_index"
                rm -f "$STATE_DIR/target_display_index"
            fi
        fi
    ) &
    disown
fi
