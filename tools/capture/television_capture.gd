extends SceneTree
## The hotel's television as the trailer has it, in a room of the second
## planta: switched off, the moment it comes on (the line across the middle),
## on, from the side, from across the room with the light it throws, and up
## close; with the torch on, off and on; and a set in a room
## of the other kind (a suite's is a size smaller).
## Needs a window (it reads the rendered image), never --headless.
##
##   godot --path . --script tools/capture/television_capture.gd -- --test-profile
## Writes evidence/tv_<moment>.png.
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String, frames := 40) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/tv_%s.png" % name)
	print("SHOT ", name)

## The player up to `metres` from the set's screen, `side` radians round from
## its front, looking at the screen -- short of whatever is in the way, so the
## camera is never inside a wardrobe or behind a wall.
func stand(set: Node3D, metres: float, side := 0.0, height := 1.64) -> void:
	var front: Vector3 = set.global_basis.z.normalized().rotated(Vector3.UP, side)
	var target: Vector3 = set.screen_point()
	var from: Vector3 = target + front * 0.6
	var query := PhysicsRayQueryParameters3D.create(from, target + front * metres, 1 | 8)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	var reach: float = metres if hit.is_empty() else maxf(0.8, target.distance_to(hit.position) - 0.5)
	var at: Vector3 = target + front * reach
	at.y = set.global_position.y
	level.player.global_position = at
	level.player.eye_height = height
	var look := target - (at + Vector3(0, height, 0))
	level.player.rotation = Vector3(0, atan2(-look.x, -look.z), 0)
	level.player.camera.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
	level.player.snap_torch()

## The player's torch on or off, at its full strength.
func torch(lit: bool) -> void:
	level.player.torch.visible = lit
	level.player.torch.light_energy = level.player.torch_energy

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 30: await process_frame
	level.ui.finish_intro()
	level.settings.values.first_game_done = true
	await level.start_floor(81, false, [1], "equilibrada")
	level.locust.set_physics_process(false)
	level.locust.global_position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	for i in 120: await process_frame
	var sets: Array = level.televisions.filter(func(set): return set.stage == 2)
	var lounge: Node3D = sets[0]
	for set in sets:
		if is_equal_approx(set.scale.x, 1.0):
			lounge = set
			break
	stand(lounge, 3.0)
	await shot("apagada")
	torch(true)
	await shot("apagada_linterna")
	torch(false)
	lounge.set_on(true)
	lounge.opening = 0.12
	lounge.set_process(false)
	lounge.glow(1.0)
	await shot("encendiendo", 3)
	lounge.set_process(true)
	await shot("encendida", 60)
	stand(lounge, 2.4, 0.8)
	await shot("lado")
	stand(lounge, 5.5, 0.35, 1.64)
	await shot("sala")
	stand(lounge, 1.2, 0.0, 1.64)
	await shot("cerca")
	stand(lounge, 3.0)
	torch(true)
	await shot("encendida_linterna")
	torch(false)
	# Another set, in a room of another kind if there is one.
	for set in sets:
		if set != lounge and not is_equal_approx(set.scale.x, lounge.scale.x):
			set.set_on(true)
			stand(set, 3.0)
			await shot("suite", 60)
			break
	print("TV listo")
	level.queue_free()
	await process_frame
	quit()
