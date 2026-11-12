extends Node
## The Lurker's lies to a mind that is going (creature.hallucinations(),
## spec_f3_integration 4): she picks them herself (OWN_LIES) by where the
## listener is (kinds_here()): claws on the false ceiling over them, knocks
## running along a duct, a phone, keys, a capsule's hiss, a copier, a chair,
## a shadow behind a blind, one lamp failing, a lever, a timer ticking, the
## fans starting. Each is this machine's alone: nothing is captioned, nothing
## goes on the net, no room's light is drunk, no objective is touched, and
## none of her sounds that mean something (NEVER) is ever played. And her
## face where she is not (phantom_sight, sight_spots()): round the jamb of a
## door to a dark room, over a cubicle's partition, hanging in a ceiling
## corner. sanity.gd makes this under itself and keeps it.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const VOICE := preload("res://game/enemies/lurker/lurker_voice.gd")
const VISUAL := preload("res://game/enemies/lurker/lurker.tscn")
const POSER := preload("res://game/app/hallucinations/lurker_poser.gd")
const OWN_LIES := true
## The bone her face is looked at by, and those that must stay hidden behind
## a jamb or a partition: her body. Her arms may show, holding on to the edge.
const HEAD := "head"
const BODY_BONES := ["body", "abdomen"]
## Where her face is seen: a door this far off, a partition, a room's corner;
## and her head's height on a jamb (under the lintel), over a partition, under
## a ceiling. Each only just off the middle of the picture and in a clear line
## (phantom_sight.beside_view(), clear()), as The Locust's: never in plain view.
const PEEK_RANGE := Vector2(10.0, 35.0)
const PARTITION_RANGE := Vector2(10.0, 25.0)
const CORNER_RANGE := Vector2(8.0, 20.0)
const PEEK_HEAD := Vector2(1.7, 2.0)
const OVER_PARTITION := 0.25
const UNDER_CEILING := 0.35
const SPOTS_MOST := 6
## Her sound lies come at the hotel's pace, her faces every 40 to 90 s (the
## author's I3).
const WAIT_SCALE := 1.0
const SIGHT_REST := Vector2(40.0, 90.0)
const BASE := "res://assets/audio/sfx/lurker/"
const SFX := "res://assets/audio/sfx/office/"
## Her sounds that mean something, never a lie's (0.5.2): her warning, her
## shriek, her presence, her bite, and a station's bell. Built from BASE so
## that no script but hers names her warning's clips.
const NEVER := [BASE + "cue_0.wav", BASE + "cue_1.wav", BASE + "cue_2.wav", BASE + "cue_short_0.wav", BASE + "cue_short_1.wav", BASE + "cue_short_2.wav", BASE + "scare_0.wav", BASE + "scare_1.wav", BASE + "presence.wav", BASE + "bite_1.wav", BASE + "bite_2.wav", SFX + "tube_bell.wav"]
## How much each kind is told where it may be (4.3); `ducto` weighs more on
## planta 3 and the phone on planta 1.
const WEIGHTS := {"garras": 3.0, "ducto": 2.0, "telefono": 1.5, "maquina": 1.0, "tubo": 2.0, "fotocopiadora": 0.7, "silla": 0.7, "persiana": 1.0, "lampara": 1.5, "palanca": 1.5, "tictac": 1.5, "ventiladores": 1.5}
const DUCT_WEIGHT_HIGH := 4.0
const PHONE_WEIGHT_LOW := 2.5
const CLAW_DB := -10.0
const KNOCK_DB := -6.0
const KNOCK_SPEED := 1.6
const PHONE_DB := -8.0
const PHONE_NEAR := 4.0
const PHONE_LONGEST := 8.0
const TYPING_DB := -10.0
const HISS_DB := -8.0
const COPIER_DB := -8.0
const CHAIR_DB := -6.0
const STARTER_DB := -8.0
const LEVER_DB := -4.0
const TICK_DB := -10.0
const FANS_DB := -6.0
## The fans' lie: rising, held, fading (seconds).
const FANS_SHAPE := Vector3(2.5, 1.0, 1.5)
## The shadow behind a blind: its size, how dark, how long it takes across.
const SHADOW := Vector2(0.5, 1.4)
const SHADOW_ALPHA := 0.8
const SHADOW_TIME := 0.8
## The lamp that fails, and for how long.
const LAMP_FAIL := 1.2
var level
var rng := RandomNumberGenerator.new()
## The last 32 lies told: {kind, point, time} (tests run silent: always kept).
var told: Array = []
## What is going on of the lies told (the phone, the moving ones): updated by
## quiet().
var jobs: Array = []
var players: Array = []
var shadow_material: StandardMaterial3D
## What is found by walking (the rooms and desks in reach) kept a moment per
## listener's metre cell: tag -> [time, cell, found].
const FOUND_KEEP := 2.0
var found_memo := {}

