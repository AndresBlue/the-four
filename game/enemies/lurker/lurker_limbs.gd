extends SkeletonModifier3D
## The Lurker's seven hands on whatever is near them: the floor, a wall, the
## ceiling. Like The Locust's feet (locust_visual.gd) each hand stays planted
## where it is in the world and only moves in a step; but it looks for its hold
## in every direction round its shoulder, from under the body to over it, so in
## a corridor the hands take the walls and the ceiling as readily as the floor.
## The seven step in two sets that take turns, as a spider walks, and at a slow
## pace, like a black widow's: long arms, long strides, each hand lifted high
## and set down far ahead, trailing far behind before it steps again, the knees
## (its elbows) riding high. No two arms are alike (anatomy.py, LIMB_SPECS),
## and each has its habit: some reach up for the ceiling, some down for the
## floor, some step slower than the rest.
##
## As in the picture: the arms are never straight (they reach no further than
## ARM_SPAN of their length, so the elbow always shows), the hands land with
## the claws dug in (the wrist held up and each finger curled until its claw's
## point is on what it holds, never through it), and the head leads, turned
## smoothly with the eyes on `look_point`.
##
## Presentation only: it never moves the body (whoever owns it does, and says
## how fast in `velocity`) and changes no collision. Runs after the animation
## player, so the clip still moves the body and the jaw.
signal footfall(point: Vector3, strength: float)

const FINGERS := ["thumb", "index", "middle", "ring", "pinky"]
const LIMBS := ["a.L", "a.R", "b.L", "c.R", "d.L", "e.R", "f.L"]
## Two alternating sets, of three and four.
const GROUP := {"a.L": 0, "c.R": 0, "d.L": 0, "a.R": 1, "b.L": 1, "e.R": 1, "f.L": 1}
## Each arm's habit: how much it would rather reach up for the ceiling and high
## on the walls (above 0) or down for the floor (below 0), and how slow its
## step is against the others'.
const HABIT := {"a.L": Vector2(0.6, 1.0), "a.R": Vector2(0.25, 1.12), "b.L": Vector2(0.9, 0.86),
	"c.R": Vector2(-0.4, 0.95), "d.L": Vector2(0.1, 1.08), "e.R": Vector2(-0.7, 1.2), "f.L": Vector2(0.45, 0.9)}
const REACH_UP := 0.12
## How far ahead, the way it is going, every arm looks for its next hold, so
## each hand lands far ahead and is let go of far behind.
const SWEEP := 0.9
## How long a hand stays on its hold before a better one may take it: without
## it a hand would land and at once be off again to a hold just found.
const DWELL := 0.6
## Where each probe looks, in degrees below the plane of the body (negative is
## above it): straight down to straight up, so a wall or a ceiling within
## reach is found as surely as the floor. Thick near the plane: the holds that
## spread the arms wide are the grazing ones.
const PROBES := [70.0, 46.0, 32.0, 23.0, 16.0, 10.0, 4.0, -12.0, -38.0, -64.0, -86.0]
## The share of an arm's reach at which a hold sits best, and the most of it
## an arm ever uses: never straight.
const IDEAL := 0.66
const ARM_SPAN := 0.88
## How the fingers lie on a hold: how the curl is shared between the three
## joints (each finger curls until its claw touches), the spread of the first,
## how high the wrist is held off the hold (a share of the hand's length, from
## the wrist to the point of the middle claw), how far the
## hand tips down into it, and how deep the claw's point goes; and how they lie
## while the hand travels.
const CLAW := Vector3(0.45, 0.6, 0.85)
const CLAW_SPREAD := 0.3
const WRIST := 0.38
const DIP := 38.0
const DIG := 0.004
const FLYING := Vector3(0.7, 1.0, 0.9)
## How long a step takes, walking and at its fastest; how high the hand lifts
## (a share of the arm's length); how many seconds of travel ahead of the shoulder it
## looks for its next hold; and how hard the elbows are pushed up.
const STEP := Vector2(0.85, 0.45)
const LIFT := 0.22
## The furthest a hold may be when it is chosen (its wrist, against the arm's
## reach, from where the shoulder will be when the hand lands), how far the arm
## may be drawn out before the hand wants to step, and before it steps whatever
## the other hands are doing: a hold the arm cannot get to leaves the hand
## hanging in the air short of it, its claws dragging.
const REACHABLE := 0.8
const DUE := 0.85
const MUST := 0.97
const KNEES := 1.6
## How far the neck juts out towards what it looks at: the head leads.
const LEAD := 0.09
## How far the head twists to keep the face upright when the body is not
## (all the way), and how quickly it follows: never a jump.
const UPRIGHT := PI
const TURN := 5.0
## Physics layers a hand can hold on to: walls, floors and furniture.
@export_flags_3d_physics var world_mask := 1
## The body's velocity in the world, written every frame by whoever moves it.
var velocity := Vector3.ZERO
## 0..1: how hard the fingers grip.
var grip := 1.0
## 0..1: how much it would rather hold a wall or the ceiling than the floor
## (raised high in a narrow place, it holds itself up on the walls).
var cling := 0.0
## What the head and the eyes turn to (the camera, usually); INF for nothing.
var look_point := Vector3.INF
## Off, the clip moves the arms and only the head and the eyes are turned here.
var hands := true
## World metres to one of the skeleton's: the creature is shown bigger than it
## was built (lurker_visual.gd, size).
var size := 1.0
var limbs: Array[Dictionary] = []
var cursor := 0
var swinging := [0, 0]
var neck := -1
var head := -1
var eyes: Array[int] = []
## Where the head is turned, in the world, as it eases towards where it wants.
var head_turn := Quaternion.IDENTITY
var head_turned := false


