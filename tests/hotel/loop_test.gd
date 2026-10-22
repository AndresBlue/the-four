extends SceneTree
## Single-floor loop: the pacing director's rules and events, and the
## documents placed on furniture, read and kept in the archive.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PLACEMENT := preload("res://game/world/generation/document_placement.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
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

## Runs the director for some seconds in one-second steps, the creature kept
## on its rounds where it stands (it does not walk here: the test moves it).
func advance(director, seconds: float) -> void:
	var creature = level.locust
	for i in int(seconds):
		if creature.mode != creature.Mode.PATROL: creature.set_mode(creature.Mode.PATROL)
		director.tick(1.0)

## The leads the director gave (and the creature took), of a kind or any.
const LEAD_KINDS := ["merodea", "emboscada", "pasa", "retirada", "quieto", "vuelve", "entre bastidores", "cordura"]
func leads(director, kind := "") -> Array:
	return director.history.filter(func(item): return bool(item.get("ok", false)) and item.kind in LEAD_KINDS and (kind.is_empty() or item.kind == kind))

## Rooms of the first planta to stand in: not a refuge, its lobby or the void.
func standing_rooms() -> Array:
	var shut: Array = level.off_limits_rooms()
	return level.manifest.rooms.filter(func(r): return int(r.wing) == 0 and not FLOOR.is_void(r) and not shut.has(int(r.id)) and not bool(r.get("landing", false)))

## Every hard rule of a lead, checked from outside against where the player
## stood when it was given.
func lead_fair(entry: Dictionary, player_at: Vector3, hidden: bool) -> bool:
	var point: Vector3 = entry.point
	var room := FLOOR.room_at(level.manifest.rooms, point)
	var theirs := FLOOR.room_at(level.manifest.rooms, player_at)
	if room.is_empty() or level.off_limits_rooms().has(int(room.id)): return false
	if not theirs.is_empty() and int(room.id) == int(theirs.id): return false
	if String(entry.kind) == "cordura": return true
	if point.distance_to(player_at) < 10.0: return false
	var walk := float(FLOOR.route_metres(level.manifest, int(theirs.id)).get(int(room.id), INF)) if not theirs.is_empty() else INF
	if walk < 12.0: return false
	if hidden and point.distance_to(player_at) < 20.0: return false
	return true

## Each document well in from where its planta is walked into (walking), no
## two on one planta, and none in a refuge.
## The piece of furniture a document lies on: the corner prop of its room
## nearest to it.
func prop_under(spot: Dictionary) -> String:
	var room: Dictionary = level.manifest.rooms[int(spot.room)]
	var best := ""
	var nearest := INF
	for prop in room.props:
		var at: Vector3 = FLOOR.position_of(room) + GEOMETRY.prop_transform(room, prop).origin
		var away := Vector2(at.x - spot.position.x, at.z - spot.position.z).length()
		if away < nearest:
			nearest = away
			best = String(prop.kind)
	return best

func documents_placed(documents: Array) -> bool:
	var plantas := {}
	for document in documents:
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, document.global_position)
		if room.is_empty() or level.manifest.refuges.has(int(room.id)) or plantas.has(int(room.wing)): return false
		plantas[int(room.wing)] = true
		var metres := FLOOR.route_metres(level.manifest, FLOOR.entry_of(level.manifest, int(room.wing)))
		if float(metres.get(int(room.id), 0.0)) < PLACEMENT.MIN_FROM_START: return false
	return true

