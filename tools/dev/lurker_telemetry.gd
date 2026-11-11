extends SceneTree
## The Lurker as she plays today, in figures: a bots' match on floor 2 with
## the real creature, sampled ten times a second of game time, and what comes
## of it -- time and stays by state, the transitions and their loops, the
## stretches she stands still while she should be going somewhere, how smooth
## her motion is, how she hunts, and what is heard of her. Meant to be run
## again after every change to her (2 or 3 minutes of wall clock).
##
##   godot --headless --path . --script res://tools/dev/lurker_telemetry.gd \
##       --log-file evidence/telemetry/<name>.log -- --automation --test-profile --silent \
##       [--difficulty=equilibrada] [--bots=1] [--seconds=240] [--seed=7] [--speed=3] [--out=<json>]
##
## --speed=k plays k game seconds per wall second (time_scale k with k times
## the physics ticks: each step is still 1/60 s of game). The bots get mercy:
## a capture is counted and spared (bot_match.spare_survivor moves her away,
## a logged jump), so one bot lasts the whole run. The parked player's camera
## is not the listener: a camera of this tool rides the nearest bot's, so her
## voice is heard where a survivor is (a lobby listener would mute it all).
## --blind: the bots know nothing of her (bot_threat_none.gd) and only go about
## the floor's tasks: the hunt measured against somebody who does not dodge her.
const MATCH := preload("res://tools/bots/bot_match.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const DIFFICULTY := preload("res://game/floors/difficulty.gd")
const VOICE := preload("res://game/enemies/lurker/lurker_voice.gd")
const BLIND := preload("res://tools/bots/bot_threat_none.gd")
const SAMPLE := 0.1
## A stop: this long without moving this far, in a state that should move.
const STUCK_TIME := 4.0
const STUCK_MOVE := 0.3
## Between two samples: a jump, a turn of the base, a change of speed.
const JUMP := 1.5
const TURN := 60.0
const SPEED_STEP := 1.5
const NEAR := 15.0
## A back-and-forth A>B>A counts as a loop within this long.
const LOOP_WINDOW := 5.0
## States she may stand still in: listening, waiting over a locker.
const STILL_STATES := [BRAIN.State.LISTEN, BRAIN.State.WAIT_ABOVE]
var level
var bots
var lurker
var options := {}
var samples: Array = []
var events: Array = []
var sounds: Array = []
var footfalls := 0
var last_claw := -INF
var voice_seen = null
var listener: Camera3D
var encounters_seen := 0
var next_sample := 0.0

func _initialize() -> void: run.call_deferred()

func arg(name_value: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name_value): return argument.trim_prefix("--%s=" % name_value)
	return fallback

func run() -> void:
	var started := Time.get_ticks_msec()
	if not OS.get_cmdline_user_args().has("--test-profile"):
		printerr("lurker_telemetry: sin --test-profile no se juega (protege el punto de control de Continuar).")
		quit(2)
		return
	var difficulty := arg("difficulty", "equilibrada")
	if not DIFFICULTY.ORDER.has(difficulty):
		printerr("lurker_telemetry: dificultad desconocida %s (%s)" % [difficulty, ", ".join(PackedStringArray(DIFFICULTY.ORDER))])
		quit(2)
		return
	var speed := clampf(float(arg("speed", "3")), 1.0, 8.0)
	var blind := OS.get_cmdline_user_args().has("--blind")
	options = {"blind": blind, "difficulty": difficulty, "bots": clampi(int(arg("bots", "1")), 1, 4), "seconds": float(arg("seconds", "240")), "seed": int(arg("seed", "7")), "speed": speed}
	var out := arg("out", "evidence/telemetry/lurker_%s_%db_s%d%s.json" % [difficulty, options.bots, options.seed, "_ciegos" if blind else ""])
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	level.set_floor(2)
	level.creature_scene = "lurker"
	bots = MATCH.new()
	bots.setup(level, {"bots": options.bots, "seed": options.seed, "difficulty": difficulty, "mercy": true, "verbose": false, "out": "", "stage_cap": 1e9, "run_cap": 1e9})
	root.add_child(bots)
	if not await bots.begin():
		printerr("lurker_telemetry: la partida no arranca (%s)" % bots.outcome)
		quit(1)
		return
	lurker = level.creature
	if lurker == null or String(lurker.kind_id()) != "lurker":
		printerr("lurker_telemetry: la criatura del piso no es The Lurker")
		quit(1)
		return
	# Every bot reads owner_match.threat: swapped, none of them minds her.
	if blind: bots.threat = BLIND.new(level)
	hook()
	var loaded := Time.get_ticks_msec()
	# Only now: loading the floor at k ticks a second would only pile steps up.
	Engine.max_fps = 0
	Engine.physics_ticks_per_second = int(60 * speed)
	Engine.time_scale = speed
	while bots.outcome.is_empty() and float(bots.clock) < float(options.seconds):
		await physics_frame
		frame()
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	var played := Time.get_ticks_msec()
	var summary: Dictionary = bots.finish()
	var report := analyse(summary)
	report["wall"] = {"load": snappedf((loaded - started) / 1000.0, 0.1), "play": snappedf((played - loaded) / 1000.0, 0.1), "total": snappedf((Time.get_ticks_msec() - started) / 1000.0, 0.1), "factor": snappedf(float(bots.clock) / maxf((played - loaded) / 1000.0, 0.001), 0.01)}
	print_table(report)
	report["samples_columns"] = ["t", "state", "x", "y", "z", "speed", "where", "room", "prey", "prey_d", "near_d", "seen", "yaw", "why"]
	report["samples"] = samples
	report["events"] = events
	report["sounds"] = sounds
	var path := ProjectSettings.globalize_path("res://" + out) if not out.is_absolute_path() else out
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	# What the director led her to, and whether she took it.
	var director = level.get("director")
	if director != null:
		for entry in director.history:
			if String(entry.kind) != "fase": print("DIRECTOR t=%0.0f %s %s sala %d ok=%s a %0.0f m" % [float(entry.t), String(entry.phase), String(entry.kind), int(entry.get("room", -1)), str(entry.get("ok", "")), float(entry.get("nearest", -1.0))])
	print("TELEMETRY_OUT %s" % path)
	bots.teardown()
	level.queue_free()
	await process_frame
	quit(0)

# --- Hooks ------------------------------------------------------------------------------------

func hook() -> void:
	var brain = lurker.brain
	brain.cue_started.connect(func(entry: Dictionary):
		event("aviso", {"seat": int(entry.seat)})
		sound("aviso"))
	brain.cue_ended.connect(func(entry: Dictionary): event("aviso_" + String(entry.outcome), {"seat": int(entry.seat), "reason": String(entry.get("reason", ""))}))
	brain.scared.connect(func(cause: String, seat: int):
		event("espantada", {"seat": seat, "cause": cause})
		sound("chillido"))
	brain.took.connect(func(seat: int): event("captura", {"seat": seat}))
	if lurker.visual != null and lurker.visual.has_signal("footfall"): lurker.visual.footfall.connect(on_footfall)
	listener = Camera3D.new()
	listener.name = "TelemetryEar"
	level.add_child(listener)
	listener.current = true

## Her claws as the game spaces them (voice.STEP_GAP), on game time: the
## voice's own gap is on the wall clock, so at --speed above 1 it lets fewer through.
func on_footfall(_point: Vector3, _strength: float, _normal: Vector3) -> void:
	var t := float(bots.clock)
	if t - last_claw < VOICE.STEP_GAP or lurker.hushed() or level.session.state != level.session.State.PLAYING: return
	last_claw = t
	footfalls += 1
	sound("garras")

func event(kind: String, data := {}) -> void:
	var entry := {"t": snappedf(float(bots.clock), 0.01), "kind": kind, "state": BRAIN.NAMES[lurker.brain.state]}
	entry.merge(data)
	events.append(entry)

func sound(kind: String) -> void:
	sounds.append([snappedf(float(bots.clock), 0.01), kind, BRAIN.NAMES[lurker.brain.state]])

## Every physics frame: the ear on the nearest bot, her voice's new sounds,
## and a sample every SAMPLE of game time.
func frame() -> void:
	if not is_instance_valid(lurker): return
	var near = nearest_bot()
	if near != null: listener.global_transform = near.camera.global_transform
	voice_sounds()
	var count := 0
	for seat in level.ledger.encounters: count += int(level.ledger.encounters[seat])
	if count > encounters_seen: event("encuentro", {"total": count})
	encounters_seen = count
	# Kept on its own grid: clock + SAMPLE would drift to every seventh frame.
	if float(bots.clock) + 1e-6 >= next_sample:
		next_sample += SAMPLE
		sample(near)

func nearest_bot():
	var best = null
	var gap := INF
	for body in bots.bodies:
		if not is_instance_valid(body) or body.dead: continue
		var d: float = body.global_position.distance_to(lurker.global_position)
		if d < gap:
			gap = d
			best = body
	return best

## What her voice played since the last frame (voice.history keeps 32), by kind;
## her claws are counted from her footfalls instead (on_footfall).
func voice_sounds() -> void:
	var history: Array = lurker.voice.history
	var fresh: Array = []
	for i in range(history.size() - 1, -1, -1):
		if is_same(history[i], voice_seen): break
		fresh.push_front(history[i])
	if not history.is_empty(): voice_seen = history[history.size() - 1]
	for entry in fresh:
		var file := String(entry.path).get_file()
		var kind := "garras_emitidas"
		if file.begins_with("knock_"): kind = "golpe_ducto"
		elif file.begins_with("scrape_"): kind = "rascar_metal"
		elif file.begins_with("tile_creak_"): kind = "crujido_placa"
		elif file.begins_with("dust_"): kind = "polvo"
		elif file.begins_with("tile_") and lurker.voice.medium() == &"plenum": kind = "crujido_plenum"
		sound(kind)

# --- A sample ----------------------------------------------------------------------------------

func sample(near) -> void:
	var motion = lurker.motion
	var brain = lurker.brain
	var at: Vector3 = lurker.global_position
	var where := place()
	var room := int(motion.room())
	var prey := int(brain.prey)
	var prey_d := -1.0
	var body = lurker.senses.body_of(prey) if prey >= 0 else null
	if body != null: prey_d = body.global_position.distance_to(at)
	var near_d: float = near.global_position.distance_to(at) if near != null else -1.0
	var hidden: bool = bool(motion.hidden) or motion.transit_phase() == &"drop"
	var seen: bool = not hidden and SIGHT.watched(level, lurker.face_point(), [lurker.get_rid()])
	var look: Vector3 = lurker.global_basis.z
	var yaw: Variant = snappedf(rad_to_deg(atan2(look.x, look.z)), 0.1) if Vector2(look.x, look.z).length() > 0.1 else null
	samples.append([snappedf(float(bots.clock), 0.01), BRAIN.NAMES[brain.state], snappedf(at.x, 0.01), snappedf(at.y, 0.01), snappedf(at.z, 0.01), snappedf(lurker.velocity.length(), 0.01), where, room, prey, snappedf(prey_d, 0.1), snappedf(near_d, 0.1), seen, yaw, why(), int(motion.jump_id), resting()])

## Where she is: on a ceiling, a door band, a channel (an archive's), in a
## duct, in the plenum, between plantas or on the floor (a leap).
func place() -> String:
	var motion = lurker.motion
	if motion.transit_phase() != &"": return "entre_plantas"
	if motion.in_duct: return "plenum" if lurker.voice.medium() == &"plenum" else ("ducto" if motion.hidden else "ducto_visible")
	if motion.on_floor: return "suelo"
	if motion.surface(): return ["techo", "franja", "canal"][int(lurker.shell.patches[motion.state.patch].kind)]
	# A squeeze leg: through a grille's mouth, between a duct and her ceiling.
	return "boca_ducto"

## Why she is where she is, as far as her motion and mind say.
func why() -> String:
	var motion = lurker.motion
	var brain = lurker.brain
	if lurker.grace > 0.0: return "gracia"
	if motion.transit_phase() != &"": return "transito_" + String(motion.transit_phase())
	var route := String(motion.route_state())
	if route == "blocked": return "bloqueada:" + String(motion.stuck)
	if route == "waiting": return "espera_puerta"
	var doing := String(lurker.intent.get("do", ""))
	if lurker.order_failed: return "orden_fallida:" + doing
	if float(brain.failed_for) > 0.0: return "ruta_fallida"
	if route == "moving": return "en_ruta"
	if doing == "hold":
		if float(brain.held_for) > 0.0: return "retenida_vista"
		if brain.state == BRAIN.State.STALK: return "acecha_a_distancia"
		return "quieta_orden"
	if doing == "keep": return "sigue"
	return "en_meta:" + doing

## Resting: her grace, the ride between plantas hidden, or hidden in a duct
## after a flight (FLEE_HIDE) waiting to come back out.
func resting() -> bool:
	var motion = lurker.motion
	return lurker.grace > 0.0 or motion.transit_phase() == &"drop" or (lurker.brain.state == BRAIN.State.FLEE and motion.in_duct and motion.hidden)

# --- The figures ---------------------------------------------------------------------------------

func analyse(summary: Dictionary) -> Dictionary:
	var total := float(samples.size()) * SAMPLE
	var minutes := maxf(total / 60.0, 0.001)
	# State time, stays and transitions.
	var time := {}
	var stays := {}
	var transitions := {}
	var chain: Array = []
	var loops := {}
	var stay_from := 0.0
	for i in samples.size():
		var s: Array = samples[i]
		time[s[1]] = float(time.get(s[1], 0.0)) + SAMPLE
		var last_one := i == samples.size() - 1
		if i > 0 and s[1] != samples[i - 1][1]:
			stays[samples[i - 1][1]] = stays.get(samples[i - 1][1], []) + [float(s[0]) - stay_from]
			var key := "%s>%s" % [samples[i - 1][1], s[1]]
			transitions[key] = int(transitions.get(key, 0)) + 1
			chain.append([float(s[0]), samples[i - 1][1], s[1]])
			stay_from = float(s[0])
		if last_one: stays[s[1]] = stays.get(s[1], []) + [float(s[0]) + SAMPLE - stay_from]
	for j in range(1, chain.size()):
		if chain[j][2] == chain[j - 1][1] and chain[j][1] == chain[j - 1][2] and float(chain[j][0]) - float(chain[j - 1][0]) <= LOOP_WINDOW:
			var key := "%s>%s>%s" % [chain[j - 1][1], chain[j - 1][2], chain[j][2]]
			loops[key] = int(loops.get(key, 0)) + 1
	var by_state := {}
	for state in time:
		var list: Array = stays.get(state, [])
		var most := 0.0
		var sum := 0.0
		for d in list:
			sum += float(d)
			most = maxf(most, float(d))
		by_state[state] = {"share": snappedf(100.0 * float(time[state]) / maxf(total, 0.001), 0.1), "seconds": snappedf(float(time[state]), 0.1), "stays": list.size(), "mean_stay": snappedf(sum / maxf(list.size(), 1), 0.1), "max_stay": snappedf(most, 0.1)}
	# Stops, speeds and the smoothness between samples.
	var stops := find_stops()
	var speeds := {}
	var jumps := {"sin_registrar": 0, "registrados": 0, "detalle": []}
	var turns := 0
	var speed_steps := 0
	for i in samples.size():
		var s: Array = samples[i]
		if not speeds.has(s[1]): speeds[s[1]] = []
		speeds[s[1]].append(float(s[5]))
		if i == 0: continue
		var p: Array = samples[i - 1]
		var hidden_now: bool = String(s[6]) in ["ducto", "plenum", "entre_plantas"] or String(p[6]) in ["ducto", "plenum", "entre_plantas"]
		if hidden_now: continue
		var gap := Vector3(s[2], s[3], s[4]).distance_to(Vector3(p[2], p[3], p[4]))
		if gap > JUMP:
			var logged: bool = int(s[14]) != int(p[14])
			jumps["registrados" if logged else "sin_registrar"] += 1
			if jumps.detalle.size() < 40: jumps.detalle.append({"t": s[0], "m": snappedf(gap, 0.01), "state": s[1], "where": s[6], "room": room_text(int(s[7])), "logged": logged})
		if s[12] != null and p[12] != null and absf(wrapf(float(s[12]) - float(p[12]), -180.0, 180.0)) > TURN: turns += 1
		if absf(float(s[5]) - float(p[5])) > SPEED_STEP: speed_steps += 1
	var speed_table := {}
	for state in speeds:
		var list: Array = speeds[state]
		list.sort()
		var sum := 0.0
		for v in list: sum += float(v)
		speed_table[state] = {"mean": snappedf(sum / maxf(list.size(), 1), 0.01), "p95": snappedf(float(list[mini(int(list.size() * 0.95), list.size() - 1)]), 0.01)}
	var logged_jumps: Array = lurker.motion.jumps.map(func(j): return String(j.reason))
	var reasons := {}
	for r in logged_jumps: reasons[r] = int(reasons.get(r, 0)) + 1
	jumps["motivos_registrados_partida"] = reasons
	# The hunt.
	var count := {}
	for e in events: count[e.kind] = int(count.get(e.kind, 0)) + 1
	var cue_times: Array = events.filter(func(e): return e.kind == "aviso").map(func(e): return float(e.t))
	var gaps := 0.0
	for k in range(1, cue_times.size()): gaps += float(cue_times[k]) - float(cue_times[k - 1])
	var near := 0
	var with_prey := 0
	var seen := 0
	for s in samples:
		if float(s[10]) >= 0.0 and float(s[10]) < NEAR: near += 1
		if int(s[8]) >= 0: with_prey += 1
		if bool(s[11]): seen += 1
	var attempts := 0
	for key in transitions:
		if String(key).ends_with(">" + BRAIN.NAMES[BRAIN.State.CREEP]): attempts += int(transitions[key])
	var hunt := {
		"first_cue": cue_times[0] if not cue_times.is_empty() else -1.0,
		"cues": int(count.get("aviso", 0)), "saves": int(count.get("aviso_saved", 0)), "captures": int(count.get("captura", 0)),
		"aborted": int(count.get("aviso_aborted", 0)), "expired": int(count.get("aviso_expired", 0)), "scares": int(count.get("espantada", 0)),
		"attempts": attempts, "encounters": encounters_seen,
		"cues_min": snappedf(int(count.get("aviso", 0)) / minutes, 0.01), "saves_min": snappedf(int(count.get("aviso_saved", 0)) / minutes, 0.01), "captures_min": snappedf(int(count.get("captura", 0)) / minutes, 0.01),
		"mean_between_cues": snappedf(gaps / (cue_times.size() - 1), 0.1) if cue_times.size() > 1 else -1.0,
		"near_share": snappedf(100.0 * near / maxf(samples.size(), 1), 0.1), "prey_share": snappedf(100.0 * with_prey / maxf(samples.size(), 1), 0.1), "seen_share": snappedf(100.0 * seen / maxf(samples.size(), 1), 0.1),
		"tally": summary.get("creature", {}),
	}
	# What is heard of her.
	var kinds := {}
	var per_state := {}
	var times: Array = [0.0]
	for row in sounds:
		kinds[row[1]] = int(kinds.get(row[1], 0)) + 1
		if row[1] == "garras_emitidas": continue
		per_state[row[2]] = int(per_state.get(row[2], 0)) + 1
		times.append(float(row[0]))
	times.append(float(bots.clock))
	times.sort()
	var silence := 0.0
	var silence_at := 0.0
	for k in range(1, times.size()):
		if float(times[k]) - float(times[k - 1]) > silence:
			silence = float(times[k]) - float(times[k - 1])
			silence_at = float(times[k - 1])
	var sound_rates := {}
	for k in kinds: sound_rates[k] = snappedf(int(kinds[k]) / minutes, 0.1)
	var state_rates := {}
	for state in time: state_rates[state] = snappedf(int(per_state.get(state, 0)) / maxf(float(time[state]) / 60.0, 0.001), 0.1)
	return {
		"options": options, "result": String(summary.get("result", "")) if not String(summary.get("result", "")).is_empty() else "a_tiempo", "places": shares(6), "game_seconds": snappedf(total, 0.1), "transitions_total": chain.size(),
		"states": by_state, "transitions_top": top(transitions, 10), "loops": top(loops, 10),
		"stops": stops, "speeds": speed_table, "jumps": jumps, "turns": turns, "speed_steps": speed_steps,
		"hunt": hunt,
		"sound": {"counts": kinds, "per_min": sound_rates, "per_min_by_state": state_rates, "longest_silence": snappedf(silence, 0.1), "longest_silence_at": snappedf(silence_at, 0.1), "raw_footfalls": footfalls},
		"bots_incidents": summary.get("incidents", []).size(), "team": summary.get("team", []),
	}

## Stretches of over STUCK_TIME within STUCK_MOVE of where they began, in a
## state that should move (all but STILL_STATES) and not resting.
func find_stops() -> Array:
	var out: Array = []
	var still_names: Array = STILL_STATES.map(func(state): return BRAIN.NAMES[state])
	var anchor := -1
	var open := {}
	for i in samples.size():
		var s: Array = samples[i]
		var still_ok: bool = s[1] in still_names or bool(s[15])
		var moved: bool = anchor >= 0 and Vector3(s[2], s[3], s[4]).distance_to(Vector3(samples[anchor][2], samples[anchor][3], samples[anchor][4])) > STUCK_MOVE
		if anchor < 0 or still_ok or moved:
			if not open.is_empty(): out.append(close_stop(open))
			open = {}
			anchor = -1 if still_ok else i
			continue
		if float(s[0]) - float(samples[anchor][0]) < STUCK_TIME: continue
		if open.is_empty(): open = {"from": float(samples[anchor][0]), "to": 0.0, "states": {}, "why": {}, "room": room_text(int(s[7])), "where": s[6]}
		open.to = float(s[0])
		open.states[s[1]] = int(open.states.get(s[1], 0)) + 1
		open.why[s[13]] = int(open.why.get(s[13], 0)) + 1
	if not open.is_empty(): out.append(close_stop(open))
	return out

func close_stop(open: Dictionary) -> Dictionary:
	return {"t": snappedf(float(open.from), 0.1), "seconds": snappedf(float(open.to) - float(open.from), 0.1), "state": most(open.states), "states": open.states, "why": most(open.why), "whys": open.why, "room": open.room, "where": open.where}

## Share of the samples by a column's value, in percent.
func shares(column: int) -> Dictionary:
	var out := {}
	for s in samples: out[s[column]] = float(out.get(s[column], 0.0)) + 100.0 / maxf(samples.size(), 1)
	for k in out: out[k] = snappedf(float(out[k]), 0.1)
	return out

func most(counts: Dictionary) -> String:
	var best := ""
	for k in counts:
		if best == "" or int(counts[k]) > int(counts[best]): best = String(k)
	return best

func top(counts: Dictionary, n: int) -> Array:
	var rows: Array = []
	for k in counts: rows.append([String(k), int(counts[k])])
	rows.sort_custom(func(a, b): return int(a[1]) > int(b[1]))
	return rows.slice(0, n)

func room_text(room: int) -> String:
	if room < 0 or room >= level.manifest.rooms.size(): return "sin sala"
	return "%d %s" % [room, bots.room_name(level.manifest.rooms[room])]

# --- The table ------------------------------------------------------------------------------------

func print_table(r: Dictionary) -> void:
	var o: Dictionary = r.options
	print("LURKER_TELEMETRY %s%s · %d bots · semilla %d · %.0f s de juego en %.0f s de reloj (carga %.0f s, x%.2f) · %s" % [o.difficulty, " (bots ciegos)" if o.blind else "", o.bots, o.seed, r.game_seconds, r.wall.total, r.wall.load, r.wall.factor, r.result])
	print("ESTADOS          %     n   media   max   vel   p95   emis/min")
	var names: Array = r.states.keys()
	names.sort_custom(func(a, b): return float(r.states[a].share) > float(r.states[b].share))
	for state in names:
		var s: Dictionary = r.states[state]
		var v: Dictionary = r.speeds.get(state, {"mean": 0.0, "p95": 0.0})
		print("  %-12s %5.1f %4d %6.1f %6.1f %5.2f %5.2f %7.1f" % [state, s.share, s.stays, s.mean_stay, s.max_stay, v.mean, v.p95, float(r.sound.per_min_by_state.get(state, 0.0))])
	print("DÓNDE %s" % ", ".join(PackedStringArray(r.places.keys().map(func(k): return "%s %.1f%%" % [k, r.places[k]]))))
	print("TRANSICIONES %d · top: %s" % [r.transitions_total, ", ".join(PackedStringArray(r.transitions_top.map(func(row): return "%s %d" % [row[0], row[1]])))])
	print("BUCLES A>B>A (<%.0f s): %s" % [LOOP_WINDOW, ", ".join(PackedStringArray(r.loops.map(func(row): return "%s %d" % [row[0], row[1]]))) if not r.loops.is_empty() else "ninguno"])
	var stuck_total := 0.0
	for s in r.stops: stuck_total += float(s.seconds)
	print("ATASCOS %d (%.0f s en total)" % [r.stops.size(), stuck_total])
	var sorted_stops: Array = r.stops.duplicate()
	sorted_stops.sort_custom(func(a, b): return float(a.seconds) > float(b.seconds))
	for s in sorted_stops.slice(0, 8): print("  t=%.0f  %.1f s  %s  %s  %s  (%s)" % [s.t, s.seconds, s.state, s.where, s.room, s.why])
	print("FLUIDEZ saltos >%.1f m fuera de ductos: %d sin registrar, %d registrados · giros >%.0f°: %d · cambios de velocidad >%.1f m/s: %d" % [JUMP, r.jumps.sin_registrar, r.jumps.registrados, TURN, r.turns, SPEED_STEP, r.speed_steps])
	var h: Dictionary = r.hunt
	print("PERSECUCIÓN primer aviso %s · avisos %d (%.2f/min) · salvadas %d (%.2f/min) · capturas %d (%.2f/min) · abortados %d · caducados %d · espantadas %d · acercamientos %d · encuentros %d" % ["%.0f s" % h.first_cue if float(h.first_cue) >= 0.0 else "nunca", h.cues, h.cues_min, h.saves, h.saves_min, h.captures, h.captures_min, h.aborted, h.expired, h.scares, h.attempts, h.encounters])
	print("  entre avisos %s · a <%.0f m de alguien %.1f%% · con presa %.1f%% · vista %.1f%%" % ["%.1f s" % h.mean_between_cues if float(h.mean_between_cues) >= 0.0 else "-", NEAR, h.near_share, h.prey_share, h.seen_share])
	print("SONIDO por minuto: %s · silencio más largo %.1f s (desde t=%.0f)" % [", ".join(PackedStringArray(r.sound.per_min.keys().map(func(k): return "%s %.1f" % [k, r.sound.per_min[k]]))), r.sound.longest_silence, r.sound.longest_silence_at])
