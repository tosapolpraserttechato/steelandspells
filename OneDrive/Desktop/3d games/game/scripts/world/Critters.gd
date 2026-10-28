class_name Critters
extends Node3D
## Small animals that live in each map: bunnies and frogs hop, mice, lizards, beetles, crabs and penguins scurry and waddle, butterflies, dragonflies, birds and
## bats fly, fish and jellyfish swim. They are only for life: no collision, nothing can hurt them. They wander around the place they were born, and run (or fly)
## away from any fighter who comes close. Meshes: CritterMesh.gd.

# map -> [kind, how many, colour schemes]
const SPECS := {
	"flora_forest": [["bunny", 8, [0, 1, 2, 3]], ["butterfly", 18, [0, 1, 2, 3, 4]], ["bird", 7, [0, 1, 3, 4]], ["frog", 4, [0, 2]], ["mouse", 4, [1, 2]]],
	"toxic_swamp": [["frog", 12, [0, 1, 2]], ["dragonfly", 14, [0, 1, 2, 3]], ["beetle", 6, [0, 2]]],
	"underwater_ocean": [["fish", 36, [0, 1, 2, 3, 4]], ["jellyfish", 8, [0, 1, 2, 3]], ["crab", 10, [0, 1, 2]]],
	"frozen_peaks": [["penguin", 10, [0, 1, 2]], ["bunny", 8, [0]], ["bird", 4, [2]]],
	"volcano_forge": [["lizard", 9, [2]], ["beetle", 10, [2, 4]], ["bat", 5, [1]]],
	"desert_tomb": [["beetle", 14, [0, 1, 4]], ["lizard", 10, [0]], ["bird", 4, [2]]],
	"sky_islands": [["bird", 16, [0, 1, 2, 3, 4]], ["butterfly", 14, [0, 1, 2, 3, 5]], ["bunny", 6, [0, 2]]],
	"shadow_crypt": [["bat", 14, [0, 1, 2]], ["mouse", 10, [0, 1, 3]], ["beetle", 5, [3]]],
	"crystal_caves": [["bat", 9, [3, 2]], ["beetle", 14, [3, 0]], ["mouse", 4, [0]]],
	"clockwork_mines": [["mouse", 10, [0, 1, 3]], ["beetle", 9, [4, 1]], ["bat", 4, [1]]],
	"moon_sanctuary": [["butterfly", 18, [4, 5]], ["bunny", 8, [0, 2]], ["bird", 3, [2]]],
	"pirate_cove": [["crab", 16, [0, 1, 2]], ["bird", 14, [2]], ["lizard", 4, [0, 1]]],
}
# how the ground animals move: speed (m/s), the distance at which they run from a fighter, hop = [height, length, seconds], rest = [min, max] seconds standing still
const WALK := {
	"bunny": {"speed": 1.6, "flee": 8.0, "hop": [0.22, 0.55, 0.34], "rest": [1.5, 5.0]},
	"frog": {"speed": 1.1, "flee": 4.5, "hop": [0.16, 0.38, 0.3], "rest": [2.0, 7.0]},
	"mouse": {"speed": 1.3, "flee": 5.0, "rest": [0.8, 3.0]},
	"lizard": {"speed": 1.4, "flee": 6.0, "rest": [1.0, 4.0]},
	"beetle": {"speed": 0.4, "flee": 3.0, "rest": [1.0, 4.0]},
	"crab": {"speed": 0.8, "flee": 4.5, "rest": [1.0, 4.0], "side": true},
	"penguin": {"speed": 0.8, "flee": 4.0, "rest": [1.5, 5.0], "waddle": true},
}
const FLYERS := ["butterfly", "dragonfly", "bird", "bat"]
const WANDER := 7.0

var _match: Node
var _half: Vector2
var _rng := RandomNumberGenerator.new()
var _items: Array = []
var _threats: Array = []
var _t := 0.0
var _mats: Dictionary = {}
var _space: PhysicsDirectSpaceState3D


