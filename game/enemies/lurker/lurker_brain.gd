extends RefCounted
## The Lurker's mind (docs/OFICINAS.md 4; spec_lurker_rebuild 2), on the
## machine that drives her. It never touches the scene: it reads a Percept
## (lurker_senses.gd), asks a world port (lurker.gd, or a test's fake) for what
## it knows of the map, and returns an intent, which lurker.gd turns into her
## motion. It draws only from the rng it is given. Above all of it is the
## warning (lurker_warning.gd): the only way to a take.
##
## What is looked at does not come on; what is not looked at flies (2, the
## one sentence): every state has a time limit and a way out, she never holds
## still because somebody might see her way, and she keeps her prey by memory,
## not by sight. An encounter has beats you can hear: presence, stalking, a
## sudden silence, claws coming closer, the warning, and relief after.
const SENSES := preload("res://game/enemies/lurker/lurker_senses.gd")
const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")

## m/s. Survivors walk at 3.8 and run at 6.0 (survivor_gait.gd). Seen, she
## crawls; unseen, lurker.gd gives her the difficulty's speed (2.4).
const CRAWL_SPEED := 1.35
## x creep_scale: the least she closes in at; CREEP_LEAD over her prey's own
## pace, up to approach_cap: she catches up with a walker, never a runner.
const CREEP_SPEED := 1.0
const CREEP_LEAD := 0.6
const CUE_FOLLOW := 3.8
const SCURRY_SPEED := 3.5
const FLEE_SPEED := 3.5
const RETREAT_SPEED := 0.8
## The warning: from this near to this far behind them, and the spot she
## creeps to (spec_f3_aggression: her long leap is her attack).
const CUE_RANGE := Vector2(2.0, 5.0)
const CUE_DIST := 2.4
## s of a torch on her face before she recoils (in a warning, one tick).
const TORCH_SCARE := 0.0
## FREEZE is only force()'s now (the author, 24 October 2026: out of the
## light at once): s before she backs off, s unlooked-at before she goes on.
const FREEZE_TIME := 3.0
const UNFREEZE := 1.0
## Her flight: s inside the duct before she goes round again; s out of the
## ceiling before she is taken to be inside (2.2: a flight that never ended
## left her standing there for good; the author: never seen more than 0.4 s
## once lit, so a bolt that has not got her in by FLEE_OUT ends with her
## taken in where she is); s before the director may lead her.
const FLEE_HIDE := 6.0
const FLEE_OUT := 0.4
const FLEE_LEADABLE := 8.0
## s she cannot get behind them before she drops back to stalking: a turn of
## their head does not undo her (2.2).
const CREEP_LOSE := 5.0
## s with nothing to play the capture before the take is over.
const TAKE_EMPTY := 0.2
## Her shriek when she is frightened (tools/audio/prepare_lurker_sfx.py).
const SCARE_SOUNDS := ["res://assets/audio/sfx/lurker/scare_0.wav", "res://assets/audio/sfx/lurker/scare_1.wav"]
const SCARE_GAIN := -2.0

enum State { ROAM, LISTEN, STALK, PEEK, FREEZE, CREEP, CUE, TAKE, RECOIL, FLEE, TRANSIT, WAIT_ABOVE, HUSH, RETURN, AMBUSH }
## Her words, by state (creature.gd's lists): stalking is her own word,
## hostile but not hunting; the silence before she closes in is stalking too;
## coming back through the ceiling is withdrawn, not to be led.
const WORDS := {State.ROAM: &"roam", State.LISTEN: &"search", State.STALK: &"stalk", State.PEEK: &"investigate", State.FREEZE: &"alert",
	State.CREEP: &"chase", State.CUE: &"strike", State.TAKE: &"capture", State.RECOIL: &"recover", State.FLEE: &"withdraw", State.TRANSIT: &"roam", State.WAIT_ABOVE: &"wait",
	State.HUSH: &"stalk", State.RETURN: &"withdraw", State.AMBUSH: &"stalk"}
const NAMES := {State.ROAM: "RONDAR", State.LISTEN: "ESCUCHAR", State.STALK: "ACECHAR", State.PEEK: "ASOMARSE", State.FREEZE: "QUIETA",
	State.CREEP: "ACERCARSE", State.CUE: "AVISO", State.TAKE: "COGER", State.RECOIL: "ESPANTARSE", State.FLEE: "HUIR", State.TRANSIT: "TRÁNSITO", State.WAIT_ABOVE: "ENCIMA",
	State.HUSH: "SILENCIO", State.RETURN: "VOLVER", State.AMBUSH: "EMBOSCADA"}
## Her beat by state, for a machine that only has the state (a puppet: it
## tells roaming near from far itself). The brain's own beat is `beat`.
const BEATS := {State.ROAM: &"roam_far", State.LISTEN: &"listen", State.STALK: &"stalk", State.PEEK: &"peek", State.FREEZE: &"peek",
	State.CREEP: &"creep", State.CUE: &"cue", State.TAKE: &"cue", State.RECOIL: &"scare", State.FLEE: &"scare", State.TRANSIT: &"transit",
	State.WAIT_ABOVE: &"above", State.HUSH: &"hush", State.RETURN: &"return", State.AMBUSH: &"ambush"}
