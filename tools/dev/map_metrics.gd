extends SceneTree
## What the floors come out like, in numbers, against what the generator
## promises (docs/DEVELOPMENT.md, "Generador de plantas"): rooms per planta,
## straight open runs, rings and dead ends, where the refuge is and how far,
## where the floor starts, whether a fixed way of walking a planta finds the
## refuge cheaply, how alike the corridor plans are, which plans come up and
## how long a floor takes to draw, and whether what is drawn per room (dark
## rooms, how kept they are, and what vary() dresses them with) has anything
## to do with where the room is. Only the manifests: nothing is built.
##
##   godot --headless --script tools/dev/map_metrics.gd -- 1000 [--survivors=N]
## Prints each measure with its threshold and PASS or FAIL, and writes
## evidence/map_metrics.json (map_metrics_N.json for another size); exits with
## 1 if anything fails. `--survivors` draws the floors of that many survivors
## (FLOOR.AREA: 1 half the hotel, 4 and 5 more; 2 by default); the measures in
## metres go with the square root of the size, the counts with the size.
const GEN := preload("res://game/world/generation/map_generator.gd")
const VALIDATOR := preload("res://game/world/generation/map_validator.gd")
const WALKER := preload("res://game/world/generation/wall_walker.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
## The points a floor is sampled at to compare what two floors have in the
## same place: every SAMPLE metres over a square SPREAD either way of the
## reception, on each planta.
const SAMPLE := 6.0
const SPREAD := 90.0
## A planta's corridors drawn on a square this many cells a side, to compare
## plans of different sizes: a cell about as wide as a corridor (the plan of a
## floor is 150 to 250 m across, a corridor 3 to 4 m), so that two corridors
## count as the same one only where they are.
const RASTER := 48
## A fixed way of walking solves a planta if it finds the refuge having looked
## into fewer than this share of it.
const CHEAP := 0.3

var results: Array = []
var failed := 0

func judge(title: String, value, passed: bool, threshold: String) -> void:
	results.append({"measure": title, "value": value, "threshold": threshold, "passed": passed})
	if not passed: failed += 1
	print("%s  %s = %s  (%s)" % ["PASS" if passed else "FAIL", title, str(value), threshold])

static func quantile(values: Array, share: float) -> float:
	if values.is_empty(): return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[clampi(int(floor(share * float(sorted.size() - 1) + 0.5)), 0, sorted.size() - 1)])

static func share_of(count: int, total: int) -> float:
	return snappedf(float(count) / maxf(1.0, float(total)), 0.001)

