extends RefCounted
## What the bots know of the creature: all of it, all the time -- where it
## stands, where it looks, what it is doing, where it is going and the way it
## will take. A person has its sounds and its aura to go by; a bot has this,
## and uses the creature's own measures (its sight, its hearing along the
## routes, its speeds) to stay out of both. Their survival is no measure of
## the game's balance; what is, is what they run into anyway.
##
## Refreshed a few times a second and shared by the whole team.
##
## This is The Locust's model (bot_threats.gd picks it by its kind), and reads
## The Locust itself; the rest of the bots ask this, and the creature only its
## contract. It also says what a recording keeps of it, and how a replay puts
## it back (bot_recorder.gd, bot_replay.gd).
const RECORDER := preload("res://tools/bots/bot_recorder.gd")
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
## Bots that only know of the creature what they see and hear (the bot_match
## option skill "novato", docs/DIFFICULTY.md): it is known while one of them
## sees it as a player would (sanity.sight_of_creature), has it within earshot
## on its planta, or is being hunted by it, and NOVICE_MEMORY after that; the
## rest of the time, for them, there is no creature. The others ("experto")
## know where it is and what it does all the time.
var novice := false
const NOVICE_EARSHOT := 12.0
const NOVICE_HUNTED := 30.0
const NOVICE_MEMORY := 4.0
var noticed_at := -INF
var position := Vector3.ZERO
var eye := Vector3.ZERO
var forward := Vector3.FORWARD
var mode := 0
## The same, in the words every creature uses (creature.activity()).
var activity: StringName = &""
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
## Its future: where its eyes will be for the next FUTURE seconds -- every
## FUTURE_STEP metres of the whole way it is taking, where that way ends, and
## the rest of its search -- each with when it gets there: {eye, t}, in order
## of t. What the bots plan against, not only where it looks now.
const FUTURE := 24.0
const FUTURE_STEP := 4.0
var future: Array = []
## The pace that future is walked at, and the rest of what it is doing.
var pace := 2.0
var hostile := false
var busy := false
var lost_time := 0.0
var last_known := Vector3.ZERO
var destination := Vector3.ZERO
## Where its search will look (last_known and what is left of its plan).
var search_points: Array = []
## Where it will come out of a lift after the survivors (its car's arrival on
## the planta in play), while it is still in a wing behind; INF otherwise.
var landing := Vector3.INF
## Rays already cast this refresh: {key: result}.
var sight_cache := {}

func _init(owner_level) -> void:
	level = owner_level

## The creature's own measures, as the floor's difficulty (and the room's
## onslaught) set them on it (game/floors/difficulty.gd); its script's
## constants, the game as it was, when there is none to ask.
func sight_range() -> float:
	return float(creature.sight_range) * float(creature.reach_scale) if is_instance_valid(creature) else LOCUST.SIGHT_RANGE

func chase_speed() -> float:
	return float(creature.chase_speed) if is_instance_valid(creature) else LOCUST.CHASE_SPEED

func track_speed() -> float:
	return float(creature.track_speed) if is_instance_valid(creature) else LOCUST.TRACK_SPEED

func torch_range() -> float:
	return float(creature.torch_range) * float(creature.reach_scale) if is_instance_valid(creature) else LOCUST.TORCH_NOTICE_RANGE

func wardrobe_done() -> float:
	return float(creature.wardrobe_steps().done) if is_instance_valid(creature) else float(LOCUST.WARDROBE_TIME.done)

func hearing_scale() -> float:
	return NOISE.HEARING_SCALE * (float(creature.hearing) * float(creature.reach_scale) if is_instance_valid(creature) else 1.0)

func lose_after() -> float:
	return float(creature.lose_after) if is_instance_valid(creature) else LOCUST.LOSE_AFTER

## Metres round where it last knew somebody it still hears in, while it runs
## them down.
func chase_earshot() -> float: return LOCUST.CHASE_EARSHOT

## Whether it is walking off from a part of the floor it found nobody in.
func leaving() -> bool: return bool(creature.leaving)

