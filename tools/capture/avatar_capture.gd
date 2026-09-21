extends SceneTree
## The three survivors as they are drawn in the game, standing in a plain lit
## room: the whole body and the face, one picture each, to look at their
## materials -- eyes, hair, skin -- without the tape over them.
##
##   godot --path . --script tools/capture/avatar_capture.gd
## Writes evidence/avatar_<id>_body.png and evidence/avatar_<id>_face.png.
const AVATAR := preload("res://game/player/avatars/avatar_visual.tscn")
const IDS := ["detective", "detective_woman", "realistic_female"]

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.msaa_3d = Viewport.MSAA_4X
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	var world := Node3D.new()
	root.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.16, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.5, 0.52)
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var holder := WorldEnvironment.new()
	holder.environment = environment
	world.add_child(holder)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 150, 0)
	key.light_energy = 1.6
	key.shadow_enabled = true
	world.add_child(key)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1.5, 1.7, -1.8)
	fill.omni_range = 6.0
	fill.light_energy = 1.2
	world.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = 40
	world.add_child(camera)
	camera.current = true
	for index in IDS.size():
		var avatar = AVATAR.instantiate()
		avatar.character = index
		world.add_child(avatar)
		for i in 8: await process_frame
		camera.position = Vector3(0, 0.95, -2.7)
		camera.look_at(Vector3(0, 0.95, 0))
		await shot("%s_body" % IDS[index])
		camera.position = Vector3(0, 1.6, -0.55)
		camera.look_at(Vector3(0, 1.58, 0))
		await shot("%s_face" % IDS[index])
		avatar.queue_free()
		await process_frame
	print("AVATAR listo")
	quit()

func shot(name: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/avatar_%s.png" % name)
