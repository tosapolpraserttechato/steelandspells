extends Node
## Particle and visual effects, all built in code (no scenes): status effects, weapon trails, skill zones, impacts,
## damage numbers, crate beams, auras and map hazards. Textures are drawn once at start.
## Everything is cheap on purpose (small particle counts, additive quads) so it runs on a laptop without a dedicated GPU.

var TEX: Dictionary = {}               # name -> ImageTexture
var _mat_cache: Dictionary = {}
var enabled := true
var quality := 1.0                    # 0.3 .. 1.0 scales particle counts


func _ready() -> void:
	_make_textures()


# ================================================================= textures

func _make_textures() -> void:
	TEX["soft"] = _tex(64, func(x: float, y: float) -> float: return pow(clampf(1.0 - Vector2(x, y).length(), 0.0, 1.0), 1.6))
	TEX["hard"] = _tex(64, func(x: float, y: float) -> float: return smoothstep(1.0, 0.82, Vector2(x, y).length()))
	TEX["ring"] = _tex(64, func(x: float, y: float) -> float:
		var d := Vector2(x, y).length()
		return smoothstep(0.55, 0.85, d) * smoothstep(1.0, 0.9, d))
	TEX["star"] = _tex(64, func(x: float, y: float) -> float:
		var ax := absf(x)
		var ay := absf(y)
		var cross := clampf(1.0 - minf(ax, ay) * 7.0, 0.0, 1.0) * clampf(1.0 - maxf(ax, ay), 0.0, 1.0)
		var glow := pow(clampf(1.0 - Vector2(x, y).length() * 1.5, 0.0, 1.0), 2.0)
		return clampf(cross + glow, 0.0, 1.0))
	TEX["spark"] = _tex(64, func(x: float, y: float) -> float:
		return clampf(1.0 - absf(y) * 5.0, 0.0, 1.0) * clampf(1.0 - absf(x), 0.0, 1.0) * clampf(1.0 - absf(y) * 5.0, 0.0, 1.0))
	TEX["drop"] = _tex(64, func(x: float, y: float) -> float:
		var yy := (y + 0.3) * 1.2
		var r := Vector2(x * (1.0 + yy * 0.7), yy).length()
		return smoothstep(0.6, 0.45, r) * (1.0 if y > -0.9 else 0.0))
	TEX["flame"] = _tex(64, func(x: float, y: float) -> float:
		var w := (1.0 - (y + 1.0) * 0.5) * 0.7 + 0.15              # wide at the bottom, narrow at the top
		var d := absf(x) / maxf(w, 0.05)
		return smoothstep(1.0, 0.3, d) * smoothstep(1.0, 0.55, absf(y - 0.2)) )
	TEX["smoke"] = _tex(64, func(x: float, y: float) -> float:
		var d := Vector2(x, y).length()
		var n := 0.5 + 0.5 * sin(x * 9.0 + y * 5.0) * sin(y * 7.0 - x * 3.0)
		return clampf((1.0 - d) * (0.55 + 0.45 * n), 0.0, 1.0))
	TEX["leaf"] = _tex(64, func(x: float, y: float) -> float:
		var d := Vector2(x * 1.8, y).length()
		return smoothstep(0.8, 0.55, d) * (1.0 - 0.4 * absf(x)))
	TEX["hex"] = _tex(96, func(x: float, y: float) -> float:
		var p := Vector2(absf(x), absf(y))
		var d := maxf(p.x * 0.866 + p.y * 0.5, p.y)
		return smoothstep(0.95, 0.85, d) * smoothstep(0.55, 0.85, d))
	TEX["arrow"] = _tex(64, func(x: float, y: float) -> float:
		var shaft := (1.0 if absf(x) < 0.12 and y < 0.2 else 0.0)
		var head := (1.0 if y >= 0.1 and absf(x) < (1.0 - y) * 0.6 else 0.0)
		return clampf(shaft + head, 0.0, 1.0))


