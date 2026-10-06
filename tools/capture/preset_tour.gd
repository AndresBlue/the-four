extends SceneTree
## A floor on one graphics preset, in the places where a preset can go wrong:
## the reception, a lit corridor, a room with its lamp out (black with the
## doors shut; then by the torch, which is the one light that always casts),
## a doorway between a dark room and a lit one from both sides, a wardrobe, a
## television on in the dark, a lift's lobby, and the creature standing in a
## lit room and in the dark one next to it. Written for Muy bajo, where the
## lamps cast nothing and light only their own rooms (PERFORMANCE.md, section
## 10): what must not show there is light in a room that is not its lamp's.
## Needs a window (it reads the rendered image), never --headless.
##
##   godot --path . --script tools/capture/preset_tour.gd -- --test-profile --automation --silent --quality=4
## Writes evidence/tour_q<n>_<place>.png, as played (lens and tape) and, with
## --raw, without them.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level
var quality := 4
var raw := false

func _initialize() -> void: run.call_deferred()

func shot(place: String, frames := 50) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/tour_q%d_%s.png" % [quality, place])
	print("SHOT ", place)

## The player at `from` (on the floor), looking at `at`.
func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = from
	var eye := from + Vector3(0, 1.64, 0)
	var way := at - eye
	level.player.rotation = Vector3(0, atan2(-way.x, -way.z), 0)
	level.player.camera.rotation.x = atan2(way.y, Vector2(way.x, way.z).length())
	level.player.snap_torch()

func torch(lit: bool) -> void:
	level.player.torch.visible = lit
	level.player.torch.light_energy = level.player.torch_energy

func middle(room: Dictionary) -> Vector3:
	return FLOOR.position_of(room) + Vector3(0, 0.04, 0)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument == "--raw": raw = true
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for i in 30: await process_frame
	level.ui.finish_intro()
	level.settings.values.first_game_done = true
	level.settings.set_value("quality", quality)
	await level.start_floor(81, false, [1], "equilibrada")
	level.locust.set_physics_process(false)
	level.locust.global_position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	if raw:
		level.get_node("Presentation/Analog/Screen").visible = false
		level.get_node("Presentation/Lens/Screen").visible = false
		level.settings.values.osd = false
	for i in 90: await process_frame
	var rooms: Array = level.manifest.rooms
	var hotel = level.hotel
	var start: Dictionary = rooms[int(level.manifest.start)]
	look(middle(start) + Vector3(3.5, 0, 3.5), middle(start) + Vector3(-4, 1.4, -4))
	await shot("recepcion")
	# A lit corridor, looked along from one of its cells into the next.
	for room in rooms:
		if int(room.get("wing", 0)) != 0 or not bool(room.get("corridor", false)) or hotel.dark_room(room): continue
		var onward := -1
		for other in level.manifest.adjacency[int(room.id)]:
			if hotel.open_pairs.has(Vector2i(mini(int(room.id), other), maxi(int(room.id), other))) and not hotel.dark_room(rooms[other]): onward = other
		if onward < 0: continue
		look(middle(room), middle(rooms[onward]) + Vector3(0, 1.4, 0))
		await shot("pasillo")
		break
	# A room with its lamp out, a door to a lit one, on the first planta.
	var dark := {}
	var lit := {}
	var door = null
	for edge in level.manifest.edges:
		var a: Dictionary = rooms[int(edge[0])]
		var b: Dictionary = rooms[int(edge[1])]
		if int(a.get("wing", 0)) != 0 or hotel.dark_room(a) == hotel.dark_room(b): continue
		var found = hotel.get_node_or_null("Door_%d_%d" % [a.id, b.id])
		var shut_in: Dictionary = a if hotel.dark_room(a) else b
		# A room, not a corridor: four walls and things in it.
		if found == null or found.locked or bool(shut_in.get("corridor", false)) or shut_in.props.is_empty(): continue
		door = found
		dark = shut_in
		lit = b if hotel.dark_room(a) else a
		break
	if door != null:
		for other in hotel.doors:
			if other.opened and not other.locked: other.set_state(false)
		var doorway: Vector3 = door.doorway
		var inside := middle(dark)
		var outside: Vector3 = doorway + (doorway - inside).normalized() * 3.0
		outside.y = inside.y
		look(inside, doorway + Vector3(0, 1.3, 0))
		await shot("oscura_cerrada")
		torch(true)
		await shot("oscura_linterna")
		torch(false)
		door.set_state(true)
		await shot("oscura_puerta_abierta")
		look(outside, inside + Vector3(0, 1.2, 0))
		await shot("desde_la_iluminada")
		# The creature, in the lit room and then in the dark one beside it:
		# along the lit room's wall, a little out from the doorway, seen from
		# the same distance on the doorway's other side.
		var out: Vector3 = (doorway - inside) * Vector3(1, 0, 1)
		out = out.normalized()
		var along := out.cross(Vector3.UP)
		var beside: Vector3 = doorway + out * 1.3 + along * 2.4
		beside.y = inside.y
		level.locust.global_position = beside
		look(Vector3(doorway.x, inside.y, doorway.z) + out * 1.3 - along * 2.4, beside + Vector3(0, 1.3, 0))
		await shot("criatura_iluminada")
		level.locust.global_position = inside
		look(outside, inside + Vector3(0, 1.3, 0))
		await shot("criatura_a_oscuras")
		level.locust.global_position = Vector3(0, -80, 0)
		door.set_state(false)
	# A wardrobe in a lit room.
	for hide in hotel.hides:
		var room: Dictionary = FLOOR.room_at(rooms, hide.global_position)
		if room.is_empty() or int(room.get("wing", 0)) != 0 or hotel.dark_room(room): continue
		var front: Vector3 = hide.global_position + hide.global_basis.z * 2.6
		look(Vector3(front.x, middle(room).y, front.z), hide.global_position + Vector3(0, 1.1, 0))
		await shot("armario")
		break
	# A television on, in whatever its room is, with the torch off.
	if not level.televisions.is_empty():
		var set: Node3D = level.televisions[0]
		var front: Vector3 = set.screen_point() + set.global_basis.z.normalized() * 2.6
		look(Vector3(front.x, set.global_position.y, front.z), set.screen_point())
		set.set_on(true)
		await shot("tele", 90)
		set.set_on(false)
	# The lobby of the first lift, from the room's middle towards its car.
	if not hotel.lifts.is_empty() and hotel.lifts[0] != Vector3.ZERO:
		var car: Vector3 = hotel.lifts[0]
		var lobby: Dictionary = FLOOR.room_at(rooms, car)
		if not lobby.is_empty():
			look(middle(lobby), car + Vector3(0, 1.2, 0))
			await shot("ascensor")
	quit()