func _setup(skeleton: Skeleton3D) -> void:
	limbs.clear()
	neck = skeleton.find_bone("neck")
	head = skeleton.find_bone("head")
	eyes = [skeleton.find_bone("eye.L"), skeleton.find_bone("eye.R")]
	for limb in LIMBS:
		var side: String = limb.substr(2, 1)
		var sfx: String = "_" + limb
		var habit: Vector2 = HABIT[limb]
		var entry := {
			"name": limb, "group": GROUP[limb], "habit": habit.x, "pace": habit.y,
			# mirrored bones turn the other way about their Z axis
			"mirror": -1.0 if side == "R" else 1.0,
			"upper": skeleton.find_bone("upperarm" + sfx),
			"fore": skeleton.find_bone("forearm" + sfx),
			"hand": skeleton.find_bone("hand" + sfx),
			"fingers": [], "rests": [], "origins": [], "claws": [],
			"planted": false, "swing": false, "t": 1.0, "duration": 0.25,
			"hold": Vector3.ZERO, "normal": Vector3.UP,
			"from": Vector3.ZERO, "to": Vector3.ZERO, "from_n": Vector3.UP, "to_n": Vector3.UP,
			"best": Vector3.ZERO, "best_n": Vector3.UP, "has_best": false,
			"tuck": Vector3.DOWN,
			# holding nothing (folded in by the body), now and once the step lands
			"free": false, "to_free": false,
			# the way the fingers point while the hand holds on (world; zero
			# until it lands), and how long it has held on
			"away": Vector3.ZERO, "dwell": 0.0,
			# how far above the hold each claw's point is (skeleton units), and how
			# far the wrist is from where it should be (world metres)
			"touch": [0.0, 0.0, 0.0, 0.0, 0.0], "miss": 0.0,
			# where the point of the middle claw is (world), for looking at it
			"claw_at": Vector3.ZERO,
			# how far each finger curls on a hold (a share of CLAW)
			"hooked": [],
		}
		for finger in FINGERS:
			var chain := []
			var rests := []
			var origins := []
			for j in 3:
				var bone := skeleton.find_bone("%s_%02d%s" % [finger, j + 1, sfx])
				chain.append(bone)
				rests.append(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
				origins.append(skeleton.get_bone_rest(bone).origin)
			entry.fingers.append(chain)
			entry.rests.append(rests)
			entry.origins.append(origins)
			# the claw's point, from the last joint: past the end of the last bone
			# (built a little shorter than the one before it) and hooked towards
			# the palm (build.py, claw_meshes)
			var middle: float = (origins[2] as Vector3).length()
			entry.claws.append(Vector3(0.0, middle * 0.85 + middle * 0.96, middle * 0.6))
		# the hand's length, wrist to the point of the middle claw
		var o: Array = entry.origins[2]
		entry.hand_reach = (o[0] as Vector3).length() + (o[1] as Vector3).length() + (o[2] as Vector3).length() + (entry.claws[2] as Vector3).y
		var shoulder := skeleton.get_bone_global_rest(entry.upper).origin
		var elbow := skeleton.get_bone_global_rest(entry.fore).origin
		var wrist := skeleton.get_bone_global_rest(entry.hand).origin
		entry.l1 = shoulder.distance_to(elbow)
		entry.l2 = elbow.distance_to(wrist)
		entry.reach = (entry.l1 + entry.l2) * ARM_SPAN
		# 1 for the biggest pair, whose arm is 1.3 long (anatomy.py, LIMB)
		entry.scale = (entry.l1 + entry.l2) / 1.3
		var out := wrist - shoulder
		out.y = 0.0
		entry.out = out.normalized()
		_hook(entry)
		limbs.append(entry)


## How far each finger curls on a hold. The hand sits on every hold the same
## way (its wrist WRIST of its length off it, tipped DIP towards it), so this
## is worked out once, on a hold of its own: the floor under a wrist held at
## that height.
func _hook(limb: Dictionary) -> void:
	var n := Vector3.UP
	var dip := deg_to_rad(DIP)
	var fingers := (Vector3.BACK * cos(dip) - n * sin(dip)).normalized()
	var palm := (-n - fingers * (-n).dot(fingers)).normalized()
	var hand := Transform3D(Basis(fingers.cross(palm).normalized(), fingers, palm), n * WRIST * float(limb.hand_reach))
	var fan := [-0.6, 1.0, 0.35, -0.35, -1.0]
	limb.hooked = []
	for f in FINGERS.size():
		var on_hold := Quaternion(Vector3.BACK, CLAW_SPREAD * float(limb.mirror) * fan[f])
		var k := _touch(hand, limb.origins[f], limb.rests[f], on_hold, limb.claws[f], Vector3.ZERO, n)
		limb.hooked.append(k)
		limb.touch[f] = _claw_height(hand, limb.origins[f], limb.rests[f], on_hold, limb.claws[f], k, Vector3.ZERO, n)


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or delta <= 0.0: return
	if limbs.is_empty(): _setup(skeleton)
	var xf := skeleton.global_transform
	var basis := xf.basis.orthonormalized()
	size = xf.basis.get_scale().x
	var up := basis.y
	var space := skeleton.get_world_3d().direct_space_state
	if not hands:
		_look(skeleton, xf, delta)
		return
	# a few probes a frame: every hand looks round itself every four frames
	for i in 2:
		_probe(limbs[cursor], skeleton, xf, basis, up, space)
		cursor = (cursor + 1) % limbs.size()
	swinging = [0, 0]
	for limb in limbs:
		if limb.swing: swinging[limb.group] += 1
	var speed := velocity.length()
	for limb in limbs:
		var socket: Vector3 = xf * skeleton.get_bone_global_pose(limb.upper).origin
		limb.tuck = socket + ((basis * limb.out) * 0.35 + up * 0.12) * limb.reach * size
		if not limb.planted or limb.hold.distance_to(socket) > limb.reach * size * 2.5:
			_probe(limb, skeleton, xf, basis, up, space)
			limb.free = not limb.has_best
			limb.hold = limb.best if limb.has_best else limb.tuck
			limb.normal = limb.best_n if limb.has_best else up
			limb.planted = true
		_step(limb, socket, delta, speed)
		_reach(limb, skeleton, xf, basis, up)
	_look(skeleton, xf, delta)


## Looks for the best hold round one hand, from a little ahead of its shoulder:
## only where its wrist can really get to.
func _probe(limb: Dictionary, skeleton: Skeleton3D, xf: Transform3D, basis: Basis, up: Vector3, space: PhysicsDirectSpaceState3D) -> void:
	var socket: Vector3 = xf * skeleton.get_bone_global_pose(limb.upper).origin
	# from where the shoulder will be when a step started now lands
	var from: Vector3 = socket + velocity * _step_time(limb) * 0.9
	var out: Vector3 = basis * limb.out
	if velocity.length() > 0.05:
		var heading := velocity.normalized()
		out += (heading - up * heading.dot(up)) * SWEEP
		out = (out - up * out.dot(up)).normalized()
	var best_score := INF
	limb.has_best = false
	for angle in PROBES:
		var a := deg_to_rad(angle)
		var direction: Vector3 = (out * cos(a) - up * sin(a)).normalized()
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * float(limb.reach) * size, world_mask)
		var hit := space.intersect_ray(query)
		if hit.is_empty(): continue
		var wrist_at: Vector3 = hit.position + (hit.normal as Vector3) * WRIST * float(limb.hand_reach) * size
		var share: float = from.distance_to(wrist_at) / (limb.reach * size)
		if share > REACHABLE: continue
		# a hold nearer the ideal reach wins; one ahead a little more; a wall or
		# the ceiling more again while it clings
		var score: float = absf(share - IDEAL)
		score -= 0.12 * clampf(velocity.normalized().dot(direction), 0.0, 1.0)
		score -= cling * 0.22 * (1.0 - absf((hit.normal as Vector3).dot(up)))
		# and each arm its habit: up for the ceiling, down for the floor
		score -= REACH_UP * float(limb.habit) * direction.dot(Vector3.UP)
		if score < best_score:
			best_score = score
			limb.best = hit.position
			limb.best_n = hit.normal
			limb.has_best = true


