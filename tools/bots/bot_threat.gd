extends RefCounted
## What the bots know of the creature: all of it, all the time -- where it
## stands, where it looks, what it is doing, where it is going and the way it
## will take. A person has its sounds and its aura to go by; a bot has this,
## and uses the creature's own measures (its sight, its hearing along the
## routes, its speeds) to stay out of both. Their survival is no measure of
## the game's balance; what is, is what they run into anyway.
##
## Refreshed a few times a second and shared by the whole team.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
const LOCUST := preload("res://game/enemies/locust/hotel_locust.gd")
## Its sight, a little wider than it is: it turns while a bot walks.
const SEEN_ANGLE := deg_to_rad(LOCUST.SIGHT_HALF_ANGLE + 10.0)
const SIGHT_MASK := 1 | 8 | 64
## Its hearing, a quarter longer than it is: a margin, not a guess.
const EAR_MARGIN := 1.25
## Metres of the creature's own way ahead that count as where it is going.
const PATH_AHEAD := 25.0
## Extra metres a room costs a route, by what the creature has to do with it.
const COST_PATH := 60.0
const COST_SEEN := 80.0
const COST_HEARD := 20.0
var level
var creature
var active := false
var position := Vector3.ZERO
var eye := Vector3.ZERO
var forward := Vector3.FORWARD
var mode := 0
var planta := -1
var room := -1
## Rooms the next PATH_AHEAD metres of its route go through.
var path_rooms := {}
## Room id -> extra metres, for routes (refreshed with the rest).
var danger := {}
## Where its eyes are and will be: now, every VANTAGE_STEP metres of the way
## it is taking over the next PATH_AHEAD, and where it is going. It turns as
## it walks and looks round when it gets there, so a bot in the line of any
## of them is a bot it is about to see.
var vantages: Array = []
const VANTAGE_STEP := 5.0

func _init(owner_level) -> void:
	level = owner_level

## Everything, once more. Nothing to fear from a creature that is not moving
## (--no-enemy), still in its grace, or on another planta than `wing`.
func refresh() -> void:
	creature = level.locust
	active = is_instance_valid(creature) and creature.is_physics_processing() and creature.control == "ai"
	path_rooms.clear()
	danger.clear()
	vantages.clear()
	if not active: return
	position = creature.global_position
	eye = position + Vector3(0, LOCUST.EYE_HEIGHT, 0)
	forward = -creature.global_basis.z
	mode = int(creature.mode)
	planta = FLOOR.planta_of(position.y)
	var here: Dictionary = FLOOR.room_at(level.manifest.rooms, position)
	room = int(here.get("id", -1))
	if room >= 0: danger[room] = INF
	var left := PATH_AHEAD
	var at := position
	for i in range(int(creature.path_index), creature.path.size()):
		var point: Vector3 = creature.path[i]
		var leg := at.distance_to(point)
		var steps := maxi(1, int(leg / 2.0))
		for s in steps:
			var sample := at.lerp(point, float(s + 1) / float(steps))
			var id := int(FLOOR.room_at(level.manifest.rooms, sample).get("id", -1))
			if id >= 0: path_rooms[id] = true
		left -= leg
		at = point
		if left <= 0.0: break
	for id in path_rooms:
		if id != room: danger[id] = float(danger.get(id, 0.0)) + COST_PATH
	vantages.append(eye)
	var walked := 0.0
	var next_mark := VANTAGE_STEP
	var from := position
	for i in range(int(creature.path_index), creature.path.size()):
		var point: Vector3 = creature.path[i]
		var leg := from.distance_to(point)
		while walked + leg >= next_mark and next_mark <= PATH_AHEAD:
			vantages.append(from.lerp(point, (next_mark - walked) / maxf(leg, 0.001)) + Vector3(0, LOCUST.EYE_HEIGHT, 0))
			next_mark += VANTAGE_STEP
		walked += leg
		from = point
		if walked > PATH_AHEAD: break
	if mode in [LOCUST.Mode.INVESTIGATE, LOCUST.Mode.SEARCH, LOCUST.Mode.CHASE] and FLOOR.planta_of(creature.destination.y) == planta:
		vantages.append(creature.destination + Vector3(0, LOCUST.EYE_HEIGHT, 0))

## Whether it is a thing to mind at all where this body is.
func near_planta(point: Vector3) -> bool:
	return active and creature.grace <= 0.0 and FLOOR.planta_of(point.y) == planta

