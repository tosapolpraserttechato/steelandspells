class_name Border
extends RefCounted
## Dresses the rim of a map so the edge belongs to it: a belt of the map's own trees, rocks, ferns, crystals, kelp... (the same models, planted bigger and denser on the
## slope beyond the playable ground), plus big versions of the decor shapes (see DecorMesh) in the map's colours. Nothing here has collision.
##   own:   [name fragment of a model the map already holds, weight, scale low, scale high]
##   decor: [DecorMesh kind, weight, scale low, scale high, palette names, glow]
## `count` is how many are planted, `from` / `to` the belt in metres beyond the edge of the play area (negative = a little inside).

const SPECS := {
	"flora_forest": {"count": 420, "from": -2.0, "to": 40.0,
		"own": [["leafy_tree", 3.0, 1.5, 2.4], ["giant_fern", 3.0, 1.6, 2.8], ["giant_mushroom", 1.0, 1.4, 2.2]],
		"decor": [["bush", 3.0, 3.0, 5.5, ["green", "dkgreen", "olive", "lime"], 0.0], ["fern", 2.0, 3.0, 6.0, ["green", "lime", "dkgreen"], 0.0], ["rock_mossy", 1.5, 3.0, 7.0, ["stone", "grey"], 0.0]]},
	"toxic_swamp": {"count": 420, "from": -2.0, "to": 40.0,
		"own": [["mangrove", 3.0, 1.4, 2.2], ["swamp_tree", 2.0, 1.4, 2.2], ["giant_fern", 2.0, 1.6, 2.6], ["giant_mushroom", 1.2, 1.4, 2.2]],
		"decor": [["reed", 3.0, 4.0, 8.0, ["dkgreen", "olive", "brown"], 0.0], ["pod", 1.2, 3.0, 6.0, ["lime", "teal", "magenta"], 1.0], ["rock_mossy", 1.2, 3.0, 7.0, ["dark", "olive"], 0.0]]},
	"underwater_ocean": {"count": 460, "from": -2.0, "to": 44.0,
		"own": [["giant_kelp", 4.0, 1.3, 2.2], ["coral_reef", 2.0, 1.5, 2.5], ["sea_anemone", 1.0, 1.5, 2.6]],
		"decor": [["coral_fan", 1.5, 5.0, 9.0, ["pink", "orange", "purple", "red"], 0.0], ["coral_branch", 1.5, 5.0, 9.0, ["pink", "orange", "teal", "purple"], 0.0],
			["seaweed", 2.0, 6.0, 10.0, ["green", "lime", "teal"], 0.0], ["rock", 1.5, 4.0, 8.0, ["stone", "teal", "tan"], 0.0]]},
	"frozen_peaks": {"count": 420, "from": -2.0, "to": 40.0,
		"own": [["snow_pine", 4.0, 1.4, 2.3], ["ice_crystal", 1.5, 1.5, 3.0]],
		"decor": [["mound", 2.0, 6.0, 12.0, ["snow", "white", "ice"], 0.0], ["rock_snowy", 1.5, 4.0, 8.0, ["stone", "grey"], 0.0], ["crystals", 1.0, 4.0, 8.0, ["ice", "sky", "white"], 0.7]]},
	"volcano_forge": {"count": 400, "from": -2.0, "to": 40.0,
		"own": [["basalt_boulders", 3.0, 1.5, 2.6], ["charred_tree", 2.0, 1.3, 2.0], ["obsidian_crystal", 1.5, 1.5, 3.0]],
		"decor": [["shard", 2.5, 5.0, 10.0, ["obsidian", "dark", "purple"], 0.0], ["rock", 2.0, 4.0, 8.0, ["dark", "iron"], 0.0], ["crystals", 1.0, 4.0, 8.0, ["ember", "red", "amber"], 1.3]]},
	"desert_tomb": {"count": 380, "from": -2.0, "to": 40.0,
		"own": [["rock", 3.0, 1.6, 3.0], ["palm_tree", 1.0, 1.2, 1.8]],
		"decor": [["mound", 2.0, 8.0, 14.0, ["sand", "tan", "cream"], 0.0], ["cactus", 1.5, 3.0, 5.0, ["green", "olive"], 0.0], ["shard", 1.0, 4.0, 8.0, ["tan", "brown"], 0.0]]},
	"sky_islands": {"count": 320, "from": -2.0, "to": 50.0,
		"own": [["cloud_puff", 4.0, 2.5, 5.0], ["floating_islet", 0.5, 1.0, 1.8]],
		"decor": []},
	"shadow_crypt": {"count": 400, "from": -2.0, "to": 40.0,
		"own": [["dead_tree", 4.0, 1.3, 2.2], ["gravestone_rip", 2.0, 1.5, 2.5]],
		"decor": [["grave", 2.0, 3.0, 5.0, ["stone", "grey", "moss"], 0.0], ["shard", 1.0, 4.0, 8.0, ["dark", "purple"], 0.0], ["bones", 1.0, 3.0, 5.0, ["bone"], 0.0]]},
	"crystal_caves": {"count": 420, "from": -2.0, "to": 40.0,
		"own": [["stalagmite_cluster", 3.0, 1.6, 3.0], ["crystal_cluster", 2.0, 1.6, 3.0], ["crystal_spire", 1.0, 1.4, 2.4]],
		"decor": [["crystals", 3.0, 5.0, 9.0, ["cyan", "magenta", "violet", "lime", "blue"], 1.4], ["boulder", 1.0, 3.0, 6.0, ["dark", "stone"], 0.0]]},
	"clockwork_mines": {"count": 380, "from": -2.0, "to": 40.0,
		"own": [["cm_ore_crag", 4.0, 1.4, 2.4], ["cm_steam_pipe", 0.8, 1.0, 1.6]],
		"decor": [["gear", 1.5, 4.0, 8.0, ["brass", "iron", "copper"], 0.0], ["rock", 2.0, 4.0, 8.0, ["dark", "iron"], 0.0]]},
	"moon_sanctuary": {"count": 340, "from": -2.0, "to": 44.0,
		"own": [["sky_pillar", 2.0, 1.2, 2.0], ["floating_islet", 1.0, 1.0, 1.8]],
		"decor": [["crystals", 1.5, 4.0, 8.0, ["moon", "sky", "violet"], 1.2], ["mound", 1.0, 6.0, 12.0, ["white", "moon"], 0.0]]},
	"pirate_cove": {"count": 380, "from": -2.0, "to": 40.0,
		"own": [["rock_a", 3.0, 1.5, 3.0], ["palm_tree", 2.0, 1.2, 1.8]],
		"decor": [["mound", 2.0, 8.0, 14.0, ["sand", "tan"], 0.0], ["rock", 1.5, 4.0, 8.0, ["tan", "stone", "brown"], 0.0], ["bush", 1.0, 3.0, 5.0, ["green", "lime", "olive"], 0.0]]},
}


