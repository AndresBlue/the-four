extends SkeletonModifier3D
## The Lurker's eight hands on whatever is near them: the floor, a wall, the
## ceiling. Like The Locust's feet (locust_visual.gd) each hand stays planted
## where it is in the world and only moves in a step; but it looks for its hold
## in every direction round its shoulder, from under the body to over it, so in
## a corridor the hands take the walls and the ceiling as readily as the floor.
## The eight step in two sets of four that take turns, as a spider walks, and
## at a slow pace, like a black widow's: long arms, long strides, each hand
## lifted high and set down well ahead, the knees (its elbows) riding high.
##
## As in the picture: the arms are never straight (they reach no further than
## ARM_SPAN of their length, so the elbow always shows), the hands land with
## the claws dug in (the wrist held up, the fingers spread and hooked down into
## what they hold), and the head leads, turned with the eyes on `look_point`.
##
## Presentation only: it never moves the body (whoever owns it does, and says
## how fast in `velocity`) and changes no collision. Runs after the animation
## player, so the clip still moves the body and the jaw.
signal footfall(point: Vector3, strength: float)

const FINGERS := ["thumb", "index", "middle", "ring", "pinky"]
const LIMBS := ["a.L", "a.R", "b.L", "b.R", "c.L", "c.R", "d.L", "d.R"]
## Two alternating sets of four.
const GROUP := {"a.L": 0, "b.R": 0, "c.L": 0, "d.R": 0, "a.R": 1, "b.L": 1, "c.R": 1, "d.L": 1}
## Where each probe looks, in degrees below the plane of the body (negative is
## above it): straight down to straight up, so a wall or a ceiling within
## reach is found as surely as the floor. Thick near the plane: the holds that
## spread the arms wide are the grazing ones.
const PROBES := [70.0, 46.0, 32.0, 23.0, 16.0, 10.0, 4.0, -12.0, -38.0, -64.0, -86.0]
## The share of an arm's reach at which a hold sits best, and the most of it
## an arm ever uses: never straight.
const IDEAL := 0.66
const ARM_SPAN := 0.88
## How the fingers lie on a hold (curl of each joint, spread of the first) and
## while the hand travels.
const CLAW := Vector3(0.0, 0.55, 0.85)
const CLAW_SPREAD := 0.3
const FLYING := Vector3(0.7, 1.0, 0.9)
## How long a step takes, walking and at its fastest; how high the hand lifts
## (a share of the arm's length); how many seconds of travel ahead of the shoulder it
## looks for its next hold; and how hard the elbows are pushed up.
const STEP := Vector2(0.85, 0.45)
const LIFT := 0.22
const AHEAD := 0.6
const KNEES := 1.6
## How far the neck juts out towards what it looks at: the head leads.
const LEAD := 0.09
## How far the head twists to keep the face upright when the body is not.
const UPRIGHT := 1.92
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


func _setup(skeleton: Skeleton3D) -> void:
	limbs.clear()
	neck = skeleton.find_bone("neck")
	head = skeleton.find_bone("head")
	eyes = [skeleton.find_bone("eye.L"), skeleton.find_bone("eye.R")]
	for limb in LIMBS:
		var pair: String = limb.substr(0, 1)
		var side: String = limb.substr(2, 1)
		var sfx := "_%s.%s" % [pair, side]
		var entry := {
			"name": limb, "group": GROUP[limb],
			# mirrored bones turn the other way about their Z axis
			"mirror": -1.0 if side == "R" else 1.0,
			"upper": skeleton.find_bone("upperarm" + sfx),
			"fore": skeleton.find_bone("forearm" + sfx),
			"hand": skeleton.find_bone("hand" + sfx),
			"fingers": [], "rests": [],
			"planted": false, "swing": false, "t": 1.0, "duration": 0.25,
			"hold": Vector3.ZERO, "normal": Vector3.UP,
			"from": Vector3.ZERO, "to": Vector3.ZERO, "from_n": Vector3.UP, "to_n": Vector3.UP,
			"best": Vector3.ZERO, "best_n": Vector3.UP, "has_best": false,
		}
		for finger in FINGERS:
			var chain := []
			var rests := []
			for j in 3:
				var bone := skeleton.find_bone("%s_%02d%s" % [finger, j + 1, sfx])
				chain.append(bone)
				rests.append(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
			entry.fingers.append(chain)
			entry.rests.append(rests)
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
		limbs.append(entry)


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
		_look(skeleton, xf)
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
		if not limb.planted or limb.hold.distance_to(socket) > limb.reach * size * 2.5:
			_probe(limb, skeleton, xf, basis, up, space)
			var out_world: Vector3 = basis * limb.out
			limb.hold = limb.best if limb.has_best else socket + (out_world * 0.3 - up * 0.6) * limb.reach * size
			limb.normal = limb.best_n if limb.has_best else up
			limb.planted = true
		_step(limb, socket, delta, speed)
		_reach(limb, skeleton, xf, basis, up)
	_look(skeleton, xf)


## Looks for the best hold round one hand, from a little ahead of its shoulder.
func _probe(limb: Dictionary, skeleton: Skeleton3D, xf: Transform3D, basis: Basis, up: Vector3, space: PhysicsDirectSpaceState3D) -> void:
	var socket: Vector3 = xf * skeleton.get_bone_global_pose(limb.upper).origin
	var from: Vector3 = socket + velocity * AHEAD
	var out: Vector3 = basis * limb.out
	var best_score := INF
	limb.has_best = false
	for angle in PROBES:
		var a := deg_to_rad(angle)
		var direction: Vector3 = (out * cos(a) - up * sin(a)).normalized()
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * float(limb.reach) * size, world_mask)
		var hit := space.intersect_ray(query)
		if hit.is_empty(): continue
		var share: float = from.distance_to(hit.position) / (limb.reach * size)
		# a hold nearer the ideal reach wins; one ahead a little more; a wall or
		# the ceiling more again while it clings
		var score: float = absf(share - IDEAL)
		score -= 0.05 * clampf(velocity.normalized().dot(direction), 0.0, 1.0)
		score -= cling * 0.22 * (1.0 - absf((hit.normal as Vector3).dot(up)))
		if score < best_score:
			best_score = score
			limb.best = hit.position
			limb.best_n = hit.normal
			limb.has_best = true


