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

func kind_id() -> StringName: return &"lurker"

## Only her ducts: no lifts, no sets, no shriek; no lockers (the author,
## M12: "no abre taquillas").
func can(ability: StringName) -> bool: return ability == &"ducts"

func tune(profile: Dictionary) -> void:
	tuning = profile
	duct_speed = float(profile.get("duct_speed", 1.6))
	if routes != null: routes.duct_speed = duct_speed

func activity() -> StringName: return word

func mode_name() -> String: return "ronda"

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
	if motion != null:
		motion.clear_legs()
		motion.transit = {}
		motion.pending_wing = -1
	net_states.clear()

func relocate(point: Vector3, rest: float) -> void:
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
	return {"at": global_position, "heading": global_basis.z, "hang": hang, "in_duct": motion != null and motion.in_duct, "near": motion.near_node if motion != null else -1, "wing_goal": wing_goal}

func restore_state(data: Dictionary, rest: float) -> void:
	if motion == null: return
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

func room_of_point(p: Vector3) -> int:
	return int(FLOOR.room_at(level.manifest.rooms, p).get("id", -1))

func sound_route(listener: Vector3) -> Dictionary:
	var v := view()
	if bool(v.drop): return {"audible": false, "distance": INF}
	if bool(v.in_duct) and bool(v.hidden) and ducts != null:
		return ducts.sound_route(v.duct_point, int(v.near), listener, room_of_point, level.get("world_audio"))
	var audio = level.get("world_audio") if level != null else null
	if audio == null: return {"audible": false, "distance": INF}
	return audio.route_source(global_position, get_rid(), listener)

func presence_route(listener: Vector3) -> Array:
	var v := view()
	if bool(v.in_duct) and bool(v.hidden) and ducts != null:
		var route: Dictionary = sound_route(listener)
		return [float(route.distance), route.position] if bool(route.get("audible", false)) else [INF, Vector3.INF]
	var audio = level.get("world_audio") if level != null else null
	if audio == null or audio.get("aura") == null: return [INF, Vector3.INF]
	return audio.aura.route_to(listener, FLOOR.floor_point(global_position))

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
				motion.cue = cue
				motion.tick(delta)
				apply_motion()
		"puppet":
			follow_state(delta)
	show_body()

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