## Draws a square texture from a function (x, y in -1..1) -> alpha 0..1, white colour.
func _tex(size: int, f: Callable) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for j in size:
		for i in size:
			var x := (float(i) + 0.5) / size * 2.0 - 1.0
			var y := 1.0 - (float(j) + 0.5) / size * 2.0
			var a: float = clampf(f.call(x, y), 0.0, 1.0)
			img.set_pixel(i, j, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# ================================================================= building blocks

func _quad_material(tex_name: String, additive: bool) -> StandardMaterial3D:
	var key := "%s_%s" % [tex_name, additive]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = TEX[tex_name]
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	_mat_cache[key] = m
	return m


func _ramp(colors: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array()
	g.colors = PackedColorArray()
	var n := colors.size()
	for i in n:
		g.add_point(float(i) / maxf(n - 1, 1), colors[i])
	g.remove_point(0) if g.get_point_count() > n else null
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(Vector2(p[0], p[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t


## Options: tex, additive, amount, life, shape ("point","sphere","box","ring","sphere_surface"), radius, extents, dir, spread, vel (min,max),
## gravity, damping, size (min,max), size_curve, colors [start .. end], one_shot, burst (explosiveness), local, spin, accel, turbulence, ring_axis
func particles(o: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	match String(o.get("shape", "point")):
		"sphere":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			pm.emission_sphere_radius = float(o.get("radius", 0.3))
		"sphere_surface":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE_SURFACE
			pm.emission_sphere_radius = float(o.get("radius", 0.3))
		"box":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			pm.emission_box_extents = o.get("extents", Vector3(0.3, 0.3, 0.3))
		"ring":
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			pm.emission_ring_axis = o.get("ring_axis", Vector3(0, 1, 0))
			pm.emission_ring_radius = float(o.get("radius", 1.0))
			pm.emission_ring_inner_radius = float(o.get("inner", float(o.get("radius", 1.0)) * 0.85))
			pm.emission_ring_height = float(o.get("height", 0.1))
		_:
			pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = o.get("dir", Vector3(0, 1, 0))
	pm.spread = float(o.get("spread", 30.0))
	var v: Array = o.get("vel", [0.5, 1.5])
	pm.initial_velocity_min = float(v[0])
	pm.initial_velocity_max = float(v[1])
	pm.gravity = o.get("gravity", Vector3.ZERO)
	var dmp: Array = o.get("damping", [0.0, 0.0])
	pm.damping_min = float(dmp[0])
	pm.damping_max = float(dmp[1])
	var sz: Array = o.get("size", [0.2, 0.4])
	pm.scale_min = float(sz[0])
	pm.scale_max = float(sz[1])
	if o.has("size_curve"):
		pm.scale_curve = _curve(o["size_curve"])
	var spin: Array = o.get("spin", [0.0, 0.0])
	pm.angular_velocity_min = float(spin[0])
	pm.angular_velocity_max = float(spin[1])
	if o.has("accel"):
		pm.linear_accel_min = float(o["accel"][0])
		pm.linear_accel_max = float(o["accel"][1])
	if o.has("radial"):
		pm.radial_accel_min = float(o["radial"][0])
		pm.radial_accel_max = float(o["radial"][1])
	if o.has("tangent"):
		pm.tangential_accel_min = float(o["tangent"][0])
		pm.tangential_accel_max = float(o["tangent"][1])
	if o.get("turbulence", 0.0) > 0.0:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = float(o["turbulence"])
		pm.turbulence_noise_scale = 2.0
	pm.color_ramp = _ramp(o.get("colors", [Color(1, 1, 1, 1), Color(1, 1, 1, 0)]))
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _quad_material(String(o.get("tex", "soft")), bool(o.get("additive", true)))
	p.draw_pass_1 = quad
	p.amount = maxi(1, int(float(o.get("amount", 16)) * quality))
	p.lifetime = float(o.get("life", 1.0))
	p.one_shot = bool(o.get("one_shot", false))
	p.explosiveness = float(o.get("burst", 0.0))
	p.randomness = 0.6
	p.local_coords = bool(o.get("local", true))
	p.visibility_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 8, 12))
	p.emitting = true
	return p


## Removes a one-shot effect node after `t` seconds.
func _free_after(n: Node, t: float) -> void:
	var wr: WeakRef = weakref(n)
	get_tree().create_timer(t).timeout.connect(func() -> void:
		var o: Object = wr.get_ref()
		if o != null:
			(o as Node).queue_free())


func _world() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_tree().root


func _spawn(n: Node3D, pos: Vector3) -> Node3D:
	_world().add_child(n)
	n.global_position = pos
	return n


func _col(a: Array) -> Color:
	return Color(a[0], a[1], a[2])


# ================================================================= status effects (loop on a character)

## Returns an effect node to be added under the character (feet at y = 0). The caller frees it when the status ends.
func status_effect(id: String, height: float = 1.85) -> Node3D:
	var root := Node3D.new()
	root.name = "fx_" + id
	if not enabled:
		return root
	var h := height
	match id:
		"burn":
			root.add_child(_at(particles({"tex": "flame", "amount": 26, "life": 0.8, "shape": "sphere", "radius": 0.28, "dir": Vector3.UP, "spread": 18,
				"vel": [0.8, 1.6], "size": [0.35, 0.6], "size_curve": [[0, 0.6], [0.4, 1.0], [1, 0.1]],
				"colors": [Color(1, 0.9, 0.3, 0.9), Color(1, 0.45, 0.1, 0.8), Color(0.5, 0.1, 0.05, 0.0)], "local": false}), Vector3(0, h * 0.45, 0)))
			root.add_child(_at(particles({"tex": "soft", "amount": 8, "life": 1.0, "shape": "sphere", "radius": 0.3, "dir": Vector3.UP, "spread": 25, "vel": [1.0, 2.0],
				"size": [0.08, 0.14], "colors": [Color(1, 0.8, 0.3, 1), Color(1, 0.3, 0.05, 0)], "local": false}), Vector3(0, h * 0.5, 0)))
		"chill":
			root.add_child(_at(particles({"tex": "star", "amount": 12, "life": 1.2, "shape": "sphere", "radius": 0.45, "vel": [0.05, 0.3], "gravity": Vector3(0, -0.3, 0),
				"size": [0.1, 0.2], "spin": [-90, 90], "colors": [Color(0.8, 0.95, 1, 0), Color(0.8, 0.95, 1, 0.9), Color(0.6, 0.85, 1, 0)]}), Vector3(0, h * 0.5, 0)))
			root.add_child(_at(particles({"tex": "smoke", "amount": 8, "life": 1.6, "shape": "sphere", "radius": 0.35, "dir": Vector3(0, -1, 0), "spread": 40, "vel": [0.1, 0.4],
				"size": [0.5, 0.9], "additive": false, "colors": [Color(0.75, 0.92, 1, 0), Color(0.75, 0.92, 1, 0.28), Color(0.75, 0.92, 1, 0)]}), Vector3(0, h * 0.3, 0)))
		"freeze":
			var shell := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.55
			cap.height = h * 1.1
			shell.mesh = cap
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.6, 0.85, 1.0, 0.38)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color(0.3, 0.6, 0.9)
			mat.emission_energy_multiplier = 0.6
			mat.rim_enabled = true
			mat.roughness = 0.1
			shell.material_override = mat
			shell.position = Vector3(0, h * 0.5, 0)
			root.add_child(shell)
			root.add_child(_at(particles({"tex": "star", "amount": 10, "life": 0.9, "shape": "sphere_surface", "radius": 0.6, "vel": [0.0, 0.1], "size": [0.12, 0.25],
				"colors": [Color(1, 1, 1, 0), Color(0.8, 0.95, 1, 1), Color(0.8, 0.95, 1, 0)]}), Vector3(0, h * 0.5, 0)))
		"poison":
			root.add_child(_at(particles({"tex": "hard", "amount": 18, "life": 1.5, "shape": "sphere", "radius": 0.4, "dir": Vector3.UP, "spread": 30, "vel": [0.3, 0.7],
				"size": [0.06, 0.16], "size_curve": [[0, 0.3], [0.2, 1.0], [0.9, 1.0], [1, 0.0]], "additive": false, "turbulence": 0.6,
				"colors": [Color(0.5, 0.95, 0.2, 0.0), Color(0.45, 0.9, 0.2, 0.8), Color(0.3, 0.7, 0.1, 0.0)], "local": false}), Vector3(0, h * 0.35, 0)))
			root.add_child(_at(particles({"tex": "drop", "amount": 5, "life": 0.9, "shape": "sphere", "radius": 0.3, "dir": Vector3.DOWN, "spread": 10, "vel": [0.2, 0.5],
				"gravity": Vector3(0, -4, 0), "size": [0.08, 0.16], "additive": false, "colors": [Color(0.55, 1, 0.2, 0.9), Color(0.3, 0.7, 0.1, 0)], "local": false}), Vector3(0, h * 0.6, 0)))
			root.add_child(_at(particles({"tex": "smoke", "amount": 8, "life": 1.8, "shape": "sphere", "radius": 0.35, "dir": Vector3.UP, "spread": 60, "vel": [0.2, 0.6],
				"size": [0.55, 1.0], "additive": false, "colors": [Color(0.4, 0.8, 0.15, 0), Color(0.4, 0.8, 0.15, 0.3), Color(0.3, 0.6, 0.1, 0)]}), Vector3(0, h * 0.45, 0)))
		"shock":
			root.add_child(_at(particles({"tex": "spark", "amount": 18, "life": 0.22, "shape": "sphere_surface", "radius": 0.5, "vel": [1.5, 3.5], "dir": Vector3.UP, "spread": 180,
				"size": [0.35, 0.7], "spin": [-300, 300], "colors": [Color(1, 1, 0.7, 1), Color(1, 0.95, 0.3, 0.9), Color(0.5, 0.7, 1, 0)]}), Vector3(0, h * 0.5, 0)))
		"stun":
			var stars := _StarRing.new()
			stars.position = Vector3(0, h + 0.2, 0)
			stars.setup(TEX["star"], Color(1, 0.9, 0.3))
			root.add_child(stars)
		"slow":
			root.add_child(_at(particles({"tex": "smoke", "amount": 8, "life": 1.2, "shape": "ring", "radius": 0.5, "inner": 0.3, "dir": Vector3.UP, "spread": 20, "vel": [0.1, 0.4],
				"size": [0.35, 0.6], "additive": false, "colors": [Color(0.55, 0.45, 0.3, 0.0), Color(0.55, 0.45, 0.3, 0.6), Color(0.4, 0.3, 0.2, 0)]}), Vector3(0, 0.1, 0)))
			root.add_child(_at(particles({"tex": "drop", "amount": 4, "life": 0.6, "shape": "ring", "radius": 0.4, "dir": Vector3.UP, "spread": 25, "vel": [0.5, 1.2], "gravity": Vector3(0, -6, 0),
				"size": [0.08, 0.14], "additive": false, "colors": [Color(0.5, 0.38, 0.22, 0.9), Color(0.4, 0.3, 0.2, 0)]}), Vector3(0, 0.1, 0)))
		"root":
			root.add_child(_at(particles({"tex": "leaf", "amount": 14, "life": 1.1, "shape": "ring", "radius": 0.45, "inner": 0.3, "dir": Vector3.UP, "spread": 12, "vel": [0.6, 1.6],
				"gravity": Vector3(0, -0.5, 0), "size": [0.15, 0.3], "spin": [-120, 120], "additive": false, "turbulence": 0.5,
				"colors": [Color(0.4, 0.8, 0.25, 0), Color(0.35, 0.75, 0.2, 1), Color(0.2, 0.5, 0.1, 0)]}), Vector3(0, 0.1, 0)))
			root.add_child(_Ring.new().setup(TEX["ring"], Color(0.35, 0.8, 0.25, 0.6), 1.3, Vector3(0, 0.05, 0)))
		"bleed":
			root.add_child(_at(particles({"tex": "drop", "amount": 7, "life": 0.7, "shape": "sphere", "radius": 0.25, "dir": Vector3.DOWN, "spread": 25, "vel": [0.1, 0.5],
				"gravity": Vector3(0, -5, 0), "size": [0.07, 0.13], "additive": false, "colors": [Color(0.85, 0.05, 0.1, 0.95), Color(0.5, 0.0, 0.05, 0)], "local": false}), Vector3(0, h * 0.55, 0)))
		"weaken":
			root.add_child(_at(particles({"tex": "smoke", "amount": 9, "life": 1.6, "shape": "sphere", "radius": 0.35, "dir": Vector3.DOWN, "spread": 40, "vel": [0.1, 0.5],
				"size": [0.5, 0.9], "additive": false, "colors": [Color(0.4, 0.25, 0.6, 0), Color(0.4, 0.25, 0.6, 0.35), Color(0.2, 0.1, 0.35, 0)]}), Vector3(0, h * 0.7, 0)))
		"vulnerable":
			root.add_child(_at(particles({"tex": "star", "amount": 8, "life": 0.8, "shape": "sphere", "radius": 0.55, "vel": [0.0, 0.2], "size": [0.12, 0.28], "spin": [-60, 60],
				"colors": [Color(1, 0.3, 0.4, 0), Color(1, 0.35, 0.45, 1), Color(1, 0.3, 0.4, 0)]}), Vector3(0, h * 0.55, 0)))
		"silence":
			root.add_child(_at(particles({"tex": "ring", "amount": 3, "life": 1.2, "shape": "point", "vel": [0.0, 0.0], "size": [0.2, 0.2], "size_curve": [[0, 0.5], [1, 2.2]],
				"colors": [Color(0.7, 0.7, 1, 0.9), Color(0.6, 0.6, 1, 0)]}), Vector3(0, h + 0.15, 0)))
		"blind":
			root.add_child(_at(particles({"tex": "smoke", "amount": 8, "life": 1.2, "shape": "sphere", "radius": 0.2, "vel": [0.1, 0.4], "dir": Vector3.UP, "spread": 70,
				"size": [0.35, 0.6], "additive": false, "colors": [Color(0.7, 0.65, 0.5, 0), Color(0.7, 0.65, 0.5, 0.5), Color(0.5, 0.45, 0.35, 0)]}), Vector3(0, h - 0.1, 0)))
		"haste":
			root.add_child(_at(particles({"tex": "spark", "amount": 16, "life": 0.45, "shape": "sphere", "radius": 0.35, "vel": [0.0, 0.2], "size": [0.3, 0.55], "local": false,
				"colors": [Color(0.5, 1, 0.75, 0), Color(0.5, 1, 0.75, 0.9), Color(0.3, 0.9, 0.6, 0)]}), Vector3(0, h * 0.4, 0)))
		"barrier":
			var shield := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = 0.95
			sph.height = 1.9
			shield.mesh = sph
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.45, 0.8, 1.0, 0.18)
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			sm.albedo_texture = TEX["hex"]
			sm.uv1_scale = Vector3(5, 3, 1)
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			shield.material_override = sm
			shield.position = Vector3(0, h * 0.5, 0)
			root.add_child(shield)
			var tw := root.create_tween().set_loops()
			tw.tween_property(sm, "albedo_color:a", 0.32, 0.8)
			tw.tween_property(sm, "albedo_color:a", 0.12, 0.8)
		"regen":
			root.add_child(_at(particles({"tex": "star", "amount": 10, "life": 1.3, "shape": "ring", "radius": 0.5, "dir": Vector3.UP, "spread": 5, "vel": [0.5, 1.0], "size": [0.12, 0.22],
				"colors": [Color(0.5, 1, 0.5, 0), Color(0.5, 1, 0.55, 0.9), Color(0.4, 0.9, 0.4, 0)]}), Vector3(0, 0.1, 0)))
		"empower":
			root.add_child(_at(particles({"tex": "flame", "amount": 14, "life": 0.9, "shape": "ring", "radius": 0.5, "dir": Vector3.UP, "spread": 10, "vel": [0.8, 1.6], "size": [0.3, 0.55],
				"colors": [Color(1, 0.7, 0.2, 0), Color(1, 0.6, 0.15, 0.7), Color(0.9, 0.3, 0.05, 0)], "local": false}), Vector3(0, 0.1, 0)))
		"cleanse_shield":
			root.add_child(_at(particles({"tex": "star", "amount": 14, "life": 1.0, "shape": "sphere_surface", "radius": 0.6, "vel": [0.0, 0.2], "size": [0.1, 0.24], "tangent": [1.5, 2.5],
				"colors": [Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(0.8, 0.9, 1, 0)]}), Vector3(0, h * 0.5, 0)))
		"invisible":
			root.add_child(_at(particles({"tex": "soft", "amount": 8, "life": 1.0, "shape": "sphere", "radius": 0.5, "vel": [0.0, 0.2], "size": [0.1, 0.2],
				"colors": [Color(0.8, 0.8, 0.95, 0), Color(0.8, 0.8, 0.95, 0.35), Color(0.8, 0.8, 0.95, 0)]}), Vector3(0, h * 0.5, 0)))
		"marked":
			var mark := Sprite3D.new()
			mark.texture = TEX["ring"]
			mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			mark.modulate = Color(1, 0.25, 0.25, 0.9)
			mark.pixel_size = 0.012
			mark.shaded = false
			mark.no_depth_test = true
			mark.position = Vector3(0, h + 0.5, 0)
			root.add_child(mark)
			var tw2 := root.create_tween().set_loops()
			tw2.tween_property(mark, "scale", Vector3(1.4, 1.4, 1.4), 0.5)
			tw2.tween_property(mark, "scale", Vector3.ONE, 0.5)
		_:
			pass
	return root


func _at(n: Node3D, pos: Vector3) -> Node3D:
	n.position = pos
	return n


# ================================================================= weapon effects

## A glowing arc for a melee swing. `parent` is the attacker (the arc follows its facing for a moment). Arc in degrees.
func slash_trail(parent: Node3D, color: Color, arc: float = 110.0, radius: float = 2.6, height: float = 1.1, flip: bool = false) -> void:
	if not enabled:
		return
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var steps := 14
	var a0 := deg_to_rad(-arc * 0.5)
	for i in steps + 1:
		var t := float(i) / steps
		var a := a0 + deg_to_rad(arc) * t
		var dirv := Vector3(sin(a), 0, -cos(a))
		var fade := pow(t, 1.4)                                      # the tail is faint, the head bright
		var sweep := deg_to_rad(18.0) * (1.0 - t)
		verts.append(dirv * (radius * 0.55) + Vector3(0, sweep * 0.5, 0))
		verts.append(dirv * radius + Vector3(0, -sweep * 0.2, 0))
		cols.append(Color(color.r, color.g, color.b, 0.0))
		cols.append(Color(color.r, color.g, color.b, fade))
		if i > 0:
			var b := (i - 1) * 2
			idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position = Vector3(0, height, 0)
	if flip:
		mi.scale = Vector3(-1, 1, 1)
	parent.add_child(mi)
	var tw := mi.create_tween()
	mi.rotation.y = deg_to_rad(-30.0) if not flip else deg_to_rad(30.0)
	tw.tween_property(mi, "rotation:y", 0.0, 0.14)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.26).from(1.0)
	tw.tween_callback(mi.queue_free)


## A projectile body: bright core, trailing sparks. kind: "bolt" (magic), "arrow", "orb", "dart", "fire", "ice", "storm", "leaf", "bone", "shadow".
func projectile_visual(kind: String, color: Color, size: float = 1.0) -> Node3D:
	var root := Node3D.new()
	if not enabled:
		return root
	var core := Sprite3D.new()
	core.texture = TEX["soft"]
	core.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	core.modulate = Color(color.r, color.g, color.b, 1.0)
	core.pixel_size = 0.0045 * size
	core.shaded = false
	core.transparent = true
	core.render_priority = 2
	var cmat := StandardMaterial3D.new()
	root.add_child(core)
	match kind:
		"arrow", "dart":
			var shaft := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.02
			cyl.bottom_radius = 0.02
			cyl.height = 0.9
			shaft.mesh = cyl
			shaft.rotation.x = deg_to_rad(90)
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.85, 0.75, 0.55)
			sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			shaft.material_override = sm
			root.add_child(shaft)
			core.pixel_size = 0.003 * size
			root.add_child(particles({"tex": "spark", "amount": 10, "life": 0.3, "vel": [0.0, 0.1], "size": [0.35, 0.5], "local": false,
				"colors": [Color(color.r, color.g, color.b, 0.7), Color(color.r, color.g, color.b, 0)]}))
		"fire":
			root.add_child(particles({"tex": "flame", "amount": 22, "life": 0.5, "shape": "sphere", "radius": 0.12, "vel": [0.0, 0.4], "size": [0.4, 0.7] , "local": false,
				"size_curve": [[0, 1.0], [1, 0.1]], "colors": [Color(1, 0.85, 0.3, 0.9), Color(1, 0.4, 0.1, 0.6), Color(0.3, 0.05, 0.0, 0)]}))
		"ice":
			root.add_child(particles({"tex": "star", "amount": 16, "life": 0.5, "shape": "sphere", "radius": 0.1, "vel": [0.0, 0.5], "size": [0.12, 0.25], "local": false,
				"colors": [Color(0.9, 1, 1, 0.9), Color(0.5, 0.85, 1, 0.5), Color(0.4, 0.7, 1, 0)]}))
		"storm":
			root.add_child(particles({"tex": "spark", "amount": 16, "life": 0.2, "shape": "sphere", "radius": 0.2, "vel": [0.5, 2.0], "dir": Vector3.UP, "spread": 180,
				"size": [0.3, 0.6], "spin": [-300, 300], "local": false, "colors": [Color(1, 1, 0.8, 1), Color(0.6, 0.8, 1, 0)]}))
		"leaf":
			root.add_child(particles({"tex": "leaf", "amount": 12, "life": 0.6, "shape": "sphere", "radius": 0.12, "vel": [0.2, 0.8], "size": [0.12, 0.22], "spin": [-200, 200], "additive": false,
				"local": false, "colors": [Color(0.5, 0.9, 0.3, 0.9), Color(0.3, 0.6, 0.15, 0)]}))
		_:
			root.add_child(particles({"tex": "soft", "amount": 14, "life": 0.45, "shape": "sphere", "radius": 0.1, "vel": [0.0, 0.3], "size": [0.2, 0.35], "local": false,
				"size_curve": [[0, 1.0], [1, 0.0]], "colors": [Color(color.r, color.g, color.b, 0.9), Color(color.r, color.g, color.b, 0)]}))
	return root


