extends RefCounted
## The hotel's rooms (docs/OFICINAS.md 11.2, Paletas): what each type of room
## is called and has in it, how it is built, lit and dressed, and the plan a
## planta of the hotel is drawn by. Every number of a room type of floor 1 is
## here: the rest of the game asks (hard_floor(), lamp_of(), label()...) or
## reads these tables through a palette, never a number of its own
## (tests/hotel/palette_scan_test.gd). A floor of another kind has a palette
## with every name this one has; FLOOR.palette() picks a manifest's. It
## preloads nothing: floor_definition.gd preloads it, and the generator and
## the validator load it headless.

## Structural roles: the same number in every palette.
const RECEPTION := 0
const LANDING := 9
const LOBBY := 10
const CORRIDOR := 11
const GALLERY := 12
const REFUGE := 19

## A cell of the grid a planta does not use: nothing is built there, nobody
## walks there. It stays in the list so a room's id is still its index.
const VOID := 20

## The room the generator turns into a television room when a planta has too
## few sets, and the salon that is never found kept (map_generator.finish(),
## light_rooms()).
const TV_ROOM := 14
const EMPTY_SALON := 18

## How much hotel each planta is, by the survivors who play the floor (the
## author, 20 October 2026): alone, half of what two or three walk; four, a
## fifth more; five, a third more. Counted when the floor starts: nobody joins
## once it has begun, and whoever drops does not shrink it. In versus the
## hunter is not counted. What four and five have over the rest is corridor,
## service and salons more than rooms let to somebody: a planta's numbers are
## its hundred, and a hundred has room for 99 (NUMBERED_MOST).
const AREA := {1: 0.5, 4: 1.2, 5: 1.35}
## Rooms on a planta of the hotel of two or three, as the generator counts
## them (every room, salon, service room and refuge; a salon once), scaled
## with the area for the others; and the rooms with a number on the door, at
## the most, whatever the size.
const ROOMS := Vector2i(81, 99)
const NUMBERED_MOST := 96

static func area_for(survivors: int) -> float:
	return float(AREA.get(clampi(survivors, 1, 5), 1.0))

## Each planta's, first to last. Alone, the first planta is still the hotel
## of two or three (the author, 20 October 2026): only the two below it are
## half of it.
static func areas_for(survivors: int) -> Array:
	var area := area_for(survivors)
	return [1.0 if clampi(survivors, 1, 5) == 1 else area, area, area]

static func rooms_window(area: float) -> Vector2i:
	return Vector2i(roundi(float(ROOMS.x) * area), roundi(float(ROOMS.y) * area))

## Rooms with a television on the plantas of the second and third stages
## (their condition asks for as many sets as there are survivors, plus two),
## and the rings a planta keeps to walk round: fewer on a planta half the size.
static func tv_rooms(area: float) -> int:
	return 6 if area < 1.0 else 8

static func rings(area: float) -> int:
	return 4 if area < 1.0 else 6

## Wardrobes per module type: bedrooms and the cloakroom get two, a few
## private rooms get one, corridors, halls and public spaces none.
const WARDROBES := {1: 2, 2: 2, 3: 2, 16: 2, 13: 1, 14: 1, 15: 1, 8: 1}
## Tiled floors (baths, laundry, maintenance); every other module is carpeted.
const HARD_FLOORS := [4, 7, 9]
const TYPES := ["recepcion", "habitacion_doble", "habitacion_simple", "suite", "bano", "salon", "comedor", "lavanderia", "almacen", "mantenimiento", "vestibulo", "pasillo", "galeria", "sala_lectura", "sala_tv", "oficina", "guardarropa", "sala_plantas", "salon_vacio", "refugio", "vacio"]
const NAMES := ["Recepción", "Habitación doble", "Habitación", "Suite", "Baños", "Salón", "Comedor", "Lavandería", "Almacén", "Mantenimiento", "Vestíbulo", "Pasillo", "Galería", "Sala de lectura", "Sala de televisión", "Oficina", "Guardarropa", "Jardín interior", "Salón vacío", "Refugio", "Vacío"]