func _step(limb: Dictionary, socket: Vector3, delta: float, speed: float) -> void:
	if limb.swing:
		limb.t = minf(1.0, limb.t + delta / limb.duration)
		var eased: float = limb.t * limb.t * (3.0 - 2.0 * limb.t)
		var lift: float = sin(PI * limb.t) * LIFT * (limb.l1 + limb.l2) * size
		var normal: Vector3 = limb.from_n.slerp(limb.to_n, eased) if limb.from_n.dot(limb.to_n) > -0.99 else limb.to_n
		limb.hold = limb.from.lerp(limb.to, eased) + normal * lift
		limb.normal = normal
		if limb.t >= 1.0:
			limb.swing = false
			limb.hold = limb.to
			limb.normal = limb.to_n
			footfall.emit(limb.to, clampf(speed / 2.5, 0.2, 1.0) * limb.scale)
		return
	var stretch: float = limb.hold.distance_to(socket) / (limb.reach * size)
	var drift: float = limb.hold.distance_to(limb.best) / (limb.reach * size) if limb.has_best else 0.0
	var due: bool = stretch > 0.95 or drift > (0.34 if speed > 0.05 else 0.2)
	var other: int = 1 - limb.group
	var free: bool = swinging[other] == 0 and swinging[limb.group] < 3
	if due and limb.has_best and (free or stretch > 1.05):
		limb.swing = true
		limb.t = 0.0
		limb.from = limb.hold
		limb.from_n = limb.normal
		limb.to = limb.best
		limb.to_n = limb.best_n
		limb.duration = lerpf(STEP.x, STEP.y, clampf(speed / 2.6, 0.0, 1.0))
		swinging[limb.group] += 1


func _reach(limb: Dictionary, skeleton: Skeleton3D, xf: Transform3D, basis: Basis, up: Vector3) -> void:
	var inv := xf.affine_inverse()
	var normal_world: Vector3 = limb.normal
	var out_world: Vector3 = basis * limb.out
	# the wrist held up off the hold: the claws are what touch it
	var target_world: Vector3 = limb.hold + normal_world * 0.075 * limb.scale * size
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
	var lift: float = sin(PI * limb.t) if limb.swing else 0.0
	var dip := deg_to_rad(lerpf(30.0, 5.0, lift))
	var fingers: Vector3 = (away * cos(dip) - n * sin(dip)).normalized()
	var palm: Vector3 = (-n - fingers * (-n).dot(fingers)).normalized()
	var hx: Vector3 = fingers.cross(palm).normalized()
	skeleton.set_bone_global_pose(limb.hand, Transform3D(Basis(hx, fingers, palm), tip))
	# fingers: spread and hooked into the hold, curled up while the hand travels
	var curl: Vector3 = (CLAW * grip).lerp(FLYING, lift)
	var spread: float = CLAW_SPREAD * (1.0 - lift) * float(limb.mirror)
	var fan := [-0.6, 1.0, 0.35, -0.35, -1.0]
	for f in FINGERS.size():
		var chain: Array = limb.fingers[f]
		var rests: Array = limb.rests[f]
		var weight: float = 0.55 if f == 0 else 1.0
		for j in 3:
			var turn := Quaternion(Vector3.RIGHT, curl[j] * weight)
			if j == 0: turn = Quaternion(Vector3.BACK, spread * fan[f]) * turn
			skeleton.set_bone_pose_rotation(chain[j], rests[j] * turn)


## The head leads: the neck and the head turn it to the point, the eyes stay
## on it.
func _look(skeleton: Skeleton3D, xf: Transform3D) -> void:
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
