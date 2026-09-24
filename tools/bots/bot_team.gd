extends RefCounted
## What the bots know together and who does what. They share everything they
## find the moment they find it, as a team talking would. Each stage has its
## plan:
##  1  find the refuge, all of them in it; its door opens.
##  2  light the sets the stage asks for, one bot to each.
##  3  the four notes, the sets, and the code at the keypad by the last door.
## Then everybody to the car beyond the refuge's door, and the first of them
## presses once all the living are in it. A bot left behind on a planta the
## floor has moved on from rides the car it missed.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NAV := preload("res://tools/bots/bot_nav.gd")
const TV_PLACEMENT := preload("res://game/world/generation/tv_placement.gd")
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
const SENSES := preload("res://tools/bots/bot_senses.gd")
## A stage with nothing new for this long is said to be stalled; twice as long
## and the next thing missing is given to the team (a finding, "revelado").
const STALL := 300.0
## How long the car waits for everybody before the first one in presses anyway.
const GATHER_WAIT := 90.0
## A task a bot gave up is not given back to it for this long.
const DROP_WAIT := 60.0
var owner_match
var level
var brains: Array = []
## What the team knows. Oracle: all of it from the start of each stage.
var knowledge := {"refuges": {}, "tvs": {}, "notes": {}, "keypad": false}
## Rooms gone through and looked round, and rooms that cannot be got to (behind
## a locked door, or off the walkable floor), for the planta being explored.
var cleared := {}
var blocked := {}
## What there is to find on this stage (bot_senses.targets), and for each,
## the nearest the team came to seeing it: the closest look that was in view
## with nothing in between, and the closest it ever stood.
var targets: Array = []
var near := {}
## Seat -> {target key: consecutive sightings}: twice in a row is seen.
var sightings := {}
var progress_at := 0.0
var stall_said := false
## Things the team was given rather than found.
var revealed: Array = []
## Task key -> seat working on it.
var claims := {}
## "seat|key" -> clock until which that bot is not given it again.
var dropped := {}
var stage := 0
var gather_since := -1.0
var clock := 0.0
## Node -> where a hand reaches it from (reach_stands).
var reach_cache := {}
## Nodes a hand reaches only from floor the rest of the planta does not join.
var island_only := {}

func _init(owner) -> void:
	owner_match = owner
	level = owner.level

func oracle() -> bool: return String(owner_match.options.get("knowledge", "discover")) == "oracle"

func tick(delta: float) -> void:
	clock += delta
	if level.session.state != level.session.State.PLAYING: return
	if stage != int(level.session.stage):
		stage = int(level.session.stage)
		claims.clear()
		gather_since = -1.0
		# What each was doing belonged to the stage just closed: the car they
		# came up in is on the planta above.
		for brain in brains: brain.set_task({})
		cleared.clear()
		blocked.clear()
		near.clear()
		sightings.clear()
		targets = SENSES.targets(level, stage)
		progress(null, "sector")
		stall_said = false
	if oracle(): learn_everything()
	else: watch_stall()
	var wing: int = stage - 1
	var here: Array = []
	for brain in brains:
		if not brain.alive() or brain.out_of_play(): continue
		var planta: int = brain.planta()
		if planta < wing:
			# Left behind: the car of its own planta, which went on without it.
			brain.set_task(lift_task(planta, brain, false))
			press_if_ready(planta, [brain])
		else: here.append(brain)
	if here.is_empty(): return
	if level.lifts.car_ready(wing) and knows_way_out(wing):
		gather(wing, here)
		return
	gather_since = -1.0
	plan_objectives(here)

## Everything this stage has, as a team that had already seen it would know.
func learn_everything() -> void:
	var wing: int = stage - 1
	knowledge.refuges[wing] = true
	for index in level.stage_televisions(): knowledge.tvs[index] = true
	if stage == level.session.STAGES:
		for index in level.containers.size():
			if int(level.containers[index].digit) >= 0: knowledge.notes[index] = true
		knowledge.keypad = true

## The car is behind the refuge's door: knowing the one is knowing the other.
func knows_way_out(wing: int) -> bool: return knowledge.refuges.has(wing)

# --- The stage's errands ------------------------------------------------------------

