extends SceneTree
## How long the offices take to play, measured on the plan alone (nothing
## built): a naive explorer who does not know the plan walks each planta from
## its way in to each of its landmarks in turn, and the minutes are counted
## (.claude/specs/cordura_y_edificio.md, phase 0).
##
## The explorer goes through the rooms with more than one door, nearest first
## over what it has seen, and sees into a room from its doorway: a landmark
## (or the lift's lobby) is found when it stands in a room next to it. It
## ignores the signs. What it has seen carries over from one leg of a planta to
## the next. "Direct" is the shortest way, for somebody who knows the plan.
## Walking WALK m/s, LOOK s more for each room it goes into; each planta adds
## the seconds its errand holds (typing, the timer, the fans, the crawl).
##   godot --headless --script tools/dev/office_explorer.gd -- 40 [--runs=3] [--survivors=2] [--area=2.0]
## Writes evidence/planta/explorador.json.
const GEN := preload("res://game/world/generation/office_generator.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const WALK := 3.2
const DIRECT_WALK := 3.8
const LOOK := 1.0
## How much nearer the explorer reckons a corridor than a room.
const CORRIDOR_PULL := 0.8
## The errands' fixed seconds: typing, the capsule's way, taking and swiping
## the card; the maneuver room's door on its motor and its lever; the post's
## cameras looked through, then the hatch and the climb; the crawl's pace.
const TYPE_HOLD := 5.0 + 1.2
const CAPSULE_SPEED := 6.0
const CARD_HOLDS := 1.5 + 0.5
const MANEUVER_HOLDS := 7.2 + 1.0
const CAMS_HOLD := 20.0 + 2.0 + 2.4
const CRAWL := 1.2

func _initialize() -> void:
	var floors := 40
	var runs := 3
	var survivors := 2
	# A bigger building than the survivors' (the scale test): every planta this area.
	var area := 0.0
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int(): floors = int(argument)
		elif argument.begins_with("--runs="): runs = int(argument.get_slice("=", 1))
		elif argument.begins_with("--survivors="): survivors = int(argument.get_slice("=", 1))
		elif argument.begins_with("--area="): area = float(argument.get_slice("=", 1))
	var naive := [[], [], []]
	var direct := [[], [], []]
	var legs := {}
	var totals: Array = []
	var made := 0
	var made_ms: Array = []
	var failures := {}
	var rooms := [[], [], []]
	var direct_totals: Array = []
	for run_seed in range(1, floors + 1):
		var generator = GEN.new()
		generator.areas = OFFICE.areas_for(survivors) if area <= 0.0 else [area, area, area]
		var data := {}
		var began := Time.get_ticks_msec()
		for attempt in generator.attempts():
			data = generator.candidate(run_seed, attempt)
			if not data.is_empty(): break
		made_ms.append(Time.get_ticks_msec() - began)
		if data.is_empty():
			for key in generator.stats: failures[key] = int(failures.get(key, 0)) + int(generator.stats[key])
			continue
		made += 1
		for p in 3: rooms[p].append(data.rooms.filter(func(r): return int(r.get("wing", -1)) == p and not FLOOR.is_void(r)).size())
		FLOOR.build_index(data.rooms)
		var straight := plantas(data, run_seed, 0, true, legs)
		for run in runs:
			var walked := plantas(data, run_seed, run + 1, false, legs)
			for p in 3: naive[p].append(walked[p])
			totals.append(walked[0] + walked[1] + walked[2])
		for p in 3: direct[p].append(straight[p])
		direct_totals.append(straight[0] + straight[1] + straight[2])
	var out := {"floors": floors, "made": made, "runs": runs, "survivors": survivors, "area": area, "walk": WALK, "look": LOOK, "draw_ms": spread(made_ms), "failures": failures}
	print("EXPLORER %d de %d pisos, dibujar %s ms, fallos %s" % [made, floors, str(spread(made_ms)), str(failures)])
	for p in 3:
		out["rooms_%d" % p] = spread(rooms[p])
		print("EXPLORER planta %d: salas %s" % [p + 1, str(spread(rooms[p]))])
	for p in 3:
		out["naive_%d" % p] = spread(naive[p])
		out["direct_%d" % p] = spread(direct[p])
		print("EXPLORER planta %d: ingenuo %s min, directo %s min" % [p + 1, str(spread(naive[p])), str(spread(direct[p]))])
	for leg in legs:
		out["leg_" + leg] = spread(legs[leg])
		print("EXPLORER tramo %s: %s min" % [leg, str(spread(legs[leg]))])
	out["naive_total"] = spread(totals)
	out["direct_total"] = spread(direct_totals)
	print("EXPLORER piso: ingenuo %s min, directo %s min" % [str(spread(totals)), str(spread(direct_totals))])
	var file := FileAccess.open("res://evidence/planta/explorador%s.json" % ("" if area <= 0.0 else "_area%s" % str(area)), FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "  "))
	quit(0)