## Everything, once more. Nothing to fear from a creature that is not moving
## (--no-enemy), still in its grace, or on another planta than `wing`.
func refresh() -> void:
	creature = level.creature
	active = is_instance_valid(creature) and creature.is_physics_processing() and creature.control == "ai"
	path_rooms.clear()
	danger.clear()
	vantages.clear()
	future.clear()
	search_points.clear()
	sight_cache.clear()
	landing = Vector3.INF
	if active and novice:
		if perceived(): noticed_at = float(level.session.elapsed)
		if float(level.session.elapsed) - noticed_at > NOVICE_MEMORY: active = false
	if not active: return
	var car: int = level.lifts.creature_car(int(level.session.stage))
	if car >= 0 and car < level.hotel.arrivals.size() and level.hotel.arrivals[car] != Vector3.ZERO: landing = level.hotel.arrivals[car]
	position = creature.global_position
	eye = position + Vector3(0, LOCUST.EYE_HEIGHT, 0)
	forward = -creature.global_basis.z
	mode = int(creature.mode)
	activity = creature.activity()
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
	see_ahead()

## Whether any of the team has the creature in sight or earshot now, or is
## being hunted by it (novice bots: see `novice`).
func perceived() -> bool:
	if creature.grace > 0.0: return false
	var at: Vector3 = creature.global_position
	for body in level.survivors():
		if not is_instance_valid(body) or int(level.session.participants.get(int(body.slot), level.session.Life.DEAD)) == level.session.Life.DEAD: continue
		if absf(body.global_position.y - at.y) >= 3.0: continue
		var gap: float = body.global_position.distance_to(at)
		if gap < NOVICE_EARSHOT: return true
		if creature.focus == body and gap < NOVICE_HUNTED and creature.mode in [LOCUST.Mode.ALERT, LOCUST.Mode.CHASE, LOCUST.Mode.WINDUP, LOCUST.Mode.RECOVER]: return true
		if level.sanity.sight_of_creature(body, level.sanity.lit_at(body.global_position)) > 0: return true
	return false

## Its future (see FUTURE): along its route at the pace it keeps in what it is
## doing, then the end of it, then the points its search has still to look at.
func see_ahead() -> void:
	hostile = mode in [LOCUST.Mode.ALERT, LOCUST.Mode.CHASE, LOCUST.Mode.WINDUP, LOCUST.Mode.RECOVER]
	busy = mode in [LOCUST.Mode.EXECUTE, LOCUST.Mode.WARDROBE]
	lost_time = float(creature.lost_time)
	last_known = creature.last_known
	destination = creature.destination
	match mode:
		LOCUST.Mode.CHASE: pace = chase_speed() if lost_time < 0.4 else track_speed()
		LOCUST.Mode.INVESTIGATE: pace = 2.9
		LOCUST.Mode.SEARCH: pace = 1.5
		LOCUST.Mode.PATROL: pace = LOCUST.LEAVE_PACE if bool(creature.leaving) else 2.2
		_: pace = 2.0
	pace = maxf(pace, float(creature.speed))
	# Standing still for a while yet: what it does then starts later.
	var wait := 0.0
	if busy: wait = maxf(0.0, (LOCUST.EXECUTION_TIME + 0.35 if mode == LOCUST.Mode.EXECUTE else wardrobe_done()) - float(creature.state_time))
	elif mode in [LOCUST.Mode.PATROL, LOCUST.Mode.SEARCH]: wait = float(creature.pause_time)
	future.append({"eye": eye, "t": 0.0})
	var walked := 0.0
	var next_mark := FUTURE_STEP
	var from := position
	for i in range(int(creature.path_index), creature.path.size()):
		var point: Vector3 = creature.path[i]
		var leg := from.distance_to(point)
		while walked + leg >= next_mark:
			var t := wait + next_mark / pace
			if t > FUTURE: break
			future.append({"eye": from.lerp(point, (next_mark - walked) / maxf(leg, 0.001)) + Vector3(0, LOCUST.EYE_HEIGHT, 0), "t": t})
			next_mark += FUTURE_STEP
		walked += leg
		from = point
		if wait + walked / pace > FUTURE: break
	var at_end := wait + walked / pace
	if FLOOR.planta_of(destination.y) == planta and at_end <= FUTURE:
		future.append({"eye": destination + Vector3(0, LOCUST.EYE_HEIGHT, 0), "t": at_end})
		# Where it goes on from there is its own to choose, but it goes out by
		# a doorway of that room: its eyes in each of them, a little after.
		var there := FLOOR.room_at(level.manifest.rooms, destination)
		if not there.is_empty() and mode in [LOCUST.Mode.PATROL, LOCUST.Mode.INVESTIGATE, LOCUST.Mode.SEARCH]:
			for other in level.manifest.adjacency[int(there.id)]:
				var portal := FLOOR.portal_between(there, level.manifest.rooms[int(other)])
				var t := at_end + 1.5 + destination.distance_to(portal) / maxf(pace, 1.5)
				if t <= FUTURE: future.append({"eye": portal + Vector3(0, LOCUST.EYE_HEIGHT, 0), "t": t})
	future.sort_custom(func(a, b): return float(a.t) < float(b.t))
	if mode in [LOCUST.Mode.SEARCH, LOCUST.Mode.CHASE, LOCUST.Mode.INVESTIGATE]: search_points.append(last_known)
	if mode == LOCUST.Mode.SEARCH:
		var before: Vector3 = destination
		var t := at_end
		for item in creature.search_plan:
			var point: Vector3 = item.point
			search_points.append(point)
			t += before.distance_to(point) * 1.3 / 1.5 + 1.0
			before = point
			if t <= FUTURE: future.append({"eye": point + Vector3(0, LOCUST.EYE_HEIGHT, 0), "t": t})