func impact(pos: Vector3, color: Color, big: bool = false) -> void:
	if not enabled:
		return
	var root := Node3D.new()
	_spawn(root, pos)
	var n := 1.6 if big else 1.0
	root.add_child(particles({"tex": "spark", "amount": int(14 * n), "life": 0.35, "one_shot": true, "burst": 1.0, "shape": "point", "vel": [3.0, 7.0] , "dir": Vector3.UP, "spread": 180,
		"gravity": Vector3(0, -6, 0), "size": [0.25, 0.5], "colors": [Color(1, 1, 0.9, 1), Color(color.r, color.g, color.b, 0.9), Color(color.r, color.g, color.b, 0)], "local": false}))
	root.add_child(particles({"tex": "soft", "amount": int(5 * n), "life": 0.35, "one_shot": true, "burst": 1.0, "shape": "point", "vel": [0.0, 0.5], "size": [0.9 * n, 1.4 * n],
		"size_curve": [[0, 0.3], [1, 1.0]], "colors": [Color(color.r, color.g, color.b, 0.7), Color(color.r, color.g, color.b, 0)]}))
	root.add_child(_Ring.new().setup(TEX["ring"], color, 1.2 * n, Vector3.ZERO, 0.3))
	_free_after(root, 1.2)


## A ground ring that grows to `radius` and fades. Used for AoE telegraphs and ground-pound shockwaves.
func ring(pos: Vector3, radius: float, color: Color, life: float = 0.5, flat: bool = true) -> void:
	if not enabled:
		return
	var r := _Ring.new().setup(TEX["ring"], color, radius, Vector3.ZERO, life)
	_spawn(r, pos)
	_free_after(r, life + 0.2)


