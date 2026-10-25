extends RefCounted
## The Lurker's senses (docs/OFICINAS.md 4 and 11.5; spec_f2_mind 5): what
## she perceives of each survivor, worked out on the machine that drives her,
## and handed to the brain as a Percept. "Los suyos": the director never tells
## her where anybody is. What she must not do (the warning) is decided on the
## truth, which only ever holds her back. This step (2b-1) has the data the
## brain and the warning read; sight, hearing and the drain come with 2b-2.

## One survivor as she has them this tick. `seen` and the perceived fields come
## from her senses; for her prey's seat the senses also fill the truth
## (Percept.victim), which only the warning's restraints and cue_ready() read.
class Seen extends RefCounted:
	var seat := -1
	## null in a harness.
	var body: Node3D = null
	## Feet, camera, camera forward (normalised).
	var point := Vector3.ZERO
	var eye := Vector3.ZERO
	var view := Vector3.FORWARD
	## sees() this tick; brain clock of the last sight and of the last noise
	## she took for theirs.
	var seen := false
	var seen_at := -INF
	var heard_at := -INF
	## Their eye in a lit place; their torch on; hidden, and in a locker she
	## saw them get into (that locker).
	var lit := false
	var torch := false
	var hidden := false
	var hide_known := false
	var hide: Node3D = null
	## Fair game (active and exploring), protected (a refuge, a car, untouchable).
	var fair := false
	var protected := false
	var remote := false
	## s added to their window (tests, then phase 4).
	var latency := 0.0
	## Her face to their eye; whether she is behind or above them out of
	## their look; whether they look at her face and can make it out.
	var distance := INF
	var behind := false
	var above := false
	var regards := false
	## Metres to the nearest other survivor she perceives or remembers.
	var alone := INF
	## m/s across the floor: running away during the window is what saves
	## (the author, 24 October 2026), walking is not.
	var speed := 0.0

class Percept extends RefCounted:
	var grace := false
	var face := Vector3.ZERO
	## Room of her face; -1 inside a network duct.
	var room := -1
	var in_duct := false
	## Duct exit index she is at, else -1.
	var exit_here := -1
	var off_limits := false
	var regarded_by: Array[int] = []
	var torch_by: Array[int] = []
	## Anybody would see her along the motion's next stretch.
	var stretch_exposed := false
	var moving := false
	var arrived := false
	var failed := false
	## lurker.transit_phase(): &"" when not between plantas.
	var transit: StringName = &""
	var on_channel := false
	## seat -> Seen: seen now, or remembered within `forget`.
	var bodies := {}
	## The truth about the brain's prey (perceived or not); null when none or
	## the seat has no body.
	var victim: Seen = null
	## level.sound_mask(face): the fans (planta 3).
	var mask := 0.0

