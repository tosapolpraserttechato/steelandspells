class_name WeaponIcons
extends Node
## Pictures of the real weapon models for item cards: each weapon is rendered once in its painted look (WeaponStyle) on a transparent background, lying
## diagonally like an inventory icon, and kept as a texture. Cards ask with `texture_for` and redraw when `icon_ready` fires.

signal icon_ready(weapon_id: String)

static var inst: WeaponIcons
static var _cache: Dictionary = {}
static var _queue: Array = []
static var _busy := false


static func texture_for(w: Dictionary) -> Texture2D:
	var id := String(w.get("id", ""))
	if _cache.has(id):
		return _cache[id]
	if inst == null or not is_instance_valid(inst):
		inst = WeaponIcons.new()
		(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(inst)
	if not _queue.any(func(q: Dictionary) -> bool: return q["id"] == id):
		_queue.append(w)
		inst._kick.call_deferred()
	return null


func _kick() -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	var w: Dictionary = _queue.pop_front()
	await _render(w)
	_busy = false
	_kick()


func _render(w: Dictionary) -> void:
	var id := String(w["id"])
	var info := Weapons.visual_for(w)
	if String(info["path"]) == "" or not ResourceLoader.exists(String(info["path"])):
		_cache[id] = null
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(192, 192)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.95)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 30, 0)
	key.light_energy = 1.5
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, -140, 0)
	rim.light_energy = 0.8
	rim.light_color = Color(0.7, 0.8, 1.0)
	vp.add_child(rim)
	var holder := Node3D.new()
	vp.add_child(holder)
	var m: Node3D = (load(String(info["path"])) as PackedScene).instantiate()
	holder.add_child(m)
	var box := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		var b := g.get_aabb()
		box = b if first else box.merge(b)
		first = false
	WeaponStyle.apply(m, w)
	var sz := box.size
	var long_axis := sz.max_axis_index()
	var longest: float = maxf(maxf(sz.x, sz.y), sz.z)
	var k := 1.5 / maxf(longest, 0.001)
	m.scale = Vector3.ONE * k
	m.position = -box.get_center() * k
	# stand the long axis up, then lean it over to the diagonal
	match long_axis:
		0: holder.basis = Basis(Vector3(0, 0, 1), deg_to_rad(45.0))
		2: holder.basis = Basis(Vector3(0, 0, 1), deg_to_rad(-45.0)) * Basis(Vector3(1, 0, 0), deg_to_rad(-90.0))
		_: holder.basis = Basis(Vector3(0, 0, 1), deg_to_rad(-45.0))
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 2.2)
	cam.fov = 36
	vp.add_child(cam)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img != null:
		_cache[id] = ImageTexture.create_from_image(img)
	else:
		_cache[id] = null
	icon_ready.emit(id)
