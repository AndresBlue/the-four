extends SceneTree
## The main menu and the credits, photographed: what a new player is offered
## (no Records and no Archivo while there is nothing in them) and who is named.
##
##   godot --path . --script tools/capture/menu_capture.gd -- --test-profile
## Writes evidence/menu_<screen>.png.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 30: await process_frame
	level.ui.finish_intro()
	for screen in ["main", "credits"]:
		level.ui.menu(screen)
		for i in 40: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/menu_%s.png" % screen)
	print("MENU listo")
	quit()