## An area marker on the ground for a skill that lands later (delay seconds), then bursts.
func telegraph(pos: Vector3, radius: float, color: Color, delay: float, parent: Node3D = null) -> Node3D:
	var r := _Ring.new().setup(TEX["hard"], Color(color.r, color.g, color.b, 0.28), radius, Vector3.ZERO, delay, false)
	if parent != null:
		parent.add_child(r)
	else:
		_spawn(r, pos)
	var edge := _Ring.new().setup(TEX["ring"], Color(color.r, color.g, color.b, 0.9), radius, Vector3.ZERO, delay, false)
	r.add_child(edge)
	_free_after(r, delay + 0.1)
	return r


func beam(from: Vector3, to: Vector3, color: Color, width: float = 0.3, life: float = 0.18) -> void:
	if not enabled:
		return
	var d := to - from
	var len := d.length()
	if len < 0.1:
		return
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, len)
	mi.mesh = box
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.9)
	mi.material_override = m
	_world().add_child(mi)
	mi.global_position = (from + to) * 0.5
	mi.look_at(to, Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	var core := MeshInstance3D.new()
	var b2 := BoxMesh.new()
	b2.size = Vector3(width * 0.35, width * 0.35, len)
	core.mesh = b2
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.albedo_color = Color(1, 1, 1, 1)
	core.material_override = m2
	mi.add_child(core)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.tween_callback(mi.queue_free)


func lightning_strike(pos: Vector3, height: float = 40.0) -> void:
	if not enabled:
		return
	var root := Node3D.new()
	_spawn(root, pos)
	var pts: Array[Vector3] = []
	var p := Vector3(0, height, 0)
	while p.y > 0.0:
		pts.append(p)
		p += Vector3(randf_range(-2.0, 2.0), -randf_range(3.0, 6.0), randf_range(-2.0, 2.0))
	pts.append(Vector3.ZERO)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.28, 0.28, a.distance_to(b))
		seg.mesh = box
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.85, 0.92, 1.0)
		seg.material_override = m
		root.add_child(seg)
		seg.position = (a + b) * 0.5
		seg.look_at_from_position(seg.position, b, Vector3.RIGHT)
	var light := OmniLight3D.new()
	light.light_color = Color(0.7, 0.8, 1.0)
	light.light_energy = 6.0
	light.omni_range = 18.0
	light.position = Vector3(0, 2, 0)
	root.add_child(light)
	root.add_child(particles({"tex": "spark", "amount": 28, "life": 0.5, "one_shot": true, "burst": 1.0, "vel": [4.0, 10.0], "dir": Vector3.UP, "spread": 70, "gravity": Vector3(0, -9, 0),
		"size": [0.3, 0.6], "colors": [Color(1, 1, 0.9, 1), Color(0.6, 0.8, 1, 0)], "local": false}))
	root.add_child(_Ring.new().setup(TEX["ring"], Color(0.7, 0.85, 1.0), 4.0, Vector3.ZERO, 0.35))
	var tw := root.create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.3)
	tw.parallel().tween_callback(func() -> void:
		for c in root.get_children():
			if c is MeshInstance3D:
				c.queue_free()).set_delay(0.12)
	_free_after(root, 1.0)


