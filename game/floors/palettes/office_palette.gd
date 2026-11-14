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
const VERSION := 2

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
	["desk", "desk", "filing", "cooler"],
	["filing", "desk", "bin", "coat_rack"],
	["", "filing", "coat_rack", "shelf"],
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

## How tall a room is (height_of()): a false ceiling at 2.95 in every room
## that has one, the boardroom too (spec_rediseno 3.5), none where the slab
## is the ceiling (4.4).
const HEIGHTS := [2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 4.4, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 2.95, 4.4, 4.4, 2.95, 2.95]
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

## Module sizes in metres (spec_proporcion D8: the first of its candidates that
## held); the corridor lanes 3 to 3.6 m with a narrow 2.4 now and then
## (spec_rediseno 3.2): axis() draws evenly from the list, so a repeat is its weight.
const MODULE_SIZES := [6.0, 6.5, 7.0, 7.5, 8.0, 9.0]
const LANE_WIDTHS := [3.0, 3.0, 3.2, 3.2, 3.4, 3.6, 2.4]

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
## The least walk to the refuge on planta 0, times sqrt(area), for the smaller
## modules (spec_proporcion D10). office_generator reads LEAST_WALKS.
const FIRST_WALK := 90.0
## The least walk to the refuge slot per planta, times sqrt(area).
const LEAST_WALKS := [90.0, 0.0, 0.0]

## Salons on a planta: more than the hotel's (open offices, cubicles, archives).
const HALLS := Vector2i(4, 8)

## The naves of planta 1 (spec_rediseno 3.3): an open office or cubicles of
## 2 x 2 or 2 x 3 modules, with an aisle NAVE_AISLE wide down the seam between
## its two rows (office_generator.make_nave()).
const NAVE_AISLE := 3.0
## Its free-standing columns (spec_rediseno 3.4), on since The Lurker goes
## round them: COLUMN a side, their centres COLUMN_OFF from the aisle's line
## on the seams between modules along it, kept COLUMN_PAD more than clear of
## every path, COLUMN_CLEAR from furniture, corner props and door sweeps and
## COLUMN_LAMP from every troffer's centre; no tile a grille, a gap or she
## may take within COLUMN_TILE of one.
const COLUMNS := true
const COLUMN := 0.6
const COLUMN_OFF := 2.1
const COLUMN_PAD := 0.3
const COLUMN_CLEAR := 1.3
const COLUMN_LAMP := 0.9
const COLUMN_TILE := 0.6
## The tests and probes switch the columns on before COLUMNS is.
static var columns_test := false

## Whether floors are drawn with columns (COLUMNS, or a test's columns_test).
static func columns_on() -> bool:
	return COLUMNS or columns_test

