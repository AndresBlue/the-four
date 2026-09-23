extends SceneTree
## The test bots (tools/bots): a floor built for their seats, the game's own
## rules applied to their bodies, and bots that get through a stage on their
## own feet. Staged pieces rather than whole floors, to fit verify.ps1.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const MATCH := preload("res://tools/bots/bot_match.gd")
const TV_PLACEMENT := preload("res://game/world/generation/tv_placement.gd")
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
const SENSES := preload("res://tools/bots/bot_senses.gd")
var level
var bot_match
var checks: Array = []
var failed := 0

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
	bot_match.setup(level, {"bots": 2, "seed": 81, "knowledge": "oracle", "verbose": true})
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
	# The other one closes the stage on its own feet.
	var through: bool = await wait_for(func(): return int(level.session.stage) >= 2 and level.session.state == level.session.State.PLAYING, 60 * 480)
	check("Un bot solo llega al refugio, se abre su puerta y toma el ascensor", through, "sector %d a los %d s · %s" % [level.session.stage, int(bot_match.clock), incidents_text()])
	await frames(10)
	check("Y el caído vuelve con el sector nuevo, en la planta de abajo", not victim.dead and victim.collision_layer == 4 and FLOOR.planta_of(victim.global_position.y) == 1, str(victim.global_position))
	var graves: Array = bot_match.incidents.filter(func(entry): return entry.severity == "grave")
	check("Sin incidencias graves por el camino", graves.is_empty(), incidents_text())
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
		if door.doorway.distance_to(portal) < 0.5 and not door.opened: door.open_immediately()
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

func incidents_text() -> String:
	return ", ".join(bot_match.incidents.map(func(entry): return "%s %s: %s" % [entry.kind, entry.bot, entry.words]))