static func attach(host: Node3D, map_id: String, map_size: Vector2, markers: Array) -> void:
	if not SPECS.has(map_id):
		return
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	if not is_instance_valid(host):
		return
	var c := Critters.new()
	c.name = "Critters"
	host.add_child(c)
	c._setup(host, map_id, map_size, markers)


func _setup(host: Node, map_id: String, map_size: Vector2, markers: Array) -> void:
	_match = host
	_half = map_size * 0.5 - Vector2(6, 6)
	_space = get_world_3d().direct_space_state
	_rng.seed = map_id.hash() + 77
	var spawns: Array = []
	for m in markers:
		spawns.append(m["pos"])
	for spec in SPECS[map_id]:
		var kind: String = spec[0]
		var left: int = maxi(1, int(float(spec[1]) * [0.4, 0.75, 1.0][Settings.quality()]))
		var vars: Array = spec[2]
		var group := 4 if kind in ["fish", "butterfly", "bird", "bat", "dragonfly"] else 3
		while left > 0:
			var n := mini(left, _rng.randi_range(maxi(1, group - 1), group + 1))
			left -= n
			var centre := _group_centre(kind, spawns)
			if centre.y < -900.0:
				continue
			var v: int = vars[_rng.randi() % vars.size()]
			for i in n:
				var home := centre + Vector3(_rng.randf_range(-2.5, 2.5), 0, _rng.randf_range(-2.5, 2.5))
				var gy := _ground(home)
				if gy.is_empty():
					home = centre
				else:
					home = gy["position"]
				_add(kind, v if _rng.randf() < 0.7 else vars[_rng.randi() % vars.size()], home, centre)
	print("CRITTERS ", map_id, " ", _items.size())
	if OS.get_environment("CRITTER_DEBUG") != "":
		for it in _items:
			if it["kind"] in WALK:
				print("CRITTER_AT ", it["kind"], " ", (it["pos"] as Vector3).snapped(Vector3(0.1, 0.1, 0.1)))
				break


## A place for a group: half of the groups near a marker (where the fighting is), the rest anywhere on the ground. y < -900 means none was found.
func _group_centre(kind: String, spawns: Array) -> Vector3:
	for attempt in 30:
		var p := Vector2.ZERO
		if not spawns.is_empty() and _rng.randf() < 0.5:
			var s: Vector3 = spawns[_rng.randi() % spawns.size()]
			var a := _rng.randf() * TAU
			var d := _rng.randf_range(6.0, 28.0)
			p = Vector2(s.x + cos(a) * d, s.z + sin(a) * d)
		else:
			p = Vector2(_rng.randf_range(-_half.x, _half.x), _rng.randf_range(-_half.y, _half.y))
		if absf(p.x) > _half.x or absf(p.y) > _half.y:
			continue
		var g := _ground(Vector3(p.x, 0, p.y))
		if g.is_empty():
			continue
		return g["position"]
	return Vector3(0, -999, 0)


## The ground under a point (a ray from far above): {position, normal} or {}.
func _ground(p: Vector3, from_y: float = 150.0) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, from_y, p.z), Vector3(p.x, -60.0, p.z), 1)
	var r := _space.intersect_ray(q)
	if r.is_empty():
		return {}
	var col: Object = r["collider"]
	if not (col is Node) or not (col as Node).has_meta("ground"):
		return {}
	return r


func _material(glow: Color) -> StandardMaterial3D:
	var key := glow.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		if glow.r + glow.g + glow.b > 0.01:
			m.emission_enabled = true
			m.emission = glow
			m.emission_energy_multiplier = 0.9
		_mats[key] = m
	return _mats[key]


