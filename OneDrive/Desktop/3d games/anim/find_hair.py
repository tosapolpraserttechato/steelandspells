"""Find the hair vertices of a character by texture colour and height, and render a debug picture with them in red.

  blender -b --factory-startup -P find_hair.py -- <character.glb> <yaw> <out_png>
"""
import colorsys
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
path, yaw, out_png = Path(argv[0]).resolve(), float(argv[1]), Path(argv[2]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=str(path))
obj = next(o for o in bpy.data.objects if o.type == "MESH")
obj.rotation_mode = "XYZ"
obj.rotation_euler.z += math.radians(yaw)
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

mesh = obj.data
img = next(n.image for m in mesh.materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE")
w, h = img.size
px = np.empty(w * h * 4, dtype=np.float32)
img.pixels.foreach_get(px)
px = px.reshape(h, w, 4)
uv = mesh.uv_layers.active.data
loops_v = np.empty(len(mesh.loops), dtype=np.int32)
mesh.loops.foreach_get("vertex_index", loops_v)
uvs = np.empty(len(mesh.loops) * 2, dtype=np.float32)
uv.foreach_get("uv", uvs)
uvs = uvs.reshape(-1, 2)
ix = np.clip((uvs[:, 0] % 1.0) * w, 0, w - 1).astype(int)
iy = np.clip((uvs[:, 1] % 1.0) * h, 0, h - 1).astype(int)
loop_rgb = px[iy, ix, :3]
n = len(mesh.vertices)
rgb = np.zeros((n, 3))
cnt = np.zeros(n)
np.add.at(rgb, loops_v, loop_rgb)
np.add.at(cnt, loops_v, 1)
rgb /= np.maximum(cnt, 1)[:, None]
P = np.array([v.co[:] for v in mesh.vertices])
hsv = np.array([colorsys.rgb_to_hsv(*c) for c in rgb])
sel = P[:, 2] > 1.15
print("HUE_HIST", np.histogram(hsv[sel, 0] * 360, bins=[0, 40, 70, 90, 110, 130, 150, 170, 200, 360])[0].tolist())
np.save(str(out_png.with_suffix(".rgbhsv.npy")), np.concatenate([P, rgb, hsv], axis=1))

# debug mask: emerald hair = hue 125-175 degrees, above the shoulders-ish
hair = (P[:, 2] > 1.12) & (hsv[:, 0] * 360 > 125) & (hsv[:, 0] * 360 < 175) & (hsv[:, 1] > 0.35)
print("HAIR", int(hair.sum()), "of", n, "z range", round(float(P[hair, 2].min()), 2), round(float(P[hair, 2].max()), 2), "y range", round(float(P[hair, 1].min()), 2), round(float(P[hair, 1].max()), 2), "x range", round(float(P[hair, 0].min()), 2), round(float(P[hair, 0].max()), 2))
col = mesh.color_attributes.new("dbg", "FLOAT_COLOR", "POINT")
data = np.zeros((n, 4), dtype=np.float32)
data[:, :3] = rgb
data[hair] = (1, 0, 0, 1)
data[:, 3] = 1
col.data.foreach_set("color", data.ravel())
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "VERTEX"
scene.render.resolution_x = scene.render.resolution_y = 600
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 1.4
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.92, 0.93, 0.95, 1)
scene.world = world
for view, pos in (("front", (0, -6, 1.4)), ("right", (6, 0, 1.4))):
    cam.location = pos
    cam.rotation_euler = (Vector((0, 0, 1.4)) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(out_png.with_name(out_png.stem + "_" + view + ".png"))
    bpy.ops.render.render(write_still=True)
