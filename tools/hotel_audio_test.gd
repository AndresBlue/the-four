extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var level = load("res://scenes/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	# The previous run deliberately mutes this test profile; establish prerequisites.
	level.settings.set_value("master", 0.8)
	level.settings.set_value("ambience", 0.65)
	level.ambience.play()
	level.theme.play()
	var index := AudioServer.get_bus_index("Ambience")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 3
	AudioServer.add_bus_effect(index, capture)
	await create_timer(1.0).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample in frames: peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	var audible := frames.size() > 0 and peak > 0.00001
	var loop_start: float = level.ambience.stream.get_length() - 0.25
	level.ambience.seek(loop_start)
	await create_timer(0.8).timeout
	var looped: bool = level.ambience.playing and level.ambience.get_playback_position() < 2
	level.settings.set_value("ambience", 0)
	var muted := AudioServer.is_bus_mute(index)
	var catalog := []
	for path in ["res://ambience.wav", "res://deep_atmosphere_short.wav", "res://piercing-glitchy-voice-sfx.wav", "res://726475__ultraameise__liminal-beep.mp3"]:
		if not ResourceLoader.exists(path): continue
		var stream = load(path)
		catalog.append({"file": path, "seconds": stream.get_length()})
	var report := FileAccess.open("res://evidence/hotel_audio.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": audible and looped and muted, "decoded": audible, "looped": looped, "muted": muted, "peak": peak, "samples": frames.size(), "catalog": catalog}, "\t"))
	report.close()
	print("HOTEL_AUDIO ", audible, " loop=", looped, " mute=", muted)
	AudioServer.remove_bus_effect(index, 0)
	capture = null
	level.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if audible and looped and muted else 1)