const SIGHT := preload("res://game/enemies/creature_sight.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
## She sees whoever is in the dark to here, without needing a torch
## (OFICINAS 4: ~20 m); into a lit place only this far: the light blinds her.
const SIGHT_DARK := 20.0
const SIGHT_LIT := 4.0
## A lit torch in the dark gives its holder away from this far (the beam).
const BEAM_SEEN := 35.0
## Degrees to either side of where her head looks: all round but straight
## behind; nearer than SIGHT_NEAR she feels them whatever the angle.
const SIGHT_HALF := 110.0
const SIGHT_NEAR := 1.5
## How often she looks (rays); the restraints are checked every tick.
const SENSE_EVERY := 0.1
## At a grille, listening, she hears this much further.
const LISTEN_EAR := 1.4
## How much of her hearing the fans take at full cover (planta 3).
const FAN_DEAF := 0.7
## A torch switched on or off: heard this many metres off (OFICINAS 4: she
## hears the click).
const TORCH_CLICK := 8.0
## As The Locust's hear_route() (hotel_locust.gd).
const APPARENT_NEAREST := 3.5
## Share of a lamp's light she drinks, from the edge of her reach to right
## under it (the lamp keeps 30 to 60 % of itself).
const DRAIN := Vector2(0.4, 0.7)
const DRAIN_EVERY := 0.1
## Share per second the light comes back after her (and goes when she comes).
const DRAIN_EASE := 1.5
## The tubes flicker while she drinks: so much either way, 7 to 11 times a second.
const DRAIN_WOBBLE := 0.08

var level
var body
var graph
var hearing := 1.0
var forget := 12.0
## Set by the brain in LISTEN.
var listening := false
## Lockers she saw somebody get into: hide node -> true.
var saw_hides := {}
## seat -> Seen, last perceived.
var memory := {}
## seat -> bool, for the clicks; a seat not in it yet makes no click.
var torch_was := {}
var look_clock := 0.0
var look_turn := 0
## seat -> bool: the last look's verdict.
var looked := {}
var clicks: Array = []

func setup(owner_level, owner_body, duct_graph) -> void:
	level = owner_level
	body = owner_body
	graph = duct_graph

func tune(profile: Dictionary) -> void:
	hearing = float(profile.get("hearing", hearing))
	forget = float(profile.get("forget", forget))

# --- Sight (5.4) ------------------------------------------------------------------

## Where she looks from: her face, or inside a network duct the exit she is at
## (from nowhere between exits).
func eye_point() -> Vector3:
	if body.in_network_duct():
		var e: int = body.at_exit()
		if e < 0: return Vector3.INF
		var exit: Dictionary = graph.exits[e]
		# Nothing is seen through a closed tile.
		if String(exit.kind) == "tile": return Vector3.INF
		return (exit.position as Vector3) - (exit.normal as Vector3) * 0.05
	return body.face_point()

func sees(player: Node3D, ignore_concealment := false) -> bool:
	if not SIGHT.alive(level, player) or not level.survivor_active(player) or float(body.grace) > 0.0: return false
	if bool(player.get("hidden")): return ignore_concealment and saw_hides.has(player.get("hiding_place"))
	var eye := eye_point()
	if eye == Vector3.INF: return false
	if SIGHT.torch_covers(level, player, body.face_point(), [body.get_rid()]): return false
	var camera: Vector3 = player.camera.global_position
	var torch_on: bool = "torch" in player and is_instance_valid(player.torch) and player.torch.visible
	var reach := SIGHT_LIT if SIGHT.lit_point(level, camera) else (BEAM_SEEN if torch_on else SIGHT_DARK)
	var to := camera - eye
	if to.length() > reach: return false
	if to.length() > SIGHT_NEAR and rad_to_deg(body.gaze().angle_to(to)) > SIGHT_HALF: return false
	var exclude := [body.get_rid(), player.get_rid()]
	return SIGHT.clear(level, eye, camera, exclude) or SIGHT.clear(level, eye, camera - Vector3(0, 0.6, 0), exclude)

## Called before the survivor is inside: only the locker is kept.
func saw_enter(hide: Node3D) -> void:
	if is_instance_valid(hide): saw_hides[hide] = true

# --- Hearing (5.5) -----------------------------------------------------------------

func room_of(point: Vector3) -> int:
	return int(FLOOR.room_at(level.manifest.rooms, point).get("id", -1))

## How a noise reaches her: {audible, apparent, distance, muffle, via}.
func hear_route(point: Vector3, radius: float) -> Dictionary:
	var missed := {"audible": false, "apparent": point, "distance": INF, "muffle": 1.0, "via": ""}
	var face: Vector3 = body.face_point()
	if level.point_protected(point) or FLOOR.planta_of(point.y) != FLOOR.planta_of(face.y) or body.in_transit(): return missed
	var mask: float = float(level.sound_mask(face)) if level.has_method("sound_mask") else 0.0
	var reach := radius * NOISE.HEARING_SCALE * hearing * float(body.dull) * (LISTEN_EAR if listening else 1.0) * (1.0 - FAN_DEAF * mask)
	var best := missed
	if not body.in_network_duct():
		var by_room := room_route(face, point, reach)
		if bool(by_room.audible): best = by_room
	if graph != null and not graph.closed:
		var by_duct := duct_route(face, point, reach)
		if bool(by_duct.audible) and float(by_duct.distance) < float(best.distance): best = by_duct
	return best

## By the rooms: hotel_locust.hear_route() step for step, from her ear.
func room_route(face: Vector3, point: Vector3, reach: float) -> Dictionary:
	var missed := {"audible": false, "apparent": point, "distance": INF, "muffle": 1.0, "via": "room"}
	var exclude := [body.get_rid()]
	var straight := face.distance_to(point)
	if straight > reach: return missed
	if SIGHT.clear(level, face, point + Vector3(0, 1, 0), exclude):
		return {"audible": true, "apparent": point, "distance": straight, "muffle": 0.0, "via": "room"}
	var start := FLOOR.floor_point(face)
	var route := FLOOR.navigation_path(level.get_world_3d().navigation_map, start, point)
	if route.size() < 2: return missed
	var end := route[route.size() - 1]
	var near := FLOOR.floor_point(point)
	if Vector2(end.x - near.x, end.z - near.z).length() > 1.5: return missed
	var length := 0.0
	for i in range(1, route.size()): length += route[i].distance_to(route[i - 1])
	if length > reach: return missed
	var apparent: Vector3 = route[0] + Vector3.UP * 1.5
	for i in range(1, route.size()):
		var probe: Vector3 = route[i] + Vector3.UP * 1.5
		if not SIGHT.clear(level, face, probe, exclude): break
		apparent = probe
	var first: Vector3 = route[0] + Vector3.UP * 1.5
	if apparent.distance_to(first) < APPARENT_NEAREST:
		var way: Vector3 = route[1] - route[0]
		way.y = 0.0
		if way.length() > 0.01: apparent = first + way.normalized() * APPARENT_NEAREST
	var detour := maxf(0.0, length - face.distance_to(apparent))
	return {"audible": true, "apparent": apparent, "distance": length, "muffle": clampf(detour / 25.0, 0.0, 1.0), "via": "room"}

## By the ducts: 2a's inbound(), into her duct, or to the grilles of her room.
func duct_route(face: Vector3, point: Vector3, reach: float) -> Dictionary:
	var missed := {"audible": false, "apparent": point, "distance": INF, "muffle": 1.0, "via": "duct"}
	var best := missed
	if body.in_network_duct():
		var route: Dictionary = graph.inbound(point, reach, body.duct_node(), room_of)
		if bool(route.audible) and float(route.metres) <= reach:
			best = {"audible": true, "apparent": face, "distance": float(route.metres), "muffle": 0.5 + 0.5 * clampf(float(route.metres) / 40.0, 0.0, 1.0), "via": "duct"}
		return best
	for e in graph.exits_of_room(room_of(face)):
		var exit: Dictionary = graph.exits[e]
		var mouth: Vector3 = exit.position
		var air := face.distance_to(mouth)
		if air >= reach or int(exit.node) < 0 or not SIGHT.clear(level, face, mouth, [body.get_rid()]): continue
		var route: Dictionary = graph.inbound(point, reach - air, int(exit.node), room_of)
		if not bool(route.audible): continue
		var distance := float(route.metres) + air
		if distance <= reach and distance < float(best.distance):
			best = {"audible": true, "apparent": mouth, "distance": distance, "muffle": 0.5 + 0.5 * clampf(distance / 40.0, 0.0, 1.0), "via": "duct"}
	return best

# --- The light she drinks (5.6) ---------------------------------------------------------

## Lamp points per room (troffers, the battens over the aisles, the room's own
## light, and the emergency units, which tremble with her too: the author),
## cached by manifest.
static func lamp_points(level, cache: Dictionary) -> Dictionary:
	if cache.get("manifest") == level.manifest: return cache.points
	var points := {}
	var palette = FLOOR.palette(level.manifest)
	var off: Array = level.off_limits_rooms() if level.has_method("off_limits_rooms") else []
	for room in level.manifest.rooms:
		var id := int(room.id)
		if FLOOR.is_void(room) or off.has(id): continue
		var py := float(room.get("py", 0.0))
		var top := py + float(room.get("height", 2.95))
		var list := PackedVector3Array()
		var lamp: String = palette.lamp_of(room)
		if lamp == "troffer" and palette.has_method("troffers"):
			for t in palette.troffers(room): list.append(Vector3((t.centre as Vector2).x, top, (t.centre as Vector2).y))
		elif lamp != "emergency" and id < level.hotel.lights.size() and is_instance_valid(level.hotel.lights[id]):
			list.append(level.hotel.lights[id].global_position)
		for unit in level.hotel.get("emergency") if level.hotel.get("emergency") != null else []:
			if int(unit.room) == id and is_instance_valid(unit.light): list.append(unit.light.global_position)
		if not list.is_empty(): points[id] = list
	cache["manifest"] = level.manifest
	cache["points"] = points
	return points

## The light she drinks from `point`: {room: amount} for every room of her
## planta with a lamp within `reach` that is alight. Never an off-limits room
## (the freight lobbies stay the safe place: the author).
static func drain_rooms(level, point: Vector3, reach: float, cache: Dictionary) -> Dictionary:
	var out := {}
	var planta := FLOOR.planta_of(point.y)
	var points := lamp_points(level, cache)
	for id in points:
		var room: Dictionary = level.manifest.rooms[int(id)]
		if FLOOR.planta_of(float(room.get("py", 0.0)) + 1.0) != planta or not level.hotel.lit(int(id)): continue
		var nearest := INF
		for lamp in points[id]: nearest = minf(nearest, (lamp as Vector3).distance_to(point))
		if nearest <= reach: out[int(id)] = lerpf(DRAIN.y, DRAIN.x, nearest / reach)
	return out

# --- The percept (5.7) ------------------------------------------------------------------

func perceive(delta: float, clock: float, prey_seat: int):
	var p = Percept.new()
	p.grace = float(body.grace) > 0.0
	p.face = body.face_point()
	p.in_duct = body.in_network_duct()
	p.room = -1 if p.in_duct else room_of(p.face)
	p.exit_here = body.at_exit()
	var off: Array = level.off_limits_rooms() if level.has_method("off_limits_rooms") else []
	p.off_limits = p.room >= 0 and off.has(p.room)
	p.mask = float(level.sound_mask(p.face)) if level.has_method("sound_mask") else 0.0
	p.moving = body.moving()
	p.arrived = body.arrived()
	p.failed = body.route_failed()
	p.transit = body.transit_phase()
	p.on_channel = body.on_channel()
	torch_clicks()
	if not p.in_duct:
		var seen_by: Dictionary = SIGHT.regarders(level, p.face, [body.get_rid()])
		p.regarded_by = seen_by.regarded_by
		p.torch_by = seen_by.torch_by
		p.stretch_exposed = SIGHT.stretch_exposed(level, body.ahead(3.0), [body.get_rid()])
	# Her looks, every SENSE_EVERY; one survivor a tick when there are many.
	var survivors: Array = level.survivors()
	look_clock -= delta
	if look_clock <= 0.0:
		look_clock = SENSE_EVERY
		if survivors.size() > 4:
			look_turn = (look_turn + 1) % survivors.size()
			var one = survivors[look_turn]
			if is_instance_valid(one) and "slot" in one: looked[int(one.slot)] = sees(one)
		else:
			for one in survivors:
				if is_instance_valid(one) and "slot" in one: looked[int(one.slot)] = sees(one)
	for one in survivors:
		if not is_instance_valid(one) or not "slot" in one: continue
		var seat := int(one.slot)
		if bool(looked.get(seat, false)):
			var s = seen_of(one, p, clock)
			s.seen = true
			s.seen_at = clock
			memory[seat] = s
	for seat in memory.keys():
		if clock - float(memory[seat].seen_at) > forget: memory.erase(seat)
	for seat in memory:
		var s = memory[seat]
		# Remembered is not seen: only this look's verdict says she sees them now.
		s.seen = bool(looked.get(int(seat), false))
		s.alone = INF
		for other in memory:
			if other != seat: s.alone = minf(s.alone, (s.point as Vector3).distance_to(memory[other].point))
		p.bodies[seat] = s
	if prey_seat >= 0:
		var prey_body = body_of(prey_seat)
		if prey_body != null:
			var v = seen_of(prey_body, p, clock)
			v.seen = bool(looked.get(prey_seat, false))
			v.seen_at = float(memory[prey_seat].seen_at) if memory.has(prey_seat) else -INF
			v.alone = float(memory[prey_seat].alone) if memory.has(prey_seat) else INF
			p.victim = v
	return p

func body_of(seat: int):
	for one in level.survivors():
		if is_instance_valid(one) and "slot" in one and int(one.slot) == seat: return one
	return null

## One survivor as things are now (no ray of its own: the regard is the
## percept's).
func seen_of(one, p, clock: float):
	var s = Seen.new()
	s.seat = int(one.slot)
	s.body = one
	s.point = one.global_position
	s.eye = one.camera.global_position
	s.view = -one.camera.global_basis.z
	s.lit = SIGHT.lit_point(level, s.eye)
	s.torch = "torch" in one and is_instance_valid(one.torch) and one.torch.visible
	s.hidden = bool(one.get("hidden"))
	var hide = one.get("hiding_place")
	s.hide_known = s.hidden and hide != null and saw_hides.has(hide)
	s.hide = hide if s.hide_known else null
	var session = level.get("session")
	s.fair = level.survivor_active(one) and (session == null or session.participants.get(s.seat, -1) == session.Life.EXPLORING)
	s.protected = level.point_protected(s.point) or (level.lifts != null and level.lifts.riding.has(s.seat)) or (level.get("untouchable") != null and level.untouchable.has(s.seat))
	s.remote = SIGHT.is_remote(level, one)
	s.latency = float(body.warning.latency_for.get(s.seat, 0.0))
	s.distance = (p.face as Vector3).distance_to(s.eye)
	s.behind = SIGHT.behind_of(s.eye, s.view, p.face)
	s.above = SIGHT.over_of(s.eye, s.view, p.face)
	s.regards = p.regarded_by.has(s.seat)
	var velocity: Vector3 = one.get("velocity") if one.get("velocity") != null else Vector3.ZERO
	s.speed = Vector2(velocity.x, velocity.z).length()
	return s

## A torch switched on or off where she can hear it: a noise like any other.
func torch_clicks() -> void:
	for one in level.survivors():
		if not is_instance_valid(one) or not "slot" in one or not "torch" in one or not is_instance_valid(one.torch): continue
		var seat := int(one.slot)
		var now: bool = one.torch.visible
		if torch_was.has(seat) and bool(torch_was[seat]) != now:
			var point: Vector3 = one.camera.global_position
			var route := hear_route(point, TORCH_CLICK / NOISE.HEARING_SCALE)
			if bool(route.audible): clicks.append({"route": route, "point": point})
		torch_was[seat] = now
