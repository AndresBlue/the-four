extends RefCounted
## The offices' rooms (docs/OFICINAS.md 2, 3 and 11.2; floor 2): what each
## type is called and has in it, how it is built, lit and dressed, the plan a
## planta is drawn by, and what the office adds: its plantas' systems, the
## plenum, the ceiling lattice and the crawl spaces. Every name of
## hotel_palette.gd is here too (tests/office/office_test.gd holds it to
## that); where the office has no use for one, it keeps the hotel's value or
## an empty one, and says so. It preloads nothing: floor_definition.gd
## preloads it, and the generator and the validator load it headless.

## The manifest "version" of floor 2 (office_floor.GENERATOR_VERSION).
const VERSION := 1

## Structural roles: the same number in every palette.
const RECEPTION := 0
const LANDING := 9
const LOBBY := 10
const CORRIDOR := 11
const GALLERY := 12
const REFUGE := 19
## A cell of the grid a planta does not use.
const VOID := 20

## The office's own types by name: office code says these, never a number.
const OPEN_OFFICE := 1
const CUBICLES := 2
const OFFICE := 3
const TOILETS := 4
const BOARDROOM := 5
const ARCHIVE := 6
const COPY_ROOM := 7
const STORE := 8
const MOBILE_ARCHIVE := 13
const MAIL := 14
const BREAK_ROOM := 15
const EXEC_OFFICE := 16
const WINDOW := 17
const ELECTRICAL := 18
const SECURITY := 21
const AIR_ROOM := 22
const AIR_PLANT := 23
const SECRETARY := 24
const DEPOT := 25

## No stage asks for televisions and no salon is kept empty
## (map_generator.finish(), light_rooms()): no type is either.
const TV_ROOM := -1
const EMPTY_SALON := -1

## How much floor each planta is by the survivors who play it, and its rooms:
## the hotel's (hotel_palette.gd says why).
const AREA := {1: 0.5, 4: 1.2, 5: 1.35}
const ROOMS := Vector2i(81, 99)
const NUMBERED_MOST := 96

static func area_for(survivors: int) -> float:
	return float(AREA.get(clampi(survivors, 1, 5), 1.0))

## Each planta's, first to last, as the hotel's.
static func areas_for(survivors: int) -> Array:
	var area := area_for(survivors)
	return [1.0 if clampi(survivors, 1, 5) == 1 else area, area, area]

static func rooms_window(area: float) -> Vector2i:
	return Vector2i(roundi(float(ROOMS.x) * area), roundi(float(ROOMS.y) * area))

## No stage of this floor asks for televisions.
static func tv_rooms(_area: float) -> int:
	return 0

static func rings(area: float) -> int:
	return 4 if area < 1.0 else 6

## Lockers per type (hide_kind()): two in the toilets' changing room and the
## security post, one in the store, the mail room and the break room.
const WARDROBES := {4: 2, 8: 1, 14: 1, 15: 1, 21: 2}
## Not read on this floor: hard_floor() asks floor_finish().
const HARD_FLOORS := []
const TYPES := ["recepcion_interna", "oficina_abierta", "cubiculos", "despacho", "aseos", "sala_juntas", "archivo", "reprografia", "almacen", "montacargas", "vestibulo_llegada", "pasillo", "pasillo_servicio", "archivo_movil", "correo", "sala_descanso", "despacho_direccion", "ventanilla", "cuarto_electrico", "vestibulo_montacargas", "vacio", "puesto_seguridad", "sala_climatizacion", "climatizadora", "secretaria", "deposito"]
const NAMES := ["Recepción interna", "Oficina abierta", "Cubículos", "Despacho", "Aseos y vestuario", "Sala de juntas", "Archivo", "Reprografía y microfichas", "Almacén", "Montacargas", "Vestíbulo de llegada", "Pasillo", "Pasillo de servicio", "Archivo móvil", "Correo", "Sala de descanso", "Despacho de dirección", "Ventanilla de Personal", "Cuarto eléctrico", "Vestíbulo del montacargas", "Vacío", "Puesto de seguridad", "Sala de climatización", "Climatizadora", "Secretaría", "Depósito"]
## The article each type's name takes on a paper (hint_placement.room_said()).
const ARTICLES := ["la", "la", "los", "el", "los", "la", "el", "la", "el", "el", "el", "el", "el", "el", "el", "la", "el", "la", "el", "el", "el", "el", "la", "la", "la", "el"]

