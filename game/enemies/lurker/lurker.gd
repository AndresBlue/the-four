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
const CAPTURE := preload("res://game/app/capture_styles/lurker_capture.gd")
const SCORE := preload("res://game/app/capture_styles/lurker_score.gd")
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
## 2a's ten (8.3) and phase 3's two: her mind's state and her prey's seat
## (spec_f3_integration 6.2).
const PACK_SIZE := 12
## TRAY and BAND: the patch kind (neither: a channel), for visual.cling.
## SCARED: drawing back from a fright or fleeing it.
enum Flag { IN_DUCT = 1, HIDDEN = 2, SURFACE = 4, DRAINING = 8, CUE = 16, DROP = 32, ARRIVING = 64, TRAY = 128, BAND = 256, SCARED = 512 }
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
## Her mind's state (lurker_brain.State) and her prey's seat as the one who
## drives her sent them; -1 before the first pack.
var net_mind := -1
var net_prey := -1
## What is heard of her (lurker_voice.gd).
var voice
var car_clock := 0.0
var route_memo := {}
var was_in_duct := false
## Her capture holds her where it poses her (lurker_capture.pose()): her
## motion waits (her mind goes on, taking).
var scene_held := false
## Her speeds while nobody sees her (tune(); spec_f3_aggression).
var unseen_speed := 0.0
var unseen_duct := 0.0
## Her forced encounters' wait (tune(); the director reads forced_after()).
var force_after := 0.0
## seat -> s left of a torch she drank (iteration 2, G1), on every machine
## from her "scare" event; lurker_senses.gd reads it on the machine in charge.
## torch_drunk: tune()'s seconds (0 never).
var drunk := {}
var torch_drunk := 0.0
## A drunk beam: this share of itself, flickering; back over the last DRUNK_RAMP s.
const DRUNK_BEAM := 0.15
const DRUNK_RAMP := 1.0
const DRUNK_SOUND := "res://assets/audio/sfx/flashlight/off_2.wav"
const DRUNK_GAIN := -6.0
## Her drink of a whole room past LIT_DRAIN (iteration 2, G8): the room, on
## every machine from her "snuff" event (-1 none); on the machine in charge,
## whom for, since when, how long they have been out of it, the room she is
## counting towards it and for how long, and when each room was last given
## back. snuff_time: tune()'s seconds (0 never).
var deep_room := -1
var deep_prey := -1
var deep_since := 0.0
var deep_out := 0.0
var snuff_aim := -1
var snuff_clock := 0.0
var snuffed := {}
var snuff_time := 0.0
## How far she drinks it and how fast (it goes in about two seconds and comes
## back in one), the most she keeps it, the most the prey may be out of it,
## how soon the same room again; the tremble as it goes, and what is left of
## it once dark.
const DEEP := 0.93
const DEEP_RISE := 0.3
const DEEP_FALL := 1.0
const DEEP_MOST := 25.0
const DEEP_OUT := 3.0
const DEEP_AGAIN := 45.0
const DEEP_WOBBLE := 0.12
const DEEP_REST_WOBBLE := 0.02
## Every capture of hers: {seat, cue, at, forced} (spec_f3_integration 5.9).
var takes: Array = []

func kind_id() -> StringName: return &"lurker"

## Only her ducts: no lifts, no sets, no shriek; no lockers (the author,
## M12: "no abre taquillas").
func can(ability: StringName) -> bool: return ability == &"ducts"

func tune(profile: Dictionary) -> void:
	tuning = profile
	duct_speed = float(profile.get("duct_speed", 1.6))
	unseen_speed = float(profile.get("unseen_speed", 0.0))
	unseen_duct = float(profile.get("unseen_duct", 0.0))
	force_after = float(profile.get("forced_after", 0.0))
	torch_drunk = float(profile.get("torch_drunk", 0.0))
	snuff_time = float(profile.get("snuff_time", 0.0))
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
	motion.tile_turned.connect(func(room: int, tile: Vector2i, open: bool, from_below: bool): tell("tile", [room, tile.x, tile.y, open, from_below]))
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
	if brain != null and brain.state in [BRAIN.State.RECOIL, BRAIN.State.FLEE]: out |= Flag.SCARED
	return out

func pack_state() -> Array:
	var look: Vector3 = visual.look_point if visual != null else Vector3.INF
	return [global_position, global_basis.get_rotation_quaternion(), velocity, maxi(WORDS.find(word), 0), flags(), grace, look, clip, motion.near_node if motion != null else -1, motion.jump_id if motion != null else 0,
		int(brain.state) if brain != null else -1, int(brain.prey) if brain != null else -1]

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
	net_mind = int(data[10])
	net_prey = int(data[11])

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
	# A guest sees her drawn between ticks and eased, as the host does.
	if visual != null and visual.has_method("present"): visual.present(global_transform, 0)