## Exposed corridors per planta (hotel_palette.gd says what they are).
const EXPOSED := [0.0, 20.0, 28.0]
const EXPOSED_CHANCE := [0.0, 0.5, 0.8]
const SECOND_EXPOSED := 0.0
const EXPOSED_LONGEST := 56.0

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
## Carpet (floor_finish(), spec_rediseno 0): on wing 2 under the rugs of the
## boardroom, the director's office and the secretary's; on wing 0 the open
## office and the cubicles, with its soft step.
const CARPET := [5, 16, 24]
const NAVE_CARPET := [1, 2]
## The floor of each type (floor_finish(), spec_rediseno 2): dark terrazzo in
## the corridors, lobbies, mail and archives; light vinyl in the rooms;
## sealed concrete in the store, the service corridor and the depot; the
## electrical room's ridged tile (quarry). CARPET on wing 2 and NAVE_CARPET on
## wing 0 are carpet instead.
const FINISH_BY_TYPE := ["vinyl", "vinyl", "vinyl", "vinyl", "vinyl", "vinyl", "terrazzo", "vinyl", "concrete", "terrazzo", "terrazzo", "terrazzo", "concrete", "terrazzo", "terrazzo", "vinyl", "vinyl", "vinyl", "quarry", "terrazzo", "vinyl", "vinyl", "vinyl", "vinyl", "vinyl", "concrete"]
const FINISHES := ["terrazzo", "tile", "carpet", "carpet_exec", "concrete", "vinyl", "quarry"]
## Painted concrete block (wall_material()): the store, the service
## corridor, the electrical room, the air rooms and the depot.
const BLOCK_WALLS := [8, 12, 18, 22, 23, 25]
const WALLS := ["office_paint", "office_paint_kept", "block", "veneer", "partition"]
## The lower wall of each type (wall_trim(), spec_rediseno 2): the frieze of
## the corridors and the lobbies, the walnut dado round the office, the
## boardroom and the security post, two tones of paint in the air rooms and the
## reception (its own greige, office_geometry.low_paint()), the secretary's one
## panelled wall; "" none.
const FRIEZE_ROOMS := [10, 11, 19]
const DADO_ROOMS := [3, 5, 21]
const TWO_TONE_ROOMS := [0, 22, 23]
const TRIMS := ["", "frieze", "dado", "two_tone", "panel_wall"]
const LAMPS := ["troffer", "batten", "emergency"]
## The colour temperature of each type's lamps, in kelvin (lamp_kelvin(),
## spec_rediseno 4): warm fluorescent, about 3000 in the rooms and 3500 in the
## corridors; amber in the reception and the break room; neutral in the
## boardroom and the director's office. Seen through the camcorder's fixed
## 3200 K balance (lighting.gd CAMERA_WHITE). The electrical room's entry waits
## for a ceiling lamp (today it has only its emergency unit), and the refuge's
## lamp is turned green after (the hotel's extras()). Starting values, set
## against the references in the captures.
const LAMP_KELVIN := [2700.0, 3000.0, 3000.0, 3000.0, 3000.0, 3300.0, 3000.0, 3000.0, 3000.0, 3000.0, 3000.0, 3500.0, 3500.0, 3000.0, 3000.0, 2700.0, 3300.0, 3000.0, 2700.0, 3000.0, 3000.0, 3000.0, 3000.0, 3000.0, 3000.0, 3000.0]
## The troffer families (troffer_look(), spec_rediseno 2): narrow with a louvre
## in the boardroom, parabolic in the secretary's office, a
## surface-mounted wraparound in the director's office, prismatic elsewhere.
## Only how they look: troffers() is the same for every family.
const TROFFER_LOOKS := ["prismatic", "narrow", "parabolic", "wrap"]
const NARROW_TROFFERS := [BOARDROOM]
const PARABOLIC_TROFFERS := [SECRETARY]
const WRAP_TROFFERS := [EXEC_OFFICE]
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
## Rooms that may have a glass partition to a corridor or a gallery: the
## offices, the director's, the window, the security post (spec_rediseno
## 3.6) and the secretary's.
const GLAZED_TYPES := [3, 16, 17, 21, 24]
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
## The cell each type wants (spec_proporcion D9): [short side at least, at most,
## long side at least, at most], 0 for no bound. Types are drawn among those
## that fit, and with none, the band gives way (office_generator.fitting()).
const ROOM_BANDS := {
	RECEPTION: [6.5, 0.0, 8.0, 0.0],
	MAIL: [6.0, 0.0, 6.5, 0.0],
	ARCHIVE: [6.5, 0.0, 0.0, 0.0],
	MOBILE_ARCHIVE: [6.5, 0.0, 0.0, 0.0],
	COPY_ROOM: [6.0, 0.0, 0.0, 0.0],
	OFFICE: [0.0, 0.0, 0.0, 7.5],
	EXEC_OFFICE: [0.0, 0.0, 0.0, 8.0],
	SECRETARY: [0.0, 0.0, 0.0, 7.5],
	BOARDROOM: [6.5, 0.0, 8.0, 0.0],
	BREAK_ROOM: [7.0, 0.0, 8.0, 0.0],
	TOILETS: [0.0, 6.5, 7.0, 0.0],
	SECURITY: [0.0, 0.0, 0.0, 7.0],
	WINDOW: [0.0, 0.0, 0.0, 7.5],
	ELECTRICAL: [0.0, 6.5, 0.0, 0.0],
	AIR_ROOM: [7.0, 0.0, 8.0, 0.0],
	REFUGE: [6.0, 0.0, 0.0, 7.0],
}
## A nave two cells wide keeps its size with smaller modules: at least this
## across and along, and modules this deep across its aisle (COLUMN_OFF).
const NAVE_SIZE := Vector2(12.0, 16.0)
const NAVE_MODULE := 6.5
## Free-standing furniture (room.furniture): footprint [w, d] with the chairs
## and the room to use it (a partition's size.x is its length), and height,
## all under FURNITURE_TOP. Step 1b's lattice and table pieces, and the
## recipes' (spec_rediseno 5.2 and 6, area 4b), each built from the pieces
## made in code (office_props.build_item()).
const FURNITURE := {
	"desk": {"size": Vector2(1.5, 1.4), "height": 1.3},
	"desk_pair": {"size": Vector2(1.5, 2.6), "height": 1.3},
	# A nave's islands (office_generator.lay_islands()): two or three desk pairs
	# side by side, screens in a cross between them; as deep as their straight
	# desks and chairs pushed in (2.27; a pair's 2.6 is for its L desks).
	"desk_island": {"size": Vector2(3.0, 2.3), "height": 1.3},
	"desk_island_6": {"size": Vector2(4.5, 2.3), "height": 1.3},
	# 1.2, not the cubicles' 1.5 of spec_rediseno 6: in a nave nothing away from
	# a wall passes 1.3 (the director, 12 November 2026).
	"partition": {"size": Vector2(0.0, 0.06), "height": 1.2},
	"pigeonholes": {"size": Vector2(1.8, 0.4), "height": 1.9},
	"copier": {"size": Vector2(1.3, 0.7), "height": 1.05},
	"vending": {"size": Vector2(0.9, 0.8), "height": 1.8},
	"card_index": {"size": Vector2(1.7, 0.5), "height": 1.2},
	"exec_desk": {"size": Vector2(2.2, 2.3), "height": 1.3},
	"lounge": {"size": Vector2(2.3, 1.4), "height": 1.6},
	"secretary_desk": {"size": Vector2(2.1, 2.5), "height": 1.3},
	"work_desk": {"size": Vector2(1.5, 1.4), "height": 1.3},
	"waiting_row": {"size": Vector2(2.5, 0.6), "height": 0.9},
	"filing": {"size": Vector2(0.5, 0.65), "height": 1.32},
	"bookcase": {"size": Vector2(0.9, 0.4), "height": 2.0},
	"sideboard": {"size": Vector2(1.8, 0.5), "height": 0.8},
	"wood_shelving": {"size": Vector2(1.2, 0.45), "height": 1.8},
	"shelving": {"size": Vector2(2.0, 0.45), "height": 2.1},
	"cart_boxes": {"size": Vector2(0.8, 0.55), "height": 1.0},
	"mail_cart": {"size": Vector2(0.9, 0.65), "height": 0.9},
	"pigeon_counter": {"size": Vector2(2.4, 0.85), "height": 1.1},
	"sorting_table": {"size": Vector2(2.0, 0.95), "height": 1.02},
	"reader_table": {"size": Vector2(1.4, 1.4), "height": 1.3},
	"work_table": {"size": Vector2(2.4, 1.8), "height": 0.74},
	"dining_set": {"size": Vector2(1.4, 2.0), "height": 0.9},
	"kitchen": {"size": Vector2(3.0, 0.65), "height": 2.15},
	"cubicles": {"size": Vector2(2.7, 1.6), "height": 2.0},
	"printer_cart": {"size": Vector2(0.8, 0.55), "height": 1.0},
	# The two-shelf cart with the set on it (Television_01), in the break room and the boardroom.
	"tv_cart": {"size": Vector2(0.8, 0.55), "height": 1.5},
	"whiteboard": {"size": Vector2(1.5, 0.6), "height": 1.9},
	"bin_floor": {"size": Vector2(0.45, 0.45), "height": 0.66},
	"plant_floor": {"size": Vector2(0.5, 0.5), "height": 1.3},
	"bench_slat": {"size": Vector2(1.5, 0.4), "height": 0.5},
	"air_desk": {"size": Vector2(1.5, 1.4), "height": 1.3},
	# The reception's front desk with the walnut wall behind it, its back to that
	# wall (office_props.front_desk()): straight, not the L it was, so it fits
	# the small receptions too.
	"reception_counter_l": {"size": Vector2(3.4, 1.7), "compact": Vector2(2.9, 1.42), "height": 2.15},
	"waiting_row_4": {"size": Vector2(3.2, 0.8), "height": 0.9},
	"office_suite": {"size": Vector2(2.0, 2.7), "height": 1.3},
	"meeting_table_s": {"size": Vector2(3.6, 1.85), "height": 0.9},
	"meeting_table_m": {"size": Vector2(4.2, 1.85), "height": 0.9},
	"meeting_table_l": {"size": Vector2(4.8, 1.85), "height": 0.9},
	"table_chair": {"size": Vector2(0.6, 0.6), "height": 0.9},
	"locker_bank": {"size": Vector2(2.7, 0.5), "height": 1.9},
	"fan_unit": {"size": Vector2(1.5, 1.2), "height": 1.6},
}
## The boardroom's tables, the longest first (office_generator.lay_table()).
const TABLE_KINDS := ["meeting_table_l", "meeting_table_m", "meeting_table_s"]
## The corner pieces' real footprints (spec_proporcion D3): [width, depth, back],
## back the local z where the piece starts, at rotation 0 round its socket: what
## office_props.build() draws (area 4c; the plant centred on the socket, the
## basin against its tiled wall), or prop_factory for the hotel's kinds (bin and
## cart, centred). The boxes' row holds the ladder and the work light of the
## store and the depot.
const CORNER_SIZES := {
	"reception": [2.24, 1.14, -0.7],
	"shelf": [2.0, 0.4, -0.7],
	"coat_rack": [1.22, 0.5, -0.75],
	"bench": [1.5, 0.45, -0.7],
	"sideboard": [1.8, 0.48, -0.7],
	"table": [1.6, 0.9, -0.7],
	"board": [1.5, 0.6, -0.7],
	"projector": [0.8, 0.5, -0.7],
	"cooler": [0.34, 0.34, -0.7],
	"fridge": [0.6, 0.65, -0.7],
	"cabinet": [1.0, 0.5, -0.7],
	"gun_rack": [1.0, 0.45, -0.7],
	"boxes": [2.2, 0.6, -0.7],
	"plant": [0.55, 0.55, -0.275],
	"bin": [0.5, 0.5, -0.25],
	"basin": [0.55, 0.45, -1.198],
	"cart": [1.35, 0.75, -0.375],
	"desk": [1.5, 1.4, -0.7],
	"filing": [1.0, 0.62, -0.7],
	"chairs": [1.74, 0.6, -0.7],
	"armchair": [2.3, 1.4, -0.7],
	"copier": [1.1, 0.7, -0.7],
	"reader": [1.4, 1.3, -0.7],
	"sorter": [1.8, 0.4, -0.7],
	"vending": [0.9, 0.8, -0.7],
}
## What office_recipes.gd lays in each furnished type, in order (spec_rediseno
## 6): [kind, how, least, most, row]. how: "lattice" (lay_lattice(): desk
## pairs, cubicle pods) or "table" (lay_table()) in the generator; "back",
## against the feature wall alone; "wall", against it or else another free
## wall; "side", against another free wall or else it; "middle", standing free
## toward it; "closed", against a wall with no door nor lift; "spare", as "side",
## but where it may not fit, so no test requires it; "run", joined to the room's
## last wall run, or else as "wall" (lay_run()); "center", the middle of the
## feature wall, where a pair of CENTER_FLANKS fits beside it, or else as "wall"
## (lay_center()); "hall", by lay_halls(), a
## corridor's. From least to most runs, drawn; row pieces side by side in a run.
const ROOM_FURNITURE := {
	# The desk, a big plant by it and the waiting row on beyond, the second
	# plant closing the row: what the first view takes in (the author, 12 November 2026).
	RECEPTION: [["reception_counter_l", "wall", 1, 1, 1], ["waiting_row_4", "side", 1, 1, 1], ["plant_floor", "run", 1, 1, 1], ["plant_floor", "spare", 1, 1, 1], ["bin_floor", "spare", 1, 1, 1], ["waiting_row", "spare", 0, 0, 1]],
	OPEN_OFFICE: [["desk_pair", "lattice", 1, 1, 1], ["filing", "spare", 1, 2, 2], ["printer_cart", "spare", 1, 1, 1], ["plant_floor", "spare", 1, 2, 1], ["bin_floor", "spare", 1, 1, 1]],
	CUBICLES: [["desk", "lattice", 1, 1, 1], ["filing", "spare", 1, 2, 2], ["plant_floor", "spare", 1, 1, 1], ["bin_floor", "spare", 1, 1, 1]],
	OFFICE: [["office_suite", "center", 1, 1, 1], ["filing", "run", 1, 2, 2], ["bookcase", "run", 1, 1, 1], ["plant_floor", "run", 1, 1, 1], ["card_index", "spare", 1, 1, 1], ["bin_floor", "spare", 1, 1, 1], ["wood_shelving", "spare", 1, 1, 1], ["filing", "spare", 1, 1, 1], ["printer_cart", "spare", 0, 1, 1]],
	TOILETS: [["cubicles", "wall", 1, 1, 1], ["locker_bank", "run", 1, 1, 1], ["locker_bank", "spare", 1, 1, 1], ["bench_slat", "middle", 1, 1, 1], ["bin_floor", "spare", 1, 1, 1]],
	BOARDROOM: [["meeting_table_s", "table", 1, 1, 1], ["whiteboard", "wall", 1, 1, 1], ["plant_floor", "run", 1, 1, 1], ["sideboard", "side", 1, 1, 1], ["sideboard", "run", 1, 1, 1], ["wood_shelving", "spare", 1, 1, 1], ["plant_floor", "spare", 1, 1, 1], ["waiting_row", "spare", 1, 1, 1], ["bin_floor", "spare", 1, 1, 1], ["tv_cart", "spare", 1, 1, 1]],
	COPY_ROOM: [["copier", "back", 1, 1, 1], ["copier", "side", 1, 1, 1], ["reader_table", "run", 1, 1, 2], ["work_table", "middle", 1, 1, 1], ["card_index", "side", 1, 1, 1], ["wood_shelving", "spare", 1, 1, 1], ["printer_cart", "spare", 1, 1, 1], ["cart_boxes", "spare", 1, 1, 1], ["bin_floor", "spare", 1, 1, 1], ["filing", "spare", 1, 1, 2]],
	STORE: [["shelving", "side", 1, 2, 1], ["cart_boxes", "middle", 0, 1, 1], ["shelving", "spare", 1, 2, 1]],
	MAIL: [["pigeonholes", "wall", 1, 1, 3], ["pigeonholes", "run", 1, 1, 2], ["pigeon_counter", "middle", 1, 1, 1], ["mail_cart", "spare", 1, 1, 3], ["printer_cart", "spare", 1, 1, 1], ["filing", "run", 1, 1, 2], ["sorting_table", "middle", 0, 1, 1], ["bin_floor", "spare", 1, 1, 1], ["cart_boxes", "spare", 1, 1, 1]],
	BREAK_ROOM: [["kitchen", "wall", 1, 1, 1], ["vending", "run", 1, 1, 1], ["plant_floor", "run", 1, 1, 1], ["dining_set", "middle", 3, 4, 1], ["filing", "spare", 1, 1, 2], ["work_desk", "spare", 0, 1, 1], ["plant_floor", "spare", 1, 1, 1], ["bin_floor", "spare", 1, 1, 1], ["tv_cart", "spare", 1, 1, 1]],
	EXEC_OFFICE: [["exec_desk", "center", 1, 1, 1], ["bookcase", "run", 2, 2, 1], ["sideboard", "run", 1, 1, 1], ["plant_floor", "run", 1, 1, 1], ["lounge", "side", 1, 1, 1], ["sideboard", "spare", 1, 1, 1], ["filing", "spare", 1, 1, 1], ["plant_floor", "spare", 1, 1, 1], ["bin_floor", "spare", 1, 1, 1]],
	WINDOW: [["filing", "run", 2, 2, 3], ["work_table", "run", 1, 1, 1], ["wood_shelving", "side", 1, 1, 1], ["work_desk", "spare", 1, 1, 1], ["bin_floor", "spare", 1, 1, 1], ["filing", "spare", 1, 1, 3], ["cart_boxes", "spare", 1, 1, 1]],
	ELECTRICAL: [["work_desk", "side", 1, 1, 1], ["shelving", "spare", 1, 1, 2], ["cart_boxes", "run", 2, 2, 1], ["work_table", "spare", 1, 1, 1], ["filing", "spare", 1, 1, 2], ["bin_floor", "spare", 1, 1, 1]],
	SECURITY: [["filing", "run", 1, 1, 3], ["work_desk", "spare", 1, 1, 1], ["wood_shelving", "spare", 1, 2, 1], ["filing", "spare", 1, 1, 2], ["waiting_row", "spare", 1, 1, 1], ["bin_floor", "spare", 1, 1, 1], ["card_index", "spare", 1, 1, 1]],
	SECRETARY: [["secretary_desk", "wall", 1, 1, 1], ["filing", "run", 1, 1, 3], ["plant_floor", "run", 1, 1, 1], ["printer_cart", "side", 1, 1, 1], ["waiting_row", "spare", 1, 1, 1], ["pigeonholes", "spare", 1, 1, 1], ["bin_floor", "spare", 1, 1, 1], ["filing", "spare", 1, 1, 2], ["card_index", "spare", 1, 1, 1]],
	DEPOT: [["shelving", "side", 1, 2, 1], ["cart_boxes", "middle", 0, 1, 1], ["shelving", "spare", 1, 2, 1]],
	LOBBY: [["filing", "closed", 1, 1, 2], ["bin_floor", "spare", 1, 1, 1], ["plant_floor", "spare", 1, 1, 1], ["bench_slat", "spare", 1, 1, 1]],
	REFUGE: [["filing", "closed", 1, 1, 2], ["bin_floor", "spare", 1, 1, 1], ["plant_floor", "spare", 1, 1, 1], ["bench_slat", "spare", 1, 1, 1]],
	AIR_ROOM: [["fan_unit", "wall", 2, 3, 1], ["work_table", "middle", 1, 1, 1], ["air_desk", "spare", 1, 1, 1], ["shelving", "spare", 1, 1, 1], ["cart_boxes", "spare", 1, 1, 1]],
	AIR_PLANT: [["air_desk", "spare", 1, 1, 1]],
	CORRIDOR: [["bin_floor", "hall", 0, 1, 1], ["bench_slat", "hall", 0, 1, 1], ["plant_floor", "hall", 0, 1, 1]],
}
## A nave's islands, the most desks first, and what stands against an island's
## ends in its group (office_generator.lay_islands()), all under 1.3 m.
const ISLAND_KINDS := ["desk_island_6", "desk_island", "desk_pair"]
## The plant last: some 10 k triangles each, and the walls end with them.
const ISLAND_ENDS := ["printer_cart", "cart_boxes", "bin_floor", "plant_floor"]
## The islands a nave cell takes at most.
const ISLANDS_MOST := 3
## The kinds a lattice lays (office_generator.lay_lattice()): an open office's
## desk pairs, or single desks where they seat more than the pairs, and in a
## nave its islands with their ends; the cubicles' pods; in both, a nave's rows
## against its closed walls (NAVE_WALL_ROW).
const LATTICE_KINDS := {OPEN_OFFICE: ["desk_island_6", "desk_island", "desk_pair", "desk", "partition", "printer_cart", "plant_floor", "cart_boxes", "bin_floor", "filing", "wood_shelving", "card_index", "shelving"], CUBICLES: ["desk", "partition", "desk_island_6", "desk_island", "desk_pair", "printer_cart", "plant_floor", "cart_boxes", "bin_floor", "filing", "wood_shelving", "card_index", "shelving"]}
## What fills a nave cell's closed walls end to end (the director, 12 November
## 2026: the references' rows of cabinets against the wall), in turn, a plant
## at the end of a row; none deeper than NAVE_WALL_DEPTH with its gap.
## No card index: some 6 k triangles each (dens6).
const NAVE_WALL_ROW := ["filing", "wood_shelving", "filing", "printer_cart", "filing", "shelving"]
const NAVE_WALL_DEPTH := 0.7
## What flanks a piece laid "center" (office_recipes.lay_center()): the director's
## desk between two bookcases, as in its reference (spec_proporcion D7); an
## office's between its filing cabinets, in sight from its door.
const CENTER_FLANKS := {"exec_desk": "bookcase", "office_suite": "filing"}
## The corner pieces (RECIPES) a type's furniture stands in for, each with the
## piece of its recipe that does: they come back only where it was not laid
## (office_recipes.restore()); "", a corner that always
## gives way (an unbuilt one, for room). Never a desk or a table, where papers
## are put (document_placement.SURFACES).
const CORNERS_REPLACED := {RECEPTION: {"reception": "reception_counter_l", "chairs": "waiting_row_4"}, OPEN_OFFICE: {"filing": ""}, CUBICLES: {"filing": ""}, OFFICE: {"filing": "filing"}, BOARDROOM: {"sideboard": "sideboard", "board": "whiteboard"}, LOBBY: {"bin": "bin_floor"}, REFUGE: {"bin": "bin_floor"}, COPY_ROOM: {"copier": "copier", "reader": "reader_table"}, MAIL: {"sorter": "pigeonholes"}, BREAK_ROOM: {"vending": "vending"}, WINDOW: {"filing": "filing"}, SECURITY: {"filing": "filing"}, SECRETARY: {"filing": "filing"}, EXEC_OFFICE: {"armchair": "lounge"}}
## The recipe pieces tried first where the corner they stand in for
## (CORNERS_REPLACED) stood (office_recipes.lay_corner(), spec_4e D).
const IN_ITS_CORNER := ["lounge"]
## The corner a paper is put on (document_placement.SURFACES) that a type keeps
## before its recipe is laid, so the recipe lays round it (spec_4e E): the types
## each planta must have (MUSTS) that have one in RECIPES.
const PAPER_TOPS_KEPT := {BREAK_ROOM: "table", MAIL: "table", SECRETARY: "desk"}
## The wall each type is framed by and furnished against first (spec_rediseno
## 6; office_recipes.feature_of(), office_rooms_capture.gd): "far", the closed
## wall farthest from its main door; "suite", the wall of its door to a
## director's office; "window", "board", "console", "unit": the wall of the
## window's desk, the electrical board, the security post's console, the air
## handler; "lift", the wall its car stands behind. Each falls back to "far".
## A type not here has none, and its capture looks straight in. The types of
## FEATURE_FIRST_PIECE end up with another (office_generator.furnish_furniture()).
const FEATURE_WALLS := {RECEPTION: "far", OPEN_OFFICE: "far", CUBICLES: "far", OFFICE: "far", TOILETS: "far", BOARDROOM: "far", COPY_ROOM: "far", STORE: "far", LANDING: "lift", LOBBY: "lift", MAIL: "far", BREAK_ROOM: "far", EXEC_OFFICE: "far", WINDOW: "window", ELECTRICAL: "board", REFUGE: "lift", SECURITY: "console", AIR_ROOM: "far", AIR_PLANT: "unit", SECRETARY: "suite", DEPOT: "far"}
## The types that end up framed by the wall their first piece against a wall
## landed on, whichever the rule above tried first.
const FEATURE_FIRST_PIECE := [RECEPTION, OFFICE, TOILETS, COPY_ROOM, STORE, MAIL, BREAK_ROOM, SECRETARY, DEPOT]
## The pieces a salon of a type has once, in its head cell (office_recipes
## hall_heads()): a director's desk. Salons are open offices, cubicles, archives
## and directors' offices only (HALL_MIX): no other one-desk type takes one.
const ONE_PER_HALL := {EXEC_OFFICE: ["exec_desk"]}
## The filing cabinets' finish by type (spec_rediseno 6; office_props.gd):
## mint at the window, grey in an office and the security post, beige at the
## secretary's; olive elsewhere.
const FILING_FINISH := {RECEPTION: "plastic_beige", OFFICE: "steel_grey", WINDOW: "steel_mint", SECURITY: "steel_grey", SECRETARY: "plastic_beige"}
## Nothing stands this deep before a glazed wall (spec_rediseno 3.6) but the
## corner pieces under its sill (0.95 m).
const GLASS_CLEAR := 0.6
const GLASS_LOW := ["desk", "table", "sideboard", "bench", "bin", "chairs", "armchair"]
## The share of the doors of lit rooms that stand open (spec_rediseno 3.6).
const OPEN_LIT := 0.6
## The types a secretary's office may swap with to stand beside a director's
## (office_generator.suites()): the plain rooms of the third planta, and a
## director's office with a door to another.
const SUITE_SWAP := [TOILETS, STORE, BREAK_ROOM, EXEC_OFFICE]