## Each corner is a socket, "" an empty one. The archives, the lift, the
## corridors, the void and the air rooms have none: what fills them is their
## own (map_generator.finish() reads four corners of every room).
const RECIPES := [
	["reception", "chairs", "plant", "coat_rack"],
	["desk", "desk", "filing", "coat_rack"],
	["filing", "desk", "bin", "coat_rack"],
	["desk", "filing", "coat_rack", "shelf"],
	["basin", "basin", "bench", "bin"],
	["sideboard", "board", "plant", "projector"],
	["", "", "", ""],
	["copier", "reader", "shelf", "cart"],
	["shelf", "shelf", "cart", "boxes"],
	["", "", "", ""],
	["bench", "bin", "", ""],
	["", "", "", ""],
	["", "", "", ""],
	["", "", "", ""],
	["sorter", "sorter", "cart", "table"],
	["vending", "cooler", "table", "fridge"],
	["desk", "sideboard", "coat_rack", "armchair"],
	["filing", "shelf", "chairs", "bin"],
	["cabinet", "shelf", "", ""],
	["bench", "bin", "", ""],
	["", "", "", ""],
	["gun_rack", "filing", "shelf", ""],
	["", "", "", ""],
	["", "", "", ""],
	["desk", "filing", "coat_rack", "plant"],
	["shelf", "boxes", "shelf", "cart"],
]

## How tall a room is (height_of()): a false ceiling at 2.95, the boardroom's
## at 3.25 (the trunk duct clears it by 5 cm), none where the slab is the
## ceiling (4.4).
const HEIGHTS := [2.95, 2.95, 2.95, 2.95, 2.95, 3.25, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 4.4, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 4.4, 4.4, 2.95, 2.95]
## The hotel's: height_of() does not read it, a salon is as tall as its type.
const HALL_HEIGHT := 4.8
## Rooms whose lamps are never out (may_be_dark()): the lit lobbies, the
## window, the security post and the rooms with only an emergency light or
## none. Salons may be dark.
const NEVER_DARK := [0, 9, 10, 17, 18, 19, 20, 21, 22, 23]
## Doors with no plaque (numbered(), plaque()).
const NO_NUMBER := [0, 9, 10, 11, 12, 19, 20, 23, 25]
## What the hotel's finish() draws (step 1a's generator); step 1b's own draws
## from PLANTA_MIX, HALL_MIX and SERVICE_BY_PLANTA.
const TIDY_ROOMS := [3, 3, 3, 4, 7, 14, 15]
const UNRULY_ROOMS := [3, 8, 7, 15, 13]
const SERVICE_ROOMS := [8, 8, 7, 4]
const HALL_ROOMS := [1, 2]

## Module sizes and corridor lanes, in metres (OFICINAS 11.3): about 0.73 of
## the hotel's.
const MODULE_SIZES := [8.0, 9.0, 10.0, 10.0, 11.0, 12.0]
const LANE_WIDTHS := [2.4, 2.6, 2.8, 3.0]

## Plans per planta: Personal presentable, Registro combs and blocks for the
## archives, Dirección tidier, with suites opening on to suites. Abandoned,
## not rotten: no rot.
const DECKS := [["spine", "twin", "ring", "comb"], ["comb", "blocks", "twin", "spine"], ["ring", "arms", "warren", "spine", "blocks"]]
const SERVED := {"spine": 0.5, "twin": 0.55, "ring": 0.55, "comb": 0.6, "blocks": 0.65, "arms": 0.5, "warren": 0.0}
const APART := {}
const ROOM_DOORS := {"warren": 1.8}

## How kept each planta still is, before its own drift.
const ORDER_BASE := [0.8, 0.62, 0.55]
## Where the refuge slot lies on each planta, as a share of the walk to its
## farthest room.
const DEPTHS := [Vector2(0.65, 0.9), Vector2(0.8, 0.97), Vector2(0.6, 0.9)]
## The hotel's generator reads one for the first planta and one for the rest.
const FIRST_DEPTH: Vector2 = DEPTHS[0]
const DEPTH: Vector2 = DEPTHS[2]
## The hotel's 150 m, for modules about 0.73 of its own.
const FIRST_WALK := 110.0
## The least walk to the refuge slot per planta, times sqrt(area).
const LEAST_WALKS := [110.0, 0.0, 0.0]

## Salons on a planta: more than the hotel's (open offices, cubicles, archives).
const HALLS := Vector2i(4, 8)

## Exposed corridors per planta (hotel_palette.gd says what they are).
const EXPOSED := [0.0, 25.0, 35.0]
const EXPOSED_CHANCE := [0.0, 0.5, 0.8]
const SECOND_EXPOSED := 0.0
const EXPOSED_LONGEST := 70.0