## Seconds until any of its eyes (now or on its way, see FUTURE) has a line to
## somebody standing at `point`; INF if none within FUTURE. Now is 0.
func time_to_sight(point: Vector3, height := 1.64) -> float:
	if not near_planta(point): return INF
	var key := Vector3i(roundi(point.x * 2.0), roundi(point.z * 2.0), roundi(height * 10.0 + point.y))
	if sight_cache.has(key): return sight_cache[key]
	var target := point + Vector3(0, height, 0)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var found := INF
	for vantage in future:
		if target.distance_to(vantage.eye) > sight_range(): continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(vantage.eye, target, SIGHT_MASK)).is_empty():
			found = float(vantage.t)
			break
	sight_cache[key] = found
	return found

## Seconds until it passes within `near` metres of `point` (INF: not within
## FUTURE): coming here, whatever it can see.
func arrival(point: Vector3, near := 5.0) -> float:
	if not near_planta(point): return INF
	for vantage in future:
		var ground: Vector3 = vantage.eye - Vector3(0, LOCUST.EYE_HEIGHT, 0)
		if Vector2(ground.x - point.x, ground.z - point.z).length() < near and absf(ground.y - point.y) < 2.0: return float(vantage.t)
	return INF

## Its ears are shut here: it is running somebody down (or tracking them)
## and only hears what is within CHASE_EARSHOT of where it last knew them.
func deaf_to(point: Vector3) -> bool:
	return mode == LOCUST.Mode.CHASE and point.distance_to(last_known) > LOCUST.CHASE_EARSHOT + 1.5 or busy

## Near a place its search is going to look.
func searched_near(point: Vector3, near := 5.0) -> bool:
	for spot in search_points:
		if Vector2(spot.x - point.x, spot.z - point.z).length() < near: return true
	return false

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
	if gap > sight_range(): return false
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
	if target.distance_to(eye) > sight_range(): return false
	var query := PhysicsRayQueryParameters3D.create(eye, target, SIGHT_MASK)
	return level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Whether any of its eyes, now or on its way (vantages), has a line to
