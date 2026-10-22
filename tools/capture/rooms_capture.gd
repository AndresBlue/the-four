extends SceneTree
## Layout inspection shots: a corridor without wardrobes, a bedroom with its
## wardrobes and a hotel doorway. Camera placement only.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(filename: String, frames := 45) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/rooms_%s.png" % filename)

func look_from(from: Vector3, at: Vector3) -> void:
	level.player.position = from + Vector3(0, 0.04, 0)
	var d := at - from
	level.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	level.player.camera.rotation = Vector3(-0.08, 0, 0)

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
	level.settings.values.quality = 2
	level.apply_settings()
	var counts := {}
	var corridor := {}
	var bedroom := {}
	for room in level.hotel.manifest.rooms:
		var n := FLOOR.hiding_count(room)
		counts[n] = int(counts.get(n, 0)) + 1
		if corridor.is_empty() and int(room.type) == FLOOR.palette(level.manifest).CORRIDOR and int(room.get("hall", -1)) < 0: corridor = room
		if bedroom.is_empty() and n == 2 and FLOOR.palette(level.manifest).TYPES[int(room.type)] in ["habitacion_doble", "habitacion_simple"]: bedroom = room
	print("ROOMS wardrobes per module: ", counts, " total hides: ", get_nodes_in_group("hotel_hides").size())
	if not corridor.is_empty():
		var c := FLOOR.position_of(corridor)
		var s := FLOOR.size_of(corridor)
		var along := Vector3(s.x * 0.4, 0, 0) if s.x >= s.y else Vector3(0, 0, s.y * 0.4)
		look_from(c - along, c + along)
		await shot("corridor")
	if not bedroom.is_empty():
		var c := FLOOR.position_of(bedroom)
		var spots := FLOOR.hiding_positions(bedroom)
		look_from(c - spots[0].normalized() * 1.5, c + spots[0])
		await shot("bedroom")
	var door = level.hotel.doors[0]
	var across: Vector3 = Basis(Vector3.UP, door.closed_rotation) * Vector3(0, 0, 1)
	look_from(door.doorway + across * 3.5, door.doorway)
	await shot("door")
	paused = false
	level.queue_free()
	await process_frame
	quit()
