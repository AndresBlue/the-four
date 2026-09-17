extends Node
## Dark aura around the creature. As it gets closer by walkable route, a sub
## drone presses in, the ambience is muffled, and directional cues (breathing,
## chitters, swells) sound a few metres ahead of the listener along the route
## the creature would take to reach them. Doors and walls do not hide which
## way it is coming from, but the cues never reveal its exact position.
## Presentation only: it reads the creature, never changes its behaviour.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const CHITTERS := ["res://assets/audio/dread/chitter_0.wav", "res://assets/audio/dread/chitter_1.wav", "res://assets/audio/dread/chitter_2.wav", "res://assets/audio/dread/chitter_3.wav"]
const HEART_LUB := "res://assets/audio/sfx/heartbeat/1.ogg"
const HEART_DUB := "res://assets/audio/sfx/heartbeat/2.ogg"
const TIMING := preload("res://game/audio/cue_timing.gd")
const ACOUSTIC_MASK := 512
## Route distance (metres) at which the aura begins, and where it is at full strength.
@export var start_distance := 30.0
@export var full_distance := 4.0
## How far ahead along the route the directional cues sit, when far and when close.
@export var cue_distance_far := 7.5
@export var cue_distance_near := 2.5
## Intensity from which the heartbeat starts, and its tempo range (BPM).
@export var heartbeat_from := 0.5
@export var heartbeat_bpm := Vector2(64, 128)
var world_audio
var intensity := 0.0
var target := 0.0
var route_distance := INF
var cue_point := Vector3.INF
var drone: AudioStreamPlayer
var breath: AudioStreamPlayer3D
var chitter: AudioStreamPlayer3D
var riser: AudioStreamPlayer3D
var heart: AudioStreamPlayer
var chitter_streams: Array[AudioStream] = []
var lub: AudioStream
var dub: AudioStream
var route_clock := 0.0
var chitter_clock := 2.0
var heart_clock := 0.0
var riser_cooldown := 0.0
var clock := 0.0
var muffle: AudioEffectLowPassFilter
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	world_audio = get_parent()
	rng.randomize()
	drone = AudioStreamPlayer.new()
	drone.name = "DreadDrone"
	drone.bus = "Aura"
	drone.stream = world_audio.loop_stream(load("res://assets/audio/dread/dread_drone.wav"))
	add_child(drone)
	breath = spatial("DreadBreath", world_audio.loop_stream(load("res://assets/audio/dread/dread_breath.wav")), 3.0, 22.0)
	chitter = spatial("DreadChitter", null, 3.5, 26.0)
	riser = spatial("DreadSwell", load("res://assets/audio/dread/presence_riser.wav"), 5.0, 30.0)
	heart = AudioStreamPlayer.new()
	heart.name = "Heartbeat"
	heart.bus = "Threat"
	add_child(heart)
	for path in CHITTERS: chitter_streams.append(load(path))
	lub = load(HEART_LUB)
	dub = load(HEART_DUB)
	var ambience := AudioServer.get_bus_index("Ambience")
	for index in AudioServer.get_bus_effect_count(ambience):
		if AudioServer.get_bus_effect(ambience, index) is AudioEffectLowPassFilter: muffle = AudioServer.get_bus_effect(ambience, index)

