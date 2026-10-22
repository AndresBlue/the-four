extends RefCounted
## The watchdog's other half (the first is each bot's own stuck ladder,
## bot_brain.watch_progress): what nobody is doing anything about.
##  - The creature: its own stuck protocol climbing past its third step, a
##    creature that stays in a few metres or a few rooms for minutes while
##    there are bots on its planta (shut in somewhere), one left on a planta
##    the floor has moved on from, and one that keeps giving up its routes.
##  - The bots: going back and forth without getting anywhere, and a way
##    walked much longer than the one there was.
## Every finding goes to the match (bot_match.report) with where and when.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## Shut in: within SHUT_RADIUS for SHUT_TIME while it means to go somewhere;
## or through no more than SHUT_ROOMS rooms in SHUT_SPAN with bots about.
const SHUT_RADIUS := 5.0
const SHUT_TIME := 90.0
const SHUT_ROOMS := 3
const SHUT_SPAN := 300.0
## Left behind: this long on another planta after a stage changed; grave at
## LATE_GRAVE (the crossing measured 15-111 s, median 32).
const LATE := 180.0
const LATE_GRAVE := 300.0
## Giving up its routes more than this many times in a minute.
const ABANDONS := 5
## Back and forth: in OSCILLATE seconds it walked more than OSCILLATE_WALK and
## ended less than OSCILLATE_NET from where it started, on the same task.
const OSCILLATE := 60.0
const OSCILLATE_WALK := 40.0
const OSCILLATE_NET := 5.0
var owner_match
var level
var creature
var clock := 0.0
var anchor := Vector3.INF
var anchor_since := 0.0
var shut_said := false
var room_log: Array = []
var rooms_said := false
## Since when the rooms it goes through are counted (a floor, or a report).
var rooms_from := 0.0
var behind_since := -1.0
var behind_said := 0
var abandons: Array = []
var abandons_said := -INF
## Seat -> {since, start, walked, key}
var sways := {}

func _init(owner) -> void:
	owner_match = owner
	level = owner.level

func tick(delta: float) -> void:
	clock += delta
	if level.session.state != level.session.State.PLAYING: return
	watch_creature()
	for brain in owner_match.brains: watch_sway(brain, delta)

## The creature of this floor, connected once it exists.
func watch_creature() -> void:
	if not is_instance_valid(level.creature): return
	if creature != level.creature:
		creature = level.creature
		# Its own protocol for getting unstuck is its model's to know.
		owner_match.threat.on_stuck(creature, on_escalated, on_abandoned)
		anchor = Vector3.INF
		room_log.clear()
		rooms_from = clock
	if not creature.is_physics_processing() or creature.control != "ai" or creature.grace > 0.0: return
	var at: Vector3 = creature.global_position
	# On its rounds, going to look at something or after somebody: meaning to
	# get somewhere.
	var moving: bool = creature.activity() in [&"roam", &"investigate", &"chase"]
	if not is_finite(anchor.x) or at.distance_to(anchor) > SHUT_RADIUS or not moving:
		anchor = at
		anchor_since = clock
		shut_said = false
	elif clock - anchor_since > SHUT_TIME and not shut_said:
		shut_said = true
		owner_match.report("criatura_encerrada", "grave", null, "la criatura lleva %d s en %d m queriendo ir a otra parte (%s)" % [int(clock - anchor_since), int(SHUT_RADIUS), mode_name()], {"where": at, "creature": true})
		owner_match.free_creature()
	# Rooms it has been in over the last minutes, while bots share its planta.
	var room := int(FLOOR.room_at(level.manifest.rooms, at).get("id", -1))
	if room >= 0 and (room_log.is_empty() or int(room_log[-1][1]) != room): room_log.append([clock, room])
	while not room_log.is_empty() and clock - float(room_log[0][0]) > SHUT_SPAN: room_log.pop_front()
	var planta := FLOOR.planta_of(at.y)
	var company: bool = owner_match.brains.any(func(brain): return brain.alive() and brain.planta() == planta)
	if company and clock - rooms_from > SHUT_SPAN and not rooms_said:
		var distinct := {}
		for entry in room_log: distinct[int(entry[1])] = true
		if distinct.size() <= SHUT_ROOMS:
			rooms_said = true
			owner_match.report("criatura_encerrada", "grave", null, "la criatura lleva %d s entre %d salas con bots en su planta" % [int(SHUT_SPAN), distinct.size()], {"where": at, "creature": true})
			owner_match.free_creature()
			room_log.clear()
			rooms_from = clock
			rooms_said = false
	# On a planta the floor has left behind.
	if planta < int(level.session.stage) - 1:
		if behind_since < 0.0: behind_since = clock
		var late: float = clock - behind_since
		if late > LATE and behind_said == 0:
			behind_said = 1
			owner_match.report("criatura_rezagada", "media", null, "la criatura sigue en la planta %d %d s después de cerrarse su sector" % [planta + 1, int(late)], {"where": at, "creature": true})
		elif late > LATE_GRAVE and behind_said == 1:
			behind_said = 2
			owner_match.report("criatura_rezagada", "grave", null, "la criatura sigue en la planta %d %d s después de cerrarse su sector" % [planta + 1, int(late)], {"where": at, "creature": true})
	else:
		behind_since = -1.0
		behind_said = 0

func on_escalated(step: int, where: Vector3) -> void:
	owner_match.note("criatura_atasco", null, {"step": step, "where": [snappedf(where.x, 0.1), snappedf(where.y, 0.1), snappedf(where.z, 0.1)]})
	if step >= 4: owner_match.report("criatura_atascada", "grave" if step >= 5 else "media", null, "la criatura sube al paso %d de su protocolo de atascos (%s)" % [step, "salto" if step >= 5 else "otro destino"], {"where": where, "creature": true, "step": step})

func on_abandoned(where: Vector3) -> void:
	abandons.append(clock)
	while not abandons.is_empty() and clock - float(abandons[0]) > 60.0: abandons.pop_front()
	if abandons.size() > ABANDONS and clock - abandons_said > 60.0:
		abandons_said = clock
		owner_match.report("criatura_sin_ruta", "media", null, "la criatura abandona %d rutas en un minuto" % abandons.size(), {"where": where, "creature": true})

func mode_name() -> String:
	return creature.mode_name().to_lower()

## A bot on the same errand for a minute that walked a lot and got nowhere.
func watch_sway(brain, delta: float) -> void:
	var key := String(brain.task.get("key", ""))
	var entry: Dictionary = sways.get(brain.seat, {})
	if entry.is_empty() or String(entry.key) != key or brain.out_of_play() or key.is_empty():
		sways[brain.seat] = {"since": clock, "start": brain.body.global_position, "walked": brain.walked, "key": key}
		return
	if clock - float(entry.since) < OSCILLATE: return
	var walked: float = brain.walked - float(entry.walked)
	var net: float = Vector2(brain.body.global_position.x - entry.start.x, brain.body.global_position.z - entry.start.z).length()
	if walked > OSCILLATE_WALK and net < OSCILLATE_NET:
		owner_match.report("bot_oscila", "media", brain, "%d m andados en %d s sin alejarse %d m, yendo a %s" % [int(walked), int(OSCILLATE), int(OSCILLATE_NET), brain.describe()])
	sways[brain.seat] = {"since": clock, "start": brain.body.global_position, "walked": brain.walked, "key": key}
