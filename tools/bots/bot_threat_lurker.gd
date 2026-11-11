extends "res://tools/bots/bot_threat.gd"
## The Lurker's model for the bots (docs/OFICINAS.md 11.6;
## spec_f3_integration 7.1): every member of The Locust's (bot_threat.gd),
## with her meaning where she has one, read through her contract and her
## brain; what a person does against her that a bot would not do on its own
## (mind()): turning with the torch on to its own warning, a teammate's torch
## on her face when she warns somebody near, guarding whoever is busy at
## something, and the last of a moving team looking back now and then; what
## the watchdog asks of her (audit_creature()); and what a recording keeps of
## her and how a replay puts her back (6.4).
##
## Her meaning for what the brain, the paths and the match read:
##   active, position, eye, forward, planta, room: her, her face, her look
##   mode -1 (never a Locust mode), activity her word, state and prey hers
##   hostile: stalking, closing in or warning; busy: taking somebody
##   hunted(body): hostile with that body as her prey; torch_catches(): never
##   exposed() and visible(): her sight from her face, 20 m in the dark and 4
##     into the light, nothing in between; watched(): from her way ahead too
##   audible(): her hearing of a noise along her routes and ducts
##   route_to() and eta(): her own travel, in metres and at her pace
##   time_to_sight() and arrival(): along her way ahead at her pace
##   deaf_to(): while she takes somebody; searched_near(): her lately
##   lose_after(): her forget; leaving(): fleeing or between plantas
##   landing: never (she never comes out of a lift)
##   on_gave_up() and on_stuck(): never fire
## Her row in a recording: x, y, z, her turn as a quaternion (qx, qy, qz, qw:
## on a ceiling she hangs upside down, which no yaw says), her mind's state
## (lurker_brain.State), her prey's seat (-1 nobody), in a duct (0 or 1), the
## duct node nearest her and the seconds left of a warning (0 with none).
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const SENSES := preload("res://game/enemies/lurker/lurker_senses.gd")
const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")
const BODY := preload("res://tools/bots/bot_body.gd")
const BOT_BRAIN := preload("res://tools/bots/bot_brain.gd")
## Seconds from the cue being played to the turn, give or take; and how many
## turn at all.
const REACT := {"experto": 0.35, "novato": 0.9}
const REACT_JITTER := 0.15
const TURN_CHANCE := {"experto": 1.0, "novato": 0.7}
## A teammate this near her face, seeing it, turns its torch on her.
const MATE_REACH := 8.0
## Cover: a worker this near gets a guard, who stands this far behind its
## back facing the room, for this long at most.
const COVER_REACH := 15.0
const COVER_BEHIND := 2.5
const COVER_MOST := 20.0
## The last of a moving team looks back this often, for this long.
const GLANCE_EVERY := Vector2(3.0, 7.0)
const GLANCE_FOR := 1.0
## Expert bots light their way while she is this near.
const TORCH_NEAR := 15.0
var state := -1
var prey := -1
## Seat -> {cue_id, point, played_at, delay, turns, helpers}: the cue played
## for that seat, while it lasts.
var cues := {}
## Worker seat -> {guard, since}.
var guards := {}
## One per cue played (7.5): at the victim's body when it was played.
var cue_records: Array = []
## Seat -> seconds: a reaction a bot has whatever its skill (the bots' test).
var react_override := {}
var rng := RandomNumberGenerator.new()
var listened = null
## Seat -> {next, until}: the looking back.
var glances := {}
## The watchdog's: takes already looked at, warnings already said hung, and
## whether the ledger's audit was already reported.
var takes_seen := 0
var hung_said := {}
var audit_said := false

func _init(owner_level) -> void:
	super(owner_level)
	rng.seed = 7151

func skill() -> String: return "novato" if novice else "experto"

func now() -> float: return float(level.session.elapsed)

# --- Her measures ----------------------------------------------------------------------

func sight_range() -> float: return SENSES.SIGHT_DARK

func chase_speed() -> float: return 1.35 * float(creature.brain.creep_scale) if active else 1.35

func track_speed() -> float: return chase_speed()

func torch_range() -> float: return SENSES.BEAM_SEEN

func wardrobe_done() -> float: return 0.0

func hearing_scale() -> float: return NOISE.HEARING_SCALE * (float(creature.senses.hearing) if active else 1.0)

func lose_after() -> float: return float(creature.senses.forget) if active else 12.0

func chase_earshot() -> float: return BRAIN.CHASE_EARSHOT

func leaving() -> bool: return active and state in [BRAIN.State.FLEE, BRAIN.State.TRANSIT]

