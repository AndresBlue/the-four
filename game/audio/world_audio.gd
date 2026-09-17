extends Node
## Local presentation only: never changes AI hearing or consumes map RNG.
const BASE := "res://assets/audio/sfx/"
const TIMING := preload("res://game/audio/cue_timing.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
# Closing cues are emitted when the leaf lands; start just before the recorded
# impact so the latch is heard with the movement, not after it.
const CLOSE_PREROLL := 0.08
const HIDE_PREROLL := 0.3
## Area layer 3D sources respond to; gameplay areas stay out of the audio path.
const ACOUSTIC_MASK := 512
## Gains (dB) at the reference mix (sliders at 50%).
## Longest walkable route (metres) along which a sound still reaches the player.
const ROUTE_LIMIT := 42.0
const ECHO_BUS := {"Effects": &"EffectsEcho", "Threat": &"ThreatEcho"}
## Direction cues on headphones. World cues use the engine's panning, at the
## strength that separates left and right the most (measured with
## tools/audio/measure_spatial.gd; higher values blur it again).
const PANNING := {"Effects": 1.15, "Threat": 1.15}
## The creature is heard binaurally instead: its sounds reach the mixer as mono
## on its own buses, where the "Ears" delay sends each ear its own copy with
## the time difference between the ears (up to about 0.65 ms, as around a
## human head) and a level difference (the far ear up to EAR_SHADOW dB down).
const CREATURE_BUS := {false: &"Creature", true: &"CreatureEcho"}
const ITD_MS := 0.65
const EAR_SHADOW := 18.0
const EAR_NEAR := 1.5
## Smallest tap delay: a zero delay would read the wrong end of the buffer.
const EAR_BASE_MS := 0.05
var ear_itd := 0.0
var ear_side := 0.0
## Head shadow: a source behind the listener loses its highs and a little level,
## so front and back sound different, not just left and right.
const REAR_CUTOFF := 3200.0
const REAR_GAIN := -4.0
const GAIN := {"open": 1.0, "open_slow": -12.0, "slam": 0.0, "close": -11.0, "hide": -8.0}
const POOLS := {
	"open_near": ["door/opening/opening1.ogg", "door/opening/opening2.ogg", "door/opening/opening3.ogg", "door/opening/wooden-opening.ogg"],
	"open_far": ["door/opening/far-opening.ogg", "door/opening/far-soft-opening.ogg"],
	"open_slow": ["door/opening/slow-opening-clean.wav"],
	"close_near": ["door/closing/closing1.ogg", "door/closing/closing2.ogg", "door/closing/closing3.ogg", "door/closing/wooden-closing.ogg"],
	"close_far": ["door/closing/far-closing.ogg", "door/closing/far-soft-closing.ogg"],
	"open_slam_near": ["door/opening/close-hard-opening.ogg"],
	"open_slam_far": ["door/opening/far-hard-opening.ogg"],
	"close_slam_near": ["door/closing/close-hard-closing.ogg"],
	"close_slam_far": ["door/closing/far-hard-closing.ogg"],
	"hide_enter": ["wardrobe/closing1.ogg", "wardrobe/closing2.ogg", "wardrobe/closing3.ogg", "wardrobe/closing4.ogg"],
	"hide_leave": ["wardrobe/opening1.ogg", "wardrobe/opening2.ogg", "wardrobe/opening3.ogg", "wardrobe/opening4.ogg"],
}
@export_range(4.0, 24.0) var far_threshold := 12.0
@export_range(1, 16) var maximum_voices := 8
var level
var enabled := true
var rng := RandomNumberGenerator.new()
var last := {}
var streams := {}
var voices: Array[AudioStreamPlayer3D] = []
var last_event := {}
var presence: AudioStreamPlayer3D
var profile: Resource
var caption_text := ""
var caption_time := 0.0
var caption_cooldown := 0.0
var presence_gain := 0.0
var clock := 0.0
var aura
## Fluorescent hum from the nearest battens.
var hums: Array[AudioStreamPlayer3D] = []
## Hum level at the reference mix and its distance scale: clearly there under
## the tube and across its room, gone a room away. Fixtures hang at ceiling
## height, so the listener is never much closer than about 1.5 m.
const HUM_DB := -28.0
const HUM_UNIT := 4.0
const HUM_REACH := 13.0
var ambient_clock := 0.0
var route_clock := 0.0
var presence_route := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	presence = AudioStreamPlayer3D.new()
	presence.name = "CreaturePresence"
	presence.bus = "Threat"
	presence.unit_size = 9.0
	presence.max_db = 4.0
	presence.volume_db = -80.0
	presence.area_mask = ACOUSTIC_MASK
	presence.panning_strength = 0.0
	add_child(presence)
	aura = get_node_or_null("DreadAura")
	for i in 2:
		var hum := make_source("FluorescentHum", "Ambience", loop_stream(load("res://assets/audio/dread/fluorescent_hum.wav")), HUM_UNIT, HUM_REACH)
		# Capped so standing right under a tube is never harsh.
		hum.max_db = HUM_DB + 3.0
		hums.append(hum)

func make_source(title: String, bus: String, stream: AudioStream, unit: float, reach: float) -> AudioStreamPlayer3D:
	var source := AudioStreamPlayer3D.new()
	source.name = title
	source.bus = bus
	source.stream = stream
	source.unit_size = unit
	source.max_distance = reach
	source.area_mask = ACOUSTIC_MASK
	add_child(source)
	return source

## Listener-based acoustics: the reverb on effect and threat buses follows the
## space the player is in, tight in rooms and long in merged salons.
func update_space(delta: float) -> void:
	var wanted := {"room_size": 0.5, "wet": 0.12, "damping": 0.6}
	if level.session.state == level.session.State.PLAYING and not level.manifest.is_empty():
		var room := FLOOR.room_at(level.manifest.rooms, listener_position())
		if not room.is_empty():
			if room.hall >= 0: wanted = {"room_size": 0.86, "wet": 0.24, "damping": 0.42}
			elif room.type in FLOOR.HARD_FLOORS: wanted = {"room_size": 0.42, "wet": 0.2, "damping": 0.25}
	for bus_name in ["Effects", "Threat", "Steps"]:
		var bus := AudioServer.get_bus_index(bus_name)
		if bus < 0: continue
		for index in AudioServer.get_bus_effect_count(bus):
			var reverb = AudioServer.get_bus_effect(bus, index)
			if not reverb is AudioEffectReverb: continue
			var extra := 0.04 if bus_name == "Threat" else 0.0
			# Your own steps only take a trace of the room, never a hall's echo.
			var scale := 0.3 if bus_name == "Steps" else 1.0
			reverb.room_size = move_toward(reverb.room_size, minf(wanted.room_size, 0.45) if bus_name == "Steps" else wanted.room_size, delta * 0.8)
			reverb.wet = move_toward(reverb.wet, wanted.wet * scale + extra, delta * 0.3)
			reverb.damping = move_toward(reverb.damping, wanted.damping, delta * 0.8)

static func loop_stream(source: AudioStream) -> AudioStream:
	var copy: AudioStream = source.duplicate()
	if copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
		copy.loop_begin = 0
		copy.loop_end = int(copy.get_length() * copy.mix_rate)
	elif copy is AudioStreamOggVorbis or copy is AudioStreamMP3: copy.loop = true
	return copy

func set_creature(next: Resource) -> void:
	presence.stop()
	profile = next
	presence_gain = 0
	if profile == null: return
	presence.stream = loop_stream(profile.presence)
	presence.max_distance = profile.audible_distance

func choose(pool: String) -> String:
	var options: Array = POOLS[pool].duplicate()
	if options.size() > 1: options.erase(last.get(pool, ""))
	var selected: String = options[rng.randi_range(0, options.size() - 1)]
	last[pool] = selected
	return BASE + selected

## The camera the local screen shows: the player's own, or while dead the
## teammate being watched.
func listener_camera() -> Camera3D:
	var current: Camera3D = level.get_viewport().get_camera_3d() if level.is_inside_tree() else null
	return current if current != null else level.player.camera

func listener_position() -> Vector3:
	return listener_camera().global_position

func door_cue(opening: bool, slow: bool, point: Vector3, emitter: RID, forceful := false) -> void:
	var distance := listener_position().distance_to(point)
	var pool := ("open" if opening else "close") + ("_slam" if forceful else "") + ("_far" if distance >= far_threshold else "_near")
	if opening and slow and distance < far_threshold: pool = "open_slow"
	var path := choose(pool)
	var gain: float = GAIN.open_slow if slow and opening else GAIN.slam if forceful else GAIN.open if opening else GAIN.close
	var start := TIMING.onset(path) if opening else maxf(TIMING.onset(path), TIMING.hit(path) - CLOSE_PREROLL)
	play_at(path, point, gain, emitter, start)
	last_event["pool"] = pool
	if enabled and distance < 16.0:
		var words := "[Un portazo]" if forceful else "[Una puerta cruje]" if opening else "[Una puerta se cierra]"
		show_caption(words, false)

func hide_cue(entering: bool, point: Vector3) -> void:
	var path := choose("hide_enter" if entering else "hide_leave")
	var start := maxf(TIMING.onset(path), TIMING.hit(path) - HIDE_PREROLL) if entering else TIMING.onset(path)
	play_at(path, point + Vector3.UP, GAIN.hide, RID(), start)

## start: seconds into the recording; negative uses its measured onset.
func play_at(path: String, point: Vector3, gain: float, emitter := RID(), start := -1.0) -> void:
	if start < 0.0: start = TIMING.onset(path)
	last_event = {"path": path, "position": point}
	if not enabled or listener_position().distance_to(point) > ROUTE_LIMIT: return
	var route := route_source(point, emitter)
	if not route.audible: return
	if not streams.has(path): streams[path] = load(path)
	if voices.size() >= maximum_voices:
		var oldest := voices.pop_front() as AudioStreamPlayer3D
		oldest.stop()
		oldest.queue_free()
	var voice := AudioStreamPlayer3D.new()
	voice.name = "WorldCue"
	voice.bus = "Effects"
	voice.stream = streams[path]
	voice.unit_size = 6.0
	voice.max_distance = 40.0
	voice.max_db = 6.0
	voice.area_mask = ACOUSTIC_MASK
	voice.pitch_scale = rng.randf_range(0.98, 1.02)
	voice.set_meta("base_gain", gain)
	voice.set_meta("emitter", emitter)
	voice.set_meta("start", start)
	add_child(voice)
	apply_route(voice, route, gain, "Effects")
	voices.append(voice)
	voice.finished.connect(func():
		voices.erase(voice)
		voice.queue_free()
	)
	voice.play(start)

## How a sound reaches the listener. With nothing solid in between it comes
## straight from the source. Otherwise it follows the walkable route and is
## heard from the last opening visible from the listener (a doorway or corner),
## quieter, duller and with an echo for the extra distance. Walls never let
## sound through.
func route_source(point: Vector3, emitter := RID()) -> Dictionary:
	var listener := listener_position()
	if not occluded(point, emitter):
		return {"audible": true, "position": point, "gain": 0.0, "cutoff": 20000.0, "echo": false, "distance": listener.distance_to(point)}
	var map: RID = level.get_world_3d().navigation_map
	var from := NavigationServer3D.map_get_closest_point(map, level.player.global_position)
	var to := NavigationServer3D.map_get_closest_point(map, point)
	var path := FLOOR.navigation_path(map, from, to)
	if path.size() < 2: return {"audible": false, "distance": INF}
	var length := 0.0
	for i in range(1, path.size()): length += path[i].distance_to(path[i - 1])
	if length > ROUTE_LIMIT: return {"audible": false, "distance": length}
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var opening := path[0] + Vector3.UP * 1.5
	for i in range(1, path.size()):
		var probe := path[i] + Vector3.UP * 1.5
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(listener, probe, 1)).is_empty(): break
		opening = probe
	var detour := maxf(0.0, length - listener.distance_to(opening))
	return {"audible": true, "position": opening, "gain": -3.0 - 20.0 * log(1.0 + detour / 5.0) / log(10.0), "cutoff": lerpf(5200.0, 900.0, clampf(detour / 25.0, 0.0, 1.0)), "echo": true, "distance": length}

