extends Node
## A whole floor played by bots: builds it with their seats, puts the local
## player out of the way, gives each bot a body and a brain, runs the team,
## and keeps what happened -- every incident with its time, planta and room --
## until the floor is won, lost, or has run out of time.
##
## Nobody's game: nothing is written to the Continue checkpoint or to the
## board of best times (hotel_main.bot_match, session.keeps_checkpoint).
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const BODY := preload("res://tools/bots/bot_body.gd")
const BRAIN := preload("res://tools/bots/bot_brain.gd")
const TEAM := preload("res://tools/bots/bot_team.gd")
const WATCHDOG := preload("res://tools/bots/bot_watchdog.gd")
const RECORDER := preload("res://tools/bots/bot_recorder.gd")
const ERROR_TAP := preload("res://tools/bots/bot_error_tap.gd")
## The threat model of the floor's kind of creature (bot_threat.gd for The
## Locust).
const THREATS := preload("res://tools/bots/bot_threats.gd")
const NAMES := ["Bot 1", "Bot 2", "Bot 3", "Bot 4", "Bot 5"]
## Caps of simulated time: a stage, and the whole floor.
const STAGE_CAP := 1800.0
const RUN_CAP := 5400.0
var level
var options := {}
var bodies: Array = []
var brains: Array = []
var team
var threat
var threat_clock := 0.0
var rng := RandomNumberGenerator.new()
## Simulated seconds since the floor started (playing and between stages).
var clock := 0.0
var stage_clock := 0.0
var stage_seen := 0
var incidents: Array = []
var events: Array = []
## Once per kind, seat and place, so a bot pushing at the same wall for a
## minute is one incident and not six hundred.
var said := {}
var outcome := ""
var started_msec := 0
var team_clock := 0.0
var look_frame := 0
## The watchdog's second half, the recording (only with somewhere to put it),
## and what the engine reports going wrong.
var watchdog
var recorder
var error_tap
## Told of every incident as it happens (bot_watch.gd, live in the observer).
var report_to
## Faults put in on purpose, to see the watchdog catch them (--fault=).
var faults_done := {}
signal ended(summary: Dictionary)

func setup(owner_level, given: Dictionary) -> void:
	level = owner_level
	options = given
	name = "BotMatch"
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = hash([int(options.get("seed", 81)), "bots"])

func seats() -> Array:
	var out: Array = []
	for i in clampi(int(options.get("bots", 3)), 1, 5): out.append(2 + i)
	return out

## Builds the floor and plays it to the end. Returns the summary.
func play() -> Dictionary:
	if await begin():
		while outcome.is_empty(): await get_tree().physics_frame
	return finish()

## Builds the floor with the bots' seats and puts them on it. False when the
## floor could not be put up.
func begin() -> bool:
	started_msec = Time.get_ticks_msec()
	level.bot_match = true
	level.session.keeps_checkpoint = false
	if bool(options.get("mercy", false)): level.spare = spare_survivor
	await level.start_floor(int(options.get("seed", 81)), false, seats(), String(options.get("difficulty", "")))
	if level.session.state != level.session.State.PLAYING:
		outcome = "no_arranca"
		return false
	park_player()
	spawn_bodies()
	team = TEAM.new(self)
	team.brains = brains
	watchdog = WATCHDOG.new(self)
	error_tap = ERROR_TAP.new()
	OS.add_logger(error_tap)
	# Before the recording, which keeps of the creature what its model says.
	threat = THREATS.make(level)
	if threat == null:
		push_warning("Los bots no tienen modelo de la criatura %s." % String(level.creature.kind_id()))
		outcome = "sin_modelo"
		return false
	threat.novice = String(options.get("skill", "experto")) == "novato"
	threat.refresh()
	if not String(options.get("out", "")).is_empty():
		recorder = RECORDER.new(self, String(options.out))
		recorder.start()
	note("piso", null, {"seed": int(level.session.run_seed), "fallback": bool(level.manifest.get("fallback", false)), "bots": bodies.size()})
	return true

## The machine's own player is nobody in a bot match: out of sight, out of
## reach, not in the session, and not driven by anything.
func park_player() -> void:
	var player = level.player
	player.active = false
	player.visible = false
	player.collision_layer = 0
	player.held = true
	player.torch.visible = false
	player.velocity = Vector3.ZERO

