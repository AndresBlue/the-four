extends CharacterBody3D
const NOISE := preload("res://game/audio/noise_kinds.gd")
## How the body moves, shared with the test bots (tools/bots).
const MOVEMENT := preload("res://game/player/survivor_gait.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PAD_FEEL := preload("res://game/player/pad_feel.gd")
## The pad's look and its running and crouching that flip (pad_feel.gd).
var pad := PAD_FEEL.new()
## Under this far pushed, a pad's toggled run walks: a light push creeps even
## with running on.
const RUN_PUSH := 0.55
var avatar
## Seat in the match (session participant key). Single player is seat 1.
var slot := 1
var camera: Camera3D
var torch: SpotLight3D
## A noise the creature may hear: where, how far it carries, and what made
## it (NOISE.Kind, which only the hunter's acoustic image reads).
signal noise(point: Vector3, radius: float, kind: int)
## `quiet`: it left the slow way (hiding_place.QUIET_EXIT).
signal hiding_changed(entering: bool, point: Vector3, quiet: bool)
var active := false
var stamina := 100.0
## How much of a mind is left, 100 down to 0. It falls in the dark and comes
## back in the light; the level keeps it (sanity.gd, tick). At zero the
## body gives off motes the creature senses from anywhere.
var sanity := 100.0
var burnt := false
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
## Stepping into a wardrobe or out of it: the body carried from where it was
## to where it is going, turning as it goes, instead of being put there
## between two frames. {from, to, yaw_from, yaw_to, time, length}. Nothing
## else moves it meanwhile, and anything that takes the body away (a capture,
## a floor rebuilt) ends it where it is.
var transit := {}
## How far the doors are eased open by the key being held to leave quietly.
var easing := 0.0
## 0..1: how far the wardrobe doors are eased open while hiding.
var peek := 0.0
## -1..1: which side the occupant looks to while peeking (+ is left), smoothed.
var peek_side := 0.0
## Looking range inside the wardrobe (radians either side), shut and fully ajar.
## (Ajar it was 1.45, with the head out past the doors: see PEEK_BACK.)
const HIDE_LOOK := Vector2(0.35, 0.7)
## How far the look has to turn for a leaf to be asked all it opens.
const PEEK_TURN := 0.45
## The head in a wardrobe, which never leaves it. Shut in, an eye rests
## CRACK_BACK behind the crack between the doors (hiding_place.slit), where
## a strip of the room is seen through it. Holding forward, it comes up to
## PEEK_BACK short of the doors' plane, on the wardrobe's middle line, and
## looking aside moves it PEEK_SIDE_LEAN over to the other side, to look out
## between the leaf that opens and the one that shuts. It used to lean half
## a metre out through the doors, and what was seen from there was the room,
## not a gap.
const CRACK_BACK := 0.14
const PEEK_BACK := 0.16
const PEEK_SIDE_LEAN := 0.16
## How far the head has settled at the crack (0 to 1), and where that and the
## place it peeks from are from where the body stands, in the body's own axes
## as it faces the doors (x to the right hand, -z towards them).
var nook := 0.0
var crack_at := Vector3.ZERO
var gap_at := Vector3.ZERO
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
# Hand-held torch: position relative to the camera and how loosely it follows.
const HAND_OFFSET := Vector3(0.24, -0.3, -0.25)
var torch_follow := 9.0
var torch_energy := 0.0
var torch_warmup := 1.0
var torch_clock := 0.0
## The camcorder is carried, not bolted to the head: on top of the look it
## trails quick turns and banks into them (a spring), trembles with the hand,
## rises and falls with breathing and nods at each heel strike. Radians
## (pitch, yaw, roll) at the default "Movimiento de cámara". The offset is
## taken out and put back every frame, so what the mouse or a script writes to
## the camera stays the look and the tremor never builds up in it. Tests and
## capture tools (--automation) run without it, so every frame is repeatable.
const TREMOR := Vector3(0.0016, 0.0013, 0.0011)
const BREATH := Vector3(0.0022, 0.0, 0.0009)
const GAIT := Vector3(0.0055, 0.0022, 0.0035)
## The spring that trails the picture behind a turn: how stiff it is, how much
## it is damped, and how far it may ever throw the camera (radians, four times
## the largest target, so nothing normal comes near it). It is integrated
## implicitly, which at this stiffness costs one division and holds at any
## frame time. The explicit form this replaces diverged below about 8 FPS, and
## a spring that diverges writes infinity into the camera's rotation, which
## becomes NaN -- and a camera in NaN draws nothing at all, not for this match
## and not for the next, because the body is the same node throughout.
const SWAY_STIFFNESS := 110.0
const SWAY_DAMPING := 13.0
const SWAY_LIMIT := 0.1
var handheld_enabled := true
## Rotation offset applied last frame.
var handheld := Vector3.ZERO
var turn_delta := Vector2.ZERO
var turn_rate := Vector2.ZERO
var sway := Vector3.ZERO
var sway_velocity := Vector3.ZERO
var hand_clock := 0.0
var was_on_floor := true
## Autofocus (graphics preset "autofocus", set by the level): the distance the
## lens is focused at follows what is in the centre of the picture, late, and
## hunts a little after a big change. A wide-angle camcorder keeps nearly all
## of a room sharp, so only something close (a document, a door leaf at arm's
## length) throws the background out of focus.
var autofocus := false
var focus := 6.0
var focus_target := 6.0
var hunt := 0.0
var focus_attributes: CameraAttributesPractical
## The camcorder's recording lamp: the red light on its front that blinks
## while the tape runs -- the dot beside REC on its screen is the same lamp
## (camcorder_osd.lamp_lit). Carried, it barely shows: it tints what is at
## arm's length, in the dark, and nothing else. When the creature has its
## owner it is all the light there is in a dark place, and the tape of the
## capture brings it up (`pilot_as`, death_tape.gd): a face a hand away from
## the lens is red in it, a body a metre off just is. It is on this machine
## only -- nobody else sees it and the creature takes no notice of it -- so
## it changes nothing that anybody can do.
const PILOT_COLOR := Color(1.0, 0.06, 0.03)
## Its strength, its reach (metres) and how fast it falls off with distance,
## as it is carried.
const PILOT_CARRIED := Vector3(0.035, 0.7, 1.4)
var pilot: OmniLight3D
## The same three as a capture wants them, or nothing (x under 0).
var pilot_as := Vector3(-1.0, 0.0, 0.0)

func _ready() -> void:
	avatar = $Avatar
	add_to_group("hotel_players")
	body_shape = $BodyShape
	camera = $Camera
	torch = $Camera/Flashlight
	# Out of the bounce light (bounce_light.gd): each volume took the beam in
	# within its own walls only, so its glow stopped dead at a cell's edge, a
	# corridor wall cut in two and the ceiling twice as bright on one side.
	torch.light_bake_mode = Light3D.BAKE_DISABLED
	if plain_beam(): shape_plain_beam(torch)
	elif torch.light_projector == null: torch.light_projector = beam_pattern()
	torch_energy = torch.light_energy
	pilot = OmniLight3D.new()
	pilot.name = "RecordingLamp"
	pilot.light_color = PILOT_COLOR
	pilot.light_energy = 0.0
	pilot.omni_range = PILOT_CARRIED.y
	pilot.omni_attenuation = 1.4
	pilot.shadow_enabled = false
	pilot.light_specular = 0.3
	pilot.light_volumetric_fog_energy = 0.0
	pilot.light_bake_mode = Light3D.BAKE_DISABLED
	# Beside the lens, a little ahead of it.
	pilot.position = Vector3(0.035, -0.02, -0.05)
	pilot.visible = false
	camera.add_child(pilot)
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
	# --handheld puts it back for a recorded walkthrough under --automation.
	handheld_enabled = not OS.get_cmdline_user_args().has("--automation") or OS.get_cmdline_user_args().has("--handheld")

func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if not reading and not hidden: pad.pressed(event, settings)
	if event is InputEventMouseMotion and not reading:
		# Zoomed in, the same hand movement swings the picture as much more,
		# so the look slows down with the lens.
		look_by(Vector2(-event.relative.x, -event.relative.y) * (settings.values.sensitivity / zoom))
	if event is InputEventMouseButton and event.pressed and not reading:
		# The zoom rocker: the wheel forward is T, back is W.
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_to(zoom_wanted * ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_to(zoom_wanted / ZOOM_STEP)
	# And on a pad, the cross up and down (it is free in play: it only dials
	# the keypad, which takes the body away from here while it is up).
	if event is InputEventJoypadButton and event.pressed and not reading:
		if event.button_index == JOY_BUTTON_DPAD_UP: zoom_to(zoom_wanted * ZOOM_STEP)
		elif event.button_index == JOY_BUTTON_DPAD_DOWN: zoom_to(zoom_wanted / ZOOM_STEP)
	if event.is_action_pressed("flashlight"):
		torch.visible = not torch.visible
		torch_warmup = 0.0

## Turning the head, however it was asked for: the mouse in pixels moved, the
## pad in how far the stick is pushed. Positive x turns left, positive y looks
## up; inverting the vertical is the player's own setting and belongs here, at
## the one place the picture is actually turned.
func look_by(amount: Vector2) -> void:
	var up: float = amount.y * (-1.0 if settings.values.invert else 1.0)
	turn_delta += Vector2(amount.x, up)
	rotate_y(amount.x)
	if hidden:
		var limit := lerpf(HIDE_LOOK.x, HIDE_LOOK.y, peek)
		rotation.y = hide_yaw + clampf(wrapf(rotation.y - hide_yaw, -PI, PI), -limit, limit)
	camera.rotation.x = clampf(camera.rotation.x + up, -1.45, 1.45)

## The right stick, read every drawn frame (pad_feel.look: eased, gentle in
## the middle, quicker held at the rim), and slowed by the zoomed lens the same
## way the mouse is.
func pad_look(delta: float) -> void:
	if not active or reading or settings == null:
		pad.stick = Vector2.ZERO
		return
	var turn := pad.look(delta, settings, zoom)
	if turn != Vector2.ZERO: look_by(turn)

func _physics_process(delta: float) -> void:
	if held:
		velocity = Vector3.ZERO
		transit = {}
		return
	if not transit.is_empty():
		step_transit(delta)
		return
	var axis := Input.get_vector("left", "right", "forward", "backward") if active and not hidden and not reading else Vector2.ZERO
	# How far the stick is pushed is how fast: a keyboard is always all the way.
	var push := minf(axis.length(), 1.0)
	var direction := (basis * Vector3(axis.x, 0, axis.y)).normalized() * push
	# Reading (a document, the sheet, the keypad) keeps the body still: the
	# keys that jump and crouch are read from the whole keyboard, so a space
	# typed while reading used to jump -- and a jump is heard. It stays as it
	# was, crouched or standing.
	var wants_crouch: bool = crouched if reading else active and not hidden and pad.wants("crouch", settings)
	MOVEMENT.set_crouch(self, wants_crouch)
	var running := MOVEMENT.tire(self, active and not hidden and push > RUN_PUSH and pad.wants("sprint", settings), delta)
	pad.settle(push > 0.1, exhausted or hidden, delta)
	# Out of the body (dead, watching, between floors): nothing stays flipped on.
	if not active: pad.reset()
	MOVEMENT.accelerate(self, direction, running, delta)
	if active and not hidden and not reading and not crouched and is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = 5.4
		noise.emit(global_position, NOISE.radius("jump"), NOISE.Kind.JUMP)
	move_and_slide()
	avatar.update_pose(velocity, crouched, delta, is_on_floor())
	# Out of the floor: under the lowest planta, not under the first one, which
	# is where everybody arriving at the second planta would already be.
	if position.y < FLOOR.planta_y(FLOOR.PLANTAS - 1) - 5.0:
		position = spawn
		velocity = Vector3.ZERO
	# Footfalls come from distance covered: one step per stride length, so
	# cadence and camera motion always match the actual ground speed.
	var planar := Vector2(velocity.x, velocity.z).length()
	if planar > 0.25 and is_on_floor() and not hidden:
		var stride := MOVEMENT.stride(crouched, running)
		var previous := floori(step_phase / PI)
		var rate := planar / stride * PI
		step_phase += rate * delta
		bob_weight = move_toward(bob_weight, 1.0, delta * 5.0)
		var index := floori(step_phase / PI)
		if index != previous:
			# Standing but creeping (a pad pushed only a little) is as quiet as
			# crouching at the same speed: the step is what is heard, not the pose.
			var heard := MOVEMENT.footfall(crouched or (not running and planar <= MOVEMENT.SPEED_CROUCH + 0.1), running, hard_floor)
			noise.emit(global_position, heard.radius, heard.kind)
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
	# Landing: the arms absorb it, the camera dips and swings back.
	var grounded := is_on_floor()
	if grounded and not was_on_floor: sway_velocity.x -= 0.35
	was_on_floor = grounded

## The beam's shape is a projector texture, and the Compatibility renderer --
## the one the modest machines run -- does not draw projectors at all. There
## the torch came out as a flat disc of light with a hard rim, a great deal
## wider than the beam, and its shadow, biased for Forward+, striped every wall
## it was pointed at with wide diagonal bands. On that renderer the beam is
## shaped with the cone's own falloff instead and biased for the depth it has.
## Found by looking, with tools/capture/torch_capture.gd: the bands are gone at
## 0.3 and 4.0 (0.12 and 2.0 cleared them at two metres and not at eleven), and
## 26 degrees with a falloff of 3 puts the pool of light where Forward+ has it.
const PLAIN_BEAM := {"angle": 26.0, "falloff": 3.0, "energy": 11.0, "bias": 0.3, "normal_bias": 4.0}

static func plain_beam() -> bool:
	return RenderingServer.get_current_rendering_method() != "forward_plus"

static func shape_plain_beam(lamp: SpotLight3D) -> void:
	lamp.light_projector = null
	lamp.spot_angle = PLAIN_BEAM.angle
	lamp.spot_angle_attenuation = PLAIN_BEAM.falloff
	lamp.light_energy = PLAIN_BEAM.energy
	lamp.shadow_bias = PLAIN_BEAM.bias
	lamp.shadow_normal_bias = PLAIN_BEAM.normal_bias

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

## Strength of the hand-held motion: the "Movimiento de cámara" slider (0.1 by
## default gives 1), none with reduced effects.
func handheld_strength() -> float:
	if not handheld_enabled or settings == null or settings.values.reduced: return 0.0
	return clampf(settings.values.bob / 0.1, 0.0, 3.0)

## Smooth noise in -1..1 with a 1/f spectrum: three octaves, each half as
## strong and twice as quick. `lane` keeps the three axes apart.
static func tremor_noise(t: float, lane: int) -> float:
	var value := 0.0
	var amplitude := 0.57
	var frequency := 0.7
	for octave in 3:
		var x := t * frequency + lane * 17.3 + octave * 5.1
		value += (sin(x) * 0.6 + sin(x * 2.17 + 1.3) * 0.4) * amplitude
		amplitude *= 0.5
		frequency *= 2.1
	return value

func update_handheld(delta: float) -> void:
	var strength := handheld_strength()
	hand_clock += delta
	# How fast the look is turning, smoothed (radians per second).
	var rate := turn_delta / maxf(delta, 0.001)
	turn_delta = Vector2.ZERO
	turn_rate = turn_rate.lerp(rate, 1.0 - exp(-delta * 12.0))
	# The arms trail a quick turn and bank into a sideways one; a stiff,
	# slightly underdamped spring brings the camera back with a hint of
	# overshoot. Clamped: a flick never throws the picture far.
	var target := Vector3(clampf(-turn_rate.y * 0.01, -0.02, 0.02), clampf(-turn_rate.x * 0.008, -0.02, 0.02), clampf(turn_rate.x * 0.012, -0.025, 0.025))
	# Backward Euler: the velocity is solved at the end of the step rather than
	# taken from its start, so a long frame settles the spring instead of
	# overshooting further every time.
	sway_velocity = (sway_velocity + (target - sway) * SWAY_STIFFNESS * delta) / (1.0 + delta * SWAY_DAMPING + delta * delta * SWAY_STIFFNESS)
	sway += sway_velocity * delta
	sway = sway.clampf(-SWAY_LIMIT, SWAY_LIMIT)
	var tremor := Vector3(tremor_noise(hand_clock, 0), tremor_noise(hand_clock, 1), tremor_noise(hand_clock, 2)) * TREMOR
	# Breathing: slow, deeper when winded.
	var winded := 1.0 + (1.0 - stamina / 100.0) * 2.0
	var breath := Vector3(sin(hand_clock * 1.7), 0.0, sin(hand_clock * 1.7 + 1.2)) * BREATH * winded
	# A nod at each heel strike (sharp, when the step's |sin| is near 0), a yaw
	# and a roll towards the planted foot once per stride.
	var strike := pow(1.0 - absf(sin(step_phase)), 5.0)
	var gait := Vector3(strike, sin(step_phase), sin(step_phase)) * GAIT * bob_weight * (1.7 if velocity.length() > 4.5 else 0.6 if crouched else 1.0)
	var offset := (sway + tremor + breath + gait) * strength
	# Nothing that is not a number leaves here. It should not be reachable any
	# more, but what it costs to be wrong is a black screen that outlives the
	# match: back to the menu, into a new floor, and still black.
	if not offset.is_finite() or not camera.rotation.is_finite():
		reset_handheld()
		return
	camera.rotation += offset - handheld
	handheld = offset

## The hand back at rest. Wherever the body is put somewhere new -- a floor
## built, a revival, a wardrobe -- the spring starts again with it: the player
## is the same node from one match to the next, and anything it was doing
## would otherwise be carried across.
func reset_handheld() -> void:
	sway = Vector3.ZERO
	sway_velocity = Vector3.ZERO
	turn_delta = Vector2.ZERO
	turn_rate = Vector2.ZERO
	handheld = Vector3.ZERO
	if is_instance_valid(camera) and not camera.rotation.is_finite(): camera.rotation = Vector3.ZERO

func update_focus(delta: float) -> void:
	if not autofocus:
		if camera.attributes == focus_attributes and focus_attributes != null: camera.attributes = null
		return
	if focus_attributes == null:
		focus_attributes = CameraAttributesPractical.new()
		focus_attributes.dof_blur_amount = 0.06
	if camera.attributes != focus_attributes: camera.attributes = focus_attributes
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 12.0, 1 | 8 | 16)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var measured: float = from.distance_to(hit.position) if not hit.is_empty() else 12.0
	# A big jump in distance sets the lens hunting: it overshoots and swings
	# back for a moment before it settles.
	if absf(measured - focus_target) > maxf(0.6, focus_target * 0.5): hunt = 1.0
	focus_target = measured
	hunt = maxf(0.0, hunt - delta * 2.5)
	var swing := sin(hand_clock * 17.0) * hunt * 0.35 * focus_target
	focus = lerpf(focus, focus_target + swing, 1.0 - exp(-delta * 6.0))
	var close := focus < 1.6
	focus_attributes.dof_blur_far_enabled = close
	focus_attributes.dof_blur_far_distance = focus * 1.8
	focus_attributes.dof_blur_far_transition = focus * 2.0
	focus_attributes.dof_blur_near_enabled = true
	focus_attributes.dof_blur_near_distance = minf(0.35, focus * 0.5)
	focus_attributes.dof_blur_near_transition = 0.2

## Where the camera looks without the hand-held motion (what the network
## sends as the look, for instance).
## The camcorder's zoom (LOOK.ZOOM_MAX at full telephoto), how far one notch
## of the wheel pushes the rocker, and how fast the motor travels (the whole
## range in about a second: a quick roll of the wheel takes it end to end).
const LOOK := preload("res://game/presentation/camcorder_look.gd")
const ZOOM_STEP := 1.42
const ZOOM_SPEED := 2.4
var zoom := 1.0
var zoom_wanted := 1.0

func zoom_to(value: float) -> void:
	zoom_wanted = clampf(value, 1.0, LOOK.ZOOM_MAX)

## Follows the rocker at the motor's pace, evenly along the lens's travel.
func update_zoom(delta: float) -> void:
	var here := log(zoom) / log(2.0)
	var there := log(zoom_wanted) / log(2.0)
	zoom = pow(2.0, move_toward(here, there, delta * ZOOM_SPEED))

## Where the rocker stands, 0 wide to 1 telephoto (the zoom bar in the OSD).
func zoom_fraction() -> float:
	return log(zoom) / log(LOOK.ZOOM_MAX)

func look_pitch() -> float:
	return camera.rotation.x - handheld.x

func _process(delta: float) -> void:
	if is_instance_valid(camera) and settings != null:
		pad_look(delta)
		update_zoom(delta)
		update_handheld(delta)
		update_focus(delta)
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

## The recording lamp, as the level has it this frame: lit or between two
## blinks, and whether there is a tape being recorded here at all.
func set_pilot(lit: bool, recording: bool) -> void:
	if not is_instance_valid(pilot): return
	pilot.visible = recording and lit
	var wanted := pilot_as if pilot_as.x >= 0.0 else PILOT_CARRIED
	pilot.light_energy = wanted.x
	pilot.omni_range = wanted.y
	pilot.omni_attenuation = wanted.z

## Burnt out, or back from it. The motes are the only thing that says so to
## anybody else.
## A mind that has gone out. Nothing shows on the body: it is the creature's
## to know, from anywhere on the floor, not something anybody sees.
func set_burnt(on: bool) -> void:
	burnt = on

func can_stand() -> bool: return MOVEMENT.can_stand(self)

## Hold forward to ease the doors open, release to let them fall shut. Looking
## to one side opens the opposite leaf wider: its open door screens the near
## side while the head leans out through that half to look across.
func update_peek(delta: float) -> void:
	var wanted := 1.0 if hidden and active and Input.is_action_pressed("forward") else 0.0
	peek = move_toward(peek, wanted, delta * (0.5 if wanted > peek else 0.9))
	# The eye goes to the crack once the body is in, and comes away as it leaves.
	nook = move_toward(nook, 1.0 if hidden and transit.is_empty() else 0.0, delta * 3.0)
	if not hidden:
		peek_side = 0.0
		return
	# Where the crack and the gap are from where this body stands (which is
	# where the wardrobe's back and sides let it, not always where it was
	# put): the wardrobe's x and z are the body's turned half round.
	if is_instance_valid(hiding_place) and transit.is_empty():
		var stands: Vector3 = hiding_place.to_local(global_position)
		crack_at = Vector3(stands.x - hiding_place.slit.x, 0.0, stands.z - (hiding_place.slit.z - CRACK_BACK))
		gap_at = Vector3(stands.x, 0.0, stands.z - (hiding_place.hinge.z - PEEK_BACK))
	var look := clampf(wrapf(rotation.y - hide_yaw, -PI, PI) / PEEK_TURN, -1.0, 1.0)
	peek_side = move_toward(peek_side, look, delta * 2.5)
	# The occupant's right hand is the wardrobe's -X ("left") leaf.
	var toward_left := maxf(peek_side, 0.0)
	var toward_right := maxf(-peek_side, 0.0)
	var ahead: float = hiding_place.PEEK_AHEAD if is_instance_valid(hiding_place) else 0.8
	var right_hand := lerpf(ahead, 1.0, toward_left) * lerpf(1.0, 0.0, toward_right)
	var left_hand := lerpf(ahead, 1.0, toward_right) * lerpf(1.0, 0.0, toward_left)
	if is_instance_valid(hiding_place): hiding_place.set_peek(peek * right_hand, peek * left_hand, self)
	# Narrow the view back inside as the doors close.
	var limit := lerpf(HIDE_LOOK.x, HIDE_LOOK.y, peek)
	rotation.y = hide_yaw + clampf(wrapf(rotation.y - hide_yaw, -PI, PI), -limit, limit)

## Head offset in body space: at the crack with the doors shut, up behind the
## gap as they open and over to the side away from where it looks, fixed to
## the wardrobe rather than to where the view turns.
func peek_lean() -> Vector3:
	if nook <= 0.0 and peek <= 0.0: return Vector3.ZERO
	# Wardrobe-aligned axes seen from inside: forward is -Z, the right hand +X.
	# Looking left moves over to the right-hand half, and the other way round.
	var out := gap_at + Vector3(peek_side * PEEK_SIDE_LEAN, 0.0, 0.0)
	return Basis(Vector3.UP, hide_yaw - rotation.y) * (crack_at * nook).lerp(out, peek)

## The body on its way into a wardrobe or out of it (transit).
func step_transit(delta: float) -> void:
	transit.time = float(transit.time) + delta
	var t := clampf(float(transit.time) / maxf(float(transit.length), 0.01), 0.0, 1.0)
	var eased := t * t * (3.0 - 2.0 * t)
	var before := global_position
	global_position = (transit.from as Vector3).lerp(transit.to, eased)
	rotation.y = lerp_angle(float(transit.yaw_from), float(transit.yaw_to), eased)
	velocity = Vector3.ZERO
	# The look levels out as it steps in, and the feet walk it.
	if hidden: camera.rotation.x = lerpf(camera.rotation.x, 0.0, minf(1.0, delta * 8.0))
	avatar.update_pose((global_position - before) / maxf(delta, 0.001), crouched, delta, true)
	eye_height = move_toward(eye_height, 0.9 if crouched else 1.64, delta * 5.0)
	update_peek(delta)
	camera.position = Vector3(0.0, eye_height, 0.0) + peek_lean()
	if t >= 1.0:
		transit = {}
		snap_torch()

func enter_hide(place: Node3D) -> bool:
	if hidden or not place.has_room(): return false
	hiding_place = place
	hidden = true
	peek = 0.0
	easing = 0.0
	place.enter(self)
	hide_yaw = place.global_rotation.y + PI
	nook = 0.0
	# Stepped into, turning round to face the doors.
	transit = {"from": global_position, "to": place.to_global(place.inside_of(self)), "yaw_from": rotation.y, "yaw_to": hide_yaw, "time": 0.0, "length": place.ENTER_TIME}
	velocity = Vector3.ZERO
	reset_handheld()
	torch.visible = false
	hiding_changed.emit(true, global_position, false)
	return true

## `quiet`: the doors were eased open first (hiding_place.QUIET_EXIT), and
## what is heard of it carries less far.
func leave_hide(quiet := false) -> bool:
	if not hidden or not is_instance_valid(hiding_place): return false
	var point: Vector3 = hiding_place.available_exit(self)
	if point == Vector3.INF: return false
	# Stepped out of, from wherever inside the body is.
	transit = {"from": global_position, "to": point, "yaw_from": rotation.y, "yaw_to": rotation.y, "time": 0.0, "length": hiding_place.QUIET_LEAVE_TIME if quiet else hiding_place.LEAVE_TIME}
	hiding_place.set_ease(0.0, self)
	hiding_place.leave(self)
	hiding_place = null
	peek = 0.0
	easing = 0.0
	hidden = false
	hiding_changed.emit(false, point, quiet)
	return true

## The key held to leave quietly: how far the doors are eased open by it (0
## to 1), and let fall shut again when it is let go.
func ease_out(amount: float) -> void:
	easing = clampf(amount, 0.0, 1.0)
	if hidden and is_instance_valid(hiding_place): hiding_place.set_ease(easing, self)

## Dragged out of a wardrobe (an execution): no room needed outside.
func force_leave_hide() -> void:
	if not hidden: return
	transit = {}
	if is_instance_valid(hiding_place):
		hiding_place.set_ease(0.0, self)
		hiding_place.leave(self)
	hiding_place = null
	hidden = false
	peek = 0.0
	easing = 0.0
	# Taken out, not stepping out: the head is nowhere but on its shoulders.
	nook = 0.0
	camera.position = Vector3(0.0, eye_height, 0.0)
	hiding_changed.emit(false, global_position, false)

func reset_survival() -> void:
	held = false
	transit = {}
	easing = 0.0
	if is_instance_valid(hiding_place): hiding_place.leave(self)
	hidden = false
	hiding_place = null
	peek = 0.0
	reading = false
	crouched = false
	stamina = 100
	recovery_delay = 0
	exhausted = false
	step_phase = 0
	reset_handheld()

func set_character(index: int) -> void:
	if avatar != null and avatar.character != index: avatar.configure(index, true)
