extends SceneTree
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
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
	# A mono test tone: stereo door recordings are not centred, which would
	# measure the recording's own balance instead of the 3D panning.
	level.world_audio.streams["test://mono_tone"] = preload("res://game/ui/osd_style.gd").beep(440.0, 0.8, 0.5)
	level.world_audio.play_at("test://mono_tone", point, -10)
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
	audio.door_cue(true, false, listener + Vector3(0, 0, -3), RID(), true)
	check("Running into a door selects a slam", audio.last_event.pool == "open_slam_near")
	check("Playback skips the recording's leading silence", is_equal_approx(audio.voices[-1].get_meta("start"), preload("res://game/audio/cue_timing.gd").onset(audio.last_event.path)))
	audio.door_cue(false, false, listener + Vector3(0, 0, -3), RID())
	check("Closing cue starts near its impact", audio.voices[-1].get_meta("start") >= preload("res://game/audio/cue_timing.gd").hit(audio.last_event.path) - audio.CLOSE_PREROLL - 0.001)
	for i in 20: audio.play_at(audio.choose("close_near"), listener, -16)
	check("Effects have bounded simultaneous voices", audio.voices.size() == audio.maximum_voices)
	var door := preload("res://game/world/interactables/hotel_door.gd").new()
	level.add_child(door)
	door.doorway = Vector3(500, 0, 0)
	var events := []
	door.sound_requested.connect(func(opening, slow, point, _rid, forceful): events.append({"opening": opening, "slow": slow, "point": point, "forceful": forceful}))
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
	check("Presence follows creature on its binaural bus", audio.presence.playing and audio.presence.global_position.distance_to(level.locust.global_position + Vector3(0, 1.4, 0)) < 0.01 and audio.presence.bus == &"Creature")
	var gain: float = audio.presence.volume_db
	level.locust.set_mode(level.locust.Mode.PATROL)
	level.locust.voice.stop()
	level.locust.position = audio.listener_position() + Vector3(0, -1.6, -4)
	level.locust.set_mode(level.locust.Mode.ALERT)
	var grunt_segment: Array = preload("res://game/audio/grunt_segments.gd").SEGMENTS[level.locust.last_grunt]
	check("Spotting the player plays an aggressive grunt", level.locust.voice.playing and grunt_segment[1] >= level.locust.AGGRESSIVE_GRUNT and is_equal_approx(level.locust.grunt_left, grunt_segment[1] / level.locust.voice.pitch_scale))
	level.locust.set_mode(level.locust.Mode.CHASE)
	check("The chase calls again once that grunt ends", level.locust.grunt_clock > level.locust.grunt_left)
	var first_grunt: int = level.locust.last_grunt
	level.locust.grunt()
	check("Grunts do not repeat back to back", level.locust.last_grunt != first_grunt)
	level.locust.voice.stop()
	# Distance has to be audible as distance, not only as volume: ten metres,
	# twenty and forty must read differently, and a shriek has to die before
	# the reach it buys (26 m of listening) makes it useful as a bearing.
	var reading := func(metres: float, shriek: bool) -> Dictionary:
		var point: Vector3 = audio.listener_position() + Vector3(0, 1.4, -metres)
		var route: Dictionary = audio.route_source(point)
		audio.apply_route(level.locust.voice, route, level.locust.shape_voice(shriek), "Threat", true)
		var db: float = level.locust.voice.volume_db - 20.0 * log(maxf(metres, 1.0) / level.locust.voice.unit_size) / log(10.0)
		return {"db": db, "cutoff": level.locust.voice.attenuation_filter_cutoff_hz, "reach": level.locust.voice.max_distance}
	var near: Dictionary = reading.call(10.0, true)
	var middle: Dictionary = reading.call(20.0, true)
	var distant: Dictionary = reading.call(40.0, true)
	check("Distance eats the top end of a cry", distant.cutoff < middle.cutoff * 0.85 and middle.cutoff < near.cutoff * 0.9)
	# More than the 6 dB per doubling that distance alone gives: the extra is
	# the air, and without it these thresholds are not met.
	check("And it keeps dropping in level", distant.db < middle.db - 8.0 and middle.db < near.db - 7.0)
	check("A shriek stops before the reach it buys is useful", distant.reach < 40.0 and distant.reach <= level.match_net.SHRIEK_RANGE + 7.0)
	check("A chase grunt carries further than a cry, and quieter", reading.call(10.0, false).reach > distant.reach and reading.call(10.0, false).db < near.db)
	level.locust.voice.stop()
	level.locust.position = Vector3(500, 0, 0)
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
	# Propagation: behind a wall a sound arrives from the doorway, with echo.
	var portal = level.hotel.doors[0]
	portal.open_immediately()
	var across: Vector3 = Basis(Vector3.UP, portal.closed_rotation) * Vector3(0, 0, 1)
	var sideways: Vector3 = across.cross(Vector3.UP).normalized()
	level.player.position = portal.doorway - across * 3.0 + sideways * 3.5 + Vector3(0, 0.04, 0)
	await physics_frame
	# Same side as the listener: the straight line meets the wall, not the doorway.
	var hidden_point: Vector3 = portal.doorway + across * 3.0 + sideways * 3.5 + Vector3.UP * 1.4
	var heard: Dictionary = audio.route_source(hidden_point)
	check("Walls never pass sound: it arrives from the opening", heard.audible and heard.echo and heard.position.distance_to(portal.doorway + Vector3.UP * 1.5) < 2.5 and heard.gain < -3.0)
	var visible_point: Vector3 = level.player.global_position + Vector3(0, 1.4, -2.0)
	var direct: Dictionary = audio.route_source(visible_point)
	check("In the open a sound comes straight from its source", direct.audible and not direct.echo and direct.position == visible_point)
	# Dread aura: follows the walkable route and points toward the creature.
	var aura = audio.aura
	level.player.position = Vector3(-3.5, 0.04, 0)
	level.player.rotation = Vector3.ZERO
	level.player.camera.rotation = Vector3.ZERO
	level.locust.grace = 0
	level.locust.set_mode(level.locust.Mode.PATROL)
	level.locust.position = Vector3(500, 0.04, 500)
	aura.reset()
	await wait(1.0)
	var far_intensity: float = aura.intensity
	level.locust.position = Vector3(3.5, 0.04, 0)
	await wait(2.5)
	check("Dread aura rises as the creature closes in by route", aura.intensity > far_intensity + 0.5 and aura.route_distance < 10.0)
	var local: Vector3 = level.player.camera.global_transform.affine_inverse() * aura.cue_point
	check("Directional dread cues sit on the creature's side", local.x > 1.0)
	# Isolate the directional layers from the centred pressure drone.
	aura.drone.bus = &"Music"
	var aura_capture := AudioEffectCapture.new()
	aura_capture.buffer_length = 3
	var aura_bus := AudioServer.get_bus_index("Aura")
	AudioServer.add_bus_effect(aura_bus, aura_capture)
	await wait(1.6)
	var dread_energy := energy(aura_capture)
	check("Rendered dread cues pan toward the creature", dread_energy.y > dread_energy.x * 1.4 and dread_energy.y > 0.0000001)
	AudioServer.remove_bus_effect(aura_bus, AudioServer.get_bus_effect_count(aura_bus) - 1)
	aura.drone.bus = &"Aura"
	level.player.position = FLOOR.position_of(level.manifest.rooms[level.manifest.exit]) + Vector3(0, 0.04, 0)
	await wait(0.4)
	check("Refuge releases the aura", aura.target == 0.0)
	level.player.position = Vector3(500, 0, 4)
	level.locust.position = Vector3(500, 0, 0)
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