func setup(owner_level) -> void:
	level = owner_level
	name = "LurkerHallucinations"
	rng.randomize()

func wait_scale() -> float: return WAIT_SCALE

func sight_rest() -> Vector2: return SIGHT_REST

func now() -> float: return Time.get_ticks_msec() / 1000.0

# --- Choosing -------------------------------------------------------------------

## One lie chosen by weight among those that fit here, and told: {kind,
## point}; {} when none fits.
func lie(_point: Vector3, gone: float) -> Dictionary:
	var options := choices(gone)
	if options.is_empty(): return {}
	var total := 0.0
	for kind in options: total += float(options[kind].weight)
	var roll := rng.randf() * total
	var chosen := ""
	for kind in options:
		roll -= float(options[kind].weight)
		chosen = kind
		if roll <= 0.0: break
	var point: Vector3 = tell(chosen, options[chosen])
	var entry := {"kind": chosen, "point": point, "time": now()}
	told.append(entry)
	if told.size() > 32: told.pop_front()
	return {"kind": chosen, "point": point}

## Every kind that may be told here now, by weight.
func kinds_here(gone: float) -> Dictionary:
	var out := {}
	var options := choices(gone)
	for kind in options: out[kind] = float(options[kind].weight)
	return out

## Every kind that fits here now: kind -> {weight, and what it is told with}.
func choices(_gone: float) -> Dictionary:
	var out := {}
	var body: Node3D = level.player
	var ear: Vector3 = body.camera.global_position
	var here := FLOOR.room_at(level.manifest.rooms, body.global_position)
	var wing := FLOOR.planta_of(body.global_position.y)
	var protected: bool = level.point_protected(body.global_position)
	var air = level.objective(&"air")
	var power = level.objective(&"power")
	var fans_still: bool = air == null or float(air.get("spin")) == 0.0
	if not protected and not here.is_empty() and OFFICE.false_ceiling(here):
		out["garras"] = {"weight": WEIGHTS.garras, "room": here}
	if not protected and (wing != 2 or fans_still):
		var path := duct_path(ear, wing)
		if not path.is_empty(): out["ducto"] = {"weight": DUCT_WEIGHT_HIGH if wing == 2 else WEIGHTS.ducto, "path": path}
	var phone := room_near(ear, wing, 6.0, 20.0, func(r): return OFFICE.has_phone(r) and int(r.id) != int(here.get("id", -1)), "telefono")
	if not phone.is_empty(): out["telefono"] = {"weight": PHONE_WEIGHT_LOW if wing == 0 else WEIGHTS.telefono, "point": FLOOR.position_of(phone) + Vector3(0, 0.75, 0)}
	var keys := room_near(ear, wing, 6.0, 15.0, func(r): return OFFICE.has_typewriter(r), "maquina")
	if not keys.is_empty(): out["maquina"] = {"weight": WEIGHTS.maquina, "point": FLOOR.position_of(keys) + Vector3(0, 0.75, 0)}
	if wing == 0:
		var tube := tube_run(ear)
		if not tube.is_empty(): out["tubo"] = {"weight": WEIGHTS.tubo, "path": tube}
	var copier := room_near(ear, wing, 6.0, 20.0, func(r): return OFFICE.has_copier(r), "fotocopiadora")
	if not copier.is_empty(): out["fotocopiadora"] = {"weight": WEIGHTS.fotocopiadora, "point": FLOOR.position_of(copier) + Vector3(0, 1.0, 0)}
	var chair := desk_near(ear, wing, 5.0, 15.0)
	if chair != Vector3.INF: out["silla"] = {"weight": WEIGHTS.silla, "point": chair}
	var pane := pane_near(body.camera)
	if not pane.is_empty(): out["persiana"] = {"weight": WEIGHTS.persiana, "pane": pane}
	var lamp := lamp_near(body.camera, wing)
	if not lamp.is_empty(): out["lampara"] = {"weight": WEIGHTS.lampara, "lamp": lamp}
	if wing == 1 and power != null and int(power.get("red")) == 0:
		var board: Dictionary = level.manifest.get("power", {}).get("board", {})
		if board.has("point"): out["palanca"] = {"weight": WEIGHTS.palanca, "point": v3(board.point) + Vector3(0, 1.2, 0)}
		var tick := tick_spot(ear)
		if tick != Vector3.INF: out["tictac"] = {"weight": WEIGHTS.tictac, "point": tick}
	if wing == 2 and air != null and fans_still:
		var unit: Dictionary = level.manifest.get("air", {}).get("unit", {})
		if unit.has("point"): out["ventiladores"] = {"weight": WEIGHTS.ventiladores, "point": v3(unit.point) + Vector3(0, 1.2, 0)}
	return out

