extends SkeletonModifier3D
## The Lurker's eight hands on whatever is near them: the floor, a wall, the
## ceiling. Like The Locust's feet (locust_visual.gd) each hand stays planted
## where it is in the world and only moves in a step; but it looks for its hold
## in every direction round its shoulder, from under the body to over it, so in
## a corridor the hands take the walls and the ceiling as readily as the floor.
## The eight step in two sets of four that take turns, as a spider walks.
## Two-bone reach for each arm, the elbows lifted away from the body, the palm
## flat on what it holds and the fingers gripping it.
##
## Presentation only: it never moves the body (whoever owns it does, and says
## how fast in `velocity`) and changes no collision. Runs after the animation
## player, so the clip still moves the body, the head and the jaw.
signal footfall(point: Vector3, strength: float)

const FINGERS := ["thumb", "index", "middle", "ring", "pinky"]
const LIMBS := ["a.L", "a.R", "b.L", "b.R", "c.L", "c.R", "d.L", "d.R"]
## Two alternating sets of four.
const GROUP := {"a.L": 0, "b.R": 0, "c.L": 0, "d.R": 0, "a.R": 1, "b.L": 1, "c.R": 1, "d.L": 1}
## Where each probe looks, in degrees below the plane of the body (negative is
## above it): straight down to straight up, so a wall or a ceiling within
## reach is found as surely as the floor. Thick near the plane: the body rides
## low, and the holds that spread the arms wide are the grazing ones.
const PROBES := [70.0, 46.0, 32.0, 23.0, 16.0, 10.0, 4.0, -12.0, -38.0, -64.0, -86.0]
## The share of an arm's reach at which a hold sits best: far out, the elbows
## high, the way a spider stands.
const IDEAL := 0.82
## Physics layers a hand can hold on to: walls, floors and furniture.
@export_flags_3d_physics var world_mask := 1
## The body's velocity in the world, written every frame by whoever moves it.
var velocity := Vector3.ZERO
## 0..1: how hard the fingers grip (the scare opens them, a pounce closes them).
var grip := 1.0
var limbs: Array[Dictionary] = []
var cursor := 0
var swinging := [0, 0]


func _setup(skeleton: Skeleton3D) -> void:
	limbs.clear()
	for limb in LIMBS:
		var pair: String = limb.substr(0, 1)
		var side: String = limb.substr(2, 1)
		var sfx := "_%s.%s" % [pair, side]
		var entry := {
			"name": limb, "group": GROUP[limb],
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
		entry.reach = entry.l1 + entry.l2
		entry.scale = entry.reach / 0.84
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
	var up := basis.y
	var space := skeleton.get_world_3d().direct_space_state
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
		if not limb.planted or limb.hold.distance_to(socket) > limb.reach * 2.5:
			_probe(limb, skeleton, xf, basis, up, space)
			limb.hold = limb.best if limb.has_best else socket - up * limb.reach * 0.6 + basis * limb.out * limb.reach * 0.3
			limb.normal = limb.best_n if limb.has_best else up
			limb.planted = true
		_step(limb, socket, delta, speed)
		_reach(limb, skeleton, xf, basis, up, socket)


## Looks for the best hold round one hand, from a little ahead of its shoulder.
func _probe(limb: Dictionary, skeleton: Skeleton3D, xf: Transform3D, basis: Basis, up: Vector3, space: PhysicsDirectSpaceState3D) -> void:
	var socket: Vector3 = xf * skeleton.get_bone_global_pose(limb.upper).origin
	var from: Vector3 = socket + velocity * 0.22
	var out: Vector3 = basis * limb.out
	var best_score := INF
	limb.has_best = false
	for angle in PROBES:
		var a := deg_to_rad(angle)
		var direction: Vector3 = (out * cos(a) - up * sin(a)).normalized()
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * float(limb.reach) * 0.98, world_mask)
		var hit := space.intersect_ray(query)
		if hit.is_empty(): continue
		var share: float = from.distance_to(hit.position) / limb.reach
		# a hold nearer the ideal reach wins; one in front of the body a little more
		var score: float = absf(share - IDEAL) - 0.05 * clampf(velocity.normalized().dot(direction), 0.0, 1.0)
		if score < best_score:
			best_score = score
			limb.best = hit.position
			limb.best_n = hit.normal
			limb.has_best = true


