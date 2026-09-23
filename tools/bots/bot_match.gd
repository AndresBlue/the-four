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
const NAMES := ["Bot 1", "Bot 2", "Bot 3", "Bot 4", "Bot 5"]
## Caps of simulated time: a stage, and the whole floor.
const STAGE_CAP := 1800.0
const RUN_CAP := 5400.0
var level
var options := {}
var bodies: Array = []
var brains: Array = []
var team
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
## Components added by later phases, when present.
var watchdog
var recorder
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
	await level.start_floor(int(options.get("seed", 81)), false, seats())
	if level.session.state != level.session.State.PLAYING:
		outcome = "no_arranca"
		return false
	park_player()
	spawn_bodies()
	team = TEAM.new(self)
	team.brains = brains
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
	if state != level.session.State.PLAYING and state != level.session.State.TRANSITION: return
	clock += delta
	if int(level.session.stage) != stage_seen:
		stage_seen = int(level.session.stage)
		stage_clock = 0.0
		team_clock = 0.0
		note("sector", null, {"stage": stage_seen})
	stage_clock += delta
	if state == level.session.State.PLAYING:
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
	if stage_clock > float(options.get("stage_cap", STAGE_CAP)):
		report("tiempo", "grave", null, "el sector %d pasa de %d s" % [stage_seen, int(options.get("stage_cap", STAGE_CAP))])
		outcome = "tiempo_agotado"
	elif clock > float(options.get("run_cap", RUN_CAP)):
		report("tiempo", "grave", null, "la partida pasa de %d s" % int(options.get("run_cap", RUN_CAP)))
		outcome = "tiempo_agotado"

## The pace a bot walks at on its way. Without the creature to mind, it walks.
func pace_for(_brain) -> int:
	return BODY.Pace.WALK

# --- What happened ------------------------------------------------------------------

## Something worth looking at: kind, how bad ("leve", "media", "grave"), the
## bot it happened to (or null), in words, and anything else worth keeping.
func report(kind: String, severity: String, brain, words: String, extra := {}) -> void:
	var at: Vector3 = brain.body.global_position if brain != null else (level.locust.global_position if extra.get("creature", false) and is_instance_valid(level.locust) else Vector3.INF)
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
	if recorder != null: recorder.event("incidencia", entry)
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
	return "%s (planta %d)" % [String(FLOOR.NAMES[int(room.get("type", 0))]), planta]

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
	var creature = level.locust
	var mode: String = creature.Mode.keys()[creature.mode].to_lower() if is_instance_valid(creature) else "?"
	report("captura", "grave", brain, "atrapado (perdonado) · la criatura en %s" % mode, {"spared": true})
	if body.hidden and is_instance_valid(body.hiding_place): level.match_net.remote_leaves(body.hiding_place, body)
	level.untouchable[int(body.slot)] = SPARED_FOR
	if is_instance_valid(creature):
		creature.focus = null
		creature.detection = 0.0
		creature.last_known = creature.global_position
		creature.set_mode(creature.Mode.SEARCH)
	return true

# --- The end ------------------------------------------------------------------------

func finish() -> Dictionary:
	var summary := {
		"result": outcome,
		"seed": int(options.get("seed", 81)),
		"floor_seed": int(level.session.run_seed),
		"fallback": bool(level.manifest.get("fallback", false)) if not level.manifest.is_empty() else false,
		"bots": seats().size(),
		"knowledge": String(options.get("knowledge", "discover")),
		"mercy": bool(options.get("mercy", false)),
		"enemy": not OS.get_cmdline_user_args().has("--no-enemy"),
		"sim_seconds": snappedf(clock, 0.1),
		"wall_seconds": snappedf((Time.get_ticks_msec() - started_msec) / 1000.0, 0.1),
		"stage": int(level.session.stage),
		"sectors": level.run_stats.get("sectors", []).duplicate(),
		"deaths": int(level.run_stats.get("deaths", 0)),
		"hides": int(level.run_stats.get("hides", 0)),
		"incidents": incidents,
		"walked": brains.map(func(brain): return snappedf(brain.walked, 0.1)),
		"states": brains.map(func(brain): return brain.state_seconds.duplicate()),
	}
	summary["realtime_factor"] = snappedf(float(summary.sim_seconds) / maxf(float(summary.wall_seconds), 0.001), 0.01)
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
