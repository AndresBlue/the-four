extends SceneTree
## The lamps' halo (presentation/camera/camcorder_effect.gd, the glare and the
## CCD's streak), looked at by itself: three lights in the dark -- a glint a
## pixel or two across, a bare bulb, a shade -- through the camcorder's HDR
## stage and nothing else: no lens, no tape, none of the game.
##
##   godot --script res://tools/dev/glare_look.gd -- [--name=glare_look]
##
## Writes evidence/<name>.png: the frame as it is, and under it the same
## lifted eight times, where the shape of a halo shows -- it is to be round
## and to fade away, with no edge and no bars in it. Needs a window (the
## stage runs on the RenderingDevice): not headless.
const EFFECT := preload("res://game/presentation/camera/camcorder_effect.gd")

func _initialize() -> void: run.call_deferred()

func light(at: Vector3, radius: float, energy: float, colour: Color) -> void:
	var ball := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	ball.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.BLACK
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = energy
	ball.material_override = material
	ball.position = at
	root.add_child(ball)

func run() -> void:
	var name := "glare_look"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--name="): name = argument.trim_prefix("--name=")
	var size := Vector2i(1280, 720)
	DisplayServer.window_set_size(size)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = environment
	var effect: CompositorEffect = EFFECT.new()
	var compositor := Compositor.new()
	compositor.compositor_effects = [effect]
	world.compositor = compositor
	root.add_child(world)
	var camera := Camera3D.new()
	camera.fov = 60.0
	root.add_child(camera)
	camera.make_current()
	# Four metres off: a glint (a clock's glass catching a lamp), a bulb and
	# a shade, each as bright as its kind is in the hotel's light.
	light(Vector3(-2.2, 0.5, -4.0), 0.004, 900.0, Color(1.0, 0.97, 0.9))
	light(Vector3(0.0, 0.5, -4.0), 0.03, 60.0, Color(1.0, 0.86, 0.62))
	light(Vector3(2.2, 0.4, -4.0), 0.22, 6.0, Color(1.0, 0.8, 0.55))
	for frame in 40: await process_frame
	await RenderingServer.frame_post_draw
	var shot: Image = root.get_texture().get_image()
	shot.convert(Image.FORMAT_RGB8)
	var page := Image.create(shot.get_width(), shot.get_height() * 2, false, Image.FORMAT_RGB8)
	page.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i.ZERO)
	for y in shot.get_height():
		for x in shot.get_width():
			var seen := shot.get_pixel(x, y)
			shot.set_pixel(x, y, Color(minf(seen.r * 8.0, 1.0), minf(seen.g * 8.0, 1.0), minf(seen.b * 8.0, 1.0)))
	page.blit_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i(0, shot.get_height()))
	page.save_png("res://evidence/%s.png" % name)
	print("GLARE_LOOK res://evidence/%s.png %s" % [name, shot.get_size()])
	effect.release()
	quit()