## Metres of her way to the nearest survivor under which her round is near (4).
const NEAR_ROUTE := 12.0

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
## The sound of what she is doing (spec_lurker_rebuild 4), set every tick.
var beat: StringName = &"roam_far"
## A noise she heard: {point, at}.
var clue := {}
## seat -> clock until which she leaves them be.
var spurned := {}
var sated_until := -INF
## Where her last take was: the rest after it covers only those near it (2.3).
var sated_point := Vector3.INF
## Clock until which she starts no new encounter on anybody (2.3).
var quiet_until := -INF
var torch_time := 0.0
var regard_time := 0.0
var unregard_time := 0.0
var creep_lost := 0.0
## Seconds asking to go without getting STALL_MOVE further (the one watch, 2.1;
## lurker_telemetry reads it). held_for is kept for it too and stays nought:
## nothing holds her for being seen any more.
var failed_for := 0.0
var held_for := 0.0
const STALL_TIME := 6.0
const STALL_MOVE := 0.5
var stalls := 0
var progress_at := Vector3.INF
## A way that failed or stalled: the next tries go by the plenum.
var route_hidden := false
## The state a freeze goes back to.
var resume := State.ROAM
## Where the flight is from, whether she is inside yet, and whether the exit
## she was making for failed her.
var away_from := Vector3.ZERO
var hidden_since := -1.0
var flee_retreat := false
var screamed := false
var take_sent := false
var took_point := Vector3.INF
## The seats whose torch was on her face at her last fright by torch:
## lurker.gd drinks them (iteration 2, G1).
var torches: Array = []
## This tick's delta.
var step := 0.0
## Survivors in play on her planta (Percept.team): the encounter is shared out
## among them (2.3).
var team := 1
const PAUSE_SCALE := [1.0, 0.75, 0.55, 0.4]
const STALK_SCALE := [1.0, 0.85, 0.7, 0.6]
const QUIET_BASE := 15.0
## m from a take inside which the rest after it holds (2.3).
const SATED_NEAR := 8.0
## Her numbers (tune(); defaults are Equilibrada's).
var window := 1.5
var lit_takes := true
var stalk_distance := 8.0
var tries := 3
var rest_after := 90.0
var emerge_delay := Vector2(4.0, 7.0)
var emerge_mode := "near"
var emerge_range := Vector2(6.0, 10.0)
var creep_scale := 0.9
var sated := 40.0
var stalk_time := Vector2(15.0, 25.0)
var peek_odds := 0.5
var hush_time := 2.5
var noise_react := 2.0
## Her round keeps near where she last knew somebody, this share of her picks
## (OFICINAS 1: "casi siempre está encima"): her own memory, never where they are.
var haunt_odds := 0.6
var haunt := Vector3.INF
const HAUNT_SPREAD := 9.0
var approach_cap := 3.5
var forget := 12.0
## Seat -> failed attempts in the encounter on them; the next attempt
## ({seat, at}) and the point she is coming back out at.
var attempts := {}
var comeback := {}
var emerging := Vector3.INF

func setup(port, draws: RandomNumberGenerator, held_warning) -> void:
	world = port
	rng = draws
	warning = held_warning if held_warning != null else WARNING.new()

## Her keys of difficulty.gd (spec_lurker_rebuild 2.5).
func tune(profile: Dictionary) -> void:
	window = float(profile.get("back_window", window))
	lit_takes = bool(profile.get("lit_takes", lit_takes))
	stalk_distance = float(profile.get("stalk_distance", stalk_distance))
	tries = int(profile.get("attempts", tries))
	rest_after = float(profile.get("encounter_rest", rest_after))
	emerge_mode = String(profile.get("emerge_mode", emerge_mode))
	emerge_delay = pair(profile.get("emerge_delay"), emerge_delay)
	emerge_range = pair(profile.get("emerge_range"), emerge_range)
	creep_scale = float(profile.get("creep_scale", creep_scale))
	sated = float(profile.get("sated", sated))
	stalk_time = pair(profile.get("stalk_time"), stalk_time)
	peek_odds = float(profile.get("peek_odds", peek_odds))
	hush_time = float(profile.get("hush", hush_time))
	noise_react = float(profile.get("noise_react", noise_react))
	haunt_odds = float(profile.get("haunt", haunt_odds))
	ambush_odds = float(profile.get("ambush_odds", ambush_odds))
	approach_cap = float(profile.get("approach_cap", approach_cap))
	forget = float(profile.get("forget", forget))

static func pair(value, fallback: Vector2) -> Vector2:
	if value is Array and value.size() == 2: return Vector2(float(value[0]), float(value[1]))
	return fallback

func activity() -> StringName: return WORDS[state]

func state_name() -> String: return NAMES[state]

func prey_seat() -> int: return prey

func noticing() -> bool:
	return prey >= 0 and state in [State.STALK, State.PEEK, State.HUSH, State.CREEP, State.CUE, State.TAKE, State.WAIT_ABOVE, State.RETURN, State.FREEZE, State.AMBUSH]

func enter(next: State) -> void:
	state = next
	state_time = 0.0
	creep_lost = 0.0
	take_sent = false
	failed_for = 0.0
	stalls = 0
	progress_at = Vector3.INF

## Into a state for the workbench and the tests ({"seat": n} for STALK and
## CREEP). CUE and TAKE cannot be forced: they only come from CREEP and the
## warning.
func force(next: StringName, data := {}) -> void:
	var wanted := String(next).to_upper()
	if wanted == "CUE" or wanted == "TAKE" or not State.has(wanted): return
	# Forced, whatever warning was running is given up.
	warning.cancel(clock, "movida")
	if data.has("seat"):
		prey = int(data.seat)
		track = {}
		seed_track = true
	if data.has("hide"):
		locker = data.hide
		hold_until = clock + rng.randf_range(WAIT_ABOVE_TIME.x, WAIT_ABOVE_TIME.y)
	emerging = Vector3.INF
	ambush_point = Vector3.INF
	ambush_share = 1.0
	if State[wanted] == State.STALK: begin_stalk(1.0)
	else: enter(State[wanted])

## Everything of the moment forgotten (a teleport, a stage given back): the
## warning in hand given up.
func forget_all(_rest: float) -> void:
	warning.cancel(clock, "movida")
	prey = -1
	track = {}
	lead = {}
	clue = {}
	show = {}
	goal = {}
	comeback = {}
	emerging = Vector3.INF
	locker = null
	listening = false
	enter(State.ROAM)

func intent(what: StringName, fields := {}) -> Dictionary:
	var out := {"do": what, "clip": "", "look": Vector3.INF}
	out.merge(fields, true)
	return out

## Stays where she is: only for what really stands still (2.4).
func hold(look := Vector3.INF, clip := "") -> Dictionary:
	return intent(&"hold", {"look": look, "clip": clip})

## Slows to a stop keeping her way (the silence, a look): lurker.gd's
## motion.pause().
func pause(look := Vector3.INF, clip := "") -> Dictionary:
	return intent(&"pause", {"look": look, "clip": clip})

