extends SceneTree
## Her drink of a room (.claude/specs/lurker_versus.md 8 and 10; phase 4), on
## a built floor 2: the room all dark within 0.2 s and its torches out,
## switched off and not drunk; a torch back at the third press and never
## before 1.0 s; a torch on less than 0.5 s neither saves nor blinds; never a
## landmark's room, a lobby nor a refuge; no fright, and neither the emergency
## units nor the landmarks' lamps touched; given back on time. Then her mind's
## drink in the three difficulties that drink it, with its brakes (the lamps
## down and a hiss first, no warning before drink_cue, one attempt), and the
## contract after it (docs/OFICINAS.md 1): the torch lit again, a teammate's
## torch and running still save; doing nothing does not. Apacible never drinks.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const LURKER := preload("res://game/enemies/lurker/lurker.gd")
const REMOTE := preload("res://game/net/remote_player.gd")
const DT := 1.0 / 60.0
const EPS := WARNING.EPS
## A person's thumb: reaction, then a press every PRESS (bot_threat_lurker's).
const REACT := 0.35
const PRESS := 0.15
var checks: Array = []
var failed := 0
var level
var lurker
var corridor := {}
## Every drink of the cases and every warning begun in its dark (one at most).
var spent: Array = []

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
	for seed_value in [2026, 7, 11, 23]:
		await level.start_floor(int(seed_value), false, [1], "equilibrada")
		corridor = find_corridor()
		if not corridor.is_empty(): break
	if corridor.is_empty(): check("Un pasillo que puede estar a oscuras, con luz ahora", false)
	else:
		lurker = level.creature
		if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
		level.player.set_physics_process(false)
		await mechanism()
		await relight()
		await cold()
		landmarks()
		for id in ["equilibrada", "desafiante", "pesadilla"]:
			await mind_drink(id)
			await contract(id)
		await apacible()
		check("Una sola tentativa por apagón", spent.all(func(n): return int(n) <= 1), str(spent))
		var audit: Array = WARNING.audit(lurker.capture_log())
		check("El registro de avisos pasa la auditoría", audit.is_empty(), str(audit))
	var file := FileAccess.open("res://evidence/lurker_drink_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("LURKER_DRINK_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)

## The lowest-id corridor of planta 1 at least 8 m long (7 in the real
## building) that she can hold on to, may drink and is not one of the floor's
## dark rooms, nothing off limits next to it.
func find_corridor() -> Dictionary:
	var off: Array = level.off_limits_rooms()
	for room in level.manifest.rooms:
		var id := int(room.id)
		if int(room.get("wing", -1)) != 0 or int(room.type) != OFFICE.CORRIDOR or level.hotel.dark_ids.has(id): continue
		var span := FLOOR.size_of(room)
		if maxf(span.x, span.y) < (7.0 if OFFICE.real_plan_on() else 8.0) or not level.creature.shell.tray_of.has(id): continue
		if level.manifest.adjacency[id].any(func(other): return off.has(int(other))): continue
		if level.point_protected(FLOOR.position_of(room)): continue
		var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
		return {"room": id, "centre": FLOOR.position_of(room), "along": along}
	return {}

func seat() -> int: return int(level.player.slot)

func frames(n: int) -> void:
	for i in n: await physics_frame

## Her clock moved by hand while her mind is off (her dark's end and the
## presses are counted on it).
func tick(n: int) -> void:
	for i in n:
		await physics_frame
		if not lurker.thinking: lurker.brain.clock += DT

## Nothing of a drink left: the room lit, the torch whole and on.
func reset() -> void:
	lurker.thinking = false
	lurker.undrain()
	# Her room given back by the test is not somebody lighting it.
	lurker.room_was_lit = {}
	lurker.outed.clear()
	lurker.dead_torches.clear()
	lurker.drunk.clear()
	lurker.sparks.clear()
	lurker.snuffed.clear()
	lurker.last_drink = -INF
	lurker.brain.scared_at = -INF
	lurker.brain.cue_after = -INF
	lurker.brain.drink_until = -INF
	level.player.torch_dim = 1.0
	if not level.executions.execution.is_empty(): level.release_execution()

func place_player(point: Vector3, facing: Vector3) -> void:
	var player = level.player
	player.global_position = point
	player.rotation.y = atan2(-facing.x, -facing.z)
	player.camera.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	await frames(3)

func aim_at(point: Vector3) -> void:
	var player = level.player
	var to: Vector3 = point - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

