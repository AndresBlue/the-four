extends RefCounted
## What a bot sees. It knows the plan of the hotel -- rooms, doors, which way
## is which -- but not what is in it: the refuge, the sets, the notes and the
## keypad it has to see with its own eyes, from where its camera is and the way
## it looks, with the light there is. That is the point of it: a note nobody
## can see is a floor nobody can finish, and a bot that never saw it says so.
##
## Seen means: inside its view (VIEW_ACROSS either side, VIEW_UP up and down),
## nothing solid between its eye and the thing (the creature's own occlusion:
## walls, shut doors, leaves), near enough for the light on it -- a lit room,
## the beam of its torch, or the thing's own glow --, and twice in a row.
## One table (RANGES) says how near, and a finding that turns out wrong is
## put right there.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const TV_PLACEMENT := preload("res://game/world/generation/tv_placement.gd")
const VIEW_ACROSS := deg_to_rad(50.0)
const VIEW_UP := deg_to_rad(35.0)
const SIGHT_MASK := 1 | 8 | 64
## The torch: the creature's own measure of the beam (spot_angle 32 x 0.85).
const TORCH_ANGLE := deg_to_rad(27.0)
const TORCH_RANGE := 24.0
## A lit set lights the room round it this far (hotel_television.RANGE).
const TV_LIGHT := 7.0
## Metres at which each kind is made out: in a lit room, in the dark inside
## the torch's beam, in the dark with nothing on it, and by its own light
## (-1: it has none).
const RANGES := {
	"refuge": {"lit": 25.0, "torch": 15.0, "dark": 0.0, "glow": 25.0},
	"tv": {"lit": 15.0, "torch": 12.0, "dark": 2.5, "glow": -1.0},
	"tv_on": {"lit": 30.0, "torch": 30.0, "dark": 30.0, "glow": 30.0},
	"note": {"lit": 9.0, "torch": 12.0, "dark": 1.5, "glow": -1.0},
	"keypad": {"lit": 15.0, "torch": 15.0, "dark": 0.0, "glow": 20.0},
}
## A ray that stops this near the point it was cast at has hit the thing
## itself (a set's box, the drawer a note hangs over), not something in front
## of it: a set is known by its box from the side, even with its screen away.
const SOLID_SELF := {"refuge": 0.3, "tv": 0.6, "tv_on": 0.6, "note": 0.2, "keypad": 0.25}

## The things of this stage there are to find, each with the points that
## show it: {key, kind, index, points, planta}.
static func targets(level, stage: int) -> Array:
	var out: Array = []
	var wing := stage - 1
	var refuges: Array = level.manifest.get("refuges", [])
	if wing < refuges.size():
		var room: Dictionary = level.manifest.rooms[int(refuges[wing])]
		var centre := FLOOR.position_of(room)
		var quarter := FLOOR.size_of(room) * 0.25
		var points: Array = [centre + Vector3(0, 1.4, 0)]
		for corner in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]: points.append(centre + Vector3(corner.x * quarter.x, 1.4, corner.y * quarter.y))
		out.append({"key": "refuge:%d" % wing, "kind": "refuge", "index": wing, "points": points, "planta": wing, "room": int(room.id)})
	for index in level.stage_televisions(stage):
		var set = level.televisions[index]
		out.append({"key": "tv:%d" % index, "kind": "tv", "index": index, "points": [set.screen_point(), set.to_global(Vector3(0, 1.3, 0))], "planta": wing, "room": int(FLOOR.room_at(level.manifest.rooms, set.global_position).get("id", -1))})
	if level.kind.asks(stage, "code"):
		for index in level.containers.size():
			var piece = level.containers[index]
			if int(piece.digit) < 0 or not is_instance_valid(piece.note): continue
			out.append({"key": "note:%d" % index, "kind": "note", "index": index, "points": [piece.note.global_position], "planta": wing, "room": int(FLOOR.room_at(level.manifest.rooms, piece.global_position).get("id", -1))})
		if is_instance_valid(level.lock):
			out.append({"key": "keypad", "kind": "keypad", "index": 0, "points": [level.lock.to_global(Vector3(0, 1.42, 0.09))], "planta": wing, "room": int(FLOOR.room_at(level.manifest.rooms, level.lock.global_position).get("id", -1))})
	return out

## Whether the light where a point is lets it be seen: the room's lamps on,
## or a lit set near it.
static func lit(level, point: Vector3) -> bool:
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, point)
	if not room.is_empty() and level.hotel.lit(int(room.id)): return true
	for index in level.stage_televisions():
		var set = level.televisions[index]
		if set.on and set.global_position.distance_to(point) < TV_LIGHT: return true
	return false

## How far a kind is made out with a given light.
static func reach_of(kind: String, light: String) -> float:
	return float(RANGES[kind].get(light, 0.0))

## One look at one point: {seen, dist, in_view, clear, light}. `light`:
## "glow", "lit", "torch" or "dark".
static func look(level, body, kind: String, point: Vector3) -> Dictionary:
	var eye: Vector3 = body.camera.global_position
	var offset: Vector3 = point - eye
	var dist := offset.length()
	var result := {"seen": false, "dist": dist, "in_view": false, "clear": false, "light": "dark"}
	if dist < 0.05: return result
	var ranges: Dictionary = RANGES[kind]
	if dist > maxf(maxf(ranges.lit, ranges.torch), maxf(ranges.dark, ranges.glow)): return result
	var forward: Vector3 = -body.camera.global_basis.z
	var flat_forward := Vector2(forward.x, forward.z).normalized()
	var flat_offset := Vector2(offset.x, offset.z)
	var across := absf(flat_forward.angle_to(flat_offset)) if flat_offset.length() > 0.05 else 0.0
	var up := absf(atan2(offset.y, maxf(flat_offset.length(), 0.05)) - body.look_pitch)
	result.in_view = across <= VIEW_ACROSS and up <= VIEW_UP
	if not result.in_view: return result
	var query := PhysicsRayQueryParameters3D.create(eye, point, SIGHT_MASK)
	query.exclude = [body.get_rid()]
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	result.clear = hit.is_empty() or hit.position.distance_to(point) <= float(SOLID_SELF.get(kind, 0.2))
	if not result.clear: return result
	var reach := 0.0
	if ranges.glow > 0.0:
		reach = ranges.glow
		result.light = "glow"
	if lit(level, point) and ranges.lit > reach:
		reach = ranges.lit
		result.light = "lit"
	if body.torch.visible and dist <= TORCH_RANGE and forward.angle_to(offset) <= TORCH_ANGLE and ranges.torch > reach:
		reach = ranges.torch
		result.light = "torch"
	if ranges.dark > reach:
		reach = ranges.dark
		result.light = "dark"
	result.seen = dist <= reach
	return result