func _step(limb: Dictionary, socket: Vector3, delta: float, speed: float) -> void:
	if limb.swing:
		limb.t = minf(1.0, limb.t + delta / limb.duration)
		var eased: float = limb.t * limb.t * (3.0 - 2.0 * limb.t)
		var lift: float = sin(PI * limb.t) * LIFT * (limb.l1 + limb.l2) * size * (0.75 + 0.25 * float(limb.pace))
		var normal: Vector3 = limb.from_n.slerp(limb.to_n, eased) if limb.from_n.dot(limb.to_n) > -0.99 else limb.to_n
		limb.hold = limb.from.lerp(limb.to, eased) + normal * lift
		limb.normal = normal
		if limb.t >= 1.0:
			limb.swing = false
			limb.hold = limb.to
			limb.normal = limb.to_n
			limb.free = limb.to_free
			limb.dwell = 0.0
			if not limb.free: footfall.emit(limb.to, clampf(speed / 2.5, 0.2, 1.0) * limb.scale)
		return
	limb.dwell += delta
	# how far the arm is drawn out: to where its wrist is, off the hold
	var wrist_at: Vector3 = limb.hold if limb.free else limb.hold + (limb.normal as Vector3) * WRIST * float(limb.hand_reach) * size
	var stretch: float = wrist_at.distance_to(socket) / (limb.reach * size)
	var drift: float = limb.hold.distance_to(limb.best) / (limb.reach * size) if limb.has_best else 0.0
	# out of reach, it must step; for a better hold, only once it has held on a
	# while, and only for one that is much better
	var due: bool = stretch > DUE or (limb.dwell > DWELL and drift > (0.45 if speed > 0.05 else 0.3))
	var other: int = 1 - limb.group
	var free: bool = swinging[other] == 0 and swinging[limb.group] < 4
	if stretch > MUST and not limb.has_best and not limb.free:
		# nothing within reach: it folds the hand in by the body to wait
		limb.swing = true
		limb.t = 0.0
		limb.from = limb.hold
		limb.from_n = limb.normal
		limb.to = limb.tuck
		limb.to_n = limb.normal
		limb.to_free = true
		limb.duration = STEP.x * float(limb.pace)
		swinging[limb.group] += 1
		return
	# a folded hand takes the first hold it finds
	if limb.free and limb.has_best: due = true
	if due and limb.has_best and (free or stretch > MUST or limb.free):
		limb.swing = true
		limb.t = 0.0
		limb.from = limb.hold
		limb.from_n = limb.normal
		limb.to = limb.best
		limb.to_n = limb.best_n
		limb.to_free = false
		limb.duration = _step_time(limb)
		swinging[limb.group] += 1


