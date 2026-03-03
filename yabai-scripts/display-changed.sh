#!/usr/bin/env bash

# Retile both displays on focus change
# Acts as a safety net - the primary cross-display drag detection
# is handled by window-moved.sh via per-window display caching.
#
# yabai provides:
#   $YABAI_DISPLAY_INDEX - new display index
#   $YABAI_RECENT_DISPLAY_INDEX - previous display index

set -euo pipefail

PREV_DISPLAY="${YABAI_RECENT_DISPLAY_INDEX:-}"
CURR_DISPLAY="${YABAI_DISPLAY_INDEX:-}"

[ -z "$PREV_DISPLAY" ] || [ -z "$CURR_DISPLAY" ] && exit 0
[ "$PREV_DISPLAY" = "$CURR_DISPLAY" ] && exit 0

SCRIPT_DIR="$(dirname "$0")"

(
    sleep 0.3
    "$SCRIPT_DIR/tile-display.sh" "$PREV_DISPLAY" &
    "$SCRIPT_DIR/tile-display.sh" "$CURR_DISPLAY" &
    wait
) &
disown