func _initialize() -> void:
	var floors := 200
	var survivors := 2
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int(): floors = argument.to_int()
		elif argument.begins_with("--survivors="): survivors = argument.get_slice("=", 1).to_int()
	var area := FLOOR.area_for(survivors)
	var reach := sqrt(area)
	var window := FLOOR.rooms_window(area)
	var generator := GEN.new()
	var times: Array = []
	var fallbacks := 0
	var invalid := 0
	var worst_lift := 0.0
	var rooms_all: Array = []
	var numbered_all: Array = []
	var areas: Array = []
	var runs: Array = []
	var rings: Array = []
	var dead: Array = []
	var bearings := {}
	var shared_bearing := 0
	var deepest := 0
	var depth_shares: Array = []
	var routes: Array = []
	var ratios: Array = []
	var starts := {}
	var start_doors := {}
	var solved := {"mano derecha": 0, "mano izquierda": 0, "barrer pasillos": 0, "esquina lejana": 0}
	var plans := {}
	var rasters: Array = []
	var together: Array = []
	var plantas := 0
	# What each floor has at the sample points, per planta: dark (1 or 0) and
	# kept (0 to 2), or -1 where it has no room.
	var sampled: Array = []
	for seed_value in floors:
		var began := Time.get_ticks_usec()
		var data := generator.generate(seed_value, survivors)
		times.append((Time.get_ticks_usec() - began) / 1000.0)
		if data.fallback: fallbacks += 1
		if not VALIDATOR.new().validate(data).is_empty(): invalid += 1
		var open := {}
		for pair in data.merged: open[Vector2i(int(pair[0]), int(pair[1]))] = true
		var box := plan_box(data)
		var floor_bearings := {}
		for gate in data.gates:
			var arrive := int(gate.arrive)
			if arrive < 0: continue
			var above := FLOOR.position_of(data.rooms[int(gate.beyond)])
			var below := FLOOR.position_of(data.rooms[arrive])
			worst_lift = maxf(worst_lift, Vector2(above.x - below.x, above.z - below.z).length())
		for planta in 3:
			plantas += 1
			var base := int(data.plantas[planta].base)
			var per := int(data.plantas[planta].width) * int(data.plantas[planta].height)
			var entry := int(data.entries[planta])
			var refuge := int(data.refuges[planta])
			var plan: String = data.plans[planta].plan
			plans[plan] = int(plans.get(plan, 0)) + 1
			# Rooms as they are counted, cells, doors and dead ends.
			var halls := {}
			var counted := 0
			var cells := 0
			var doors := 0
			var single := 0
			var numbered := 0
			var square := 0.0
			for local in per:
				var room: Dictionary = data.rooms[base + local]
				if FLOOR.is_void(room): continue
				cells += 1
				doors += data.adjacency[base + local].size()
				square += float(room.span_x) * float(room.span_z)
				if int(room.get("number", 0)) > 0: numbered += 1
				if room.kind != "module" or bool(room.get("landing", false)) or (planta > 0 and base + local == entry): continue
				if int(room.hall) >= 0:
					if halls.has(int(room.hall)): continue
					halls[int(room.hall)] = true
				counted += 1
				if data.adjacency[base + local].size() == 1 and base + local != refuge: single += 1
			rooms_all.append(counted)
			numbered_all.append(numbered)
			areas.append(square)
			rings.append(doors / 2 - cells + 1)
			dead.append(float(single) / maxf(1.0, float(counted)))
			runs.append(longest_run(data, open, planta))
			# The refuge: how far in, which way, and whether it is the deepest.
			var metres := FLOOR.route_metres(data, entry)
			var far := 0.0
			var farthest := entry
			for id in metres:
				if float(metres[id]) > far:
					far = float(metres[id])
					farthest = int(id)
			var at: float = float(metres.get(refuge, 0.0))
			depth_shares.append(at / maxf(1.0, far))
			if farthest == refuge: deepest += 1
			routes.append(at)
			var from := FLOOR.position_of(data.rooms[entry])
			var to := FLOOR.position_of(data.rooms[refuge])
			var straight := Vector2(to.x - from.x, to.z - from.z)
			ratios.append(at / maxf(1.0, straight.length()))
			var bearing := int(floor(fposmod(straight.angle() + PI / 8.0, TAU) / (PI / 4.0))) % 8
			bearings[bearing] = int(bearings.get(bearing, 0)) + 1
			if floor_bearings.has(bearing): shared_bearing += 1
			floor_bearings[bearing] = true
			# The fixed ways of walking a planta.
			for hand in [1, -1]:
				var cheapest := INF
				for heading in WALKER.HEADINGS:
					var walk := WALKER.walk(data.rooms, data.adjacency, entry, heading, hand, refuge)
					if bool(walk.found): cheapest = minf(cheapest, float(walk.rooms))
				if cheapest < CHEAP * cells: solved["mano derecha" if hand == 1 else "mano izquierda"] += 1
			if sweep(data, base, per, entry, refuge) < CHEAP * cells: solved["barrer pasillos"] += 1
			if far_corner(data, base, per, entry, refuge) < CHEAP * counted: solved["esquina lejana"] += 1
			rasters.append({"floor": seed_value, "raster": raster(data, base, per, box)})
		# The plantas of one floor two by two, each pair on a square over the
		# two of them: whatever the third is like has nothing to do with it.
		for pair in [[0, 1], [0, 2], [1, 2]]:
			var both := pair_box(data, pair[0], pair[1])
			var one := raster(data, int(data.plantas[pair[0]].base), int(data.plantas[pair[0]].width) * int(data.plantas[pair[0]].height), both)
			var two := raster(data, int(data.plantas[pair[1]].base), int(data.plantas[pair[1]].width) * int(data.plantas[pair[1]].height), both)
			together.append(best_overlap(one, two))
		# Where the floor starts, on the plan of the first planta, and which
		# way its reception's door faces.
		var start := FLOOR.position_of(data.rooms[int(data.start)])
		var column := clampi(int((start.x - box.position.x) / box.size.x * 3.0), 0, 2)
		var row := clampi(int((start.z - box.position.y) / box.size.y * 3.0), 0, 2)
		starts[row * 3 + column] = int(starts.get(row * 3 + column, 0)) + 1
		var facing := int(round(fposmod(float(data.start_facing), TAU) / (PI / 2.0))) % 4
		start_doors[facing] = int(start_doors.get(facing, 0)) + 1
		if seed_value < 500: sampled.append(samples(data))
	# Alike plans: pairs of plantas from different floors, and the three of
	# each floor, compared at their best of the eight turns and mirrors.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var apart: Array = []
	for pair in 400:
		var one: Dictionary = rasters[rng.randi_range(0, rasters.size() - 1)]
		var two: Dictionary = rasters[rng.randi_range(0, rasters.size() - 1)]
		if one.floor == two.floor: continue
		apart.append(best_overlap(one.raster, two.raster))
	# The same place on two floors: dark or not, kept or not, and vary() (the
	# paintings, the furniture along the walls) there, one floor after the
	# next.
	var dark_alike: Array = []
	var kept_alike: Array = []
	var looks_alike: Array = []
	for index in sampled.size() - 1:
		for planta in 3:
			dark_alike.append(correlation(sampled[index][planta].dark, sampled[index + 1][planta].dark))
			kept_alike.append(correlation(sampled[index][planta].kept, sampled[index + 1][planta].kept))
	var one = GEOMETRY.new()
	var two = GEOMETRY.new()
	for index in 200:
		one.looks = GEOMETRY.looks_of(index)
		two.looks = GEOMETRY.looks_of(index + 1)
		var first: Array = []
		var second: Array = []
		for x in range(-15, 16):
			for z in range(-15, 16):
				var at := Vector3(x * SAMPLE, 0.0, z * SAMPLE)
				first.append(one.vary(at, 13))
				second.append(two.vary(at, 13))
		looks_alike.append(correlation(first, second))
	one.free()
	two.free()
	print("pisos ", floors, " · plantas ", plantas, " · por qué se volvió a dibujar algo: ", generator.stats)
	print("supervivientes ", survivors, ", área ×", area)
	judge("habitaciones por planta, mínimo", rooms_all.min(), rooms_all.min() >= window.x, ">= %d" % window.x)
	judge("habitaciones por planta, máximo", rooms_all.max(), rooms_all.max() <= window.y, "<= %d" % window.y)
	judge("habitaciones con número por planta, máximo", numbered_all.max(), numbered_all.max() <= FLOOR.NUMBERED_MOST, "<= %d" % FLOOR.NUMBERED_MOST)
	judge("área por planta, mediana (m²)", snappedf(quantile(areas, 0.5), 1.0), true, "informativo")
	judge("pisos de respaldo", share_of(fallbacks, floors), float(fallbacks) / floors < 0.005, "< 0,5 %")
	var redrawn := 0
	for reason in generator.stats: if not String(reason).begins_with("island"): redrawn += int(generator.stats[reason])
	judge("plantas dibujadas otra vez", share_of(redrawn, plantas), true, "informativo")
	judge("pisos que no valida el validador", invalid, invalid == 0, "0")
	judge("desvío entre coche y vestíbulo de llegada (m)", snappedf(worst_lift, 0.0001), worst_lift < 0.001, "< 1 mm")
	judge("recta abierta más larga (m)", snappedf(runs.max(), 0.1), runs.max() <= 45.01, "<= 45 m")
	judge("anillos por planta, mínimo", rings.min(), rings.min() >= FLOOR.rings(area), ">= %d" % FLOOR.rings(area))
	judge("habitaciones sin salida, mediana", snappedf(quantile(dead, 0.5), 0.01), quantile(dead, 0.5) >= 0.2 and quantile(dead, 0.5) <= 0.45, "20–45 %")
	var worst_bearing := 0
	for bin in bearings: worst_bearing = maxi(worst_bearing, int(bearings[bin]))
	judge("dirección del refugio, sector más repetido", share_of(worst_bearing, plantas), float(worst_bearing) / plantas <= 0.2, "<= 20 %")
	judge("pisos con dos refugios en la misma dirección", shared_bearing, shared_bearing == 0, "0")
	judge("refugio en la sala más honda", share_of(deepest, plantas), deepest == 0, "0 %")
	judge("hondura del refugio (fracción del recorrido más largo), mínimo", snappedf(depth_shares.min(), 0.01), depth_shares.min() >= 0.55 - 0.001, ">= 0,55")
	judge("hondura del refugio, máximo", snappedf(depth_shares.max(), 0.01), depth_shares.max() <= 0.9 + 0.001, "<= 0,90")
	judge("recorrido llegada → refugio, p5 (m)", snappedf(quantile(routes, 0.05), 1.0), quantile(routes, 0.05) >= 90.0 * reach, ">= %d m" % roundi(90.0 * reach))
	judge("recorrido llegada → refugio, mediana (m)", snappedf(quantile(routes, 0.5), 1.0), quantile(routes, 0.5) >= 140.0 * reach and quantile(routes, 0.5) <= 260.0 * reach, "%d–%d m" % [roundi(140.0 * reach), roundi(260.0 * reach)])
	judge("recorrido / línea recta, p5", snappedf(quantile(ratios, 0.05), 0.01), quantile(ratios, 0.05) >= 1.5, ">= 1,5")
	var worst_start := 0
	for bin in starts: worst_start = maxi(worst_start, int(starts[bin]))
	judge("recepción, casilla 3×3 más repetida", share_of(worst_start, floors), float(worst_start) / floors <= 0.2, "<= 20 %")
	var worst_door := 0
	for bin in start_doors: worst_door = maxi(worst_door, int(start_doors[bin]))
	judge("puerta de la recepción, dirección más repetida", share_of(worst_door, floors), float(worst_door) / floors <= 0.35, "<= 35 %")
	for way in solved: judge("plantas que resuelve «%s» con menos del 30 %%" % way, share_of(int(solved[way]), plantas), float(solved[way]) / plantas <= 0.2, "<= 20 %")
	# A planta half the size has fewer lanes to differ in: two of them at random
	# share a little more of their corridor floor.
	var alike_mean := 0.12 if area >= 1.0 else 0.14
	var alike_p95 := 0.25 if area >= 1.0 else 0.27
	judge("parecido de planos al azar (IoU), media", snappedf(quantile(apart, 0.5) if apart.is_empty() else apart.reduce(func(a, b): return a + b, 0.0) / apart.size(), 0.001), apart.reduce(func(a, b): return a + b, 0.0) / maxf(1.0, apart.size()) <= alike_mean, "<= %s" % str(alike_mean).replace(".", ","))
	judge("parecido de planos al azar (IoU), p95", snappedf(quantile(apart, 0.95), 0.001), quantile(apart, 0.95) <= alike_p95, "<= %s" % str(alike_p95).replace(".", ","))
	judge("parecido de las plantas de un piso (IoU), máximo", snappedf(together.max() if not together.is_empty() else 0.0, 0.001), together.is_empty() or together.max() <= 0.35, "<= 0,35")
	for plan in ["spine", "twin", "ring", "comb", "blocks", "arms", "warren", "rot"]:
		var used: float = float(plans.get(plan, 0)) / plantas
		judge("uso del plano %s" % plan, snappedf(used, 0.001), used >= 0.08 and used <= 0.2, "8–20 %")
	var mean := func(values: Array) -> float: return values.reduce(func(a, b): return a + b, 0.0) / maxf(1.0, values.size())
	judge("salas oscuras en el mismo sitio de dos pisos (correlación)", snappedf(mean.call(dark_alike), 0.001), absf(mean.call(dark_alike)) <= 0.05, "<= 0,05")
	judge("estado de las salas en el mismo sitio de dos pisos (correlación)", snappedf(mean.call(kept_alike), 0.001), absf(mean.call(kept_alike)) <= 0.05, "<= 0,05")
	judge("vary() en el mismo sitio de dos pisos (correlación)", snappedf(mean.call(looks_alike), 0.001), absf(mean.call(looks_alike)) <= 0.05, "<= 0,05")
	judge("generación, mediana (ms)", snappedf(quantile(times, 0.5), 0.1), true, "informativo")
	var slowest := 250.0 * maxf(1.0, area * area)
	judge("generación, p99 (ms)", snappedf(quantile(times, 0.99), 0.1), quantile(times, 0.99) <= slowest, "<= %d ms" % roundi(slowest))
	var file := FileAccess.open("res://evidence/map_metrics%s.json" % ("" if survivors == 2 else "_%d" % survivors), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"floors": floors, "survivors": survivors, "passed": failed == 0, "stats": generator.stats, "measures": results}, "\t"))
		file.close()
	print("MAP_METRICS ", "PASS" if failed == 0 else "FAIL", " · ", results.size() - failed, "/", results.size())
	quit(0 if failed == 0 else 1)

