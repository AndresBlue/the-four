extends SceneTree
## Side-view contact sheet of The Locust's procedural gait at several speeds,
## plus wind-up and strike poses. Body is moved by script; no AI runs.
var locust
var frames: Array[Image] = []

func _initialize() -> void: run.call_deferred()

func grab() -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(480, 320)
	frames.append(image)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(960, 640))
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.22, 0.22, 0.25)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 1.0
	world.add_child(env)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 20)
	floor.mesh = plane
	var grid := StandardMaterial3D.new()
	grid.albedo_color = Color(0.35, 0.33, 0.3)
	floor.material_override = grid
	world.add_child(floor)
	# Ticks every metre show whether planted feet slide.
	for x in range(-10, 90):
		var tick := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.03, 0.01, 1.2)
		tick.mesh = box
		tick.position = Vector3(x, 0.005, 0)
		world.add_child(tick)
	locust = load("res://game/enemies/locust/locust.tscn").instantiate()
	world.add_child(locust)
	locust.rotation.y = -PI / 2
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 45
	var x := 0.0
	for speed in [1.6, 3.4, 5.4]:
		for i in 90:
			var delta := 1.0 / 60.0
			x += speed * delta
			locust.position = Vector3(x, 0, 0)
			locust.visual.move_velocity = Vector3(speed, 0, 0)
			locust.visual.aggression = 1.0 if speed > 5 else 0.0
			camera.position = Vector3(x + 0.4, 1.0, 3.4)
			camera.look_at(Vector3(x + 0.2, 0.9, 0))
			await process_frame
			if i in [60, 67, 74, 81]: await grab()
	locust.visual.move_velocity = Vector3.ZERO
	for i in 40:
		locust.visual.attack = minf(1.0, i / 30.0)
		await process_frame
	await grab()
	locust.visual.attack = 0.0
	locust.visual.recovering = 1.0
	for i in 12: await process_frame
	await grab()
	var sheet := Image.create(480 * 4, 320 * 4, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, 480, 320), Vector2i((i % 4) * 480, (i / 4) * 320))
	sheet.save_png("res://evidence/locust_gait.png")
	quit()
