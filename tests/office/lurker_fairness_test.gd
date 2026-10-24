extends SceneTree
## The Lurker's guarantee (docs/OFICINAS.md 1 and 11.5; spec_f2_mind 10.2):
## she never takes anybody she has not warned behind them, never before the
## warning has run its window, and a look in the light, a torch on her face
## (theirs or a teammate's) or running away saves. Part B: 200 seeded
## approaches on a straight corridor with no scene, her brain against the
## harness's own truth and an oracle that does not read the brain; walking
## away does not save (the author, 24 October 2026), running does. Part A:
## she on a built floor 2, her senses, brain and warning together.
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
	recordings()
	never_faked()
	await part_a()
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

## Her warning's three recordings load and each is over before the shortest
## window (Pesadilla's) could end in a take; her two shrieks load.
func recordings() -> void:
	var shortest := INF
	for id in DIFFICULTY.ORDER: shortest = minf(shortest, float(DIFFICULTY.profile(id, &"lurker").back_window))
	var bad: Array = []
	for path in WARNING.CUE_SOUNDS:
		var stream = load(path)
		if not stream is AudioStream or (stream as AudioStream).get_length() >= shortest: bad.append(path)
	for path in BRAIN.SCARE_SOUNDS:
		if not load(path) is AudioStream: bad.append(path)
	check("Sus tres avisos suenan enteros antes de la ventana más corta, y sus chillidos cargan", bad.is_empty(), str(bad))

## The hallucinations never fake her warning (docs/OFICINAS.md 5): no script
## of the game but lurker.gd and lurker_warning.gd names its sounds or its
## caption.
func never_faked() -> void:
	var allowed := ["res://game/enemies/lurker/lurker.gd", "res://game/enemies/lurker/lurker_warning.gd"]
	var found: Array = []
	for path in scripts("res://game"):
		if allowed.has(path): continue
		var body := FileAccess.get_file_as_string(path)
		for word in ["lurker/cue_", "CUE_SOUNDS", "CUE_CAPTION"]:
			if body.contains(word): found.append("%s: %s" % [path, word])
	check("Ninguna alucinación ni nada más que ella puede imitar su aviso", found.is_empty(), str(found))

func scripts(dir: String) -> Array:
	var out: Array = []
	var access := DirAccess.open(dir)
	if access == null: return out
	for name in access.get_files():
		if name.ends_with(".gd"): out.append(dir.path_join(name))
	for sub in access.get_directories(): out.append_array(scripts(dir.path_join(sub)))
	return out

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

# --- Part A: in the world (spec_f2_mind 10.2) -----------------------------------------------

const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SEEDS := [2026, 7, 11, 23]
var level
var lurker
var corridor := {}
var took_ok: Array = []

## The common floor: the first seed whose planta 1 has a corridor for the cases.
func part_a() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "lurker"
	level.set_floor(2)
	for seed_value in SEEDS:
		await level.start_floor(int(seed_value), false, [1], "equilibrada")
		corridor = find_corridor()
		if not corridor.is_empty():
			corridor["seed"] = int(seed_value)
			break
	if corridor.is_empty():
		check("Parte A: un pasillo para los casos", false, "ninguna semilla")
		return
	lurker = level.creature
	check("Parte A: en el piso 2 la criatura es The Lurker", lurker != null and lurker.kind_id() == &"lurker")
	if lurker == null or lurker.kind_id() != &"lurker": return
	if level.director != null: level.director.process_mode = Node.PROCESS_MODE_DISABLED
	level.player.set_physics_process(false)
	lurker.brain.took.connect(func(seat: int): took_ok.append(lurker.may_capture(level.player) and seat == int(level.player.slot)))
	await back_turned()
	await torch_turn()
	await dark_turn()
	await lit_cases()
	await lobby()
	await tool_forced()
	var audit: Array = WARNING.audit(lurker.capture_log())
	check("Parte A: el registro de avisos pasa la auditoría", audit.is_empty(), str(audit))
	level.queue_free()
	await process_frame

## The lowest-id corridor cell of planta 1 at least 8 m long, not next to an
## off-limits room: {room, centre, along}.
func find_corridor() -> Dictionary:
	var off: Array = level.off_limits_rooms()
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != 0 or int(room.type) != OFFICE.CORRIDOR: continue
		var span := FLOOR.size_of(room)
		if maxf(span.x, span.y) < 8.0 or not level.creature.shell.tray_of.has(int(room.id)): continue
		if level.manifest.adjacency[int(room.id)].any(func(other): return off.has(int(other))): continue
		var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
		return {"room": int(room.id), "centre": FLOOR.position_of(room), "along": along}
	return {}

func place_player(point: Vector3, facing: Vector3) -> void:
	var player = level.player
	player.global_position = point
	player.rotation.y = atan2(-facing.x, -facing.z)
	player.camera.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	for i in 3: await physics_frame

## The player's view turned on to a point.
func aim_at(point: Vector3) -> void:
	var player = level.player
	var to: Vector3 = point - player.camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.camera.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())

## The player 1.5 m along the corridor facing on, her 2.4 m behind them on
## the ceiling, closing in; the corridor dark or lit, the torch on or off.
func set_up(dark: bool, torch: bool) -> void:
	lurker.brain.forget_all(0.0)
	# A fresh approach: neither the calm after a fright nor after a take.
	lurker.brain.spurned = {}
	lurker.brain.sated_until = -INF
	if not level.executions.execution.is_empty(): level.release_execution()
	level.hotel.set_room_power(int(corridor.room), not dark)
	var centre: Vector3 = corridor.centre
	var along: Vector3 = corridor.along
	await place_player(centre + along * 1.5, along)
	level.player.torch.visible = torch
	lurker.place_over(centre - along * 0.9, level.player.camera.global_position)
	lurker.grace = 0.0
	lurker.thinking = true
	await physics_frame
	lurker.brain.force(&"creep", {"seat": int(level.player.slot)})

