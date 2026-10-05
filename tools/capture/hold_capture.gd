extends SceneTree
## What a held key looks like, and what a first game opens with: the ring
## round the aiming dot half way through a drawer, the opening scene's words
## and ring while it is being skipped, and the first floor's warning with its
## objective under it.
##
##   godot --path . --script tools/capture/hold_capture.gd -- --test-profile
## Writes evidence/hold_<moment>.png.
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/hold_%s.png" % name)

## The ring told `fraction` every frame for `frames` frames, on `which`.
func holding(which: String, fraction: float, frames: int) -> void:
	for i in frames:
		if which == "skip": level.ui.hold_skip(fraction)
		else: level.ui.hold(fraction)
		await process_frame

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 30: await process_frame
	level.ui.finish_intro()
	level.settings.values.first_game_done = false
	await level.start_floor(81, false, [1], "equilibrada")
	level.locust.set_physics_process(false)
	level.locust.global_position = Vector3(0, -80, 0)
	level.lifts.brief_wait = 0.0
	for i in 200: await process_frame
	await shot("primer_objetivo")
	await holding("hold", 0.6, 30)
	await shot("anillo")
	level.ui.show_skip(level.settings.prompt_name("interact"))
	await holding("skip", 0.45, 30)
	await shot("saltar")
	print("HOLD listo")
	level.queue_free()
	await process_frame
	quit()
