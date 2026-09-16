extends SceneTree

var scene: Node3D
var wall: StandardMaterial3D
var trim: StandardMaterial3D
var dark: StandardMaterial3D

func material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func attach(parent: Node, node: Node) -> void:
	parent.add_child(node)
	node.owner = scene

func box(parent: Node3D, label: String, pos: Vector3, size: Vector3, mat: Material, solid := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	mesh.material_override = mat
	mesh.position = pos
	attach(parent, mesh)
	if solid:
		var body := StaticBody3D.new()
		attach(mesh, body)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = size
		attach(body, shape)
	return mesh

func wall_segment(pos: Vector3, size: Vector3) -> void:
	box(scene, "Wall", pos, size, wall)
	box(scene, "Skirting", Vector3(pos.x, 0.11, pos.z), Vector3(size.x + 0.025, 0.22, size.z + 0.025), trim, false)
	box(scene, "Cornice", Vector3(pos.x, 3.52, pos.z), Vector3(size.x + 0.06, 0.09, size.z + 0.06), trim, false)

func sign_text(words: String, pos: Vector3, angle := 0.0, font_size := 52, color := Color(0.15, 0.16, 0.11)) -> void:
	var label := Label3D.new()
	label.text = words
	label.position = pos
	label.rotation.y = angle
	label.font_size = font_size
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 0
	attach(scene, label)

func ceiling_light(pos: Vector3, color: Color, power: float) -> void:
	box(scene, "Fixture", pos, Vector3(1.9, 0.11, 0.65), trim, false)
	box(scene, "Diffuser", pos - Vector3(0, 0.065, 0), Vector3(1.7, 0.03, 0.47), material(color, 2.0), false)
	var light := OmniLight3D.new()
	light.position = pos - Vector3(0, 0.28, 0)
	light.light_color = color
	light.light_energy = power
	light.omni_range = 8.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = true
	attach(scene, light)

func ellipsoid(parent: Node3D, pos: Vector3, dimensions: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.mesh.radial_segments = 20
	mesh.mesh.rings = 12
	mesh.position = pos
	mesh.scale = dimensions
	mesh.material_override = mat
	attach(parent, mesh)

func limb(parent: Node3D, from: Vector3, to: Vector3, radius: float, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = CylinderMesh.new()
	mesh.mesh.top_radius = radius * 0.7
	mesh.mesh.bottom_radius = radius
	mesh.mesh.height = from.distance_to(to)
	mesh.mesh.radial_segments = 12
	mesh.position = (from + to) * 0.5
	mesh.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	mesh.material_override = mat
	attach(parent, mesh)

func make_enemy() -> void:
	var enemy := Node3D.new()
	enemy.name = "Enemy"
	enemy.position = Vector3(0, 0, -12)
	attach(scene, enemy)
	var imported_path := "res://assets/enemies/locust.glb"
	if ResourceLoader.exists(imported_path):
		var imported: Node3D = load(imported_path).instantiate()
		imported.name = "ImportedLocust"
		imported.scale = Vector3.ONE * 1.9
		imported.position = Vector3(0, -0.0045, -0.27)
		imported.set_script(load("res://game/enemies/locust/locust_visual.gd"))
		attach(enemy, imported)
	else:
		var skin := material(Color(0.055, 0.041, 0.031))
		var face := material(Color(0.51, 0.43, 0.29))
		var eye := material(Color(0.86, 0.85, 0.63), 0.5)
		ellipsoid(enemy, Vector3(0, 1.82, 0), Vector3(0.55, 0.75, 0.3), skin)
		ellipsoid(enemy, Vector3(0, 2.61, 0.02), Vector3(0.52, 0.52, 0.30), face)
		ellipsoid(enemy, Vector3(0, 2.45, 0.25), Vector3(0.30, 0.31, 0.08), dark)
		for side in [-1, 1]:
			ellipsoid(enemy, Vector3(side * 0.135, 2.68, 0.265), Vector3(0.13, 0.115, 0.065), dark)
			ellipsoid(enemy, Vector3(side * 0.135, 2.69, 0.297), Vector3(0.037, 0.044, 0.025), eye)
			limb(enemy, Vector3(side * 0.14, 1.46, 0), Vector3(side * 0.29, 0.72, 0.13), 0.08, skin)
			limb(enemy, Vector3(side * 0.29, 0.72, 0.13), Vector3(side * 0.4, 0.08, 0.05), 0.05, skin)
			ellipsoid(enemy, Vector3(side * 0.4, 0.06, 0.11), Vector3(0.16, 0.10, 0.38), skin)
			limb(enemy, Vector3(side * 0.25, 2.03, 0), Vector3(side * 0.65, 1.32, 0.02), 0.065, skin)
			limb(enemy, Vector3(side * 0.65, 1.32, 0.02), Vector3(side * 0.82, 0.64, 0.21), 0.047, skin)
			for finger in range(3):
				limb(enemy, Vector3(side * (0.78 + finger * 0.05), 0.65, 0.2), Vector3(side * (0.81 + finger * 0.075), 0.37, 0.28), 0.014, skin)
	var body := StaticBody3D.new()
	body.name = "StaticCollision"
	attach(enemy, body)
	var collider := CollisionShape3D.new()
	collider.shape = CapsuleShape3D.new()
	collider.shape.radius = 0.65
	collider.shape.height = 2.9
	collider.position.y = 1.45
	attach(body, collider)
	enemy.set_meta("ai_enabled", false)
	enemy.set_meta("asset_status", "placeholder" if not ResourceLoader.exists(imported_path) else "imported")

func ui_label(parent: Node, label_name: String, words: String, pos: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = words
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	attach(parent, label)
	return label

func _initialize() -> void:
	scene = Node3D.new()
	scene.name = "TheFour"
	scene.set_script(load("res://legacy/fuse_prototype/scripts/main.gd"))
	wall = material(Color(0.48, 0.44, 0.25))
	trim = material(Color(0.23, 0.22, 0.14))
	dark = material(Color(0.008, 0.007, 0.006))
	var floor_mat := material(Color(0.25, 0.23, 0.155))
	box(scene, "Floor", Vector3(0, -0.15, -2), Vector3(24, 0.3, 32), floor_mat)
	box(scene, "Ceiling", Vector3(0, 3.75, -2), Vector3(24, 0.25, 32), material(Color(0.39, 0.38, 0.29)))
	wall_segment(Vector3(-12, 1.8, -2), Vector3(0.25, 3.6, 32))
	wall_segment(Vector3(12, 1.8, -2), Vector3(0.25, 3.6, 32))
	wall_segment(Vector3(0, 1.8, 14), Vector3(24, 3.6, 0.25))
	wall_segment(Vector3(0, 1.8, -18), Vector3(24, 3.6, 0.25))
	# Open doorways connect a 7 m central corridor to four side rooms.
	for side in [-1, 1]:
		for segment in [[11.0, 6.0], [1.0, 8.0], [-12.0, 12.0]]:
			wall_segment(Vector3(side * 3.5, 1.8, segment[0]), Vector3(0.22, 3.6, segment[1]))
		for doorway in [6.5, -4.5]:
			wall_segment(Vector3(side * 3.5, 3.18, doorway), Vector3(0.25, 0.84, 3.0))
		wall_segment(Vector3(side * 7.75, 1.8, 0), Vector3(8.5, 3.6, 0.22))
		for z in [-13.0, 4.0, 10.0]:
			wall_segment(Vector3(side * 8, 1.8, z), Vector3(0.7, 3.6, 0.7))
	# Ceiling tile seams establish scale without external textures.
	for z in range(-17, 15, 2):
		box(scene, "CeilingGrid", Vector3(0, 3.612, z), Vector3(24, 0.025, 0.028), trim, false)
	for x in range(-11, 13, 2):
		box(scene, "CeilingGrid", Vector3(x, 3.612, -2), Vector3(0.025, 0.025, 32), trim, false)
	for z in [10, 3, -4, -11, -16]:
		ceiling_light(Vector3(0, 3.52, z), Color(1, 0.88, 0.61), 1.2)
	for x in [-7.0, 7.0]:
		for z in [8.0, -7.0]:
			ceiling_light(Vector3(x, 3.52, z), Color(0.93, 0.91, 0.72), 0.9)
	# Closed service door and numbered observation bay.
	box(scene, "ServiceDoor", Vector3(8, 1.35, -17.83), Vector3(1.7, 2.7, 0.12), material(Color(0.18, 0.22, 0.20)))
	box(scene, "DoorHandle", Vector3(8.55, 1.18, -17.72), Vector3(0.05, 0.25, 0.05), material(Color(0.6, 0.58, 0.46)), false)
	sign_text("01", Vector3(0, 2.6, -17.83), 0, 180)
	sign_text("OBSERVACIÓN", Vector3(0, 1.7, -17.82), 0, 34)
	sign_text("SERVICIO", Vector3(8, 2.95, -17.72), 0, 26)
	sign_text("THE FOUR  /  NIVEL 01", Vector3(0, 2.55, 13.83), PI, 58)
	for side in [-1, 1]:
		sign_text("SALA " + ("A" if side < 0 else "B"), Vector3(side * 3.36, 2.72, 4.5), -side * PI / 2, 34)
	# Low rail around the static specimen, open at the front.
	for side in [-1, 1]:
		box(scene, "SpecimenRail", Vector3(side * 1.7, 0.45, -12.1), Vector3(0.065, 0.065, 3), trim)
		for z in [-10.6, -13.6]:
			box(scene, "RailPost", Vector3(side * 1.7, 0.22, z), Vector3(0.08, 0.44, 0.08), trim)
	make_enemy()
	var environment_node := WorldEnvironment.new()
	environment_node.environment = Environment.new()
	environment_node.environment.background_mode = Environment.BG_COLOR
	environment_node.environment.background_color = Color(0.025, 0.025, 0.018)
	environment_node.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_node.environment.ambient_light_color = Color(0.63, 0.59, 0.43)
	environment_node.environment.ambient_light_energy = 0.32
	environment_node.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	attach(scene, environment_node)
	var player := CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 0.05, 9)
	player.set_script(load("res://legacy/fuse_prototype/scripts/player.gd"))
	attach(scene, player)
	var collision := CollisionShape3D.new()
	collision.shape = CapsuleShape3D.new()
	collision.shape.radius = 0.28
	collision.shape.height = 1.75
	collision.position.y = 0.875
	attach(player, collision)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.63
	camera.fov = 78
	camera.current = true
	attach(player, camera)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	attach(scene, hud)
	var cream := Color(0.88, 0.87, 0.77)
	ui_label(hud, "Title", "T H E   F O U R", Vector2(38, 29), 26, cream)
	ui_label(hud, "Subtitle", "PRUEBA DE SUPERVIVENCIA   /   0.2", Vector2(40, 67), 12, Color(0.65, 0.66, 0.56))
	ui_label(hud, "Status", "PISO 01   /   ACCESO", Vector2(1000, 35), 14, cream)
	ui_label(hud, "Crosshair", "·", Vector2(635, 342), 22, Color(0.9, 0.9, 0.8, 0.65))
	ui_label(hud, "Hint", "", Vector2(38, 674), 13, cream)
	ui_label(hud, "Specimen", "01 / THE LOCUST\nESTÁTICO · MODELO DE DOUMTY", Vector2(38, 610), 13, Color(0.7, 0.70, 0.57))
	ui_label(hud, "MusicStatus", "", Vector2(860, 636), 12, Color(0.7, 0.70, 0.57))
	var music := AudioStreamPlayer.new()
	music.name = "Music"
	music.stream = load("res://assets/audio/the_four_theme.mp3")
	music.set_script(load("res://legacy/fuse_prototype/scripts/music.gd"))
	attach(scene, music)
	var packed := PackedScene.new()
	packed.pack(scene)
	var result := ResourceSaver.save(packed, "res://legacy/fuse_prototype/main.tscn")
	print("SCENE_BUILD=", result)
	scene.free()
	quit(result)