func spawn_bodies() -> void:
	for i in seats().size():
		var seat: int = seats()[i]
		var body := BODY.new()
		body.setup(level, seat, NAMES[i], i % 3)
		body.process_mode = Node.PROCESS_MODE_PAUSABLE
		level.add_child(body)
		body.place(level.match_net.spawn_point(seat), level.player.rotation.y)
		level.match_net.bodies[seat] = body
		body.fell.connect(func(point): fell(body, point))
		bodies.append(body)
		brains.append(BRAIN.new(self, body))

func _physics_process(delta: float) -> void:
	if level == null or team == null or not outcome.is_empty(): return
	var state: int = level.session.state
	if state == level.session.State.WON:
		outcome = "ganada"
		return
	if state == level.session.State.FAILED:
		outcome = "perdida"
		return
	# Somebody playing the creature against them went back to the menu.
	if state == level.session.State.MENU:
		outcome = "abandonada"
		return
	if state != level.session.State.PLAYING and state != level.session.State.TRANSITION: return
	clock += delta
	if int(level.session.stage) != stage_seen:
		stage_seen = int(level.session.stage)
		stage_clock = 0.0
		team_clock = 0.0
		note("sector", null, {"stage": stage_seen})
	stage_clock += delta
	if state == level.session.State.PLAYING:
		threat_clock -= delta
		if threat_clock <= 0.0:
			threat_clock = 0.2
			threat.refresh()
		team_clock -= delta
		if team_clock <= 0.0:
			team_clock = 0.5
			team.tick(0.5)
		for brain in brains: brain.tick(delta)
		# Five looks a second each, not all on the same frame.
		look_frame += 1
		for i in brains.size():
			if (look_frame + i * 2) % 12 == 0: team.look(brains[i])
	if watchdog != null: watchdog.tick(delta)
	if recorder != null: recorder.tick(delta)
	watch_deaths()
	engine_errors()
	inject_faults()
	if stage_clock > float(options.get("stage_cap", STAGE_CAP)):
		report("tiempo", "grave", null, "el sector %d pasa de %d s" % [stage_seen, int(options.get("stage_cap", STAGE_CAP))])
		outcome = "tiempo_agotado"
	elif clock > float(options.get("run_cap", RUN_CAP)):
		report("tiempo", "grave", null, "la partida pasa de %d s" % int(options.get("run_cap", RUN_CAP)))
		outcome = "tiempo_agotado"

## The pace a bot walks at on its way: walking where the creature would not
## hear it, crouched where only that is not heard, and not a step where even
## that would be. Chosen four times a second (each choice asks the creature's
## own hearing along the routes). Coming nearer (on its way past within a few
## seconds), a walk it does not hear yet is one it is about to: crouched.
## `quiet`: asked while keeping out of its way, never bold.
func pace_for(brain, quiet := false) -> int:
	if not threat.near_planta(brain.body.global_position): return BODY.Pace.WALK
	# A novice does not walk carefully: it walks, and runs when it is scared.
	if threat.novice: return BODY.Pace.WALK
	if brain.bold() and not quiet: return BODY.Pace.CROUCH if threat.position.distance_to(brain.body.global_position) < 30.0 else BODY.Pace.WALK
	brain.pace_clock -= 1.0 / 60.0
	if brain.pace_clock > 0.0: return brain.pace_now
	brain.pace_clock = 0.25
	var hard := "_hard" if brain.body.hard_floor else ""
	var here: Vector3 = brain.body.global_position
	var ahead: Vector3 = brain.nav.next_point() if brain.nav.active() else here
	# Its ears are shut here (a chase listens only round where it lost them,
	# and holding somebody it hears nothing): any pace.
	if threat.deaf_to(here) and threat.deaf_to(ahead):
		brain.pace_now = BODY.Pace.WALK
		return brain.pace_now
	var closing: bool = threat.arrival(here, 20.0) < 5.0
	if not closing and not threat.audible(here, "walk" + hard) and not threat.audible(ahead, "walk" + hard): brain.pace_now = BODY.Pace.WALK
	elif not threat.audible(here, "crouch" + hard) and not threat.audible(ahead, "crouch" + hard): brain.pace_now = BODY.Pace.CROUCH
	else: brain.pace_now = BODY.Pace.STILL
	return brain.pace_now

## What sending a bot to `point` now would cost it in risk, in metres of
## walking: its eyes there soon, it coming past, or where it is going.
func task_danger(point: Vector3) -> float:
	if threat == null or not threat.near_planta(point): return 0.0
	var extra := 0.0
	if threat.time_to_sight(point) < 15.0: extra += 60.0
	if threat.arrival(point, 8.0) < 20.0: extra += 60.0
	if point.distance_to(threat.destination) < 12.0: extra += 60.0
	return extra