## Where a door stands in a wall, from its middle. No room has the hotel's
## domestic alcoves.
const DOOR_PLACES := [0.0, 0.0, 1.0, -1.0, 1.5, -1.5]
const DOOR_PLACES_DOMESTIC := DOOR_PLACES
const DOMESTIC := []

## The dark rooms, and how kept rooms are: the hotel's numbers.
const DARK_OWN := [0.23, 0.29, 0.36]
const DARK_SPREAD := 0.45
const DARK_CORRIDOR := Vector2(0.03, 0.05)
const WEAR := 0.25
const KEPT := Vector2(0.25, 0.55)

## Corner pieces that turn their back to the wall (map_generator.finish()):
## rotation 0 in the first two corners, 2 in the other two.
const WALL_KINDS := ["desk", "shelf", "filing", "sideboard", "board", "copier", "sorter", "vending", "cooler", "fridge", "cabinet", "gun_rack", "reception", "basin", "bench"]

## Plain or bare ceilings, and walls let go.
const SERVICE_CEILINGS := [8, 12, 18, 22, 23, 25]
const DECREPIT_WALLS := [8, 25]
const SPRINKLER_ROOMS := [0, 1, 2, 3, 5, 7, 11, 14, 15, 16, 17, 24]
## No wall lamps on this floor.
const SCONCE_ROOMS := []
## The fluorescent battens (lamp_of()): the archives, the store, the service
## corridor, the air rooms and the depot.
const BATTEN_ROOMS := [6, 8, 12, 13, 22, 23, 25]
## The hotel's: lamp_of() does not read it, no office has a chandelier.
const CHANDELIER_HEIGHT := 4.0
## The set of furniture each type puts along its walls (room_dressing, step
## 1d); "" none: archive rows run to the walls.
const MODULE_SET := {0: "office_open", 1: "office_open", 2: "office_open", 3: "office_private", 4: "lockers", 5: "office_private", 6: "", 7: "copy", 8: "store", 9: "", 10: "", 11: "office_corridor", 12: "office_corridor", 13: "", 14: "mail", 15: "break", 16: "office_private", 17: "office_private", 18: "", 19: "", 20: "", 21: "office_private", 22: "", 23: "", 24: "office_private", 25: "store"}
const ALARM_ROOMS := [0, 10, 11, 12]
## No fuse boxes (no key on this floor, OFICINAS 14), ceiling fans or clocks.
const FUSE_ROOMS := []
const FAN_ROOMS := []
const CLOCK_ROOMS := []
## The hotel's (reception, lobby, corridor, gallery): read only by the hotel's
## dressing, which step 1d replaces.
const PUBLIC_ROOMS := [0, 10, 11, 12]
## The hotel's: read only by the hotel's dressing, which step 1d replaces.
const SMEAR_ROOMS := [4, 7, 8, 9]
## Metal shelving and carts instead of wood (prop_factory): every type but the
## boardroom, the director's office and the secretary's.
const SERVICE := [0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18, 19, 20, 21, 22, 23, 25]
## Types that are circulation besides corridors and halls: the structural
## roles, as the hotel's.
const CIRCULATION := [0, 9, 10, 12]

# --- What the office adds ----------------------------------------------------

