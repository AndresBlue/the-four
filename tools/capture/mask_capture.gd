extends SceneTree
## The Locust's mask as the camcorder sees it from very close
## (evidence/mask_*.png): the lens put straight in front of the mask at a few
## distances, through the whole picture -- camera stage, lens and tape -- to
## decide how near the face of a capture can be held before the model and its
## texture give out.
var level

func _initialize() -> void: run.call_deferred()

## The mask in the head bone's space (tools/dev/mask_probe.gd).
const MASK_CENTRE := Vector3(-0.0014, 0.079, 0.0358)

func mask_frame() -> Transform3D:
	var visual = level.locust.visual
	var head: Transform3D = visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(int(visual.bones["Head1"]))
	var origin: Vector3 = head * MASK_CENTRE
	# Facing: the bone's +Z; up: its +Y.
	return Transform3D(Basis(head.basis.x.normalized(), head.basis.y.normalized(), head.basis.z.normalized()), origin)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(81)
	level.player.set_physics_process(false)
	level.player.handheld_enabled = false
	var spot := Vector3(0, 0.04, 0)
	level.player.global_position = spot
	level.locust.global_position = spot + Vector3(0, 0.04, -1.6)
	level.locust.rotation.y = PI
	level.locust.grace = 999.0
	var lit := not OS.get_cmdline_user_args().has("--dark")
	if lit:
		var lamp := OmniLight3D.new()
		lamp.light_energy = 2.0
		lamp.omni_range = 9.0
		lamp.position = spot + Vector3(1.5, 2.6, 0.5)
		level.add_child(lamp)
	for i in 30: await process_frame
	var camera: Camera3D = level.player.camera
	camera.top_level = true
	var taken: Array = []
	for distance in [1.5, 0.6, 0.3, 0.2, 0.15, 0.12]:
		var mask := mask_frame()
		var eye: Vector3 = mask.origin + mask.basis.z * distance
		camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(mask.origin, Vector3.UP)
		level.camera_cut()
		for i in 20:
			await process_frame
			mask = mask_frame()
			eye = mask.origin + mask.basis.z * distance
			camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(mask.origin, Vector3.UP)
		await RenderingServer.frame_post_draw
		var name := "mask_%s%03d" % ["" if lit else "dark_", int(round(distance * 100.0))]
		root.get_texture().get_image().save_png("res://evidence/%s.png" % name)
		taken.append(name)
	print("MASK_SHOTS ", taken, " mask=", mask_frame())
	level.queue_free()
	await process_frame
	quit()
