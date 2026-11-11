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
## How much bigger than it was built it is shown: 1.35 read in the offices as
## a blot half a metre wide with sticks for arms (the visual pass, 1.2 times).
@export var size := 1.62
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
## Her presence (the visual pass): the ink dragged behind her when she dashes
## and catching up (TRAIL_CATCH a second, at most TRAIL_MOST behind, a tail
## of rags behind that); her body pressed down for a moment before a dash
## (`crouch`, lurker.gd sets it); still, a tic of the head held a while and a
## shudder now and then, never on a beat; and her torso turned towards what
## she looks at when her neck will not take her face round (from TORSO_FROM
## off her heading, at most TORSO_MOST more). Drawing only.
const TRAIL_CATCH := 7.0
const TRAIL_MOST := 0.55
const CROUCH := 0.07
## 20 to 40 degrees.
const TIC := Vector2(0.349, 0.698)
const TIC_HOLD := Vector2(0.6, 1.8)
const TIC_GAP := Vector2(1.2, 3.8)
const TIC_SNAP := 14.0
const SHUDDER := 0.012
const TORSO_FROM := 1.35
const TORSO_MOST := 0.8
## The ink round each shoulder and up the neck: a share of the trunk's.
const SHOULDER := 0.24
const NECK := 0.32
const TORSO_RATE := 5.0
## Faster than this (her bolt) no hand can step: the arms are swept back and
## the ink drawn out behind her twice as far.
const SWEPT_FROM := 6.0
## Her gait in her body (the author: "se le ve tosco"): a bob and a roll with
## her stride (STRIDE metres a cycle), and a lean into what she speeds up or
## slows down by (LEAN rad per m/s2, at most LEAN_MOST).
const STRIDE := 0.9
const BOB := 0.018
const ROLL := 0.05
const LEAN := 0.025
const LEAN_MOST := 0.22
var stride := 0.0
var lean := 0.0
var last_speed := 0.0
## Her contact with what she holds: a dark stain projected on the surface
## under her (a decal: nothing on the Compatibility renderer).
var stain: Decal
## Held to what she clings to (the grip pass; the author: "se le ve tosco"):
## her trunk drawn up towards the surface until its middle is CONTACT off it,
## at most PRESS_MOST nearer than her body hangs. A ball of TRUNK cast that
## way finds the surface, an edge as well as a face, so it never goes through
## a door head. It hangs at one distance, and her ink lies on what she holds
## (the shader's `spill`). Drawing only: her body and its rules keep the hang.
const CONTACT := 0.3
const PRESS_MOST := 0.3
const TRUNK := 0.22
const SPILL := 1.7
var press := 0.0
var trunk_rest := Vector3.INF
var press_query := PhysicsShapeQueryParameters3D.new()
## Each hand that lands tugs her trunk ahead (a spring, SURGE_HZ, damped by
## SURGE_DAMP): she goes in short lurches and checks, never on a rail, at most
## SURGE_MOST either way (inside smooth()'s LAG_MOST). Her abdomen swings
## behind them and her head is held still against them (lurker_limbs.gd).
const SURGE_KICK := 1.2
const SURGE_HZ := 1.8
const SURGE_DAMP := 0.45
const SURGE_MOST := 0.07
const SURGE_PITCH := 0.25
const ABDOMEN_LAG := 0.7
const ABDOMEN_SWAY := 0.08
var surge := 0.0
var surge_v := 0.0
## A stain where each hand holds on (a decal, as `stain`): it comes as the
## hand lands, breathes while it holds and fades where it was once it lets go.
var grip_stains: Array[Decal] = []
var grip_fade := PackedFloat32Array()
var breath := 0.0
## Her bolt: drawn out along the way she runs.
const STRETCH := 0.3
var stretched := 0.0
## A blot with a torn, soft edge: a radial fade broken by noise, so no stain
## of hers reads as a round sticker.
static var blot: ImageTexture
var crouch := false
var crouched := 0.0
var trail_at := Vector3.INF
var tic_rng := RandomNumberGenerator.new()
var tic_clock := 1.5
var tic_goal := 0.0
var tic_angle := 0.0
var tic_axis := Vector3.BACK
var shudder_left := 0.0
var shudder_clock := 3.0
var torso_yaw := 0.0
var model: Node3D


