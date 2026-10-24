extends RefCounted
## The Lurker's mind (docs/OFICINAS.md 4; spec_f2_mind 7), on the machine that
## drives her. It never touches the scene: it reads a Percept (lurker_senses.gd),
## asks a world port (lurker.gd, or a test's fake) for what it knows of the
## map, and returns an intent, which lurker.gd turns into her motion. It draws
## only from the rng it is given. Above all of it is the warning
## (lurker_warning.gd): the only way to a take.
##
## Her states: her round (by ducts and ceilings), listening at a grille,
## stalking her prey out of their sight, a show at the edge of a view,
## frozen by a look in the light, closing in, the warning, the take, the
## recoil, the flight, the way between plantas and waiting above a locker.
const SENSES := preload("res://game/enemies/lurker/lurker_senses.gd")
const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")

## m/s. Survivors walk at 3.8 (OFICINAS 1): she is slower than any of them,
## but keeps up with one who only walks away from her warning (the author,
## 24 October 2026: leaving saves only running).
const CRAWL_SPEED := 1.35
## x creep_scale.
const CREEP_SPEED := 1.0
const CUE_FOLLOW := 3.8
const SCURRY_SPEED := 3.5
const FLEE_SPEED := 2.0
const RETREAT_SPEED := 0.8
## The warning: from this near to this far behind them (OFICINAS 4: 2 to 3 m),
## and the spot she creeps to.
const CUE_RANGE := Vector2(2.0, 3.0)
const CUE_DIST := 2.4
## s of a torch on her face before she recoils (in a warning, one tick).
const TORCH_SCARE := 0.2
## s looked at in the light before she freezes; s unlooked-at before she goes on.
const FREEZE_AFTER := 0.3
const UNFREEZE := 1.0
const RECOIL_HOLD := 0.5
## Her flight: how long she stays inside the duct after.
const FLEE_HIDE := 6.0
## s she cannot get behind them before she drops back to stalking.
const CREEP_LOSE := 2.0
## s with nothing to play the capture before the take is over (phase 2 has
## no capture style).
const TAKE_EMPTY := 0.2
## Her shriek when she is frightened (tools/audio/prepare_lurker_sfx.py).
const SCARE_SOUNDS := ["res://assets/audio/sfx/lurker/scare_0.wav", "res://assets/audio/sfx/lurker/scare_1.wav"]
const SCARE_GAIN := -2.0

enum State { ROAM, LISTEN, STALK, PEEK, FREEZE, CREEP, CUE, TAKE, RECOIL, FLEE, TRANSIT, WAIT_ABOVE }
## Her words, by state (creature.gd's lists): stalking is her own word,
## hostile but not hunting (the author, 24 October 2026).
const WORDS := {State.ROAM: &"roam", State.LISTEN: &"search", State.STALK: &"stalk", State.PEEK: &"investigate", State.FREEZE: &"alert",
	State.CREEP: &"chase", State.CUE: &"strike", State.TAKE: &"capture", State.RECOIL: &"recover", State.FLEE: &"withdraw", State.TRANSIT: &"roam", State.WAIT_ABOVE: &"wait"}
const NAMES := {State.ROAM: "RONDAR", State.LISTEN: "ESCUCHAR", State.STALK: "ACECHAR", State.PEEK: "ASOMARSE", State.FREEZE: "QUIETA",
	State.CREEP: "ACERCARSE", State.CUE: "AVISO", State.TAKE: "COGER", State.RECOIL: "ESPANTARSE", State.FLEE: "HUIR", State.TRANSIT: "TRÁNSITO", State.WAIT_ABOVE: "ENCIMA"}

signal cue_started(entry: Dictionary)
signal cue_ended(entry: Dictionary)
signal scared(cause: String, seat: int)
signal took(seat: int)

