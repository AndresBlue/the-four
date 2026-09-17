extends Node3D
## Procedural animation for The Locust (Valve Biped skeleton, modelled facing +Z).
## Feet are planted in world space and only move during a step, so the pointed
## legs never slide; two-bone IK bends the knees to reach them. Presentation
## only: it never moves the body, changes collision or alters perception.
signal footfall(point: Vector3, strength: float)

const BONE := "ValveBiped.Bip01_"
const LEGS := [["L", -1.0], ["R", 1.0]]
## Body-space lateral distance of each foot from the centre line (metres).
@export var stance_width := 0.21
## Reference top speed used to scale stride, lean and arm swing.
@export var run_speed := 6.4
var skeleton: Skeleton3D
var body: Node3D
var bones := {}
var lengths := {}
var feet := {}
## Inputs written by the controller every physics frame.
var move_velocity := Vector3.ZERO
var aggression := 0.0
var attack := 0.0
var recovering := 0.0
## 0..1: stooping to pass under a lintel.
var duck := 0.0
var look_point := Vector3.INF
## 0..1 progress of an execution (impale, lift, three stabs) and of searching
## a wardrobe (reaching in with both arms).
var execute := 0.0
var searching := 0.0
var hunch := 0.0
var bob := 0.0
var arm_dirs := {}
var initialized := false

func _ready() -> void:
	preload("res://game/enemies/locust/locust_look.gd").apply(self)
	var rigs := find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty(): return
	skeleton = rigs[0]
	body = get_parent() as Node3D
	for name in ["Pelvis", "Spine", "Spine2", "Spine4", "Neck1", "Head1", "L_UpperArm", "L_Forearm", "L_Hand", "R_UpperArm", "R_Forearm", "R_Hand", "L_Thigh", "L_Calf", "L_Foot", "R_Thigh", "R_Calf", "R_Foot"]:
		bones[name] = skeleton.find_bone(BONE + name)
	for side in ["L", "R"]:
		var hip := skeleton.get_bone_global_rest(bones[side + "_Thigh"]).origin
		var knee := skeleton.get_bone_global_rest(bones[side + "_Calf"]).origin
		var ankle := skeleton.get_bone_global_rest(bones[side + "_Foot"]).origin
		lengths[side] = Vector2(hip.distance_to(knee), knee.distance_to(ankle))
	initialized = bones.values().all(func(id): return id >= 0)

func snap_feet() -> void:
	for leg in LEGS: feet[leg[0]] = {"planted": home(leg[1], Vector3.ZERO), "from": Vector3.ZERO, "to": Vector3.ZERO, "t": 1.0, "swing": false, "duration": 0.3}

## Resting place of a foot under the hip, optionally led along the motion.
func home(side: float, lead: Vector3) -> Vector3:
	var basis := body.global_basis.orthonormalized()
	var point := body.global_position + basis.x * side * stance_width + lead
	point.y = body.global_position.y
	return point

func _process(delta: float) -> void:
	if not initialized or not is_instance_valid(body) or delta <= 0.0: return
	if feet.is_empty(): snap_feet()
	var planar := Vector3(move_velocity.x, 0, move_velocity.z)
	var speed := planar.length()
	var ratio := clampf(speed / run_speed, 0.0, 1.0)
	step_feet(delta, planar, speed, ratio)
	skeleton.reset_bone_poses()
	pose_body(delta, ratio)
	for leg in LEGS: solve_leg(leg[0], feet[leg[0]])
	pose_arms(delta, ratio)
	pose_head(delta)

