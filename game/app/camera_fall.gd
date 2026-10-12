extends RefCounted
## Where the camcorder ends up when it is knocked out of its owner's hands
## (docs/EXECUTION.md, section 8): a place on the floor near the capture from
## which the tape goes on recording what is done to them, how it lies there,
## and how it gets there. Worked out once, at the grab, on the machine of
## whoever dies, with a few hundred rays; it holds no state and knows nothing
## of the level but the physics it is handed, so it can be tried on any room
## from a test.
##
## A camcorder does not land level: it lies on one of its sides, propped a
## little by its own lens, and what it sees is half hidden by whatever is next
## to it. That is the picture this looks for, and when no place gives one --
## a corner, a wardrobe's mouth, a corridor full of somebody else -- the
## camera falls face down at its owner's feet and the tape records only sound,
## which is a take as good as any other and is why there is nowhere in the
## hotel this cannot be resolved.

## What the fallen camera records: the body held up and its fall; only part of
## it; or nothing but the carpet.
enum { VIEW, PARTIAL, DOWN }
const NAMES := ["ve", "ve a medias", "boca abajo"]

## Candidate places: this many directions round the middle of the capture, at
## each of these distances (metres), on the floor.
const DIRECTIONS := 16
const RADII := [0.9, 1.5, 2.2]
## Room the camcorder needs round its lens, and what counts as in its way:
## walls and furniture (1), door leaves shut (8) or standing open (64, 128).
const CLEARANCE := 0.12
const SOLID := 1 | 8
const ANY_LEAF := 1 | 8 | 64 | 128
## How far the floor under a candidate may be from the floor of the capture:
## the top of a table or the planta below are not places it falls to.
const FLOOR_SLACK := 0.2
## Nearer than this to the creature's feet, or to the body where it will
## lie, it would be under them.
const KEEP_OFF := 0.45
const KEEP_BODY := 0.4
## In the dark the camcorder's own lamp is all the light there is, and it
## reaches about a metre: the body has to fall within it.
const DARK_REACH := 1.05
## How it lies, which is how the baked prop lies (tools/props/build_camcorder.gd:
## 27 cm long behind its lens, which is 2.4 cm from one of its sides and 6.6
## from the other): on one side or the other, with its tail on the floor and
## its lens tipped up between PITCH degrees, which is what raises the lens.
const LENS_SIDE := {-1.0: 0.076, 1.0: 0.034}
const LENGTH := 0.27
const PITCH := Vector2(8.0, 20.0)
## It does not lie flat on either side -- the strap is on one, the viewfinder
## and the lens barrel stand out of the other -- so it is rolled short of a
## quarter turn one way and a little past it the other (degrees).
const ROLL := {-1.0: Vector2(80.0, 102.0), 1.0: Vector2(56.0, 78.0)}
## The fall: how long it takes, how high it goes on its way.
const FLIGHT := Vector2(0.32, 0.4)
const ARC := Vector2(0.2, 0.5)
## Its field of view as it lies (the lens wide, camcorder_look.VIEW_FOV), to
## judge what falls in the picture.
const VIEW_HALF := deg_to_rad(39.0)
## How far to either side of where it points something can be and still be
## well inside the picture's short way.
const AIM_SPREAD := deg_to_rad(26.0)

## scene:
##   from      where the camera is when the swipe takes it (world)
##   middle    the floor between victim and creature
##   hold      the floor under where the body is held up
##   body      the floor where the body will lie (its middle)
##   head      and where its head will be: it lies from `hold` to there
##   creature  its feet
##   torch     where its owner's torch comes to rest, or Vector3.INF
##   dark      nothing lights the place but the camcorder's own lamp
##   exclude   bodies the rays go through (the victim's, the creature's)
##   allowed   Callable(point) -> bool: false for a place it must not land
##             (a refuge, the sweep of a door on the move)
## Returns {rest: Transform3D, kind, leaned, apex, turns, axis, duration, score, tried, valid}.
static func solve(space: PhysicsDirectSpaceState3D, scene: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var from: Vector3 = scene.from
	var middle: Vector3 = scene.middle
	var exclude: Array = scene.get("exclude", [])
	var best := {}
	var tried := 0
	var valid := 0
	var turn := rng.randf() * TAU
	for radius in RADII:
		for index in DIRECTIONS:
			tried += 1
			var angle := turn + TAU * float(index) / float(DIRECTIONS)
			var spot := settle(space, scene, middle + Vector3(cos(angle), 0.0, sin(angle)) * float(radius), exclude)
			if spot.is_empty(): continue
			valid += 1
			for side in [-1.0, 1.0]:
				var take := frame(space, scene, spot, side, rng, exclude)
				if take.is_empty(): continue
				if best.is_empty() or float(take.score) > float(best.score): best = take
	if best.is_empty() or int(best.kind) == DOWN: best = face_down(space, scene, rng, exclude)
	best["tried"] = tried
	best["valid"] = valid
	route(best, from, rng)
	return best

## The floor at a point, or INF when there is none within reach of it.
static func floor_under(space: PhysicsDirectSpaceState3D, point: Vector3, exclude: Array) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.9, point - Vector3.UP * 0.8, SOLID)
	query.exclude = exclude
	var hit := space.intersect_ray(query)
	return hit.position if not hit.is_empty() else Vector3.INF

