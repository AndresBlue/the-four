extends RefCounted
## Who sees what, for any creature (docs/OFICINAS.md 11.5): whether somebody
## has a point in view (The Locust's watched()), a torch on a face, a look at
## a face that can be made out, the edge of a view (phantom_sight's), and
## being behind or above somebody. All static, no state; it preloads nothing
## but floor_definition.gd, so The Locust can use it without the avatar.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")

## What blocks a look: the world, the doors, the hiding places (the rays of
## hotel_locust.clear_sight and sanity.sight_of_creature). Bodies (layer 4)
## never do.
const MASK := 1 | 8 | 64
## Degrees between where a survivor looks and her face for them to be looking
## at her: their own view, and a guest's puppet, whose view arrives late
## (remote_player.DELAY and the net) and is given the benefit of the doubt.
const REGARD_LOCAL := 30.0
const REGARD_REMOTE := 45.0
## Metres a look carries (sanity sees the creature to 28).
const REGARD_REACH := 30.0
## In the dark, with no torch, her pale face is made out only this near (the
## author, 24 October 2026: "solo a muy poca distancia").
const DARK_FACE := 1.2
## The torch on her face: on, the view pointed within this of the face, this
## near (the beam, spot_range 24, is still strong there), nothing between.
## The aim is the camera's, not the lamp's lagging node.
const TORCH_FACE_ANGLE := 20.0
const TORCH_REACH := 20.0
## watched(): The Locust's SIGHT_RANGE and its cone.
const WATCH_REACH := 70.0
const WATCH_DOT := 0.35
## beside_view(): phantom_sight.PLACE_OFF, the band at the edge of a view.
const BESIDE := Vector2(0.45, 0.85)
## Behind somebody: horizontally more than ~105 degrees from where they look,
## or above them (50 degrees up or more) while they do not look up at her.
const REAR_DOT := -0.26
const OVER_SIN := 0.77
const OVER_LOOK := 0.5

## Alive (not DEAD in the session), with a camera: a body whose look counts.
## Protected rooms and cars included: a torch from the freight lobby still saves.
static func alive(level, body) -> bool:
	if not is_instance_valid(body) or not "camera" in body or not is_instance_valid(body.camera): return false
	var session = level.get("session")
	if session == null or not "slot" in body: return true
	return session.participants.get(int(body.slot), session.Life.DEAD) != session.Life.DEAD

## Any survivor but this machine's own player: its view reaches here late.
## Bots (bot_body.gd extends remote_player.gd) get the same margin: on the
## side of more saves.
static func is_remote(level, body) -> bool:
	return body != level.get("player")

## Lit where it is: the room's lamps on (hotel.lit()), never inside a crawl
## space (level.crawling_at(), absent on the hotel: false).
static func lit_point(level, point: Vector3) -> bool:
	if level.has_method("crawling_at") and bool(level.crawling_at(point)): return false
	var room := FLOOR.room_at(level.manifest.rooms, point)
	if room.is_empty(): return false
	return bool(level.hotel.lit(int(room.id)))

## Nothing of MASK between two points (exclude: RIDs).
static func clear(level, from: Vector3, to: Vector3, exclude: Array) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK)
	query.exclude = exclude
	return level.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Whether any active survivor (level.survivor_active) has `target` in view:
## within `reach`, the camera's forward dotted with the way to it at least
## `dot`, a clear ray from the camera. The Locust's watched(), point for point.
static func watched(level, target: Vector3, exclude: Array, reach := WATCH_REACH, dot := WATCH_DOT) -> bool:
	for body in level.survivors():
		if not is_instance_valid(body) or not level.survivor_active(body) or not "camera" in body or not is_instance_valid(body.camera): continue
		var eye: Vector3 = body.camera.global_position
		var towards: Vector3 = target - eye
		var gap := towards.length()
		if gap > reach or gap < 0.01: continue
		if -body.camera.global_basis.z.dot(towards / gap) < dot: continue
		if clear(level, eye, eye + towards, [body.get_rid()] + exclude): return true
	return false

## Their torch is on, they are not hidden, and their view points at `face`
## within TORCH_FACE_ANGLE, within TORCH_REACH, through nothing. No least
## distance: a torch on her face a metre away counts most of all.
static func torch_covers(level, body, face: Vector3, exclude: Array) -> bool:
	if not alive(level, body) or bool(body.get("hidden")): return false
	if not "torch" in body or not is_instance_valid(body.torch) or not body.torch.visible: return false
	var eye: Vector3 = body.camera.global_position
	var to := face - eye
	var d := to.length()
	if d > TORCH_REACH or d < 0.05: return false
	if rad_to_deg((-body.camera.global_basis.z).angle_to(to)) > TORCH_FACE_ANGLE: return false
	return clear(level, eye, face, exclude + [body.get_rid()])

