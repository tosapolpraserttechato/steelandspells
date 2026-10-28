"""List the skeleton and the animation clips in a glTF humanoid animation pack.

  blender -b --factory-startup -P inspect_ual.py -- <file.glb>
"""
import sys
from pathlib import Path

import bpy

path = Path(sys.argv[sys.argv.index("--") + 1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(path))
arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
print("ARMATURES", [(a.name, len(a.data.bones)) for a in arms])
print("MESHES", [(m.name, len(m.data.vertices)) for m in meshes])
for a in arms:
    print("BONES", [b.name for b in a.data.bones])
    print("REST_HEIGHT", max(b.tail_local.z for b in a.data.bones))
acts = sorted(bpy.data.actions, key=lambda x: x.name)
print("ACTIONS", len(acts))
for act in acts:
    print("ACT", act.name, [int(act.frame_range[0]), int(act.frame_range[1])])
print("FPS", bpy.context.scene.render.fps)
