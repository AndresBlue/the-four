extends RefCounted
## The guarantee, in code (docs/OFICINAS.md 1 and 11.5): The Lurker never
## takes anybody she has not warned, and never before the warning has run its
## window. One per Lurker, on the machine in charge, whoever drives her (the
## brain, or phase 4's hunter): start() begins a warning behind a survivor,
## check() is asked every tick while it runs with that tick's truth, and the
## take happens only on the tick check() says it is due. Every warning goes
## into the ledger with what came of it, and audit() says whether a ledger is
## fair. spec_f2_mind 6, with the author's decision of 24 October 2026:
## leaving during the window saves only running, not walking (she keeps up
## with a walker and takes them, with her long leap if need be).

## s after the due time the take may still happen.
const TAKE_HOLD := 0.6
## m from her face to the victim's eye: no take from farther...
const TAKE_REACH := 3.4
## ...unless they did not run: then her long leap (lurker_motion.gd
## LEAP_REACH) closes the rest.
const TAKE_REACH_WALKED := TAKE_REACH + 4.0
## m/s: faster than this during the window is running (survivor_gait.gd
## walks at 3.8 and runs at 6.0).
const RUNNING := 5.0
## s: the most of a victim's latency added to their window.
const LATENCY_CAP := 0.5
## remote_player.DELAY: a puppet's view is this late.
const REMOTE_VIEW := 0.1
const EPS := 0.000001
const CUE_SOUNDS := ["res://assets/audio/sfx/lurker/cue_0.wav", "res://assets/audio/sfx/lurker/cue_1.wav", "res://assets/audio/sfx/lurker/cue_2.wav"]
## The same, shorter (about 0.8 s), for less time than LONG_CUE until the take
## (Pesadilla's window): a warning is always heard whole before it.
const CUE_SOUNDS_SHORT := ["res://assets/audio/sfx/lurker/cue_short_0.wav", "res://assets/audio/sfx/lurker/cue_short_1.wav", "res://assets/audio/sfx/lurker/cue_short_2.wav"]
const LONG_CUE := 1.2
static func cue_sounds(hold: float) -> Array: return CUE_SOUNDS if hold >= LONG_CUE else CUE_SOUNDS_SHORT
const CUE_CAPTION := "[Algo respira a tu espalda]"
const CUE_CAPTION_NEAR := "[Algo respira cerca]"
## The cue from above, in a tall room (the author, 24 October 2026).
const CUE_CAPTION_ABOVE := "[Algo respira sobre ti]"

## Every warning of the floor: {id, seat, at, window, latency, due, point:
## [x, y, z], above, outcome: "active"|"taken"|"saved"|"aborted"|"expired",
## end, by (saver seat, -1), reason, take_at (-1), ran, captured, forced (a
## tool's capture, no warning, skipped by audit()), heard_after (-1; phase 4:
## the victim's machine said it played it this many s after `at`)}.
## Reasons: "mirada", "linterna", "corriendo" (saves); "protegida",
## "escondida", "fuera", "con luz", "movida" (aborts); "lejos" (expired);
## "forzada" (a tool's capture).
var ledger: Array = []
## The ledger entry in hand, or {}.
var active := {}
var next_id := 1
## seat -> s, set by tests only; wins over the net (phase 4).
var latency_for := {}

func can_start(_clock: float) -> bool:
	return active.is_empty()

## Begins a warning behind `seat` now (from above it when `above`); the entry,
## also kept in `active`.
func start(seat: int, clock: float, window: float, latency: float, point: Vector3, above := false) -> Dictionary:
	var given := clampf(float(latency_for.get(seat, latency)), 0.0, LATENCY_CAP)
	var entry := {"id": next_id, "seat": seat, "at": clock, "window": window, "latency": given, "due": clock + window + given,
		"point": [point.x, point.y, point.z], "above": above, "outcome": "active", "end": -1.0, "by": -1, "reason": "",
		"take_at": -1.0, "ran": false, "captured": false, "forced": false, "heard_after": -1.0}
	next_id += 1
	ledger.append(entry)
	active = entry
	return entry