## Minutes each planta takes, walked naively (or straight, knowing the plan).
func plantas(data: Dictionary, run_seed: int, run: int, straight: bool, legs: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, run, "explorer"])
	var out := [0.0, 0.0, 0.0]
	# Planta 1: the window, the station the card went to (followed by ear or
	# read off the map: straight there), the lift.
	var mail: Dictionary = data.get("mail", {})
	var stations: Array = data.get("tubes", {}).get("exits", []).filter(func(e): return String(e.get("kind", "")) == "station")
	var seen := {}
	var start := int(data.entries[0])
	var window := int(mail.get("window", -1))
	var a := leg(data, start, window, seen, rng, straight)
	var exit: Dictionary = stations[rng.randi_range(0, stations.size() - 1)] if not stations.is_empty() else {}
	var station := int(exit.get("room", window))
	var b := leg(data, window, station, seen, rng, true) + minf(float(exit.get("tube", 30.0)), 200.0) / CAPSULE_SPEED
	var c := leg(data, station, int(data.refuges[0]), seen, rng, straight)
	out[0] = (a + b + c + TYPE_HOLD + CARD_HOLDS) / 60.0
	if not straight:
		add(legs, "1_ventanilla", a / 60.0)
		add(legs, "1_estacion", b / 60.0)
		add(legs, "1_montacargas", c / 60.0)
	# Planta 2: the board, the maneuver room, then the lift.
	seen = {}
	var electrical := int(data.get("power", {}).get("room", -1))
	var maneuver := int(data.get("power", {}).get("maneuver", {}).get("room", electrical))
	a = leg(data, int(data.entries[1]), electrical, seen, rng, straight)
	b = leg(data, electrical, maneuver, seen, rng, straight)
	c = leg(data, maneuver, int(data.refuges[1]), seen, rng, straight)
	out[1] = (a + b + c + MANEUVER_HOLDS) / 60.0
	if not straight:
		add(legs, "2_cuadro", a / 60.0)
		add(legs, "2_maniobra", b / 60.0)
		add(legs, "2_montacargas", c / 60.0)
	# Planta 3: the post and its cameras, the air room, the crawl.
	seen = {}
	var air: Dictionary = data.get("air", {})
	var post := int(air.get("security", {}).get("room", -1))
	var plant := int(air.get("room", data.refuges[2]))
	a = leg(data, int(data.entries[2]), post, seen, rng, straight)
	b = leg(data, post, plant, seen, rng, straight)
	var crawl := float(air.get("main", {}).get("length", 35.0)) / CRAWL
	out[2] = (a + b + CAMS_HOLD + crawl) / 60.0
	if not straight:
		add(legs, "3_seguridad", a / 60.0)
		add(legs, "3_climatizacion", b / 60.0)
		add(legs, "3_ducto", crawl / 60.0)
	return out

func add(legs: Dictionary, key: String, value: float) -> void:
	if not legs.has(key): legs[key] = []
	legs[key].append(value)

## Seconds from one room to another: straight along the doors, or exploring.
func leg(data: Dictionary, from: int, to: int, seen: Dictionary, rng: RandomNumberGenerator, straight: bool) -> float:
	if from < 0 or to < 0 or from == to: return 0.0
	if straight:
		return float(FLOOR.route_metres(data, from).get(to, 0.0)) / DIRECT_WALK
	var rooms: Array = data.rooms
	var here := from
	var seconds := 0.0
	seen[here] = true
	for _step in 2000:
		if data.adjacency[here].has(to) or here == to:
			return seconds + FLOOR.position_of(rooms[here]).distance_to(FLOOR.position_of(rooms[to])) / WALK + LOOK
		# What it can go on to: rooms it has not been in, next to one it has,
		# that lead somewhere (more than one door); nearest by the way it knows.
		var known := within(data, here, seen)
		var best := -1
		var best_cost := INF
		for id in known:
			for other in data.adjacency[id]:
				var next := int(other)
				if seen.has(next) or data.adjacency[next].size() < 2: continue
				var pull := CORRIDOR_PULL if bool(rooms[next].get("corridor", false)) else 1.0
				var cost: float = (float(known[id]) + FLOOR.position_of(rooms[id]).distance_to(FLOOR.position_of(rooms[next]))) * pull * rng.randf_range(0.85, 1.15)
				if cost < best_cost:
					best_cost = cost
					best = next
		if best < 0:
			# Nothing left that leads anywhere: it walks straight there at last.
			return seconds + float(FLOOR.route_metres(data, here).get(to, 0.0)) / WALK
		var through := within(data, here, seen.merged({best: true}))
		seconds += float(through.get(best, 0.0)) / WALK + LOOK
		seen[best] = true
		here = best
	return seconds

## Metres from a room to every room it has been in, through those rooms only.
func within(data: Dictionary, from: int, seen: Dictionary) -> Dictionary:
	var rooms: Array = data.rooms
	var metres := {from: 0.0}
	var open: Array = [from]
	while not open.is_empty():
		var best := 0
		for index in open.size():
			if float(metres[open[index]]) < float(metres[open[best]]): best = index
		var at: int = open[best]
		open.remove_at(best)
		for other in data.adjacency[at]:
			var next := int(other)
			if not seen.has(next): continue
			var length: float = float(metres[at]) + FLOOR.position_of(rooms[at]).distance_to(FLOOR.position_of(rooms[next]))
			if not metres.has(next) or length < float(metres[next]) - 0.001:
				if not metres.has(next): open.append(next)
				metres[next] = length
	return metres

## [min, p25, median, p75, max], to a decimal.
func spread(values: Array) -> Array:
	if values.is_empty(): return []
	var sorted := values.duplicate()
	sorted.sort()
	var at := func(q: float) -> float: return snappedf(float(sorted[clampi(roundi(q * (sorted.size() - 1)), 0, sorted.size() - 1)]), 0.1)
	return [at.call(0.0), at.call(0.25), at.call(0.5), at.call(0.75), at.call(1.0)]
