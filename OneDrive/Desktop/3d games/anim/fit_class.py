"""Fit a skeleton to each class model: find the yaw that makes the front view most symmetric, take the body centre
from the mesh, build the landmarks from anim/classes.json, and render an overlay (bones drawn through a see-through mesh)
so the fit can be judged by eye.

  blender -b --factory-startup -P fit_class.py -- <characters_dir> <classes.json> <out_dir> [class_id ...]
Writes <out_dir>/<id>_landmarks.json and <out_dir>/<id>_overlay_front.png / _right.png
"""
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import landmarks_lib  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
src_dir, cfg_path, out_dir = (Path(a).resolve() for a in argv[:3])
only = set(argv[3:])
configs = json.loads(cfg_path.read_text(encoding="utf-8"))
out_dir.mkdir(parents=True, exist_ok=True)


def rot(P, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return np.stack([P[:, 0] * c - P[:, 1] * s, P[:, 0] * s + P[:, 1] * c, P[:, 2]], axis=1)


def symmetry_score(P, H, f0):
    """How well the body (legs to shoulders) mirrors left-right about its own centre in a front view (overlap of the two halves)."""
    m = (P[:, 2] > f0 + 0.05 * H) & (P[:, 2] < f0 + 0.80 * H)
    q = P[m]
    xc = np.median(q[:, 0])
    q = q[np.abs(q[:, 0] - xc) < 0.5]
    res = 0.02
    ix = np.clip(np.round((q[:, 0] - xc) / res).astype(int) + 30, 0, 60)
    iz = np.clip(np.round(q[:, 2] / res).astype(int), 0, 130)
    g = np.zeros((61, 131), dtype=bool)
    g[ix, iz] = True
    mirror = g[::-1, :]
    return float((g & mirror).sum()) / max(float((g | mirror).sum()), 1.0)


def add_line(scene, name, p0, p1, color, radius):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    sp = cu.splines.new("POLY")
    sp.points.add(1)
    sp.points[0].co = (*p0, 1)
    sp.points[1].co = (*p1, 1)
    ob = bpy.data.objects.new(name, cu)
    scene.collection.objects.link(ob)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    ob.data.materials.append(mat)
    return ob


for cid, cfg in configs.items():
    if (only and cid not in only) or cfg.get("manual"):          # manual = skeleton measured by hand (the Druid)
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    bpy.ops.import_scene.gltf(filepath=str(src_dir / f"class_{cid}.glb"))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    P = np.array([(o.matrix_world @ vv.co)[:] for o in meshes for vv in o.data.vertices])
    H, f0 = cfg["H"], cfg.get("floor_z", 0.0)
    scores = [(symmetry_score(rot(P, cfg["yaw"] + d), H, f0), cfg["yaw"] + d) for d in np.arange(-cfg["yaw_range"], cfg["yaw_range"] + 0.1, 3.0)]
    base = symmetry_score(rot(P, cfg["yaw"]), H, f0)
    best = max(scores)
    if best[0] < base + 0.03:                        # only turn the model when it clearly looks more symmetric
        best = (base, cfg["yaw"])
    yaw = float(best[1])
    Q = rot(P, yaw)
    # body axis: feet and head both tell where the body stands; capes, weapons and wings pull a plain median sideways
    def centre_of(mask, r):
        c = (float(np.median(Q[mask, 0])), float(np.median(Q[mask, 1])))
        for _ in range(4):
            near = mask & (np.abs(Q[:, 0] - c[0]) < r) & (np.abs(Q[:, 1] - c[1]) < r)
            c = (float(np.median(Q[near, 0])), float(np.median(Q[near, 1])))
        return c
    feet_c = centre_of((Q[:, 2] > f0) & (Q[:, 2] < f0 + 0.07 * H), 0.25)
    head_c = centre_of((Q[:, 2] > f0 + 0.88 * H) & (Q[:, 2] < f0 + 0.97 * H), 0.2)
    mode = cfg.get("centre", "feet")
    if isinstance(mode, list):
        xc, yc = mode
    elif mode == "head":
        xc, yc = head_c
    else:
        xc, yc = feet_c[0], head_c[1]
    yc = yc - 0.04                                   # the head sits a little forward of the spine
    print("CENTRE", cid, "feet", [round(v, 3) for v in feet_c], "head", [round(v, 3) for v in head_c], "used", round(xc, 3), round(yc, 3))
    cfg2 = dict(cfg, name=cid, yaw=round(yaw, 1))
    lm = landmarks_lib.build(cfg2, xc, yc)
    if "hair_bones" in lm:
        lm["hair_rule"] = {"mode": "behind_head"}
    (out_dir / f"{cid}_landmarks.json").write_text(json.dumps(lm, indent=1), encoding="utf-8")
    print("FIT", cid, "yaw", round(yaw, 1), "symmetry", round(best[0], 3), "centre", round(xc, 3), round(yc, 3), "height", round(float(Q[:, 2].max()), 2))

    for o in meshes:
        o.rotation_mode = "XYZ"
        o.rotation_euler.z += math.radians(yaw)
    for name, b in {**lm["bones"], **lm.get("hair_bones", {})}.items():
        hair = name.startswith("hair")
        add_line(scene, name, b["head"], b["tail"], (0.1, 0.3, 1.0) if hair else (1.0, 0.1, 0.1), 0.012)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_xray = True
    scene.display.shading.xray_alpha = 0.45
    scene.render.resolution_x, scene.render.resolution_y = 420, 520
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.92, 0.93, 0.95, 1)
    scene.world = world
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.35
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    centre = Vector((xc, yc, 0.95))
    for view, (dx, dy) in (("front", (0, -6)), ("right", (6, 0))):
        cam.location = (xc + dx, yc + dy, 0.95)
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out_dir / f"{cid}_overlay_{view}.png")
        bpy.ops.render.render(write_still=True)
