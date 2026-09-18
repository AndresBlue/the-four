extends CharacterBody3D
const NOISE := preload("res://game/audio/noise_kinds.gd")
var avatar
## Seat in the match (session participant key). Single player is seat 1.
var slot := 1
var camera: Camera3D
var torch: SpotLight3D
## A noise the creature may hear: where, how far it carries, and what made
## it (NOISE.Kind, which only the hunter's acoustic image reads).
signal noise(point: Vector3, radius: float, kind: int)
signal hiding_changed(entering: bool, point: Vector3)
var active := false
var stamina := 100.0
var recovery_delay := 0.0
var exhausted := false
var crouched := false
var hidden := false
## Impaled and lifted during an execution: the body is placed, not walked.
var held := false
## Holding a document up to read: no walking or looking around.
var reading := false
var hiding_place: Node3D
var body_shape: CollisionShape3D
## Advances by PI per footfall; derived from distance walked, not time.
var step_phase := 0.0
var bob_weight := 0.0
var eye_height := 1.64
var hide_yaw := 0.0
## 0..1: how far the wardrobe doors are eased open while hiding.
var peek := 0.0
## -1..1: which side the occupant looks to while peeking (+ is left), smoothed.
var peek_side := 0.0
## Looking range inside the wardrobe (radians either side), shut and fully ajar.
const HIDE_LOOK := Vector2(0.35, 1.45)
## How far the head leans out through the gap at full peek (metres), forward
## and sideways into the opened half.
const PEEK_LEAN := 0.5
const PEEK_SIDE_LEAN := 0.28
var footstep: AudioStreamPlayer3D
## Two voices so a step's tail is not cut by the next one.
var step_voices: Array[AudioStreamPlayer3D] = []
var step_voice := 0
## Step clips per set, loaded from the generated table.
var step_clips := {}
## Footfall index whose sound already started ahead of the impact.
var step_scheduled := -1
## Set by the level from the module underfoot: tiles instead of carpet.
var hard_floor := false
## Physics frame at which the last started step clip reaches its impact (tests).
var step_impact_frame := -1.0
const STEPS := preload("res://game/audio/footstep_segments.gd")
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
	for set_name in STEPS.SETS:
		step_clips[set_name] = STEPS.SETS[set_name].map(func(entry): return {"stream": load(entry[0]), "impact": entry[1]})
	footstep.stream = step_clips.carpet_walk[0].stream
	var second := footstep.duplicate() as AudioStreamPlayer3D
	second.name = "FootstepsTail"
	add_child(second)
	step_voices = [footstep, second]
	if settings == null: set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventMouseMotion and not reading:
		rotate_y(-event.relative.x * settings.values.sensitivity)
		if hidden:
			var limit := lerpf(HIDE_LOOK.x, HIDE_LOOK.y, peek)
			rotation.y = hide_yaw + clampf(wrapf(rotation.y - hide_yaw, -PI, PI), -limit, limit)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * settings.values.sensitivity * (-1 if settings.values.invert else 1), -1.45, 1.45)
	if event.is_action_pressed("flashlight"):
		torch.visible = not torch.visible
		torch_warmup = 0.0

func _physics_process(delta: float) -> void:
	if held:
		velocity = Vector3.ZERO
		return
	var axis := Input.get_vector("left", "right", "forward", "backward") if active and not hidden and not reading else Vector2.ZERO
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
		noise.emit(global_position, 10.0, NOISE.Kind.JUMP)
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
		var rate := planar / stride * PI
		step_phase += rate * delta
		bob_weight = move_toward(bob_weight, 1.0, delta * 5.0)
		var index := floori(step_phase / PI)
		if index != previous:
			# Tiles carry a step further than carpet.
			noise.emit(global_position, (2.5 if crouched else 16.0 if running else 7.0) * (1.3 if hard_floor else 1.0), NOISE.Kind.RUN if running and not crouched else NOISE.Kind.FOOTSTEP)
			if step_scheduled != index: play_step(running, 0.0)
		# Recorded steps have their impact some way into the clip: start the next
		# one early so the impact lands exactly on the footfall (and the head dip).
		var next := index + 1
		if step_scheduled != next:
			var remaining := (float(next) * PI - step_phase) / rate
			if remaining <= 0.2 and play_step(running, remaining): step_scheduled = next
	else:
		bob_weight = move_toward(bob_weight, 0.0, delta * 4.0)
		step_scheduled = -1
	eye_height = move_toward(eye_height, 0.9 if crouched else 1.64, delta * 5.0)
	# Head is highest mid-stride and dips at each heel strike; it sways toward
	# the planted foot once per two steps.
	# Kept subtle: about 1.5 cm walking and 2.5 cm running at the default setting.
	var amplitude: float = 0.0 if settings.values.reduced else settings.values.bob * (0.1 if crouched else 0.25 if running else 0.15)
	var lift := (absf(sin(step_phase)) - 0.6) * amplitude * bob_weight
	update_peek(delta)
	camera.position = Vector3(sin(step_phase) * amplitude * 0.2 * bob_weight, eye_height + lift, 0.0) + peek_lean()
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

