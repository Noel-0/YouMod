#!/bin/sh
set -eu

source_root=${1:-.}
player_file="$source_root/Files/Player.x"

test -f "$player_file" || {
  echo "Missing $player_file" >&2
  exit 2
}

grep -Fq '%hook YTFullscreenEngagementOverlayController' "$player_file" &&
  grep -Fq '%orig(IS_ENABLED(DisablesEngagementPanel) ? NO : enabled);' "$player_file"
