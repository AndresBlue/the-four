extends SceneTree
## What the game shows before it shows anything: the headphones notice on
## black, the VCR blue with PLAY, and the tape breaking up into the menu.
## One frame per beat, by the clock of the sequence itself.
##   godot --path . --script tools/capture/boot_capture.gd -- --silent
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/boot_%s.png" % name)
	print("SHOT ", name)

func wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until: await process_frame

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.play_intro()
	# 0.3 black, 0.45 fading up, 1.6 held, 0.45 fading out, 0.3 black.
	await wait(0.45)
	await shot("notice_in")
	await wait(1.2)
	await shot("notice")
	await wait(1.0)
	await shot("notice_out")
	await wait(0.7)
	await shot("blue")
	await wait(2.2)
	await shot("static")
	await wait(2.6)
	await shot("menu")
	# The screens with the smallest type on them, to see that the tape's grain
	# and colour bleed leave them readable.
	level.ui.show_settings("main")
	await wait(0.8)
	await shot("settings")
	level.ui.menu("multiplayer")
	await wait(0.8)
	await shot("multiplayer")
	print("BOOT listo")
	quit()
