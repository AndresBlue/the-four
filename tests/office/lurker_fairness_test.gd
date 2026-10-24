extends SceneTree
## The Lurker's guarantee (docs/OFICINAS.md 1 and 11.5; spec_f2_mind 10.2):
## she never takes anybody she has not warned behind them, never before the
## warning has run its window, and a look in the light, a torch on her face
## (theirs or a teammate's) or running away saves. Part B: 200 seeded
## approaches on a straight corridor with no scene, her brain against the
## harness's own truth and an oracle that does not read the brain; walking
## away does not save (the author, 24 October 2026), running does. Part A,
## in the world, comes with 2b-2.
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")
const SENSES := preload("res://game/enemies/lurker/lurker_senses.gd")
const DIFFICULTY := preload("res://game/floors/difficulty.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const DT := 1.0 / 60.0
const EPS := WARNING.EPS
## The least of each outcome the 200 must cover (the first run gave 91, 47,
## 25, 0 and 37). None expires: she keeps up with a walker on a straight
## corridor, so "lejos" is checked on the warning itself (rules()).
const COVERAGE := {"taken": 40, "saved": 25, "aborted": 10, "expired": 0, "none": 15}
const LAST_MOMENT := 10
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

## The world port, on a line: she is behind them along -x.
class FakeWorld extends RefCounted:
	var screams := 0
	func behind_point(seen, metres: float) -> Vector3: return Vector3(seen.point.x - metres, 0, 0)
	func flee_exit(_away: Vector3) -> int: return 0
	func dark_retreat(_away: Vector3) -> Vector3: return Vector3(-20, 0, 0)
	func scream(_point: Vector3) -> void: screams += 1

func run() -> void:
	var results: Array = []
	var counts := {"taken": 0, "saved": 0, "aborted": 0, "expired": 0, "none": 0}
	var by_id := {}
	var wrong: Array = []
	var unpaired: Array = []
	var early: Array = []
	var bad_start: Array = []
	var audits: Array = []
	var prop_a: Array = []
	var prop_b: Array = []
	var last_moment := 0
	for i in 200:
		var r := approach(i)
		results.append(r.evidence)
		var outcome: String = r.outcome
		counts[outcome] = int(counts[outcome]) + 1
		var id: String = r.evidence.id
		if not by_id.has(id): by_id[id] = {"taken": 0, "saved": 0, "aborted": 0, "expired": 0, "none": 0}
		by_id[id][outcome] = int(by_id[id][outcome]) + 1
		if outcome != r.oracle.outcome or absf(float(r.end) - float(r.oracle.end)) > EPS: wrong.append([i, outcome, r.oracle.outcome, r.end, r.oracle.end])
		if r.takes.size() != (1 if outcome == "taken" else 0): unpaired.append(i)
		for t in r.takes:
			if absf(float(t) - float(r.end)) > EPS: unpaired.append(i)
		if outcome == "taken" and float(r.end) - float(r.at) < float(r.window) + minf(float(r.latency), WARNING.LATENCY_CAP) - EPS: early.append(i)
		if bool(r.bad_start): bad_start.append(i)
		if not WARNING.audit(r.ledger).is_empty(): audits.append([i, WARNING.audit(r.ledger)])
		if outcome == "taken" and bool(r.saved_before_take): prop_a.append(i)
		if bool(r.save_before_due) and outcome != "saved": prop_b.append([i, outcome])
		if bool(r.last_moment_save) and outcome == "saved": last_moment += 1
	check("Las 200 acaban como dice el oráculo, en el mismo instante", wrong.is_empty(), str(wrong.slice(0, 5)))
	check("Cada captura va con su aviso, y no hay captura sin él", unpaired.is_empty(), str(unpaired.slice(0, 5)))
	check("Ninguna captura antes de su ventana más la latencia", early.is_empty(), str(early.slice(0, 5)))
	check("Ningún aviso empieza mirada o con la víctima protegida", bad_start.is_empty(), str(bad_start.slice(0, 5)))
	check("El registro de cada una pasa la auditoría", audits.is_empty(), str(audits.slice(0, 3)))
	check("Ninguna captura tuvo antes un momento que la salvaba", prop_a.is_empty(), str(prop_a.slice(0, 5)))
	check("Toda la que tuvo un momento que la salvaba antes del plazo se salvó (%d en la última décima)" % last_moment, prop_b.is_empty() and last_moment >= LAST_MOMENT, str(prop_b.slice(0, 5)))
	var short := []
	for key in COVERAGE:
		if int(counts[key]) < int(COVERAGE[key]): short.append("%s %d" % [key, int(counts[key])])
	check("Cubre cogidas, salvadas, abortadas, caducadas y sin aviso: %s" % str(counts), short.is_empty(), ", ".join(short))
	rules()
	var file := FileAccess.open("res://evidence/lurker_fairness_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks, "counts": counts, "by_difficulty": by_id, "last_moment": last_moment, "approaches": results}, "\t"))
	print("LURKER_FAIRNESS_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)

## The warning's own rules, straight: walking off out of reach does not save
## and the warning runs out ("lejos"); running off out of reach saves
## ("corriendo"); walking off within the leap's reach is taken.
func rules() -> void:
	var cases := [[8.0, 3.8, "expired", "lejos"], [4.0, 6.0, "saved", "corriendo"], [6.0, 3.8, "taken", ""]]
	var bad: Array = []
	for c in cases:
		var w = WARNING.new()
		w.start(1, 0.0, 1.5, 0.0, Vector3.ZERO)
		var p = SENSES.Percept.new()
		var v = SENSES.Seen.new()
		v.seat = 1
		v.fair = true
		v.distance = float(c[0])
		v.speed = float(c[1])
		var verdict := &""
		var t := 0.0
		while verdict == &"" and t < 5.0:
			t += DT
			verdict = w.check(t, v, p, true)
		if verdict == &"due": w.take(t)
		var entry: Dictionary = w.ledger[0]
		if String(entry.outcome) != String(c[2]) or String(entry.reason) != String(c[3]): bad.append([c, entry.outcome, entry.reason])
	check("Alejarse andando no salva y el aviso caduca lejos; corriendo, salva; andando al alcance del salto, coge", bad.is_empty(), str(bad))

## One approach: the draws, her brain run against the harness's truth, and
## the oracle's verdict on the same truth.
func approach(i: int) -> Dictionary:
	var id: String = DIFFICULTY.ORDER[i % 4]
	var profile := DIFFICULTY.profile(id, &"lurker")
	var W := float(profile.back_window)
	var lit_takes := bool(profile.lit_takes)
	var r := RandomNumberGenerator.new()
	r.seed = 7000 + i
	var gap := r.randf_range(4.0, 9.0)
	var lit := r.randf() < 0.3
	var torch := r.randf() < 0.4
	var remote := r.randf() < 0.5
	var latency := r.randf_range(0.0, 0.6) if remote else 0.0
	var facing_her := r.randf() < 0.08
	var turn_at := r.randf_range(0.0, W + latency + 0.8) if r.randf() < 0.45 else INF
	var mate_at := r.randf_range(0.0, W + latency + 0.3) if r.randf() < 0.15 else INF
	var walk_at := r.randf_range(0.0, W) if r.randf() < 0.2 else INF
	var protect_at := r.randf_range(0.0, W) if r.randf() < 0.08 else INF
	var hide_at := r.randf_range(0.0, W) if r.randf() < 0.04 else INF
	var protected_from_start := r.randf() < 0.04
	var gone_at := r.randf_range(0.0, W) if r.randf() < 0.03 else INF
	# Last, so the draws above stay as the spec has them: running away, and a
	# turn that brings the first save into the last tenth before the due time.
	var run_at := r.randf_range(0.0, W) if r.randf() < 0.12 else INF
	if r.randf() < 0.3: turn_at = W + minf(latency, WARNING.LATENCY_CAP) - 0.25 - r.randf_range(0.0, 0.08)
	var draws := {"gap": gap, "lit": lit, "torch": torch, "remote": remote, "latency": latency, "facing_her": facing_her, "turn_at": turn_at, "mate_at": mate_at,
		"walk_at": walk_at, "protect_at": protect_at, "hide_at": hide_at, "protected_from_start": protected_from_start, "gone_at": gone_at, "run_at": run_at, "turn_at_final": turn_at}
	var world := FakeWorld.new()
	var brain = BRAIN.new()
	var draws_rng := RandomNumberGenerator.new()
	draws_rng.seed = 1
	brain.setup(world, draws_rng, WARNING.new())
	brain.tune(profile)
	brain.warning.latency_for[1] = latency
	brain.force(&"creep", {"seat": 1})
	var x_l := -gap
	var x_v := 0.0
	var target_x := x_l
	var pace := 0.0
	var at := INF
	var truth: Array = []
	var takes: Array = []
	var bad_start := false
	var steps := int(12.0 / DT)
	for k in steps:
		var t: float = brain.clock + DT
		# The victim and her this tick (she went where the last intent said).
		var since := t - at
		var speed := 0.0
		if since >= run_at - EPS: speed = 6.0
		elif since >= walk_at - EPS: speed = 3.8
		x_v += speed * DT
		x_l = move_toward(x_l, target_x, pace * DT)
		var angle := 180.0
		if facing_her: angle = 0.0
		elif since >= turn_at - EPS: angle = maxf(0.0, 180.0 - 600.0 * (since - turn_at))
		var distance := sqrt((x_v - x_l) * (x_v - x_l) + 1.0)
		var cone := SIGHT.REGARD_REMOTE if remote else SIGHT.REGARD_LOCAL
		var regards := angle <= cone and (lit or (torch and angle <= SIGHT.TORCH_FACE_ANGLE) or distance <= SIGHT.DARK_FACE)
		var torch_by: Array[int] = []
		if torch and angle <= SIGHT.TORCH_FACE_ANGLE: torch_by.append(1)
		if since >= mate_at - EPS: torch_by.append(2)
		var regarded_by: Array[int] = []
		if regards: regarded_by.append(1)
		var protected: bool = protected_from_start or since >= protect_at - EPS
		var hidden: bool = since >= hide_at - EPS
		var gone: bool = since >= gone_at - EPS
		var p = SENSES.Percept.new()
		p.face = Vector3(x_l, 2.2, 0)
		p.regarded_by = regarded_by
		p.torch_by = torch_by
		var v = SENSES.Seen.new()
		v.seat = 1
		v.point = Vector3(x_v, 0, 0)
		v.eye = Vector3(x_v, 1.64, 0)
		v.view = Vector3(-1, 0, 0) if angle < 90.0 else Vector3(1, 0, 0)
		v.seen = true
		v.lit = lit
		v.torch = torch
		v.hidden = hidden
		v.fair = not protected
		v.protected = protected
		v.remote = remote
		v.latency = latency
		v.distance = distance
		v.behind = angle >= 105.0
		v.regards = regards
		v.speed = speed
		v.alone = 20.0
		p.bodies[1] = v
		p.victim = null if gone else v
		var was_cue: bool = brain.state == BRAIN.State.CUE
		var asked: Dictionary = brain.tick(DT, p)
		if at < INF and t > at + EPS:
			truth.append({"t": t, "gone": gone, "fair": not protected, "hidden": hidden, "lit": lit, "regards": regards, "torch": not torch_by.is_empty(), "regarded": not regarded_by.is_empty(), "distance": distance, "speed": speed})
		if at == INF and brain.state == BRAIN.State.CUE and not was_cue:
			at = t
			if protected or regards or not torch_by.is_empty(): bad_start = true
		match String(asked.do):
			"go":
				target_x = (asked.to as Vector3).x
				pace = float(asked.speed)
			"take":
				takes.append(t)
				pace = 0.0
			_:
				pace = 0.0
		if at < INF and not brain.state in [BRAIN.State.CUE, BRAIN.State.TAKE]: break
	var ledger: Array = brain.warning.ledger
	var entry: Dictionary = ledger[ledger.size() - 1] if not ledger.is_empty() else {}
	var outcome: String = String(entry.outcome) if not entry.is_empty() else "none"
	var end: float = float(entry.take_at) if outcome == "taken" else (float(entry.end) if not entry.is_empty() else -1.0)
	var due := at + W + minf(latency, WARNING.LATENCY_CAP)
	var oracle := judge(truth, at, due, lit_takes)
	# Properties that do not copy the order of check().
	var saved_before_take := false
	var save_before_due := false
	var first_save := INF
	var aborted_first := false
	for row in truth:
		var saving: bool = bool(row.regards) or bool(row.torch) or bool(row.regarded)
		var aborting: bool = bool(row.gone) or not bool(row.fair) or bool(row.hidden) or (bool(row.lit) and not lit_takes)
		if aborting and first_save == INF: aborted_first = true
		if saving and outcome == "taken" and float(row.t) <= end + EPS: saved_before_take = true
		if saving and first_save == INF and not aborted_first and float(row.t) <= due + EPS: first_save = float(row.t)
		if aborted_first or first_save < INF: break
	save_before_due = first_save < INF
	var last_moment_save: bool = save_before_due and first_save >= due - 0.1 - EPS
	return {"outcome": outcome, "end": end, "at": at, "window": W, "latency": latency, "takes": takes, "ledger": ledger, "bad_start": bad_start, "oracle": oracle,
		"saved_before_take": saved_before_take, "save_before_due": save_before_due, "last_moment_save": last_moment_save,
		"evidence": {"i": i, "id": id, "draws": draws, "oracle": oracle, "outcome": outcome, "at": at, "due": due if at < INF else -1.0, "take_at": end if outcome == "taken" else -1.0}}

## The verdict from the harness's truth alone, tick by tick from the cue on:
## abort, save, take, saved running, expiry, in that order.
func judge(truth: Array, at: float, due: float, lit_takes: bool) -> Dictionary:
	if at == INF: return {"outcome": "none", "end": -1.0}
	var ran := false
	for row in truth:
		var t := float(row.t)
		if bool(row.gone) or not bool(row.fair) or bool(row.hidden) or (bool(row.lit) and not lit_takes): return {"outcome": "aborted", "end": t}
		if bool(row.regards) or bool(row.torch) or bool(row.regarded): return {"outcome": "saved", "end": t}
		if float(row.speed) >= WARNING.RUNNING: ran = true
		if t >= due - EPS:
			var d := float(row.distance)
			if d <= WARNING.TAKE_REACH or (not ran and d <= WARNING.TAKE_REACH_WALKED): return {"outcome": "taken", "end": t}
			if ran: return {"outcome": "saved", "end": t}
		if t > due + WARNING.TAKE_HOLD + EPS: return {"outcome": "expired", "end": t}
	return {"outcome": "active", "end": -1.0}