static func v3(p) -> Vector3: return Vector3(float(p[0]), float(p[1]), float(p[2]))

## The walking metres from the listener to a point (world_audio's walked
## route), INF when there is no way.
func walk_metres(from: Vector3, to: Vector3) -> float:
	var path: PackedVector3Array = level.world_audio.walked_route(from, to)
	if path.size() < 2: return INF
	var metres := 0.0
	for i in range(1, path.size()): metres += path[i].distance_to(path[i - 1])
	return metres

## A room of the listener's planta `low` to `high` walking metres off that
## `fits`, picked at random among those that do; {} when none.
func room_near(ear: Vector3, wing: int, low: float, high: float, fits: Callable, tag: String) -> Dictionary:
	var found = kept(tag, ear)
	if found == null:
		found = []
		for room in level.manifest.rooms:
			if FLOOR.is_void(room) or int(room.get("wing", -1)) != wing or not fits.call(room): continue
			var at := FLOOR.position_of(room)
			var straight := Vector2(at.x - ear.x, at.z - ear.z).length()
			if straight > high: continue
			var walked := walk_metres(ear, at)
			if walked >= low and walked <= high: found.append(room)
		keep(tag, ear, found)
	return found[rng.randi_range(0, found.size() - 1)] if not found.is_empty() else {}

## What was found for `tag` from this metre cell within FOUND_KEEP; null when
## nothing is kept.
func kept(tag: String, ear: Vector3):
	var entry = found_memo.get(tag)
	if entry == null or now() - float(entry[0]) > FOUND_KEEP or entry[1] != Vector3i(ear.floor()): return null
	return entry[2]

func keep(tag: String, ear: Vector3, found: Array) -> void:
	found_memo[tag] = [now(), Vector3i(ear.floor()), found]

## A desk of a room 5 to 15 walking metres off, at a chair's height.
func desk_near(ear: Vector3, wing: int, low: float, high: float) -> Vector3:
	var found = kept("silla", ear)
	if found == null:
		found = []
		for room in level.manifest.rooms:
			if FLOOR.is_void(room) or int(room.get("wing", -1)) != wing: continue
			var at := FLOOR.position_of(room)
			if Vector2(at.x - ear.x, at.z - ear.z).length() > high: continue
			for item in room.get("furniture", []):
				if not String(item.kind) in ["desk", "desk_pair", "desk_island", "desk_island_6", "office_suite", "exec_desk", "secretary_desk", "work_desk", "air_desk", "reader_table"]: continue
				var spot := at + Vector3(float(item.at[0]), 0.4, float(item.at[1]))
				var walked := walk_metres(ear, spot)
				if walked >= low and walked <= high: found.append(spot)
				break
		keep("silla", ear, found)
	return found[rng.randi_range(0, found.size() - 1)] if not found.is_empty() else Vector3.INF

