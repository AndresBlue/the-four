extends SceneTree
## The blood on the lens (presentation/shaders/lens_blood.gdshaderinc), looked
## at by itself: the same drops the tape's filter draws, over a plain ground,
## at a row of seconds after the first of them lands -- on a light ground
## and on a dark one, with the camcorder upright and lying on its side.
##
##   godot --script res://tools/dev/lens_blood_look.gd -- [--seed=1.37] [--times=0.05,0.3,0.6,0.9,1.3]
##
## Writes evidence/lens_blood.png. Nothing of the game is loaded.
var times: Array = [0.05, 0.3, 0.6, 0.9, 1.3]
var seed_value := 1.37

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--times="):
			times = []
			for piece in argument.trim_prefix("--times=").split(","): times.append(float(piece))
		elif argument.begins_with("--seed="): seed_value = float(argument.trim_prefix("--seed="))
	var size := Vector2i(640, 360)
	DisplayServer.window_set_size(size)
	var material := ShaderMaterial.new()
	material.shader = load("res://tools/dev/lens_blood_look.gdshader")
	var page_rect := ColorRect.new()
	page_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	page_rect.material = material
	root.add_child(page_rect)
	material.set_shader_parameter("lens_seed", seed_value)
	material.set_shader_parameter("wide", float(size.x) / float(size.y))
	# Upright on a light ground and on a dark one; and lying on its side, as
	# it does on a floor (down is to one side of the picture, a little up it).
	var rows: Array = [[Vector3(0.92, 0.92, 0.9), Vector2(0.0, 1.0)], [Vector3(0.22, 0.2, 0.16), Vector2(0.0, 1.0)], [Vector3(0.92, 0.92, 0.9), Vector2(-0.93, 0.3)]]
	var page := Image.create(size.x * times.size(), size.y * rows.size(), false, Image.FORMAT_RGB8)
	for row in rows.size():
		material.set_shader_parameter("ground", rows[row][0])
		material.set_shader_parameter("lens_down", rows[row][1])
		for column in times.size():
			material.set_shader_parameter("lens_blood", float(times[column]))
			await process_frame
			await RenderingServer.frame_post_draw
			var shot: Image = root.get_texture().get_image()
			shot.convert(Image.FORMAT_RGB8)
			shot.resize(size.x, size.y, Image.INTERPOLATE_BILINEAR)
			page.blit_rect(shot, Rect2i(Vector2i.ZERO, size), Vector2i(size.x * column, size.y * row))
	page.save_png("res://evidence/lens_blood.png")
	print("LENS_BLOOD_SHEET res://evidence/lens_blood.png")
	quit()
