extends SceneTree
## Floor 2 as step 1a leaves it (.claude/specs/spec_f1_generator.md 1.7;
## docs/OFICINAS.md 11.2 and 11.3): the office palette has every name the
## hotel's has and everything geometry and the systems ask of it, with the
## values of the design; the office kind has the hotel kind's shape and is
## built, not released; and ten floors of the minimal generator come out
## valid, of floor 2 and in the office's modules, without moving the hotel's.
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const HOTEL := preload("res://game/floors/palettes/hotel_palette.gd")
const KIND := preload("res://game/floors/office_floor.gd")
const HOTEL_KIND := preload("res://game/floors/hotel_floor.gd")
const FLOORS := preload("res://game/floors/floor_index.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GEN := preload("res://game/world/generation/office_generator.gd")
const OFFICE_VALIDATOR := preload("res://game/world/generation/office_validator.gd")
const HOTEL_GEN := preload("res://game/world/generation/map_generator.gd")
const CREATURE := preload("res://game/enemies/creature.gd")
## What geometry and the systems call of the palette (spec_f1_geometry.md
## 0.2, spec_f1_systems.md 0.2).
const CONTRACT := ["false_ceiling", "floor_finish", "wall_material", "lamp_of", "plaque", "stripe_color", "zone_label", "hide_kind", "always_lit", "ceiling_rect", "full_tiles", "troffers", "free_tiles", "tile_of", "tile_centre", "crawl_boxes", "shaft_box", "POWER", "STRIPES", "LETTERS", "TYPE_LETTERS", "PLENUM", "FURNITURE", "FURNITURE_TOP", "TILE", "MODULE_SET", "FUSE_ROOMS", "TUBE_Y", "STATION_Y", "AIR_UNIT", "HATCH", "STUB"]
## The rules run_score.meets() knows.
const RULES := ["won", "solo", "clean", "brave", "time_under", "team_out", "restarted", "mine", "unseen", "mvp", "grade", "versus_out", "hunter_won"]
## The office's furniture sets along the walls (spec_f1_geometry.md 9.5).
const SETS := ["office_open", "office_private", "mail", "copy", "break", "lockers", "store", "office_corridor"]
## The office's types, 0 to 25.
const TYPE_COUNT := 26
## Table 1.2, type by type on wing 0: the floor, the lamp and the walls.
const FINISHES_12 := ["terrazzo", "vinyl", "vinyl", "vinyl", "tile", "vinyl", "vinyl", "vinyl", "concrete", "terrazzo", "terrazzo", "vinyl", "concrete", "vinyl", "vinyl", "vinyl", "vinyl", "vinyl", "concrete", "terrazzo", "vinyl", "vinyl", "concrete", "concrete", "vinyl", "concrete"]
const LAMPS_12 := ["troffer", "troffer", "troffer", "troffer", "troffer", "pendant", "batten", "troffer", "batten", "troffer", "troffer", "troffer", "batten", "batten", "troffer", "troffer", "troffer", "troffer", "emergency", "troffer", "emergency", "troffer", "batten", "batten", "troffer", "batten"]
const WALLS_12 := ["office_paint", "office_paint", "office_paint", "office_paint", "block", "office_paint", "office_paint", "block", "block", "office_paint", "office_paint", "block", "block", "office_paint", "block", "office_paint", "office_paint", "office_paint", "block", "office_paint", "office_paint", "office_paint", "block", "block", "office_paint", "block"]
var checks: Array = []
var failed := 0
## What each seed of the minimal generator drew, for the evidence.
var seeds: Array = []

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	var began := Time.get_ticks_msec()
	palette_tables()
	palette_places()
	palette_lattice()
	palette_crawl()
	kind_checks()
	generator_checks()
	texts()
	var seconds := float(Time.get_ticks_msec() - began) / 1000.0
	var file := FileAccess.open("res://evidence/office_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"passed": failed == 0, "seconds": seconds, "checks": checks, "seeds": seeds}, "\t"))
	print("OFFICE_TEST_RESULT ", checks.size() - failed, "/", checks.size(), " in %.1f s" % seconds)
	quit(1 if failed > 0 else 0)

# --- Paleta ------------------------------------------------------------------

## Every name of the hotel's palette and of the contract; the tables and the
## questions against the design (spec 1.2).
func palette_tables() -> void:
	var office: Script = OFFICE
	var hotel: Script = HOTEL
	var constants := office.get_script_constant_map()
	var methods := {}
	for method in office.get_script_method_list(): methods[String(method.name)] = true
	var missing: Array = []
	for name in hotel.get_script_constant_map():
		if not constants.has(name): missing.append(name)
	for method in hotel.get_script_method_list():
		if not methods.has(String(method.name)): missing.append(String(method.name))
	check("La paleta de oficinas tiene todos los nombres de la del hotel", missing.is_empty(), str(missing))
	var absent: Array = CONTRACT.filter(func(name): return not constants.has(name) and not methods.has(name))
	check("Y todo lo que le piden la geometría y los sistemas", absent.is_empty(), str(absent))
	var sizes: Array = [OFFICE.TYPES.size(), OFFICE.NAMES.size(), OFFICE.ARTICLES.size(), OFFICE.RECIPES.size(), OFFICE.HEIGHTS.size(), OFFICE.MODULE_SET.size(), OFFICE.FINISH_BY_TYPE.size()]
	check("TYPES, NAMES, ARTICLES, RECIPES, HEIGHTS, MODULE_SET y FINISH_BY_TYPE tienen 26 entradas", sizes.all(func(size): return int(size) == TYPE_COUNT), str(sizes))
	check("Cada receta tiene sus cuatro rincones", OFFICE.RECIPES.all(func(recipe): return recipe.size() == 4))
	check("Los papeles estructurales tienen su número y su tipo", OFFICE.RECEPTION == 0 and OFFICE.LANDING == 9 and OFFICE.LOBBY == 10 and OFFICE.CORRIDOR == 11 and OFFICE.GALLERY == 12 and OFFICE.REFUGE == 19 and OFFICE.VOID == 20 and FLOOR.VOID == OFFICE.VOID and OFFICE.TYPES[OFFICE.LANDING] == "montacargas" and OFFICE.TYPES[OFFICE.REFUGE] == "vestibulo_montacargas")
	var heights_right: bool = is_equal_approx(OFFICE.height_of({"type": OFFICE.OFFICE}), 2.95) and is_equal_approx(OFFICE.height_of({"type": OFFICE.ELECTRICAL}), 2.95) and is_equal_approx(OFFICE.height_of({"type": OFFICE.BOARDROOM}), 3.25) and [OFFICE.GALLERY, OFFICE.AIR_ROOM, OFFICE.AIR_PLANT].all(func(type): return is_equal_approx(OFFICE.height_of({"type": type}), 4.4))
	check("Alturas: 2,95 el despacho y el cuarto eléctrico, 3,25 la sala de juntas, 4,4 el pasillo de servicio y las dos de climatización", heights_right)
	var open_ceilings: Array = []
	var unknown: Array = []
	var soft: Array = []
	var never_dark: Array = []
	var tallest := 0.0
	for type in TYPE_COUNT:
		if not OFFICE.false_ceiling({"type": type}): open_ceilings.append(type)
		else: tallest = maxf(tallest, OFFICE.height_of({"type": type}))
		if not OFFICE.may_be_dark({"type": type}): never_dark.append(type)
		var set_name := String(OFFICE.MODULE_SET.get(type, "?"))
		if not (set_name in SETS or set_name == ""): unknown.append("conjunto %d" % type)
		for wing in 3:
			var room := {"type": type, "wing": wing}
			if not OFFICE.floor_finish(room) in OFFICE.FINISHES or not OFFICE.wall_material(room) in OFFICE.WALLS or not OFFICE.lamp_of(room) in OFFICE.LAMPS: unknown.append("%d en la planta %d" % [type, wing])
			if not OFFICE.hard_floor(room): soft.append(Vector2i(type, wing))
	check("Sin falso techo solo el pasillo de servicio, la sala de climatización y la climatizadora", open_ceilings == [12, 22, 23], str(open_ceilings))
	check("Cada tipo en cada planta tiene suelo, paredes, lámpara y conjunto conocidos", unknown.is_empty(), str(unknown))
	var finishes: Array = range(TYPE_COUNT).map(func(type): return OFFICE.floor_finish({"type": type, "wing": 0}))
	check("El suelo de cada tipo es el de la tabla 1.2", finishes == FINISHES_12, str(finishes))
	var lamps: Array = range(TYPE_COUNT).map(func(type): return OFFICE.lamp_of({"type": type, "wing": 0}))
	check("La lámpara de cada tipo es la de la tabla 1.2", lamps == LAMPS_12, str(lamps))
	var walls: Array = range(TYPE_COUNT).map(func(type): return OFFICE.wall_material({"type": type, "wing": 0}))
	check("Las paredes de cada tipo son las de la tabla 1.2", walls == WALLS_12, str(walls))
	check("Moqueta solo en la planta 3, en juntas, dirección y secretaría", soft == [Vector2i(5, 2), Vector2i(16, 2), Vector2i(24, 2)], str(soft))
	check("Nunca a oscuras los vestíbulos, la ventanilla, el cuarto eléctrico, el vacío, seguridad y la climatización, y un salón puede estarlo", never_dark == [0, 9, 10, 17, 18, 19, 20, 21, 22, 23] and OFFICE.may_be_dark({"type": OFFICE.OPEN_OFFICE, "hall": 6, "id": 6}), str(never_dark))
	var plenum: Dictionary = OFFICE.PLENUM
	var duct_y := float(plenum.duct_y)
	var main := float(plenum.main)
	check("El conducto troncal y los ramales pasan 5 cm por encima del falso techo más alto", duct_y - float(plenum.duct[1]) / 2.0 >= tallest + 0.05 - 0.001 and duct_y - float(plenum.branch[1]) / 2.0 >= tallest + 0.05 - 0.001, "techo más alto %.2f" % tallest)
	check("El ducto principal deja 10 cm sobre el falso techo y 5 cm bajo el forjado", duct_y - main / 2.0 >= float(plenum.ceiling) + 0.1 - 0.001 and duct_y + main / 2.0 <= float(plenum.slab) - 0.05 + 0.001)
	check("Los tubos van entre el dintel de las puertas y el falso techo", OFFICE.TUBE_Y >= 2.65 and OFFICE.TUBE_Y <= float(plenum.ceiling) - 0.1 + 0.001)
	var lockers: Array = OFFICE.WARDROBES.keys()
	lockers.sort()
	check("Taquillas en aseos, almacén, correo, descanso y seguridad", lockers == [4, 8, 14, 15, 21], str(lockers))
	check("Ningún mueble suelto pasa de FURNITURE_TOP", OFFICE.FURNITURE.values().all(func(piece): return float(piece.height) < OFFICE.FURNITURE_TOP))
	check("Placas: P-114, S-322, M-215, y ninguna sin número", OFFICE.plaque({"type": OFFICE.OFFICE, "wing": 0, "number": 114}) == "P-114" and OFFICE.plaque({"type": OFFICE.SECURITY, "wing": 2, "number": 322}) == "S-322" and OFFICE.plaque({"type": OFFICE.ELECTRICAL, "wing": 1, "number": 215}) == "M-215" and OFFICE.plaque({"type": OFFICE.OFFICE, "wing": 0, "number": 0}) == "")
	check("Llevan número: no un pasillo, no lo de NO_NUMBER, y de un salón solo la sala que le da nombre", OFFICE.numbered({"type": OFFICE.OFFICE, "hall": -1, "id": 4}) and not OFFICE.numbered({"type": OFFICE.OFFICE, "hall": -1, "id": 4, "corridor": true}) and not OFFICE.numbered({"type": OFFICE.LANDING, "hall": -1, "id": 4}) and OFFICE.numbered({"type": OFFICE.OPEN_OFFICE, "hall": 7, "id": 7}) and not OFFICE.numbered({"type": OFFICE.OPEN_OFFICE, "hall": 7, "id": 8}))
	var sizes_same := true
	for survivors in range(0, 7):
		if OFFICE.area_for(survivors) != HOTEL.area_for(survivors) or OFFICE.areas_for(survivors) != HOTEL.areas_for(survivors): sizes_same = false
	for area in [0.5, 1.0, 1.2, 1.35]:
		if OFFICE.rooms_window(area) != HOTEL.rooms_window(area) or OFFICE.rings(area) != HOTEL.rings(area) or OFFICE.tv_rooms(area) != 0: sizes_same = false
	check("El tamaño del piso, sus ventanas y sus anillos son los del hotel, y no pide teles", sizes_same)
	check("Nada es doméstico, y uno se esconde en taquillas", range(TYPE_COUNT).all(func(type): return not OFFICE.domestic({"type": type})) and OFFICE.hide_kind({"type": OFFICE.TOILETS}) == "locker")
	check("Un manifiesto del piso 2 es de la paleta de oficinas; uno sin piso, del hotel", FLOOR.palette({"floor": 2}) == OFFICE and FLOOR.palette({}) == HOTEL)

## Off-limits, always lit, stripes and zone names, on a manifest written by
## hand: three wings, a void, the electrical room, the security post.
func palette_places() -> void:
	var rooms := [
		{"id": 0, "type": 0, "wing": 0, "sector": 0},
		{"id": 1, "type": 3, "wing": 0, "sector": 1},
		{"id": 2, "type": 20, "wing": 0, "sector": 0},
		{"id": 3, "type": 9, "wing": 1, "sector": 0},
		{"id": 4, "type": 10, "wing": 1, "sector": 0},
		{"id": 5, "type": 19, "wing": 1, "sector": 1},
		{"id": 6, "type": 18, "wing": 1, "sector": 1},
		{"id": 7, "type": 6, "wing": 1, "sector": 2},
		{"id": 8, "type": 9, "wing": 2, "sector": 0},
		{"id": 9, "type": 21, "wing": 2, "sector": 1},
		{"id": 10, "type": 16, "wing": 2, "sector": 2},
		{"id": 11, "type": 3, "wing": 0, "sector": 9},
	]
	var departments := [[{"sector": 0, "name": "ALTAS", "colour": 0}, {"sector": 1, "name": "NÓMINAS", "colour": 1}], [{"sector": 1, "name": "REGISTRO", "colour": 2}, {"sector": 2, "name": "ARCHIVO", "colour": 3}], [{"sector": 1, "name": "SEGURIDAD", "colour": 4}, {"sector": 2, "name": "DIRECCIÓN", "colour": 5}]]
	var circuits := [{"code": "R-2", "name": "ARCHIVO", "sector": 2}, {"code": "R-1", "name": "REGISTRO", "sector": 1}]
	var manifest := {"rooms": rooms, "departments": departments, "power": {"circuits": circuits}}
	check("Lo vedado: el montacargas y los dos vestíbulos, en orden", OFFICE.off_limits_rooms(manifest) == [3, 4, 5, 8], str(OFFICE.off_limits_rooms(manifest)))
	check("Personal, con corriente, siempre encendida menos el vacío", OFFICE.always_lit(manifest, 0) == [0, 1, 11], str(OFFICE.always_lit(manifest, 0)))
	check("Registro: lo vedado, nunca el cuarto eléctrico", OFFICE.always_lit(manifest, 1) == [3, 4, 5], str(OFFICE.always_lit(manifest, 1)))
	check("Dirección: lo vedado y el puesto de seguridad", OFFICE.always_lit(manifest, 2) == [8, 9], str(OFFICE.always_lit(manifest, 2)))
	var first: Color = OFFICE.stripe_color(manifest, rooms[0])
	var second: Color = OFFICE.stripe_color(manifest, rooms[1])
	check("Cada sector su franja, y gris donde no hay departamento", first == OFFICE.STRIPES[0] and second == OFFICE.STRIPES[1] and first != second and OFFICE.stripe_color(manifest, rooms[11]) == Color("6f6a5e"))
	check("En Registro, la zona es su circuito", OFFICE.zone_label(manifest, rooms[7]) == "R-2 ARCHIVO" and OFFICE.zone_label(manifest, rooms[5]) == "R-1 REGISTRO")
	check("En Personal y Dirección, su departamento", OFFICE.zone_label(manifest, rooms[1]) == "NÓMINAS" and OFFICE.zone_label(manifest, rooms[10]) == "DIRECCIÓN")
	check("Sin departamento ni circuito, nada", OFFICE.zone_label(manifest, rooms[11]) == "" and OFFICE.zone_label({}, rooms[7]) == "" and OFFICE.zone_label({}, rooms[1]) == "")

## The ceiling lattice on rooms off it and on it: troffers on whole tiles, in
## pairs along the long side, none twice, 3 x 3 in 8 m and 4 x 4 in 12 m, one
## line along a lane; free tiles whole, clear of the troffers and the walls;
## a room of battens with no troffers and free tiles.
func palette_lattice() -> void:
	var rooms: Array = []
	for at in [0.0, 0.37, 5.05]:
		for span in [8.0, 9.0, 10.0, 12.0]:
			rooms.append({"id": 0, "type": OFFICE.OFFICE, "wing": 0, "px": at, "pz": -at, "span_x": span, "span_z": span, "open_sides": []})
		rooms.append({"id": 0, "type": OFFICE.CORRIDOR, "wing": 0, "px": at, "pz": -at, "span_x": 2.4, "span_z": 10.0, "open_sides": ["north", "south"], "corridor": true})
	rooms.append({"id": 0, "type": OFFICE.OFFICE, "wing": 0, "px": 0.37, "pz": 0.37, "span_x": 8.0, "span_z": 8.0, "open_sides": ["east"]})
	var inside := true
	var pairs := true
	var once := true
	var clear := true
	var counts: Array = []
	for room in rooms:
		var tiles: Rect2i = OFFICE.full_tiles(room)
		var rect: Rect2 = OFFICE.ceiling_rect(room)
		var troffers: Array = OFFICE.troffers(room)
		var along_z: bool = rect.size.y > rect.size.x
		var used := {}
		var lines := {}
		for troffer in troffers:
			var first: Vector2i = troffer.tiles[0]
			var second: Vector2i = troffer.tiles[1]
			if not tiles.has_point(first) or not tiles.has_point(second): inside = false
			var step: Vector2i = Vector2i(0, 1) if along_z else Vector2i(1, 0)
			if bool(troffer.along_z) != along_z or second - first != step: pairs = false
			if used.has(first) or used.has(second): once = false
			used[first] = true
			used[second] = true
			var line: int = first.x if along_z else first.y
			lines[line] = true
		var label := "%s en %.2f" % [str(Vector2(float(room.span_x), float(room.span_z))), float(room.px)]
		if bool(room.get("corridor", false)):
			if lines.size() != 1 or troffers.size() != maxi(1, roundi(maxf(rect.size.x, rect.size.y) / OFFICE.TROFFER_PITCH)): counts.append(label)
		elif float(room.span_x) == 8.0 and troffers.size() != 9: counts.append(label)
		elif float(room.span_x) == 12.0 and troffers.size() != 16: counts.append(label)
		var centres: Array = troffers.map(func(troffer): return troffer.centre)
		var open: Array = room.open_sides
		for tile in OFFICE.free_tiles(room):
			var centre := Vector2((float(tile.x) + 0.5) * OFFICE.TILE, (float(tile.y) + 0.5) * OFFICE.TILE)
			if not tiles.has_point(tile) or used.has(tile) or centres.any(func(other): return centre.distance_to(other) < OFFICE.GRILLE_CLEAR - 0.0001): clear = false
			if bool(room.get("corridor", false)): continue
			if not open.has("west") and centre.x - rect.position.x < OFFICE.GRILLE_WALL - 0.0001: clear = false
			if not open.has("east") and rect.end.x - centre.x < OFFICE.GRILLE_WALL - 0.0001: clear = false
			if not open.has("north") and centre.y - rect.position.y < OFFICE.GRILLE_WALL - 0.0001: clear = false
			if not open.has("south") and rect.end.y - centre.y < OFFICE.GRILLE_WALL - 0.0001: clear = false
	check("Cada luminaria está sobre placas enteras", inside)
	check("Sus dos placas van juntas a lo largo del lado largo", pairs)
	check("Ninguna placa tiene dos luminarias", once)
	check("3 x 3 en 8 m, 4 x 4 en 12 m y una línea en un carril", counts.is_empty(), str(counts))
	check("Las placas libres son enteras y se apartan de las luminarias y de las paredes", clear)
	var archive := {"id": 0, "type": OFFICE.ARCHIVE, "wing": 1, "px": 0.37, "pz": 0.0, "span_x": 10.0, "span_z": 10.0, "open_sides": []}
	check("Un archivo, de regletas, no tiene luminarias y sí placas libres", OFFICE.troffers(archive).is_empty() and not OFFICE.free_tiles(archive).is_empty())
	check("tile_of() y tile_centre() van y vuelven", OFFICE.tile_of(OFFICE.tile_centre(Vector2i(3, -2), 1.0)) == Vector2i(3, -2) and OFFICE.tile_centre(Vector2i(3, -2), 1.0).is_equal_approx(Vector3(2.1, 1.0, -0.9)))

## The crawl spaces on a duct written by hand on planta 3: a run from the
## hatch to a bend, a run from the bend to the shaft's mouth, an edge of no
## length and a trunk that is not crawled; and the shaft beyond the mouth.
func palette_crawl() -> void:
	var main := float(OFFICE.PLENUM.main)
	var y := FLOOR.planta_y(2) + float(OFFICE.PLENUM.duct_y)
	var floor_y := y - main * 0.5
	var nodes := [[0.0, y, 0.0, 0, "hatch"], [6.0, y, 0.0, 1, "main"], [6.0, y, 8.0, 2, "shaft"], [6.0, y, 0.0, 1, "main"]]
	var edges := [[0, 1, 6.0, "main"], [1, 2, 8.0, "main"], [1, 3, 0.0, "main"], [0, 2, 10.0, "trunk"]]
	var manifest := {"plenum": OFFICE.PLENUM.duplicate(true), "ducts": {"nodes": nodes, "edges": edges, "exits": []}, "air": {"shaft": {"rect": [6.0, 9.1, 2.2, 2.2], "floor_y": floor_y}}}
	var boxes: Array = OFFICE.crawl_boxes(manifest)
	check("Una caja por tramo gateable con longitud: dos", boxes.size() == 2, str(boxes.size()))
	if boxes.size() != 2: return
	check("Cada caja tiene el suelo a py + duct_y - main / 2 y main de alto", boxes.all(func(box): return is_equal_approx(box.position.y, floor_y) and is_equal_approx(box.size.y, main)))
	check("El tramo de la escotilla empieza en ella y pasa main / 2 del codo", boxes[0].is_equal_approx(AABB(Vector3(0.0, floor_y, -main * 0.5), Vector3(6.0 + main * 0.5, main, main))), str(boxes[0]))
	check("El del pozo sale main / 2 antes del codo y acaba en la boca", boxes[1].is_equal_approx(AABB(Vector3(6.0 - main * 0.5, floor_y, -main * 0.5), Vector3(main, main, 8.0 + main * 0.5))), str(boxes[1]))
	check("En el codo se solapan main por main", boxes[0].intersection(boxes[1]).size.is_equal_approx(Vector3(main, main, main)))
	check("Preguntado otra vez por el mismo manifiesto, da lo mismo sin rehacerlo", is_same(OFFICE.crawl_boxes(manifest), OFFICE.crawl_boxes(manifest)))
	check("Sin conductos, ninguna caja", OFFICE.crawl_boxes({}).is_empty())
	check("El pozo: su planta desde floor_y, main de alto", OFFICE.shaft_box(manifest).is_equal_approx(AABB(Vector3(4.9, floor_y, 8.0), Vector3(2.2, main, 2.2))), str(OFFICE.shaft_box(manifest)))

# --- Tipo de piso ------------------------------------------------------------

## floor_index with floor 2 built and not released, and the office kind with
## everything the hotel kind has.
func kind_checks() -> void:
	check("floor_index: el piso 2 es el de oficinas, construido y sin publicar", FLOORS.kind(2) == KIND and FLOORS.built(2) and not FLOORS.released(2))
	check("Sin publicar no tiene título propio ni hitos", FLOORS.title(2) == "PISO 2" and FLOORS.milestones(2).is_empty())
	check("El hotel sigue publicado, con su título y sus 18 hitos", FLOORS.released(1) and FLOORS.title(1) == "PISO 1: EL HOTEL" and FLOORS.milestones(1).size() == 18 and FLOORS.milestones(1) == HOTEL_KIND.MILESTONES)
	check("Los pisos construidos son el 1 y el 2, cada uno con la versión de su generador", FLOORS.numbers() == [1, 2] and FLOORS.versions() == {1: FLOOR.VERSION, 2: OFFICE.VERSION}, str(FLOORS.versions()))
	check("Un número sin piso sigue siendo el hotel, sin título ni hitos", FLOORS.kind(7) == HOTEL_KIND and not FLOORS.built(7) and not FLOORS.released(7) and FLOORS.title(7) == "PISO 7" and FLOORS.milestones(7).is_empty())
	var kind: Script = KIND
	var hotel_kind: Script = HOTEL_KIND
	var own := kind.get_script_constant_map()
	var methods := {}
	for method in kind.get_script_method_list(): methods[String(method.name)] = true
	var missing: Array = []
	for name in hotel_kind.get_script_constant_map():
		if not own.has(name): missing.append(name)
	for method in hotel_kind.get_script_method_list():
		if not methods.has(String(method.name)): missing.append(String(method.name))
	check("El tipo de piso de oficinas tiene todo lo que tiene el del hotel", missing.is_empty(), str(missing))
	check("Es el piso 2, con su paleta, su generador y su validador, y sin objetivos todavía", KIND.NUMBER == 2 and KIND.PALETTE == OFFICE and KIND.GENERATOR == GEN and KIND.VALIDATOR == OFFICE_VALIDATOR and KIND.OBJECTIVES.is_empty())
	check("Tres etapas, una por planta", KIND.count() == FLOOR.PLANTAS)
	var stages_right := true
	for number in range(1, KIND.count() + 1):
		var stage: Dictionary = KIND.stage(number)
		for key in ["errand", "brief", "level", "department"]:
			if String(stage.get(key, "")).is_empty(): stages_right = false
		var errand := String(stage.get("errand", ""))
		if errand.length() > 24 or errand != errand.to_upper(): stages_right = false
	check("Cada etapa dice su encargo (en mayúsculas, 24 letras o menos), su aviso, su nivel y su departamento", stages_right)
	var ids := {}
	var rules_known := true
	for milestone in KIND.MILESTONES:
		ids[String(milestone.id)] = true
		if not String(milestone.rule[0]) in RULES: rules_known = false
	check("Sus hitos tienen ids distintos y reglas que run_score.meets() sabe", ids.size() == KIND.MILESTONES.size() and rules_known)
	var made = (load(KIND.CREATURE) as PackedScene).instantiate()
	check("Su criatura se carga y es una criatura del contrato", made != null and made is CREATURE)
	if made != null: made.free()
	check("Juega con la dificultad y las reglas del Lurker, y su generador es la versión 1", KIND.CREATURE_KEY == &"lurker" and KIND.GENERATOR_VERSION == 1)
	check("Sus etapas se llaman niveles; las del hotel, sectores", KIND.title_of(2) == "NIVEL 2" and HOTEL_KIND.title_of(2) == "SECTOR 2")

# --- Generador mínimo --------------------------------------------------------

## Ten floors of the office generator (the hotel's, with the office palette):
## none of last resort, valid for the office validator, of floor 2, every type
## one the base finish() draws from the office palette at its type's height,
## every cell in the office's sizes; and the hotel of the same seeds as it was
## before them.
func generator_checks() -> void:
	var hotel_before := {}
	for run_seed in range(1, 11): hotel_before[run_seed] = JSON.stringify(HOTEL_GEN.new().generate(run_seed, 2))
	## What map_generator.finish() can give a room with the office palette: a
	## hotel constant read without palette. gives 5, 6, 16, 17 or 18 instead.
	var drawable: Array = [OFFICE.RECEPTION, OFFICE.LANDING, OFFICE.LOBBY, OFFICE.CORRIDOR, OFFICE.GALLERY, OFFICE.REFUGE, OFFICE.VOID] + OFFICE.TIDY_ROOMS + OFFICE.UNRULY_ROOMS + OFFICE.SERVICE_ROOMS + OFFICE.HALL_ROOMS
	var fallen: Array = []
	var invalid: Array = []
	var unnamed: Array = []
	var other_palette: Array = []
	var strange_types: Array = []
	var foreign: Array = []
	var strange_sizes: Array = []
	for run_seed in range(1, 11):
		var generator = GEN.new()
		var manifest: Dictionary = generator.generate(run_seed, 2)
		if bool(manifest.get("fallback", true)): fallen.append(run_seed)
		var errors: Array = generator.validator().validate(manifest)
		if not errors.is_empty(): invalid.append("%d: %s" % [run_seed, str(errors)])
		if int(manifest.get("floor", 0)) != 2 or int(manifest.get("version", 0)) != OFFICE.VERSION: unnamed.append(run_seed)
		if FLOOR.palette(manifest) != OFFICE: other_palette.append(run_seed)
		var counted := 0
		for room in manifest.rooms:
			var room_type := int(room.type)
			if room_type < 0 or room_type >= TYPE_COUNT: strange_types.append("%d:%d" % [run_seed, int(room.id)])
			elif not room_type in drawable: foreign.append("%d:%d tipo %d" % [run_seed, int(room.id), room_type])
			elif room_type != OFFICE.VOID and not is_equal_approx(float(room.get("height", 0.0)), OFFICE.height_of(room)): foreign.append("%d:%d alto %.2f" % [run_seed, int(room.id), float(room.get("height", 0.0))])
			if room_type != OFFICE.VOID: counted += 1
			if not sizes_fit(room): strange_sizes.append("%d:%d" % [run_seed, int(room.id)])
		seeds.append({"seed": run_seed, "attempt": int(manifest.get("attempt", -1)), "plans": manifest.get("plans", []).map(func(plan): return String(plan.plan)), "rooms": counted})
	check("Diez semillas, ninguna de reserva", fallen.is_empty(), str(fallen))
	check("El validador de oficinas las da por buenas", invalid.is_empty(), str(invalid))
	check("Cada manifiesto dice que es del piso 2, versión 1", unnamed.is_empty(), str(unnamed))
	check("Y se lee con la paleta de oficinas", other_palette.is_empty(), str(other_palette))
	check("Todos los tipos son de oficina (0 a 25)", strange_types.is_empty(), str(strange_types))
	check("Cada sala es un tipo que el generador mínimo dibuja con la paleta de oficinas, a la altura de su tipo", foreign.is_empty(), str(foreign.slice(0, 10)))
	check("Módulos y carriles de las medidas de oficina", strange_sizes.is_empty(), str(strange_sizes.slice(0, 10)))
	var moved: Array = []
	for run_seed in range(1, 11):
		if JSON.stringify(HOTEL_GEN.new().generate(run_seed, 2)) != hotel_before[run_seed]: moved.append(run_seed)
	check("El hotel de esas semillas sale igual después de las oficinas", moved.is_empty(), str(moved))

## A cell's sides are the office's: a module's both from MODULE_SIZES, a
## crossing's both from LANE_WIDTHS, a lane's one from each.
static func sizes_fit(room: Dictionary) -> bool:
	var x := float(room.span_x)
	var z := float(room.span_z)
	match String(room.get("kind", "module")):
		"module": return among(x, OFFICE.MODULE_SIZES) and among(z, OFFICE.MODULE_SIZES)
		"cross": return among(x, OFFICE.LANE_WIDTHS) and among(z, OFFICE.LANE_WIDTHS)
	return (among(x, OFFICE.LANE_WIDTHS) and among(z, OFFICE.MODULE_SIZES)) or (among(x, OFFICE.MODULE_SIZES) and among(z, OFFICE.LANE_WIDTHS))

## Whether a length is one of these, within a millimetre (a lobby's span is
## carried down the plantas as the difference of two edges).
static func among(value: float, lengths: Array) -> bool:
	return lengths.any(func(length): return absf(float(length) - value) < 0.001)

## No middle dot or long dash in the office's texts (CLAUDE.md), looked for by
## their escapes so this file has neither.
func texts() -> void:
	var bad: Array = []
	for path in ["res://game/floors/palettes/office_palette.gd", "res://game/floors/office_floor.gd"]:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("\u00b7") or text.contains("\u2014"): bad.append(path.get_file())
	check("Ni punto medio ni guion largo en la paleta ni en el tipo de piso", bad.is_empty(), str(bad))
