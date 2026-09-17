extends SceneTree
## The execution seen from the side (evidence/execution_*.png): impaled,
## lifted and the three blows.
var level

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
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
	var view := Camera3D.new()
	view.fov = 60.0
	level.add_child(view)
	view.global_position = spot + Vector3(3.4, 1.9, 1.4)
	view.look_at(spot + Vector3(0, 1.4, -0.9))
	view.current = true
	# Straight into the execution, with the creature still animating.
	level.locust.face_toward(spot, 1.0, 100.0)
	level.capture_survivor(level.player)
	var shots := {25: "impale", 66: "lift", 100: "second", 140: "head"}
	var taken: Array = []
	for frame in 200:
		await process_frame
		if shots.has(frame):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/execution_%s.png" % shots[frame])
			taken.append(shots[frame])
	print("EXECUTION_SHOTS ", taken)
	level.queue_free()
	await process_frame
	quit()