## What hangs on a type's walls, in order (spec_rediseno 2 and 6, area 4c;
## office_walls.gd): [piece, how many, its RULE_TEXTS for a "rule"]. The first
## is tried on the room's feature wall first.
const WALL_DRESSING := {
	# Framed prints, the clock and the directory: no rule, plan nor extinguisher in the floor's first view.
	RECEPTION: [["picture_large", 1, 0], ["map", 1, 0], ["picture", 2, 0], ["clock", 1, 0], ["directory", 1, 0], ["socket", 2, 0]],
	OPEN_OFFICE: [["notice", 3, 0], ["clock", 1, 0], ["picture", 3, 0], ["rule", 1, 1], ["plan", 1, 0], ["hooks", 1, 0], ["extinguisher", 1, 0], ["thermostat", 1, 0], ["alarm", 1, 0], ["socket", 2, 0]],
	CUBICLES: [["notice", 2, 0], ["clock", 1, 0], ["picture", 2, 0], ["rule", 1, 1], ["plan", 1, 0], ["extinguisher", 1, 0], ["thermostat", 1, 0], ["socket", 2, 0]],
	OFFICE: [["picture_large", 1, 0], ["diplomas", 1, 0], ["notice", 1, 0], ["picture", 3, 0], ["clock_square", 1, 0], ["hooks", 1, 0], ["thermostat", 1, 0], ["socket", 1, 0]],
	TOILETS: [["hooks", 2, 0], ["rule", 1, 4], ["notice", 1, 0], ["extinguisher", 1, 0]],
	BOARDROOM: [["screen", 1, 0], ["map", 1, 0], ["picture", 4, 0], ["clock", 1, 0], ["notice", 1, 0], ["thermostat", 1, 0], ["socket", 2, 0]],
	COPY_ROOM: [["rule", 1, 5], ["rule", 1, 6], ["rule", 1, 7], ["notice", 2, 0], ["clock", 1, 0], ["plan", 1, 0], ["extinguisher", 1, 0], ["socket", 2, 0]],
	STORE: [["notice", 1, 0], ["rule", 1, 0], ["extinguisher", 1, 0]],
	DEPOT: [["notice", 1, 0], ["rule", 1, 0], ["extinguisher", 1, 0]],
	ELECTRICAL: [["notice", 1, 0], ["extinguisher", 1, 0]],
	AIR_ROOM: [["notice", 1, 0], ["thermostat", 1, 0], ["extinguisher", 1, 0]],
	LOBBY: [["notice", 1, 0], ["directory", 1, 0], ["plan", 1, 0], ["extinguisher", 1, 0], ["alarm", 1, 0]],
	REFUGE: [["notice", 1, 0], ["plan", 1, 0], ["extinguisher", 1, 0]],
	MAIL: [["central", 1, 0], ["clock", 1, 0], ["notice", 2, 0], ["plan", 1, 0], ["picture", 1, 0], ["extinguisher", 1, 0], ["socket", 1, 0]],
	BREAK_ROOM: [["notice", 2, 0], ["clock", 1, 0], ["picture", 3, 0], ["rule", 1, 4], ["plan", 1, 0], ["thermostat", 1, 0], ["socket", 2, 0]],
	EXEC_OFFICE: [["map_large", 1, 0], ["picture", 4, 0], ["diplomas", 2, 0], ["clock_square", 1, 0], ["thermostat", 1, 0], ["socket", 1, 0]],
	WINDOW: [["notice", 2, 0], ["clock", 1, 0], ["plan", 1, 0], ["picture", 1, 0]],
	SECURITY: [["keys", 1, 0], ["notice", 2, 0], ["clock", 1, 0], ["plan", 1, 0], ["picture", 1, 0], ["extinguisher", 1, 0], ["alarm", 1, 0]],
	SECRETARY: [["clock_square", 1, 0], ["picture", 4, 0], ["notice", 1, 0], ["diplomas", 1, 0], ["thermostat", 1, 0], ["socket", 1, 0]],
}
## The rule signs (docs/OFICINAS.md 9, spec_rediseno 6), a row to a line.
const RULE_TEXTS := ["MANTENGA ENCENDIDAS\nLAS LUCES\nDE LOS PASILLOS", "NO TRABAJE\nDE ESPALDAS\nA LA PUERTA", "NO SE QUEDE SOLO\nEN EL ARCHIVO", "LAS REJILLAS\nNO SE ABREN", "MANTENGA\nEL ORDEN\nY LA LIMPIEZA", "REPROGRAFÍA", "FOTOCOPIAS\nPLANOS\nMICROFICHAS\nENCUADERNACIÓN", "USO LECTOR DE MICROFICHAS\n1. ENCIENDA EL LECTOR\n2. COLOQUE LA FICHA\n3. AJUSTE EL FOCO\n4. APAGUE AL TERMINAR"]
## The corridors' fittings (office_walls.gd): one at every CORRIDOR_PITCH
## metres of the building's grid along each wall, in this order, each wall of
## a cell starting at its own quarter of it.
const CORRIDOR_RHYTHM := ["picture", "alarm", "clock", "extinguisher", "picture", "socket", "plan", "hose", "picture", "fountain", "rule", "thermostat"]
## Every 2 m: at 3 the corridors' walls read bare (the author, 12 November 2026).
const CORRIDOR_PITCH := 2.0
## How tall each corner piece (RECIPES) stands, for what hangs on the wall
## behind it (office_walls.gd); 2.2 for any not here (the basin's mirror too).
## With what stands on or by it: the sideboard with the director's globe, the
## boxes with the work light, the reader with its microfiche reader; the plant
## is the secretary's tall one.
const CORNER_HEIGHT := {"reception": 1.1, "bench": 0.45, "sideboard": 1.3, "table": 0.84, "desk": 0.95, "chairs": 0.95, "armchair": 1.6, "bin": 0.64, "boxes": 1.5, "filing": 1.32, "cooler": 1.45, "fridge": 1.6, "projector": 1.55, "coat_rack": 1.85, "plant": 1.85, "reader": 1.3, "cart": 1.16, "copier": 1.05}
## Either side of a floor system's spot on a wall, nothing else hangs
## (office_walls.gd, LAYOUT.fixtures()): the electrical board with its supply
## box and memo, the security post's desk, the air handler; 0.9 elsewhere.
const FIXTURE_HALF := {ELECTRICAL: 2.2, SECURITY: 1.1, AIR_PLANT: 1.7}
## The chairs of a type's waiting row and of its corner "chairs"
## (office_props.gd, office_models.gd); the stacking chair elsewhere.
const WAITING_CHAIR := {RECEPTION: "reception_seat", WINDOW: "waiting_chair", SECRETARY: "visitor_chair"}

