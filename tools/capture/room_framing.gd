extends RefCounted
## The framing of tools/capture/office_rooms_capture.gd (spec_rediseno 6), so that
## tests/office/office_proportion_test.gd measures from the same camera, with
## nothing built. From the corridor, OUT metres back from the doorway, looking at
## the room's feature wall; from across the room when that wall is the doorway's
## own; from INSIDE metres in when it is too far aside.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
## Eye height in the doorway, how far back out of the room, the height looked at
## and the horizontal field of view.
const EYE := 1.5
const OUT := 0.2
const AIM := 1.5
const FOV := 55.0
## A feature wall more than 25 degrees aside from straight in (its cosine) is
## framed from INSIDE metres into the room, past the door's leaf.
const ASIDE := 0.9
const INSIDE := 1.2
## A feature wall that is the doorway's own is framed from across the room, this
## far from the wall opposite: past what stands against it (0.65 m) and over
## what stands deeper (1.3 m).
const ACROSS_OFF := 1.2

## The doorway to look through: the first one that leads to a corridor, else
## the first one of the room; with none (the air plant), its open side. Its
## portal and the way into the room.
static func door_of(rooms: Array, room: Dictionary) -> Dictionary:
	var ways: Array = FLOOR.doorways(room)
	if ways.is_empty():
		var open_to: Dictionary = rooms[FLOOR.beside(room, LAYOUT.way_of(String(room.open_sides[0])))]
		return {"other": open_to, "portal": FLOOR.portal_between(room, open_to), "inward": inward_of(room, open_to)}
	var pick: Dictionary = ways[0]
	for doorway in ways:
		var beyond: Dictionary = rooms[int(doorway.other)]
		if bool(beyond.get("corridor", false)):
			pick = doorway
			break
	var other: Dictionary = rooms[int(pick.other)]
	return {"other": other, "portal": FLOOR.portal_between(room, other), "inward": inward_of(room, other)}

## Normal of the wall shared by two rooms, pointing into room (the same
## criterion as portal_between).
static func inward_of(room: Dictionary, other: Dictionary) -> Vector3:
	return Vector3(signf(float(room.x) - float(other.x)), 0, 0) if int(room.x) != int(other.x) else Vector3(0, 0, signf(float(room.z) - float(other.z)))

## Where the camera looks in a room: the middle of its feature wall
## (room.feature, palette.FEATURE_WALLS; spec_rediseno 6) at AIM over its
## floor, or 6 m straight in from the doorway when it has none.
static func aim_of(room: Dictionary, door: Dictionary, from: Vector3) -> Vector3:
	var straight: Vector3 = from + door.inward * 6.0 + Vector3(0, AIM - EYE, 0)
	var wall := String(room.get("feature", ""))
	if wall == "": return straight
	var centre := FLOOR.position_of(room)
	var face := LAYOUT.face(room, wall)
	return Vector3(centre.x + face, centre.y + AIM, centre.z) if wall == "west" or wall == "east" else Vector3(centre.x, centre.y + AIM, centre.z + face)

## The eye and the point looked at, {from, at}, for a room through a doorway.
static func view_of(room: Dictionary, door: Dictionary) -> Dictionary:
	var from: Vector3 = door.portal - door.inward * OUT + Vector3(0, EYE, 0)
	var aim := aim_of(room, door, from)
	var wall := String(room.get("feature", ""))
	var way: Vector2i = LAYOUT.way_of(wall) if wall != "" else Vector2i.ZERO
	if Vector3(way.x, 0, way.y).dot(door.inward) < -0.5:
		var depth: float = FLOOR.size_of(room).x if absf(door.inward.x) > 0.5 else FLOOR.size_of(room).y
		from = FLOOR.position_of(room) + door.inward * (depth * 0.5 - ACROSS_OFF) + Vector3(0, EYE, 0)
	elif (aim - from).normalized().dot(door.inward) < ASIDE:
		# A feature wall too far aside is not seen past the jamb and the open door.
		from = door.portal + door.inward * INSIDE + Vector3(0, EYE, 0)
		aim = aim_of(room, door, from)
	return {"from": from, "at": aim}