## Places a 3D player where the route says, on the echo bus when it travelled,
## duller and a little quieter when it comes from behind.
## creature: on the binaural creature buses (mono into the mixer).
func apply_route(player: AudioStreamPlayer3D, route: Dictionary, gain: float, dry_bus: String, creature := false) -> void:
	player.global_position = route.position
	player.bus = ECHO_BUS[dry_bus] if route.echo else StringName(dry_bus)
	player.panning_strength = PANNING[dry_bus]
	if creature:
		player.bus = CREATURE_BUS[route.echo]
		player.panning_strength = 0.0
	var rear := behind(route.position)
	player.volume_db = gain + route.gain + REAR_GAIN * rear
	player.attenuation_filter_cutoff_hz = minf(route.cutoff, lerpf(20000.0, REAR_CUTOFF, rear))

## 0 in front of or beside the listener, 1 straight behind (smooth in between).
func behind(point: Vector3) -> float:
	if level == null or level.player == null: return 0.0
	var camera := listener_camera()
	var local: Vector3 = camera.global_basis.inverse() * (point - camera.global_position)
	local.y = 0.0
	if local.length_squared() < 0.01: return 0.0
	return smoothstep(0.0, 1.0, maxf(0.0, local.normalized().z))

func occluded(point: Vector3, emitter := RID()) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(point, listener_position(), 1 | 8 | 64)
	if emitter.is_valid(): ray.exclude = [emitter]
	return not level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func show_caption(words: String, is_presence: bool) -> void:
	if is_presence and caption_cooldown > 0: return
	caption_text = words
	caption_time = 2.5
	if is_presence: caption_cooldown = 18.0