# --- The frame ---------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	grace = maxf(0.0, grace - delta)
	match control:
		"ai":
			if motion != null:
				think(delta)
				if not scene_held:
					motion.cue = cue
					motion.unseen = unseen_now()
					motion.watched = motion.surface() and not cue and SIGHT.watched(level, face_point(), [get_rid()])
					motion.unseen_pace = unseen_speed
					motion.unseen_duct = unseen_duct
					motion.tick(delta)
					apply_motion()
		"puppet":
			follow_state(delta)
	sound_beat(delta)
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
		if inside: duct_trips += 1
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

## Her beats and what each does to the dread, the music and her voice
## (spec_lurker_rebuild 4): {aura, clicks, menace, fast, silent}. Between
## plantas she sounds as roaming far.
const MOODS := {
	&"roam_far": {"aura": 0.35, "clicks": false, "menace": -1.0, "fast": false, "silent": false},
	&"roam_near": {"aura": 0.6, "clicks": false, "menace": -1.0, "fast": false, "silent": false},
	&"listen": {"aura": 0.0, "clicks": false, "menace": -1.0, "fast": true, "silent": false},
	&"stalk": {"aura": 0.85, "clicks": false, "menace": -1.0, "fast": false, "silent": false},
	&"peek": {"aura": 0.3, "clicks": false, "menace": -1.0, "fast": true, "silent": false},
	&"hush": {"aura": 0.0, "clicks": false, "menace": 1.0, "fast": true, "silent": true},
	&"creep": {"aura": 1.0, "clicks": false, "menace": 1.0, "fast": false, "silent": false},
	&"cue": {"aura": 0.0, "clicks": false, "menace": 1.0, "fast": true, "silent": true},
	&"scare": {"aura": 0.0, "clicks": false, "menace": 0.0, "fast": true, "silent": false},
	&"return": {"aura": 0.5, "clicks": false, "menace": -1.0, "fast": false, "silent": false},
	&"rest": {"aura": 0.2, "clicks": false, "menace": 0.0, "fast": false, "silent": false},
	&"above": {"aura": 0.6, "clicks": false, "menace": -1.0, "fast": false, "silent": false},
	&"transit": {"aura": 0.35, "clicks": false, "menace": -1.0, "fast": false, "silent": false},
}
## On a puppet: whether her way to this machine's player is short (roaming
## near), reckoned every NEAR_EVERY.
const NEAR_EVERY := 0.5
var near_clock := 0.0
var near_local := false

## What her beat does now (creature.mood()); {} before she has one, as today.
func mood() -> Dictionary:
	var b := beat_now()
	if b == &"": return {}
	var out: Dictionary = (MOODS.get(b, MOODS[&"roam_far"]) as Dictionary).duplicate()
	# Her claws' false clicks only while she goes unseen, in the plenum or a duct.
	if b == &"stalk": out["clicks"] = bool(view().in_duct)
	return out

## Her beat: the brain's where it drives her; else from the state sent
## (BRAIN.BEATS), roaming near or far by her way to this machine's player.
func beat_now() -> StringName:
	if control == "ai" and brain != null: return brain.beat
	var b: StringName = BRAIN.BEATS.get(net_mind, &"")
	if b == &"roam_far" and near_local: b = &"roam_near"
	return b

## Every physics tick on every machine: her beat and mood to her voice (whose
## setter ducks the floor for the silence and the warning), and her arrival
## over a locker heard once.
func sound_beat(delta: float) -> void:
	if voice == null: return
	near_clock -= delta
	if control != "ai" and near_clock <= 0.0:
		near_clock = NEAR_EVERY
		near_local = false
		if level != null and level.get("player") != null and is_instance_valid(level.player):
			var here := room_of_point(global_position)
			var theirs := room_of_point(level.player.global_position)
			near_local = here >= 0 and theirs >= 0 and float(travel_metres(here).get(theirs, INF)) <= BRAIN.NEAR_ROUTE
	var b := beat_now()
	if b == &"above" and voice.beat != &"above": voice.arrive_above()
	voice.beat = b
	voice.mood = mood()

## The exit nearest a point within 1.5 m; -1 when none.
func exit_near(point: Vector3) -> int:
	if ducts == null: return -1
	var best := -1
	var best_d := 1.5
	for e in ducts.exits.size():
		if String(ducts.exits[e].kind) == "tile": continue
		var d: float = (ducts.exits[e].position as Vector3).distance_to(point)
		if d < best_d:
			best_d = d
			best = e
	return best

## Nobody has her in view (the shared sight's watched(), from where she is:
## her face, or her point in a duct): unseen she flies in every state but
## closing in (its own pace, the brain's) and the warning (spec_lurker_rebuild
## 2.4).
func unseen_now() -> bool:
	if cue or brain == null: return false
	var going: bool = brain.state in [BRAIN.State.ROAM, BRAIN.State.LISTEN, BRAIN.State.STALK, BRAIN.State.FLEE, BRAIN.State.RETURN, BRAIN.State.TRANSIT] \
		or (brain.state == BRAIN.State.PEEK and not bool(brain.show.get("arrived", false))) \
		# Closing in through the ceiling she flies too, and creeps only once out
		# on a surface: at a creep she trailed a walker along the plenum for good.
		or (brain.state == BRAIN.State.CREEP and motion.in_duct)
	if not going: return false
	var at: Vector3 = motion.duct_point if motion.in_duct else face_point()
	return not SIGHT.watched(level, at, [get_rid()])

