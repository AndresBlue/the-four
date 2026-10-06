extends SceneTree
## Puts the graphics presets of one benchmark view side by side, three to a
## row from the cheapest to the dearest, each labelled, to judge the
## differences by eye.
##   godot --path . --script res://tools/benchmarks/preset_sheet.gd -- --bench=res://evidence/bench/presets_forward_plus --view=room36 [--kind=vhs] [--crop=x,y,w,h]
## Reads <bench>/<view>_q<n>_<kind>.png (hotel_benchmark.gd) and writes
## <bench>/sheet_<view>_<kind>.png. With --crop, each panel is that rectangle
## of the 1920 × 1080 capture at full size instead of the whole frame.
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const PANEL := Vector2i(960, 540)
const COLUMNS := 3

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var bench := "res://evidence/bench/presets_forward_plus"
	var view := "room36"
	var kind := "vhs"
	var crop := Rect2i()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--bench="): bench = argument.trim_prefix("--bench=")
		if argument.begins_with("--view="): view = argument.trim_prefix("--view=")
		if argument.begins_with("--kind="): kind = argument.trim_prefix("--kind=")
		if argument.begins_with("--crop="):
			var parts := argument.trim_prefix("--crop=").split(",")
			crop = Rect2i(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]))
	var rows := ceili(float(PRESETS.ORDER.size()) / COLUMNS)
	var sheet := Image.create(PANEL.x * COLUMNS, PANEL.y * rows, false, Image.FORMAT_RGB8)
	var font := ThemeDB.fallback_font
	for place in PRESETS.ORDER.size():
		var quality: int = PRESETS.ORDER[place]
		var path := "%s/%s_q%d_%s.png" % [bench, view, quality, kind]
		if not FileAccess.file_exists(path):
			print("SHEET missing ", path)
			quit(1)
			return
		var image := Image.load_from_file(path)
		if crop.size != Vector2i.ZERO: image = image.get_region(crop)
		image.resize(PANEL.x, PANEL.y, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, PANEL), Vector2i(place % COLUMNS, place / COLUMNS) * PANEL)
	# The labels are drawn by a viewport over the finished sheet.
	var viewport := SubViewport.new()
	viewport.size = sheet.get_size()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var backdrop := TextureRect.new()
	backdrop.texture = ImageTexture.create_from_image(sheet)
	viewport.add_child(backdrop)
	for place in PRESETS.ORDER.size():
		var label := Label.new()
		label.text = PRESETS.NAMES[PRESETS.ORDER[place]].to_upper()
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 34)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 8)
		label.position = Vector2(Vector2i(place % COLUMNS, place / COLUMNS) * PANEL) + Vector2(18, 12)
		viewport.add_child(label)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var out := "%s/sheet_%s_%s%s.png" % [bench, view, kind, "_crop" if crop.size != Vector2i.ZERO else ""]
	viewport.get_texture().get_image().save_png(out)
	print("SHEET ", out)
	quit()
