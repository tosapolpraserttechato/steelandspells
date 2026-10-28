"""Rig one Hunyuan character with a skeleton fitted from measured joints, skin it, retarget the Quaternius
Universal Animation Library (CC0) clips onto it, and add simulated hair motion.

  blender -b --factory-startup -P rig_character.py -- <character.glb> <ual.glb> <landmarks.json> <out.glb> <preview_dir>

Steps
 1. turn the mesh to face -Y
 2. build a skeleton with the library's bone names but the character's own proportions and resting pose
 3. skin the mesh (Blender's automatic weights fail on these fused meshes, so every vertex is weighted by its
    distance to each bone, measured against that body part's thickness, then smoothed along the mesh)
 4. for every clip copy the library bone's world-space rotation change onto the character's bone; a retarget that
    works although the library rests in a T-pose and the character stands with its arms down. Hips movement is scaled
    to the character's size. Bones listed in "straighten" are posed from a straight leg (the mesh keeps its real stance).
 5. hair: bones listed in "hair_bones" hang from the head; the hair vertices (found by texture colour) are weighted to
    them; a small spring simulation of each strand (inertia, spring back, a light breeze) is baked into every clip.
 6. write a GLB with the mesh, skeleton and all clips, plus preview pictures.
"""
import colorsys
import json
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
DEBUG = "--debug" in argv                 # only show which vertices each cloth panel claims, then stop
argv = [a for a in argv if not a.startswith("--")]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import cloth as clothlib  # noqa: E402

char_glb, ual_glb, lm_path, out_glb, preview_dir = (Path(a).resolve() for a in argv[:5])
ual2_glb = Path(argv[5]).resolve() if len(argv) > 5 else None      # optional second CC0 library (Universal Animation Library 2)
lm = json.loads(lm_path.read_text(encoding="utf-8"))
preview_dir.mkdir(parents=True, exist_ok=True)

CLIPS = {  # name in the game -> clip in the library
    "Idle": "Idle_Loop", "Run": "Jog_Fwd_Loop", "Sprint": "Sprint_Loop",
    "JumpStart": "Jump_Start", "JumpLoop": "Jump_Loop", "JumpLand": "Jump_Land",
    "CastEnter": "Spell_Simple_Enter", "CastIdle": "Spell_Simple_Idle_Loop", "CastShoot": "Spell_Simple_Shoot", "CastExit": "Spell_Simple_Exit",
    "Attack": "Sword_Attack", "HitChest": "Hit_Chest", "HitHead": "Hit_Head", "Death": "Death01",
}
# extra clips from Universal Animation Library 2 (CC0): its bones use Unreal-style names, mapped to the first library's
EXTRA_CLIPS = {
    "Knockback": "Hit_Knockback", "Throw": "OverhandThrow", "Hook": "Melee_Hook", "Block": "Sword_Block",
    "MeleeA": "Sword_Regular_A", "MeleeB": "Sword_Regular_B", "MeleeC": "Sword_Regular_C", "MeleeCombo": "Sword_Regular_Combo",
    "SlideStart": "Slide_Start", "SlideLoop": "Slide_Loop", "SlideExit": "Slide_Exit",
    "Consume": "Consume", "ChestOpen": "Chest_Open", "Revive": "LayToIdle", "EmoteYes": "Yes", "EmoteNo": "Idle_No_Loop",
}
UAL2_MAP = {"root": "root", "DEF-hips": "pelvis", "DEF-spine.001": "spine_01", "DEF-spine.002": "spine_02", "DEF-spine.003": "spine_03",
            "DEF-neck": "neck_01", "DEF-head": "Head"}
for _s, _l in (("L", "l"), ("R", "r")):
    UAL2_MAP.update({f"DEF-shoulder.{_s}": f"clavicle_{_l}", f"DEF-upper_arm.{_s}": f"upperarm_{_l}", f"DEF-forearm.{_s}": f"lowerarm_{_l}",
                     f"DEF-hand.{_s}": f"hand_{_l}", f"DEF-thigh.{_s}": f"thigh_{_l}", f"DEF-shin.{_s}": f"calf_{_l}",
                     f"DEF-foot.{_s}": f"foot_{_l}", f"DEF-toe.{_s}": f"ball_{_l}"})
