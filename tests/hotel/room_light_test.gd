extends SceneTree
## Light per room (step 0e, docs/OFICINAS.md 11.3) on a live floor: hotel.lit()
## says what sanity, the figure and the bots read before it, on every room,
## lit, in a wing's blackout and with the light given back from the panel; a
## room's power and its drain come back exactly as they were; put_on_actor()
## moves a mesh that is not on layer 1, and follow_bodies() only the one that
## asks for it.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const ROOM_LAYERS := preload("res://game/world/hotel/room_layers.gd")
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title)

func frames(count: int) -> void:
	for i in count: await physics_frame

## What a room's light was before hotel.lit(): sanity.lit_at(), phantom_sight,
## bot_senses and bot_brain all read this.
func lit_before(id: int) -> bool:
	return not level.hotel.dark and not level.hotel.dark_ids.has(id)

## Whether a room's lamp is a failing batten: its energy moves every frame.
func flickering(id: int) -> bool:
	return level.hotel.flickers.any(func(entry): return entry.light == level.hotel.lights[id])

## Every built room (no void cell): [rooms, rooms whose middle sanity was
## asked about, disagreements of hotel.lit(), of its lamp and of sanity].
func agreement() -> Array:
	var seen := 0
	var asked := 0
	var wrong := 0
	for room in level.manifest.rooms:
		if FLOOR.is_void(room): continue
		var id := int(room.id)
		seen += 1
		var expected := lit_before(id)
		if level.hotel.lit(id) != expected: wrong += 1
		if level.hotel.lights[id].has_meta("off") == expected: wrong += 1
		var middle: Vector3 = FLOOR.position_of(room) + Vector3(0, 1.0, 0)
		var found: Dictionary = FLOOR.room_at(level.manifest.rooms, middle)
		if found.is_empty() or int(found.id) != id: continue
		asked += 1
		if level.sanity.lit_at(middle) != expected: wrong += 1
	return [seen, asked, wrong]

## A mesh with a box to draw, on these layers, under that parent.
func mesh_on(parent: Node, layers: int) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = BoxMesh.new()
	piece.layers = layers
	parent.add_child(piece)
	return piece

## Stands the player in a room and runs the floor's round round it at once,
## as the level does four times a second (hotel_main, visibility_clock).
func stand_in(room: Dictionary) -> void:
	level.player.global_position = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	level.hotel.update_visibility(level.player.global_position, true)

