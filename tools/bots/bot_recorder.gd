extends RefCounted
## Everything a bot match did, written down as it happens, so it can be
## watched again in the observer (bot_replay.gd) -- and so a run that dies
## halfway still leaves most of itself behind.
##
## In the run's folder:
##  header.json     what floor this is, and who played it: enough to put the
##                  same floor up again and know it is the same (its hash).
##  events.jsonl    one line per thing that happened, written at once: doors,
##                  sets, drawers, the keypad, lifts, stages, the blackout,
##                  deaths, hides, the creature's modes, what the bots found
##                  and what went wrong.
##  track_NNNN.bin  where everybody was, RATE times a second, in minute-long
##                  compressed pieces (one piece lost at most); every second
##                  the routes they meant to take; every KEYFRAME seconds the
##                  whole state of the floor, which is what a jump back in
##                  time starts from.
##  heartbeat.json  rewritten every HEARTBEAT seconds of the wall clock, so
##                  whoever runs this can tell a slow run from a dead one.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NET := preload("res://game/net/net_session.gd")
const FORMAT := 1
const RATE := 10.0
const SEGMENT := 60.0
const KEYFRAME := 30.0
const HEARTBEAT := 10.0
## Per bot in a frame: x, y, z, yaw, pitch, flags, hide, intent, sanity,
## speed, stamina, life. The creature: what its threat model says
## (bot_threat.recorded_row: for The Locust x, y, z, yaw, mode, focus seat,
## detection, stuck step, destination x, z, last known x, z).
const BOT_FIELDS := 12
const CREATURE_FIELDS := 12
enum Flag { CROUCHED = 1, TORCH = 2, HIDDEN = 4, DEAD = 8, RUNNING = 16, HELD = 32, RIDING = 64, BURNT = 128 }
var owner_match
var level
var folder := ""
var events_file: FileAccess
var track: FileAccess
var segment := -1
var clock := 0.0
var frame_clock := 0.0
var route_clock := 0.0
var key_clock := 0.0
var beat_msec := 0
var last := {}
var hides_seen := {}
## Door index -> [opened, locked] of each stage's gate: they open and lock
## without swinging (hotel_geometry.open_gates, relock_gate), which no
## signal says.
var gates_seen := {}

func _init(owner, out: String) -> void:
	owner_match = owner
	level = owner.level
	folder = out

