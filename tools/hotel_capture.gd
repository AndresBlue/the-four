extends SceneTree
func _initialize() -> void: run.call_deferred()
func save_image(filename: String) -> void:
	for frame in 25: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/" + filename)
func run() -> void:
	var level = load("res://scenes/hotel.tscn").instantiate()
	root.add_child(level)
	await save_image("hotel_final_menu.png")
	await level.start_floor(81)
	for room in level.manifest.rooms:
		if room.type == 1:
			level.player.position = Vector3(room.x * 12, 0.04, room.z * 12 - 4.35)
			level.player.rotation.y = PI / 2
			level.player.camera.look_at(Vector3(room.x * 12 - 4.35, 0.7, room.z * 12 - 4.35))
			await save_image("hotel_final_bedroom.png")
			break
	level.session.pause()
	level.ui.show_settings("pause")
	await save_image("hotel_final_settings.png")
	level.session.set_state(level.session.State.PLAYING)
	var exit_room: Dictionary = level.manifest.rooms[level.manifest.exit]
	level.player.position = Vector3(exit_room.x * 12, 0.04, exit_room.z * 12 + 1.5)
	level.player.rotation.y = 0
	await save_image("hotel_final_refuge.png")
	paused = false
	level.queue_free()
	await process_frame
	quit()