## A duct path of 3 to 6 edges on the listener's planta, starting within 12 m
## of them, nowhere near where she really is in the ducts.
func duct_path(ear: Vector3, wing: int) -> PackedInt32Array:
	var creature = level.creature
	var ducts = creature.get("ducts") if is_instance_valid(creature) else null
	if ducts == null: return PackedInt32Array()
	var starts: Array = []
	for n in ducts.nodes.size():
		if ducts.node_wings[n] == wing and Vector2(ducts.nodes[n].x - ear.x, ducts.nodes[n].z - ear.z).length() <= 12.0: starts.append(n)
	if starts.is_empty(): return PackedInt32Array()
	var her: Vector3 = creature.view().duct_point if bool(creature.view().in_duct) else Vector3.INF
	for attempt in 6:
		var path := PackedInt32Array([int(starts[rng.randi_range(0, starts.size() - 1)])])
		var length := rng.randi_range(3, 6)
		while path.size() <= length:
			var next: Array = []
			for link in ducts.adjacency[path[path.size() - 1]]:
				if not path.has(int(link[0])) and ducts.node_wings[int(link[0])] == wing: next.append(int(link[0]))
			if next.is_empty(): break
			path.append(int(next[rng.randi_range(0, next.size() - 1)]))
		if path.size() < 4: continue
		var near_her := false
		for n in path:
			if her != Vector3.INF and ducts.nodes[n].distance_to(her) < 3.0: near_her = true
		if not near_her: return path
	return PackedInt32Array()

## A tube from the hub to a station whose nearest point is 6 to 20 m off.
func tube_run(ear: Vector3) -> Array:
	var files = level.objective(&"files")
	if files == null or not files.has_method("tube_path") or files.get("station_exits") == null: return []
	var runs: Array = []
	for exit in files.station_exits:
		var path: Array = files.tube_path(int(exit.node))
		if path.size() < 2: continue
		var nearest := INF
		for p in path: nearest = minf(nearest, (p as Vector3).distance_to(ear))
		if nearest >= 6.0 and nearest <= 20.0: runs.append(path)
	return runs[rng.randi_range(0, runs.size() - 1)] if not runs.is_empty() else []

## A glazed pane 4 to 12 m off, within 50 degrees of the view, whose far side
## is a room not lit: {sheet, far (the side away from the camera), width}.
func pane_near(camera: Camera3D) -> Dictionary:
	var panes = level.hotel.get("panes")
	if panes == null: return {}
	var eye := camera.global_position
	var forward := -camera.global_basis.z
	var found: Array = []
	for sheet in panes:
		if not is_instance_valid(sheet): continue
		var centre: Vector3 = sheet.global_position
		var to := centre - eye
		if to.length() < 4.0 or to.length() > 12.0 or forward.angle_to(to) > deg_to_rad(50.0): continue
		var normal: Vector3 = sheet.global_basis.z.normalized()
		var far: Vector3 = normal if normal.dot(to) > 0.0 else -normal
		var behind := FLOOR.room_at(level.manifest.rooms, centre + far * 0.6)
		if behind.is_empty() or level.hotel.lit(int(behind.id)): continue
		found.append({"sheet": sheet, "far": far, "width": float((sheet.mesh as QuadMesh).size.x)})
	return found[rng.randi_range(0, found.size() - 1)] if not found.is_empty() else {}

## A lit room of the listener's planta within 15 m with two or more troffers,
## the one that will fail in view: {room, seed, point}.
func lamp_near(camera: Camera3D, wing: int) -> Dictionary:
	if not level.hotel.has_method("flicker_one"): return {}
	var eye := camera.global_position
	var forward := -camera.global_basis.z
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != wing or not level.hotel.lit(int(room.id)): continue
		var lamps: Array = OFFICE.troffers(room)
		if lamps.size() < 2: continue
		var seed_value := rng.randi()
		var lamp: Dictionary = lamps[posmod(seed_value, lamps.size())]
		var point := Vector3(lamp.centre.x, float(room.get("py", 0.0)) + float(room.height), lamp.centre.y)
		var to := point - eye
		if to.length() > 15.0 or forward.dot(to.normalized()) < 0.5: continue
		return {"room": int(room.id), "seed": seed_value, "point": point}
	return {}