## The floor as it is seen (office_geometry.floor_surface()): Dirección's
## carpet shows polished vinyl round its rug (rug_of()); how it sounds is
## floor_finish()'s still (hard_floor()).
static func floor_look(room: Dictionary) -> String:
	var finish := floor_finish(room)
	# The reception's vinyl polished, giving back its lights (its reference).
	if int(room.type) == RECEPTION and finish == "vinyl": return "vinyl_polished"
	return "vinyl" if finish == "carpet_exec" else finish

## What is left on a room's floor, by its type (office_clutter.litter()): the
## stores' tools, an office's shoes and cord, the mousetraps.
const LITTER_KINDS := {STORE: ["toolbox", "broom", "mousetrap"], DEPOT: ["toolbox", "broom", "mousetrap"], OFFICE: ["shoes", "cord_floor"], OPEN_OFFICE: ["cord_floor", "shoes"], CUBICLES: ["cord_floor"], BREAK_ROOM: ["mousetrap", "broom"], ARCHIVE: ["mousetrap", "toolbox"]}
static func litter_of(room: Dictionary) -> Array:
	return LITTER_KINDS.get(int(room.type), [])

## The rug of a room (office_fittings.gd): "persian" in the director's and the
## secretary's offices of wing 2, "plain" in its boardroom, "mat" inside the
## reception's door; "" none.
static func rug_of(room: Dictionary) -> String:
	var room_type := int(room.type)
	if floor_finish(room) == "carpet_exec": return "plain" if room_type == BOARDROOM else "persian"
	if room_type == RECEPTION: return "mat"
	return ""