## The article each type's name takes on a paper: «la recepción», «el
## almacén» (hint_placement.room_said()).
const ARTICLES := ["la", "la", "la", "la", "los", "el", "el", "la", "el", "el", "el", "el", "la", "la", "la", "la", "el", "el", "el", "el", "el"]

# Each corner is a reserved furnishing socket; the central cross remains clear.
const RECIPES := [
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
]

## How tall a room is (map_generator.finish()): a salon of several modules
## HALL_HEIGHT, whatever it is; any other by its type: the reception, the
## lounge, the dining room, the indoor garden and the empty salon 4.2, the
## rest 3.15.
const HEIGHTS := [4.2, 3.15, 3.15, 3.15, 3.15, 4.2, 4.2, 3.15, 3.15, 3.15, 3.15, 3.15, 3.15, 3.15, 3.15, 3.15, 3.15, 4.2, 4.2, 3.15, 3.15]
const HALL_HEIGHT := 4.8
## Rooms whose lamps are never out (may_be_dark()): the reception, the baths,
## laundry and service rooms, the lift lobbies, the refuge and the void.
const NEVER_DARK := [0, 4, 7, 8, 9, 10, 19, 20]

## Doors that carry no guest number: reception, circulation, service, the
## refuge and whatever is not there. In a hotel only the rooms let to
## somebody have a plaque.
const NO_NUMBER := [0, 7, 8, 9, 10, 11, 12, 15, 19, 20]
## What a room can be. Where the plan still reads like a hotel it is a guest
## room; where it has come apart it is whatever the place turned into.
const TIDY_ROOMS := [1, 1, 2, 2, 2, 3, 4, 16]
const UNRULY_ROOMS := [2, 3, 4, 5, 6, 13, 14, 16, 17, 18]
const SERVICE_ROOMS := [7, 8, 9, 15]
const HALL_ROOMS := [5, 6, 17, 18]

## Module sizes (a room's side) and the width of a corridor lane, in metres.
const MODULE_SIZES := [12.0, 12.0, 13.0, 13.0, 14.0, 15.0, 16.0]
const LANE_WIDTHS := [3.0, 3.5, 3.5, 4.0]

## Plans for a planta's corridors. Each floor deals one per planta, never the
## same twice; the first planta from the tidier plans, the last from the ones
## that have come apart.
const DECKS := [["spine", "twin", "ring", "comb", "arms"], ["spine", "twin", "blocks", "arms", "rot", "warren"], ["blocks", "warren", "rot", "comb", "ring"]]
## Share of a planta's rooms its corridors grow to serve, by plan: a warren is
## rooms giving on to rooms, blocks are a hotel with a corridor at most doors.
const SERVED := {"spine": 0.4, "twin": 0.45, "ring": 0.45, "comb": 0.55, "blocks": 0.6, "arms": 0.4, "warren": 0.0, "rot": 0.35}
## Plans too alike to share a floor: both are most of the lanes.
const APART := {"blocks": "rot", "rot": "blocks"}

## How much of a hotel each planta still is, before its own drift: it comes
## apart as one goes down, but never in the same direction twice.
const ORDER_BASE := [0.8, 0.6, 0.42]
## How far in the refuge is, as a share of the way to the farthest room of
## its planta, walking: never the deepest room, never near the door.
const DEPTH := Vector2(0.55, 0.9)
## On the first planta further in, and never nearer than FIRST_WALK metres
## walked (scaled with the square root of the planta's size): the stage that
## is only finding the way out was being left in under a minute (the author,
## 20 October 2026).
const FIRST_DEPTH := Vector2(0.65, 0.9)
const FIRST_WALK := 150.0

## Salons on a planta: two or three rooms thrown into one (scaled with the
## size of the floor).
const HALLS := Vector2i(2, 6)

