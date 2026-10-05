extends SceneTree
## The screens a difficulty is chosen on, photographed: the one "Nueva partida"
## opens, with the first and the last of them under the cursor, and the room
## with its host choosing one.
##
##   godot --path . --script tools/capture/difficulty_capture.gd -- --test-profile
## Writes evidence/difficulty_<screen>.png.
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String, frames := 30) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/difficulty_%s.png" % name)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 30: await process_frame
	level.ui.finish_intro()
	level.settings.values.difficulty = "apacible"
	level.ui.menu("difficulty")
	await shot("apacible")
	level.ui.buttons["pesadilla"].grab_focus()
	await shot("pesadilla", 10)
	if level.net.host("Andrés", 0, 24690) == OK:
		level.net.players[2] = {"name": "Camila", "character": 2, "peer": 0, "connected": true}
		level.net.set_option("difficulty", "equilibrada")
		level.ui.menu("lobby")
		await shot("sala")
		level.net.shutdown("")
	print("DIFFICULTY listo")
	level.queue_free()
	await process_frame
	quit()