func plan_objectives(here: Array) -> void:
	var errands: Array = objectives()
	# Whoever already has one of these keeps it while it still stands.
	var wanted := {}
	for errand in errands: wanted[errand.key] = errand
	for key in claims.keys():
		if not wanted.has(key): claims.erase(key)
	var free: Array = []
	for brain in here:
		var key := String(brain.task.get("key", ""))
		if wanted.has(key) and claims.get(key, -1) == brain.seat:
			brain.set_task(wanted[key])
			continue
		free.append(brain)
	for errand in errands:
		if free.is_empty(): break
		if claims.has(errand.key): continue
		var best = null
		var best_cost := INF
		for brain in free:
			if clock < float(dropped.get("%d|%s" % [brain.seat, errand.key], -1.0)): continue
			var cost: float = NAV.route_length(level, brain.body.global_position, errand.stands[0]) + owner_match.task_danger(errand.stands[0]) if FLOOR.planta_of(brain.body.global_position.y) == FLOOR.planta_of(errand.stands[0].y) else INF
			if cost < best_cost:
				best_cost = cost
				best = brain
		if best == null: continue
		claims[errand.key] = best.seat
		best.set_task(errand)
		free.erase(best)
	for brain in free:
		var idle := idle_task(brain)
		if String(idle.get("kind", "")) == "explore": claims[idle.key] = brain.seat
		brain.set_task(idle)

## What is left to do on this stage that the team knows how to do.
func objectives() -> Array:
	var errands: Array = []
	if stage >= 2:
		var needed: int = TV_PLACEMENT.needed(level.session.roster_count)
		var lit: int = level.televisions_on()
		for index in level.stage_televisions():
			if lit >= needed: break
			var set = level.televisions[index]
			if set.on or not knowledge.tvs.has(index): continue
			errands.append(tv_task(index))
			lit += 1
	if stage == level.session.STAGES:
		for index in knowledge.notes:
			var piece = level.containers[int(index)]
			if is_instance_valid(piece) and not piece.searched: errands.append(note_task(int(index)))
		if knowledge.keypad and not level.code_entered and level.found_digits.size() >= DIGITS.COUNT and level.sets_lit() and is_instance_valid(level.lock):
			errands.append(code_task())
	return errands

## Nothing of its own to do. Knowing the refuge and all this stage needs, it
## waits there -- safe, and where the way out is; on the first stage that is
## the errand itself. Otherwise it goes and looks.
func idle_task(brain) -> Dictionary:
	var wing: int = stage - 1
	if knowledge.refuges.has(wing) and (stage == 1 or oracle() or knows_enough()): return refuge_task(brain)
	var room := explore_room(brain)
	# Still going round the same room: the task as it stands, stops and all.
	if room >= 0 and String(brain.task.get("key", "")) == "explore:%d" % room: return brain.task
	if room >= 0:
		var looking := explore_task(room)
		if not looking.is_empty(): return looking
	if knowledge.refuges.has(wing): return refuge_task(brain)
	return {}

## Whether the team knows where everything this stage needs is.
func knows_enough() -> bool:
	if stage >= 2:
		var known_sets := 0
		for index in level.stage_televisions():
			if knowledge.tvs.has(index) or level.televisions[index].on: known_sets += 1
		if known_sets < TV_PLACEMENT.needed(level.session.roster_count): return false
	if stage == level.session.STAGES:
		if not knowledge.keypad and not level.code_entered: return false
		for target in targets:
			if target.kind == "note" and not knowledge.notes.has(target.index) and needed(target): return false
	return knowledge.refuges.has(stage - 1)

# --- Looking round ------------------------------------------------------------------

## The room it is going through, if it is still one to go through; otherwise
## the nearest one nobody has been round or is on the way to, by the plan.
func explore_room(brain) -> int:
	if String(brain.task.get("kind", "")) == "explore":
		var current := int(brain.task.get("room", -1))
		if current >= 0 and not cleared.has(current) and not blocked.has(current) and int(claims.get("explore:%d" % current, brain.seat)) == brain.seat: return current
	var rooms: Array = level.manifest.rooms
	var here: Dictionary = FLOOR.room_at(rooms, brain.body.global_position)
	if here.is_empty(): return -1
	var wing: int = stage - 1
	# Dijkstra over the plan, room middle to room middle.
	var fallback := -1
	var cost := {int(here.id): 0.0}
	var open: Array = [int(here.id)]
	var done := {}
	while not open.is_empty():
		var current: int = open[0]
		for candidate in open:
			if float(cost[candidate]) < float(cost[current]): current = candidate
		open.erase(current)
		done[current] = true
		var room: Dictionary = rooms[current]
		# Where the creature's eyes will soon be, or where it is going, is looked
		# round later: the next room on is taken instead.
		if not cleared.has(current) and not blocked.has(current) and not claims.has("explore:%d" % current) and int(room.get("wing", -1)) == wing and not FLOOR.is_void(room):
			if owner_match.task_danger(FLOOR.position_of(room)) < 60.0: return current
			if fallback < 0: fallback = current
		for other in level.manifest.adjacency[current]:
			var next := int(other)
			if done.has(next) or (blocked.has(next) and not cleared.has(next)): continue
			var step: float = FLOOR.position_of(room).distance_to(FLOOR.position_of(rooms[next]))
			if float(cost[current]) + step < float(cost.get(next, INF)):
				cost[next] = float(cost[current]) + step
				if not open.has(next): open.append(next)
	return fallback