## A corridor's floor furniture (office_recipes.lay_halls()): in one this wide or
## more, a piece no deeper than HALL_DEPTH every HALL_STEP metres along a wall,
## leaving HALL_PASS to walk and HALL_SIGN_CLEAR each side of where the zone sign
## may be.
const HALL_KINDS := ["bin_floor", "bench_slat", "plant_floor"]
const HALL_WIDTH := 3.0
const HALL_DEPTH := 0.5
const HALL_STEP := Vector2(5.0, 8.0)
const HALL_PASS := 2.0
const HALL_SIGN_CLEAR := 0.7

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

## Hard underfoot: everything but carpet, either scan of it.
static func hard_floor(room: Dictionary) -> bool:
	return not (floor_finish(room) in ["carpet", "carpet_exec"])

## The floor's material (FINISHES).
static func floor_finish(room: Dictionary) -> String:
	var room_type := int(room.type)
	var wing := int(room.get("wing", 0))
	# Wing 2's carpet is the director's own scan (carpet_exec); the naves' is carpet.
	if room_type in CARPET and wing == 2: return "carpet_exec"
	if room_type in NAVE_CARPET and wing == 0: return "carpet"
	return String(FINISH_BY_TYPE[room_type])

## Whether a cell is one a type wants (ROOM_BANDS).
static func fits_band(room_type: int, room: Dictionary) -> bool:
	var band: Array = ROOM_BANDS.get(room_type, [])
	if band.is_empty(): return true
	var short_side := minf(float(room.span_x), float(room.span_z))
	var long_side := maxf(float(room.span_x), float(room.span_z))
	if float(band[0]) > 0.0 and short_side < float(band[0]) - 0.001: return false
	if float(band[1]) > 0.0 and short_side > float(band[1]) + 0.001: return false
	if float(band[2]) > 0.0 and long_side < float(band[2]) - 0.001: return false
	return float(band[3]) <= 0.0 or long_side <= float(band[3]) + 0.001