## Her transform and velocity from the motion; the Visual is drawn from it
## between ticks, eased (lurker_visual.present(), spec_lurker_rebuild 3.1).
func apply_motion() -> void:
	if motion == null: return
	global_transform = motion.transform()
	velocity = motion.velocity
	if visual != null and visual.has_method("present"): visual.present(global_transform, motion.jump_id)

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
	# Through a grille or a tile her hands stay on (spec_lurker_rebuild 3.7).
	var on_surface: bool = (motion.clinging() if control == "ai" and motion != null else net_flags & Flag.SURFACE != 0)
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
## crawl_fast and vent_crawl). Idle only after IDLE_AFTER under 0.05 m/s
## (spec_lurker_rebuild 3.3): a waypoint or a door never restarts her crawl.
const IDLE_AFTER := 0.15
## A pose 2b asks for (her scare, looming, peeking, backing off) is played as
## it is: picking by pace hid every one of them under idle or crawl.
const POSES := ["scare", "loom", "peek", "retreat"]
var intent_clip := ""
var still_for := 0.0
func pick_clip(in_duct: bool) -> void:
	var speed: float = velocity.length()
	var animator: AnimationPlayer = visual.get("animator")
	still_for = still_for + get_physics_process_delta_time() if speed < 0.05 else 0.0
	if not in_duct and intent_clip in POSES:
		clip = CLIPS.find(intent_clip)
		if animator != null: animator.speed_scale = 1.0
		return
	if in_duct:
		clip = CLIPS.find("vent_crawl")
		if animator != null: animator.speed_scale = speed / MOTION.VENT_CLIP_SPEED if speed > 0.05 else 1.0
	elif speed < 0.05 and still_for >= IDLE_AFTER:
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
	if brain != null: lines.append("  mente %s, presa %d%s" % [brain.state_name(), int(brain.prey), (", aviso %.1f s" % maxf(0.0, float(warning.active.due) - brain.clock)) if not warning.active.is_empty() else ""])
	if not drained.is_empty(): lines.append("  bebe " + ", ".join(PackedStringArray(drained.keys().map(func(r): return "%d (%.2f)" % [int(r), float(drained[r])]))))
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
	out["state"] = brain.state_name() if brain != null else ""
	out["prey"] = int(brain.prey) if brain != null else -1
	out["bebe"] = drained.duplicate()
	return out

# --- The observer (spec_f3_integration 6.1) -----------------------------------------------

## Her marks (observer_gizmos.gd), only where g.here(). &"path": her way
## ahead, the outline of the ceiling she is on and a tick along her normal,
## the director's lead, the warning in hand (a line to the victim's head and
## a ring round them that closes with its window) and every room she drinks.
## &"sight": her dark sight as the edges of her view, and a line to her prey
## while she sees them. &"ducts": the network of the planta looked at (the
## plenum fainter, the main duct thick), every grille and gap (red while it
## is shut to her), the tiles she left open, her way inside and where she is.
func draw_gizmos(g) -> void:
	if motion == null: return
	match g.layer:
		&"path": gizmo_path(g)
		&"sight": gizmo_sight(g)
		&"ducts": gizmo_ducts(g)

func gizmo_path(g) -> void:
	var points: PackedVector3Array = motion.ahead(30.0)
	for i in range(1, points.size()):
		if g.here(points[i]): g.line(points[i - 1], points[i], g.COLOURS.path)
	if motion.surface():
		var patch: Dictionary = shell.patches[motion.state.patch]
		if int(patch.kind) == SHELL.Kind.TRAY:
			var r: Rect2 = patch.rect
			var y := float(patch.y) - 0.02
			var corners := [Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y), Vector3(r.end.x, y, r.end.y), Vector3(r.position.x, y, r.end.y)]
			for k in 4: g.line(corners[k], corners[(k + 1) % 4], g.COLOURS.shell)
		var at: Vector3 = motion.anchor()
		g.line(at, at + motion.transform().basis.y * 0.5, g.COLOURS.shell)
	if brain != null and not brain.lead.is_empty() and g.here(brain.lead.point): g.ring(FLOOR.floor_point(brain.lead.point), float(brain.lead.radius), g.COLOURS.lead, 32)
	if brain != null and not warning.active.is_empty():
		var victim = senses.body_of(int(warning.active.seat)) if senses != null else null
		if victim != null:
			var head: Vector3 = victim.camera.global_position if victim.get("camera") != null else victim.global_position + Vector3.UP * 1.6
			var left := clampf((float(warning.active.due) - brain.clock) / maxf(float(warning.active.window), 0.01), 0.0, 1.0)
			g.line(face_point(), head, g.COLOURS.cue)
			g.ring(victim.global_position, 0.3 + 1.2 * left, g.COLOURS.cue, 20)
	for r in drained:
		var centre := FLOOR.position_of(level.manifest.rooms[int(r)])
		if g.here(centre): g.ring(centre, 0.5, Color(g.COLOURS.drain, clampf(float(drained[r]), 0.1, 1.0)), 12)