func _ready() -> void:
	model = get_node("Model")
	model.scale = Vector3.ONE * size
	tic_rng.randomize()
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	animator = model.find_children("*", "AnimationPlayer", true, false)[0]
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = LAYER
	body_bone = skeleton.find_bone("body")
	abdomen_bone = skeleton.find_bone("abdomen")
	head_bone = skeleton.find_bone("head")
	limbs = LIMBS.new()
	limbs.name = "Limbs"
	limbs.footfall.connect(landed)
	skeleton.add_child(limbs)
	limbs.hands = crawling
	ink = fog("Ink", 0.95 * size, 0.2 * size, 40.0, 0.0, 0.17 * size)
	(ink.material_override as ShaderMaterial).set_shader_parameter("spill", SPILL)
	stain = Decal.new()
	stain.name = "Stain"
	stain.size = Vector3(1.1, 0.9, 1.1) * size
	stain.texture_albedo = blot_texture()
	stain.cull_mask = 0xFFFFF ^ LAYER
	stain.normal_fade = 0.3
	stain.position = Vector3.DOWN * 0.2 * size
	add_child(stain)
	for i in LIMBS.LIMBS.size():
		var grip_stain := Decal.new()
		grip_stain.name = "GripStain%d" % i
		grip_stain.top_level = true
		grip_stain.texture_albedo = blot
		grip_stain.cull_mask = 0xFFFFF ^ LAYER
		grip_stain.normal_fade = 0.5
		grip_stain.visible = false
		add_child(grip_stain)
		grip_stains.append(grip_stain)
		grip_fade.append(0.0)
	press_query.shape = SphereShape3D.new()
	(press_query.shape as SphereShape3D).radius = TRUNK
	# Tighter and darker than it was: 0.46 thick in a sphere of 1.0, its thin
	# rags reached 1.6 m and read on a lit wall as a grey cloud of smoke
	# round her, not as her darkness.
	vapour = fog("Vapour", 0.6 * size, 0.22 * size, gloom, 1.0, 0.17 * size)
	animator.play("idle")


static func blot_texture() -> ImageTexture:
	if blot != null: return blot
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.09
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var r := Vector2(x - 31.5, y - 31.5).length() / 32.0 + noise.get_noise_2d(x, y) * 0.3
			var a := clampf((1.0 - r) / 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(0, 0, 0, a * a * 0.85))
	blot = ImageTexture.create_from_image(image)
	return blot


## A hand has landed: the sound's, and a tug on her trunk.
func landed(point: Vector3, strength: float, normal: Vector3) -> void:
	footfall.emit(point, strength, normal)
	if limbs.swept or not limbs.grips.is_empty(): return
	surge_v += SURGE_KICK * clampf(limbs.velocity.length() / 1.35, 0.0, 1.5)


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
	limbs.swept = limbs.velocity.length() > SWEPT_FROM
	var camera := get_viewport().get_camera_3d()
	limbs.look_point = look_point if look_point != Vector3.INF else (camera.global_position if camera else Vector3.INF)
	hold_on(delta)
	pose_body(delta)
	stain_grips(delta)
	var xf := skeleton.global_transform
	var front := xf * (skeleton.get_bone_global_pose(body_bone) * Vector3(0.0, 0.2, 0.0))
	var back := xf * (skeleton.get_bone_global_pose(abdomen_bone) * Vector3(0.0, 0.14, 0.0))
	var head := xf * (skeleton.get_bone_global_pose(head_bone) * Vector3(0.0, 0.06, 0.1))
	var middle := (front + back) * 0.5
	trunk_rest = middle + global_basis.y.normalized() * press
	# The ink lags behind a dash and catches up.
	if trail_at == Vector3.INF or delta <= 0.0 or middle.distance_to(trail_at) > 2.0: trail_at = middle
	trail_at = trail_at.lerp(middle, 1.0 - exp(-TRAIL_CATCH * delta))
	var drag := trail_at - middle
	var trail_most: float = TRAIL_MOST * size / 1.35 * (2.0 if limbs.swept else 1.0)
	if drag.length() > trail_most: drag = drag.normalized() * trail_most
	# The shoulders in the ink, thinning at once so the arms come out of it
	# sharp (from the hands' modifier, a frame old); the neck, so the face
	# comes out of the mass; and the tail of rags behind a dash. The vapour
	# takes the neck and the tail, not the arms.
	var roots_a := PackedVector3Array()
	var roots_b := PackedVector3Array()
	var ink_w := PackedFloat32Array()
	for limb in limbs.limbs:
		var shoulder: Vector3 = limb.shoulder_at
		var elbow: Vector3 = limb.elbow_at
		var on: bool = crawling and shoulder != Vector3.INF
		roots_a.append(shoulder if on else Vector3.ZERO)
		roots_b.append(shoulder.lerp(elbow, 0.15) if on else Vector3.ZERO)
		ink_w.append(SHOULDER if on else 0.0)
	roots_a.resize(7)
	roots_b.resize(7)
	ink_w.resize(7)
	var vapour_w := PackedFloat32Array()
	vapour_w.resize(7)
	roots_a.append(front)
	roots_b.append(front.lerp(head, 0.8))
	ink_w.append(NECK)
	vapour_w.append(NECK)
	roots_a.append(back + drag * 0.8)
	roots_b.append(back + drag * 2.0)
	var tail := 0.5 if drag.length() > 0.02 else 0.0
	ink_w.append(tail)
	vapour_w.append(tail)
	for cloud in [ink, vapour]:
		cloud.global_position = middle + drag * 0.6
		var material := cloud.material_override as ShaderMaterial
		material.set_shader_parameter("axis_a", front + drag * 0.3)
		material.set_shader_parameter("axis_b", back + drag)
		material.set_shader_parameter("face", head)
		material.set_shader_parameter("roots_a", roots_a)
		material.set_shader_parameter("roots_b", roots_b)
		material.set_shader_parameter("roots_w", ink_w if cloud == ink else vapour_w)
	(vapour.material_override as ShaderMaterial).set_shader_parameter("density", gloom)