## A corner piece's plan rect in its cell, from its socket and turn (the basis
## hotel_geometry.prop_transform() gives it: a quarter takes local (x, z) to (z, -x)).
static func corner_rect(kind: String, socket: Array, rotation: int) -> Rect2:
	var spec: Array = CORNER_SIZES[kind]
	var wide: float = spec[0]
	var deep: float = spec[1]
	var back: float = spec[2]
	var at := Vector2(float(socket[0]), float(socket[1]))
	match rotation % 4:
		0: return Rect2(at.x - wide * 0.5, at.y + back, wide, deep)
		1: return Rect2(at.x + back, at.y - wide * 0.5, deep, wide)
		2: return Rect2(at.x - wide * 0.5, at.y - back - deep, wide, deep)
	return Rect2(at.x - back - deep, at.y - wide * 0.5, deep, wide)

## The walls' material (WALLS): the director's walnut veneer, the copy room's
## demountable partition, block where the building shows, the greige vinyl
## wallcovering elsewhere, kept clean in the reception (the floor's first view).
static func wall_material(room: Dictionary) -> String:
	var room_type := int(room.type)
	if room_type == RECEPTION: return "office_paint_kept"
	if room_type == EXEC_OFFICE and int(room.get("wing", 0)) == 2: return "veneer"
	if room_type == COPY_ROOM: return "partition"
	return "block" if room_type in BLOCK_WALLS else "office_paint"

