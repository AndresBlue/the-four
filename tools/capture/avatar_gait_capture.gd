extends SceneTree
## Side-view contact sheet of a survivor's procedural gait: standing, walking,
## running, crouched still (one hand down), crouched moving and in the air.
## The body is moved by script, on a floor with a tick every metre, so a foot
## that slides shows up at once.
##
##   godot --path . --script tools/capture/avatar_gait_capture.gd -- --character=2
##
## Writes evidence/avatar_gait_<character>.png.
const AVATAR := preload("res://game/player/avatars/avatar_visual.gd")
var avatar: Node3D
var frames: Array[Image] = []
var character := 2

func _initialize() -> void: run.call_deferred()

func grab() -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(480, 320)
	frames.append(image)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--character="): character = int(argument.trim_prefix("--character="))
	DisplayServer.window_set_size(Vector2i(960, 640))
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.2, 0.23)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 1.0
	world.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.9, 0.7, 0.0)
	world.add_child(key)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 20)
	ground.mesh = plane
	var grid := StandardMaterial3D.new()
	grid.albedo_color = Color(0.32, 0.3, 0.28)
	ground.material_override = grid
	world.add_child(ground)
	# A tick every metre: a planted foot has to stay on one of them.
	for x in range(-10, 120):
		var tick := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.03, 0.01, 1.2)
		tick.mesh = box
		tick.position = Vector3(x, 0.005, 0)
		world.add_child(tick)
	var body := Node3D.new()
	world.add_child(body)
	avatar = AVATAR.new()
	avatar.character = character
	avatar.first_person = false
	body.add_child(avatar)
	# Facing the way it walks: forward is -Z, so +X needs a quarter turn back.
	body.rotation.y = -PI / 2
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 45
	# The bought models carry a camera of their own, and Godot makes the first
	# one it sees current: without this every frame was shot from the model's
	# camera, which is why the body looked the same from every angle.
	camera.current = true
	# Which way the body is really facing, measured instead of assumed: the
	# line between its hands is its own right, whatever the model was authored
	# along, and the camera stands off that so every shot is a profile.
	for i in 4:
		avatar.update_pose(Vector3.ZERO, false, 1.0 / 60.0, true)
		await process_frame
	var aside := Vector3.RIGHT
	if avatar.rig != null and avatar.bones.get("lh", -1) >= 0 and avatar.bones.get("rh", -1) >= 0:
		var left: Vector3 = avatar.rig.global_transform * avatar.rig.get_bone_global_pose(avatar.bones.lh).origin
		var right: Vector3 = avatar.rig.global_transform * avatar.rig.get_bone_global_pose(avatar.bones.rh).origin
		var across := right - left
		across.y = 0.0
		if across.length() > 0.05: aside = across.normalized()
	print("AVATAR_SIDE ", aside)
	var at := 0.0
	# Standing, walking, running: four frames of each, a step apart.
	for speed in [0.0, 3.4, 6.0]:
		for i in 110:
			var delta := 1.0 / 60.0
			at += speed * delta
			body.position = Vector3(at, 0, 0)
			avatar.update_pose(Vector3(speed, 0, 0) if speed > 0.0 else Vector3.ZERO, false, delta, true)
			camera.position = body.global_position + body.global_basis.x * 3.6 + Vector3(0, 1.1, 0)
			camera.look_at(body.global_position + Vector3(0, 0.95, 0))
			await process_frame
			if i in [80, 86, 92, 98]: await grab()
	# Crouched and still: the hand goes down. Then crouched and moving: it
	# comes up and the stride shortens.
	for i in 150:
		var delta := 1.0 / 60.0
		body.position = Vector3(at, 0, 0)
		avatar.update_pose(Vector3.ZERO, true, delta, true)
		camera.position = body.global_position + aside * 3.2 + Vector3(0, 0.9, 0)
		camera.look_at(body.global_position + Vector3(0, 0.6, 0))
		await process_frame
		if i in [60, 110]: await grab()
	for i in 150:
		var delta := 1.0 / 60.0
		at += 2.0 * delta
		body.position = Vector3(at, 0, 0)
		avatar.update_pose(Vector3(2.0, 0, 0), true, delta, true)
		camera.position = body.global_position + aside * 3.2 + Vector3(0, 0.9, 0)
		camera.look_at(body.global_position + Vector3(0, 0.6, 0))
		await process_frame
		if i in [100, 120]: await grab()
	# In the air: the legs let go of the ground and fold under the body.
	for i in 60:
		var delta := 1.0 / 60.0
		at += 3.0 * delta
		body.position = Vector3(at, 0.9, 0)
		avatar.update_pose(Vector3(3.0, 4.0, 0), false, delta, false)
		camera.position = body.global_position + aside * 3.6 + Vector3(0, 0.7, 0)
		camera.look_at(body.global_position + Vector3(0, 0.5, 0))
		await process_frame
		if i in [30, 50]: await grab()
	var sheet := Image.create(480 * 4, 320 * 4, false, Image.FORMAT_RGBA8)
	for i in mini(frames.size(), 16):
		sheet.blit_rect(frames[i], Rect2i(0, 0, 480, 320), Vector2i((i % 4) * 480, (i / 4) * 320))
	sheet.save_png("res://evidence/avatar_gait_%d.png" % character)
	print("AVATAR_GAIT ", frames.size(), " cuadros")
	quit()