# ================================================================= zones and persistent skill effects

## A lasting area: kind = "poison", "fire", "frost", "storm", "heal", "smoke", "sand", "arcane", "bone", "void", "time", "water", "thorn".
## Returns the node; it removes itself after `dur` seconds.
func zone(pos: Vector3, radius: float, kind: String, dur: float) -> Node3D:
	var root := Node3D.new()
	_spawn(root, pos)
	if not enabled:
		_free_after(root, dur)
		return root
	var c := zone_color(kind)
	var area := PI * radius * radius
	var k := clampf(area / 30.0, 0.6, 4.0)
	root.add_child(_Ring.new().setup(TEX["hard"], Color(c.r, c.g, c.b, 0.16), radius, Vector3(0, 0.04, 0), 0.4, false, true))
	root.add_child(_Ring.new().setup(TEX["ring"], Color(c.r, c.g, c.b, 0.7), radius, Vector3(0, 0.05, 0), 0.4, false, true))
	var base := {"shape": "ring", "radius": radius, "inner": 0.0, "ring_axis": Vector3.UP, "height": 0.2}
	match kind:
		"poison":
			root.add_child(particles(base.merged({"tex": "hard", "amount": int(18 * k), "life": 1.6, "dir": Vector3.UP, "spread": 15, "vel": [0.3, 0.9], "size": [0.1, 0.28], "additive": false,
				"size_curve": [[0, 0.2], [0.2, 1.0], [0.9, 1.0], [1, 0.0]], "colors": [Color(0.5, 0.95, 0.2, 0), Color(0.5, 0.95, 0.25, 0.8), Color(0.3, 0.7, 0.1, 0)]})))
			root.add_child(particles(base.merged({"tex": "smoke", "amount": int(10 * k), "life": 2.6, "dir": Vector3.UP, "spread": 25, "vel": [0.2, 0.6], "size": [1.4, 2.4], "additive": false,
				"colors": [Color(0.35, 0.75, 0.15, 0), Color(0.35, 0.75, 0.15, 0.28), Color(0.25, 0.55, 0.1, 0)], "turbulence": 0.4})))
		"fire":
			root.add_child(particles(base.merged({"tex": "flame", "amount": int(26 * k), "life": 0.9, "dir": Vector3.UP, "spread": 12, "vel": [0.8, 2.2], "size": [0.6, 1.1],
				"size_curve": [[0, 0.7], [0.4, 1.0], [1, 0.1]], "colors": [Color(1, 0.85, 0.3, 0.9), Color(1, 0.4, 0.1, 0.7), Color(0.4, 0.05, 0, 0)]})))
			root.add_child(particles(base.merged({"tex": "soft", "amount": int(8 * k), "life": 1.4, "dir": Vector3.UP, "spread": 20, "vel": [1.0, 3.0], "size": [0.08, 0.16],
				"colors": [Color(1, 0.8, 0.3, 1), Color(1, 0.3, 0.05, 0)], "local": false})))
		"frost":
			root.add_child(particles(base.merged({"tex": "star", "amount": int(16 * k), "life": 1.4, "dir": Vector3.UP, "spread": 20, "vel": [0.2, 0.7], "size": [0.12, 0.3], "spin": [-60, 60],
				"colors": [Color(0.8, 0.95, 1, 0), Color(0.85, 0.97, 1, 1), Color(0.6, 0.85, 1, 0)]})))
			root.add_child(particles(base.merged({"tex": "smoke", "amount": int(8 * k), "life": 2.4, "dir": Vector3.UP, "spread": 20, "vel": [0.1, 0.4], "size": [1.4, 2.2], "additive": false,
				"colors": [Color(0.8, 0.94, 1, 0), Color(0.8, 0.94, 1, 0.25), Color(0.7, 0.9, 1, 0)]})))
		"storm":
			root.add_child(particles(base.merged({"tex": "spark", "amount": int(18 * k), "life": 0.25, "dir": Vector3.UP, "spread": 90, "vel": [2.0, 6.0], "size": [0.4, 0.9], "spin": [-300, 300],
				"colors": [Color(1, 1, 0.8, 1), Color(0.6, 0.75, 1, 0)]})))
			root.add_child(particles(base.merged({"tex": "smoke", "amount": int(8 * k), "life": 2.2, "shape": "ring", "dir": Vector3.UP, "vel": [0.1, 0.3], "size": [1.6, 2.6], "additive": false,
				"colors": [Color(0.3, 0.35, 0.55, 0), Color(0.3, 0.35, 0.55, 0.3), Color(0.2, 0.2, 0.4, 0)]})))
		"heal":
			root.add_child(particles(base.merged({"tex": "star", "amount": int(18 * k), "life": 1.6, "dir": Vector3.UP, "spread": 8, "vel": [0.5, 1.2], "size": [0.12, 0.26],
				"colors": [Color(0.5, 1, 0.55, 0), Color(0.6, 1, 0.65, 1), Color(0.4, 0.9, 0.5, 0)]})))
		"smoke", "sand":
			var cc := Color(0.55, 0.55, 0.55) if kind == "smoke" else Color(0.9, 0.75, 0.4)
			root.add_child(particles(base.merged({"tex": "smoke", "amount": int(16 * k), "life": 2.2, "dir": Vector3.UP, "spread": 40, "vel": [0.3, 1.0], "size": [1.4, 2.4], "additive": false,
				"turbulence": 1.0, "colors": [Color(cc.r, cc.g, cc.b, 0), Color(cc.r, cc.g, cc.b, 0.5), Color(cc.r, cc.g, cc.b, 0)]})))
		_:
			root.add_child(particles(base.merged({"tex": "soft", "amount": int(16 * k), "life": 1.5, "dir": Vector3.UP, "spread": 18, "vel": [0.4, 1.2], "size": [0.2, 0.45], "tangent": [1.0, 2.0],
				"colors": [Color(c.r, c.g, c.b, 0), Color(c.r, c.g, c.b, 0.8), Color(c.r, c.g, c.b, 0)]})))
	var tw := root.create_tween()
	tw.tween_interval(maxf(dur - 0.6, 0.1))
	tw.tween_callback(func() -> void:
		for ch in root.get_children():
			if ch is GPUParticles3D:
				ch.emitting = false)
	_free_after(root, dur + 2.5)
	return root


