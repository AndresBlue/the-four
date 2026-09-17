extends SceneTree
## How clearly the creature's footfalls tell their direction, through the real
## mixer: left/right level on the Master bus and the share of high frequencies
## (duller from behind) for sources around a still listener. Real time.
var level
var capture: AudioEffectCapture
const DIRECTIONS := [["silence", Vector3(0, 0, -3.5)], ["left", Vector3(-3.5, 0, 0)], ["front-left", Vector3(-2.5, 0, -2.5)], ["front", Vector3(0, 0, -3.5)], ["right", Vector3(3.5, 0, 0)], ["back", Vector3(0, 0, 3.5)], ["back-left", Vector3(-2.5, 0, 2.5)]]

func _initialize() -> void: run.call_deferred()

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.player.set_physics_process(false)
	level.world_audio.enabled = true
	level.world_audio.profile = null
	for source in level.world_audio.hums: source.volume_db = -80
	# A bedroom-sized room with nothing in the middle.
	var FLOOR := preload("res://game/world/generation/floor_definition.gd")
	for room in level.manifest.rooms:
		if int(room.type) == 18 or int(room.type) == 5:
			level.player.global_position = FLOOR.position_of(room)
			break
	level.player.rotation.y = 0.0
	level.player.camera.rotation = Vector3.ZERO
	for i in 10: await process_frame
	capture = AudioEffectCapture.new()
	capture.buffer_length = 3.0
	AudioServer.add_bus_effect(0, capture)
	var ear: Vector3 = level.player.camera.global_position
	await measure(ear)
	# Again without the room reverb on the creature's bus: how much of the
	# opposite channel is the room.
	var bus := AudioServer.get_bus_index("Threat")
	for index in AudioServer.get_bus_effect_count(bus): AudioServer.set_bus_effect_enabled(bus, index, false)
	print("-- without reverb")
	await measure(ear)
	for index in AudioServer.get_bus_effect_count(bus): AudioServer.set_bus_effect_enabled(bus, index, true)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	level.queue_free()
	await process_frame
	quit()

func measure(ear: Vector3) -> void:
	for entry in DIRECTIONS:
		# The creature stands where its steps land (the ears follow it).
		level.locust.global_position = Vector3(ear.x, 0.04, ear.z) + entry[1]
		await create_timer(0.6).timeout
		capture.clear_buffer()
		var left := 0.0
		var right := 0.0
		var high := 0.0
		var total := 0.0
		var previous := Vector2.ZERO
		var lags := {}
		for step in 6:
			if entry[0] != "silence": level.locust.on_footfall(Vector3(ear.x, 0.6, ear.z) + entry[1], 0.8)
			await create_timer(0.35).timeout
			var frames := capture.get_buffer(capture.get_frames_available())
			# Interaural delay: the lag (samples) that best lines the right ear up with the left.
			var best := 0
			var best_score := -INF
			var count := mini(frames.size(), 9000)
			for lag in range(-40, 41):
				var score := 0.0
				for i in range(40, count - 40): score += frames[i].x * frames[i + lag].y
				if score > best_score:
					best_score = score
					best = lag
			lags[best] = lags.get(best, 0) + 1
			for frame in frames:
				left += frame.x * frame.x
				right += frame.y * frame.y
				var change: Vector2 = frame - previous
				high += change.length_squared()
				total += frame.length_squared()
				previous = frame
		print("%-11s L %6.1f  R %6.1f  L-R %5.1f dB  high %4.1f %%  lag %s  routed %s" % [entry[0], 10 * log(left + 1e-12) / log(10), 10 * log(right + 1e-12) / log(10), 10 * log((left + 1e-12) / (right + 1e-12)) / log(10), 100.0 * high / maxf(total, 1e-12), lags, level.world_audio.route_source(Vector3(ear.x, 0.6, ear.z) + entry[1] + Vector3.UP * 0.2, level.locust.get_rid()).echo])