# --- Her, a few times a second ------------------------------------------------------------

func refresh() -> void:
	creature = level.creature
	active = is_instance_valid(creature) and creature.is_physics_processing() and creature.control == "ai" and creature.get("brain") != null and creature.grace <= 0.0
	path_rooms.clear()
	danger.clear()
	vantages.clear()
	future.clear()
	search_points.clear()
	sight_cache.clear()
	landing = Vector3.INF
	if is_instance_valid(creature) and creature.has_signal("cue_played") and listened != creature:
		listened = creature
		creature.cue_played.connect(on_cue)
	if not active: return
	var brain = creature.brain
	state = int(brain.state)
	prey = int(brain.prey)
	position = creature.global_position
	eye = creature.face_point()
	var look: Vector3 = creature.global_basis.z
	forward = Vector3(look.x, 0, look.z).normalized() if Vector2(look.x, look.z).length() > 0.01 else Vector3.FORWARD
	mode = -1
	activity = creature.activity()
	planta = FLOOR.planta_of(position.y)
	room = int(FLOOR.room_at(level.manifest.rooms, position).get("id", -1))
	hostile = state in [BRAIN.State.STALK, BRAIN.State.CREEP, BRAIN.State.CUE]
	busy = state == BRAIN.State.TAKE
	lost_time = 0.0
	last_known = position
	pace = maxf(float(creature.motion.pace_now()), 1.35)
	if room >= 0: danger[room] = INF
	var ahead: PackedVector3Array = creature.motion.ahead(FUTURE * pace)
	destination = ahead[ahead.size() - 1] if not ahead.is_empty() else position
	future.append({"eye": eye, "t": 0.0})
	vantages.append(eye)
	var walked := 0.0
	var next_mark := FUTURE_STEP
	var next_vantage := VANTAGE_STEP
	for i in range(1, ahead.size()):
		var a: Vector3 = ahead[i - 1]
		var b: Vector3 = ahead[i]
		var leg := a.distance_to(b)
		var id := int(FLOOR.room_at(level.manifest.rooms, b).get("id", -1))
		if id >= 0 and walked <= PATH_AHEAD: path_rooms[id] = true
		while walked + leg >= next_mark and next_mark / pace <= FUTURE:
			future.append({"eye": a.lerp(b, (next_mark - walked) / maxf(leg, 0.001)), "t": next_mark / pace})
			next_mark += FUTURE_STEP
		while walked + leg >= next_vantage and next_vantage <= PATH_AHEAD:
			vantages.append(a.lerp(b, (next_vantage - walked) / maxf(leg, 0.001)))
			next_vantage += VANTAGE_STEP
		walked += leg
	for id in path_rooms:
		if id != room: danger[id] = float(danger.get(id, 0.0)) + COST_PATH

## Whether a point is in a lit room: she sees into the light only near.
func lit_at(point: Vector3) -> bool:
	var id := int(FLOOR.room_at(level.manifest.rooms, point).get("id", -1))
	return id >= 0 and bool(level.hotel.lit(id))

func clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, SIGHT_MASK)
	query.exclude = [creature.get_rid()] if is_instance_valid(creature) else []
	return level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func exposed(point: Vector3, height := 1.64) -> bool:
	if not near_planta(point) or bool(creature.motion.in_duct): return false
	var target := point + Vector3(0, height, 0)
	var offset := target - eye
	if offset.length() > (SENSES.SIGHT_LIT if lit_at(point) else SENSES.SIGHT_DARK): return false
	if offset.length() > SENSES.SIGHT_NEAR and forward.angle_to(Vector3(offset.x, 0, offset.z)) > deg_to_rad(SENSES.SIGHT_HALF): return false
	return clear(eye, target)

func visible(point: Vector3, height := 1.64) -> bool:
	if not near_planta(point) or bool(creature.motion.in_duct): return false
	var target := point + Vector3(0, height, 0)
	if target.distance_to(eye) > (SENSES.SIGHT_LIT if lit_at(point) else SENSES.SIGHT_DARK): return false
	return clear(eye, target)

func route_to(point: Vector3) -> float:
	if not near_planta(point) or room < 0: return INF
	var to := int(FLOOR.room_at(level.manifest.rooms, point).get("id", -1))
	if to == room: return Vector2(point.x - position.x, point.z - position.z).length()
	return float(creature.travel_metres(room).get(to, INF))

func eta(point: Vector3) -> float:
	var metres := route_to(point)
	return metres / pace if metres != INF else INF

func deaf_to(_point: Vector3) -> bool: return busy