## Plants the belt. `half` is the playable half-size of the map (the edge of the flat ground).
static func dress(host: Node3D, map_id: String, map_root: Node3D, map_size: Vector2) -> void:
	if not SPECS.has(map_id):
		return
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	if not is_instance_valid(host) or not is_instance_valid(map_root):
		return
	var spec: Dictionary = SPECS[map_id]
	var own_meshes: Dictionary = map_root.get_meta("own_meshes", {})
	var space := host.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = map_id.hash() + 4242
	var half := map_size * 0.5
	var from_d: float = float(spec["from"])
	var to_d: float = float(spec["to"])
	# the things that can be planted
	var items: Array = []
	var total_w := 0.0
	for o in spec["own"]:
		var found: Array = []
		for k in own_meshes:
			if String(k).contains(String(o[0])):
				found.append_array(own_meshes[k])
		if found.is_empty():
			continue
		items.append({"own": found, "w": float(o[1]), "lo": float(o[2]), "hi": float(o[3])})
		total_w += float(o[1])
	for d in spec["decor"]:
		items.append({"k": d[0], "w": float(d[1]), "lo": float(d[2]), "hi": float(d[3]), "pal": d[4], "glow": float(d[5])})
		total_w += float(d[1])
	if items.is_empty():
		return
	var groups: Dictionary = {}
	var placed := 0
	var tries := 0
	var count: int = int(float(spec["count"]) * [0.3, 0.65, 1.0][Settings.quality()])
	while placed < count and tries < count * 12:
		tries += 1
		var p := Vector2(rng.randf_range(-half.x - to_d, half.x + to_d), rng.randf_range(-half.y - to_d, half.y + to_d))
		var out := maxf(absf(p.x) - half.x, absf(p.y) - half.y)          # how far beyond the play area edge
		if out < from_d or out > to_d:
			continue
		var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 200.0, p.y), Vector3(p.x, -80.0, p.y), 1)
		var r := space.intersect_ray(q)
		if r.is_empty():
			continue
		var col: Object = r["collider"]
		if not (col is Node) or not (col as Node).has_meta("ground"):
			continue
		var pick := rng.randf() * total_w
		var it: Dictionary = items[0]
		for c in items:
			pick -= float(c["w"])
			if pick <= 0.0:
				it = c
				break
		var s := rng.randf_range(float(it["lo"]), float(it["hi"]))
		var yaw := rng.randf() * TAU
		var basis := Basis(Vector3.UP, yaw)
		var tilt := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		basis = Basis(tilt, rng.randf_range(0.0, 0.12)) * basis
		basis = basis.scaled(Vector3(s, s * rng.randf_range(0.85, 1.2), s))
		var pos: Vector3 = r["position"] - Vector3(0, 0.25 * s * (0.6 if it.has("own") else 0.3), 0)
		var cell := "%d_%d" % [int(floor(pos.x / 80.0)), int(floor(pos.z / 80.0))]
		if it.has("own"):
			var meshes: Array = it["own"]
			var mesh: Mesh = meshes[rng.randi() % meshes.size()]
			var gk := "o%d|%s" % [mesh.get_instance_id(), cell]
			if not groups.has(gk):
				groups[gk] = {"mesh": mesh, "xf": [], "col": [], "decor": false, "glow": 0.0}
			groups[gk]["xf"].append(Transform3D(basis, pos))
		else:
			var v := rng.randi() % Decor.VARIANTS
			var pal_name: String = it["pal"][rng.randi() % (it["pal"] as Array).size()]
			var kind: String = it["k"]
			if kind.begins_with("rock") or kind.begins_with("boulder"):
				pal_name = Decor.ROCK_MAP.get(pal_name, pal_name)
			var base_col: Color = Decor.PAL[pal_name]
			var cc := Color.from_hsv(fposmod(base_col.h + rng.randf_range(-0.03, 0.03), 1.0), clampf(base_col.s * rng.randf_range(0.85, 1.1), 0.0, 1.0), clampf(base_col.v * rng.randf_range(0.85, 1.1), 0.0, 1.0)).srgb_to_linear()
			var gk := "d%s%d|%s|%.1f" % [kind, v, cell, float(it["glow"])]
			if not groups.has(gk):
				groups[gk] = {"mesh": Decor._mesh(kind, v), "xf": [], "col": [], "decor": true, "glow": float(it["glow"])}
			groups[gk]["xf"].append(Transform3D(basis, pos))
			groups[gk]["col"].append(Color(cc.r, cc.g, cc.b, rng.randf()))
		placed += 1
	var holder := Node3D.new()
	holder.name = "Rim"
	map_root.add_child(holder)
	for gk in groups:
		var g: Dictionary = groups[gk]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		if g["decor"]:
			mm.use_colors = true
			mm.use_custom_data = true
		mm.mesh = g["mesh"]
		mm.instance_count = g["xf"].size()
		for i in g["xf"].size():
			mm.set_instance_transform(i, g["xf"][i])
			if g["decor"]:
				mm.set_instance_color(i, Color.WHITE)
				mm.set_instance_custom_data(i, g["col"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if g["decor"]:
			mmi.material_override = Decor._material(float(g["glow"]))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = [150.0, 200.0, 260.0][Settings.quality()]
		holder.add_child(mmi)
	print("RIM ", map_id, " planted ", placed, " in ", groups.size(), " groups")
