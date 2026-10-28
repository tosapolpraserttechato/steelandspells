"""Render orthographic views (front, back, left, right, top) of a character GLB with a measuring grid.

The grid lines are every 0.25 m in the picture frame so joint positions can be read off: the camera looks
at (0, 0, 0.95) with ortho_scale 2.4 m in a 800 x 800 picture.

  blender -b --factory-startup -P render_views.py -- <model.glb> <out_dir> <name> [yaw_degrees] [look_at_z] [picture_width_m]
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
model, out_dir, name = Path(argv[0]).resolve(), Path(argv[1]).resolve(), argv[2]
yaw = float(argv[3]) if len(argv) > 3 else 0.0       # turn the model about Z first (degrees)
cz = float(argv[4]) if len(argv) > 4 else 0.95        # height the camera looks at
scale = float(argv[5]) if len(argv) > 5 else 2.4      # ortho_scale: picture width in metres
out_dir.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(model))
if yaw:
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.rotation_mode = "XYZ"
            o.rotation_euler.z += math.radians(yaw)
    bpy.context.view_layer.update()

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "TEXTURE"
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.film_transparent = False
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.92, 0.93, 0.95, 1)
scene.world = world

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = scale
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
centre = Vector((0, 0, cz))

# a measuring grid on a plane behind the model for each view: thin lines every 0.25 m, thicker at metres
VIEWS = {"front": (0, -6, cz), "back": (0, 6, cz), "left": (-6, 0, cz), "right": (6, 0, cz)}
for view, pos in VIEWS.items():
    cam.location = pos
    cam.rotation_euler = (centre - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(out_dir / f"{name}_{view}.png")
    bpy.ops.render.render(write_still=True)
cam.location = (0, 0, 8)
cam.rotation_euler = (0, 0, 0)
scene.render.filepath = str(out_dir / f"{name}_top.png")
bpy.ops.render.render(write_still=True)
print("DONE", name)
