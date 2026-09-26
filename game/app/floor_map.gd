extends Node
## The plan that draws itself on the shared sheet (paper_sheet.gd's map): the
## walls of the floor as the survivors see them. Whatever any of them has in
## front of them -- a 90-degree arc, a few metres out, as far as the light
## lets them see -- is put down on it, and it fades: three minutes after it
## was last seen it is gone, as if the page forgot it.
##
## Nothing is sent: every machine works it out from the bodies it has (its own
## player, its teammates' copies, the bots), with the same rays against the
## same walls, so every sheet shows much the same plan.
##
## The walls come from hotel_geometry.plan_walls, cut into PIECE-long pieces
## so a wall seen in part is drawn in part. Owned by hotel_main (`level.floor_map`),
## which calls tick() from its loop and reset() with every new floor.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## Longest piece of wall remembered on its own, in metres.
const PIECE := 0.7
## How often the eyes are read, and how wide and far they reach: lit, with a
## torch in the dark, and in the dark without one.
const LOOK_EVERY := 0.15
const ARC := 90.0
const RAYS := 33
const REACH_LIT := 9.0
const REACH_TORCH := 7.0
const REACH_DARK := 2.5
## A ray's hit counts for the piece of wall within this of it.
const SNAP := 0.35
## Seconds a piece stays on the plan after it was last seen.
const FORGET := 180.0
const GRID := 2.0
var level
## Per piece: its ends, its planta, when it was last seen and when it first
## came back on to the page (for the ink to bloom), -1 never.
var piece_a := PackedVector2Array()
var piece_b := PackedVector2Array()
var piece_planta := PackedInt32Array()
var seen := PackedFloat32Array()
var bloomed := PackedFloat32Array()
## (planta, cell x, cell z) -> piece indices, by their middles.
var cells := {}
## Per planta: the plan's extent (x, z), for the page to fit it.
var bounds := {}
## The pieces on the page now (index -> true), so drawing it does not go
## through the several thousand of a planta every time; the faded ones are let
## go now and then.
var live := {}
var prune_clock := 0.0
var clock := 0.0
var look_clock := 0.0
var hotel_seen = null

## A new floor: the plan of its walls, nothing seen.
func reset() -> void:
	piece_a = PackedVector2Array()
	piece_b = PackedVector2Array()
	piece_planta = PackedInt32Array()
	seen = PackedFloat32Array()
	bloomed = PackedFloat32Array()
	cells.clear()
	bounds.clear()
	live.clear()
	clock = 0.0
	look_clock = 0.0
	hotel_seen = level.hotel if level != null else null
	if level == null or not is_instance_valid(level.hotel): return
	for wall in level.hotel.plan_walls:
		var a: Vector2 = wall[0]
		var b: Vector2 = wall[1]
		var planta := int(wall[2])
		var parts := maxi(1, ceili(a.distance_to(b) / PIECE))
		for k in parts:
			add_piece(a.lerp(b, float(k) / parts), a.lerp(b, float(k + 1) / parts), planta)
		var box: Rect2 = bounds.get(planta, Rect2(a, Vector2.ZERO))
		bounds[planta] = box.expand(a).expand(b)

func add_piece(a: Vector2, b: Vector2, planta: int) -> void:
	var index := piece_a.size()
	piece_a.append(a)
	piece_b.append(b)
	piece_planta.append(planta)
	seen.append(-1.0)
	bloomed.append(-1.0)
	var key := cell_of((a + b) * 0.5, planta)
	if not cells.has(key): cells[key] = PackedInt32Array()
	cells[key].append(index)

func cell_of(point: Vector2, planta: int) -> Vector3i:
	return Vector3i(planta, floori(point.x / GRID), floori(point.y / GRID))

## How faded a piece is: 1 just seen, 0 forgotten (or never seen).
func freshness(index: int) -> float:
	if seen[index] < 0.0: return 0.0
	return clampf(1.0 - (clock - seen[index]) / FORGET, 0.0, 1.0)

