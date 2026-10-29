class_name MapLoader
extends RefCounted
## Loads a finished map (res://maps/<id>/<id>.glb + markers.json) and makes it playable:
##  - collision: trimesh for terrain, floors, walls and buildings, convex hulls for rocks and cover, thin trunks for trees, none for plants and decals
##  - rendering: every mesh used many times is merged into MultiMeshes per 80 m cell (few draw calls, frustum culling per cell, visibility range for small plants)
##  - markers.json (Blender axes: x east, y north, z up) is converted to Godot axes (x, z, -y)

const CELL := 80.0
const NO_COLLISION := ["fern", "flower", "kelp", "anemone", "grass", "glow_mushroom", "spore", "cloud", "puff", "bulb", "stalactite", "lava_river", "water", "path_", "jump_pad",
	"thorn_patch", "curse", "steam", "eclipse", "warning", "cave_river", "cave_water", "lantern_glow", "decal", "mist", "rail_", "gold_inlay", "scorch", "strike_", "waterfall", "updraft"]
const TRUNK := ["leafy_tree", "snow_pine", "dead_tree", "swamp_tree", "mangrove", "palm_tree", "charred_tree", "tree"]
const TRIMESH := ["terrain", "door_", "hall_", "lookout", "court_", "tower", "gallery", "bridge_", "rope_bridge", "bulwark", "pilaster", "wall", "floating_island", "floating_islet", "sky_pillar",
	"arch", "gate", "tunnel", "cathedral", "mausoleum", "pyramid", "castle", "temple", "pavilion", "colonnade", "fort", "hall", "smithy", "hut", "house", "cabin", "forge", "galleon",
	"pinnace", "pier", "shipwreck", "rotunda", "sphinx", "stairs", "chess_board", "cliff", "tower", "smelter", "headframe", "cannon", "cart", "stall", "well",
	"altar", "fountain", "statue", "chest", "pedestal", "plinth", "monolith", "chess_king", "chess_queen", "chess_rook", "chess_bishop", "chess_knight", "chess_pawn"]
const SMALL_PLANTS := ["fern", "flower", "anemone", "kelp", "glow_mushroom", "grass", "spore"]


## True while a map is built only to be looked at (the title screen): the ground gets collision (flowers and animals need it), everything else none.
static var ground_only := false
static var keep_names := {}                 # node names that must not be merged into MultiMeshes (they move)


static func blender_to_godot(p: Array) -> Vector3:
	return Vector3(float(p[0]), float(p[2]), -float(p[1]))


static func read_markers(map_id: String) -> Dictionary:
	var path := "res://maps/%s/markers.json" % map_id
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("MapLoader: no markers for " + map_id)
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Builds the map under `parent`. Returns {root, markers, size, collision_bodies}.
static func build(parent: Node3D, map_id: String) -> Dictionary:
	var packed: PackedScene = load("res://maps/%s/%s.glb" % [map_id, map_id])
	var root: Node3D = packed.instantiate()
	root.name = "Map"
	parent.add_child(root)
	var info := read_markers(map_id)
	var markers: Array = []
	for m in info.get("markers", []):
		var d: Dictionary = m.duplicate()
		d["pos"] = blender_to_godot(m["position"])
		markers.append(d)
	_remove_marker_nodes(root, markers)
	_tame_lights(root)
	keep_names.clear()
	for mk in markers:
		if String(mk.get("kind", "")) == "moving_cover":
			keep_names[String(mk.get("object", ""))] = true            # these chess pieces move: they stay single objects with their own collision
	var stats := _process(root)
	return {"root": root, "markers": markers, "size": info.get("size_m", [240, 240]), "stats": stats, "info": info}


static func _remove_marker_nodes(root: Node3D, markers: Array) -> void:
	var names := {}
	for m in markers:
		names[m["name"]] = true
	for c in root.get_children():
		if c is Node3D and not (c is MeshInstance3D) and not (c is Light3D) and names.has(String(c.name)):
			c.queue_free()


static func _base_name(n: String) -> String:
	var s := n
	var at := s.find("@")
	if at >= 0:
		s = s.substr(0, at)
	var re := RegEx.new()
	re.compile("_\\d+$")
	var m := re.search(s)
	if m != null:
		s = s.substr(0, m.get_start())
	return s


static func _matches(name: String, list: Array) -> bool:
	for k in list:
		if name.contains(k):
			return true
	return false


