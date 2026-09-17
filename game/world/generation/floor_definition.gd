extends RefCounted

const VERSION := 3
const CELL := 12.0
## Clear width of a doorway: a hotel door with room for the creature to pass.
const PORTAL := 1.3
## Door leaf width, a little narrower than the opening.
const LEAF_WIDTH := 1.2
## Wardrobes per module type: bedrooms and the cloakroom get two, a few
## private rooms get one, corridors, halls and public spaces none.
const WARDROBES := {1: 2, 2: 2, 3: 2, 16: 2, 13: 1, 14: 1, 15: 1, 8: 1}
const TYPES := ["recepcion", "habitacion_doble", "habitacion_simple", "suite", "bano", "salon", "comedor", "lavanderia", "almacen", "mantenimiento", "vestibulo", "pasillo", "galeria", "sala_lectura", "sala_tv", "oficina", "guardarropa", "sala_plantas", "salon_vacio", "refugio"]
const NAMES := ["Recepción", "Habitación doble", "Habitación", "Suite", "Baños", "Salón", "Comedor", "Lavandería", "Almacén", "Mantenimiento", "Vestíbulo", "Pasillo", "Galería", "Sala de lectura", "Sala de televisión", "Oficina", "Guardarropa", "Jardín interior", "Salón vacío", "Refugio"]
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
	["sofa", "lamp", "phone", "plant"]
]

static func position_of(room: Dictionary) -> Vector3:
	return Vector3(room.get("px", room.x * CELL), 0, room.get("pz", room.z * CELL))

static func size_of(room: Dictionary) -> Vector2:
	return Vector2(room.get("span_x", CELL), room.get("span_z", CELL))

static func hiding_count(room: Dictionary) -> int:
	if int(room.get("hall", -1)) >= 0: return 0
	return WARDROBES.get(int(room.type), 0)

## Wardrobe spots against the walls; with two, they go on opposite walls.
static func hiding_positions(room: Dictionary) -> Array[Vector3]:
	var span := size_of(room) * 0.5 - Vector2.ONE * 0.8
	var open: Array = room.get("open_sides", [])
	var candidates: Array[Vector3] = []
	for wall in ["west", "east", "north", "south"]:
		if open.has(wall): continue
		for offset in [-1.8, 1.8]:
			match wall:
				"west": candidates.append(Vector3(-span.x, 0, offset))
				"east": candidates.append(Vector3(span.x, 0, offset))
				"north": candidates.append(Vector3(offset, 0, -span.y))
				"south": candidates.append(Vector3(offset, 0, span.y))
	var result: Array[Vector3] = []
	var count := mini(hiding_count(room), candidates.size())
	if count >= 1: result.append(candidates[0])
	# Candidates come in pairs per wall (west, east, ...): index 2 is the opposite wall.
	if count >= 2: result.append(candidates[2] if candidates.size() > 2 else candidates[1])
	return result

static func hiding_yaw(spot: Vector3) -> float:
	if absf(spot.x) > absf(spot.z): return -signf(spot.x) * PI / 2
	return PI if spot.z > 0 else 0.0

static func hiding_approach(spot: Vector3) -> Vector3:
	return spot + Basis(Vector3.UP, hiding_yaw(spot)) * Vector3(0, 0, 1.1)

static func portal_between(a: Dictionary, b: Dictionary) -> Vector3:
	var point := position_of(a)
	var size := size_of(a)
	if a.x != b.x: point.x += sign(b.x - a.x) * size.x * 0.5
	else: point.z += sign(b.z - a.z) * size.y * 0.5
	return point

static func navigation_path(map: RID, origin: Vector3, target: Vector3) -> PackedVector3Array:
	var query := NavigationPathQueryParameters3D.new()
	query.map = map
	query.start_position = origin
	query.target_position = target
	query.path_search_max_polygons = 0
	query.simplify_path = true
	query.simplify_epsilon = 0.02
	var result := NavigationPathQueryResult3D.new()
	NavigationServer3D.query_path(query, result)
	return result.path