func gizmo_sight(g) -> void:
	if motion.in_duct or not g.here(global_position): return
	var eye := face_point()
	var forward := Vector3(global_basis.z.x, 0, global_basis.z.z)
	if forward.length() < 0.1: return
	forward = forward.normalized()
	for side in [-1.0, 1.0]: g.line(eye, eye + forward.rotated(Vector3.UP, deg_to_rad(SENSES.SIGHT_HALF) * side) * SENSES.SIGHT_DARK, g.COLOURS.sight)
	var body = senses.body_of(int(brain.prey)) if senses != null and brain != null and int(brain.prey) >= 0 else null
	if body != null and senses.sees(body): g.line(eye, body.global_position + Vector3.UP * 1.5, g.COLOURS.aim)

func gizmo_ducts(g) -> void:
	if ducts == null: return
	for e in ducts.edges:
		var a: Vector3 = ducts.nodes[int(e[0])]
		var b: Vector3 = ducts.nodes[int(e[1])]
		if not g.here(a) or not g.here(b): continue
		var colour: Color = g.COLOURS.duct if String(e[3]) != "plenum" else Color(g.COLOURS.duct, 0.35)
		g.line(a, b, colour)
		if ducts.visible_kinds.has(String(e[3])): g.line(a + Vector3.UP * 0.03, b + Vector3.UP * 0.03, colour)
	for x in ducts.exits.size():
		var exit: Dictionary = ducts.exits[x]
		if String(exit.kind) == "tile" or not g.here(exit.position): continue
		var node := int(exit.node)
		var shut: bool = not routes.exit_usable(x) or (node >= 0 and ducts.closed_wings[ducts.node_wings[node]] != 0)
		g.mark(exit.position, g.COLOURS.closed if shut else g.COLOURS.exit, 0.25)
	for room in ducts.open_tiles:
		for tile in ducts.open_tiles[room]:
			var p: Vector3 = ducts.tile_point(int(room), tile)
			if g.here(p): g.ring(p, 0.35, g.COLOURS.exit, 8)
	for leg in motion.legs:
		if String(leg.kind) != "duct": continue
		var points: PackedVector3Array = leg.points
		for i in range(1, points.size()): g.line(points[i - 1], points[i], g.COLOURS.duct_path)
	if motion.in_duct and g.here(motion.duct_point): g.ring(motion.duct_point, 0.4, g.COLOURS.duct_path, 12)

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
	brain.scared.connect(func(cause: String, seat: int):
		scares += 1
		tell("scare", [seat, cause, face_point(), brain.torches.duplicate() if torch_drunk > 0.0 else [], torch_drunk]))

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
	if int(brain.state) != tally_state:
		tally_state = int(brain.state)
		if brain.state == BRAIN.State.PEEK: peeks += 1
	cue = brain.state == BRAIN.State.CUE
	snuff_step(delta)

## The light coming on where she is, and the fans stopping, told to her mind.
func watch_systems(delta: float, face: Vector3) -> void:
	systems_clock -= delta
	if systems_clock > 0.0: return
	systems_clock = SYSTEMS_EVERY
	var room: int = motion.room() if not motion.in_duct else -1
	if room >= 0 and level.get("hotel") != null:
		var lit_now: bool = level.hotel.lit(room)
		# Her own drink given back is not somebody lighting it (G8).
		var hers: bool = room == deep_room or float(drained.get(room, 0.0)) > SENSES.DRAIN.y + SENSES.DRAIN_WOBBLE
		if room_was_lit.has(room) and not bool(room_was_lit[room]) and lit_now and not hers: brain.on_room_lit(face)
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
	intent_clip = clip_name
	if visual != null: visual.look_point = wanted.get("look", Vector3.INF)
	var same: bool = last_order.get("do", &"") == what
	match what:
		&"keep":
			return
		&"hold":
			order_failed = false
			if not same: motion.hold()
		&"pause":
			# Slows to a stop keeping her way (the silence, a look): the next go
			# to the same place goes on without a new plan.
			order_failed = false
			if not same: motion.pause()
		&"go":
			var to: Vector3 = wanted.to
			var hidden: bool = bool(wanted.get("hidden", false))
			if not same or (last_order.get("to", Vector3.INF) as Vector3).distance_to(to) > 0.3 or float(last_order.get("speed", 0.0)) != float(wanted.speed) or bool(last_order.get("hidden", false)) != hidden:
				# Going with somebody in her eye (a look given): over surfaces,
				# never into the ceiling, where she sees nothing; with no way
				# over them (a door shut, glass between), or sent hidden (her
				# way watched in the light, spec_lurker_rebuild 2.1), by the
				# plenum.
				var surface: bool = (wanted.get("look", Vector3.INF) as Vector3) != Vector3.INF and not hidden
				order_failed = not motion.go_to(to, float(wanted.speed), surface)
				if order_failed and surface: order_failed = not motion.go_to(to, float(wanted.speed))
		&"duct", &"listen":
			if not same or int(last_order.get("exit", -2)) != int(wanted.exit):
				order_failed = not motion.go_to_exit(int(wanted.exit), float(wanted.get("speed", BRAIN.CRAWL_SPEED)))
		&"vanish":
			# Taken to be inside after a flight that would not end (2.2): into
			# the nearest duct, only where nobody sees her go.
			order_failed = false
			if not same and motion.surface() and not SIGHT.watched(level, face_point(), [get_rid()]):
				motion.place_in_duct(ducts.nearest_node(motion.anchor()))
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

