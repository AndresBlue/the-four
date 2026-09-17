extends SubViewport
## What the television shows in the opening scene: a dim papered corner and
## The Locust itself (the game's own model with its reference look), rendered
## to a texture for the screen. It leans in from the edge of the picture,
## stares, lunges at the lens and beats on the glass with its bladed arm; each
## blow ends exactly at the point of the tube where the cracks will start.
## Bones are posed directly here; the gameplay IK is not used.
const LOOK := preload("res://game/enemies/locust/locust_look.gd")
const MODEL := preload("res://assets/enemies/locust.glb")
const BONE := "ValveBiped.Bip01_"
## Model scale, as in the game.
const SCALE := 1.95
## Length of the blade beyond the hand, in model units along the forearm.
const BLADE := 0.36
var camera: Camera3D
var locust: Node3D
var skeleton: Skeleton3D
var bones := {}
## Timeline inputs, written by the scene every frame.
var peek := 0.0
var lunge := 0.0
var twitch := 0.0
## Current blow: {start, hit, uv}; the arm winds up, strikes and recoils.
var blow := {}
var clock := 0.0
var rng := RandomNumberGenerator.new()

func _init() -> void:
	size = Vector2i(640, 480)
	own_world_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	rng.seed = 713

func build(materials: Dictionary) -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.02, 0.018, 0.015)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.55, 0.45, 0.35)
	environment.environment.ambient_light_energy = 0.12
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(environment)
	# A papered corner behind it, like the photograph.
	for wall in [[Vector3(-0.2, 2.0, -1.6), Vector3(5.0, 4.0, 0.1), 0.0], [Vector3(-1.7, 2.0, 0.2), Vector3(3.6, 4.0, 0.1), PI / 2]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = wall[1]
		box.material = materials.plaster
		mesh.mesh = box
		mesh.position = wall[0]
		mesh.rotation.y = wall[2]
		add_child(mesh)
	var floor_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(6, 0.1, 6)
	plane.material = materials.carpet
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0, -0.05, 0.5)
	add_child(floor_mesh)
	# Hard light from the camera side on the face; the wall falls off behind.
	var key := SpotLight3D.new()
	key.position = Vector3(0.35, 3.1, 1.5)
	key.light_color = Color(1.0, 0.88, 0.72)
	key.light_energy = 7.0
	key.spot_range = 4.0
	key.spot_angle = 26.0
	key.spot_attenuation = 1.6
	key.shadow_enabled = true
	add_child(key)
	key.look_at(Vector3(0.0, 2.45, 0.2))
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.2, 1.4, 1.2)
	fill.light_color = Color(0.7, 0.25, 0.2)
	fill.light_energy = 0.6
	fill.omni_range = 4.0
	add_child(fill)
	locust = MODEL.instantiate()
	locust.scale = Vector3.ONE * SCALE
	add_child(locust)
	LOOK.apply(locust)
	skeleton = locust.find_children("*", "Skeleton3D", true, false)[0]
	for name in ["Spine2", "Spine4", "Neck1", "Head1", "R_Clavicle", "R_UpperArm", "R_Forearm", "R_Hand", "L_UpperArm", "L_Forearm"]:
		bones[name] = skeleton.find_bone(BONE + name)
	camera = Camera3D.new()
	# Framed like the photograph: head and shoulders, close.
	camera.fov = 50.0
	camera.near = 0.02
	camera.position = Vector3(0.04, 2.55, 1.1)
	add_child(camera)
	camera.look_at(Vector3(0.0, 2.42, 0.0))
	camera.current = true
	pose(0.0)

## Advances the creature by one frame of the scene's timeline.
func pose(delta: float) -> void:
	clock += delta
	if skeleton == null: return
	skeleton.reset_bone_poses()
	# Leans in from beyond the right edge, then steps at the lens.
	var lean := 1.0 - peek
	locust.position = Vector3(lerpf(0.95, 0.06, peek), 0.0, lerpf(0.0, 0.42, lunge))
	# Arms hang instead of the T-pose.
	aim(bones.L_UpperArm, "L_Forearm", Vector3(0.25, -1.0, 0.15))
	aim(bones.R_UpperArm, "R_Forearm", Vector3(-0.25, -1.0, 0.15))
	# The upper body tilts sideways into the picture, head cocked the other way.
	turn(bones.Spine2, Vector3(0, 0, 1), lean * 0.38)
	turn(bones.Neck1, Vector3(0, 0, 1), -lean * 0.3 + sin(clock * 1.7) * 0.03)
	var jerk := twitch * (rng.randf() - 0.5) * 0.25
	turn(bones.Head1, Vector3(0, 0, 1), -0.32 + jerk)
	turn(bones.Head1, Vector3(1, 0, 0), 0.12 + lunge * 0.1)
	strike()