## `hidden`: by the plenum, where nobody sees her way (2.1).
func go(to: Vector3, speed: float, look := Vector3.INF, hidden := false, clip := "") -> Dictionary:
	return intent(&"go", {"to": to, "speed": speed, "look": look, "hidden": hidden, "clip": clip})

# --- One tick ----------------------------------------------------------------------------

func tick(delta: float, p) -> Dictionary:
	var out := decide(delta, p)
	beat = beat_of(p)
	return out

func decide(delta: float, p) -> Dictionary:
	clock += delta
	state_time += delta
	step = delta
	if p.grace: return hold()
	if p.transit != &"":
		if state != State.TRANSIT: enter(State.TRANSIT)
		return intent(&"keep")
	if state == State.TRANSIT: enter(State.ROAM)
	team = maxi(1, int(p.team))
	remember(p)
	if state == State.CUE: return cue_tick(p)
	# A torch on her face: she recoils; an attempt only if she was after them.
	if not state in [State.TAKE, State.RECOIL, State.FLEE]:
		torch_time = torch_time + delta if not p.torch_by.is_empty() else 0.0
		if not p.torch_by.is_empty() and torch_time >= TORCH_SCARE:
			recoil(int(p.torch_by[0]), "linterna", p, closing(p))
			return recoil_tick(p)
	if p.regarded_by.is_empty():
		regard_time = 0.0
		unregard_time += delta
	else:
		regard_time += delta
		unregard_time = 0.0
	# Made out (a look in the light, or this near in the dark): out of it at
	# once, for the ceiling (the author, 24 October 2026).
	if regard_time > 0.0 and (state in [State.ROAM, State.LISTEN, State.STALK, State.HUSH, State.CREEP, State.WAIT_ABOVE, State.AMBUSH] or (state == State.RETURN and not bool(p.in_duct))):
		if closing(p): failed_attempt(prey)
		flee_from(p, int(p.regarded_by[0]))
		# Who lit her is where somebody is: her round comes back about there.
		haunt = away_from
	var out := state_tick(p)
	watch_progress(p, out)
	return out

func state_tick(p) -> Dictionary:
	match state:
		State.ROAM: return roam_tick(p)
		State.LISTEN: return listen_tick(p)
		State.STALK: return stalk_tick(p)
		State.PEEK: return peek_tick(p)
		State.HUSH: return hush_tick(p)
		State.CREEP: return creep_tick(p)
		State.TAKE: return take_tick(p)
		State.RECOIL: return recoil_tick(p)
		State.FLEE: return flee_tick(p)
		State.RETURN: return return_tick(p)
		State.WAIT_ABOVE: return wait_above_tick(p)
		State.FREEZE: return freeze_tick(p)
		State.AMBUSH: return ambush_tick(p)
	return hold()

## Her sound (spec_lurker_rebuild 4): what she is doing, and for her round how
## near she is by her own ways.
func beat_of(p) -> StringName:
	if state in [State.ROAM, State.LISTEN] and resting(): return &"rest" if state == State.ROAM else &"listen"
	if state == State.ROAM: return &"roam_near" if float(p.nearest_route) <= NEAR_ROUTE else &"roam_far"
	return BEATS[state]

## Nobody new for her for now: after an encounter, or a take.
func resting() -> bool:
	return clock < quiet_until or clock < sated_until

## Asking to go and not getting anywhere: first another way, then another room
## (2.1). It replaces GIVE_UP and HOLD_MOST; standing still on purpose (a
## pause, a hold, listening, the silence, above a locker, waiting inside the
## ceiling) is never counted.
func watch_progress(p, out: Dictionary) -> void:
	var face: Vector3 = p.face
	if not StringName(out.get("do", &"hold")) in [&"go", &"duct"]:
		failed_for = 0.0
		progress_at = face
		return
	if progress_at == Vector3.INF or face.distance_to(progress_at) >= STALL_MOVE:
		progress_at = face
		failed_for = 0.0
		stalls = 0
		return
	failed_for += step
	if failed_for < STALL_TIME: return
	failed_for = 0.0
	progress_at = face
	stalls += 1
	goal = {}
	last_go = Vector3.INF
	repath = 0.0
	route_hidden = not route_hidden
	if stalls < 2: return
	if int(p.room) >= 0: searched[int(p.room)] = clock + SEARCHED_FOR
	emerging = Vector3.INF
	comeback = {}
	prey = -1
	track = {}
	enter(State.ROAM)

## Whether she is after somebody close enough for being seen to cost her an
## attempt (2.3).
func closing(p) -> bool:
	if prey < 0: return false
	if state in [State.HUSH, State.CREEP]: return true
	if state != State.STALK: return false
	var seen = known(p)
	return seen != null and float(seen.distance) < stalk_distance

# --- Her prey, kept by memory (2.1) --------------------------------------------------------

## The prey as she last knew them: {seat, point, eye, heading, velocity, at}.
var track := {}
## Set by force(): the next remember() may take the prey from the truth.
var seed_track := false
## s ahead she reckons where they went out of her sight.
const PREDICT := 2.0
## m from where she reckons them within which a noise is theirs.
const NOISE_TRACK := 6.0

func remember(p) -> void:
	if prey < 0:
		track = {}
		return
	var seen = p.bodies.get(prey)
	if seen != null and (bool(seen.seen) or track.is_empty() or int(track.seat) != prey):
		track = {"seat": prey, "point": seen.point, "eye": seen.eye, "heading": seen.heading, "velocity": seen.velocity, "at": clock if bool(seen.seen) else float(seen.seen_at)}
		haunt = seen.point
	elif seed_track and track.is_empty() and p.victim != null and int(p.victim.seat) == prey:
		# Put on somebody by a tool (force()): they are hers from where they are.
		var v = p.victim
		track = {"seat": prey, "point": v.point, "eye": v.eye, "heading": v.heading, "velocity": v.velocity, "at": clock}
	seed_track = false

