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
## Margin over ROUTE_LIMIT before a route is not even searched: covers the
## height of the ears and of the source above the walkable floor.
const ROUTE_SLACK := 10.0
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
## Air absorption: distance does not only make a sound quieter, it eats its top
## end. Without this the only thing telling ten metres from forty was volume,
## so a cry across the floor read like a cry in the room. Metres of route at
## which the effect is complete, the level it takes off there, and the top end
## that survives it.
const AIR_REACH := 45.0
const AIR_GAIN := -6.0
const AIR_CUTOFF := 2000.0
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
## Where a creature that is not there is walking (sanity's phantom_passage):
## the presence and the aura take it whenever it is nearer than the real one.
## INF when nobody is imagining one. This machine's only.
var phantom_point := Vector3.INF
var presence_phantom := false
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
## A lit set hisses, softly, once the burst of static it came on with has died
## down: the nearest few of them, placed like the hums.
const TV_HISS := "res://assets/audio/intro/tv_static.wav"
const TV_HISS_DB := -27.0
const TV_HISS_UNIT := 3.0
const TV_HISS_REACH := 11.0
## How long the hiss takes to come up under the end of the burst.
const TV_HISS_RISE := 1.5
var tv_hiss: Array[AudioStreamPlayer3D] = []
## Long sounds -- a set coming to life, the power going, a warp -- get players
## of their own, outside `voices`: at fourteen seconds they were the oldest in
## that pool by far, and the next doors cut them off mid-hiss. Each is routed
## again as the listener moves, like the hums, and goes quiet (not off) while
## the route does not reach. {player, point, gain, emitter, path, started,
## follow, base_db, audible, length}
var long_cues: Array = []
const LONG_REROUTE := 0.25
## A cue given a length fades out over this much at its end.
const LONG_FADE := 0.4
var long_clock := 0.0
## While set, nothing new is heard: a player coming back into a running floor
## is told what already happened (wardrobes taken, sets lit), and hearing all
## of it at once was a burst of doors from nowhere.
var hush := false

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
	for i in 2:
		var hiss := make_source("TelevisionHiss", "Ambience", loop_stream(load(TV_HISS)), TV_HISS_UNIT, TV_HISS_REACH)
		hiss.max_db = TV_HISS_DB + 3.0
		tv_hiss.append(hiss)

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
## A sound the whole floor hears: somebody being killed. It has no reach. Near,
## it is placed like any other sound; past where a sound would carry, or with
## no way for it to get here, it still arrives -- from the direction it happened
## in, through the echo of the building, quieter the further off it is, but
## never under EVERYWHERE_FLOOR below its own level. Nobody on the floor misses
## that it happened, only how far away.
const EVERYWHERE_FLOOR := -24.0
const EVERYWHERE_UNIT := 8.0
func play_everywhere(path: String, point: Vector3, gain: float, start := -1.0) -> void:
	if start < 0.0: start = TIMING.onset(path)
	last_event = {"path": path, "position": point, "everywhere": true}
	if not enabled: return
	var straight := listener_position().distance_to(point)
	var route: Dictionary = route_source(point) if straight <= ROUTE_LIMIT + ROUTE_SLACK else {"audible": false}
	var far: bool = not route.audible
	var distance: float = straight * 1.4 if far else float(route.get("distance", straight))
	if not streams.has(path): streams[path] = load(path)
	var voice := AudioStreamPlayer3D.new()
	voice.name = "EverywhereCue"
	voice.stream = streams[path]
	# Its own fall-off, with a floor, instead of the player's, which ends.
	voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	voice.max_distance = 0.0
	voice.area_mask = ACOUSTIC_MASK
	add_child(voice)
	voice.global_position = point if far else route.position
	voice.bus = ECHO_BUS["Effects"] if far or route.echo else &"Effects"
	voice.panning_strength = PANNING["Effects"]
	var fall := -20.0 * log(1.0 + distance / EVERYWHERE_UNIT) / log(10.0)
	voice.volume_db = gain + maxf(fall + (-6.0 if far else float(route.gain)), EVERYWHERE_FLOOR)
	voice.finished.connect(voice.queue_free)
	# Not in `voices`, which are recycled, but gone with them on a reset: a
	# death heard as the floor ended used to finish over the next one.
	voice.add_to_group("everywhere_cues")
	voice.play(start)