## What each planta is (OFICINAS 3), and its light at the start: battery
## units only where it is not "none" (geometry 7.2).
const SYSTEMS := ["mail", "power", "air"]
const POWER := ["mains", "emergency", "none"]
const PLANTA_NAMES := ["PERSONAL", "REGISTRO Y ARCHIVO", "DIRECCIÓN"]
## Plaques: the planta's letter, or the type's own.
const LETTERS := ["P", "R", "D"]
const TYPE_LETTERS := {21: "S", 8: "M", 18: "M", 22: "M"}
## Where the creature never goes and nobody is taken.
const OFF_LIMITS := [9, 10, 19]
## Carpet and veneer: on wing 2 only.
const CARPET := [5, 16, 24]
## The floor of each type (floor_finish()); CARPET on wing 2 is carpet instead.
const FINISH_BY_TYPE := ["terrazzo", "vinyl", "vinyl", "vinyl", "tile", "vinyl", "vinyl", "vinyl", "concrete", "terrazzo", "terrazzo", "vinyl", "concrete", "vinyl", "vinyl", "vinyl", "vinyl", "vinyl", "concrete", "terrazzo", "vinyl", "vinyl", "concrete", "concrete", "vinyl", "concrete"]
const FINISHES := ["terrazzo", "tile", "carpet", "concrete", "vinyl"]
## Concrete block walls (wall_material()): corridors, toilets, service and
## plant rooms.
const BLOCK_WALLS := [4, 7, 8, 11, 12, 14, 18, 22, 23, 25]
const WALLS := ["office_paint", "block", "veneer"]
const LAMPS := ["troffer", "batten", "pendant", "emergency"]
## Where the special rooms lie, as a share of the walk.
const WINDOW_DEPTH := Vector2(0.15, 0.45)
const ELECTRICAL_DEPTH := Vector2(0.4, 0.7)
const SECURITY_DEPTH := Vector2(0.25, 0.55)
## Metres over the planta's floor. duct: the trunk [width, height]; branch:
## the branches, bridges and loose links; main: the crawl duct's clear inside,
## square. Copied whole into manifest.plenum.
const PLENUM := {"ceiling": 2.95, "slab": 4.4, "duct_y": 3.7, "main": 1.2, "duct": [1.0, 0.8], "branch": [0.5, 0.3]}
## Tube runs: between the door head (2.65) and the false ceiling.
const TUBE_Y := 2.8
## A station's mouth and tray (its point); the hub's mouth too.
const STATION_Y := 1.25
const STATIONS := Vector2i(8, 14)
## Walking metres between two stations, times sqrt(area).
const STATION_APART := 15.0
## Tube metres from the hub to any station.
const STATION_TUBE_MIN := 25.0
const MAIN_LENGTH := Vector2(25.0, 45.0)
const MAIN_IDEAL := 35.0
const MAIN_BENDS := 2
## The hatch hangs `in` from the plant's wall; the ladder's foot is `stand`
## out from it.
const HATCH := {"in": 1.5, "stand": 0.75}
## The crossing's side stub, past the main's side wall.
const STUB := 1.5
## No gap, ceiling or duct exit within main / 2 + this of the main or the
## stub, in plan.
const MAIN_CLEAR := 1.2
## The shaft's landing: along the wall it opens from, out from it.
const SHAFT := Vector2(2.2, 2.2)
## The air handler: width along its wall, height, depth.
const AIR_UNIT := Vector3(3.0, 2.2, 1.5)
## Share of the main duct where the remains lie.
const REMAINS := Vector2(0.55, 0.8)
## Cells with a missing tile, per planta.
const GAP_SHARE := [0.03, 0.045, 0.06]
## The archives' shelving (step 1b): shelf height, row depth, aisles, the
## spine, the end aisles, the doors' clearances, the inset and the gap left
## to the long wall. ARCHIVE is type 6, so this is ARCHIVE_LAYOUT.
const ARCHIVE_LAYOUT := {"shelf": 2.1, "row": 0.6, "aisle": 1.0, "spine": 1.6, "end_min": 1.0, "door_depth": 1.5, "door_band": 1.0, "inset": 0.15, "wall_gap": [0.0, 0.9]}
## Share of wing 1's corridor cells a timer lights.
const TIMER_COVER := 0.5
## Corridor lines that are service corridors.
const GALLERY_SHARE := 0.15
const WALL_GRILLE_Y := 0.35
## Along a wall, between a locker and a fixture or two fixtures.
const WALL_APART := 1.5
## Corner sockets: this far in from each wall's centre line.
const SOCKET_INSET := 1.3
## Nothing in a room is taller (OFICINAS 2).
const FURNITURE_TOP := 2.2
## Rooms that may have a glass partition to a corridor.
const GLAZED_TYPES := [3, 16, 17, 24]
## The zones' stripes, one per department of a planta.
const STRIPES := [Color("8a7a3c"), Color("5f6b3a"), Color("8b5a3c"), Color("4f6470"), Color("7a6a55"), Color("a39a7a"), Color("6e3b3b"), Color("3f5a4c")]
## Departments per planta: [name, focus types]. The first is the one of the
## sector it is walked into from.
const DEPARTMENTS := [
	[["ALTAS", [3]], ["NÓMINAS", [3, 7]], ["EXPEDIENTES", [13, 3]], ["SELECCIÓN", [5, 3]], ["FORMACIÓN", [5, 15]], ["TRASLADOS", [3, 14]], ["BAJAS", [3, 8]]],
	[["REGISTRO", [3, 14]], ["ARCHIVO", [6, 13]], ["CORREO", [14]], ["MICROFICHAS", [7, 13]], ["REPROGRAFÍA", [7, 8]], ["ARCHIVO CENTRAL", [6]], ["CLASIFICACIÓN", [14, 6]]],
	[["SECRETARÍA GENERAL", [24, 16]], ["DIRECCIÓN", [16]], ["JUNTAS", [5]], ["GABINETE", [16, 24]], ["PROTOCOLO", [24, 5]], ["ASESORÍA", [16, 6]], ["SEGURIDAD", [3]], ["MANTENIMIENTO", [8]]],
]
## Weight multiplier of a department's focus types.
const FOCUS := 3.0
## Module types by weight, per planta.
const PLANTA_MIX := [
	{3: 4.0, 7: 1.0, 15: 0.8, 4: 0.6, 5: 0.6, 14: 0.5, 13: 0.4, 8: 0.4},
	{6: 2.0, 3: 2.0, 13: 1.8, 14: 1.5, 7: 1.5, 8: 0.6, 4: 0.5, 15: 0.4},
	{16: 3.5, 24: 2.0, 5: 1.0, 4: 0.6, 6: 0.5, 15: 0.5, 8: 0.4},
]
const HALL_MIX := [{1: 3.0, 2: 3.0}, {6: 4.0, 2: 1.5, 1: 1.0}, {1: 1.5, 16: 1.5, 6: 0.5}]
const SERVICE_BY_PLANTA := [[4, 15, 8, 7], [8, 7, 4, 8], [8, 4, 15, 8]]
const MUSTS := [{15: 1, 5: 1}, {6: 2, 14: 1, 7: 1}, {5: 1, 16: 2, 24: 1}]
## A large module ("módulo grande"): both sides at least this.
const BOARDROOM_SIDE := 10.0
## Free-standing furniture (room.furniture, step 1b): footprint [w, d] with the
## chairs (a partition's size.x is its length), and height, all under
## FURNITURE_TOP.
const FURNITURE := {
	"desk": {"size": Vector2(1.5, 1.4), "height": 1.3},
	"desk_pair": {"size": Vector2(1.5, 2.6), "height": 1.3},
	"partition": {"size": Vector2(0.0, 0.06), "height": 1.5},
	"meeting_table": {"size": Vector2(3.6, 1.2), "height": 0.9},
	"pigeonholes": {"size": Vector2(1.8, 0.4), "height": 1.9},
	"copier": {"size": Vector2(1.3, 0.7), "height": 1.05},
	"vending": {"size": Vector2(0.9, 0.8), "height": 1.8},
	"card_index": {"size": Vector2(1.7, 0.5), "height": 1.2},
}

