extends Node3D
## The Lurker as it is seen (docs/LURKER.md): the model, its hands on whatever
## is near (lurker_limbs.gd), and the darkness it carries. Its body is black
## and takes no light at all (lurker_body.tres); round it the dark is ink, or
## a thick black vapour, always moving (lurker_darkness.gdshader): dense and
## torn along the body, and in rags a little further out. Only the face is
## left to be seen, and it and the eyes are always on the camera.
##
## Presentation only: whoever moves it sets its transform (its up is the
## surface it clings to, its +Z the way it faces) and `velocity`.
const LIMBS := preload("res://game/enemies/lurker/lurker_limbs.gd")
const DARKNESS := preload("res://game/enemies/lurker/lurker_darkness.gdshader")
## Render layer 3, its own. (Layer 2 is the player's own body; 5 to 20 are
## rooms at the lowest preset, room_layers.gd.)
const LAYER := 4
signal footfall(point: Vector3, strength: float, normal: Vector3)

## The hands plant themselves on what is near; off, the clip moves the arms.
@export var crawling := true: set = set_crawling
## 0..1: how much its hands would rather hold walls and ceiling than the floor.
@export var cling := 0.0
## The rags of vapour round the ink: how thick.
@export var gloom := 4.0
## How much bigger than it was built it is shown.
@export var size := 1.35
var velocity := Vector3.ZERO
## Where the head and the eyes turn; INF follows the camera that is drawing.
var look_point := Vector3.INF
var skeleton: Skeleton3D
var animator: AnimationPlayer
var limbs: SkeletonModifier3D
var ink: MeshInstance3D
var vapour: MeshInstance3D
var body_bone := -1
var abdomen_bone := -1
var head_bone := -1
var last_position := Vector3.INF
## Drawn between her physics ticks and eased (spec_lurker_rebuild 3.1, 3.2):
## lurker.gd hands this node every tick's body transform (present()); the
## body that collides, senses and is sent keeps the raw one. At most TURN_MOST
## rad/s of turn, and drawn at most LAG_MOST behind, settling in about
## LAG_TIME; a logged jump, or showing again, is drawn at once.
const TURN_MOST := 6.0
const LAG_TIME := 0.08
const LAG_MOST := 0.15
var tick_before := Transform3D()
var tick_after := Transform3D()
var jump_seen := -1
var presented_at := -1
var drawn_at := -1
var shown_q := Quaternion()
var shown_origin := Vector3.ZERO
var lag_velocity := Vector3.ZERO
var smoothing := false
var snap := true


func _ready() -> void:
	var model: Node3D = get_node("Model")
	model.scale = Vector3.ONE * size
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	animator = model.find_children("*", "AnimationPlayer", true, false)[0]
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = LAYER
	body_bone = skeleton.find_bone("body")
	abdomen_bone = skeleton.find_bone("abdomen")
	head_bone = skeleton.find_bone("head")
	limbs = LIMBS.new()
	limbs.name = "Limbs"
	limbs.footfall.connect(func(point, strength, normal): footfall.emit(point, strength, normal))
	skeleton.add_child(limbs)
	limbs.hands = crawling
	ink = fog("Ink", 0.95 * size, 0.24 * size, 40.0, 0.0, 0.17 * size)
	# Tighter and darker than it was: 0.46 thick in a sphere of 1.0, its thin
	# rags reached 1.6 m and read on a lit wall as a grey cloud of smoke
	# round her, not as her darkness.
	vapour = fog("Vapour", 0.8 * size, 0.28 * size, gloom, 1.0, 0.17 * size)
	animator.play("idle")


func fog(name_: String, radius: float, thickness: float, density: float, rags: float, face_clear: float) -> MeshInstance3D:
	var cloud := MeshInstance3D.new()
	cloud.name = name_
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	cloud.mesh = sphere
	var material := ShaderMaterial.new()
	material.shader = DARKNESS
	material.set_shader_parameter("radius", radius)
	material.set_shader_parameter("thickness", thickness)
	material.set_shader_parameter("density", density)
	material.set_shader_parameter("vapour", rags)
	material.set_shader_parameter("face_clear", face_clear)
	cloud.material_override = material
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud.layers = LAYER
	add_child(cloud)
	return cloud