## Whether the creature would see somebody standing at `point` (eye height
## `height`): inside its sight, near enough, nothing in between.
func exposed(point: Vector3, height := 1.64) -> bool:
	if not near_planta(point): return false
	var target := point + Vector3(0, height, 0)
	var offset := target - eye
	var gap := offset.length()
	if gap > LOCUST.SIGHT_RANGE: return false
	if gap > 1.5 and forward.angle_to(Vector3(offset.x, 0, offset.z)) > SEEN_ANGLE: return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, SIGHT_MASK)
	return level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Whether it could see somebody standing there if it turned: near enough and
## nothing in between, whichever way it faces. Searching, it looks all round,
## and a body in its line at thirty metres is noticed in a tenth of a second
## -- a step into that line is the step that gets a bot run down.
func visible(point: Vector3, height := 1.64) -> bool:
	if not near_planta(point): return false
	var target := point + Vector3(0, height, 0)
	if target.distance_to(eye) > LOCUST.SIGHT_RANGE: return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, SIGHT_MASK)
	return level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Whether any of its eyes, now or on its way (vantages), has a line to
## somebody standing there.
func watched(point: Vector3, height := 1.64) -> bool:
	if not near_planta(point): return false
	var target := point + Vector3(0, height, 0)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for vantage in vantages:
		if target.distance_to(vantage) > LOCUST.SIGHT_RANGE: continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(vantage, target, SIGHT_MASK)).is_empty(): return true
	return false

## Whether a noise of this kind made at `point` would reach it: its own
## measure (hotel_locust.hear_route), with a margin.
func audible(point: Vector3, noise_name: String) -> bool:
	if not near_planta(point): return false
	var radius: float = NOISE.radius(noise_name) * EAR_MARGIN
	if position.distance_to(point) > radius * NOISE.HEARING_SCALE: return false
	return bool(creature.hear_route(point, radius).audible)

## Metres of walking from the creature to `point`, or INF.
func route_to(point: Vector3) -> float:
	if not near_planta(point): return INF
	var route := FLOOR.navigation_path(level.get_world_3d().navigation_map, position, point)
	if route.size() < 2: return INF
	var total := 0.0
	for i in range(1, route.size()): total += route[i].distance_to(route[i - 1])
	return total

## Seconds for it to get there at the pace it has now (running if hunting).
func eta(point: Vector3) -> float:
	var metres := route_to(point)
	if metres == INF: return INF
	var pace: float = LOCUST.CHASE_SPEED if mode in [LOCUST.Mode.CHASE, LOCUST.Mode.ALERT] else maxf(2.9, float(creature.speed))
	return metres / pace

## Whether it is after this body: seen and being run down, or making it out
## right now. (Coming to look where it is, without having seen it, is not
## this: that is got away from quietly, bot_brain.mind_creature.)
func hunted(body) -> bool:
	if not near_planta(body.global_position): return false
	if mode in [LOCUST.Mode.ALERT, LOCUST.Mode.CHASE, LOCUST.Mode.WINDUP, LOCUST.Mode.RECOVER] and creature.focus == body: return true
	return float(creature.detection) >= LOCUST.SUSPICION and creature.sees(body, true)

## Whether its torch would catch the creature's eye: the beam on its chest,
## the way the creature measures it (hotel_locust.lit_by_torch).
func torch_catches(body) -> bool:
	if not near_planta(body.global_position): return false
	var chest := position + Vector3(0, 1.6, 0)
	var from: Vector3 = body.camera.global_position
	var offset := chest - from
	if offset.length() > LOCUST.TORCH_NOTICE_RANGE + 5.0: return false
	if (-body.camera.global_basis.z).angle_to(offset) > deg_to_rad(40.0): return false
	var query := PhysicsRayQueryParameters3D.create(from, chest, SIGHT_MASK)
	return level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## What a room adds to a route through it, by what the creature has to do with
## it: where it stands (never), where it is going, what it sees.
func room_cost(room_id: int) -> float:
	if not active: return 0.0
	var extra: float = danger.get(room_id, 0.0)
	if extra == INF: return INF
	var centre := FLOOR.position_of(level.manifest.rooms[room_id])
	if centre.distance_to(position) < LOCUST.SIGHT_RANGE and visible(centre): extra += COST_SEEN
	return extra