func zone_color(kind: String) -> Color:
	match kind:
		"poison": return Color(0.45, 0.9, 0.2)
		"fire": return Color(1.0, 0.45, 0.1)
		"frost": return Color(0.6, 0.88, 1.0)
		"storm": return Color(0.9, 0.9, 0.4)
		"heal": return Color(0.5, 1.0, 0.55)
		"smoke": return Color(0.6, 0.6, 0.6)
		"sand": return Color(0.9, 0.75, 0.4)
		"bone": return Color(0.85, 0.85, 0.75)
		"void": return Color(0.5, 0.25, 0.8)
		"time": return Color(0.95, 0.8, 0.4)
		"water": return Color(0.3, 0.7, 1.0)
		"thorn": return Color(0.4, 0.75, 0.25)
	return Color(0.7, 0.5, 1.0)


# ================================================================= numbers, rewards, crates, auras

func damage_number(pos: Vector3, amount: float, color: Color = Color(1, 1, 1), crit: bool = false, heal: bool = false) -> void:
	var l := Label3D.new()
	l.text = ("+" if heal else "") + str(int(round(amount)))
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0016 if not crit else 0.0022
	l.no_depth_test = true
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.modulate = Color(0.5, 1.0, 0.5) if heal else (Color(1.0, 0.85, 0.2) if crit else color)
	l.font_size = 48
	l.render_priority = 5
	_spawn(l, pos + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3)))
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y + 1.4, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.tween_callback(l.queue_free)


