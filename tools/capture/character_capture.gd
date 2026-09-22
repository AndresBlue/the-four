extends SceneTree
## The character screen of the menu, once per survivor, at a given window
## size: to see that each one stands whole in its preview.
##
##   godot --path . --script tools/capture/character_capture.gd -- [--size=1264x681]
## Writes evidence/character_<index>_open.png and character_<index>.png.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var size := Vector2i(1264, 681)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	DisplayServer.window_set_size(size)
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 30: await process_frame
	# Each one twice: opening the screen with it already chosen, and chosen
	# from the list with the screen open.
	for index in 3:
		level.settings.set_value("character", index)
		level.ui.show_characters()
		for i in 40: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/character_%d_open.png" % index)
		level.ui.buttons["character_%d" % ((index + 1) % 3)].pressed.emit()
		for i in 10: await process_frame
		level.ui.buttons["character_%d" % index].pressed.emit()
		for i in 40: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/character_%d.png" % index)
	print("CHARACTER listo")
	level.queue_free()
	await process_frame
	quit()