var world
var rng: RandomNumberGenerator
var warning
var clock := 0.0
var state := State.ROAM
var state_time := 0.0
var prey := -1
## A noise she heard: {point, at}; it moves her only in ROAM and LISTEN (2b-2).
var clue := {}
## seat -> clock until which she leaves them be.
var spurned := {}
var sated_until := -INF
var torch_time := 0.0
var regard_time := 0.0
var unregard_time := 0.0
var creep_lost := 0.0
## The state a freeze goes back to.
var resume := State.ROAM
## Where the flight is from, and whether she is inside yet.
var away_from := Vector3.ZERO
var hidden_since := -1.0
var screamed := false
var take_sent := false
## This tick's delta.
var step := 0.0
## Her numbers (tune(); defaults are Desafiante's).
var window := 1.5
var lit_takes := true
var stalk_distance := 8.0
var freeze_time := 4.0
var scare_calm := 35.0
var creep_scale := 1.0
var sated := 40.0

func setup(port, draws: RandomNumberGenerator, held_warning) -> void:
	world = port
	rng = draws
	warning = held_warning if held_warning != null else WARNING.new()

## Her keys of difficulty.gd (spec_f2_mind 4.1).
func tune(profile: Dictionary) -> void:
	window = float(profile.get("back_window", window))
	lit_takes = bool(profile.get("lit_takes", lit_takes))
	stalk_distance = float(profile.get("stalk_distance", stalk_distance))
	freeze_time = float(profile.get("freeze_time", freeze_time))
	scare_calm = float(profile.get("scare_calm", scare_calm))
	creep_scale = float(profile.get("creep_scale", creep_scale))
	sated = float(profile.get("sated", sated))
	var every = profile.get("peek_every")
	if every is Vector2: peek_every = every

func activity() -> StringName: return WORDS[state]

func state_name() -> String: return NAMES[state]

func prey_seat() -> int: return prey

func noticing() -> bool:
	return prey >= 0 and state in [State.STALK, State.CREEP, State.CUE, State.PEEK, State.FREEZE, State.WAIT_ABOVE, State.TAKE]

func enter(next: State) -> void:
	state = next
	state_time = 0.0
	creep_lost = 0.0
	take_sent = false

## Into a state for the workbench and the tests ({"seat": n} for STALK and
## CREEP). CUE and TAKE cannot be forced: they only come from CREEP and the
## warning.
func force(next: StringName, data := {}) -> void:
	var wanted := String(next).to_upper()
	if wanted == "CUE" or wanted == "TAKE" or not State.has(wanted): return
	# Forced, whatever warning was running is given up.
	warning.cancel(clock, "movida")
	if data.has("seat"): prey = int(data.seat)
	if data.has("hide"):
		locker = data.hide
		hold_until = clock + rng.randf_range(WAIT_ABOVE_TIME.x, WAIT_ABOVE_TIME.y)
	enter(State[wanted])
	if State[wanted] == State.STALK: peek_clock = rng.randf_range(peek_every.x, peek_every.y)

## Everything of the moment forgotten (a teleport, a stage given back): the
## warning in hand given up.
func forget_all(_rest: float) -> void:
	warning.cancel(clock, "movida")
	prey = -1
	lead = {}
	clue = {}
	show = {}
	goal = {}
	locker = null
	listening = false
	enter(State.ROAM)

func intent(what: StringName, fields := {}) -> Dictionary:
	var out := {"do": what, "clip": "", "look": Vector3.INF}
	out.merge(fields, true)
	return out

func hold(look := Vector3.INF, clip := "") -> Dictionary:
	return intent(&"hold", {"look": look, "clip": clip})

# --- One tick (7.4) -------------------------------------------------------------------

func tick(delta: float, p) -> Dictionary:
	clock += delta
	state_time += delta
	step = delta
	if p.grace: return hold()
	if p.transit != &"":
		if state != State.TRANSIT: enter(State.TRANSIT)
		return intent(&"keep")
	if state == State.TRANSIT: enter(State.ROAM)
	if state == State.CUE: return cue_tick(p)
	# A torch on her face: she recoils.
	if not state in [State.TAKE, State.RECOIL, State.FLEE]:
		torch_time = torch_time + delta if not p.torch_by.is_empty() else 0.0
		if torch_time >= TORCH_SCARE:
			recoil(int(p.torch_by[0]), "linterna", p)
			return recoil_tick(p)
	# Looked at: what is looked at in the light does not come on.
	if p.regarded_by.is_empty():
		regard_time = 0.0
		unregard_time += delta
	else:
		regard_time += delta
		unregard_time = 0.0
	if regard_time >= FREEZE_AFTER and state in [State.ROAM, State.LISTEN, State.STALK, State.CREEP, State.WAIT_ABOVE]:
		resume = state
		enter(State.FREEZE)
	match state:
		State.CREEP: return creep_tick(p)
		State.TAKE: return take_tick(p)
		State.RECOIL: return recoil_tick(p)
		State.FLEE: return flee_tick(p)
		State.FREEZE: return freeze_tick(p)
		State.ROAM: return roam_tick(p)
		State.LISTEN: return listen_tick(p)
		State.STALK: return stalk_tick(p)
		State.PEEK: return peek_tick(p)
		State.WAIT_ABOVE: return wait_above_tick(p)
	return hold()