## Reached the point she was last sent to (spec_lurker_rebuild 2.1), not
## merely standing still: within ARRIVE_NEAR of it across the floor.
const ARRIVE_NEAR := 0.6
func arrived() -> bool:
	if motion == null or not motion.at_goal(): return false
	if StringName(last_order.get("do", &"")) != &"go": return true
	var to: Vector3 = last_order.get("to", Vector3.INF)
	var at: Vector3 = motion.anchor()
	return Vector2(to.x - at.x, to.z - at.z).length() <= ARRIVE_NEAR

func route_failed() -> bool: return order_failed or (motion != null and motion.route_state() == &"blocked")

func on_channel() -> bool: return motion != null and motion.on_channel()

# --- What she knows of the map: the world port (7.9, 8.4) -------------------------------------

## Behind them along their eased heading (not every flick of the mouse), on
## her ceiling over that point; never a point with no ceiling.
func behind_point(seen, metres: float) -> Vector3:
	var at: Vector3 = (seen.eye as Vector3) - flat_heading(seen) * metres
	var room := FLOOR.room_at(level.manifest.rooms, seen.point)
	if not room.is_empty() and shell.tray_of.has(int(room.id)):
		var s = shell.tray_state(int(room.id), at.x, at.z)
		return shell.anchor_of(s)
	var s = shell.state_at(Vector3(at.x, (seen.point as Vector3).y + 1.0, at.z))
	return shell.anchor_of(s) if s != null else ceiling_near(seen, at)

## Their eased heading, flat (lurker_senses Seen.heading), else their view.
func flat_heading(seen) -> Vector3:
	var h: Vector3 = seen.heading
	var flat := Vector3(h.x, 0, h.z)
	if flat.length() < 0.01: flat = Vector3(seen.view.x, 0, seen.view.z)
	return flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD

## Where she stalks somebody from (spec_lurker_rebuild 2.4): a ceiling out of
## their cone (STALK_CONE degrees either side of their eased heading), near
## `metres` from them, in their room or one next to it; behind them and in
## the dark first. Never INF.
const STALK_CONE := 60.0
const STALK_TURNS := [0.0, 35.0, -35.0, 70.0, -70.0, 105.0, -105.0]
const STALK_REACH := [1.0, 0.75, 1.3]
func stalk_point(seen, metres: float) -> Vector3:
	var heading := flat_heading(seen)
	var eye: Vector3 = seen.eye
	var room := int(FLOOR.room_at(level.manifest.rooms, seen.point).get("id", -1))
	var rooms: Array = ([room] + Array(level.manifest.adjacency[room])) if room >= 0 else []
	var best := Vector3.INF
	var best_score := INF
	for turn in STALK_TURNS:
		var away := (-heading).rotated(Vector3.UP, deg_to_rad(float(turn)))
		for reach in STALK_REACH:
			var at: Vector3 = eye + away * metres * float(reach)
			var r := int(FLOOR.room_at(level.manifest.rooms, at).get("id", -1))
			if not rooms.has(r) or not shell.tray_of.has(r): continue
			var p: Vector3 = shell.anchor_of(shell.tray_state(r, at.x, at.z))
			var to := Vector3(p.x - eye.x, 0, p.z - eye.z)
			if to.length() > 0.01 and rad_to_deg(heading.angle_to(to)) < STALK_CONE: continue
			var score: float = absf(float(turn)) / 90.0 + absf(float(reach) - 1.0) + (1.0 if SIGHT.lit_point(level, p) else 0.0)
			if score < best_score:
				best_score = score
				best = p
	return best if best != Vector3.INF else ceiling_near(seen, eye - heading * metres)

