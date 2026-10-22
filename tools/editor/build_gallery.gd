extends SceneTree
## Rebuilds a disposable editor reference; does not change any generated game map.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const OUTPUT := "res://tools/workbenches/module_gallery.tscn"

func _initialize() -> void: build.call_deferred()

func own_tree(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		# Preview geometry must not run interaction scripts or create duplicate shapes.
		if child is Area3D: child.set_script(null)
		if child is MeshInstance3D or child is MultiMeshInstance3D:
			if String(child.name).begins_with("Mesh_ceiling"): child.visible = false
		own_tree(child, scene)

func build() -> void:
	var scene := Node3D.new()
	scene.name = "ModuleGallery_REFERENCE_ONLY"
	root.add_child(scene)
	var builder := GEOMETRY.new()
	scene.add_child(builder)
	builder.name = "Modules"
	builder.manifest = {"width": 1, "adjacency": [[]], "merged": []}
	# Modules stand alone here and are seen from outside: whole walls.
	builder.full_walls = true
	var hotel: GDScript = FLOOR.palette({})
	for type in hotel.TYPES.size():
		# The void (a cell a planta does not use) has nothing to show.
		if type == FLOOR.VOID: continue
		var props := []
		for slot in 4: props.append({"slot": slot, "kind": hotel.RECIPES[type][slot], "rotation": 0})
		var room := {"id": 0, "x": 0, "z": 0, "type": type, "height": 3.2, "span_x": 16.0, "span_z": 16.0, "hall": -1, "variant": type % 2, "layout": type % 4, "open_sides": [], "props": props}
		var module := Node3D.new()
		module.name = "%02d_%s" % [type, hotel.TYPES[type]]
		module.position = Vector3((type % 5) * 21, 0, int(type / 5) * 21)
		builder.add_child(module)
		builder.build_room(module, room)
		builder.text(module, hotel.NAMES[type], Vector3(0, 4.3, 0), 0, 64)
	# The editor reference uses ordinary editable meshes. Runtime MultiMesh buffers
	# cannot be read back from the dummy renderer used by a headless builder.
	for batch in builder.batches.values():
		for group in batch.groups:
			var transforms: Array = batch.groups[group]
			var material: String = GEOMETRY.material_of(group)
			var path := "res://game/presentation/materials/%s.tres" % material
			for index in transforms.size():
				var instance := MeshInstance3D.new()
				instance.name = "Mesh_%s_%d" % [group.replace("@", "-"), index]
				var mesh := GEOMETRY.unit_mesh(group)
				mesh.material = load(path) if ResourceLoader.exists(path) else builder.materials[material]
				instance.mesh = mesh
				instance.transform = transforms[index]
				batch.parent.add_child(instance)
	builder.batches.clear()
	# Save only baked nodes, never a second generator authority.
	builder.set_script(null)
	var world := WorldEnvironment.new()
	world.name = "PreviewLighting"
	world.environment = load("res://game/presentation/hotel_environment.tres").duplicate()
	world.environment.ambient_light_energy = 0.65
	world.environment.fog_enabled = false
	scene.add_child(world)
	var camera := Camera3D.new()
	camera.name = "PreviewCamera_RMB_WASD_QE"
	camera.far = 300
	camera.fov = 55.0
	camera.position = Vector3(42, 60, 94)
	scene.add_child(camera)
	camera.look_at(Vector3(42, 0, 32))
	camera.set_script(load("res://tools/editor/preview_camera.gd"))
	var canvas := CanvasLayer.new()
	canvas.name = "PreviewInstructions"
	scene.add_child(canvas)
	var label := Label.new()
	label.text = "TALLER · Referencia de 20 módulos · RMB + WASD: volar · Q/E: altura · Shift: acelerar\nTechos ocultos para inspección. Edita las recetas/materiales y regenera; esta galería no forma parte de la partida."
	label.position = Vector2(20, 18)
	canvas.add_child(label)
	own_tree(scene, scene)
	var packed := PackedScene.new()
	var error := packed.pack(scene)
	if error == OK: error = ResourceSaver.save(packed, OUTPUT)
	print("GALLERY_RESULT ", error, " modules=", FLOOR.palette({}).TYPES.size())
	scene.queue_free()
	await process_frame
	quit(error)