## A floor at the sample points of each planta: {dark, kept}, each a list
## with -1 where the floor has no room.
static func samples(data: Dictionary) -> Array:
	var out: Array = []
	var steps := int(SPREAD / SAMPLE)
	for planta in 3:
		var dark: Array = []
		var kept: Array = []
		for x in range(-steps, steps + 1):
			for z in range(-steps, steps + 1):
				var room := FLOOR.room_at(data.rooms, Vector3(x * SAMPLE, FLOOR.planta_y(planta) + 0.5, z * SAMPLE))
				dark.append(-1 if room.is_empty() else (1 if bool(room.dark) else 0))
				kept.append(-1 if room.is_empty() else int(room.kept))
		out.append({"dark": dark, "kept": kept})
	return out

## Pearson's correlation of two lists over the places both have something
## (-1 is nothing); 0 when either is the same everywhere.
static func correlation(one: Array, two: Array) -> float:
	var xs: Array = []
	var ys: Array = []
	for index in one.size():
		if float(one[index]) < 0.0 or float(two[index]) < 0.0: continue
		xs.append(float(one[index]))
		ys.append(float(two[index]))
	if xs.size() < 2: return 0.0
	var mx: float = xs.reduce(func(a, b): return a + b, 0.0) / xs.size()
	var my: float = ys.reduce(func(a, b): return a + b, 0.0) / ys.size()
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for index in xs.size():
		sxy += (xs[index] - mx) * (ys[index] - my)
		sxx += (xs[index] - mx) * (xs[index] - mx)
		syy += (ys[index] - my) * (ys[index] - my)
	if sxx <= 0.0 or syy <= 0.0: return 0.0
	return sxy / sqrt(sxx * syy)

