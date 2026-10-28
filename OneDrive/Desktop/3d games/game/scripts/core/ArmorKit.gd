class_name ArmorKit
extends RefCounted
## Builds the armor a fighter wears and fastens it to the skeleton: each piece sits in the local space of a bone (BoneAttachment3D), so it moves with the animation.
## Sizes come from ArmorFit (the real chest, limbs and skull of that class model, plus a margin) so the metal stands clear of the body instead of cutting into it.
## A look (Data.armor_looks[set id]) picks a style (plate, leather, robe, bone, crystal...), the colours and the shapes of the helmet, shoulders, skirt and shield.
## Wearing all five pieces of a set ("complete") makes it better: glowing trim and runes, a taller crest, a mantle, spikes, floating sparks, a brighter metal.

const SLOTS := ["helmet", "chestplate", "shield", "leggings", "boots"]
const STYLE := {
	"plate": {"metal": 0.85, "rough": 0.35, "plates": "segment", "shoulder": "layered", "helm": "visor", "skirt": "tassets", "shield": "kite", "sleeve": "bracer"},
	"leather": {"metal": 0.05, "rough": 0.85, "plates": "smooth", "shoulder": "pad", "helm": "hood", "skirt": "tabard", "shield": "round", "sleeve": "bracer"},
	"chain": {"metal": 0.7, "rough": 0.5, "plates": "ridged", "shoulder": "dome", "helm": "dome", "skirt": "tassets", "shield": "round", "sleeve": "bracer"},
	"scale": {"metal": 0.6, "rough": 0.45, "plates": "ridged", "shoulder": "layered", "helm": "crest", "skirt": "tassets", "shield": "kite", "sleeve": "bracer"},
	"robe": {"metal": 0.0, "rough": 0.9, "plates": "smooth", "shoulder": "pad", "helm": "hat", "skirt": "robe", "shield": "ward", "sleeve": "wide"},
	"bone": {"metal": 0.1, "rough": 0.8, "plates": "segment", "shoulder": "skull", "helm": "skull", "skirt": "tabard", "shield": "round", "sleeve": "bracer"},
	"crystal": {"metal": 0.3, "rough": 0.25, "plates": "ridged", "shoulder": "crystal", "helm": "crown", "skirt": "tassets", "shield": "ward", "sleeve": "bracer"},
	"organic": {"metal": 0.0, "rough": 0.9, "plates": "ridged", "shoulder": "leaf", "helm": "horned", "skirt": "tabard", "shield": "round", "sleeve": "bracer"},
	"mech": {"metal": 0.8, "rough": 0.4, "plates": "segment", "shoulder": "gear", "helm": "visor", "skirt": "tassets", "shield": "round", "sleeve": "bracer"},
	"royal": {"metal": 0.8, "rough": 0.3, "plates": "smooth", "shoulder": "wing", "helm": "crown", "skirt": "tabard", "shield": "kite", "sleeve": "bracer"},
	"ice": {"metal": 0.1, "rough": 0.15, "plates": "ridged", "shoulder": "spike", "helm": "crown", "skirt": "tassets", "shield": "kite", "sleeve": "bracer"},
	"flame": {"metal": 0.6, "rough": 0.4, "plates": "segment", "shoulder": "spike", "helm": "horned", "skirt": "tassets", "shield": "kite", "sleeve": "bracer"},
	"storm": {"metal": 0.7, "rough": 0.35, "plates": "segment", "shoulder": "wing", "helm": "crest", "skirt": "tassets", "shield": "kite", "sleeve": "bracer"},
	"moon": {"metal": 0.6, "rough": 0.3, "plates": "smooth", "shoulder": "dome", "helm": "circlet", "skirt": "robe", "shield": "ward", "sleeve": "wide"},
	"ocean": {"metal": 0.3, "rough": 0.35, "plates": "ridged", "shoulder": "dome", "helm": "horned", "skirt": "tabard", "shield": "round", "sleeve": "bracer"},
	"desert": {"metal": 0.5, "rough": 0.6, "plates": "smooth", "shoulder": "pad", "helm": "crest", "skirt": "tabard", "shield": "round", "sleeve": "bracer"},
}

var model: CharacterModel
var sk: Skeleton3D
var fit: Dictionary = {}
var groups: Dictionary = {}                   # bone name -> MeshKit
var look: Dictionary = {}
var complete := false
var class_id := ""
var model_nodes: Array = []                    # BoneAttachment3Ds of pieces that are Hunyuan models
var rng := RandomNumberGenerator.new()


## `pieces` maps each worn slot to the id of its set; `complete_set` is the set id of which all five pieces are worn ("" if none); `skins` maps a slot to the name of the skin
## of that (brand-new) piece. Returns the nodes that were added (the model frees them the next time it is dressed).
static func dress(m: CharacterModel, pieces: Dictionary, complete_set: String, skins: Dictionary = {}, worn: Dictionary = {}) -> Array:
	var nodes: Array = []
	if m.skeleton == null or pieces.is_empty():
		return nodes
	var fit := ArmorFit.measure(m.class_id, m.skeleton, m.meshes)
	if fit.is_empty() or not fit.has("limbs"):
		return nodes
	# one builder per (set, skin): its pieces share the colours; a piece with another skin gets its own colours
	var groups: Dictionary = {}
	for slot in pieces:
		var key := "%s|%s|%s" % [pieces[slot], skins.get(slot, ""), worn.get(slot, false)]
		if not groups.has(key):
			groups[key] = {"set": String(pieces[slot]), "skin": String(skins.get(slot, "")), "worn": bool(worn.get(slot, false)), "slots": []}
		groups[key]["slots"].append(slot)
	var extras_done := false
	for key in groups:
		var g: Dictionary = groups[key]
		var k := ArmorKit.new()
		k.model = m
		k.sk = m.skeleton
		k.fit = fit
		k.look = resolve(String(g["set"]), m.class_id, String(g["skin"]), bool(g["worn"]))
		k.class_id = m.class_id
		k.complete = (String(g["set"]) == complete_set) and not bool(g["worn"])
		k.rng.seed = int(k.look.get("seed", 1)) * 7919
		for slot in g["slots"]:
			match String(slot):
				"helmet": k.build_helmet()
				"chestplate": k.build_chest()
				"shield": k.build_shield()
				"leggings": k.build_legs()
				"boots": k.build_boots()
		if k.complete and not extras_done:
			extras_done = true
			k.build_complete_extras()
			var aura := k.make_aura()
			if aura != null:
				m.add_child(aura)
				nodes.append(aura)
		nodes.append_array(k.model_nodes)
		for bone in k.groups:
			var kit: MeshKit = k.groups[bone]
			if kit.is_empty():
				continue
			var att := BoneAttachment3D.new()
			att.bone_name = bone
			m.skeleton.add_child(att)
			kit.commit(att, 60.0)
			nodes.append(att)
	return nodes


