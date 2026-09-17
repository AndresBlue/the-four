extends RefCounted
## A survivor as the echo returns it: a cloud of points along the shape it is
## actually holding, so standing still reads as a crisp figure and running
## smears. Presentation only; it reads the avatar's live pose and nothing else.
##
## avatar_visual.gd rewrites global bone poses every physics frame, so the
## poses sampled here are the ones on screen. Characters 1 and 2 are rigged;
## character 0 is a single unrigged mesh and falls back to its capsule.

## Bone pairs walked from end to end. The avatar's dictionary has no head,
## hand or foot keys, so those ends are extrapolated from the bone before them.
const LIMBS := [
	["hip", "spine", 1.0],
	["spine", "head", 1.0],
	["la", "lf", 1.0],
	["lf", "lhand", 1.0],
	["ra", "rf", 1.0],
	["rf", "rhand", 1.0],
	["lt", "lk", 1.0],
	["lk", "lfoot", 1.0],
	["rt", "rk", 1.0],
	["rk", "rfoot", 1.0],
]
## Samples along each limb: ten limbs by six is sixty points, enough for a
## human shape at six metres and cheap enough to redo several times a second.
const ALONG := 6
## Rings up the capsule when there is no rig, and the half-width at each of
## them, so the fallback reads as a person and not a pill.
const RINGS := [
	[0.12, 0.09], [0.45, 0.13], [0.78, 0.15], [1.02, 0.20],
	[1.24, 0.26], [1.44, 0.23], [1.60, 0.14], [1.73, 0.11],
]
const AROUND := 5

## World points for this survivor's silhouette, appended to `out`.
static func points(body: Node3D, out: PackedVector3Array) -> void:
	var avatar = body.avatar if "avatar" in body else null
	if avatar != null and avatar.rig != null and not avatar.bones.is_empty():
		if rigged(avatar, out): return
	capsule(body, out)

## Along the bones the avatar is actually posing.
static func rigged(avatar, out: PackedVector3Array) -> bool:
	var rig: Skeleton3D = avatar.rig
	var frame := rig.global_transform
	var places := {}
	for key in avatar.bones:
		var id: int = avatar.bones[key]
		if id < 0: return false
		places[key] = frame * rig.get_bone_global_pose(id).origin
	# The ends of the chain: the model has no bone for them.
	var up: Vector3 = (places.spine - places.hip)
	places["head"] = places.spine + (up.normalized() if up.length() > 0.01 else Vector3.UP) * 0.42
	places["lhand"] = places.lf + (places.lf - places.la)
	places["rhand"] = places.rf + (places.rf - places.ra)
	places["lfoot"] = places.lk + (places.lk - places.lt)
	places["rfoot"] = places.rk + (places.rk - places.rt)
	for limb in LIMBS:
		var from: Vector3 = places[limb[0]]
		var to: Vector3 = places[limb[1]]
		for i in ALONG:
			out.append(from.lerp(to, float(i) / float(ALONG - 1)))
	return true

## No rig: rings up the body capsule, turned with it.
static func capsule(body: Node3D, out: PackedVector3Array) -> void:
	var frame := body.global_transform
	var squat: float = 0.59 if ("crouched" in body and body.crouched) else 1.0
	for ring in RINGS:
		var y: float = ring[0] * squat
		var radius: float = ring[1]
		for i in AROUND:
			var angle := TAU * float(i) / float(AROUND)
			out.append(frame * Vector3(cos(angle) * radius, y, sin(angle) * radius))
