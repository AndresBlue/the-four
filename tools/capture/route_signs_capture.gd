extends SceneTree
## The corridors' way-out signs (exit_route_signs.gd), each shot from both
## sides from where somebody walking up to it would read it, on the first
## planta. With a window (needs a renderer):
##   godot --path . --script res://tools/capture/route_signs_capture.gd -- --test-profile --automation --silent [--seed=81]
## Shots in evidence/route_sign_<n>_<front|back>.png.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const WAYS := ["delante", "izquierda", "derecha", "atras"]
var level

func _initialize() -> void: run.call_deferred()

func shot(filename: String) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/route_sign_%s.png" % filename)
	print("CAPTURE evidence/route_sign_%s.png" % filename)

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
	var n := 0
	for sign in level.hotel.route_signs:
		if int(sign.planta) != 0: continue
		var at: Vector3 = sign.position
		var normal := Vector3(float(sign.normal.x), 0, float(sign.normal.y))
		for side in [["front", 1.0, int(sign.front)], ["back", -1.0, int(sign.back)]]:
			# As far as 6 m back along the way it faces, short of any wall.
			var ray := PhysicsRayQueryParameters3D.create(at, at + normal * float(side[1]) * 6.0, 1)
			var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(ray)
			var back_off: float = 6.0 if hit.is_empty() else maxf(1.5, at.distance_to(hit.position) - 0.6)
			var stand: Vector3 = at + normal * float(side[1]) * back_off
			stand.y = FLOOR.planta_y(0) + 0.04
			level.player.position = stand
			face(at)
			print("SIGN %d %s: dice %s" % [n, side[0], WAYS[int(side[2])]])
			await shot("%d_%s" % [n, side[0]])
		n += 1
	level.queue_free()
	await process_frame
	quit()
