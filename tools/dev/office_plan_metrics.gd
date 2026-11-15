extends SceneTree
## The real plan (.claude/specs/planta_real.md 13) measured on many seeds,
## nothing built: whether each seed gives a floor without the standby one and
## why tries fail, the validator's codes on what comes out, the metres from
## the way in to the exit per planta, where the reception, the lifts and the
## air room fall and how that spreads, and the rules of 13.11 to 13.14; and
## per planta its rings, lockers, square metres and rooms by size, and the
## light layers each floor takes (room_layers, as light_layers_scan counts them).
##   godot --headless --script tools/dev/office_plan_metrics.gd -- 200 [--survivors=N]
## The floor of a seed is the first try that comes out (office_plan.floor_of()),
## so a validator not yet rewritten for the real plan does not hide it.
## Writes evidence/planta/metricas.json.
const PLAN := preload("res://tools/dev/office_plan.gd")
const GEN := preload("res://game/world/generation/office_generator.gd")
const VALIDATOR := preload("res://game/world/generation/office_validator.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const METRICS := preload("res://tools/dev/office_metrics.gd")
const LAYERS := preload("res://game/world/hotel/room_layers.gd")

func _initialize() -> void:
	var floors := 200
	var survivors := 2
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int(): floors = int(argument)
		elif argument.begins_with("--survivors="): survivors = int(argument.get_slice("=", 1))
	OFFICE.real_plan_test = true
	var made := 0
	var reasons := {}
	var codes := {}
	var rejected := 0
	var attempts: Array = []
	var walks := [[], [], []]
	var shares := [[], [], []]
	var specials := {"window": [], "electrical": [], "security": []}
	var hits := 0
	var rooms := [[], [], []]
	var small := [[], [], []]
	var sites := {"reception": [], "a": [], "b": [], "air": []}
	var relative := {"a_from_reception": {}, "b_from_a": {}, "air_from_b": {}}
	var power_zones: Array = []
	var power_ceiling: Array = []
	var timers: Array = []
	var stations: Array = []
	var naves := 0
	var times: Array = []
	var lockers := [[], [], []]
	var rings := [[], [], []]
	var floor_m2 := [[], [], []]
	var sizes := [{}, {}, {}]
	# Rooms of each type per planta (a salon once), per seed; and how often two
	# rooms of a type the programme keeps apart (REAL_APART) stand side by side.
	var kinds := [{}, {}, {}]
	var side_by_side := [{}, {}, {}]
	var layers_most := 0
	var layers_full := 0
	var clashes := 0
	# The building from seed to seed (planta_real.md 13.3, 13.14): its typology,
	# length and depth, bays, crosses and where the middle ones stand, where the
	# reception is, the notch, the order of its bays and whether its two bands
	# of the first planta run alike.
	var build := {"typology": {}, "length": [], "depth": [], "bays": [], "crosses": {}, "cross_at": [], "start": {}, "notch": 0, "orders": {}, "bands_alike": 0}
	for run_seed in range(1, floors + 1):
		var generator = GEN.new()
		generator.areas = OFFICE.areas_for(survivors)
		var data := {}
		var began := Time.get_ticks_msec()
		for attempt in generator.attempts():
			data = generator.candidate(run_seed, attempt)
			if not data.is_empty(): break
		times.append(Time.get_ticks_msec() - began)
		for key in generator.stats: reasons[key] = int(reasons.get(key, 0)) + int(generator.stats[key])
		if data.is_empty(): continue
		made += 1
		attempts.append(int(data.attempt))
		measure_building(generator, data, build)
		var errors: Array = VALIDATOR.new().validate(data)
		if not errors.is_empty(): rejected += 1
		for code in PLAN.codes(errors): codes[code] = int(codes.get(code, 0)) + 1
		for p in 3:
			walks[p].append(float(FLOOR.route_metres(data, int(data.entries[p])).get(int(data.refuges[p]), -1.0)))
			shares[p].append(VALIDATOR.share_in(data, p, int(data.refuges[p])))
			hits += int(data.wall_hits[p])
			var count := 0
			var under := 0
			var seen := {}
			for room in data.rooms:
				if int(room.wing) != p or FLOOR.is_void(room) or bool(room.corridor) or int(room.type) in [OFFICE.LANDING, OFFICE.LOBBY]: continue
				var key := int(room.hall) if int(room.hall) >= 0 else int(room.id)
				if seen.has(key): continue
				seen[key] = true
				var area := 0.0
				for other in data.rooms:
					if int(other.id) == key or (int(room.hall) >= 0 and int(other.hall) == int(room.hall)): area += float(other.span_x) * float(other.span_z)
				count += 1
				if area < 30.0: under += 1
			rooms[p].append(count)
			small[p].append(float(under) / maxf(1.0, float(count)))
			# Rings as the validator counts them, the floor's square metres, the
			# rooms' sizes by band (a salon whole) and the lockers.
			var doors := 0
			var cells := 0
			var m2 := 0.0
			var seen_size := {}
			for room in data.rooms:
				if int(room.wing) != p or FLOOR.is_void(room): continue
				cells += 1
				doors += data.adjacency[int(room.id)].size()
				m2 += float(room.span_x) * float(room.span_z)
				if bool(room.corridor) or int(room.type) in [OFFICE.LANDING, OFFICE.LOBBY]: continue
				var key := int(room.hall) if int(room.hall) >= 0 else int(room.id)
				seen_size[key] = float(seen_size.get(key, 0.0)) + float(room.span_x) * float(room.span_z)
			# Less the rings inside a salon, as the validator (rings_ok()).
			var hall_cells := {}
			var seams := {}
			for room in data.rooms:
				if int(room.wing) == p and int(room.hall) >= 0 and not FLOOR.is_void(room): hall_cells[int(room.hall)] = int(hall_cells.get(int(room.hall), 0)) + 1
			for pair in data.merged:
				var a: Dictionary = data.rooms[int(pair[0])]
				if int(a.wing) == p and int(a.hall) >= 0 and int(a.hall) == int(data.rooms[int(pair[1])].hall): seams[int(a.hall)] = int(seams.get(int(a.hall), 0)) + 1
			var inside := 0
			for hall in hall_cells: inside += maxi(0, int(seams.get(hall, 0)) - int(hall_cells[hall]) + 1)
			rings[p].append(doors / 2 - cells + 1 - inside)
			floor_m2[p].append(m2)
			for key in seen_size:
				var a: float = seen_size[key]
				var band := "<15" if a < 15.0 else "15-30" if a < 30.0 else "30-50" if a < 50.0 else "50-100" if a < 100.0 else ">=100"
				sizes[p][band] = int(sizes[p].get(band, 0)) + 1
		for p in 3:
			var count := {}
			var seen := {}
			for room in data.rooms:
				if int(room.wing) != p or FLOOR.is_void(room) or bool(room.corridor): continue
				var key := int(room.hall) if int(room.hall) >= 0 else int(room.id)
				if seen.has(key): continue
				seen[key] = true
				count[int(room.type)] = int(count.get(int(room.type), 0)) + 1
			for t in OFFICE.NAMES.size():
				if not kinds[p].has(t): kinds[p][t] = []
				kinds[p][t].append(int(count.get(t, 0)))
			var apart := {}
			for room in data.rooms:
				if int(room.wing) == p and OFFICE.kept_apart(room): apart[Vector2i(int(room.x), int(room.z))] = room
			for cell: Vector2i in apart:
				for next: Vector2i in [cell + Vector2i(1, 0), cell + Vector2i(0, 1)]:
					var other: Dictionary = apart.get(next, {})
					var room: Dictionary = apart[cell]
					if other.is_empty() or int(other.type) != int(room.type) or (int(room.hall) >= 0 and int(other.hall) == int(room.hall)): continue
					tally(side_by_side[p], OFFICE.plan_code(room))
		for want in [["window", 0, OFFICE.WINDOW], ["electrical", 1, OFFICE.ELECTRICAL], ["security", 2, OFFICE.SECURITY]]:
			var found := VALIDATOR.of_type(data, int(want[1]), int(want[2]))
			specials[want[0]].append(VALIDATOR.share_in(data, int(want[1]), int(found[0].id)) if found.size() == 1 else -1.0)
		# Where the four fall on the building, as shares of its length and depth.
		var box := used_box(data, 0)
		var at := func(id: int) -> Vector2: return (Vector2(float(data.rooms[id].px), float(data.rooms[id].pz)) - box.position) / box.size
		var reception: Vector2 = at.call(int(data.start))
		var a: Vector2 = at.call(int(data.refuges[0]))
		var b: Vector2 = at.call(int(data.refuges[1]))
		var air: Vector2 = at.call(int(data.refuges[2]))
		sites.reception.append(reception)
		sites.a.append(a)
		sites.b.append(b)
		sites.air.append(air)
		tally(relative.a_from_reception, sector(reception, a, box))
		tally(relative.b_from_a, sector(a, b, box))
		tally(relative.air_from_b, sector(b, air, box))
		# The power room to B (13.12): zones crossed and the share under a false ceiling.
		var room_e := VALIDATOR.of_type(data, 1, OFFICE.ELECTRICAL)
		if room_e.size() == 1:
			var path := way(data, int(room_e[0].id), int(data.refuges[1]))
			var zones := {}
			var lined := 0
			for id in path:
				zones[int(data.rooms[id].sector)] = true
				if OFFICE.false_ceiling(data.rooms[id]): lined += 1
			power_zones.append(zones.size())
			power_ceiling.append(float(lined) / maxf(1.0, float(path.size())))
		var m := METRICS.floor_measures(data)
		for p in 3: lockers[p].append(int(m.lockers[p]))
		var assigned := LAYERS.assign(data)
		var used := {}
		for bit in assigned.layer:
			if bit != 0: used[bit] = true
		for room in assigned.cars: used[assigned.cars[room]] = true
		layers_most = maxi(layers_most, used.size())
		if used.size() >= 16: layers_full += 1
		clashes += int(assigned.clashes)
		timers.append(float(m.timer_cover))
		stations.append(int(m.stations))
		if not data.get("nave", {}).is_empty() or data.rooms.any(func(r): return String(r.get("nave_axis", "")) != ""): naves += 1
	var out := {"floors": floors, "survivors": survivors, "made": made, "reasons": reasons, "rejected": rejected, "codes": codes}
	print("PLAN_METRICS semillas %d, con planta (sin la de reserva) %d, rechazadas por el validador %d" % [floors, made, rejected])
	print("PLAN_METRICS intento que sale: %s" % str(spread(attempts)))
	print("PLAN_METRICS intentos fallidos por motivo: %s" % str(reasons))
	print("PLAN_METRICS códigos del validador (pisos con cada uno): %s" % str(codes))
	for p in 3:
		print("PLAN_METRICS planta %d: metros llegada-salida %s, cuota %s, salas %s, salas < 30 m2 %s" % [p + 1, str(spread(walks[p])), str(spread(shares[p])), str(spread(rooms[p])), str(spread(small[p]))])
		out["walk_%d" % p] = spread(walks[p])
		out["share_%d" % p] = spread(shares[p])
		out["rooms_%d" % p] = spread(rooms[p])
		out["small_%d" % p] = spread(small[p])
	print("PLAN_METRICS manos en la pared que encuentran un refugio: %d" % hits)
	for key in specials:
		print("PLAN_METRICS %s, cuota %s" % [key, str(spread(specials[key]))])
		out[key] = spread(specials[key])
	for key in sites:
		var xs: Array = sites[key].map(func(v): return snappedf(v.x, 0.01))
		var zs: Array = sites[key].map(func(v): return snappedf(v.y, 0.01))
		print("PLAN_METRICS %s: x %s, z %s, extremo oeste %d / este %d" % [key, str(spread(xs)), str(spread(zs)), xs.filter(func(x): return x < 0.5).size(), xs.filter(func(x): return x >= 0.5).size()])
		out["site_" + key] = {"x": spread(xs), "z": spread(zs)}
	for key in relative:
		print("PLAN_METRICS rumbo %s (8 sectores, 0 = este): %s" % [key, str(relative[key])])
		out[key] = relative[key]
	print("PLAN_METRICS cuadro a B: zonas cruzadas %s, bajo falso techo %s, pisos con 3 zonas o más %d de %d" % [str(spread(power_zones)), str(spread(power_ceiling)), power_zones.filter(func(n): return int(n) >= 3).size(), power_zones.size()])
	print("PLAN_METRICS minuteros (cobertura de la planta 2) %s, estaciones %s, pisos con nave %d" % [str(spread(timers)), str(spread(stations)), naves])
	print("PLAN_METRICS ms por semilla %s" % str(spread(times)))
	for p in 3:
		print("PLAN_METRICS planta %d: vueltas %s, taquillas %s, m2 %s, salas por tamaño (m2) %s" % [p + 1, str(spread(rings[p])), str(spread(lockers[p])), str(spread(floor_m2[p])), str(sizes[p])])
		out["rings_%d" % p] = spread(rings[p])
		out["lockers_%d" % p] = spread(lockers[p])
		out["m2_%d" % p] = spread(floor_m2[p])
		out["sizes_%d" % p] = sizes[p]
	for p in 3:
		var line: Array = []
		for t in kinds[p]:
			var values: Array = kinds[p][t]
			if values.max() > 0: line.append("%s %s" % [OFFICE.plan_code({"type": t}) if OFFICE.plan_code({"type": t}) != "" else str(t), str(spread(values))])
		print("PLAN_METRICS planta %d: salas por tipo [mín, p10, p50, p90, máx] %s" % [p + 1, ", ".join(line)])
		print("PLAN_METRICS planta %d: parejas lado a lado de tipos que van sueltos %s" % [p + 1, str(side_by_side[p])])
	print("PLAN_METRICS edificio: tipologías %s, largo %s, fondo %s, vanos %s, transversales %s, transversales del medio a %s del largo" % [str(build.typology), str(spread(build.length)), str(spread(build.depth)), str(spread(build.bays)), str(build.crosses), str(spread(build.cross_at))])
	print("PLAN_METRICS edificio: recepción %s, con muesca %d, órdenes de vanos distintos %d de %d, bandas de la planta 1 iguales %d" % [str(build.start), int(build.notch), build.orders.size(), made, int(build.bands_alike)])
	out["building"] = {"typology": build.typology, "length": spread(build.length), "depth": spread(build.depth), "bays": spread(build.bays), "crosses": build.crosses, "cross_at": spread(build.cross_at), "start": build.start, "notch": build.notch, "orders": build.orders.size(), "bands_alike": build.bands_alike}
	print("PLAN_METRICS capas de luz: como mucho %d de 16, pisos que llegan a 16: %d, choques %d" % [layers_most, layers_full, clashes])
	out["layers_most"] = layers_most
	out["layers_full"] = layers_full
	out["power_zones"] = spread(power_zones)
	out["power_ceiling"] = spread(power_ceiling)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/planta"))
	var file := FileAccess.open("res://evidence/planta/metricas%s.json" % ("" if survivors == 2 else "_s%d" % survivors), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(out, "\t"))
	quit()

## The building a seed came out on (generator.building, the try that came out).
static func measure_building(generator, data: Dictionary, build: Dictionary) -> void:
	var b: Dictionary = generator.building
	if b.is_empty(): return
	tally(build.typology, String(b.get("typology", "ring")))
	tally(build.start, String(b.get("start_kind", "")))
	if String(b.shape) == "notch": build.notch += 1
	# Planta 2 has no end bay for a reception: the building's own outline.
	var box := used_box(data, 1)
	build.length.append(snappedf(box.size.x, 0.1))
	build.depth.append(snappedf(box.size.y, 0.1))
	var bays := 0.0
	var order := ""
	var crosses: Array = []
	for column in b.columns:
		var role := String(column.role)
		if role in ["hall", "lift_a", "lift_b"]: bays += 1.0
		elif role in ["offices", "core_a", "core_b"]: bays += 0.5
		if role == "cross": crosses.append(float(column.centre))
		order += {"hall": "h", "offices": "o", "core_a": "c", "core_b": "c", "lift_a": "a", "lift_b": "b", "cross": "|", "end": ""}.get(role, "?")
	build.bays.append(bays)
	tally(build.crosses, crosses.size())
	var start := float(b.columns[0].centre) - float(b.columns[0].size) * 0.5
	var length := float(b.columns[-1].centre) + float(b.columns[-1].size) * 0.5 - start
	for i in range(1, crosses.size() - 1): build.cross_at.append(snappedf((float(crosses[i]) - start) / length, 0.01))
	build.orders[order] = true
	# The first planta's two bands, each the widths of its rooms along it.
	var bands := {}
	for room in data.rooms:
		if int(room.wing) != 0 or FLOOR.is_void(room) or bool(room.corridor): continue
		var role := String(b.rows[int(room.z)].role)
		if not role in ["front", "back"]: continue
		if not bands.has(role): bands[role] = {}
		var key := int(room.hall) if int(room.hall) >= 0 else int(room.id)
		bands[role][key] = int(bands[role].get(key, 0)) + 1
	var shapes: Array = ["front", "back"].map(func(role): return str(bands.get(role, {}).values()))
	if shapes[0] == shapes[1]: build.bands_alike += 1

## [min, p10, p50, p90, max] of a list of numbers.
static func spread(values: Array) -> Array:
	return [0.0, 0.1, 0.5, 0.9, 1.0].map(func(q): return snappedf(METRICS.quantile(values, q), 0.01))

static func tally(counts: Dictionary, key: Variant) -> void:
	counts[key] = int(counts.get(key, 0)) + 1

## The way from one point to another in eight sectors, the building's own
## proportions undone (0 east, counted towards +z).
static func sector(from: Vector2, to: Vector2, box: Rect2) -> int:
	var d := (to - from) * box.size
	return int(floor(fposmod(d.angle() + PI / 8.0, TAU) / (PI / 4.0))) % 8

## The used cells' box of a planta, in metres.
static func used_box(data: Dictionary, planta: int) -> Rect2:
	var low := Vector2(INF, INF)
	var high := -low
	for room in data.rooms:
		if int(room.wing) != planta or FLOOR.is_void(room): continue
		var half := Vector2(float(room.span_x), float(room.span_z)) * 0.5
		low = low.min(Vector2(float(room.px), float(room.pz)) - half)
		high = high.max(Vector2(float(room.px), float(room.pz)) + half)
	return Rect2(low, high - low)

## The shortest walk in metres from a room to another, as the rooms on it.
static func way(data: Dictionary, from: int, to: int) -> Array:
	var metres := {from: 0.0}
	var parent := {from: -1}
	var open: Array = [from]
	while not open.is_empty():
		var best := 0
		for index in open.size():
			if float(metres[open[index]]) < float(metres[open[best]]): best = index
		var at: int = open[best]
		open.remove_at(best)
		if at == to: break
		for other in data.adjacency[at]:
			var next := int(other)
			var length: float = float(metres[at]) + FLOOR.position_of(data.rooms[at]).distance_to(FLOOR.position_of(data.rooms[next]))
			if not metres.has(next) or length < float(metres[next]) - 0.001:
				if not metres.has(next): open.append(next)
				metres[next] = length
				parent[next] = at
	var path: Array = []
	var here := to
	while parent.has(here) and here >= 0:
		path.append(here)
		here = int(parent[here])
	return path