func reset() -> void:
	for voice in voices:
		voice.stop()
		voice.queue_free()
	voices.clear()
	presence.stop()
	presence_gain = 0
	presence_route = {}
	for source in hums: source.stop()
	if aura != null: aura.reset()
	caption_time = 0
	caption_cooldown = 0
	caption_text = ""

func _physics_process(delta: float) -> void:
	if level == null: return
	caption_time = maxf(0, caption_time - delta)
	caption_cooldown = maxf(0, caption_cooldown - delta)
	if caption_time <= 0: caption_text = ""
	if not enabled: return
	ambient_clock -= delta
	if ambient_clock <= 0.0:
		ambient_clock = 0.5
		update_ambient_sources()
	update_hum_levels()
	update_space(delta)
	if not is_instance_valid(level.locust) or level.session.state != level.session.State.PLAYING: return
	var creature = level.locust
	var voice_point: Vector3 = creature.global_position + Vector3(0, 1.4, 0)
	route_clock -= delta
	if route_clock <= 0.0 or presence_route.is_empty():
		route_clock = 0.25
		presence_route = route_source(voice_point, creature.get_rid())
	# Heard straight, it sits on the creature; heard around corners, it drifts to the opening.
	var target: Vector3 = voice_point if not presence_route.get("echo", false) else presence_route.position
	update_ears(target, delta)
	if profile == null: return
	var distance: float = presence_route.get("distance", INF)
	var audible: bool = level.session.state == level.session.State.PLAYING and creature.grace <= 0 and not level.in_refuge() and presence_route.audible and distance < profile.audible_distance
	presence.global_position = target if not presence_route.get("echo", false) or presence.global_position.distance_to(target) > 8.0 else presence.global_position.lerp(target, minf(1.0, delta * 4.0))
	presence.bus = CREATURE_BUS[presence_route.get("echo", false)]
	if audible and not presence.playing: presence.play()
	presence_gain = move_toward(presence_gain, 1.0 if audible else 0.0, delta * 0.6)
	if presence_gain <= 0 and presence.playing: presence.stop()
	clock += delta
	if clock < 0.1: return
	clock = 0
	var rear := behind(presence.global_position)
	presence.volume_db = profile.volume_db + presence_route.get("gain", 0.0) + REAR_GAIN * rear + linear_to_db(maxf(presence_gain, 0.0001)) - (16.0 if creature.mode == creature.Mode.WINDUP else 0.0)
	presence.attenuation_filter_cutoff_hz = minf(presence_route.get("cutoff", 20000.0), lerpf(20000.0, REAR_CUTOFF, rear))
	if audible and presence_gain > 0.5 and distance < 12: show_caption(profile.caption, true)

