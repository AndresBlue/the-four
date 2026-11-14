extends SceneTree
## Every kind of room of floor 2 from several angles, as the game shows it (the
## camcorder's lens, tape and OSD; no objective cards), for a reviewer to judge
## light, shading, composition, textures and models. For each type present in
## the floor (the first room of it, planta 1 first, lit): (1) from its doorway;
## (2) from the far corner looking back at the doorway; (3) close over its
## main piece of furniture at a seated eye; (4) up at the ceiling at a slant;
## (5) down along the floor at a grazing angle towards a lit lamp. Then the
## office and the open office dark, with the torch, from their doorway and
## from their far corner. At Alto, the window 1280 wide:
##   godot --path . --script res://tools/capture/office_angles_capture.gd --log-file <log> -- --automation --test-profile --silent [--seed=7] [--quality=2] [--prefix=rev1]
## Writes evidence/rediseno/<prefix>/<type>_<n>.png and indice.json ([{tipo,
## angulo, sala, archivo}]).
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FRAMING := preload("res://tools/capture/room_framing.gd")
const BACKGROUND := preload("res://tools/capture/background_window.gd")
const ANGLES := ["puerta", "rincon", "mueble", "techo", "suelo"]
const SEATED := 1.15
const STANDING := 1.6
## How far into the room the doorway's view stands (FRAMING's own is in the
## leaf's swing or the frame), and the ball that must be clear round an eye.
const PAST_DOOR := 0.5
const EYE_ROOM := 0.22
var level
var out_dir := "res://evidence/rediseno/rev1"
var index: Array = []
var pose := {}

func _initialize() -> void: run.call_deferred()

## A room's type name (OFFICE.label()) as a file name: lower case, no
## accents, underscores.
static func slug(room: Dictionary) -> String:
	var name := OFFICE.label(room).to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ñ", "n"], [" ", "_"]]: name = name.replace(pair[0], pair[1])
	return name

## Whether an eye at a point stands clear of every collider (furniture, a
## leaf, a frame), the player's own body left out.
func clear_at(point: Vector3) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = EYE_ROOM
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.exclude = [level.player.get_rid()]
	query.transform = Transform3D(Basis.IDENTITY, point)
	return level.player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

## The eye moved towards what it looks at, a quarter metre at a time, until
## it is clear (clear_at()); where it was if no step is.
func clear_eye(from: Vector3, at: Vector3) -> Vector3:
	var ahead := Vector3(at.x - from.x, 0, at.z - from.z)
	if ahead.length() < 0.01: return from
	ahead = ahead.normalized() * 0.25
	for k in 9:
		if clear_at(from + ahead * k): return from + ahead * k
	print("ANGLES eye not clear at %s" % from)
	return from

func look(from: Vector3, at: Vector3) -> void:
	from = clear_eye(from, at)
	level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = atan2(at.y - from.y, maxf(flat.length(), 0.001))
	pose = {"eye": [from.x, from.y, from.z], "target": [at.x, at.y, at.z]}

func shot(room: Dictionary, angle: String, n: int, name := "", settle_ms := 1200) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	level.hotel.flicker_clock = 0.4
	level.hotel._process(0.0)
	await level.bounce_ready()
	level.hotel.update_visibility(level.player.global_position, true)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < settle_ms: await process_frame
	await RenderingServer.frame_post_draw
	var file := "%s_%d.png" % [slug(room) if name.is_empty() else name, n]
	root.get_texture().get_image().save_png(out_dir + "/" + file)
	index.append({"tipo": OFFICE.label(room), "angulo": angle, "sala": int(room.id), "archivo": file, "pose": pose})
	print("ANGLES %s %s room=%d" % [file, angle, int(room.id)])

## The room's light on, as capture_rooms' light_all() does it.
func light(room: Dictionary, on: bool) -> void:
	var id := int(room.id)
	if on:
		level.hotel.dark_ids.erase(id)
		level.hotel.set_room_power(id, false)
	level.hotel.set_room_power(id, on)

