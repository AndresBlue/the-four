extends "res://game/enemies/creature.gd"
## The Lurker, the creature of the offices (docs/OFICINAS.md 4 and 11.4; the
## body that is seen is lurker.tscn, docs/LURKER.md). In this step she is never
## on the floor of a room but for a leap: she goes over the ceilings, down the
## band over a door head and the walls of the tall rooms, held up between the
## shelves of an archive, and through her ducts, where she is heard and not
## seen. She never opens a door. What she wants is the brain's (2b); how she
## gets there is lurker_motion.gd's (spec_f2_movement 8).
const SHELL := preload("res://game/enemies/lurker/lurker_shell.gd")
const DUCTS := preload("res://game/enemies/lurker/duct_graph.gd")
const ROUTES := preload("res://game/enemies/lurker/lurker_routes.gd")
const MOTION := preload("res://game/enemies/lurker/lurker_motion.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const SENSES := preload("res://game/enemies/lurker/lurker_senses.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const WARNING := preload("res://game/enemies/lurker/lurker_warning.gd")
const VOICE := preload("res://game/enemies/lurker/lurker_voice.gd")
## Her sound out of the plenum, through the tile under her: this much quieter
## and duller than in the room (spec_f3_integration 3.5).
const PLENUM_LOSS := -6.0
const PLENUM_CUTOFF := 1800.0
## Her duct routes kept this long per node and listener's 2 m cell.
const ROUTE_MEMO := 0.25
## Her claws outside the car, every so often, while a survivor rides between
## plantas and she drops through the ducts (2.3).
const CAR_SCRATCH := Vector2(0.6, 1.3)
## Her shriek frightens whoever is this near with a clear line to it (3.7).
const SHRIEK_FRIGHT := 12.0
## A warning played here (the bots react to it, 7.1).
signal cue_played(seat: int, cue_id: int, point: Vector3)
## Her presence over a locker and her aura (game/audio/creature_audio_profile.gd).
@export var sound_profile: Resource = preload("res://game/audio/profiles/lurker.tres")
const WORDS: Array[StringName] = [&"roam", &"investigate", &"search", &"alert", &"chase", &"strike", &"recover", &"capture", &"open", &"wait", &"idle", &"stalk", &"withdraw"]
const CLIPS := ["idle", "crawl", "crawl_fast", "vent_crawl", "retreat", "loom", "scare", "peek"]
const PACK_SIZE := 10
## TRAY and BAND: the patch kind (neither: a channel), for visual.cling.
enum Flag { IN_DUCT = 1, HIDDEN = 2, SURFACE = 4, DRAINING = 8, CUE = 16, DROP = 32, ARRIVING = 64, TRAY = 128, BAND = 256 }
## Her face in her frame: the offset shell.cue_pose() uses.
const FACE_OFFSET := SHELL.FACE_OFFSET
## How hard her hands hold on, by what she holds (the bench's 0.6 held up).
const CLING_TRAY := 0.3
const CLING_BAND := 0.5
const CLING_CHANNEL := 0.6
## Her body's layer, as The Locust's: sight passes, survivors do not.
const BODY_LAYER := 32
## Rooms she makes her den in: this share of the walk from the planta's entry.
const DEN_BAND := Vector2(0.5, 0.8)

var level
var shell
var ducts
var routes
var motion
var visual: Node3D
var body_shape: CollisionShape3D
var shape_rest := Vector3.ZERO
## What she is doing (2b sets it), and the clip she shows.
var word: StringName = &"roam"
var clip := 0
var shown_clip := -1
var draining := false
## 2b: the back cue is running.
var cue := false
var tuning := {}
var duct_speed := 1.6
var was_hidden := false
var net_states: Array = []
var net_clock := 0.0
var net_jump := -1
var net_flags := 0
var net_look := Vector3.INF
var net_near := -1
## What is heard of her (lurker_voice.gd).
var voice
var car_clock := 0.0
var route_memo := {}
var was_in_duct := false

func kind_id() -> StringName: return &"lurker"

## Only her ducts: no lifts, no sets, no shriek; no lockers (the author,
## M12: "no abre taquillas").
func can(ability: StringName) -> bool: return ability == &"ducts"

func tune(profile: Dictionary) -> void:
	tuning = profile
	duct_speed = float(profile.get("duct_speed", 1.6))
	drain_reach = float(profile.get("drain_reach", drain_reach))
	if routes != null: routes.duct_speed = duct_speed
	if brain != null: brain.tune(profile)
	if senses != null: senses.tune(profile)

func activity() -> StringName: return word

func mode_name() -> String: return brain.state_name() if brain != null and control == "ai" else "ronda"

func eye_point() -> Vector3: return global_transform * FACE_OFFSET

func face_point() -> Vector3: return eye_point()

func gaze() -> Vector3:
	if visual != null and visual.look_point != Vector3.INF: return visual.look_point - eye_point()
	return global_basis.z

func travel_metres(room_id: int) -> Dictionary:
	return routes.travel_metres(room_id) if routes != null else {}

func in_transit() -> bool:
	var v := view()
	return bool(v.drop) or bool(v.arriving)

func transit_phase() -> StringName:
	return motion.transit_phase() if control == "ai" and motion != null else &""

func hushed() -> bool: return bool(view().drop)

func _ready() -> void:
	visual = get_node_or_null("Visual")
	voice = VOICE.new()
	voice.name = "Voice"
	add_child(voice)
	if level != null:
		voice.setup(self)
		if is_instance_valid(level.get("world_audio")) and level.world_audio.has_method("ensure_duct_bus"): level.world_audio.ensure_duct_bus()
	if visual != null and visual.has_signal("footfall"): visual.footfall.connect(voice.footfall)
	body_shape = get_node_or_null("BodyShape")
	if body_shape != null: shape_rest = body_shape.position
	if level != null: rng.seed = hash([int(level.manifest.get("seed", 0)), "lurker"])
	arrive()

func _exit_tree() -> void:
	if routes != null: routes.teardown()

## Her floor worked out from the manifest: the shell, her ducts, her routes
## (only the machine that moves her watches doors) and her motion.
func arrive() -> void:
	if level == null: return
	shell = SHELL.build(level.manifest)
	if shell == null:
		push_error("lurker: no shell on this floor")
		set_physics_process(false)
		return
	ducts = DUCTS.of(level.manifest)
	if routes != null: routes.teardown()
	routes = ROUTES.new()
	routes.duct_speed = duct_speed
	routes.setup(level, shell, ducts, control == "ai")
	motion = MOTION.new()
	motion.setup(shell, routes, ducts, level)
	motion.rng.seed = rng.seed
	motion.clearance = clearance
	motion.busy = func() -> bool: return is_engaged() or is_hunting() or cue
	motion.bodies_ahead = bodies_ahead
	motion.left_behind = left_behind
	think_setup()
	var stage := int(level.session.stage) if level.get("session") != null else 1
	var den := den_point(stage)
	if den != Vector3.INF: teleport(den, 0.0, &"den")

func set_control(kind: String) -> void:
	var was := control
	control = kind
	if was != kind and is_inside_tree(): arrive()

# --- What the motion asks of the world ---------------------------------------------

## The ray down (7.3 step 3): the most she may hang over what is under her.
func clearance(at: Vector3, s) -> float:
	var tray: Dictionary = shell.patches[s.patch]
	var py := float(shell.rooms[int(tray.room)].get("py", 0.0))
	var query := PhysicsRayQueryParameters3D.create(at, Vector3(at.x, py - 0.2, at.z), MOTION.RAY_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var hit_y: float = (hit.position as Vector3).y if not hit.is_empty() else py
	return float(tray.y) - hit_y - MOTION.BODY_DEPTH - MOTION.HEAD_CLEAR

## Metres to the first survivor body ahead along a line (the visible duct,
## or her way at head height), INF none.
func bodies_ahead(from: Vector3, dir: Vector3, reach: float) -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	query.shape = sphere
	query.collision_mask = 4
	query.exclude = [get_rid()]
	query.motion = dir.normalized() * reach
	query.transform = Transform3D(Basis(), from)
	var cast := get_world_3d().direct_space_state.cast_motion(query)
	if cast.is_empty() or float(cast[0]) >= 1.0: return INF
	return float(cast[0]) * reach

## Somebody alive is still on her planta (M10: she goes after them first).
## (hotel_main.survivor_active(): alive, not in a lobby, not riding).
func left_behind() -> bool:
	if level == null or not level.has_method("survivors"): return false
	var mine := FLOOR.planta_of(global_position.y)
	for body in level.survivors():
		if not is_instance_valid(body) or FLOOR.planta_of(body.global_position.y) != mine: continue
		if not level.has_method("survivor_active") or level.survivor_active(body): return true
	return false

# --- Placement ------------------------------------------------------------------------

func teleport(point: Vector3, yaw: float, reason := &"") -> void:
	var heading := global_basis.z if is_nan(yaw) else Vector3(-sin(yaw), 0, -cos(yaw))
	if motion != null: motion.place_at(point, heading, reason if reason != &"" else &"teleport")
	velocity = Vector3.ZERO
	forget_journey(point, reason)
	apply_motion()

func forget_journey(_point: Vector3, _reason: StringName) -> void:
	if brain != null and not warning.active.is_empty(): warning.cancel(brain.clock, "movida")
	if motion != null:
		motion.clear_legs()
		motion.transit = {}
		motion.pending_wing = -1
	net_states.clear()

func relocate(point: Vector3, rest: float) -> void:
	if brain != null: brain.forget_all(rest)
	undrain()
	if motion != null:
		motion.place_at(point, global_basis.z, &"relocate")
		motion.hold()
	grace = maxf(grace, rest)
	apply_motion()

func follow_to_planta(stage: int, _fresh := false) -> void:
	if motion != null: motion.follow_to_planta(stage - 1)

## Her den on a stage's planta: on the third, the air room (the author, M9:
## "su nido"); else a room between half and four fifths of the walk from the
## entry, drawn from the floor's seed. Its tray point clear of the lamps.
func den_room(stage: int) -> int:
	if shell == null: return -1
	var manifest: Dictionary = level.manifest
	var wing := stage - 1
	var air: Dictionary = manifest.get("air", {})
	if wing == 2 and shell.tray_of.has(int(air.get("room", -1))): return int(air.room)
	var walk := FLOOR.route_metres(manifest, FLOOR.entry_of(manifest, wing))
	var top := 0.0
	for r in walk:
		if shell.tray_of.has(int(r)) and int(manifest.rooms[int(r)].get("wing", -1)) == wing: top = maxf(top, float(walk[r]))
	var picks: Array = []
	for r in walk:
		if not shell.tray_of.has(int(r)) or int(manifest.rooms[int(r)].get("wing", -1)) != wing or top <= 0.0: continue
		var share := float(walk[r]) / top
		if share >= DEN_BAND.x and share <= DEN_BAND.y: picks.append(int(r))
	if picks.is_empty(): return -1
	picks.sort()
	var draw := RandomNumberGenerator.new()
	draw.seed = hash([int(manifest.get("seed", 0)), "lurker_den", stage])
	return int(picks[draw.randi_range(0, picks.size() - 1)])

func den_point(stage: int) -> Vector3:
	var r := den_room(stage)
	if r < 0: return Vector3.INF
	var room: Dictionary = level.manifest.rooms[r]
	var p: Vector2 = shell.clear_point(r, float(room.px), float(room.pz))
	return shell.anchor_of(shell.tray_state(r, p.x, p.y, SHELL.DEFAULT_HANG))

func start_room(stage: int) -> int: return den_room(stage)

# --- Kept and given back ---------------------------------------------------------------

func save_state() -> Dictionary:
	var wing_goal := -1
	if motion != null:
		wing_goal = int(motion.transit.get("wing", motion.pending_wing))
	var hang: float = motion.state.hang if motion != null and motion.surface() else SHELL.DEFAULT_HANG
	# Whom she leaves be, and for how long more (spec_f3_integration 2.7).
	var calm := {}
	if brain != null:
		for seat in brain.spurned:
			var left: float = float(brain.spurned[seat]) - float(brain.clock)
			if left > 0.0: calm[int(seat)] = left
	return {"at": global_position, "heading": global_basis.z, "hang": hang, "in_duct": motion != null and motion.in_duct, "near": motion.near_node if motion != null else -1, "wing_goal": wing_goal, "calm": calm}

func restore_state(data: Dictionary, rest: float) -> void:
	if motion == null: return
	undrain()
	if brain != null:
		brain.forget_all(rest)
		var calm: Dictionary = data.get("calm", {})
		for seat in calm: brain.spurned[int(seat)] = brain.clock + float(calm[seat])
	grace = maxf(grace, rest)
	var wing_goal := int(data.get("wing_goal", -1))
	if wing_goal >= 0:
		if motion.busy.is_valid() and bool(motion.busy.call()):
			motion.pending_wing = wing_goal
		else:
			var e: int = routes.arrival_exit(wing_goal, motion.rng)
			if e >= 0:
				var r := int(ducts.exits[e].room)
				var p: Vector2 = shell.clear_point(r, float(shell.rooms[r].px), float(shell.rooms[r].pz))
				motion.place_at(shell.anchor_of(shell.tray_state(r, p.x, p.y)), Vector3.ZERO, &"restore")
				apply_motion()
				return
	if bool(data.get("in_duct", false)) and int(data.get("near", -1)) >= 0:
		motion.place_in_duct(int(data.near))
		apply_motion()
		return
	var at: Vector3 = data.get("at", global_position)
	motion.place_at(at, data.get("heading", global_basis.z), &"restore", float(data.get("hang", SHELL.DEFAULT_HANG)))
	motion.hold()
	apply_motion()

# --- The view: what every machine reads (8.2) ------------------------------------------

func view() -> Dictionary:
	if control == "ai" and motion != null:
		var phase: StringName = motion.transit_phase()
		return {"drop": phase == &"drop", "arriving": phase == &"arriving", "leaving": phase == &"leaving", "in_duct": motion.in_duct, "hidden": motion.hidden, "duct_point": motion.duct_point, "near": motion.near_node}
	return {"drop": net_flags & Flag.DROP != 0, "arriving": net_flags & Flag.ARRIVING != 0, "leaving": false, "in_duct": net_flags & Flag.IN_DUCT != 0, "hidden": net_flags & Flag.HIDDEN != 0, "duct_point": global_position, "near": net_near}

## Where her last way out of a hidden duct to the listener came out
## (sound_route()); Vector3.INF when none.
var heard_at := Vector3.INF

## Where her presence and her voice sound from (world_audio): hidden in a duct,
## where her way to the listener comes out of it, or else the duct itself; out
## of one, her face.
func voice_point() -> Vector3:
	var v := view()
	if bool(v.in_duct) and bool(v.hidden): return heard_at if heard_at != Vector3.INF else v.duct_point
	return face_point()

## Her presence loop only over a locker, waiting (the author's I11).
func presence_on() -> bool: return activity() == &"wait"

func room_of_point(p: Vector3) -> int:
	return int(FLOOR.room_at(level.manifest.rooms, p).get("id", -1))

func sound_route(listener: Vector3) -> Dictionary:
	var v := view()
	var hid: bool = bool(v.in_duct) and bool(v.hidden)
	var route := sound_route_from(v.duct_point if hid else face_point(), listener)
	heard_at = route.position if hid and bool(route.get("audible", false)) else Vector3.INF
	return route

## How a sound of hers made at `point` reaches the listener (3.5): not at all
## to a listener where nothing of her is heard, or on another planta; out of
## a hidden duct by its grilles, on the duct bus; out of the plenum by the
## tile under her; else by the room's own route. Every route ends where the
## listener can see it.
func sound_route_from(point: Vector3, listener: Vector3) -> Dictionary:
	var silent := {"audible": false, "position": point, "gain": -80.0, "cutoff": 20000.0, "echo": false, "distance": INF}
	var v := view()
	var audio = level.get("world_audio") if level != null else null
	if bool(v.drop) or audio == null: return silent
	if level.has_method("point_protected") and level.point_protected(listener): return silent
	if FLOOR.planta_of(point.y) != FLOOR.planta_of(listener.y): return silent
	if bool(v.in_duct) and bool(v.hidden) and ducts != null:
		if voice != null and voice.medium() == &"plenum": return plenum_route(point, listener, audio)
		return duct_route(point, int(v.near), listener, audio)
	return audio.route_source(point, get_rid(), listener)

## Out of a duct by its grilles (conduit_graph.sound_route: a grille's node is
## the grille itself), kept ROUTE_MEMO s per node and listener's cell.
func duct_route(point: Vector3, near: int, listener: Vector3, audio) -> Dictionary:
	var key := [near, Vector3i((listener / 2.0).floor())]
	var now := Time.get_ticks_msec() / 1000.0
	var kept = route_memo.get(key)
	if kept != null and now - float(kept[0]) < ROUTE_MEMO: return kept[1]
	var route: Dictionary = ducts.sound_route(point, near, listener, room_of_point, audio)
	if bool(route.audible): route["bus"] = audio.DUCT_BUS
	if route_memo.size() > 64: route_memo = {}
	route_memo[key] = [now, route]
	return route

## Out of the plenum by the middle of the tile under her (the author's M7),
## quieter and duller than in the room.
func plenum_route(point: Vector3, listener: Vector3, audio) -> Dictionary:
	var p: Vector3 = shell.plenum_mouth(point) - Vector3(0, 0.05, 0)
	if room_of_point(p) == room_of_point(listener):
		return {"audible": true, "position": p, "gain": PLENUM_LOSS, "cutoff": PLENUM_CUTOFF, "echo": false, "distance": p.distance_to(listener)}
	var route: Dictionary = audio.route_source(p, RID(), listener)
	if bool(route.audible):
		route["gain"] = float(route.gain) + PLENUM_LOSS
		route["cutoff"] = minf(float(route.cutoff), PLENUM_CUTOFF)
	return route

func presence_route(listener: Vector3) -> Array:
	if level != null and level.has_method("point_protected") and level.point_protected(listener): return [INF, Vector3.INF]
	var v := view()
	if bool(v.in_duct) and bool(v.hidden) and ducts != null:
		var route: Dictionary = sound_route(listener)
		return [float(route.distance), route.position] if bool(route.get("audible", false)) else [INF, Vector3.INF]
	var audio = level.get("world_audio") if level != null else null
	if audio == null or audio.get("aura") == null: return [INF, Vector3.INF]
	var felt: Array = audio.aura.route_to(listener, FLOOR.floor_point(global_position))
	# Felt from where her face is, not from the floor under her.
	if felt[1] != Vector3.INF: felt[1] = Vector3(felt[1].x, face_point().y, felt[1].z)
	return felt

# --- The net (8.3) --------------------------------------------------------------------------

func flags() -> int:
	var out := 0
	if motion == null: return out
	if motion.in_duct: out |= Flag.IN_DUCT
	if motion.hidden: out |= Flag.HIDDEN
	if motion.surface():
		out |= Flag.SURFACE
		var kind := int(shell.patches[motion.state.patch].kind)
		if kind == SHELL.Kind.TRAY: out |= Flag.TRAY
		elif kind == SHELL.Kind.BAND: out |= Flag.BAND
	if draining: out |= Flag.DRAINING
	if cue: out |= Flag.CUE
	if motion.transit_phase() == &"drop": out |= Flag.DROP
	if motion.transit_phase() == &"arriving": out |= Flag.ARRIVING
	return out

func pack_state() -> Array:
	var look: Vector3 = visual.look_point if visual != null else Vector3.INF
	return [global_position, global_basis.get_rotation_quaternion(), velocity, maxi(WORDS.find(word), 0), flags(), grace, look, clip, motion.near_node if motion != null else -1, motion.jump_id if motion != null else 0]

func push_state(data: Array) -> void:
	if data.size() != PACK_SIZE: return
	var entry := {"time": net_clock, "position": data[0], "rotation": data[1], "velocity": data[2]}
	if int(data[9]) != net_jump:
		net_jump = int(data[9])
		net_states.clear()
		global_position = data[0]
		global_basis = Basis(data[1] as Quaternion)
	net_states.append(entry)
	while net_states.size() > 10: net_states.pop_front()
	word = WORDS[clampi(int(data[3]), 0, WORDS.size() - 1)]
	net_flags = int(data[4])
	grace = float(data[5])
	net_look = data[6]
	clip = int(data[7])
	net_near = int(data[8])

func follow_state(delta: float) -> void:
	net_clock += delta
	if net_states.is_empty(): return
	var wanted := net_clock - 0.1
	var before: Dictionary = net_states[0]
	var after: Dictionary = net_states[net_states.size() - 1]
	for i in range(net_states.size() - 1):
		if float(net_states[i].time) <= wanted and float(net_states[i + 1].time) >= wanted:
			before = net_states[i]
			after = net_states[i + 1]
			break
	var t := clampf((wanted - float(before.time)) / maxf(float(after.time) - float(before.time), 0.001), 0.0, 1.0)
	global_transform = Transform3D(Basis((before.rotation as Quaternion).slerp(after.rotation, t)), (before.position as Vector3).lerp(after.position, t))
	velocity = (before.velocity as Vector3).lerp(after.velocity, t)

# --- The frame ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	grace = maxf(0.0, grace - delta)
	match control:
		"ai":
			if motion != null:
				think(delta)
				motion.cue = cue
				motion.tick(delta)
				apply_motion()
		"puppet":
			follow_state(delta)
	drain_step(delta)
	show_body()
	sound_step(delta)

## Every machine: her travel in the ducts heard, a tile shifted where she goes
## into or out of the ceiling, and her claws outside a riding car.
func sound_step(delta: float) -> void:
	if voice == null or level == null or level.get("world_audio") == null: return
	var v := view()
	var inside := bool(v.in_duct)
	if inside != was_in_duct:
		var e := exit_near(v.duct_point if inside else global_position)
		if e >= 0 and String(ducts.exits[e].kind) in ["ceiling", "gap"]: voice.tile_shift(ducts.exits[e].position)
		was_in_duct = inside
	if inside and bool(v.hidden): voice.travel(delta, velocity.length())
	var lifts = level.get("lifts")
	if lifts == null or int(lifts.boarding.get("car", -1)) < 0 or not bool(v.drop):
		car_clock = 0.0
		return
	car_clock -= delta
	if car_clock > 0.0: return
	car_clock = voice.rng.randf_range(CAR_SCRATCH.x, CAR_SCRATCH.y)
	voice.outside_car()

## The exit nearest a point within 1.5 m; -1 when none.
func exit_near(point: Vector3) -> int:
	if ducts == null: return -1
	var best := -1
	var best_d := 1.5
	for e in ducts.exits.size():
		var d: float = (ducts.exits[e].position as Vector3).distance_to(point)
		if d < best_d:
			best_d = d
			best = e
	return best

## Her transform and velocity from the motion.
func apply_motion() -> void:
	if motion == null: return
	global_transform = motion.transform()
	velocity = motion.velocity

## What is seen of her, the same on every machine (7.5): the Visual follows
## `hidden`, her body collides only out of the ducts and the drop, and her
## hands hold on as hard as what she holds asks.
func show_body() -> void:
	var v := view()
	var hide_now: bool = bool(v.hidden) or bool(v.drop)
	collision_layer = 0 if bool(v.in_duct) or bool(v.drop) else BODY_LAYER
	collision_mask = 0
	if visual == null: return
	if hide_now != was_hidden:
		visual.visible = not hide_now
		visual.process_mode = Node.PROCESS_MODE_DISABLED if hide_now else Node.PROCESS_MODE_INHERIT
		if not hide_now and visual.get("limbs") != null and visual.limbs.has_method("replant"): visual.limbs.replant()
		was_hidden = hide_now
	if hide_now: return
	visual.velocity = velocity
	var on_surface: bool = (motion.surface() if control == "ai" and motion != null else net_flags & Flag.SURFACE != 0)
	visual.crawling = on_surface
	var tray: bool = (int(shell.patches[motion.state.patch].kind) == SHELL.Kind.TRAY) if control == "ai" and motion != null and motion.surface() else net_flags & Flag.TRAY != 0
	var band: bool = (int(shell.patches[motion.state.patch].kind) == SHELL.Kind.BAND) if control == "ai" and motion != null and motion.surface() else net_flags & Flag.BAND != 0
	visual.cling = CLING_TRAY if tray else CLING_BAND if band else CLING_CHANNEL
	# Shrunk under a short lane (M2): her body along its +Y.
	var squash: float = motion.squash if control == "ai" and motion != null else 1.0
	visual.scale = Vector3(1.0, squash, 1.0)
	if body_shape != null: body_shape.position = Vector3(shape_rest.x, shape_rest.y * squash, shape_rest.z)
	if control == "ai": pick_clip(bool(v.in_duct))
	if clip != shown_clip and visual.has_method("play"):
		shown_clip = clip
		visual.play(CLIPS[clip])

## The clip for her pace, unless 2b has set one (2a picks idle, crawl,
## crawl_fast and vent_crawl).
func pick_clip(in_duct: bool) -> void:
	var speed: float = velocity.length()
	var animator: AnimationPlayer = visual.get("animator")
	if in_duct:
		clip = CLIPS.find("vent_crawl")
		if animator != null: animator.speed_scale = speed / MOTION.VENT_CLIP_SPEED if speed > 0.05 else 1.0
	elif speed < 0.05:
		clip = CLIPS.find("idle")
		if animator != null: animator.speed_scale = 1.0
	elif speed <= 1.6:
		clip = CLIPS.find("crawl")
		if animator != null: animator.speed_scale = speed / 1.35
	else:
		clip = CLIPS.find("crawl_fast")
		if animator != null: animator.speed_scale = speed / MOTION.SCURRY_SPEED

# --- The observer -------------------------------------------------------------------------

func debug_lines() -> Array[String]:
	var lines: Array[String] = super()
	if motion == null: return lines
	var kind := "ducto"
	var room_id: int = motion.room()
	var u := 0.0
	var v := 0.0
	var hang := 0.0
	if motion.surface():
		kind = ["techo", "franja", "pasillo"][int(shell.patches[motion.state.patch].kind)]
		u = motion.state.u
		v = motion.state.v
		hang = motion.state.hang
	var leg := String(motion.legs[0].kind) if not motion.legs.is_empty() else "parada"
	lines.append("  lurker, %s, %s %d, u %.1f v %.1f, cuelga %.2f, %s, ducto %s, viaje %s" % [String(word), kind, room_id, u, v, hang, leg, "si" if motion.in_duct else "no", String(motion.transit_phase())])
	return lines

func debug_state() -> Dictionary:
	var out := super()
	if motion == null: return out
	out["patch"] = motion.state.patch if motion.surface() else -1
	out["room"] = motion.room()
	out["hang"] = motion.state.hang if motion.surface() else 0.0
	out["in_duct"] = motion.in_duct
	out["hidden"] = motion.hidden
	out["legs"] = motion.legs.size()
	out["transit"] = String(motion.transit_phase())
	out["jump_id"] = motion.jump_id
	return out

# --- Her mind (spec_f2_mind 8): senses, brain and the warning ---------------------------

## Tests and probes switch the mind off (the senses still answer).
var thinking := true
var senses
var brain
## Held here, on the machine in charge, whoever drives her: the only way to a take.
var warning = WARNING.new()
var intent := {}
var last_order := {}
var order_failed := false
## The light she drinks: room -> applied amount, room -> target.
var drained := {}
var drain_targets := {}
var drain_clock := 0.0
var drain_reach := 3.5
var drain_cache := {}
var drain_time := 0.0
## What the floor's systems last showed her (every SYSTEMS_EVERY): whether her
## room was lit, whether her planta's ducts were shut.
const SYSTEMS_EVERY := 0.25
var systems_clock := 0.0
var room_was_lit := {}
var ducts_were_shut := false

func think_setup() -> void:
	senses = SENSES.new()
	senses.setup(level, self, ducts)
	senses.tune(tuning)
	brain = BRAIN.new()
	brain.setup(self, rng, warning)
	brain.tune(tuning)
	brain.cue_started.connect(func(entry: Dictionary): if level.get("match_net") != null and level.match_net.has_method("send_cue"): level.match_net.send_cue(int(entry.seat), int(entry.id), Vector3(entry.point[0], entry.point[1], entry.point[2]), float(entry.due) - float(entry.at)))
	brain.cue_ended.connect(func(entry: Dictionary): if level.get("match_net") != null and level.match_net.has_method("send_cue_over"): level.match_net.send_cue_over(int(entry.id), String(entry.outcome)))
	brain.scared.connect(func(cause: String, seat: int): on_event("scare", [seat, cause, face_point()]))

func think(delta: float) -> void:
	if control != "ai" or not thinking or brain == null: return
	var p = senses.perceive(delta, brain.clock, brain.prey_seat())
	for click in senses.clicks: brain.on_heard(click.route, click.point)
	senses.clicks = []
	watch_systems(delta, p.face)
	intent = brain.tick(delta, p)
	senses.listening = brain.listening
	apply_intent(intent)
	word = brain.activity()
	cue = brain.state == BRAIN.State.CUE

## The light coming on where she is, and the fans stopping, told to her mind.
func watch_systems(delta: float, face: Vector3) -> void:
	systems_clock -= delta
	if systems_clock > 0.0: return
	systems_clock = SYSTEMS_EVERY
	var room: int = motion.room() if not motion.in_duct else -1
	if room >= 0 and level.get("hotel") != null:
		var lit_now: bool = level.hotel.lit(room)
		if room_was_lit.has(room) and not bool(room_was_lit[room]) and lit_now: brain.on_room_lit(face)
		room_was_lit = {room: lit_now}
	var wing: int = clampi(motion.wing(), 0, ducts.closed_wings.size() - 1)
	var shut: bool = ducts.closed_wings[wing] != 0
	if ducts_were_shut and not shut:
		var e: int = routes.nearest_exit(plan_start())
		if e >= 0: brain.on_ducts_open(ducts.exits[e].position)
	ducts_were_shut = shut

## The one place her mind talks to her motion (spec_f2_mind 8.3): an order
## only when the intent changed.
func apply_intent(wanted: Dictionary) -> void:
	var what: StringName = wanted.get("do", &"hold")
	var clip_name: String = String(wanted.get("clip", ""))
	if clip_name != "": clip = maxi(CLIPS.find(clip_name), 0)
	if visual != null: visual.look_point = wanted.get("look", Vector3.INF)
	var same: bool = last_order.get("do", &"") == what
	match what:
		&"keep":
			return
		&"hold":
			if not same: motion.hold()
		&"go":
			var to: Vector3 = wanted.to
			if not same or (last_order.get("to", Vector3.INF) as Vector3).distance_to(to) > 0.3 or float(last_order.get("speed", 0.0)) != float(wanted.speed):
				order_failed = not motion.go_to(to, float(wanted.speed))
		&"duct", &"listen":
			if not same or int(last_order.get("exit", -2)) != int(wanted.exit):
				order_failed = not motion.go_to_exit(int(wanted.exit), float(wanted.get("speed", BRAIN.CRAWL_SPEED)))
		&"take":
			var victim = senses.body_of(int(wanted.seat))
			if wanted.get("leap", false) and victim != null: motion.leap(FLOOR.floor_point(victim.global_position))
			else: motion.hold()
			if victim != null and level.has_method("capture_survivor"): level.capture_survivor(victim)
	last_order = wanted.duplicate()

# --- The getters her percept reads (8.3) ---------------------------------------------------

func in_network_duct() -> bool: return motion != null and motion.in_duct and motion.hidden

func duct_node() -> int: return motion.near_node if motion != null and motion.in_duct else -1

func at_exit() -> int:
	if not in_network_duct() or not motion.legs.is_empty(): return -1
	if motion.mouth_exit >= 0: return motion.mouth_exit
	for e in ducts.exits.size():
		if int(ducts.exits[e].node) == motion.near_node: return e
	return -1

func ahead(metres: float) -> PackedVector3Array:
	return motion.ahead(metres) if motion != null and not motion.legs.is_empty() else PackedVector3Array()

func moving() -> bool: return motion != null and motion.route_state() == &"moving"

func arrived() -> bool: return motion != null and motion.at_goal()

func route_failed() -> bool: return order_failed or (motion != null and motion.route_state() == &"blocked")

func on_channel() -> bool: return motion != null and motion.on_channel()

# --- What she knows of the map: the world port (7.9, 8.4) -------------------------------------

## Behind them along their look, on her ceiling over that point.
func behind_point(seen, metres: float) -> Vector3:
	var view: Vector3 = seen.view
	var flat := Vector3(view.x, 0, view.z)
	if flat.length() < 0.01: flat = Vector3.FORWARD
	var at: Vector3 = (seen.eye as Vector3) - flat.normalized() * metres
	var room := FLOOR.room_at(level.manifest.rooms, seen.point)
	if not room.is_empty() and shell.tray_of.has(int(room.id)):
		var s = shell.tray_state(int(room.id), at.x, at.z)
		return shell.anchor_of(s)
	var s = shell.state_at(Vector3(at.x, (seen.point as Vector3).y + 1.0, at.z))
	return shell.anchor_of(s) if s != null else at

func plan_start() -> Dictionary:
	var from: Dictionary = motion.plan_start()
	return from.get("start", {"room": motion.room()})

func flee_exit(away_from: Vector3) -> int:
	return routes.flee_exit(plan_start(), away_from, global_position)

## The nearest dark ceiling at least 4 m from `away_from`, else her nearest exit.
func dark_retreat(away_from: Vector3) -> Vector3:
	var here: int = motion.room()
	var metres: Dictionary = routes.travel_metres(here) if here >= 0 else {}
	var best := Vector3.INF
	var best_m := INF
	for r in metres:
		var point := room_point(int(r))
		if point.distance_to(away_from) < 4.0 or SIGHT.lit_point(level, point): continue
		if float(metres[r]) < best_m:
			best_m = float(metres[r])
			best = point
	if best != Vector3.INF: return best
	var e: int = routes.nearest_exit(plan_start())
	return ducts.exits[e].position if e >= 0 else global_position

func exit_of_room(room: int) -> int:
	var exits: PackedInt32Array = ducts.exits_of_room(room)
	return exits[0] if not exits.is_empty() else -1

## A room's tray point clear of its lamps.
func room_point(room: int) -> Vector3:
	var r: Dictionary = level.manifest.rooms[room]
	var p: Vector2 = shell.clear_point(room, float(r.px), float(r.pz))
	return shell.anchor_of(shell.tray_state(room, p.x, p.y))

## Her round (7.9): a room of her planta she has not listened at lately,
## farther than 6 m, the staler and nearer the likelier.
func patrol_room() -> int:
	var here: int = motion.room()
	if here < 0: return -1
	var metres: Dictionary = routes.travel_metres(here)
	var rooms: Array = []
	var weights: Array = []
	for r in metres:
		var room := int(r)
		if room == here or float(metres[r]) < 6.0 or brain.searched_lately(room): continue
		rooms.append(room)
		weights.append((1.0 + minf(brain.clock - float(brain.visited.get(room, -300.0)), 300.0) / 60.0) / (1.0 + float(metres[r]) / 40.0))
	if rooms.is_empty(): return -1
	var total := 0.0
	for w in weights: total += float(w)
	var pick := rng.randf() * total
	for i in rooms.size():
		pick -= float(weights[i])
		if pick <= 0.0: return int(rooms[i])
	return int(rooms[rooms.size() - 1])

## The director's zone: rooms of that planta with a ceiling for her, not in
## `avoid`, their middle within `radius`.
func lead_rooms(point: Vector3, radius: float, avoid: Array) -> Array:
	var out: Array = []
	var planta := FLOOR.planta_of(point.y)
	for room in level.manifest.rooms:
		var id := int(room.id)
		if not shell.tray_of.has(id) or avoid.has(id) or int(room.get("wing", -1)) != planta: continue
		if FLOOR.position_of(room).distance_to(FLOOR.floor_point(point)) <= radius: out.append(id)
	return out

## Where a noise is worth going: her ceiling over it.
func clue_point(point: Vector3) -> Vector3:
	var s = shell.state_at(FLOOR.floor_point(point) + Vector3.UP)
	return shell.anchor_of(s) if s != null else point

## A spot for a show at the edge of somebody's view: a dark ceiling 5 to 16 m
## from their eye, beside their look, in plain view of it, that she can reach.
func show_spot(seen, kind: String) -> Dictionary:
	var eye: Vector3 = seen.eye
	var found: Array = []
	for id in shell.tray_of:
		var point := room_point(int(id))
		var d := point.distance_to(eye)
		if d < 5.0 or d > 16.0 or FLOOR.planta_of(point.y) != FLOOR.planta_of(eye.y): continue
		if SIGHT.lit_point(level, point) or not SIGHT.beside(eye, seen.view, point): continue
		if not SIGHT.clear(level, eye, point, [get_rid()]): continue
		found.append(point)
	if found.is_empty(): return {}
	return {"kind": kind, "point": found[rng.randi_range(0, found.size() - 1)]}

func lead_to(point: Vector3, radius: float, seconds: float, kind: String, once := false, avoid: Array = [], sniff := false) -> bool:
	return control == "ai" and brain != null and brain.lead_to(point, radius, seconds, kind, once, avoid, sniff)

func investigate(point: Vector3) -> void:
	if brain != null: brain.clue = {"point": point, "at": brain.clock}

func searched_lately(room_id: int) -> bool: return brain != null and brain.searched_lately(room_id)

## The ceiling over a locker.
func above_locker(hide: Node3D) -> Vector3:
	var s = shell.state_at(hide.global_position + Vector3.UP)
	return shell.anchor_of(s) if s != null else hide.global_position

func presence_sound() -> Resource: return sound_profile

## A moment of hers every machine must hear of (6.3). Told on this machine
## only for now: the net's reliable event is phase 4's.
func on_event(kind: String, data: Array) -> void:
	match kind:
		"scare":
			var at: Vector3 = data[2]
			if voice != null: voice.shriek_heard(at)
			frighten(at)

## Her shriek frightens the minds near it (on the authority, where minds
## are kept): on her planta, within SHRIEK_FRIGHT and with a clear line.
func frighten(at: Vector3) -> void:
	var mind = level.get("sanity")
	var audio = level.get("world_audio")
	if mind == null or not mind.has_method("fright") or audio == null or not level.has_method("survivors"): return
	if level.get("match_net") != null and level.match_net.has_method("in_charge") and not level.match_net.in_charge(): return
	for body in level.survivors():
		if not is_instance_valid(body) or body.get("camera") == null: continue
		var ear: Vector3 = body.camera.global_position
		if FLOOR.planta_of(ear.y) != FLOOR.planta_of(at.y) or ear.distance_to(at) > SHRIEK_FRIGHT: continue
		if audio.occluded(at, get_rid(), ear): continue
		mind.fright(body, mind.SANITY_SHRIEK)

## Her shriek, at her face, for everybody.
func scream(point: Vector3) -> void:
	var path: String = BRAIN.SCARE_SOUNDS[rng.randi_range(0, BRAIN.SCARE_SOUNDS.size() - 1)]
	var audio = level.get("world_audio")
	if audio != null and audio.has_method("play_at"): audio.play_at(path, point, BRAIN.SCARE_GAIN)
	if level.get("match_net") != null and level.match_net.has_method("world_sound"): level.match_net.world_sound(path, point, BRAIN.SCARE_GAIN, 0.0)

# --- The contract, through her mind ---------------------------------------------------------

func sees(player: Node3D, ignore_concealment := false) -> bool:
	return senses != null and senses.sees(player, ignore_concealment)

func hear(point: Vector3, radius: float) -> void:
	if control != "ai" or grace > 0.0 or senses == null: return
	var route: Dictionary = senses.hear_route(point, radius)
	if bool(route.audible): brain.on_heard(route, point)

func hear_route(point: Vector3, radius: float) -> Dictionary:
	return senses.hear_route(point, radius) if senses != null else {"audible": false, "apparent": point, "distance": INF, "muffle": 1.0}

func watched(point: Vector3) -> bool: return SIGHT.watched(level, point, [get_rid()])

func quarry() -> Node3D:
	if brain == null or not brain.noticing(): return null
	return senses.body_of(brain.prey_seat())

func saw_enter(hide: Node3D, _sure := true) -> void:
	if senses != null: senses.saw_enter(hide)

func noticing() -> bool: return brain != null and brain.noticing()

## The gate: the machine in charge only; a tool's forced capture is let
## through and logged.
func may_capture(body: Node3D) -> bool:
	if level.get("match_net") != null and level.match_net.has_method("in_charge") and not level.match_net.in_charge(): return false
	var clock: float = brain.clock if brain != null else 0.0
	if level.get("executions") != null and not level.executions.forced.is_empty():
		warning.forced_take(int(body.slot), clock)
		return true
	return warning.may_capture(int(body.slot), clock)

func cue_of(body: Node3D) -> int:
	var clock: float = brain.clock if brain != null else 0.0
	for i in range(warning.ledger.size() - 1, -1, -1):
		var entry: Dictionary = warning.ledger[i]
		if int(entry.seat) == int(body.slot) and String(entry.outcome) == "taken" and absf(float(entry.take_at) - clock) <= WARNING.EPS: return int(entry.id)
	return -1

func capture_log() -> Array: return warning.ledger.duplicate(true)

## Her place in a capture is her capture style's (phase 3), not a yaw: her
## basis is upside down on a ceiling.
func turn_for_capture(_yaw: float) -> void: pass

func begin_capture(data: Dictionary) -> void:
	if brain != null: brain.on_captured(data)

func end_capture() -> void:
	if brain != null: brain.on_released()

## Her warning, played here from where she is: in the victim's own ears, and
## heard by the floor by anybody else (spec_f2_mind 9.2).
func play_cue(seat: int, cue_id: int, point: Vector3, hold: float) -> void:
	var audio = level.get("world_audio")
	if audio == null or not audio.has_method("play_cue"): return
	var mine: bool = level.get("player") != null and seat == int(level.player.slot) and (not level.has_method("local_alive") or level.local_alive())
	var path: String = WARNING.CUE_SOUNDS[cue_id % WARNING.CUE_SOUNDS.size()]
	audio.play_cue(path, point, mine)
	var entry: Dictionary = warning.active if not warning.active.is_empty() else {}
	var caption: String = WARNING.CUE_CAPTION_ABOVE if bool(entry.get("above", false)) else WARNING.CUE_CAPTION
	if mine: audio.show_caption(caption, false, hold)
	elif bool(audio.route_source(point, RID(), level.player.camera.global_position).get("audible", false)) and point.distance_to(level.player.camera.global_position) <= 10.0:
		audio.show_caption(WARNING.CUE_CAPTION_NEAR, false)
	# Nothing else of hers starts on the victim's machine from CLEAN before its
	# due time until it is over (0.5.6).
	if mine and voice != null: voice.quiet_until = voice.now() + hold
	cue_played.emit(seat, cue_id, point)

func cue_over(_cue_id: int, _outcome: String) -> void:
	if voice != null: voice.quiet_until = INF
	var audio = level.get("world_audio")
	if audio != null and "caption_lock" in audio: audio.caption_lock = 0.0

## Tests and the workbench: on the ceiling over a point, facing `toward`, held.
func place_over(point: Vector3, toward := Vector3.INF) -> void:
	var s = shell.state_at(Vector3(point.x, point.y + 1.0, point.z))
	if s == null: return
	var at: Vector3 = shell.anchor_of(s)
	var heading := global_basis.z
	if toward != Vector3.INF: heading = Vector3(toward.x - at.x, 0, toward.z - at.z)
	motion.place_at(at, heading, &"probe")
	motion.hold()
	apply_motion()

## Tests: inside the duct at that exit's node, hidden.
func place_in_exit(exit: int) -> void:
	motion.place_in_duct(int(ducts.exits[exit].node))
	motion.mouth_exit = exit
	apply_motion()

# --- The light she drinks (spec_f2_mind 5.6) ----------------------------------------------------

## Every DRAIN_EVERY on every machine, from her own position: the targets.
func drain_step(delta: float) -> void:
	drain_clock -= delta
	if drain_clock > 0.0: return
	drain_clock = SENSES.DRAIN_EVERY
	var quiet: bool = grace > 0.0 or in_transit() or hushed() or level == null
	drain_targets = {} if quiet else SENSES.drain_rooms(level, global_position, drain_reach, drain_cache)

## Every frame: each room's light eased towards its target and trembling
## while she drinks (all its lamps together), nothing trembling on reduced
## effects.
func _process(delta: float) -> void:
	if level == null or level.get("hotel") == null: return
	drain_time += delta
	var hotel = level.hotel
	var reduced: bool = bool(hotel.get("reduced"))
	var rooms := {}
	for r in drained: rooms[r] = true
	for r in drain_targets: rooms[r] = true
	for r in rooms:
		var target := float(drain_targets.get(r, 0.0))
		var now := move_toward(float(drained.get(r, 0.0)), target, SENSES.DRAIN_EASE * delta)
		var sent := now
		if target > 0.0 and not reduced: sent = clampf(now + SENSES.DRAIN_WOBBLE * sin(TAU * float(hash(int(r)) % 5 + 7) * drain_time + float(r)), 0.0, 0.89)
		if now <= 0.0:
			drained.erase(r)
			hotel.drain(int(r), 0.0)
			if hotel.has_method("drain_emergency"): hotel.drain_emergency(int(r), 0.0)
			continue
		if absf(sent - float(hotel.drained(int(r)))) > 0.01:
			hotel.drain(int(r), sent)
			if hotel.has_method("drain_emergency"): hotel.drain_emergency(int(r), sent)
		drained[r] = now
	draining = not drained.is_empty()

## Every room she drank given back at once (a stage given back, a floor continued).
func undrain() -> void:
	if level == null or level.get("hotel") == null: return
	for r in drained:
		level.hotel.drain(int(r), 0.0)
		if level.hotel.has_method("drain_emergency"): level.hotel.drain_emergency(int(r), 0.0)
	drained = {}
	drain_targets = {}
	draining = false
