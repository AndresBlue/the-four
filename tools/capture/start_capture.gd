extends SceneTree
## The start of a floor: the reception under its blinking red lamp
## (evidence/start_reception_*.png), on and off.
var level

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.player.camera.rotation.x = 0.45
	level.player.rotation.y += 0.6
	for phase in [["on", 0.3], ["off", 1.1]]:
		level.hotel.flicker_clock = phase[1] - 0.02
		level.hotel.update_visibility(level.player.position, true)
		for i in 30: await process_frame
		level.hotel.flicker_clock = phase[1]
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/start_reception_%s.png" % phase[0])
	paused = false
	level.queue_free()
	await process_frame
	quit()