func _add(kind: String, variant: int, home: Vector3, centre: Vector3) -> void:
	var parts := CritterMesh.parts(kind, variant)
	var mat := _material(parts["glow"])
	var root := Node3D.new()
	var sc := float(parts["scale"]) * _rng.randf_range(0.9, 1.15) * (1.25 if kind in WALK else 1.0)
	root.scale = Vector3.ONE * sc
	var body := MeshInstance3D.new()
	body.mesh = parts["body"]
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.visibility_range_end = 65.0
	root.add_child(body)
	var wings: Array = []
	if parts.has("wing"):
		var at: Vector3 = parts["wing_at"]
		for s in [1.0, -1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(at.x * s, at.y, at.z)
			pivot.scale = Vector3(s, 1, 1)
			var wm := MeshInstance3D.new()
			wm.mesh = parts["wing"]
			wm.material_override = mat
			wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			wm.visibility_range_end = 65.0
			pivot.add_child(wm)
			root.add_child(pivot)
			wings.append(pivot)
	var tail: Node3D = null
	if parts.has("tail"):
		tail = Node3D.new()
		tail.position = parts["tail_at"]
		var tm := MeshInstance3D.new()
		tm.mesh = parts["tail"]
		tm.material_override = mat
		tm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tm.visibility_range_end = 65.0
		tail.add_child(tm)
		root.add_child(tail)
	add_child(root)
	var it := {"node": root, "kind": kind, "home": home, "centre": centre, "pos": home, "yaw": _rng.randf() * TAU, "wings": wings, "tail": tail, "sc": sc,
		"state": "idle", "timer": _rng.randf_range(0.0, 4.0), "target": home, "gy": home.y, "gy_t": _rng.randf() * 0.5, "flee": 0.0, "hop": 0.0, "ph": _rng.randf() * 100.0,
		"p1": _rng.randf_range(0, TAU), "p2": _rng.randf_range(0, TAU), "p3": _rng.randf_range(0, TAU), "p4": _rng.randf_range(0, TAU), "r": _rng.randf_range(0.7, 1.3),
		"dir": 1.0 if _rng.randf() < 0.5 else -1.0, "h": 0.0, "up": Vector3.UP}
	match kind:
		"butterfly": it["h"] = _rng.randf_range(0.8, 2.6); it["R"] = _rng.randf_range(2.5, 6.5)
		"dragonfly": it["h"] = _rng.randf_range(0.7, 2.0); it["R"] = _rng.randf_range(2.0, 5.0)
		"bird": it["h"] = _rng.randf_range(9.0, 20.0); it["R"] = _rng.randf_range(10.0, 24.0)
		"bat": it["h"] = _rng.randf_range(3.5, 8.0); it["R"] = _rng.randf_range(4.0, 9.0)
		"fish": it["h"] = _rng.randf_range(1.2, 4.5); it["R"] = _rng.randf_range(5.0, 9.0)
		"jellyfish": it["h"] = _rng.randf_range(2.5, 7.0); it["R"] = _rng.randf_range(2.0, 4.0)
	_items.append(it)
	_place(it)


func _place(it: Dictionary) -> void:
	var n: Node3D = it["node"]
	var up: Vector3 = it["up"]
	var b := Basis(Vector3.UP, float(it["yaw"]))
	if up.dot(Vector3.UP) < 0.999:
		b = Basis(Quaternion(Vector3.UP, up)) * b
	var pl := float(it.get("pulse", 1.0))
	n.global_transform = Transform3D(b.scaled(Vector3(1.0 / sqrt(pl), pl, 1.0 / sqrt(pl)) * float(it["sc"])), it["pos"])


# ----------------------------------------------------------------- the daily life

func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	var campos := cam.global_position if cam != null else Vector3.ZERO
	_threats.clear()
	for c in _match.combatants:
		if is_instance_valid(c) and not c.dead:
			_threats.append(c.global_position)
	for it in _items:
		var n: Node3D = it["node"]
		var far := (it["pos"] as Vector3).distance_squared_to(campos) > 75.0 * 75.0
		if far:
			n.visible = false
			continue
		n.visible = true
		var kind: String = it["kind"]
		if kind in FLYERS:
			_fly(it, delta)
		elif kind == "fish":
			_swim(it, delta)
		elif kind == "jellyfish":
			_drift(it, delta)
		else:
			_walk(it, delta)
		_place(it)


func _nearest_threat(p: Vector3, within: float) -> Variant:
	var best := within * within
	var found: Variant = null
	for t in _threats:
		var d := (t as Vector3).distance_squared_to(p)
		if d < best:
			best = d
			found = t
	return found


func _walk(it: Dictionary, delta: float) -> void:
	var kind: String = it["kind"]
	var cfg: Dictionary = WALK[kind]
	var pos: Vector3 = it["pos"]
	it["timer"] = float(it["timer"]) - delta
	var scared: Variant = _nearest_threat(pos, float(cfg["flee"])) if it["flee"] <= 0.0 else null
	if scared != null:
		var away := Vector3(pos.x - scared.x, 0, pos.z - scared.z)
		away = away.normalized() if away.length() > 0.01 else Vector3(1, 0, 0)
		away = away.rotated(Vector3.UP, _rng.randf_range(-0.7, 0.7))
		it["target"] = _clamp_target(pos + away * _rng.randf_range(7.0, 11.0))
		it["state"] = "move"
		it["flee"] = 1.6
	it["flee"] = maxf(0.0, float(it["flee"]) - delta)
	var fleeing: bool = it["flee"] > 0.0
	var hopping: bool = cfg.has("hop")
	if it["state"] == "idle":
		# a little breathing, an occasional look about
		if _rng.randf() < delta * 0.5:
			it["yaw"] = float(it["yaw"]) + _rng.randf_range(-1.0, 1.0)
		if float(it["timer"]) <= 0.0:
			var a := _rng.randf() * TAU
			var d := _rng.randf_range(1.5, WANDER)
			it["target"] = _clamp_target((it["home"] as Vector3) + Vector3(cos(a) * d, 0, sin(a) * d))
			it["state"] = "move"
			it["hop"] = 0.0
		return
	var tgt: Vector3 = it["target"]
	var to := Vector3(tgt.x - pos.x, 0, tgt.z - pos.z)
	var dist := to.length()
	if dist < 0.25:
		it["state"] = "idle"
		it["timer"] = _rng.randf_range(float(cfg["rest"][0]), float(cfg["rest"][1]))
		it["pos"] = Vector3(pos.x, float(it["gy"]), pos.z)
		return
	var heading := atan2(to.x, to.z)
	if cfg.get("side", false):
		heading += PI * 0.5                      # crabs walk sideways
	it["yaw"] = lerp_angle(float(it["yaw"]), heading, minf(1.0, delta * (10.0 if fleeing else 6.0)))
	var speed := float(cfg["speed"]) * (2.4 if fleeing else 1.0)
	var step := minf(dist, speed * delta)
	var dirv := to / dist
	var y_off := 0.0
	if hopping:
		var hp: Array = cfg["hop"]
		var dur := float(hp[2]) * (0.8 if fleeing else 1.0)
		it["hop"] = float(it["hop"]) + delta / dur
		var ph := float(it["hop"])
		if fmod(ph, 1.6) > 1.0:                  # a short rest between hops
			step = 0.0
		else:
			var s := fmod(ph, 1.6)
			step = minf(dist, float(hp[1]) * (1.4 if fleeing else 1.0) * delta / dur)
			y_off = sin(clampf(s, 0.0, 1.0) * PI) * float(hp[0]) * (1.3 if fleeing else 1.0)
	else:
		# scurrying: a quick bob, a waddle for penguins
		var ph := _t * (9.0 if kind != "penguin" else 5.0) + float(it["ph"])
		y_off = absf(sin(ph)) * (0.012 if kind != "penguin" else 0.015)
		if cfg.get("waddle", false):
			it["yaw"] = float(it["yaw"]) + sin(ph) * 0.02
	var np := pos + dirv * step
	it["gy_t"] = float(it["gy_t"]) - delta
	if it["gy_t"] <= 0.0 or step > 0.0:
		var g := _ground(np, pos.y + 3.0)
		if g.is_empty() or (g["normal"] as Vector3).y < 0.72:
			it["state"] = "idle"
			it["timer"] = 1.0
			it["target"] = it["home"]
			return
		it["gy"] = (g["position"] as Vector3).y
		it["up"] = (it["up"] as Vector3).lerp(g["normal"], minf(1.0, delta * 6.0)).normalized()
		it["gy_t"] = 0.15
	it["pos"] = Vector3(np.x, float(it["gy"]) + y_off, np.z)


func _clamp_target(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -_half.x, _half.x), p.y, clampf(p.z, -_half.y, _half.y))


