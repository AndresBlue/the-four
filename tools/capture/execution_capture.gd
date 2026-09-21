extends SceneTree
## The execution seen from the side (evidence/execution_*.png): the grab, the
## lift, the mask coming in, the arm through the face and the picture going.
## With "-- --victim" it stays behind the victim's own eyes instead
## (evidence/execution_pov_*.png), which is where the arm and the static are.
var level
var victim := false

func _initialize() -> void: run.call_deferred()

func run() -> void:
	victim = OS.get_cmdline_user_args().has("--victim")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	# The tape screen plays over everything for its first seconds and these
	# shots are about what is behind it.
	level.ui.finish_intro()
	await level.start_floor(81)
	level.player.set_physics_process(false)
	var spot := Vector3(0, 0.04, 0)
	level.player.global_position = spot
	level.locust.global_position = spot + Vector3(0, 0.04, -1.6)
	level.locust.rotation.y = 0.0
	level.locust.grace = 0.0
	# A camera to the side, plus light enough to see what happens.
	var lamp := OmniLight3D.new()
	lamp.light_energy = 3.0
	lamp.omni_range = 12.0
	lamp.position = spot + Vector3(2.5, 2.6, 2.0)
	level.add_child(lamp)
	if not victim:
		var view := Camera3D.new()
		view.fov = 60.0
		level.add_child(view)
		view.global_position = spot + Vector3(3.4, 1.9, 1.4)
		view.look_at(spot + Vector3(0, 1.4, -0.9))
		view.current = true
	# Straight into the execution, with the creature still animating.
	level.locust.face_toward(spot, 1.0, 100.0)
	level.capture_survivor(level.player)
	# Timed off the execution itself, not off frame numbers: the window does
	# not render at a fixed rate and the beats would slide.
	var shots := [[0.15, "grab"], [0.7, "lift"], [2.2, "face"], [2.9, "kill"], [3.4, "static"]]
	if victim: shots = [[0.2, "grab"], [2.4, "held"], [level.ARM_TIME + level.ARM_SWING * 0.45, "arm"], [level.KILL_TIME + 0.02, "covered"], [level.SIGNAL_TIME + 0.25, "static"]]
	var prefix := "execution_pov_" if victim else "execution_" 
	var taken: Array = []
	var next := 0
	while next < shots.size():
		await process_frame
		if level.execution.is_empty(): break
		if float(level.execution.time) < float(shots[next][0]): continue
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/%s%s.png" % [prefix, shots[next][1]])
		taken.append(shots[next][1])
		next += 1
	print("EXECUTION_SHOTS ", taken)
	level.queue_free()
	await process_frame
	quit()