## Every tick while a warning runs, before anything else the brain does, with
## that tick's truth: `v` the victim's (null when the seat has no body any
## more), `p` the percept (its regarded_by, torch_by and off_limits). &""
## (go on), &"saved", &"aborted", &"due" (take now) or &"expired"; the entry
## is closed for every verdict but &"" and &"due". A save on the last tick
## wins over the take.
func check(clock: float, v, p, lit_takes: bool) -> StringName:
	if active.is_empty(): return &""
	if v == null: return close(clock, "aborted", -1, "fuera")
	if not bool(v.fair): return close(clock, "aborted", -1, "protegida" if bool(v.protected) else "fuera")
	if bool(v.hidden): return close(clock, "aborted", -1, "escondida")
	if bool(v.lit) and not lit_takes: return close(clock, "aborted", -1, "con luz")
	if bool(p.off_limits): return close(clock, "aborted", -1, "protegida")
	var torch_by: Array = p.torch_by
	var regarded_by: Array = p.regarded_by
	if bool(v.regards): return close(clock, "saved", int(v.seat), "linterna" if torch_by.has(int(v.seat)) else "mirada")
	if not torch_by.is_empty(): return close(clock, "saved", int(torch_by[0]), "linterna")
	if not regarded_by.is_empty(): return close(clock, "saved", int(regarded_by[0]), "mirada")
	if float(v.speed) >= RUNNING: active["ran"] = true
	var due := float(active.due)
	if clock >= due - EPS:
		var distance := float(v.distance)
		var ran := bool(active.ran)
		if distance <= TAKE_REACH or (not ran and distance <= TAKE_REACH_WALKED): return &"due"
		if ran: return close(clock, "saved", int(v.seat), "corriendo")
	if clock > due + TAKE_HOLD + EPS: return close(clock, "expired", -1, "lejos")
	return &""

func close(clock: float, outcome: String, by: int, reason: String) -> StringName:
	active["outcome"] = outcome
	active["end"] = clock
	active["by"] = by
	active["reason"] = reason
	active = {}
	return StringName(outcome)

## The take, on the tick check() said &"due": the entry "taken" at `clock`.
func take(clock: float) -> bool:
	if active.is_empty(): return false
	var due := float(active.due)
	if clock < due - EPS or clock > due + TAKE_HOLD + EPS: return false
	active["outcome"] = "taken"
	active["take_at"] = clock
	active["end"] = clock
	active = {}
	return true

## The gate (creature.may_capture): only the seat taken on this very tick.
func may_capture(seat: int, clock: float) -> bool:
	for i in range(ledger.size() - 1, -1, -1):
		var entry: Dictionary = ledger[i]
		if int(entry.seat) != seat: continue
		return String(entry.outcome) == "taken" and absf(float(entry.take_at) - clock) <= EPS
	return false

## A tool's capture (executions.forced not empty): logged, never a warning.
func forced_take(seat: int, clock: float) -> void:
	if not active.is_empty(): cancel(clock, "movida")
	ledger.append({"id": next_id, "seat": seat, "at": clock, "window": 0.0, "latency": 0.0, "due": clock, "point": [0.0, 0.0, 0.0], "above": false,
		"outcome": "taken", "end": clock, "by": -1, "reason": "forzada", "take_at": clock, "ran": false, "captured": false, "forced": true, "heard_after": -1.0})
	next_id += 1

## begin_capture() with the execution's cue.
func captured(cue_id: int) -> void:
	for entry in ledger:
		if int(entry.id) == cue_id: entry["captured"] = true

## Phase 4: the victim's machine played it this long after it started.
func heard(cue_id: int, after: float) -> void:
	for entry in ledger:
		if int(entry.id) == cue_id: entry["heard_after"] = after

## The warning in hand given up (a teleport, a relocation, a stage change).
func cancel(clock: float, reason: String) -> void:
	if not active.is_empty(): close(clock, "aborted", -1, reason)

## Everything wrong with a ledger ([] when fair): a take outside its window,
## a due time that is not the start, the window and the latency, a latency
## out of bounds, a capture without a take, two warnings at once, one still
## running that is not the last, ids out of order. Tools' captures skipped.
static func audit(log: Array) -> Array[String]:
	var wrong: Array[String] = []
	var last_id := 0
	var last_end := -INF
	for i in log.size():
		var e: Dictionary = log[i]
		if int(e.id) <= last_id: wrong.append("%d: ids fuera de orden" % int(e.id))
		last_id = int(e.id)
		if bool(e.get("forced", false)): continue
		var at := float(e.at)
		var due := float(e.due)
		if absf(due - (at + float(e.window) + float(e.latency))) > EPS: wrong.append("%d: el plazo no es la ventana más la latencia" % int(e.id))
		if float(e.latency) < -EPS or float(e.latency) > LATENCY_CAP + EPS: wrong.append("%d: latencia fuera de límites" % int(e.id))
		if String(e.outcome) == "taken":
			var take_at := float(e.take_at)
			if take_at < due - EPS or take_at > due + TAKE_HOLD + EPS: wrong.append("%d: cogida fuera de su ventana" % int(e.id))
		elif bool(e.get("captured", false)): wrong.append("%d: captura sin cogida" % int(e.id))
		if String(e.outcome) == "active" and i != log.size() - 1: wrong.append("%d: sigue activo y no es el último" % int(e.id))
		if at < last_end - EPS: wrong.append("%d: se solapa con el anterior" % int(e.id))
		var end := float(e.end)
		last_end = end if end >= 0.0 else INF
	return wrong
