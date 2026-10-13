extends SceneTree
## A look at the blood of a capture (game/app/blood.gd), from close and for
## long enough: the capture bench films the scene, which is over in five
## seconds and seen from across a room, and a pool takes thirty to spread.
##
##   godot --fixed-fps 60 --script res://tools/dev/blood_look.gd -- --test-profile [--floor=hard] [--wall=0.6] [--light=room|torch|dark] [--seed=81] [--name=x]
##
## Stages one capture (in the biggest room, or with --floor=hard in the
## biggest room with a hard floor; --wall: their back that far from a wall),
## and writes evidence/blood_<name>.png: the place seen from a step away, a
## little above the floor, just after the blow, as the body lies and forty
## seconds on (--times=a,b,c for others); and under it the same seconds seen
## from above. Says how many stains it laid and where.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SCORE := preload("res://game/app/capture_score.gd")
var TIMES: Array = [3.45, 4.6, 40.0]
var level
var options := {}

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in count: await process_frame

func staging_room(hard: bool) -> Dictionary:
	var best := {}
	var best_area := 0.0
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or level.point_protected(FLOOR.position_of(room)): continue
		if hard != (int(room.type) in FLOOR.HARD_FLOORS): continue
		if not hard and int(room.get("wing", 0)) != 0: continue
		var span: Vector2 = FLOOR.size_of(room)
		if span.x * span.y > best_area:
			best_area = span.x * span.y
			best = room
	return best

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair := argument.trim_prefix("--").split("=")
			options[pair[0]] = pair[1]
		elif argument.begins_with("--"): options[argument.trim_prefix("--")] = true
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.session.keeps_checkpoint = false
	level.ui.finish_intro()
	if options.has("times"):
		TIMES = []
		for piece in String(options.times).split(","): TIMES.append(float(piece))
	# Desafiante: alone, the floor is lost with the capture and nothing is
	# given back, so what was spilt stays to be looked at.
	await level.start_floor(int(options.get("seed", 81)), false, [1], "desafiante")
	level.ui.hide_transit()
	level.lifts.brief_wait = 0.0
	level.settings.values.character = int(options.get("character", 2))
	level.settings.values.reduced = options.has("reduced")
	level.apply_settings()
	level.automation = true
	if is_instance_valid(level.director):
		level.director.queue_free()
		level.director = null
	var creature = level.locust
	var player = level.player
	creature.set_physics_process(false)
	creature.grace = 0.0
	await frames(5)
	var room := staging_room(String(options.get("floor", "carpet")) == "hard")
	if room.is_empty():
		print("BLOOD_LOOK no such room")
		quit(1)
		return
	var centre: Vector3 = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	var span: Vector2 = FLOOR.size_of(room)
	var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
	var at := centre
	if options.has("wall"): at = centre - along * (maxf(span.x, span.y) * 0.5 - float(options.wall)) + along.cross(Vector3.UP) * float(options.get("shift", 0.0))
	var light := String(options.get("light", "room"))
	if light in ["torch", "dark"] and not level.hotel.dark: level.hotel.blackout(true)
	player.reset_survival()
	player.global_position = at
	player.rotation.y = atan2(-along.x, -along.z)
	player.camera.rotation = Vector3.ZERO
	player.active = true
	player.held = false
	player.torch.visible = light == "torch"
	level.session.participants[player.slot] = level.session.Life.EXPLORING
	creature.global_position = at + along * 1.4
	creature.rotation.y = atan2(along.x, along.z)
	creature.set_mode(creature.Mode.PATROL)
	await frames(30)
	level.executions.forced = {"entry": "front", "glance": false}
	level.capture_survivor(player)
	if level.execution.is_empty():
		print("BLOOD_LOOK not caught")
		quit(1)
		return
	var blood = level.executions.blood
	var record: Dictionary = blood.records[-1] if not blood.records.is_empty() else {}
	var stains := 0
	var where: Array = []
	for node in record.get("nodes", []):
		if node is MultiMeshInstance3D and node.name.begins_with("Blood") and node != record.get("air"):
			stains += (node as MultiMeshInstance3D).multimesh.instance_count
			where.append("%s:%d" % [node.get_parent().name, (node as MultiMeshInstance3D).multimesh.instance_count])
	print("BLOOD_LOOK room=", FLOOR.TYPES[int(room.type)], " stains=", stains, " in ", where, " flying=", (record.get("flying", []) as Array).size(), " pool at=", record.get("pool_at", "none"))
	for node in record.get("nodes", []):
		if node is MultiMeshInstance3D and node != record.get("air"):
			var multi: MultiMesh = (node as MultiMeshInstance3D).multimesh
			for index in mini(4, multi.instance_count): print("  stain ", (node as Node3D).global_transform * multi.get_instance_transform(index), " custom=", multi.get_instance_custom_data(index), " visible=", (node as Node3D).is_visible_in_tree(), " layers=", (node as VisualInstance3D).layers)
	# Two views of it, from outside the scene: a step and a half off to one
	# side, knee high; and from over it.
	var middle: Vector3 = at + along * 0.3
	var side := along.cross(Vector3.UP)
	var near := Camera3D.new()
	near.fov = 62.0
	level.add_child(near)
	if options.has("wall"):
		# From the room, behind the creature: the wall they were held against.
		near.global_position = middle + along * 3.4 + side * 1.3 + Vector3.UP * 1.4
		near.look_at(middle - along * 0.8 + Vector3.UP * 1.0)
	else:
		near.global_position = middle + side * 2.3 - along * 1.2 + Vector3.UP * 0.75
		near.look_at(middle + Vector3.UP * 0.35 - along * 0.6)
	var over := Camera3D.new()
	over.fov = 62.0
	level.add_child(over)
	if options.has("wall"):
		# And the wall itself, square on, from two steps off.
		over.global_position = middle + along * 2.0 + Vector3.UP * 1.2
		over.look_at(middle - along * 1.0 + Vector3.UP * 1.1)
	else:
		over.global_position = middle - along * 0.6 + Vector3.UP * 2.6 + side * 0.01
		over.look_at(middle - along * 0.6, along)
	var size := Vector2i(1280, 720)
	var page := Image.create(size.x * TIMES.size(), size.y * 2, false, Image.FORMAT_RGB8)
	var clock := 0.0
	var next := 0
	while next < TIMES.size():
		await process_frame
		# The place as it is, not as a tape shows it: no filter, no words over
		# it ("--tape" leaves them).
		if not options.has("tape"):
			for layer in root.find_children("*", "CanvasLayer", true, false): (layer as CanvasLayer).visible = false
		if not level.execution.is_empty(): clock = float(level.execution.time)
		else:
			# The scene is over and so is the floor: the blood's clock is run
			# from here, and what the game says about losing is put away.
			clock += 1.0 / 60.0
			if not blood.records.is_empty(): blood.records[-1].clock = clock
			blood._process(0.0)
		if clock < float(TIMES[next]): continue
		for view in 2:
			(near if view == 0 else over).current = true
			await frames(3)
			await RenderingServer.frame_post_draw
			var shot: Image = root.get_texture().get_image()
			shot.convert(Image.FORMAT_RGB8)
			shot.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
			page.blit_rect(shot, Rect2i(Vector2i.ZERO, size), Vector2i(size.x * next, size.y * view))
		clock += 6.0 / 60.0
		next += 1
	var path := "res://evidence/blood_%s.png" % String(options.get("name", "look"))
	page.save_png(path)
	print("BLOOD_LOOK_SHEET ", path)
	level.queue_free()
	await process_frame
	quit()
