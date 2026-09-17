extends SceneTree
## Frames of the opening scene at key moments (evidence/intro_*.png).
const MOMENTS := [5.5, 12.0, 21.5, 24.5, 26.6, 29.5, 33.0, 34.2, 36.0, 37.9, 38.6]
var level

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.settings.values.quality = 2
	level.apply_settings()
	level.start_intro(81)
	var intro = level.intro
	intro.speed = 2.0
	for moment in MOMENTS:
		while intro.time < moment: await process_frame
		intro.speed = 0.0
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/intro_%04.1f.png" % moment)
		intro.speed = 2.0
	intro.speed = 0.0
	level.queue_free()
	await process_frame
	quit()