func spatial(title: String, stream: AudioStream, unit: float, reach: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = title
	player.bus = "Aura"
	player.stream = stream
	player.unit_size = unit
	player.max_distance = reach
	player.max_db = 6.0
	player.area_mask = ACOUSTIC_MASK
	player.panning_strength = 1.4
	add_child(player)
	return player

func reset() -> void:
	intensity = 0.0
	target = 0.0
	route_distance = INF
	cue_point = Vector3.INF
	for player in [drone, breath, chitter, riser, heart]: player.stop()
	if muffle != null: muffle.cutoff_hz = 20000.0
	riser_cooldown = 0.0

## Point `distance` metres along a path, or its end.
static func along(path: PackedVector3Array, distance: float) -> Vector3:
	var left := distance
	for i in range(1, path.size()):
		var segment := path[i].distance_to(path[i - 1])
		if segment >= left: return path[i - 1].lerp(path[i], left / maxf(segment, 0.001))
		left -= segment
	return path[path.size() - 1]

func update_route(listener: Vector3, creature: Node3D) -> void:
	var straight := listener.distance_to(creature.global_position)
	if straight > start_distance * 1.3:
		route_distance = straight * 1.3
		cue_point = listener + (creature.global_position - listener).normalized() * cue_distance_far
		return
	var level = world_audio.level
	var path := FLOOR.navigation_path(level.get_world_3d().navigation_map, level.player.global_position, creature.global_position)
	if path.size() < 2:
		route_distance = straight * 1.3
		cue_point = creature.global_position
		return
	var length := 0.0
	for i in range(1, path.size()): length += path[i].distance_to(path[i - 1])
	route_distance = length
	var ahead := minf(lerpf(cue_distance_far, cue_distance_near, intensity), length)
	cue_point = along(path, ahead)

func _physics_process(delta: float) -> void:
	var level = world_audio.level
	if level == null or not world_audio.enabled: return
	clock += delta
	riser_cooldown = maxf(0.0, riser_cooldown - delta)
	var creature = level.locust
	var active: bool = is_instance_valid(creature) and level.session.state == level.session.State.PLAYING and creature.grace <= 0 and not level.in_refuge()
	var listener: Vector3 = world_audio.listener_position()
	target = 0.0
	if active:
		route_clock -= delta
		if route_clock <= 0.0:
			route_clock = 0.25
			update_route(listener, creature)
		# Rises steadily with closeness instead of saturating early.
		target = pow(clampf((start_distance - route_distance) / (start_distance - full_distance), 0.0, 1.0), 1.3)
		# Its state sharpens the dread: hunting reads worse than wandering.
		match creature.mode:
			creature.Mode.CHASE, creature.Mode.WINDUP, creature.Mode.RECOVER, creature.Mode.ALERT: target = maxf(target + 0.25, 0.7)
			creature.Mode.INVESTIGATE, creature.Mode.SEARCH: target += 0.08
		target = clampf(target, 0.0, 1.0)
	var previous := intensity
	intensity = move_toward(intensity, target, delta * (0.6 if target > intensity else 0.18))
	var shaped := pow(intensity, 1.4)
	apply_levels(shaped, delta, listener)
	if intensity > 0.02 and cue_point != Vector3.INF:
		var ear := cue_point + Vector3.UP * 1.5
		breath.global_position = ear if breath.global_position.distance_to(ear) > 6.0 else breath.global_position.lerp(ear, minf(1.0, delta * 2.5))
	update_chitters(delta)
	update_heart(delta)
	if previous < 0.55 and intensity >= 0.55 and riser_cooldown <= 0.0 and cue_point != Vector3.INF:
		riser.global_position = cue_point + Vector3.UP * 1.5
		riser.volume_db = 0.0
		riser.play()
		riser_cooldown = 30.0

func apply_levels(shaped: float, _delta: float, _listener: Vector3) -> void:
	var audible := intensity > 0.01
	for player in [drone, breath]:
		if audible and not player.playing: player.play(rng.randf() * 4.0)
		elif not audible and player.playing: player.stop()
	# The drone wavers slightly off pitch, which reads as wrong rather than musical.
	# Pressure stays underneath: the directional layers must stay readable.
	drone.volume_db = lerpf(-42.0, -15.0, shaped)
	drone.pitch_scale = 0.97 + sin(clock * 0.21) * 0.015 + shaped * 0.02
	breath.volume_db = lerpf(-24.0, 6.0, shaped)
	breath.pitch_scale = 0.9 + sin(clock * 0.13) * 0.04
	if muffle != null: muffle.cutoff_hz = lerpf(20000.0, 650.0, pow(intensity, 1.8))

func update_chitters(delta: float) -> void:
	chitter_clock -= delta
	if chitter_clock > 0.0 or intensity < 0.15 or cue_point == Vector3.INF: return
	# Clicks jump a little around the route point so the ear keeps searching.
	var jitter := Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(0.8, 2.4), rng.randf_range(-1.4, 1.4))
	chitter.global_position = cue_point + jitter
	chitter.stream = chitter_streams[rng.randi_range(0, chitter_streams.size() - 1)]
	chitter.pitch_scale = rng.randf_range(0.82, 1.18)
	chitter.volume_db = lerpf(-6.0, 6.0, intensity)
	chitter.play()
	chitter_clock = lerpf(5.5, 0.6, intensity) * rng.randf_range(0.6, 1.5)

func update_heart(delta: float) -> void:
	if intensity < heartbeat_from:
		heart_clock = 0.0
		return
	var strength := (intensity - heartbeat_from) / (1.0 - heartbeat_from)
	var period := 60.0 / lerpf(heartbeat_bpm.x, heartbeat_bpm.y, strength)
	heart_clock -= delta
	if heart_clock <= 0.0:
		# Each recording is a whole beat; alternate them and restart on tempo.
		heart_clock = period
		heart.stream = lub if heart.stream != lub else dub
		heart.volume_db = lerpf(-20.0, -8.0, strength)
		heart.pitch_scale = 1.0 + strength * 0.08
		heart.play(TIMING.onset(heart.stream.resource_path))