static func _process(root: Node3D) -> Dictionary:
	var meshes: Array = []
	var usage: Dictionary = {}
	for c in root.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			meshes.append(c)
			usage[c.mesh] = int(usage.get(c.mesh, 0)) + 1
	var shape_cache: Dictionary = {}
	var groups: Dictionary = {}
	var bodies := 0
	var merged := 0
	var soft_cache := {}
	var path_cells := {}                       # 1 m cells covered by a path: Decor.gd keeps flowers off them
	var bigs: Array = []
	var own_meshes := {}                       # prop kind -> up to four of its meshes
	var door_parts := {}                       # gate name -> [its mesh, its collision body, decorations that move with it...]
	var mushroom_pads: Array = []              # bounce pads for the giant mushrooms (Match.gd makes them into hazards)
	var tamed := {}
	for mi in meshes:
		var node := mi as MeshInstance3D
		var base := _base_name(String(node.name))
		for si in node.mesh.get_surface_count():
			var sm := node.mesh.surface_get_material(si)
			if sm is BaseMaterial3D and not tamed.has(sm):
				tamed[sm] = true
				_tame_emission(sm as BaseMaterial3D)
		if base.begins_with("path_"):
			_stamp_path(node, path_cells)
			_soften_path(node, soft_cache)
		elif base != "terrain" and node.mesh != null:
			# big things (ships, towers, huge rocks): the title screen panorama keeps its camera clear of them
			var ab := node.mesh.get_aabb()
			var sc := node.global_transform.basis.get_scale()
			var ext := Vector3(ab.size.x * sc.x, ab.size.y * sc.y, ab.size.z * sc.z)
			var rad := maxf(ext.x, ext.z) * 0.5
			if ext.y > 2.5 and rad > 1.5 and not base.begins_with("cloud"):
				bigs.append([node.global_transform * ab.get_center(), rad])
		var shared: bool = int(usage[node.mesh]) >= 3 and not keep_names.has(String(node.name))
		var is_terrain := base == "terrain"
		# variety: every tree, rock, fern, crystal... gets its own size, lean, turn and colour (the map only holds a few shapes of each)
		var tint := Color.WHITE
		var variety: Dictionary = _variety_for(base) if shared else {}
		if not variety.is_empty():
			var vr := RandomNumberGenerator.new()
			vr.seed = hash(String(node.name)) ^ int(node.global_position.x * 97.0) ^ (int(node.global_position.z * 131.0) << 8)
			var xf := node.global_transform
			var sz := vr.randf_range(float(variety["scale"][0]), float(variety["scale"][1]))
			var tall := vr.randf_range(0.88, 1.22) if _matches(base, NO_COLLISION) else 1.0
			var b := xf.basis
			if variety.get("spin", true):
				b = b * Basis(Vector3.UP, vr.randf() * TAU)
			var lean := float(variety.get("lean", 0.0))
			if lean > 0.0:
				b = b * Basis(Vector3(vr.randf_range(-1.0, 1.0), 0.0, vr.randf_range(-1.0, 1.0)).normalized(), deg_to_rad(vr.randf_range(0.0, lean)))
			xf.basis = b * Basis.from_scale(Vector3(sz, sz * tall, sz))
			node.global_transform = xf
			var pal: Array = variety["tints"]
			var shade := vr.randf_range(float(variety["val"][0]), float(variety["val"][1]))
			tint = Color.WHITE.lerp(pal[vr.randi() % pal.size()], float(variety.get("mix", 0.6))) * shade
			tint.a = 1.0
		# liquid hazards: a trimesh on its own physics layer (bit 4) that Match.gd samples with a ray under each fighter
		if (base == "lava_river" or base == "cave_river") and not ground_only:
			var sb := StaticBody3D.new()
			sb.collision_layer = 8
			sb.collision_mask = 0
			sb.set_meta("surface", "lava" if base == "lava_river" else "shallow_water")
			var scs := CollisionShape3D.new()
			scs.shape = _trimesh_shape(node.mesh, shape_cache)
			sb.add_child(scs)
			root.add_child(sb)
			sb.global_transform = node.global_transform
		# giant mushrooms are too tall to jump onto: their caps bounce (see HazardNode "bounce_pad"): a ring around the foot throws you up onto the cap, the cap bounces you
		if base.begins_with("giant_mushroom") and node.mesh != null and not ground_only:
			var mxf := node.global_transform
			var mab := node.mesh.get_aabb()
			var lo := Vector3(1e9, 1e9, 1e9)
			var hi := Vector3(-1e9, -1e9, -1e9)
			for ci in 8:
				var corner := mab.position + Vector3(mab.size.x * float(ci & 1), mab.size.y * float((ci >> 1) & 1), mab.size.z * float((ci >> 2) & 1))
				var wp := mxf * corner
				lo = Vector3(minf(lo.x, wp.x), minf(lo.y, wp.y), minf(lo.z, wp.z))
				hi = Vector3(maxf(hi.x, wp.x), maxf(hi.y, wp.y), maxf(hi.z, wp.z))
			var cap_r := maxf(hi.x - lo.x, hi.z - lo.z) * 0.5
			var h := hi.y - mxf.origin.y
			if h > 2.5 and cap_r > 1.4:
				var cx := (lo.x + hi.x) * 0.5
				var cz := (lo.z + hi.z) * 0.5
				mushroom_pads.append({"kind": "bounce_pad", "pos": Vector3(cx, mxf.origin.y + 0.3, cz), "radius": cap_r * 1.3, "launch_speed": sqrt(2.0 * 24.0 * (h + 1.2)), "inward": true, "quiet": true})
				mushroom_pads.append({"kind": "bounce_pad", "pos": Vector3(cx, hi.y, cz), "radius": cap_r * 0.8, "launch_speed": 15.5, "quiet": true})
		# collision
		var shape: Shape3D = null
		if keep_names.has(String(node.name)):
			shape = _convex_shape(node.mesh, shape_cache)
		elif _matches(base, NO_COLLISION) or (ground_only and not (is_terrain or base.begins_with("floating_island") or base.begins_with("floating_islet"))):
			shape = null
		elif _matches(base, TRUNK):
			shape = _trunk_shape(node.mesh, shape_cache)
		elif _matches(base, TRIMESH) or not shared:
			shape = _trimesh_shape(node.mesh, shape_cache) if (shared or is_terrain or _matches(base, TRIMESH)) else null
		else:
			shape = _convex_shape(node.mesh, shape_cache)
		if shape != null:
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var cs := CollisionShape3D.new()
			cs.shape = shape
			body.add_child(cs)
			if is_terrain or base.begins_with("floating_island") or base.begins_with("floating_islet"):
				body.set_meta("ground", true)             # Decor.gd scatters flowers and the like on these
			root.add_child(body)
			body.global_transform = node.global_transform
			bodies += 1
			if keep_names.has(String(node.name)):
				door_parts[String(node.name)] = [node, body]
			if String(node.name).begins_with("door_") and not (String(node.name).ends_with("_glyph") or String(node.name).ends_with("_sill")):
				door_parts[String(node.name)] = [node, body]            # the gate of a pressure plate (PlateNode / DoorNode): it slides into the ground
		# rendering: merge shared meshes into MultiMeshes by 80 m cell
		if shared and not is_terrain:
			var g := node.global_position
			var key := "%d_%d_%d" % [node.mesh.get_instance_id(), int(floor(g.x / CELL)), int(floor(g.z / CELL))]
			if not groups.has(key):
				groups[key] = {"mesh": node.mesh, "xf": [], "col": [], "tinted": not variety.is_empty(), "small": _matches(base, SMALL_PLANTS), "mat": node.material_override, "cast": node.cast_shadow}
			groups[key]["xf"].append(node.global_transform)
			groups[key]["col"].append(tint)
			# remember a few of each kind of prop: Border.gd plants more of them (bigger) around the map's rim
			var pm: Array = own_meshes.get(base, [])
			if pm.size() < 4 and not pm.has(node.mesh) and not String(node.name).contains("lod"):
				pm.append(node.mesh)
				own_meshes[base] = pm
			node.queue_free()
			merged += 1
	var vc_cache := {}
	for key in groups:
		var gd: Dictionary = groups[key]
		var mmi := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = bool(gd["tinted"])
		mm.mesh = gd["mesh"]
		mm.instance_count = gd["xf"].size()
		if gd["tinted"]:
			_use_vertex_colors(gd["mesh"], vc_cache)
		for i in gd["xf"].size():
			mm.set_instance_transform(i, gd["xf"][i])
			if gd["tinted"]:
				mm.set_instance_color(i, gd["col"][i])
		mmi.multimesh = mm
		if gd["small"]:
			mmi.visibility_range_end = 150.0
		elif gd["xf"].size() > 8:
			mmi.visibility_range_end = 420.0
		root.add_child(mmi)
	root.set_meta("path_cells", path_cells)
	root.set_meta("big_props", bigs)
	root.set_meta("own_meshes", own_meshes)
	root.set_meta("mushroom_pads", mushroom_pads)
	for dn in door_parts:
		for mi2 in meshes:
			if is_instance_valid(mi2) and String(mi2.name) == dn + "_glyph":
				door_parts[dn].append(mi2)
	root.set_meta("door_parts", door_parts)
	return {"bodies": bodies, "merged": merged, "groups": groups.size()}


