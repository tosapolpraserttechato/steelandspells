"""Render four orthographic views (front, right, back, left; camera at -Y, +X, +Y, -X) of every class model,
small, so each character's facing direction and pose can be judged.

  blender -b --factory-startup -P render_orient.py -- <characters_dir> <out_dir> [class_id ...]
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src_dir, out_dir = Path(argv[0]).resolve(), Path(argv[1]).resolve()
only = set(argv[2:])
out_dir.mkdir(parents=True, exist_ok=True)
VIEWS = {"front": (0, -6), "right": (6, 0), "back": (0, 6), "left": (-6, 0)}

for glb in sorted(src_dir.glob("class_*.glb")):
    cid = glb.stem[len("class_"):]
    if only and cid not in only:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    bpy.ops.import_scene.gltf(filepath=str(glb))
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = 300, 360
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.92, 0.93, 0.95, 1)
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.3
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    for view, (cx, cy) in VIEWS.items():
        cam.location = (cx, cy, 0.95)
        cam.rotation_euler = (Vector((0, 0, 0.95)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out_dir / f"{cid}_{view}.png")
        bpy.ops.render.render(write_still=True)
    print("DONE", cid)