## A long sound on a player of its own (see long_cues). follow: `point` is an
## offset from the listener instead of a place, for what is heard from above
## wherever you are (the power going). length: seconds before it fades out, 0
## for the whole recording. Returns the player, or null when nothing plays.
func play_long(path: String, point: Vector3, gain: float, emitter := RID(), follow := false, length := 0.0) -> AudioStreamPlayer3D:
	last_event = {"path": path, "position": point, "long": true}
	if not enabled or hush: return null
	if not streams.has(path): streams[path] = load(path)
	var voice := AudioStreamPlayer3D.new()
	voice.name = "LongCue"
	voice.stream = streams[path]
	voice.unit_size = 6.0
	voice.max_distance = 40.0
	voice.max_db = 6.0
	voice.area_mask = ACOUSTIC_MASK
	add_child(voice)
	var cue := {"player": voice, "point": point, "gain": gain, "emitter": emitter, "path": path, "started": Time.get_ticks_msec() / 1000.0, "follow": follow, "base_db": -80.0, "audible": false, "length": length}
	long_cues.append(cue)
	route_long(cue)
	voice.volume_db = float(cue.base_db)
	voice.finished.connect(func(): stop_long(voice))
	voice.play(TIMING.onset(path))
	return voice

## Stops a long cue early (a set switched off again). Untyped: whoever kept
## the player may hand it over after it played out and freed itself, and a
## typed argument refuses a freed one with a script error.
func stop_long(voice) -> void:
	if not is_instance_valid(voice): return
	for cue in long_cues.duplicate():
		if cue.player != voice: continue
		long_cues.erase(cue)
		if is_instance_valid(voice):
			voice.stop()
			voice.queue_free()

## Whether a long cue of this recording started within `within` seconds and
## reaches this listener: the same dead channel is not played twice over.
func long_playing(path: String, within: float) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	for cue in long_cues:
		if cue.path == path and bool(cue.audible) and now - float(cue.started) <= within and is_instance_valid(cue.player) and cue.player.playing: return true
	return false

func route_long(cue: Dictionary) -> void:
	var voice: AudioStreamPlayer3D = cue.player
	if not is_instance_valid(voice): return
	if cue.follow:
		voice.global_position = listener_position() + cue.point
		voice.bus = &"Effects"
		voice.panning_strength = PANNING["Effects"]
		voice.attenuation_filter_cutoff_hz = 20000.0
		cue.base_db = float(cue.gain)
		cue.audible = true
		return
	var point: Vector3 = cue.point
	var route: Dictionary = route_source(point, cue.emitter) if listener_position().distance_to(point) <= ROUTE_LIMIT else {"audible": false}
	cue.audible = route.audible
	if not route.audible:
		cue.base_db = -80.0
		return
	apply_route(voice, route, float(cue.gain), "Effects")
	cue.base_db = voice.volume_db

## Every frame: the level (with the fade of a cue given a length); every
## LONG_REROUTE seconds: where it is heard from.
func update_long(delta: float) -> void:
	if long_cues.is_empty(): return
	long_clock -= delta
	var reroute := long_clock <= 0.0
	if reroute: long_clock = LONG_REROUTE
	var now := Time.get_ticks_msec() / 1000.0
	for cue in long_cues.duplicate():
		var voice: AudioStreamPlayer3D = cue.player
		if not is_instance_valid(voice):
			long_cues.erase(cue)
			continue
		if reroute or cue.follow: route_long(cue)
		var fade := 0.0
		if float(cue.length) > 0.0:
			var left := float(cue.length) - (now - float(cue.started))
			if left <= 0.0:
				stop_long(voice)
				continue
			fade = linear_to_db(clampf(left / LONG_FADE, 0.001, 1.0))
		voice.volume_db = float(cue.base_db) + fade