## Whether the camcorder has room at a place on the floor.
static func clear(space: PhysicsDirectSpaceState3D, ground: Vector3, exclude: Array) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = CLEARANCE
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.collision_mask = ANY_LEAF
	query.exclude = exclude
	query.transform = Transform3D(Basis.IDENTITY, ground + Vector3.UP * (CLEARANCE + 0.04))
	return space.intersect_shape(query, 1).is_empty()

## A candidate brought down to a place the camera can really end at: on the
## floor of the capture, with room, reached from the hand in a straight line
## -- or, with something in the way, at the foot of whatever stopped it.
## {ground, leaned} or nothing.
static func settle(space: PhysicsDirectSpaceState3D, scene: Dictionary, wanted: Vector3, exclude: Array) -> Dictionary:
	var level_y: float = (scene.middle as Vector3).y
	var from: Vector3 = scene.from
	var ground := floor_under(space, Vector3(wanted.x, level_y, wanted.z), exclude)
	var leaned := false
	var target := (ground if ground != Vector3.INF else Vector3(wanted.x, level_y, wanted.z)) + Vector3.UP * 0.15
	var query := PhysicsRayQueryParameters3D.create(from, target, ANY_LEAF)
	query.exclude = exclude
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		# Stopped on the way: it drops where it was stopped, a little short.
		var back := (from - (hit.position as Vector3))
		back.y = 0.0
		if back.length() < 0.05: return {}
		var stopped: Vector3 = hit.position + back.normalized() * (CLEARANCE + 0.07)
		ground = floor_under(space, Vector3(stopped.x, level_y, stopped.z), exclude)
		leaned = true
	if ground == Vector3.INF or absf(ground.y - level_y) > FLOOR_SLACK: return {}
	if not clear(space, ground, exclude): return {}
	var flat := Vector2(ground.x, ground.z)
	var creature: Vector3 = scene.creature
	if flat.distance_to(Vector2(creature.x, creature.z)) < KEEP_OFF: return {}
	# Not under the body either, anywhere along where it will lie.
	var lying := from_body(scene, flat)
	if lying < KEEP_BODY: return {}
	var allowed: Callable = scene.get("allowed", Callable())
	if allowed.is_valid() and not bool(allowed.call(ground)): return {}
	if bool(scene.get("dark", false)) and lying > DARK_REACH: return {}
	return {"ground": ground, "leaned": leaned}

## How far a place on the floor is from the body as it will lie: from the
## line between where it is let go and where its head ends up.
static func from_body(scene: Dictionary, flat: Vector2) -> float:
	var feet := Vector2((scene.hold as Vector3).x, (scene.hold as Vector3).z)
	var top: Vector3 = scene.get("head", scene.body)
	var head := Vector2(top.x, top.z)
	var along := head - feet
	if along.length() < 0.01: return flat.distance_to(feet)
	var t := clampf((flat - feet).dot(along) / along.length_squared(), 0.0, 1.0)
	return flat.distance_to(feet + along * t)

## Nothing between two points but what the rays are told to go through.
static func sees(space: PhysicsDirectSpaceState3D, eye: Vector3, point: Vector3, exclude: Array) -> bool:
	var query := PhysicsRayQueryParameters3D.create(eye, point, ANY_LEAF)
	query.exclude = exclude
	return space.intersect_ray(query).is_empty()