## Seconds since a piece came back on to the page, INF if it has not.
func since_bloom(index: int) -> float:
	return INF if bloomed[index] < 0.0 else clock - bloomed[index]

## Counted while the floor is played, from hotel_main's loop.
func tick(delta: float) -> void:
	if level == null or not is_instance_valid(level.hotel): return
	if not is_same(hotel_seen, level.hotel): reset()
	clock += delta
	prune_clock -= delta
	if prune_clock <= 0.0:
		prune_clock = 5.0
		for index in live.keys():
			if freshness(index) <= 0.0: live.erase(index)
	look_clock -= delta
	if look_clock > 0.0: return
	look_clock = LOOK_EVERY
	look_now()

## Every living survivor's eyes, once.
func look_now() -> void:
	if piece_a.is_empty(): return
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for body in level.survivors():
		if not is_instance_valid(body) or not "camera" in body or not is_instance_valid(body.camera): continue
		if int(level.session.participants.get(body.slot, level.session.Life.DEAD)) == level.session.Life.DEAD: continue
		look_from(body, space)

func look_from(body: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var eye: Vector3 = body.camera.global_position
	var forward: Vector3 = -body.camera.global_basis.z
	forward.y = 0.0
	if forward.length() < 0.01: return
	forward = forward.normalized()
	var reach := REACH_LIT
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, eye)
	if level.hotel.dark or room.is_empty() or level.hotel.dark_room(room):
		reach = REACH_TORCH if bool(body.torch.visible) else REACH_DARK
	var planta := FLOOR.planta_of(eye.y)
	for k in RAYS:
		var angle := deg_to_rad(-ARC * 0.5 + ARC * float(k) / float(RAYS - 1))
		var way := forward.rotated(Vector3.UP, angle)
		var query := PhysicsRayQueryParameters3D.create(eye, eye + way * reach, 1 | 8)
		query.exclude = [body.get_rid()]
		var hit := space.intersect_ray(query)
		if hit.is_empty(): continue
		var at: Vector3 = hit.position
		mark(Vector2(at.x, at.z), planta)

## The piece of wall a hit landed on, seen now.
func mark(point: Vector2, planta: int) -> void:
	var here := cell_of(point, planta)
	var best := -1
	var best_gap := SNAP
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var bucket = cells.get(Vector3i(here.x, here.y + dx, here.z + dz))
			if bucket == null: continue
			for index in bucket:
				var gap := Geometry2D.get_closest_point_to_segment(point, piece_a[index], piece_b[index]).distance_to(point)
				if gap < best_gap:
					best_gap = gap
					best = index
	if best < 0: return
	# A point of a wall seen is the stretch of it round that point: the
	# pieces either side, when they are the same wall going on. Rays fan out,
	# and a wall seen at a slant was left full of gaps between them.
	for index in [best - 1, best, best + 1]:
		if index < 0 or index >= piece_a.size() or piece_planta[index] != planta: continue
		if index == best - 1 and not piece_b[index].is_equal_approx(piece_a[best]): continue
		if index == best + 1 and not piece_a[index].is_equal_approx(piece_b[best]): continue
		# Back on the page after it had faded away: its ink blooms again.
		if freshness(index) <= 0.0: bloomed[index] = clock
		seen[index] = clock
		live[index] = true

## The pieces of a planta on the page now, in the order they were cut (so
## the pieces of one wall come one after another).
func live_on(planta: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for index in live:
		if piece_planta[index] == planta and freshness(index) > 0.0: out.append(index)
	out.sort()
	return out

## The planta the map shows: where the camera this machine looks through is.
func viewer_planta() -> int:
	var camera: Camera3D = level.get_viewport().get_camera_3d()
	var at: Vector3 = camera.global_position if camera != null else level.player.global_position
	return FLOOR.planta_of(at.y)