## somebody standing there.
func watched(point: Vector3, height := 1.64) -> bool:
	if not near_planta(point): return false
	var target := point + Vector3(0, height, 0)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for vantage in vantages:
		if target.distance_to(vantage) > sight_range(): continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(vantage, target, SIGHT_MASK)).is_empty(): return true
	return false

## Whether a noise of this kind made at `point` would reach it: its own
## measure (hotel_locust.hear_route), with a margin.
func audible(point: Vector3, noise_name: String) -> bool:
	if not near_planta(point): return false
	var radius: float = NOISE.radius(noise_name) * EAR_MARGIN
	if position.distance_to(point) > radius * hearing_scale(): return false
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
	var pace: float = chase_speed() if mode in [LOCUST.Mode.CHASE, LOCUST.Mode.ALERT] else maxf(2.9, float(creature.speed))
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
	if offset.length() > torch_range() + 5.0: return false
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
	if centre.distance_to(position) < sight_range() and visible(centre): extra += COST_SEEN
	return extra

# --- What a recording keeps of it (bot_recorder.gd, bot_replay.gd) ----------------
#
# Asked of the floor's creature as it is now, not of the last refresh.

## Its row of a recorded frame, in the order of bot_recorder.CREATURE_FIELDS:
## x, y, z, yaw, mode, the seat it is after, detection, stuck step,
## destination x, z, last known x, z. Empty with no creature. The replay
## poses it from the first four and draws its line to the sixth
## (bot_replay.gd), so any creature's model keeps those there.
func recorded_row() -> Array:
	var it = level.creature
	if not is_instance_valid(it): return []
	var c: Vector3 = it.global_position
	var focus: int = int(it.focus.slot) if is_instance_valid(it.focus) and "slot" in it.focus else -1
	return [c.x, c.y, c.z, it.rotation.y, int(it.mode), focus, float(it.detection), int(it.stuck_level), it.destination.x, it.destination.z, it.last_known.x, it.last_known.z]

## The next sixteen points of its route; null with no creature.
func recorded_route() -> Variant:
	var it = level.creature
	if not is_instance_valid(it): return null
	var points := PackedVector3Array()
	for i in range(int(it.path_index), mini(it.path.size(), int(it.path_index) + 16)): points.append(it.path[i])
	return points

## What the recording's log watches of it: its mode and the seat it is after
## (-1: nobody). Empty with no creature.
func recorded_watch() -> Dictionary:
	var it = level.creature
	if not is_instance_valid(it): return {}
	return {"mode": int(it.mode), "focus": int(it.focus.slot) if is_instance_valid(it.focus) and "slot" in it.focus else -1}

## Said with a change of its mode: where it is and how near it was to making
## somebody out. Empty with no creature.
func recorded_mode_change() -> Dictionary:
	var it = level.creature
	if not is_instance_valid(it): return {}
	return {"where": RECORDER.vec(it.global_position), "detection": snappedf(float(it.detection), 0.01)}

## Each part of the floor it gives a search up in, told to `heard`
## (origin, next): the recording's "abandona".
func on_gave_up(heard: Callable) -> void:
	var it = level.creature
	if is_instance_valid(it) and it.has_signal("area_abandoned"): it.area_abandoned.connect(heard)

## Its protocol for getting unstuck going up a step (step, where), and each
## route it gives up (where), told to the watchdog (bot_watchdog.gd).
func on_stuck(it, escalated: Callable, abandoned: Callable) -> void:
	it.stuck_escalated.connect(escalated)
	it.route_abandoned.connect(abandoned)

## A replay's puppet of it, put where the recording has it: there, turned so
## and moving so, with no state of its own on the way to pull it elsewhere.
func replay_pose(at: Vector3, yaw: float, moving: Vector3) -> void:
	var it = level.creature
	it.global_position = at
	it.rotation.y = yaw
	it.velocity = moving
	it.net_states.clear()

## And doing what the recording says it was doing then.
func replay_mode(value: int) -> void:
	level.creature.mode = value
	level.creature.state_time = 0.0