## The prey this tick: as seen, or reckoned from the track; null once lost
## (forget s without a sight or a noise of them).
func known(p):
	if prey < 0 or track.is_empty() or clock - float(track.at) > forget: return null
	var seen = p.bodies.get(prey)
	if seen != null and bool(seen.seen): return seen
	var ahead := minf(clock - float(track.at), PREDICT)
	var velocity: Vector3 = track.velocity
	var s = SENSES.Seen.new()
	s.seat = prey
	s.point = (track.point as Vector3) + velocity * ahead
	s.eye = (track.eye as Vector3) + velocity * ahead
	s.heading = track.heading
	s.view = track.heading
	s.velocity = velocity
	s.speed = Vector2(velocity.x, velocity.z).length()
	s.seen_at = float(track.at)
	s.fair = true
	if seen != null:
		s.fair = seen.fair
		s.lit = seen.lit
		s.alone = seen.alone
		s.straggle = seen.straggle
	var face: Vector3 = p.face
	s.distance = face.distance_to(s.eye)
	s.behind = SIGHT.behind_of(s.eye, s.heading, face)
	s.above = SIGHT.over_of(s.eye, s.heading, face)
	return s

## Where she knows `seat` to be (her track, or her memory); INF when not.
func known_point(seat: int, p) -> Vector3:
	if not track.is_empty() and int(track.seat) == seat:
		var ahead := minf(clock - float(track.at), PREDICT)
		return (track.point as Vector3) + (track.velocity as Vector3) * ahead
	var seen = p.bodies.get(seat)
	return seen.point if seen != null else Vector3.INF

func known_heading(seat: int, p) -> Vector3:
	if not track.is_empty() and int(track.seat) == seat: return track.heading
	var seen = p.bodies.get(seat)
	return seen.heading if seen != null else Vector3.FORWARD

## Lost: she searches where she last knew them, at once (never where they
## really are: no cheating).
func lose(_p) -> Dictionary:
	if not track.is_empty(): clue = {"point": track.point, "at": clock - noise_react}
	prey = -1
	track = {}
	goal = {}
	enter(State.ROAM)
	return pause()

# --- Choosing whom ---------------------------------------------------------------------------

func sorted_seats(p) -> Array:
	var seats: Array = p.bodies.keys()
	seats.sort()
	return seats

## Under the rest after her last take: only those who were near it (2.3).
func sated_on(seen) -> bool:
	return clock < sated_until and sated_point != Vector3.INF and (seen.point as Vector3).distance_to(sated_point) < SATED_NEAR

## Whom she may start on now, from what she perceives: never between
## encounters, never one she leaves be, never one in a protected room.
func candidates(p) -> Array:
	var out: Array = []
	if clock < quiet_until: return out
	for seat in sorted_seats(p):
		var seen = p.bodies[seat]
		if bool(seen.seen) and bool(seen.fair) and not bool(seen.hidden) and not bool(seen.protected) and float(spurned.get(int(seat), -INF)) <= clock and not sated_on(seen): out.append(int(seat))
	return out

## Alone, in the dark, behind the rest, busy (2.3).
func score(seen) -> float:
	return 0.35 * clampf(float(seen.alone) / 15.0, 0.0, 1.0) + 0.25 * (0.0 if bool(seen.lit) else 1.0) \
		+ 0.2 * clampf(float(seen.straggle) / 15.0, 0.0, 1.0) + 0.2 * (1.0 if bool(seen.busy) else 0.0)

## A tie is parted by her draws, never by the lowest seat (2.1).
const TIE := 0.001

func choose_prey(p) -> int:
	var best := -1
	var best_score := -INF
	for seat in candidates(p):
		var s := score(p.bodies[seat]) + rng.randf() * TIE
		if s > best_score:
			best_score = s
			best = int(seat)
	return best

# --- Her round and listening -------------------------------------------------------------

const LISTEN_TIME := Vector2(3.0, 6.0)
const LISTEN_P := 0.5
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
## Where her round is going: {point, room, since, noise, hidden}; {} picks again.
var goal := {}
var hold_until := 0.0
var listening := false

func searched_lately(room: int) -> bool:
	return float(searched.get(room, -INF)) > clock

## The director's zones: while she goes about on her own, or once a flight has
## lasted FLEE_LEADABLE (2.3). Its forced encounter ("encuentro") holds in any
## room, lit or with no ceiling of hers: she goes by the plenum.
func lead_to(point: Vector3, radius: float, seconds: float, kind: String, once := false, avoid := [], sniff := false) -> bool:
	if not (state in [State.ROAM, State.LISTEN] or (state == State.FLEE and state_time >= FLEE_LEADABLE)): return false
	var rooms: Array = world.lead_rooms(point, radius, avoid)
	if rooms.is_empty() and kind != "encuentro": return false
	lead = {"point": point, "radius": radius, "until": clock + seconds, "kind": kind, "rooms": rooms, "once": once, "sniff": sniff}
	goal = {}
	if state != State.ROAM:
		comeback = {}
		enter(State.ROAM)
	return true

## At the zone of a "cruce" lead: a show for the first fair seat she perceives.
func on_lead_reached(p = null) -> void:
	if String(lead.get("kind", "")) != "cruce" or p == null: return
	for seat in sorted_seats(p):
		var seen = p.bodies[seat]
		if bool(seen.seen) and bool(seen.fair) and not bool(seen.hidden):
			if start_show(int(seat), p): lead = {}
			return

## A noise to act on: after noise_react s (Pesadilla at once), while it lasts.
func noise_ready() -> bool:
	return not clue.is_empty() and clock - float(clue.at) >= noise_react and clock - float(clue.at) < CLUE_FOR

func noise_goal() -> Dictionary:
	return {"point": world.clue_point(clue.point), "room": -1, "since": clock, "noise": true}