func _step(limb: Dictionary, socket: Vector3, delta: float, speed: float) -> void:
	if limb.swing:
		limb.t = minf(1.0, limb.t + delta / limb.duration)
		var eased: float = limb.t * limb.t * (3.0 - 2.0 * limb.t)
		var lift: float = sin(PI * limb.t) * 0.13 * limb.scale
		var normal: Vector3 = limb.from_n.slerp(limb.to_n, eased) if limb.from_n.dot(limb.to_n) > -0.99 else limb.to_n
		limb.hold = limb.from.lerp(limb.to, eased) + normal * lift
		limb.normal = normal
		if limb.t >= 1.0:
			limb.swing = false
			limb.hold = limb.to
			limb.normal = limb.to_n
			footfall.emit(limb.to, clampf(speed / 2.5, 0.2, 1.0) * limb.scale)
		return
	var stretch: float = limb.hold.distance_to(socket) / limb.reach
	var drift: float = limb.hold.distance_to(limb.best) / limb.reach if limb.has_best else 0.0
	var due: bool = stretch > 0.96 or drift > (0.34 if speed > 0.05 else 0.2)
	var other: int = 1 - limb.group
	var free: bool = swinging[other] == 0 and swinging[limb.group] < 3
	if due and limb.has_best and (free or stretch > 1.04):
		limb.swing = true
		limb.t = 0.0
		limb.from = limb.hold
		limb.from_n = limb.normal
		limb.to = limb.best
		limb.to_n = limb.best_n
		limb.duration = clampf(0.3 - speed * 0.05, 0.13, 0.3)
		swinging[limb.group] += 1


func _reach(limb: Dictionary, skeleton: Skeleton3D, xf: Transform3D, basis: Basis, up: Vector3, socket_world: Vector3) -> void:
	var inv := xf.affine_inverse()
	var normal_world: Vector3 = limb.normal
	var target_world: Vector3 = limb.hold + normal_world * 0.04 * limb.scale
	var s: Vector3 = skeleton.get_bone_global_pose(limb.upper).origin
	var t: Vector3 = inv * target_world
	var out_world: Vector3 = basis * limb.out
	var pole: Vector3 = inv.basis * (up * 0.9 + out_world * 0.5)
	var a: float = limb.l1
	var b: float = limb.l2
	var span: Vector3 = t - s
	var d: float = clampf(span.length(), absf(a - b) + 0.002, a + b - 0.002)
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
	# the palm flat on the surface, the fingers pointing away from the body
	var n: Vector3 = (inv.basis * normal_world).normalized()
	var fingers: Vector3 = tip - s
	fingers = (fingers - n * fingers.dot(n))
	if fingers.length_squared() < 1e-8: fingers = inv.basis * out_world
	fingers = fingers.normalized()
	var palm: Vector3 = -n
	var hx: Vector3 = fingers.cross(palm).normalized()
	skeleton.set_bone_global_pose(limb.hand, Transform3D(Basis(hx, fingers, palm), tip))
	# fingers: dug in while planted, curled up while the hand travels
	var lift: float = sin(PI * limb.t) if limb.swing else 0.0
	var base := Vector3(0.3, 0.45, 0.38) * grip
	var flying := Vector3(0.8, 1.0, 0.85)
	var curl: Vector3 = base.lerp(flying, lift)
	for f in FINGERS.size():
		var chain: Array = limb.fingers[f]
		var rests: Array = limb.rests[f]
		var scale_: float = 0.55 if f == 0 else 1.0
		for j in 3:
			var angle: float = curl[j] * scale_
			skeleton.set_bone_pose_rotation(chain[j], rests[j] * Quaternion(Vector3.RIGHT, angle))


func _frame(y: Vector3, x_hint: Vector3) -> Basis:
	var x := (x_hint - y * x_hint.dot(y)).normalized()
	return Basis(x, y, x.cross(y))
