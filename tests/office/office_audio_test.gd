extends SceneTree
## The Lurker's sound on a built floor 2 (spec_f3_integration 9.4), on the real
## clock: her duct bus; out of a duct by the grille of the listener's room, or
## by the next room's; nothing to another planta or to a room where nothing of
## her is heard; never through a wall; real samples on the duct bus; her claws
## by what is under each hand; the warning heard clean of her other sounds;
## her aura out of the grille and without its breath; the hum of a room she
## drinks lower; her shriek captioned and frightening; her claws outside a
## riding car; her presence only over a locker.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const VOICE := preload("res://game/enemies/lurker/lurker_voice.gd")
const SEEDS := [81, 7, 2026, 11]
const EAR := Vector3(0, 1.6, 0)
var checks: Array = []
var failed := 0
var level
var lurker
var audio
var room_r := {}
var exit_e := -1

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func wait(seconds: float) -> void: await create_timer(seconds).timeout

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "lurker"
	level.set_floor(2)
	var seed_used := -1
	for seed_value in SEEDS:
		await level.start_floor(int(seed_value), false, [1], "equilibrada")
		if find_room():
			seed_used = int(seed_value)
			break
	lurker = level.creature
	audio = level.world_audio
	if seed_used < 0 or lurker == null or lurker.kind_id() != &"lurker":
		check("Una oficina de la planta 1 con rejilla de techo, y ella en el piso", false)
		finish(seed_used)
		return
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.set_physics_process(false)
	lurker.thinking = false
	lurker.grace = 0.0
	# Automation runs with the world's sound off: heard here, as in
	# spatial_audio_test, at its mix.
	audio.enabled = true
	level.settings.set_value("master", 0.8)
	level.settings.set_value("effects", 0.8)
	level.settings.set_value("threat", 0.85)
	bus()
	await grille()
	await walls()
	await real_audio()
	await surfaces()
	await clean_cue()
	await aura()
	await hum()
	await shriek_and_car()
	await presence()
	finish(seed_used)