## Marks the 1 m ground cells (x, z) under a path mesh.
static func _stamp_path(node: MeshInstance3D, cells: Dictionary) -> void:
	if node.mesh == null or node.mesh.get_surface_count() == 0:
		return
	var arr := node.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		for i in v.size():
			idx.append(i)
	var xf := node.global_transform
	for t in range(0, idx.size() - 2, 3):
		var a := xf * v[idx[t]]
		var b := xf * v[idx[t + 1]]
		var c := xf * v[idx[t + 2]]
		var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
		var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
		var d := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(d) < 0.0001:
			continue
		var x := lo.x
		while x <= hi.x:
			var z := lo.y
			while z <= hi.y:
				var w1 := ((b.z - c.z) * (x - c.x) + (c.x - b.x) * (z - c.z)) / d
				var w2 := ((c.z - a.z) * (x - c.x) + (a.x - c.x) * (z - c.z)) / d
				if w1 >= -0.1 and w2 >= -0.1 and w1 + w2 <= 1.1:
					cells[Vector2i(floori(x), floori(z))] = true
				z += 0.6
			x += 0.6


## What varies for each kind of repeated prop: size (`scale`), height stretch (plants only), `lean` (degrees), brightness (`val`), and a colour cast picked from `tints`
## (mixed `mix` of the way toward the cast, so the paint of the model still shows).
const VARIETY := [
	{"names": ["leafy_tree"], "scale": [0.8, 1.28], "lean": 3.0, "val": [0.78, 1.05], "mix": 0.65,
		"tints": [Color(0.8, 1.0, 0.7), Color(1.0, 1.0, 0.6), Color(0.65, 0.95, 0.85), Color(1.0, 0.78, 0.5), Color(1.0, 0.82, 0.9), Color(0.7, 1.0, 0.7), Color(1, 1, 1)]},
	{"names": ["snow_pine"], "scale": [0.8, 1.3], "lean": 3.0, "val": [0.8, 1.08], "mix": 0.5, "tints": [Color(0.9, 1.0, 1.0), Color(0.75, 0.95, 0.85), Color(0.85, 1.0, 0.8), Color(1, 1, 1), Color(0.8, 0.9, 1.0)]},
	{"names": ["dead_tree", "charred_tree"], "scale": [0.78, 1.3], "lean": 5.0, "val": [0.7, 1.12], "mix": 0.5, "tints": [Color(1.0, 0.9, 0.8), Color(0.85, 0.9, 1.0), Color(1, 1, 1), Color(0.9, 0.85, 0.95)]},
	{"names": ["swamp_tree", "mangrove"], "scale": [0.8, 1.3], "lean": 4.0, "val": [0.72, 1.1], "mix": 0.6, "tints": [Color(0.8, 1.0, 0.7), Color(0.7, 0.9, 0.8), Color(1.0, 0.95, 0.6), Color(0.85, 0.7, 1.0), Color(1, 1, 1)]},
	{"names": ["palm_tree"], "scale": [0.82, 1.25], "lean": 6.0, "val": [0.8, 1.08], "mix": 0.5, "tints": [Color(0.8, 1.0, 0.7), Color(1.0, 1.0, 0.7), Color(0.7, 1.0, 0.85), Color(1, 1, 1)]},
	{"names": ["giant_fern"], "scale": [0.7, 1.4], "lean": 6.0, "val": [0.75, 1.1], "mix": 0.7, "tints": [Color(0.7, 1.0, 0.6), Color(0.5, 1.0, 0.8), Color(1.0, 1.0, 0.55), Color(0.6, 0.85, 0.7), Color(0.9, 0.8, 1.0), Color(1, 1, 1)]},
	{"names": ["giant_flower"], "scale": [0.75, 1.4], "lean": 5.0, "val": [0.85, 1.1], "mix": 0.6, "tints": [Color(1.0, 0.6, 0.8), Color(1.0, 0.9, 0.4), Color(0.7, 0.8, 1.0), Color(0.9, 0.6, 1.0), Color(1.0, 0.65, 0.4), Color(1, 1, 1), Color(0.6, 1.0, 0.9)]},
	{"names": ["giant_mushroom", "glow_mushroom", "spore_pod"], "scale": [0.7, 1.4], "lean": 5.0, "val": [0.8, 1.1], "mix": 0.75,
		"tints": [Color(1.0, 0.5, 0.5), Color(1.0, 0.85, 0.4), Color(0.7, 0.6, 1.0), Color(0.6, 1.0, 0.9), Color(1.0, 0.6, 0.9), Color(0.7, 1.0, 0.5), Color(1, 1, 1)]},
	{"names": ["hollow_log"], "spin": false, "scale": [0.8, 1.25], "lean": 0.0, "val": [0.7, 1.1], "mix": 0.5, "tints": [Color(1, 1, 1), Color(0.9, 1.0, 0.9), Color(1.0, 0.9, 0.8), Color(0.9, 0.9, 1.0)]},
	{"names": ["ore_crag", "basalt_boulders", "rock_a", "rock"], "scale": [0.72, 1.45], "lean": 6.0, "val": [0.66, 1.15], "mix": 0.5,
		"tints": [Color(1, 1, 1), Color(0.9, 0.95, 1.0), Color(1.0, 0.92, 0.85), Color(0.85, 1.0, 0.9), Color(0.95, 0.9, 1.0), Color(1.0, 0.85, 0.75)]},
	{"names": ["stalagmite_cluster"], "scale": [0.75, 1.4], "lean": 3.0, "val": [0.65, 1.12], "mix": 0.55, "tints": [Color(1, 1, 1), Color(0.9, 0.9, 1.0), Color(1.0, 0.9, 1.0), Color(0.85, 1.0, 1.0)]},
	{"names": ["crystal_cluster", "crystal_spire"], "scale": [0.75, 1.45], "lean": 5.0, "val": [0.85, 1.1], "mix": 0.8,
		"tints": [Color(1.0, 0.6, 1.0), Color(0.6, 1.0, 1.0), Color(0.7, 0.7, 1.0), Color(0.7, 1.0, 0.7), Color(1.0, 0.8, 0.5), Color(1.0, 0.6, 0.7)]},
	{"names": ["ice_crystal"], "scale": [0.75, 1.4], "lean": 5.0, "val": [0.88, 1.1], "mix": 0.6, "tints": [Color(0.8, 0.95, 1.0), Color(0.7, 0.85, 1.0), Color(1, 1, 1), Color(0.8, 1.0, 0.95), Color(0.9, 0.85, 1.0)]},
	{"names": ["obsidian_crystal"], "scale": [0.75, 1.4], "lean": 5.0, "val": [0.8, 1.15], "mix": 0.55, "tints": [Color(1.0, 0.6, 0.5), Color(0.8, 0.6, 1.0), Color(0.6, 0.6, 0.75), Color(1, 1, 1)]},
	{"names": ["gravestone_rip", "grave_crosses"], "spin": false, "scale": [0.85, 1.18], "lean": 5.0, "val": [0.62, 1.1], "mix": 0.5, "tints": [Color(0.9, 1.0, 0.9), Color(1, 1, 1), Color(0.85, 0.9, 1.0), Color(1.0, 0.95, 0.85)]},
	{"names": ["giant_kelp"], "scale": [0.8, 1.35], "lean": 5.0, "val": [0.8, 1.1], "mix": 0.65, "tints": [Color(0.7, 1.0, 0.6), Color(0.5, 1.0, 0.8), Color(1.0, 0.9, 0.5), Color(0.9, 0.7, 1.0), Color(0.6, 0.9, 0.7)]},
	{"names": ["sea_anemone"], "scale": [0.75, 1.4], "lean": 5.0, "val": [0.85, 1.1], "mix": 0.75, "tints": [Color(1.0, 0.5, 0.7), Color(1.0, 0.7, 0.3), Color(0.7, 0.5, 1.0), Color(0.4, 1.0, 0.9), Color(1.0, 0.4, 0.4), Color(1, 1, 1)]},
	{"names": ["coral_reef"], "scale": [0.8, 1.3], "lean": 0.0, "val": [0.85, 1.1], "mix": 0.7, "tints": [Color(1.0, 0.5, 0.6), Color(1.0, 0.7, 0.3), Color(0.7, 0.5, 1.0), Color(0.5, 1.0, 0.9), Color(1.0, 1.0, 0.5), Color(1, 1, 1)]},
	{"names": ["giant_clam"], "scale": [0.8, 1.3], "lean": 0.0, "val": [0.8, 1.1], "mix": 0.5, "tints": [Color(1.0, 0.6, 0.8), Color(0.6, 0.9, 1.0), Color(1.0, 0.9, 0.6), Color(1, 1, 1)]},
	{"names": ["cloud_puff"], "scale": [0.75, 1.35], "lean": 0.0, "val": [0.88, 1.0], "mix": 0.8, "tints": [Color(1, 1, 1), Color(0.9, 0.95, 1.0), Color(1.0, 0.93, 0.95), Color(1.0, 0.98, 0.88)]},
	{"names": ["crate", "barrel"], "spin": false, "scale": [0.92, 1.1], "lean": 0.0, "val": [0.72, 1.08], "mix": 0.5, "tints": [Color(1, 1, 1), Color(1.0, 0.9, 0.8), Color(0.9, 0.95, 1.0), Color(0.9, 1.0, 0.9)]},
]