## The room's main piece: the largest of its furniture, in world space; or its
## middle when it has none.
func main_piece(room: Dictionary) -> Dictionary:
	var centre := FLOOR.position_of(room)
	var best: Dictionary = {}
	var area := 0.0
	for item in room.get("furniture", []):
		var size := Vector2(float(item.size[0]), float(item.size[1]))
		if size.x * size.y > area:
			area = size.x * size.y
			best = item
	if best.is_empty(): return {"at": centre, "height": 0.75}
	var p := Vector2(float(best.at[0]), float(best.at[1]))
	var span := FLOOR.size_of(room)
	# Laid out in the room's own frame when it fits in the room's span.
	var local: bool = absf(p.x) <= span.x * 0.5 + 0.01 and absf(p.y) <= span.y * 0.5 + 0.01
	var at := centre + Vector3(p.x, 0, p.y) if local else Vector3(p.x, centre.y, p.y)
	return {"at": at, "height": float(best.get("extra", {}).get("height", 0.75))}

func frames(room: Dictionary) -> Array:
	var centre := FLOOR.position_of(room)
	var span := FLOOR.size_of(room)
	var door: Dictionary = {}
	if not FLOOR.doorways(room).is_empty() or not room.get("open_sides", []).is_empty():
		door = FRAMING.door_of(level.manifest.rooms, room)
	var inward: Vector3 = door.inward if not door.is_empty() else (Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1))
	var portal: Vector3 = door.portal if not door.is_empty() else centre - inward * ((span.x if absf(inward.x) > 0.5 else span.y) * 0.5)
	var depth: float = span.x if absf(inward.x) > 0.5 else span.y
	var width: float = span.y if absf(inward.x) > 0.5 else span.x
	var side := Vector3(inward.z, 0, -inward.x)
	var up := Vector3(0, STANDING, 0)
	var out: Array = []
	# (1) The doorway: the reference framing when there is a door.
	if not door.is_empty():
		var view := FRAMING.view_of(room, door)
		out.append([view.from + door.inward * PAST_DOOR, view.at])
	else: out.append([portal + inward * 0.4 + up, centre + Vector3(0, 1.2, 0)])
	# (2) The far corner, looking back at the doorway.
	var corner := centre + inward * (depth * 0.5 - 0.45) + side * (width * 0.5 - 0.45) + up
	out.append([corner, portal + Vector3(0, 1.3, 0)])
	# (3) Over the main piece, at a seated eye, from the room's middle side.
	var piece: Dictionary = main_piece(room)
	var toward: Vector3 = centre - piece.at
	toward.y = 0.0
	if toward.length() < 0.3: toward = -inward
	var eye: Vector3 = piece.at + toward.normalized() * 1.1 + Vector3(0, SEATED, 0)
	out.append([eye, piece.at + Vector3(0, float(piece.height), 0)])
	# (4) Up at the ceiling, at a slant towards the far side.
	out.append([centre - inward * (depth * 0.25) + up, centre + inward * (depth * 0.5) + Vector3(0, float(room.height) + 0.6, 0)])
	# (5) Along the floor at a grazing angle, towards the lamps.
	out.append([portal + inward * 0.5 + side * (width * 0.2) + up, centre + inward * (depth * 0.3) + Vector3(0, 0.35, 0)])
	return out

## --types=a,b: only those types (their files' names, slug()).
var only := PackedStringArray()
var doors := false
var triplets := false