func searched_near(point: Vector3, _near := 5.0) -> bool:
	return active and creature.searched_lately(int(FLOOR.room_at(level.manifest.rooms, point).get("id", -1)))

func hunted(body) -> bool:
	return near_planta(body.global_position) and hostile and prey == int(body.slot)

func torch_catches(_body) -> bool: return false

func on_gave_up(_heard: Callable) -> void: pass

func on_stuck(_it, _escalated: Callable, _abandoned: Callable) -> void: pass

# --- Her warnings ---------------------------------------------------------------------------

## A cue played for a seat (lurker.cue_played): the bot's to turn to, after
## its reaction; and what it was like from the victim, for the batch.
func on_cue(seat: int, cue_id: int, point: Vector3) -> void:
	var delay: float = float(react_override.get(seat, REACT[skill()] + rng.randf_range(-REACT_JITTER, REACT_JITTER)))
	cues[seat] = {"cue_id": cue_id, "point": point, "played_at": now(), "delay": delay, "turns": rng.randf() < float(TURN_CHANCE[skill()]), "helpers": {}}
	var victim = null
	for body in level.survivors():
		if is_instance_valid(body) and int(body.slot) == seat: victim = body
	if victim == null or victim.get("camera") == null: return
	var view: Vector3 = -victim.camera.global_basis.z
	var to_her: Vector3 = point - victim.camera.global_position
	var entry: Dictionary = creature.warning.active if is_instance_valid(creature) else {}
	cue_records.append({"id": cue_id, "seat": seat, "played_at": snappedf(now(), 0.01), "angle": snappedf(rad_to_deg(Vector3(view.x, 0, view.z).angle_to(Vector3(to_her.x, 0, to_her.z))), 0.1), "above": rad_to_deg(Vector3(to_her.x, 0, to_her.z).angle_to(to_her)) >= 50.0 and to_her.y > 0.0, "distance": snappedf(to_her.length(), 0.01), "routed": bool(level.world_audio.route_source(point, RID(), victim.camera.global_position).get("audible", false)), "delay": snappedf(float(creature.brain.clock) - float(entry.get("at", creature.brain.clock)), 0.01) if not entry.is_empty() else 0.0})

func cue_over(cue: Dictionary) -> bool:
	if not is_instance_valid(creature): return true
	var entry: Dictionary = creature.warning.active
	return entry.is_empty() or int(entry.id) != int(cue.cue_id)

## The cue records with what each came to (the ledger's outcome, and the
## seconds from its playing to the take), for the match's summary.
func cue_summary() -> Array:
	var ledger: Array = creature.capture_log() if is_instance_valid(creature) else []
	var by_id := {}
	for e in ledger: by_id[int(e.id)] = e
	var out: Array = []
	for record in cue_records:
		var row: Dictionary = record.duplicate()
		var e: Dictionary = by_id.get(int(record.id), {})
		row["outcome"] = String(e.get("outcome", ""))
		row["reason"] = String(e.get("reason", ""))
		row["window"] = snappedf(float(e.get("window", 0.0)) + float(e.get("latency", 0.0)), 0.01)
		row["after"] = snappedf(float(e.take_at) - float(e.at), 0.01) if float(e.get("take_at", -1.0)) >= 0.0 else -1.0
		out.append(row)
	return out

# --- What a person does that a bot would not (bot_brain.mind_creature) ------------------------

## null: not its business this frame; true: it took the frame.
func mind(brain, delta: float) -> Variant:
	match_ref = brain.owner_match
	if not active or brain.body.hidden: return null
	var seat := int(brain.seat)
	var face: Vector3 = creature.face_point()
	var head: Vector3 = brain.body.camera.global_position
	# 1. Its own warning: after its reaction, round to her with the torch on.
	var mine: Dictionary = cues.get(seat, {})
	if not mine.is_empty():
		if cue_over(mine): cues.erase(seat)
		elif now() - float(mine.played_at) < float(mine.delay) or not bool(mine.turns): return null
		elif creature.drunk.has(seat) and not lit_at(head):
			# Its torch drunk (iteration 2, G1): turning to her saves nothing; running does.
			brain.go_to(brain.flee_point(), BODY.Pace.RUN, delta)
			brain.minding = "huye"
			return true
		else:
			brain.halt()
			brain.face(face)
			brain.body.torch_wanted = true
			brain.minding = "aviso"
			return true
	# 2. A teammate's: near her face and seeing it, its torch on her.
	for other in cues.keys():
		var theirs: Dictionary = cues[other]
		if int(other) == seat or cue_over(theirs) or creature.drunk.has(seat): continue
		if head.distance_to(face) > MATE_REACH or not clear(head, face): continue
		var helpers: Dictionary = theirs.helpers
		if not helpers.has(seat): helpers[seat] = now() + REACT[skill()] + rng.randf_range(-REACT_JITTER, REACT_JITTER)
		if now() < float(helpers[seat]): continue
		brain.halt()
		brain.face(face)
		brain.body.torch_wanted = true
		brain.minding = "alumbra"
		return true
	# 3. Cover: two that cover each other.
	if cover(brain, delta): return true
	return null

