extends SceneTree
## The Lurker in Versus, the attack from the plenum (.claude/specs/lurker_versus.md
## 13.3, which remade phase 3): her driver (lurker_player.gd, scripted) is
## judged as the host judges her, against a survivor the script moves (the
## local player, its own physics off), in a room of planta 1 put dark. Her
## versus profile. From over the ceiling she marks it; too far off its marker
## is red for "far"; near, green, and her charge fills in 2 s watching it
## (here and on the judge). The attack crawls to the tile behind it, drops and
## begins her warning; whoever runs is saved, and her marker waits. Down by a
## tile 5 m behind it, with her charge a warning, without it none. It turns
## with its torch in her warning: saved, she is blinded and bolts back up into
## the plenum by herself, the picture closing in; a torch on her face out of a
## warning does the same; a look in the light sends her off with no flash.
## Her peek, down, frightens it once in 10 s. Sent off half way down the tile
## of her attack, she comes back up by herself; sent off half way through her
## warning, the warning is called off and nobody is taken. It keeps its back to her:
## taken at her due time, never without its warning.
## evidence/versus/rehecho/ataque.json and ataque.txt.
##   godot --headless --fixed-fps 60 --path . --script res://tests/office/lurker_stalk_test.gd -- --automation --test-profile --silent [--seed=81]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")
const DT := 1.0 / 60.0
const OUT := "res://evidence/versus/rehecho/"
var checks: Array = []
var failed := 0
var lines: Array = []
var level
var lurker
var driver
var survivor
## The room: {room, centre, way (its look), py}.
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
	check("Su perfil de Versus: ventana 1,2 s, linterna bebida 4 s, nunca apagada para siempre", is_equal_approx(float(tuned.back_window), 1.2) and is_equal_approx(float(lurker.torch_drunk), 4.0) and float(lurker.torch_kill) == 0.0, "%s, %s, %s" % [tuned.back_window, lurker.torch_drunk, lurker.torch_kill])
	spot = find_spot()
	check("Una oficina de la planta 1 con placas, que puede estar a oscuras, de al menos 7 m", not spot.is_empty())
	if not spot.is_empty():
		lines.append("sala %d, centro %s, mira %s" % [int(spot.room), str(spot.centre), str(spot.way)])
		await cases()
	var tally: Dictionary = lurker.tally()
	var audit: Array = WARNING.audit(lurker.capture_log())
	check("Nunca coge sin aviso: cada captura con el suyo, y el registro pasa la auditoría", int(tally.unpaired) == 0 and audit.is_empty(), "%s %s" % [str(tally), str(audit)])
	var file := FileAccess.open(OUT + "ataque.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"seed": seed_value, "checks": checks, "ledger": lurker.capture_log()}, "\t"))
	var text := FileAccess.open(OUT + "ataque.txt", FileAccess.WRITE)
	if text != null:
		for line in lines: text.store_line(line)
	print("LURKER_STALK_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

# --- The place --------------------------------------------------------------------

## A room of planta 1 with tiles, a false ceiling of hers, that may be dark,
## not protected, at least 7 m along one way: the survivor stands a little
## short of its middle looking along that way.
func find_spot() -> Dictionary:
	var off: Array = level.off_limits_rooms()
	var best := {}
	var longest := 7.0
	for id in lurker.ducts.room_tiles:
		var room: Dictionary = level.manifest.rooms[int(id)]
		if int(room.wing) != 0 or off.has(int(id)) or not lurker.shell.tray_of.has(int(id)) or not OFFICE.false_ceiling(room) or not OFFICE.may_be_dark(room): continue
		var size := FLOOR.size_of(room)
		var centre := FLOOR.position_of(room)
		if level.point_protected(centre + Vector3(0, 1, 0)): continue
		var length := maxf(size.x, size.y)
		if length < longest: continue
		longest = length
		var way := Vector3(1, 0, 0) if size.x >= size.y else Vector3(0, 0, 1)
		best = {"room": int(id), "centre": centre, "way": way, "py": float(room.py), "length": length}
	return best

func wait(seconds: float) -> void:
	for i in int(seconds / DT): await physics_frame

func until(done: Callable, seconds: float) -> bool:
	for i in int(seconds / DT):
		if done.call(): return true
		await physics_frame
	return done.call()

## The survivor `ahead` metres along the way from the room's middle, its back
## to where she comes from (it looks along the way), its torch as said.
func stand(ahead := 1.0, torch := false) -> void:
	var way: Vector3 = spot.way
	survivor.global_position = Vector3((spot.centre as Vector3).x, float(spot.py), (spot.centre as Vector3).z) + way * ahead
	survivor.rotation.y = atan2(-way.x, -way.z)
	survivor.camera.rotation.x = 0.0
	survivor.velocity = Vector3.ZERO
	survivor.torch.visible = torch

func turn_to_her(off := 0.0) -> void:
	var to: Vector3 = lurker.face_point() - survivor.camera.global_position
	survivor.rotation.y = atan2(-to.x, -to.z) + deg_to_rad(off)
	survivor.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

## In the plenum `back` metres behind the survivor (against its look), her
## camera on it.
func over(back: float) -> void:
	var feet: Vector3 = survivor.global_position
	var p: Vector3 = feet - (spot.way as Vector3) * back
	driver.trip = {}
	driver.attack = {}
	driver.to_plenum(Vector3(p.x, float(spot.py) + 1.0, p.z), int(spot.room))
	aim()
	await wait(0.25)

## Her camera turned on the survivor's chest.
func aim() -> void:
	var to: Vector3 = survivor.global_position + Vector3(0, 1.1, 0) - lurker.motion.anchor()
	driver.yaw = atan2(-to.x, -to.z)
	driver.tilt = -0.9

## Whatever came before forgotten: no wait, no immunity, nobody warned lately.
func fresh() -> void:
	lurker.stunned_until = -INF
	lurker.immune_until = -INF
	lurker.fled_until = -INF
	lurker.warned = {}
	lurker.release_at = -INF
	lurker.drunk = {}
	driver.attacked = {}
	driver.flashed_until = -INF
	driver.view.immune_until = -INF
	survivor.torch_dim = 1.0

func last() -> Dictionary: return lurker.warning.ledger[lurker.warning.ledger.size() - 1] if not lurker.warning.ledger.is_empty() else {}

func info() -> Dictionary: return driver.prey_info

## Attack with her key, aiming at it as she goes; whether a warning began.
func attack() -> bool:
	driver.asked[&"lurker_release"] = true
	await physics_frame
	await physics_frame
	if driver.attack.is_empty(): return lurker.cue
	var trail: Array = []
	var done: bool = await until(func() -> bool:
		var m = lurker.motion
		var now := "%s %s%s%s%s" % [String(driver.attack.get("phase", "-")), "P" if m.plenum else "", "S" if m.surface() else "", "D" if m.in_duct else "", ("L" + String(m.legs[0].kind)) if not m.legs.is_empty() else ""]
		if trail.is_empty() or trail.back() != now: trail.append(now)
		return lurker.cue or driver.attack.is_empty(), 4.0)
	lines.append("ataque: " + " > ".join(trail) + "; " + why_not())
	return done and lurker.cue

# --- The cases ------------------------------------------------------------------------

func cases() -> void:
	var seat := int(survivor.slot)
	level.hotel.set_room_power(int(spot.room), false)
	stand()
	# --- Far: over another room, more than her crawl from any tile behind it.
	await over(PLAYER_CRAWL() + 3.0)
	aim()
	await wait(0.3)
	var far_info := info().duplicate()
	check("Desde el plénum la marca (la más centrada en su vista) y, lejos, en rojo por la distancia", driver.prey == seat and not bool(far_info.get("ok", true)) and String(far_info.get("why", "")) == "far", "%d %s" % [driver.prey, str(far_info)])
	# --- Near: green, and her charge fills in 2 s, here and on the judge.
	await over(1.5)
	await wait(0.3)
	var near_info := info().duplicate()
	check("Cerca, detrás, en verde", bool(near_info.get("ok", false)) and not (near_info.get("drop", {}) as Dictionary).is_empty(), str(near_info))
	var charged: bool = await until(func() -> bool: return driver.charged() and lurker.charged.has(seat), 3.0)
	check("Vigilándola desde arriba sin que la mire, la carga se llena en 2 s (aquí y en el juez)", charged, "%.2f %s" % [driver.charge, str(lurker.watching)])
	# --- The attack: the crawl to the tile behind it, the drop, the warning.
	var before := str(info())
	var began: bool = await attack()
	var entry := last()
	check("Atacar: va a la placa detrás de la presa, cae y empieza el aviso", began and String(entry.get("outcome", "")) == "active" and lurker.motion.surface() and driver.mode == "down", "%s %s; antes %s; %s; %s" % [began, str(entry), before, why_not(), " / ".join(lurker.debug_lines())])
	if began:
		var run_way: Vector3 = spot.way
		var ended: bool = await until(func() -> bool:
			survivor.velocity = run_way * 6.0
			survivor.global_position += run_way * 6.0 * DT
			return String(last().outcome) != "active", 3.0)
		survivor.velocity = Vector3.ZERO
		check("A quien corre no lo alcanza: salvado corriendo", ended and String(last().outcome) == "saved" and String(last().reason) == "corriendo" and level.execution.is_empty(), str(last()))
		stand()
		await over(1.5)
		await wait(0.3)
		check("Y la misma presa, en espera: rojo, con su arco", String(info().get("why", "")) == "wait" and float(info().get("wait", 0.0)) > 0.0, str(info()))
	# --- With her charge a warning from a tile 5 m behind; without it, none.
	fresh()
	stand(2.5)
	# A tile some 5 m behind it from which nothing stands between her face and its eye.
	var back := 5.0
	for metres in [5.0, 4.5, 5.5, 4.0, 6.0]:
		var way: Dictionary = driver.tile_way(survivor.global_position - (spot.way as Vector3) * float(metres) + Vector3(0, 3.0, 0))
		if not way.is_empty() and SIGHT.clear(level, (way.point as Vector3) - Vector3(0, 0.5, 0), survivor.camera.global_position, [lurker.get_rid(), survivor.get_rid()]):
			back = float(metres)
			break
	await over(back)
	await until(func() -> bool: return lurker.charged.has(seat), 3.0)
	var five: Dictionary = driver.tile_way(lurker.motion.point)
	var with_charge := false
	if not five.is_empty():
		driver.go_down(five)
		await until(func() -> bool: return lurker.motion.surface() and lurker.motion.legs.is_empty(), 2.0)
		driver.look_at_point(survivor.camera.global_position)
		# Her camera eased down to her eyes: her look is its look.
		await wait(0.5)
		var reasons := why_not()
		level.match_net.lurker_release()
		with_charge = lurker.cue
		lines.append("a %.2f m, carga %s: %s; %s" % [lurker.face_point().distance_to(survivor.camera.global_position), str(lurker.charged), str(last()), reasons])
		if with_charge: await until(func() -> bool:
			survivor.global_position += (spot.way as Vector3) * 6.0 * DT
			return String(last().outcome) != "active", 3.0)
	fresh()
	stand(2.5)
	await over(back)
	lurker.charged.clear()
	lurker.watching.clear()
	driver.prey = -1
	driver.go_down(driver.tile_way(lurker.motion.point))
	await until(func() -> bool: return lurker.motion.surface() and lurker.motion.legs.is_empty(), 2.0)
	await wait(lurker.CHARGE_KEEP + 0.2)
	driver.look_at_point(survivor.camera.global_position)
	await wait(0.5)
	var refused: int = lurker.releases_refused
	level.match_net.lurker_release()
	check("Con carga avisa desde una placa a unos 5 m; sin ella, no", with_charge and not lurker.cue and lurker.releases_refused == refused + 1, "%s %s; %s" % [with_charge, lurker.cue, str(lines.back())])
	# --- It turns with its torch in her warning: saved, she is blinded and bolts up.
	fresh()
	stand(1.0, true)
	await wait(0.7)
	await over(1.5)
	var flashes: float = driver.view.flash_clock
	if await attack():
		await wait(0.25)
		turn_to_her()
		var gone: bool = await until(func() -> bool: return driver.up(), 1.5)
		check("Se gira con la linterna: salvado por ella", String(last().outcome) == "saved" and String(last().reason) == "linterna", str(last()))
		check("Y la ciega: fogonazo en su vista, su linterna bebida 4 s, en espera", driver.view.flash_clock != flashes and lurker.stunned() and lurker.drunk.has(seat), "%s %s %s" % [driver.view.flash_clock, lurker.stunned(), lurker.drunk])
		check("Ella vuelve sola al plénum, con la imagen que se cierra y la cámara sobre ella", gone and driver.clock - driver.fled_at < driver.FLED_FOR + 1.5 and driver.mode == "above", "%s %.2f %s; %s" % [gone, driver.clock - driver.fled_at, driver.mode, " / ".join(lurker.debug_lines())])
		stand()
		await over(1.5)
		await wait(0.3)
		check("En espera tras el fogonazo: su marcador lo dice (rojo, su arco)", String(info().get("why", "")) == "wait", str(info()))
	else: check("El aviso para el fogonazo", false, str(last()))
	# --- Out of a warning: the torch on her face 0.15 s blinds her; she bolts up.
	# (Past the 4 s the last flash drank that torch for.)
	fresh()
	await wait(4.5)
	survivor.torch.visible = false
	stand()
	await over(1.5)
	driver.go_down()
	await until(func() -> bool: return lurker.motion.surface() and lurker.motion.legs.is_empty(), 2.0)
	survivor.torch.visible = true
	await wait(0.7)
	flashes = driver.view.flash_clock
	turn_to_her()
	var blinded: bool = await until(func() -> bool: return driver.view.flash_clock != flashes, 1.0)
	var up_again: bool = await until(func() -> bool: return driver.up(), 1.5)
	check("Abajo, sin aviso, la linterna en la cara la ciega y vuelve al plénum", blinded and up_again and lurker.stunned(), "%s %s %s; %s" % [blinded, up_again, lurker.stunned(), " / ".join(lurker.debug_lines())])
	# --- A look in a lit room: off, with no flash and no wait.
	fresh()
	survivor.torch.visible = false
	await wait(1.2)
	stand()
	await over(1.5)
	driver.go_down()
	await until(func() -> bool: return lurker.motion.surface() and lurker.motion.legs.is_empty(), 2.0)
	level.hotel.set_room_power(int(spot.room), true)
	await wait(0.3)
	flashes = driver.view.flash_clock
	turn_to_her()
	var fled: bool = await until(func() -> bool: return driver.up(), 1.5)
	check("Mirada con luz: vuelve al plénum, sin fogonazo ni espera", fled and driver.view.flash_clock == flashes and not lurker.stunned(), " / ".join(lurker.debug_lines()))
	# --- Her peek, down: frightens once in 10 s, no warning sound.
	fresh()
	await wait(5.5)
	stand()
	await over(1.5)
	driver.go_down()
	await until(func() -> bool: return lurker.motion.surface() and lurker.motion.legs.is_empty(), 2.0)
	turn_to_her(48.0)
	var sane: float = survivor.sanity
	lurker.peeked = {}
	driver.asked[&"lurker_peek"] = true
	await wait(0.1)
	var first: float = float(lurker.peeked.get(seat, -1.0))
	driver.asked[&"lurker_peek"] = true
	await wait(0.1)
	check("Asomarse, abajo, al borde de su vista le baja la cordura, una vez en 10 s y sin el sonido del aviso", first >= 0.0 and survivor.sanity < sane - 5.0 and float(lurker.peeked.get(seat, -1.0)) == first and lurker.warning.active.is_empty(), "%.1f -> %.1f, %.2f" % [sane, survivor.sanity, first])
	# --- Sent off half way down the tile of her attack: no ceiling under her to
	# bolt from; once on the one below, back up by herself.
	fresh()
	level.hotel.set_room_power(int(spot.room), false)
	await wait(1.2)
	stand()
	await over(1.5)
	await wait(0.3)
	driver.asked[&"lurker_release"] = true
	var dropping: bool = await until(func() -> bool: return String(driver.attack.get("phase", "")) == "drop" and not lurker.motion.surface(), 2.0)
	lurker.scare_off(false, seat, lurker.face_point())
	var sent: float = driver.clock
	var back_up: bool = await until(func() -> bool: return driver.up(), 2.0)
	check("Echada a media caída por la placa: vuelve sola al plénum, sin quedarse abajo", dropping and back_up and driver.clock - sent < 1.2 and lurker.warning.active.is_empty(), "%s %s %.2f s; %s" % [dropping, back_up, driver.clock - sent, " / ".join(lurker.debug_lines())])
	# --- Sent off half way through her warning by a torch the warning does not
	# judge (a third's: the judge's call by hand): no take, she goes up.
	fresh()
	await wait(1.2)
	stand()
	await over(1.5)
	await wait(0.3)
	if await attack():
		var counting: Dictionary = last()
		await wait(0.4)
		lurker.scare_off(true, seat, lurker.face_point())
		await wait(float(counting.window) + 1.5)
		check("Echada por una linterna a media cuenta: el aviso se cancela, sin captura, y vuelve al plénum", String(counting.outcome) == "aborted" and String(counting.reason) == "echada" and level.execution.is_empty() and lurker.warning.active.is_empty() and driver.up(), "%s; %s" % [str(counting), " / ".join(lurker.debug_lines())])
	else: check("El aviso para echarla a media cuenta", false, "%s %s" % [str(last()), str(info())])
	# --- Its back to her: taken at her due time, with its warning.
	fresh()
	level.hotel.set_room_power(int(spot.room), false)
	await wait(1.2)
	stand()
	await over(1.5)
	await wait(0.3)
	if not await attack():
		check("Coge a quien da la espalda", false, "no empezó: %s %s" % [str(last()), str(info())])
		return
	var taken_entry: Dictionary = last()
	var taken: bool = await until(func() -> bool: return String(taken_entry.outcome) != "active", 3.0)
	check("Coge a quien da la espalda, al vencer el plazo, con su ventana de 1,2 s", taken and String(taken_entry.outcome) == "taken" and float(taken_entry.take_at) >= float(taken_entry.due) - WARNING.EPS and not level.execution.is_empty() and is_equal_approx(float(taken_entry.window), 1.2), str(taken_entry))

func PLAYER_CRAWL() -> float: return float(driver.CRAWL_REACH)

## What the judge would ask of a warning on the survivor now (lurker.judge_release()).
func why_not() -> String:
	var p = lurker.senses.perceive(0.0, lurker.brain.clock, -1)
	var v = lurker.senses.seen_of(survivor, p, lurker.brain.clock)
	var eye: Vector3 = lurker.senses.eye_point()
	var target: Vector3 = survivor.camera.global_position
	var exclude := [lurker.get_rid(), survivor.get_rid()]
	var angle: float = rad_to_deg(lurker.gaze().angle_to(target - eye)) if eye != Vector3.INF else -1.0
	var rays := "%s/%s" % [SIGHT.clear(level, eye, target, exclude), SIGHT.clear(level, eye, target - Vector3(0, 0.6, 0), exclude)] if eye != Vector3.INF else "-"
	return "ángulo %.0f, rayos %s, ve %s, justo %s, en ducto %s, detrás %s, la miran %s, linterna %s, luz %s, puede %s, después %s, aturdida %s, a %.2f m, superficie %s" % [angle, rays, lurker.senses.sees(survivor), v.fair, p.in_duct, v.behind, str(p.regarded_by), str(p.torch_by), v.lit, lurker.warning.can_start(lurker.brain.clock), lurker.brain.clock >= lurker.brain.cue_after, lurker.stunned(), float(v.distance), lurker.motion.surface()]