## The look of a set with the style's defaults filled in, colours as Color. The class leans the colours towards its own theme colour (so a Frost Mage in plate is still icy),
## and a skin of a brand-new piece replaces the palette.
static func resolve(set_id: String, cls: String = "", skin_name: String = "", worn: bool = false) -> Dictionary:
	var raw: Dictionary = Data.armor_looks.get(set_id, {})
	var style: String = raw.get("style", "plate")
	var out: Dictionary = (STYLE.get(style, STYLE["plate"]) as Dictionary).duplicate()
	for k in raw:
		out[k] = raw[k]
	out["style"] = style
	out["set_id"] = set_id
	for c in ["c1", "c2", "glow"]:
		var v: Variant = out.get(c, "")
		out[c] = Color.html(String(v)) if typeof(v) == TYPE_STRING and String(v) != "" else (Color(0.6, 0.6, 0.65) if c == "c1" else (Color(0.9, 0.75, 0.3) if c == "c2" else Color(1, 0.85, 0.5)))
	out["rar"] = Data.rarity_index(String(Data.armor_sets.get(set_id, {}).get("rarity", "common")))
	if not out.has("seed"):
		out["seed"] = absi(set_id.hash()) % 1000
	var skin := Data.skin_def(skin_name, "armor")
	if not skin.is_empty():
		out["c1"] = Color.html(String(skin["armor_c1"]))
		out["c2"] = Color.html(String(skin["armor_c2"]))
		out["glow"] = Color.html(String(skin["armor_glow"]))
	if FLAIR.has(cls):
		var accent := Color.html(String(FLAIR[cls]["accent"]))
		out["c2"] = (out["c2"] as Color).lerp(accent, 0.3)
		out["glow"] = (out["glow"] as Color).lerp(accent, 0.55)
		out["c1"] = (out["c1"] as Color).lerp(accent, 0.07)
	if worn:                                                  # an old, worn piece: dull, rusty, brown, no glow
		out["c1"] = (out["c1"] as Color).darkened(0.18).lerp(Color(0.36, 0.22, 0.12), 0.45)
		out["c2"] = (out["c2"] as Color).darkened(0.25).lerp(Color(0.5, 0.3, 0.14), 0.55)
		out["glow"] = (out["glow"] as Color).darkened(0.4)
		out["metal"] = float(out["metal"]) * 0.3
		out["rough"] = 0.95
		out["worn"] = true
	return out


# ------------------------------------------------------------------ helpers

func _kit(bone: String) -> MeshKit:
	if groups.has(bone):
		return groups[bone]
	var kit := MeshKit.new()
	var bi := sk.find_bone(bone)
	if bi >= 0:
		kit.xf = sk.get_bone_global_rest(bi).affine_inverse()
	var metal: float = look["metal"] + (0.1 if complete else 0.0)
	var rough: float = look["rough"]
	var c1: Color = look["c1"]
	var c2: Color = look["c2"]
	var g: Color = look["glow"]
	if complete:
		c1 = c1.lightened(0.08)
		c2 = c2.lightened(0.12)
	kit.material("p", c1, rough, clampf(metal, 0.0, 0.5))
	kit.material("t", c2, maxf(rough - 0.1, 0.15), clampf(metal + 0.1, 0.0, 0.55))
	kit.material("d", c1.darkened(0.5), 0.8, clampf(metal * 0.5, 0.0, 0.9))
	kit.material("g", g, 0.3, 0.0, 0.15 if look.get("worn", false) else (1.6 if complete else 0.7) + 0.2 * float(look["rar"]))
	kit.material("c", c1.lerp(c2, 0.25), 0.95, 0.0)
	groups[bone] = kit
	return kit


func _margin(r: float) -> float:
	return r * 1.08 + 0.012


func _side_sign(side: String) -> float:
	return 1.0 if side == "L" else -1.0


# ------------------------------------------------------------------ helmet

func build_helmet() -> void:
	if _model_piece("helmet"):
		return
	var h: Dictionary = fit["head"]
	var kit := _kit("DEF-head")
	var c: Vector3 = h["c"]
	var r: Vector3 = h["r"]
	var base: float = h["base"]
	var top: float = h["top"]
	var shape := String(look["helm"])
	var rx := r.x + 0.03
	var rz := r.z + 0.03
	var brow := base + 0.1
	var ry := (top - base) * 0.5 + 0.03
	var cy := base + ry - 0.01
	var shell := func(y0: float, y1: float, grow: float, key: String) -> void:
		var rings: Array = []
		var n := 8
		for i in n + 1:
			var y := lerpf(y0, y1, float(i) / float(n))
			var t := clampf((y - cy) / ry, -1.0, 1.0)
			var k := sqrt(maxf(1.0 - t * t, 0.0))
			rings.append(MeshKit.ring(c.x, y, c.z, (rx + grow) * maxf(k, 0.03), (rz + grow) * maxf(k, 0.03), (rz + grow) * maxf(k, 0.03), 16))
		kit.loft(key, rings, true, false)
	var sx := 1.0
	match shape:
		"dome":
			shell.call(brow, top + 0.03, 0.0, "p")
			kit.loft("t", [MeshKit.ring(c.x, brow, c.z, rx + 0.012, rz + 0.012, rz + 0.012, 16), MeshKit.ring(c.x, brow + 0.025, c.z, rx + 0.008, rz + 0.008, rz + 0.008, 16)])
		"visor":
			shell.call(base - 0.03, top + 0.03, 0.005, "p")
			kit.box("g", Vector3(rx * 1.5, 0.022, 0.02), Vector3(c.x, base + 0.12, c.z + rz * 0.88))          # the eye slit
			kit.box("t", Vector3(0.02, ry * 1.1, 0.02), Vector3(c.x, base + ry, c.z + rz * 0.97))              # the nasal ridge
		"hood":
			shell.call(base + 0.0, top + 0.04, 0.02, "c")
			kit.tube("c", Vector3(c.x, top - 0.02, c.z - rz * 0.4), Vector3(c.x, top - 0.12, c.z - rz * 1.9), rz * 0.65, 0.01, 10)   # the cowl points backwards
			kit.loft("d", [MeshKit.ring(c.x, base + 0.07, c.z + 0.01, rx + 0.03, rz + 0.04, rz + 0.03, 16), MeshKit.ring(c.x, base + 0.1, c.z + 0.01, rx + 0.032, rz + 0.042, rz + 0.032, 16)])
		"crown":
			kit.loft("t", [MeshKit.ring(c.x, brow, c.z, rx + 0.012, rz + 0.012, rz + 0.012, 16), MeshKit.ring(c.x, brow + 0.045, c.z, rx + 0.012, rz + 0.012, rz + 0.012, 16)], false, false)
			var spikes := 5 + int(look["seed"]) % 3
			for i in spikes:
				var a := TAU * float(i) / float(spikes)
				var p := Vector3(c.x + cos(a) * (rx + 0.012), brow + 0.045, c.z + sin(a) * (rz + 0.012))
				kit.tube("t", p, p + Vector3(0, 0.08 + 0.03 * float(i % 2) + (0.06 if complete else 0.0), 0), 0.014, 0.002, 5)
			kit.ball("g", 0.016, Vector3(c.x, brow + 0.025, c.z + rz + 0.016))
		"horned":
			shell.call(brow, top + 0.03, 0.0, "p")
			for s in [-1.0, 1.0]:
				var root := Vector3(c.x + s * (rx - 0.01), brow + 0.07, c.z)
				var mid := root + Vector3(s * 0.09, 0.07, -0.01)
				var tip := mid + Vector3(s * 0.04, 0.1 + (0.05 if complete else 0.0), 0.03)
				kit.tube("t", root, mid, 0.026, 0.018, 6)
				kit.tube("t", mid, tip, 0.018, 0.003, 6)
		"circlet":
			kit.loft("t", [MeshKit.ring(c.x, brow + 0.02, c.z, rx + 0.006, rz + 0.006, rz + 0.006, 18), MeshKit.ring(c.x, brow + 0.04, c.z, rx + 0.006, rz + 0.006, rz + 0.006, 18)])
			kit.ball("g", 0.022, Vector3(c.x, brow + 0.045, c.z + rz + 0.012))
			kit.tube("t", Vector3(c.x, brow + 0.045, c.z + rz + 0.012), Vector3(c.x, brow + 0.11 + (0.05 if complete else 0.0), c.z + rz + 0.0), 0.012, 0.002, 5)
		"hat":
			kit.cyl("c", rx * 2.0, rx * 2.0, 0.012, Vector3(c.x, brow + 0.02, c.z), Basis(), 18)                 # a wide brim
			kit.tube("c", Vector3(c.x, brow + 0.02, c.z), Vector3(c.x, brow + 0.34 + (0.08 if complete else 0.0), c.z - 0.06), rx * 1.05, 0.012, 14)
			kit.cyl("t", rx * 1.07, rx * 1.07, 0.03, Vector3(c.x, brow + 0.045, c.z), Basis(), 14)
			kit.ball("g", 0.02, Vector3(c.x, brow + 0.045, c.z + rx * 1.06))
		"skull":
			shell.call(brow, top + 0.03, 0.0, "p")
			kit.ball("p", 0.075, Vector3(c.x, brow + 0.06, c.z + rz + 0.05), Vector3(1.0, 0.9, 0.8))               # a skull above the brow
			for s in [-1.0, 1.0]:
				kit.ball("g", 0.016, Vector3(c.x + s * 0.03, brow + 0.07, c.z + rz + 0.105))
				kit.tube("p", Vector3(c.x + s * (rx + 0.01), brow + 0.05, c.z), Vector3(c.x + s * (rx + 0.1), brow + 0.2, c.z - 0.05), 0.02, 0.004, 5)
		"crest":
			shell.call(brow - 0.02, top + 0.03, 0.0, "p")
			var fin := 0.1 + (0.07 if complete else 0.0) + 0.012 * float(look["seed"] % 4)
			for i in 6:                                       # a fin of plumes along the top, back to front
				var z := c.z + lerpf(-rz * 0.9, rz * 0.7, float(i) / 5.0)
				kit.tube("t", Vector3(c.x, top + 0.01, z), Vector3(c.x, top + 0.01 + fin * (1.0 - absf(float(i) - 2.5) / 4.0), z - 0.04), 0.016, 0.004, 5)
	_flair_helm(kit, c, rx, rz, brow, top, base)
	# a plume or halo that only the complete set has
	if complete and shape != "hat":
		kit.loft("g", [MeshKit.ring(c.x, top + 0.12, c.z, 0.13, 0.13, 0.13, 20), MeshKit.ring(c.x, top + 0.125, c.z, 0.145, 0.145, 0.145, 20)])