func level_up(target: Node3D) -> void:
	if not enabled:
		return
	var root := Node3D.new()
	target.add_child(root)
	root.add_child(_Ring.new().setup(TEX["ring"], Color(1, 0.9, 0.4), 3.0, Vector3(0, 0.05, 0), 0.7))
	root.add_child(particles({"tex": "star", "amount": 30, "life": 1.2, "one_shot": true, "burst": 0.8, "shape": "ring", "radius": 0.7, "dir": Vector3.UP, "spread": 8, "vel": [2.0, 4.0],
		"size": [0.15, 0.32], "colors": [Color(1, 0.95, 0.5, 1), Color(1, 0.8, 0.2, 0)]}))
	_free_after(root, 2.0)


## A vertical column of light in the rarity colour (loot crates, drops). Persistent; the caller frees it.
func crate_beam(rarity_id: String, height: float = 6.0) -> Node3D:
	var root := Node3D.new()
	var c := Data.rarity_color(rarity_id)
	var glow: float = float(Data.rarity(rarity_id)["glow"])
	if not enabled:
		return root
	root.add_child(particles({"tex": "soft", "amount": int(10 + 20 * glow), "life": 1.8, "shape": "ring", "radius": 0.5, "dir": Vector3.UP, "spread": 4, "vel": [1.0, 2.5],
		"size": [0.12, 0.3], "colors": [Color(c.r, c.g, c.b, 0), Color(c.r, c.g, c.b, 0.9), Color(c.r, c.g, c.b, 0)]}))
	if glow > 0.05:
		var beam_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.18
		cyl.bottom_radius = 0.32
		cyl.height = height
		beam_mesh.mesh = cyl
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.albedo_color = Color(c.r, c.g, c.b, 0.12 + 0.16 * glow)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam_mesh.material_override = m
		beam_mesh.position = Vector3(0, height * 0.5, 0)
		root.add_child(beam_mesh)
	var light := OmniLight3D.new()
	light.light_color = c
	light.light_energy = 0.6 + 2.0 * glow
	light.omni_range = 5.0 + 4.0 * glow
	light.position = Vector3(0, 1.0, 0)
	root.add_child(light)
	return root


func crate_burst(pos: Vector3, rarity_id: String) -> void:
	var c := Data.rarity_color(rarity_id)
	var root := Node3D.new()
	_spawn(root, pos)
	root.add_child(particles({"tex": "star", "amount": 40, "life": 1.4, "one_shot": true, "burst": 1.0, "vel": [3.0, 8.0], "dir": Vector3.UP, "spread": 60, "gravity": Vector3(0, -6, 0),
		"size": [0.2, 0.45], "colors": [Color(1, 1, 1, 1), Color(c.r, c.g, c.b, 0.9), Color(c.r, c.g, c.b, 0)], "local": false}))
	root.add_child(_Ring.new().setup(TEX["ring"], c, 4.5, Vector3(0, 0.05, 0), 0.6))
	_free_after(root, 2.5)


## Aura around a character: "gold" (legendary modified gear) or a mythic aura id ("flames", "stars", "void", "embers", "aurora", "mist").
func aura(id: String, height: float = 1.85) -> Node3D:
	var root := Node3D.new()
	if not enabled:
		return root
	var a := _aura_def(id)
	var c: Color = a["color"]
	root.add_child(_at(particles({"tex": a["tex"], "amount": 18, "life": 1.3, "shape": "ring", "radius": 0.6, "dir": Vector3.UP, "spread": 6, "vel": [0.5, 1.2],
		"size": [0.15, 0.32], "size_curve": [[0, 0.5], [0.3, 1.0], [1, 0.0]], "tangent": [a["spin"], a["spin"] + 0.5],
		"colors": [Color(c.r, c.g, c.b, 0), Color(c.r, c.g, c.b, 0.85), Color(c.r, c.g, c.b, 0)]}), Vector3(0, 0.1, 0)))
	root.add_child(_Ring.new().setup(TEX["ring"], Color(c.r, c.g, c.b, 0.45), 1.1, Vector3(0, 0.04, 0), 1.4, true, true))
	if a["mythic"]:
		root.add_child(_at(particles({"tex": "soft", "amount": 10, "life": 1.6, "shape": "sphere", "radius": 0.5, "vel": [0.0, 0.3], "size": [0.4, 0.8],
			"colors": [Color(c.r, c.g, c.b, 0), Color(c.r, c.g, c.b, 0.25), Color(c.r, c.g, c.b, 0)]}), Vector3(0, height * 0.5, 0)))
	return root


func _aura_def(id: String) -> Dictionary:
	match id:
		"flames": return {"color": Color(1.0, 0.4, 0.1), "tex": "flame", "spin": 0.0, "mythic": true}
		"stars": return {"color": Color(0.7, 0.8, 1.0), "tex": "star", "spin": 1.0, "mythic": true}
		"void": return {"color": Color(0.5, 0.2, 0.8), "tex": "smoke", "spin": 1.5, "mythic": true}
		"embers": return {"color": Color(1.0, 0.5, 0.2), "tex": "soft", "spin": 0.5, "mythic": true}
		"aurora": return {"color": Color(0.4, 1.0, 0.8), "tex": "star", "spin": 0.5, "mythic": true}
		"mist": return {"color": Color(0.5, 0.9, 0.6), "tex": "smoke", "spin": 0.3, "mythic": true}
	return {"color": Color(1.0, 0.8, 0.25), "tex": "star", "spin": 0.5, "mythic": false}      # gold


