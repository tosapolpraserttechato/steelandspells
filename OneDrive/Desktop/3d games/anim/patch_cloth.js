// One-off patch: wire anim/cloth.py into anim/rig_character.py (kept for the record; the result lives in rig_character.py).
const fs = require('fs');
const root = __dirname;

// 1. cloth.py: robust arc ordering
let c = fs.readFileSync(`${root}/cloth.py`, 'utf8');
const s0 = c.indexOf('    else:\n        centres = np.linspace(a0, a1, n)');
const s1 = c.indexOf('    s = W.sum(1, keepdims=True)');
if (s0 < 0 || s1 < 0) throw new Error('cloth.py anchors missing');
c = c.slice(0, s0) + `    else:
        lo, hi = min(a0, a1), max(a0, a1)
        centres = np.linspace(lo, hi, n)
        step = centres[1] - centres[0]
        for i, cc in enumerate(centres):
            W[:, i] = np.clip(1.0 - np.abs(theta - cc) / step, 0.0, 1.0)
        W[theta <= centres[0], 0] = 1.0
        W[theta >= centres[-1], n - 1] = 1.0
` + c.slice(s1);
fs.writeFileSync(`${root}/cloth.py`, c);

// 2. rig_character.py
let t = fs.readFileSync(`${root}/rig_character.py`, 'utf8');
const rep = (a, b) => {
  if (!t.includes(a)) throw new Error('MISSING: ' + a.slice(0, 90));
  t = t.replace(a, () => b);
};

rep(`argv = sys.argv[sys.argv.index("--") + 1:]
char_glb, ual_glb, lm_path, out_glb, preview_dir = (Path(a).resolve() for a in argv[:5])
ual2_glb = Path(argv[5]).resolve() if len(argv) > 5 else None`,
`argv = sys.argv[sys.argv.index("--") + 1:]
DEBUG = "--debug" in argv                 # only show which vertices each cloth panel claims, then stop
argv = [a for a in argv if not a.startswith("--")]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import cloth as clothlib  # noqa: E402

char_glb, ual_glb, lm_path, out_glb, preview_dir = (Path(a).resolve() for a in argv[:5])
ual2_glb = Path(argv[5]).resolve() if len(argv) > 5 else None`);

// move the hair mask function and the radii above the skeleton
const hs = t.indexOf('def hair_vertex_mask(obj, rule):');
const he = t.indexOf('RADII = {"DEF-hips"');
const hairFn = t.slice(hs, he);
t = t.slice(0, hs) + t.slice(he);
const rs = t.indexOf('RADII = {"DEF-hips"');
const re = t.indexOf('SMOOTH_STEPS = 45');
const radii = t.slice(rs, re);
t = t.slice(0, rs) + t.slice(re);
rep(`hips_z = BODY["DEF-hips"]["head"][2]\nHAIR_SOFT`, 'HAIR_SOFT');

rep(`BODY = lm["bones"]
HAIR = lm.get("hair_bones", {})
ALL = {**BODY, **HAIR}
`, `BODY = lm["bones"]
HAIR = lm.get("hair_bones", {})
HAIR_ORDER = list(HAIR.keys())


${hairFn}${radii}hips_z = BODY["DEF-hips"]["head"][2]
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
`);

rep(`ORDER = list(BODY.keys())                            # parents come before children in the landmarks file
HAIR_ORDER = list(HAIR.keys())
`, `ORDER = list(BODY.keys())                            # parents come before children in the landmarks file
`);

rep(`        d = np.linalg.norm(P - (a + tt[:, None] * ab), axis=1) / RADII[n]
        if n in HAIR:`, `        d = np.linalg.norm(P - (a + tt[:, None] * ab), axis=1) / RADII[n]
        if n in CLOTH:
            d = np.full(len(P), 1e6)                                  # cloth chains are weighted by their panel below
        elif n in HAIR:`);

rep(`    keep = np.argsort(-W, axis=1)[:, :4]`, `    for _pn in panels:                                            # cloth panels take over the vertices that belong to them
        W = clothlib.apply_weights(W, names, P, _pn)
    keep = np.argsort(-W, axis=1)[:, :4]`);

rep(`hair_mask = hair_vertex_mask(char, lm["hair_rule"]) if HAIR else np.zeros(len(char.data.vertices), dtype=bool)
weights = skin_mesh(char, [n for n in ORDER if n != "root"] + HAIR_ORDER, ALL, hair_mask)`,
`weights = skin_mesh(char, [n for n in ORDER if n != "root"] + HAIR_ORDER + CLOTH_ORDER, ALL, hair_mask)`);

rep(`# ---------------------------------------------------------------- 5. retarget the clips`, `if DEBUG:
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

# ---------------------------------------------------------------- 5. retarget the clips`);

rep(`    hair = simulate_hair(body, frames) if HAIR else {}
`, `    hair = simulate_hair(body, frames) if HAIR else {}
    cloth_out = {}
    for pn in panels:
        for f_, bd in clothlib.simulate(pn, rest_t, body, frames, FPS).items():
            for bn, (pos, d_rigid, d_now, rot3) in bd.items():
                q_rigid = Matrix(rot3.tolist()).to_quaternion()
                q = Vector(d_rigid.tolist()).rotation_difference(Vector(d_now.tolist())) @ q_rigid
                cloth_out.setdefault(f_, {})[bn] = Matrix.Translation(Vector(pos.tolist())) @ q.to_matrix().to_4x4()
`);
rep(`        posed = {**body[f], **hair.get(f, {})}`, `        posed = {**body[f], **hair.get(f, {}), **cloth_out.get(f, {})}`);

fs.writeFileSync(`${root}/rig_character.py`, t);
console.log('patched; lines', t.split('\n').length);
