"""Print per-height statistics of a character mesh (after turning it about Z) to help place joints.

  blender -b --factory-startup -P slice_mesh.py -- <model.glb> <yaw_degrees>
"""
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
path, yaw = Path(argv[0]), float(argv[1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(path))
obj = next(o for o in bpy.data.objects if o.type == "MESH")
pts = np.array([(obj.matrix_world @ v.co)[:] for v in obj.data.vertices])
c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
x = pts[:, 0] * c - pts[:, 1] * s
y = pts[:, 0] * s + pts[:, 1] * c
z = pts[:, 2]
print("BBOX x", round(x.min(), 3), round(x.max(), 3), "y", round(y.min(), 3), round(y.max(), 3), "z", round(z.min(), 3), round(z.max(), 3), "n", len(z))
for z0 in np.arange(0.0, 1.86, 0.05):
    m = (z >= z0) & (z < z0 + 0.05) & (np.abs(y - 0.07) < 0.28)         # drop the bow, which sticks far out front and back
    if m.sum() < 5:
        print("SLICE", round(z0, 2), "n", int(m.sum()))
        continue
    xs, ys = x[m], y[m]
    print("SLICE", round(z0, 2), "n", int(m.sum()), "x", round(xs.min(), 3), round(float(np.median(xs)), 3), round(xs.max(), 3), "y", round(ys.min(), 3), round(float(np.median(ys)), 3), round(ys.max(), 3))
