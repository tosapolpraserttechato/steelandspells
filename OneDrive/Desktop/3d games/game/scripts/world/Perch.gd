class_name Perch
extends RefCounted
## Sniper perches: on each side of every map a ledge juts out of the high wall beyond the play area, 8-12 m above the ground, with a jump pad on the floor
## below that throws you up onto it. From there you can see (and shoot) across the whole map: hold aim for a second for a sniper shot (see WeaponRunner).
## Besides the pad there is a ladder up the front of the ledge and, where the rim is steep, stepped slabs beside it (2 m apart, a double jump apart); wherever the rim
## has a real cliff there is a ladder and a jump pad up that too. Built once the map has its collision, from rays shot at the rim. The look of everything is PerchDress.

const LEDGE := Vector3(6.0, 0.6, 4.2)
const STEP := Vector3(2.8, 0.5, 2.4)              # one slab of the stairs up the wall
const STEP_RISE := 2.0                            # height between slabs: a double jump reaches 2.5 m


static func build(host: Match, map_root: Node3D, map_size: Vector2) -> void:
	if map_size.x <= 0.0:
		return
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	if not is_instance_valid(host) or not is_instance_valid(map_root):
		return
	var space := host.get_world_3d().direct_space_state
	var half := map_size * 0.5
	var made := 0
	# four sides: +x, -x, +z, -z; two perches on each, either side of the middle
	for side in 4:
		var dir := Vector2.ZERO
		match side:
			0: dir = Vector2(1, 0)
			1: dir = Vector2(-1, 0)
			2: dir = Vector2(0, 1)
			3: dir = Vector2(0, -1)
		var along := Vector2(-dir.y, dir.x)
		for k in [-1.0, 1.0]:
			var lateral: float = k * 0.34 * (map_size.y if absf(dir.x) > 0.5 else map_size.x)
			var edge := Vector2(dir.x * half.x, dir.y * half.y) + along * lateral
			var spot := _find_wall(space, edge, dir, half)
			if spot.is_empty():
				continue
			_make_ledge(host, map_root, space, spot["pos"], dir, spot["floor"], int(k))
			_make_steps(host, map_root, space, dir, along * k, spot["pos"], spot["floor"])
			made += 1
	var cliffs := _make_cliff_routes(host, map_root, space, map_size)
	if OS.get_environment("TOAST_DEBUG") != "":
		print("PERCHES ", host.map_id, " ", made, " cliff routes ", cliffs)


## Walks outward from the edge of the play area until the ground has climbed 9+ m above the floor; returns the ledge position and the floor height at the edge.
static func _find_wall(space: PhysicsDirectSpaceState3D, edge: Vector2, dir: Vector2, half: Vector2) -> Dictionary:
	var floor_y := _ground(space, edge - dir * 4.0)
	if floor_y < -900.0:
		return {}
	for d in range(2, 46, 2):
		var p := edge + dir * float(d)
		var y := _ground(space, p)
		if y > floor_y + 9.5:
			# the ledge sticks out of the wall at 9 m (a bit more on the rim's steep walls)
			var pos := Vector3(p.x - dir.x * 2.2, floor_y + 9.0, p.y - dir.y * 2.2)
			return {"pos": pos, "floor": floor_y}
	return {}


static func _ground(space: PhysicsDirectSpaceState3D, p: Vector2) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 300.0, p.y), Vector3(p.x, -120.0, p.y), 1)
	var r := space.intersect_ray(q)
	return float(r["position"].y) if not r.is_empty() else -999.0