## The corridor lit, the player 1.5 m along it facing on, its torch on (warm)
## or off, her 2.4 m behind on the ceiling, her mind off and put on it.
func set_up(torch: bool) -> void:
	reset()
	lurker.brain.forget_all(0.0)
	lurker.brain.spurned = {}
	lurker.brain.attempts = {}
	lurker.brain.sated_until = -INF
	lurker.brain.quiet_until = -INF
	level.hotel.set_room_power(int(corridor.room), true)
	var centre: Vector3 = corridor.centre
	var along: Vector3 = corridor.along
	await place_player(centre + along * 1.5, along)
	level.player.torch.visible = torch
	lurker.place_over(centre - along * 0.9, level.player.camera.global_position)
	lurker.grace = 0.0
	# Warm: on for more than TORCH_COLD.
	await frames(40)

# --- The mechanism -------------------------------------------------------------------------

func lamp_energies() -> Array:
	var out: Array = []
	for e in level.hotel.get("emergency") if level.hotel.get("emergency") != null else []:
		if is_instance_valid(e.light): out.append(e.light.light_energy)
	for e in level.hotel.get("landmark_lamps") if level.hotel.get("landmark_lamps") != null else []:
		if is_instance_valid(e.light): out.append(e.light.light_energy)
	return out

func mechanism() -> void:
	await set_up(true)
	var room := int(corridor.room)
	var before := lamp_energies()
	var scares: int = lurker.scares
	var sane := float(level.player.sanity)
	level.world_audio.caption_text = ""
	lurker.drink(room, 4.0, 1.5)
	var dark_after := -1
	for i in 30:
		await tick(1)
		if dark_after < 0 and not level.hotel.lit(room): dark_after = i + 1
	check("Bebe la sala: a oscuras del todo en 0,2 s", dark_after > 0 and dark_after <= 13 and float(level.hotel.drained(room)) >= 0.999, "%d fotogramas, %.3f" % [dark_after, float(level.hotel.drained(room))])
	check("Su linterna se apaga con el interruptor, sin quedar bebida", not level.player.torch.visible and lurker.outed.has(seat()) and lurker.dead_torches.has(seat()) and not lurker.drunk.has(seat()) and float(level.player.torch_dim) == 0.0)
	check("Un chillido propio con su subtítulo; no es un susto", String(level.world_audio.caption_text) == LURKER.DRINK_CAPTION and lurker.scares == scares and absf(float(level.player.sanity) - sane) < 0.5 and not lurker.brain.state in [BRAIN.State.RECOIL, BRAIN.State.FLEE], "%s %d %.1f" % [level.world_audio.caption_text, lurker.scares - scares, float(level.player.sanity) - sane])
	check("Ni la emergencia ni los apliques de hito (decisión E)", lamp_energies() == before)
	await tick(int(4.0 / DT))
	var back := false
	for i in 90:
		await tick(1)
		if level.hotel.lit(room):
			back = true
			break
	check("A los 4 s devuelve la sala", back and lurker.deep_room < 0 and lurker.snuffed.has(room))

## Pressed at these seconds from the drink (each press switches it): whether
## it was back after each press.
func presses(at: Array) -> Array:
	var out: Array = []
	var t := 0.0
	var i := 0
	while i < at.size():
		await tick(1)
		t += DT
		if t + EPS < float(at[i]): continue
		level.player.torch.visible = not level.player.torch.visible
		await tick(2)
		t += 2 * DT
		out.append(not lurker.dead_torches.has(seat()))
		i += 1
	return out

func relight() -> void:
	var room := int(corridor.room)
	await set_up(true)
	lurker.drink(room, 6.0, 1.5)
	await tick(1)
	# On, off, on before 1.0 s: sparks only; off and on after it: back.
	var early := await presses([0.3, 0.45, 0.6, 0.75, 0.9, 1.05, 1.2])
	check("Encendida a la tercera pulsación antes de 1,0 s solo chispea; la siguiente tras 1,0 s vuelve", early == [false, false, false, false, false, false, true] and float(level.player.torch_dim) == 1.0 and not lurker.outed.has(seat()), str(early))
	await set_up(true)
	lurker.drink(room, 6.0, 1.5)
	await tick(1)
	var late := await presses([1.3, 1.45, 1.6])
	check("Pasado 1,0 s, vuelve a la tercera pulsación, ni antes ni después", late == [false, false, true], str(late))
	reset()

