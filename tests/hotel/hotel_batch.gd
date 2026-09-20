extends SceneTree
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const WALK := preload("res://tests/hotel/hotel_walkthrough.gd")
var failures: Array = []
var walks: Array = []
var physics_passed := 0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	Engine.max_fps = 0
	var started := Time.get_ticks_msec()
	var count := 1000
	var report_path := "res://evidence/hotel_batch.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="): count = int(arg.trim_prefix("--count="))
		if arg.begins_with("--report="): report_path = "res://evidence/" + arg.trim_prefix("--report=").get_file()
	for seed_value in count:
		await level.start_floor(seed_value)
		if level.session.state != level.session.State.PLAYING or not level.physical_errors.is_empty():
			failures.append({"seed": seed_value, "reason": "physical_validation"})
			continue
		physics_passed += 1
		await physics_frame
		# Every leg of the floor: the start to the first refuge, and from each
		# gate to the refuge of the wing it opens.
		var from := Vector3.ZERO
		for stage in level.manifest.refuges.size():
			var room: Dictionary = level.manifest.rooms[int(level.manifest.refuges[stage])]
			var destination := FLOOR.position_of(room)
			var path := FLOOR.navigation_path(level.get_world_3d().navigation_map, from, destination)
			if path.size() < 2 or path[path.size() - 1].distance_to(destination) > 1.0:
				failures.append({"seed": seed_value, "reason": "navigation_stage_%d" % (stage + 1)})
				print("NAV_FAIL ", seed_value, " etapa ", stage + 1, " points=", path.size(), " end=", path[-1] if not path.is_empty() else Vector3.ZERO, " expected=", destination)
				break
			var gate: Dictionary = level.manifest.gates[stage]
			if int(gate.get("beyond", -1)) < 0: break
			from = FLOOR.position_of(level.manifest.rooms[int(gate.beyond)])
		if seed_value < 20:
			var success := await walk(level)
			walks.append({"seed": seed_value, "passed": success, "position_teleports": 0})
			if not success: failures.append({"seed": seed_value, "reason": "physical_walk"})
		if seed_value % 50 == 0: print("BATCH_PROGRESS ", seed_value, "/", count, " failures=", failures.size())
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "physical_seeds": physics_passed, "walks": walks, "failures": failures, "elapsed_seconds": (Time.get_ticks_msec() - started) / 1000.0}, "\t"))
	file.close()
	print("BATCH_RESULT ", failures.is_empty(), " seeds=", physics_passed, " walks=", walks.size(), " failures=", failures)
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func walk(level) -> bool:
	# BFS selects a route; movement and door interaction use the actual player.
	var parents := {0: -1}
	var queue: Array[int] = [0]
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for next in level.manifest.adjacency[current]:
			if not parents.has(next):
				parents[next] = current
				queue.append(next)
	var path: Array[int] = [int(level.manifest.exit)]
	while parents[path.back()] != -1: path.append(parents[path.back()])
	path.reverse()
	for id in path:
		var room: Dictionary = level.manifest.rooms[id]
		var destination := FLOOR.position_of(room)
		var frames := 0
		while Vector2(level.player.position.x - destination.x, level.player.position.z - destination.z).length() > 0.22 and frames < 700:
			var direction: Vector3 = destination - level.player.position
			level.player.rotation.y = atan2(-direction.x, -direction.z)
			level.player.camera.rotation.x = 0
			var door = level.focused_door()
			if is_instance_valid(door) and not door.opened and not door.moving:
				Input.action_release("forward")
				Input.action_press("interact")
				for frame in 3: await physics_frame
				Input.action_release("interact")
				for frame in 45: await physics_frame
			else: Input.action_press("forward")
			await physics_frame
			frames += 1
		Input.action_release("forward")
		if frames >= 700: return false
	level.player.camera.rotation.x = -0.4
	# Standing in the refuge with the quota is the condition of the first
	# stage: what it opens is the door on, which the navigation legs above
	# already prove is walkable.
	for frame in 120: await physics_frame
	return level.session.goal.get("ready", false) or level.session.stage > 1 or level.session.state == level.session.State.WON
