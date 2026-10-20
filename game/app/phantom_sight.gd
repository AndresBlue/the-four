extends Node3D
## A mind going sees it too: far off, for a moment, where it is not. Its head
## and neck round the jamb of an open door down a corridor, the pale face
## cocked, looking at you -- the way it waits behind the door on the title
## screen -- or, at the end of a long corridor, the whole of it standing
## there. It is there only while it is looked at: out of sight, a quick turn
## of the head, a step towards it or the torch full on it, and it is gone.
##
## Local to this machine, like every lie of the floor: one model of it, no
## body, no collision, in no group, told to nobody. Never in the refuge, never
## while the real one is near or hunting, never for the one who drives it,
## the observer or the test bots.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const LOOK := preload("res://game/enemies/locust/locust_look.gd")
const POSER := preload("res://game/enemies/locust/locust_poser.gd")
const MODEL := preload("res://assets/enemies/locust.glb")
const SIGHT_MASK := 1 | 8 | 64
## Where: a door standing open this far off, or the far end of a straight run
## of corridor this far off (at least RUN_CELLS cells long).
const PEEK_RANGE := Vector2(10.0, 35.0)
const STAND_RANGE := Vector2(24.0, 45.0)
const RUN_CELLS := 3
## When: under this much sanity, at the earliest this long after the last one
## (drawn between the two), rolled every LOOK_EVERY seconds with a chance that
## grows as the mind goes.
const UNEASY := 60.0
const REST := Vector2(90.0, 180.0)
const LOOK_EVERY := 0.5
const CHANCE := Vector2(0.01, 0.06)
## Placed where the camera is not quite looking (so it never appears in plain
## view): off the middle of the picture by between these (cos of the angle).
const PLACE_OFF := Vector2(0.45, 0.85)
## Seen: that near the middle of the picture, with nothing in between.
const SEEN := 0.8
## How it goes: seen for a moment (drawn), or never seen within UNSEEN_FOR;
## gone at once out of view (LOST), with the head turned faster than FAST
## (radians a second), with the camera nearer than NEAR, or in the torch.
const SHOWN := Vector2(0.6, 1.6)
const UNSEEN_FOR := 6.0
const LOST := 0.5
const FAST := deg_to_rad(120.0)
const NEAR := 8.0
## The creature itself this near, or on the hunt, and there is no lie to tell.
const REAL_NEAR := 25.0
## Its head slides out from behind the jamb over this long.
const PEEK_IN := 0.4
## How far past the jamb it stands (metres beyond the edge of the doorway),
## tried in turn, and how far it leans out: the head has to clear the jamb and
## nothing else may (BODY_BONES).
const JAMB_BEHIND := [0.55, 0.4, 0.7]
const PEEK_LEAN := 0.6
const BODY_BONES := ["Spine", "Spine2", "Pelvis", "L_Forearm", "R_Forearm", "L_Hand", "R_Hand"]
var level
var model: Node3D
var poser
var rng := RandomNumberGenerator.new()
var rest := 0.0
var roll_clock := 0.0
## "", "peek" or "stand"; how long it has been out, since it was first seen,
## how long it is to be seen for; the side it leans to; and its head point.
var kind := ""
var out_for := 0.0
var seen_for := -1.0
var show_for := 1.0
var lean_side := 1.0
var face_point := Vector3.ZERO
var last_forward := Vector3.ZERO
var turn_rate := 0.0
## How many it has shown, and how each went (tests, and the observer's log).
var shown := 0
var last_end := ""

func setup(owner_level) -> void:
	level = owner_level
	name = "PhantomSight"
	rng.randomize()
	rest = rng.randf_range(REST.x, REST.y) * 0.5

func ensure_model() -> void:
	if is_instance_valid(model): return
	model = MODEL.instantiate()
	model.name = "Phantom"
	model.scale = Vector3.ONE * 1.95
	add_child(model)
	LOOK.apply(model)
	poser = POSER.new(model)
	model.visible = false

func showing() -> bool:
	return not kind.is_empty()

## Whether the floor may lie like this to this machine now.
func allowed() -> bool:
	if level.observer or level.bot_match or level.match_net.local_is_locust() or not level.local_alive(): return false
	if level.player.sanity >= UNEASY or level.player.hidden or level.player.reading or level.in_refuge(): return false
	var creature = level.locust
	if not is_instance_valid(creature): return false
	if creature.mode in [creature.Mode.ALERT, creature.Mode.CHASE, creature.Mode.WINDUP, creature.Mode.RECOVER, creature.Mode.EXECUTE]: return false
	return creature.global_position.distance_to(level.player.global_position) > REAL_NEAR or FLOOR.planta_of(creature.global_position.y) != FLOOR.planta_of(level.player.global_position.y)