# ------------------------------------------------------------------ chest

## The torso measurements interpolated to height y.
func _band_at(y: float) -> Dictionary:
	var bands: Array = fit["torso"]
	if bands.is_empty():
		var hp: Vector3 = fit["hips"]
		return {"y": y, "cx": hp.x, "cz": hp.z, "rx": 0.16, "rz": 0.11}
	if y <= float(bands[0]["y"]):
		return bands[0]
	for i in bands.size() - 1:
		var a: Dictionary = bands[i]
		var b: Dictionary = bands[i + 1]
		if y <= float(b["y"]):
			var t := (y - float(a["y"])) / maxf(float(b["y"]) - float(a["y"]), 0.001)
			return {"y": y, "cx": lerpf(a["cx"], b["cx"], t), "cz": lerpf(a["cz"], b["cz"], t), "rx": lerpf(a["rx"], b["rx"], t), "rz": lerpf(a["rz"], b["rz"], t)}
	return bands[bands.size() - 1]


func _torso_rings(pad: float, y0: float, y1: float, bulge: float) -> Array:
	var rings: Array = []
	if (fit["torso"] as Array).is_empty():
		return rings
	var n := maxi(int((y1 - y0) / 0.035), 2)
	for i in n + 1:
		var y := lerpf(y0, y1, float(i) / float(n))
		var b := _band_at(y)
		var wob := bulge if i % 2 == 0 else 0.0
		rings.append(MeshKit.ring(b["cx"], y, b["cz"], float(b["rx"]) * 1.06 + pad + wob, float(b["rz"]) * 1.06 + pad + wob, float(b["rz"]) * 0.98 + pad + wob, 16))
	return rings


func build_chest() -> void:
	if _model_piece("chestplate"):
		return
	var bands: Array = fit["torso"]
	if bands.is_empty():
		return
	var hips: Vector3 = fit["hips"]
	var kit := _kit("DEF-spine.002")
	var top_y: float = (bands[bands.size() - 1] as Dictionary)["y"]
	var plates := String(look["plates"])
	var bulge := 0.012 if plates == "ridged" else 0.0
	var lo := hips.y + 0.1
	if plates == "segment":
		# three plates with a gap between them: abdomen, ribs, chest
		var span := top_y - lo
		for i in 3:
			var r := _torso_rings(0.018 + 0.006 * float(i), lo + span * float(i) / 3.0, lo + span * float(i + 1) / 3.0 + 0.02, 0.0)
			kit.loft("p", r, i == 2, i == 0)
	else:
		kit.loft("p", _torso_rings(0.02, lo, top_y, bulge), false, true)
	# a collar around the neck, a belt at the waist, a glowing emblem on the breast
	var neck := _torso_rings(0.03, top_y - 0.01, top_y + 0.01, 0.0)
	if neck.size() >= 1:
		var nb: Dictionary = bands[bands.size() - 1]
		var cr := 0.1 + (0.04 if String(look["style"]) in ["royal", "storm", "robe", "moon"] else 0.0)
		kit.loft("t", [MeshKit.ring(nb["cx"], top_y + 0.02, nb["cz"] - 0.01, cr, cr, cr, 14), MeshKit.ring(nb["cx"], top_y + 0.09 + (0.05 if complete else 0.0), nb["cz"] - 0.03, cr + 0.04, cr + 0.04, cr + 0.04, 14)])
	var waist := _torso_rings(0.034, lo - 0.02, lo + 0.05, 0.0)
	if waist.size() >= 2:
		kit.loft("t", waist)
	var mid: Dictionary = bands[bands.size() / 2]
	var front := float(mid["cz"]) + float(mid["rz"]) * 1.06 + 0.032
	var emblem_y := float(mid["y"]) + 0.1
	match int(look["seed"]) % 4:
		0: kit.ball("g", 0.034, Vector3(mid["cx"], emblem_y, front), Vector3(1, 1, 0.45))
		1: kit.box("g", Vector3(0.05, 0.08, 0.02), Vector3(mid["cx"], emblem_y, front), Basis(Vector3.BACK, PI * 0.25))
		2: kit.tube("g", Vector3(mid["cx"], emblem_y - 0.05, front), Vector3(mid["cx"], emblem_y + 0.06, front), 0.026, 0.004, 5)
		3: kit.cyl("g", 0.04, 0.04, 0.016, Vector3(mid["cx"], emblem_y, front), Basis(Vector3.RIGHT, PI * 0.5), 10)
	_pauldrons()
	_flair_back(bands[bands.size() - 1])
	_sleeves()
	if String(look["skirt"]) == "robe" or String(look["style"]) == "robe":
		var collar := _torso_rings(0.05, top_y - 0.04, top_y - 0.0, 0.0)
		if collar.size() >= 2:
			kit.loft("c", collar)