## A corridor of planta 2, 6 to 20 m off and 6 m or more from every timer
## button: where a timer that is not there ticks.
func tick_spot(ear: Vector3) -> Vector3:
	var buttons: Array = level.manifest.get("power", {}).get("timers", [])
	var spots: Array = []
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != 1 or not bool(room.get("corridor", false)): continue
		var at := FLOOR.position_of(room) + Vector3(0, 1.2, 0)
		var gap := at.distance_to(ear)
		if gap < 6.0 or gap > 20.0: continue
		if buttons.any(func(b): return v3(b.point).distance_to(at) < 6.0): continue
		spots.append(at)
	return spots[rng.randi_range(0, spots.size() - 1)] if not spots.is_empty() else Vector3.INF

# --- Telling ---------------------------------------------------------------------

## Tells a kind with what choices() found for it; where it is told from.
func tell(kind: String, with: Dictionary) -> Vector3:
	var on: bool = level.world_audio.enabled
	match kind:
		"garras":
			return claws(level.player.global_position)
		"ducto":
			var ducts = level.creature.ducts
			var points := PackedVector3Array()
			for n in with.path: points.append(ducts.nodes[n])
			jobs.append({"kind": "ducto", "points": points, "nodes": with.path, "at": 0.0, "next": 0.0})
			return points[0]
		"telefono":
			var voice = loop_long(SFX + "phone_ring.wav", with.point, PHONE_DB, 0.0) if on else null
			jobs.append({"kind": "telefono", "voice": voice, "point": with.point, "left": PHONE_LONGEST})
			return with.point
		"maquina":
			if on: loop_long(SFX + "typing.wav", with.point, TYPING_DB, rng.randf_range(2.0, 3.0))
			return with.point
		"tubo":
			var path: Array = with.path
			var voice = loop_long(SFX + "tube_hiss.wav", path[0], HISS_DB, 0.0) if on else null
			var length := 0.0
			for i in range(1, path.size()): length += (path[i] as Vector3).distance_to(path[i - 1])
			jobs.append({"kind": "tubo", "voice": voice, "path": path, "run": 0.0, "stop": length * rng.randf_range(0.6, 0.8)})
			return path[0]
		"fotocopiadora":
			say(SFX + "copier.wav", with.point, COPIER_DB)
			return with.point
		"silla":
			say(SFX + "chair_roll.wav", with.point, CHAIR_DB)
			return with.point
		"persiana":
			return shadow(with.pane)
		"lampara":
			level.hotel.flicker_one(int(with.lamp.room), LAMP_FAIL, int(with.lamp.seed))
			say(SFX + "starter.wav", with.lamp.point, STARTER_DB)
			return with.lamp.point
		"palanca":
			say(SFX + "lever_%d.wav" % rng.randi_range(1, 3), with.point, LEVER_DB)
			return with.point
		"tictac":
			if on: loop_long(SFX + "tick.wav", with.point, TICK_DB, rng.randf_range(3.0, 5.0))
			return with.point
		"ventiladores":
			var voice = loop_long(SFX + "fans.wav", with.point, -80.0, 0.0) if on else null
			jobs.append({"kind": "ventiladores", "voice": voice, "t": 0.0})
			return with.point
	return Vector3.INF

## 3 to 6 claws on the ceiling within 1.5 m over `point` in 1.2 s, and four
## times in ten a tile shifted near by, with its dust.
func claws(point: Vector3) -> Vector3:
	var room := FLOOR.room_at(level.manifest.rooms, point)
	var top: float = float(room.get("py", 0.0)) + float(room.get("height", 2.95)) - 0.02
	var over := Vector3(point.x, top, point.z)
	for i in rng.randi_range(3, 6):
		var at := over + Vector3(rng.randf_range(-1.5, 1.5), 0, rng.randf_range(-1.5, 1.5))
		var file := BASE + "tile_%d.wav" % rng.randi_range(1, 6)
		later(rng.randf_range(0.0, 1.2), func(): say(file, at, CLAW_DB))
	if rng.randf() < 0.4:
		var tile := over + Vector3(rng.randf_range(-2.0, 2.0), 0, rng.randf_range(-2.0, 2.0))
		var creak := BASE + "tile_creak_%d.wav" % rng.randi_range(1, 3)
		var dust := BASE + "dust_%d.wav" % rng.randi_range(1, 2)
		later(1.2, func():
			say(creak, tile, CLAW_DB)
			if level.world_audio.enabled: VOICE.dust_puff(level, tile))
		later(1.35, func(): say(dust, tile, CLAW_DB - 6.0))
	return over