## She only moves along a stretch nobody has exposed.
func exposed(p) -> bool:
	return not p.regarded_by.is_empty() or bool(p.stretch_exposed)

# --- Closing in and the warning ----------------------------------------------------------

## Everything a warning needs to begin, on this tick's truth.
func cue_ready(p) -> bool:
	var v = p.victim
	return state == State.CREEP and v != null and int(v.seat) == prey and bool(v.seen) and bool(v.fair) and not bool(v.hidden) \
		and not bool(p.in_duct) and not bool(p.off_limits) and float(v.distance) >= CUE_RANGE.x and float(v.distance) <= CUE_RANGE.y \
		and bool(v.behind) and p.regarded_by.is_empty() and p.torch_by.is_empty() and (lit_takes or not bool(v.lit)) \
		and warning.can_start(clock) and clock >= sated_until and float(spurned.get(prey, -INF)) <= clock

func creep_tick(p) -> Dictionary:
	var v = p.victim
	if v == null or int(v.seat) != prey:
		enter(State.STALK)
		return hold()
	if cue_ready(p):
		var entry: Dictionary = warning.start(prey, clock, window, float(v.latency), p.face, bool(v.above))
		enter(State.CUE)
		cue_started.emit(entry)
		return hold(v.eye)
	if not bool(v.fair) or bool(v.hidden):
		enter(State.STALK)
		return hold()
	creep_lost = 0.0 if bool(v.behind) else creep_lost + step
	if creep_lost >= CREEP_LOSE:
		enter(State.STALK)
		return hold()
	if exposed(p): return hold(v.eye)
	return intent(&"go", {"to": world.behind_point(v, CUE_DIST), "speed": CREEP_SPEED * creep_scale, "look": v.eye})

## The warning runs (7.4.3): checked first, on the truth, every tick.
func cue_tick(p) -> Dictionary:
	var v = p.victim
	var verdict: StringName = warning.check(clock, v, p, lit_takes)
	var entry: Dictionary = warning.ledger[warning.ledger.size() - 1] if not warning.ledger.is_empty() else {}
	match verdict:
		&"saved":
			cue_ended.emit(entry)
			recoil(int(entry.by), String(entry.reason), p)
			return recoil_tick(p)
		&"aborted":
			cue_ended.emit(entry)
			if String(entry.reason) == "escondida" and v != null and bool(v.hide_known):
				locker = v.hide
				hold_until = clock + rng.randf_range(WAIT_ABOVE_TIME.x, WAIT_ABOVE_TIME.y)
				enter(State.WAIT_ABOVE)
			else: enter(State.STALK)
			return hold()
		&"expired":
			cue_ended.emit(entry)
			enter(State.STALK)
			return hold()
		&"due":
			warning.take(clock)
			var seat := prey
			enter(State.TAKE)
			take_sent = true
			took.emit(seat)
			return intent(&"take", {"seat": seat, "leap": float(v.distance) > WARNING.TAKE_REACH, "look": v.eye})
	# Still running: she keeps behind them, at their walking pace at most.
	if float(v.distance) > CUE_RANGE.y:
		return intent(&"go", {"to": world.behind_point(v, CUE_DIST), "speed": CUE_FOLLOW, "look": v.eye, "exposed_ok": true})
	return hold(v.eye, "loom" if bool(p.on_channel) else "idle")

func take_tick(_p) -> Dictionary:
	if state_time >= TAKE_EMPTY:
		sated_until = clock + sated
		away_from = Vector3.ZERO
		prey = -1
		enter(State.FLEE)
	return hold()