## Points the creature buses' ears at where it is heard from: the side it is
## on arrives first and louder at that ear. Eased so a turn of the head never
## jumps the delay by more than a few samples at a time.
func update_ears(point: Vector3, delta: float) -> void:
	var camera := listener_camera()
	var local: Vector3 = camera.global_basis.inverse() * (point - camera.global_position)
	var side := 0.0
	if Vector2(local.x, local.z).length_squared() > 0.0001:
		side = sin(atan2(local.x, -local.z))
	ear_side = move_toward(ear_side, side, delta * 6.0)
	ear_itd = ear_side * ITD_MS
	var far_db := -EAR_SHADOW * pow(absf(ear_side), 0.7)
	var near_db := EAR_NEAR * absf(ear_side)
	var left := EAR_BASE_MS + maxf(ear_itd, 0.0)
	var right := EAR_BASE_MS + maxf(-ear_itd, 0.0)
	for bus_name in CREATURE_BUS.values():
		var bus := AudioServer.get_bus_index(bus_name)
		if bus < 0 or AudioServer.get_bus_effect_count(bus) == 0: continue
		var ears = AudioServer.get_bus_effect(bus, 0)
		if not ears is AudioEffectDelay: continue
		ears.tap1_delay_ms = left
		ears.tap2_delay_ms = right
		ears.tap1_level_db = far_db if ear_side > 0.0 else near_db
		ears.tap2_level_db = near_db if ear_side > 0.0 else far_db