func _pauldrons() -> void:
	var shape := String(look["shoulder"])
	for side in ["L", "R"]:
		var s := _side_sign(side)
		var up: Dictionary = fit["limbs"].get("upper_arm.%s" % side, {})
		if up.is_empty():
			continue
		var a: Vector3 = up["a"]
		var r: float = (float(up["r"]) + 0.03) * 0.78
		var kit := _kit("DEF-shoulder.%s" % side)
		var c := a + Vector3(s * 0.01, 0.025, 0)
		match shape:
			"none":
				pass
			"pad":
				kit.ball("p", r * 1.5, c, Vector3(1.0, 0.55, 1.0))
			"dome":
				kit.ball("p", r * 1.85, c + Vector3(s * 0.02, 0, 0), Vector3(1.0, 0.65, 1.1))
				kit.ball("t", r * 0.5, c + Vector3(s * 0.1, 0.03, 0), Vector3(1.0, 0.5, 1.0))
			"layered":
				for i in 3:
					var k := 1.0 - 0.17 * float(i)
					kit.ball("p" if i % 2 == 0 else "t", r * 1.9 * k, c + Vector3(s * (0.03 + 0.012 * float(i)), 0.02 - 0.03 * float(i), 0), Vector3(1.0, 0.4, 1.05))
			"spike":
				kit.ball("p", r * 1.7, c, Vector3(1.0, 0.6, 1.05))
				var n := 3 + (2 if complete else 0)
				for i in n:
					var ang := PI * 0.15 + float(i) * PI * 0.6 / float(n)
					var base := c + Vector3(s * cos(ang) * r * 1.5, sin(ang) * r * 1.0, 0)
					kit.tube("t", base, base + Vector3(s * cos(ang) * 0.1, sin(ang) * 0.12, 0), 0.026, 0.004, 5)
			"skull":
				kit.ball("p", r * 1.6, c, Vector3(1.0, 0.6, 1.0))
				kit.ball("t", 0.05, c + Vector3(s * 0.05, 0.07, 0.03), Vector3(1.0, 0.9, 0.85))
				kit.ball("g", 0.011, c + Vector3(s * 0.04, 0.075, 0.075))
				kit.ball("g", 0.011, c + Vector3(s * 0.075, 0.075, 0.07))
			"crystal":
				kit.ball("p", r * 1.5, c, Vector3(1.0, 0.55, 1.0))
				for i in 3:
					var p := c + Vector3(s * (0.03 + 0.03 * float(i)), 0.04, (float(i) - 1.0) * 0.04)
					kit.tube("g", p, p + Vector3(s * 0.03 * float(i), 0.11 + 0.04 * float(i) + (0.06 if complete else 0.0), 0), 0.03, 0.003, 5)
			"wing":
				kit.ball("p", r * 1.5, c, Vector3(1.0, 0.55, 1.0))
				for i in 4:
					var l := 0.14 + 0.04 * float(i) + (0.05 if complete else 0.0)
					var p := c + Vector3(s * 0.04, 0.05 + 0.012 * float(i), -0.02 - 0.012 * float(i))
					kit.tube("t", p, p + Vector3(s * l, 0.04 + 0.03 * float(i), -0.02), 0.018, 0.004, 5)
			"leaf":
				kit.ball("c", r * 1.5, c, Vector3(1.0, 0.55, 1.0))
				for i in 4:
					var ang := float(i) * 0.5
					kit.ball("t", 0.04, c + Vector3(s * (0.05 + 0.04 * cos(ang)), 0.05 + 0.025 * float(i), (float(i) - 1.5) * 0.045), Vector3(0.5, 0.25, 1.2))
			"gear":
				kit.ball("p", r * 1.5, c, Vector3(1.0, 0.55, 1.0))
				kit.cyl("t", 0.07, 0.07, 0.03, c + Vector3(s * 0.06, 0.05, 0), Basis(Vector3.BACK, PI * 0.5), 10)
				kit.ball("g", 0.016, c + Vector3(s * 0.08, 0.05, 0))
			"horn":
				kit.ball("p", r * 1.5, c, Vector3(1.0, 0.55, 1.0))
				kit.tube("t", c + Vector3(s * 0.04, 0.03, 0), c + Vector3(s * 0.12, 0.17, 0), 0.04, 0.005, 6)


func _sleeves() -> void:
	var wide := String(look["sleeve"]) == "wide"
	for side in ["L", "R"]:
		var s := _side_sign(side)
		var fa: Dictionary = fit["limbs"].get("forearm.%s" % side, {})
		var ua: Dictionary = fit["limbs"].get("upper_arm.%s" % side, {})
		if fa.is_empty():
			continue
		var a: Vector3 = fa["a"]
		var b: Vector3 = fa["b"]
		var r := _margin(float(fa["r"]))
		var kit := _kit("DEF-forearm.%s" % side)
		var p0 := a.lerp(b, 0.0)
		var p1 := a.lerp(b, 0.97)
		if wide:
			kit.tube("c", p0, p1 + Vector3(0, -0.05, 0), r * 1.1, r * 2.4, 10)                     # a long hanging sleeve
			kit.tube("t", p1 + Vector3(0, -0.05, 0), p1 + Vector3(0, -0.075, 0), r * 2.4, r * 2.45, 10)
		else:
			kit.tube("p", p0, p1, r, r * 1.08, 10)
			kit.tube("t", p0, a.lerp(b, 0.1), r * 1.1, r * 1.1, 10)
			kit.tube("t", a.lerp(b, 0.86), p1, r * 1.1, r * 1.1, 10)
		if not ua.is_empty():
			var kit2 := _kit("DEF-upper_arm.%s" % side)
			var ua_a: Vector3 = ua["a"]
			var ua_b: Vector3 = ua["b"]
			var cloth_style: bool = wide or String(look["style"]) in ["robe", "leather", "organic", "desert", "moon", "ocean"]
			kit2.tube("c" if cloth_style else "p", ua_a.lerp(ua_b, 0.0), ua_a.lerp(ua_b, 1.0), _margin(float(ua["r"])) * 1.12, _margin(float(ua["r"])) * (1.5 if wide else 1.1), 10)


# ------------------------------------------------------------------ legs