## The plan's footprint: every cell of the grid, whatever the plantas use.
static func plan_box(data: Dictionary) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for room in data.rooms:
		var at := FLOOR.position_of(room)
		var half := FLOOR.size_of(room) * 0.5
		low = Vector2(minf(low.x, at.x - half.x), minf(low.y, at.z - half.y))
		high = Vector2(maxf(high.x, at.x + half.x), maxf(high.y, at.z + half.y))
	return Rect2(low, high - low)

## The box over two plantas of a floor, every cell of either.
static func pair_box(data: Dictionary, one: int, two: int) -> Rect2:
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for room in data.rooms:
		if int(room.wing) != one and int(room.wing) != two: continue
		var at := FLOOR.position_of(room)
		var half := FLOOR.size_of(room) * 0.5
		low = Vector2(minf(low.x, at.x - half.x), minf(low.y, at.z - half.y))
		high = Vector2(maxf(high.x, at.x + half.x), maxf(high.y, at.z + half.y))
	return Rect2(low, high - low)

## Longest a row or a column of cells runs with no wall between them.
static func longest_run(data: Dictionary, open: Dictionary, planta: int) -> float:
	var base := int(data.plantas[planta].base)
	var width := int(data.plantas[planta].width)
	var height := int(data.plantas[planta].height)
	var longest := 0.0
	for across in [true, false]:
		for line in (height if across else width):
			var run := 0.0
			var previous := -1
			for along in (width if across else height):
				var id: int = base + (line * width + along if across else along * width + line)
				var room: Dictionary = data.rooms[id]
				var size: float = float(room.span_x) if across else float(room.span_z)
				if previous >= 0 and open.has(Vector2i(previous, id)): run += size
				else: run = size
				if not FLOOR.is_void(room): longest = maxf(longest, run)
				previous = id
	return longest