func _physics_process(delta: float) -> void:
	if level == null or level.manifest.is_empty() or level.session.state != level.session.State.PLAYING: return
	var camera: Camera3D = level.player.camera
	var forward := -camera.global_basis.z
	turn_rate = forward.angle_to(last_forward) / maxf(delta, 0.001) if last_forward != Vector3.ZERO else 0.0
	last_forward = forward
	if showing():
		haunt(delta, camera)
		return
	rest -= delta
	roll_clock -= delta
	if rest > 0.0 or roll_clock > 0.0: return
	roll_clock = LOOK_EVERY
	if turn_rate > FAST * 0.5 or not allowed(): return
	var gone: float = clampf(1.0 - level.player.sanity / UNEASY, 0.0, 1.0)
	if rng.randf() > lerpf(CHANCE.x, CHANCE.y, gone): return
	if place(camera): begin()

func begin() -> void:
	out_for = 0.0
	seen_for = -1.0
	show_for = rng.randf_range(SHOWN.x, SHOWN.y)
	# Lit by the lamp of the room it stands in, like the creature it passes
	# for: it is in no group, so nobody does that for it (hotel_geometry).
	if is_instance_valid(level) and is_instance_valid(level.hotel): level.hotel.light_body(model)
	model.visible = true
	pose(0.0)

## Out there: it keeps still (only the head twitches), leans out once seen,
## and goes the moment the rules say.
func haunt(delta: float, camera: Camera3D) -> void:
	out_for += delta
	var eye := camera.global_position
	var towards := face_point - eye
	var in_view: bool = (-camera.global_basis.z).dot(towards.normalized()) >= SEEN and clear(eye, face_point)
	if seen_for < 0.0:
		if in_view:
			seen_for = 0.0
			shown += 1
		elif out_for > UNSEEN_FOR or not allowed():
			vanish("sin ver")
			return
	else:
		seen_for += delta
		var end := ""
		if (-camera.global_basis.z).dot(towards.normalized()) < LOST or not clear(eye, face_point): end = "fuera de vista"
		elif turn_rate > FAST: end = "giro"
		elif towards.length() < NEAR: end = "cerca"
		elif torch_on(camera): end = "linterna"
		elif seen_for > show_for: end = "tiempo"
		if not end.is_empty():
			vanish(end)
			return
	pose(clampf(seen_for / PEEK_IN, 0.0, 1.0) if seen_for >= 0.0 else 0.0)

func vanish(why: String) -> void:
	if seen_for >= 0.0:
		level.sanity.glitch = 0.5
		last_end = why
	kind = ""
	if is_instance_valid(model): model.visible = false
	rest = rng.randf_range(REST.x, REST.y)
	var view = level.get("observer_view")
	if view != null and is_instance_valid(view): view.note("alucinación, %s" % why)

func clear(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, SIGHT_MASK)
	query.exclude = [level.player.get_rid()]
	return level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## The beam full on its face.
func torch_on(camera: Camera3D) -> bool:
	if not level.player.torch.visible: return false
	var offset := face_point - camera.global_position
	return offset.length() < 20.0 and (-camera.global_basis.z).angle_to(offset) < deg_to_rad(10.0)

## Lit enough to be made out: its room's lamps, or the torch pointing that way.
func lit(point: Vector3, camera: Camera3D) -> bool:
	var room := FLOOR.room_at(level.manifest.rooms, point)
	if not room.is_empty() and not level.hotel.dark and not level.hotel.dark_ids.has(int(room.id)): return true
	var offset := point - camera.global_position
	return level.player.torch.visible and offset.length() < 22.0 and (-camera.global_basis.z).angle_to(offset) < deg_to_rad(40.0)

## Just off to the side of the picture, where a turn of the head will find it.
func beside_view(point: Vector3, camera: Camera3D) -> bool:
	var towards := point - camera.global_position
	var dot := (-camera.global_basis.z).dot(towards.normalized())
	return dot >= PLACE_OFF.x and dot <= PLACE_OFF.y

## Somewhere to be: a door or the end of a corridor. False when there is none.
func place(camera: Camera3D) -> bool:
	ensure_model()
	var spots: Array = []
	var eye := camera.global_position
	for door in level.hotel.doors:
		if not is_instance_valid(door) or not door.opened or door.moving or door.locked: continue
		var gap: float = door.doorway.distance_to(eye)
		if gap < PEEK_RANGE.x or gap > PEEK_RANGE.y or FLOOR.planta_of(door.doorway.y) != FLOOR.planta_of(eye.y): continue
		if not beside_view(door.doorway + Vector3(0, 1.8, 0), camera) or not clear(eye, door.doorway + Vector3(0, 1.8, 0)): continue
		spots.append({"kind": "peek", "door": door})
	var run_end := corridor_end(eye)
	if run_end != Vector3.INF and beside_view(run_end + Vector3(0, 2.2, 0), camera) and clear(eye, run_end + Vector3(0, 2.2, 0)): spots.append({"kind": "stand", "point": run_end})
	spots.shuffle()
	for spot in spots:
		if spot.kind == "peek" and place_peek(spot.door, camera): return true
		if spot.kind == "stand" and place_stand(spot.point, camera): return true
	return false

