#!/usr/bin/env bash

# Handle space changes - tile both previous and current spaces
# This ensures windows dragged between spaces trigger retiling on both ends
#
# yabai provides these environment variables for space_changed:
#   $YABAI_SPACE_ID - new space ID
#   $YABAI_SPACE_INDEX - new space index
#   $YABAI_RECENT_SPACE_ID - previous space ID
#   $YABAI_RECENT_SPACE_INDEX - previous space index

set -euo pipefail

PREV_SPACE="${YABAI_RECENT_SPACE_INDEX:-}"
CURR_SPACE="${YABAI_SPACE_INDEX:-}"

# Validate we have the needed info
if [ -z "$PREV_SPACE" ] || [ -z "$CURR_SPACE" ]; then
    exit 0
fi

# Skip if same space (shouldn't happen but be safe)
if [ "$PREV_SPACE" = "$CURR_SPACE" ]; then
    exit 0
fi

SCRIPT_DIR="$(dirname "$0")"

# Tile both spaces in parallel (they have separate per-space locks)
"$SCRIPT_DIR/tile-space.sh" "$PREV_SPACE" &
"$SCRIPT_DIR/tile-space.sh" "$CURR_SPACE" &

wait
