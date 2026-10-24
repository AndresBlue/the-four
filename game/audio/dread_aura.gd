extends Node
## Dark aura around the creature. As it gets closer by walkable route, a sub
## drone presses in, the ambience is muffled, and directional cues (breathing,
## chitters, swells) sound a few metres ahead of the listener along the route
## the creature would take to reach them. Doors and walls do not hide which
## way it is coming from, but the cues never reveal its exact position.
## Presentation only: it reads the creature, never changes its behaviour.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PROFILE := preload("res://game/audio/creature_audio_profile.gd")
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
## How much of the aura is left of a creature holding still to be taken for
## gone.
const HUSHED := 0.15
var world_audio
var intensity := 0.0
var target := 0.0
## What the target is before HUSHED: how near it is and how it hunts, with no
## allowance for a creature holding still. The theme goes by this
## (theme_mood): whoever waits in a wardrobe knows it is outside.
var menace := 0.0
var route_distance := INF
var cue_point := Vector3.INF
var drone: AudioStreamPlayer
var breath: AudioStreamPlayer3D
var chitter: AudioStreamPlayer3D
var heart: AudioStreamPlayer
var chitter_streams: Array[AudioStream] = []
var lub: AudioStream
var dub: AudioStream
var route_clock := 0.0
var chitter_clock := 2.0
var heart_clock := 0.0
var clock := 0.0
var muffle: AudioEffectLowPassFilter
## Whether the breath layer plays, and how far over the cue point the ear sits
## (use_profile()).
var breath_enabled := true
var rise := 1.5
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
	heart = AudioStreamPlayer.new()
	heart.name = "Heartbeat"
	heart.bus = "Threat"
	add_child(heart)
	if chitter_streams.is_empty():
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
	menace = 0.0
	route_distance = INF
	cue_point = Vector3.INF
	for player in [drone, breath, chitter, heart]: player.stop()
	if muffle != null: muffle.cutoff_hz = 20000.0

## Point `distance` metres along a path, or its end.
static func along(path: PackedVector3Array, distance: float) -> Vector3:
	var left := distance
	for i in range(1, path.size()):
		var segment := path[i].distance_to(path[i - 1])
		if segment >= left: return path[i - 1].lerp(path[i], left / maxf(segment, 0.001))
		left -= segment
	return path[path.size() - 1]

## How far it is walking from the listener to `source`, and where the cues
## sit for it: [metres, cue point].
func route_to(listener: Vector3, source: Vector3) -> Array:
	var straight := listener.distance_to(source)
	if straight > start_distance * 1.3: return [straight * 1.3, listener + (source - listener).normalized() * cue_distance_far]
	# On another planta it is not coming: nothing but the lift joins them.
	if FLOOR.planta_of(listener.y) != FLOOR.planta_of(source.y): return [INF, source]
	# The same route the creature's voice is given (world_audio.walked_route):
	# asked for once between the two of them.
	var path: PackedVector3Array = world_audio.walked_route(listener, source)
	if path.size() < 2: return [straight * 1.3, source]
	var length := 0.0
	for i in range(1, path.size()): length += path[i].distance_to(path[i - 1])
	return [length, along(path, minf(lerpf(cue_distance_far, cue_distance_near, intensity), length))]

## The creature (its presence_route(): The Locust's is route_to() from where
## it stands), or the one a mind going imagines walking past
## (world_audio.phantom_point), whichever is nearer: the aura is the same.
var from_phantom := false
func update_route(listener: Vector3, creature: Node3D, real: bool) -> void:
	var best: Array = creature.presence_route(listener) if real else [INF, Vector3.INF]
	from_phantom = false
	if world_audio.phantom_point != Vector3.INF:
		var imagined := route_to(listener, world_audio.phantom_point)
		if float(imagined[0]) < float(best[0]):
			best = imagined
			from_phantom = true
	route_distance = best[0]
	cue_point = best[1]