## Opened once the floor is up and the bots are on it.
func start() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	var header := {
		"format": FORMAT,
		"generator": FLOOR.VERSION,
		"protocol": NET.PROTOCOL,
		"godot": Engine.get_version_info().string,
		"commit": String(owner_match.options.get("commit", "")),
		"seed": int(owner_match.options.get("seed", 81)),
		"floor_seed": int(level.session.run_seed),
		"fallback": bool(level.manifest.get("fallback", false)),
		"floor_hash": hash(JSON.stringify(level.manifest)),
		"seats": owner_match.seats(),
		"names": owner_match.bodies.map(func(body): return body.player_name),
		"characters": owner_match.bodies.map(func(body): return int(body.avatar.character) if body.avatar != null else 0),
		"knowledge": String(owner_match.options.get("knowledge", "discover")),
		"skill": String(owner_match.options.get("skill", "experto")),
		"difficulty": String(owner_match.level.difficulty),
		"mercy": bool(owner_match.options.get("mercy", false)),
		"enemy": not OS.get_cmdline_user_args().has("--no-enemy"),
		"rate": RATE,
		"bot_fields": BOT_FIELDS,
		"creature_fields": CREATURE_FIELDS,
		"date": Time.get_datetime_string_from_system(),
	}
	var file := FileAccess.open(folder.path_join("header.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(header, "\t"))
	file.close()
	events_file = FileAccess.open(folder.path_join("events.jsonl"), FileAccess.WRITE)
	for index in level.hotel.doors.size():
		var door = level.hotel.doors[index]
		door.swung.connect(func(target, slow, forceful): event("puerta", {"door": index, "open": target, "slow": slow, "forceful": forceful}))
	for index in level.televisions.size():
		level.televisions[index].switched.connect(func(on): event("tele", {"index": index, "on": on}))
	for index in level.containers.size():
		var piece = level.containers[index]
		# Deferred: the signal comes before the level writes down whose hands
		# it was (apply_search), and that is what the event keeps.
		piece.searched_changed.connect(func(): event("mueble", {"index": index, "searched": piece.searched, "slot": int(piece.slot), "digit": int(piece.digit), "by": int(level.found_by.get(int(piece.slot), -1)) if int(piece.slot) > 0 else -1}), CONNECT_DEFERRED)
	for body in owner_match.bodies: body.footfall.connect(func(point, radius): event("ruido", {"seat": int(body.slot), "at": vec(point), "radius": snappedf(radius, 0.1)}))
	# What the pacing director played, and every place the creature gave up.
	if is_instance_valid(level.director) and level.director.has_signal("decided"):
		level.director.decided.connect(func(entry):
			var data: Dictionary = entry.duplicate()
			if data.has("point"): data.point = vec(data.point)
			data.erase("t")
			# Its own kind is the move played; the event's kind is "director".
			data["move"] = data.get("kind", "")
			data.erase("kind")
			event("director", data))
	owner_match.threat.on_gave_up(func(origin, next): event("abandona", {"from": vec(origin), "to": vec(next)}))
	beat_msec = Time.get_ticks_msec()
	keyframe()
	frame()
	heartbeat()

func tick(delta: float) -> void:
	if events_file == null: return
	clock = owner_match.clock
	watch_changes()
	frame_clock += delta
	if frame_clock >= 1.0 / RATE:
		frame_clock = fmod(frame_clock, 1.0 / RATE)
		frame()
	route_clock += delta
	if route_clock >= 1.0:
		route_clock = 0.0
		routes()
	key_clock += delta
	if key_clock >= KEYFRAME:
		key_clock = 0.0
		keyframe()
	if Time.get_ticks_msec() - beat_msec > HEARTBEAT * 1000.0: heartbeat()

## One line of what happened, written through at once.
func event(kind: String, data := {}) -> void:
	if events_file == null: return
	var entry := {"t": snappedf(owner_match.clock, 0.01), "kind": kind}
	entry.merge(data)
	events_file.store_line(JSON.stringify(entry))
	events_file.flush()

## The track piece for this minute, opening the next one when it is time.
func stream() -> FileAccess:
	var wanted := int(clock / SEGMENT)
	if wanted != segment or track == null:
		if track != null: track.close()
		segment = wanted
		track = FileAccess.open_compressed(folder.path_join("track_%04d.bin" % segment), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		# A piece starts with the whole floor, so it can be read on its own.
		if clock > 0.0: keyframe()
	return track

func frame() -> void:
	var values := PackedFloat32Array()
	values.resize(owner_match.bodies.size() * BOT_FIELDS + CREATURE_FIELDS)
	var at := 0
	for i in owner_match.bodies.size():
		var body = owner_match.bodies[i]
		var brain = owner_match.brains[i]
		var p: Vector3 = body.global_position
		var flags := 0
		if body.crouched: flags |= Flag.CROUCHED
		if body.torch.visible: flags |= Flag.TORCH
		if body.hidden: flags |= Flag.HIDDEN
		if body.dead: flags |= Flag.DEAD
		if body.running: flags |= Flag.RUNNING
		if not level.execution.is_empty() and int(level.execution.seat) == int(body.slot): flags |= Flag.HELD
		if level.lifts.riding.has(int(body.slot)): flags |= Flag.RIDING
		if body.burnt: flags |= Flag.BURNT
		var row := [p.x, p.y, p.z, body.rotation.y, body.look_pitch, flags, level.hotel.hides.find(body.hiding_place) if body.hidden else -1, brain.state, body.mind(), Vector2(body.velocity.x, body.velocity.z).length(), body.stamina, int(level.session.participants.get(int(body.slot), 2))]
		for value in row:
			values[at] = float(value)
			at += 1
	for value in owner_match.threat.recorded_row():
		values[at] = float(value)
		at += 1
	stream().store_var(["f", snappedf(clock, 0.01), values])

## Where everybody meant to go: the rest of each bot's route and the
## creature's, with what each was doing.
func routes() -> void:
	var out := {}
	for brain in owner_match.brains:
		var points := PackedVector3Array()
		if brain.nav.active():
			for i in range(brain.nav.index, mini(brain.nav.path.size(), brain.nav.index + 12)): points.append(brain.nav.path[i])
		out[brain.seat] = {"path": points, "task": String(brain.task.get("label", "")), "kind": String(brain.task.get("kind", ""))}
	var ahead: Variant = owner_match.threat.recorded_route()
	if ahead != null: out[0] = {"path": ahead}
	stream().store_var(["r", snappedf(clock, 0.01), out])

## The whole floor as it stands: what a jump in time starts from.
func keyframe() -> void:
	stream().store_var(["k", snappedf(clock, 0.01), owner_match.snapshot()])

## Things that change without a signal of their own: stage, state, blackout,
## the code, lives, lifts, hides and the creature's mode.
func watch_changes() -> void:
	var now := {
		"stage": int(level.session.stage),
		"state": int(level.session.state),
		"blackout": bool(level.hotel.dark),
		"code": bool(level.code_entered),
		"lives": level.session.participants.duplicate(),
		"away": level.lifts.lift_away.keys().filter(func(index): return level.lifts.lift_gone(int(index))),
		"leaving": level.lifts.leaving >= 0.0,
		"execution": int(level.execution.get("seat", -1)),
	}
	now.merge(owner_match.threat.recorded_watch())
	for field in now:
		if last.has(field) and last[field] == now[field]: continue
		if last.has(field) or field in ["stage", "state"]:
			var data := {"value": now[field]}
			var told: Dictionary = owner_match.threat.recorded_mode_change() if field == "mode" else {}
			if not told.is_empty():
				data.merge(told)
				data["focus"] = now.get("focus", -1)
			event(field, data)
	last = now
	for gate in level.hotel.gates:
		if not is_instance_valid(gate): continue
		var index: int = level.hotel.doors.find(gate)
		var now_gate := [bool(gate.opened) != bool(gate.moving), bool(gate.locked)]
		var before: Array = gates_seen.get(index, [])
		if not before.is_empty():
			if before[0] != now_gate[0] and not gate.moving: event("puerta", {"door": index, "open": now_gate[0], "gate": true})
			if before[1] != now_gate[1]: event("cerrojo", {"door": index, "locked": now_gate[1]})
		gates_seen[index] = now_gate
	for index in level.hotel.hides.size():
		var occupant = level.hotel.hides[index].occupant
		var seat: int = int(occupant.slot) if is_instance_valid(occupant) and "slot" in occupant else -1
		if int(hides_seen.get(index, -1)) != seat:
			if hides_seen.has(index) or seat >= 0: event("armario", {"hide": index, "seat": seat})
			hides_seen[index] = seat

func heartbeat() -> void:
	beat_msec = Time.get_ticks_msec()
	var file := FileAccess.open(folder.path_join("heartbeat.json"), FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"wall": Time.get_unix_time_from_system(), "sim": snappedf(owner_match.clock, 0.1), "stage": int(level.session.stage), "state": int(level.session.state)}))
	file.close()

func close() -> void:
	if track != null:
		track.close()
		track = null
	if events_file != null:
		events_file.close()
		events_file = null
	heartbeat()

static func vec(point: Vector3) -> Array:
	return [snappedf(point.x, 0.01), snappedf(point.y, 0.01), snappedf(point.z, 0.01)]