REF_CLIP = "Idle_Loop"       # a pose with the arms down: the character's resting pose is matched to its first frame
FPS = 24.0


def log(*a):
    print("RIG", *a, flush=True)


# ---------------------------------------------------------------- 1. the character mesh, turned to face -Y

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=str(char_glb))
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.parent = None
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
char = bpy.context.view_layer.objects.active
char.rotation_mode = "XYZ"
char.rotation_euler.z += math.radians(lm["yaw"])
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# a display base under the feet (Thunder God) is cut off and the character is lowered onto the floor
fz = lm.get("floor_z", 0.0)
if fz:
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(char.data)
    rx, ry = lm["bones"]["root"]["head"][0], lm["bones"]["root"]["head"][1]
    # the base: everything under the floor line, plus its thin rim (low and far from the feet)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < fz - 0.004 or (v.co.z < fz + 0.10 and math.hypot(v.co.x - rx, v.co.y - ry) > 0.22)], context="VERTS")
    for v in bm.verts:
        v.co.z -= fz
    bm.to_mesh(char.data)
    bm.free()
    for b in list(lm["bones"].values()) + list(lm.get("hair_bones", {}).values()):
        b["head"][2] -= fz
        b["tail"][2] -= fz
    if "hair_geom" in lm:
        lm["hair_geom"]["min_z"] -= fz
    log("base removed below", fz, "; mesh lowered")
log("mesh", char.name, len(char.data.vertices), "vertices")

# ---------------------------------------------------------------- 2. the animation library (source skeleton and clips)

before = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=str(ual_glb))
new = [o for o in bpy.data.objects if o not in before]
src = next(o for o in new if o.type == "ARMATURE")
for o in new:
    if o.type == "MESH":
        bpy.data.objects.remove(o, do_unlink=True)
src.animation_data_create()
src2 = None
if ual2_glb is not None:
    before2 = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ual2_glb))
    new2 = [o for o in bpy.data.objects if o not in before2]
    src2 = next(o for o in new2 if o.type == "ARMATURE")
    for o in new2:
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    src2.animation_data_create()
    missing = [v for v in UAL2_MAP.values() if v not in src2.data.bones]
    log("second library bones missing:", missing)


def play(armature, action, frame):
    armature.animation_data.action = action
    if hasattr(armature.animation_data, "action_slot") and action.slots:
        armature.animation_data.action_slot = action.slots[0]
    scene.frame_set(frame)


# ---------------------------------------------------------------- 3. the character's skeleton

BODY = lm["bones"]
HAIR = lm.get("hair_bones", {})
HAIR_ORDER = list(HAIR.keys())


def hair_vertex_mask(obj, rule):
    """Hair = emerald-green texture colour above the shoulders (found from the colour texture through the UVs), or for
    classes without a hair colour rule (mode behind_head) the vertices behind the head and neck, above the hair length."""
    mesh = obj.data
    if rule.get("mode") == "behind_head":
        g = lm["hair_geom"]
        P = np.array([v.co[:] for v in mesh.vertices])
        return (P[:, 2] > g["min_z"]) & (P[:, 1] > g["behind_y"]) & (np.abs(P[:, 0] - g["xc"]) < g["half_width"])
    img = next(n.image for m in mesh.materials for n in m.node_tree.nodes if n.type == "TEX_IMAGE")
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    uvs = np.empty(len(mesh.loops) * 2, dtype=np.float32)
    mesh.uv_layers.active.data.foreach_get("uv", uvs)
    uvs = uvs.reshape(-1, 2)
    loops_v = np.empty(len(mesh.loops), dtype=np.int32)
    mesh.loops.foreach_get("vertex_index", loops_v)
    loop_rgb = px[np.clip((uvs[:, 1] % 1.0) * h, 0, h - 1).astype(int), np.clip((uvs[:, 0] % 1.0) * w, 0, w - 1).astype(int), :3]
    n = len(mesh.vertices)
    rgb, cnt = np.zeros((n, 3)), np.zeros(n)
    np.add.at(rgb, loops_v, loop_rgb)
    np.add.at(cnt, loops_v, 1)
    rgb /= np.maximum(cnt, 1)[:, None]
    P = np.array([v.co[:] for v in mesh.vertices])
    hsv = np.array([colorsys.rgb_to_hsv(*c) for c in rgb])
    return (P[:, 2] > rule["min_z"]) & (hsv[:, 0] * 360 > rule["hue_min"]) & (hsv[:, 0] * 360 < rule["hue_max"]) & (hsv[:, 1] > rule["min_sat"])