func later(seconds: float, what: Callable) -> void:
	get_tree().create_timer(seconds).timeout.connect(func(): if is_instance_valid(self): what.call())

## A shadow sliding behind the blind of a pane, across it, in SHADOW_TIME.
func shadow(pane: Dictionary) -> Vector3:
	var sheet: Node3D = pane.sheet
	var start: Vector3 = sheet.global_position + (pane.far as Vector3) * 0.15
	if not level.world_audio.enabled: return start
	if shadow_material == null:
		shadow_material = StandardMaterial3D.new()
		shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var soft := GradientTexture2D.new()
		soft.fill = GradientTexture2D.FILL_SQUARE
		soft.fill_from = Vector2(0.5, 0.5)
		soft.fill_to = Vector2(1.0, 0.5)
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0, 0, 0, SHADOW_ALPHA))
		ramp.set_color(1, Color(0, 0, 0, 0))
		ramp.add_point(0.6, Color(0, 0, 0, SHADOW_ALPHA))
		soft.gradient = ramp
		shadow_material.albedo_texture = soft
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = SHADOW
	mesh.material = shadow_material
	quad.mesh = mesh
	add_child(quad)
	quad.global_basis = sheet.global_basis
	var across: Vector3 = sheet.global_basis.x.normalized()
	var half := float(pane.width) * 0.5
	jobs.append({"kind": "persiana", "quad": quad, "from": start - across * half, "to": start + across * half, "t": 0.0})
	quad.global_position = start - across * half
	return start

## A routed sound of the lie, never one of NEVER.
func say(path: String, point: Vector3, gain: float) -> void:
	if NEVER.has(path):
		push_error("lurker_hallucinations: %s is never a lie" % path)
		return
	if level.world_audio.enabled: level.world_audio.play_at(path, point, gain)

## A looped recording held at a point (play_long, never following the
## listener), for `seconds` (0: until stopped).
func loop_long(path: String, point: Vector3, gain: float, seconds: float):
	if NEVER.has(path):
		push_error("lurker_hallucinations: %s is never a lie" % path)
		return null
	var voice = level.world_audio.play_long(path, point, gain, RID(), false, seconds)
	if voice == null: return null
	voice.stream = level.world_audio.loop_stream(voice.stream)
	voice.play()
	return voice

# --- What goes on ------------------------------------------------------------------

## Every frame (sanity's phantom_quiet): the phone stops when the listener
## comes near it, the moving lies move.
func quiet(delta: float) -> void:
	for job in jobs.duplicate():
		if step(job, delta): jobs.erase(job)