func roam_tick(p) -> Dictionary:
	listening = false
	# The director's crossing comes before choosing: a show for whoever she
	# perceives (OFICINAS 4: the guaranteed encounter is a peek).
	if String(lead.get("kind", "")) == "cruce":
		for seat in candidates(p):
			if start_show(int(seat), p):
				lead = {}
				return hold()
	var chosen := choose_prey(p)
	if chosen >= 0:
		prey = chosen
		track = {}
		remember(p)
		begin_hunt(p, 1.0)
		return pause()
	if not lead.is_empty() and clock >= float(lead.until): lead = {}
	if bool(p.failed):
		goal = {}
		route_hidden = not route_hidden
	if goal.is_empty():
		pick_goal(p)
		if goal.is_empty(): return pause()
	elif noise_ready() and float(clue.at) > float(goal.get("since", -INF)):
		# A new noise: her goal now, whatever she was going to (2.2).
		goal = noise_goal()
	# Arrived where she was going (not on the tick she chose it).
	if bool(p.arrived) and float(goal.get("since", clock)) < clock:
		var here := int(goal.get("room", int(p.room)))
		if here >= 0: visited[here] = clock
		if bool(goal.get("noise", false)): clue = {}
		if not lead.is_empty():
			if String(lead.kind) == "cruce": on_lead_reached(p)
			elif bool(lead.once): lead = {}
		goal = {}
		if state == State.PEEK: return hold()
		if int(p.room) >= 0 and world.exit_of_room(int(p.room)) >= 0 and rng.randf() < LISTEN_P:
			enter(State.LISTEN)
			hold_until = clock + rng.randf_range(LISTEN_TIME.x, LISTEN_TIME.y)
			return hold()
		return pause()
	return go(goal.point, CRAWL_SPEED, Vector3.INF, bool(p.stretch_exposed) or route_hidden or bool(goal.get("hidden", false)))

## A noise, else the director's zone, else her own round (2.2).
func pick_goal(p) -> void:
	if noise_ready():
		goal = noise_goal()
		return
	if not lead.is_empty():
		if String(lead.kind) == "encuentro":
			goal = {"point": world.clue_point(lead.point), "room": -1, "since": clock, "hidden": true}
			return
		var room := -1
		var metres: Dictionary = world.travel_metres(int(p.room)) if int(p.room) >= 0 else {}
		var best := INF
		for r in lead.rooms:
			var stale: bool = clock - float(visited.get(int(r), -INF)) >= VISIT_STALE
			# In a duct (no room of hers) the nearest in a straight line.
			var m: float = float(metres.get(int(r), INF)) if not metres.is_empty() else (p.face as Vector3).distance_to(world.room_point(int(r)))
			if stale and m < best:
				best = m
				room = int(r)
		if room >= 0:
			goal = {"point": world.room_point(room), "room": room, "since": clock}
			return
		lead = {}
	if haunt != Vector3.INF and not resting() and rng.randf() < haunt_odds:
		var near := haunt + Vector3(rng.randf_range(-HAUNT_SPREAD, HAUNT_SPREAD), 0.0, rng.randf_range(-HAUNT_SPREAD, HAUNT_SPREAD))
		goal = {"point": world.clue_point(near), "room": -1, "since": clock, "hidden": true}
		return
	var patrol: int = world.patrol_room()
	if patrol >= 0: goal = {"point": world.room_point(patrol), "room": patrol, "since": clock}

func listen_tick(p) -> Dictionary:
	listening = true
	var chosen := choose_prey(p)
	if chosen >= 0:
		listening = false
		prey = chosen
		track = {}
		remember(p)
		begin_hunt(p, 1.0)
		return pause()
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

# --- Stalking, the show and the silence (2.2) -----------------------------------------------

const STALK_REPATH := 0.5
## m from her stalking spot that is there.
const ARRIVE_NEAR := 0.6
## The silence: what makes it now, and how far they may go before she
## follows again.
const OCCASION_STILL := 2.0
const OCCASION_ALONE := 6.0
const HUSH_SLACK := 4.0
## s of stalking at least, once back to it from closing in or a show.
const STALK_SHORT := 3.0
## When in her stalking she shows herself (a share of it).
const PEEK_AT := Vector2(0.3, 0.6)
var stalk_left := 0.0
var stalk_spent := 0.0
var peek_at := -1.0
var repath := 0.0
var last_go := Vector3.INF

## Stalking for a draw of stalk_time, shorter with more of them about (2.3),
## `share` of it; and whether she shows herself on the way.
func begin_stalk(share: float) -> void:
	stalk_left = rng.randf_range(stalk_time.x, stalk_time.y) * float(STALK_SCALE[team_index()]) * share
	stalk_spent = 0.0
	peek_at = stalk_left * rng.randf_range(PEEK_AT.x, PEEK_AT.y) if rng.randf() < peek_odds else -1.0
	last_go = Vector3.INF
	repath = 0.0
	enter(State.STALK)

func team_index() -> int: return clampi(team - 1, 0, 3)

## Still, busy, or alone in the dark with their back to her (2.2).
func occasion(seen) -> bool:
	if float(seen.distance) > stalk_distance + HUSH_SLACK: return false
	return float(seen.still_for) >= OCCASION_STILL or bool(seen.busy) or (float(seen.alone) >= OCCASION_ALONE and not bool(seen.lit) and bool(seen.behind))

func stalk_tick(p) -> Dictionary:
	var seen = known(p)
	if seen == null: return lose(p)
	var v = p.victim
	if v != null and bool(v.hidden) and bool(v.hide_known): return to_locker(v)
	# Another one more alone and in the dark: she changes her mind.
	for seat in candidates(p):
		if int(seat) != prey and score(p.bodies[seat]) > score(seen) + SWITCH_MARGIN:
			prey = int(seat)
			track = {}
			remember(p)
			return pause(p.bodies[seat].eye)
	stalk_spent += step
	stalk_left -= step
	if bool(seen.seen):
		if peek_at >= 0.0 and stalk_spent >= peek_at:
			peek_at = -1.0
			if start_show(prey, p): return hold()
		if occasion(seen) or (stalk_left <= 0.0 and float(seen.distance) <= stalk_distance + HUSH_SLACK):
			enter(State.HUSH)
			return pause(seen.eye)
	repath -= step
	if repath <= 0.0 or last_go == Vector3.INF or bool(p.failed):
		repath = STALK_REPATH
		if bool(p.failed): route_hidden = not route_hidden
		last_go = world.stalk_point(seen, stalk_distance)
	var face: Vector3 = p.face
	if Vector2(last_go.x - face.x, last_go.z - face.z).length() <= ARRIVE_NEAR: return pause(seen.eye)
	return go(last_go, CRAWL_SPEED, seen.eye, bool(p.stretch_exposed) or route_hidden)

