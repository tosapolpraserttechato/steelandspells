#!/bin/bash
# Rig every class listed in anim/classes.json (or the ids given) with rig_character.py.
cd "$(dirname "$0")/.."
BL="C:/Program Files/Blender Foundation/Blender 5.2/blender.exe"
UAL1="anim_src/ual_standard/Animation Library[Standard]/Godot/AnimationLibrary_Godot_Standard.glb"
UAL2="anim_src/ual2_standard/Universal Animation Library 2 [Standard]/Unreal-Godot/UAL2_Standard.glb"
IDS="$@"
if [ -z "$IDS" ]; then IDS=$(node -e "console.log(Object.keys(require('./anim/classes.json')).join(' '))"); fi
for id in $IDS; do
  echo "=== $id"
  LM="anim/fit/${id}_landmarks.json"; [ "$id" = "druid" ] && LM="anim/druid_landmarks.json"
  mkdir -p "anim/previews/$id"
  rm -f anim/previews/$id/*.png
  "$BL" -b --factory-startup -P anim/rig_character.py -- "map/characters/class_$id.glb" "$UAL1" "$LM" "anim/out/class_${id}_rigged.glb" "anim/previews/$id" "$UAL2" 2>&1 | grep -E "^RIG (skinned|exported)|Error|Traceback|line [0-9]+"
done
echo "ALL DONE"