func build_legs() -> void:
	if _model_piece("leggings"):
		return
	var hips: Vector3 = fit["hips"]
	var skirt := String(look["skirt"])
	var kit := _kit("DEF-hips")
	var bands: Array = fit["torso"]
	var waist_rx := 0.17
	var waist_rz := 0.12
	if not bands.is_empty():
		var b0: Dictionary = bands[0]
		waist_rx = float(b0["rx"]) * 1.0 + 0.03
		waist_rz = float(b0["rz"]) * 1.02 + 0.03
	var wy := hips.y + 0.1
	kit.loft("t", [MeshKit.ring(hips.x, wy - 0.05, hips.z, waist_rx, waist_rz, waist_rz * 0.95, 16), MeshKit.ring(hips.x, wy + 0.03, hips.z, waist_rx, waist_rz, waist_rz * 0.95, 16)])
	kit.ball("g", 0.025, Vector3(hips.x, wy - 0.01, hips.z + waist_rz + 0.012))
	# the pelvis: a shell from the crotch to the waist, so the hips need no clothes of their own
	var pelvis: Array = []
	for i in 5:
		var py := lerpf(hips.y - 0.15, wy - 0.04, float(i) / 4.0)
		var bd := _band_at(hips.y - 0.04)
		var sq := lerpf(0.78, 1.0, float(i) / 4.0)
		pelvis.append(MeshKit.ring(float(bd["cx"]), py, float(bd["cz"]), float(bd["rx"]) * 0.98 * sq + 0.02, float(bd["rz"]) * 1.05 + 0.02, float(bd["rz"]) * 0.98 + 0.02, 16))
	kit.loft("c" if skirt == "robe" else "p", pelvis, false, true)
	_flair_belt(kit, hips, wy, waist_rx, waist_rz)
	for side in ["L", "R"]:
		var s := _side_sign(side)
		var th: Dictionary = fit["limbs"].get("thigh.%s" % side, {})
		var sh: Dictionary = fit["limbs"].get("shin.%s" % side, {})
		if th.is_empty() or sh.is_empty():
			continue
		var ta: Vector3 = th["a"]
		var tb: Vector3 = th["b"]
		var tr := _margin(float(th["r"]))
		var lk := _kit("DEF-thigh.%s" % side)
		match skirt:
			"robe":
				var len := 0.5
				lk.tube("c", ta + Vector3(0, 0.02, 0), ta.lerp(tb, 0.35) + Vector3(0, -len * 0.55, 0), tr * 1.5, tr * 1.7, 10)
			"tabard":
				lk.box("c", Vector3(0.17, 0.4, 0.014), ta + Vector3(0, -0.2, tr + 0.03), Basis(Vector3.RIGHT, 0.06))
				lk.box("t", Vector3(0.17, 0.02, 0.018), ta + Vector3(0, -0.4, tr + 0.04), Basis(Vector3.RIGHT, 0.06))
				lk.box("c", Vector3(0.15, 0.34, 0.014), ta + Vector3(0, -0.18, -tr - 0.03), Basis(Vector3.RIGHT, -0.05))
			"tassets":
				for i in 3:
					lk.box("p" if i != 1 else "t", Vector3(0.17, 0.09, 0.012), ta + Vector3(s * 0.01, -0.08 - 0.07 * float(i), tr + 0.02 + 0.006 * float(i)), Basis(Vector3.RIGHT, 0.12 + 0.08 * float(i)))
		# the thigh guard, a knee cap on the shin, the shin guard
		lk.tube("c" if skirt == "robe" else "p", ta, tb, tr * 1.05, tr * 0.95, 10)
		lk.tube("t", ta.lerp(tb, 0.0), ta.lerp(tb, 0.07), tr * 1.1, tr * 1.1, 10)
		var sa: Vector3 = sh["a"]
		var sb: Vector3 = sh["b"]
		var sr := _margin(float(sh["r"]))
		var sk_kit := _kit("DEF-shin.%s" % side)
		sk_kit.ball("t", tr * 0.62, sa + Vector3(0, 0.01, tr * 0.5), Vector3(1.0, 0.9, 0.8))
		sk_kit.tube("c" if skirt == "robe" else "p", sa, sb, sr * 1.08, sr * 0.9, 10)
		sk_kit.box("t", Vector3(0.025, (sa.lerp(sb, 0.86) - sa.lerp(sb, 0.12)).length(), 0.02), sa.lerp(sb, 0.5) + Vector3(0, 0, sr * 0.95), Basis(Vector3.RIGHT, 0.0))
		if skirt == "robe":
			sk_kit.tube("c", sa.lerp(sb, 0.0), sa.lerp(sb, 0.97), sr * 1.35, sr * 1.8, 10)


# ------------------------------------------------------------------ boots

func build_boots() -> void:
	if _model_piece("boots"):
		return
	for side in ["L", "R"]:
		var ft: Dictionary = fit.get("foot.%s" % side, {})
		var sh: Dictionary = fit["limbs"].get("shin.%s" % side, {})
		if ft.is_empty() or sh.is_empty():
			continue
		var a: Vector3 = ft["a"]
		var b: Vector3 = ft["b"]
		var w: float = ft["w"] + 0.02
		var kit := _kit("DEF-foot.%s" % side)
		var mid := a.lerp(b, 0.45)
		var length := (b - a).length()
		kit.ball("p", 0.5, a.lerp(b, 0.5) + Vector3(0, -0.005, 0.005), Vector3(w * 2.0, 0.085 / 0.5 * 0.5, (length * 0.62 + 0.04) * 1.0) * 1.0 / 1.0)
		kit.ball("t", 0.5, b + Vector3(0, -0.03, 0.0), Vector3(w * 1.9, 0.08, 0.1))                           # toe cap
		kit.box("d", Vector3(w * 2.0, 0.025, length * 1.1), mid + Vector3(0, -0.07, -0.01))                    # the sole
		kit.ball("g", 0.012, b + Vector3(0, 0.0, 0.07))
		var sa: Vector3 = sh["a"]
		var sb: Vector3 = sh["b"]
		var sr := _margin(float(sh["r"]))
		var sk_kit := _kit("DEF-shin.%s" % side)
		sk_kit.tube("p", sb.lerp(sa, 0.34), sb + Vector3(0, -0.04, 0), sr * 1.12, sr * 1.25, 10)               # the boot's shaft
		sk_kit.tube("t", sb.lerp(sa, 0.36), sb.lerp(sa, 0.28), sr * 1.4, sr * 1.4, 10)                          # a folded cuff
		if String(look["style"]) in ["storm", "royal", "moon", "flame"]:
			for i in 3:                                                                                          # little wings at the ankle
				var p := sb + Vector3(0, 0.04 + 0.015 * float(i), -0.04)
				sk_kit.tube("t", p, p + Vector3(_side_sign(side) * 0.1, 0.02 + 0.04 * float(i), -0.06), 0.014, 0.003, 5)


# ------------------------------------------------------------------ shield

func build_shield() -> void:
	if _model_piece("shield"):
		return
	var fa: Dictionary = fit["limbs"].get("forearm.L", {})
	if fa.is_empty():
		return
	var kit := _kit("DEF-forearm.L")
	var a: Vector3 = fa["a"]
	var b: Vector3 = fa["b"]
	var r := float(fa["r"])
	var mid := a.lerp(b, 0.5)
	var out_x := 0.075 + r
	var c := mid + Vector3(out_x, 0.0, 0.02)
	var face := Basis(Vector3.BACK, PI * 0.5)                         # discs with their flat side towards +X
	match String(look["shield"]):
		"round":
			kit.cyl("p", 0.17, 0.17, 0.03, c, face, 18)
			kit.cyl("t", 0.18, 0.18, 0.018, c + Vector3(0.012, 0, 0), face, 18)
			kit.ball("g", 0.045, c + Vector3(0.03, 0, 0), Vector3(0.5, 1.0, 1.0))
		"kite":
			for i in 5:
				var y := lerpf(0.28, -0.3, float(i) / 4.0)
				var wd := lerpf(0.2, 0.02, pow(float(i) / 4.0, 1.5))
				kit.box("p" if i % 2 == 0 else "t", Vector3(0.03, 0.17, wd * 2.0), c + Vector3(0, y, 0), Basis(Vector3.RIGHT, 0.0))
			kit.ball("g", 0.04, c + Vector3(0.025, 0.07, 0), Vector3(0.5, 1.0, 1.0))
		"ward":
			kit.cyl("g", 0.16, 0.16, 0.008, c, face, 20)                                                        # a glowing ward of light
			kit.cyl("t", 0.17, 0.16, 0.012, c + Vector3(-0.004, 0, 0), face, 20)
			kit.ball("t", 0.035, c + Vector3(0.016, 0, 0), Vector3(0.5, 1.0, 1.0))
	if complete:
		kit.cyl("g", 0.2, 0.2, 0.005, c + Vector3(0.018, 0, 0), face, 24)


# ------------------------------------------------------------------ the extras of a complete set

func build_complete_extras() -> void:
	var bands: Array = fit["torso"]
	if bands.is_empty():
		return
	# a short mantle down the back from the shoulders to the waist
	var top: Dictionary = bands[bands.size() - 1]
	var low: Dictionary = bands[maxi(bands.size() / 3, 0)]
	var kit := _kit("DEF-spine.003")
	var back_top := float(top["cz"]) - float(top["rz"]) * 1.0 - 0.04
	var back_low := float(low["cz"]) - float(low["rz"]) * 1.0 - 0.07
	var wt := float(top["rx"]) * 1.1
	var wl := float(low["rx"]) * 1.25
	kit.loft("c", [
		MeshKit.ring(float(top["cx"]), float(top["y"]) + 0.02, back_top + 0.02, wt, 0.03, 0.03, 12),
		MeshKit.ring(float(top["cx"]), lerpf(float(top["y"]), float(low["y"]), 0.5), back_top - 0.03, wt * 1.1, 0.03, 0.03, 12),
		MeshKit.ring(float(top["cx"]), float(low["y"]), back_low, wl, 0.03, 0.03, 12)])
	kit.box("g", Vector3(wl * 2.0, 0.012, 0.012), Vector3(float(top["cx"]), float(low["y"]), back_low - 0.03))
	# glowing runes down the back of the chest
	for i in 4:
		kit.box("g", Vector3(0.012, 0.05, 0.01), Vector3(float(top["cx"]) + (float(i) - 1.5) * 0.045, lerpf(float(low["y"]) + 0.06, float(top["y"]) - 0.04, 0.5), back_top - 0.045))