func play_at(path: String, point: Vector3, gain: float, emitter := RID(), start := -1.0) -> void:
	if start < 0.0: start = TIMING.onset(path)
	last_event = {"path": path, "position": point}
	if not enabled or hush or listener_position().distance_to(point) > ROUTE_LIMIT: return
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
## What a shut door between takes off a sound: this much quieter, and nothing
## above this much of its top end gets through the wood.
const SHUT_DOOR_LOSS := 8.0
const SHUT_DOOR_CUTOFF := 1500.0
func route_source(point: Vector3, emitter := RID()) -> Dictionary:
	var listener := listener_position()
	if not occluded(point, emitter):
		return {"audible": true, "position": point, "gain": 0.0, "cutoff": 20000.0, "echo": false, "distance": listener.distance_to(point)}
	# A walked route is never shorter than the straight line less the gap from
	# each end down to the walkable floor (a few metres at most), so past this
	# the search below could only end in "too far", after crossing the floor.
	var straight := listener.distance_to(point)
	if straight > ROUTE_LIMIT + ROUTE_SLACK: return {"audible": false, "distance": straight}
	var map: RID = level.get_world_3d().navigation_map
	# Each end on its own planta: a sound from the floor above or below has no
	# way here but the slab, and the slab lets nothing through.
	if FLOOR.planta_of(listener.y) != FLOOR.planta_of(point.y): return {"audible": false, "distance": INF}
	var from := FLOOR.closest(map, listener_position())
	var to := FLOOR.closest(map, point)
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
	# The route walks through doorways whether their doors are open or not
	# (the navigation ignores them): a shut door on the way was heard almost
	# as if it stood open. Each one it has to come through takes its share.
	var shut := {}
	for i in range(1, path.size()):
		var through := PhysicsRayQueryParameters3D.create(path[i - 1] + Vector3.UP * 1.2, path[i] + Vector3.UP * 1.2, 8)
		# Not the door making the sound: a door heard shutting is not behind itself.
		if emitter.is_valid(): through.exclude = [emitter]
		var hit := space.intersect_ray(through)
		if not hit.is_empty(): shut[hit.collider] = true
	var gain := -3.0 - 20.0 * log(1.0 + detour / 5.0) / log(10.0) - SHUT_DOOR_LOSS * shut.size()
	var cutoff := lerpf(5200.0, 900.0, clampf(detour / 25.0, 0.0, 1.0))
	if not shut.is_empty(): cutoff = minf(cutoff, SHUT_DOOR_CUTOFF)
	return {"audible": true, "position": opening, "gain": gain, "cutoff": cutoff, "echo": true, "distance": length}

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
	var far := clampf(float(route.get("distance", 0.0)) / AIR_REACH, 0.0, 1.0)
	player.volume_db = gain + route.gain + REAR_GAIN * rear + AIR_GAIN * far
	# The square root front-loads it: the first metres already dull a sound,
	# which is what tells a room away from a floor away.
	player.attenuation_filter_cutoff_hz = minf(minf(route.cutoff, lerpf(20000.0, REAR_CUTOFF, rear)), lerpf(20000.0, AIR_CUTOFF, sqrt(far)))

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
	for cue in get_tree().get_nodes_in_group("everywhere_cues"):
		if is_ancestor_of(cue): cue.queue_free()
	for cue in long_cues.duplicate(): stop_long(cue.player)
	long_cues.clear()
	hush = false
	presence.stop()
	presence_gain = 0
	presence_route = {}
	for source in hums: source.stop()
	for source in tv_hiss: source.stop()
	if aura != null: aura.reset()
	caption_time = 0
	caption_cooldown = 0
	caption_text = ""

## A grunt aimed at this listener takes the scene: everything else the
## creature brings with it -- the aura, its feet -- and the hotel's own bed
## and music step back for as long as it lasts, fast in and slower out, so
## the voice is what is heard and not one more layer of the din.
const DUCK_DEPTH := 9.0
const DUCK_ATTACK := 0.08
const DUCK_RELEASE := 0.6
var duck := 0.0
var duck_hold := 0.0

func duck_under(seconds: float) -> void:
	duck_hold = maxf(duck_hold, seconds)

## What the ducked sounds lose right now, in dB (<= 0).
func duck_db() -> float:
	return -DUCK_DEPTH * duck

