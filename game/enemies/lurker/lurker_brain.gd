extends RefCounted
## The Lurker's mind (docs/OFICINAS.md 4; spec_f2_mind 7), on the machine that
## drives her. It never touches the scene: it reads a Percept (lurker_senses.gd),
## asks a world port (lurker.gd, or a test's fake) for what it knows of the
## map, and returns an intent, which lurker.gd turns into her motion. It draws
## only from the rng it is given. Above all of it is the warning
## (lurker_warning.gd): the only way to a take.
##
## This step (2b-1) has the states of the warning (closing in, the cue, the
## take, the recoil and the flight) and being frozen by a look; the round,
## listening, stalking, the shows and waiting above a locker hold still until
## 2b-2 fills them.
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
	if data.has("seat"): prey = int(data.seat)
	enter(State[wanted])

## Everything of the moment forgotten (a teleport, a stage given back): the
## warning in hand given up.
func forget_all(_rest: float) -> void:
	warning.cancel(clock, "movida")
	prey = -1
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
			enter(State.WAIT_ABOVE if String(entry.reason) == "escondida" and v != null and bool(v.hide_known) else State.STALK)
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
