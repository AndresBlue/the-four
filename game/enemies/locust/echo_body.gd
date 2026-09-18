extends RefCounted
## A survivor as the echo comes back from them: points on the surface of the
## body, not along its bones. Tracing the bone centre-lines drew a skeleton
## hanging in the air, which is neither what a body looks like nor what an echo
## would return. Here every bone is a tapered sleeve of the right thickness and
## the points sit on that sleeve.
##
## Only the half of each sleeve turned towards the listener is kept: sound comes
## back from the surface facing it, never from the far side of a chest.
##
## avatar_visual.gd rewrites global bone poses every physics frame, so the pose
## sampled here is the one on screen. Characters 1 and 2 are rigged; character 0
## is a single unrigged mesh and falls back to its capsule.

## Bone, bone, thickness at each end. A person, roughly: a deep chest, a neck
## and head, arms tapering to the hand, legs tapering to the foot.
const SLEEVES := [
	["hip", "spine", 0.165, 0.150],
	["spine", "head", 0.115, 0.100],
	["la", "lf", 0.058, 0.046],
	["lf", "lhand", 0.044, 0.034],
	["ra", "rf", 0.058, 0.046],
	["rf", "rhand", 0.044, 0.034],
	["lt", "lk", 0.092, 0.066],
	["lk", "lfoot", 0.062, 0.044],
	["rt", "rk", 0.092, 0.066],
	["rk", "rfoot", 0.062, 0.044],
]
## Rings along a sleeve and points around each ring. Half are thrown away by
## the facing test, so a body comes back as roughly a hundred and forty points.
const ALONG := 4
const AROUND := 7
## No rig: rings up the body, with the half-width of a person at each height.
const RINGS := [
	[0.10, 0.10], [0.42, 0.14], [0.72, 0.16], [0.98, 0.20],
	[1.22, 0.24], [1.40, 0.21], [1.58, 0.13], [1.72, 0.10],
]

## World points on the surface of this survivor that face `from`, appended to
## `out`. `from` is where the click left, not where the camera is.
static func points(body: Node3D, from: Vector3, out: PackedVector3Array) -> void:
	var avatar = body.avatar if "avatar" in body else null
	if avatar != null and avatar.rig != null and not avatar.bones.is_empty():
		if rigged(avatar, from, out): return
	capsule(body, from, out)

## Sleeves around the bones the avatar is actually posing.
static func rigged(avatar, from: Vector3, out: PackedVector3Array) -> bool:
	var rig: Skeleton3D = avatar.rig
	var frame := rig.global_transform
	var places := {}
	for key in avatar.bones:
		var id: int = avatar.bones[key]
		if id < 0: return false
		places[key] = frame * rig.get_bone_global_pose(id).origin
	# The ends of the chain: the model has no bone for them.
	var up: Vector3 = places.spine - places.hip
	places["head"] = places.spine + (up.normalized() if up.length() > 0.01 else Vector3.UP) * 0.42
	places["lhand"] = places.lf + (places.lf - places.la)
	places["rhand"] = places.rf + (places.rf - places.ra)
	places["lfoot"] = places.lk + (places.lk - places.lt)
	places["rfoot"] = places.rk + (places.rk - places.rt)
	for sleeve in SLEEVES:
		sleeve_points(places[sleeve[0]], places[sleeve[1]], sleeve[2], sleeve[3], from, out)
	return true

## Points on the surface of a tapered sleeve from one bone to the next, keeping
## only the side that faces the listener.
static func sleeve_points(from_point: Vector3, to_point: Vector3, near: float, far: float, listener: Vector3, out: PackedVector3Array) -> void:
	var axis := to_point - from_point
	var span := axis.length()
	if span < 0.01: return
	axis /= span
	# Any two directions across the bone will do to lay a ring on.
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.15: side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var other := axis.cross(side).normalized()
	for i in ALONG:
		var along := float(i) / float(ALONG - 1)
		var middle: Vector3 = from_point.lerp(to_point, along)
		var radius: float = lerpf(near, far, along)
		var towards := (listener - middle).normalized()
		for j in AROUND:
			var turn := TAU * float(j) / float(AROUND)
			var outward := (side * cos(turn) + other * sin(turn))
			# The far side of a limb sends nothing back.
			if outward.dot(towards) <= 0.0: continue
			out.append(middle + outward * radius)

## No rig: rings up the body capsule, turned with it, facing side only.
static func capsule(body: Node3D, listener: Vector3, out: PackedVector3Array) -> void:
	var frame := body.global_transform
	var squat: float = 0.59 if ("crouched" in body and body.crouched) else 1.0
	for ring in RINGS:
		var middle: Vector3 = frame * Vector3(0, ring[0] * squat, 0)
		var towards := (listener - middle).normalized()
		for i in AROUND:
			var turn := TAU * float(i) / float(AROUND)
			var outward := frame.basis * Vector3(cos(turn), 0, sin(turn))
			if outward.normalized().dot(towards) <= 0.0: continue
			out.append(middle + outward * ring[1])