func door_views() -> void:
	var examples := {}
	for door in level.hotel.doors:
		var leaf := door.get_node_or_null("Leaf") as MeshInstance3D
		if leaf == null or door.locked: continue
		for family: String in level.hotel.DOOR_MODELS:
			if leaf.mesh.resource_path == String(level.hotel.DOOR_MODELS[family]) and not examples.has(family):
				examples[family] = door
		if examples.size() == level.hotel.DOOR_MODELS.size(): break
	for family: String in examples:
		var door = examples[family]
		var normal: Vector3 = door.across()
		var along: Vector3 = door.along()
		var portal: Vector3 = door.doorway
		var was_open: bool = door.opened
		for face: float in [-1.0, 1.0]:
			var room := FLOOR.room_at(level.manifest.rooms, portal + normal * face * 0.7)
			if room.is_empty(): continue
			light(room, true)
			var from := portal + normal * face * 1.65 + along * 0.46 + Vector3.UP * STANDING
			var aim := portal + Vector3.UP * 1.38
			var name := "puerta_%s_%s" % [family, "a" if face < 0.0 else "b"]
			door.set_state(false)
			look(from, aim)
			await shot(room, "cerrada", 1, name)
			door.swing_to(true, true, false)
			door.motion.pause()
			door.motion.custom_step(door.SLOW_SWING * 0.5)
			await shot(room, "giro", 2, name, 0)
			door.set_state(true)
			await shot(room, "abierta", 3, name)
			door.set_state(false)
			level.hotel.dark_ids[int(room.id)] = true
			level.hotel.set_room_power(int(room.id), false)
			level.player.torch.visible = true
			await shot(room, "cerrada_linterna", 4, name)
			level.player.torch.visible = false
			light(room, true)
		door.set_state(was_open)

func run() -> void:
	BACKGROUND.configure()
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	var seed_value := 7
	var quality := 2
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--prefix="): out_dir = "res://evidence/rediseno/" + argument.trim_prefix("--prefix=")
		if argument.begins_with("--types="): only = argument.trim_prefix("--types=").split(",")
		if argument == "--doors": doors = true
		if argument == "--triplets": triplets = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	level.settings.values = level.settings.DEFAULTS.duplicate()
	level.settings.set_designed(quality)
	level.creature_scene = "none"
	await level.start_floor(seed_value, false, [1], "apacible", 2)
	BACKGROUND.release_input(level)
	level.apply_settings()
	await level.bounce_ready()
	DisplayServer.window_set_size(Vector2i(1280, 800))
	BACKGROUND.configure()
	for i in 30: await process_frame
	level.player.set_physics_process(false)
	level.player.torch.visible = false
	level.ui.visible = false
	# (llegada) What a player sees as the floor opens: at the spawn, looking the
	# way the floor starts them (start_facing), then a step and two on.
	if only.is_empty() or only.has("llegada"):
		var start: Dictionary = level.manifest.rooms[int(level.manifest.start)]
		light(start, true)
		var yaw := float(level.manifest.get("start_facing", PI))
		var ahead := Vector3(-sin(yaw), 0, -cos(yaw))
		var eye: Vector3 = level.player.spawn + Vector3(0, level.player.camera.position.y, 0)
		for n in 3:
			var from := eye + ahead * 1.2 * n
			look(from, from + ahead * 5.0)
			await shot(start, "llegada", n + 1, "llegada")
	# The first room of each type, planta 1 first.
	var chosen := {}
	for wing in 3:
		for room in level.manifest.rooms:
			if FLOOR.is_void(room) or int(room.get("wing", 0)) != wing or chosen.has(int(room.type)): continue
			chosen[int(room.type)] = room
	var types: Array = chosen.keys()
	types.sort()
	for type: int in types:
		var room: Dictionary = chosen[type]
		if not only.is_empty() and not only.has(slug(room)): continue
		light(room, true)
		var views := frames(room)
		for n in views.size():
			if triplets and n >= 3 and type != OFFICE.RECEPTION: continue
			look(views[n][0], views[n][1])
			await shot(room, ANGLES[n], n + 1)
	# Dark, with the torch.
	for kind: int in [OFFICE.OFFICE, OFFICE.OPEN_OFFICE]:
		if not chosen.has(kind): continue
		var room: Dictionary = chosen[kind]
		if not only.is_empty() and not only.has(slug(room)): continue
		level.hotel.dark_ids[int(room.id)] = true
		level.hotel.set_room_power(int(room.id), false)
		level.player.torch.visible = true
		var views := frames(room)
		for n in 2:
			look(views[n][0], views[n][1])
			await shot(room, ANGLES[n] + "_linterna", 6 + n)
		level.player.torch.visible = false
		light(room, true)
	if doors: await door_views()
	var file := FileAccess.open(out_dir + "/indice.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(index, "\t"))
	file.close()
	print("ANGLES_DONE %d" % index.size())
	quit()