## One lie going on, one frame of it; true when it is over.
func step(job: Dictionary, delta: float) -> bool:
	match String(job.kind):
		"telefono":
			job.left = float(job.left) - delta
			if float(job.left) > 0.0 and level.player.global_position.distance_to(job.point) > PHONE_NEAR: return false
			level.world_audio.stop_long(job.voice)
			return true
		"ducto":
			var points: PackedVector3Array = job.points
			job.at = float(job.at) + delta * KNOCK_SPEED
			job.next = float(job.next) - delta
			var total := 0.0
			for i in range(1, points.size()): total += points[i].distance_to(points[i - 1])
			if float(job.at) >= total: return true
			if float(job.next) <= 0.0:
				job.next = 0.5 / KNOCK_SPEED
				knock(points, job.nodes, float(job.at))
			return false
		"tubo":
			job.run = float(job.run) + delta * float(level.objective(&"files").CAPSULE_SPEED)
			if float(job.run) >= float(job.stop):
				level.world_audio.stop_long(job.voice)
				return true
			var at: Vector3 = level.objective(&"files").along(job.path, float(job.run))
			for cue in level.world_audio.long_cues:
				if cue.player == job.voice: cue.point = at
			return false
		"ventiladores":
			job.t = float(job.t) + delta
			var t := float(job.t)
			var shape := FANS_SHAPE
			if t >= shape.x + shape.y + shape.z:
				level.world_audio.stop_long(job.voice)
				return true
			var up := clampf(t / shape.x, 0.0, 1.0) if t < shape.x + shape.y else clampf(1.0 - (t - shape.x - shape.y) / shape.z, 0.0, 1.0)
			for cue in level.world_audio.long_cues:
				if cue.player == job.voice: cue.gain = FANS_DB + linear_to_db(maxf(up, 0.001))
			return false
		"persiana":
			job.t = float(job.t) + delta
			var quad: MeshInstance3D = job.quad
			if float(job.t) >= SHADOW_TIME or not is_instance_valid(quad):
				if is_instance_valid(quad): quad.queue_free()
				return true
			quad.global_position = (job.from as Vector3).lerp(job.to, float(job.t) / SHADOW_TIME)
			return false
	return true

## A knock `metres` along a duct lie, out of the grilles as one of hers is.
func knock(points: PackedVector3Array, nodes: PackedInt32Array, metres: float) -> void:
	var left := metres
	var at := points[0]
	var near := int(nodes[0])
	for i in range(1, points.size()):
		var piece := points[i].distance_to(points[i - 1])
		if left <= piece:
			at = points[i - 1].lerp(points[i], left / maxf(piece, 0.001))
			near = int(nodes[i - 1]) if left < piece * 0.5 else int(nodes[i])
			break
		left -= piece
	var audio = level.world_audio
	if not audio.enabled: return
	var ducts = level.creature.ducts
	var listener: Vector3 = audio.listener_position()
	if level.point_protected(listener): return
	var route: Dictionary = ducts.sound_route(at, near, listener, func(p): return int(FLOOR.room_at(level.manifest.rooms, p).get("id", -1)), audio)
	if not bool(route.get("audible", false)): return
	route["bus"] = audio.DUCT_BUS
	players = players.filter(func(p): return is_instance_valid(p))
	var player := AudioStreamPlayer3D.new()
	player.stream = load(BASE + "knock_%d.wav" % rng.randi_range(1, 8))
	player.unit_size = 6.0
	player.max_distance = 40.0
	player.area_mask = audio.ACOUSTIC_MASK
	audio.add_child(player)
	audio.apply_route(player, route, KNOCK_DB, "Threat", true)
	player.finished.connect(player.queue_free)
	players.append(player)
	player.play()

func _exit_tree() -> void:
	for job in jobs:
		if job.has("voice") and job.voice != null: level.world_audio.stop_long(job.voice)
		if job.has("quad") and is_instance_valid(job.quad): job.quad.queue_free()
	jobs = []

# --- Her face where she is not --------------------------------------------------------

## Her model for phantom_sight, under `host`: her hands still, her head on
## whoever looks.
func sight_model(host: Node) -> Node3D:
	var model: Node3D = VISUAL.instantiate()
	model.name = "Phantom"
	host.add_child(model)
	model.crawling = false
	model.look_point = Vector3.INF
	return model

func sight_poser(model: Node3D):
	return POSER.new(model)