## Waits for the session's change to reach the geometry (hotel_main.on_state()).
func wait_dark(wanted: bool) -> void:
	for i in 60:
		if level.hotel.dark == wanted: return
		await physics_frame

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	# The creature would come looking and end the run.
	level.locust.set_physics_process(false)
	level.locust.global_position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	await frames(3)
	var hotel = level.hotel
	var session = level.session
	# Lit, as the floor starts.
	var normal := agreement()
	check("Con luz, hotel.lit(), la lampara y la cordura dicen lo de antes en las %d salas" % normal[0], not hotel.dark and normal[0] > 0 and normal[1] > 0 and normal[2] == 0)
	# The wing's blackout, as the televisions trip it (televisions_objective):
	# the level applies it when the session says it changed.
	session.goal["blackout"] = true
	session.changed.emit()
	await wait_dark(true)
	var cut := agreement()
	check("En el apagon del ala ninguna sala tiene luz, como antes", hotel.dark and cut[0] == normal[0] and cut[2] == 0)
	# The light given back from the panel with the key (code_lock.apply_panel()).
	session.goal["blackout"] = false
	session.goal["restored"] = true
	session.changed.emit()
	await wait_dark(false)
	await frames(5)
	var back := agreement()
	check("Con la luz devuelta desde el cuadro dice otra vez lo de antes", not hotel.dark and back[0] == normal[0] and back[2] == 0)
	# A room's own power: the one the player starts in, or the first lit room
	# whose lamp is steady. The player stands in it, so the round shows its lamp.
	var start: Dictionary = FLOOR.room_at(level.manifest.rooms, level.player.global_position)
	if start.is_empty() or hotel.dark_ids.has(int(start.id)) or flickering(int(start.id)):
		for room in level.manifest.rooms:
			if not FLOOR.is_void(room) and not hotel.dark_ids.has(int(room.id)) and not flickering(int(room.id)):
				start = room
				break
	var room_id := int(start.id)
	var middle: Vector3 = FLOOR.position_of(start) + Vector3(0, 1.0, 0)
	var asks: bool = int(FLOOR.room_at(level.manifest.rooms, middle).get("id", -1)) == room_id
	var lamp: OmniLight3D = hotel.lights[room_id]
	stand_in(start)
	var energy := lamp.light_energy
	var shown := lamp.visible
	hotel.set_room_power(room_id, false)
	var out_now: bool = not hotel.lit(room_id) and lamp.has_meta("off") and not lamp.visible and (not asks or not level.sanity.lit_at(middle))
	stand_in(start)
	await frames(20)
	check("Sin corriente su sala no tiene luz y la ronda de salas no le enciende la lampara", out_now and not lamp.visible and lamp.has_meta("off") and not hotel.lit(room_id))
	hotel.blackout(true)
	hotel.blackout(false)
	check("El apagon y su vuelta no le devuelven la luz a una sala sin corriente", lamp.has_meta("off") and not hotel.lit(room_id))
	hotel.set_room_power(room_id, true)
	stand_in(start)
	await frames(20)
	check("Con la corriente devuelta su lampara queda encendida y con su energia", shown and lamp.visible and hotel.lit(room_id) and not lamp.has_meta("off") and lamp.light_energy == energy and hotel.unpowered.is_empty())
	var again := agreement()
	check("Y el resto del piso dice lo de antes", not hotel.dark and again[0] == normal[0] and again[2] == 0)
	# A dark room of the floor stays dark with its power given back.
	var dark_id := -1
	for id in hotel.dark_ids:
		dark_id = int(id)
		break
	if dark_id >= 0:
		hotel.set_room_power(dark_id, false)
		hotel.set_room_power(dark_id, true)
		check("Una sala oscura del piso sigue oscura con la corriente devuelta", hotel.lights[dark_id].has_meta("off") and not hotel.lit(dark_id) and hotel.unpowered.is_empty())
	else:
		print("SKIP no dark room on seed 81")
	# The drain: the lamp's energy scaled, and back exactly.
	var before: Array = hotel.lights.map(func(light): return light.light_energy)
	hotel.drain(room_id, 0.5)
	var half: bool = is_equal_approx(lamp.light_energy, energy * 0.5) and is_equal_approx(hotel.drained(room_id), 0.5) and hotel.lit(room_id) and (not asks or level.sanity.lit_at(middle))
	hotel.drain(room_id, 0.95)
	var drunk: bool = is_equal_approx(lamp.light_energy, energy * 0.05) and not hotel.lit(room_id) and (not asks or not level.sanity.lit_at(middle))
	hotel.drain(room_id, 0.0)
	var after: Array = hotel.lights.map(func(light): return light.light_energy)
	check("Medio drenada su lampara alumbra la mitad y la sala sigue con luz", half)
	check("Drenada mas alla de LIT_DRAIN la sala no tiene luz", drunk)
	check("drain(sala, 0) devuelve la energia exacta de todas las lamparas", lamp.light_energy == energy and before == after and hotel.drained(room_id) == 0.0 and hotel.lit(room_id) and hotel.drains.is_empty() and hotel.drain_from.is_empty())
	# A failing tube in a drained room flickers under what is left of it. The
	# flicker loop skips a lamp that is not shown: the player stands under it.
	var failing: Dictionary = {}
	for entry in hotel.flickers:
		var id := int(entry.light.get_meta("room", -1))
		if id >= 0 and not hotel.dark_ids.has(id):
			failing = entry
			break
	if not failing.is_empty() and not hotel.reduced:
		var tube: OmniLight3D = failing.light
		var flicker_id := int(tube.get_meta("room", -1))
		stand_in(level.manifest.rooms[flicker_id])
		hotel.drain(flicker_id, 0.5)
		var highest := 0.0
		var lowest := INF
		var showing := true
		for i in 30:
			await process_frame
			showing = showing and tube.visible
			highest = maxf(highest, tube.light_energy)
			lowest = minf(lowest, tube.light_energy)
		hotel.drain(flicker_id, 0.0)
		check("Un tubo que falla tiembla con lo que le queda, nunca por encima", showing and lowest < highest and highest <= float(failing.energy) * 0.5 + 0.0001 and hotel.drained(flicker_id) == 0.0)
	else:
		print("SKIP no failing tube in a lit room on seed 81")
	# put_on_actor(): a mesh off layer 1 is moved, put_on() leaves it.
	var bits: int = 1 << ROOM_LAYERS.FIRST
	var other: int = 1 << (ROOM_LAYERS.FIRST + 3)
	var own := mesh_on(root, 4)
	ROOM_LAYERS.put_on(own, bits)
	var untouched: bool = own.layers == 4
	ROOM_LAYERS.put_on_actor(own, bits)
	var moved: bool = own.layers == (4 | bits) and own.is_visible_in_tree()
	ROOM_LAYERS.put_on_actor(own, other)
	var swapped: bool = own.layers == (4 | other)
	ROOM_LAYERS.put_on_actor(own, 0)
	check("put_on_actor() pone en una sala una malla que no esta en la capa 1, y put_on() no", untouched and moved and swapped and own.layers == 4)
	var plain := mesh_on(root, 1)
	var twin := mesh_on(root, 1)
	ROOM_LAYERS.put_on(plain, bits)
	ROOM_LAYERS.put_on_actor(twin, bits)
	check("En la capa 1 put_on_actor() hace lo mismo que put_on()", plain.layers == (1 | bits) and twin.layers == plain.layers)
	# follow_bodies(): only the mesh that asks for it leaves its own layer.
	var body := Node3D.new()
	root.add_child(body)
	body.add_to_group("hotel_actors")
	body.global_position = FLOOR.position_of(start)
	var opted := mesh_on(body, 4)
	opted.set_meta("follow_rooms", true)
	var alone := mesh_on(body, 4)
	var first_person := mesh_on(body, 2)
	var walker := mesh_on(body, 1)
	var bit: int = hotel.layer_at(body.global_position + Vector3(0, 0.9, 0))
	hotel.follow_bodies()
	check("follow_bodies() lleva a su sala la malla que lo pide y deja en su capa la del cuerpo en primera persona", bit != 0 and opted.layers == (4 | bit) and alone.layers == 4 and first_person.layers == 2 and walker.layers == (1 | bit))
	body.queue_free()
	own.queue_free()
	plain.queue_free()
	twin.queue_free()
	var file := FileAccess.open("res://evidence/room_light_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("ROOM_LIGHT_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