## A ceiling nearest `at` for somebody at `seen`, never INF: the free tile of
## their room or a room next to it nearest `at`; else where she is.
func ceiling_near(seen, at: Vector3) -> Vector3:
	var room := int(FLOOR.room_at(level.manifest.rooms, seen.point).get("id", -1))
	var best := Vector3.INF
	if room >= 0:
		for r in [room] + Array(level.manifest.adjacency[room]):
			if not ducts.room_tiles.has(int(r)) or not shell.tray_of.has(int(r)): continue
			for t in ducts.room_tiles[int(r)]:
				var p: Vector3 = clue_point(ducts.tile_point(int(r), t))
				if best == Vector3.INF or p.distance_to(at) < best.distance_to(at): best = p
	return best if best != Vector3.INF else motion.anchor()

func plan_start() -> Dictionary:
	var from: Dictionary = motion.plan_start()
	return from.get("start", {"room": motion.room()})

func flee_exit(away_from: Vector3) -> int:
	return routes.flee_exit(plan_start(), away_from, global_position)

## Where she comes back out of the ceiling for another attempt on `seat`
## (spec_f3_aggression), from where she knows them to be: her ceiling just
## under a way out of the ducts of their planta (a grille, a gap or any tile
## of a false ceiling), in a room
## not lit and not off limits, `span` metres from them ("behind": behind
## their back; "far" and "near": by the span alone); the nearest to the
## middle of the span. Vector3.INF with none.
func emerge_point(_seat: int, mode: String, span: Vector2, known: Vector3, heading: Vector3) -> Vector3:
	# Where she knows them to be (spec_lurker_rebuild 2.4), never where they are.
	if known == Vector3.INF or ducts == null: return Vector3.INF
	var at := known
	var forward := Vector3(heading.x, 0, heading.z)
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var best := Vector3.INF
	var best_score := INF
	for e in ducts.exits.size():
		var exit = ducts.exits[e]
		if String(exit.kind) == "hatch" or not routes.exit_usable(e): continue
		var room := int(exit.room)
		if room >= 0 and level.hotel.lit(room): continue
		var ways: Array = [exit.position]
		if String(exit.kind) == "tile":
			if not shell.tray_of.has(room): continue
			ways = ducts.room_tiles[room].map(func(t): return ducts.tile_point(room, t))
		for p in ways:
			if FLOOR.planta_of(p.y) != FLOOR.planta_of(at.y) or level.point_protected(p): continue
			var flat := Vector3(p.x - at.x, 0, p.z - at.z)
			var d := flat.length()
			if d < span.x or d > span.y: continue
			var score := absf(d - (span.x + span.y) * 0.5)
			if mode == "behind":
				var ahead := forward.dot(flat / maxf(d, 0.01))
				if ahead > -0.2: continue
				score += ahead * 2.0
			if score < best_score:
				best_score = score
				best = p
	return clue_point(best) if best != Vector3.INF else Vector3.INF

## A tile she goes through (spec_f3_aggression): the hotel swings it (down
## and left half open as she comes out; up and shut again after her as she
## goes in), the grid creaks with dust, one hand takes it for the swing, and
## the plenum keeps which ones she left open. On every machine, by her event
## "tile" (tell()).
const TILE_HAND := "a.R"
const TILE_GRIP := 0.4
func turn_tile(room: int, tile: Vector2i, open: bool, from_below: bool) -> void:
	var list: Array = ducts.open_tiles.get(room, [])
	if open and from_below and list.has(tile): return
	if open and not from_below and not list.has(tile): list.append(tile)
	if not open or from_below: list.erase(tile)
	ducts.open_tiles[room] = list
	var at: Vector3 = ducts.tile_point(room, tile)
	var hotel = level.get("hotel") if level != null else null
	if hotel != null and hotel.has_method("turn_tile"):
		var held = hotel.turn_tile(room, tile, open, from_below)
		if held is Vector3: at = held
	if voice != null: voice.tile_shift(at)
	var limbs = visual.get("limbs") if visual != null else null
	if limbs == null or not limbs.grips.is_empty(): return
	limbs.grips = {TILE_HAND: {"point": at, "normal": Vector3.DOWN}}
	get_tree().create_timer(TILE_GRIP).timeout.connect(func(): if is_instance_valid(limbs) and limbs.grips.has(TILE_HAND) and limbs.grips.size() == 1: limbs.grips = {})

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

## A grille or a gap of the room (she listens at one: a closed tile lets
## nothing through); -1 with none.
func exit_of_room(room: int) -> int:
	for e in ducts.exits_of_room(room):
		if ducts.sounding(ducts.exits[e]): return e
	return -1

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

## Her lies to a mind that is going (spec_f3_integration 4).
func hallucinations() -> Variant: return load("res://game/app/hallucinations/lurker_hallucinations.gd")