func step_feet(delta: float, planar: Vector3, speed: float, ratio: float) -> void:
	# Long, reaching strides for its size.
	var stride := lerpf(0.8, 1.9, ratio)
	var direction := planar.normalized() if speed > 0.05 else Vector3.ZERO
	var duration := clampf(stride / maxf(speed, 0.1) * 0.5, 0.17, 0.42)
	var lift := 0.1 + ratio * 0.12
	var reach := stride * 0.45 * minf(1.0, speed / 0.8)
	for leg in LEGS:
		var foot: Dictionary = feet[leg[0]]
		var other: Dictionary = feet["R" if leg[0] == "L" else "L"]
		var rest := home(leg[1], Vector3.ZERO)
		if foot.planted.distance_to(rest) > 2.5:
			snap_feet()
			return
		if foot.swing:
			foot.t = minf(1.0, foot.t + delta / foot.duration)
			var eased: float = foot.t * foot.t * (3.0 - 2.0 * foot.t)
			foot.planted = foot.from.lerp(foot.to, eased) + Vector3.UP * sin(PI * foot.t) * lift
			if foot.t >= 1.0:
				foot.swing = false
				foot.planted = foot.to
				footfall.emit(foot.to, ratio)
			continue
		# Planted feet stay put; a step starts once the foot has fallen as far
		# behind the hip as it landed ahead of it, or drifts sideways on turns.
		var offset: Vector3 = foot.planted - rest
		var behind := -offset.dot(direction) if speed > 0.05 else 0.0
		var sideways := (offset - direction * offset.dot(direction)).length() if speed > 0.05 else offset.length()
		var due := behind > reach or sideways > 0.28 or (speed <= 0.2 and offset.length() > 0.16)
		# Alternate legs; when running the next step may start as the other lands.
		var other_ready: bool = not other.swing or (ratio > 0.6 and other.t > 0.75)
		if due and other_ready:
			foot.swing = true
			foot.t = 0.0
			foot.from = foot.planted
			# Land ahead of where the hip will be when the step finishes.
			foot.to = rest + direction * (speed * duration + reach)
			foot.duration = duration
	var lifting: float = maxf(sin(PI * feet.L.t) if feet.L.swing else 0.0, sin(PI * feet.R.t) if feet.R.swing else 0.0)
	bob = lerpf(bob, lifting, minf(1.0, delta * 12.0))

func to_skeleton(point: Vector3) -> Vector3:
	return skeleton.global_transform.affine_inverse() * point

## Rotates a bone in skeleton space so its child lies along `direction`.
func aim_bone(bone: int, child: int, direction: Vector3) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	var current := (skeleton.get_bone_global_pose(child).origin - pose.origin).normalized()
	var wanted := direction.normalized()
	if current.dot(wanted) > 0.9999 or current.dot(wanted) < -0.9999: return
	pose.basis = Basis(Quaternion(current, wanted)) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)

func turn_bone(bone: int, axis: Vector3, angle: float) -> void:
	var pose := skeleton.get_bone_global_pose(bone)
	pose.basis = Basis(axis.normalized(), angle) * pose.basis
	skeleton.set_bone_global_pose(bone, pose)

func pose_body(delta: float, ratio: float) -> void:
	# Lower the pelvis so legs keep slack to reach; stilts rise mid-step.
	var pelvis := skeleton.get_bone_global_pose(bones.Pelvis)
	var drop := lerpf(0.05, 0.15, ratio) + attack * 0.08 + duck * 0.12 - bob * 0.025
	pelvis.origin += Vector3(0, -drop, 0)
	skeleton.set_bone_global_pose(bones.Pelvis, pelvis)
	var lean_target := ratio * 0.32 + aggression * 0.12 + attack * 0.25 - recovering * 0.1 + duck * 0.55 + searching * 0.35 - execute * 0.15
	hunch = lerpf(hunch, lean_target, minf(1.0, delta * 5.0))
	# Model faces +Z: pitching about +X tips the chest forward.
	turn_bone(bones.Spine2, Vector3.RIGHT, hunch * 0.6)
	turn_bone(bones.Spine4, Vector3.RIGHT, hunch * 0.4)
	var sway := 0.0
	if feet.L.swing: sway -= sin(PI * feet.L.t)
	if feet.R.swing: sway += sin(PI * feet.R.t)
	turn_bone(bones.Spine, Vector3.FORWARD, sway * 0.05 * (0.4 + ratio))

func solve_leg(side: String, foot: Dictionary) -> void:
	var thigh: int = bones[side + "_Thigh"]
	var calf: int = bones[side + "_Calf"]
	var ankle: int = bones[side + "_Foot"]
	var hip := skeleton.get_bone_global_pose(thigh).origin
	var target := to_skeleton(foot.planted)
	var upper: float = lengths[side].x
	var lower: float = lengths[side].y
	var reach := target - hip
	var distance := clampf(reach.length(), 0.05, upper + lower - 0.002)
	var along := reach.normalized()
	# Knees point forward (+Z) and slightly outward.
	var pole := Vector3(0.15 if side == "L" else -0.15, 0.0, 1.0)
	var bend := (pole - along * pole.dot(along)).normalized()
	var cos_hip := clampf((upper * upper + distance * distance - lower * lower) / (2.0 * upper * distance), -1.0, 1.0)
	var knee := hip + along * upper * cos_hip + bend * upper * sqrt(1.0 - cos_hip * cos_hip)
	aim_bone(thigh, calf, knee - hip)
	var tip := hip + along * distance
	aim_bone(calf, ankle, tip - skeleton.get_bone_global_pose(calf).origin)