## Walking the corridors and looking into every room that opens on to them,
## from the ones at the way in: how many cells it has looked at when it sees
## the refuge, INF if it never does.
static func sweep(data: Dictionary, base: int, per: int, entry: int, refuge: int) -> float:
	var seen := {entry: true}
	var queue: Array = []
	for other in data.adjacency[entry]:
		if bool(data.rooms[int(other)].corridor): queue.append(int(other))
	if bool(data.rooms[entry].corridor): queue.append(entry)
	var walked := {}
	var cursor := 0
	while cursor < queue.size():
		var at: int = queue[cursor]
		cursor += 1
		if walked.has(at): continue
		walked[at] = true
		seen[at] = true
		for other in data.adjacency[at]:
			var next := int(other)
			seen[next] = true
			if next == refuge: return float(seen.size())
			if bool(data.rooms[next].corridor) and not walked.has(next): queue.append(next)
	return INF

## Going to the far side of the planta first: rooms in order of how far they
## are in a straight line from the way in. Where the refuge is in that order.
static func far_corner(data: Dictionary, base: int, per: int, entry: int, refuge: int) -> float:
	var from := FLOOR.position_of(data.rooms[entry])
	var rooms: Array = []
	for local in per:
		var room: Dictionary = data.rooms[base + local]
		if FLOOR.is_void(room) or room.kind != "module": continue
		rooms.append(base + local)
	rooms.sort_custom(func(a, b): return FLOOR.position_of(data.rooms[a]).distance_to(from) > FLOOR.position_of(data.rooms[b]).distance_to(from))
	return float(rooms.find(refuge) + 1)