func _reach(limb: Dictionary, skeleton: Skeleton3D, xf: Transform3D, basis: Basis, up: Vector3) -> void:
	var inv := xf.affine_inverse()
	var normal_world: Vector3 = limb.normal
	var out_world: Vector3 = basis * limb.out
	# the wrist held up off the hold: the claws are what touch it
	var held: bool = not limb.free and not (limb.swing and limb.to_free)
	var target_world: Vector3 = limb.hold + normal_world * WRIST * float(limb.hand_reach) * size if held else limb.hold
	var s: Vector3 = skeleton.get_bone_global_pose(limb.upper).origin
	var t: Vector3 = inv * target_world
	var pole: Vector3 = inv.basis * (up * KNEES + out_world * 0.5)
	var a: float = limb.l1
	var b: float = limb.l2
	var span: Vector3 = t - s
	var d: float = clampf(span.length(), absf(a - b) + 0.002, (a + b) * ARM_SPAN)
	var along: Vector3 = span.normalized()
	var side: Vector3 = pole - along * pole.dot(along)
	if side.length_squared() < 1e-8: side = along.cross(Vector3.RIGHT)
	side = side.normalized()
	var x: float = (a * a - b * b + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(a * a - x * x, 0.0))
	var elbow: Vector3 = s + along * x + side * h
	var tip: Vector3 = s + along * d
	limb.miss = tip.distance_to(t) * size if held and not limb.swing else 0.0
	var y1: Vector3 = (elbow - s).normalized()
	var y2: Vector3 = (tip - elbow).normalized()
	var bend: Vector3 = y1.cross(y2)
	if bend.length_squared() < 1e-8: bend = along.cross(side)
	bend = bend.normalized()
	skeleton.set_bone_global_pose(limb.upper, Transform3D(_frame(y1, bend), s))
	skeleton.set_bone_global_pose(limb.fore, Transform3D(_frame(y2, bend), elbow))
	# the hand tipped down into the hold, fingers pointing away from the body
	var n: Vector3 = (inv.basis * normal_world).normalized()
	var away: Vector3 = tip - s
	away = away - n * away.dot(n)
	if away.length_squared() < 1e-8: away = inv.basis * out_world
	away = away.normalized()
	# held on, the hand stays as it landed, its claws where they went in; it
	# only turns with the arm while it travels
	if held and not limb.swing:
		if limb.away == Vector3.ZERO: limb.away = xf.basis.orthonormalized() * away
		else:
			away = inv.basis * (limb.away as Vector3)
			away = (away - n * away.dot(n)).normalized()
	else:
		limb.away = Vector3.ZERO
	var lift: float = sin(PI * limb.t) if limb.swing else 0.0
	var dip := deg_to_rad(lerpf(DIP, 5.0, lift))
	var fingers: Vector3 = (away * cos(dip) - n * sin(dip)).normalized()
	var palm: Vector3 = (-n - fingers * (-n).dot(fingers)).normalized()
	var hx: Vector3 = fingers.cross(palm).normalized()
	var hand := Transform3D(Basis(hx, fingers, palm), tip)
	skeleton.set_bone_global_pose(limb.hand, hand)
	# fingers: spread, and each curled until its claw's point is on the hold (a
	# hair into it, never through); curled up while the hand travels
	# a hand holding nothing hangs loosely curled
	if not held: lift = maxf(lift, 0.6)
	var spread: float = CLAW_SPREAD * (1.0 - lift) * float(limb.mirror)
	var fan := [-0.6, 1.0, 0.35, -0.35, -1.0]
	for f in FINGERS.size():
		var chain: Array = limb.fingers[f]
		var rests: Array = limb.rests[f]
		var spread_turn := Quaternion(Vector3.BACK, spread * fan[f])
		var curl: Vector3 = (CLAW * float(limb.hooked[f]) * grip).lerp(FLYING, lift)
		if f == 2: limb.claw_at = xf * _claw_point(hand, limb.origins[f], rests, spread_turn, limb.claws[f], curl)
		for j in 3:
			var turn := Quaternion(Vector3.RIGHT, curl[j])
			if j == 0: turn = spread_turn * turn
			skeleton.set_bone_pose_rotation(chain[j], rests[j] * turn)


