extends SceneTree
## Phase 3 of The Lurker in Versus (.claude/specs/lurker_versus.md 3, 4.3, 6
## and 7): her driver (lurker_player.gd, scripted) lies in wait over a door
## head of planta 1 and is judged as the host judges her, against a survivor
## the script moves (the local player, its own physics off). Her versus
## profile and its dark. At 6 m, without her charge, no warning; settled and
## watching it 2 s, yes. It runs off: saved. It turns with its torch in her
## warning: saved, she is blinded (her flash, its torch drunk, her wait) and
## bolts in by herself; a torch held on her face out of a warning does the
## same; a look in the light sends her off with no flash. Her peek frightens
## it once in 10 s. It keeps its back to her: taken at her due time, never
## without its warning. evidence/versus/f3/acecho.json and acecho.txt.
##   godot --headless --fixed-fps 60 --path . --script res://tests/office/lurker_stalk_test.gd -- --automation --test-profile --silent [--seed=81]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")
const DT := 1.0 / 60.0
const OUT := "res://evidence/versus/f3/"
## The survivor this far from her face; and the run line this much longer.
const FAR := 6.0
const RUN_ROOM := 10.0
var checks: Array = []
var failed := 0
var lines: Array = []
var level
var lurker
var driver
var survivor
var spot := {}

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail})
	if not passed: failed += 1
	var line := ("PASS " if passed else "FAIL ") + title + ("  (" + detail + ")" if not detail.is_empty() else "")
	print(line)
	lines.append(line)

