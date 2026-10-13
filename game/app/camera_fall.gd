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
## The fall (route). What pulls it down; how fast up the swipe sends it off
## the hand (m/s); how high it hops off the floor and the share of its speed
## over the ground it keeps through that; and how far it turns over in the
## air: at least this much on its way down (radians) and between these on
## the hop (degrees).
const GRAVITY := 9.8
const TOSS := Vector2(0.2, 0.9)
const HOP := Vector2(0.05, 0.09)
const HOP_KEEP := 0.5
const AIR_LEAST := 2.0
const HOP_TURN := Vector2(100.0, 190.0)
## Going over on its edges: half its body across and half up (metres: what
## it is, tools/props/build_camcorder.gd), so each quarter turn takes it
## STEP further; how long each of the last ones takes, the slowest last; and
## how nearly it stops on top of an edge, from the first of those to the last.
const SECTION := Vector2(0.055, 0.06)
const STEP := 0.115
const KNOCK_TIME := [0.15, 0.2, 0.3]
const KNOCK_SLOW := Vector2(0.3, 0.86)
## And once it lies: how long it rocks, how far (degrees), how fast and how
## soon that dies.
const ROCK := 0.36
const ROCK_ANGLE := 5.0
const ROCK_RATE := 6.5
const ROCK_FADE := 0.1
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
## Returns {rest: Transform3D, kind, leaned, score, tried, valid} and its fall (route).
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
	route(space, best, from, seed_value, exclude)
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

## How it gets there (docs/EXECUTION.md, 8.2): as a thing that weighs what a
## camcorder weighs. Knocked out of the hand it falls as anything falls -- the
## time that takes is the height's, not the scene's --, turning over at the
## rate the blow gave it; it hits the floor, hops once, shorter and slower,
## and what is left of its way it goes over on its edges, a quarter turn at a
## time, each slower than the one before and the last barely making it over,
## until it rocks on the side it stays on. All of it a function of the time
## since the swipe, drawn from the capture's seed and tried against the same
## walls on every machine: the same fall at any frame rate, for its owner
## (death_tape.gd) and for whoever watches it go (executions.move_camcorder).
##
## Added to `take`: `landed` and `hopped` (seconds from the swipe to the floor
## and to the end of the hop), `duration` (to lying still), `knocks` (when
## each quarter turn comes down), and what pose() needs.
static func route(space: PhysicsDirectSpaceState3D, take: Dictionary, from: Vector3, seed_value: int, exclude: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 0x2545f491
	var rest: Transform3D = take.rest
	var toss := rng.randf_range(TOSS.x, TOSS.y)
	var drop := maxf(from.y - rest.origin.y, 0.05)
	var flight := (toss + sqrt(toss * toss + 2.0 * GRAVITY * drop)) / GRAVITY
	var hop_height := rng.randf_range(HOP.x, HOP.y)
	var hop := 2.0 * sqrt(2.0 * hop_height / GRAVITY)
	# Over on its edges, about the way its lens points and so across it: the
	# picture turns on itself a quarter at a time. As many times as the place
	# has room for, to the side it was already going if it can.
	var lens := Vector3(-rest.basis.z.x, 0.0, -rest.basis.z.z)
	var way := Vector3.ZERO
	var count := 0
	if lens.length() > 0.5:
		var side := lens.normalized().cross(Vector3.UP)
		var going := Vector3(rest.origin.x - from.x, 0.0, rest.origin.z - from.z)
		if side.dot(going) < 0.0: side = -side
		var wanted := rng.randi_range(2, KNOCK_TIME.size())
		for tried in range(wanted, 0, -1):
			for towards in [side, -side]:
				var start: Vector3 = rest.origin - (towards as Vector3) * STEP * float(tried)
				if not sees(space, rest.origin + Vector3.UP * 0.04, start + Vector3.UP * 0.04, exclude) or not sees(space, from, start + Vector3.UP * 0.1, exclude): continue
				if floor_under(space, start, exclude) == Vector3.INF: continue
				way = towards
				count = tried
				break
			if count > 0: break
	var times: Array = KNOCK_TIME.slice(KNOCK_TIME.size() - count)
	var start_at: Vector3 = rest.origin - way * STEP * float(count)
	# Where it first hits the floor: it keeps HOP_KEEP of its speed over the
	# ground through the hop, and the two together get it to where it rolls from.
	var across := Vector3(start_at.x - from.x, 0.0, start_at.z - from.z)
	var strike := Vector3(from.x, start_at.y, from.z) + across * (flight / (flight + HOP_KEEP * hop))
	take["toss"] = toss
	take["landed"] = flight
	take["hop"] = hop
	take["hop_height"] = hop_height
	take["hopped"] = flight + hop
	take["strike"] = strike
	take["start"] = start_at
	take["way"] = way
	take["times"] = times
	var knocks: Array = []
	var clock := flight + hop
	for length in times:
		clock += float(length)
		knocks.append(clock)
	take["knocks"] = knocks
	take["duration"] = clock
	# How it turns in the air between the floor and the floor.
	take["hop_axis"] = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.3, 0.3), rng.randf_range(-1.0, 1.0)).normalized()
	take["hop_turn"] = deg_to_rad(rng.randf_range(HOP_TURN.x, HOP_TURN.y))
	take["axis"] = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.35, 0.35), rng.randf_range(-1.0, 1.0)).normalized()