## Behind the jamb on the far side of an open door, facing the camera, leaning
## into the gap: valid when, leant out, its head is in view and its chest is not.
func place_peek(door, camera: Camera3D) -> bool:
	var eye := camera.global_position
	var across: Vector3 = Basis(Vector3.UP, door.closed_rotation) * Vector3(0, 0, 1)
	if across.dot(door.doorway - eye) < 0.0: across = -across
	var along := Vector3.UP.cross(across).normalized()
	var map: RID = level.get_world_3d().navigation_map
	for side in [1.0, -1.0]:
		for behind in JAMB_BEHIND:
			var spot: Vector3 = door.doorway + across * 0.5 + along * side * (FLOOR.PORTAL * 0.5 + behind)
			spot.y = FLOOR.planta_y(FLOOR.planta_of(door.doorway.y))
			if FLOOR.room_at(level.manifest.rooms, spot).is_empty() or FLOOR.closest(map, spot).distance_to(spot) > 0.6: continue
			kind = "peek"
			model.global_position = spot
			# Facing the camera; its lean goes towards the gap, the other way from `side`.
			var to_eye := eye - spot
			model.rotation = Vector3(0, atan2(to_eye.x, to_eye.z), 0)
			var model_x: Vector3 = model.global_basis.x.normalized()
			lean_side = 1.0 if model_x.dot(-along * side) > 0.0 else -1.0
			pose(1.0)
			var head: Vector3 = poser.point("Head1")
			if clear(eye, head) and lit(head, camera) and hidden_body(eye):
				face_point = head
				return true
			kind = ""
	return false

## Everything of it but the head and neck behind the wall: its middle, its
## hips and its hanging arms.
func hidden_body(eye: Vector3) -> bool:
	for bone in BODY_BONES:
		if clear(eye, poser.point(bone)): return false
	return true

## Standing at the far end of the corridor, looking back down it.
func place_stand(point: Vector3, camera: Camera3D) -> bool:
	if not lit(point + Vector3(0, 2.0, 0), camera): return false
	kind = "stand"
	model.global_position = point
	var to_eye := camera.global_position - point
	model.rotation = Vector3(0, atan2(to_eye.x, to_eye.z), 0)
	pose(1.0)
	face_point = poser.point("Head1")
	return true

## The far end of the straight open run of corridor cells the camera stands
## in, when it is long enough and far enough; INF otherwise.
func corridor_end(eye: Vector3) -> Vector3:
	var here := FLOOR.room_at(level.manifest.rooms, eye)
	if here.is_empty() or not bool(here.get("corridor", false)): return Vector3.INF
	var open := {}
	for pair in level.manifest.get("merged", []):
		open[Vector2i(int(pair[0]), int(pair[1]))] = true
	var best := Vector3.INF
	for axis in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var at: Dictionary = here
		var cells := 1
		while true:
			var next := {}
			for other in level.manifest.adjacency[int(at.id)]:
				var room: Dictionary = level.manifest.rooms[int(other)]
				var step := FLOOR.position_of(room) - FLOOR.position_of(at)
				var key := Vector2i(mini(int(at.id), int(other)), maxi(int(at.id), int(other)))
				if bool(room.get("corridor", false)) and open.has(key) and step.normalized().dot(axis) > 0.95:
					next = room
					break
			if next.is_empty(): break
			at = next
			cells += 1
		if cells < RUN_CELLS: continue
		var end := FLOOR.position_of(at)
		var gap := end.distance_to(eye)
		if gap >= STAND_RANGE.x and gap <= STAND_RANGE.y: best = end
	return best

## Leant out of the jamb by `amount` (0..1), or standing: the title screen's
## pose (locust_poser), with the head cocked and the odd twitch.
func pose(amount: float) -> void:
	if not is_instance_valid(model): return
	var twitch := 0.0
	if seen_for > 0.3 and fmod(seen_for, 0.9) < 0.12: twitch = 1.0
	if kind == "stand": poser.pose_stare(twitch)
	else: poser.pose_peek(lerpf(0.05, PEEK_LEAN, amount), twitch, lean_side)