# --- Questions ---------------------------------------------------------------

## What a room is called on the plans and the papers.
static func label(room: Dictionary) -> String:
	return String(NAMES[int(room.get("type", 0))])

## The article its name takes (ARTICLES).
static func article(room: Dictionary) -> String:
	return String(ARTICLES[int(room.get("type", 0))])

## How tall a room is (HEIGHTS): a salon as tall as its type.
static func height_of(room: Dictionary) -> float:
	return float(HEIGHTS[int(room.type)])

## Under a false ceiling, with the plenum over it: all but the service
## corridor, the air room and the plant.
static func false_ceiling(room: Dictionary) -> bool:
	return height_of(room) < float(PLENUM.slab) - 0.01

## Hard underfoot: everything but carpet.
static func hard_floor(room: Dictionary) -> bool:
	return floor_finish(room) != "carpet"

## The floor's material (FINISHES).
static func floor_finish(room: Dictionary) -> String:
	if int(room.type) in CARPET and int(room.get("wing", 0)) == 2: return "carpet"
	return String(FINISH_BY_TYPE[int(room.type)])

## The walls' material (WALLS): veneer where the carpet is, block where the
## building shows, paint elsewhere.
static func wall_material(room: Dictionary) -> String:
	if int(room.type) in CARPET and int(room.get("wing", 0)) == 2: return "veneer"
	return "block" if int(room.type) in BLOCK_WALLS else "office_paint"

## The rooms The Lurker's lies use (spec_f3_integration 4.3): where a phone
## could ring, keys be struck, a copier start.
static func has_phone(room: Dictionary) -> bool: return int(room.type) in [OFFICE, EXEC_OFFICE, SECRETARY]
static func has_typewriter(room: Dictionary) -> bool: return int(room.type) in [OFFICE, EXEC_OFFICE, WINDOW, SECRETARY]
static func has_copier(room: Dictionary) -> bool: return int(room.type) == COPY_ROOM

## Whether a room can have its lamps out: salons too ("zonas apagadas").
static func may_be_dark(room: Dictionary) -> bool:
	return not int(room.type) in NEVER_DARK

