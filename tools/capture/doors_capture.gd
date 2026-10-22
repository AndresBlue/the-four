extends SceneTree
## A door seen from inside a room (its number is the room behind it) and a room
## whose ceiling lamp is out (evidence/door_number.png, dark_room.png).
var level

func _initialize() -> void: run.call_deferred()

func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = atan2(at.y - from.y, flat.length())

func shot(name: String) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/%s.png" % name)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	# The tape screen plays over everything for its first seconds and these
	# shots are about what is behind it.
	level.ui.finish_intro()
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	var FLOOR := preload("res://game/world/generation/floor_definition.gd")
	# A shut door, seen from 2.5 m inside one of its rooms.
	for door in level.hotel.doors:
		if door.opened: continue
		var facing := Basis(Vector3.UP, door.closed_rotation).z
		var eye: Vector3 = door.doorway + facing * 2.5 + Vector3(0, 1.6, 0)
		var inside := FLOOR.room_at(level.manifest.rooms, eye)
		var behind := FLOOR.room_at(level.manifest.rooms, door.doorway - facing * 2.5)
		if inside.is_empty() or behind.is_empty(): continue
		print("DOOR inside room ", int(inside.get("number", 0)), " behind room ", int(behind.get("number", 0)))
		look(eye, door.doorway + Vector3(0, 1.9, 0))
		await shot("door_number")
		break
	for i in level.hotel.lights.size():
		if not level.hotel.lights[i].has_meta("off"): continue
		var centre := FLOOR.position_of(level.manifest.rooms[i])
		print("DARK room ", int(level.manifest.rooms[i].get("number", 0)), " type ", FLOOR.palette(level.manifest).label(level.manifest.rooms[i]))
		look(centre + Vector3(0, 1.6, 4.5), centre + Vector3(0, 1.2, -3))
		await shot("dark_room")
		break
	level.queue_free()
	await process_frame
	quit()