func _flap(it: Dictionary, freq: float, amp: float) -> void:
	var f := sin(_t * freq + float(it["ph"])) * amp
	for w in it["wings"]:
		(w as Node3D).rotation.z = f


func _fly(it: Dictionary, delta: float) -> void:
	var kind: String = it["kind"]
	var home: Vector3 = it["home"]
	var ph1 := float(it["p1"])
	var ph2 := float(it["p2"])
	var ph3 := float(it["p3"])
	var ph4 := float(it["p4"])
	var R := float(it["R"])
	var base_h := float(it["h"])
	var p: Vector3
	match kind:
		"butterfly":
			p = home + Vector3(sin(_t * 0.31 * float(it["r"]) + ph1) * R + sin(_t * 1.1 + ph2) * 0.5, 0, cos(_t * 0.27 * float(it["r"]) + ph3) * R * 0.8 + cos(_t * 0.9 + ph4) * 0.5)
			p.y = float(it["gy"]) + base_h + sin(_t * 1.3 + ph2) * 0.45 + sin(_t * 3.1 + ph1) * 0.12
			_flap(it, 13.0, 0.45 + 0.65 * absf(sin(_t * 0.6 + ph3)))
		"dragonfly":
			p = home + Vector3(sin(_t * 0.5 * float(it["r"]) + ph1) * R + sin(_t * 2.1 + ph2) * 0.7, 0, cos(_t * 0.43 + ph3) * R * 0.8 + sin(_t * 1.7 + ph4) * 0.7)
			p.y = float(it["gy"]) + base_h + sin(_t * 0.8 + ph2) * 0.3
			_flap(it, 30.0, 0.3)
		"bird":
			var a := _t * (5.0 / R) * float(it["dir"]) + ph1
			p = home + Vector3(cos(a) * R, 0, sin(a) * R * 0.85)
			p.y = float(it["gy"]) + base_h + sin(_t * 0.4 + ph2) * 1.6
			var glide := smoothstep(-0.2, 0.3, sin(_t * 0.5 + ph3))
			_flap(it, 10.0, lerpf(0.2, 0.7, glide))
		_:
			p = home + Vector3(sin(_t * 0.55 * float(it["r"]) + ph1) * R + sin(_t * 1.9 + ph2) * 1.5, 0, cos(_t * 0.5 + ph3) * R * 0.8 + sin(_t * 1.6 + ph4) * 1.2)
			p.y = float(it["gy"]) + base_h + sin(_t * 1.2 + ph2) * 1.2
			_flap(it, 17.0, 0.85)
	# keep above the ground, and swerve away from fighters
	it["gy_t"] = float(it["gy_t"]) - delta
	if it["gy_t"] <= 0.0:
		var g := _ground(Vector3(p.x, 0, p.z))
		if not g.is_empty():
			it["gy"] = (g["position"] as Vector3).y
		it["gy_t"] = 0.5
	p.y = maxf(p.y, float(it["gy"]) + 0.5)
	var scared: Variant = _nearest_threat(p, 4.0 if kind != "bird" else 6.0)
	var old: Vector3 = it["pos"]
	if scared != null:
		var away: Vector3 = (p - (scared as Vector3))
		it["push"] = (it.get("push", Vector3.ZERO) as Vector3).lerp(away.normalized() * 3.0, minf(1.0, delta * 4.0))
	else:
		it["push"] = (it.get("push", Vector3.ZERO) as Vector3).lerp(Vector3.ZERO, minf(1.0, delta * 1.5))
	p += it["push"]
	var mv := p - old
	if mv.length() > 0.0005 and delta > 0.0:
		var heading := atan2(mv.x, mv.z)
		it["yaw"] = lerp_angle(float(it["yaw"]), heading, minf(1.0, delta * 8.0))
		it["up"] = (it["up"] as Vector3).lerp(Vector3.UP, minf(1.0, delta * 4.0)).normalized()
	it["pos"] = p