## Whether another bot stands, or is going to stand, within SPOT_APART of a
## place (its escape, bot_brain.safe_place).
const SPOT_APART := 4.0
func spot_taken(point: Vector3, asking) -> bool:
	for brain in brains:
		if brain == asking or not brain.alive(): continue
		if brain.body.global_position.distance_to(point) < SPOT_APART: return true
		if brain.escape != Vector3.INF and brain.escape.distance_to(point) < SPOT_APART: return true
	return false

## Metres of walking from a room to every room of its planta (kept).
var walks := {}
func walks_from(room_id: int) -> Dictionary:
	if not walks.has(room_id): walks[room_id] = FLOOR.route_metres(level.manifest, room_id)
	return walks[room_id]

# --- What happened ------------------------------------------------------------------

## Something worth looking at: kind, how bad ("leve", "media", "grave"), the
## bot it happened to (or null), in words, and anything else worth keeping.
func report(kind: String, severity: String, brain, words: String, extra := {}) -> void:
	var at: Vector3 = brain.body.global_position if brain != null else (level.creature.global_position if extra.get("creature", false) and is_instance_valid(level.creature) else Vector3.INF)
	if extra.has("where"): at = extra.where
	# About the floor, not a place on it: the stage's own planta, no room.
	var placed := at != Vector3.INF
	if not placed: at = Vector3(0, FLOOR.planta_y(maxi(int(level.session.stage) - 1, 0)), 0)
	var seat: int = brain.seat if brain != null else 0
	var key := "%s|%d|%d|%d|%s" % [kind, seat, roundi(at.x / 3.0), roundi(at.z / 3.0), words]
	if said.has(key) and clock - float(said[key]) < 30.0: return
	said[key] = clock
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, at) if placed and not level.manifest.is_empty() else {}
	var entry := {
		"t": snappedf(clock, 0.1),
		"kind": kind,
		"severity": severity,
		"seat": seat,
		"bot": brain.body.player_name if brain != null else "",
		"stage": int(level.session.stage),
		"planta": FLOOR.planta_of(at.y) + 1,
		"room": int(room.get("id", -1)),
		"room_name": room_name(room),
		"where": [snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01)],
		"words": words,
	}
	for field in extra:
		if field in ["where", "creature"]: continue
		var value = extra[field]
		entry[field] = [snappedf(value.x, 0.01), snappedf(value.y, 0.01), snappedf(value.z, 0.01)] if value is Vector3 else value
	incidents.append(entry)
	events.append({"t": entry.t, "kind": "incidencia", "entry": entry})
	if recorder != null: recorder.event("incidencia", {"entry": entry})
	if report_to != null: report_to.incident(entry)
	if bool(options.get("verbose", true)):
		print("BOT %s %s · %s · %s%s · %s" % [clock_text(clock), severity.to_upper(), kind, entry.bot + " · " if not entry.bot.is_empty() else "", entry.room_name, words])

## Something that happened, not wrong in itself, for the recording.
func note(kind: String, brain, data := {}) -> void:
	var entry := {"t": snappedf(clock, 0.1), "kind": kind}
	if brain != null: entry["seat"] = brain.seat
	entry.merge(data)
	events.append(entry)
	if recorder != null: recorder.event(kind, entry)

func room_name(room: Dictionary) -> String:
	if room.is_empty(): return "el piso"
	var number := int(room.get("number", 0))
	var planta := int(room.get("wing", 0)) + 1
	if number > 0: return "Habitación %d (planta %d)" % [number, planta]
	return "%s (planta %d)" % [FLOOR.palette(level.manifest).label(room), planta]