## Stepped slabs up the rim beside a perch (2 m apart, so a double jump reaches each from the last): the way up for those who skip the jump pad. They climb away from the
## perch towards the corner, `outward` being the direction along the wall that goes that way. A second jump pad on the floor throws you straight to the third slab.
## Where the rim is a gentle slope the slabs would be buried in it and there are no stairs at all: you can simply walk up there.
static func _make_steps(host: Match, map_root: Node3D, space: PhysicsDirectSpaceState3D, dir: Vector2, outward: Vector2, ledge_pos: Vector3, floor_y: float) -> void:
	var spots: Array = []
	for j in [1, 2, 3, 4]:
		var top: float = floor_y + STEP_RISE * float(j)
		var c := Vector2(ledge_pos.x, ledge_pos.z) + outward * (5.0 + 3.8 * float(4 - j))     # in line with the perch, so the gaps stay even
		var g := _ground(space, c)
		if g < -900.0 or g > top - 0.6:
			return
		spots.append({"xz": c, "top": top})
	var st := PerchDress.style(host.map_id)
	for s in spots:
		var c: Vector2 = s["xz"]
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		map_root.add_child(body)
		body.global_position = Vector3(c.x, float(s["top"]) - STEP.y * 0.5, c.y)
		body.rotation.y = atan2(dir.x, dir.y)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = STEP
		cs.shape = bs
		body.add_child(cs)
		PerchDress.dress_step(body, st, STEP)
	var landing: Vector2 = spots[2]["xz"]
	var pad_xz := landing - dir * 7.0
	var gy := _ground(space, pad_xz)
	if gy > -900.0 and absf(gy - floor_y) < 2.5:
		_make_pad(host, Vector3(pad_xz.x, gy + 0.2, pad_xz.y), Vector3(landing.x, float(spots[2]["top"]) + 0.9, landing.y), 1.05, "step_pad")


## Ladders and jump pads up the real cliffs of the rim: wherever the ground jumps up by 5+ m within a metre or so (and stays up), a ladder hangs on the face (walk into
## it to climb, Space kicks off, the top hops you over the lip) and a jump pad on the floor in front throws you up to the top. Two tries on each side of the map.
static func _make_cliff_routes(host: Match, map_root: Node3D, space: PhysicsDirectSpaceState3D, map_size: Vector2) -> int:
	var half := map_size * 0.5
	var st := PerchDress.style(host.map_id)
	var made := 0
	for side in 4:
		var dir := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)][side] as Vector2
		var along := Vector2(-dir.y, dir.x)
		var length := map_size.y if absf(dir.x) > 0.5 else map_size.x
		for frac in [-0.16, 0.16]:
			var edge := Vector2(dir.x * half.x, dir.y * half.y) + along * (float(frac) * length)
			var cliff := _find_cliff(space, edge, dir)
			if cliff.is_empty():
				continue
			var face: Vector2 = cliff["face"]
			var foot_y := _ground(space, face - dir * 0.5)
			var top: float = cliff["top"]
			LadderNode.make(host, Vector3(face.x - dir.x * 0.2, foot_y, face.y - dir.y * 0.2), -dir, top - foot_y, st["trim"], st["rung"])
			var pad_xz := face - dir * 8.0
			var gy := _ground(space, pad_xz)
			if gy > -900.0:
				var land := Vector3(face.x + dir.x * 2.0, top + 0.9, face.y + dir.y * 2.0)
				_make_pad(host, Vector3(pad_xz.x, gy + 0.2, pad_xz.y), land, clampf(0.8 + 0.06 * (land.y - gy), 1.0, 2.0), "cliff_pad")
			made += 1
			if OS.get_environment("TOAST_DEBUG") != "":
				print("CLIFF side ", side, " face ", Vector3(face.x, foot_y, face.y).snapped(Vector3(0.1, 0.1, 0.1)), " top ", snappedf(top, 0.1))
	return made