## How much more often rooms open on to each other, by plan: a warren is
## rooms giving on to rooms.
const ROOM_DOORS := {"warren": 1.8, "rot": 1.25}
## Exposed corridors (the author, 20 October 2026: an L of tens of metres with
## no door, the creature met in it, and getting away was hard): a stretch with
## no door on to any room, so with no wardrobe within reach, only the fire
## doors and the corridors that branch off it. The first planta is a hotel and
## has none laid; the second, one of 30 m in half its floors; the last, one of
## 50 m and, where there is a second, another of 35 (metres scaled with the
## square root of the size of the floor), never longer than EXPOSED_LONGEST;
## where the first will not go at its length, a fifth or two fifths shorter.
const EXPOSED := [0.0, 30.0, 50.0]
const EXPOSED_CHANCE := [0.0, 0.5, 1.0]
const SECOND_EXPOSED := 35.0
const EXPOSED_LONGEST := 90.0

## Where a door can stand in the wall of a room, in metres from the middle of
## the wall, either way. A door off the middle leaves that wall its furniture
## on the far side only. Rooms with the domestic alcoves (2.8 m out from the
## middle: hotel_geometry.build_room()) keep it nearer, beside them.
const DOOR_PLACES := [0.0, 0.0, 1.5, -1.5, 2.0, -2.0]
const DOOR_PLACES_DOMESTIC := [0.0, 1.5, -1.5]
const DOMESTIC := [1, 2, 3, 4, 7, 15, 16]

## The dark rooms. Each room that can be dark (may_be_dark()) is on its
## own with DARK_OWN, more the lower the planta; each one that is puts out the
## rooms it opens on to with DARK_SPREAD, so they come in stretches. A
## corridor is the last thing a hotel stops lighting and what makes a planta
## legible, so one goes dark rarely: on its own or beside a dark room.
const DARK_OWN := [0.23, 0.29, 0.36]
const DARK_SPREAD := 0.45
const DARK_CORRIDOR := Vector2(0.03, 0.05)
## How kept a room is (0 kept, 1 neglected, 2 abandoned) goes with its order,
## give or take WEAR: kept over the second number, abandoned under the first.
const WEAR := 0.25
const KEPT := Vector2(0.25, 0.55)

## Corner pieces that turn their back to the wall (map_generator.finish()):
## rotation 0 in the first two corners, 2 in the other two.
const WALL_KINDS := ["bed", "sofa", "desk", "tv", "reception", "washer", "basin", "shelf"]

## Service rooms (laundry, storeroom, maintenance, office) have a suspended
## ceiling of acoustic tiles; the empty lounge and the storeroom decrepit
## paper on the walls.
const SERVICE_CEILINGS := [7, 8, 9, 15]
const DECREPIT_WALLS := [8, 18]

## Public rooms: a sprinkler's head beside the smoke detector
## (hotel_geometry.ceiling_fittings()).
const SPRINKLER_ROOMS := [0, 5, 6, 10, 11, 12, 13, 14]

## Modules with wall lamps: reception, lobby, corridor, gallery.
const SCONCE_ROOMS := [0, 10, 11, 12]

## The fluorescent battens (lamp_of()): the baths, laundry, storeroom and
## maintenance. They hum, and some flicker.
const BATTEN_ROOMS := [4, 7, 8, 9]
## A room taller than this has a chandelier instead of the dome (lamp_of()),
## but the reception, whose ceiling has the red lamp the way back is found by.
const CHANDELIER_HEIGHT := 4.0

## The set of furniture each type puts along its walls (room_dressing.SETS);
## a type that is not here puts none.
const MODULE_SET := {0: "lounge", 1: "bedroom", 2: "bedroom", 3: "bedroom", 4: "bath", 5: "lounge", 6: "dining", 7: "laundry", 8: "service", 9: "service", 10: "lounge", 11: "corridor", 12: "corridor", 13: "reading", 14: "lounge", 15: "office", 16: "wardrobe", 17: "garden", 18: "empty"}

