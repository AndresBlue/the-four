extends SceneTree
## The same view drawn through each upscaler, to compare what they rebuild:
## native, the plain stretch, FSR 1.0 and FSR 2.2, at a render scale.
##
##   godot --path . --script tools/capture/upscale_capture.gd -- [--seed=81] [--scale=0.6]
## Writes evidence/upscale_<mode>.png. Forward+ only: Compatibility has no FSR.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String, mode: int, scale: float) -> void:
	root.scaling_3d_mode = mode
	root.scaling_3d_scale = scale
	# Temporal upscalers need a few frames of history to settle.
	for i in 90: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/upscale_%s.png" % name)

func run() -> void:
	var seed_value := 81
	var scale := 0.6
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--scale="): scale = float(argument.trim_prefix("--scale="))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(seed_value)
	level.settings.values.quality = 2
	level.apply_settings()
	level.player.torch.visible = true
	for i in 120: await process_frame
	await shot("native", Viewport.SCALING_3D_MODE_BILINEAR, 1.0)
	await shot("bilinear", Viewport.SCALING_3D_MODE_BILINEAR, scale)
	await shot("fsr1", Viewport.SCALING_3D_MODE_FSR, scale)
	await shot("fsr2", Viewport.SCALING_3D_MODE_FSR2, scale)
	print("UPSCALE listo")
	quit()