func _physics_process(delta: float) -> void:
	var level = world_audio.level
	if level == null or not world_audio.enabled: return
	clock += delta
	var creature = level.creature
	var playing: bool = is_instance_valid(creature) and level.session.state == level.session.State.PLAYING and not level.in_refuge() and not level.match_net.local_is_locust()
	var real: bool = playing and creature.grace <= 0
	var active: bool = real or (playing and world_audio.phantom_point != Vector3.INF)
	var listener: Vector3 = world_audio.listener_position()
	target = 0.0
	menace = 0.0
	if active:
		route_clock -= delta
		if route_clock <= 0.0:
			route_clock = 0.25
			update_route(listener, creature, real)
		# Rises steadily with closeness instead of saturating early.
		target = pow(clampf((start_distance - route_distance) / (start_distance - full_distance), 0.0, 1.0), 1.3)
		var near := clampf((start_distance * 1.5 - route_distance) / (start_distance * 0.5), 0.0, 1.0)
		# Its state sharpens the dread (alarm_level()): hunting reads worse
		# than wandering. An imagined one only walks.
		var alarm: int = 0 if from_phantom else int(creature.alarm_level())
		match alarm:
			# Scaled by how near it is: at full strength anywhere, a hunter
			# sprinting down an empty corridor across the floor told every
			# survivor it was running.
			2: target = maxf(target + 0.25 * near, 0.7 * near)
			1: target += 0.08 * near
		target = clampf(target, 0.0, 1.0)
		menace = target
		# Waiting beside a wardrobe for whoever is in it (hotel_locust, the
		# feint): it holds itself so still that what gives it away dies down,
		# as it would if it had gone. Its feet are not part of this: it has
		# not walked off, and nothing here says it has.
		if not from_phantom and creature.hushed(): target *= HUSHED
	var previous := intensity
	intensity = move_toward(intensity, target, delta * (0.6 if target > intensity else 0.18))
	var shaped := pow(intensity, 1.4)
	apply_levels(shaped, delta, listener)
	if intensity > 0.02 and cue_point != Vector3.INF:
		var ear := cue_point + Vector3.UP * rise
		breath.global_position = ear if breath.global_position.distance_to(ear) > 6.0 else breath.global_position.lerp(ear, minf(1.0, delta * 2.5))
	update_chitters(delta)
	update_heart(delta)

## The floor's creature's aura (creature_audio_profile's aura_*); null: the
## defaults, as the aura always was.
func use_profile(profile: Resource) -> void:
	var p: Resource = profile if profile != null and "aura_start" in profile else PROFILE.new()
	start_distance = float(p.aura_start)
	full_distance = float(p.aura_full)
	breath_enabled = bool(p.aura_breath)
	rise = float(p.aura_rise)
	chitter_streams = []
	for stream in p.aura_clicks: chitter_streams.append(stream)
	if chitter_streams.is_empty():
		for path in CHITTERS: chitter_streams.append(load(path))
	if not breath_enabled and breath != null: breath.stop()

func apply_levels(shaped: float, _delta: float, _listener: Vector3) -> void:
	var audible := intensity > 0.01
	for player in [drone, breath]:
		var on: bool = audible and (player != breath or breath_enabled)
		if on and not player.playing: player.play(rng.randf() * 4.0)
		elif not on and player.playing: player.stop()
	# The drone wavers slightly off pitch, which reads as wrong rather than musical.
	# Pressure stays underneath: the directional layers must stay readable.
	drone.volume_db = lerpf(-42.0, -15.0, shaped) + world_audio.duck_db()
	drone.pitch_scale = 0.97 + sin(clock * 0.21) * 0.015 + shaped * 0.02
	breath.volume_db = lerpf(-24.0, 6.0, shaped) + world_audio.duck_db()
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
	chitter.volume_db = lerpf(-6.0, 6.0, intensity) + world_audio.duck_db()
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
		heart.volume_db = lerpf(-20.0, -8.0, strength) + world_audio.duck_db()
		heart.pitch_scale = 1.0 + strength * 0.08
		heart.play(TIMING.onset(heart.stream.resource_path))