func explore_task(room_id: int) -> Dictionary:
	var room: Dictionary = level.manifest.rooms[room_id]
	if not views_cache.has(room_id): views_cache[room_id] = viewpoints(room)
	var stops: Array = views_cache[room_id]
	if stops.is_empty():
		room_blocked(room_id)
		return {}
	return {"kind": "explore", "key": "explore:%d" % room_id, "label": owner_match.room_name(room), "stands": [stops[0]], "stops": stops.slice(1), "room": room_id}

## Where to stand to have seen all of a room: its middle, and then what the
## middle does not see -- along a long corridor every VIEW_STEP metres, and
## the quarters a partition or an alcove hides from the middle (a suite's
## set stands in its alcove, facing the partition, and is seen from nowhere
## else). Every one on floor the planta is joined by.
const VIEW_STEP := 7.0
var views_cache := {}
func viewpoints(room: Dictionary) -> Array:
	var centre := FLOOR.position_of(room)
	var span := FLOOR.size_of(room)
	var stops: Array = []
	var middle := snap(centre)
	if Vector2(middle.x - centre.x, middle.z - centre.z).length() < 1.5 and NAV.joined(level, middle): stops.append(middle)
	else:
		var out := NAV.nearest_joined(level, centre, 3.0)
		if out != Vector3.INF: stops.append(out + Vector3(0, 0.05, 0))
	if stops.is_empty(): return stops
	var candidates: Array = []
	var long_way := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
	var length: float = maxf(span.x, span.y)
	if length > 11.0:
		var reach: float = length * 0.5 - 2.5
		var along := VIEW_STEP
		while along <= reach + 0.01:
			candidates.append(centre + long_way * along)
			candidates.append(centre - long_way * along)
			along += VIEW_STEP
	for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		candidates.append(centre + Vector3(corner.x * span.x * 0.25, 0, corner.y * span.y * 0.25))
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var eye: Vector3 = stops[0] + Vector3(0, 1.6, 0)
	for candidate in candidates:
		var point := snap(candidate)
		if Vector2(point.x - candidate.x, point.z - candidate.z).length() > 1.2: continue
		# What the middle already sees needs no stop of its own (long ways are
		# walked anyway: a note on a corridor wall is seen from beside it).
		var query := PhysicsRayQueryParameters3D.create(eye, point + Vector3(0, 1.6, 0), 1)
		var hidden: bool = not space.intersect_ray(query).is_empty()
		var far: bool = eye.distance_to(point + Vector3(0, 1.6, 0)) > VIEW_STEP
		if not hidden and not far: continue
		if stops.any(func(stop): return stop.distance_to(point) < 3.0): continue
		if not NAV.joined(level, point): continue
		stops.append(point)
	return stops

## A bot has been through a room and looked round it.
func room_cleared(brain, room_id: int) -> void:
	cleared[room_id] = true
	# Looking round is getting on too: stalled is neither finding nor looking.
	progress_at = clock
	claims.erase("explore:%d" % room_id)
	owner_match.note("sala", brain, {"room": room_id})

## A room nobody can get into from here: behind a door with a lock, or with
## no walkable floor joined to the rest.
func room_blocked(room_id: int) -> void:
	if room_id < 0: return
	blocked[room_id] = true
	claims.erase("explore:%d" % room_id)

## Every room of the planta there is a way into has been looked round.
func exhausted() -> bool:
	var wing: int = stage - 1
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != wing or FLOOR.is_void(room): continue
		if not cleared.has(int(room.id)) and not blocked.has(int(room.id)): return false
	return true