## The director's rules, played out on its own clock: quiet when it has
## nothing to direct, leads that never point at the player, phases that rest
## after a chase or a death, a distraction for a team that hides, and the
## burnt-out mind played through it instead of told to the creature.
func director_rules(player, creature, director) -> void:
	creature.set_physics_process(false)
	player.set_physics_process(false)
	player.reading = false
	var rooms := standing_rooms()
	# The player in one room, the creature far off (it never walks here).
	var home: Dictionary = rooms[rooms.size() / 3]
	var metres := FLOOR.route_metres(level.manifest, int(home.id))
	var far: Dictionary = home
	for room in rooms:
		if float(metres.get(int(room.id), 0.0)) > float(metres.get(int(far.id), 0.0)): far = room
	player.global_position = FLOOR.position_of(home) + Vector3(0, 0.04, 0)
	creature.global_position = FLOOR.position_of(far) + Vector3(0, 0.04, 0)
	creature.set_mode(creature.Mode.PATROL)
	creature.grace = 10.0
	director.force = true
	advance(director, 5)
	check("En la gracia de la criatura el director calla", leads(director).is_empty() and director.silent())
	creature.grace = 0.0
	# A long stretch of play, the player moving about now and then and
	# sometimes hiding: every lead within the rules, and the moves varied.
	var unfair := 0
	var count_before := 0
	var hidden := false
	for second in 600:
		if second % 40 == 0:
			var next: Dictionary = rooms[(second / 40 * 7) % rooms.size()]
			player.global_position = FLOOR.position_of(next) + Vector3(0, 0.04, 0)
			hidden = second % 120 == 80
			player.hidden = hidden
		creature.global_position = FLOOR.position_of(far) + Vector3(0, 0.04, 0)
		advance(director, 1)
		var given := leads(director)
		for entry in given.slice(count_before):
			if not lead_fair(entry, player.global_position, hidden): unfair += 1
		count_before = given.size()
	player.hidden = false
	var kinds := {}
	for entry in leads(director): kinds[entry.kind] = true
	check("En diez minutos da pistas (%d)" % leads(director).size(), leads(director).size() >= 8)
	check("Ninguna apunta a la sala del jugador ni a su lado, ni cerca de un escondido", unfair == 0)
	check("Y juega jugadas distintas (%s)" % ", ".join(kinds.keys()), kinds.size() >= 3)
	check("La criatura sigue la pista: su destino queda en la zona", not creature.lead_active() or creature.lead.rooms.has(int(FLOOR.room_at(level.manifest.rooms, creature.destination).get("id", -1))))
	# A chase: hands off while it lasts, then a rest with only backstage leads.
	creature.set_mode(creature.Mode.CHASE)
	director.tick(1.0)
	check("Durante una persecución, pico y manos fuera", director.phase == director.Phase.PEAK)
	var before: int = leads(director).size()
	creature.set_mode(creature.Mode.PATROL)
	advance(director, 25)
	var during_rest := leads(director).slice(before)
	var from_room := int(FLOOR.room_at(level.manifest.rooms, player.global_position).get("id", -1))
	check("Tras la persecución descansa: solo la manda lejos", director.phase == director.Phase.RELIEF and during_rest.all(func(entry): return entry.kind == "entre bastidores"))
	check("Y lejos de verdad: a más de 45 m andando del jugador", during_rest.all(func(entry): return float(FLOOR.route_metres(level.manifest, from_room).get(int(entry.room), 0.0)) >= director.BACKSTAGE_MIN))
	advance(director, 10)
	check("Pasado el descanso vuelve a acechar", director.phase == director.Phase.BUILD)
	# A death: a longer rest, and the leads keep further off for a while.
	level.session.participants[1] = level.session.Life.DEAD
	director.tick(1.0)
	level.session.participants[1] = level.session.Life.EXPLORING
	check("Tras una muerte, respiro largo y pistas más lejos", director.phase == director.Phase.RELIEF and director.rest_until - director.clock >= director.REST_AFTER_DEATH - 1.5 and director.nearest_prowl() > director.PROWL_MIN)
	# The team hidden and the creature walking up to it having seen nobody:
	# something falls over far away, and it goes to look.
	var near_room: Dictionary = home
	for room in rooms:
		var gap := float(metres.get(int(room.id), INF))
		if gap > 6.0 and gap < 14.0:
			near_room = room
			break
	player.global_position = FLOOR.position_of(home) + Vector3(0, 0.04, 0)
	player.hidden = true
	creature.global_position = FLOOR.position_of(near_room) + Vector3(0, 0.04, 0)
	creature.detection = 0.0
	director.last_distraction = -INF
	director.rest(30.0)
	director.tick(1.0)
	var fell: Array = director.history.filter(func(entry): return entry.kind == "distracción")
	check("A un equipo escondido le distrae a la criatura, lejos", fell.size() == 1 and creature.mode == creature.Mode.INVESTIGATE and creature.destination.distance_to(player.global_position) >= director.DISTRACT_FAR - 3.0)
	player.hidden = false
	creature.set_mode(creature.Mode.PATROL)
	# A burnt-out mind: the creature is sent round the rooms near it -- never
	# its own -- and opens a wardrobe there, instead of being told the spot.
	player.global_position = FLOOR.position_of(home) + Vector3(0, 0.04, 0)
	player.set_burnt(true)
	creature.global_position = FLOOR.position_of(far) + Vector3(0, 0.04, 0)
	director.rest_until = director.clock
	director.set_phase(director.Phase.BUILD)
	director.burnt_next = director.clock
	advance(director, 2)
	var burnt: Array = leads(director, "cordura")
	check("Con la cordura a cero, el director la acerca a su zona sin darle el sitio", not burnt.is_empty() and lead_fair(burnt[-1], player.global_position, false) and bool(creature.lead.get("sniff", false)))
	player.set_burnt(false)
	# The refuge stays calm: nothing is played for somebody in there.
	player.global_position = FLOOR.position_of(level.manifest.rooms[level.refuge_room()]) + Vector3(0, 0.04, 0)
	var calm: int = director.history.size()
	advance(director, 120)
	check("En el refugio no se juega nada", director.history.slice(calm).all(func(entry): return entry.kind == "fase"))
	director.force = false
	creature.set_physics_process(true)
	player.set_physics_process(true)

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.discoveries.found.clear()
	if FileAccess.file_exists(level.discoveries.save_path): DirAccess.remove_absolute(level.discoveries.save_path)
	# The floor as two or three play it (hotel_main.drawn_for): what follows
	# walks known places of it.
	level.drawn_for = 2
	await level.start_floor(81)
	var player = level.player
	var creature = level.locust
	creature.grace = 0.0
	var director = level.director
	director.set_physics_process(false)
	director.force = true
	# --- Documents ---
	# On a top, or shut in a suitcase (document_placement.HOLDERS).
	var documents := get_nodes_in_group("hotel_documents")
	var shut: Array = level.containers.filter(func(piece): return not piece.document.is_empty())
	check("Dos documentos por piso", documents.size() + shut.size() == PLACEMENT.PER_FLOOR)
	var again := PLACEMENT.choose(level.manifest, "locust", level.hotel.containers)
	check("Colocación reproducible por semilla", again.size() == PLACEMENT.PER_FLOOR and again.all(func(spot): return (int(spot.container) >= 0 and level.containers[int(spot.container)].document == spot.entry) or documents.any(func(d): return d.entry_id == spot.entry and d.position.is_equal_approx(spot.position))))
	check("Documentos bien dentro de su planta, uno por planta y en ningún refugio", documents_placed(documents + shut))
	# Measured from the floor of their own planta: the plantas are stacked.
	check("Documentos sobre muebles, no en el suelo", documents.all(func(d): return d.position.y - FLOOR.planta_y(FLOOR.planta_of(d.position.y)) > 0.6 and d.position.y - FLOOR.planta_y(FLOOR.planta_of(d.position.y)) < 0.9))
	check("Ni en la mesilla del teléfono, y si no, en una maleta y con su papel a la vista", again.all(func(spot): return int(spot.container) >= 0 or prop_under(spot) != "phone") and shut.all(func(piece): return piece.kind == "luggage" and is_instance_valid(piece.note) and piece.digit < 0))
	var entries: Array = documents.map(func(d): return d.entry_id) + shut.map(func(piece): return piece.document)
	check("Documentos distintos entre sí", entries.size() == 2 and entries[0] != entries[1])
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
	var official: bool = load("res://game/discovery/discovery_catalog.gd").entry(document.entry_id).has("form")
	var form_script: Script = load("res://game/ui/hotel_form.gd")
	check("Un papel del hotel se lee en su impreso, a máquina, y los demás como texto", level.ui.reading.get_children().any(func(node): return node.get_script() == form_script) == official)
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
	# A document shut in a suitcase (document_placement.HOLDERS) is read the
	# moment the suitcase is gone through, by whoever does, and its paper
	# leaves with them; the suitcase opens its lid and makes no sound.
	var suitcase = level.containers.filter(func(piece): return piece.kind == "luggage" and not piece.searched and piece.digit < 0 and piece.hint < 0 and piece.document.is_empty())[0]
	suitcase.document = document.entry_id
	suitcase.plant_note()
	level.apply_search(level.containers.find(suitcase), true, false, player.slot)
	await frames(60)
	check("Un documento en una maleta se lee al abrirla, y su papel se va con quien la abre", level.interaction.reading_entry == document.entry_id and is_instance_valid(level.ui.reading) and not is_instance_valid(suitcase.note) and suitcase.silent() and String(suitcase.left.get("part", "")).begins_with("lid"))
	level.close_document()
	await process_frame
	level.ui.menu("archive")
	check("El archivo del menú lista la entrada leída", level.ui.buttons.has(document.entry_id) and not level.ui.buttons[document.entry_id].disabled)
	# All sixteen are there, and the one read opens as its file.
	var slots: int = level.ui.column.find_children("*", "Button", true, false).filter(func(button): return String(button.text).contains("SIN DESCUBRIR") or level.ui.buttons.values().has(button)).size()
	level.ui.buttons[document.entry_id].pressed.emit()
	var body: String = String(load("res://game/discovery/discovery_catalog.gd").entry(document.entry_id).body)
	var shown: bool = is_instance_valid(level.ui.dossier) and level.ui.dossier.find_children("*", "Label", true, false).any(func(words): return String(words.text) == body)
	level.ui.close_dossier()
	check("El archivo enseña los dieciséis, y el leído se abre como su ficha", slots >= 16 and shown and not is_instance_valid(level.ui.dossier))
	level.ui.overlay.hide()
	# --- Director ---
	await director_rules(player, creature, director)
	var file := FileAccess.open("res://evidence/loop_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks, "director_history": director.history.map(func(item): return {"kind": item.kind, "time": item.t, "phase": item.phase})}, "\t"))
	file.close()
	print("LOOP_RESULT ", checks.size() - failed, "/", checks.size())
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)