## A moment of hers every machine must hear of (spec_f3_integration 6.3):
## applied here and, in a match, told reliably to the others, whose puppet
## applies it with on_event() (match_net.creature_event()).
##   "scare" [by_seat, cause, at, seats, seconds]: her shriek heard, the minds
##           near it frightened where minds are kept, and the torches of
##           `seats` drunk for `seconds` (G1; the last two may be missing)
##   "tile"  [room, tile_x, tile_y, open, from_below]: a tile she went through
##   "snuff" [room]: the room she drinks dark (G8), -1 when she gives it back
## Phase 4 adds "room_off" [room, seconds] (versus: a room she drinks dark).
## Her going into and out of a grille is heard on every machine from her
## flags (sound_step()), with no event of its own.
func tell(kind: String, data: Array) -> void:
	on_event(kind, data)
	var net = level.get("match_net") if level != null else null
	if net != null and is_instance_valid(net) and net.has_method("creature_event"): net.creature_event(kind, data)

func on_event(kind: String, data: Array) -> void:
	match kind:
		"scare":
			var at: Vector3 = data[2]
			if voice != null: voice.shriek_heard(at)
			frighten(at)
			if data.size() >= 5: drink_torches(data[3], float(data[4]))
		"snuff":
			deep_room = int(data[0]) if data.size() >= 1 else -1
		"tile":
			if ducts != null and data.size() == 5: turn_tile(int(data[0]), Vector2i(int(data[1]), int(data[2])), bool(data[3]), bool(data[4]))

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

func forced_after() -> float: return force_after

## Her stalking comes and goes within one encounter: the rest is for its end.
func earned_rest() -> bool: return brain == null or brain.resting()

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

func capture_records() -> Array: return takes.duplicate(true)

## What a bots' match counts of her (spec_f3_integration 7.3): her warnings
## and what came of them (her ledger), her takes, a tool's or not, and the
## ones without their warning; her frights, peeks and trips into the ducts.
var scares := 0
var peeks := 0
var duct_trips := 0
var tally_state := -1
func tally() -> Dictionary:
	var out := {"cues": 0, "saves": 0, "captures": 0, "forced": 0, "scares": scares, "scares_torch": 0, "scares_turn": 0, "scares_mate": 0, "peeks": peeks, "duct_trips": duct_trips, "unpaired": 0}
	for e in warning.ledger:
		if bool(e.get("forced", false)): continue
		out.cues += 1
		if String(e.outcome) != "saved": continue
		out.saves += 1
		if int(e.get("by", -1)) >= 0 and int(e.by) != int(e.seat): out.scares_mate += 1
		elif String(e.reason) == "linterna": out.scares_torch += 1
		elif String(e.reason) == "mirada": out.scares_turn += 1
	for take in takes:
		if bool(take.forced):
			out.forced += 1
			continue
		out.captures += 1
		if not warning.ledger.any(func(e): return int(e.id) == int(take.cue) and int(e.seat) == int(take.seat) and String(e.outcome) == "taken"): out.unpaired += 1
	return out

## Her place in a capture is her capture style's (phase 3), not a yaw: her
## basis is upside down on a ceiling.
func turn_for_capture(_yaw: float) -> void: pass

func begin_capture(data: Dictionary) -> void:
	if brain != null: brain.on_captured(data)
	if motion != null: motion.hold()
	if visual != null: visual.crawling = true
	var forced: bool = level.get("executions") != null and not level.executions.forced.is_empty()
	takes.append({"seat": int(data.get("seat", -1)), "cue": int(data.get("cue", -1)), "at": brain.clock if brain != null else 0.0, "forced": forced})

func capture_style() -> Variant: return CAPTURE

func capture_length() -> float: return SCORE.CUT_TIME

func end_capture() -> void:
	if brain != null: brain.on_released()

## Her warning, played here from where she is: in the victim's own ears, and
## heard by the floor by anybody else (spec_f2_mind 9.2).
func play_cue(seat: int, cue_id: int, point: Vector3, hold: float) -> void:
	var audio = level.get("world_audio")
	if audio == null or not audio.has_method("play_cue"): return
	var mine: bool = level.get("player") != null and seat == int(level.player.slot) and (not level.has_method("local_alive") or level.local_alive())
	var sounds: Array = WARNING.cue_sounds(hold)
	var path: String = sounds[cue_id % sounds.size()]
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
	if deep_room >= 0: rooms[deep_room] = true
	var line := float(hotel.LIT_DRAIN)
	for r in rooms:
		var deep: bool = int(r) == deep_room
		var was := float(drained.get(r, 0.0))
		var target: float = DEEP if deep else float(drain_targets.get(r, 0.0))
		# Drunk dark slowly, given back in about a second (G8); else as ever.
		var rate: float = DEEP_RISE if deep else (DEEP_FALL if was > SENSES.DRAIN.y + SENSES.DRAIN_WOBBLE else SENSES.DRAIN_EASE)
		var now := move_toward(was, target, rate * delta)
		var sent := now
		var wave := sin(TAU * float(hash(int(r)) % 5 + 7) * drain_time + float(r))
		if deep and not reduced:
			# The tremble grows as it goes; once dark, what is left trembles on,
			# never back over the line (lit() would blink).
			if now >= line: sent = clampf(now + DEEP_REST_WOBBLE * wave, line + 0.005, 0.98)
			else: sent = clampf(now + DEEP_WOBBLE * wave, 0.0, line - 0.01)
		elif not deep and target > 0.0 and not reduced: sent = clampf(now + SENSES.DRAIN_WOBBLE * wave, 0.0, 0.89)
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
	torch_step(delta, reduced)