## One bot's look round, five times a second: what of this stage it sees now.
func look(brain) -> void:
	if oracle() or brain.out_of_play() or brain.body.hidden: return
	var seen: Dictionary = sightings.get(brain.seat, {})
	var blind: Array = owner_match.options.get("blind", [])
	for target in targets:
		if known(target) or int(target.planta) != brain.planta() or blind.has(target.key): continue
		var kind: String = "tv_on" if target.kind == "tv" and level.televisions[target.index].on else String(target.kind)
		var saw := false
		var glance_near := false
		for point in target.points:
			var glance: Dictionary = SENSES.look(level, brain.body, kind, point)
			remember_near(target, brain, glance)
			if glance.seen:
				saw = true
				glance_near = float(glance.dist) <= SENSES.reach_of(kind, String(glance.light)) * 0.6
				break
		if not saw: continue
		# Made out: twice within the last second, or once, clearly, from well
		# inside the distance it can be seen from.
		var times: Array = seen.get(target.key, [])
		times = times.filter(func(t): return owner_match.clock - float(t) < 1.0)
		times.append(owner_match.clock)
		seen[target.key] = times
		if times.size() >= 2 or glance_near: learn(target, brain)
	sightings[brain.seat] = seen

func known(target: Dictionary) -> bool:
	match String(target.kind):
		"refuge": return knowledge.refuges.has(target.index)
		"tv": return knowledge.tvs.has(target.index)
		"note": return knowledge.notes.has(target.index)
		"keypad": return knowledge.keypad
	return true

func learn(target: Dictionary, brain, given := false) -> void:
	match String(target.kind):
		"refuge": knowledge.refuges[target.index] = true
		"tv": knowledge.tvs[target.index] = true
		"note": knowledge.notes[target.index] = true
		"keypad": knowledge.keypad = true
	progress(brain, "descubre", {"target": target.key, "given": given})

## The closest look at it so far, and the closest look that was in view with
## nothing in between (what a "not found" is explained by).
func remember_near(target: Dictionary, brain, glance: Dictionary) -> void:
	var entry: Dictionary = near.get(target.key, {"closest": INF, "best": {}})
	if float(glance.dist) < float(entry.closest): entry.closest = glance.dist
	if glance.in_view and glance.clear:
		var best: Dictionary = entry.best
		if best.is_empty() or float(glance.dist) < float(best.dist): entry.best = {"dist": snappedf(glance.dist, 0.1), "light": glance.light, "seat": brain.seat, "t": snappedf(owner_match.clock, 0.1)}
	near[target.key] = entry

## Something moved on: a thing found, an errand done, a new stage.
func progress(brain, kind: String, data := {}) -> void:
	progress_at = clock
	stall_said = false
	owner_match.note(kind, brain, data)

## Nothing new for too long, or every room looked round and something still
## never seen: said, with the nearest look anybody had at it, and given to the
## team so the floor goes on.
func watch_stall() -> void:
	var missing: Array = targets.filter(func(target): return not known(target) and needed(target))
	if missing.is_empty(): return
	if exhausted():
		var shut: Array = blocked.keys().filter(func(id): return not cleared.has(id) and int(level.manifest.rooms[id].get("wing", -1)) == stage - 1)
		owner_match.note("planta_recorrida", null, {"cleared": cleared.size(), "blocked": shut})
		for target in missing: reveal(target, "recorrida toda la planta%s" % ("" if shut.is_empty() else ", salvo %d salas a las que no se pudo entrar" % shut.size()))
		return
	var quiet: float = clock - progress_at
	if quiet > STALL and not stall_said:
		stall_said = true
		owner_match.report("etapa_estancada", "media", null, "%d s sin encontrar nada nuevo en el sector %d" % [int(quiet), stage])
	if quiet > STALL * 2.0: reveal(missing[0], "%d s sin encontrar nada" % int(quiet))

## Whether this stage still needs it found.
func needed(target: Dictionary) -> bool:
	match String(target.kind):
		"refuge": return true
		"keypad": return not level.code_entered
		"note":
			var piece = level.containers[target.index]
			return is_instance_valid(piece) and not piece.searched
		"tv":
			if level.televisions[target.index].on: return false
			var known_sets := 0
			for index in level.stage_televisions():
				if knowledge.tvs.has(index) or level.televisions[index].on: known_sets += 1
			return known_sets < TV_PLACEMENT.needed(level.session.roster_count)
	return false

