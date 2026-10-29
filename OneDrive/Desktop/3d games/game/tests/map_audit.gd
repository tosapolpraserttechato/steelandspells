extends Node3D
## Looks at a map for two kinds of mistakes: water (or other liquid) that hangs above the ground it should lie on, and solid-looking objects that have no collision.
##   godot --headless --path game res://tests/map_audit.tscn -- map=desert_tomb
## Prints WATER lines (water height vs the ground under its footprint) and NOCOL lines (objects at least 1 m wide and 0.3 m high that a ray from above passes through).

var _map := "desert_tomb"
var _root: Node3D
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv[0] == "map":
			_map = kv[1]
	var built := MapLoader.build(self, _map)
	_root = built["root"]


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _frames < 3:
		return
	var space := get_world_3d().direct_space_state
	var seen := {}
	for c in _root.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		var name := String(mi.name)
		var base := MapLoader._base_name(name)
		var bb := mi.global_transform * mi.get_aabb()
		if base.contains("water") or base.contains("lava_river"):
			var low := 1e9
			var high := -1e9
			var misses := 0
			for i in 7:
				for j in 7:
					var x := bb.position.x + bb.size.x * (float(i) + 0.5) / 7.0
					var z := bb.position.z + bb.size.z * (float(j) + 0.5) / 7.0
					var q := PhysicsRayQueryParameters3D.create(Vector3(x, bb.end.y + 60.0, z), Vector3(x, bb.position.y - 60.0, z), 1)
					var hit := space.intersect_ray(q)
					if hit.is_empty():
						misses += 1
						continue
					low = minf(low, hit["position"].y)
					high = maxf(high, hit["position"].y)
			var rim_low := 1e9
			var rim_high := -1e9
			for k in 16:
				var ang := TAU * float(k) / 16.0
				var rx := bb.get_center().x + cos(ang) * (bb.size.x * 0.5 + 1.2)
				var rz := bb.get_center().z + sin(ang) * (bb.size.z * 0.5 + 1.2)
				var rq := PhysicsRayQueryParameters3D.create(Vector3(rx, bb.end.y + 60.0, rz), Vector3(rx, bb.position.y - 60.0, rz), 1)
				var rh := space.intersect_ray(rq)
				if not rh.is_empty():
					rim_low = minf(rim_low, rh["position"].y)
					rim_high = maxf(rim_high, rh["position"].y)
			print("WATER_RIM ", name, " ground just outside the footprint: ", snappedf(rim_low, 0.01), " .. ", snappedf(rim_high, 0.01), " (surface ", snappedf(bb.position.y, 0.01), ")")
			print("WATER ", name, " surface y ", snappedf(bb.position.y, 0.01), " ground y ", snappedf(low, 0.01), " .. ", snappedf(high, 0.01), " footprint ", snappedf(bb.size.x, 0.1), " x ", snappedf(bb.size.z, 0.1),
				" | hangs above ground by up to ", snappedf(bb.position.y - low, 0.01), " m, sinks into ground by up to ", snappedf(high - bb.position.y, 0.01), " m (", misses, " rays missed)")
			continue
		if bb.size.x < 1.0 and bb.size.z < 1.0 or bb.size.y < 0.3 or MapLoader._matches(base, MapLoader.NO_COLLISION) or base == "terrain":
			continue
		var cx := bb.position.x + bb.size.x * 0.5
		var cz := bb.position.z + bb.size.z * 0.5
		var top := bb.end.y
		var q2 := PhysicsRayQueryParameters3D.create(Vector3(cx, top + 8.0, cz), Vector3(cx, top - 3.0, cz), 1)
		var h2 := space.intersect_ray(q2)
		var solid := not h2.is_empty() and float(h2["position"].y) > bb.position.y + bb.size.y * 0.35
		if not solid:                                                    # hollow things (a gate, a frame) have no top at the centre: try four horizontal rays at the middle height from outside
			var mid := bb.position.y + bb.size.y * 0.5
			for dir: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
				var reach := (bb.size.x if absf(dir.x) > 0.5 else bb.size.z) * 0.5 + 3.0
				var from := Vector3(cx, mid, cz) + dir * reach
				var side := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, Vector3(cx, mid, cz), 1))
				if not side.is_empty():
					solid = true
					break
		if not solid:
			var key := base
			if not seen.has(key):
				seen[key] = 0
			seen[key] = int(seen[key]) + 1
			if int(seen[key]) <= 2:
				print("NOCOL ", name, " size ", bb.size.snapped(Vector3(0.1, 0.1, 0.1)), " at ", Vector3(cx, bb.position.y, cz).snapped(Vector3(0.1, 0.1, 0.1)))
	for k in seen:
		print("NOCOL_KIND ", k, " x", seen[k])
	get_tree().quit()