RADII = {"DEF-hips": 0.17, "DEF-spine.001": 0.16, "DEF-spine.002": 0.16, "DEF-spine.003": 0.17, "DEF-neck": 0.06, "DEF-head": 0.11,
         "DEF-shoulder.L": 0.07, "DEF-shoulder.R": 0.07, "DEF-upper_arm.L": 0.055, "DEF-upper_arm.R": 0.055, "DEF-forearm.L": 0.045,
         "DEF-forearm.R": 0.045, "DEF-hand.L": 0.04, "DEF-hand.R": 0.04, "DEF-thigh.L": 0.09, "DEF-thigh.R": 0.09, "DEF-shin.L": 0.065,
         "DEF-shin.R": 0.065, "DEF-foot.L": 0.05, "DEF-foot.R": 0.05, "DEF-toe.L": 0.04, "DEF-toe.R": 0.04}
RADII = {k: v * lm.get("H", 1.7) / 1.7 for k, v in RADII.items()}     # thicker, taller characters get thicker body parts
for n in HAIR_ORDER:
    RADII[n] = 0.07 * lm.get("H", 1.7) / 1.7
hips_z = BODY["DEF-hips"]["head"][2]
hair_mask = hair_vertex_mask(char, lm["hair_rule"]) if HAIR else np.zeros(len(char.data.vertices), dtype=bool)

# cloth panels (skirts, coats, capes, wings) from anim/classes.json
class_cfg = json.loads((Path(__file__).resolve().parent / "classes.json").read_text(encoding="utf-8")).get(lm["name"], {})
panels = []
if class_cfg.get("cloth"):
    panels = clothlib.build_panels(np.array([v.co[:] for v in char.data.vertices]), lm, RADII, hair_mask, class_cfg["cloth"])
CLOTH = {}
for _pn in panels:
    CLOTH.update(_pn["bones"])
CLOTH_ORDER = list(CLOTH.keys())
for _n in CLOTH_ORDER:
    RADII[_n] = 1.0
ALL = {**BODY, **HAIR, **CLOTH}
arm_data = bpy.data.armatures.new("rig")
tgt = bpy.data.objects.new("rig", arm_data)
scene.collection.objects.link(tgt)
bpy.context.view_layer.objects.active = tgt
tgt.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
for name, b in ALL.items():
    eb = arm_data.edit_bones.new(name)
    eb.head, eb.tail = Vector(b["head"]), Vector(b["tail"])
for name, b in ALL.items():
    if b["parent"]:
        arm_data.edit_bones[name].parent = arm_data.edit_bones[b["parent"]]
bpy.ops.object.mode_set(mode="OBJECT")
ORDER = list(BODY.keys())                            # parents come before children in the landmarks file

# ---------------------------------------------------------------- 4. skin the mesh


SMOOTH_STEPS = 45
LOWER_SMOOTH_STEPS = 140
HAIR_SOFT, HAIR_SMOOTH_STEPS = 3.0, 160