func reveal(target: Dictionary, why: String) -> void:
	var entry: Dictionary = near.get(target.key, {"closest": INF, "best": {}})
	var best: Dictionary = entry.best
	var words := "%s: nunca visto (%s)" % [target_name(target), why]
	if not best.is_empty(): words += "; lo más cerca que se tuvo a la vista, sin nada delante, fue a %.1f m con luz «%s»" % [float(best.dist), best.light]
	elif float(entry.closest) < INF: words += "; lo más cerca que se pasó fue a %.1f m, sin tenerlo delante" % float(entry.closest)
	else: words += "; nadie pasó cerca"
	owner_match.report("no_encontrado", "grave", null, words, {"where": target.points[0], "target": target.key})
	revealed.append(target.key)
	learn(target, null, true)

func target_name(target: Dictionary) -> String:
	var room: Dictionary = level.manifest.rooms[int(target.room)] if int(target.room) >= 0 else {}
	match String(target.kind):
		"refuge": return "el refugio (%s)" % owner_match.room_name(room)
		"tv": return "la tele %d en %s" % [target.index, owner_match.room_name(room)]
		"note": return "la nota del mueble %d (%s) en %s" % [target.index, level.containers[target.index].kind, owner_match.room_name(room)]
		"keypad": return "el teclado de la última puerta"
	return String(target.key)

# --- The car ----------------------------------------------------------------------

func gather(wing: int, here: Array) -> void:
	if gather_since < 0.0: gather_since = clock
	for brain in here: brain.set_task(lift_task(wing, brain, true))
	press_if_ready(wing, here)

## The first of them in the car presses once every living bot on this planta
## is in it, or once the car has waited long enough (said).
func press_if_ready(index: int, group: Array) -> void:
	if not level.lifts.car_ready(index): return
	var inside: Array = level.lifts.inside(index)
	var everybody := true
	for brain in group:
		if not inside.has(brain.body): everybody = false
	var leader = null
	for brain in group:
		if inside.has(brain.body) and (leader == null or brain.seat < leader.seat): leader = brain
	if leader == null: return
	if not everybody:
		if gather_since < 0.0 or clock - gather_since < GATHER_WAIT: return
		var missing: Array = []
		for brain in group:
			if not inside.has(brain.body): missing.append("%s (%s, a %.1f m del coche%s)" % [brain.body.player_name, brain.state_name(), brain.body.global_position.distance_to(level.hotel.lifts[index]), brain.surroundings()])
		owner_match.report("espera_ascensor", "media", leader, "pulsa sin todos tras %d s en el coche; faltan %s" % [int(GATHER_WAIT), ", ".join(missing)])
	owner_match.note("ascensor", leader, {"car": index, "riders": inside.size()})
	level.match_net.call_lift(index)
	gather_since = -1.0

# --- Tasks ------------------------------------------------------------------------

func lift_task(index: int, brain, gathering: bool) -> Dictionary:
	var centre: Vector3 = level.hotel.lifts[index]
	var slot := brains.find(brain)
	var angle := TAU * float(slot) / float(maxi(brains.size(), 1))
	var spot: Vector3 = centre + Vector3(cos(angle), 0, sin(angle)) * (0.45 if brains.size() > 1 else 0.0)
	return {"kind": "lift", "key": "lift:%d" % index, "label": "el ascensor %d" % (index + 1), "stands": [snap(spot), snap(centre)], "look": centre + Vector3(0, 1.4, 0), "car": index, "gathering": gathering}

func refuge_task(brain) -> Dictionary:
	var room: Dictionary = level.manifest.rooms[int(level.manifest.refuges[stage - 1])]
	var centre := FLOOR.position_of(room)
	var slot := brains.find(brain)
	var angle := TAU * float(slot) / float(maxi(brains.size(), 1))
	var reach: float = minf(1.0, minf(FLOOR.size_of(room).x, FLOOR.size_of(room).y) * 0.5 - 1.0)
	var spot := centre + Vector3(cos(angle), 0, sin(angle)) * maxf(reach, 0.0)
	return {"kind": "refuge", "key": "refuge:%d" % stage, "label": "el refugio", "stands": [snap(spot), snap(centre)], "look": centre + Vector3(0, 1.4, 0)}