## The lower wall of a room (TRIMS).
static func wall_trim(room: Dictionary) -> String:
	var room_type := int(room.type)
	if room_type == SECRETARY: return "panel_wall"
	if room_type in FRIEZE_ROOMS: return "frieze"
	if room_type in DADO_ROOMS: return "dado"
	if room_type in TWO_TONE_ROOMS: return "two_tone"
	return ""

## The rooms The Lurker's lies use (spec_f3_integration 4.3): where a phone
## could ring, keys be struck, a copier start.
static func has_phone(room: Dictionary) -> bool: return int(room.type) in [OFFICE, EXEC_OFFICE, SECRETARY]
static func has_typewriter(room: Dictionary) -> bool: return int(room.type) in [OFFICE, EXEC_OFFICE, WINDOW, SECRETARY]
static func has_copier(room: Dictionary) -> bool: return int(room.type) == COPY_ROOM

## Whether a room can have its lamps out: salons too ("zonas apagadas").
static func may_be_dark(room: Dictionary) -> bool:
	return not int(room.type) in NEVER_DARK

## The lamp on a room's ceiling (LAMPS): the electrical room and the void only
## the emergency unit; the boardroom has troffers like any office.
static func lamp_of(room: Dictionary) -> String:
	var room_type := int(room.type)
	if room_type == ELECTRICAL or room_type == VOID: return "emergency"
	return "batten" if room_type in BATTEN_ROOMS else "troffer"