## A teammate at work (a "use" task, at it) within COVER_REACH with nobody
## guarding it gets this bot as its guard, if this one is standing or
## walking: behind the worker's back, facing the room, while the work lasts
## or COVER_MOST seconds.
func cover(brain, delta: float) -> bool:
	var seat := int(brain.seat)
	for worker in guards.keys():
		if int(guards[worker].guard) != seat: continue
		var w = brain_of(int(worker))
		if w == null or not w.alive() or not working(w) or now() - float(guards[worker].since) > COVER_MOST:
			guards.erase(worker)
			return false
		var spot := guard_spot(w)
		var me: Vector3 = brain.body.global_position
		if Vector2(spot.x - me.x, spot.z - me.z).length() > 0.4: brain.go_to(spot, BODY.Pace.WALK, delta)
		else:
			brain.halt()
			brain.face(spot + (spot - w.body.global_position).normalized() * 3.0 + Vector3(0, 1.5, 0))
		brain.body.torch_wanted = not lit_at(spot)
		brain.minding = "cubre"
		return true
	if working(brain) or not brain.state in [BOT_BRAIN.State.IDLE, BOT_BRAIN.State.MOVE]: return false
	for w in owner_match_of(brain).brains:
		if w == brain or not w.alive() or guards.has(int(w.seat)) or not working(w): continue
		if w.planta() != brain.planta() or w.body.global_position.distance_to(brain.body.global_position) > COVER_REACH: continue
		guards[int(w.seat)] = {"guard": seat, "since": now()}
		owner_match_of(brain).note("cubre", brain, {"worker": int(w.seat)})
		return true
	return false

func working(brain) -> bool:
	return String(brain.task.get("kind", "")) == "use" and brain.state == BOT_BRAIN.State.ACT

## Behind the worker's back by COVER_BEHIND: where its look is not.
func guard_spot(worker) -> Vector3:
	var yaw: float = worker.body.look_yaw
	var ahead := Vector3(-sin(yaw), 0, -cos(yaw))
	return worker.body.global_position - ahead * COVER_BEHIND

func owner_match_of(brain): return brain.owner_match

func brain_of(seat: int):
	for brain in owner_match_of_any().brains:
		if int(brain.seat) == seat: return brain
	return null

## The match is every brain's: any of them says which.
var match_ref = null
func owner_match_of_any():
	return match_ref

## 4. Looking back: in a moving team of two or more on her planta, in a room
## not lit, the one furthest from where it is going looks behind it for
## GLANCE_FOR every GLANCE_EVERY (bot_brain.walk_towards turns its head).
func looks_back(brain) -> bool:
	if not active or brain.planta() != planta or lit_at(brain.body.global_position): return false
	var moving: Array = owner_match_of(brain).brains.filter(func(b): return b.alive() and b.state == BOT_BRAIN.State.MOVE and b.planta() == planta)
	if moving.size() < 2: return false
	var last = moving[0]
	for b in moving:
		if b.body.global_position.distance_to(b.stand()) > last.body.global_position.distance_to(last.stand()): last = b
	if last != brain: return false
	var seat := int(brain.seat)
	var g: Dictionary = glances.get(seat, {"next": now() + rng.randf_range(GLANCE_EVERY.x, GLANCE_EVERY.y), "until": -INF})
	if now() >= float(g.next):
		g.until = now() + GLANCE_FOR
		g.next = now() + GLANCE_FOR + rng.randf_range(GLANCE_EVERY.x, GLANCE_EVERY.y)
	glances[seat] = g
	return now() < float(g.until)

## The torch: never hidden; on in the dark, while crawling, while a warning
## is on it, and (an expert) while she is near.
func wants_torch(body) -> bool:
	if body.hidden: return false
	var seat := int(body.slot)
	if cues.has(seat) and not cue_over(cues[seat]): return true
	if bool(body.get("crawling")): return true
	if not lit_at(body.global_position) or level.hotel.dark: return true
	return not novice and active and near_planta(body.global_position) and body.global_position.distance_to(position) < TORCH_NEAR