## How long a step of this hand takes at the speed it is going.
func _step_time(limb: Dictionary) -> float:
	return lerpf(STEP.x, STEP.y, clampf(velocity.length() / 2.6, 0.0, 1.0)) * float(limb.pace)


## How far a finger must curl (a share of CLAW) for its claw's point to rest
## on the plane of the hold. Closing the finger takes the claw down and then,
## past straight down, back up under the palm: so first the deepest it goes,
## then, halving, where on the way there it meets the hold. A finger too short
## to reach stops at its deepest.
func _touch(hand: Transform3D, origins: Array, rests: Array, spread_turn: Quaternion, claw: Vector3, point: Vector3, normal: Vector3) -> float:
	var deepest := -1.0
	var depth := INF
	var k := -1.0
	while k <= 1.6:
		var height := _claw_height(hand, origins, rests, spread_turn, claw, k, point, normal)
		if height < depth:
			depth = height
			deepest = k
		k += 0.2
	if depth >= -DIG: return deepest
	var low := -1.0
	var high := deepest
	if _claw_height(hand, origins, rests, spread_turn, claw, low, point, normal) <= -DIG: return low
	for i in 8:
		var mid := (low + high) * 0.5
		if _claw_height(hand, origins, rests, spread_turn, claw, mid, point, normal) > -DIG: low = mid
		else: high = mid
	return (low + high) * 0.5