## Physics frames until the warning in hand ends (or none starts), at most
## `seconds`; `each` is called every frame with the brain.
func run_cue(seconds: float, each := Callable()) -> Dictionary:
	var before: int = lurker.warning.ledger.size()
	var started := false
	for i in int(seconds * 60.0):
		await physics_frame
		if each.is_valid(): each.call(lurker.brain)
		if lurker.warning.ledger.size() > before: started = true
		if started and lurker.warning.active.is_empty(): break
	return lurker.warning.ledger[lurker.warning.ledger.size() - 1] if lurker.warning.ledger.size() > before else {}

func back_turned() -> void:
	var bad: Array = []
	for id in DIFFICULTY.ORDER:
		level.set_difficulty(id)
		level.arm_creature()
		var W := float(level.tuning().back_window)
		took_ok = []
		await set_up(true, false)
		var entry := await run_cue(6.0)
		await physics_frame
		var ok: bool = not entry.is_empty() and String(entry.outcome) == "taken" and absf(float(entry.window) - W) < 1e-6
		if ok: ok = float(entry.take_at) - float(entry.at) >= W - 1e-6 and float(entry.take_at) - float(entry.at) <= W + 1.0 / 60.0 + 1e-6
		if ok: ok = took_ok == [true] and not lurker.may_capture(level.player)
		if not ok: bad.append([id, entry.get("outcome", "nada"), entry.get("at", -1), entry.get("take_at", -1), took_ok])
	check("Parte A: de espaldas a oscuras la coge al final de su ventana, en las cuatro dificultades", bad.is_empty(), str(bad))
	level.set_difficulty("equilibrada")
	level.arm_creature()

func torch_turn() -> void:
	await set_up(true, true)
	level.player.rotation.y += PI
	await physics_frame
	level.player.rotation.y -= PI
	var turned := [false]
	var entry := await run_cue(6.0, func(brain):
		var active: Dictionary = lurker.warning.active
		if not turned[0] and not active.is_empty() and brain.clock >= float(active.due) - 0.3:
			turned[0] = true
			aim_at(lurker.face_point()))
	var ok: bool = not entry.is_empty() and String(entry.outcome) == "saved" and String(entry.reason) == "linterna" and int(entry.by) == int(level.player.slot) and float(entry.end) < float(entry.due)
	check("Parte A: darse la vuelta con la linterna a falta de 0,3 s la espanta", ok, str(entry))
	var spurned: float = float(lurker.brain.spurned.get(int(level.player.slot), -INF))
	check("Parte A: y la deja en paz su rato", ok and spurned >= float(entry.end) + float(level.tuning().scare_calm) - 0.01, str(spurned))

func dark_turn() -> void:
	await set_up(true, false)
	var turned := [false]
	var entry := await run_cue(6.0, func(brain):
		var active: Dictionary = lurker.warning.active
		if not turned[0] and not active.is_empty() and brain.clock >= float(active.due) - 0.3:
			turned[0] = true
			aim_at(lurker.face_point()))
	check("Parte A: a oscuras y sin linterna, darse la vuelta no basta", not entry.is_empty() and String(entry.outcome) == "taken", str(entry))

func lit_cases() -> void:
	await set_up(false, false)
	var turned := [false]
	var entry := await run_cue(6.0, func(brain):
		var active: Dictionary = lurker.warning.active
		if not turned[0] and not active.is_empty() and brain.clock >= float(active.due) - 0.3:
			turned[0] = true
			aim_at(lurker.face_point()))
	check("Parte A: con luz, mirarla la salva", not entry.is_empty() and String(entry.outcome) == "saved" and String(entry.reason) == "mirada", str(entry))
	level.set_difficulty("apacible")
	level.arm_creature()
	await set_up(false, false)
	var none := await run_cue(3.0)
	check("Parte A: en Apacible, con luz, no avisa", none.is_empty())
	level.set_difficulty("equilibrada")
	level.arm_creature()

## The freight lobby of planta 1: never a warning there.
func lobby() -> void:
	var refuge := -1
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) == 0 and int(room.type) == OFFICE.REFUGE:
			refuge = int(room.id)
			break
	if refuge < 0:
		check("Parte A: un vestíbulo del montacargas", false)
		return
	var room: Dictionary = level.manifest.rooms[refuge]
	var door: Dictionary = FLOOR.doorways(room)[0] if not FLOOR.doorways(room).is_empty() else {}
	var centre := FLOOR.position_of(room)
	lurker.brain.forget_all(0.0)
	await place_player(centre, Vector3(1, 0, 0))
	lurker.place_over(centre - Vector3(2.4, 0, 0), level.player.camera.global_position)
	lurker.brain.force(&"creep", {"seat": int(level.player.slot)})
	var none := await run_cue(4.0)
	check("Parte A: nunca avisa en el vestíbulo del montacargas", none.is_empty() and lurker.brain.state != lurker.brain.State.CUE, str(door))

## A tool's capture goes through and is logged as forced.
func tool_forced() -> void:
	level.executions.forced = {"glance": false}
	var let: bool = lurker.may_capture(level.player)
	var last: Dictionary = lurker.warning.ledger[lurker.warning.ledger.size() - 1]
	level.executions.forced = {}
	check("Parte A: una herramienta que fuerza la captura pasa y queda apuntada como forzada", let and bool(last.forced) and String(last.reason) == "forzada")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000
	var stray := false
	for i in 10:
		for k in rng.randi_range(1, 5): await physics_frame
		if lurker.may_capture(level.player): stray = true
	check("Parte A: fuera del instante de una cogida, nunca puede capturar", not stray)