## A fright by torch drinks it (iteration 2, G1): on every machine, from her
## event. Its click where it is; no caption, nothing on screen.
func drink_torches(seats: Array, seconds: float) -> void:
	if seconds <= 0.0 or level == null: return
	var audio = level.get("world_audio")
	for seat in seats:
		drunk[int(seat)] = seconds
		var one = survivor_of(int(seat))
		if one != null and audio != null and audio.has_method("play_at") and is_instance_valid(one.get("torch")): audio.play_at(DRUNK_SOUND, one.torch.global_position, DRUNK_GAIN)

## Every frame: each drunk torch's beam down and flickering, back up at the
## end; given back whole once it is over.
func torch_step(delta: float, reduced: bool) -> void:
	for seat in drunk.keys():
		var left := float(drunk[seat]) - delta
		var one = survivor_of(int(seat))
		if left <= 0.0:
			drunk.erase(seat)
			if one != null and "torch_dim" in one: one.torch_dim = 1.0
			continue
		drunk[seat] = left
		var low := DRUNK_BEAM
		# Uneven: two beats that rarely meet, a filament starved of current.
		if not reduced: low *= 0.5 + 0.5 * absf(sin(drain_time * 23.0 + float(seat))) * (0.6 + 0.4 * sin(drain_time * 7.3 + float(seat) * 1.7))
		if one != null and "torch_dim" in one: one.torch_dim = lerpf(1.0, low, clampf(left / DRUNK_RAMP, 0.0, 1.0))

## The survivor of a seat on this machine, null when none.
func survivor_of(seat: int):
	if level == null or not level.has_method("survivors"): return null
	for one in level.survivors():
		if is_instance_valid(one) and "slot" in one and int(one.slot) == seat: return one
	return null

## On the machine in charge, after her mind (G8): stalking somebody in a lit
## room for snuff_time s on end, she drinks that room dark; she keeps it while
## her encounter on them goes on there, and gives it back when it ends, when
## they have been out of it DEEP_OUT s, or after DEEP_MOST s.
func snuff_step(delta: float) -> void:
	if snuff_time <= 0.0 or level == null or level.get("hotel") == null: return
	var clock: float = brain.clock
	var prey_body = senses.body_of(int(brain.prey)) if int(brain.prey) >= 0 else null
	var theirs := room_of_point(prey_body.global_position) if prey_body != null else -1
	if deep_room >= 0:
		deep_out = deep_out + delta if theirs != deep_room else 0.0
		var mine: int = motion.room()
		var near: bool = mine == deep_room or (mine >= 0 and Array(level.manifest.adjacency[deep_room]).has(mine))
		var going: bool = brain.state in [BRAIN.State.STALK, BRAIN.State.HUSH, BRAIN.State.CREEP, BRAIN.State.CUE] and int(brain.prey) == deep_prey
		if not going or not near or deep_out > DEEP_OUT or clock - deep_since > DEEP_MOST: snuff(-1, -1)
		return
	var aim := theirs if brain.state == BRAIN.State.STALK and theirs >= 0 and level.hotel.lit(theirs) and may_snuff(theirs, clock) else -1
	snuff_clock = snuff_clock + delta if aim >= 0 and aim == snuff_aim else 0.0
	snuff_aim = aim
	if aim >= 0 and snuff_clock >= snuff_time: snuff(aim, int(brain.prey))

## A room she may drink dark: one that may be dark at all, not protected nor
## off limits, and not given back in the last DEEP_AGAIN s.
func may_snuff(room: int, clock: float) -> bool:
	var data: Dictionary = level.manifest.rooms[room]
	if not OFFICE.may_be_dark(data) or level.point_protected(FLOOR.position_of(data)): return false
	if level.has_method("off_limits_rooms") and level.off_limits_rooms().has(room): return false
	return clock - float(snuffed.get(room, -INF)) >= DEEP_AGAIN

## Drinks `room` dark for `seat`, or gives it back (-1): told to every machine.
func snuff(room: int, seat: int) -> void:
	var clock: float = brain.clock if brain != null else 0.0
	if room < 0 and deep_room >= 0: snuffed[deep_room] = clock
	deep_prey = seat
	deep_since = clock
	deep_out = 0.0
	snuff_clock = 0.0
	snuff_aim = -1
	tell("snuff", [room])

## Every room she drank given back at once (a stage given back, a floor continued).
func undrain() -> void:
	if level == null or level.get("hotel") == null: return
	for r in drained:
		level.hotel.drain(int(r), 0.0)
		if level.hotel.has_method("drain_emergency"): level.hotel.drain_emergency(int(r), 0.0)
	drained = {}
	drain_targets = {}
	draining = false
	deep_room = -1
	deep_prey = -1
