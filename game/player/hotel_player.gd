extends CharacterBody3D
var avatar
var camera: Camera3D
var torch: SpotLight3D
signal noise(point: Vector3, radius: float)
signal hiding_changed(entering: bool, point: Vector3)
var active := false
var stamina := 100.0
var recovery_delay := 0.0
var exhausted := false
var crouched := false
var hidden := false
var hiding_place: Node3D
var body_shape: CollisionShape3D
## Advances by PI per footfall; derived from distance walked, not time.
var step_phase := 0.0
var bob_weight := 0.0
var eye_height := 1.64
var hide_yaw := 0.0
## 0..1: how far the wardrobe doors are eased open while hiding.
var peek := 0.0
## Looking range inside the wardrobe (radians either side), shut and fully ajar.
const HIDE_LOOK := Vector2(0.35, 1.35)
## How far the head leans out through the gap at full peek (metres).
const PEEK_LEAN := 0.5
var footstep: AudioStreamPlayer3D
var settings
var spawn := Vector3.ZERO
# Stamina: long sprints, slow and delayed recovery.
const STAMINA_DRAIN := 8.0
# Metres covered per footfall for each gait.
# Adult cadence at each gait's speed (steps per second). Footfalls still come
# from distance covered, so the stride is speed / cadence: long strides
# walking, longer and slightly quicker ones running.
const CADENCE_WALK := 2.0
const CADENCE_RUN := 2.5
const CADENCE_CROUCH := 1.5
const STRIDE_WALK := 3.8 / CADENCE_WALK
const STRIDE_RUN := 6.0 / CADENCE_RUN
const STRIDE_CROUCH := 2.0 / CADENCE_CROUCH
const STAMINA_RECOVERY := 6.0
const RECOVERY_DELAY := 3.0
const EXHAUSTED_UNTIL := 30.0
# Hand-held torch: position relative to the camera and how loosely it follows.
const HAND_OFFSET := Vector3(0.24, -0.3, -0.25)
var torch_follow := 9.0
var torch_energy := 0.0
var torch_warmup := 1.0
var torch_clock := 0.0

func _ready() -> void:
	avatar = $Avatar
	add_to_group("hotel_players")
	body_shape = $BodyShape
	camera = $Camera
	torch = $Camera/Flashlight
	if torch.light_projector == null: torch.light_projector = beam_pattern()
	torch_energy = torch.light_energy
	# The torch is carried, not bolted to the view: it trails the camera.
	torch.top_level = true
	snap_torch()
	footstep = $Footsteps
	footstep.stream = step_sound()
	if settings == null: set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * settings.values.sensitivity)
		if hidden:
			var limit := lerpf(HIDE_LOOK.x, HIDE_LOOK.y, peek)
			rotation.y = hide_yaw + clampf(wrapf(rotation.y - hide_yaw, -PI, PI), -limit, limit)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * settings.values.sensitivity * (-1 if settings.values.invert else 1), -1.45, 1.45)
	if event.is_action_pressed("flashlight"):
		torch.visible = not torch.visible
		torch_warmup = 0.0