## A noise she heard: kept as a clue.
func on_heard(_route: Dictionary, point: Vector3) -> void:
	clue = {"point": point, "at": clock}

func on_captured(execution: Dictionary) -> void:
	if execution.has("cue"): warning.captured(int(execution.cue))

func on_released() -> void:
	if state == State.TAKE:
		sated_until = clock + sated
		prey = -1
		enter(State.FLEE)

# --- Frightened ---------------------------------------------------------------------

func recoil(by: int, cause: String, p) -> void:
	if prey >= 0: spurned[prey] = clock + scare_calm
	away_from = p.face
	for seen in p.bodies.values():
		if int(seen.seat) == by: away_from = seen.eye
	enter(State.RECOIL)
	screamed = false
	torch_time = 0.0
	scared.emit(cause, by)

func recoil_tick(p) -> Dictionary:
	if not screamed:
		screamed = true
		world.scream(p.face)
	if state_time >= RECOIL_HOLD:
		enter(State.FLEE)
		hidden_since = -1.0
	return hold(away_from, "scare")

func flee_tick(p) -> Dictionary:
	if bool(p.in_duct):
		if hidden_since < 0.0: hidden_since = clock
		if clock - hidden_since >= FLEE_HIDE: enter(State.ROAM)
		return hold()
	var exit: int = world.flee_exit(away_from)
	if exit >= 0: return intent(&"duct", {"exit": exit, "speed": FLEE_SPEED, "clip": "crawl_fast"})
	return intent(&"go", {"to": world.dark_retreat(away_from), "speed": FLEE_SPEED, "exposed_ok": true, "clip": "crawl_fast"})

func freeze_tick(p) -> Dictionary:
	var look: Vector3 = Vector3.INF
	if not p.regarded_by.is_empty():
		for seen in p.bodies.values():
			if int(seen.seat) == int(p.regarded_by[0]): look = seen.eye
	if unregard_time >= UNFREEZE:
		enter(resume)
		return hold(look)
	if state_time >= freeze_time:
		# Looked at too long: she backs off, slowly, into the dark.
		return intent(&"go", {"to": world.dark_retreat(look if look != Vector3.INF else p.face), "speed": RETREAT_SPEED, "exposed_ok": true, "clip": "retreat", "look": look})
	return hold(look, "idle")

# --- Her round, listening, stalking, the shows, waiting above (7.5) ---------------------------

const STALK_SLACK := 2.0
const STALK_REPATH := 0.5
const LISTEN_TIME := Vector2(4.0, 8.0)
const LISTEN_P := 0.5
const SHOW_WAIT := 10.0
const PEEK_TIME := 4.0
const PEEK_SEEN := 0.35
const WAIT_ABOVE_TIME := Vector2(20.0, 40.0)
const SEARCHED_FOR := 60.0
const SWITCH_MARGIN := 0.3
const CHASE_EARSHOT := 9.0
## s a noise stays worth going to.
const CLUE_FOR := 20.0
## A room is stale for her round after this long.
const VISIT_STALE := 60.0

## {point, radius, until, kind, rooms, once, sniff}
var lead := {}
## room -> clock until which she leaves it be (listened at), room -> clock
## she was last there.
var searched := {}
var visited := {}
## Where her round is going: {point, room}; {} picks again.
var goal := {}
var hold_until := 0.0
var repath := 0.0
## PEEK: {kind, point, seat}.
var show := {}
var locker: Node3D = null
var peek_clock := 0.0
var peek_every := Vector2(40.0, 65.0)
## LISTEN: she hears further (lurker.gd copies it to her senses).
var listening := false

func searched_lately(room: int) -> bool:
	return float(searched.get(room, -INF)) > clock

## The director's zones (7.8): only while she goes about on her own.
func lead_to(point: Vector3, radius: float, seconds: float, kind: String, once := false, avoid := [], sniff := false) -> bool:
	if not state in [State.ROAM, State.LISTEN]: return false
	var rooms: Array = world.lead_rooms(point, radius, avoid)
	if rooms.is_empty(): return false
	lead = {"point": point, "radius": radius, "until": clock + seconds, "kind": kind, "rooms": rooms, "once": once, "sniff": sniff}
	goal = {}
	if state == State.LISTEN: enter(State.ROAM)
	return true

