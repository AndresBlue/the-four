extends SceneTree
## The Lurker on floor 2 as it is played, to be looked at (the visual pass of
## spec_lurker_rebuild): the player's camera with the camcorder over it, her
## mind off and her motion driven from here. Over a ceiling with the torch at
## 6 and 3 m, out of a ceiling tile and out of a grille, in a dark room with no
## torch and across a lit one, her ink near and far, scared and fleeing. JPGs
## in evidence/lurker_look/<phase>/.
##   godot --path . --rendering-method forward_plus --fixed-fps 30 --script res://tools/capture/lurker_office_look.gd -- --automation --test-profile --silent [--phase=antes]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SEED := 7
## Her pace seen (lurker_brain.CRAWL_SPEED) and fleeing (FLEE_SPEED).
const SEEN_PACE := 1.35
const FLEE_PACE := 3.5
const EYE := 1.6
var level
var lurker
var out_dir := "res://evidence/lurker_look/antes"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): out_dir = "res://evidence/lurker_look/" + argument.trim_prefix("--phase=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await process_frame
	level.ui.finish_intro()
	level.creature_scene = "lurker"
	level.set_floor(2)
	await level.start_floor(SEED, false, [1], "equilibrada")
	lurker = level.creature
	lurker.thinking = false
	lurker.grace = 0.0
	level.player.set_physics_process(false)
	level.player.set_process(false)
	level.player.set_process_input(false)
	level.player.set_process_unhandled_input(false)
	level.ui.visible = false
	var big := pick(func(r: Dictionary) -> bool: return OFFICE.false_ceiling(r))
	var tiled := pick(func(r: Dictionary) -> bool: return OFFICE.false_ceiling(r) and lurker.ducts.room_tiles.has(int(r.id)) and int(r.id) != int(big.get("id", -1)))
	var other := pick(func(r: Dictionary) -> bool: return int(r.id) != int(big.get("id", -1)) and int(r.id) != int(tiled.get("id", -1)))
	if big.is_empty() or tiled.is_empty() or other.is_empty():
		print("LOOK no rooms")
		quit(1)
		return
	print("LOOK rooms %d %d %d" % [int(big.id), int(tiled.id), int(other.id)])
	power(int(big.id), false)
	# Over a ceiling, the torch on, across at 6 m and at 3 m.
	await across(big, 6.0, true, "techo_6m")
	await across(big, 3.0, true, "techo_3m")
	# Her way of going while watched, 2 s of it.
	await across(big, 4.0, true, "rafaga", 20)
	# In the dark with no torch at 4 m.
	await across(big, 4.0, false, "oscura_4m")
	# Out of a ceiling tile, and out of a grille.
	await out_of_tile(tiled)
	await out_of_grille()
	# Across a lit room.
	power(int(other.id), true)
	await across(other, 5.0, false, "luz")
	# Her ink near and far, the torch on.
	await ink(big)
	# Scared, then fleeing.
	await scared(big)
	level.queue_free()
	await process_frame
	quit()

## The biggest room of planta 1 with a ceiling for her that `test` takes.
func pick(test: Callable) -> Dictionary:
	var best := {}
	var area := 0.0
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != 0 or not lurker.shell.tray_of.has(id) or OFFICE.off_limits(room) or not test.call(room): continue
		var span: Vector2 = FLOOR.size_of(room)
		if minf(span.x, span.y) < 5.0: continue
		if span.x * span.y > area:
			area = span.x * span.y
			best = room
	return best

func power(room: int, on: bool) -> void:
	if bool(level.hotel.lit(room)) != on: level.hotel.set_room_power(room, on)

## The room's centre on its floor, its long axis and its short one.
func frame_of(room: Dictionary) -> Array:
	var span: Vector2 = FLOOR.size_of(room)
	var centre := Vector3(float(room.px), float(room.get("py", 0.0)), float(room.pz))
	var along := Vector3.RIGHT if span.x >= span.y else Vector3.BACK
	var side := Vector3.BACK if span.x >= span.y else Vector3.RIGHT
	return [centre, along, side, maxf(span.x, span.y), minf(span.x, span.y)]

func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = from - Vector3(0, level.player.camera.position.y, 0)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = atan2(at.y - from.y, flat.length())
	level.player.snap_torch()
	level.hotel.update_visibility(level.player.global_position, true)

func torch(on: bool) -> void:
	level.player.torch.visible = on
	level.player.snap_torch()

func save(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out_dir + "/" + name + ".jpg", 0.88)

## `count` pictures, one every `every` frames (at 30 a second).
func film(name: String, count: int, every: int) -> void:
	for k in count:
		for i in every: await process_frame
		await save("%s_%02d" % [name, k])

func wait(seconds: float) -> void:
	for i in int(seconds * 30.0): await process_frame

## She crosses the room's ceiling `metres` in front of the eye, across its
## short side; four pictures 0.1 s apart once she is under way.
func across(room: Dictionary, metres: float, lamp: bool, name: String, count := 4) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	var side: Vector3 = f[2]
	var half_long: float = float(f[3]) * 0.5
	var half_short: float = float(f[4]) * 0.5
	var eye := centre - along * minf(half_long - 0.6, metres * 0.5) + Vector3.UP * EYE
	var line := eye + along * metres
	var start := Vector3(line.x, centre.y, line.z) - side * (half_short - 0.8)
	var finish := Vector3(line.x, centre.y, line.z) + side * (half_short - 0.8)
	lurker.place_over(start, finish)
	torch(lamp)
	look(eye, Vector3(line.x, centre.y + 2.2, line.z))
	await wait(0.5)
	lurker.motion.go_to(finish, SEEN_PACE, true)
	# Under way and some way in: a third of the crossing.
	await wait(minf(1.2, (half_short - 0.8) * 0.66 / SEEN_PACE + 0.4) if count <= 4 else 0.3)
	look(eye, lurker.global_position)
	await film(name, count, 3)
	print("LOOK ", name, " at %.1f m" % Vector2(lurker.global_position.x - eye.x, lurker.global_position.z - eye.z).length())

func out_of_tile(room: Dictionary) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	var goal := centre + along * 1.0
	var eye := centre - along * 2.0 + Vector3.UP * EYE
	torch(true)
	var node: int = int(lurker.ducts.plenum_node[int(room.id)])
	lurker.motion.place_in_duct(node)
	lurker.apply_motion()
	look(eye, goal + Vector3.UP * 2.4)
	await wait(0.5)
	lurker.motion.go_to(goal, SEEN_PACE)
	await film("placa", 24, 3)

func out_of_grille() -> void:
	var exit := -1
	for e in lurker.ducts.exits.size():
		var ex: Dictionary = lurker.ducts.exits[e]
		var r: int = int(ex.room)
		if String(ex.kind) == "ceiling" and lurker.shell.tray_of.has(r) and int(level.manifest.rooms[r].get("wing", -1)) == 0:
			exit = e
			break
	if exit < 0:
		print("LOOK no grille")
		return
	var at: Vector3 = lurker.ducts.exits[exit].position
	var room: Dictionary = level.manifest.rooms[int(lurker.ducts.exits[exit].room)]
	var floor_y := float(room.get("py", 0.0))
	var to_centre := Vector3(float(room.px) - at.x, 0, float(room.pz) - at.z)
	var away := to_centre.normalized() if to_centre.length() > 0.5 else Vector3.RIGHT
	power(int(room.id), false)
	torch(true)
	lurker.place_in_exit(exit)
	look(Vector3(at.x, floor_y + EYE, at.z) + away * 3.0, at)
	await wait(0.5)
	lurker.motion.go_to(Vector3(at.x, floor_y, at.z) + away * 1.5, SEEN_PACE)
	await film("rejilla", 24, 3)

func ink(room: Dictionary) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	torch(true)
	var eye := centre + Vector3.UP * EYE
	lurker.place_over(centre + along * 1.0, eye)
	look(eye, lurker.global_position)
	await wait(1.0)
	await save("tinta_cerca")
	var far := centre - along * (float(f[3]) * 0.5 - 0.6) + Vector3.UP * EYE
	look(far, lurker.global_position)
	await wait(1.0)
	await save("tinta_lejos")

func scared(room: Dictionary) -> void:
	var f := frame_of(room)
	var centre: Vector3 = f[0]
	var along: Vector3 = f[1]
	torch(true)
	var eye := centre - along * 1.5 + Vector3.UP * EYE
	lurker.place_over(centre + along * 1.5, eye)
	look(eye, lurker.global_position)
	await wait(0.5)
	lurker.apply_intent({"do": &"hold", "clip": "scare", "look": level.player.camera.global_position})
	await film("espanto", 8, 3)
	var away := centre + along * (float(f[3]) * 0.5 - 0.8)
	lurker.apply_intent({"do": &"go", "to": away, "speed": FLEE_PACE, "clip": "crawl_fast"})
	await film("huida", 8, 3)