# ================================================================= map hazards (ambient, persistent)

## kind: "lava", "steam", "poison_water", "quicksand", "snow", "embers", "bubbles", "spores", "moon_dust", "fog_wisp"
func hazard(kind: String, radius: float) -> Node3D:
	var root := Node3D.new()
	if not enabled:
		return root
	var shape := {"shape": "ring", "radius": radius, "inner": 0.0, "ring_axis": Vector3.UP, "height": 0.1}
	match kind:
		"lava":
			root.add_child(particles(shape.merged({"tex": "soft", "amount": 14, "life": 2.0, "dir": Vector3.UP, "spread": 25, "vel": [1.5, 4.0], "gravity": Vector3(0, -2, 0), "size": [0.08, 0.16],
				"colors": [Color(1, 0.8, 0.3, 1), Color(1, 0.35, 0.05, 0.8), Color(0.3, 0.05, 0, 0)], "local": false})))
		"steam":
			root.add_child(particles(shape.merged({"tex": "smoke", "amount": 14, "life": 1.8, "dir": Vector3.UP, "spread": 12, "vel": [2.0, 4.0], "size": [1.0, 2.0], "additive": false,
				"colors": [Color(0.95, 0.95, 0.95, 0.0), Color(0.95, 0.95, 0.95, 0.5), Color(0.8, 0.8, 0.8, 0)]})))
		"poison_water", "bubbles":
			root.add_child(particles(shape.merged({"tex": "hard", "amount": 14, "life": 1.4, "dir": Vector3.UP, "spread": 10, "vel": [0.3, 0.8], "size": [0.12, 0.3], "additive": false,
				"colors": [Color(0.5, 0.95, 0.25, 0.0), Color(0.5, 0.95, 0.25, 0.8), Color(0.3, 0.7, 0.15, 0)]})))
		"quicksand":
			root.add_child(particles(shape.merged({"tex": "smoke", "amount": 12, "life": 1.6, "dir": Vector3.UP, "spread": 30, "vel": [0.3, 1.0], "size": [0.6, 1.2], "additive": false, "tangent": [0.5, 1.0],
				"colors": [Color(0.85, 0.7, 0.4, 0.0), Color(0.85, 0.7, 0.4, 0.45), Color(0.7, 0.55, 0.3, 0)]})))
		"snow":
			root.add_child(particles({"tex": "soft", "amount": 60, "life": 3.5, "shape": "box", "extents": Vector3(radius, 0.5, radius), "dir": Vector3.DOWN, "spread": 20, "vel": [0.6, 1.2],
				"size": [0.05, 0.1], "colors": [Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)], "turbulence": 0.5, "local": false}))
		"spores":
			root.add_child(particles(shape.merged({"tex": "soft", "amount": 14, "life": 2.5, "dir": Vector3.UP, "spread": 40, "vel": [0.1, 0.5], "size": [0.1, 0.22], "turbulence": 0.6,
				"colors": [Color(0.9, 0.8, 0.4, 0), Color(0.95, 0.85, 0.5, 0.8), Color(0.9, 0.8, 0.4, 0)]})))
		"moon_dust":
			root.add_child(particles(shape.merged({"tex": "star", "amount": 14, "life": 2.5, "dir": Vector3.UP, "spread": 30, "vel": [0.1, 0.5], "size": [0.1, 0.22],
				"colors": [Color(0.8, 0.85, 1, 0), Color(0.85, 0.9, 1, 1), Color(0.8, 0.85, 1, 0)]})))
		_:
			root.add_child(particles(shape.merged({"tex": "smoke", "amount": 8, "life": 3.0, "dir": Vector3.UP, "spread": 40, "vel": [0.1, 0.4], "size": [1.2, 2.0], "additive": false,
				"colors": [Color(0.6, 0.6, 0.75, 0), Color(0.6, 0.6, 0.75, 0.25), Color(0.5, 0.5, 0.65, 0)]})))
	return root


# ================================================================= helper nodes

## A flat textured disc/ring on the ground that grows (or stays) and fades.
class _Ring extends MeshInstance3D:
	var _mat: StandardMaterial3D
	var _life := 0.5
	var _grow := true
	var _loop := false
	var _radius := 1.0
	var _t := 0.0
	var _start_a := 1.0

	func setup(tex: Texture2D, color: Color, radius: float, offset: Vector3, life: float = 0.5, grow: bool = true, loop: bool = false) -> _Ring:
		var q := QuadMesh.new()
		q.size = Vector2(radius * 2.0, radius * 2.0)
		q.orientation = PlaneMesh.FACE_Y
		mesh = q
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat.albedo_texture = tex
		_mat.albedo_color = color
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.no_depth_test = false
		_mat.render_priority = -1
		material_override = _mat
		position = offset + Vector3(0, 0.05, 0)
		_life = life
		_grow = grow
		_loop = loop
		_radius = radius
		_start_a = color.a
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if grow:
			scale = Vector3(0.15, 1, 0.15)
		return self

	func _process(delta: float) -> void:
		_t += delta
		var k := clampf(_t / maxf(_life, 0.01), 0.0, 1.0)
		if _loop:
			_mat.albedo_color.a = _start_a * (0.75 + 0.25 * sin(_t * 3.0))
			return
		if _grow:
			var s := lerpf(0.15, 1.0, 1.0 - pow(1.0 - k, 3.0))
			scale = Vector3(s, 1, s)
			_mat.albedo_color.a = _start_a * (1.0 - k)
		else:
			_mat.albedo_color.a = _start_a * (0.6 + 0.4 * k)             # a telegraph gets stronger until it lands


## Stars orbiting above a head (stun).
class _StarRing extends Node3D:
	var _t := 0.0

	func setup(tex: Texture2D, color: Color) -> void:
		for i in 3:
			var s := Sprite3D.new()
			s.texture = tex
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.modulate = color
			s.pixel_size = 0.004
			s.shaded = false
			s.set_meta("a", TAU * i / 3.0)
			add_child(s)

	func _process(delta: float) -> void:
		_t += delta * 4.0
		for s in get_children():
			var a: float = s.get_meta("a") + _t
			s.position = Vector3(cos(a) * 0.4, 0.0, sin(a) * 0.4)