## At the zone of a "cruce" lead: a show for the first fair seat she perceives.
func on_lead_reached(p = null) -> void:
	if String(lead.get("kind", "")) != "cruce" or p == null: return
	for seat in sorted_seats(p):
		var seen = p.bodies[seat]
		if bool(seen.seen) and bool(seen.fair) and not bool(seen.hidden):
			start_show(int(seat), p)
			lead = {}
			return

func sorted_seats(p) -> Array:
	var seats: Array = p.bodies.keys()
	seats.sort()
	return seats

## Her own choice of prey (7.7): the one alone and in the dark, from what she
## perceives; never while sated, never one she spurned.
func candidates(p) -> Array:
	var out: Array = []
	if clock < sated_until: return out
	for seat in sorted_seats(p):
		var seen = p.bodies[seat]
		if bool(seen.seen) and bool(seen.fair) and not bool(seen.hidden) and float(spurned.get(int(seat), -INF)) <= clock: out.append(int(seat))
	return out

func score(seen) -> float:
	return 0.6 * clampf(float(seen.alone) / 15.0, 0.0, 1.0) + 0.4 * (0.0 if bool(seen.lit) else 1.0)

func choose_prey(p) -> int:
	var found := candidates(p)
	if found.is_empty(): return -1
	if found.size() == 1: return int(found[0])
	var best := int(found[0])
	for seat in found:
		if score(p.bodies[seat]) > score(p.bodies[best]): best = int(seat)
	return best

func roam_tick(p) -> Dictionary:
	listening = false
	var chosen := choose_prey(p)
	if chosen >= 0:
		prey = chosen
		enter(State.STALK)
		peek_clock = rng.randf_range(peek_every.x, peek_every.y)
		return hold()
	if not lead.is_empty() and clock >= float(lead.until): lead = {}
	if bool(p.failed): goal = {}
	if goal.is_empty():
		var room := -1
		if not lead.is_empty():
			var metres: Dictionary = world.travel_metres(int(p.room)) if int(p.room) >= 0 else {}
			var best := INF
			for r in lead.rooms:
				var stale: bool = clock - float(visited.get(int(r), -INF)) >= VISIT_STALE
				var m := float(metres.get(int(r), INF))
				if stale and m < best:
					best = m
					room = int(r)
			if room < 0: lead = {}
		if room >= 0: goal = {"point": world.room_point(room), "room": room}
		elif not clue.is_empty() and clock - float(clue.at) < CLUE_FOR: goal = {"point": world.clue_point(clue.point), "room": -1}
		else:
			var patrol: int = world.patrol_room()
			if patrol >= 0: goal = {"point": world.room_point(patrol), "room": patrol}
		if goal.is_empty(): return hold()
	if bool(p.arrived) and state_time > 0.5:
		var here := int(goal.get("room", int(p.room)))
		if here >= 0: visited[here] = clock
		if not lead.is_empty():
			if String(lead.kind) == "cruce": on_lead_reached(p)
			elif bool(lead.once): lead = {}
		goal = {}
		if state == State.PEEK: return hold()
		if int(p.room) >= 0 and world.exit_of_room(int(p.room)) >= 0 and rng.randf() < LISTEN_P:
			enter(State.LISTEN)
			hold_until = clock + rng.randf_range(LISTEN_TIME.x, LISTEN_TIME.y)
		return hold()
	if exposed(p): return hold()
	return intent(&"go", {"to": goal.point, "speed": CRAWL_SPEED})

func listen_tick(p) -> Dictionary:
	listening = true
	var chosen := choose_prey(p)
	if chosen >= 0:
		listening = false
		prey = chosen
		enter(State.STALK)
		return hold()
	if not clue.is_empty() and float(clue.at) > clock - 0.2:
		listening = false
		goal = {}
		enter(State.ROAM)
		return hold()
	if clock >= hold_until:
		listening = false
		if int(p.room) >= 0: searched[int(p.room)] = clock + SEARCHED_FOR
		enter(State.ROAM)
		return hold()
	var exit: int = world.exit_of_room(int(p.room)) if int(p.room) >= 0 else int(p.exit_here)
	return intent(&"listen", {"exit": exit}) if exit >= 0 else hold()

