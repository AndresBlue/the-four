extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for index in 3:
		level.settings.set_value("character", index)
		level.ui.show_characters()
		for frame in 25: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/avatar_%d.png" % index)
	level.settings.set_value("character", 0)
	level.queue_free()
	await process_frame
	quit()
