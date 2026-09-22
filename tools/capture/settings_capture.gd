extends SceneTree
## The settings screen, one picture per tab, at a given window size: to see
## that every row fits, reads and says what it does.
##
##   godot --path . --script tools/capture/settings_capture.gd -- [--size=1280x720]
## Writes evidence/settings_<tab>.png.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var size := Vector2i(1280, 720)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			size = Vector2i(int(parts[0]), int(parts[1]))
	DisplayServer.window_set_size(size)
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 30: await process_frame
	var tabs := ["imagen", "graficos", "controles", "audio"]
	for index in tabs.size():
		level.ui.show_settings("main")
		for i in 20: await process_frame
		var container: Array = level.ui.column.find_children("*", "TabContainer", true, false)
		if container.is_empty(): break
		container[0].current_tab = index
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/settings_%s.png" % tabs[index])
	print("SETTINGS listo")
	level.queue_free()
	await process_frame
	quit()