# --- The watchdog's (bot_watchdog.gd) -------------------------------------------------------

## Every take not a tool's paired with a warning of hers at that seat that
## it ended (spec_f3_integration 5.9); the ledger fair (WARNING.audit); and
## no warning left open past its time. `report` (kind, severity, words,
## extra) is the watchdog's.
func audit_creature(report: Callable) -> void:
	if not is_instance_valid(creature) or creature.get("brain") == null: return
	var ledger: Array = creature.capture_log()
	var takes: Array = creature.capture_records()
	while takes_seen < takes.size():
		var take: Dictionary = takes[takes_seen]
		takes_seen += 1
		if bool(take.get("forced", false)): continue
		var paired := ledger.any(func(e): return int(e.id) == int(take.cue) and int(e.seat) == int(take.seat) and String(e.outcome) == "taken")
		if not paired: report.call("captura_sin_aviso", "grave", "cogió al asiento %d sin su aviso (aviso %d)" % [int(take.seat), int(take.cue)], {"where": creature.global_position, "creature": true, "seat": int(take.seat)})
	if not audit_said:
		var wrong: Array = WARNING.audit(ledger)
		if not wrong.is_empty():
			audit_said = true
			report.call("registro_injusto", "grave", "su registro de avisos no es justo: %s" % str(wrong.slice(0, 3)), {"where": creature.global_position, "creature": true})
	var clock := float(creature.brain.clock)
	for e in ledger:
		if String(e.outcome) == "active" and clock > float(e.due) + WARNING.TAKE_HOLD + 2.0 and not hung_said.has(int(e.id)):
			hung_said[int(e.id)] = true
			report.call("aviso_colgado", "media", "el aviso %d sigue abierto %.1f s después de vencer" % [int(e.id), clock - float(e.due)], {"where": creature.global_position, "creature": true, "seat": int(e.seat)})

# --- What a recording keeps of her (6.4) ------------------------------------------------------

func recorded_row() -> Array:
	var it = level.creature
	if not is_instance_valid(it) or it.get("brain") == null or it.get("motion") == null: return []
	var at: Vector3 = it.global_position
	var turn: Quaternion = it.global_basis.get_rotation_quaternion()
	var left: float = maxf(0.0, float(it.warning.active.due) - float(it.brain.clock)) if not it.warning.active.is_empty() else 0.0
	return [at.x, at.y, at.z, turn.x, turn.y, turn.z, turn.w, int(it.brain.state), int(it.brain.prey), 1 if it.motion.in_duct else 0, int(it.motion.near_node), left]

## Her way ahead, its first sixteen points; null with no creature.
func recorded_route() -> Variant:
	var it = level.creature
	if not is_instance_valid(it) or it.get("motion") == null: return null
	var ahead: PackedVector3Array = it.motion.ahead(30.0)
	return ahead.slice(0, 16)

## Her mind's state and the seat she is after (-1: nobody).
func recorded_watch() -> Dictionary:
	var it = level.creature
	if not is_instance_valid(it) or it.get("brain") == null: return {}
	return {"mode": int(it.brain.state), "focus": int(it.brain.prey)}

## Said with a change of her state: where she is, and its name.
func recorded_mode_change() -> Dictionary:
	var it = level.creature
	if not is_instance_valid(it) or it.get("brain") == null: return {}
	return {"where": RECORDER.vec(it.global_position), "state": it.brain.state_name()}

## A replay's frame of her: placed and turned as the recording has her,
## between its two frames, with no state of her own to pull her elsewhere.
func replay_row(a: PackedFloat32Array, b: PackedFloat32Array, c: int, w: float, span: float) -> void:
	if c + 7 > a.size() or c + 7 > b.size(): return
	var it = level.creature
	var from := Vector3(a[c], a[c + 1], a[c + 2])
	var to := Vector3(b[c], b[c + 1], b[c + 2])
	var turn := Quaternion(a[c + 3], a[c + 4], a[c + 5], a[c + 6]).normalized().slerp(Quaternion(b[c + 3], b[c + 4], b[c + 5], b[c + 6]).normalized(), w)
	it.global_transform = Transform3D(Basis(turn), from.lerp(to, w))
	it.velocity = (to - from) / span if from.distance_to(to) <= 3.0 else Vector3.ZERO
	it.net_states.clear()

## And doing what the recording says she was doing then (her word, for the
## observer's panel).
func replay_mode(value: int) -> void:
	var it = level.creature
	it.net_mind = value
	it.word = BRAIN.WORDS.get(value, &"roam")