## The sudden silence where she sounded: still, and quiet (spec 4), then she
## comes on.
func hush_tick(p) -> Dictionary:
	var seen = known(p)
	if seen == null: return lose(p)
	if float(seen.distance) > stalk_distance + HUSH_SLACK:
		stalk_left = maxf(stalk_left, STALK_SHORT)
		enter(State.STALK)
		return pause(seen.eye)
	# The silence is for one who stays put; after one walking away she closes in
	# at once (held here, she let them go from three metres off).
	if state_time >= hush_time or float(seen.still_for) <= 0.0: enter(State.CREEP)
	return pause(seen.eye)

## A show at the edge of somebody's view (OFICINAS 4: "se asoma").
const SHOW_WAIT := 10.0
const PEEK_TIME := 4.0
## Looked at this long in a peek she bolts (lit, gone within 0.4 s).
const PEEK_SEEN := 0.1
## PEEK: {kind, point, seat, arrived}.
var show := {}

func start_show(seat: int, p) -> bool:
	var seen = p.bodies.get(seat)
	if seen == null: return false
	var spot: Dictionary = world.show_spot(seen, "peek")
	if spot.is_empty(): return false
	show = {"kind": "peek", "point": spot.point, "seat": seat, "arrived": false}
	if prey != seat:
		prey = seat
		track = {}
		remember(p)
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
			if prey >= 0:
				stalk_left = maxf(stalk_left, STALK_SHORT)
				enter(State.STALK)
			else: enter(State.ROAM)
			return pause(look)
		else: return go(show.point, CRAWL_SPEED, look, bool(p.stretch_exposed))
	# Looked at: she goes all at once, and comes back for them later.
	if regard_time >= PEEK_SEEN:
		if prey >= 0 and comeback.is_empty(): comeback = {"seat": prey, "at": clock + rng.randf_range(emerge_delay.x, emerge_delay.y)}
		flee_from(p, int(p.regarded_by[0]) if not p.regarded_by.is_empty() else -1)
		return hold(look)
	if clock >= hold_until:
		# Unseen to the end: on Desafiante and Pesadilla she comes straight on.
		if prey >= 0 and emerge_mode == "behind": enter(State.HUSH)
		elif prey >= 0:
			stalk_left = maxf(stalk_left, STALK_SHORT)
			enter(State.STALK)
		else: enter(State.ROAM)
		return pause(look)
	return hold(look, "peek")

# --- The silent ambush (iteration 3, H2) ------------------------------------------------

## Now and then, instead of following a prey on the move, she goes hidden by
## the plenum to a ceiling ahead of them, comes out and waits there, still
## and silent; the warning straight from it as they pass under or beyond her,
## nothing of her heard before. Back to stalking if they do not come in
## AMBUSH_WAIT s, go AMBUSH_LEAVE m off or hide; a failed ambush is no attempt.
const AMBUSH_WAIT := 12.0
const AMBUSH_LEAVE := 16.0
## s to get to her spot, and the clock she got there at.
const AMBUSH_REACH := 10.0
var ambush_since := -1.0
## m/s: a prey this fast is on the move, worth waiting for ahead.
const AMBUSH_MOVING := 1.0
var ambush_odds := 0.3
## Where she waits (INF: where she is, for force()), and the share of
## stalking she would have had.
var ambush_point := Vector3.INF
var ambush_share := 1.0

## Stalking for `share`, or now and then an ambush ahead of a prey on the move.
func begin_hunt(p, share: float) -> void:
	var seen = known(p)
	if seen != null and float(seen.speed) >= AMBUSH_MOVING and rng.randf() < ambush_odds:
		var at: Vector3 = world.ambush_point(seen)
		if at != Vector3.INF:
			ambush_point = at
			ambush_share = share
			ambush_since = -1.0
			enter(State.AMBUSH)
			return
	begin_stalk(share)

func ambush_tick(p) -> Dictionary:
	var seen = known(p)
	if seen == null: return lose(p)
	var v = p.victim
	if cue_ready(p):
		var entry: Dictionary = warning.start(prey, clock, window, float(v.latency), p.face, bool(v.above))
		enter(State.CUE)
		cue_started.emit(entry)
		return hold(v.eye)
	# They go another way (measured from where she waits, not from her: she may
	# start further off than that), or hide.
	var gone: bool = ambush_point != Vector3.INF and (seen.point as Vector3).distance_to(ambush_point) > AMBUSH_LEAVE
	if gone or (v != null and (bool(v.hidden) or not bool(v.fair))):
		begin_stalk(ambush_share)
		return pause(seen.eye)
	var face: Vector3 = p.face
	# There is out on the ceiling: still inside it she could never warn.
	# (Put there by a tool, with no spot: she waits where she is.)
	var there: bool = ambush_point == Vector3.INF or (not bool(p.in_duct) and Vector2(ambush_point.x - face.x, ambush_point.z - face.z).length() <= ARRIVE_NEAR)
	if not there:
		if bool(p.failed) or state_time > AMBUSH_REACH:
			begin_stalk(ambush_share)
			return pause(seen.eye)
		return go(ambush_point, CRAWL_SPEED, Vector3.INF, true)
	if ambush_since < 0.0: ambush_since = clock
	if clock - ambush_since > AMBUSH_WAIT:
		begin_stalk(ambush_share)
		return pause(seen.eye)
	return hold(seen.eye)

# --- Closing in and the warning ------------------------------------------------------------

## Everything a warning needs to begin, on this tick's truth.
func cue_ready(p) -> bool:
	var v = p.victim
	return state in [State.CREEP, State.AMBUSH] and v != null and int(v.seat) == prey and bool(v.seen) and bool(v.fair) and not bool(v.hidden) \
		and not bool(p.in_duct) and not bool(p.off_limits) and float(v.distance) >= CUE_RANGE.x and float(v.distance) <= CUE_RANGE.y \
		and bool(v.behind) and p.regarded_by.is_empty() and p.torch_by.is_empty() and (lit_takes or not bool(v.lit)) \
		and warning.can_start(clock) and not sated_on(v) and float(spurned.get(prey, -INF)) <= clock