## What hangs on walls and from ceilings besides (October 2026): where a
## fire alarm's pull station is put, which rooms have a fuse box and which a
## ceiling fan, by module.
const ALARM_ROOMS := [0, 10, 11, 12]
const FUSE_ROOMS := [7, 8, 9, 15]
const FAN_ROOMS := [6, 13, 15]
## A long-case clock stands on a bare stretch of these, where no wall lamp
## hangs over it.
const CLOCK_ROOMS := [1, 2, 3, 5, 6, 13, 14]

## Public rooms: reception, lobby, corridor, gallery. No mirror hangs in them
## and gum is trodden into their floors (room_dressing.hang_mirror(), decals()).
const PUBLIC_ROOMS := [0, 10, 11, 12]
## Tile or metal to smear (room_dressing.decals()): the baths, laundry,
## storeroom and maintenance.
const SMEAR_ROOMS := [4, 7, 8, 9]

## Service rooms (laundry, storeroom, maintenance, cloakroom): metal shelving
## and carts instead of the guests' wood.
const SERVICE := [7, 8, 9, 16]

## Types that are circulation, besides corridors and halls: the reception,
## the lift's landing, the lobbies and galleries (the structural roles).
const CIRCULATION := [0, 9, 10, 12]

## What a room is called on the plans and the papers.
static func label(room: Dictionary) -> String:
	return String(NAMES[int(room.get("type", 0))])

## The article its name takes (ARTICLES).
static func article(room: Dictionary) -> String:
	return String(ARTICLES[int(room.get("type", 0))])

## How tall a room is (HEIGHTS).
static func height_of(room: Dictionary) -> float:
	return HALL_HEIGHT if int(room.get("hall", -1)) >= 0 else float(HEIGHTS[int(room.type)])

## Tiled underfoot: steps ring on it and blood does not soak in.
static func hard_floor(room: Dictionary) -> bool:
	return int(room.type) in HARD_FLOORS

## The floor's material (hotel_geometry.build_room()).
static func floor_finish(room: Dictionary) -> String:
	return "tile" if hard_floor(room) else "carpet"

## The walls' material (hotel_geometry.build_room()).
static func wall_material(room: Dictionary) -> String:
	return "plaster_decrepit" if int(room.type) in DECREPIT_WALLS else "plaster"

## Whether a room can have its lamps out: never the reception, the baths,
## laundry and service rooms, the lift lobbies, a salon of several modules or
## the refuge.
static func may_be_dark(room: Dictionary) -> bool:
	return not (int(room.type) in NEVER_DARK or int(room.get("hall", -1)) >= 0)

## The lamp on a room's ceiling (hotel_geometry.build_room()): "batten",
## "chandelier" or "dome".
static func lamp_of(room: Dictionary) -> String:
	if int(room.type) in BATTEN_ROOMS: return "batten"
	if float(room.height) > CHANDELIER_HEIGHT and int(room.type) != RECEPTION: return "chandelier"
	return "dome"

## A room with the domestic alcoves (DOMESTIC).
static func domestic(room: Dictionary) -> bool:
	return int(room.get("type", -1)) in DOMESTIC

## Whether a room carries a guest number on its door (NO_NUMBER).
static func numbered(room: Dictionary) -> bool:
	return int(room.hall) < 0 and not bool(room.get("corridor", false)) and not bool(room.get("service", false)) and not int(room.type) in NO_NUMBER

## Rooms the creature is never sent to: every refuge, and the lift lobby each
## one leads to.
static func off_limits_rooms(manifest: Dictionary) -> Array:
	var rooms: Array = [int(manifest.exit)]
	for refuge in manifest.get("refuges", []): rooms.append(int(refuge))
	for gate in manifest.get("gates", []): rooms.append(int(gate.get("beyond", -1)))
	return rooms
