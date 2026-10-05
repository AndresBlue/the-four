extends SceneTree
## The rules of a room, photographed: the room with a few of them changed, and
## the screen the host picks them on, tab by tab.
##
##   godot --path . --script tools/capture/rules_capture.gd -- --test-profile
## Writes evidence/rules_<screen>.png.
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String, frames := 30) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/rules_%s.png" % name)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 30: await process_frame
	level.ui.finish_intro()
	if level.net.host("Andrés", 0, 24689) != OK:
		print("RULES no pudo abrir la sala")
		quit(1)
		return
	level.net.players[2] = {"name": "Camila", "character": 2, "peer": 0, "connected": true}
	level.net.players[3] = {"name": "Rodrigo", "character": 1, "peer": 0, "connected": true}
	level.net.set_option("rules", {"restarts": 2, "code": 1, "plan_fade": 300, "onslaught": 1})
	level.ui.menu("lobby")
	await shot("sala")
	level.ui.rules_view = {}
	level.ui.menu("rules")
	await shot("equipo")
	for page in ["piso", "hoja", "locust"]:
		level.ui.turn_tab(1)
		await shot(page, 15)
	level.net.shutdown("")
	print("RULES listo")
	level.queue_free()
	await process_frame
	quit()
