extends CharacterBody3D
var camera: Camera3D
var torch: SpotLight3D
signal noise(point: Vector3, radius: float)
var active := false
var stamina := 100.0
var recovery_delay := 0.0
var exhausted := false
var crouched := false
var hidden := false
var hiding_place: Node3D
var body_shape: CollisionShape3D
var step_clock := 0.0
var hide_yaw := 0.0
var footstep: AudioStreamPlayer3D
var settings
var spawn := Vector3.ZERO
var bob_time := 0.0

func _ready() -> void:
	add_to_group("hotel_players")
	body_shape = $BodyShape
	camera = $Camera
	torch = $Camera/Flashlight
	footstep = $Footsteps
	footstep.stream = step_sound()
	if settings == null: set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * settings.values.sensitivity)
		if hidden: rotation.y = hide_yaw + clampf(wrapf(rotation.y - hide_yaw, -PI, PI), -0.6, 0.6)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * settings.values.sensitivity * (-1 if settings.values.invert else 1), -1.45, 1.45)
	if event.is_action_pressed("flashlight"): torch.visible = not torch.visible

func _physics_process(delta: float) -> void:
	var axis := Input.get_vector("left", "right", "forward", "backward") if active and not hidden else Vector2.ZERO
	var direction := (basis * Vector3(axis.x, 0, axis.y)).normalized()
	var wants_crouch := hidden or (active and Input.is_action_pressed("crouch"))
	if wants_crouch or can_stand(): crouched = wants_crouch
	body_shape.shape.height = 1.05 if crouched else 1.8
	body_shape.position.y = 0.54 if crouched else 0.91
	var running := active and not hidden and not crouched and axis.length() > 0.1 and Input.is_action_pressed("sprint") and stamina > 0 and not exhausted
	if running:
		stamina = maxf(0, stamina - 20 * delta)
		recovery_delay = 1.5
		if stamina <= 0: exhausted = true
	else:
		recovery_delay = maxf(0, recovery_delay - delta)
		if recovery_delay <= 0: stamina = minf(100, stamina + 15 * delta)
		if stamina >= 25: exhausted = false
	var speed := 2.0 if crouched else 6.0 if running else 3.8
	velocity.x = move_toward(velocity.x, direction.x * speed, 22 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 22 * delta)
	if not is_on_floor(): velocity.y -= 20 * delta
	if active and not hidden and not crouched and is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = 5.4
		noise.emit(global_position, 10.0)
	move_and_slide()
	if position.y < -5:
		position = spawn
		velocity = Vector3.ZERO
	if axis.length() > 0.1 and is_on_floor(): bob_time += delta * speed * 1.8
	var amplitude: float = 0.0 if settings.values.reduced else settings.values.bob * 0.08
	camera.position.y = move_toward(camera.position.y, (0.9 if crouched else 1.64) + sin(bob_time) * amplitude * axis.length(), delta * 5)
	if Vector2(velocity.x, velocity.z).length() > 0.3 and is_on_floor() and not hidden:
		step_clock += delta
		if step_clock > (0.8 if crouched else 0.3 if running else 0.52):
			step_clock = 0
			noise.emit(global_position, 2.5 if crouched else 16.0 if running else 7.0)
			footstep.volume_db = -27 if crouched else -12 if running else -19
			footstep.play()

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

func enter_hide(place: Node3D) -> bool:
	if hidden or is_instance_valid(place.occupant): return false
	hiding_place = place
	place.occupant = self
	hidden = true
	global_position = place.global_position + Vector3(0, 0.04, 0)
	velocity = Vector3.ZERO
	rotation.y = place.global_rotation.y + PI
	hide_yaw = rotation.y
	camera.rotation = Vector3.ZERO
	torch.visible = false
	return true

func leave_hide() -> bool:
	if not hidden or not is_instance_valid(hiding_place): return false
	var point: Vector3 = hiding_place.available_exit(self)
	if point == Vector3.INF: return false
	global_position = point
	hiding_place.occupant = null
	hiding_place = null
	hidden = false
	return true

func reset_survival() -> void:
	if is_instance_valid(hiding_place): hiding_place.occupant = null
	hidden = false
	hiding_place = null
	crouched = false
	stamina = 100
	recovery_delay = 0
	exhausted = false
	step_clock = 0
