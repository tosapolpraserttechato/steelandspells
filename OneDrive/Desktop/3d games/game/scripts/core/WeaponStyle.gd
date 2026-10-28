class_name WeaponStyle
extends RefCounted
## Gives every weapon model the same clean, hand-painted look (see shaders/painted_weapon.gdshader).
## The free low-poly weapon packs all have different flat colours; this paints every one of them the same way, so the whole armoury looks like one set.
## The shapes are not changed: the detail is in the paint (shaded steel, an engraved line on blades, wrapped grips, brass trim, glowing gems and inlays).

const SHADER := "res://shaders/painted_weapon.gdshader"
const STEEL := {"burn": Color(0.52, 0.4, 0.36), "chill": Color(0.45, 0.6, 0.75), "shock": Color(0.56, 0.58, 0.46), "poison": Color(0.42, 0.56, 0.4), "weaken": Color(0.46, 0.4, 0.56),
	"slow": Color(0.45, 0.55, 0.68), "bleed": Color(0.55, 0.4, 0.42), "marked": Color(0.55, 0.42, 0.5), "stun": Color(0.58, 0.54, 0.4), "vulnerable": Color(0.55, 0.45, 0.5)}
const NEUTRAL := Color(0.5, 0.52, 0.55)
const GLOW := {"staff": 0.9, "wand": 0.9, "orb": 1.0, "tome": 0.8, "enchblade": 1.0, "gauntlet": 0.9, "spiritbow": 1.0}

static var _shader: Shader
static var _noise_a: ImageTexture
static var _cache: Dictionary = {}


static func _make_noise() -> void:
	if _noise_a != null:
		return
	var n := FastNoiseLite.new()
	n.seed = 11
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 3
	_noise_a = ImageTexture.create_from_image(n.get_seamless_image(128, 128))


static func _v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


static func _material_for(src: Material, w: Dictionary, info: Dictionary, skin: Dictionary = {}, worn: bool = false) -> ShaderMaterial:
	_make_noise()
	if _shader == null:
		_shader = load(SHADER)
	var el := ""
	if w.has("on_hit"):
		el = String(w["on_hit"]["id"])
	var key := "%d|%s|%s|%s|%s" % [src.get_instance_id() if src != null else 0, w.get("id", ""), el, skin.get("id", ""), worn]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("noise_a", _noise_a)
	if src is BaseMaterial3D:
		var bm := src as BaseMaterial3D
		m.set_shader_parameter("src_col", bm.albedo_color)
		if bm.albedo_texture != null:
			m.set_shader_parameter("src_tex", bm.albedo_texture)
			m.set_shader_parameter("use_tex", true)
	var glow := Weapons.color_for(w)
	var gs: float = GLOW.get(String(w.get("family", "")), 0.0) if bool(w.get("magic", false)) else 0.0
	if el != "" and gs == 0.0 and el in ["burn", "chill", "shock", "poison"]:
		gs = 0.25
	m.set_shader_parameter("glow_color", _v3(glow))
	m.set_shader_parameter("glow_strength", gs)
	m.set_shader_parameter("steel_tint", _v3(STEEL.get(el, NEUTRAL)))
	m.set_shader_parameter("unit", info["unit"])
	m.set_shader_parameter("center", info["center"])
	m.set_shader_parameter("ax_long", info["long"])
	m.set_shader_parameter("ax_width", info["width"])
	m.set_shader_parameter("crystal", String(w.get("family", "")) == "orb")
	m.set_shader_parameter("wear", 0.95 if worn else 0.0)
	if not skin.is_empty():                            # a skin pasted over the weapon: its paint, and its glow if it has one
		var tint := Color.html(String(skin["tint"]))
		m.set_shader_parameter("skin_tint", _v3(tint))
		m.set_shader_parameter("skin_mix", 0.82)
		if String(skin.get("glow", "")) != "":
			var gc := Color.html(String(skin["glow"]))
			m.set_shader_parameter("glow_color", _v3(gc))
			m.set_shader_parameter("glow_strength", maxf(gs, 0.7))
		if String(w.get("family", "")) == "orb":
			m.set_shader_parameter("glow_color", _v3(tint.lerp(Color.html(String(skin.get("glow", "#ffffff"))) if String(skin.get("glow", "")) != "" else tint, 0.5)))
	_cache[key] = m
	return m


## Re-paints every surface under `root`. Safe to call again with another weapon.
static func apply(root: Node, w: Dictionary, skin: Dictionary = {}, worn: bool = false) -> void:
	var info := _shape_of(root)
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null:
			continue
		for s in inst.mesh.get_surface_count():
			var src: Material = inst.mesh.surface_get_material(s)
			if src == null:
				src = inst.get_active_material(s)
			inst.set_surface_override_material(s, _material_for(src, w, info, skin, worn))
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Size, centre and the long / width directions of the model (in the models' own space), so the paint lines up on every weapon.
static func _shape_of(root: Node) -> Dictionary:
	var box := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if g.mesh == null:
			continue
		var b := g.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var sz := box.size
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var order := [0, 1, 2]
	order.sort_custom(func(a: int, b: int) -> bool: return sz[a] > sz[b])
	return {"unit": maxf(sz[order[0]], 0.01), "center": box.get_center(), "long": axes[order[0]], "width": axes[order[1]]}
