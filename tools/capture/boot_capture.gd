extends SceneTree
## What the game shows before it shows anything: the headphones notice on
## black, the deck's blue with PLAY in 4:3, the snow of the blank tape, the
## picture found in slanted bands, and the menu. One frame per beat, by where
## the sequence itself has got to (hotel_ui.play_intro), into evidence/vhs/.
##   godot --path . --script tools/capture/boot_capture.gd -- --test-profile --silent
var level
var look: ShaderMaterial

func _initialize() -> void: run.call_deferred()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/vhs/boot_%s.png" % name)
	print("SHOT ", name)

func wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until: await process_frame

## What the tape's filter over the boot has a term at, 0 once the boot is over.
func term(key: String) -> float:
	return float(look.get_shader_parameter(key)) if is_instance_valid(level.ui.intro) and look.get_shader_parameter(key) != null else 0.0

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/vhs"))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.play_intro()
	var deck: ColorRect = level.ui.intro.get_node("Deck")
	look = deck.material
	await wait(1.4)
	await shot("1_notice")
	while not deck.visible or level.ui.intro.get_node("Tape").modulate.a < 1.0: await process_frame
	await wait(0.8)
	await shot("2_blue")
	await wait(0.5)
	await shot("2_blue_b")
	while term("signal_loss") < 0.99: await process_frame
	await wait(0.2)
	await shot("3_snow")
	await shot("3_snow_b")
	await shot("3_snow_c")
	while term("entry") <= 0.0: await process_frame
	for step in [[0.92, "a"], [0.74, "b"], [0.56, "c"], [0.38, "d"], [0.2, "e"], [0.07, "f"]]:
		while term("entry") > step[0]: await process_frame
		await shot("4_entry_" + step[1])
	await shot("5_settled")
	while is_instance_valid(level.ui.intro): await process_frame
	await wait(0.4)
	await shot("6_menu")
	# The screens with the smallest type on them, to see them in the tape's
	# own lettering.
	level.ui.show_settings("main")
	await wait(0.8)
	await shot("7_settings")
	level.ui.menu("multiplayer")
	await wait(0.8)
	await shot("8_multiplayer")
	print("BOOT listo")
	quit()
