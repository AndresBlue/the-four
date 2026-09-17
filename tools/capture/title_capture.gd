extends SceneTree
## Main menu over the title room (evidence/title_*.png) at a few moments of
## the camera drift, plus a close look at the doorway.
var level

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	var title = level.title_scene
	for moment in [0.0, 22.0, 48.0]:
		title.clock = moment
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/title_%d.png" % int(moment))
	level.on_action("multiplayer")
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/title_multiplayer.png")
	level.on_action("main")
	# Close-up of the gap without the menu.
	level.ui.overlay.hide()
	title.camera.fov = 20.0
	var aim: Vector3 = title.global_transform * (title.DOORWAY + Vector3(0.4, 1.9, 0.0))
	for i in 20:
		title.camera.look_at(aim)
		await process_frame
	title.set_process(false)
	title.camera.look_at(aim)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/title_doorway.png")
	# Straight on from the middle of the room, to check the pose.
	title.camera.fov = 45.0
	title.camera.global_position = title.global_transform * (title.DOORWAY + Vector3(-0.3, 1.7, 3.2))
	title.camera.look_at(aim)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/title_front.png")
	# The pose alone, without the set.
	title.builder.visible = false
	var lamp := OmniLight3D.new()
	lamp.light_energy = 6.0
	lamp.omni_range = 12.0
	title.add_child(lamp)
	lamp.global_position = title.camera.global_position
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/title_pose.png")
	level.queue_free()
	await process_frame
	quit()