## The blow: wind-up behind the shoulder, a fast stab at the tube, recoil.
func strike() -> void:
	if blow.is_empty(): return
	var start: float = blow.start
	var hit: float = blow.hit
	var now := clock
	if now > hit + 0.55: return
	var shoulder := skeleton.global_transform * skeleton.get_bone_global_pose(bones.R_UpperArm).origin
	var glass := camera.project_position(blow.uv * Vector2(size), 0.09)
	# Raised high beside the head, drawn back from the lens.
	var up := camera.global_basis.y
	var right := camera.global_basis.x
	var toward := camera.global_basis.z
	var cocked := shoulder + up * 0.85 - right * 0.3 - toward * 0.35
	var target := cocked
	if now < start: return
	if now < hit - 0.1:
		target = shoulder.lerp(cocked, ease_out((now - start) / maxf(hit - 0.1 - start, 0.01)))
	elif now < hit:
		target = cocked.lerp(glass, ease_in((now - (hit - 0.1)) / 0.1))
	elif now < hit + 0.12:
		target = glass
	else:
		target = glass.lerp(shoulder - up * 0.35 - right * 0.2 + toward * 0.15, ease_out((now - hit - 0.12) / 0.43))
	reach(target)

## Two-bone reach of the right arm so that the blade tip lands on the target.
func reach(target: Vector3) -> void:
	var to_skeleton := skeleton.global_transform.affine_inverse()
	var tip_local := to_skeleton * target
	var upper_rest := skeleton.get_bone_global_rest(bones.R_UpperArm).origin
	var fore_rest := skeleton.get_bone_global_rest(bones.R_Forearm).origin
	var hand_rest := skeleton.get_bone_global_rest(bones.R_Hand).origin
	var a := upper_rest.distance_to(fore_rest)
	var b := fore_rest.distance_to(hand_rest) + BLADE
	var shoulder := skeleton.get_bone_global_pose(bones.R_UpperArm).origin
	var span := tip_local - shoulder
	var d := clampf(span.length(), absf(a - b) + 0.001, a + b - 0.001)
	var direction := span.normalized()
	# Elbow bends outwards and down.
	var pole := Vector3(-1.0, -0.6, -0.3).normalized()
	var side := (pole - direction * pole.dot(direction)).normalized()
	var along := (a * a - b * b + d * d) / (2.0 * d)
	var height := sqrt(maxf(a * a - along * along, 0.0))
	var elbow := shoulder + direction * along + side * height
	aim(bones.R_UpperArm, "R_Forearm", elbow - shoulder)
	aim(bones.R_Forearm, "R_Hand", (shoulder + direction * d) - elbow)

## Rotates a bone so the direction to its child points along `direction`
## (skeleton space), keeping everything above it as posed.
func aim(bone: int, child: String, direction: Vector3) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_pose := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var current := parent_pose * skeleton.get_bone_pose(bone)
	var child_offset := skeleton.get_bone_rest(skeleton.find_bone(BONE + child)).origin
	var now_direction := (current.basis * child_offset).normalized()
	var rotation := Quaternion(now_direction, direction.normalized())
	var wanted := Basis(rotation) * current.basis
	skeleton.set_bone_pose_rotation(bone, (parent_pose.basis.inverse() * wanted).get_rotation_quaternion())

## Turns a bone about a skeleton-space axis by an angle.
func turn(bone: int, axis: Vector3, angle: float) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_pose := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var current := parent_pose * skeleton.get_bone_pose(bone)
	var wanted := Basis(axis.normalized(), angle) * current.basis
	skeleton.set_bone_pose_rotation(bone, (parent_pose.basis.inverse() * wanted).get_rotation_quaternion())

static func ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)

static func ease_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t
