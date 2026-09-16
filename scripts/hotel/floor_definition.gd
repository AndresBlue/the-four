extends RefCounted

const VERSION := 3
const CELL := 12.0
const PORTAL := 2.4
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

static func hiding_positions(room: Dictionary) -> Array[Vector3]:
	var span := size_of(room) * 0.5 - Vector2.ONE * 0.8
	var open: Array = room.get("open_sides", [])
	var result: Array[Vector3] = []
	for wall in ["west", "east", "north", "south"]:
		if open.has(wall): continue
		for offset in [-1.8, 1.8]:
			if result.size() == 4: return result
			match wall:
				"west": result.append(Vector3(-span.x, 0, offset))
				"east": result.append(Vector3(span.x, 0, offset))
				"north": result.append(Vector3(offset, 0, -span.y))
				"south": result.append(Vector3(offset, 0, span.y))
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