static func _variety_for(base: String) -> Dictionary:
	if base.contains("arch") or base.contains("wall") or base.contains("monolith") or base.contains("face") or base.contains("cliff"):
		return {}
	for v in VARIETY:
		for n in v["names"]:
			if base.contains(n):
				return v
	return {}


## Lets a model's materials take the colour of each instance (MultiMesh instance colours multiply the vertex colour, which is white where the model has none).
## The material is copied first: the original may be shared with the terrain or a building, which must not change.
static func _use_vertex_colors(mesh: Mesh, cache: Dictionary) -> void:
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m is BaseMaterial3D and not (m as BaseMaterial3D).vertex_color_use_as_albedo:
			if not cache.has(m):
				var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.vertex_color_use_as_albedo = true
				cache[m] = d
			mesh.surface_set_material(i, cache[m])


static func _trimesh_shape(mesh: Mesh, cache: Dictionary) -> Shape3D:
	var k := "t%d" % mesh.get_instance_id()
	if not cache.has(k):
		cache[k] = mesh.create_trimesh_shape()
	return cache[k]


static func _convex_shape(mesh: Mesh, cache: Dictionary) -> Shape3D:
	var k := "c%d" % mesh.get_instance_id()
	if not cache.has(k):
		cache[k] = mesh.create_convex_shape(true, true)
	return cache[k]