func run() -> void:
	var seed_value := 81
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.creature_scene = "lurker"
	# Hunting bots from this machine (--bots-hunt): her versus, built so.
	level.solo_locust = true
	await level.start_floor(seed_value, false, [1], "desafiante", 2)
	lurker = level.creature
	level.hand_creature_to_player()
	driver = lurker.driver
	driver.scripted = true
	lurker.grace = 0.0
	survivor = level.player
	survivor.set_physics_process(false)
	survivor.held = true
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	var tuned: Dictionary = level.tuning()
	check("Su perfil de Versus: ventana 1,2 s, linterna bebida 4 s, nunca apagada para siempre; la planta 1 como en Equilibrada", is_equal_approx(float(tuned.back_window), 1.2) and is_equal_approx(float(lurker.torch_drunk), 4.0) and float(lurker.torch_kill) == 0.0 and String(level.hotel.difficulty_id) == "equilibrada", "%s, %s, %s, %s" % [tuned.back_window, lurker.torch_drunk, lurker.torch_kill, level.hotel.difficulty_id])
	var kinds := {}
	for site in lurker.stalk_sites: kinds[String(site.kind)] = int(kinds.get(String(site.kind), 0)) + 1
	check("Sitios de acecho del manifiesto: dinteles, esquinas, bocas de pasillo y taquillas", kinds.has("door") and kinds.has("corner"), str(kinds))
	check("Ninguno junto a una lámpara de su sala", lurker.stalk_sites.all(func(s): return (lurker.shell.lamps_of.get(int(s.room), PackedVector2Array()) as PackedVector2Array).is_empty() or Array(lurker.shell.lamps_of[int(s.room)]).all(func(l): return Vector2((s.point as Vector3).x, (s.point as Vector3).z).distance_to(l) >= SHELL.LAMP_CLEAR - 1e-4)))
	var again: Array = lurker.STALK.sites(lurker.shell)
	check("Los mismos en cada máquina: deterministas", again.size() == lurker.stalk_sites.size() and again.map(func(s): return s.point) == lurker.stalk_sites.map(func(s): return s.point))
	spot = find_spot()
	check("Un dintel de la planta 1 con vista larga", not spot.is_empty())
	if not spot.is_empty():
		lines.append("dintel: sala %d, sitio %d, %s" % [int(spot.room), int(spot.site), str(spot.way)])
		await cases()
	var tally: Dictionary = lurker.tally()
	var audit: Array = WARNING.audit(lurker.capture_log())
	check("Nunca coge sin aviso: cada captura con el suyo, y el registro pasa la auditoría", int(tally.unpaired) == 0 and audit.is_empty(), "%s %s" % [str(tally), str(audit)])
	var file := FileAccess.open(OUT + "acecho.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"seed": seed_value, "checks": checks, "ledger": lurker.capture_log()}, "\t"))
	var text := FileAccess.open(OUT + "acecho.txt", FileAccess.WRITE)
	if text != null:
		for line in lines: text.store_line(line)
	print("LURKER_STALK_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

# --- The place --------------------------------------------------------------------

## A lintel of planta 1 over a room that may be dark, with a way from it FAR
## along which, and RUN_ROOM further, the floor is in rooms that are not
## protected, and nothing stands between: {site, room, way}.
func find_spot() -> Dictionary:
	var off: Array = level.off_limits_rooms()
	for i in lurker.stalk_sites.size():
		var site: Dictionary = lurker.stalk_sites[i]
		var room := int(site.room)
		if String(site.kind) != "door" or int(site.wing) != 0 or off.has(room) or not OFFICE.may_be_dark(level.manifest.rooms[room]): continue
		# The one lurker_stalk takes from under it: no other site this near.
		if lurker.stalk_sites.any(func(o): return o != site and int(o.wing) == 0 and Vector2((o.point as Vector3).x - (site.point as Vector3).x, (o.point as Vector3).z - (site.point as Vector3).z).length() < 2.0): continue
		var py := float(level.manifest.rooms[room].get("py", 0.0))
		var at: Vector3 = site.point
		for k in 16:
			var way := Vector3(cos(k * TAU / 16.0), 0, sin(k * TAU / 16.0))
			var good := true
			var metres := 1.0
			while metres <= FAR + RUN_ROOM and good:
				var p := Vector3(at.x, py + 1.0, at.z) + way * metres
				var found := FLOOR.room_at(level.manifest.rooms, p)
				good = not found.is_empty() and not off.has(int(found.id)) and not level.point_protected(p) and (metres > FAR or int(found.id) == room)
				metres += 0.5
			if good and SIGHT.clear(level, at, Vector3(at.x, py + 1.6, at.z) + way * FAR, [lurker.get_rid()]):
				return {"site": i, "room": room, "way": way, "py": py}
	return {}

## Her back on the ceiling a metre into the room from the lintel, looking at
## the survivor's spot; then to the lintel (lurker_stalk) and settled there.
func to_site() -> bool:
	var site: Dictionary = lurker.stalk_sites[int(spot.site)]
	var at: Vector3 = site.point
	lurker.teleport(Vector3(at.x, float(spot.py) + 1.0, at.z) + (spot.way as Vector3) * 0.8, NAN, &"prueba")
	look_along(spot.way)
	for i in 3: await physics_frame
	driver.asked[&"lurker_stalk"] = true
	return await until(func() -> bool: return driver.settled(), 8.0)

func look_along(way: Vector3, pitch := -0.15) -> void:
	driver.yaw = atan2(-way.x, -way.z)
	driver.pitch = pitch

## The survivor FAR from her face along the way, its back to her, its torch as said.
func stand(metres := FAR, torch := false) -> void:
	var face: Vector3 = lurker.face_point()
	var way: Vector3 = spot.way
	var eye_height: float = survivor.camera.global_position.y - survivor.global_position.y
	var h := metres
	for i in 3:
		survivor.global_position = Vector3(face.x, float(spot.py), face.z) + way * h
		var eye := Vector3(survivor.global_position.x, float(spot.py) + eye_height, survivor.global_position.z)
		h += metres - face.distance_to(eye)
	survivor.global_position = Vector3(face.x, float(spot.py), face.z) + way * h
	survivor.rotation.y = atan2(-way.x, -way.z)
	survivor.camera.rotation.x = 0.0
	survivor.velocity = Vector3.ZERO
	survivor.torch.visible = torch

## The survivor's view turned on to her face; `off` degrees aside.
func turn_to_her(off := 0.0) -> void:
	var to: Vector3 = lurker.face_point() - survivor.camera.global_position
	survivor.rotation.y = atan2(-to.x, -to.z) + deg_to_rad(off)
	survivor.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

func wait(seconds: float) -> void:
	for i in int(seconds / DT): await physics_frame

func until(done: Callable, seconds: float) -> bool:
	for i in int(seconds / DT):
		if done.call(): return true
		await physics_frame
	return done.call()

## Whatever came before forgotten: no wait, no immunity, nobody warned lately.
func fresh() -> void:
	stand()
	lurker.stunned_until = -INF
	lurker.immune_until = -INF
	lurker.fled_until = -INF
	lurker.warned = {}
	lurker.release_at = -INF
	lurker.drunk = {}
	survivor.torch_dim = 1.0

func last() -> Dictionary: return lurker.warning.ledger[lurker.warning.ledger.size() - 1] if not lurker.warning.ledger.is_empty() else {}

func release() -> void:
	driver.asked[&"lurker_release"] = true
	await physics_frame
	await physics_frame

# --- The cases ------------------------------------------------------------------------

func cases() -> void:
	var room := int(spot.room)
	level.hotel.set_room_power(room, false)
	var settled: bool = await to_site()
	check("Acechar la lleva al dintel y se asienta (quieta 1 s)", settled and driver.on_band() and lurker.settled() and (lurker.flags() & lurker.Flag.SETTLED) != 0, " / ".join(lurker.debug_lines()))
	if not settled: return
	# Asentada oye 1,5 veces más lejos: un ruido de 9 m de alcance, a 11 m.
	var face: Vector3 = lurker.face_point()
	var noise := Vector3(face.x, float(spot.py) + 0.1, face.z) + (spot.way as Vector3) * 11.0
	var heard: bool = bool(lurker.senses.hear_route(noise, 9.0 / 2.6).audible)
	driver.settle_clock = 0.0
	var unsettled: bool = bool(lurker.senses.hear_route(noise, 9.0 / 2.6).audible)
	driver.settle_clock = driver.SETTLE
	check("Asentada oye 1,5 veces más lejos: lo de 9 m le llega a 11 m, y sin asentarse no", heard and not unsettled)

	# --- Sin carga, a 6 m no hay aviso.
	stand()
	await wait(0.3)
	var refused: int = lurker.releases_refused
	await release()
	check("Sin carga no puede avisar a 6 m", not lurker.cue and lurker.releases_refused == refused + 1 and lurker.charged.is_empty(), "%.2f m" % lurker.face_point().distance_to(survivor.camera.global_position))

	# --- Carga: 2 s viéndola sin que la vean.
	check("Asentada y viéndola de espaldas 2 s, se carga", await until(func() -> bool: return lurker.charged.has(int(survivor.slot)), 3.0), str(lurker.watching))
	await wait(0.6)
	await release()
	var began: bool = lurker.cue and String(last().get("outcome", "")) == "active"
	check("Con carga, sí: el aviso empieza a 6 m", began, str(last()))
	# --- Quien corre se salva.
	if began:
		var run_way: Vector3 = spot.way
		var ended: bool = await until(func() -> bool:
			survivor.velocity = run_way * 6.0
			survivor.global_position += run_way * 6.0 * DT
			return String(last().outcome) != "active", 3.0)
		survivor.velocity = Vector3.ZERO
		check("A quien corre no lo alcanza: salvado corriendo", ended and String(last().outcome) == "saved" and String(last().reason) == "corriendo" and level.execution.is_empty(), str(last()))

	# --- El que se gira con la linterna la ciega, y ella huye sola.
	fresh()
	await wait(0.6)
	settled = await to_site()
	# Its torch on already, away from her: a torch just switched on is cold (4.2).
	stand(FAR, true)
	var charged: bool = await until(func() -> bool: return lurker.charged.has(int(survivor.slot)), 3.5)
	await release()
	var flashes: float = driver.view.flash_clock
	if charged and lurker.cue:
		await wait(0.3)
		turn_to_her()
		var gone: bool = await until(func() -> bool: return lurker.motion.in_duct, 1.0)
		check("Se gira con la linterna: salvado por ella", String(last().outcome) == "saved" and String(last().reason) == "linterna", str(last()))
		check("Y la ciega: fogonazo en su vista, su linterna bebida 4 s, aviso y bebida en espera", driver.view.flash_clock != flashes and lurker.stunned() and lurker.drunk.has(int(survivor.slot)), "%s %s %s" % [driver.view.flash_clock, lurker.stunned(), lurker.drunk])
		check("Ella huye sola al techo en menos de 0,5 s, sin que nadie la lleve", gone and driver.stalk_at < 0, " / ".join(lurker.debug_lines()))
		# En espera, soltar no sirve aunque cumpla todo lo demás.
		survivor.torch.visible = false
		lurker.drunk = {}
		await to_site()
		stand()
		await until(func() -> bool: return lurker.charged.has(int(survivor.slot)), 3.5)
		refused = lurker.releases_refused
		await release()
		check("En los 6 s tras el fogonazo no hay aviso", lurker.stunned() and not lurker.cue and lurker.releases_refused == refused + 1)
	else:
		check("Cargada otra vez para el fogonazo", false, "%s %s" % [charged, lurker.cue])

	# --- Fuera de un aviso: la linterna en la cara 0,15 s la ciega.
	fresh()
	await wait(0.6)
	await to_site()
	stand(FAR, true)
	await wait(0.6)
	flashes = driver.view.flash_clock
	var before := " / ".join(lurker.debug_lines())
	turn_to_her()
	var seen_by: Dictionary = SIGHT.regarders(level, lurker.face_point(), [lurker.get_rid()])
	lines.append("linterna fuera de aviso: %s, fría %s, bebida %s; antes %s" % [str(seen_by), SIGHT.torch_cold(survivor), lurker.senses.drank(survivor), before])
	var blinded: bool = await until(func() -> bool: return driver.view.flash_clock != flashes, 1.0)
	var gone: bool = await until(func() -> bool: return lurker.motion.in_duct, 1.0)
	check("Sin aviso, la linterna sin beber en la cara la ciega y huye", blinded and gone and lurker.stunned(), "%s %s %s haz %.2f; %s" % [blinded, gone, lurker.stunned(), lurker.beam_time, " / ".join(lurker.debug_lines())])

	# --- Mirada en una sala con luz: huida corta, sin blanco ni espera.
	fresh()
	survivor.torch.visible = false
	await wait(1.2)
	await to_site()
	level.hotel.set_room_power(room, true)
	stand(4.0)
	await wait(0.2)
	flashes = driver.view.flash_clock
	turn_to_her()
	var fled: bool = await until(func() -> bool: return lurker.motion.in_duct, 1.0)
	check("Mirada con luz: huye al techo, sin fogonazo ni espera", fled and driver.view.flash_clock == flashes and not lurker.stunned(), " / ".join(lurker.debug_lines()))

	# --- Asomarse: baja la cordura, una vez cada 10 s por persona. (Pasado el
	# descanso de la cordura entre dos sustos: sanity.SANITY_SIGHT_REST.)
	fresh()
	await wait(5.5)
	await to_site()
	stand(4.0)
	turn_to_her(48.0)
	var sane: float = survivor.sanity
	lurker.peeked = {}
	driver.asked[&"lurker_peek"] = true
	await wait(0.1)
	var first: float = float(lurker.peeked.get(int(survivor.slot), -1.0))
	driver.asked[&"lurker_peek"] = true
	await wait(0.1)
	check("Asomarse al borde de su vista le baja la cordura", first >= 0.0 and survivor.sanity < sane - 5.0, "%.1f -> %.1f, %.2f; %s" % [sane, survivor.sanity, first, " / ".join(lurker.debug_lines())])
	check("Y no otra vez antes de 10 s, ni con el sonido del aviso", first >= 0.0 and float(lurker.peeked.get(int(survivor.slot), -1.0)) == first and lurker.warning.active.is_empty())

	# --- De espaldas y quieto: lo coge al vencer el plazo, con su aviso.
	fresh()
	level.hotel.set_room_power(room, false)
	await wait(1.2)
	await to_site()
	stand()
	await until(func() -> bool: return lurker.charged.has(int(survivor.slot)), 3.5)
	await release()
	if not lurker.cue:
		check("Coge a quien da la espalda tras acechar", false, "no empezó: %s" % str(last()))
		return
	var entry: Dictionary = last()
	var taken: bool = await until(func() -> bool: return String(entry.outcome) != "active", 3.0)
	check("Coge a quien da la espalda tras acechar, al vencer el plazo", taken and String(entry.outcome) == "taken" and float(entry.take_at) >= float(entry.due) - WARNING.EPS and not level.execution.is_empty(), str(entry))
	check("Con su ventana: 1,2 s", is_equal_approx(float(entry.window), 1.2), str(entry.window))
	check("El informe tiene su aviso más largo: unos 6 m", absf(float(lurker.longest_take) - FAR) < 0.3, "%.2f" % lurker.longest_take)
