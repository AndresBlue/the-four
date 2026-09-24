extends SceneTree
## The creature a mind going sees where it is not (game/app/phantom_sight.gd):
## its head round an open door, and standing at the end of a corridor, shot
## from where the game would show it, and the same spots from nearer to judge
## the pose. With a window (needs a renderer):
##   godot --path . --script res://tools/capture/phantom_capture.gd -- --test-profile --automation --silent
## Shots in evidence/phantom_*.png.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(filename: String, frames := 30) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/phantom_%s.png" % filename)
	print("CAPTURE evidence/phantom_%s.png" % filename)

## Looks at a point from where the player stands.
func face(point: Vector3) -> void:
	var camera: Camera3D = level.player.camera
	var towards := point - camera.global_position
	level.player.rotation.y = atan2(-towards.x, -towards.z)
	camera.rotation.x = atan2(towards.y, Vector2(towards.x, towards.z).length())

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	var seed_value := 81
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	await level.start_floor(seed_value)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	level.settings.values.quality = 2
	level.apply_settings()
	level.player.sanity = 20.0
	level.player.torch.visible = true
	var sight = level.sanity.ensure_sight()
	sight.set_physics_process(false)
	sight.ensure_model()
	var camera: Camera3D = level.player.camera
	var found := {}
	for room in level.manifest.rooms:
		if int(room.wing) != 0 or FLOOR.is_void(room) or level.off_limits_rooms().has(int(room.id)): continue
		for turn in 12:
			level.player.global_position = FLOOR.closest(level.get_world_3d().navigation_map, FLOOR.position_of(room)) + Vector3(0, 0.04, 0)
			level.player.rotation.y = TAU * turn / 12.0
			camera.rotation.x = 0.0
			if not sight.place(camera) or found.has(sight.kind): continue
			found[sight.kind] = {"position": level.player.global_position, "yaw": level.player.rotation.y, "model": sight.model.global_transform, "face": sight.face_point, "side": sight.lean_side}
			sight.kind = ""
		if found.size() == 2: break
	# A clear picture to judge the pose by: the tape frays with the mind.
	level.player.sanity = 100.0
	for kind in found:
		var spot: Dictionary = found[kind]
		sight.kind = kind
		sight.lean_side = spot.side
		sight.model.global_transform = spot.model
		sight.model.visible = true
		sight.seen_for = 1.0
		sight.pose(1.0)
		level.player.global_position = spot.position
		face(spot.face)
		await shot(kind)
		# And from nearer, on the same line of sight, to judge the pose.
		var towards: Vector3 = spot.face - camera.global_position
		var flat := Vector3(towards.x, 0, towards.z)
		level.player.global_position = spot.position + flat - flat.normalized() * 4.0
		face(spot.face)
		print("PHANTOM %s · cara %s · modelo %s · cabeza a la vista %s" % [kind, spot.face, spot.model.origin, sight.clear(camera.global_position, spot.face)])
		await shot(kind + "_cerca")
		sight.model.visible = false
		sight.kind = ""
	print("PHANTOM_SPOTS ", found.keys())
	paused = false
	level.queue_free()
	await process_frame
	quit()