func pose_arms(delta: float, ratio: float) -> void:
	var swing := 0.0
	if feet.L.swing: swing += sin(PI * feet.L.t)
	if feet.R.swing: swing -= sin(PI * feet.R.t)
	for side in [["L", 1.0], ["R", -1.0]]:
		var s: float = side[1]
		# Blade arms: hanging forward while walking, raised during the wind-up,
		# driven down and forward in the strike.
		var upper := Vector3(s * 0.42, -0.85, 0.28 + swing * s * 0.3 * ratio)
		var fore := Vector3(s * 0.1, -0.55, 0.8)
		upper = upper.lerp(Vector3(s * 0.45, -0.4, 0.8), aggression)
		fore = fore.lerp(Vector3(s * 0.05, -0.2, 1.0), aggression)
		upper = upper.lerp(Vector3(s * 0.55, 0.75, 0.3), attack)
		fore = fore.lerp(Vector3(s * 0.15, 0.95, -0.2), attack)
		upper = upper.lerp(Vector3(s * 0.2, -0.35, 0.95), recovering)
		fore = fore.lerp(Vector3(s * -0.1, -0.8, 0.6), recovering)
		if searching > 0.0:
			# Reaching into a wardrobe: both arms forward, low and open.
			var reach := clampf((searching - 0.5) / 0.35, 0.0, 1.0)
			upper = upper.lerp(Vector3(s * 0.5, -0.25, 0.9), 0.7)
			fore = fore.lerp(Vector3(s * 0.3, -0.15 + reach * 0.2, 1.0), 0.8)
		if execute > 0.0:
			# The first arm holds the body up; the other stabs chest, hip, head.
			var lift := clampf(execute / 0.18, 0.0, 1.0)
			var holding: bool = s > 0.0
			upper = upper.lerp(Vector3(s * 0.35, lerpf(0.1, 0.75, lift), 0.7), 0.85)
			fore = fore.lerp(Vector3(s * 0.1, lerpf(0.2, 0.55, lift), 0.95), 0.85)
			if not holding:
				# Three thrusts, each one drawn back first.
				var thrust := 0.0
				for hit in [0.34, 0.55, 0.76]:
					var phase: float = (execute - hit) / 0.12
					if absf(phase) < 1.0: thrust = maxf(thrust, 1.0 - absf(phase))
				upper = upper.lerp(Vector3(s * 0.55, 0.35 - thrust * 0.2, 0.35 + thrust * 0.65), 0.9)
				fore = fore.lerp(Vector3(s * 0.15, 0.55 - thrust * 0.9, 0.2 + thrust * 0.9), 0.9)
		var key: String = side[0]
		var blend := minf(1.0, delta * (26.0 if execute > 0.0 else 18.0 if recovering > 0.1 else 8.0))
		if not arm_dirs.has(key): arm_dirs[key] = [upper, fore]
		arm_dirs[key][0] = arm_dirs[key][0].lerp(upper, blend)
		arm_dirs[key][1] = arm_dirs[key][1].lerp(fore, blend)
		aim_bone(bones[key + "_UpperArm"], bones[key + "_Forearm"], arm_dirs[key][0])
		aim_bone(bones[key + "_Forearm"], bones[key + "_Hand"], arm_dirs[key][1])

func pose_head(_delta: float) -> void:
	if look_point == Vector3.INF: return
	var head := skeleton.get_bone_global_pose(bones.Head1)
	var target := to_skeleton(look_point) - head.origin
	target.y *= 0.6
	if target.length() < 0.1: return
	var forward := Vector3(0, 0, 1)
	var wanted := target.normalized()
	# Limit to a believable neck range.
	var angle := minf(forward.angle_to(wanted), 1.0)
	var axis := forward.cross(wanted)
	if axis.length() < 0.001: return
	turn_bone(bones.Neck1, axis, angle * 0.45)
	turn_bone(bones.Head1, axis, angle * 0.4)
