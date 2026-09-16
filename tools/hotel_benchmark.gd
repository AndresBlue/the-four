extends SceneTree
const FLOOR := preload("res://scripts/hotel/floor_definition.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var level = load("res://scenes/hotel.tscn").instantiate()
	root.add_child(level)
	var load_start := Time.get_ticks_msec()
	await level.start_floor(81)
	var load_ms := Time.get_ticks_msec() - load_start
	var peak_memory := 0.0
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var results: Array = []
	for quality in [0, 1, 2]:
		level.settings.values.quality = quality
		level.apply_settings()
		var samples: Array[float] = []
		for id in [0, 36, int(level.manifest.exit)]:
			var room: Dictionary = level.manifest.rooms[id]
			level.player.position = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
			level.player.rotation.y = 0.65
			level.player.camera.rotation.x = -0.1
			level.hotel.update_visibility(level.player.position, true)
			for frame in 35: await process_frame
			for frame in 60:
				var started := Time.get_ticks_usec()
				await RenderingServer.frame_post_draw
				await process_frame
				samples.append((Time.get_ticks_usec() - started) / 1000.0)
				peak_memory = maxf(peak_memory, Performance.get_monitor(Performance.MEMORY_STATIC))
			if id == 36:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://evidence/hotel_quality_%d.png" % quality)
		samples.sort()
		var average := 0.0
		for sample in samples: average += sample
		average /= samples.size()
		results.append({"quality": quality, "mean_frame_ms": average, "p95_frame_ms": samples[int(samples.size() * 0.95)], "sample_count": samples.size()})
	var report := FileAccess.open("res://evidence/hotel_benchmark_%s.json" % RenderingServer.get_current_rendering_method(), FileAccess.WRITE)
	report.store_string(JSON.stringify({"renderer": RenderingServer.get_current_rendering_method(), "viewport": str(root.size), "rooms": level.manifest.rooms.size(), "results": results, "floor_load_ms": load_ms, "peak_static_memory_bytes": peak_memory, "node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT)}, "\t"))
	report.close()
	print("BENCHMARK ", results)
	paused = false
	level.queue_free()
	await process_frame
	quit()