def skin_mesh(obj, names, bones_lm, hair_mask):
    P = np.array([v.co[:] for v in obj.data.vertices])
    D = []
    for n in names:
        a, b = np.array(bones_lm[n]["head"]), np.array(bones_lm[n]["tail"])
        ab = b - a
        tt = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
        d = np.linalg.norm(P - (a + tt[:, None] * ab), axis=1) / RADII[n]
        if n in CLOTH:
            d = np.full(len(P), 1e6)                                  # cloth chains are weighted by their panel below
        elif n in HAIR:
            d = np.where(hair_mask, d, 1e6)                          # hair bones only move hair
        elif n not in ("DEF-head", "DEF-neck"):
            d = np.where(hair_mask & (P[:, 2] > 1.1), d + 3.0, d)    # hair follows only the head, neck and its own strands
        D.append(d)
    Dst = np.stack(D, axis=1)
    if lm.get("leg_sides"):
        # each leg only takes the vertices on its own side of the body (below the crotch): with the legs close together an inner trouser
        # vertex would otherwise follow the other leg and shred when the legs swing apart
        _xc = float(bones_lm["DEF-hips"]["head"][0])
        _lowv = P[:, 2] < float(bones_lm["DEF-hips"]["head"][2]) - 0.02
        _gap = float(lm["leg_sides"])
        for _i, _n in enumerate(names):
            if any(k in _n for k in ("thigh", "shin", "foot", "toe")):
                _wrong = (P[:, 0] < _xc - _gap) if _n.endswith(".L") else (P[:, 0] > _xc + _gap)          # +X is the character's left
                Dst[:, _i] = np.where(_lowv & _wrong, Dst[:, _i] + 6.0, Dst[:, _i])
    W = 1.0 / np.maximum(Dst, 0.25) ** 8
    W /= W.sum(1, keepdims=True)
    # Cloth that hangs far from the legs (skirts, robes, coats) follows the pelvis instead of tearing between the two legs.
    leg_cols = [i for i, n in enumerate(names) if any(k in n for k in ("thigh", "shin", "foot", "toe"))]
    hips_col = names.index("DEF-hips")
    sk = np.where(P[:, 2] < hips_z, np.clip((Dst[:, leg_cols].min(axis=1) - 1.4) / 2.0, 0.0, 0.85), 0.0)
    moved = W[:, leg_cols].sum(axis=1) * sk
    W[:, leg_cols] *= (1.0 - sk)[:, None]
    W[:, hips_col] += moved
    E = np.array([e.vertices[:] for e in obj.data.edges])
    cnt = np.zeros(len(P))
    np.add.at(cnt, E[:, 0], 1)
    np.add.at(cnt, E[:, 1], 1)
    hair_cols = np.array([n in HAIR for n in names])
    for _ in range(SMOOTH_STEPS):
        acc = np.zeros_like(W)
        np.add.at(acc, E[:, 0], W[E[:, 1]])
        np.add.at(acc, E[:, 1], W[E[:, 0]])
        W = 0.5 * W + 0.5 * acc / np.maximum(cnt, 1)[:, None]
        if hair_cols.any():
            W[np.ix_(~hair_mask, hair_cols)] = 0.0                   # smoothing must not leak hair weights onto the body
        W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
    # Arms that are re-posed a long way (an A-pose mesh hung down, see "hang_arms") blend their weights over a wider zone along the sleeve
    # (shoulder, elbow, wrist, fingers), otherwise the cloth tears where the bones turn differently.
    if lm.get("hang_arms") is not None:
        arm_cols = [i for i, n in enumerate(names) if any(k in n for k in ("upper_arm", "forearm", "hand"))]
        arm_zone = Dst[:, arm_cols].min(axis=1) < 2.6
        for _ in range(int(lm.get("arm_smooth", 40))):
            acc = np.zeros_like(W)
            np.add.at(acc, E[:, 0], W[E[:, 1]])
            np.add.at(acc, E[:, 1], W[E[:, 0]])
            W[arm_zone] = 0.5 * W[arm_zone] + 0.5 * (acc / np.maximum(cnt, 1)[:, None])[arm_zone]
            W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
    # Skirts, robes and coats wrap both legs: smooth the weights much further below the hips (along the surface, so
    # separate trouser legs stay separate) or the hem tears apart between the legs when they move.
    low = P[:, 2] < hips_z + 0.05 * lm.get("H", 1.7)
    for _ in range(LOWER_SMOOTH_STEPS):
        acc = np.zeros_like(W)
        np.add.at(acc, E[:, 0], W[E[:, 1]])
        np.add.at(acc, E[:, 1], W[E[:, 0]])
        W[low] = 0.5 * W[low] + 0.5 * (acc / np.maximum(cnt, 1)[:, None])[low]
        if hair_cols.any():
            W[np.ix_(~hair_mask, hair_cols)] = 0.0
        W /= np.maximum(W.sum(1, keepdims=True), 1e-9)
    # The hair is one continuous shell. Its weights depend only on height along the back strand (head, then each hair bone with
    # a linear blend between neighbours), so the whole hair mass bends together and the shell cannot tear open sideways
    # (torn gaps looked like transparent strands).
    hair_idx = np.nonzero(hair_mask)[0]
    chain = sorted([n for n in names if n.startswith("hair_back_")], key=lambda n: int(n.rsplit("_", 1)[1]))
    if len(hair_idx) and chain:
        ztop = bones_lm[chain[0]]["head"][2]
        zbot = bones_lm[chain[-1]]["tail"][2]
        u = (ztop - P[hair_idx, 2]) / max(ztop - zbot, 1e-6) * len(chain)
        Wh = np.zeros((len(hair_idx), W.shape[1]))
        Wh[:, names.index("DEF-head")] = np.where(u <= -0.5, 1.0, np.clip(1.0 - (u + 0.5), 0.0, 1.0))
        for j, n in enumerate(chain, 1):
            w = np.clip(1.0 - np.abs(u - (j - 0.5)), 0.0, 1.0)
            if j == len(chain):
                w = np.where(u >= j - 0.5, 1.0, w)
            Wh[:, names.index(n)] = w
        W[hair_idx] = Wh / np.maximum(Wh.sum(1, keepdims=True), 1e-9)
    for _pn in panels:                                            # cloth panels take over the vertices that belong to them
        W = clothlib.apply_weights(W, names, P, _pn)
    keep = np.argsort(-W, axis=1)[:, :4]
    mask = np.zeros_like(W, dtype=bool)
    np.put_along_axis(mask, keep, True, axis=1)
    W = np.where(mask, W, 0.0)
    W /= W.sum(1, keepdims=True)
    for vg in list(obj.vertex_groups):
        obj.vertex_groups.remove(vg)
    groups = [obj.vertex_groups.new(name=n) for n in names]
    for gi, g in enumerate(groups):
        for vi in np.nonzero(W[:, gi] > 0.003)[0]:
            g.add([int(vi)], float(W[vi, gi]), "REPLACE")
    return W