func _physics_process(delta: float) -> void:
	var axis := Input.get_vector("left", "right", "forward", "backward") if active and not hidden else Vector2.ZERO
	var direction := (basis * Vector3(axis.x, 0, axis.y)).normalized()
	var wants_crouch := active and not hidden and Input.is_action_pressed("crouch")
	if wants_crouch or can_stand(): crouched = wants_crouch
	body_shape.shape.height = 1.05 if crouched else 1.8
	body_shape.position.y = 0.54 if crouched else 0.91
	var running := active and not hidden and not crouched and axis.length() > 0.1 and Input.is_action_pressed("sprint") and stamina > 0 and not exhausted
	if running:
		stamina = maxf(0, stamina - STAMINA_DRAIN * delta)
		recovery_delay = RECOVERY_DELAY
		if stamina <= 0: exhausted = true
	else:
		recovery_delay = maxf(0, recovery_delay - delta)
		if recovery_delay <= 0: stamina = minf(100, stamina + STAMINA_RECOVERY * delta)
		if stamina >= EXHAUSTED_UNTIL: exhausted = false
	var speed := 2.0 if crouched else 6.0 if running else 3.8
	velocity.x = move_toward(velocity.x, direction.x * speed, 22 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 22 * delta)
	if not is_on_floor(): velocity.y -= 20 * delta
	if active and not hidden and not crouched and is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = 5.4
		noise.emit(global_position, 10.0)
	move_and_slide()
	avatar.update_pose(velocity, crouched, delta)
	if position.y < -5:
		position = spawn
		velocity = Vector3.ZERO
	# Footfalls come from distance covered: one step per stride length, so
	# cadence and camera motion always match the actual ground speed.
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 0.25 and is_on_floor() and not hidden:
		var stride := STRIDE_CROUCH if crouched else STRIDE_RUN if running else STRIDE_WALK
		var previous := floori(step_phase / PI)
		step_phase += planar * delta / stride * PI
		bob_weight = move_toward(bob_weight, 1.0, delta * 5.0)
		if floori(step_phase / PI) != previous:
			noise.emit(global_position, 2.5 if crouched else 16.0 if running else 7.0)
			footstep.volume_db = -22 if crouched else -3 if running else -12
			# Running strikes land heavier and a little lower.
			footstep.pitch_scale = randf_range(0.84, 0.94) if running else randf_range(0.94, 1.06)
			footstep.play()
	else:
		bob_weight = move_toward(bob_weight, 0.0, delta * 4.0)
	eye_height = move_toward(eye_height, 0.9 if crouched else 1.64, delta * 5.0)
	# Head is highest mid-stride and dips at each heel strike; it sways toward
	# the planted foot once per two steps.
	# Kept subtle: about 1.5 cm walking and 2.5 cm running at the default setting.
	var amplitude: float = 0.0 if settings.values.reduced else settings.values.bob * (0.1 if crouched else 0.25 if running else 0.15)
	var lift := (absf(sin(step_phase)) - 0.6) * amplitude * bob_weight
	update_peek(delta)
	# Peeking leans the head forward through the gap between the doors.
	camera.position = Vector3(sin(step_phase) * amplitude * 0.2 * bob_weight, eye_height + lift, -peek * PEEK_LEAN)
	camera.rotation.z = sin(step_phase) * amplitude * 0.02 * bob_weight

