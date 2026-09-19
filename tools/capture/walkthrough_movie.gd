extends SceneTree
## A recorded walk through the seed 81 floor, for judging the camera in motion
## (hand-held motion, exposure, motion blur, tape): the player really walks,
## with input, along the route from the reception, turning towards the path
## ahead, doors open. Recorded by Godot's Movie Maker:
##   godot --path . --rendering-method forward_plus --write-movie evidence/lookdev/walk.avi --fixed-fps 30 --script res://tools/capture/walkthrough_movie.gd -- --automation --test-profile --no-enemy --silent --handheld [--quality=2] [--seconds=24] [--run]
## --handheld keeps the camera's hand-held motion, which --automation turns off.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SIZE := Vector2i(1280, 720)
var level

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var quality := 2
	var seconds := 24.0
	var running := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--seconds="): seconds = float(argument.trim_prefix("--seconds="))
		if argument == "--run": running = true
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	level.settings.set_value("quality", quality)
	DisplayServer.window_set_size(SIZE)
	if is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
	for door in level.hotel.doors:
		if not door.opened: door.set_state(true)
	var route: PackedVector3Array = FLOOR.navigation_path(level.get_world_3d().navigation_map, level.player.global_position, FLOOR.position_of(level.manifest.rooms[int(level.manifest.exit)]))
	level.player.active = true
	level.player.torch.visible = true
	var target := 1
	var elapsed := 0.0
	Input.action_press("forward")
	if running: Input.action_press("sprint")
	while elapsed < seconds and target < route.size():
		await physics_frame
		var delta := 1.0 / Engine.physics_ticks_per_second
		elapsed += delta
		var here: Vector3 = level.player.global_position
		# Next waypoint a little ahead, so corners are cut like a person would.
		while target < route.size() - 1 and Vector2(route[target].x - here.x, route[target].z - here.z).length() < 1.2: target += 1
		var aim: Vector3 = route[target] - here
		var yaw := atan2(-aim.x, -aim.z)
		var turn := wrapf(yaw - level.player.rotation.y, -PI, PI)
		var step := clampf(turn, -2.6 * delta, 2.6 * delta)
		level.player.rotation.y += step
		# As the mouse would: the hand-held camera reads the turn.
		level.player.turn_delta.x += step
		level.player.camera.rotation.x = lerpf(level.player.camera.rotation.x, -0.08 + sin(elapsed * 0.4) * 0.05, delta * 2.0)
	Input.action_release("forward")
	Input.action_release("sprint")
	print("WALK done ", snappedf(elapsed, 0.1), " s")
	level.queue_free()
	await process_frame
	quit()
