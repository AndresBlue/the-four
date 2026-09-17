extends SceneTree
## Loudness calibration: renders typical moments through the real mixer and
## reports RMS and peak on the Master bus in dBFS. Real time; run headless.
## Usage after "--": --label=name [--volumes=0.5] (all sliders at that value)
var level
var capture: AudioEffectCapture
var results := {}
var label := "mix"

func _initialize() -> void: run.call_deferred()

func db(value: float) -> float:
	return linear_to_db(maxf(value, 0.000001))

func measure(title: String, seconds: float) -> void:
	capture.clear_buffer()
	await create_timer(seconds).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var sum := 0.0
	var peak := 0.0
	var left := 0.0
	var right := 0.0
	for frame in frames:
		sum += frame.length_squared() * 0.5
		left += frame.x * frame.x
		right += frame.y * frame.y
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	var rms := sqrt(sum / maxi(1, frames.size()))
	results[title] = {"rms_db": snappedf(db(rms), 0.1), "peak_db": snappedf(db(peak), 0.1), "balance_lr": snappedf(db(sqrt(left / maxf(right, 1e-12))), 0.1)}
	print("%-34s RMS %6.1f dBFS   peak %6.1f dBFS   L/R %5.1f dB" % [title, db(rms), db(peak), results[title].balance_lr])

func run() -> void:
	var volume := -1.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		if argument.begins_with("--volumes="): volume = float(argument.trim_prefix("--volumes="))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	if volume >= 0.0:
		for key in ["master", "ambience", "music", "effects", "threat"]: level.settings.set_value(key, volume)
	var audio = level.world_audio
	audio.enabled = true
	# Diagnostics: isolate stages of the chain.
	if OS.get_cmdline_user_args().has("--no-limiter"): AudioServer.set_bus_effect_enabled(0, 0, false)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 4.0
	AudioServer.add_bus_effect(0, capture)
	level.ambience.play()
	level.theme.play()
	level.ventilation.play()
	await create_timer(0.5).timeout
	await measure("bed: ambience+music+ventilation", 3.0)
	var listener: Vector3 = audio.listener_position()
	level.player.footstep.volume_db = -19
	level.player.footstep.play()
	await measure("player footstep (walk)", 0.4)
	audio.door_cue(true, false, listener + Vector3(1.5, 0, -2), RID())
	await measure("door open, 2.5 m", 1.2)
	audio.door_cue(false, false, listener + Vector3(1.5, 0, -2), RID())
	await measure("door close, 2.5 m", 1.0)
	audio.door_cue(true, false, listener + Vector3(1.5, 0, -2), RID(), true)
	await measure("door slam, 2.5 m", 1.0)
	audio.door_cue(true, false, listener + Vector3(0, 0, -20), RID())
	await measure("door open, 20 m", 1.2)
	level.ambience.stop()
	level.theme.stop()
	level.ventilation.stop()
	for i in AudioServer.bus_count: print("BUS ", i, " ", AudioServer.get_bus_name(i), " -> ", AudioServer.get_bus_send(i), " fx=", AudioServer.get_bus_effect_count(i), " vol=", AudioServer.get_bus_volume_db(i))
	# Creature cues without the bed. The listener faces -Z, so +X is to its right.
	level.locust.grace = 0
	var map: RID = level.get_world_3d().navigation_map
	for distance in [34.0, 20.0, 10.0, 4.0]:
		level.locust.global_position = NavigationServer3D.map_get_closest_point(map, level.player.global_position + Vector3(distance, 0, 0))
		await create_timer(4.0).timeout
		print("  aura intensity=%.2f route=%.1f m" % [audio.aura.intensity, audio.aura.route_distance])
		await measure("locust + aura at %d m (right)" % int(distance), 2.0)
	level.locust.on_footfall(level.player.position + Vector3(4, 0, 0), 1.0)
	await measure("locust footfall 4 m", 0.4)
	level.locust.set_mode(level.locust.Mode.WINDUP)
	await measure("attack warning", 0.7)
	var file := FileAccess.open("res://evidence/audio_mix_%s.json" % label, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	file.close()
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	level.queue_free()
	await process_frame
	quit()