static func _trunk_shape(mesh: Mesh, cache: Dictionary) -> Shape3D:
	var k := "k%d" % mesh.get_instance_id()
	if not cache.has(k):
		var box := mesh.get_aabb()
		var s := CylinderShape3D.new()
		s.radius = maxf(0.25, minf(box.size.x, box.size.z) * 0.07)
		s.height = maxf(2.0, box.size.y * 0.6)
		cache[k] = s
	return cache[k]


## Painted sky per map (colours are sRGB): top, horizon, ground, clouds 0..1, night 0..1 (stars + moon), aurora 0..1, rays (underwater), sun colour.
const SKY := {
	"flora_forest": {"top": [0.16, 0.44, 0.92], "horizon": [0.84, 0.93, 0.86], "cloud": 0.52},
	"underwater_ocean": {"top": [0.02, 0.2, 0.38], "horizon": [0.12, 0.55, 0.62], "ground": [0.02, 0.15, 0.25], "cloud": 0.0, "rays": 1.0, "sun": [0.6, 0.95, 1.0]},
	"volcano_forge": {"top": [0.1, 0.04, 0.07], "horizon": [0.95, 0.4, 0.14], "ground": [0.2, 0.06, 0.04], "cloud": 0.7, "cloud_color": [0.35, 0.12, 0.1], "cloud_shadow": [0.12, 0.05, 0.06], "sun": [1.0, 0.55, 0.25]},
	"frozen_peaks": {"top": [0.1, 0.24, 0.62], "horizon": [0.82, 0.9, 0.98], "cloud": 0.38, "night": 0.3, "aurora": 0.8},
	"shadow_crypt": {"top": [0.04, 0.03, 0.1], "horizon": [0.3, 0.22, 0.42], "cloud": 0.5, "cloud_color": [0.35, 0.3, 0.5], "cloud_shadow": [0.12, 0.1, 0.2], "night": 0.9, "sun": [0.8, 0.7, 1.0], "aurora": 0.25, "aurora_color": [0.6, 0.3, 1.0]},
	"toxic_swamp": {"top": [0.12, 0.28, 0.2], "horizon": [0.62, 0.78, 0.4], "cloud": 0.78, "cloud_color": [0.62, 0.78, 0.5], "cloud_shadow": [0.25, 0.4, 0.25], "sun": [0.95, 0.95, 0.55]},
	"crystal_caves": {"top": [0.02, 0.03, 0.12], "horizon": [0.1, 0.16, 0.38], "cloud": 0.0, "night": 0.85, "sun": [0.55, 0.7, 1.0], "aurora": 0.45, "aurora_color": [0.2, 0.9, 1.0], "aurora_color2": [0.6, 0.4, 1.0]},
	"clockwork_mines": {"top": [0.1, 0.08, 0.12], "horizon": [0.55, 0.38, 0.24], "cloud": 0.75, "cloud_color": [0.4, 0.3, 0.25], "cloud_shadow": [0.15, 0.1, 0.1], "sun": [1.0, 0.75, 0.4]},
	"moon_sanctuary": {"top": [0.02, 0.03, 0.12], "horizon": [0.2, 0.2, 0.5], "cloud": 0.35, "cloud_color": [0.5, 0.55, 0.8], "cloud_shadow": [0.15, 0.18, 0.32], "night": 1.0, "sun": [0.75, 0.82, 1.0], "aurora": 0.55, "aurora_color": [0.4, 0.8, 1.0], "aurora_color2": [0.8, 0.4, 1.0]},
	"desert_tomb": {"top": [0.2, 0.48, 0.9], "horizon": [0.99, 0.86, 0.6], "cloud": 0.22, "cloud_color": [1.0, 0.95, 0.85], "sun": [1.0, 0.88, 0.6]},
	"pirate_cove": {"top": [0.14, 0.46, 0.95], "horizon": [0.86, 0.94, 1.0], "cloud": 0.58},
	"chess_arena": {"top": [0.14, 0.12, 0.38], "horizon": [0.92, 0.68, 0.66], "cloud": 0.45, "cloud_color": [1.0, 0.8, 0.82], "cloud_shadow": [0.5, 0.4, 0.62], "sun": [1.0, 0.82, 0.6]},
	"sky_islands": {"top": [0.12, 0.42, 0.95], "horizon": [0.8, 0.92, 1.0], "ground": [0.7, 0.82, 0.95], "cloud": 0.72, "sun": [1.0, 0.95, 0.8]},
}