## The lamp on a room's ceiling (LAMPS): the electrical room and the void only
## the emergency unit, the boardroom a pendant.
static func lamp_of(room: Dictionary) -> String:
	var room_type := int(room.type)
	if room_type == ELECTRICAL or room_type == VOID: return "emergency"
	if room_type == BOARDROOM: return "pendant"
	return "batten" if room_type in BATTEN_ROOMS else "troffer"

## No room has the hotel's domestic alcoves.
static func domestic(_room: Dictionary) -> bool:
	return false

## Whether a room carries a plaque: not a corridor, not in NO_NUMBER, and of a
## salon only the room it is named by (its hall).
static func numbered(room: Dictionary) -> bool:
	var hall := int(room.get("hall", -1))
	return not bool(room.get("corridor", false)) and not int(room.type) in NO_NUMBER and (hall < 0 or hall == int(room.get("id", -1)))

## Where one hides here.
static func hide_kind(_room: Dictionary) -> String:
	return "locker"

## A door's plaque: "P-114", or "" with no number.
static func plaque(room: Dictionary) -> String:
	var number := int(room.get("number", 0))
	if number == 0: return ""
	return "%s-%d" % [String(TYPE_LETTERS.get(int(room.type), LETTERS[int(room.get("wing", 0))])), number]

## Where the creature never goes and nobody is taken (OFF_LIMITS).
static func off_limits(room: Dictionary) -> bool:
	return int(room.type) in OFF_LIMITS

## The ids of every room that is not void and is off-limits, ascending.
static func off_limits_rooms(manifest: Dictionary) -> Array:
	var rooms: Array = []
	for room in manifest.get("rooms", []):
		if int(room.type) != VOID and off_limits(room): rooms.append(int(room.id))
	rooms.sort()
	return rooms

## The rooms of a wing that keep their lamps whatever the board or the air
## does, ascending: on mains, every room; else the off-limits ones and, on
## wing 2, the security post (its own battery). Never the electrical room: it
## shows only its emergency unit.
static func always_lit(manifest: Dictionary, wing: int) -> Array:
	var rooms: Array = []
	for room in manifest.get("rooms", []):
		var room_type := int(room.type)
		if int(room.get("wing", -1)) != wing or room_type == VOID or room_type == ELECTRICAL: continue
		if POWER[wing] == "mains" or off_limits(room) or (wing == 2 and room_type == SECURITY): rooms.append(int(room.id))
	rooms.sort()
	return rooms

## The stripe of a room's zone: the colour of its sector's department on its
## wing, or a grey where none is.
static func stripe_color(manifest: Dictionary, room: Dictionary) -> Color:
	var wing := int(room.get("wing", 0))
	var departments: Array = manifest.get("departments", [])
	if wing < departments.size():
		for entry in departments[wing]:
			if int(entry.get("sector", -1)) == int(room.get("sector", -2)): return STRIPES[int(entry.get("colour", 0))]
	return Color("6f6a5e")

## What a zone is called on its signs: on wing 1 its circuit ("R-2 ARCHIVO"),
## on the others its department ("NÓMINAS"); "" when nothing matches.
static func zone_label(manifest: Dictionary, room: Dictionary) -> String:
	var wing := int(room.get("wing", 0))
	var sector := int(room.get("sector", -2))
	if wing == 1:
		for circuit in manifest.get("power", {}).get("circuits", []):
			if int(circuit.get("sector", -1)) == sector: return "%s %s" % [String(circuit.get("code", "")), String(circuit.get("name", ""))]
		return ""
	var departments: Array = manifest.get("departments", [])
	if wing < departments.size():
		for entry in departments[wing]:
			if int(entry.get("sector", -1)) == sector: return String(entry.get("name", ""))
	return ""

# --- The ceiling lattice -----------------------------------------------------

## One world lattice of ceiling tiles for the generator, the validator and the
## geometry: tile (i, j) covers x from i * TILE to (i + 1) * TILE and z from
## j * TILE to (j + 1) * TILE. Troffers are two tiles, one every
## TROFFER_PITCH or so; a ceiling exit or a gap keeps GRILLE_CLEAR from every
## troffer's centre and, outside corridors, GRILLE_WALL from every wall.
const TILE := 0.6
const TROFFER_PITCH := 3.0
## Half a wall's thickness: a ceiling stops at the wall's face.
const WALL_HALF := 0.09
const GRILLE_CLEAR := 0.9
const GRILLE_WALL := 1.0
## An edge this near a lattice line is on it (floating point).
const ON_LINE := 0.0001

