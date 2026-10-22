extends SceneTree
## No room type is a bare number outside the palettes (docs/OFICINAS.md 11.2):
## the game and its tools ask game/floors/palettes/ what a room is, so a floor
## of another kind is never read as the hotel by a list written somewhere
## else. A text scan of every script under game/ and tools/ with its comments
## left out, the patterns tried first on lines they must and must not catch,
## and the hotel's palette checked against floor 1 as it was before step 0d.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const HOTEL := preload("res://game/floors/palettes/hotel_palette.gd")
const KIND := preload("res://game/floors/hotel_floor.gd")
const GEN := preload("res://game/world/generation/map_generator.gd")
const VALIDATOR := preload("res://game/world/generation/map_validator.gd")
const ROOTS := ["res://game", "res://tools"]
const PALETTES := "res://game/floors/palettes"
## What each pattern catches, by the name a failure gives it. A role is
## compared by its name read through a palette or FLOOR (palette.REFUGE,
## FLOOR.VOID), never by its number nor by a constant of the script's own;
## a bare VOID is let through, since it is the role floor_definition.gd
## keeps (is_void()). A table of types is read through a palette (palette.X,
## builder.palette.X, FLOOR.palette(manifest).X), never from a constant of
## the script's own. Written without backslashes, so each reads as it is.
const PATTERNS := {
	"tipo comparado con un número": '[A-Za-z0-9_]*type(?![A-Za-z0-9_])(?:" *, *-?[0-9]+)?[)]* *(?:==|!=|<=|>=|<|>) *-?[0-9]',
	"número comparado con un tipo": '[0-9] *(?:==|!=) *(?:int[(] *)?[A-Za-z0-9_.]*(?<![A-Za-z0-9_])type(?![A-Za-z0-9_])',
	"tipo en una lista de números": '[A-Za-z0-9_]*type(?![A-Za-z0-9_])(?:" *, *-?[0-9]+)?[)]* +(?:not +)?in *[[] *-?[0-9]',
	"tipo en una tabla propia": '[A-Za-z0-9_]*type(?![A-Za-z0-9_])(?:" *, *-?[0-9]+)?[)]* +(?:not +)?in +[A-Z][A-Z0-9_]*(?![A-Za-z0-9_])(?![.]palette[(])',
	"tabla propia preguntada por un tipo": '(?<![A-Za-z0-9_.])[A-Z][A-Z0-9_]*(?:[.][A-Z][A-Z0-9_]*)? *[.]has[(][^)]*(?<![A-Za-z0-9_])type(?![A-Za-z0-9_])',
	"tabla propia leída por tipo": '(?<![A-Za-z0-9_.])[A-Z][A-Z0-9_]*(?:[.][A-Z][A-Z0-9_]*)?(?:[[]|[.]get[(]) *(?:int[(] *)?[A-Za-z0-9_.]*(?:[.]type(?![A-Za-z0-9_])|[.]get[(]"type")',
	"tipo comparado con una constante propia": '[A-Za-z0-9_]*type(?![A-Za-z0-9_])(?:" *, *-?[0-9]+)?[)]* *(?:==|!=) *(?!VOID(?![A-Za-z0-9_]))[A-Z][A-Z0-9_]*(?![A-Za-z0-9_.(])',
}
## Lines the patterns must catch, and lines they must leave alone.
const CAUGHT := [
	'if room.type == 19:',
	'int(room.get("type", 0)) != 20',
	'if 19 == room.type: pass',
	'var hard := int(room.type) in [4, 7, 9]',
	'if not int(room.type) in [11, 12]: continue',
	'int(room.type) in FLOOR.HARD_FLOORS',
	'var service: bool = builder.building_type in SERVICE',
	'if DOMESTIC.has(int(room.get("type", -1))): pass',
	'String(FLOOR.NAMES[int(room.type)])',
	'var set_name: String = MODULE_SET.get(int(room.type), "")',
	'if int(room.type) == CORRIDOR and lit(room): return room',
]
const SPARED := [
	'if int(room.type) == palette.REFUGE: pass',
	'var hard: bool = int(room.type) in palette.HARD_FLOORS',
	'return int(room.get("type", -1)) in FLOOR.palette({}).CIRCULATION',
	'node.name = "Room_%d_%s" % [room.id, palette.TYPES[room.type]]',
	'if FLOOR.is_void(room): continue',
	'room.type = palette.VOID',
	'var options: Array = SOUNDS[type]',
	'if room.hall >= 0: pass',
	'if builder.building_type in builder.palette.SERVICE: pass',
	'return int(room.get("type", 0)) == VOID',
	'if int(room.type) == FLOOR.VOID: pass',
]
## Scripts left out on purpose, by path, and why. None.
const EXCEPTIONS := {}
## The declarations that went to the palette, by the script they left.
const GONE := {
	"res://game/world/generation/floor_definition.gd": ["AREA", "ROOMS", "NUMBERED_MOST", "WARDROBES", "HARD_FLOORS", "TYPES", "NAMES", "RECIPES"],
	"res://game/world/generation/map_generator.gd": ["NO_NUMBER", "TIDY_ROOMS", "UNRULY_ROOMS", "SERVICE_ROOMS", "HALL_ROOMS", "RECEPTION", "LANDING", "LOBBY", "CORRIDOR", "GALLERY", "TV_ROOM", "REFUGE", "VOID", "MODULE_SIZES", "LANE_WIDTHS", "DECKS", "SERVED", "APART", "ORDER_BASE", "DEPTH", "FIRST_DEPTH", "FIRST_WALK", "HALLS", "ROOM_DOORS", "EXPOSED", "EXPOSED_CHANCE", "SECOND_EXPOSED", "EXPOSED_LONGEST", "DOOR_PLACES", "DOOR_PLACES_DOMESTIC", "DOMESTIC", "DARK_OWN", "DARK_SPREAD", "DARK_CORRIDOR", "WEAR", "KEPT", "EMPTY_SALON"],
	"res://game/world/hotel/hotel_geometry.gd": ["SERVICE_CEILINGS", "DECREPIT_WALLS", "SPRINKLER_ROOMS", "SCONCE_ROOMS", "CHANDELIER_HEIGHT"],
	"res://game/world/hotel/room_dressing.gd": ["DOMESTIC", "MODULE_SET", "ALARM_ROOMS", "FUSE_ROOMS", "FAN_ROOMS", "CLOCK_ROOMS"],
	"res://game/world/hotel/prop_factory.gd": ["SERVICE"],
	"res://game/world/generation/hint_placement.gd": ["THE"],
	"res://game/world/generation/exit_route_signs.gd": ["CIRCULATION"],
}
## The functions that went to the palette from floor_definition.gd.
const GONE_FUNCS := ["area_for", "areas_for", "rooms_window", "tv_rooms", "rings", "may_be_dark"]
## The scripts step 0d changed outside tests/ (but for two whose only change
## is a comment): each still compiles.
const TOUCHED := ["res://game/floors/palettes/hotel_palette.gd", "res://game/world/generation/floor_definition.gd", "res://game/floors/hotel_floor.gd", "res://game/world/generation/map_generator.gd", "res://game/world/generation/map_validator.gd", "res://game/app/hotel_main.gd", "res://game/world/hotel/hotel_geometry.gd", "res://game/world/hotel/room_dressing.gd", "res://game/world/hotel/prop_factory.gd", "res://game/audio/world_audio.gd", "res://game/app/blood.gd", "res://game/app/interaction.gd", "res://game/net/remote_player.gd", "res://game/app/code_lock.gd", "res://game/world/generation/hint_placement.gd", "res://game/world/generation/exit_route_signs.gd", "res://tools/bots/bot_body.gd", "res://tools/bots/bot_match.gd", "res://tools/dev/map_metrics.gd", "res://tools/dev/echo_rehearsal.gd", "res://tools/dev/blood_look.gd", "res://tools/dev/zfight_scan.gd", "res://tools/dev/map_plan.gd", "res://tools/dev/echo_probe.gd", "res://tools/dev/wood_look.gd", "res://tools/audio/measure_spatial.gd", "res://tools/audio/measure_steps.gd", "res://tools/capture/catalog_capture.gd", "res://tools/capture/doors_capture.gd", "res://tools/capture/darkness_capture.gd", "res://tools/capture/echo_capture.gd", "res://tools/capture/lookdev_capture.gd", "res://tools/capture/lurker_capture.gd", "res://tools/capture/props_capture.gd", "res://tools/capture/rooms_capture.gd", "res://tools/capture/torch_capture.gd", "res://tools/editor/build_gallery.gd"]
## The hotel's tables as floor 1 had them before step 0d (copied from where
## they were), and the new ones as written.
const BEFORE := {
	"AREA": {1: 0.5, 4: 1.2, 5: 1.35},
	"ROOMS": Vector2i(81, 99),
	"NUMBERED_MOST": 96,
	"WARDROBES": {1: 2, 2: 2, 3: 2, 16: 2, 13: 1, 14: 1, 15: 1, 8: 1},
	"HARD_FLOORS": [4, 7, 9],
	"TYPES": ["recepcion", "habitacion_doble", "habitacion_simple", "suite", "bano", "salon", "comedor", "lavanderia", "almacen", "mantenimiento", "vestibulo", "pasillo", "galeria", "sala_lectura", "sala_tv", "oficina", "guardarropa", "sala_plantas", "salon_vacio", "refugio", "vacio"],
	"NAMES": ["Recepción", "Habitación doble", "Habitación", "Suite", "Baños", "Salón", "Comedor", "Lavandería", "Almacén", "Mantenimiento", "Vestíbulo", "Pasillo", "Galería", "Sala de lectura", "Sala de televisión", "Oficina", "Guardarropa", "Jardín interior", "Salón vacío", "Refugio", "Vacío"],
	"RECIPES": [
		["reception", "sofa", "plant", "luggage"],
		["bed", "bed", "wardrobe", "desk"],
		["bed", "nightstand", "desk", "curtain"],
		["bed", "sofa", "tv", "phone"],
		["basin", "basin", "shelf", "bin"],
		["sofa", "sofa", "lamp", "plant"],
		["table", "table", "table", "shelf"],
		["washer", "washer", "cart", "shelf"],
		["shelf", "luggage", "shelf", "cart"],
		["shelf", "cart", "desk", "bin"],
		["sofa", "lamp", "plant", "luggage"],
		["plant", "bin", "lamp", "luggage"],
		["sofa", "lamp", "plant", "curtain"],
		["shelf", "desk", "sofa", "lamp"],
		["tv", "sofa", "sofa", "phone"],
		["desk", "phone", "shelf", "bin"],
		["wardrobe", "wardrobe", "luggage", "sofa"],
		["plant", "plant", "sofa", "lamp"],
		["curtain", "lamp", "bin", "sofa"],
		["sofa", "lamp", "phone", "plant"],
		[]
	],
	"NO_NUMBER": [0, 7, 8, 9, 10, 11, 12, 15, 19, 20],
	"TIDY_ROOMS": [1, 1, 2, 2, 2, 3, 4, 16],
	"UNRULY_ROOMS": [2, 3, 4, 5, 6, 13, 14, 16, 17, 18],
	"SERVICE_ROOMS": [7, 8, 9, 15],
	"HALL_ROOMS": [5, 6, 17, 18],
	"RECEPTION": 0,
	"LANDING": 9,
	"LOBBY": 10,
	"CORRIDOR": 11,
	"GALLERY": 12,
	"TV_ROOM": 14,
	"REFUGE": 19,
	"MODULE_SIZES": [12.0, 12.0, 13.0, 13.0, 14.0, 15.0, 16.0],
	"LANE_WIDTHS": [3.0, 3.5, 3.5, 4.0],
	"DECKS": [["spine", "twin", "ring", "comb", "arms"], ["spine", "twin", "blocks", "arms", "rot", "warren"], ["blocks", "warren", "rot", "comb", "ring"]],
	"SERVED": {"spine": 0.4, "twin": 0.45, "ring": 0.45, "comb": 0.55, "blocks": 0.6, "arms": 0.4, "warren": 0.0, "rot": 0.35},
	"APART": {"blocks": "rot", "rot": "blocks"},
	"ORDER_BASE": [0.8, 0.6, 0.42],
	"DEPTH": Vector2(0.55, 0.9),
	"FIRST_DEPTH": Vector2(0.65, 0.9),
	"FIRST_WALK": 150.0,
	"HALLS": Vector2i(2, 6),
	"ROOM_DOORS": {"warren": 1.8, "rot": 1.25},
	"EXPOSED": [0.0, 30.0, 50.0],
	"EXPOSED_CHANCE": [0.0, 0.5, 1.0],
	"SECOND_EXPOSED": 35.0,
	"EXPOSED_LONGEST": 90.0,
	"DOOR_PLACES": [0.0, 0.0, 1.5, -1.5, 2.0, -2.0],
	"DOOR_PLACES_DOMESTIC": [0.0, 1.5, -1.5],
	"DOMESTIC": [1, 2, 3, 4, 7, 15, 16],
	"DARK_OWN": [0.23, 0.29, 0.36],
	"DARK_SPREAD": 0.45,
	"DARK_CORRIDOR": Vector2(0.03, 0.05),
	"WEAR": 0.25,
	"KEPT": Vector2(0.25, 0.55),
	"EMPTY_SALON": 18,
	"SERVICE_CEILINGS": [7, 8, 9, 15],
	"DECREPIT_WALLS": [8, 18],
	"SPRINKLER_ROOMS": [0, 5, 6, 10, 11, 12, 13, 14],
	"SCONCE_ROOMS": [0, 10, 11, 12],
	"CHANDELIER_HEIGHT": 4.0,
	"MODULE_SET": {0: "lounge", 1: "bedroom", 2: "bedroom", 3: "bedroom", 4: "bath", 5: "lounge", 6: "dining", 7: "laundry", 8: "service", 9: "service", 10: "lounge", 11: "corridor", 12: "corridor", 13: "reading", 14: "lounge", 15: "office", 16: "wardrobe", 17: "garden", 18: "empty"},
	"ALARM_ROOMS": [0, 10, 11, 12],
	"FUSE_ROOMS": [7, 8, 9, 15],
	"FAN_ROOMS": [6, 13, 15],
	"CLOCK_ROOMS": [1, 2, 3, 5, 6, 13, 14],
	"SERVICE": [7, 8, 9, 16],
	"ARTICLES": ["la", "la", "la", "la", "los", "el", "el", "la", "el", "el", "el", "el", "la", "la", "la", "la", "el", "el", "el", "el", "el"],
	"CIRCULATION": [0, 9, 10, 12],
	"VOID": 20,
	"NEVER_DARK": [0, 4, 7, 8, 9, 10, 19, 20],
	"HEIGHTS": [4.2, 3.15, 3.15, 3.15, 3.15, 4.2, 4.2, 3.15, 3.15, 3.15, 3.15, 3.15, 3.15, 3.15, 3.15, 3.15, 3.15, 4.2, 4.2, 3.15, 3.15],
	"HALL_HEIGHT": 4.8,
	"BATTEN_ROOMS": [4, 7, 8, 9],
	"PUBLIC_ROOMS": [0, 10, 11, 12],
	"SMEAR_ROOMS": [4, 7, 8, 9],
	"WALL_KINDS": ["bed", "sofa", "desk", "tv", "reception", "washer", "basin", "shelf"],
}

