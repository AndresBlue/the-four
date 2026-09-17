extends SceneTree
## Wardrobe and creature inspection shots: room view, inside shut, peeking,
## and The Locust stooping through a doorway. Camera placement only.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(filename: String, frames := 45) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/wardrobe_%s.png" % filename)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.settings.values.quality = 2
	level.apply_settings()
	var hide = get_nodes_in_group("hotel_hides")[2]
	var front: Vector3 = hide.to_global(Vector3(0, 0, 3.2))
	level.player.position = front + Vector3(0.8, 0.04, 0)
	var d: Vector3 = hide.global_position - level.player.position
	level.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	level.player.camera.rotation = Vector3(-0.1, 0, 0)
	await shot("room")
	level.player.active = true
	level.player.enter_hide(hide)
	await shot("inside_shut", 60)
	Input.action_press("forward")
	await shot("peek", 150)
	level.player.rotation.y = level.player.hide_yaw + 1.1
	await shot("peek_left", 70)
	level.player.rotation.y = level.player.hide_yaw - 1.1
	await shot("peek_right", 70)
	Input.action_release("forward")
	level.player.leave_hide()
	# The Locust under a door lintel, seen from the next room.
	var door = level.hotel.doors[0]
	door.open_immediately()
	var across: Vector3 = Basis(Vector3.UP, door.closed_rotation) * Vector3(0, 0, 1)
	level.locust.position = door.doorway + Vector3(0, 0.04, 0)
	level.locust.rotation.y = atan2(across.x, across.z)
	level.locust.visual.duck = 1.0
	level.player.position = door.doorway + across * 5.5 + Vector3(0, 0.04, 0)
	level.player.rotation = Vector3(0, atan2(across.x, across.z), 0)
	level.player.camera.rotation = Vector3(0.05, 0, 0)
	await shot("locust_doorway")
	level.locust.position = level.player.position - across * 3.5
	level.locust.visual.duck = 0.0
	await shot("locust_close")
	paused = false
	level.queue_free()
	await process_frame
	quit()