func cold() -> void:
	await set_up(true)
	level.player.torch.visible = false
	await frames(3)
	aim_at(lurker.face_point())
	level.player.torch.visible = true
	await frames(1)
	var face: Vector3 = lurker.face_point()
	var cold_now: bool = SIGHT.torch_cold(level.player) and not SIGHT.torch_covers(level, level.player, face, [lurker.get_rid()])
	var look: Dictionary = SIGHT.look_of(level, level.player, face, [lurker.get_rid()], false)
	await frames(int(SIGHT.TORCH_COLD / DT) + 2)
	var warm: bool = not SIGHT.torch_cold(level.player) and SIGHT.torch_covers(level, level.player, face, [lurker.get_rid()])
	check("Una linterna encendida hace menos de 0,5 s ni ciega ni salva; después, sí", cold_now and not bool(look.torch) and warm)
	reset()

func landmarks() -> void:
	var wrong: Array = []
	for room in level.manifest.rooms:
		if FLOOR.is_void(room): continue
		if not OFFICE.may_be_dark(room) and lurker.may_snuff(int(room.id), lurker.brain.clock): wrong.append(int(room.id))
	check("Nunca bebe hitos, vestíbulos ni refugios", wrong.is_empty(), str(wrong))
	var room := int(corridor.room)
	lurker.snuffed[room] = lurker.brain.clock
	var again: bool = lurker.may_snuff(room, lurker.brain.clock + LURKER.DEEP_AGAIN - 1.0) == false and lurker.may_snuff(room, lurker.brain.clock + LURKER.DEEP_AGAIN)
	lurker.snuffed.clear()
	check("La misma sala, no antes de 45 s", again)

# --- Her mind's drink, by difficulty ---------------------------------------------------------

## The warnings begun since `drank` while its room was dark.
func in_dark(drank: Dictionary) -> int:
	return lurker.warning.ledger.filter(func(e): return float(e.at) >= float(drank.at) and float(e.at) < float(drank.at) + float(drank.dark)).size()

## Stalking the player in the lit corridor (stalking forever, the player on
## the move without going anywhere): she warns of it, drinks it, closes in;
## nothing is done, so she takes.
func mind_drink(id: String) -> void:
	level.set_difficulty(id)
	level.arm_creature()
	var tuning: Dictionary = level.tuning()
	await set_up(false)
	var room := int(corridor.room)
	var kept: float = lurker.snuff_time
	# The stalking she needs before it is her difficulty's (as ever): here, short.
	lurker.snuff_time = 1.0
	var made: int = lurker.drinks.size()
	var started: int = lurker.warning.ledger.size()
	lurker.thinking = true
	lurker.brain.force(&"stalk", {"seat": seat()})
	var warned_at := -1.0
	var low := 0.0
	var entry := {}
	for i in int(20.0 / DT):
		await physics_frame
		lurker.brain.stalk_left = 999.0
		lurker.brain.peek_at = -1.0
		if lurker.drinks.size() == made: level.player.velocity = (corridor.along as Vector3) * 0.5
		else: level.player.velocity = Vector3.ZERO
		if warned_at < 0.0 and lurker.warn_room == room: warned_at = float(lurker.brain.clock)
		if lurker.warn_room == room: low = float(level.hotel.drained(room))
		if lurker.warning.ledger.size() > started and String(lurker.warning.ledger[started].outcome) != "active":
			entry = lurker.warning.ledger[started]
			break
	lurker.snuff_time = kept
	var drank: Dictionary = lurker.drinks[made] if lurker.drinks.size() > made else {}
	var tag := id.capitalize()
	check("%s: antes de beber, las lámparas bajan y sube un siseo %.1f s" % [tag, float(tuning.drink_warn)], warned_at >= 0.0 and not drank.is_empty() and absf(float(drank.at) - warned_at - float(tuning.drink_warn)) <= 2.0 * DT + EPS and low >= 0.5, "%.2f %s %.2f" % [warned_at, str(drank), low])
	check("%s: bebe la sala de su presa %.0f s" % [tag, float(tuning.drink_dark)], not drank.is_empty() and int(drank.room) == room and float(drank.dark) == float(tuning.drink_dark) and Array(drank.seats).has(seat()))
	check("%s: su primer aviso, no antes de %.1f s del chillido, en su apagón" % [tag, float(tuning.drink_cue)], not drank.is_empty() and not entry.is_empty() and float(entry.at) - float(drank.at) >= float(tuning.drink_cue) - EPS, "%s %s" % [str(drank), str(entry)])
	check("%s: sin hacer nada, la coge" % tag, String(entry.get("outcome", "")) == "taken", str(entry))
	if not drank.is_empty(): spent.append(in_dark(drank))
	await frames(30)