## They are looking at her: their view within REGARD_LOCAL (REGARD_REMOTE for
## a puppet) of `face`, within REGARD_REACH, a clear ray, and she can be made
## out: `lit_face` (lit_point(face), worked out once by the caller), their
## torch on her face, or near enough to see it in the dark (DARK_FACE).
## Hidden bodies regard nothing.
static func regards(level, body, face: Vector3, exclude: Array, lit_face: bool) -> bool:
	return bool(look_of(level, body, face, exclude, lit_face).regards)

## One body's look at her face, one ray: {"regards": bool, "torch": bool}.
static func look_of(level, body, face: Vector3, exclude: Array, lit_face: bool) -> Dictionary:
	var none := {"regards": false, "torch": false}
	if not alive(level, body) or bool(body.get("hidden")): return none
	var eye: Vector3 = body.camera.global_position
	var to := face - eye
	var d := to.length()
	if d > REGARD_REACH or d < 0.05: return none
	var angle := rad_to_deg((-body.camera.global_basis.z).angle_to(to))
	var cone := REGARD_REMOTE if is_remote(level, body) else REGARD_LOCAL
	if angle > cone: return none
	if not clear(level, eye, face, exclude + [body.get_rid()]): return none
	var torch_on: bool = "torch" in body and is_instance_valid(body.torch) and body.torch.visible
	var torch: bool = torch_on and d <= TORCH_REACH and angle <= TORCH_FACE_ANGLE
	return {"regards": lit_face or torch or d <= DARK_FACE, "torch": torch}

## Who regards her now and whose torch is on her face, over every alive,
## unhidden survivor (level.survivors()), ascending seats:
## {"regarded_by": [seat...], "torch_by": [seat...]}. One ray per body.
static func regarders(level, face: Vector3, exclude: Array) -> Dictionary:
	var lit_face := lit_point(level, face)
	var regarded: Array[int] = []
	var torched: Array[int] = []
	var seats := {}
	for body in level.survivors():
		if not is_instance_valid(body) or not "slot" in body: continue
		seats[int(body.slot)] = body
	var order: Array = seats.keys()
	order.sort()
	for seat in order:
		var look := look_of(level, seats[seat], face, exclude, lit_face)
		if bool(look.regards): regarded.append(int(seat))
		if bool(look.torch): torched.append(int(seat))
	return {"regarded_by": regarded, "torch_by": torched}

## Whether anybody would see her along these points of her way: the first,
## the middle (index size / 2) and the last, each with its own lit_point().
static func stretch_exposed(level, points: PackedVector3Array, exclude: Array) -> bool:
	if points.is_empty(): return false
	var picks := [0, points.size() / 2, points.size() - 1]
	for i in picks:
		var at: Vector3 = points[i]
		if not regarders(level, at, exclude).regarded_by.is_empty(): return true
	return false

## Just off to the side of a view, where a turn of the head finds it.
static func beside(eye: Vector3, forward: Vector3, point: Vector3, band := BESIDE) -> bool:
	var dot := forward.dot((point - eye).normalized())
	return dot >= band.x and dot <= band.y

static func beside_view(camera: Camera3D, point: Vector3, band := BESIDE) -> bool:
	return beside(camera.global_position, -camera.global_basis.z, point, band)

## She is behind them (REAR_DOT) or above them out of their look (OVER_*):
## the author's cue from above (24 October 2026) is the second.
static func behind_of(eye: Vector3, view: Vector3, face: Vector3) -> bool:
	return rear_of(eye, view, face) or over_of(eye, view, face)

static func rear_of(eye: Vector3, view: Vector3, face: Vector3) -> bool:
	var to := face - eye
	if to.length() < 0.01: return false
	var flat := Vector3(to.x, 0, to.z)
	var ahead := Vector3(view.x, 0, view.z)
	return flat.length() > 0.2 and ahead.length() > 0.01 and ahead.normalized().dot(flat.normalized()) <= REAR_DOT

static func over_of(eye: Vector3, view: Vector3, face: Vector3) -> bool:
	var to := face - eye
	if to.length() < 0.01: return false
	return to.normalized().y >= OVER_SIN and view.normalized().dot(to.normalized()) < OVER_LOOK
