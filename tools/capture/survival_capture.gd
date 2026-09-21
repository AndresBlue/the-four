extends SceneTree
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
func _initialize() -> void: run.call_deferred()
func shot(filename: String) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/" + filename + ".png")
func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	# The tape screen plays over everything for its first seconds and these
	# shots are about what is behind it.
	level.ui.finish_intro()
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	var bounds := AABB()
	for mesh in level.locust.visual.find_children("*", "MeshInstance3D", true, false):
		var local_box: AABB = level.locust.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = bounds.merge(local_box)
	print("LOCUST_BOUNDS ",bounds)
	level.settings.values.quality = 2
	level.apply_settings()
	for edge in level.manifest.merged:
		var a: Dictionary = level.manifest.rooms[edge[0]]
		var b: Dictionary = level.manifest.rooms[edge[1]]
		level.player.position = FLOOR.position_of(a) + Vector3(0, 0.04, 0)
		var d: Vector3 = FLOOR.position_of(b) - level.player.position
		level.player.rotation.y = atan2(-d.x, -d.z)
		level.player.camera.rotation = Vector3.ZERO
		await shot("upgrade_grand_salon")
		break
	for room in level.manifest.rooms:
		var sides: Array = room.get("open_sides", [])
		if sides.size() != 2: continue
		if not (sides.has("west") or sides.has("east")) or not (sides.has("north") or sides.has("south")): continue
		var forward := Vector3(-1 if sides.has("west") else 1, 0, -1 if sides.has("north") else 1)
		level.player.position = FLOOR.position_of(room) - forward * 1.5 + Vector3(0, 0.04, 0)
		level.player.rotation.y = atan2(-forward.x, -forward.z)
		level.player.camera.rotation = Vector3.ZERO
		await shot("upgrade_lounge_corner")
		break
	level.player.position = Vector3(0, 0.04, 0)
	level.player.rotation = Vector3.ZERO
	level.player.camera.rotation = Vector3.ZERO
	level.locust.position = Vector3(0, 0.04, -3.5)
	level.locust.rotation.y = PI
	await shot("upgrade_locust")
	var hide = get_nodes_in_group("hotel_hides")[0]
	level.player.enter_hide(hide)
	await shot("upgrade_hide")
	level.player.leave_hide()
	level.session.pause()
	await shot("upgrade_pause")
	paused = false
	level.queue_free()
	await process_frame
	quit()