## Where a claw's point is with each joint of its finger curled as given.
func _claw_point(hand: Transform3D, origins: Array, rests: Array, spread_turn: Quaternion, claw: Vector3, curl: Vector3) -> Vector3:
	var at := hand
	for j in 3:
		var turn := Quaternion(Vector3.RIGHT, curl[j])
		if j == 0: turn = spread_turn * turn
		at = at * Transform3D(Basis(rests[j] * turn), origins[j])
	return at * claw


## How far above the hold a claw's point is with the finger curled by k.
func _claw_height(hand: Transform3D, origins: Array, rests: Array, spread_turn: Quaternion, claw: Vector3, k: float, point: Vector3, normal: Vector3) -> float:
	var at := hand
	for j in 3:
		var turn := Quaternion(Vector3.RIGHT, CLAW[j] * k)
		if j == 0: turn = spread_turn * turn
		at = at * Transform3D(Basis(rests[j] * turn), origins[j])
	return (at * claw - point).dot(normal)


## The head leads: the neck and the head turn it to the point, the eyes stay
## on it.
func _look(skeleton: Skeleton3D, xf: Transform3D, delta: float) -> void:
	if look_point == Vector3.INF or head < 0: return
	var target: Vector3 = xf.affine_inverse() * look_point
	var neck_pose := skeleton.get_bone_global_pose(neck)
	var toward: Vector3 = target - neck_pose.origin
	neck_pose.origin += toward.normalized() * minf(LEAD, toward.length() * 0.2)
	skeleton.set_bone_global_pose(neck, neck_pose)
	for step in [[neck, 0.5, deg_to_rad(55.0)], [head, 1.0, deg_to_rad(70.0)]]:
		var bone: int = step[0]
		var head_pose := skeleton.get_bone_global_pose(head)
		var face: Vector3 = head_pose.basis.z.normalized()
		var eye_height: Vector3 = head_pose.origin + head_pose.basis.y * 0.07
		var wanted: Vector3 = (target - eye_height).normalized()
		var axis: Vector3 = face.cross(wanted)
		if axis.length_squared() < 1e-8: continue
		var angle: float = minf(face.angle_to(wanted) * float(step[1]), float(step[2]))
		var pose := skeleton.get_bone_global_pose(bone)
		pose.basis = Basis(axis.normalized(), angle) * pose.basis
		skeleton.set_bone_global_pose(bone, pose)
	# and the face upright, however the body hangs (on a wall, on the ceiling):
	# the head turns on the neck rather than lie on its side
	var upright := skeleton.get_bone_global_pose(head)
	var face_axis: Vector3 = upright.basis.z.normalized()
	var sky: Vector3 = xf.basis.orthonormalized().inverse() * Vector3.UP
	var want: Vector3 = sky - face_axis * sky.dot(face_axis)
	var have: Vector3 = upright.basis.y - face_axis * upright.basis.y.dot(face_axis)
	if want.length_squared() > 1e-6 and have.length_squared() > 1e-6:
		var roll := clampf(have.signed_angle_to(want, face_axis), -UPRIGHT, UPRIGHT)
		upright.basis = Basis(face_axis, roll) * upright.basis
	# eased, so a turn of the body never snaps the face round
	var frame := xf.basis.orthonormalized()
	var wanted_turn := (frame * upright.basis.orthonormalized()).get_rotation_quaternion()
	head_turn = head_turn.slerp(wanted_turn, 1.0 - exp(-TURN * delta)) if head_turned else wanted_turn
	head_turned = true
	upright.basis = frame.inverse() * Basis(head_turn)
	skeleton.set_bone_global_pose(head, upright)
	for eye in eyes:
		if eye < 0: continue
		var pose := skeleton.get_bone_global_pose(eye)
		var forward: Vector3 = pose.basis.y.normalized()
		var wanted: Vector3 = (target - pose.origin).normalized()
		var axis: Vector3 = forward.cross(wanted)
		if axis.length_squared() < 1e-8: continue
		pose.basis = Basis(axis.normalized(), minf(forward.angle_to(wanted), deg_to_rad(40.0))) * pose.basis
		skeleton.set_bone_global_pose(eye, pose)


func _frame(y: Vector3, x_hint: Vector3) -> Basis:
	var x := (x_hint - y * x_hint.dot(y)).normalized()
	return Basis(x, y, x.cross(y))