static var _sky_noise: ImageTexture


static func _c(a: Array, fallback: Color) -> Color:
	return Color(a[0], a[1], a[2]) if a.size() >= 3 else fallback


static func _noise_texture() -> ImageTexture:
	if _sky_noise == null:
		var n := FastNoiseLite.new()
		n.seed = 5
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.01
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		var a := n.get_seamless_image(256, 256)
		n.seed = 17
		n.frequency = 0.018
		var b := n.get_seamless_image(256, 256)
		var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
		for y in 256:
			for x in 256:
				img.set_pixel(x, y, Color(a.get_pixel(x, y).r, b.get_pixel(x, y).r, a.get_pixel(255 - x, y).r))
		_sky_noise = ImageTexture.create_from_image(img)
	return _sky_noise


## Maps with pale ground (sand, snow, marble) are turned down a little so the ground keeps its colour instead of burning out to white.
## Dark maps get a floor under their ambient light, so shadowed ground and characters are not pitch black next to bright glowing things (that was the harsh contrast).
const AMBIENT_FLOOR := {"crystal_caves": 0.62, "shadow_crypt": 0.5, "moon_sanctuary": 0.55, "volcano_forge": 0.5}
const EXPOSURE := {"pirate_cove": 0.66, "desert_tomb": 0.74, "frozen_peaks": 0.84, "underwater_ocean": 0.78, "sky_islands": 0.88, "chess_arena": 0.86, "shadow_crypt": 0.82,
	"moon_sanctuary": 0.9, "flora_forest": 0.94}