## How far her trunk is drawn up towards what she clings to (see CONTACT):
## eased, and let go of faster than taken, so an edge coming never meets it.
func hold_on(delta: float) -> void:
	var goal := 0.0
	if crawling and limbs.grips.is_empty() and trunk_rest != Vector3.INF and is_inside_tree():
		var reach := PRESS_MOST + CONTACT - TRUNK
		press_query.transform = Transform3D(Basis(), trunk_rest)
		press_query.motion = -global_basis.y.normalized() * reach
		press_query.collision_mask = limbs.world_mask
		var room_left := get_world_3d().direct_space_state.cast_motion(press_query)
		goal = clampf(reach * room_left[0] - (CONTACT - TRUNK), 0.0, PRESS_MOST)
	press = lerpf(press, goal, 1.0 - exp(-(18.0 if goal < press else 4.0) * delta))


## A stain under each hand that holds on (see grip_stains).
func stain_grips(delta: float) -> void:
	breath += delta
	for i in mini(grip_stains.size(), limbs.limbs.size()):
		var limb: Dictionary = limbs.limbs[i]
		var mark := grip_stains[i]
		var held: bool = crawling and limbs.grips.is_empty() and not limbs.swept and limb.planted and not limb.swing and not limb.free
		grip_fade[i] = move_toward(grip_fade[i], 1.0 if held else 0.0, delta * (5.0 if held else 2.0))
		mark.visible = grip_fade[i] > 0.01
		if not mark.visible: continue
		if held:
			# under the palm and the claws, flat on the hold
			var n: Vector3 = limb.normal
			var at: Vector3 = ((limb.hold as Vector3) + (limb.claw_at as Vector3)) * 0.5
			at -= n * (at - (limb.hold as Vector3)).dot(n)
			var side := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized().rotated(n, float(i) * 2.1)
			mark.global_transform = Transform3D(Basis(side, n, side.cross(n)), at)
		var wide: float = float(limb.hand_reach) * limbs.size * 0.9 * (1.0 + 0.06 * sin(breath * 1.4 + float(i)))
		mark.size = Vector3(wide, 0.3, wide)
		mark.modulate = Color(1, 1, 1, grip_fade[i] * (0.8 + 0.2 * sin(breath * 1.9 + float(i) * 1.3)))