# Incandescent torch: hot centre, faint reflector ring and a soft falloff.
static func beam_pattern() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.42, 0.52, 0.62, 0.85, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1), Color(0.9, 0.9, 0.9), Color(0.62, 0.62, 0.62), Color(0.74, 0.74, 0.74), Color(0.4, 0.4, 0.4), Color(0.1, 0.1, 0.1), Color(0, 0, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture

static func step_sound() -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(4410)
	for i in 2205:
		var t := float(i) / 22050
		var value := sin(TAU * 85 * t) * exp(-t * 55) * minf(1, t * 500)
		samples.encode_s16(i * 2, int(value * 16000))
	sound.data = samples
	return sound

func torch_target() -> Transform3D:
	var view := camera.global_transform
	var hand := view * HAND_OFFSET
	# Aim converges on what the camera looks at a few metres ahead.
	var aim := view.origin - view.basis.z * 7.0
	return Transform3D(Basis.looking_at(aim - hand, view.basis.y), hand)

func snap_torch() -> void:
	if is_instance_valid(torch) and is_instance_valid(camera) and camera.is_inside_tree(): torch.global_transform = torch_target()

func _process(delta: float) -> void:
	if not is_instance_valid(torch) or not torch.is_inside_tree(): return
	var target := torch_target()
	var reduced: bool = settings != null and settings.values.reduced
	var planar := Vector2(velocity.x, velocity.z).length()
	var moving := minf(planar / 3.8, 1.6) if is_on_floor() and not hidden else 0.0
	torch_clock += delta
	# Walking sway follows the footstep cycle; breathing keeps it alive when still.
	var sway := 0.2 if reduced else 1.0
	var step := step_phase
	moving *= bob_weight
	var offset := Vector3(sin(step) * 0.02, (absf(sin(step)) - 0.6) * 0.02, 0.0) * moving
	offset += Vector3(sin(torch_clock * 0.9) * 0.004, sin(torch_clock * 1.3) * 0.005, 0.0)
	var yaw := sin(step) * 0.03 * moving + sin(torch_clock * 0.7) * 0.006
	var pitch := cos(step * 2.0) * 0.012 * moving + sin(torch_clock * 1.1) * 0.008
	var roll := sin(step) * 0.02 * moving
	target.origin += target.basis * (offset * sway)
	target.basis = target.basis * Basis.from_euler(Vector3(pitch, yaw, roll) * sway)
	if target.origin.distance_to(torch.global_position) > 1.5:
		torch.global_transform = target
	else:
		# Frame-rate independent lag; running shakes the beam behind the view.
		var weight := 1.0 - exp(-delta * (torch_follow * (1.8 if reduced else 1.0)))
		var current := torch.global_transform
		current.origin = current.origin.lerp(target.origin, minf(1.0, weight * 2.0))
		current.basis = Basis(current.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), weight))
		torch.global_transform = current
	# Filament warm-up when switched on, and a slight dip while jolted.
	torch_warmup = minf(1.0, torch_warmup + delta * 6.0)
	var warm := torch_warmup * torch_warmup
	if torch_warmup < 0.6 and not reduced: warm *= 0.7 + 0.3 * absf(sin(torch_clock * 90.0))
	torch.light_energy = torch_energy * warm * (1.0 - 0.06 * moving * absf(sin(step)) * sway)

func can_stand() -> bool:
	if not crouched: return true
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	# Query above the contact margin: touching the floor must not forbid standing.
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.95, 0))
	query.collision_mask = 1 | 8
	return get_world_3d().direct_space_state.intersect_shape(query).is_empty()

## Hold forward to ease the doors open, release to let them fall shut.
func update_peek(delta: float) -> void:
	var wanted := 1.0 if hidden and active and Input.is_action_pressed("forward") else 0.0
	peek = move_toward(peek, wanted, delta * (0.5 if wanted > peek else 0.9))
	if hidden and is_instance_valid(hiding_place): hiding_place.set_peek(peek)
	# Narrow the view back inside as the doors close.
	if hidden:
		var limit := lerpf(HIDE_LOOK.x, HIDE_LOOK.y, peek)
		rotation.y = hide_yaw + clampf(wrapf(rotation.y - hide_yaw, -PI, PI), -limit, limit)

func enter_hide(place: Node3D) -> bool:
	if hidden or is_instance_valid(place.occupant): return false
	hiding_place = place
	hidden = true
	peek = 0.0
	place.enter(self)
	global_position = place.to_global(place.inside_offset)
	velocity = Vector3.ZERO
	rotation.y = place.global_rotation.y + PI
	hide_yaw = rotation.y
	camera.rotation = Vector3.ZERO
	torch.visible = false
	hiding_changed.emit(true, global_position)
	return true

func leave_hide() -> bool:
	if not hidden or not is_instance_valid(hiding_place): return false
	var point: Vector3 = hiding_place.available_exit(self)
	if point == Vector3.INF: return false
	global_position = point
	snap_torch()
	hiding_place.leave()
	hiding_place = null
	peek = 0.0
	hidden = false
	hiding_changed.emit(false, global_position)
	return true

func reset_survival() -> void:
	if is_instance_valid(hiding_place): hiding_place.leave()
	hidden = false
	hiding_place = null
	peek = 0.0
	crouched = false
	stamina = 100
	recovery_delay = 0
	exhausted = false
	step_phase = 0

func set_character(index: int) -> void:
	if avatar != null and avatar.character != index: avatar.configure(index, true)
