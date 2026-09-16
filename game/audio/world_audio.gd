extends Node
## Local presentation only: never changes AI hearing or consumes map RNG.
const BASE := "res://assets/audio/sfx/"
const POOLS := {
	"open_near": ["door/opening/opening1.ogg", "door/opening/opening2.ogg", "door/opening/opening3.ogg", "door/opening/wooden-opening.ogg"],
	"open_far": ["door/opening/far-opening.ogg", "door/opening/far-soft-opening.ogg"],
	"open_slow": ["door/opening/creaky-wooden-door-slow-opening.mp3"],
	"close_near": ["door/closing/closing1.ogg", "door/closing/closing2.ogg", "door/closing/closing3.ogg", "door/closing/wooden-closing.ogg"],
	"close_far": ["door/closing/far-closing.ogg", "door/closing/far-soft-closing.ogg"],
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	presence = AudioStreamPlayer3D.new()
	presence.name = "CreaturePresence"
	presence.bus = "Threat"
	presence.unit_size = 7.0
	presence.max_db = -6.0
	presence.volume_db = -80.0
	add_child(presence)

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

func listener_position() -> Vector3:
	return level.player.camera.global_position

func door_cue(opening: bool, slow: bool, point: Vector3, emitter: RID) -> void:
	var distance := listener_position().distance_to(point)
	var pool := ("open" if opening else "close") + ("_far" if distance >= far_threshold else "_near")
	if opening and slow and distance < far_threshold: pool = "open_slow"
	play_at(choose(pool), point, -16.0 if slow else -10.0, emitter)
	last_event["pool"] = pool
	if enabled and distance < 16.0: show_caption("[Una puerta cruje]" if opening else "[Una puerta se cierra]", false)

func hide_cue(entering: bool, point: Vector3) -> void:
	play_at(choose("hide_enter" if entering else "hide_leave"), point + Vector3.UP, -16.0)

func play_at(path: String, point: Vector3, gain: float, emitter := RID()) -> void:
	last_event = {"path": path, "position": point}
	if not enabled or listener_position().distance_to(point) > 32.0: return
	if not streams.has(path): streams[path] = load(path)
	if voices.size() >= maximum_voices:
		var oldest := voices.pop_front() as AudioStreamPlayer3D
		oldest.stop()
		oldest.queue_free()
	var voice := AudioStreamPlayer3D.new()
	voice.name = "WorldCue"
	voice.bus = "Effects"
	voice.stream = streams[path]
	voice.unit_size = 5.0
	voice.max_distance = 32.0
	voice.max_db = -4.0
	voice.pitch_scale = rng.randf_range(0.98, 1.02)
	voice.set_meta("base_gain", gain)
	voice.set_meta("emitter", emitter)
	add_child(voice)
	voice.global_position = point
	voices.append(voice)
	update_voice(voice)
	voice.finished.connect(func():
		voices.erase(voice)
		voice.queue_free()
	)
	voice.play()

func occluded(point: Vector3, emitter := RID()) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(point, listener_position(), 1 | 8 | 64)
	if emitter.is_valid(): ray.exclude = [emitter]
	return not level.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func update_voice(voice: AudioStreamPlayer3D) -> void:
	var blocked := occluded(voice.global_position, voice.get_meta("emitter", RID()))
	voice.volume_db = float(voice.get_meta("base_gain")) - (7.0 if blocked else 0.0)
	voice.attenuation_filter_cutoff_hz = 2000.0 if blocked else 5000.0

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
	caption_time = 0
	caption_cooldown = 0
	caption_text = ""

func _physics_process(delta: float) -> void:
	if level == null: return
	caption_time = maxf(0, caption_time - delta)
	caption_cooldown = maxf(0, caption_cooldown - delta)
	if caption_time <= 0: caption_text = ""
	if not enabled or profile == null or not is_instance_valid(level.locust): return
	var creature = level.locust
	presence.global_position = creature.global_position + Vector3(0, 1.4, 0)
	var distance := presence.global_position.distance_to(listener_position())
	var audible: bool = level.session.state == level.session.State.PLAYING and creature.grace <= 0 and not level.in_refuge() and distance < profile.audible_distance
	if audible and not presence.playing: presence.play()
	presence_gain = move_toward(presence_gain, 1.0 if audible else 0.0, delta * 0.6)
	if presence_gain <= 0 and presence.playing: presence.stop()
	clock += delta
	if clock < 0.1: return
	clock = 0
	var blocked := occluded(presence.global_position)
	presence.volume_db = profile.volume_db + linear_to_db(maxf(presence_gain, 0.0001)) - (8.0 if blocked else 0.0) - (16.0 if creature.mode == creature.Mode.WINDUP else 0.0)
	presence.attenuation_filter_cutoff_hz = 1800.0 if blocked else 5000.0
	if audible and presence_gain > 0.5 and distance < 18: show_caption(profile.caption, true)
	for voice in voices: update_voice(voice)