## Walks outward from the edge of the play area until the ground jumps up by more than 3.5 m between two samples a metre apart and stays at least that high for 3 m more
## (so a tree trunk or a boulder is not a cliff). Only cliffs close to the arena count. Returns the face (found to a few cm) and the lowest height of the top.
static func _find_cliff(space: PhysicsDirectSpaceState3D, edge: Vector2, dir: Vector2) -> Dictionary:
	var prev := _ground(space, edge - dir * 4.0)
	if prev < -900.0:
		return {}
	var floor0 := prev
	var d := -3.0
	while d < 16.0:
		var cur := _ground(space, edge + dir * d)
		if cur < -900.0:
			return {}
		if cur - prev > 3.5 and prev - floor0 < 14.0:
			var top := cur
			for k in [1.0, 2.0, 3.0]:
				var g := _ground(space, edge + dir * (d + k))
				if g < prev + (cur - prev) * 0.6:
					return {}                                    # a narrow thing, not a cliff
				top = minf(top, g)
			if top - prev < 5.0 or top - prev > 36.0:
				return {}
			var lo := d - 1.0
			var hi := d
			for i in 6:
				var mid := (lo + hi) * 0.5
				if _ground(space, edge + dir * mid) > prev + (top - prev) * 0.5:
					hi = mid
				else:
					lo = mid
			return {"face": edge + dir * ((lo + hi) * 0.5), "top": top}
		prev = cur
		d += 1.0
	return {}


static func _make_pad(host: Match, at: Vector3, land: Vector3, seconds: float, pad_name: String) -> void:
	var marker := {"kind": "jump_pad", "pos": at, "radius": 1.6, "launch_seconds": seconds, "name": pad_name, "quiet": true}
	var h := HazardNode.new()
	host.add_child(h)
	h.setup(marker, host)
	h._target = land
	host.hazards.append(h)


static func _make_ledge(host: Match, map_root: Node3D, space: PhysicsDirectSpaceState3D, pos: Vector3, dir: Vector2, floor_y: float, k: int) -> void:
	var yaw := atan2(dir.x, dir.y)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	map_root.add_child(body)
	body.global_position = pos
	body.rotation.y = yaw
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = LEDGE
	cs.shape = bs
	body.add_child(cs)
	var st := PerchDress.style(host.map_id)
	# where the ladder up the front of the ledge stands (on the side away from the stairs), and so how far the floor is below
	var front := Vector2(pos.x, pos.z) - dir * (LEDGE.z * 0.5)
	var along := Vector2(-dir.y, dir.x)
	var foot_xz := front - along * float(k) * 1.8
	var foot_y := _ground(space, foot_xz + (-dir) * 0.6)
	if foot_y < -900.0:
		foot_y = floor_y
	body.set_meta("map_id", host.map_id)
	PerchDress.dress_ledge(body, st, LEDGE, -float(k), pos.y - foot_y, int(absf(pos.x * 7.0 + pos.z * 13.0)))
	var list: Array = host.get_meta("perch_list", [])                       # for the test script action perch:N
	list.append({"pos": pos, "dir": dir, "floor": floor_y})
	host.set_meta("perch_list", list)
	# the jump pad on the floor, 9 m in front of the wall, throwing you up onto the ledge
	var pad_xz := Vector2(pos.x, pos.z) - dir * 9.0
	var pad_y := floor_y + 0.2
	var land := pos + Vector3(-dir.x * 0.2, 0.9, -dir.y * 0.2)
	_make_pad(host, Vector3(pad_xz.x, pad_y, pad_xz.y), land, 1.25, "perch_pad")
	if OS.get_environment("TOAST_DEBUG") != "":
		print("PERCH_AT ledge ", pos.snapped(Vector3(0.1, 0.1, 0.1)), " pad ", Vector3(pad_xz.x, pad_y, pad_xz.y).snapped(Vector3(0.1, 0.1, 0.1)))
	# the ladder: walk into it to climb, and at the top you hop onto the ledge
	var height := pos.y + LEDGE.y * 0.5 - foot_y
	if height > 2.5 and height < 16.0:
		LadderNode.make(host, Vector3(foot_xz.x, foot_y, foot_xz.y), -dir, height, st["trim"], st["rung"])
		if OS.get_environment("TOAST_DEBUG") != "":
			print("LADDER foot ", Vector3(foot_xz.x, foot_y, foot_xz.y).snapped(Vector3(0.1, 0.1, 0.1)), " height ", snappedf(height, 0.1), " out ", -dir)
