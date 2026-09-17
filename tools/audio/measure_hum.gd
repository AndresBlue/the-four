extends SceneTree
## Fluorescent hum level through the real mixer (sliders at 50%): standing under
## a batten, across its room and in the next room. Master bus dBFS. Real time.
var level
var capture: AudioEffectCapture

func _initialize() -> void: run.call_deferred()

func measure(title: String, seconds: float) -> void:
	await create_timer(0.8).timeout
	capture.clear_buffer()
	await create_timer(seconds).timeout
	var frames := capture.get_buffer(capture.get_frames_available())
	var sum := 0.0
	for frame in frames: sum += frame.length_squared() * 0.5
	var playing: int = level.world_audio.hums.filter(func(hum): return hum.playing).size()
	print("%-40s RMS %6.1f dBFS  hums=%d" % [title, linear_to_db(maxf(sqrt(sum / maxi(1, frames.size())), 0.000001)), playing])

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	level.world_audio.enabled = true
	level.world_audio.profile = null
	capture = AudioEffectCapture.new()
	capture.buffer_length = 4.0
	AudioServer.add_bus_effect(0, capture)
	# A service room with a steady tube, far from any other batten.
	var chosen = null
	for entry in level.hotel.tubes:
		if level.hotel.flickers.any(func(f): return f.light == entry.light): continue
		var alone: bool = level.hotel.tubes.all(func(other): return other == entry or other.light.global_position.distance_to(entry.light.global_position) > 14.0)
		if alone:
			chosen = entry
			break
	if chosen == null: chosen = level.hotel.tubes[0]
	var under: Vector3 = chosen.light.global_position
	var map: RID = level.get_world_3d().navigation_map
	var floor_point := NavigationServer3D.map_get_closest_point(map, Vector3(under.x, 0, under.z))
	level.player.global_position = floor_point + Vector3(0, 0.04, 0)
	await measure("under the tube", 2.0)
	for distance in [3.0, 5.0]:
		level.player.global_position = NavigationServer3D.map_get_closest_point(map, floor_point + Vector3(distance, 0, 0)) + Vector3(0, 0.04, 0)
		await measure("%.1f m from the tube (+X, %.1f m)" % [distance, level.player.global_position.distance_to(floor_point)], 2.0)
	level.player.global_position = NavigationServer3D.map_get_closest_point(map, floor_point + Vector3(11, 0, 0)) + Vector3(0, 0.04, 0)
	await measure("about 11 m away (%.1f m)" % level.player.global_position.distance_to(floor_point), 2.0)
	level.player.global_position = floor_point + Vector3(0, 0.04, 0)
	level.player.footstep.play()
	await measure("under the tube + one footstep", 0.4)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	level.queue_free()
	await process_frame
	quit()