func make_aura() -> Node3D:
	var g: Color = look["glow"]
	var n := Fx.particles({"tex": "soft", "amount": 10, "life": 2.4, "shape": "sphere", "radius": 0.55, "dir": Vector3.UP, "spread": 20, "vel": [0.15, 0.45], "size": [0.04, 0.09],
		"colors": [Color(g.r, g.g, g.b, 0.0), Color(g.r, g.g, g.b, 0.8), Color(g.r, g.g, g.b, 0.0)]})
	if n == null:
		return null
	n.position = Vector3(0, 0.9, 0)
	return n


# ------------------------------------------------------------------ class flair: whatever the armor, it still feels like the class

## A touch of the class on every set: its colour leans into the palette (see resolve) and a few pieces carry a motif that belongs to the class.
const FLAIR := {
	"druid": {"accent": "#7ad04a", "helm": "leaves", "shoulder": "leaf", "belt": "vine", "back": "none"},
	"sea_king": {"accent": "#3ac8d8", "helm": "fins", "shoulder": "shell", "belt": "pearls", "back": "none"},
	"flame_lord": {"accent": "#ff7a2a", "helm": "flames", "shoulder": "flame", "belt": "ember", "back": "none"},
	"frost_mage": {"accent": "#9ae0ff", "helm": "icecrown", "shoulder": "ice", "belt": "snow", "back": "none"},
	"thunder_god": {"accent": "#ffee66", "helm": "wings", "shoulder": "bolt", "belt": "bolts", "back": "none"},
	"desert_assassin": {"accent": "#e0b060", "helm": "veil", "shoulder": "wrap", "belt": "sash", "back": "none"},
	"necromancer": {"accent": "#9affc0", "helm": "bonecrown", "shoulder": "skull", "belt": "skull", "back": "none"},
	"arcanist": {"accent": "#8ab0ff", "helm": "runes", "shoulder": "rune", "belt": "runes", "back": "ring"},
	"poison_brewer": {"accent": "#a0e040", "helm": "goggles", "shoulder": "vials", "belt": "vials", "back": "none"},
	"pirate_captain": {"accent": "#d8a040", "helm": "tricorn", "shoulder": "epaulet", "belt": "sash", "back": "none"},
	"time_mage": {"accent": "#ffd070", "helm": "gearhalo", "shoulder": "gear", "belt": "clock", "back": "gear"},
	"celestial_mage": {"accent": "#c8d8ff", "helm": "moon", "shoulder": "star", "belt": "stars", "back": "ring"},
}


func _flair(key: String) -> String:
	return String(FLAIR.get(class_id, {}).get(key, "none"))


## A ring of radius r standing upright (in the XY plane) at depth z, as a thin band: `kit.loft(key, _upright_ring(...))`.
func _upright_ring(c: Vector3, r: float, thick: float, z: float) -> Array:
	var a: Array = []
	var b: Array = []
	for k in 20:
		var t := TAU * float(k) / 20.0
		a.append(Vector3(c.x + cos(t) * r, c.y + sin(t) * r, z))
		b.append(Vector3(c.x + cos(t) * (r + thick), c.y + sin(t) * (r + thick), z))
	return [a, b]


func _flair_helm(kit: MeshKit, c: Vector3, rx: float, rz: float, brow: float, top: float, base: float) -> void:
	match _flair("helm"):
		"leaves":
			for i in 5:
				var a := PI * 0.2 + float(i) * PI * 0.6 / 4.0
				kit.ball("g" if i % 2 == 0 else "t", 0.035, Vector3(c.x + cos(a) * rx, brow + 0.07, c.z + sin(a) * rz * 0.6 + 0.02), Vector3(0.55, 0.3, 1.5))
		"fins":
			for s in [-1.0, 1.0]:
				for i in 3:
					var root := Vector3(c.x + s * rx, brow + 0.04 + 0.04 * float(i), c.z)
					kit.tube("g", root, root + Vector3(s * (0.08 + 0.03 * float(i)), 0.03 + 0.03 * float(i), -0.06), 0.02, 0.003, 5)
		"flames":
			for i in 3:
				var p := Vector3(c.x + (float(i) - 1.0) * 0.05, top - 0.01, c.z - rz * 0.5)
				kit.tube("g", p, p + Vector3(0, 0.12 + 0.05 * float(i % 2), -0.04), 0.03, 0.003, 5)
		"icecrown":
			for i in 5:
				var a := TAU * float(i) / 5.0
				var p := Vector3(c.x + cos(a) * rx * 0.95, brow + 0.05, c.z + sin(a) * rz * 0.95)
				kit.tube("g", p, p + Vector3(0, 0.1 + 0.04 * float(i % 2), 0), 0.02, 0.002, 5)
		"wings":
			for s in [-1.0, 1.0]:
				for i in 3:
					var root := Vector3(c.x + s * (rx + 0.01), brow + 0.07 + 0.015 * float(i), c.z - 0.02)
					kit.tube("t", root, root + Vector3(s * (0.12 + 0.025 * float(i)), 0.05 + 0.03 * float(i), -0.05), 0.014, 0.003, 4)
		"veil":
			kit.box("c", Vector3(rx * 1.9, 0.09, 0.012), Vector3(c.x, base + 0.07, c.z + rz + 0.012))
			for i in 2:
				kit.tube("c", Vector3(c.x + (float(i) - 0.5) * 0.06, base + 0.15, c.z - rz), Vector3(c.x + (float(i) - 0.5) * 0.09, base - 0.28 - 0.06 * float(i), c.z - rz - 0.06), 0.03, 0.012, 5)
		"bonecrown":
			for i in 5:
				var a := PI * (0.1 + 0.8 * float(i) / 4.0)
				var p := Vector3(c.x + cos(a) * rx, brow + 0.05, c.z + sin(a) * rz)
				kit.tube("t", p, p + Vector3(0, 0.1 + 0.03 * float(i % 2), 0), 0.014, 0.003, 4)
			kit.ball("t", 0.032, Vector3(c.x, brow + 0.06, c.z + rz + 0.02), Vector3(1.0, 0.9, 0.8))
		"runes":
			var rc := Vector3(c.x, top + 0.05, c.z)
			kit.loft("g", _upright_ring(rc, 0.17, 0.012, c.z - rz - 0.05))
		"goggles":
			for s in [-1.0, 1.0]:
				kit.ball("g", 0.03, Vector3(c.x + s * 0.045, brow + 0.04, c.z + rz + 0.012), Vector3(1.0, 1.0, 0.5))
				kit.ball("t", 0.036, Vector3(c.x + s * 0.045, brow + 0.04, c.z + rz + 0.004), Vector3(1.0, 1.0, 0.5))
			kit.box("d", Vector3(rx * 2.1, 0.012, 0.012), Vector3(c.x, brow + 0.04, c.z + rz * 0.5))
		"tricorn":
			kit.cyl("p", rx * 1.8, rx * 1.8, 0.022, Vector3(c.x, brow + 0.03, c.z), Basis(), 3)
			kit.cyl("p", rx * 1.0, rx * 1.15, 0.09, Vector3(c.x, brow + 0.075, c.z), Basis(), 12)
			kit.tube("t", Vector3(c.x + rx * 0.7, brow + 0.1, c.z), Vector3(c.x + rx * 1.3, brow + 0.2, c.z - 0.12), 0.012, 0.002, 4)
		"gearhalo":
			var gc := Vector3(c.x, top - 0.01, c.z)
			kit.loft("g", _upright_ring(gc, 0.2, 0.012, c.z - rz - 0.06))
			for i in 10:
				var a := TAU * float(i) / 10.0
				kit.box("t", Vector3(0.026, 0.026, 0.014), Vector3(gc.x + cos(a) * 0.215, gc.y + sin(a) * 0.215, c.z - rz - 0.06), Basis(Vector3.BACK, a))
		"moon":
			kit.ball("g", 0.03, Vector3(c.x, brow + 0.09, c.z + rz + 0.012))
			for i in 4:
				kit.box("g", Vector3(0.008, 0.07, 0.006), Vector3(c.x, brow + 0.09, c.z + rz + 0.014), Basis(Vector3.BACK, PI * 0.25 * float(i)))


