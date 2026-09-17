extends SceneTree
## Screenshots of every menu screen, the intro and the in-game HUD.
## Usage after "--": --prefix=name
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
var prefix := "ui"

func _initialize() -> void: run.call_deferred()

func shot(filename: String, frames := 30) -> void:
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/%s_%s.png" % [prefix, filename])

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="): prefix = argument.trim_prefix("--prefix=")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.ui.play_intro()
	await shot("intro_notice", 90)
	await shot("intro_play", 150)
	level.ui.finish_intro()
	await shot("main", 60)
	level.on_action("characters")
	await shot("characters", 60)
	level.on_action("credits")
	await shot("credits")
	level.ui.show_settings("main")
	await shot("settings")
	level.ui.menu("loading")
	await shot("loading")
	level.on_action("main")
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -50, 0)
	# In-game HUD: flash message, spent stamina and focus on a door.
	var door = level.hotel.doors.filter(func(d): return not d.opened)[0]
	var across: Vector3 = door.global_basis.z.normalized()
	level.player.position = door.doorway + across * 1.5 + Vector3(0, 0.04, 0)
	level.player.rotation = Vector3(0, atan2(across.x, across.z), 0)
	level.player.camera.rotation = Vector3(-0.1, 0, 0)
	level.player.stamina = 45
	level.player.torch.visible = true
	await shot("hud", 45)
	level.session.pause()
	await shot("pause")
	level.session.set_state(level.session.State.PLAYING)
	level.session.elapsed = 754
	level.session.capture(1)
	await shot("failed")
	level.session.set_state(level.session.State.WON)
	await shot("won")
	paused = false
	level.queue_free()
	await process_frame
	quit()
