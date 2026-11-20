extends SceneTree
## Frames of the opening scene at key moments (evidence/intro_*.png), or at
## those given: -- --moments=18.5,20,21.5 [--prefix=intro_revela].
const MOMENTS := [5.5, 12.0, 17.0, 21.0, 23.0, 26.1, 26.38, 30.3, 31.7, 33.4, 33.7, 35.5, 37.4, 38.75, 39.3]
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
	var moments: Array = MOMENTS
	var prefix := "intro"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--moments="): moments = Array(argument.trim_prefix("--moments=").split(",")).map(func(m): return float(m))
		if argument.begins_with("--prefix="): prefix = argument.trim_prefix("--prefix=")
	intro.speed = 2.0
	for moment in moments:
		while intro.time < moment: await process_frame
		intro.speed = 0.0
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://evidence/%s_%04.1f.png" % [prefix, moment])
		intro.speed = 2.0
	intro.speed = 0.0
	level.queue_free()
	await process_frame
	quit()
