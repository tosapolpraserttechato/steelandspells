extends SceneTree
# Makes the boots rigid: every vertex near or below the ankle follows only its foot bone (the toe bone is dropped), blending up the shin,
# so the shoes no longer stretch when the legs move. Writes models/classes/fixed/<class>_body.res.
#   godot --headless --path game --script res://tools/fix_feet.gd
const CLASSES := ["druid", "sea_king", "flame_lord", "frost_mage", "thunder_god", "desert_assassin", "necromancer", "arcanist", "poison_brewer", "pirate_captain", "time_mage", "celestial_mage", "gm_ravn"]
const BLEND := 0.14          # metres above the ankle over which the rigid weight fades out

func _init() -> void:
	for cls in CLASSES:
		_fix(cls)
	quit()

func _fix(cls: String) -> void:
	var packed: PackedScene = load("res://models/classes/class_%s.glb" % cls)
	var root: Node3D = packed.instantiate()
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = null
	for m in root.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).skin != null:
			mi = m
	if mi == null:
		print("NO SKINNED MESH ", cls)
		return
	var skin: Skin = mi.skin
	var bind_of := {}
	for i in skin.get_bind_count():
		bind_of[skin.get_bind_name(i)] = i
	var foot_ids := {}
	var toe_ids := {}
	var foot_y := {}
	var foot_xz := {}
	for side in ["L", "R"]:
		var fb := skel.find_bone("DEF-foot." + side)
		var tb := skel.find_bone("DEF-toe." + side)
		var rest := skel.get_bone_global_rest(fb)
		foot_ids[side] = bind_of.get("DEF-foot." + side, -1)
		toe_ids[side] = bind_of.get("DEF-toe." + side, -1)
		foot_y[side] = rest.origin.y
		foot_xz[side] = Vector2(rest.origin.x, rest.origin.z)
	var mesh: ArrayMesh = mi.mesh as ArrayMesh
	var out := ArrayMesh.new()
	var changed := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if bones.is_empty():
			var fmt := mesh.surface_get_format(s)
			out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, [], {}, fmt)
			out.surface_set_material(s, mesh.surface_get_material(s))
			continue
		var bpv := bones.size() / verts.size()
		for v in verts.size():
			var p := verts[v]
			var side := "L" if Vector2(p.x, p.z).distance_to(foot_xz["L"]) < Vector2(p.x, p.z).distance_to(foot_xz["R"]) else "R"
			if Vector2(p.x, p.z).distance_to(foot_xz[side]) > 0.45:
				continue
			var above: float = p.y - float(foot_y[side])
			var w_foot := clampf(1.0 - above / BLEND, 0.0, 1.0) if above > 0.0 else 1.0
			if p.y > float(foot_y[side]) + BLEND:
				continue
			# gather the existing influences, move toe weight to the foot, scale the rest down, add the rigid foot weight
			var acc := {}
			for k in bpv:
				var b := bones[v * bpv + k]
				var w := weights[v * bpv + k]
				if w <= 0.0:
					continue
				if b == int(toe_ids[side]):
					b = int(foot_ids[side])
				acc[b] = float(acc.get(b, 0.0)) + w * (1.0 - w_foot)
			acc[int(foot_ids[side])] = float(acc.get(int(foot_ids[side]), 0.0)) + w_foot
			var keys := acc.keys()
			keys.sort_custom(func(a: int, b: int) -> bool: return acc[a] > acc[b])
			var total := 0.0
			for k in mini(bpv, keys.size()):
				total += float(acc[keys[k]])
			for k in bpv:
				if k < keys.size():
					bones[v * bpv + k] = int(keys[k])
					weights[v * bpv + k] = float(acc[keys[k]]) / total
				else:
					bones[v * bpv + k] = 0
					weights[v * bpv + k] = 0.0
			changed += 1
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		var format := mesh.surface_get_format(s)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(s), arrays, [], {}, format)
		out.surface_set_material(s, mesh.surface_get_material(s))
	var err := ResourceSaver.save(out, "res://models/classes/fixed/%s_body.res" % cls)
	print("FIXED ", cls, " vertices changed ", changed, " save ", err)