## Sun, painted sky, ambient light, fog, glow and a gentle colour grade from the map's data; a cool fill light opposite the sun.
static func apply_environment(parent: Node3D, map_id: String) -> void:
	var env_data: Dictionary = Data.maps[map_id].get("env", {})
	var env := Environment.new()
	var sky_a: Array = env_data.get("sky", [0.5, 0.7, 0.9])
	var sky_col := Color(sky_a[0], sky_a[1], sky_a[2])
	var style: Dictionary = SKY.get(map_id, {})
	var sun_a: Array = env_data.get("color", [1, 1, 1])
	var sun_col := Color(sun_a[0], sun_a[1], sun_a[2])
	var pitch := float(env_data.get("pitch", 50))
	var yaw := float(env_data.get("yaw", 30))
	var basis := Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(-yaw + 180.0), 0.0))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fantasy_sky.gdshader")
	mat.set_shader_parameter("top_color", _c(style.get("top", []), sky_col.darkened(0.35)))
	mat.set_shader_parameter("horizon_color", _c(style.get("horizon", []), sky_col.lerp(Color.WHITE, 0.3)))
	mat.set_shader_parameter("ground_color", _c(style.get("ground", []), sky_col.darkened(0.5)))
	mat.set_shader_parameter("sun_color", _c(style.get("sun", []), sun_col))
	mat.set_shader_parameter("sun_dir", basis.z)
	mat.set_shader_parameter("night", float(style.get("night", 0.0)))
	mat.set_shader_parameter("cloud_amount", float(style.get("cloud", 0.4)))
	mat.set_shader_parameter("cloud_color", _c(style.get("cloud_color", []), Color(1, 1, 1)))
	mat.set_shader_parameter("cloud_shadow", _c(style.get("cloud_shadow", []), Color(0.55, 0.62, 0.78)))
	mat.set_shader_parameter("aurora", float(style.get("aurora", 0.0)))
	mat.set_shader_parameter("aurora_color", _c(style.get("aurora_color", []), Color(0.3, 1.0, 0.7)))
	mat.set_shader_parameter("aurora_color2", _c(style.get("aurora_color2", []), Color(0.6, 0.3, 1.0)))
	mat.set_shader_parameter("rays", float(style.get("rays", 0.0)))
	mat.set_shader_parameter("noise", _noise_texture())
	var sky := Sky.new()
	sky.sky_material = mat
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL      # the sky moves, so it would be redrawn into its reflection map every frame: do one face per frame instead
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var amb := sky_col.lerp(Color.WHITE, 0.45)
	env.ambient_light_color = amb
	env.ambient_light_energy = maxf(float(env_data.get("ambient", 1.0)) * 0.9, float(AMBIENT_FLOOR.get(map_id, 0.0)))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(OS.get_environment("EXPOSURE")) if OS.get_environment("EXPOSURE") != "" else float(EXPOSURE.get(map_id, 1.0))
	# a soft glow around bright things and a slightly richer, more saturated picture
	var lite := OS.get_environment("FX_LITE") != ""
	env.glow_enabled = false
	env.glow_intensity = 0.55
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.03
	env.fog_sky_affect = 0.2
	if env_data.has("fog"):
		var f: Array = env_data["fog"]
		env.fog_enabled = true
		env.fog_light_color = Color(f[0], f[1], f[2])
		env.fog_density = float(f[3])
	else:
		env.fog_enabled = true
		env.fog_light_color = _c(style.get("horizon", []), sky_col).lerp(Color.WHITE, 0.15)
		env.fog_density = 0.0006
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = sun_col
	sun.light_energy = float(env_data.get("energy", 1.2))
	sun.shadow_enabled = Settings.quality() > 0
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 2.6                  # keeps the striped "shadow acne" off flat ground (the dirt paths) when the sun is low
	sun.directional_shadow_max_distance = [40.0, 60.0, 80.0][Settings.quality()]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.rotation_degrees = Vector3(-pitch, -yaw + 180.0, 0)
	parent.add_child(sun)
	# a cool fill from the other side so shadows are blue-violet instead of grey
	var fill := DirectionalLight3D.new()
	fill.light_color = _c(style.get("top", []), Color(0.5, 0.6, 1.0)).lerp(Color(0.6, 0.65, 1.0), 0.5)
	fill.light_energy = 0.28
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-30.0, -yaw, 0)
	parent.add_child(fill)



