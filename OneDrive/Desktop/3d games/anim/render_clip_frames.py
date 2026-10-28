"""Open a rigged character GLB (with its animation clips) and render chosen frames of a clip, e.g. a head close-up
to check the hair motion. Also proves the exported GLB really carries the clips.

  blender -b --factory-startup -P render_clip_frames.py -- <rigged.glb> <out_dir> <name> <clip> <look_at_z> <picture_width_m> <frame> [frame ...]
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
glb, out_dir, name, clip = Path(argv[0]).resolve(), Path(argv[1]).resolve(), argv[2], argv[3]
cz, width = float(argv[4]), float(argv[5])
NO_CULL = "--noculling" in argv
frames = [int(f) for f in argv[6:] if not f.startswith("--")]
out_dir.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=str(glb))
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
print("CLIPS", sorted(a.name for a in bpy.data.actions))
act = next(a for a in bpy.data.actions if a.name.split("|")[-1] == clip or a.name == clip)
arm.animation_data_create()
arm.animation_data.action = act
if hasattr(arm.animation_data, "action_slot") and act.slots:
    arm.animation_data.action_slot = act.slots[0]

if NO_CULL:
    for m in bpy.data.materials:
        m.use_backface_culling = False
print("CULLING", [(m.name, m.use_backface_culling, m.blend_method if hasattr(m, "blend_method") else None) for m in bpy.data.materials])
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "TEXTURE"
scene.render.resolution_x = scene.render.resolution_y = 500
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.92, 0.93, 0.95, 1)
scene.world = world
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = width
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
pos = Vector((3.0, 3.2, cz))                  # from behind and to the side, to see the hair that hangs down the back
cam.location = pos
cam.rotation_euler = (Vector((0, 0.1, cz)) - pos).to_track_quat("-Z", "Y").to_euler()
for f in frames:
    scene.frame_set(f)
    scene.render.filepath = str(out_dir / f"{name}{"_nocull" if NO_CULL else ""}_{clip}_{f:03d}.png")
    bpy.ops.render.render(write_still=True)
print("DONE")
