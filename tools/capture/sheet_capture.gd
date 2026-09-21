extends SceneTree
## The shared sheet and the slips beside it, as they are opened in a match:
## empty, with a few numbers found, and with four hands having drawn on it.
##   godot --path . --script tools/capture/sheet_capture.gd -- --silent
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String) -> void:
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/sheet_%s.png" % name)
	print("SHOT ", name)

func scribble(seat: int, count: int, from: Vector2, step: Vector2) -> void:
	# A stroke as the host would confirm it, in page coordinates 0..1.
	var points := PackedVector2Array()
	for i in count:
		var t := float(i) / float(count)
		points.append(from + step * t + Vector2(0.0, sin(t * 9.0) * 0.03))
	level.ui.sheet.apply_confirmed("%d:1" % seat, 0, points)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	for i in 120: await process_frame
	var ui = level.ui
	ui.sheet.seat = 1
	ui.sheet.open(true, "TAB", [])
	await shot("empty")
	ui.sheet.close()
	# Three of the four numbers, found in three different rooms.
	ui.sheet.open(true, "TAB", [
		{"slot": 1, "digit": 4, "where": "HABITACIÓN 214"},
		{"slot": 2, "digit": 7, "where": "LAVANDERÍA"},
		{"slot": 3, "digit": 9, "where": "PASILLO"},
		{"slot": 4, "digit": 0, "where": "COMEDOR"}])
	await shot("notes")
	# And four hands on the page.
	scribble(1, 40, Vector2(0.12, 0.30), Vector2(0.30, 0.10))
	scribble(2, 40, Vector2(0.20, 0.62), Vector2(0.34, -0.05))
	scribble(3, 30, Vector2(0.55, 0.22), Vector2(0.18, 0.34))
	scribble(4, 30, Vector2(0.60, 0.70), Vector2(0.22, -0.16))
	await shot("drawn")
	print("SHEET listo")
	quit()
