extends SceneTree
## What the office generator promises, measured on its manifests and nothing
## built (spec_f1_generator.md 3.3; modelled on map_metrics.gd):
##   godot --headless --script tools/dev/office_metrics.gd -- 1000 [--survivors=N]
## Each measure with its threshold, PASS or FAIL; evidence/office_metrics.json
## (office_metrics_N.json for other sizes); exit 1 on any failure.
const GEN := preload("res://game/world/generation/office_generator.gd")
const VALIDATOR := preload("res://game/world/generation/office_validator.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const METRES := preload("res://game/world/generation/conduit_metres.gd")
## The keys floor_measures() gives for every floor (office_test checks them).
const MEASURES := ["rooms", "numbered", "refuge_share", "window_share", "electrical_share", "security_share", "walk_0", "area_0", "stations", "tube_min", "sectors_served", "sectors", "timer_cover", "archives_1", "aisle_min", "aisles_per_salon", "lockers", "main_length", "main_bends", "crossings", "duct_pieces", "rooms_with_exit", "ratio_min", "ratio_band", "loose", "express", "gaps", "gaps_wanted", "dark", "open_items", "boardrooms", "boardrooms_with_table", "glazed", "props"]

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

## Every per-floor number of the table in spec 3.3, per planta where it is one.
static func floor_measures(data: Dictionary) -> Dictionary:
	var rooms: Array = data.rooms
	var out := {}
	var count := [0, 0, 0]
	var numbered := [0, 0, 0]
	var dark := [0, 0, 0]
	var lockers := [0, 0, 0]
	var glazed := [0, 0, 0]
	var sectors := [{}, {}, {}]
	var props: Array = []
	var open_items: Array = []
	var boardrooms := 0
	var tables := 0
	for room in rooms:
		if int(room.type) == OFFICE.VOID: continue
		var w := int(room.wing)
		count[w] += 1
		if int(room.get("number", 0)) > 0: numbered[w] += 1
		if bool(room.get("dark", false)): dark[w] += 1
		lockers[w] += room.get("hides", []).size()
		glazed[w] += room.get("glazed", []).size()
		sectors[w][int(room.sector)] = true
		if not bool(room.corridor): props.append(room.props.size())
		if int(room.type) == OFFICE.OPEN_OFFICE: open_items.append(room.get("furniture", []).size())
		if int(room.type) == OFFICE.BOARDROOM:
			boardrooms += 1
			if room.get("furniture", []).any(func(it): return String(it.kind) == "meeting_table"): tables += 1
	out["rooms"] = count
	out["numbered"] = numbered
	out["dark"] = [0, 1, 2].map(func(w): return float(dark[w]) / maxf(1.0, float(count[w])))
	out["lockers"] = lockers
	out["glazed"] = glazed
	out["sectors"] = sectors.map(func(s): return s.size())
	out["props"] = quantile(props, 0.5)
	out["open_items"] = quantile(open_items, 0.5)
	out["boardrooms"] = boardrooms
	out["boardrooms_with_table"] = tables
	out["refuge_share"] = [0, 1, 2].map(func(p): return VALIDATOR.share_in(data, p, int(data.refuges[p])))
	for want in [["window_share", 0, OFFICE.WINDOW], ["electrical_share", 1, OFFICE.ELECTRICAL], ["security_share", 2, OFFICE.SECURITY]]:
		var found := VALIDATOR.of_type(data, int(want[1]), int(want[2]))
		out[want[0]] = VALIDATOR.share_in(data, int(want[1]), int(found[0].id)) if found.size() == 1 else -1.0
	out["walk_0"] = float(FLOOR.route_metres(data, int(data.entries[0])).get(int(data.refuges[0]), 0.0))
	out["area_0"] = float(data.areas[0])
	# The post.
	var stations: Array = data.tubes.exits.filter(func(e): return String(e.kind) == "station")
	out["stations"] = stations.size()
	out["tube_min"] = stations.reduce(func(a, e): return minf(a, float(e.tube)), INF)
	var served := {}
	for e in stations: served[int(rooms[int(e.room)].sector)] = true
	var planta0 := {}
	for room in rooms:
		if int(room.wing) == 0 and int(room.type) != OFFICE.VOID and not bool(room.corridor): planta0[int(room.sector)] = true
	out["sectors_served"] = planta0.keys().all(func(s): return served.has(s))
	# Power.
	var corridor := 0
	for room in rooms:
		if int(room.wing) == 1 and int(room.type) != OFFICE.VOID and bool(room.corridor): corridor += 1
	var covered := {}
	for t in data.power.timers:
		for id in t.rooms: covered[int(id)] = true
	out["timer_cover"] = float(covered.size()) / maxf(1.0, float(corridor))
	# Archives.
	var on_second := 0
	var aisle_min := INF
	var per_salon: Array = []
	for arch in data.archives:
		if int(rooms[int(arch.rooms[0])].wing) == 1: on_second += 1
		if arch.rooms.size() > 1: per_salon.append(arch.aisles.size())
		for aisle in arch.aisles:
			aisle_min = minf(aisle_min, float(aisle[2]) - float(aisle[0]) if String(arch.axis) == "x" else float(aisle[3]) - float(aisle[1]))
	out["archives_1"] = on_second
	out["aisle_min"] = aisle_min
	out["aisles_per_salon"] = quantile(per_salon, 0.5)
	# The main duct.
	var ducts: Dictionary = data.ducts
	out["main_length"] = float(data.air.main.length)
	out["main_bends"] = int(data.air.main.bends)
	out["crossings"] = ducts.edges.filter(func(e): return String(e[3]) == "cross").size()
	# The ducts.
	var by_wing := [[], [], []]
	var exits := [[], [], []]
	for i in ducts.nodes.size():
		var n: Array = ducts.nodes[i]
		if String(n[4]) in ["trunk", "branch", "stub"]: by_wing[int(rooms[int(n[3])].wing)].append(i)
	out["duct_pieces"] = [0, 1, 2].map(func(p): return METRES.pieces(ducts, by_wing[p], ["main", "cross", "drop"]))
	var has_exit := {}
	var gaps := [0, 0, 0]
	for e in ducts.exits:
		var w := int(rooms[int(e.room)].wing)
		if String(e.kind) == "gap": gaps[w] += 1
		elif String(e.kind) != "hatch":
			has_exit[int(e.room)] = true
			exits[w].append(e)
	var main_cells: Array = data.air.main.cells
	var want_exit := 0
	var got_exit := 0
	var eligible := [0, 0, 0]
	for room in rooms:
		if int(room.type) == OFFICE.VOID or OFFICE.off_limits(room): continue
		if OFFICE.false_ceiling(room): eligible[int(room.wing)] += 1
		if bool(room.corridor) or (int(room.wing) == 2 and main_cells.has(int(room.id)) and not OFFICE.false_ceiling(room)): continue
		want_exit += 1
		if has_exit.has(int(room.id)): got_exit += 1
	out["rooms_with_exit"] = float(got_exit) / maxf(1.0, float(want_exit))
	out["express"] = [0, 1, 2].map(func(p): return ducts.edges.filter(func(e): return String(e[3]) == "express" and int(rooms[int(ducts.nodes[int(e[0])][3])].wing) == p).size())
	out["gaps"] = gaps
	out["gaps_wanted"] = [0, 1, 2].map(func(p): return roundi(float(OFFICE.GAP_SHARE[p]) * float(eligible[p])))
	out["loose"] = [0, 1, 2].map(func(p): return ducts.edges.filter(func(e): return String(e[3]) == "loose" and int(rooms[int(ducts.nodes[int(e[0])][3])].wing) == p).size())
	# Shortcuts: 40 drawn pairs of exits a planta that walk 12 m or more apart,
	# duct metres from cell node to cell node (no crawl duct, no drops: the way
	# from a grille to its room's middle is walked in the room either way) over
	# walking metres door to door from the middle of one room to the other's.
	var cell_node := {}
	for i in ducts.nodes.size():
		if String(ducts.nodes[i][4]) in ["trunk", "branch"]: cell_node[int(ducts.nodes[i][3])] = i
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(data.seed), "office_metrics"])
	var ratios: Array = []
	for p in 3:
		var pool: Array = exits[p]
		if pool.size() < 2: continue
		for k in 40:
			var a: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
			var b: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
			if int(a.room) == int(b.room): continue
			var walk := METRES.door_metres(rooms, data.adjacency, int(a.room), int(b.room))
			if walk < 12.0 or walk == INF: continue
			if not cell_node.has(int(a.room)) or not cell_node.has(int(b.room)): continue
			var duct := float(METRES.metres(ducts, int(cell_node[int(a.room)]), INF, ["main", "cross", "drop"]).get(int(cell_node[int(b.room)]), INF))
			ratios.append(duct / walk)
	out["ratio_min"] = ratios.reduce(func(m, r): return minf(m, r), INF)
	out["ratio_band"] = float(ratios.filter(func(r): return r >= 0.55 and r <= 0.9).size()) / maxf(1.0, float(ratios.size()))
	out["ratio_median"] = quantile(ratios, 0.5)
	return out