## The ceiling in world x and z: the cell less WALL_HALF on every side with a
## wall (not in open_sides; north is -z, south +z, west -x, east +x).
static func ceiling_rect(room: Dictionary) -> Rect2:
	var open: Array = room.get("open_sides", [])
	var centre := Vector2(float(room.px), float(room.pz))
	var half := Vector2(float(room.span_x), float(room.span_z)) * 0.5
	var low := centre - half
	var high := centre + half
	if not open.has("west"): low.x += WALL_HALF
	if not open.has("east"): high.x -= WALL_HALF
	if not open.has("north"): low.y += WALL_HALF
	if not open.has("south"): high.y -= WALL_HALF
	return Rect2(low, high - low)

## The whole tiles inside ceiling_rect(): i from ceili(x0 / TILE) to
## floori(x1 / TILE), that end left out; j likewise. Edge rows and columns cut
## by the walls are not in it.
static func full_tiles(room: Dictionary) -> Rect2i:
	var rect := ceiling_rect(room)
	var low := Vector2i(ceili(rect.position.x / TILE - ON_LINE), ceili(rect.position.y / TILE - ON_LINE))
	var high := Vector2i(floori(rect.end.x / TILE + ON_LINE), floori(rect.end.y / TILE + ON_LINE))
	return Rect2i(low, Vector2i(maxi(high.x - low.x, 0), maxi(high.y - low.y, 0)))

## The troffers of a room lit by them: [] for any other lamp. Each
## {"tiles": [Vector2i, Vector2i], "along_z": bool, "centre": Vector2}: its
## long side along the ceiling's longer one (x on a tie), its centre on a
## lattice line that way, as near as the lattice lets it to n evenly spaced
## centres per side (n = round(side / TROFFER_PITCH), at least one); kept
## inside full_tiles(), and none twice. 3 x 3 in an 8 m module, 4 x 4 in a
## 12 m one, one line along a lane.
static func troffers(room: Dictionary) -> Array:
	if lamp_of(room) != "troffer": return []
	var rect := ceiling_rect(room)
	var tiles := full_tiles(room)
	var along_z: bool = rect.size.y > rect.size.x
	var long_start: float = rect.position.y if along_z else rect.position.x
	var long_size: float = rect.size.y if along_z else rect.size.x
	var cross_start: float = rect.position.x if along_z else rect.position.y
	var cross_size: float = rect.size.x if along_z else rect.size.y
	var long_low: int = tiles.position.y if along_z else tiles.position.x
	var long_high: int = (tiles.end.y if along_z else tiles.end.x) - 2
	var cross_low: int = tiles.position.x if along_z else tiles.position.y
	var cross_high: int = (tiles.end.x if along_z else tiles.end.y) - 1
	if long_high < long_low or cross_high < cross_low: return []
	var long_count := maxi(1, roundi(long_size / TROFFER_PITCH))
	var cross_count := maxi(1, roundi(cross_size / TROFFER_PITCH))
	var used := {}
	var out: Array = []
	for a in long_count:
		var along := long_start + long_size * (float(a) + 0.5) / float(long_count)
		var t := clampi(roundi(along / TILE) - 1, long_low, long_high)
		for b in cross_count:
			var across := cross_start + cross_size * (float(b) + 0.5) / float(cross_count)
			var u := clampi(floori(across / TILE), cross_low, cross_high)
			var first: Vector2i = Vector2i(u, t) if along_z else Vector2i(t, u)
			var second: Vector2i = Vector2i(u, t + 1) if along_z else Vector2i(t + 1, u)
			if used.has(first) or used.has(second): continue
			used[first] = true
			used[second] = true
			var centre := Vector2((float(first.x + second.x) * 0.5 + 0.5) * TILE, (float(first.y + second.y) * 0.5 + 0.5) * TILE)
			out.append({"tiles": [first, second], "along_z": along_z, "centre": centre})
	return out

