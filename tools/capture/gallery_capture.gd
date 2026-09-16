extends SceneTree
func _initialize() -> void: capture.call_deferred()
func capture() -> void:
	var gallery: Node = load("res://tools/workbenches/module_gallery.tscn").instantiate()
	root.add_child(gallery)
	for frame in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/module_gallery.png")
	gallery.queue_free()
	await process_frame
	quit()
