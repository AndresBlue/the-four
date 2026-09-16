extends SceneTree
var level
var checks: Array = []
var errors := 0
func _initialize() -> void: run.call_deferred()
func check(title: String, ok: bool) -> void:
	checks.append({"check": title, "passed": ok})
	if not ok: errors += 1
	print("PASS " if ok else "FAIL ", title)
func wait(seconds: float) -> void: await create_timer(seconds).timeout
func energy(capture: AudioEffectCapture) -> Vector2:
	var result := Vector2.ZERO
	var data := capture.get_buffer(capture.get_frames_available())
	for frame in data: result += Vector2(frame.x * frame.x, frame.y * frame.y)
	return result / maxi(1, data.size())
func sample_at(point: Vector3, capture: AudioEffectCapture) -> Vector2:
	level.world_audio.reset()
	await wait(0.1)
	capture.clear_buffer()
	level.world_audio.play_at("res://assets/audio/sfx/door/opening/opening1.ogg", point, -10)
	level.world_audio.voices[-1].pitch_scale = 1.0
	await wait(0.9)
	return energy(capture)
func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.player.set_physics_process(false)
	level.player.position = Vector3(500, 0, 4)
	level.player.rotation = Vector3.ZERO
	level.player.camera.rotation = Vector3.ZERO
	var audio = level.world_audio
	audio.enabled = true
	level.settings.set_value("master", 0.8)
	level.settings.set_value("effects", 0.8)
	level.settings.set_value("threat", 0.85)
	var no_repeat := true
	var valid := true
	for pool in audio.POOLS:
		var previous := ""
		for i in 24:
			var selected: String = audio.choose(pool)
			if audio.POOLS[pool].size() > 1 and selected == previous: no_repeat = false
			var stream: AudioStream = load(selected)
			valid = valid and stream != null and stream.get_length() > 0
			previous = selected
	check("Pools decode and avoid immediate repeats", valid and no_repeat)
	var listener: Vector3 = audio.listener_position()
	audio.door_cue(true, false, listener + Vector3(0, 0, -3), RID())
	check("Nearby door uses dry pool at the actual source", audio.last_event.pool == "open_near" and audio.voices[-1].global_position.distance_to(listener + Vector3(0, 0, -3)) < 0.01)
	audio.door_cue(true, false, listener + Vector3(0, 0, -20), RID())
	check("Far listener selects distant recordings", audio.last_event.pool == "open_far")
	audio.door_cue(true, true, listener + Vector3(0, 0, -3), RID())
	check("Slow opening selects creaking recording", audio.last_event.pool == "open_slow")
	for i in 20: audio.play_at(audio.choose("close_near"), listener, -16)
	check("Effects have bounded simultaneous voices", audio.voices.size() == audio.maximum_voices)
	var door := preload("res://game/world/interactables/hotel_door.gd").new()
	level.add_child(door)
	door.doorway = Vector3(500, 0, 0)
	var events := []
	door.sound_requested.connect(func(opening, slow, point, _rid): events.append({"opening": opening, "slow": slow, "point": point}))
	door.open_immediately()
	check("Map initialization emits no door sound", events.is_empty())
	level.player.position = door.doorway
	check("Occupied close emits no false latch", not door.toggle() and events.is_empty())
	level.player.position = Vector3(500, 0, 4)
	door.toggle()
	check("Closing sound waits for physical completion", events.is_empty())
	await wait(0.8)
	check("Completed close emits one cue", events.size() == 1 and not events[0].opening)
	door.toggle()
	await wait(0.8)
	events.clear()
	door.toggle()
	level.player.position = door.doorway
	await wait(0.8)
	check("Blocked closing reopens without a latch sound", door.opened and events.is_empty())
	level.player.position = Vector3(500, 0, 4)
	var hide = get_nodes_in_group("hotel_hides")[0]
	var entered: bool = level.player.enter_hide(hide)
	check("Hiding plays wardrobe entry", entered and audio.last_event.path.contains("wardrobe/closing"))
	var left: bool = level.player.leave_hide()
	check("Leaving hiding plays wardrobe opening", left and audio.last_event.path.contains("wardrobe/opening"))
	level.player.position = Vector3(500, 0, 4)
	level.player.rotation = Vector3.ZERO
	level.player.camera.rotation = Vector3.ZERO
	level.locust.position = Vector3(500, 0, 0)
	level.locust.grace = 0
	await wait(2)
	check("Presence follows creature and uses Threat bus", audio.presence.playing and audio.presence.global_position.distance_to(level.locust.global_position + Vector3(0, 1.4, 0)) < 0.01 and audio.presence.bus == &"Threat")
	var gain: float = audio.presence.volume_db
	level.locust.set_mode(level.locust.Mode.WINDUP)
	await wait(0.2)
	check("Presence ducks under attack warning", audio.presence.volume_db < gain - 10)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.2)
	shape.shape = box
	wall.add_child(shape)
	level.add_child(wall)
	wall.position = Vector3(500, 1.5, 2)
	await physics_frame
	await physics_frame
	check("Physical wall occludes sound ray", audio.occluded(Vector3(500, 1.4, 0)))
	wall.queue_free()
	await physics_frame
	audio.reset()
	audio.set_physics_process(false)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2
	var bus := AudioServer.get_bus_index("Effects")
	AudioServer.add_bus_effect(bus, capture)
	listener = audio.listener_position()
	var left_energy := await sample_at(listener + Vector3(-3, 0, -2), capture)
	var right_energy := await sample_at(listener + Vector3(3, 0, -2), capture)
	var far_energy := await sample_at(listener + Vector3(20, 0, -2), capture)
	check("Rendered audio pans left and right", left_energy.x > left_energy.y * 1.2 and right_energy.y > right_energy.x * 1.2 and minf(left_energy.x, right_energy.y) > 0.00000001)
	check("Rendered audio attenuates at distance", far_energy.x + far_energy.y > 0.00000000001 and far_energy.x + far_energy.y < (right_energy.x + right_energy.y) * 0.5)
	level.session.set_state(level.session.State.FAILED)
	check("Death clears active cues", audio.voices.is_empty() and not audio.presence.playing)
	AudioServer.remove_bus_effect(bus, 0)
	var file := FileAccess.open("res://evidence/spatial_audio.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": errors == 0, "checks": checks, "left_energy": [left_energy.x, left_energy.y], "right_energy": [right_energy.x, right_energy.y], "far_energy": [far_energy.x, far_energy.y]}, "\t"))
	file.close()
	print("SPATIAL_AUDIO ", checks.size() - errors, "/", checks.size())
	level.queue_free()
	await process_frame
	await wait(0.1)
	quit(0 if errors == 0 else 1)
