extends SceneTree
## The sheet of the offices' pieces made in code (spec_rediseno.md 5.1, area
## 4a): every sample of game/world/office/pieces/index.gd at its usual size,
## seen from the front right over a floor, with its name and size, in
## evidence/rediseno/piezas.png (and piezas.json). Needs a window:
##   godot --path . --script res://tools/capture/office_pieces_sheet.gd -- --automation --test-profile --silent
const OG := preload("res://game/world/office/office_geometry.gd")
const INDEX := preload("res://game/world/office/pieces/index.gd")
const CELL := 320
const COLUMNS := 8
const OUT := "res://evidence/rediseno/"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var builder = OG.new()
	var pieces: Array = INDEX.samples(builder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CELL, CELL)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.18, 0.18, 0.2)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.53, 0.5)
	environment.ambient_light_energy = 0.6
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	sun.shadow_enabled = true
	viewport.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.3, -2.2, 0)
	fill.light_energy = 0.35
	viewport.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 35.0
	viewport.add_child(camera)
	camera.current = true
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.3, 0.29, 0.27)
	ground_material.roughness = 0.9
	plane.material = ground_material
	ground.mesh = plane
	viewport.add_child(ground)
	var holder := MeshInstance3D.new()
	viewport.add_child(holder)
	var rows := ceili(pieces.size() / float(COLUMNS))
	var sheet := Image.create(COLUMNS * CELL, rows * CELL, false, Image.FORMAT_RGB8)
	var listing: Array = []
	for k in pieces.size():
		var title: String = pieces[k][0]
		var mesh: ArrayMesh = pieces[k][1]
		holder.mesh = mesh
		var box := mesh.get_aabb()
		var radius := maxf(box.size.length() * 0.5, 0.05)
		var centre := box.get_center()
		plane.size = Vector2.ONE * radius * 5.0
		ground.position = Vector3(centre.x, -0.001, centre.z)
		camera.position = centre + Vector3(0.45, 0.35, 1.0).normalized() * radius * 3.3
		camera.look_at(centre)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((k % COLUMNS) * CELL, (k / COLUMNS) * CELL))
		var size: Vector3 = mesh.get_meta("size")
		var surfaces: Array = []
		for s in mesh.get_surface_count(): surfaces.append(mesh.surface_get_name(s))
		listing.append({"name": title, "size": [size.x, size.y, size.z], "triangles": int(mesh.get_meta("triangles")), "surfaces": surfaces})
		print("PIECE %d %s (%.2f x %.2f x %.2f) %d tris" % [k, title, size.x, size.y, size.z, int(mesh.get_meta("triangles"))])
	# Each name and size over its cell.
	var canvas := SubViewport.new()
	canvas.size = sheet.get_size()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var backdrop := TextureRect.new()
	backdrop.texture = ImageTexture.create_from_image(sheet)
	canvas.add_child(backdrop)
	var font := ThemeDB.fallback_font
	for k in pieces.size():
		var size: Vector3 = pieces[k][1].get_meta("size")
		var label := Label.new()
		label.text = "%s\n%.2f x %.2f x %.2f" % [pieces[k][0], size.x, size.y, size.z]
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)
		label.position = Vector2((k % COLUMNS) * CELL + 8, (k / COLUMNS) * CELL + 6)
		canvas.add_child(label)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png(OUT + "piezas.png")
	var file := FileAccess.open(OUT + "piezas.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(listing, "\t"))
	print("PIECES ", pieces.size())
	builder.free()
	quit()