## A room's lamp colour temperature (LAMP_KELVIN).
static func lamp_kelvin(room: Dictionary) -> float:
	return float(LAMP_KELVIN[int(room.type)])

## A room's troffer family (TROFFER_LOOKS).
static func troffer_look(room: Dictionary) -> String:
	var room_type := int(room.type)
	if room_type in NARROW_TROFFERS: return "narrow"
	if room_type in PARABOLIC_TROFFERS: return "parabolic"
	if room_type in WRAP_TROFFERS: return "wrap"
	return "prismatic"

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
## columns (i), ascending; none within COLUMN_TILE of a column (spec_rediseno 9).
static func free_tiles(room: Dictionary) -> Array[Vector2i]:
	var rect := ceiling_rect(room)
	var tiles := full_tiles(room)
	var open: Array = room.get("open_sides", [])
	var walled := int(room.type) != CORRIDOR
	var taken := {}
	var centres: Array = []
	var posts := column_rects(room)
	# In a nave (its islands, the director's 12 November): none over the furniture
	# or a corner piece, its floor and a body round it free, so she lands in a street.
	var under: Array[Rect2] = []
	if int(room.type) in [OPEN_OFFICE, CUBICLES] and not aisle_strips(room).is_empty():
		var middle := Vector2(float(room.px), float(room.pz))
		for it in room.get("furniture", []):
			var size := Vector2(float(it.size[0]), float(it.size[1]))
			if int(it.turn) % 2 == 1: size = Vector2(size.y, size.x)
			under.append(Rect2(middle + Vector2(float(it.at[0]), float(it.at[1])) - size / 2, size).grow(TILE / 2 + 0.3))
		var sockets: Array = room.get("sockets", [])
		for prop in room.get("props", []):
			if int(prop.slot) < sockets.size():
				var r := corner_rect(String(prop.kind), sockets[int(prop.slot)], int(prop.rotation))
				under.append(Rect2(r.position + middle, r.size).grow(TILE / 2 + 0.3))
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
			var by_column := false
			for post in posts:
				var nearest := Vector2(clampf(centre.x, post.position.x, post.end.x), clampf(centre.y, post.position.y, post.end.y))
				if centre.distance_to(nearest) < COLUMN_TILE:
					by_column = true
					break
			if by_column: continue
			if under.any(func(r: Rect2) -> bool: return r.has_point(centre)): continue
			if walled:
				if not open.has("west") and centre.x - rect.position.x < GRILLE_WALL: continue
				if not open.has("east") and rect.end.x - centre.x < GRILLE_WALL: continue
				if not open.has("north") and centre.y - rect.position.y < GRILLE_WALL: continue
				if not open.has("south") and rect.end.y - centre.y < GRILLE_WALL: continue
			out.append(tile)
	return out

## A room's columns in world x and z, each a COLUMN square (room.columns:
## {x, z} from the cell's centre, in every cell a column stands in).
static func column_rects(room: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for c in room.get("columns", []):
		var centre := Vector2(float(room.px) + float(c.x), float(room.pz) + float(c.z))
		out.append(Rect2(centre - Vector2.ONE * COLUMN * 0.5, Vector2.ONE * COLUMN))
	return out

## A nave cell's half of the central aisle, in the cell's own x and z: along
## the seam to the nave's other row (spec_rediseno 3.3); none in a line or an L.
static func aisle_strips(room: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var half := Vector2(float(room.span_x), float(room.span_z)) * 0.5
	var aisle := NAVE_AISLE * 0.5
	var open: Array = room.get("open_sides", [])
	match String(room.get("nave_axis", "")):
		"x":
			if open.has("north"): out.append(Rect2(-half.x, -half.y, half.x * 2.0, aisle))
			if open.has("south"): out.append(Rect2(-half.x, half.y - aisle, half.x * 2.0, aisle))
		"z":
			if open.has("west"): out.append(Rect2(-half.x, -half.y, aisle, half.y * 2.0))
			if open.has("east"): out.append(Rect2(half.x - aisle, -half.y, aisle, half.y * 2.0))
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
