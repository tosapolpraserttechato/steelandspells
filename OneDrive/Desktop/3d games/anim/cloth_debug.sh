#!/bin/bash
# Show which vertices each cloth panel claims for a class: anim/cloth_debug.sh <class_id>
cd "$(dirname "$0")/.."
id=$1
LM="anim/fit/${id}_landmarks.json"; [ "$id" = "druid" ] && LM="anim/druid_landmarks.json"
mkdir -p "anim/cloth_debug/$id"
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P anim/rig_character.py -- "map/characters/class_$id.glb" "anim_src/ual_standard/Animation Library[Standard]/Godot/AnimationLibrary_Godot_Standard.glb" "$LM" "anim/out_debug.glb" "anim/cloth_debug/$id" --debug 2>&1 | grep -E "^CLOTH|^RIG (skinned|debug)|Error|Traceback|line [0-9]+|Exception"
