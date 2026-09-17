extends Node3D
## Presentation only. Never changes capsule, speed, or saved floor state.
const IDS := ["detective", "detective_woman", "realistic_female"]
const NAMES := ["Detective Masculino", "Detective Femenino", "Exploradora"]
@export_enum("Detective Masculino", "Detective Femenino", "Exploradora") var character := 0
@export var first_person := false
var model: Node3D
var rig: Skeleton3D
var bones := {}
var meshes: Array[MeshInstance3D] = []
var phase := 0.0
var initialized := false
# Fitted transform of the unrigged model, reused by its crouch/walk motion.
var base_scale := Vector3.ONE
var base_height := 0.0

func _ready() -> void: configure(character, first_person)

func configure(index: int, local_view: bool) -> void:
	character = clampi(index, 0, IDS.size() - 1)
	first_person = local_view
	if model != null:
		remove_child(model)
		model.queue_free()
	rig = null
	bones.clear()
	meshes.clear()
	if character == 0:
		model = MeshInstance3D.new()
		model.mesh = load("res://game/player/avatars/detective_relaxed.res")
	else: model = load("res://assets/players/%s/model.fbx" % IDS[character]).instantiate()
	model.name = "Model"
	add_child(model)
	# Imported demonstration clips are preserved but never drive game root motion.
	for animation in model.find_children("*", "AnimationPlayer", true, false):
		if character == 2:
			animation.play(animation.get_animation_list()[0])
			animation.advance(0.0)
			animation.pause()
		else: animation.stop()
	if model is MeshInstance3D: meshes.append(model)
	for mesh in model.find_children("*", "MeshInstance3D", true, false): meshes.append(mesh)
	var bounds := AABB()
	var first := true
	for mesh in meshes:
		var box: AABB = global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		mesh.layers = 2 if first_person else 1
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var size_factor := 1.78 / maxf(bounds.size.y, 0.01)
	model.scale *= size_factor
	model.position.y -= bounds.position.y * size_factor
	model.rotation.y += PI
	base_scale = model.scale
	base_height = model.position.y
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if not rigs.is_empty():
		# Some models carry a small accessory skeleton too; animate the body one.
		rigs.sort_custom(func(a, b): return a.get_bone_count() > b.get_bone_count())
		rig = rigs[0]
		var names := {"hip":"mixamorig_Hips", "spine":"mixamorig_Spine", "la":"mixamorig_LeftArm", "lf":"mixamorig_LeftForeArm", "ra":"mixamorig_RightArm", "rf":"mixamorig_RightForeArm", "lt":"mixamorig_LeftUpLeg", "lk":"mixamorig_LeftLeg", "rt":"mixamorig_RightUpLeg", "rk":"mixamorig_RightLeg"} if character == 1 else {"hip":"CC_Base_Hip", "spine":"CC_Base_Spine01", "la":"CC_Base_L_Upperarm", "lf":"CC_Base_L_Forearm", "ra":"CC_Base_R_Upperarm", "rf":"CC_Base_R_Forearm", "lt":"CC_Base_L_Thigh", "lk":"CC_Base_L_Calf", "rt":"CC_Base_R_Thigh", "rk":"CC_Base_R_Calf"}
		for key in names: bones[key] = rig.find_bone(names[key])
	initialized = true
	update_pose(Vector3.ZERO, false, 0)

func rotate_bone(key: String, axis: Vector3, angle: float) -> void:
	var id: int = bones.get(key, -1)
	if id < 0: return
	var pose := rig.get_bone_global_pose(id)
	pose.basis = Basis(axis, angle) * pose.basis
	rig.set_bone_global_pose(id, pose)

func update_pose(velocity: Vector3, crouching: bool, delta: float) -> void:
	if not initialized: return
	var speed := Vector2(velocity.x, velocity.z).length()
	phase += delta * speed * 2.5
	if rig == null:
		# The OBJ has no bones: only a restrained whole-body walking motion.
		model.position.y = base_height + (absf(sin(phase)) * 0.015 if speed > 0.1 else 0.0)
		model.scale.y = base_scale.y * (0.59 if crouching else 1.0)
		return
	rig.reset_bone_poses()
	var right := (rig.global_basis.inverse() * global_basis * Vector3.RIGHT).normalized()
	var down := (rig.global_basis.inverse() * global_basis * Vector3.DOWN).normalized()
	var forward := (rig.global_basis.inverse() * global_basis * Vector3.FORWARD).normalized()
	var stride := sin(phase) * minf(speed / 6.0, 1.0) * 0.55
	if crouching:
		var hip := rig.get_bone_global_pose(bones.hip)
		hip.origin += rig.global_basis.inverse() * global_basis * Vector3.DOWN * 0.48
		rig.set_bone_global_pose(bones.hip, hip)
		rotate_bone("spine", right, 0.55)
	for pair in [["la", "lf", -1.0], ["ra", "rf", 1.0]]:
		var a: int = bones[pair[0]]
		var b: int = bones[pair[1]]
		if a < 0 or b < 0: continue
		var pose := rig.get_bone_global_pose(a)
		var direction := (rig.get_bone_global_pose(b).origin - pose.origin).normalized()
		var target: Vector3 = (down + right * pair[2] * 0.12 + forward * stride * pair[2]).normalized()
		pose.basis = Basis(Quaternion(direction, target)) * pose.basis
		rig.set_bone_global_pose(a, pose)
	for side in ["l", "r"]:
		var swing := stride * (1 if side == "l" else -1)
		rotate_bone(side + "t", right, (1.35 if crouching else 0.0) + swing)
		rotate_bone(side + "k", right, -2.25 if crouching else -maxf(0, -swing))
