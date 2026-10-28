#!/bin/bash
# Starts every map for a few seconds and reports errors, the decor and animal counts, and takes a picture: shots/map_<id>.png
#   bash tests/all_maps_check.sh [map ...]
cd "$(dirname "$0")/.."
G="C:/Users/Nalinee/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
MAPS="$@"
if [ -z "$MAPS" ]; then
  MAPS="chess_arena clockwork_mines crystal_caves desert_tomb flora_forest frozen_peaks moon_sanctuary pirate_cove shadow_crypt sky_islands toxic_swamp underwater_ocean volcano_forge"
fi
for m in $MAPS; do
  echo "== $m"
  NO_SAVE=1 "$G" --path . --resolution 1280x720 -- autostart=$m class=druid bots=2 "script=1.5:edge:0" shot=res://shots/map_$m.png shot_after=8 quit_after=9 2>&1 | grep -E "ERROR|SCRIPT|Parse|DECOR|CRITTERS" | grep -v "utility function" | head -6
done
echo ALL_MAPS_DONE
