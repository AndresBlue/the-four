extends SceneTree
## A sheet of every baked model in assets/props/hotel/ (build_catalogue.gd),
## each seen from its front (+Z) and a little from the right and above, with
## its size: evidence/catalogue_sheet.png. Checks that fronts face +Z and that
## sizes are real. Needs a window.
##   godot --path . --script res://tools/props/catalogue_sheet.gd
const TARGET := "res://assets/props/hotel/"
const CELL := 256
const COLUMNS := 8

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var names: Array = []
	for file in DirAccess.get_files_at(TARGET):
		if file.ends_with(".res"): names.append(file.get_basename())
	names.sort()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(CELL, CELL)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.18, 0.18, 0.2)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.5, 0.5)
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.5, 0)
	viewport.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 35.0
	viewport.add_child(camera)
	var holder := MeshInstance3D.new()
	viewport.add_child(holder)
	var rows := ceili(names.size() / float(COLUMNS))
	var sheet := Image.create(COLUMNS * CELL, rows * CELL, false, Image.FORMAT_RGB8)
	for k in names.size():
		var mesh: Mesh = load(TARGET + names[k] + ".res")
		holder.mesh = mesh
		var box := mesh.get_aabb()
		var radius := box.size.length() * 0.5
		var centre := box.get_center()
		camera.position = centre + Vector3(0.45, 0.35, 1.0).normalized() * radius * 3.3
		camera.look_at(centre)
		for frame in 4: await process_frame
		await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i((k % COLUMNS) * CELL, (k / COLUMNS) * CELL))
		print("SHEET %d %s (%.2f x %.2f x %.2f)" % [k, names[k], box.size.x, box.size.y, box.size.z])
	sheet.save_png("res://evidence/catalogue_sheet.png")
	quit()
