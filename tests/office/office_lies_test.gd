extends SceneTree
## The Lurker's lies on a built floor 2 (spec_f3_integration 9.5): she
## chooses them herself, at the hotel's pace; each planta lies with its own
## (the tube and the phone on planta 1, the lever and the timer on 2, the fans
## and the ducts on 3) and only where it fits; none of them drinks a light,
## plays her warning or any sound of hers that means something, touches an
## objective, follows the listener or captions; one lamp fails alone; with the
## red lever running there is no timer and with the fans running no fans nor
## ducts; in the freight lobby nothing of her; in a locker the mind wears as
## in the dark; and a room she drinks stays lit for the mind.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const LIES := preload("res://game/app/hallucinations/lurker_hallucinations.gd")
const SANITY := preload("res://game/app/sanity.gd")
const EVERYWHERE := ["garras", "ducto", "telefono", "maquina", "fotocopiadora", "silla", "persiana", "lampara"]
const OWN := {0: ["tubo"], 1: ["palanca", "tictac"], 2: ["ventiladores"]}
const WANTED := {0: ["tubo", "telefono"], 1: ["palanca", "tictac"], 2: ["ventiladores", "ducto"]}
var checks: Array = []
var failed := 0
var level
var lies

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "lurker"
	level.set_floor(2)
	await level.start_floor(81, false, [1], "equilibrada")
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.set_physics_process(false)
	var creature = level.creature
	creature.thinking = false
	creature.place_over(Vector3.ZERO)
	creature.set_physics_process(false)
	creature.global_position = Vector3(0, -80, 0)
	level.hotel.reduced = false
	own_lies()
	await cadence()
	await plantas()
	await one_lamp()
	await conditions()
	await locker()
	drained()
	finish()

func finish() -> void:
	var file := FileAccess.open("res://evidence/office_lies_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("OFFICE_LIES_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)

func frames(count: int) -> void:
	for i in count: await physics_frame

func stand_at(point: Vector3) -> void:
	level.player.global_position = point
	level.player.velocity = Vector3.ZERO
	await frames(2)

## Case 1.
func own_lies() -> void:
	lies = level.sanity.creature_lies()
	check("Sus mentiras son suyas, y las elige ella", lies != null and lies.get_script() == LIES and level.sanity.lies_tell_own())
	lies.rng.seed = 81

## Case 2: the pace.
func cadence() -> void:
	var room := first_room(0, func(r): return not level.point_protected(FLOOR.position_of(r)))
	await stand_at(FLOOR.position_of(room) + Vector3(0, 0.04, 0))
	level.player.sanity = 30.0
	var gone: float = 1.0 - 30.0 / SANITY.SANITY_UNEASY
	var mid := lerpf(SANITY.HALLUCINATION_WAIT.y, SANITY.HALLUCINATION_WAIT.x, gone) * LIES.WAIT_SCALE
	var inside := true
	for i in 50:
		level.sanity.hallucination_wait = 0.0
		level.sanity.hallucinate(1.0 / 60.0)
		var wait: float = level.sanity.hallucination_wait
		if wait < mid * 0.7 - 1e-4 or wait > mid * 1.3 + 1e-4: inside = false
	check("A su ritmo: cada espera entre el 70 y el 130 % de la del hotel", inside, "%.2f" % mid)
	level.player.sanity = 100.0

## Case 3 and 4: 200 lies on each planta, and what none of them does.
func plantas() -> void:
	level.world_audio.enabled = true
	var power = level.objective(&"power")
	var air = level.objective(&"air")
	var files = level.objective(&"files")
	var power_before: Array = [int(power.red), power.get("on_order").duplicate() if power.get("on_order") != null else []]
	var air_before := float(air.running_until)
	var files_before: String = var_to_str(files.get("requests"))
	var bad_kinds: Array = []
	var never: Array = []
	var follows := 0
	var masked := 0
	var captions := 0
	for wing in 3:
		var spot := await spot_for(wing)
		if spot == Vector3.INF:
			check("Un sitio de la planta %d donde caben sus mentiras de esa planta" % (wing + 1), false)
			continue
		var seen := {}
		for i in 200:
			var said: Dictionary = lies.lie(Vector3.ZERO, 0.8)
			if said.is_empty(): continue
			var kind := String(said.kind)
			seen[kind] = int(seen.get(kind, 0)) + 1
			if not (kind in EVERYWHERE or kind in OWN[wing]): bad_kinds.append("%d %s" % [wing, kind])
			await physics_frame
			var path := String(level.world_audio.last_event.get("path", ""))
			if LIES.NEVER.has(path): never.append(path)
			for cue in level.world_audio.long_cues:
				if bool(cue.follow): follows += 1
				if LIES.NEVER.has(String(cue.path)): never.append(String(cue.path))
			if float(air.sound_mask(level.player.global_position)) != 0.0: masked += 1
			if not level.world_audio.caption_text.is_empty(): captions += 1
		var wanted: Array = WANTED[wing]
		check("En la planta %d miente con lo suyo (%s)" % [wing + 1, ", ".join(wanted)], wanted.all(func(k): return seen.has(k)), str(seen))
		for k in lies.jobs.duplicate(): lies.step(k, 100.0)
	await frames(90)
	check("Cada mentira es de su planta", bad_kinds.is_empty(), str(bad_kinds))
	check("Ninguna bebe la luz, ni suena su aviso, ni nada suyo que signifique algo", level.hotel.drains.is_empty() and level.world_audio.last_cue.is_empty() and never.is_empty(), "%s %s" % [str(level.hotel.drains), str(never)])
	check("Ninguna toca un objetivo, sigue al que escucha, tapa con los ventiladores ni lleva subtítulo", int(power.red) == int(power_before[0]) and float(air.running_until) == air_before and var_to_str(files.get("requests")) == files_before and follows == 0 and masked == 0 and captions == 0, "%d %d %d" % [follows, masked, captions])
	level.world_audio.enabled = false

