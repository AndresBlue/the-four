extends SceneTree
## Contact sheets of look-dev shots (tools/capture/lookdev_capture.gd).
##   godot --path . --script res://tools/capture/lookdev_sheet.gd -- --dirs=res://evidence/lookdev/base_q2[,res://evidence/lookdev/x_q2] [--kind=raw] [--out=path.png]
## One folder: every shot in a grid of three. Several: one row per shot and one
## column per folder (before / after, now / reference), each labelled with its
## folder name. Shots missing from a folder are left black.
const SHOTS := ["recepcion", "dormitorio", "salon", "pasillo", "bano", "servicio", "oscura"]
const PANEL := Vector2i(640, 360)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var dirs := PackedStringArray()
	var kind := "raw"
	var out := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--dirs="): dirs = argument.trim_prefix("--dirs=").split(",")
		if argument.begins_with("--kind="): kind = argument.trim_prefix("--kind=")
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
	if dirs.is_empty():
		print("SHEET needs --dirs")
		quit(1)
		return
	if out.is_empty(): out = dirs[dirs.size() - 1] + "/sheet_%s.png" % kind
	# Panels: [image path, label, cell].
	var panels: Array = []
	var cells := Vector2i()
	if dirs.size() == 1:
		cells = Vector2i(3, int(ceil(SHOTS.size() / 3.0)))
		for i in SHOTS.size(): panels.append(["%s/%s_%s.png" % [dirs[0], SHOTS[i], kind], SHOTS[i], Vector2i(i % 3, i / 3)])
	else:
		cells = Vector2i(dirs.size(), SHOTS.size())
		for row in SHOTS.size():
			for column in dirs.size():
				panels.append(["%s/%s_%s.png" % [dirs[column], SHOTS[row], kind], "%s · %s" % [dirs[column].get_file(), SHOTS[row]], Vector2i(column, row)])
	var sheet := Image.create(PANEL.x * cells.x, PANEL.y * cells.y, false, Image.FORMAT_RGB8)
	for panel in panels:
		if not FileAccess.file_exists(panel[0]): continue
		var image := Image.load_from_file(panel[0])
		image.resize(PANEL.x, PANEL.y, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, PANEL), panel[2] * PANEL)
	var viewport := SubViewport.new()
	viewport.size = sheet.get_size()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var backdrop := TextureRect.new()
	backdrop.texture = ImageTexture.create_from_image(sheet)
	viewport.add_child(backdrop)
	for panel in panels:
		var label := Label.new()
		label.text = panel[1].to_upper()
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 6)
		label.position = Vector2(panel[2] * PANEL) + Vector2(10, 6)
		viewport.add_child(label)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(out)
	print("SHEET ", out)
	quit()