## The fall of a camcorder that comes to lie at `rest`, for a machine that
## was only told where (executions.note_lens): the same one its owner's makes.
static func fall_to(space: PhysicsDirectSpaceState3D, rest: Transform3D, from: Vector3, seed_value: int, exclude: Array) -> Dictionary:
	var take := {"rest": rest}
	route(space, take, from, seed_value, exclude)
	return take

## How it is turned as it starts to go over on its edges.
static func rolled(take: Dictionary, quarters: float) -> Basis:
	var way: Vector3 = take.way
	if way == Vector3.ZERO: return (take.rest as Transform3D).basis
	return Basis(Vector3.UP.cross(way).normalized(), -quarters * PI * 0.5) * (take.rest as Transform3D).basis

## Where it is and how it is turned `time` seconds after the swipe took it
## from `from`.
static func pose(take: Dictionary, from: Transform3D, time: float) -> Transform3D:
	var rest: Transform3D = take.rest
	var landed := float(take.landed)
	var hopped := float(take.hopped)
	var times: Array = take.times
	var count := times.size()
	var start: Vector3 = take.start
	var strike: Vector3 = take.strike
	var rolling := rolled(take, float(count))
	var struck := Basis(take.hop_axis as Vector3, -float(take.hop_turn)) * rolling
	if time < landed:
		# In the air: nothing pushes it but its weight, and it turns at one rate
		# about one axis, the nearest way round that is most of a turn.
		var t := maxf(time, 0.0)
		var point := from.origin.lerp(Vector3(strike.x, from.origin.y, strike.z), t / landed)
		point.y = from.origin.y + float(take.toss) * t - 0.5 * GRAVITY * t * t
		point.y = maxf(point.y, strike.y)
		var between := (struck * from.basis.orthonormalized().inverse()).get_rotation_quaternion()
		var angle := between.get_angle()
		var axis: Vector3 = between.get_axis() if angle > 0.02 and between.get_axis().is_finite() else (take.axis as Vector3)
		if angle <= 0.02: angle = 0.0
		if angle > PI:
			angle = TAU - angle
			axis = -axis
		# The short way if that is turn enough to be a fall; the long way round
		# if it would have come down all but as it left the hand.
		var turn := angle if angle >= AIR_LEAST else angle - TAU
		return Transform3D(Basis(axis.normalized(), turn * t / landed) * from.basis.orthonormalized(), point)
	if time < hopped:
		var u := (time - landed) / maxf(float(take.hop), 0.001)
		var point := strike.lerp(start, u)
		point.y += 4.0 * float(take.hop_height) * u * (1.0 - u)
		return Transform3D(Basis(take.hop_axis as Vector3, -float(take.hop_turn) * (1.0 - u)) * rolling, point)
	var way: Vector3 = take.way
	var since := time - hopped
	for index in count:
		var length := float(times[index])
		if since < length:
			# Over one edge: quick off the floor, slow at the top of it -- the
			# last ones all but stop there -- and down on the next side. Its
			# middle goes up over the edge and comes down further on.
			var u := since / length
			var slow := lerpf(KNOCK_SLOW.x, KNOCK_SLOW.y, float(index + KNOCK_TIME.size() - count) / maxf(float(KNOCK_TIME.size() - 1), 1.0))
			var turned := u + slow * sin(TAU * u) / TAU
			var angle := turned * PI * 0.5
			var low := SECTION.x if index % 2 == 0 else SECTION.y
			var wide := SECTION.y if index % 2 == 0 else SECTION.x
			var along := (-wide * cos(angle) + low * sin(angle) + wide) / (low + wide)
			var over := wide * sin(angle) + low * cos(angle) - lerpf(low, wide, turned)
			return Transform3D(rolled(take, float(count - index) - turned), start + way * STEP * (float(index) + along) + Vector3.UP * over)
		since -= length
	# On the side it stays on: it rocks there, less each time.
	if since < ROCK and not is_zero_approx(float(take.duration)):
		var axis := Vector3.UP.cross(way).normalized() if way != Vector3.ZERO else rest.basis.z.normalized()
		var rock := deg_to_rad(ROCK_ANGLE) * sin(TAU * ROCK_RATE * since) * exp(-since / ROCK_FADE) * (1.0 - since / ROCK)
		return Transform3D(Basis(axis, rock) * rest.basis, rest.origin + Vector3.UP * absf(rock) * 0.03)
	return rest

## When it hits something, seconds from the swipe, and how hard (1 the floor
## the first time): the floor, the floor again, and each edge it comes down on.
static func blows(take: Dictionary) -> Array:
	var said: Array = [[float(take.landed), 1.0], [float(take.hopped), 0.5]]
	var knocks: Array = take.knocks
	for index in knocks.size(): said.append([float(knocks[index]), 0.34 - 0.06 * float(index)])
	return said
