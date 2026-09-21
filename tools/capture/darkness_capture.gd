extends SceneTree
## Darkness and light leaks, for evidence and before/after comparisons:
##   darkness_door    a dark room, looking at a shut door into a lit room
##   darkness_room    the same dark room, torch off
##   darkness_torch   the same dark room, torch on
##   darkness_wall    the wall between two rooms while a teammate in the next
##                    room points a torch at it from the other side
##   darkness_powered a lit room with a wall lamp in it, torch off
##   darkness_cut     the same, with the floor's power cut: nothing should be
##                    giving off light of its own any more
##   darkness_restored and the same again with the power back
##   darkness_refuge  the refuge, and darkness_refuge_cut the same with the
##                    power cut: its exit signs stay lit, they are the one
##                    thing here with a battery
## Pass "-- --prefix=name" to keep a second set beside the first.
##   godot --path . --script res://tools/capture/darkness_capture.gd -- --automation
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const REMOTE := preload("res://game/net/remote_player.gd")
var level
var prefix := "darkness"

func _initialize() -> void: run.call_deferred()

func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = atan2(at.y - from.y, flat.length())
	level.player.snap_torch()

func shot(name: String) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/%s_%s.png" % [prefix, name])
	print("SHOT ", name)

func dark(room: Dictionary) -> bool:
	return level.hotel.lights[int(room.id)].has_meta("off")

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="): prefix = argument.trim_prefix("--prefix=")
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
	var darks := 0
	for room in level.manifest.rooms: if dark(room): darks += 1
	print("DARK rooms ", darks, " of ", level.manifest.rooms.size())
	# A dark room with a shut door into a lit one: the leak, if any, is here.
	var found := false
	for door in level.hotel.doors:
		for side in [-1.0, 1.0]:
			var facing: Vector3 = Basis(Vector3.UP, door.closed_rotation).z * side
			var here := FLOOR.room_at(level.manifest.rooms, door.doorway + facing * 2.5)
			var there := FLOOR.room_at(level.manifest.rooms, door.doorway - facing * 2.5)
			if here.is_empty() or there.is_empty() or not dark(here) or dark(there): continue
			if door.opened: door.set_state(false)
			for i in 90: await physics_frame
			look(door.doorway + facing * 3.2 + Vector3(0, 1.6, 0), door.doorway + Vector3(0, 1.2, 0))
			await shot("door")
			var centre := FLOOR.position_of(here)
			look(centre + Vector3(0, 1.6, 0) - facing * 0.0 + facing * 3.0, centre - facing * 3.0 + Vector3(0, 1.0, 0))
			await shot("room")
			level.player.torch.visible = true
			await shot("torch")
			level.player.torch.visible = false
			found = true
			break
		if found: break
	if not found: print("NO dark room beside a lit one behind a shut door")
	# A teammate's torch on the far side of a wall.
	var mate = REMOTE.new()
	mate.setup(level, 2, "Prueba", 0)
	level.add_child(mate)
	for room in level.manifest.rooms:
		var centre := FLOOR.position_of(room)
		var span := FLOOR.size_of(room)
		var wall := centre + Vector3(span.x * 0.5, 0, 0)
		var next := FLOOR.room_at(level.manifest.rooms, wall + Vector3(2.0, 0, 0))
		if next.is_empty() or level.manifest.adjacency[room.id].has(next.id): continue
		mate.place(wall + Vector3(3.0, 0.04, 1.5), PI / 2)
		for i in 6:
			mate.push_state([wall + Vector3(3.0, 0.04, 1.5), PI / 2, 0.0, Vector3.ZERO, 2, -1, 0.0, 0.0])
			await physics_frame
		look(wall + Vector3(-3.5, 1.6, 1.5), wall + Vector3(0, 1.2, 1.5))
		await shot("wall")
		break
	# The power cut. What is left giving off light of its own when nothing is
	# lighting the floor any more: a shade, a dome or a wall lamp that stops
	# lighting the room but keeps glowing ends up the only thing visible in it.
	for room in level.manifest.rooms:
		# A lit room, looking up at its dome from across it: the ceiling lamp,
		# and the wall lamps of a public room if it has any, all in frame.
		if dark(room) or int(room.type) in [4, 7, 8, 9] or FLOOR.size_of(room).x < 9.0: continue
		var centre := FLOOR.position_of(room)
		level.player.torch.visible = false
		look(centre + Vector3(3.4, 1.6, 0), centre + Vector3(0, 2.8, 0))
		await shot("powered")
		level.hotel.blackout(true)
		await shot("cut")
		level.hotel.blackout(false)
		await shot("restored")
		break
	# The refuge with the power cut: the exit signs are the one thing on the
	# floor with a battery, and they stay lit so it can still be found.
	var refuge: Dictionary = level.manifest.rooms[int(level.manifest.refuges[0])]
	var middle := FLOOR.position_of(refuge)
	level.player.torch.visible = false
	look(middle + Vector3(0, 1.6, 3.4), middle + Vector3(0, 2.3, -2.5))
	await shot("refuge")
	level.hotel.blackout(true)
	await shot("refuge_cut")
	level.hotel.blackout(false)
	level.queue_free()
	await process_frame
	quit()
