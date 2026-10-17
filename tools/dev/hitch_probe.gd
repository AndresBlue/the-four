extends SceneTree
## Hitches while playing: a walk down the longest lit corridor of a floor and
## back, at walking pace, the look sweeping side to side, frames as fast as
## they come (no vsync, no cap). Every frame's time is kept with what the
## floor did in it -- a round of its rooms and lamps (hotel_main, four a
## second), a reflection probe made or let go, lamps that started or stopped
## casting, wall lamps lit or put out, bounce volumes shown -- and the worst
## frames are listed with it, and the frames with a round against those without.
##
##   godot --rendering-method forward_plus --script res://tools/dev/hitch_probe.gd -- --test-profile --automation --silent [--seed=81] [--quality=3] [--frames=900] [--set=key:value,...] [--still]
##
## The creature is about its business, as in a game; "--still" puts it away
## and walks the camera instead of the body; "--near" holds it still some way
## off, where it is heard all the walk; "--creature" times its own steps. The
## world's sounds are worked out as in a game, with the speakers muted. Each of the worst frames says
## where its time went: the scripts' _process, a physics tick, drawing it.
## Needs a window.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
var level

func _initialize() -> void: run.call_deferred()

func longest_run() -> Array:
	var best: Array = []
	for room in level.manifest.rooms:
		if not bool(room.get("corridor", false)) or int(room.get("wing", 0)) != 0 or level.hotel.lights[int(room.id)].has_meta("off"): continue
		for way in [Vector2i(1, 0), Vector2i(0, 1)]:
			var back: int = FLOOR.beside(room, -way)
			if back >= 0 and level.hotel.open_pairs.has(Vector2i(mini(int(room.id), back), maxi(int(room.id), back))): continue
			var run: Array = [int(room.id)]
			while true:
				var next: int = FLOOR.beside(level.manifest.rooms[run[-1]], way)
				if next < 0 or not level.hotel.open_pairs.has(Vector2i(mini(run[-1], next), maxi(run[-1], next))) or level.hotel.lights[next].has_meta("off"): break
				run.append(next)
			if run.size() > best.size(): best = run
	return best

## What the floor is doing right now, to tell what changed in a frame.
func state() -> Dictionary:
	var hotel = level.hotel
	var casting := 0
	for lamp in hotel.lights:
		if lamp.visible and lamp.shadow_enabled: casting += 1
	var walls := 0
	for k in hotel.sconce_lights.size():
		if hotel.sconce_lights[k].visible: walls += 1
	var shown := 0
	if hotel.bounce != null:
		for volume in hotel.bounce.volumes:
			if volume.visible: shown += 1
	return {"probes": hotel.probes_made, "casting": casting, "walls": walls, "bounce": shown, "rooms": hotel.room_nodes.filter(func(node): return node.visible).size()}

