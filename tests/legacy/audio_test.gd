extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var level: Node3D = load("res://legacy/fuse_prototype/main.tscn").instantiate()
	root.add_child(level)
	level.begin_run()
	await process_frame
	var music = level.get_node("Music")
	var bus_index := AudioServer.get_bus_index("Music")
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 5.0
	AudioServer.add_bus_effect(bus_index, capture)
	music.volume_db = -22.0
	music.stream_paused = false
	music.play(30.0)
	await create_timer(1.5).timeout
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for frame in samples:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	var decoded := samples.size() > 0 and peak > 0.0001
	print("PASS " if decoded else "FAIL ", "Mezcla MP3 real: frames=", samples.size(), " peak=", peak)
	music.seek(music.stream.get_length() - 0.5)
	await create_timer(1.5).timeout
	var looped: bool = music.playing and music.get_playback_position() < 3.0
	print("PASS " if looped else "FAIL ", "Bucle al terminar pista: posición=", music.get_playback_position())
	var file := FileAccess.open("res://evidence/audio_test.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"decoded_samples": samples.size(), "peak": peak, "decoded": decoded, "looped": looped}, "\t"))
	file.close()
	AudioServer.remove_bus_effect(bus_index, 0)
	level.queue_free()
	await process_frame
	await process_frame
	quit(0 if decoded and looped else 1)