static func clock_text(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func fell(body, point: Vector3) -> void:
	var brain = brains[bodies.find(body)]
	report("fuera_del_mapa", "grave", brain, "cayó fuera del plano", {"where": point})
	var map: RID = level.get_world_3d().navigation_map
	var back := FLOOR.closest(map, Vector3(point.x, FLOOR.planta_y(brain.planta()), point.z))
	body.place(back + Vector3(0, 0.1, 0), body.rotation.y)
	brain.nav.clear()

## Mercy (-Mercy): the strike lands and nobody dies. Said, with how it
## happened; the creature is left looking for nobody, and the bot has a few
## seconds to get away before it can be taken again.
const SPARED_FOR := 6.0
func spare_survivor(body) -> bool:
	var index := bodies.find(body)
	if index < 0: return false
	var brain = brains[index]
	var creature = level.creature
	var mode: String = creature.mode_name().to_lower() if is_instance_valid(creature) else "?"
	report("captura", "grave", brain, "atrapado (perdonado) · la criatura en %s" % mode, {"spared": true})
	if body.hidden and is_instance_valid(body.hiding_place): level.match_net.remote_leaves(body.hiding_place, body)
	level.untouchable[int(body.slot)] = SPARED_FOR
	if is_instance_valid(creature):
		# Taken off somewhere else for a moment, or a spared bot is only spared
		# again six seconds later, and again, and the floor never goes on.
		var away := far_room(creature.global_position)
		creature.relocate(away + Vector3(0, 0.04, 0) if away != Vector3.INF else creature.global_position, SPARED_FOR)
		note("criatura_apartada", brain, {"to": RECORDER.vec(creature.global_position)})
	return true

## With mercy, a creature found shut in is taken somewhere else once it has
## been said: the finding is made, and the floor goes on.
func free_creature() -> void:
	if not bool(options.get("mercy", false)) or not is_instance_valid(level.creature): return
	var away := far_room(level.creature.global_position)
	if away == Vector3.INF: return
	level.creature.relocate(away + Vector3(0, 0.04, 0), 0.0)
	note("criatura_apartada", null, {"to": RECORDER.vec(level.creature.global_position), "why": "encerrada"})

## A room of the creature's planta at least SPARE_AWAY metres of walking from
## every living bot, the nearest such; INF when there is none.
const SPARE_AWAY := 40.0
func far_room(from: Vector3) -> Vector3:
	var map: RID = level.get_world_3d().navigation_map
	var planta := FLOOR.planta_of(from.y)
	var best := Vector3.INF
	var best_gap := INF
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != planta or FLOOR.is_void(room) or level.off_limits_rooms().has(int(room.id)): continue
		var centre := FLOOR.closest(map, FLOOR.position_of(room))
		var near_bot := false
		for other in bodies:
			if other.dead or FLOOR.planta_of(other.global_position.y) != planta: continue
			if other.global_position.distance_to(centre) < SPARE_AWAY: near_bot = true
		if near_bot: continue
		var gap: float = centre.distance_to(from)
		if gap < best_gap:
			best_gap = gap
			best = centre
	return best

## A bot the creature took for good (no mercy): an incident like a spared
## one, with what the creature was doing.
var lives_seen := {}
func watch_deaths() -> void:
	for i in brains.size():
		var seat: int = brains[i].seat
		var life = level.session.participants.get(seat, level.session.Life.DEAD)
		if life == level.session.Life.DEAD and lives_seen.has(seat) and lives_seen[seat] != life:
			report("muerte", "grave", brains[i], "muerto: la criatura lo ejecutó (la persecución, en el registro de modos de la grabación)")
		lives_seen[seat] = life

## Whatever the engine or a script reported since the last frame, as an
## incident with its second. Warnings are left to the log.
func engine_errors() -> void:
	if error_tap == null: return
	for entry in error_tap.drain():
		if String(entry.type) == "warning": continue
		var text := String(entry.rationale) if not String(entry.rationale).is_empty() else String(entry.code)
		report("error_motor", "grave", null, "%s (%s:%d, %s)" % [text, String(entry.file).get_file(), int(entry.line), entry.function])

## --fault=block: a wall across the first bot's way at 20 s; error: a script
## error at 30 s; hang: this process stops answering at 20 s. For testing that
## the watchdog and the runner catch each.
func inject_faults() -> void:
	var fault := String(options.get("faults", ""))
	if fault.is_empty(): return
	if fault == "block" and clock > 20.0 and not faults_done.has("block") and not brains.is_empty() and brains[0].nav.active():
		faults_done["block"] = true
		var brain = brains[0]
		var ahead: Vector3 = brain.nav.next_point()
		var way := Vector3(ahead.x - brain.body.global_position.x, 0, ahead.z - brain.body.global_position.z).normalized()
		if way == Vector3.ZERO: way = Vector3.FORWARD
		var wall := StaticBody3D.new()
		wall.name = "InjectedWall"
		wall.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(6.0, 2.5, 0.3)
		shape.shape = box
		wall.add_child(shape)
		level.add_child(wall)
		wall.global_position = brain.body.global_position + way * 1.2 + Vector3(0, 1.25, 0)
		wall.look_at(wall.global_position + way, Vector3.UP)
		note("fallo", null, {"fault": "block", "where": RECORDER.vec(wall.global_position)})
	elif fault == "error" and clock > 30.0 and not faults_done.has("error"):
		faults_done["error"] = true
		push_error("fallo inyectado por --fault=error")
	elif fault == "hang" and clock > 20.0:
		while true: OS.delay_msec(1000)

## The whole floor as it stands: what a keyframe of the recording keeps and
## what a replay jumps to. Doors (open or not) and which are locked, the sets,
## the drawers gone through, the numbers and whose, the code, the power, the
## stage, lives, and who is in which wardrobe.
func snapshot() -> Dictionary:
	var doors := PackedByteArray()
	var locked: Array = []
	for index in level.hotel.doors.size():
		var door = level.hotel.doors[index]
		# A leaf swinging counts as where it is going: the event that sent it
		# is before this picture, and a jump here must not leave it behind.
		doors.append(1 if door.opened != door.moving else 0)
		if door.locked: locked.append(index)
	var sets: Array = []
	for index in level.televisions.size():
		if level.televisions[index].on: sets.append(index)
	var searched: Array = []
	for index in level.containers.size():
		if level.containers[index].searched: searched.append(index)
	var hides := {}
	for index in level.hotel.hides.size():
		var occupant = level.hotel.hides[index].occupant
		if is_instance_valid(occupant) and "slot" in occupant: hides[index] = int(occupant.slot)
	return {"doors": doors, "locked": locked, "tvs": sets, "searched": searched, "digits": level.found_digits.duplicate(), "found_by": level.found_by.duplicate(), "code": bool(level.code_entered), "blackout": bool(level.hotel.dark), "stage": int(level.session.stage), "lives": level.session.participants.duplicate(), "hides": hides}

# --- The end ------------------------------------------------------------------------

func finish() -> Dictionary:
	# The line the floor left, or, for one that did not end, the ledger's now.
	var tape: Dictionary = level.ui.summary if not level.ui.summary.is_empty() else level.ledger.close(outcome == "ganada")
	var summary := {
		"result": outcome,
		"seed": int(options.get("seed", 81)),
		"floor_seed": int(level.session.run_seed),
		"fallback": bool(level.manifest.get("fallback", false)) if not level.manifest.is_empty() else false,
		"bots": seats().size(),
		"knowledge": String(options.get("knowledge", "discover")),
		"skill": String(options.get("skill", "experto")),
		"difficulty": String(level.difficulty),
		"mercy": bool(options.get("mercy", false)),
		"enemy": not OS.get_cmdline_user_args().has("--no-enemy"),
		"sim_seconds": snappedf(clock, 0.1),
		"wall_seconds": snappedf((Time.get_ticks_msec() - started_msec) / 1000.0, 0.1),
		"stage": int(level.session.stage),
		"sectors": level.run_stats.get("sectors", []).duplicate() + ([level.session.elapsed] if outcome == "ganada" else []),
		"deaths": int(level.run_stats.get("deaths", 0)),
		"hides": int(level.run_stats.get("hides", 0)),
		"incidents": incidents,
		"walked": brains.map(func(brain): return snappedf(brain.walked, 0.1)),
		"states": brains.map(func(brain): return brain.state_seconds.duplicate()),
		# What each seat lived through with the creature (run_ledger.gd), for
		# the tables that compare difficulties.
		"team": tape.get("team", []).map(func(member): return {"seat": int(member.seat), "encounters": int(member.get("encounters", 0)), "quiet": int(member.get("quiet", 0)), "chases": int(member.get("chases", 0)), "escapes": int(member.get("escapes", 0)), "chased": int(member.get("chased", 0)), "deaths": int(member.get("deaths", 0)), "closest": float(member.get("closest", -1.0))}),
		"restarts": int(level.session.restarts),
	}
	summary["realtime_factor"] = snappedf(float(summary.sim_seconds) / maxf(float(summary.wall_seconds), 0.001), 0.01)
	summary["revealed"] = team.revealed if team != null else []
	for entry in incidents: entry["replay_at"] = maxf(0.0, float(entry.t) - 8.0)
	engine_errors()
	if recorder != null:
		recorder.event("fin", {"result": outcome})
		recorder.close()
	if error_tap != null:
		OS.remove_logger(error_tap)
		error_tap = null
	ended.emit(summary)
	return summary

## Everything it added taken away again, for a floor after this one.
func teardown() -> void:
	for body in bodies:
		if is_instance_valid(body):
			level.match_net.bodies.erase(int(body.slot))
			body.queue_free()
	bodies.clear()
	brains.clear()
	level.bot_match = false
	level.spare = Callable()
	level.untouchable.clear()