## The camcorder lying at a place on one of its sides, turned towards what is
## about to happen: what it would record from there, and how good a take it
## is. Nothing when it would see none of it.
static func frame(space: PhysicsDirectSpaceState3D, scene: Dictionary, spot: Dictionary, side: float, rng: RandomNumberGenerator, exclude: Array) -> Dictionary:
	var ground: Vector3 = spot.ground
	# Seen first from where the lens would be lying flat; raised below, once
	# it is known how far it is tipped up.
	var eye := ground + Vector3.UP * float(LENS_SIDE[side])
	var hold: Vector3 = scene.hold
	var body: Vector3 = scene.body
	var creature: Vector3 = scene.creature
	# What there is to see: the legs and the trunk of the body held up, the
	# floor it will fall on, and the creature's own legs.
	var legs := hold + Vector3.UP * 0.9
	var trunk := hold + Vector3.UP * 1.9
	var fallen := body + Vector3.UP * 0.15
	var shins := creature + Vector3.UP * 0.5
	var sees_legs := sees(space, eye, legs, exclude)
	var sees_trunk := sees(space, eye, trunk, exclude)
	var sees_fall := sees(space, eye, fallen, exclude)
	var sees_shins := sees(space, eye, shins, exclude)
	if not (sees_legs or sees_trunk or sees_fall or sees_shins): return {}
	var kind := VIEW if sees_fall and (sees_legs or sees_trunk) else PARTIAL
	# Turned so that both are in the picture: the body held up and the floor
	# it will fall on, each to one side of the middle. Lying on its side, what
	# is across the room is the short way of the picture, so they have to be
	# within AIM_SPREAD of each other; further apart, it keeps the body held
	# up, with the floor beside it at the edge.
	var to_hold := atan2(-(legs.x - eye.x), -(legs.z - eye.z))
	var to_fall := atan2(-(fallen.x - eye.x), -(fallen.z - eye.z))
	var between := wrapf(to_fall - to_hold, -PI, PI)
	var spread := absf(between) * 0.5
	var slack := maxf(0.0, AIM_SPREAD - spread)
	var yaw := to_hold + signf(between) * minf(spread, AIM_SPREAD) + rng.randf_range(-slack, slack) * 0.5
	# And tipped up to it: the nearer it lies, the more.
	var away := legs - eye
	var flat := Vector2(away.x, away.z).length()
	var pitch := deg_to_rad(clampf(rad_to_deg(atan2(away.y, maxf(flat, 0.01))), PITCH.x, PITCH.y))
	var roll := side * deg_to_rad(rng.randf_range((ROLL[side] as Vector2).x, (ROLL[side] as Vector2).y))
	eye += Vector3.UP * LENGTH * 0.85 * sin(pitch)
	var rest := Transform3D(Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Basis(Vector3.BACK, roll), eye)
	var forward := -rest.basis.z
	# Something close taking up part of the frame -- a chair's leg, the edge of
	# a door, a wardrobe's side -- is what makes it a camera on the floor and
	# not a shot. Between a quarter and a little over half is wanted.
	var blocked := 0
	var rays := 0
	for column in 5:
		for row in 3:
			var across := (float(column) - 2.0) / 2.0 * VIEW_HALF * 1.25
			var up := (float(row) - 1.0) * VIEW_HALF * 0.6
			var way := (rest.basis * Basis.from_euler(Vector3(up, -across, 0.0)) * Vector3.FORWARD).normalized()
			rays += 1
			var query := PhysicsRayQueryParameters3D.create(eye, eye + way * 0.7, ANY_LEAF)
			query.exclude = exclude
			var hit := space.intersect_ray(query)
			# The floor right under the lens is not something in the way.
			if not hit.is_empty() and (hit.position as Vector3).y > ground.y + 0.04: blocked += 1
	var covered := float(blocked) / float(rays)
	var score := 0.0
	score += 3.0 if sees_fall else 0.0
	score += 2.0 if sees_legs else 0.0
	score += 1.0 if sees_trunk else 0.0
	score += 0.6 if sees_shins else 0.0
	score += 1.2 * (1.0 - clampf(absf(covered - 0.4) / 0.4, 0.0, 1.0))
	if covered > 0.7: score -= 2.5
	# Near enough for the body to be big in the picture, not so near it is on it.
	var reach := Vector2(eye.x - hold.x, eye.z - hold.z).length()
	score += 2.4 * (1.0 - clampf(absf(reach - 1.05) / 1.05, 0.0, 1.0))
	# A hand falling next to the lens is the last thing the tape sees: near
	# where the head will be, not beside the legs.
	var top: Vector3 = scene.get("head", body)
	var beside := Vector2(eye.x - top.x, eye.z - top.z).length()
	score += 1.2 * (1.0 - clampf(absf(beside - 0.65) / 0.65, 0.0, 1.0))
	# Best of all from where the body falls towards it: the floor it lands on,
	# the body held up behind that and the creature behind the body, in a line.
	var along := Vector2(body.x - hold.x, body.z - hold.z)
	var out := Vector2(eye.x - hold.x, eye.z - hold.z)
	if along.length() > 0.05 and out.length() > 0.05: score += 1.6 * maxf(0.0, along.normalized().dot(out.normalized()))
	score -= 2.0 * clampf((spread - AIM_SPREAD) / AIM_SPREAD, 0.0, 1.0)
	# With the torch on the floor, the wall its beam throws the shadows on.
	var torch: Vector3 = scene.get("torch", Vector3.INF)
	if torch != Vector3.INF:
		var lit := (creature + Vector3.UP * 1.2 - torch).normalized()
		score += 1.2 * maxf(0.0, forward.dot(lit))
	if bool(spot.leaned): score -= 0.3
	score += rng.randf() * 0.3
	return {"rest": rest, "kind": kind, "leaned": bool(spot.leaned), "score": score, "covered": covered, "side": side}