func creep_tick(p) -> Dictionary:
	var v = p.victim
	var seen = known(p)
	if seen == null or v == null or int(v.seat) != prey: return lose(p)
	if cue_ready(p):
		var entry: Dictionary = warning.start(prey, clock, window, float(v.latency), p.face, bool(v.above))
		enter(State.CUE)
		cue_started.emit(entry)
		return hold(v.eye)
	if bool(v.hidden) and bool(v.hide_known): return to_locker(v)
	if not bool(v.fair) or bool(v.hidden):
		stalk_left = maxf(stalk_left, STALK_SHORT)
		enter(State.STALK)
		return pause()
	# A turn of their head does not undo her: she goes round to their back again.
	creep_lost = 0.0 if bool(v.behind) else creep_lost + step
	if creep_lost >= CREEP_LOSE:
		stalk_left = maxf(stalk_left, STALK_SHORT)
		enter(State.STALK)
		return pause(seen.eye)
	if bool(p.failed): route_hidden = not route_hidden
	var pace := clampf(float(seen.speed) + CREEP_LEAD, CREEP_SPEED * creep_scale, approach_cap)
	return go(world.behind_point(seen, CUE_DIST), pace, seen.eye, bool(p.stretch_exposed) or route_hidden)

## The warning runs: checked first, on the truth, every tick.
func cue_tick(p) -> Dictionary:
	var v = p.victim
	var verdict: StringName = warning.check(clock, v, p, lit_takes)
	var entry: Dictionary = warning.ledger[warning.ledger.size() - 1] if not warning.ledger.is_empty() else {}
	match verdict:
		&"saved":
			cue_ended.emit(entry)
			recoil(int(entry.by), String(entry.reason), p, true)
			return recoil_tick(p)
		&"aborted":
			cue_ended.emit(entry)
			if String(entry.reason) == "escondida" and v != null and bool(v.hide_known): return to_locker(v)
			stalk_left = maxf(stalk_left, STALK_SHORT)
			enter(State.STALK)
			return hold()
		&"expired":
			cue_ended.emit(entry)
			stalk_left = maxf(stalk_left, STALK_SHORT)
			enter(State.STALK)
			return hold()
		&"due":
			warning.take(clock)
			var seat := prey
			took_point = v.point
			enter(State.TAKE)
			take_sent = true
			took.emit(seat)
			return intent(&"take", {"seat": seat, "leap": float(v.distance) > WARNING.TAKE_REACH, "look": v.eye})
	# Still running: she keeps behind them, at their walking pace at most.
	if float(v.distance) > CUE_RANGE.y:
		return go(world.behind_point(v, CUE_DIST), CUE_FOLLOW, v.eye)
	return hold(v.eye, "loom" if bool(p.on_channel) else "idle")

func take_tick(_p) -> Dictionary:
	if state_time >= TAKE_EMPTY: end_take()
	return hold()

## A take ends the encounter: those near it are left be for `sated`, and
## nobody new is started on for a while (2.3).
func end_take() -> void:
	sated_until = clock + sated
	sated_point = took_point
	if prey >= 0: attempts.erase(prey)
	end_encounter()
	away_from = Vector3.ZERO
	prey = -1
	track = {}
	hidden_since = -1.0
	flee_retreat = false
	enter(State.FLEE)

func end_encounter() -> void:
	quiet_until = maxf(quiet_until, clock + QUIET_BASE * float(PAUSE_SCALE[team_index()]))

## The light came on in the room she is in (OFICINAS 3: the light herds her):
## she leaves by the ducts for the dark, with no fright and no shriek.
func on_room_lit(face: Vector3) -> void:
	if not state in [State.ROAM, State.STALK, State.HUSH, State.CREEP, State.AMBUSH]: return
	away_from = face
	hidden_since = -1.0
	flee_retreat = false
	enter(State.FLEE)

## The fans stopped (planta 3): back in by the nearest grille at once, before
## the survivors are through (OFICINAS 3: "es una carrera por entrar antes").
func on_ducts_open(exit_point: Vector3) -> void:
	if not state in [State.ROAM, State.LISTEN]: return
	clue = {"point": exit_point, "at": clock - noise_react}
	goal = {}

## A noise she heard: a clue; and near where she reckons her prey, news of
## them (2.1: "su último vistazo o ruido").
func on_heard(_route: Dictionary, point: Vector3) -> void:
	clue = {"point": point, "at": clock}
	haunt = point
	if prey < 0 or track.is_empty() or clock - float(track.at) > forget: return
	var ahead := minf(clock - float(track.at), PREDICT)
	var reckoned: Vector3 = (track.point as Vector3) + (track.velocity as Vector3) * ahead
	if Vector2(point.x - reckoned.x, point.z - reckoned.z).length() > NOISE_TRACK: return
	track["eye"] = (track.eye as Vector3) + (point - (track.point as Vector3))
	track["point"] = point
	track["at"] = clock

func on_captured(execution: Dictionary) -> void:
	if execution.has("cue"): warning.captured(int(execution.cue))

func on_released() -> void:
	if state == State.TAKE: end_take()

# --- Frightened, the flight and coming back (2.2) ---------------------------------------------

func flee_from(p, seat: int) -> void:
	away_from = p.face
	for seen in p.bodies.values():
		if int(seen.seat) == seat: away_from = seen.eye
	hidden_since = -1.0
	flee_retreat = false
	emerging = Vector3.INF
	enter(State.FLEE)

## `counts`: she was after them (2.3), so it is a failed attempt.
func recoil(by: int, cause: String, p, counts: bool) -> void:
	if counts: failed_attempt(prey)
	away_from = p.face
	for seen in p.bodies.values():
		if int(seen.seat) == by: away_from = seen.eye
	haunt = away_from
	torches = Array(p.torch_by) if cause == "linterna" else []
	enter(State.RECOIL)
	screamed = false
	torch_time = 0.0
	scared.emit(cause, by)

## Her shriek and her scare clip go on the bolt itself, not before it (the
## author: lit, she is gone in 0.4 s): no stand looking first.
func recoil_tick(p) -> Dictionary:
	if not screamed:
		screamed = true
		world.scream(p.face)
	hidden_since = -1.0
	flee_retreat = false
	emerging = Vector3.INF
	enter(State.FLEE)
	return intent(&"bolt", {"from": away_from, "clip": "scare"})

