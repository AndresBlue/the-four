extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
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
	# Volume curve: 50% is the reference mix, 100% adds +6 dB behind a limiter.
	var effects_bus := AudioServer.get_bus_index("Effects")
	level.settings.set_value("effects", 0.5)
	var reference_db := AudioServer.get_bus_volume_db(effects_bus)
	level.settings.set_value("effects", 1.0)
	var extreme_db := AudioServer.get_bus_volume_db(effects_bus)
	var curve := absf(reference_db) < 0.05 and absf(extreme_db - 6.02) < 0.05 and AudioServer.get_bus_effect(0, 0) is AudioEffectHardLimiter
	var threat_bus := AudioServer.get_bus_index("Threat")
	var threat_capture := AudioEffectCapture.new()
	threat_capture.buffer_length = 1
	AudioServer.add_bus_effect(threat_bus, threat_capture)
	level.settings.set_value("music", 0)
	level.settings.set_value("effects", 0)
	level.settings.set_value("threat", 0.85)
	level.locust.position = level.player.position + Vector3(0, 0, -3)
	level.locust.set_mode(level.locust.Mode.WINDUP)
	await create_timer(0.5).timeout
	var threat_frames := threat_capture.get_buffer(threat_capture.get_frames_available())
	var threat_peak := 0.0
	for sample in threat_frames: threat_peak = maxf(threat_peak, maxf(absf(sample.x), absf(sample.y)))
	var warning_audible := threat_peak > 0.00001
	level.settings.set_value("music", 0.25)
	level.settings.set_value("effects", 0.8)
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://docs/hotel_audio_inventory.json"))
	var report := FileAccess.open("res://evidence/hotel_audio.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": audible and looped and muted and warning_audible and curve, "volume_curve": curve, "reference_db": reference_db, "extreme_db": extreme_db, "decoded": audible, "looped": looped, "muted": muted, "warning_without_music_or_effects": warning_audible, "threat_peak": threat_peak, "peak": peak, "samples": frames.size(), "catalog": catalog}, "\t"))
	report.close()
	print("HOTEL_AUDIO ", audible, " loop=", looped, " mute=", muted, " independent_warning=", warning_audible, " curve=", curve)
	AudioServer.remove_bus_effect(threat_bus, 0)
	threat_capture = null
	AudioServer.remove_bus_effect(index, 0)
	capture = null
	level.queue_free()
	await process_frame
	await create_timer(0.15).timeout
	quit(0 if audible and looped and muted and warning_audible and curve else 1)