func stalk_tick(p) -> Dictionary:
	var seen = p.bodies.get(prey)
	if seen == null:
		var last = p.victim
		clue = {"point": last.point if last != null else p.face, "at": clock}
		prey = -1
		enter(State.ROAM)
		return hold()
	var v = p.victim
	if v != null and bool(v.hidden) and bool(v.hide_known):
		locker = v.hide
		enter(State.WAIT_ABOVE)
		hold_until = clock + rng.randf_range(WAIT_ABOVE_TIME.x, WAIT_ABOVE_TIME.y)
		return hold()
	if v != null and creep_ready(v, p):
		enter(State.CREEP)
		return hold(v.eye)
	# Another one more alone and in the dark: she changes her mind.
	for seat in candidates(p):
		if int(seat) != prey and score(p.bodies[seat]) > score(seen) + SWITCH_MARGIN:
			prey = int(seat)
			return hold()
	if bool(seen.seen):
		peek_clock -= step
		if peek_clock <= 0.0:
			if start_show(prey, p): return hold()
			peek_clock = 5.0
	repath -= step
	if float(seen.distance) <= stalk_distance + STALK_SLACK and float(seen.distance) >= stalk_distance - STALK_SLACK: return hold(seen.eye)
	if exposed(p): return hold(seen.eye)
	if repath > 0.0 and last_go != Vector3.INF: return intent(&"go", {"to": last_go, "speed": CRAWL_SPEED, "look": seen.eye})
	repath = STALK_REPATH
	last_go = world.behind_point(seen, stalk_distance)
	return intent(&"go", {"to": last_go, "speed": CRAWL_SPEED, "look": seen.eye})

var last_go := Vector3.INF

## Everything creeping in needs: they are hers, fair, behind, unwatched.
func creep_ready(v, p) -> bool:
	return bool(v.seen) and bool(v.fair) and not bool(v.hidden) and bool(v.behind) and float(v.distance) <= stalk_distance + 1.0 \
		and (not bool(v.lit) or lit_takes) and p.regarded_by.is_empty() and p.torch_by.is_empty() \
		and clock >= sated_until and float(spurned.get(prey, -INF)) <= clock

## A show at the edge of somebody's view (OFICINAS 4: "se asoma").
func start_show(seat: int, p) -> bool:
	var seen = p.bodies.get(seat)
	if seen == null: return false
	var spot: Dictionary = world.show_spot(seen, "peek")
	if spot.is_empty(): return false
	show = {"kind": "peek", "point": spot.point, "seat": seat, "arrived": false}
	prey = seat
	enter(State.PEEK)
	return true

func peek_tick(p) -> Dictionary:
	var seen = p.bodies.get(int(show.get("seat", -1)))
	var look: Vector3 = seen.eye if seen != null else Vector3.INF
	if not bool(show.get("arrived", false)):
		if bool(p.arrived) and state_time > 0.3:
			show["arrived"] = true
			hold_until = clock + PEEK_TIME
		elif state_time > SHOW_WAIT:
			enter(State.STALK if prey >= 0 else State.ROAM)
			return hold()
		elif exposed(p): return hold(look)
		else: return intent(&"go", {"to": show.point, "speed": CRAWL_SPEED, "look": look})
	# She looks, and goes all at once: when it is over, or once looked at.
	if regard_time >= PEEK_SEEN or clock >= hold_until:
		away_from = look if look != Vector3.INF else p.face
		hidden_since = -1.0
		enter(State.FLEE)
		return hold(look)
	return hold(look, "peek")

func wait_above_tick(p) -> Dictionary:
	var v = p.victim
	if v != null and not bool(v.hidden) and bool(v.fair):
		enter(State.CREEP)
		return hold(v.eye)
	if clock >= hold_until or not is_instance_valid(locker):
		if int(p.room) >= 0: searched[int(p.room)] = clock + SEARCHED_FOR
		locker = null
		prey = -1
		enter(State.ROAM)
		return hold()
	var over: Vector3 = world.above_locker(locker)
	if (p.face as Vector3).distance_to(over) > 0.6 and not exposed(p): return intent(&"go", {"to": over, "speed": CRAWL_SPEED})
	return hold(locker.global_position, "idle")
