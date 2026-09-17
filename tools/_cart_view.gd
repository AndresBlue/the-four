extends SceneTree
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -50, 0)
	level.settings.values.quality = 2
	level.apply_settings()
	var count := 0
	for room in level.manifest.rooms:
		if room.type not in [7, 9]: continue
		var node: Node3D = level.hotel.room_nodes[room.id]
		for prop in node.get_children():
			if not String(prop.name).ends_with("_cart"): continue
			var cart: Vector3 = prop.global_position
			var from := cart + (FLOOR.position_of(room) - cart).normalized() * 3.2
			level.player.position = from + Vector3(0, 0.04, 0)
			var d := cart - from
			level.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
			level.player.camera.rotation = Vector3(-0.3, 0, 0)
			level.hotel.update_visibility(level.player.position, true)
			for i in 60: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/cart_view_%d.png" % count)
			count += 1
			break
		if count >= 2: break
	quit()
