extends SceneTree
## The test bots (tools/bots): a floor built for their seats, the game's own
## rules applied to their bodies, and bots that get through a stage on their
## own feet. Staged pieces rather than whole floors, to fit verify.ps1.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const MATCH := preload("res://tools/bots/bot_match.gd")
const TV_PLACEMENT := preload("res://game/world/generation/tv_placement.gd")
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
const SENSES := preload("res://tools/bots/bot_senses.gd")
const BODY := preload("res://tools/bots/bot_body.gd")
const REPLAY := preload("res://tools/bots/bot_replay.gd")
const RECORDING := "res://evidence/bots/test_recording"
var level
var bot_match
var checks: Array = []
var failed := 0
## Doors this test put open by hand, which no recording hears about.
var forced_doors: Array = []

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, "" if passed or detail.is_empty() else " · " + detail)

func frames(count: int) -> void:
	for i in count: await physics_frame

## Physics frames until the condition holds, or the limit. Whether it held.
func wait_for(condition: Callable, limit: int) -> bool:
	for frame in limit:
		if condition.call(): return true
		await physics_frame
	return condition.call()

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	Engine.max_fps = 0
	var saved: String = level.session.checkpoint_path
	for path in [saved, saved + ".bak"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var board: int = level.records.runs.size()
	bot_match = MATCH.new()
	var recording := ProjectSettings.globalize_path(RECORDING)
	if DirAccess.dir_exists_absolute(recording):
		for file in DirAccess.get_files_at(recording): DirAccess.remove_absolute(recording.path_join(file))
	bot_match.setup(level, {"bots": 2, "seed": 81, "knowledge": "oracle", "verbose": true, "out": recording})
	root.add_child(bot_match)
	var began: bool = await bot_match.begin()
	check("El piso se levanta con los asientos de los bots", began and level.session.participants.keys() == [2, 3] and level.session.roster_count == 2, str(level.session.participants))
	var per_stage := [level.stage_televisions(2).size(), level.stage_televisions(3).size()]
	check("Y pone las teles que pide un equipo de dos", per_stage == [TV_PLACEMENT.needed(2) + 2, TV_PLACEMENT.needed(2) + 2], str(per_stage))
	check("El jugador de esta máquina no está en la partida", not level.survivors().has(level.player) and level.player.collision_layer == 0 and not level.player.active)
	check("Nada va al punto de control de Continuar", not level.session.keeps_checkpoint and not FileAccess.file_exists(saved))
	# The creature is not what this part is about: it stays where it is.
	level.locust.set_physics_process(false)
	level.locust.global_position = FLOOR.position_of(level.manifest.rooms[int(level.manifest.refuges[2])]) + Vector3(0, 0.04, 0)
	# What the keypad says, without a screen.
	var right: String = "".join(DIGITS.code(level.manifest).map(func(digit): return str(digit)))
	var wrong: String = str((int(right) + 1) % 10000).pad_zeros(4)
	check("El teclado dice que no a otro código", level.code_verdict(wrong) == "wrong")
	# Asked as on the last stage, whose sets count; nothing is changed by asking.
	level.session.stage = 3
	var dark: String = level.code_verdict(right)
	for index in level.stage_televisions(): level.televisions[index].on = true
	var lit: String = level.code_verdict(right)
	for index in level.stage_televisions(): level.televisions[index].on = false
	level.session.stage = 1
	check("Y que faltan teles al bueno con las teles del sector apagadas, y que sí con ellas encendidas", dark == "sets" and lit == "right", "%s, %s" % [dark, lit])
	await seeing()
	await minding()
	# Somebody else's hands on a drawer: the number is theirs.
	var holder := -1
	for index in level.containers.size():
		if int(level.containers[index].digit) >= 0:
			holder = index
			break
	level.match_net.use_container(level.containers[holder], 3)
	var slot := int(level.containers[holder].slot)
	check("Lo que un bot encuentra queda a su nombre", int(level.found_by.get(slot, -1)) == 3 and level.found_digits.has(slot))
	check("El registro de un bot se oye como el de cualquiera", level.containers[holder].searched and not is_instance_valid(level.containers[holder].note))
	# A bot taken: held up, dead, out of the way, and up again on the next stage.
	var victim = bot_match.bodies[1]
	level.capture_survivor(victim)
	await frames(30)
	var held_near: bool = not level.execution.is_empty() and victim.global_position.distance_to(level.victim_hold_point()) < 0.6
	check("Un bot atrapado queda sostenido delante de la criatura", held_near, str(victim.global_position))
	await wait_for(func(): return level.session.participants.get(3) == level.session.Life.DEAD, 400)
	await frames(2)
	check("Y muere, fuera de la vista y sin cuerpo que estorbe", level.session.participants.get(3) == level.session.Life.DEAD and victim.dead and victim.collision_layer == 0 and not victim.visible)
	# The other one closes the stage on its own feet. Half way, and once it is
	# through, the floor as it stands, to hold the recording to.
	var pictures: Array = []
	var halfway: bool = await wait_for(func(): return bot_match.clock > 40.0, 60 * 120)
	if halfway: pictures.append([bot_match.clock, bot_match.snapshot(), moving_doors()])
	var through: bool = await wait_for(func(): return int(level.session.stage) >= 2 and level.session.state == level.session.State.PLAYING, 60 * 480)
	await frames(30)
	pictures.append([bot_match.clock, bot_match.snapshot(), moving_doors()])
	check("Un bot solo llega al refugio, se abre su puerta y toma el ascensor", through, "sector %d a los %d s · %s" % [level.session.stage, int(bot_match.clock), incidents_text()])
	await frames(10)
	check("Y el caído vuelve con el sector nuevo, en la planta de abajo", not victim.dead and victim.collision_layer == 4 and FLOOR.planta_of(victim.global_position.y) == 1, str(victim.global_position))
	# The death this test brought about itself is not one of them.
	var graves: Array = bot_match.incidents.filter(func(entry): return entry.severity == "grave" and entry.kind != "muerte")
	check("La muerte que la prueba provocó queda anotada", bot_match.incidents.any(func(entry): return entry.kind == "muerte" and entry.seat == 3))
	check("Sin incidencias graves por el camino", graves.is_empty(), incidents_text())
	# What was recorded says what happened: the floor worked out from the
	# recording at those two moments is the floor as it was then.
	bot_match.finish()
	var replay := REPLAY.new()
	replay.setup(level, recording)
	var read: bool = replay.read()
	var same := read and pictures.size() == 2
	var differences: Array = []
	for picture in pictures:
		if not read: break
		var recorded: Dictionary = replay.state_at(float(picture[0]))
		var live: Dictionary = picture[1]
		for field in ["tvs", "searched", "code", "stage", "blackout"]:
			if str(recorded.get(field)) != str(live.get(field)): differences.append("%s a %d s: %s / %s" % [field, int(picture[0]), recorded.get(field), live.get(field)])
		var lives := {}
		for seat in live.lives: lives[int(seat)] = int(live.lives[seat])
		if pairs(recorded.lives) != pairs(lives): differences.append("vidas a %d s: %s / %s" % [int(picture[0]), recorded.lives, lives])
		var doors: PackedByteArray = recorded.doors
		for index in doors.size():
			if picture[2].has(index) or forced_doors.has(index): continue
			if doors[index] != live.doors[index]: differences.append("puerta %d a %d s" % [index, int(picture[0])])
	same = same and differences.is_empty()
	check("La grabación dice lo que pasó: el piso rehecho de ella es el que había", same, ", ".join(differences.slice(0, 6)) if read else replay.problem)
	replay.free()
	bot_match.teardown()
	check("Y la tabla de mejores tiempos, intacta", level.records.runs.size() == board)
	var file := FileAccess.open("res://evidence/bots_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("BOTS_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	paused = false
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

## A body put somewhere, looking at a point.
func stand_looking(body, at: Vector3, point: Vector3) -> void:
	body.place(at + Vector3(0, 0.05, 0), 0.0)
	body.wish = Vector3.ZERO
	await frames(2)
	var offset: Vector3 = point - body.camera.global_position
	body.look_yaw = atan2(-offset.x, -offset.z)
	body.rotation.y = body.look_yaw
	body.look_pitch = atan2(offset.y, Vector2(offset.x, offset.z).length())
	body.camera.rotation.x = body.look_pitch
	await frames(1)

## What a bot sees (bot_senses.gd), with the match held still meanwhile: the
## refuge from its doorway, a note in the dark with and without the torch, and
## what the team says of a thing never seen once every room is looked round.
func seeing() -> void:
	bot_match.set_physics_process(false)
	var body = bot_match.bodies[0]
	var brain = bot_match.brains[0]
	var team = bot_match.team
	var map: RID = level.get_world_3d().navigation_map
	bot_match.options["knowledge"] = "discover"
	team.targets = SENSES.targets(level, 1)
	team.knowledge.refuges.clear()
	var refuge: Dictionary = level.manifest.rooms[int(level.manifest.refuges[0])]
	var lobby := int(level.manifest.gates[0].beyond)
	var outside := {}
	for doorway in FLOOR.doorways(refuge):
		if int(doorway.other) != lobby: outside = level.manifest.rooms[int(doorway.other)]
	var portal := FLOOR.portal_between(refuge, outside)
	var out := (FLOOR.position_of(outside) - FLOOR.position_of(refuge))
	out = Vector3(out.x, 0, out.z).normalized()
	await stand_looking(body, FLOOR.closest(map, portal + out * 1.0), FLOOR.position_of(refuge) + Vector3(0, 1.4, 0))
	for door in level.hotel.doors:
		if door.doorway.distance_to(portal) < 0.5 and not door.opened:
			door.open_immediately()
			forced_doors.append(level.hotel.doors.find(door))
	await frames(2)
	for look in 3: team.look(brain)
	check("Un bot en el vano del refugio lo ve", team.knowledge.refuges.has(0), str(body.global_position))
	# A note in a room gone dark: not from three metres without light, yes with the torch.
	var piece = null
	for candidate in level.containers:
		if int(candidate.digit) >= 0 and is_instance_valid(candidate.note):
			piece = candidate
			break
	var room := int(FLOOR.room_at(level.manifest.rooms, piece.global_position).get("id", -1))
	var was_dark: bool = level.hotel.dark_ids.has(room)
	level.hotel.dark_ids[room] = true
	var front: Vector3 = piece.global_basis.z
	await stand_looking(body, FLOOR.closest(map, piece.note.global_position + Vector3(front.x, 0, front.z).normalized() * 3.0), piece.note.global_position)
	body.torch.visible = false
	var dark: Dictionary = SENSES.look(level, body, "note", piece.note.global_position)
	body.torch.visible = true
	var torch: Dictionary = SENSES.look(level, body, "note", piece.note.global_position)
	body.torch.visible = false
	if not was_dark: level.hotel.dark_ids.erase(room)
	check("A oscuras, una nota a tres metros no se ve sin linterna y sí con ella", not dark.seen and torch.seen, "%s / %s" % [dark, torch])
	# Every room looked round and a set never seen: said, with the nearest
	# look there was, and given to the team so the floor goes on.
	team.targets = SENSES.targets(level, 2)
	var set_target: Dictionary = team.targets.filter(func(target): return target.kind == "tv")[0]
	team.knowledge.tvs.clear()
	team.stage = 2
	for other in level.manifest.rooms:
		if int(other.get("wing", -1)) == 1: team.cleared[int(other.id)] = true
	var before: int = bot_match.incidents.size()
	team.watch_stall()
	var said: Array = bot_match.incidents.slice(before).filter(func(entry): return entry.kind == "no_encontrado" and entry.severity == "grave")
	check("Recorrida la planta sin ver una tele, se dice y se le da al equipo", not said.is_empty() and team.knowledge.tvs.has(int(set_target.index)) and team.revealed.has(set_target.key), str(said))
	# As it was: the rest of this test plays with a team that knows.
	bot_match.incidents.resize(before)
	team.cleared.clear()
	team.stage = 0
	bot_match.options["knowledge"] = "oracle"
	for brain_each in bot_match.brains: brain_each.set_task({})
	body.place(level.match_net.spawn_point(body.slot), 0.0)
	await frames(2)
	bot_match.set_physics_process(true)

## The creature, with the match held still: the pace a bot keeps by what the
## creature would hear, one run down near the refuge getting into it, and
## mercy taking a strike that would have killed.
func minding() -> void:
	bot_match.set_physics_process(false)
	var body = bot_match.bodies[0]
	var brain = bot_match.brains[0]
	var creature = level.locust
	var map: RID = level.get_world_3d().navigation_map
	var refuge: Dictionary = level.manifest.rooms[int(level.manifest.refuges[0])]
	var lobby := int(level.manifest.gates[0].beyond)
	var outside := {}
	for doorway in FLOOR.doorways(refuge):
		if int(doorway.other) != lobby: outside = level.manifest.rooms[int(doorway.other)]
	var portal := FLOOR.portal_between(refuge, outside)
	var out := (FLOOR.position_of(outside) - FLOOR.position_of(refuge))
	out = Vector3(out.x, 0, out.z).normalized()
	for door in level.hotel.doors:
		if door.doorway.distance_to(portal) < 0.5 and not door.opened:
			door.open_immediately()
			forced_doors.append(level.hotel.doors.find(door))
	var spot := FLOOR.closest(map, portal + out * 4.0)
	await stand_looking(body, spot, portal + Vector3(0, 1.4, 0))
	creature.set_physics_process(true)
	creature.grace = 0.0
	# Far off, it walks; near enough to be heard walking, it does not.
	creature.global_position = FLOOR.closest(map, spot + out * 60.0) + Vector3(0, 0.04, 0)
	bot_match.threat.refresh()
	brain.pace_clock = 0.0
	var far: int = bot_match.pace_for(brain)
	creature.global_position = along(spot, 9.0) + Vector3(0, 0.04, 0)
	bot_match.threat.refresh()
	brain.pace_clock = 0.0
	var near: int = bot_match.pace_for(brain)
	check("Lejos de la criatura anda; donde lo oiría andar, se agacha o se para", far == BODY.Pace.WALK and near != BODY.Pace.WALK, "%d, %d · activa %s, en planta %s, oye %s, a %.1f m" % [far, near, bot_match.threat.active, bot_match.threat.near_planta(body.global_position), bot_match.threat.audible(body.global_position, "walk"), creature.global_position.distance_to(body.global_position)])
	# Hunted four metres from the refuge's door: into the refuge, where it is safe.
	creature.global_position = along(spot, 9.0) + Vector3(0, 0.04, 0)
	creature.look_at(Vector3(spot.x, creature.global_position.y, spot.z), Vector3.UP)
	creature.focus = body
	creature.last_known = spot
	creature.set_mode(creature.Mode.CHASE)
	bot_match.team.knowledge.refuges[0] = true
	level.spare = bot_match.spare_survivor
	var start: int = bot_match.incidents.size()
	# No errands meanwhile: what moves it is the creature.
	for brain_each in bot_match.brains: brain_each.set_task({})
	bot_match.team_clock = 1.0e9
	bot_match.set_physics_process(true)
	var safe: bool = await wait_for(func(): return level.point_in_refuge(body.global_position), 60 * 12)
	var caught: bool = bot_match.incidents.slice(start).any(func(entry): return entry.kind == "captura")
	check("Cazado junto al refugio, corre a él y queda a salvo", safe and not caught, "%s%s" % [body.global_position, " · atrapado" if caught else ""])
	bot_match.set_physics_process(false)
	bot_match.team_clock = 0.0
	level.untouchable.clear()
	# Mercy: the strike is noted and nobody dies.
	var before: int = bot_match.incidents.size()
	body.place(spot + Vector3(0, 0.05, 0), 0.0)
	await frames(2)
	level.capture_survivor(body)
	var spared: bool = level.execution.is_empty() and level.untouchable.has(int(body.slot)) and level.session.participants.get(body.slot) != level.session.Life.DEAD
	var noted: bool = bot_match.incidents.slice(before).any(func(entry): return entry.kind == "captura")
	check("Con clemencia, la captura se anota y no mata", spared and noted)
	bot_match.incidents.resize(start)
	level.spare = Callable()
	level.untouchable.clear()
	# As it was for the rest: the creature out of the way, the bot at the start.
	creature.set_physics_process(false)
	creature.set_mode(creature.Mode.PATROL)
	creature.focus = null
	creature.global_position = FLOOR.position_of(level.manifest.rooms[int(level.manifest.refuges[2])]) + Vector3(0, 0.04, 0)
	bot_match.threat.refresh()
	for brain_each in bot_match.brains: brain_each.set_task({})
	body.place(level.match_net.spawn_point(body.slot), 0.0)
	await frames(2)
	bot_match.set_physics_process(true)

## A dictionary of seats as a sorted list, so two with the same contents in
## another order read the same.
func pairs(values: Dictionary) -> Array:
	var out: Array = []
	for key in values: out.append([int(key), int(values[key])])
	out.sort()
	return out

## The point `metres` of walking from `from` towards the reception: a place
## that is that far by the way a noise travels, not through a wall.
func along(from: Vector3, metres: float) -> Vector3:
	var route := FLOOR.navigation_path(level.get_world_3d().navigation_map, from, Vector3(0, 0.04, 0))
	var left := metres
	for i in range(1, route.size()):
		var leg: float = route[i - 1].distance_to(route[i])
		if leg >= left: return route[i - 1].lerp(route[i], left / leg)
		left -= leg
	return route[route.size() - 1] if route.size() > 0 else from

## Doors mid-swing: a picture taken then counts them where they are going.
func moving_doors() -> Array:
	var out: Array = []
	for index in level.hotel.doors.size():
		if level.hotel.doors[index].moving: out.append(index)
	return out

func incidents_text() -> String:
	return ", ".join(bot_match.incidents.map(func(entry): return "%s %s: %s" % [entry.kind, entry.bot, entry.words]))
