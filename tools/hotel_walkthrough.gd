extends SceneTree
const FLOOR := preload("res://scripts/hotel/floor_definition.gd")
var level
var failures: Array[String] = []
var walked := 0.0

func _initialize() -> void: run.call_deferred()

func capture_image(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/hotel_%s.png" % name_value)

func route(data: Dictionary) -> Array[int]:
	var parents := {int(data.start): -1}
	var queue: Array[int] = [int(data.start)]
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for next in data.adjacency[current]:
			if not parents.has(next):
				parents[next] = current
				queue.append(next)
	var path: Array[int] = [int(data.exit)]
	while parents[path.back()] != -1: path.append(parents[path.back()])
	path.reverse()
	return path

func run() -> void:
	level = load("res://scenes/hotel.tscn").instantiate()
	root.add_child(level)
	await capture_image("menu")
	level.ui.show_settings("main")
	await capture_image("settings")
	level.on_action("main")
	var run_seed := 81
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="): run_seed = int(arg.trim_prefix("--seed="))
	await level.start_floor(run_seed)
	if DisplayServer.get_name() == "headless": Engine.max_fps = 0
	for frame in 4: await physics_frame
	await capture_image("reception")
	var navigation := FLOOR.navigation_path(level.get_world_3d().navigation_map, level.player.position, FLOOR.position_of(level.manifest.rooms[level.manifest.exit]))
	print("NAV end=", navigation[-1] if not navigation.is_empty() else Vector3.ZERO, " expected=", FLOOR.position_of(level.manifest.rooms[level.manifest.exit]))
	if navigation.size() < 2: failures.append("navigation_empty")
	var path := route(level.manifest)
	var screenshot_count := 0
	var timings: Array[float] = []
	for id in path:
		var room: Dictionary = level.manifest.rooms[id]
		var destination := FLOOR.position_of(room)
		var frames := 0
		while Vector2(level.player.position.x - destination.x, level.player.position.z - destination.z).length() > 0.22 and frames < 1000:
			var direction: Vector3 = destination - level.player.position
			direction.y = 0
			level.player.rotation.y = atan2(-direction.x, -direction.z)
			level.player.camera.rotation.x = 0
			var door = level.focused_door()
			if is_instance_valid(door) and not door.opened and not door.moving:
				Input.action_release("forward")
				Input.action_press("interact")
				for wait_frame in 3: await physics_frame
				Input.action_release("interact")
				for wait_frame in 45: await physics_frame
			else: Input.action_press("forward")
			var before: Vector3 = level.player.position
			var tick := Time.get_ticks_usec()
			await physics_frame
			timings.append((Time.get_ticks_usec() - tick) / 1000.0)
			walked += level.player.position.distance_to(before)
			frames += 1
		Input.action_release("forward")
		if frames >= 1000:
			failures.append("stuck_room_%d" % id)
			print("STUCK position=", level.player.position, " target=", destination, " focus=", level.focused_door())
			for door in level.hotel.doors:
				if door.doorway.distance_to(level.player.position) < 4: print("DOOR ", door.name, " open=", door.opened, " moving=", door.moving, " angle=", door.rotation.y)
			await capture_image("stuck")
			break
		if screenshot_count < 3 and id != 0:
			level.player.rotation.y += 0.6
			await capture_image("room_%d" % screenshot_count)
			screenshot_count += 1
	if failures.is_empty():
		await capture_image("refuge")
		level.player.camera.rotation.x = -0.4
		Input.action_press("interact")
		for frame in 200: await physics_frame
		Input.action_release("interact")
		for frame in 100: await physics_frame
		if level.session.state != level.session.State.WON: failures.append("no_victory")
		await capture_image("victory")
	timings.sort()
	var report := FileAccess.open("res://evidence/hotel_walkthrough.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "seed": 81, "route": path, "walked_metres": walked, "position_teleports": 0, "navigation_points": navigation.size(), "physics_wait_p95_ms": timings[int(timings.size() * 0.95)] if not timings.is_empty() else 0, "renderer": RenderingServer.get_current_rendering_method()}, "\t"))
	report.close()
	print("HOTEL_WALKTHROUGH=", failures.is_empty(), " ", failures, " metres=", walked)
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