## Up to SPOTS_MOST places her face may be seen from `camera`, shuffled:
## {kind ("peek", "partition" or "corner"), point (her origin), up (the
## surface she holds), facing (where her body points; none: the camera),
## side (the lean), head (her head's height, or where it is)}. She holds on as she does: to
## the far face of the wall beside a jamb, her head out into the doorway; to
## the back of a partition, head up over its top; upside down in a corner.
## phantom_sight.place_spot() tries them.
func sight_spots(sight, camera: Camera3D) -> Array:
	var eye := camera.global_position
	var wing := FLOOR.planta_of(eye.y)
	var base := FLOOR.planta_y(wing)
	var spots: Array = []
	for door in level.hotel.doors:
		if not is_instance_valid(door) or not door.opened or door.moving or door.locked: continue
		var gap: float = door.doorway.distance_to(eye)
		if gap < PEEK_RANGE.x or gap > PEEK_RANGE.y or FLOOR.planta_of(door.doorway.y) != wing: continue
		var across: Vector3 = Basis(Vector3.UP, door.closed_rotation) * Vector3(0, 0, 1)
		if across.dot(door.doorway - eye) < 0.0: across = -across
		var far := FLOOR.room_at(level.manifest.rooms, door.doorway + across * 0.8)
		if far.is_empty() or level.hotel.lit(int(far.id)): continue
		var along := Vector3.UP.cross(across).normalized()
		var jamb: Vector3 = door.doorway + Vector3(0, base + PEEK_HEAD.x - door.doorway.y, 0)
		if not sight.beside_view(jamb, camera) or not sight.clear(eye, jamb): continue
		# Either side of the doorway, her body on the far face of the wall, her
		# head just in the opening.
		for side in [1.0, -1.0]:
			var point: Vector3 = door.doorway + across * 0.2 + along * side * (FLOOR.PORTAL * 0.5 + 0.35)
			point.y = base
			var head: Vector3 = door.doorway + across * 0.15 + along * side * (FLOOR.PORTAL * 0.5 - 0.12)
			head.y = base + rng.randf_range(PEEK_HEAD.x, PEEK_HEAD.y)
			spots.append({"kind": "peek", "point": point, "up": across, "facing": -along * side, "side": -side, "head": head})
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != wing: continue
		var centre := FLOOR.position_of(room)
		var straight := Vector2(centre.x - eye.x, centre.z - eye.z).length()
		if straight > maxf(PARTITION_RANGE.y, CORNER_RANGE.y) + 10.0: continue
		for item in room.get("furniture", []):
			if String(item.kind) != "partition": continue
			var at := centre + Vector3(float(item.at[0]), 0, float(item.at[1]))
			var gap := at.distance_to(eye)
			var over := at + Vector3(0, float(item.extra.height) + OVER_PARTITION, 0)
			if gap < PARTITION_RANGE.x or gap > PARTITION_RANGE.y or not sight.beside_view(over, camera) or not sight.clear(eye, over): continue
			var away := Vector3(at.x - eye.x, 0, at.z - eye.z).normalized()
			spots.append({"kind": "partition", "point": at + away * 0.12, "up": away, "facing": Vector3.UP, "side": 1.0, "head": base + float(item.extra.height) + OVER_PARTITION})
		var top: float = float(room.get("py", 0.0)) + float(room.height)
		var half := Vector2(float(room.span_x) * 0.5 - 0.4, float(room.span_z) * 0.5 - 0.4)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var at := Vector3(centre.x + corner.x * half.x, top, centre.z + corner.y * half.y)
			var gap := at.distance_to(eye)
			var under := at - Vector3(0, UNDER_CEILING, 0)
			if gap < CORNER_RANGE.x or gap > CORNER_RANGE.y or not sight.beside_view(under, camera) or not sight.clear(eye, under): continue
			spots.append({"kind": "corner", "point": at, "up": Vector3.DOWN, "side": 1.0, "head": top - UNDER_CEILING})
	shuffle(spots)
	return spots.slice(0, SPOTS_MOST)

## Shuffled with her own rng (tests seed it).
func shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var kept = list[i]
		list[i] = list[j]
		list[j] = kept

# --- The base API ---------------------------------------------------------------------

## Sanity's voice branch (only reached if OWN_LIES were false): claws over
## `point`. Never a voice.
func false_call(point: Vector3) -> void:
	claws(point)

## A duct lie started near the listener; false when there is none to tell.
func walk_past() -> bool:
	var body: Node3D = level.player
	var path := duct_path(body.camera.global_position, FLOOR.planta_of(body.global_position.y))
	if path.is_empty() or level.point_protected(body.global_position): return false
	tell("ducto", {"path": path})
	return true

## Where the duct lie going on began; Vector3.INF when none is.
func walk_start() -> Vector3:
	for job in jobs:
		if String(job.kind) == "ducto": return (job.points as PackedVector3Array)[0]
	return Vector3.INF