## Starts a step clip so its impact sounds `ahead` seconds from now. Returns
## false while it is still too early for this clip's lead-in.
func play_step(running: bool, ahead: float) -> bool:
	var set_name := ("hard_walk" if hard_floor else "carpet_run" if running and not crouched else "carpet_walk")
	var clips: Array = step_clips[set_name]
	var clip: Dictionary = clips[randi() % clips.size()]
	# Hard-floor running reuses the walk takes, struck quicker and harder.
	var pitch := randf_range(0.95, 1.05)
	if crouched: pitch = randf_range(0.9, 0.97)
	elif running and hard_floor: pitch = randf_range(1.04, 1.12)
	var lead := ahead * pitch
	if lead > clip.impact: return false
	var voice := step_voices[step_voice]
	step_voice = (step_voice + 1) % step_voices.size()
	voice.stream = clip.stream
	voice.pitch_scale = pitch
	voice.volume_db = (-41.0 if crouched else -22.0 if running else -31.0) + (2.0 if hard_floor else 0.0)
	voice.play(clip.impact - lead)
	step_impact_frame = Engine.get_physics_frames() + ahead * Engine.physics_ticks_per_second
	return true

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

## Hold forward to ease the doors open, release to let them fall shut. Looking
## to one side opens the opposite leaf wider: its open door screens the near
## side while the head leans out through that half to look across.
func update_peek(delta: float) -> void:
	var wanted := 1.0 if hidden and active and Input.is_action_pressed("forward") else 0.0
	peek = move_toward(peek, wanted, delta * (0.5 if wanted > peek else 0.9))
	if not hidden:
		peek_side = 0.0
		return
	var look := clampf(wrapf(rotation.y - hide_yaw, -PI, PI) / 0.9, -1.0, 1.0)
	peek_side = move_toward(peek_side, look, delta * 2.5)
	# The occupant's right hand is the wardrobe's -X ("left") leaf.
	var toward_left := maxf(peek_side, 0.0)
	var toward_right := maxf(-peek_side, 0.0)
	var right_hand := lerpf(0.55, 1.0, toward_left) * lerpf(1.0, 0.0, toward_right)
	var left_hand := lerpf(0.55, 1.0, toward_right) * lerpf(1.0, 0.0, toward_left)
	if is_instance_valid(hiding_place): hiding_place.set_peek(peek * right_hand, peek * left_hand)
	# Narrow the view back inside as the doors close.
	var limit := lerpf(HIDE_LOOK.x, HIDE_LOOK.y, peek)
	rotation.y = hide_yaw + clampf(wrapf(rotation.y - hide_yaw, -PI, PI), -limit, limit)

## Head offset in body space: forward through the doors and sideways into the
## half that is open, fixed to the wardrobe rather than to where the view turns.
func peek_lean() -> Vector3:
	if not hidden or peek <= 0.0: return Vector3.ZERO
	# Wardrobe-aligned axes seen from inside: forward is -Z, the right hand +X.
	# Looking left leans out through the right-hand half, and the other way round.
	var outward := Vector3(peek_side * PEEK_SIDE_LEAN, 0.0, -PEEK_LEAN - absf(peek_side) * 0.12) * peek
	return Basis(Vector3.UP, hide_yaw - rotation.y) * outward

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

## Dragged out of a wardrobe (an execution): no room needed outside.
func force_leave_hide() -> void:
	if not hidden: return
	if is_instance_valid(hiding_place): hiding_place.leave()
	hiding_place = null
	hidden = false
	peek = 0.0
	hiding_changed.emit(false, global_position)

func reset_survival() -> void:
	held = false
	if is_instance_valid(hiding_place): hiding_place.leave()
	hidden = false
	hiding_place = null
	peek = 0.0
	reading = false
	crouched = false
	stamina = 100
	recovery_delay = 0
	exhausted = false
	step_phase = 0

func set_character(index: int) -> void:
	if avatar != null and avatar.character != index: avatar.configure(index, true)
