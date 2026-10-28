"""Colour a rigged GLB by the dominant bone of every vertex and render front + right views (bind pose), to see where skin weights are wrong.
  blender -b --factory-startup -P weights_debug.py -- <rigged.glb> <out_prefix>
"""
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
glb, prefix = Path(argv[0]).resolve(), Path(argv[1]).resolve()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(glb))
obj = [o for o in bpy.data.objects if o.type == "MESH"][0]
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
# bind pose
for a in bpy.data.actions:
    pass
arm.animation_data_clear()
arm.data.pose_position = "REST"
names = [vg.name for vg in obj.vertex_groups]
n_v = len(obj.data.vertices)
W = np.zeros((n_v, len(names)))
for v in obj.data.vertices:
    for g in v.groups:
        W[v.index, g.group] = g.weight
dom = W.argmax(1)
conf = W.max(1)
pal = {}
def colour(i):
    n = names[i]
    key = n.replace(".L", "").replace(".R", "")
    h = (hash(key) % 997) / 997.0
    import colorsys
    r, g, b = colorsys.hsv_to_rgb(h, 0.9, 0.5 + 0.5 * (1 if n.endswith(".L") else 0.55))
    return (r, g, b)
cols = np.array([colour(i) for i in dom]) * (0.35 + 0.65 * conf[:, None])
rgba = np.concatenate([cols, np.ones((n_v, 1))], axis=1).astype(np.float32)
attr = obj.data.color_attributes.new("dbg", "FLOAT_COLOR", "POINT")
attr.data.foreach_set("color", rgba.ravel())
for m in obj.data.materials:
    pass
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "VERTEX"
scene.render.resolution_x, scene.render.resolution_y = 600, 700
world = bpy.data.worlds.new("w"); world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.9, 0.9, 0.92, 1)
scene.world = world
cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = 2.3
cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
for view, (dx, dy) in (("front", (0, -6)), ("right", (6, 0))):
    cam.location = (dx, dy, 1.0)
    cam.rotation_euler = (Vector((0, 0, 1.0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(prefix) + "_" + view + ".png"
    bpy.ops.render.render(write_still=True)
# legend: bones that own more than 40 vertices
for i, n in enumerate(names):
    c = int((dom == i).sum())
    if c > 40 and ("arm" in n or "hand" in n or "shoulder" in n):
        print("OWNER", n, c)