func finish(seed_used: int) -> void:
	var file := FileAccess.open("res://evidence/office_audio_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks, "seed": seed_used}, "\t"))
	print("OFFICE_AUDIO_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	if level != null: level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)

## R: the first room of planta 1 with a ceiling grille, not off-limits and
## with a ceiling of hers; E: that grille.
func find_room() -> bool:
	var off: Array = level.off_limits_rooms()
	var ducts = level.creature.ducts
	if ducts == null: return false
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != 0 or off.has(int(room.id)) or not level.creature.shell.tray_of.has(int(room.id)): continue
		for e in ducts.exits.size():
			if int(ducts.exits[e].room) == int(room.id) and String(ducts.exits[e].kind) == "ceiling":
				room_r = room
				exit_e = e
				return true
	return false

func centre_of(room: Dictionary) -> Vector3: return FLOOR.position_of(room)

func listen_at(point: Vector3) -> void:
	level.player.global_position = point
	await physics_frame
	await physics_frame

func knock() -> Dictionary:
	lurker.voice.knock_clock = 0.0
	lurker.voice.travel(1.0 / 60.0, 1.0)
	return lurker.voice.last

func in_duct_at_e() -> void:
	lurker.place_in_exit(exit_e)
	await physics_frame

## Case 1.
func bus() -> void:
	var count := 0
	var index := -1
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == "Ducts":
			count += 1
			index = i
	var eq := false
	var box := false
	if index >= 0:
		for k in AudioServer.get_bus_effect_count(index):
			if AudioServer.get_bus_effect(index, k) is AudioEffectEQ6: eq = true
			if AudioServer.get_bus_effect(index, k) is AudioEffectReverb: box = true
	check("Hay un bus Ducts, uno solo, que manda al de la criatura, con su ecualizador y su caja", count == 1 and AudioServer.get_bus_send(index) == &"Creature" and eq and box, "%d %s %s %s" % [count, str(AudioServer.get_bus_send(index)) if index >= 0 else "", str(eq), str(box)])

## Cases 2, 3 and 5.
func grille() -> void:
	await in_duct_at_e()
	var grille_at: Vector3 = lurker.ducts.exits[exit_e].position
	var listener := centre_of(room_r) + EAR
	await listen_at(centre_of(room_r))
	var route: Dictionary = lurker.sound_route(listener)
	check("Desde el ducto, en su sala se la oye por la rejilla, en el bus de los ductos", bool(route.audible) and (route.position as Vector3).distance_to(grille_at) <= 0.02 and String(route.get("bus", "")) == "Ducts", "%s a %.2f m de la rejilla" % [str(route.get("bus", "")), (route.position as Vector3).distance_to(grille_at)])
	var last := knock()
	check("Un golpe suyo dentro del ducto suena en la rejilla, en el bus de los ductos", String(last.path).contains("knock_") and (last.point as Vector3).distance_to(grille_at) <= 0.02 and String(last.bus) == "Ducts", str(last))
	# Her steps come in runs (the author, 25 October 2026): 6 to 8 very fast,
	# then a silence, never a steady pace.
	var gaps: Array = []
	lurker.voice.run_left = 0
	for i in 60: gaps.append(lurker.voice.next_step())
	var runs: Array = []
	var count := 0
	for gap in gaps:
		count += 1
		if float(gap) >= VOICE.RUN_REST.x:
			runs.append(count)
			count = 0
	check("Sus pasos en el ducto van en tandas: de 6 a 8 muy rápidos y un silencio", runs.size() >= 6 and runs.all(func(n): return n >= VOICE.RUN.x and n <= VOICE.RUN.y) and gaps.all(func(g): return float(g) <= VOICE.RUN_STEP.y or float(g) >= VOICE.RUN_REST.x), str(runs))
	var q := {}
	var q_exits: Array = []
	for other in level.manifest.adjacency[int(room_r.id)]:
		var room: Dictionary = level.manifest.rooms[int(other)]
		if int(room.get("wing", -1)) != 0 or level.off_limits_rooms().has(int(other)): continue
		var mine: Array = []
		for e in lurker.ducts.exits.size():
			# A closed tile lets no sound through (spec_f3_aggression): its grilles and gaps.
			if int(lurker.ducts.exits[e].room) == int(other) and not String(lurker.ducts.exits[e].kind) in ["hatch", "tile"]: mine.append(lurker.ducts.exits[e].position)
		if not mine.is_empty():
			q = room
			q_exits = mine
			break
	if not q.is_empty():
		var there := centre_of(q) + EAR
		await listen_at(centre_of(q))
		var other_route: Dictionary = lurker.sound_route(there)
		var near := INF
		for p in q_exits: near = minf(near, (other_route.position as Vector3).distance_to(p))
		check("En la sala de al lado se la oye por la rejilla de esa sala", bool(other_route.audible) and near <= 0.02, "a %.2f m" % near)
	var high := {}
	for room in level.manifest.rooms:
		if not FLOOR.is_void(room) and int(room.get("wing", -1)) == 1:
			high = room
			break
	var up := centre_of(high) + EAR
	check("Desde otra planta no se la oye", not bool(lurker.sound_route(up).audible))

## Cases 6 and 6b.
func walls() -> void:
	await in_duct_at_e()
	var heard := 0
	var through := 0
	var tried := 0
	for room in level.manifest.rooms:
		if tried >= 20: break
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != 0: continue
		# Shelves are no wall, and the middle of an archive stands among them.
		if int(room.type) in [OFFICE.ARCHIVE, OFFICE.MOBILE_ARCHIVE]: continue
		var listener := centre_of(room) + EAR
		if level.point_protected(listener): continue
		tried += 1
		await listen_at(centre_of(room))
		if not bool(lurker.sound_route(listener).audible): continue
		var last := knock()
		heard += 1
		if audio.occluded(last.point, RID(), listener): through += 1
	check("Donde se la oye, nunca a través de una pared (%d de %d salas)" % [heard, tried], heard > 0 and through == 0, "%d tapadas" % through)
	var lobby := {}
	for r in level.off_limits_rooms():
		var room: Dictionary = level.manifest.rooms[int(r)]
		if int(room.get("wing", -1)) == 0:
			lobby = room
			break
	if lobby.is_empty():
		check("Un vestíbulo protegido en la planta 1", false)
		return
	var safe := centre_of(lobby) + EAR
	await listen_at(centre_of(lobby))
	# The voice keeps 32 sounds at most: a count from an empty log.
	lurker.voice.history.clear()
	var before: int = lurker.voice.history.size()
	for i in 30: knock()
	var felt: Array = lurker.presence_route(safe)
	check("En el vestíbulo protegido no se oye nada de ella", level.point_protected(safe) and not bool(lurker.sound_route(safe).audible) and float(felt[0]) == INF and lurker.voice.history.size() == before)

## Case 7.
func real_audio() -> void:
	await in_duct_at_e()
	await listen_at(centre_of(room_r))
	var index := AudioServer.get_bus_index("Ducts")
	var capture := AudioEffectCapture.new()
	# The whole window and its tail: a two-second buffer keeps only its last part.
	capture.buffer_length = 4.0
	AudioServer.add_bus_effect(index, capture)
	var near := await knock_peak(capture)
	var high := {}
	for room in level.manifest.rooms:
		if not FLOOR.is_void(room) and int(room.get("wing", -1)) == 1:
			high = room
			break
	await listen_at(centre_of(high))
	var far := await knock_peak(capture)
	AudioServer.remove_bus_effect(index, AudioServer.get_bus_effect_count(index) - 1)
	check("Sus golpes suenan de verdad en el bus de los ductos desde su sala, y nada desde otra planta", near > 1e-5 and far < 1e-6, "%s %s" % [str(near), str(far)])

func knock_peak(capture: AudioEffectCapture) -> float:
	# Past the tail of what was playing. Her runs of knocks end in a rest of up to
	# 2.6 s (lurker_voice RUN_REST): a second's window can fall inside it and hear
	# nothing of her, so the window is three.
	await wait(1.6)
	capture.clear_buffer()
	# A run starts with the window: far off on her round the rest between two
	# is longer than it (lurker_voice RUNS), and this measures the bus, not that.
	lurker.voice.knock_clock = 0.0
	lurker.voice.run_left = 0
	var peak := 0.0
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 3000:
		lurker.voice.travel(1.0 / 60.0, 2.0)
		await process_frame
	await wait(0.3)
	for frame in capture.get_buffer(capture.get_frames_available()): peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	return peak


## Case 8: on the surface, out of the duct.
func surfaces() -> void:
	lurker.place_over(centre_of(room_r))
	await physics_frame
	await listen_at(centre_of(room_r))
	var ceiling := centre_of(room_r) + Vector3(0, OFFICE.height_of(room_r), 0)
	var tile := await step(ceiling, Vector3.DOWN)
	check("Una mano en el falso techo de su sala suena a placa", String(tile.path).contains("/tile_") == OFFICE.false_ceiling(room_r) and String(tile.material) == ("tile" if OFFICE.false_ceiling(room_r) else "hard"), str(tile))
	var block := {}
	var veneer := {}
	for room in level.manifest.rooms:
		if FLOOR.is_void(room): continue
		if block.is_empty() and OFFICE.wall_material(room) == "block": block = room
		if veneer.is_empty() and OFFICE.wall_material(room) == "veneer" and not OFFICE.hard_floor(room): veneer = room
	check("Hay sala de chapa en la planta 3 (el despacho de dirección)", not veneer.is_empty())
	if not block.is_empty():
		var hard := await step(centre_of(block) + Vector3(0, 1.0, 0), Vector3(1, 0, 0))
		check("En una pared de bloque, a duro", String(hard.path).contains("/hard_") and String(hard.material) == "hard", str(hard))
		if not veneer.is_empty():
			var wood := await step(centre_of(veneer) + Vector3(0, 1.0, 0), Vector3(1, 0, 0))
			check("En la chapa de madera de la planta 3, a madera", String(wood.path).contains("/wood_") and String(wood.material) == "wood", str(wood))
			var soft := await step(centre_of(veneer) + Vector3(0, 0.02, 0), Vector3.UP)
			check("En la moqueta, el duro apagado y 8 dB por debajo", String(soft.path).contains("/hard_") and float(soft.cutoff) <= VOICE.SOFT_CUTOFF and absf(float(hard.gain) - float(soft.gain) - 8.0) < 0.01, "%s %s" % [str(hard), str(soft)])

func step(point: Vector3, normal: Vector3) -> Dictionary:
	await wait(VOICE.STEP_GAP + 0.02)
	# The timer runs on frame time and STEP_GAP on the wall clock: a slow frame
	# left them 0.088 s apart, so the gap is cleared outright.
	lurker.voice.step_at = -INF
	lurker.voice.footfall(point, 0.8, normal)
	return lurker.voice.last

## Case 9, the clean half second: her warning on this machine, and nothing
## of hers starts from CLEAN before it is due until it is over.
func clean_cue() -> void:
	lurker.voice.history.clear()
	await in_duct_at_e()
	await listen_at(centre_of(room_r))
	var face: Vector3 = level.player.camera.global_position + Vector3(0, 0.4, 1.5)
	lurker.play_cue(int(level.player.slot), 0, face, 1.2)
	check("El aviso suena en los oídos de la víctima, desde ella", String(audio.last_cue.get("path", "")).contains("lurker/cue_") and bool(audio.last_cue.get("mine", false)) and not audio.ears_hold.is_empty() and (audio.ears_hold.point as Vector3).distance_to(face) <= 0.1, str(audio.last_cue))
	var at_start: int = lurker.voice.history.size()
	knock()
	var early_ok: bool = knocks_since(at_start) == 1
	await wait(1.2 - VOICE.CLEAN + 0.1)
	var before: int = lurker.voice.history.size()
	knock()
	await wait(VOICE.STEP_GAP + 0.02)
	lurker.voice.footfall(centre_of(room_r) + Vector3(0, 2.5, 0), 0.8, Vector3.DOWN)
	var hushed: bool = lurker.voice.history.size() == before
	lurker.cue_over(0, "saved")
	knock()
	check("Antes de su medio segundo limpio suena; dentro de él, nada suyo; acabado el aviso, vuelve", early_ok and hushed and knocks_since(before) == 1)

## The knocks the voice made from entry `from` of its log on: scrapes are
## in the log too, and the log is cut at 32, so sizes are no count of them.
func knocks_since(from: int) -> int:
	var count := 0
	for entry in lurker.voice.history.slice(from):
		if String(entry.get("path", "")).contains("knock_"): count += 1
	return count

## Case 10.
func aura() -> void:
	await in_duct_at_e()
	await listen_at(centre_of(room_r))
	await wait(1.0)
	var listener: Vector3 = audio.listener_position()
	var route: Dictionary = lurker.sound_route(listener)
	var aura = audio.aura
	check("El aura la siente por la rejilla, sin respiración", aura.cue_point != Vector3.INF and (aura.cue_point as Vector3).distance_to(route.position) <= 0.15 and absf(float(aura.route_distance) - float(route.distance)) <= 0.5 and not aura.breath.playing and aura.rise == 0.0, "%s %s %.2f %.2f" % [str(aura.cue_point), str(route.position), float(aura.route_distance), float(route.distance)])

## Case 11: the hum of a room she drinks (the battens are what hums).
func hum() -> void:
	var room := -1
	var lamp := Vector3.ZERO
	var off: Array = level.off_limits_rooms()
	for r in level.manifest.rooms:
		# Not one of the floor's dark rooms: there is no lamp alight there to drink.
		if FLOOR.is_void(r) or off.has(int(r.id)) or OFFICE.lamp_of(r) != "batten" or level.hotel.dark_ids.has(int(r.id)) or not lurker.shell.tray_of.has(int(r.id)): continue
		room = int(r.id)
		lamp = centre_of(r)
		break
	if room < 0:
		check("Una sala con regletas", false)
		return
	level.hotel.set_room_power(room, true)
	lurker.place_over(lamp, lamp + Vector3(1, 0, 0))
	await listen_at(lamp + Vector3(1.0, 0, 0))
	await wait(1.5)
	var lowered := false
	var heard := 0
	for player in audio.hums:
		var entry = player.get_meta("entry") if player.has_meta("entry") else null
		if entry == null or not player.playing or int(entry.light.get_meta("room", -1)) != room: continue
		heard += 1
		if player.pitch_scale < 1.0: lowered = true
	check("El zumbido de la sala que bebe suena más grave", level.hotel.drained(room) > 0.0 and lowered, "%d zumbidos de la sala, bebida %.2f" % [heard, float(level.hotel.drained(room))])

## Her shriek near the listener (3.7): its caption, and the mind it costs
## SANITY_SHRIEK where the difficulty wears minds; and her claws outside a car
## this machine's player rides (3.8), on the creature's bus to one side.
func shriek_and_car() -> void:
	await listen_at(centre_of(room_r))
	var ear: Vector3 = level.player.camera.global_position
	var forward: Vector3 = -level.player.camera.global_basis.z
	var at: Vector3 = ear + Vector3(forward.x, 0, forward.z).normalized() * 3.0
	level.player.sanity = 80.0
	level.sanity.sight_rest = 0.0
	level.sanity.sight_paid = 0.0
	audio.caption_lock = 0.0
	audio.caption_text = ""
	lurker.on_event("scare", [int(level.player.slot), "linterna", at])
	var worn: bool = level.rule("sanity") == 1
	var cost: float = level.sanity.SANITY_SHRIEK
	check("Su chillido cerca lleva su subtítulo y le cuesta a la cordura", audio.caption_text == "[Un chillido]" and absf(level.player.sanity - (80.0 - cost if worn else 80.0)) < 0.01, "%s %.2f" % [audio.caption_text, level.player.sanity])
	var lifts = level.get("lifts")
	if lifts == null:
		check("El montacargas del piso", false)
		return
	var point: Vector3 = level.player.global_position
	lifts.boarding = {"point": point, "time": 0.0, "car": 0}
	var sides := 0.0
	var placed := true
	for i in 2:
		lurker.voice.outside_car()
		var off: Vector3 = (lurker.voice.last.point as Vector3) - point
		placed = placed and String(lurker.voice.last.bus) == "Creature" and absf(Vector2(off.x, off.z).length() - 1.3) < 0.01 and off.y >= 1.0 and off.y <= 2.4
		sides += signf(off.cross(forward).y)
	lifts.boarding = {}
	check("Fuera del coche se la oye arañar a un lado y al otro, en el bus de la criatura", placed and sides == 0.0, str(lurker.voice.last))

## Case 12: what world_audio does with her words (her mind is off: with the
## listener in sight she would hunt them instead of waiting).
func presence() -> void:
	var hide: Node3D = null
	for node in get_nodes_in_group("hotel_hides"):
		var spot: Vector3 = (node as Node3D).global_position
		var room := FLOOR.room_at(level.manifest.rooms, spot)
		if room.is_empty() or int(room.get("wing", -1)) != 0 or level.off_limits_rooms().has(int(room.id)): continue
		if lurker.shell.state_at(spot + Vector3.UP) == null: continue
		hide = node
		break
	if hide == null:
		check("Una taquilla en la planta 1", false)
		return
	var room := FLOOR.room_at(level.manifest.rooms, hide.global_position)
	var forward: Vector3 = hide.global_basis.z
	var stand: Vector3 = hide.global_position + Vector3(forward.x, 0, forward.z).normalized() * 3.0
	stand.y = float(room.get("py", 0.0))
	await listen_at(stand)
	lurker.place_over(hide.global_position + Vector3(forward.x, 0, forward.z).normalized() * 1.0)
	lurker.word = &"stalk"
	await wait(1.0)
	var quiet: bool = not audio.presence.playing
	lurker.place_over(hide.global_position)
	lurker.word = &"wait"
	await wait(1.5)
	var ceiling := float(room.get("py", 0.0)) + OFFICE.height_of(room)
	var at: Vector3 = audio.presence.global_position
	var near := Vector2(at.x - hide.global_position.x, at.z - hide.global_position.z).length()
	check("Su presencia no suena acechando, y sí encima de una taquilla, bajo el techo", quiet and audio.presence.playing and at.y < ceiling - 0.1 and near <= 1.2, "%s %s a %.2f m, %.2f bajo el techo" % [str(quiet), str(audio.presence.playing), near, ceiling - at.y])