## Moves the hum emitters to the closest fluorescent battens. A tube in another
## room is only heard through the opening, like any other sound.
func update_ambient_sources() -> void:
	if level.session.state != level.session.State.PLAYING or not is_instance_valid(level.hotel):
		for source in hums: source.stop()
		return
	var listener := listener_position()
	var nearest: Array = level.hotel.tubes.filter(func(entry): return is_instance_valid(entry.light) and entry.light.global_position.distance_to(listener) < HUM_REACH)
	nearest.sort_custom(func(a, b): return a.light.global_position.distance_to(listener) < b.light.global_position.distance_to(listener))
	for i in hums.size():
		var hum := hums[i]
		var route := route_source(nearest[i].light.global_position) if i < nearest.size() else {"audible": false}
		if route.audible:
			hum.set_meta("entry", nearest[i])
			hum.set_meta("route_gain", route.gain)
			hum.global_position = route.position
			hum.attenuation_filter_cutoff_hz = route.cutoff
			if not hum.playing: hum.play(rng.randf() * 1.5)
		else:
			hum.set_meta("entry", null)
			hum.stop()

## Hum follows the tube: it drops out with the light when it flickers.
func update_hum_levels() -> void:
	for hum in hums:
		var entry = hum.get_meta("entry") if hum.has_meta("entry") else null
		if entry == null or not hum.playing: continue
		var level_ratio: float = clampf(entry.light.light_energy / maxf(entry.energy, 0.01), 0.0, 1.0)
		hum.volume_db = HUM_DB + float(hum.get_meta("route_gain", 0.0)) + linear_to_db(maxf(level_ratio, 0.001))