## The whole tiles a ceiling exit or a gap may take: no troffer's, at least
## GRILLE_CLEAR from every troffer's centre and, but in corridors, at least
## GRILLE_WALL from every walled side of ceiling_rect(). Rows (j) first, then
## columns (i), ascending.
static func free_tiles(room: Dictionary) -> Array[Vector2i]:
	var rect := ceiling_rect(room)
	var tiles := full_tiles(room)
	var open: Array = room.get("open_sides", [])
	var walled := int(room.type) != CORRIDOR
	var taken := {}
	var centres: Array = []
	for troffer in troffers(room):
		for tile in troffer.tiles: taken[tile] = true
		centres.append(troffer.centre)
	var out: Array[Vector2i] = []
	for j in range(tiles.position.y, tiles.end.y):
		for i in range(tiles.position.x, tiles.end.x):
			var tile := Vector2i(i, j)
			if taken.has(tile): continue
			var centre := Vector2((float(i) + 0.5) * TILE, (float(j) + 0.5) * TILE)
			var near := false
			for other in centres:
				if centre.distance_to(other) < GRILLE_CLEAR:
					near = true
					break
			if near: continue
			if walled:
				if not open.has("west") and centre.x - rect.position.x < GRILLE_WALL: continue
				if not open.has("east") and rect.end.x - centre.x < GRILLE_WALL: continue
				if not open.has("north") and centre.y - rect.position.y < GRILLE_WALL: continue
				if not open.has("south") and rect.end.y - centre.y < GRILLE_WALL: continue
			out.append(tile)
	return out

## The tile a world point is under.
static func tile_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.z / TILE))

## A tile's centre, at height y.
static func tile_centre(tile: Vector2i, y: float) -> Vector3:
	return Vector3((float(tile.x) + 0.5) * TILE, y, (float(tile.y) + 0.5) * TILE)

# --- The crawl spaces --------------------------------------------------------

## The manifests crawl_boxes() and shaft_box() last answered, and their
## answers: crawling_at() asks every physics frame for every body.
static var crawl_manifest: Dictionary = {}
static var crawl_cache: Array[AABB] = []
static var shaft_manifest: Dictionary = {}
static var shaft_cache := AABB()

## The clear inside of the crawlable main duct, world, unpadded: one box per
## "main" and "cross" edge of manifest.ducts, from node to node, plenum.main
## wide and tall, its floor at the nodes' y - main / 2. An end at a "main"
## node (a bend, the crossing) is lengthened by main / 2 so elbows and the
## stub close; the hatch, the shaft's mouth and the stub's far end are not.
## An edge of no length gives no box.
static func crawl_boxes(manifest: Dictionary) -> Array[AABB]:
	if is_same(manifest, crawl_manifest): return crawl_cache
	var boxes: Array[AABB] = []
	var ducts: Dictionary = manifest.get("ducts", {})
	var main := float(manifest.get("plenum", PLENUM).get("main", PLENUM.main))
	var nodes: Array = ducts.get("nodes", [])
	for edge in ducts.get("edges", []):
		if not String(edge[3]) in ["main", "cross"]: continue
		var a: Array = nodes[int(edge[0])]
		var b: Array = nodes[int(edge[1])]
		var from := Vector3(float(a[0]), float(a[1]), float(a[2]))
		var to := Vector3(float(b[0]), float(b[1]), float(b[2]))
		if from.distance_to(to) < 0.001: continue
		var along_x: bool = absf(to.x - from.x) >= absf(to.z - from.z)
		var way: Vector3 = Vector3(signf(to.x - from.x), 0.0, 0.0) if along_x else Vector3(0.0, 0.0, signf(to.z - from.z))
		var start: Vector3 = from - way * (main * 0.5 if String(a[4]) == "main" else 0.0)
		var end: Vector3 = to + way * (main * 0.5 if String(b[4]) == "main" else 0.0)
		var across: Vector3 = Vector3(0.0, 0.0, main * 0.5) if along_x else Vector3(main * 0.5, 0.0, 0.0)
		var low := Vector3(minf(start.x, end.x), from.y - main * 0.5, minf(start.z, end.z)) - across
		var high := Vector3(maxf(start.x, end.x), from.y + main * 0.5, maxf(start.z, end.z)) + across
		boxes.append(AABB(low, high - low))
	crawl_manifest = manifest
	crawl_cache = boxes
	return boxes

## The shaft's standing room: air.shaft.rect from air.shaft.floor_y up main,
## to py + duct_y + main / 2. An empty box when the manifest has no shaft.
static func shaft_box(manifest: Dictionary) -> AABB:
	if is_same(manifest, shaft_manifest): return shaft_cache
	var shaft: Dictionary = manifest.get("air", {}).get("shaft", {})
	var box := AABB()
	if shaft.has("rect") and shaft.has("floor_y"):
		var main := float(manifest.get("plenum", PLENUM).get("main", PLENUM.main))
		var rect: Array = shaft.rect
		box = AABB(Vector3(float(rect[0]) - float(rect[2]) * 0.5, float(shaft.floor_y), float(rect[1]) - float(rect[3]) * 0.5), Vector3(float(rect[2]), main, float(rect[3])))
	shaft_manifest = manifest
	shaft_cache = box
	return box
