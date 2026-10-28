"""Turn raw Hunyuan GLBs of weapons into game-ready models: stand the weapon upright (long axis along glTF +Y), put the business end on top, centre it on the grip's
bounding box, cut the triangles and shrink the textures.

  blender -b -P prep_weapon.py -- <raw_dir> <out_dir> <tris> <tex_px> <orient.json>
orient.json: {"<file stem>": "wide" | "narrow" | "none"}   (wide: the heavier end is the top, as for a staff head, an axe or a hammer; narrow: the thin end is the top, as for a blade;
"none": keep the pose as generated: orbs and crossbows)
Blender is Z-up: the long axis goes to +Z here, the glTF exporter turns it into +Y. The second axis (the width of a blade or the sweep of a bow) goes to +X.
"""
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
raw_dir, out_dir = Path(argv[0]).resolve(), Path(argv[1]).resolve()
tris_target, tex_px = int(argv[2]), int(argv[3])
orient = json.loads(Path(argv[4]).read_text(encoding="utf-8"))
out_dir.mkdir(parents=True, exist_ok=True)


def import_single_mesh(glb):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o != obj:
            bpy.data.objects.remove(o, do_unlink=True)
    return obj


def stand_up(obj, mode):
    P = np.array([v.co[:] for v in obj.data.vertices])
    c = P.mean(axis=0)
    Q = P - c
    # principal axes of the vertex cloud, weighted so a thin weapon with a big head is not dominated by the head
    w, V = np.linalg.eigh(np.cov(Q.T))
    order = np.argsort(-w)
    a1, a2 = V[:, order[0]], V[:, order[1]]
    t = Q @ a1
    lo, hi = np.percentile(t, 20), np.percentile(t, 80)
    top, bot = Q[t >= hi], Q[t <= lo]

    def spread(S):
        s = S - np.outer(S @ a1, a1)
        return float(np.sqrt((s ** 2).sum(axis=1).mean()))

    heavier_up = spread(top) >= spread(bot)
    if (mode == "wide") != heavier_up:
        a1 = -a1
        a2 = -a2
    a3 = np.cross(a1, a2)                      # right-handed: x = a2, y = a3, z = a1 (a2 x a3 = a1)
    R = np.stack([a2, a3, a1], axis=0)        # rows map the old axes onto the new x, y, z
    Pn = Q @ R.T
    lo_z = Pn[:, 2].min()
    Pn[:, 2] -= (lo_z + Pn[:, 2].max()) * 0.5
    for v, p in zip(obj.data.vertices, Pn):
        v.co = Vector(p)
    # the normals follow the new vertex positions
    obj.data.update()
    return float(Pn[:, 2].max() - Pn[:, 2].min())


def decimate(obj, target):
    current = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    if current <= target:
        return current
    mod = obj.modifiers.new("decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = target / current
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return current


def shrink_textures(px):
    for img in bpy.data.images:
        if img.size[0] == 0:
            continue
        if img.size[0] > px:
            img.scale(px, px)


def export(obj, path):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    kwargs = dict(filepath=str(path), export_format="GLB", use_selection=True, export_apply=True)
    try:
        bpy.ops.export_scene.gltf(**kwargs, export_image_format="JPEG", export_image_quality=88)
    except TypeError:
        bpy.ops.export_scene.gltf(**kwargs, export_image_format="JPEG")


for glb in sorted(raw_dir.glob("*.glb")):
    mode = orient.get(glb.stem, "none")
    obj = import_single_mesh(glb)
    length = 0.0
    if mode != "none":
        length = stand_up(obj, mode)
    before = decimate(obj, tris_target)
    shrink_textures(tex_px)
    out_glb = out_dir / glb.name
    export(obj, out_glb)
    print("PREPPED", glb.name, mode, "length", round(length, 2), "tris", before, "->", sum(len(p.vertices) - 2 for p in obj.data.polygons))