func _swim(it: Dictionary, delta: float) -> void:
	var home: Vector3 = it["centre"]                # the school's heart: fish of one school share it
	var school := absi(hash((it["centre"] as Vector3).snapped(Vector3.ONE))) % 1000
	var R := 5.0 + float(school % 5)
	var sp := 0.3 + 0.03 * float(school % 7)
	var ph := float(school) * 0.0063
	var centre := home + Vector3(sin(_t * sp * 0.5 + ph) * R, 0, cos(_t * sp * 0.43 + ph * 1.3) * R * 0.8)
	var off := Vector3(sin(_t * 0.9 + float(it["p2"])) * 1.4, sin(_t * 0.7 + float(it["p3"])) * 0.5, cos(_t * 0.8 + float(it["p4"])) * 1.4)
	var p := centre + off
	p.y = float(it["gy"]) + float(it["h"]) + sin(_t * 0.2 + ph) * 1.2 + off.y
	it["gy_t"] = float(it["gy_t"]) - delta
	if it["gy_t"] <= 0.0:
		var g := _ground(Vector3(p.x, 0, p.z))
		if not g.is_empty():
			it["gy"] = (g["position"] as Vector3).y
		it["gy_t"] = 0.6
	p.y = maxf(p.y, float(it["gy"]) + 0.6)
	var scared: Variant = _nearest_threat(p, 5.0)
	var old: Vector3 = it["pos"]
	if scared != null:
		it["push"] = (it.get("push", Vector3.ZERO) as Vector3).lerp((p - (scared as Vector3)).normalized() * 4.0, minf(1.0, delta * 4.0))
	else:
		it["push"] = (it.get("push", Vector3.ZERO) as Vector3).lerp(Vector3.ZERO, minf(1.0, delta * 1.5))
	p += it["push"]
	var mv := p - old
	if mv.length() > 0.0005 and delta > 0.0:
		it["yaw"] = lerp_angle(float(it["yaw"]), atan2(mv.x, mv.z), minf(1.0, delta * 6.0))
	it["pos"] = p
	if it["tail"] != null:
		(it["tail"] as Node3D).rotation.y = sin(_t * 11.0 + float(it["ph"])) * 0.5


func _drift(it: Dictionary, delta: float) -> void:
	var home: Vector3 = it["home"]
	var R := float(it["R"])
	var p := home + Vector3(sin(_t * 0.13 + float(it["p1"])) * R, 0, cos(_t * 0.11 + float(it["p3"])) * R)
	p.y = float(it["gy"]) + float(it["h"]) + sin(_t * 0.4 + float(it["p2"])) * 1.5
	it["gy_t"] = float(it["gy_t"]) - delta
	if it["gy_t"] <= 0.0:
		var g := _ground(Vector3(p.x, 0, p.z))
		if not g.is_empty():
			it["gy"] = (g["position"] as Vector3).y
		it["gy_t"] = 0.8
	p.y = maxf(p.y, float(it["gy"]) + 1.0)
	it["pos"] = p
	it["yaw"] = float(it["yaw"]) + delta * 0.1
	# the bell pulses
	it["pulse"] = 1.0 + 0.1 * sin(_t * 2.4 + float(it["ph"]))
