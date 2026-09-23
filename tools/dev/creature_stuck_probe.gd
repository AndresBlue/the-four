extends SceneTree
## Where the creature gets stuck, if anywhere. On each floor it is sent on a
## number of journeys between rooms of the same wing -- half of them walking
## to something it heard, half of them hunting at full speed, slamming doors
## -- and every time it stands still for more than STOP seconds while it means
## to move is a stop, written down with where it was and the door nearest it.
## Waiting for a door it is opening is not a stop.
##
##   godot --headless --path . --rendering-method forward_plus --fixed-fps 60 \
##       --script tools/dev/creature_stuck_probe.gd -- --seeds=81,213,404 --trips=20
##
## One line per floor and a total. --trace adds a line per stop and per trip.
## --strict fails (exit code 1) on any stop, any hop and any journey it never
## finished: tools/verify.ps1 runs a short version that way.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const STOP := 2.0
var level
var trace := false

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var seeds: Array = [81]
	var trips := 20
	var strict := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="): seeds = Array(argument.trim_prefix("--seeds=").split(",")).map(func(text): return int(text))
		if argument.begins_with("--trips="): trips = int(argument.trim_prefix("--trips="))
		if argument == "--trace": trace = true
		if argument == "--strict": strict = true
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	var total := {"trips": 0, "arrived": 0, "stops": 0, "hops": 0, "steps": [0, 0, 0, 0, 0, 0]}
	for run_seed in seeds:
		await level.start_floor(int(run_seed))
		var creature = level.locust
		# Out of the way: nothing it does distracts the creature, and it is
		# what a chase is aimed at, so the chase has somebody to be after.
		level.player.set_physics_process(false)
		level.player.global_position = Vector3(0, -200, 0)
		creature.grace = 0.0
		var rng := RandomNumberGenerator.new()
		rng.seed = int(run_seed) * 7919 + 13
		var floor_result := {"trips": 0, "arrived": 0, "stops": 0, "hops": 0}
		var counts_before: Array = creature.stuck_counts.duplicate()
		for trip in trips:
			var ends := journey(rng)
			if ends.is_empty(): continue
			var hunting: bool = trip % 2 == 1
			var outcome: Dictionary = await walk(creature, ends[0], ends[1], hunting)
			floor_result.trips += 1
			if outcome.arrived: floor_result.arrived += 1
			floor_result.stops += int(outcome.stops)
			floor_result.hops += int(outcome.hops)
			if trace: print("   %s %s · %0.0f m en línea, %0.0f de ruta · %s en %0.1f s (%0.1f s ante puertas) · paradas %d" % ["caza" if hunting else "anda", str(Vector2(ends[0].x, ends[0].z).round()), ends[0].distance_to(ends[1]), outcome.length, "llegó" if outcome.arrived else "NO LLEGÓ", outcome.seconds, outcome.at_doors, outcome.stops])
		var steps: Array = []
		for i in 6: steps.append(int(creature.stuck_counts[i]) - int(counts_before[i]))
		print("SEED %d · %d trayectos · llegó a %d · paradas de más de %0.0f s: %d · saltos: %d · pasos del protocolo 1-5: %d/%d/%d/%d/%d" % [run_seed, floor_result.trips, floor_result.arrived, STOP, floor_result.stops, floor_result.hops, steps[1], steps[2], steps[3], steps[4], steps[5]])
		for key in ["trips", "arrived", "stops", "hops"]: total[key] += int(floor_result[key])
		for i in 6: total.steps[i] += steps[i]
	print("STUCK_PROBE · %d trayectos · llegó a %d · paradas %d · saltos %d · pasos %s" % [total.trips, total.arrived, total.stops, total.hops, str(total.steps.slice(1))])
	var clean: bool = total.stops == 0 and total.hops == 0 and total.arrived == total.trips
	quit(1 if strict and not clean else 0)

