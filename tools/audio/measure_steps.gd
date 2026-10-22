extends SceneTree
## Player footstep level through the real mixer (sliders at 50%), in a
## bedroom-sized module and in a merged hall, walking and running. Master dBFS.
var level
var capture: AudioEffectCapture

func _initialize() -> void: run.call_deferred()

## Averages eight steps (same clip order every run) so clip choice does not skew it.
func measure(title: String, action: Callable) -> void:
	seed(7)
	var peak := 0.0
	var sum := 0.0
	var tail := 0.0
	for take in 8:
		capture.clear_buffer()
		action.call()
		await create_timer(0.9).timeout
		var frames := capture.get_buffer(capture.get_frames_available())
		var take_peak := 0.0
		var take_sum := 0.0
		var take_tail := 0.0
		for i in frames.size():
			var frame: Vector2 = frames[i]
			take_peak = maxf(take_peak, maxf(absf(frame.x), absf(frame.y)))
			take_sum += frame.length_squared() * 0.5
			# Energy after 0.45 s: what is left is the room's echo.
			if i > frames.size() / 2: take_tail += frame.length_squared() * 0.5
		peak += take_peak / 8.0
		sum += take_sum / maxi(1, frames.size()) / 8.0
		tail += take_tail / maxi(1, frames.size() / 2) / 8.0
	print("%-34s peak %6.1f  RMS %6.1f  tail RMS %6.1f dBFS" % [title, linear_to_db(maxf(peak, 1e-6)), linear_to_db(maxf(sqrt(sum), 1e-6)), linear_to_db(maxf(sqrt(tail), 1e-6))])

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	level.world_audio.enabled = true
	level.world_audio.profile = null
	for source in level.world_audio.hums: source.volume_db = -80
	capture = AudioEffectCapture.new()
	capture.buffer_length = 2.0
	AudioServer.add_bus_effect(0, capture)
	var FLOOR := preload("res://game/world/generation/floor_definition.gd")
	var spots := {}
	for room in level.manifest.rooms:
		if not spots.has("hall") and int(room.hall) >= 0: spots["hall"] = FLOOR.position_of(room)
		if not spots.has("room") and int(room.hall) < 0 and FLOOR.palette(level.manifest).TYPES[int(room.type)] == "habitacion_simple": spots["room"] = FLOOR.position_of(room)
	for key in ["room", "hall"]:
		level.player.global_position = spots[key] + Vector3(0.5, 0.04, 0.5)
		level.player.hard_floor = false
		await create_timer(2.5).timeout
		await measure("%s: walk step" % key, func(): level.player.play_step(false, 0.0))
		await measure("%s: run step" % key, func(): level.player.play_step(true, 0.0))
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	level.queue_free()
	await process_frame
	quit()