func run() -> void:
	var quality := PRESETS.ULTRA
	var seed_value := 81
	var frames := 900
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--frames="): frames = int(argument.trim_prefix("--frames="))
		if argument.begins_with("--set="):
			for pair in argument.trim_prefix("--set=").split(","):
				var text := pair.get_slice(":", 1)
				PRESETS.overrides[pair.get_slice(":", 0)] = (text == "true") if text in ["true", "false"] else (float(text) if "." in text else int(text))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(seed_value)
	level.settings.set_designed(quality)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await level.bounce_ready()
	var still := OS.get_cmdline_user_args().has("--still")
	# "--steps": the camera in the physics ticks' steps, as it was.
	level.player.smooth_steps = not OS.get_cmdline_user_args().has("--steps")
	if still and is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
	var player = level.player
	if still: player.set_physics_process(false)
	else: player.active = true
	var cells := longest_run()
	var first: Vector3 = FLOOR.position_of(level.manifest.rooms[cells[0]])
	var last: Vector3 = FLOOR.position_of(level.manifest.rooms[cells[-1]])
	var along := (last - first).normalized()
	var length := first.distance_to(last)
	# "--near": the creature held still some 15 m off the corridor's middle,
	# where it is heard all the walk long (its voice and the aura route to it
	# four times a second).
	if OS.get_cmdline_user_args().has("--near") and is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		var middle: Vector3 = first.lerp(last, 0.5)
		level.locust.global_position = FLOOR.closest(root.get_world_3d().navigation_map, middle + along.cross(Vector3.UP) * 12.0 + along * 6.0)
		print("HITCH the creature held at ", level.locust.global_position.snapped(Vector3.ONE * 0.1), ", ", snappedf(level.locust.global_position.distance_to(middle), 0.1), " m from the corridor's middle")
	# The world's sounds worked out as in a game (an automated run leaves them
	# off), with nothing coming out of the speakers.
	level.world_audio.enabled = true
	AudioServer.set_bus_mute(0, true)
	# Settled first, at the start, for two seconds.
	player.global_position = first + Vector3(0, 0.04, 0)
	for frame in 120: await process_frame
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	var times := PackedFloat32Array()
	var marks: Array = []
	var parts: Array = []
	var viewport := root.get_viewport_rid()
	# Where the camera is drawn: read as the frame goes to be drawn, after
	# everything has placed it (read at the start of the frame, the body had
	# moved and the camera not yet).
	var steps := PackedVector3Array()
	var drawn_at := PackedFloat64Array()
	var read_camera := func() -> void:
		steps.append(player.camera.global_position)
		drawn_at.append(Time.get_ticks_usec() / 1000.0)
	RenderingServer.frame_pre_draw.connect(read_camera)
	if not still: Input.action_press("forward")
	# "--creature": its own steps timed, one by one (it is stepped from here).
	var creature_steps: Array = []
	var timing_creature: bool = not still and OS.get_cmdline_user_args().has("--creature") and is_instance_valid(level.locust)
	if timing_creature:
		level.locust.set_physics_process(false)
		var step := func() -> void:
			var start := Time.get_ticks_usec()
			level.locust._physics_process(1.0 / Engine.physics_ticks_per_second)
			creature_steps.append([(Time.get_ticks_usec() - start) / 1000.0, str(level.locust.mode)])
		physics_frame.connect(step)
	var walked := 0.0
	var before := state()
	var clock: float = level.visibility_clock
	var tick := Time.get_ticks_usec()
	for frame in frames:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := (now - tick) / 1000.0
		tick = now
		# Walking pace, there and back, the look sweeping +-40 degrees.
		walked += 3.8 * dt / 1000.0
		var lap := fmod(walked, length * 2.0)
		var at: float = lap if lap < length else length * 2.0 - lap
		var heading := along if lap < length else -along
		if still: player.global_position = first + along * at + Vector3(0, 0.04, 0)
		else:
			# Walking for real: turned round at either end of the corridor.
			var there: float = (player.global_position - first).dot(along)
			if there > length - 1.0: heading = -along
			elif there < 1.0: heading = along
			else: heading = along if absf(wrapf(player.rotation.y - atan2(-along.x, -along.z), -PI, PI)) < PI * 0.5 else -along
		player.rotation.y = atan2(-heading.x, -heading.z) + sin(frame * 0.035) * 0.5
		parts.append([Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, RenderingServer.viewport_get_measured_render_time_cpu(viewport) + RenderingServer.get_frame_setup_time_cpu(), RenderingServer.viewport_get_measured_render_time_gpu(viewport)])
		var after := state()
		var round_ran: bool = level.visibility_clock < clock
		clock = level.visibility_clock
		var changed: Array = []
		if round_ran: changed.append("round")
		for key in after:
			if after[key] != before[key]: changed.append("%s %d>%d" % [key, before[key], after[key]])
		before = after
		times.append(dt)
		marks.append(changed)
	# The worst frames and what happened in them (and in the frame before).
	var order := range(times.size())
	order.sort_custom(func(a, b): return times[a] > times[b])
	var sorted := Array(times)
	sorted.sort()
	var median: float = sorted[sorted.size() / 2]
	print("HITCH seed=", seed_value, " quality=", quality, " frames=", times.size(), " median ", snappedf(median, 0.01), " ms, 95th ", snappedf(sorted[int(sorted.size() * 0.95)], 0.01), " ms, 99th ", snappedf(sorted[int(sorted.size() * 0.99)], 0.01), " ms, worst ", snappedf(sorted[-1], 0.01), " ms; over twice the median: ", sorted.filter(func(t): return t > median * 2.0).size(), "; teeth (1.5 ms over the median): ", sorted.filter(func(t): return t > median + 1.5).size())
	for k in 15:
		var i: int = order[k]
		print("  frame %d: %.2f ms (process %.2f, physics %.2f, render cpu %.2f, gpu %.2f)  %s  (before it: %s)" % [i, times[i], parts[i][0], parts[i][1], parts[i][2], parts[i][3], marks[i], marks[i - 1] if i > 0 else []])
	var with_round := []
	var without := []
	for i in times.size():
		if "round" in marks[i]: with_round.append(times[i])
		else: without.append(times[i])
	var mean := func(list: Array) -> float: return list.reduce(func(sum, t): return sum + t, 0.0) / maxf(1.0, list.size())
	Input.action_release("forward")
	# How evenly the camera goes, frame by frame, against how long each frame
	# took: its speed from one frame to the next, and how much that speed
	# wanders (0 for an even walk; the steps of the physics ticks show as more).
	RenderingServer.frame_pre_draw.disconnect(read_camera)
	if not still:
		var speeds := PackedFloat32Array()
		for i in range(1, steps.size()):
			var flat := Vector2(steps[i].x - steps[i - 1].x, steps[i].z - steps[i - 1].z).length()
			var took: float = drawn_at[i] - drawn_at[i - 1]
			if took > 0.0: speeds.append(flat / (took / 1000.0))
		var mean_speed := 0.0
		for v in speeds: mean_speed += v
		mean_speed /= maxf(1.0, speeds.size())
		var spread := 0.0
		for v in speeds: spread += (v - mean_speed) * (v - mean_speed)
		spread = sqrt(spread / maxf(1.0, speeds.size()))
		print("HITCH steps: the camera's speed frame to frame %.2f m/s, wandering by %.2f m/s (%.0f %%)" % [mean_speed, spread, spread / maxf(0.001, mean_speed) * 100.0])
	if timing_creature:
		for connection in physics_frame.get_connections(): physics_frame.disconnect(connection.callable)
		var costs := creature_steps.map(func(c): return float(c[0]))
		costs.sort()
		var worst_steps := creature_steps.duplicate()
		worst_steps.sort_custom(func(a, b): return a[0] > b[0])
		print("HITCH the creature's steps: ", creature_steps.size(), ", median %.2f ms, worst %s" % [costs[costs.size() / 2], worst_steps.slice(0, 6).map(func(c): return "%.2f ms (mode %s)" % [c[0], c[1]])])
	var med := func(column: int) -> float:
		var values := parts.map(func(p): return float(p[column]))
		values.sort()
		return values[values.size() / 2]
	print("HITCH a middling frame: process %.2f, physics %.2f, render cpu %.2f, gpu %.2f ms" % [med.call(0), med.call(1), med.call(2), med.call(3)])
	var laps := {}
	var walked_by := 0.0
	for i in times.size():
		walked_by += 3.8 * times[i] / 1000.0
		var lap := int(walked_by / (length * 2.0))
		if not laps.has(lap): laps[lap] = [0, 0, 0.0]
		laps[lap][0] += 1
		if times[i] > median * 2.0: laps[lap][1] += 1
		laps[lap][2] = maxf(laps[lap][2], times[i])
	for lap in laps: print("HITCH lap %d (there and back): %d frames, %d over twice the median, worst %.2f ms" % [lap, laps[lap][0], laps[lap][1], laps[lap][2]])
	print("HITCH frames with a round: ", with_round.size(), ", mean ", snappedf(mean.call(with_round), 0.01), " ms; without: ", without.size(), ", mean ", snappedf(mean.call(without), 0.01), " ms")
	level.queue_free()
	await process_frame
	quit()