## After her drink of the corridor, on her one attempt: the torch lit again
## by pressing (and turned to her), a teammate's torch from outside it, and
## running away each save.
func contract(id: String) -> void:
	var tuning: Dictionary = level.tuning()
	var room := int(corridor.room)
	var along: Vector3 = corridor.along
	var bad: Array = []
	for how in ["reencendida", "compañero", "corriendo"]:
		await set_up(true)
		lurker.thinking = true
		lurker.brain.force(&"creep", {"seat": seat()})
		var started: int = lurker.warning.ledger.size()
		var made: int = lurker.drinks.size()
		lurker.drink(room, float(tuning.drink_dark), float(tuning.drink_cue), seat())
		var drank: Dictionary = lurker.drinks[made]
		var other = null
		if how == "compañero":
			# Come in from outside it after the drink: its torch was never hers.
			other = REMOTE.new()
			other.setup(level, 2, "Prueba", 1)
			level.add_child(other)
			other.set_physics_process(false)
			other.place((corridor.centre as Vector3) + along * (3.0 if OFFICE.real_plan_on() else 4.0) + Vector3(-along.z, 0, along.x) * 0.8, atan2(-along.x, -along.z))
			level.match_net.bodies[2] = other
			level.session.participants[2] = level.session.Life.EXPLORING
			other.torch.visible = true
		var t := 0.0
		var next_press := REACT
		var turned := false
		var ran := false
		var entry := {}
		for i in int(8.0 / DT):
			await physics_frame
			t += DT
			var active: Dictionary = lurker.warning.active
			match how:
				"reencendida":
					if lurker.dead_torches.has(seat()) and t >= next_press:
						level.player.torch.visible = not level.player.torch.visible
						next_press += PRESS
					if not turned and not active.is_empty() and lurker.brain.clock >= float(active.due) - 0.3:
						turned = true
						aim_at(lurker.face_point())
				"compañero":
					if not turned and not active.is_empty() and lurker.brain.clock >= float(active.due) - 0.5:
						turned = true
						other.camera.look_at(lurker.face_point())
				"corriendo":
					if not active.is_empty() or ran:
						ran = true
						level.player.velocity = along * 6.0
						level.player.global_position += along * 6.0 * DT
			if lurker.warning.ledger.size() > started and String(lurker.warning.ledger[started].outcome) != "active":
				entry = lurker.warning.ledger[started]
				break
		var wanted: Array = {"reencendida": [int(seat()), "linterna"], "compañero": [2, "linterna"], "corriendo": [int(seat()), "corriendo"]}[how]
		if entry.is_empty() or String(entry.outcome) != "saved" or int(entry.by) != int(wanted[0]) or String(entry.reason) != String(wanted[1]) or float(entry.at) - float(drank.at) < float(tuning.drink_cue) - EPS:
			bad.append([how, entry])
		spent.append(in_dark(drank))
		if other != null:
			level.match_net.bodies.erase(2)
			level.session.participants.erase(2)
			# Gone: her senses forget it (they keep a body that left as last seen).
			lurker.senses.memory.erase(2)
			lurker.senses.looked.erase(2)
			other.queue_free()
		level.player.velocity = Vector3.ZERO
		await frames(10)
	check("%s: tras beber, siguen salvando la linterna reencendida, la de un compañero y correr" % id.capitalize(), bad.is_empty(), str(bad))

func apacible() -> void:
	level.set_difficulty("apacible")
	level.arm_creature()
	await set_up(false)
	var made: int = lurker.drinks.size()
	lurker.thinking = true
	lurker.brain.force(&"stalk", {"seat": seat()})
	for i in int(4.0 / DT):
		await physics_frame
		lurker.brain.stalk_left = 999.0
		level.player.velocity = (corridor.along as Vector3) * 0.5
	check("Apacible: nunca bebe", lurker.snuff_time == 0.0 and lurker.drinks.size() == made and lurker.warn_room < 0)
	level.set_difficulty("equilibrada")
	level.arm_creature()
	reset()