func tv_task(index: int) -> Dictionary:
	var set = level.televisions[index]
	return usable_task({"kind": "tv", "key": "tv:%d" % index, "label": "la tele %d" % index}, set, set.to_global(Vector3(0, 1.3, 0)))

func note_task(index: int) -> Dictionary:
	var piece = level.containers[index]
	var reach: float = maxf(float(piece.front), 0.3) + 0.25
	return usable_task({"kind": "note", "key": "note:%d" % index, "label": "el mueble %d (%s)" % [index, piece.kind]}, piece, piece.to_global(Vector3(0, 0.6, (reach - 0.2) * 0.5)))

func code_task() -> Dictionary:
	var code := ""
	for slot in range(1, DIGITS.COUNT + 1): code += str(level.found_digits.get(slot, 0))
	return usable_task({"kind": "code", "key": "code", "label": "el teclado", "code": code}, level.lock, level.lock.to_global(Vector3(0, 1.3, 0)))

## A task on something used by hand: where to stand to reach it, worked out
## once. With nowhere to stand, it says so -- nobody could use it -- and the
## bot goes as near as it gets and does it anyway, so the floor goes on.
func usable_task(task: Dictionary, node: Node3D, aim: Vector3) -> Dictionary:
	task["node"] = node
	task["aim"] = aim
	# Things used by hand do not move: where to stand is worked out once.
	if not reach_cache.has(node):
		var stands := reach_stands(node, aim, node.global_basis.z)
		reach_cache[node] = stands
	var found: Array = reach_cache[node]
	task["stands"] = found if not found.is_empty() else [snap(aim)]
	if found.is_empty():
		task["unusable"] = true
		if island_only.has(node): task["island"] = true
	return task

## Where a hand gets to it from: points round it on the walkable floor, its
## front first and near before far, from which the ray a player's interaction
## casts (from the eye, hotel_main.focused_area) hits it before anything else.
const REACH_RINGS := [0.9, 1.3, 1.7]
const REACH_WAYS := 16
func reach_stands(node: Node3D, aim: Vector3, front: Vector3) -> Array:
	var map: RID = level.get_world_3d().navigation_map
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var ahead := Vector3(front.x, 0, front.z).normalized()
	var found: Array = []
	for ring in REACH_RINGS:
		for step in REACH_WAYS:
			var angle := TAU * float(step) / float(REACH_WAYS)
			var way := Vector3(cos(angle), 0, sin(angle))
			var point: Vector3 = FLOOR.floor_point(aim) + way * float(ring)
			var snapped := FLOOR.closest(map, point)
			if Vector2(snapped.x - point.x, snapped.z - point.z).length() > 0.25 or FLOOR.planta_of(snapped.y) != FLOOR.planta_of(aim.y): continue
			var eye := snapped + Vector3(0, 1.64, 0)
			if eye.distance_to(aim) > 2.0: continue
			var query := PhysicsRayQueryParameters3D.create(eye, eye + (aim - eye).normalized() * 2.0, 1 | 8 | 16)
			query.collide_with_areas = true
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty() or hit.collider != node: continue
			found.append([float(ring) - 0.8 * way.dot(ahead), snapped + Vector3(0, 0.05, 0)])
	found.sort_custom(func(a, b): return a[0] < b[0])
	# Only where a body can walk to from the rest of the planta: a scrap of
	# floor behind the furniture is where a bot got in and could not leave.
	var stands: Array = []
	var islands := 0
	for entry in found:
		if stands.size() >= 6: break
		if NAV.joined(level, entry[1]): stands.append(entry[1])
		else: islands += 1
	if stands.is_empty() and islands > 0: island_only[node] = true
	return stands

func snap(point: Vector3) -> Vector3:
	return FLOOR.closest(level.get_world_3d().navigation_map, point) + Vector3(0, 0.05, 0)

# --- Told by the bots ---------------------------------------------------------------

func finished(brain, task: Dictionary) -> void:
	claims.erase(String(task.get("key", "")))
	if String(task.get("kind", "")) in ["tv", "note", "code"]: progress(brain, "hecho", {"task": task.get("key", "")})

func drop(brain, task: Dictionary, _why: String) -> void:
	var key := String(task.get("key", ""))
	claims.erase(key)
	dropped["%d|%s" % [brain.seat, key]] = clock + DROP_WAIT
	# Nobody else gets sent to look round a room one of them could not reach.
	if String(task.get("kind", "")) == "explore": room_blocked(int(task.get("room", -1)))
