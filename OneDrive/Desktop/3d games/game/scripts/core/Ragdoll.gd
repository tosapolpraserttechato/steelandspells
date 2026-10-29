class_name Ragdoll
extends RefCounted
## Death as a ragdoll: the body of a fallen fighter is handed to physics. Every important bone gets a capsule-shaped rigid body, joined to its parent bone with limits for how far it may bend,
## and they collide with the map only. The hit that killed pushes the body away from the attacker. The skeleton follows the bodies, so the model collapses, rolls and settles on whatever it
## lands on (steps, slopes, ledges). Undone when the fighter respawns.
##   bone, parent bone (the physical bone it is joined to), capsule radius, mass, swing limit (degrees), twist limit (degrees)

const PARTS := [
	["DEF-hips", "", 0.15, 11.0, 0.0, 0.0],
	["DEF-spine.001", "DEF-hips", 0.14, 8.0, 28.0, 22.0],
	["DEF-spine.003", "DEF-spine.001", 0.15, 9.0, 28.0, 22.0],
	["DEF-head", "DEF-spine.003", 0.1, 4.0, 40.0, 35.0],
	["DEF-upper_arm.L", "DEF-spine.003", 0.055, 2.2, 85.0, 50.0],
	["DEF-forearm.L", "DEF-upper_arm.L", 0.045, 1.6, 75.0, 8.0],
	["DEF-upper_arm.R", "DEF-spine.003", 0.055, 2.2, 85.0, 50.0],
	["DEF-forearm.R", "DEF-upper_arm.R", 0.045, 1.6, 75.0, 8.0],
	["DEF-thigh.L", "DEF-hips", 0.085, 5.5, 70.0, 25.0],
	["DEF-shin.L", "DEF-thigh.L", 0.065, 3.5, 70.0, 6.0],
	["DEF-foot.L", "DEF-shin.L", 0.05, 1.2, 30.0, 10.0],
	["DEF-thigh.R", "DEF-hips", 0.085, 5.5, 70.0, 25.0],
	["DEF-shin.R", "DEF-thigh.R", 0.065, 3.5, 70.0, 6.0],
	["DEF-foot.R", "DEF-shin.R", 0.05, 1.2, 30.0, 10.0],
]
# the bone that marks where each part ends (its length runs from the bone to this one)
const TIPS := {
	"DEF-hips": "DEF-spine.001", "DEF-spine.001": "DEF-spine.003", "DEF-spine.003": "DEF-head", "DEF-head": "", "DEF-upper_arm.L": "DEF-forearm.L", "DEF-forearm.L": "DEF-hand.L",
	"DEF-upper_arm.R": "DEF-forearm.R", "DEF-forearm.R": "DEF-hand.R", "DEF-thigh.L": "DEF-shin.L", "DEF-shin.L": "DEF-foot.L", "DEF-foot.L": "DEF-toe.L",
	"DEF-thigh.R": "DEF-shin.R", "DEF-shin.R": "DEF-foot.R", "DEF-foot.R": "DEF-toe.R",
}


## Starts the ragdoll on a model. `push` is the velocity (m/s, world space) given to the whole body at the moment of death. Returns false when the model cannot do it.
static func start(model: CharacterModel, push: Vector3) -> bool:
	var sk := model.skeleton
	if sk == null:
		return false
	stop(model)
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = "Ragdoll"
	sk.add_child(sim)
	var made := 0
	for part in PARTS:
		var bone := String(part[0])
		var bi := sk.find_bone(bone)
		if bi < 0:
			continue
		var pb := PhysicalBone3D.new()
		pb.name = "RB_" + bone
		sim.add_child(pb)                                                  # (its bone_name is set after it has a skeleton above it)
		pb.bone_name = bone
		var tip := sk.find_bone(String(TIPS.get(bone, "")))
		var length := 0.2
		if tip >= 0:
			length = maxf(0.08, (sk.get_bone_global_rest(tip).origin - sk.get_bone_global_rest(bi).origin).length())
		var radius := float(part[2])
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = maxf(length, radius * 2.0 + 0.01)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		pb.add_child(cs)
		pb.body_offset = Transform3D(Basis.IDENTITY, Vector3(0, length * 0.5, 0))           # the capsule lies along the bone (its +Y)
		pb.mass = float(part[3])
		pb.collision_layer = 0
		pb.collision_mask = 1                                              # the map only: no bumping into other fighters or itself
		pb.linear_damp = 0.12
		pb.angular_damp = 2.4
		pb.friction = 0.9
		pb.bounce = 0.05
		if String(part[1]) != "":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", float(part[4]))
			pb.set("joint_constraints/twist_span", float(part[5]))
		made += 1
	if made < 6:
		sim.queue_free()
		return false
	model.anim.active = false                                              # the clips stop posing the skeleton; the bodies take over
	sim.physical_bones_start_simulation()
	for c in sim.get_children():
		if c is PhysicalBone3D:
			var b := c as PhysicalBone3D
			b.linear_velocity = push
			b.angular_velocity = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 1.2
	model.set_meta("ragdoll", sim)
	return true


static func stop(model: CharacterModel) -> void:
	if model == null or not model.has_meta("ragdoll"):
		return
	var sim = model.get_meta("ragdoll")
	model.remove_meta("ragdoll")
	if is_instance_valid(sim):
		(sim as PhysicalBoneSimulator3D).physical_bones_stop_simulation()
		(sim as PhysicalBoneSimulator3D).queue_free()
	if model.anim != null:
		model.anim.active = true