func _physics_process(delta: float) -> void:
	if level == null: return
	duck_hold = maxf(0.0, duck_hold - delta)
	duck = move_toward(duck, 1.0 if duck_hold > 0.0 else 0.0, delta / (DUCK_ATTACK if duck_hold > 0.0 else DUCK_RELEASE))
	caption_time = maxf(0, caption_time - delta)
	caption_cooldown = maxf(0, caption_cooldown - delta)
	if caption_time <= 0: caption_text = ""
	if not enabled: return
	update_long(delta)
	ambient_clock -= delta
	if ambient_clock <= 0.0:
		ambient_clock = 0.5
		update_tv_hiss()
		update_ambient_sources()
	update_hum_levels()
	update_hiss_levels()
	update_space(delta)
	if not is_instance_valid(level.locust) or level.session.state != level.session.State.PLAYING: return
	var creature = level.locust
	var voice_point: Vector3 = creature.global_position + Vector3(0, 1.4, 0)
	# A creature imagined nearer than the real one is the one heard.
	var listener := listener_position()
	presence_phantom = phantom_point != Vector3.INF and (creature.grace > 0.0 or phantom_point.distance_to(listener) < creature.global_position.distance_to(listener))
	if presence_phantom: voice_point = phantom_point + Vector3(0, 1.4, 0)
	route_clock -= delta
	if route_clock <= 0.0 or presence_route.is_empty():
		route_clock = 0.25
		presence_route = route_source(voice_point, RID() if presence_phantom else creature.get_rid())
	# Heard straight, it sits on the creature; heard around corners, it drifts to the opening.
	var target: Vector3 = voice_point if not presence_route.get("echo", false) else presence_route.position
	update_ears(target, delta)
	if profile == null: return
	var distance: float = presence_route.get("distance", INF)
	var audible: bool = level.session.state == level.session.State.PLAYING and (creature.grace <= 0 or presence_phantom) and not level.in_refuge() and presence_route.audible and distance < profile.audible_distance
	presence.global_position = target if not presence_route.get("echo", false) or presence.global_position.distance_to(target) > 8.0 else presence.global_position.lerp(target, minf(1.0, delta * 4.0))
	presence.bus = CREATURE_BUS[presence_route.get("echo", false)]
	if audible and not presence.playing: presence.play()
	presence_gain = move_toward(presence_gain, 1.0 if audible else 0.0, delta * 0.6)
	if presence_gain <= 0 and presence.playing: presence.stop()
	clock += delta
	if clock < 0.1: return
	clock = 0
	var rear := behind(presence.global_position)
	presence.volume_db = profile.volume_db + presence_route.get("gain", 0.0) + REAR_GAIN * rear + linear_to_db(maxf(presence_gain, 0.0001)) - (16.0 if creature.mode == creature.Mode.WINDUP and not presence_phantom else 0.0)
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
	# With the power gone nothing hums: the tubes are hidden, not dimmed, so
	# their energy alone kept the hum on through the blackout.
	if level.session.state != level.session.State.PLAYING or not is_instance_valid(level.hotel) or level.hotel.dark:
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

## The hiss of the lit sets nearest the listener, once each one's burst of
## static is over (hotel_television.hiss_after). The sets stay lit through the
## blackout, so unlike the hums this does not stop with the power.
func update_tv_hiss() -> void:
	var lit: Array = []
	var sets = level.get("televisions") if level != null else null
	if sets != null and level.session.state == level.session.State.PLAYING:
		var listener := listener_position()
		var now := Time.get_ticks_msec() / 1000.0
		for set in sets:
			if not is_instance_valid(set) or not set.on or now < float(set.hiss_after): continue
			var point: Vector3 = set.screen_point()
			if point.distance_to(listener) < TV_HISS_REACH: lit.append({"point": point, "since": float(set.hiss_after)})
		lit.sort_custom(func(a, b): return a.point.distance_to(listener) < b.point.distance_to(listener))
	for i in tv_hiss.size():
		var hiss := tv_hiss[i]
		var route: Dictionary = route_source(lit[i].point) if i < lit.size() else {"audible": false}
		if route.audible:
			hiss.set_meta("route_gain", route.gain)
			hiss.set_meta("since", lit[i].since)
			hiss.global_position = route.position
			hiss.attenuation_filter_cutoff_hz = route.cutoff
			if not hiss.playing:
				hiss.volume_db = -80.0
				hiss.play(rng.randf() * 2.0)
		else: hiss.stop()

## The hiss comes up under the tail of the burst instead of starting on a cut.
func update_hiss_levels() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for hiss in tv_hiss:
		if not hiss.playing: continue
		var rise := clampf((now - float(hiss.get_meta("since", 0.0))) / TV_HISS_RISE, 0.001, 1.0)
		hiss.volume_db = TV_HISS_DB + float(hiss.get_meta("route_gain", 0.0)) + linear_to_db(rise)

## Hum follows the tube: it drops out with the light when it flickers.
func update_hum_levels() -> void:
	for hum in hums:
		var entry = hum.get_meta("entry") if hum.has_meta("entry") else null
		if entry == null or not hum.playing: continue
		var level_ratio: float = clampf(entry.light.light_energy / maxf(entry.energy, 0.01), 0.0, 1.0)
		hum.volume_db = HUM_DB + float(hum.get_meta("route_gain", 0.0)) + linear_to_db(maxf(level_ratio, 0.001))
