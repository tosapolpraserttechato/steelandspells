class_name AtmosphereFx
extends Node3D
## Magic drifting in the air around the player, different on every map: fireflies in the forest, bubbles under the sea, embers in the forge,
## snow and sparkles on the peaks, wisps in the crypt... A box of slow particles that follows the player.

const KINDS := {
	"flora_forest": {"tex": "soft", "amount": 64, "life": 7.0, "vel": [0.05, 0.3], "size": [0.1, 0.2], "colors": [Color(1.0, 0.95, 0.5, 0.0), Color(1.0, 0.95, 0.5, 0.95), Color(0.7, 1.0, 0.4, 0.0)], "turbulence": 0.9, "gravity": Vector3(0, 0.03, 0)},
	"underwater_ocean": {"tex": "ring", "amount": 80, "life": 7.0, "vel": [0.3, 0.9], "size": [0.06, 0.18], "colors": [Color(0.8, 1.0, 1.0, 0.0), Color(0.8, 1.0, 1.0, 0.55), Color(0.8, 1.0, 1.0, 0.0)], "turbulence": 0.5, "gravity": Vector3(0, 0.25, 0)},
	"volcano_forge": {"tex": "spark", "amount": 70, "life": 5.0, "vel": [0.3, 1.2], "size": [0.08, 0.2], "colors": [Color(1.0, 0.75, 0.3, 0.0), Color(1.0, 0.5, 0.15, 0.95), Color(0.6, 0.15, 0.05, 0.0)], "turbulence": 1.4, "gravity": Vector3(0, 0.5, 0)},
	"frozen_peaks": {"tex": "soft", "amount": 150, "life": 7.0, "vel": [0.1, 0.4], "size": [0.06, 0.13], "colors": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.9), Color(0.8, 0.9, 1.0, 0.0)], "turbulence": 0.8, "gravity": Vector3(0.15, -0.9, 0.05)},
	"shadow_crypt": {"tex": "soft", "amount": 36, "life": 8.0, "vel": [0.05, 0.25], "size": [0.3, 0.6], "colors": [Color(0.7, 0.6, 1.0, 0.0), Color(0.75, 0.65, 1.0, 0.28), Color(0.7, 0.6, 1.0, 0.0)], "turbulence": 0.6, "gravity": Vector3(0, 0.05, 0)},
	"toxic_swamp": {"tex": "soft", "amount": 60, "life": 7.0, "vel": [0.05, 0.3], "size": [0.1, 0.24], "colors": [Color(0.6, 1.0, 0.3, 0.0), Color(0.6, 1.0, 0.3, 0.6), Color(0.4, 0.8, 0.2, 0.0)], "turbulence": 0.7, "gravity": Vector3(0, 0.12, 0)},
	"crystal_caves": {"tex": "star", "amount": 60, "life": 6.0, "vel": [0.03, 0.2], "size": [0.06, 0.16], "colors": [Color(0.5, 0.95, 1.0, 0.0), Color(0.6, 0.95, 1.0, 0.95), Color(0.6, 0.6, 1.0, 0.0)], "turbulence": 0.5, "gravity": Vector3(0, 0.04, 0), "spin": [-40.0, 40.0]},
	"clockwork_mines": {"tex": "spark", "amount": 40, "life": 4.0, "vel": [0.2, 0.8], "size": [0.05, 0.12], "colors": [Color(1.0, 0.85, 0.4, 0.0), Color(1.0, 0.7, 0.25, 0.9), Color(0.5, 0.3, 0.1, 0.0)], "turbulence": 1.0, "gravity": Vector3(0, 0.3, 0)},
	"moon_sanctuary": {"tex": "star", "amount": 70, "life": 7.0, "vel": [0.03, 0.2], "size": [0.07, 0.18], "colors": [Color(0.8, 0.88, 1.0, 0.0), Color(0.85, 0.9, 1.0, 0.9), Color(0.7, 0.7, 1.0, 0.0)], "turbulence": 0.5, "gravity": Vector3(0, 0.06, 0), "spin": [-30.0, 30.0]},
	"desert_tomb": {"tex": "soft", "amount": 80, "life": 6.0, "vel": [0.2, 0.8], "size": [0.05, 0.12], "colors": [Color(1.0, 0.88, 0.55, 0.0), Color(1.0, 0.85, 0.5, 0.55), Color(1.0, 0.8, 0.4, 0.0)], "turbulence": 1.0, "gravity": Vector3(0.7, 0.05, 0.2)},
	"pirate_cove": {"tex": "soft", "amount": 40, "life": 5.0, "vel": [0.3, 1.0], "size": [0.05, 0.1], "colors": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.6), Color(0.9, 0.95, 1.0, 0.0)], "turbulence": 0.8, "gravity": Vector3(0.9, 0.0, 0.2)},
	"chess_arena": {"tex": "star", "amount": 48, "life": 6.0, "vel": [0.05, 0.25], "size": [0.08, 0.18], "colors": [Color(1.0, 0.85, 0.4, 0.0), Color(1.0, 0.88, 0.5, 0.95), Color(1.0, 0.7, 0.3, 0.0)], "turbulence": 0.4, "gravity": Vector3(0, 0.1, 0), "spin": [-40.0, 40.0]},
	"sky_islands": {"tex": "soft", "amount": 48, "life": 8.0, "vel": [0.1, 0.4], "size": [0.1, 0.22], "colors": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.5), Color(0.9, 0.95, 1.0, 0.0)], "turbulence": 0.8, "gravity": Vector3(0.3, 0.1, 0.1)},
}

var target: Node3D
var _emitter: Node3D


static func attach(parent: Node3D, map_id: String, follow: Node3D) -> AtmosphereFx:
	var a := AtmosphereFx.new()
	a.target = follow
	parent.add_child(a)
	a.setup(map_id)
	return a


func setup(map_id: String) -> void:
	var k: Dictionary = KINDS.get(map_id, KINDS["flora_forest"])
	var o: Dictionary = k.duplicate()
	o["shape"] = "box"
	o["extents"] = Vector3(16, 5, 16)
	o["dir"] = Vector3.UP
	o["spread"] = 180.0
	o["local"] = false
	_emitter = Fx.particles(o)
	(_emitter as GPUParticles3D).visibility_aabb = AABB(Vector3(-24, -10, -24), Vector3(48, 24, 48))
	add_child(_emitter)


func _process(_delta: float) -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position + Vector3(0, 2.0, 0)