bpy.ops.object.select_all(action="DESELECT")
char.select_set(True)
tgt.select_set(True)
bpy.context.view_layer.objects.active = tgt
bpy.ops.object.parent_set(type="ARMATURE_NAME")
weights = skin_mesh(char, [n for n in ORDER if n != "root"] + HAIR_ORDER + CLOTH_ORDER, ALL, hair_mask)
log("skinned:", len(char.vertex_groups), "groups;", int(hair_mask.sum()), "hair vertices;", int((weights.max(1) < 0.5).sum()), "vertices with no main bone")

if DEBUG:
    n_v = len(char.data.vertices)
    colors = np.tile(np.array([0.80, 0.80, 0.82]), (n_v, 1))
    for k, pn in enumerate(panels):
        colors = colors * (1 - pn["cw"][:, None]) + np.array(clothlib.DEBUG_COLOURS[k % len(clothlib.DEBUG_COLOURS)]) * pn["cw"][:, None]
    colors[hair_mask] = (0.15, 0.15, 0.15)
    rgba = np.concatenate([colors, np.ones((n_v, 1))], axis=1).astype(np.float32)
    attr = char.data.color_attributes.new("dbg", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", rgba.ravel())
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "VERTEX"
    scene.render.resolution_x, scene.render.resolution_y = 420, 520
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.92, 0.93, 0.95, 1)
    scene.world = world
    for bn, b in CLOTH.items():
        cu = bpy.data.curves.new(bn, "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = 0.008
        sp = cu.splines.new("POLY")
        sp.points.add(1)
        sp.points[0].co = (*b["head"], 1)
        sp.points[1].co = (*b["tail"], 1)
        ob = bpy.data.objects.new(bn, cu)
        scene.collection.objects.link(ob)
        mat = bpy.data.materials.new(bn)
        mat.diffuse_color = (0.0, 0.0, 0.0, 1)
        ob.data.materials.append(mat)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.4
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    xc0, yc0 = BODY["root"]["head"][0], BODY["root"]["head"][1]
    for view, (dx, dy) in (("front", (0, -6)), ("right", (6, 0)), ("back", (0, 6))):
        cam.location = (xc0 + dx, yc0 + dy, 0.95)
        cam.rotation_euler = (Vector((xc0, yc0, 0.95)) - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(preview_dir / f"{lm['name']}_cloth_{view}.png")
        bpy.ops.render.render(write_still=True)
    log("debug pictures written")
    sys.exit(0)

# ---------------------------------------------------------------- 5. retarget the clips

rest_t = {n: tgt.data.bones[n].matrix_local.copy() for n in ALL}
rest_rel = {n: (rest_t[ALL[n]["parent"]].inverted() @ rest_t[n]) if ALL[n]["parent"] else None for n in ALL}

# straightened bones: pose the animation from a straight leg (hip to ankle) while the mesh stays bound to the real, bent one
q_base = {n: rest_t[n].to_quaternion() for n in ORDER}
for side in ("L", "R"):
    hip = Vector(BODY[f"DEF-thigh.{side}"]["head"])
    ankle = Vector(BODY[f"DEF-foot.{side}"]["head"])
    straight = (ankle - hip).normalized()
    for n in (f"DEF-thigh.{side}", f"DEF-shin.{side}"):
        if n in lm.get("straighten", []):
            bind_dir = (Vector(BODY[n]["tail"]) - Vector(BODY[n]["head"])).normalized()
            q_base[n] = bind_dir.rotation_difference(straight) @ q_base[n]
# arms: a mesh with its arms out (an A-pose from the reference picture) is posed from hanging arms, so the idle and run clips do not leave the arms sticking out
if lm.get("hang_arms") is not None:
    _out = math.radians(float(lm["hang_arms"]))
    for side, sgn in (("L", 1), ("R", -1)):
        _hf = math.radians(float((lm.get("hang_fwd") or [0, 0])[0 if side == "L" else 1]))        # a hanging arm may keep part of its forward swing
        _down = Vector((sgn * math.sin(_out), -math.sin(_hf), -math.cos(_out))).normalized()
        for n in (f"DEF-upper_arm.{side}", f"DEF-forearm.{side}", f"DEF-hand.{side}"):
            _bind = (Vector(BODY[n]["tail"]) - Vector(BODY[n]["head"])).normalized()
            q_base[n] = _bind.rotation_difference(_down) @ q_base[n]
HIP_SCALE = Vector(BODY["DEF-hips"]["head"]).z / src.data.bones["DEF-hips"].head_local.z

play(src, bpy.data.actions[REF_CLIP], 0)
ref_q = {n: src.pose.bones[n].matrix.to_quaternion() for n in ORDER}
ref_hips_t = src.pose.bones["DEF-hips"].matrix.translation.copy()


def body_pose(act, f, rig=None):
    """Armature-space matrices of the character's body bones for clip frame f (rig = the library skeleton playing the clip)."""
    rig = rig or src
    names = UAL2_MAP if rig is src2 else {n: n for n in ORDER}
    play(rig, act, f)
    posed = {}
    for n in ORDER:
        ms = rig.pose.bones[names[n]].matrix
        q = (ms.to_quaternion() @ ref_q[n].inverted()) @ q_base[n]
        parent = BODY[n]["parent"]
        if parent is None:
            m = rest_t[n].copy()
        else:
            head = (posed[parent] @ rest_rel[n]).translation
            if n == "DEF-hips":
                head = Vector(BODY[n]["head"]) + (ms.translation - ref_hips_t) * HIP_SCALE
            m = Matrix.Translation(head) @ q.to_matrix().to_4x4()
        posed[n] = m
    return posed


# hair chains: the strands are grouped by the name before the last underscore, parents first
CHAINS = {}
for n in HAIR_ORDER:
    CHAINS.setdefault(n.rsplit("_", 1)[0], []).append(n)
HAIR_LEN = {n: (Vector(ALL[n]["tail"]) - Vector(ALL[n]["head"])).length for n in HAIR_ORDER}
HAIR_STIFF, HAIR_DAMP, HAIR_GRAVITY = 0.22, 0.86, 0.0006


def simulate_hair(body_by_frame, frames):
    """Verlet strands pinned to the head, pulled back toward their resting shape, with a light breeze.
    Run twice over the clip so looping clips start where they end; returns {frame: {hair_bone: matrix}}."""
    out = {}
    head_rest_inv = rest_t["DEF-head"].inverted()
    for ci, (chain, bones) in enumerate(CHAINS.items()):
        state = None
        for pass_no in (0, 1):
            for f in frames:
                m_head = body_by_frame[f]["DEF-head"]
                rigid = [m_head @ (head_rest_inv @ rest_t[b]) for b in bones]     # the strand if the hair were stiff
                pts_r = [mm.translation.copy() for mm in rigid]
                pts_r.append((rigid[-1] @ Vector((0, HAIR_LEN[bones[-1]], 0))).copy())
                if state is None:
                    state = ([p.copy() for p in pts_r], [p.copy() for p in pts_r])
                P, Pp = state
                t = f / FPS
                breeze = Vector((0.0035 * math.sin(2.1 * t + ci), 0.0025 * math.sin(1.7 * t + 1.3 * ci + 0.6), 0.0))
                P[0] = pts_r[0].copy()
                for j in range(1, len(P)):
                    vel = (P[j] - Pp[j]) * HAIR_DAMP
                    Pp[j] = P[j].copy()
                    P[j] = P[j] + vel + (pts_r[j] - P[j]) * HAIR_STIFF + Vector((0, 0, -HAIR_GRAVITY)) + breeze * (j / len(P))
                for j in range(1, len(P)):
                    d = P[j] - P[j - 1]
                    P[j] = P[j - 1] + d.normalized() * HAIR_LEN[bones[j - 1]]
                if pass_no == 1:
                    for i, b in enumerate(bones):
                        d_now = (P[i + 1] - P[i]).normalized()
                        d_rigid = (rigid[i].to_3x3() @ Vector((0, 1, 0))).normalized()
                        q = d_rigid.rotation_difference(d_now) @ rigid[i].to_quaternion()
                        out.setdefault(f, {})[b] = Matrix.Translation(P[i]) @ q.to_matrix().to_4x4()
    return out


tgt.animation_data_create()
tgt_actions = {}
ALL_CLIPS = {k: (v, src) for k, v in CLIPS.items()}
if src2 is not None:
    ALL_CLIPS.update({k: (v, src2) for k, v in EXTRA_CLIPS.items()})
for game_name, (clip, rig) in ALL_CLIPS.items():
    act = bpy.data.actions.get(clip)
    if act is None:
        log("missing clip", clip)
        continue
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    frames = list(range(f0, f1 + 1))
    body = {f: body_pose(act, f, rig) for f in frames}
    hair = simulate_hair(body, frames) if HAIR else {}
    cloth_out = {}
    for pn in panels:
        for f_, bd in clothlib.simulate(pn, rest_t, body, frames, FPS).items():
            for bn, (pos, d_rigid, d_now, rot3) in bd.items():
                q_rigid = Matrix(rot3.tolist()).to_quaternion()
                q = Vector(d_rigid.tolist()).rotation_difference(Vector(d_now.tolist())) @ q_rigid
                cloth_out.setdefault(f_, {})[bn] = Matrix.Translation(Vector(pos.tolist())) @ q.to_matrix().to_4x4()
    new_act = bpy.data.actions.new(game_name)
    tgt.animation_data.action = new_act
    for f in frames:
        posed = {**body[f], **hair.get(f, {}), **cloth_out.get(f, {})}
        for n in ALL:
            pb = tgt.pose.bones[n]
            parent = ALL[n]["parent"]
            base = posed[parent] @ rest_rel[n] if parent else rest_t[n]
            loc, rot, _ = (base.inverted() @ posed[n]).decompose()
            pb.rotation_mode = "QUATERNION"
            pb.location = loc
            pb.rotation_quaternion = rot
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_quaternion", frame=f)
    new_act.use_fake_user = True
    tgt_actions[game_name] = (new_act, f0, f1)
    log("clip", game_name, "from", clip, f0, f1)

# ---------------------------------------------------------------- 6. preview pictures

bpy.data.objects.remove(src, do_unlink=True)
if src2 is not None:
    bpy.data.objects.remove(src2, do_unlink=True)
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "TEXTURE"
scene.render.resolution_x, scene.render.resolution_y = 480, 600
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.92, 0.93, 0.95, 1)
scene.world = world
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = 2.6
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
cam.location = Vector((2.4, -4.2, 1.0))
cam.rotation_euler = (Vector((0, 0, 0.95)) - cam.location).to_track_quat("-Z", "Y").to_euler()
PREVIEW = (("Idle", (0, 30)), ("Run", (0, 5, 11, 16)), ("Sprint", (0, 8)), ("CastShoot", (0, 5, 11)), ("Attack", (0, 10, 20, 30)), ("JumpLoop", (30,)), ("Death", (0, 20, 40, 57)))
for clip, frames in PREVIEW:
    if clip not in tgt_actions:
        continue
    act, f0, f1 = tgt_actions[clip]
    for f in frames:
        f = min(max(f, f0), f1)
        tgt.animation_data.action = act
        if hasattr(tgt.animation_data, "action_slot") and act.slots:
            tgt.animation_data.action_slot = act.slots[0]
        scene.frame_set(f)
        scene.render.filepath = str(preview_dir / f"{lm['name']}_{clip}_{f:03d}.png")
        bpy.ops.render.render(write_still=True)

# ---------------------------------------------------------------- 7. export

bpy.data.objects.remove(cam, do_unlink=True)
keep = {a for a, _, _ in tgt_actions.values()}
for a in list(bpy.data.actions):                     # drop the library clips so only the character's own clips are exported
    if a not in keep:
        bpy.data.actions.remove(a)
for game_name, (a, _f0, _f1) in tgt_actions.items():     # a library clip with the same name may have forced a .001 suffix
    a.name = game_name
bpy.ops.object.select_all(action="DESELECT")
char.select_set(True)
tgt.select_set(True)
kwargs = dict(filepath=str(out_glb), export_format="GLB", use_selection=True, export_animations=True)
try:
    bpy.ops.export_scene.gltf(**kwargs, export_animation_mode="ACTIONS", export_image_format="JPEG")
except TypeError:
    bpy.ops.export_scene.gltf(**kwargs)
log("exported", out_glb.name, round(out_glb.stat().st_size / 1e6, 2), "MB,", len(tgt_actions), "clips")