## The planta's corridors on a RASTER × RASTER square laid over the plan.
static func raster(data: Dictionary, base: int, per: int, box: Rect2) -> PackedByteArray:
	var cells := PackedByteArray()
	cells.resize(RASTER * RASTER)
	for local in per:
		var room: Dictionary = data.rooms[base + local]
		if FLOOR.is_void(room) or not bool(room.corridor): continue
		var at := FLOOR.position_of(room)
		var half := FLOOR.size_of(room) * 0.5
		var x0 := clampi(int((at.x - half.x - box.position.x) / box.size.x * RASTER), 0, RASTER - 1)
		var x1 := clampi(int((at.x + half.x - box.position.x) / box.size.x * RASTER), 0, RASTER - 1)
		var z0 := clampi(int((at.z - half.y - box.position.y) / box.size.y * RASTER), 0, RASTER - 1)
		var z1 := clampi(int((at.z + half.y - box.position.y) / box.size.y * RASTER), 0, RASTER - 1)
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1): cells[z * RASTER + x] = 1
	return cells

## Intersection over union of two plans, at the best of the eight ways of
## turning and mirroring the second.
static func best_overlap(one: PackedByteArray, two: PackedByteArray) -> float:
	var side := RASTER
	var count_one := 0
	for value in one: count_one += value
	var marks := PackedInt32Array()
	for index in two.size():
		if two[index]: marks.append(index)
	if count_one + marks.size() == 0: return 0.0
	var best := 0.0
	for turn in 8:
		# Each cell of the second, turned back to where it lands on the first.
		var both := 0
		for index in marks:
			var u := index % side
			var v := index / side
			if turn & 4:
				var swap := u
				u = v
				v = swap
			if turn & 1: u = side - 1 - u
			if turn & 2: v = side - 1 - v
			both += one[v * side + u]
		best = maxf(best, float(both) / float(count_one + marks.size() - both))
	return best