## Two rooms of one wing, far enough apart to be a walk, as points of floor
## it can stand on. Never a refuge or a lift lobby: it does not go in there.
func journey(rng: RandomNumberGenerator) -> Array:
	var map: RID = level.get_world_3d().navigation_map
	var refuges: Array = level.manifest.get("refuges", [])
	var rooms: Array = level.manifest.rooms.filter(func(room): return not FLOOR.is_void(room) and not refuges.has(int(room.id)) and not bool(room.get("landing", false)))
	for attempt in 40:
		var a: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
		var b: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
		if int(a.wing) != int(b.wing) or int(a.id) == int(b.id): continue
		var from: Vector3 = NavigationServer3D.map_get_closest_point(map, FLOOR.position_of(a))
		var to: Vector3 = NavigationServer3D.map_get_closest_point(map, FLOOR.position_of(b))
		if from.distance_to(to) < 15.0: continue
		var route := FLOOR.navigation_path(map, from, to)
		if route.is_empty() or route[route.size() - 1].distance_to(to) > 1.0: continue
		return [from, to]
	return []

func walk(creature, from: Vector3, to: Vector3, hunting: bool) -> Dictionary:
	var map: RID = level.get_world_3d().navigation_map
	var length := 0.0
	var route := FLOOR.navigation_path(map, from, to)
	for i in range(1, route.size()): length += route[i].distance_to(route[i - 1])
	creature.global_position = from + Vector3(0, 0.04, 0)
	creature.velocity = Vector3.ZERO
	creature.speed = 0.0
	creature.stuck_level = 0
	creature.stuck_origin = Vector3.INF
	creature.set_mode(creature.Mode.CHASE if hunting else creature.Mode.INVESTIGATE)
	creature.destination = to
	creature.last_known = to
	creature.focus = level.player
	var budget: float = length / (4.0 if hunting else 1.2) + 20.0
	var result := {"arrived": false, "stops": 0, "hops": 0, "seconds": 0.0, "length": length, "at_doors": 0.0}
	var still := 0.0
	var counted := false
	var hops_before: int = int(creature.stuck_counts[5])
	var frames := int(budget * 60.0)
	for i in frames:
		# Kept at it: an investigation gives up after twelve seconds and a
		# chase after seven without sight, and this is about the walking.
		creature.state_time = 0.0
		if hunting:
			creature.last_known = to
			creature.lost_time = 0.0
			if creature.mode != creature.Mode.CHASE: creature.set_mode(creature.Mode.CHASE)
		elif creature.mode != creature.Mode.INVESTIGATE:
			creature.set_mode(creature.Mode.INVESTIGATE)
			creature.destination = to
		await physics_frame
		result.seconds = float(i) / 60.0
		if Vector2(creature.global_position.x - to.x, creature.global_position.z - to.z).length() < 1.0:
			result.arrived = true
			break
		var moving: float = Vector2(creature.velocity.x, creature.velocity.z).length()
		var waiting: bool = creature.door_ahead() != null and moving < 0.1
		if waiting: result.at_doors += 1.0 / 60.0
		if moving < 0.15 and not waiting:
			still += 1.0 / 60.0
			if still > STOP and not counted:
				counted = true
				result.stops += 1
				if trace: print("      PARADA en %s · modo %d · %s" % [str(creature.global_position.round()), creature.mode, door_note(creature.global_position)])
		else:
			still = 0.0
			counted = false
	result.hops = int(creature.stuck_counts[5]) - hops_before
	return result

## The door nearest a point, and how it stands.
func door_note(point: Vector3) -> String:
	var best = null
	var gap := INF
	for door in level.hotel.doors:
		var d: float = Vector2(door.doorway.x - point.x, door.doorway.z - point.z).length()
		if d < gap:
			gap = d
			best = door
	if best == null: return "sin puertas"
	return "puerta a %0.1f m, %s%s" % [gap, "abierta" if best.opened else "cerrada", " con llave" if best.locked else ""]