## Her body as she holds still and as she goes (drawing only, on the Model):
## turned towards what she looks at past what her neck can do, pressed down
## before a dash, a shudder; and the tic of her head handed to the hands'
## modifier. Her capture (grips held) has none of it.
func pose_body(delta: float) -> void:
	var capture: bool = not limbs.grips.is_empty()
	var still: bool = limbs.velocity.length() < 0.1 and not capture
	# The head's tic: snapped round, held, snapped back; drawn, never periodic.
	tic_clock -= delta
	if tic_clock <= 0.0:
		if tic_goal != 0.0 or not still:
			tic_goal = 0.0
			tic_clock = tic_rng.randf_range(TIC_GAP.x, TIC_GAP.y) if still else 0.4
		else:
			tic_goal = tic_rng.randf_range(TIC.x, TIC.y) * (1.0 if tic_rng.randf() < 0.5 else -1.0)
			tic_axis = Vector3.BACK if tic_rng.randf() < 0.6 else Vector3.UP
			tic_clock = tic_rng.randf_range(TIC_HOLD.x, TIC_HOLD.y)
	if not still: tic_goal = 0.0
	tic_angle = move_toward(tic_angle, tic_goal, TIC_SNAP * delta)
	limbs.tic_head = Quaternion(tic_axis, tic_angle)
	# A shudder through her, now and then while still.
	shudder_clock -= delta
	if shudder_clock <= 0.0:
		shudder_clock = tic_rng.randf_range(2.0, 6.0)
		if still: shudder_left = tic_rng.randf_range(0.15, 0.3)
	shudder_left = maxf(0.0, shudder_left - delta)
	var shake := Vector3.ZERO
	if shudder_left > 0.0: shake = Vector3(tic_rng.randf() - 0.5, tic_rng.randf() - 0.5, tic_rng.randf() - 0.5) * 2.0 * SHUDDER * size
	# Pressed down a moment before she dashes.
	crouched = move_toward(crouched, 1.0 if crouch and not capture else 0.0, delta * 12.0)
	# Her torso round to what she stares at once her neck runs out.
	var goal := 0.0
	if limbs.look_point != Vector3.INF and not capture:
		var to: Vector3 = global_basis.inverse() * (limbs.look_point - global_position)
		var off := atan2(to.x, to.z)
		goal = clampf(signf(off) * maxf(0.0, absf(off) - TORSO_FROM), -TORSO_MOST, TORSO_MOST)
	torso_yaw = lerpf(torso_yaw, goal, 1.0 - exp(-TORSO_RATE * delta))
	# Her stride in her body: a bob and a roll, and a lean into her speeding
	# up or slowing down (her abdomen swings the other way from the clip).
	var going: float = limbs.velocity.length()
	# Tugged along by her hands: lurches and checks, her abdomen swinging behind
	# and her head held still against them.
	var w := TAU * SURGE_HZ
	surge_v += (-w * w * surge - 2.0 * SURGE_DAMP * w * surge_v) * delta
	surge = clampf(surge + surge_v * delta, -SURGE_MOST, SURGE_MOST)
	if capture or limbs.swept:
		surge = 0.0
		surge_v = 0.0
	stride = fmod(stride + going * delta / STRIDE, 1.0)
	var weight: float = clampf(going / 1.0, 0.0, 1.0) * (0.0 if limbs.swept or capture else 1.0)
	var bob: float = sin(stride * TAU * 2.0) * BOB * size * weight
	var roll: float = sin(stride * TAU) * ROLL * weight
	if delta > 0.0: lean = lerpf(lean, clampf((going - last_speed) / delta * LEAN, -LEAN_MOST, LEAN_MOST), 1.0 - exp(-8.0 * delta))
	last_speed = going
	limbs.abdomen_swing = Vector2(sin(stride * TAU + 0.8) * ABDOMEN_SWAY * weight, clampf(surge_v * ABDOMEN_LAG, -0.3, 0.3))
	limbs.head_hold = global_basis * (Vector3.FORWARD * surge)
	# Bolting, drawn out along her run.
	stretched = move_toward(stretched, 1.0 if limbs.swept else 0.0, delta * 10.0)
	var thin := 1.0 - 0.12 * stretched
	var scaled := Vector3(size * thin, size * (1.0 - 0.08 * crouched) * thin, size * (1.0 + STRETCH * stretched))
	var turn := Basis(Vector3.UP, torso_yaw) * Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, -lean - surge_v * SURGE_PITCH)
	model.transform = Transform3D(turn * Basis.from_scale(scaled), Vector3.DOWN * (CROUCH * size * crouched + bob + press) + Vector3.BACK * surge + shake)
