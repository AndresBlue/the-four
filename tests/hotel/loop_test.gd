extends SceneTree
## Single-floor loop: the pacing director's rules and events, and the
## documents placed on furniture, read and kept in the archive.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PLACEMENT := preload("res://game/world/generation/document_placement.gd")
const CATALOG := preload("res://game/discovery/discovery_catalog.gd")
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

## Runs the director for some seconds in one-second steps.
func advance(director, seconds: float) -> void:
	for i in int(seconds): director.tick(1.0)

func started(director, type := "") -> Array:
	return director.history.filter(func(item): return item.started and (type.is_empty() or item.type == type))

## Each document well in from where its planta is walked into (walking), no
## two on one planta, and none in a refuge.
func documents_placed(documents: Array) -> bool:
	var plantas := {}
	for document in documents:
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, document.position)
		if room.is_empty() or level.manifest.refuges.has(int(room.id)) or plantas.has(int(room.wing)): return false
		plantas[int(room.wing)] = true
		var metres := FLOOR.route_metres(level.manifest, FLOOR.entry_of(level.manifest, int(room.wing)))
		if float(metres.get(int(room.id), 0.0)) < PLACEMENT.MIN_FROM_START: return false
	return true

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.discoveries.found.clear()
	if FileAccess.file_exists(level.discoveries.save_path): DirAccess.remove_absolute(level.discoveries.save_path)
	await level.start_floor(81)
	var player = level.player
	var creature = level.locust
	creature.grace = 0.0
	var director = level.director
	director.set_physics_process(false)
	director.force = true
	# --- Documents ---
	var documents := get_nodes_in_group("hotel_documents")
	check("Dos documentos por piso", documents.size() == PLACEMENT.PER_FLOOR)
	var again := PLACEMENT.choose(level.manifest, "locust")
	check("Colocación reproducible por semilla", again.size() == documents.size() and again.all(func(spot): return documents.any(func(d): return d.entry_id == spot.entry and d.position.is_equal_approx(spot.position))))
	check("Documentos bien dentro de su planta, uno por planta y en ningún refugio", documents_placed(documents))
	# Measured from the floor of their own planta: the plantas are stacked.
	check("Documentos sobre muebles, no en el suelo", documents.all(func(d): return d.position.y - FLOOR.planta_y(FLOOR.planta_of(d.position.y)) > 0.6 and d.position.y - FLOOR.planta_y(FLOOR.planta_of(d.position.y)) < 0.9))
	check("Documentos distintos entre sí", documents[0].entry_id != documents[1].entry_id)
	var document = documents[0]
	# Walked up to from the middle of the room and looked at, the way it is
	# read in a game. A document lies on a piece of furniture and furniture
	# stands against a wall, so how close one can get to it depends on what it
	# is lying on: a few steps are tried, near to far, and the first one from
	# which it can be read counts.
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, document.position)
	var inward: Vector3 = FLOOR.position_of(room) - document.position
	inward.y = 0.0
	if inward.length() < 0.5: inward = Vector3(0, 0, 1)
	var readable := false
	for step in [1.0, 1.3, 1.6, 1.9]:
		player.position = document.position + inward.normalized() * step
		player.position.y = FLOOR.planta_y(FLOOR.planta_of(document.position.y)) + 0.04
		player.rotation.y = 0.0
		var eye: Vector3 = player.position + Vector3(0, player.eye_height, 0)
		var to_doc: Vector3 = document.position - eye
		player.rotation.y = atan2(-to_doc.x, -to_doc.z)
		player.camera.rotation.x = atan2(to_doc.y, Vector2(to_doc.x, to_doc.z).length())
		await frames(3)
		if level.focused_document() == document:
			readable = true
			break
	check("Mirar un documento lo enfoca para leer", readable)
	player.active = true
	level.open_document(document)
	check("Leer muestra la hoja y detiene al jugador", player.reading and is_instance_valid(level.ui.reading))
	var before: Vector3 = player.position
	Input.action_press("forward")
	await frames(20)
	Input.action_release("forward")
	check("Mientras lee no camina", player.position.distance_to(before) < 0.05)
	check("Leer lo guarda en el archivo", level.discoveries.has(document.entry_id))
	var saved := FileAccess.get_file_as_string(level.discoveries.save_path)
	check("El archivo persiste en disco", saved.contains(document.entry_id))
	level.close_document()
	await process_frame
	check("Cerrar devuelve el control", not player.reading and not is_instance_valid(level.ui.reading))
	check("Releer no duplica la entrada", not level.discoveries.record(document.entry_id) and level.discoveries.found.size() == 1)
	var fresh = load("res://game/services/discovery_service.gd").new()
	fresh.save_path = level.discoveries.save_path
	fresh.load_record()
	check("Una sesión nueva carga lo descubierto", fresh.has(document.entry_id))
	fresh.free()
	level.ui.menu("archive")
	check("El archivo del menú lista la entrada leída", level.ui.buttons.has(document.entry_id) and not level.ui.buttons[document.entry_id].disabled)
	level.ui.overlay.hide()
	# --- Director ---
	player.reading = false
	player.position = Vector3(0, 0.04, 0)
	await frames(2)
	creature.set_mode(creature.Mode.PATROL)
	creature.position = Vector3(400, 0.04, 400)
	director.tick(1.0)
	advance(director, 40)
	check("Ningún evento en los primeros 45 s", started(director).is_empty())
	# Keep exploring: a new room every few seconds.
	var rooms: Array = level.manifest.rooms.filter(func(r): return r.id != level.manifest.exit and int(r.wing) == 0 and not FLOOR.is_void(r) and not bool(r.get("landing", false)) and FLOOR.position_of(r).length() < 40.0)
	player.position = FLOOR.position_of(rooms[1]) + Vector3(0, 0.04, 0)
	await frames(2)
	advance(director, 8)
	var first := started(director)
	check("Explorando llega un evento con consecuencias", first.size() == 1 and first[0].type in ["fall", "steps"])
	check("Nunca apunta a la posición del jugador", first.size() == 1 and first[0].point.distance_to(player.global_position) >= 5.0)
	check("Evento en otra sala distinta a la del jugador", first.size() == 1 and FLOOR.room_at(level.manifest.rooms, first[0].point).get("id", -1) != FLOOR.room_at(level.manifest.rooms, player.global_position).get("id", -2))
	if first.size() == 1 and first[0].type == "fall":
		check("Un objeto que cae hace que investigue ese punto", creature.mode == creature.Mode.INVESTIGATE and creature.destination.distance_to(first[0].point) < 0.5)
	elif first.size() == 1:
		check("Los pasos guían su patrulla a una sala vecina", creature.mode == creature.Mode.PATROL and creature.guided and creature.destination.distance_to(first[0].point) < 0.5)
	advance(director, 3)
	check("Solo un evento activo a la vez", started(director).size() == 1)
	# A chase: nothing during it, then 30 s of rest after it ends.
	director.active = {}
	creature.set_mode(creature.Mode.CHASE)
	advance(director, 60)
	check("Nada durante la persecución", started(director).size() == 1)
	creature.set_mode(creature.Mode.PATROL)
	player.position = FLOOR.position_of(rooms[2]) + Vector3(0, 0.04, 0)
	await frames(2)
	advance(director, 29)
	check("Descanso de 30 s tras la persecución", started(director).size() == 1)
	advance(director, 3)
	check("Tras el descanso vuelve a haber eventos", started(director).size() == 2)
	# Staying put: only an ambient signal, the creature is left alone.
	director.active = {}
	creature.set_mode(creature.Mode.PATROL)
	creature.guided = false
	var patrol_before: Vector3 = creature.destination
	advance(director, 70)
	var ambient := started(director).slice(2)
	check("Quedarse quieto solo trae una señal ambiental", ambient.size() >= 1 and ambient.all(func(item): return item.type == "raps"))
	check("La señal ambiental no mueve a la criatura", creature.mode == creature.Mode.PATROL and creature.destination == patrol_before and not creature.guided)
	check("Los eventos se separan al menos 45 s", started(director).reduce(func(acc, item): return {"ok": acc.ok and item.time - acc.last >= director.SEPARATION, "last": item.time}, {"ok": true, "last": -INF}).ok)
	# Steps: the patrol is sent through a room next to the player's, not to the player.
	director.active = {}
	creature.set_mode(creature.Mode.PATROL)
	player.position = FLOOR.position_of(rooms[1]) + Vector3(0, 0.04, 0)
	await frames(2)
	var here := FLOOR.room_at(level.manifest.rooms, player.global_position)
	var guided_ok: bool = director.start("steps")
	var target := FLOOR.room_at(level.manifest.rooms, creature.destination)
	check("Los pasos guían la patrulla a una sala cercana que no es la del jugador", guided_ok and creature.guided and target.get("id", -1) != here.id and target.get("id", -1) >= 0)
	director.update_active()
	check("El evento de pasos sigue activo mientras camina", director.active.get("type", "") == "steps")
	creature.set_mode(creature.Mode.CHASE)
	director.update_active()
	check("Si se interrumpe, el evento termina", director.active.is_empty() and not creature.guided)
	creature.set_mode(creature.Mode.PATROL)
	director.force = false
	director.active = {}
	director.last_event = director.clock
	director.last_hostile = director.clock
	# The refuge stays calm.
	director.force = true
	var count := started(director).size()
	player.position = FLOOR.position_of(level.manifest.rooms[level.manifest.exit]) + Vector3(0, 0.04, 0)
	director.active = {}
	advance(director, 120)
	check("En el refugio no hay eventos", started(director).size() == count)
	var file := FileAccess.open("res://evidence/loop_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks, "director_history": director.history.map(func(item): return {"type": item.type, "time": item.time, "started": item.started})}, "\t"))
	file.close()
	print("LOOP_RESULT ", checks.size() - failed, "/", checks.size())
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