func set_crawling(value: bool) -> void:
	crawling = value
	if limbs: limbs.hands = value


## Plays one of the model's clips (idle, loom, scare, peek...).
func play(clip: String, blend := 0.2) -> void:
	animator.play(clip, blend)


## This tick's transform of the body (lurker.gd apply_motion()) and its count
## of logged jumps.
func present(at: Transform3D, jump: int) -> void:
	var frame := Engine.get_physics_frames()
	if jump != jump_seen or presented_at < 0 or frame - presented_at > 1:
		tick_before = at
		snap = true
	else:
		tick_before = tick_after
	tick_after = at
	jump_seen = jump
	presented_at = frame


## Where this node is drawn this frame, as an offset from the body.
func smooth(delta: float) -> void:
	var frame := Engine.get_process_frames()
	var away := drawn_at < 0 or frame - drawn_at > 1
	drawn_at = frame
	var body := get_parent_node_3d()
	if body == null or presented_at < 0 or Engine.get_physics_frames() - presented_at > 1:
		# Not presented (her capture holds her, a puppet): drawn on the body.
		if smoothing:
			smoothing = false
			transform = Transform3D(Basis.from_scale(scale), Vector3.ZERO)
		return
	var target := tick_before.interpolate_with(tick_after, Engine.get_physics_interpolation_fraction())
	var to_q := target.basis.get_rotation_quaternion()
	if snap or away or not smoothing:
		shown_q = to_q
		shown_origin = target.origin
		lag_velocity = Vector3.ZERO
		snap = false
	else:
		var gap := shown_q.angle_to(to_q)
		var most := TURN_MOST * delta
		shown_q = to_q if gap <= most else shown_q.slerp(to_q, most / gap)
		# A critically damped spring (Game Programming Gems 4, 1.10).
		var omega := 2.0 / LAG_TIME
		var x := omega * delta
		var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
		var change := shown_origin - target.origin
		var push := (lag_velocity + change * omega) * delta
		lag_velocity = (lag_velocity - push * omega) * decay
		var off := (change + push) * decay
		if off.length() > LAG_MOST: off = off.normalized() * LAG_MOST
		shown_origin = target.origin + off
	smoothing = true
	var local := body.global_transform.affine_inverse() * Transform3D(Basis(shown_q), shown_origin)
	transform = Transform3D(local.basis.orthonormalized() * Basis.from_scale(scale), local.origin)


func _process(delta: float) -> void:
	smooth(delta)
	if delta > 0.0 and last_position != Vector3.INF and velocity == Vector3.ZERO:
		limbs.velocity = (global_position - last_position) / delta
	else:
		limbs.velocity = velocity
	last_position = global_position
	limbs.cling = cling
	var camera := get_viewport().get_camera_3d()
	limbs.look_point = look_point if look_point != Vector3.INF else (camera.global_position if camera else Vector3.INF)
	var xf := skeleton.global_transform
	var front := xf * (skeleton.get_bone_global_pose(body_bone) * Vector3(0.0, 0.2, 0.0))
	var back := xf * (skeleton.get_bone_global_pose(abdomen_bone) * Vector3(0.0, 0.14, 0.0))
	var head := xf * (skeleton.get_bone_global_pose(head_bone) * Vector3(0.0, 0.06, 0.1))
	var middle := (front + back) * 0.5
	for cloud in [ink, vapour]:
		cloud.global_position = middle
		var material := cloud.material_override as ShaderMaterial
		material.set_shader_parameter("axis_a", front)
		material.set_shader_parameter("axis_b", back)
		material.set_shader_parameter("face", head)
	(vapour.material_override as ShaderMaterial).set_shader_parameter("density", gloom)
