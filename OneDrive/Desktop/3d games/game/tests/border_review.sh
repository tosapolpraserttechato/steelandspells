#!/bin/bash
# Takes a picture from near each map edge, looking outwards, for the maps given (or all 13): shots/edge_<map>_<angle>.png
#   bash tests/border_review.sh [map ...]
cd "$(dirname "$0")/.."
G="C:/Users/Nalinee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
MAPS="$@"
if [ -z "$MAPS" ]; then
  MAPS="chess_arena clockwork_mines crystal_caves desert_tomb flora_forest frozen_peaks moon_sanctuary pirate_cove shadow_crypt sky_islands toxic_swamp underwater_ocean volcano_forge"
fi
for m in $MAPS; do
  for a in 0 90; do
    NO_SAVE=1 "$G" --path . --resolution 1280x720 -- autostart=$m class=druid bots=1 "script=1.5:edge:$a" shot=res://shots/edge_${m}_$a.png shot_after=6 quit_after=7 2>&1 | grep -E "ERROR|SCRIPT" | head -3
  done
  echo "done $m"
done
echo BORDERS_DONE