## No place to see from: at its owner's feet, lens to the carpet.
static func face_down(space: PhysicsDirectSpaceState3D, scene: Dictionary, rng: RandomNumberGenerator, exclude: Array) -> Dictionary:
	var from: Vector3 = scene.from
	var level_y: float = (scene.middle as Vector3).y
	var ground := floor_under(space, Vector3(from.x, level_y, from.z), exclude)
	if ground == Vector3.INF or absf(ground.y - level_y) > 0.6: ground = Vector3(from.x, level_y, from.z)
	var rest := Transform3D(Basis.from_euler(Vector3(deg_to_rad(rng.randf_range(-82.0, -70.0)), rng.randf() * TAU, 0.0)) * Basis(Vector3.BACK, rng.randf_range(-0.5, 0.5)), ground + Vector3.UP * 0.06)
	return {"rest": rest, "kind": DOWN, "leaned": false, "score": 0.0, "covered": 1.0, "side": 1.0}

## How it gets there: an arc and a tumble, the same every time for the same
## seed. `apex` is how high over the straight line its path goes, `axis` and
## `turns` the tumble (whole turns, so it ends exactly as it lies).
static func route(take: Dictionary, from: Vector3, rng: RandomNumberGenerator) -> void:
	var rest: Transform3D = take.rest
	var span := from.distance_to(rest.origin)
	take["duration"] = lerpf(FLIGHT.x, FLIGHT.y, clampf((span - 1.0) / 2.0, 0.0, 1.0))
	take["apex"] = lerpf(ARC.x, ARC.y, rng.randf()) * (0.5 if int(take.kind) == DOWN else 1.0)
	take["turns"] = 1
	take["axis"] = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.35, 0.35), rng.randf_range(-1.0, 1.0)).normalized()

## Where it is and how it is turned `time` seconds into its fall (0 as the
## swipe takes it, `duration` as it touches the floor), from where it was.
static func flight(take: Dictionary, from: Transform3D, time: float) -> Transform3D:
	var rest: Transform3D = take.rest
	var s := clampf(time / maxf(float(take.duration), 0.01), 0.0, 1.0)
	# Thrown, not carried: quick off the hand, falling into the floor.
	var along := 1.0 - pow(1.0 - s, 1.6)
	var point := from.origin.lerp(rest.origin, along)
	point.y = lerpf(from.origin.y, rest.origin.y, s * s) + float(take.apex) * sin(PI * s) * (1.0 - s * 0.35)
	var spin := Basis(take.axis as Vector3, TAU * float(take.turns) * along)
	var turned := Basis(from.basis.get_rotation_quaternion().slerp(rest.basis.get_rotation_quaternion(), along))
	return Transform3D(spin * turned, point)

## Settling after it lands: two bounces and a rock, gone in a fifth of a
## second. `since` is seconds since it touched the floor.
static func settle_offset(since: float) -> Transform3D:
	if since < 0.0 or since > 0.24: return Transform3D.IDENTITY
	var first := maxf(0.0, sin(PI * clampf(since / 0.1, 0.0, 1.0))) * 0.06
	var second := maxf(0.0, sin(PI * clampf((since - 0.1) / 0.08, 0.0, 1.0))) * 0.02
	var rock := sin(since * 70.0) * 0.05 * exp(-since * 22.0)
	return Transform3D(Basis(Vector3.BACK, rock) * Basis(Vector3.RIGHT, rock * 0.6), Vector3.UP * (first + second))
