"""Print every bone of the armature in a glTF file: parent, head, tail, roll in armature space."""
import sys
from pathlib import Path

import bpy

path = Path(sys.argv[sys.argv.index("--") + 1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(path))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
print("ARM", arm.name, "loc", tuple(round(v, 3) for v in arm.location), "rot", tuple(round(v, 3) for v in arm.rotation_euler), "scale", tuple(round(v, 3) for v in arm.scale), "parent", arm.parent.name if arm.parent else None)
for b in arm.data.bones:
    print("BONE", b.name, "|", b.parent.name if b.parent else "-", "| head", tuple(round(v, 3) for v in b.head_local), "tail", tuple(round(v, 3) for v in b.tail_local), "conn", b.use_connect)
