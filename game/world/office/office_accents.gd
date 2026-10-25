extends RefCounted
## A floor's accent lights (spec_rediseno 4): desk lamps, track spots and wall
## lamps, at most MOST to a room, kept by room so that its power, her drain and
## the round of lamps reach them (office_geometry.gd: accent_spot(),
## accent_sconce()).
const MOST := 3
## Room id -> its accents: {"light": Light3D, "energy": float, "sconce": int
## (its index in sconce_lights, or -1), "mesh": MeshInstance3D or null (a wall
## lamp's own glow), "glowing": bool}.
var rooms := {}
## A wall lamp's index in sconce_lights -> its room id.
var by_sconce := {}

## Whether the room can take one more.
func has_room(room_id: int) -> bool:
	return of_room(room_id).size() < MOST

func add(room_id: int, entry: Dictionary) -> void:
	if not rooms.has(room_id): rooms[room_id] = []
	rooms[room_id].append(entry)
	if int(entry.get("sconce", -1)) >= 0: by_sconce[int(entry.sconce)] = room_id

func of_room(room_id: int) -> Array:
	return rooms.get(room_id, [])