func _flair_shoulder(kit: MeshKit, s: float, c: Vector3, r: float) -> void:
	match _flair("shoulder"):
		"leaf":
			for i in 3:
				kit.ball("t" if i % 2 == 0 else "g", 0.03, c + Vector3(s * (0.04 + 0.03 * float(i)), 0.06 + 0.012 * float(i), (float(i) - 1.0) * 0.04), Vector3(0.5, 0.25, 1.4))
		"shell":
			for i in 3:
				kit.ball("g", r * (1.0 - 0.18 * float(i)), c + Vector3(s * 0.01, 0.045 + 0.015 * float(i), 0), Vector3(1.0, 0.25, 1.0))
		"flame":
			for i in 3:
				var p := c + Vector3(s * (0.03 + 0.03 * float(i)), 0.05, 0)
				kit.tube("g", p, p + Vector3(s * 0.02, 0.1 + 0.04 * float(i % 2), 0), 0.026, 0.003, 5)
		"ice":
			for i in 3:
				var p := c + Vector3(s * (0.02 + 0.035 * float(i)), 0.05, (float(i) - 1.0) * 0.03)
				kit.tube("g", p, p + Vector3(s * 0.02, 0.11 + 0.03 * float(i), 0), 0.022, 0.002, 5)
		"bolt":
			var p := c + Vector3(s * 0.03, 0.08, 0)
			for i in 3:
				var q := p + Vector3(s * (0.06 if i % 2 == 0 else -0.03), 0.045, 0)
				kit.tube("g", p, q, 0.012, 0.012, 4)
				p = q
		"wrap":
			for i in 2:
				kit.tube("c", c + Vector3(s * 0.05, -0.02, (float(i) - 0.5) * 0.06), c + Vector3(s * 0.07, -0.2 - 0.05 * float(i), (float(i) - 0.5) * 0.08 - 0.03), 0.028, 0.012, 5)
		"skull":
			kit.ball("t", 0.036, c + Vector3(s * 0.05, 0.07, 0.03), Vector3(1.0, 0.9, 0.85))
			kit.ball("g", 0.009, c + Vector3(s * 0.04, 0.075, 0.062))
			kit.ball("g", 0.009, c + Vector3(s * 0.065, 0.075, 0.058))
		"rune":
			kit.cyl("g", 0.05, 0.05, 0.006, c + Vector3(s * 0.06, 0.12, 0), Basis(Vector3.RIGHT, PI * 0.5), 12)
		"vials":
			for i in 2:
				kit.cyl("g", 0.012, 0.012, 0.06, c + Vector3(s * (0.05 + 0.035 * float(i)), 0.07, 0.0), Basis(), 6)
				kit.cyl("t", 0.008, 0.008, 0.015, c + Vector3(s * (0.05 + 0.035 * float(i)), 0.108, 0.0), Basis(), 5)
		"epaulet":
			for i in 5:
				kit.tube("t", c + Vector3(s * (0.03 + 0.02 * float(i)), -0.01, 0.0), c + Vector3(s * (0.045 + 0.022 * float(i)), -0.09, 0.0), 0.007, 0.004, 4)
		"gear":
			kit.cyl("t", 0.06, 0.06, 0.016, c + Vector3(s * 0.07, 0.05, 0), Basis(Vector3.BACK, PI * 0.5), 10)
			kit.ball("g", 0.014, c + Vector3(s * 0.08, 0.05, 0))
		"star":
			for i in 4:
				kit.box("g", Vector3(0.008, 0.08, 0.006), c + Vector3(s * 0.06, 0.1, 0), Basis(Vector3.BACK, PI * 0.25 * float(i)))


func _flair_belt(kit: MeshKit, hips: Vector3, wy: float, rx: float, rz: float) -> void:
	var front := Vector3(hips.x, wy - 0.01, hips.z + rz + 0.02)
	match _flair("belt"):
		"vine":
			for i in 4:
				kit.ball("t", 0.03, Vector3(hips.x + (float(i) - 1.5) * 0.09, wy - 0.02, hips.z + rz * (0.9 if i % 2 == 0 else 1.0)), Vector3(0.6, 0.3, 1.4))
		"pearls":
			for i in 7:
				kit.ball("g", 0.014, Vector3(hips.x + (float(i) - 3.0) * 0.045, wy - 0.01, hips.z + rz + 0.012 - absf(float(i) - 3.0) * 0.004))
		"ember":
			for i in 3:
				kit.tube("g", front + Vector3((float(i) - 1.0) * 0.05, 0.0, 0.0), front + Vector3((float(i) - 1.0) * 0.05, -0.1 - 0.03 * float(i % 2), 0.01), 0.018, 0.002, 4)
		"snow":
			for i in 3:
				kit.ball("g", 0.022, front + Vector3((float(i) - 1.0) * 0.06, -0.01, 0.0))
		"bolts":
			kit.box("g", Vector3(0.012, 0.07, 0.01), front + Vector3(0.0, -0.04, 0.0), Basis(Vector3.BACK, 0.4))
		"sash":
			kit.box("c", Vector3(0.07, rx * 2.4, 0.02), Vector3(hips.x, wy - 0.02, hips.z + rz + 0.012), Basis(Vector3.BACK, PI * 0.5))
			kit.tube("c", front + Vector3(-rx * 0.8, -0.01, 0.0), front + Vector3(-rx * 0.8, -0.2, 0.01), 0.03, 0.012, 5)
		"skull":
			kit.ball("t", 0.04, front + Vector3(0.0, 0.0, 0.01), Vector3(1.0, 0.9, 0.8))
			kit.ball("g", 0.009, front + Vector3(-0.015, 0.004, 0.044))
			kit.ball("g", 0.009, front + Vector3(0.015, 0.004, 0.044))
		"runes":
			for i in 3:
				kit.box("g", Vector3(0.012, 0.045, 0.01), front + Vector3((float(i) - 1.0) * 0.05, -0.02, 0.0))
		"vials":
			for i in 3:
				kit.cyl("g", 0.014, 0.014, 0.06, front + Vector3((float(i) - 1.0) * 0.06, -0.06, 0.01), Basis(), 6)
				kit.cyl("t", 0.009, 0.009, 0.014, front + Vector3((float(i) - 1.0) * 0.06, -0.025, 0.01), Basis(), 5)
		"clock":
			kit.cyl("t", 0.045, 0.045, 0.014, front + Vector3(0.0, -0.01, 0.012), Basis(Vector3.RIGHT, PI * 0.5), 14)
			kit.cyl("g", 0.034, 0.034, 0.016, front + Vector3(0.0, -0.01, 0.014), Basis(Vector3.RIGHT, PI * 0.5), 14)
		"stars":
			for i in 3:
				kit.ball("g", 0.016, front + Vector3((float(i) - 1.0) * 0.06, -0.01, 0.0))