var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

## A script's code without its comments (a # inside a string stays).
static func code_of(path: String) -> String:
	var kept: PackedStringArray = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var quoted := false
		var cut := line.length()
		for i in line.length():
			if line[i] == "\"": quoted = not quoted
			elif line[i] == "#" and not quoted:
				cut = i
				break
		kept.append(line.substr(0, cut))
	return "\n".join(kept)

## Every script under a folder and its subfolders, the palettes' left out.
static func scripts(folder: String, into: Array) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"): into.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		var path := folder.path_join(sub)
		if path != PALETTES: scripts(path, into)

func run() -> void:
	var began := Time.get_ticks_msec()
	scan()
	moved()
	questions()
	routes()
	var seconds := float(Time.get_ticks_msec() - began) / 1000.0
	var file := FileAccess.open("res://evidence/palette_scan_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"passed": failed == 0, "seconds": seconds, "checks": checks}, "\t"))
	print("PALETTE_SCAN_RESULT ", checks.size() - failed, "/", checks.size(), " in %.1f s" % seconds)
	quit(1 if failed > 0 else 0)

## The scan, and what left the scripts it was in.
func scan() -> void:
	var regexes := {}
	for name in PATTERNS: regexes[name] = RegEx.create_from_string(PATTERNS[name])
	# The patterns first: a scan that catches nothing proves nothing.
	for line in CAUGHT: check("El barrido coge: %s" % line, regexes.values().any(func(regex): return regex.search(line) != null))
	for line in SPARED: check("El barrido deja: %s" % line, regexes.values().all(func(regex): return regex.search(line) == null))
	var files: Array = []
	for root in ROOTS: scripts(root, files)
	check("Hay scripts que barrer en game y tools", files.size() > 100, "%d" % files.size())
	var hits: Array = []
	for path in files:
		if EXCEPTIONS.has(path): continue
		var lines := code_of(path).split("\n")
		for index in lines.size():
			for name in regexes:
				if regexes[name].search(lines[index]) != null: hits.append("%s:%d %s: %s" % [path, index + 1, name, lines[index].strip_edges()])
	for hit in hits: print("  ", hit)
	check("Ningún número de tipo de sala fuera de las paletas (%d scripts)" % files.size(), hits.is_empty(), "%d sitios" % hits.size())
	for path in GONE:
		var code := code_of(path)
		for name in GONE[path]: check("%s ya no declara %s" % [path.get_file(), name], RegEx.create_from_string("(?m)^const %s(?![A-Za-z0-9_])" % name).search(code) == null)
	var floor_code := code_of("res://game/world/generation/floor_definition.gd")
	for name in GONE_FUNCS: check("floor_definition.gd ya no tiene %s()" % name, not floor_code.contains("static func %s(" % name))
	check("La paleta no precarga nada", not FileAccess.get_file_as_string("res://game/floors/palettes/hotel_palette.gd").contains("preload("))
	for path in TOUCHED:
		var compiled := load(path) as GDScript
		check("%s compila" % path.get_file(), compiled != null and compiled.can_instantiate())

## The tables as they were: the same values, types and order.
func moved() -> void:
	var hotel: Script = HOTEL
	var constants := hotel.get_script_constant_map()
	for name in BEFORE: check("La paleta guarda %s como estaba" % name, constants.has(name) and var_to_str(constants[name]) == var_to_str(BEFORE[name]))

## The questions against the lists and numbers floor 1 used before them.
func questions() -> void:
	var hard := [4, 7, 9]
	var never_dark := [0, 4, 7, 8, 9, 10, 19, 20]
	var tall := [0, 5, 6, 17, 18]
	var battens := [4, 7, 8, 9]
	var domestic := [1, 2, 3, 4, 7, 15, 16]
	var no_number := [0, 7, 8, 9, 10, 11, 12, 15, 19, 20]
	var same := {"hard_floor": true, "floor_finish": true, "wall_material": true, "may_be_dark": true, "height_of": true, "lamp_of": true, "domestic": true, "label": true, "article": true, "numbered": true}
	for type in 21:
		for hall in [-1, 0]:
			var room := {"type": type, "hall": hall}
			if HOTEL.hard_floor(room) != (type in hard): same.hard_floor = false
			if HOTEL.floor_finish(room) != ("tile" if type in hard else "carpet"): same.floor_finish = false
			if HOTEL.wall_material(room) != ("plaster_decrepit" if type in [8, 18] else "plaster"): same.wall_material = false
			if HOTEL.may_be_dark(room) != (not (type in never_dark or hall >= 0)): same.may_be_dark = false
			if HOTEL.height_of(room) != (4.8 if hall >= 0 else 4.2 if type in tall else 3.15): same.height_of = false
			if HOTEL.domestic(room) != (type in domestic): same.domestic = false
			if HOTEL.label(room) != String(BEFORE.NAMES[type]): same.label = false
			if HOTEL.article(room) != String(BEFORE.ARTICLES[type]): same.article = false
			for height in [3.15, 4.2, 4.8]:
				var lit := {"type": type, "hall": hall, "height": height}
				var lamp: String = "batten" if type in battens else "chandelier" if height > 4.0 and type != 0 else "dome"
				if HOTEL.lamp_of(lit) != lamp: same.lamp_of = false
			for corridor in [false, true]:
				for service in [false, true]:
					var door := {"type": type, "hall": hall, "corridor": corridor, "service": service}
					var wanted: bool = hall < 0 and not corridor and not service and not type in no_number
					if HOTEL.numbered(door) != wanted or GEN.numbered(door) != wanted: same.numbered = false
	for name in same: check("%s responde como la lista de antes" % name, same[name])
	var sizes := true
	for survivors in range(0, 7):
		var area := float({1: 0.5, 4: 1.2, 5: 1.35}.get(clampi(survivors, 1, 5), 1.0))
		if HOTEL.area_for(survivors) != area: sizes = false
		if HOTEL.areas_for(survivors) != [1.0 if clampi(survivors, 1, 5) == 1 else area, area, area]: sizes = false
	for area in [0.5, 1.0, 1.2, 1.35]:
		if HOTEL.rooms_window(area) != Vector2i(roundi(81.0 * area), roundi(99.0 * area)): sizes = false
		if HOTEL.tv_rooms(area) != (6 if area < 1.0 else 8) or HOTEL.rings(area) != (4 if area < 1.0 else 6): sizes = false
	check("El tamaño del piso, sus ventanas, teles y anillos, como antes", sizes)
	check("Lo vedado: la salida, los refugios y lo que hay tras cada ascensor, en ese orden", HOTEL.off_limits_rooms({"exit": 5, "refuges": [7, 9], "gates": [{"beyond": 11}, {}]}) == [5, 7, 9, 11, -1])

## Who reaches the palette, and how.
func routes() -> void:
	check("Un manifiesto sin piso es del hotel", FLOOR.palette({}) == HOTEL)
	check("El del piso 1 también", FLOOR.palette({"floor": 1}) == HOTEL)
	check("Un piso sin paleta cae en la del hotel", FLOOR.palette({"floor": 7}) == HOTEL)
	check("El tipo de piso del hotel lleva su paleta", KIND.PALETTE == HOTEL)
	check("Los papeles estructurales, con su número", HOTEL.RECEPTION == 0 and HOTEL.LANDING == 9 and HOTEL.LOBBY == 10 and HOTEL.CORRIDOR == 11 and HOTEL.GALLERY == 12 and HOTEL.REFUGE == 19 and HOTEL.VOID == 20 and FLOOR.VOID == HOTEL.VOID)
	var generator = GEN.new()
	check("El generador dibuja con la paleta del hotel", generator.palette == HOTEL)
	check("Su validador es el del hotel y lee la misma paleta", generator.validator().get_script() == VALIDATOR and VALIDATOR.new().palette == HOTEL)
	var agree := true
	for type in 21:
		for hall in [-1, 0]:
			var room := {"type": type, "hall": hall, "corridor": false, "service": false}
			if generator.numbers(room) != HOTEL.numbered(room): agree = false
	check("numbers() pregunta a la paleta", agree)