## A point of a planta where every kind that planta must show can be told:
## Vector3.INF when there is none.
func spot_for(wing: int) -> Vector3:
	var wanted: Array = WANTED[wing]
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != wing or bool(room.get("landing", false)): continue
		var at := FLOOR.position_of(room) + Vector3(0, 0.04, 0)
		if level.point_protected(at): continue
		await stand_at(at)
		var here: Dictionary = lies.kinds_here(0.8)
		if wanted.all(func(k): return here.has(k)): return at
	return Vector3.INF

## Case 5.
func one_lamp() -> void:
	var room := first_room(0, func(r): return level.hotel.lit(int(r.id)) and OFFICE.troffers(r).size() >= 2 and not level.hotel.flickers.any(func(e): return e.light == level.hotel.lights[int(r.id)]))
	if room.is_empty():
		check("Una sala con luz y dos luminarias o más", false)
		return
	var id := int(room.id)
	# In the room: a lamp far off is hidden, and a hidden lamp does not flicker.
	await stand_at(FLOOR.position_of(room) + Vector3(0, 0.04, 0))
	await frames(10)
	var light: OmniLight3D = level.hotel.lights[id]
	var full := light.light_energy
	var lenses: Array = level.hotel.lenses_of(id).map(func(m): return m.material_override)
	var share := 1.0 / OFFICE.troffers(room).size()
	var started: bool = level.hotel.flicker_one(id, 1.2, 7)
	var lowest := full
	var quad_seen := false
	for i in 60:
		await physics_frame
		lowest = minf(lowest, light.light_energy)
		for child in level.hotel.get_children():
			if String(child.name).begins_with("LensFailing") and child.visible: quad_seen = true
	await frames(30)
	var gone := true
	for child in level.hotel.get_children():
		if String(child.name).begins_with("LensFailing"): gone = false
	var same: bool = level.hotel.lenses_of(id).map(func(m): return m.material_override) == lenses
	check("Una lámpara falla sola: la sala baja como mucho lo de una luminaria, las demás no cambian y la lente oscura se va", started and quad_seen and lowest >= full * (1.0 - share) - 1e-4 and lowest < full - 1e-4 and same and gone and absf(light.light_energy - full) < 1e-4, "%.3f de %.3f, parte %.2f, %s %s %s" % [lowest, full, share, str(quad_seen), str(same), str(gone)])

## Cases 6 and 6b.
func conditions() -> void:
	var power = level.objective(&"power")
	var air = level.objective(&"air")
	var spot := await spot_for(1)
	if spot != Vector3.INF:
		power.red = 1
		var here: Dictionary = lies.kinds_here(0.8)
		power.red = 0
		check("Con la palanca roja en marcha no hay tictac ni palanca", not here.has("tictac") and not here.has("palanca"), str(here.keys()))
	spot = await spot_for(2)
	if spot != Vector3.INF:
		air.spin = 1.0
		var here: Dictionary = lies.kinds_here(0.8)
		air.spin = 0.0
		check("Con los ventiladores en marcha, ni ventiladores ni ductos en la planta 3", not here.has("ventiladores") and not here.has("ducto"), str(here.keys()))
	var lobby := first_room(0, func(r): return level.point_protected(FLOOR.position_of(r)))
	if lobby.is_empty():
		check("El vestíbulo del montacargas", false)
		return
	await stand_at(FLOOR.position_of(lobby) + Vector3(0, 0.04, 0))
	var kinds := {}
	for i in 200:
		var said: Dictionary = lies.lie(Vector3.ZERO, 0.8)
		if not said.is_empty(): kinds[String(said.kind)] = true
	check("En el vestíbulo protegido ni garras ni ductos", not kinds.has("garras") and not kinds.has("ducto"), str(kinds.keys()))
	for k in lies.jobs.duplicate(): lies.step(k, 100.0)

## Case 8.
func locker() -> void:
	var room := first_room(0, func(r): return level.hotel.lit(int(r.id)) and not level.point_protected(FLOOR.position_of(r)))
	await stand_at(FLOOR.position_of(room) + Vector3(0, 0.04, 0))
	level.player.sanity = 100.0
	level.player.hidden = true
	await frames(120)
	var fell: float = 100.0 - level.player.sanity
	level.player.hidden = false
	check("Escondido en una taquilla la cordura baja como a oscuras", absf(fell - SANITY.SANITY_DARK * 2.0) < SANITY.SANITY_DARK * 0.1, "%.3f" % fell)
	level.player.sanity = 100.0

## Case 9.
func drained() -> void:
	var room := first_room(0, func(r): return level.hotel.lit(int(r.id)))
	var id := int(room.id)
	level.hotel.drain(id, 0.6)
	var still: bool = level.sanity.lit_at(FLOOR.position_of(room) + Vector3(0, 0.04, 0))
	level.hotel.drain(id, 0.0)
	check("Una sala que ella bebe al 0,6 sigue con luz para la cordura", still)

func first_room(wing: int, fits: Callable) -> Dictionary:
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != wing: continue
		if fits.call(room): return room
	return {}