## A ring or a gear floating behind the shoulders for the casters that have one.
func _flair_back(top: Dictionary) -> void:
	var mode := _flair("back")
	if mode == "none":
		return
	var kit := _kit("DEF-spine.003")
	var c := Vector3(float(top["cx"]), float(top["y"]) - 0.1, float(top["cz"]) - float(top["rz"]) - 0.12)
	kit.loft("g", _upright_ring(c, 0.3, 0.014, c.z))
	if mode == "gear":
		for i in 12:
			var a := TAU * float(i) / 12.0
			kit.box("t", Vector3(0.04, 0.04, 0.016), Vector3(c.x + cos(a) * 0.325, c.y + sin(a) * 0.325, c.z), Basis(Vector3.BACK, a))
	elif complete:
		kit.loft("g", _upright_ring(c, 0.4, 0.01, c.z))


# ------------------------------------------------------------------ pieces made on Hunyuan

## A piece made on Hunyuan lives in models/armor/<set id>/<slot>.glb (slot: helmet, chestplate, shield, leggings, boots; the boots are one boot, it is mirrored for the other foot).
## It is scaled to the measured body (helmet to the skull, chestplate to the chest width, leggings to the hips and legs, boots to the foot, shield to the arm), put where that part of the body
## is and fastened to the bone, so it moves with the animation. Returns true when the model was used (then the procedural piece is skipped).
func _model_piece(slot: String) -> bool:
	var set_id := String(look.get("set_id", ""))
	var path := "res://models/armor/%s/%s.glb" % [set_id, slot]
	var styled := false
	if set_id == "" or not ResourceLoader.exists(path):
		path = "res://models/armor/style_%s/%s.glb" % [String(look.get("style", "")), slot]       # one model per style and piece serves every set of that style
		styled = true
		if not ResourceLoader.exists(path):
			return false
	var res: Resource = load(path)
	if not (res is PackedScene):
		return false
	var sides: Array = [""]
	if slot == "boots" or slot == "leggings":
		sides = ["L", "R"]
	for side in sides:
		var node: Node3D = (res as PackedScene).instantiate()
		if styled:
			_tint_model(node)
		var tmp := Node3D.new()                              # measure the model on its own first
		tmp.add_child(node)
		var box := AABB()
		var first := true
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var t := Transform3D.IDENTITY                       # the mesh's place inside the model, up through its parents
			var cur: Node = m
			while cur != null and cur != tmp:
				if cur is Node3D:
					t = (cur as Node3D).transform * t
				cur = cur.get_parent()
			var b := t * m.get_aabb()
			box = b if first else box.merge(b)
			first = false
		if first:
			tmp.free()
			return false
		var bone := "DEF-spine.002"
		var target := Vector3.ZERO
		var k := 1.0
		match slot:
			"helmet":
				var h: Dictionary = fit["head"]
				bone = "DEF-head"
				var hc: Vector3 = h["c"]
				target = Vector3(hc.x, float(h["base"]) + 0.14, hc.z)
				k = (float(h["top"]) - float(h["base"]) + 0.12) / maxf(box.size.y, 0.01)
			"chestplate":
				var bands: Array = fit["torso"]
				bone = "DEF-spine.002"
				var widths: Array = []
				for b in bands:
					widths.append(float(b["rx"]))
				widths.sort()
				var wmax: float = float(widths[widths.size() / 2]) if not widths.is_empty() else 0.2
				var hips: Vector3 = fit["hips"]
				var top_y: float = float((bands[bands.size() - 1] as Dictionary)["y"]) if not bands.is_empty() else hips.y + 0.45
				target = Vector3(hips.x, (hips.y + 0.05 + top_y + 0.08) * 0.5, hips.z)
				k = (wmax * 2.0 * 1.3) / maxf(box.size.x, 0.01)
			"leggings":
				bone = "DEF-thigh.%s" % side
				var th: Dictionary = fit["limbs"].get("thigh.%s" % side, {})
				var ft: Dictionary = fit.get("foot.%s" % side, {})
				if th.is_empty() or ft.is_empty():
					tmp.free()
					continue
				var top: Vector3 = th["a"]
				var low: Vector3 = ft["a"]
				target = (top + low) * 0.5 + Vector3(0, 0.02, 0.01)
				k = (top.y - low.y + 0.06) / maxf(box.size.y, 0.01)
			"boots":
				bone = "DEF-foot.%s" % side
				var ft: Dictionary = fit.get("foot.%s" % side, {})
				if ft.is_empty():
					tmp.free()
					continue
				var a: Vector3 = ft["a"]
				var bb: Vector3 = ft["b"]
				target = a.lerp(bb, 0.45) + Vector3(0, 0.02, 0)
				k = ((bb - a).length() * 1.6) / maxf(maxf(box.size.z, box.size.x), 0.01)
			"shield":
				bone = "DEF-forearm.L"
				var fa: Dictionary = fit["limbs"].get("forearm.L", {})
				if fa.is_empty():
					tmp.free()
					return false
				target = (fa["a"] as Vector3).lerp(fa["b"], 0.5) + Vector3(0.1 + float(fa["r"]), 0, 0.02)
				k = 0.5 / maxf(maxf(box.size.x, box.size.y), 0.01)
		var bi := sk.find_bone(bone)
		if bi < 0:
			tmp.free()
			continue
		tmp.remove_child(node)
		tmp.free()
		if OS.get_environment("ARMOR_DEBUG") != "":
			print("HYPIECE ", slot, " box ", box, " k ", k, " target ", target, " bone ", bone)
		var basis := Basis.from_scale(Vector3((-k if side == "R" else k), k, k))
		if slot == "shield":
			basis = Basis(Vector3.UP, -PI * 0.5) * basis                    # the shield faces outwards
		var local := sk.get_bone_global_rest(bi).affine_inverse() * Transform3D(basis, target - basis * box.get_center())
		node.transform = local * node.transform                  # (the model's own root transform was part of the measurement)
		var att := BoneAttachment3D.new()
		att.bone_name = bone
		sk.add_child(att)
		att.add_child(node)
		model_nodes.append(att)
		if OS.get_environment("ARMOR_DEBUG") != "":
			print("HYPLACED ", slot, " in tree ", att.is_inside_tree(), " global ", node.global_position, " scale ", node.global_transform.basis.get_scale(), " meshes ", node.find_children("*", "MeshInstance3D", true, false).size(), " visible ", node.visible)
	return true


## A style model shared by several sets is coloured per set: its textures are multiplied by the set's main colour (half way to white, so the painted detail stays).
func _tint_model(node: Node3D) -> void:
	var tint := Color.WHITE.lerp(look["c1"] as Color, 0.55)
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var src := m.get_active_material(s)
			if src is BaseMaterial3D:
				var copy := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
				copy.albedo_color = (copy.albedo_color as Color) * tint
				m.set_surface_override_material(s, copy)


## The file of a Hunyuan model for a piece: the set's own (models/armor/<set id>/<slot>.glb) or else its style's (models/armor/style_<style>/<slot>.glb); "" if there is none.
static func model_path(set_id: String, slot: String) -> String:
	var own := "res://models/armor/%s/%s.glb" % [set_id, slot]
	if ResourceLoader.exists(own):
		return own
	var style := String(Data.armor_looks.get(set_id, {}).get("style", ""))
	var shared := "res://models/armor/style_%s/%s.glb" % [style, slot]
	return shared if ResourceLoader.exists(shared) else ""