## An attempt on `seat` failed: after `tries` she leaves them be for
## rest_after and starts nobody for a while; until then she comes back out of
## the ceiling for another, emerge_delay later. Each seat keeps its own count.
func failed_attempt(seat: int) -> void:
	if seat < 0: return
	attempts[seat] = int(attempts.get(seat, 0)) + 1
	if int(attempts[seat]) >= tries:
		attempts.erase(seat)
		spurned[seat] = clock + rest_after
		comeback = {}
		end_encounter()
		return
	# Each failure brings the next attempt sooner (iteration 2, G3).
	var sooner: float = ESCALATE[mini(int(attempts[seat]) - 1, ESCALATE.size() - 1)]
	comeback = {"seat": seat, "at": clock + rng.randf_range(emerge_delay.x, emerge_delay.y) * sooner}

## emerge_delay's share for the next attempt, by failures so far (G3).
const ESCALATE := [1.0, 0.7, 0.5, 0.4]

func flee_tick(p) -> Dictionary:
	if bool(p.in_duct):
		if hidden_since < 0.0: hidden_since = clock
		if not comeback.is_empty():
			emerging = Vector3.INF
			enter(State.RETURN)
			return hold()
		if clock - hidden_since >= FLEE_HIDE: enter(State.ROAM)
		return hold()
	if state_time >= FLEE_OUT:
		# Taken to be inside: lurker.gd puts her in the nearest duct where
		# nobody sees it, and she goes on from there.
		emerging = Vector3.INF
		if not comeback.is_empty(): enter(State.RETURN)
		else: enter(State.ROAM)
		return intent(&"vanish")
	# Into the ceiling at a bolt by the nearest way in away from the light
	# (lurker_motion.bolt()); with none near enough, lurker.gd takes her in.
	return intent(&"bolt", {"from": away_from, "clip": "crawl_fast"})

## Coming back: in the ceiling emerge_delay, then out where she knows her
## prey to be now (or the one most on their own near them), and stalking them
## again, shorter.
const RETURN_STALK := 0.4
const RETURN_NEAR := 12.0
const RETURN_MOST := 20.0

func return_tick(p) -> Dictionary:
	if emerging == Vector3.INF:
		if comeback.is_empty():
			enter(State.ROAM)
			return hold()
		if clock < float(comeback.at): return hold()
		var seat := return_target(p)
		var at := known_point(seat, p)
		var heading := known_heading(seat, p)
		comeback = {}
		var out: Vector3 = world.emerge_point(seat, emerge_mode, emerge_range, at, heading) if at != Vector3.INF else Vector3.INF
		if out == Vector3.INF:
			enter(State.ROAM)
			return hold()
		if seat != prey:
			prey = seat
			track = {}
			remember(p)
		emerging = out
		state_time = 0.0
		return go(emerging, FLEE_SPEED, Vector3.INF, true, "crawl_fast")
	if bool(p.failed) or state_time > RETURN_MOST:
		emerging = Vector3.INF
		enter(State.ROAM)
		return pause()
	if bool(p.arrived) and not bool(p.in_duct) and state_time > 0.5:
		emerging = Vector3.INF
		begin_hunt(p, RETURN_STALK)
		return pause()
	return go(emerging, FLEE_SPEED, Vector3.INF, true, "crawl_fast")

## The seat she comes back for: of those she knows of within RETURN_NEAR of
## the one who got away, the one most on their own (2.3: "va a por el que se
## queda atrás").
func return_target(p) -> int:
	var failed := int(comeback.get("seat", -1))
	var base := known_point(failed, p)
	if base == Vector3.INF: return failed
	var best := failed
	var first = p.bodies.get(failed)
	var best_alone: float = minf(float(first.alone), 30.0) if first != null else -INF
	for seat in sorted_seats(p):
		var seen = p.bodies[seat]
		if int(seat) == failed or not bool(seen.fair) or bool(seen.hidden) or bool(seen.protected) or float(spurned.get(int(seat), -INF)) > clock: continue
		if (seen.point as Vector3).distance_to(base) > RETURN_NEAR: continue
		var alone := minf(float(seen.alone), 30.0) + rng.randf() * TIE
		if alone > best_alone:
			best_alone = alone
			best = int(seat)
	return best

# --- Above a locker, and the freeze the tools may ask for ------------------------------------

const WAIT_ABOVE_TIME := Vector2(20.0, 40.0)
var locker: Node3D = null

func to_locker(v) -> Dictionary:
	locker = v.hide
	hold_until = clock + rng.randf_range(WAIT_ABOVE_TIME.x, WAIT_ABOVE_TIME.y)
	enter(State.WAIT_ABOVE)
	return hold()

func wait_above_tick(p) -> Dictionary:
	var v = p.victim
	if v != null and not bool(v.hidden) and bool(v.fair):
		enter(State.CREEP)
		return pause(v.eye)
	if clock >= hold_until or not is_instance_valid(locker):
		if int(p.room) >= 0: searched[int(p.room)] = clock + SEARCHED_FOR
		locker = null
		prey = -1
		track = {}
		enter(State.ROAM)
		return hold()
	var over: Vector3 = world.above_locker(locker)
	if (p.face as Vector3).distance_to(over) > ARRIVE_NEAR: return go(over, CRAWL_SPEED, Vector3.INF, bool(p.stretch_exposed))
	return hold(locker.global_position, "idle")

func freeze_tick(p) -> Dictionary:
	var look: Vector3 = Vector3.INF
	if not p.regarded_by.is_empty():
		for seen in p.bodies.values():
			if int(seen.seat) == int(p.regarded_by[0]): look = seen.eye
	if unregard_time >= UNFREEZE:
		enter(resume)
		return hold(look)
	if state_time >= FREEZE_TIME:
		# Looked at too long: she backs off, slowly, into the dark.
		return go(world.dark_retreat(look if look != Vector3.INF else p.face), RETREAT_SPEED, look, false, "retreat")
	return hold(look, "idle")
