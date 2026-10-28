"""Turn raw Hunyuan GLBs of armor pieces / weapons / perches into game-ready models (small meshes, 1024 px textures).

The game scales and places every piece itself (ArmorKit._model_piece measures the model's bounding box), so nothing is normalised here: only the triangle count and the
texture size are cut down. Run headless:
  blender -b -P prep_armor.py -- <raw_dir> <out_dir> <tris> <tex_px> [name_prefix ...]
Input  <raw_dir>/<set id>__<slot>.glb      (or any name); output <out_dir>/<same name>.glb
"""
import sys
from pathlib import Path

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
raw_dir, out_dir = Path(argv[0]).resolve(), Path(argv[1]).resolve()
tris_target, tex_px = int(argv[2]), int(argv[3])
prefixes = argv[4:]
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
    if prefixes and not any(glb.stem.startswith(p) for p in prefixes):
        continue
    obj = import_single_mesh(glb)
    before = decimate(obj, tris_target)
    shrink_textures(tex_px)
    out_glb = out_dir / glb.name
    export(obj, out_glb)
    after = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print("PREPPED", glb.name, "tris", before, "->", after, "mb", round(out_glb.stat().st_size / 1e6, 2))