func _initialize() -> void:
	var floors := 1000
	var survivors := 2
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int(): floors = int(argument)
		elif argument.begins_with("--survivors="): survivors = int(argument.get_slice("=", 1))
	var fallen := 0
	var rejected := 0
	var redraws := {}
	var times: Array = []
	var all: Array = []
	var areas: Array = []
	for run_seed in range(1, floors + 1):
		var generator = GEN.new()
		var began := Time.get_ticks_usec()
		var data: Dictionary = generator.generate(run_seed, survivors)
		times.append(float(Time.get_ticks_usec() - began) / 1000.0)
		for key in generator.stats: redraws[key] = int(redraws.get(key, 0)) + int(generator.stats[key])
		if data.is_empty() or bool(data.get("fallback", false)):
			fallen += 1
			continue
		if not VALIDATOR.new().validate(data).is_empty(): rejected += 1
		areas.append(float(data.area))
		all.append(floor_measures(data))
	var made := all.size()
	var each := func(key: String) -> Array: return all.map(func(m): return m[key])
	var per := func(key: String, p: int) -> Array: return all.map(func(m): return m[key][p])
	judge("Pisos de respaldo", float(fallen) / float(floors), float(fallen) / float(floors) < 0.005, "< 0,5 %")
	judge("Pisos que el validador rechaza", rejected, rejected == 0, "0")
	judge("Plantas sorteadas otra vez (por motivo)", redraws, true, "informativo")
	for p in 3:
		var shares: Array = per.call("refuge_share", p)
		var band: Vector2 = OFFICE.DEPTHS[p]
		judge("Refugio de la planta %d, mín/máx" % p, [snappedf(quantile(shares, 0.0), 0.01), snappedf(quantile(shares, 1.0), 0.01)], quantile(shares, 0.0) >= band.x - 0.01 and quantile(shares, 1.0) <= band.y + 0.01, "dentro de %s" % str(band))
		judge("Numeradas de más en la planta %d" % p, (per.call("numbered", p) as Array).filter(func(n): return int(n) > OFFICE.NUMBERED_MOST).size(), (per.call("numbered", p) as Array).all(func(n): return int(n) <= OFFICE.NUMBERED_MOST), "0")
		var secs: Array = per.call("sectors", p)
		judge("Sectores de la planta %d, mín/máx" % p, [quantile(secs, 0.0), quantile(secs, 1.0)], quantile(secs, 0.0) >= 5 and quantile(secs, 1.0) <= 7, "5 a 7")
		judge("Taquillas de la planta %d, p5" % p, quantile(per.call("lockers", p), 0.05), quantile(per.call("lockers", p), 0.05) >= 8.0 * quantile(areas, 0.05), ">= 8 × área")
		judge("Una pieza de conducto en la planta %d" % p, (per.call("duct_pieces", p) as Array).all(func(n): return int(n) == 1), (per.call("duct_pieces", p) as Array).all(func(n): return int(n) == 1), "100 %")
		judge("Enlaces sueltos en la planta %d, mediana" % p, quantile(per.call("loose", p), 0.5), true, "informativo")
		judge("Troncos rectos en la planta %d, mediana" % p, quantile(per.call("express", p), 0.5), true, "informativo")
		var gaps_ok: bool = all.all(func(m): return int(m.gaps[p]) == int(m.gaps_wanted[p]))
		judge("Huecos de la planta %d según GAP_SHARE" % p, gaps_ok, gaps_ok, "todos")
		judge("Salas a oscuras en la planta %d, media" % p, snappedf((per.call("dark", p) as Array).reduce(func(a, b): return a + b, 0.0) / maxf(1.0, float(made)), 0.01), true, "hacia 0,23, 0,29, 0,36 (informativo)")
		judge("Lados de cristal en la planta %d, mediana" % p, quantile(per.call("glazed", p), 0.5), true, "informativo")
	var walks_ok: bool = all.all(func(m): return float(m.walk_0) >= 110.0 * sqrt(float(m.area_0)) - 0.5)
	judge("Paseo al montacargas de la planta 0", snappedf(quantile(each.call("walk_0"), 0.0), 0.1), walks_ok, ">= 110 × raíz del área")
	for want in [["window_share", OFFICE.WINDOW_DEPTH, "Ventanilla"], ["electrical_share", OFFICE.ELECTRICAL_DEPTH, "Cuarto eléctrico"], ["security_share", OFFICE.SECURITY_DEPTH, "Seguridad"]]:
		var shares: Array = each.call(want[0])
		var band: Vector2 = want[1]
		judge("%s, mín/máx" % String(want[2]), [snappedf(quantile(shares, 0.0), 0.01), snappedf(quantile(shares, 1.0), 0.01)], quantile(shares, 0.0) >= band.x - 0.01 and quantile(shares, 1.0) <= band.y + 0.01, "dentro de %s" % str(band))
	var stations: Array = each.call("stations")
	judge("Estaciones por piso, mín/máx", [quantile(stations, 0.0), quantile(stations, 1.0)], quantile(stations, 0.0) >= OFFICE.STATIONS.x and quantile(stations, 1.0) <= OFFICE.STATIONS.y, "8 a 14")
	judge("Metros de tubo a una estación, p5", snappedf(quantile(each.call("tube_min"), 0.05), 0.1), quantile(each.call("tube_min"), 0.05) >= OFFICE.STATION_TUBE_MIN, ">= 25")
	var served := float((each.call("sectors_served") as Array).count(true)) / maxf(1.0, float(made))
	judge("Pisos con estación en cada sector de la planta 0", snappedf(served, 0.001), served >= 0.95, ">= 95 %")
	judge("Minuteros sobre el pasillo de la planta 1, p5", snappedf(quantile(each.call("timer_cover"), 0.05), 0.01), quantile(each.call("timer_cover"), 0.05) >= OFFICE.TIMER_COVER, ">= 0,5")
	judge("Archivos en la planta 1, p5", quantile(each.call("archives_1"), 0.05), quantile(each.call("archives_1"), 0.05) >= 2, ">= 2")
	judge("Pasillos por salón de archivo, mediana", quantile(each.call("aisles_per_salon"), 0.5), true, "informativo")
	judge("Pasillo de archivo más estrecho", snappedf(quantile(each.call("aisle_min"), 0.0), 0.001), quantile(each.call("aisle_min"), 0.0) >= 0.95 - 0.001, ">= 0,95")
	var lengths: Array = each.call("main_length")
	judge("Conducto principal, mín/máx", [snappedf(quantile(lengths, 0.0), 0.1), snappedf(quantile(lengths, 1.0), 0.1)], quantile(lengths, 0.0) >= OFFICE.MAIN_LENGTH.x and quantile(lengths, 1.0) <= OFFICE.MAIN_LENGTH.y, "25 a 45")
	judge("Codos del principal, mín", quantile(each.call("main_bends"), 0.0), quantile(each.call("main_bends"), 0.0) >= OFFICE.MAIN_BENDS, ">= 2")
	judge("Cruces del principal", (each.call("crossings") as Array).all(func(n): return int(n) == 1), (each.call("crossings") as Array).all(func(n): return int(n) == 1), "uno en cada piso")
	judge("Salas con salida de conducto", snappedf(quantile(each.call("rooms_with_exit"), 0.0), 0.001), quantile(each.call("rooms_with_exit"), 0.0) >= 1.0, "100 %")
	judge("Atajo de conducto más corto (puerta a puerta)", snappedf(quantile(each.call("ratio_min"), 0.0), 0.001), quantile(each.call("ratio_min"), 0.0) >= 0.55, ">= 0,55")
	judge("Razón conducto / paseo de los pares, mediana", snappedf(quantile(each.call("ratio_median"), 0.5), 0.01), true, "informativo")
	judge("Pares con atajo entre 0,55 y 0,9, mediana", snappedf(quantile(each.call("ratio_band"), 0.5), 0.001), quantile(each.call("ratio_band"), 0.5) >= 0.10, ">= 0,10")
	judge("Muebles por celda de oficina abierta, mediana", quantile(each.call("open_items"), 0.5), quantile(each.call("open_items"), 0.5) >= 2.0, ">= 2")
	var boards := float((each.call("boardrooms_with_table") as Array).reduce(func(a, b): return a + b, 0)) / maxf(1.0, float((each.call("boardrooms") as Array).reduce(func(a, b): return a + b, 0)))
	judge("Salas de juntas con mesa", snappedf(boards, 0.001), boards >= 0.8, ">= 80 %")
	judge("Props de esquina por sala, mediana", quantile(each.call("props"), 0.5), true, "informativo")
	var area_most := quantile(areas, 1.0)
	judge("Generación p50 (ms)", snappedf(quantile(times, 0.5), 1.0), quantile(times, 0.5) <= 2000.0, "<= 2000, solo (decisión del autor)")
	judge("Generación p99 (ms)", snappedf(quantile(times, 0.99), 1.0), quantile(times, 0.99) <= 700.0 * maxf(1.0, area_most * area_most), "<= 700 × máx(1, área²)")
	var out_name := "office_metrics.json" if floors == 1000 and survivors == 2 else "office_metrics_%d%s.json" % [floors, "" if survivors == 2 else "_s%d" % survivors]
	var file := FileAccess.open("res://evidence/" + out_name, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"floors": floors, "survivors": survivors, "results": results}, "\t"))
	print("OFFICE_METRICS %s %d/%d" % ["PASS" if failed == 0 else "FAIL", results.size() - failed, results.size()])
	quit(0 if failed == 0 else 1)