## Glowing materials in the map files are very strong with a white glow colour (the crystal pads of the Crystal Caves burn out to flat white, and so do the jump pad discs).
## Their glow is tinted by the colour in their name, kept under 1.0 and, when the surface itself is very bright, reduced further.
const GLOW_TINT := {"violet": Color(0.62, 0.38, 1.0), "cyan": Color(0.25, 0.9, 1.0), "magenta": Color(1.0, 0.3, 0.85), "lime": Color(0.6, 1.0, 0.3), "orange": Color(1.0, 0.55, 0.2),
	"blue": Color(0.3, 0.5, 1.0), "pink": Color(1.0, 0.5, 0.75), "amber": Color(1.0, 0.7, 0.25), "teal": Color(0.2, 0.85, 0.75), "green": Color(0.4, 1.0, 0.5), "red": Color(1.0, 0.35, 0.3)}


static func _tame_emission(m: BaseMaterial3D) -> void:
	if not m.emission_enabled:
		return
	var name := String(m.resource_name).to_lower()
	var white := m.emission.get_luminance() > 0.8 and (m.emission.s < 0.2)
	if white:
		for k in GLOW_TINT:
			if name.contains(k):
				m.emission = GLOW_TINT[k]
				m.albedo_color = m.albedo_color.lerp(GLOW_TINT[k], 0.55)
				break
	m.emission_energy_multiplier = minf(m.emission_energy_multiplier, 0.85 if white else 1.2)


## The dirt of the paths has a strong ridged normal map that looks like stripes of shadow in low sun: it is turned down (once per material).
static func _soften_path(node: MeshInstance3D, cache: Dictionary) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF          # a path lies a few centimetres above the ground: its own shadow on itself made stripes
	if node.mesh == null:
		return
	for s in node.mesh.get_surface_count():
		var m := node.mesh.surface_get_material(s)
		if m is BaseMaterial3D and (m as BaseMaterial3D).normal_enabled:
			if not cache.has(m):
				var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				d.normal_scale = minf(d.normal_scale, 0.12)
				d.roughness = maxf(d.roughness, 0.95)
				d.albedo_color = d.albedo_color * Color(0.78, 0.76, 0.74, 1.0)
				cache[m] = d
			node.mesh.surface_set_material(s, cache[m])


## The point lights in the map files carry the unscaled values of the modelling program (energies of 100 000 and more), which burn everything within their range to flat white
## (the Crystal Caves, Shadow Crypt and Moon Sanctuary). Here they get a soft, sensible strength; the colour and range from the file are kept.
const LIGHT_ENERGY := 2.2


static func _tame_lights(root: Node) -> void:
	for n in root.find_children("*", "Light3D", true, false):
		if n is OmniLight3D:
			var l := n as OmniLight3D
			if l.light_energy > 8.0:
				l.light_energy = LIGHT_ENERGY
			l.light_specular = 0.3
			l.omni_attenuation = 1.3
			l.distance_fade_enabled = true                          # lights far from the camera are switched off (a map has up to 35 of them)
			l.distance_fade_begin = 36.0
			l.distance_fade_length = 14.0
			l.shadow_enabled = false
		elif n is SpotLight3D and (n as SpotLight3D).light_energy > 8.0:
			(n as SpotLight3D).light_energy = LIGHT_ENERGY
