extends SceneTree
## Online menus (evidence/online_*.png): multiplayer, join, the room as host
## with other seats filled in for the picture, and the sheet open over a floor.
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String) -> void:
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/online_%s.png" % name)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	# The tape screen plays over everything for its first seconds and these
	# shots are about what is behind it.
	level.ui.finish_intro()
	await process_frame
	level.on_action("multiplayer")
	await shot("multiplayer")
	level.on_action("join")
	await shot("join")
	level.net.host("Andrés", 0, 24650)
	# Pretend guests, only for the picture.
	level.net.players[2] = {"name": "Camila", "character": 1, "peer": 0, "connected": true}
	level.net.players[3] = {"name": "Tomás", "character": 2, "peer": 0, "connected": true}
	level.net.players[4] = {"name": "Vale", "character": 1, "peer": 0, "connected": true}
	level.net.options.mode = level.net.Mode.VERSUS
	level.net.options.locust = 3
	level.ui.menu("lobby")
	await shot("lobby")
	level.net.shutdown("")
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.toggle_sheet()
	var sheet = level.ui.sheet
	for op in [[0, [Vector2(0.2, 0.3), Vector2(0.35, 0.3), Vector2(0.35, 0.55), Vector2(0.6, 0.55)]], [0, [Vector2(0.6, 0.55), Vector2(0.6, 0.35), Vector2(0.75, 0.35)]], [0, [Vector2(0.18, 0.28), Vector2(0.22, 0.32)]]]:
		sheet.counter += 1
		sheet.apply_confirmed("1:%d" % sheet.counter, op[0], PackedVector2Array(op[1]))
	await shot("sheet")
	level.queue_free()
	await process_frame
	quit()
