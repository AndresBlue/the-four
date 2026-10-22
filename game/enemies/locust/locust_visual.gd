extends Node3D
const EXECUTION := preload("res://game/enemies/locust/hotel_locust.gd")
const SCORE := preload("res://game/app/capture_score.gd")
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
## The mask, in the head bone's own space (measured on the model,
## tools/dev/mask_probe.gd): its centre. It faces the bone's +Z and its top is
## the bone's +Y; the pale part is 12 cm across and 14 high in the world.
const MASK_CENTRE := Vector3(-0.0014, 0.079, 0.0358)
## The blade beyond the hand, in model units along the forearm.
const BLADE := 0.36
## How far from the lens it brings its mask when it bends over somebody
## (metres; the tape frames it nearer still, death_tape.gd).
const MASK_REACH := 0.17
## The capture it is playing a part in, or nothing. While there is one, the
## whole pose is that scene's and a function of its clock (pose_capture):
## its capture style (game/app/capture_styles/locust_capture.gd) writes this
## every frame of an execution, the same on every machine. {time, entry,
## side, ending, lens, mask_from, chest, face, body, glance} -- points in the
## world, see locust_capture.scene_for().
var scene := {}
## Rest lengths of the back (hips to neck, neck to head) and of each arm.
var back := Vector2.ZERO
var arms := {}

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
		var shoulder := skeleton.get_bone_global_rest(bones[side + "_UpperArm"]).origin
		var elbow := skeleton.get_bone_global_rest(bones[side + "_Forearm"]).origin
		var wrist := skeleton.get_bone_global_rest(bones[side + "_Hand"]).origin
		arms[side] = Vector2(shoulder.distance_to(elbow), elbow.distance_to(wrist) + BLADE)
	initialized = bones.values().all(func(id): return id >= 0)
	if initialized:
		var hips := skeleton.get_bone_global_rest(bones.Spine).origin
		var neck := skeleton.get_bone_global_rest(bones.Neck1).origin
		back = Vector2(hips.distance_to(neck), neck.distance_to(skeleton.get_bone_global_rest(bones.Head1).origin))

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
	if not scene.is_empty():
		pose_capture()
		for leg in LEGS: solve_leg(leg[0], feet[leg[0]])
		return
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
			# At a wardrobe: both arms forward, low and open, and in as its
			# doors go (a third of the way through, hotel_locust.WARDROBE_TIME).
			var reach := clampf((searching - 0.3) / 0.1, 0.0, 1.0)
			upper = upper.lerp(Vector3(s * 0.5, -0.25, 0.9), 0.7)
			fore = fore.lerp(Vector3(s * 0.3, -0.15 + reach * 0.2, 1.0), 0.8)
		if execute > 0.0:
			# One arm holds the body up and draws it in while the mask comes to
			# meet it; the other waits, drawn back, and goes through the face.
			var lift := clampf(execute / 0.18, 0.0, 1.0)
			var kill: float = EXECUTION.EXECUTION_KILL / EXECUTION.EXECUTION_TIME
			var closing := clampf((execute - 0.12) / maxf(kill - 0.12, 0.01), 0.0, 1.0)
			var holding: bool = s > 0.0
			upper = upper.lerp(Vector3(s * 0.35, lerpf(0.1, 0.75, lift), lerpf(0.7, 0.45, closing)), 0.85)
			fore = fore.lerp(Vector3(s * 0.1, lerpf(0.2, 0.55, lift), lerpf(0.95, 0.7, closing)), 0.85)
			if not holding:
				# Wound up all the way through the wait, then one blow, and a
				# fast one: from drawn back to buried in a fifth of a second.
				var phase: float = (execute - kill) / 0.05
				var thrust: float = maxf(0.0, 1.0 - absf(phase))
				thrust = thrust * thrust * (3.0 - 2.0 * thrust)
				var wind := closing * 0.4
				upper = upper.lerp(Vector3(s * (0.6 + wind) * (1.0 - thrust), 0.4 - thrust * 0.35, 0.25 - wind * 0.25 + thrust * 1.05), 0.92)
				fore = fore.lerp(Vector3(s * 0.15 * (1.0 - thrust), 0.6 - thrust * 1.2, 0.1 + thrust * 1.25), 0.92)
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

# --- A capture (docs/EXECUTION.md) ------------------------------------------------

## Where the mask is in the world as posed, as a frame: its centre, +Z out of
## the face and +Y up it. The tape of whoever is caught frames its picture in
## this space (death_tape.gd), so what it shows never depends on where the
## creature happened to be standing.
func mask_transform() -> Transform3D:
	if not initialized: return global_transform
	var head: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(bones.Head1)
	return Transform3D(head.basis.orthonormalized(), head * MASK_CENTRE)

## A rotation of the world, in the skeleton's own space.
func to_skeleton_basis(basis: Basis) -> Basis:
	return skeleton.global_basis.orthonormalized().inverse() * basis

## Two bones bent so that the end of the second lands on a point: `root` and
## `joint` are the bones, `tip` a bone below them (or the same as `joint` with
## `reach` its length), `pole` where the joint goes.
func bend_to(root: int, joint: int, tip: int, span: Vector2, target: Vector3, pole: Vector3) -> void:
	var from := skeleton.get_bone_global_pose(root).origin
	var reach := target - from
	var distance := clampf(reach.length(), absf(span.x - span.y) + 0.002, span.x + span.y - 0.002)
	var along := reach.normalized()
	var bend := pole - along * pole.dot(along)
	if bend.length() < 0.001: bend = Vector3.UP - along * along.y
	bend = bend.normalized()
	var cos_root := clampf((span.x * span.x + distance * distance - span.y * span.y) / (2.0 * span.x * distance), -1.0, 1.0)
	var elbow := from + along * span.x * cos_root + bend * span.x * sqrt(maxf(0.0, 1.0 - cos_root * cos_root))
	aim_bone(root, joint, elbow - from)
	aim_bone(joint, tip, from + along * distance - skeleton.get_bone_global_pose(joint).origin)

## An arm ("L" or "R") with the point of its blade on a place in the world.
func reach_arm(side: String, target: Vector3, pole: Vector3) -> void:
	bend_to(bones[side + "_UpperArm"], bones[side + "_Forearm"], bones[side + "_Hand"], arms[side], to_skeleton(target), pole)

## Where the point of an arm's blade is when the arm hangs, in the world: what
## an arm is brought from and let go back to.
func hanging(side: String) -> Vector3:
	var s := 1.0 if side == "L" else -1.0
	var shoulder := skeleton.get_bone_global_pose(bones[side + "_UpperArm"]).origin
	var span: Vector2 = arms[side]
	return skeleton.global_transform * (shoulder + Vector3(s * 0.2, -0.93, 0.28).normalized() * (span.x + span.y) * 0.94)

## The whole body during a capture, from the scene's clock and nothing else:
## bent over its victim with the mask at the lens, the arm that runs them
## through, the other that knocks the camera away; then straightening and
## bringing the body up with it, the blow, and what it does over the body.
func pose_capture() -> void:
	var time := float(scene.time)
	var entry := String(scene.entry)
	var side := float(scene.get("side", 1.0))
	var stoop := SCORE.stoop(time)
	var lens: Vector3 = scene.lens
	var chest: Vector3 = scene.chest
	var face: Vector3 = scene.face
	var lying: Vector3 = scene.body
	# Hips down and forward as it bends, so the knees fold instead of the legs
	# standing like stilts under a folded back.
	var pelvis := skeleton.get_bone_global_pose(bones.Pelvis)
	pelvis.origin += Vector3(0.0, -(0.05 + 0.13 * stoop), 0.08 * stoop)
	skeleton.set_bone_global_pose(bones.Pelvis, pelvis)
	# The head, bent over: the mask MASK_REACH from the lens, facing it, cocked
	# to one side and harder after the jerk.
	var mask_from: Vector3 = scene.mask_from
	var cock := side * (0.24 + 0.2 * SCORE.smooth(SCORE.ramp(time, SCORE.JERK_TIME, SCORE.JERK_TIME + SCORE.JERK_LENGTH)))
	var facing := -mask_from
	# Its own axes in the world (this node is turned round and scaled under it).
	var frame := body.global_basis.orthonormalized()
	var forward := -frame.z
	var right := frame.x
	# Looking straight down at somebody, the top of its head points ahead.
	var bowed := to_skeleton_basis(Basis(facing, cock) * Basis.looking_at(-facing, Vector3.UP if absf(facing.y) < 0.92 else forward))
	var bowed_at := to_skeleton(lens + mask_from * MASK_REACH) - bowed * MASK_CENTRE
	var standing := skeleton.get_bone_global_pose(bones.Head1)
	var head_at := standing.origin.lerp(bowed_at, stoop)
	bend_to(bones.Spine, bones.Neck1, bones.Head1, back, head_at, Vector3(0.0, 1.0, -0.3))
	var head := skeleton.get_bone_global_pose(bones.Head1)
	head.basis = Basis(head.basis.get_rotation_quaternion().slerp(bowed.get_rotation_quaternion(), stoop))
	skeleton.set_bone_global_pose(bones.Head1, head)
	# Upright again: it looks at the face it holds up, then at the body, and
	# then at the lens on the floor or away, to wherever it is going next.
	var upright := 1.0 - SCORE.smooth(SCORE.ramp(stoop, 0.0, 0.6))
	if upright > 0.0:
		var after := SCORE.smooth(SCORE.ramp(time, SCORE.DROP_TIME, SCORE.DROP_TIME + 0.25))
		var look := face.lerp(lying, after)
		var last := SCORE.glance(time)
		var seen: Vector3 = scene.get("glance", Vector3.INF)
		if String(scene.get("ending", "leave")) == "glance" and seen != Vector3.INF:
			look = look.lerp(seen, last)
			look_at_point(look, upright, side * 0.3 * SCORE.smooth(SCORE.ramp(time, SCORE.GLANCE_COCK, SCORE.GLANCE_COCK + 0.06)))
		else:
			# Done with it: the head comes up and round, the shoulders after it.
			var away := body.global_position + forward * 3.0 + right * side * 3.5 + Vector3.UP * 2.3
			look_at_point(look.lerp(away, last), upright, 0.0)
			turn_bone(bones.Spine2, Vector3.UP, -side * 0.35 * last * upright)
	# The arm that holds: through the chest from the first frame, and with the
	# body wherever it is taken, until it is let fall.
	var into := (chest - skeleton.global_transform * skeleton.get_bone_global_pose(bones.L_UpperArm).origin).normalized()
	var held := SCORE.smooth(SCORE.ramp(time, 0.0, 0.03)) * (1.0 - SCORE.smooth(SCORE.ramp(time, SCORE.DROP_TIME, SCORE.DROP_TIME + 0.45)))
	# From behind it comes right through, far enough to be seen from the
	# victim's own eyes, before it turns them round on it.
	var pierce := 0.14 + (0.5 * (1.0 - SCORE.smooth(SCORE.ramp(time, SCORE.BACK_TURN_FROM, SCORE.BACK_TURN_TO))) if entry == "back" else 0.0)
	reach_arm("L", hanging("L").lerp(chest + into * pierce, held), Vector3(0.6, -0.5, -0.4))
	# The other: up and back while the face lasts, across the lens in the
	# swipe, drawn back for as long as it holds the body up, through the face,
	# and down.
	var shoulder: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(bones.R_UpperArm).origin
	var raised := shoulder + right * 0.75 + Vector3.UP * 0.75 + forward * 0.25
	var drawn := shoulder + right * 0.85 + Vector3.UP * 0.55 - forward * 0.45
	var swing := SCORE.swipe(entry, time)
	var tip := hanging("R").lerp(raised, SCORE.smooth(SCORE.ramp(time, 0.0, 0.1)))
	if swing > 0.0:
		# Through the lens: it reaches it SWIPE_REACH into the swing.
		var across := pow(swing, log(0.5) / log(SCORE.SWIPE_REACH / SCORE.SWIPE_LENGTH))
		var start := lens + right * side * 0.6 + Vector3.UP * 0.32 - forward * 0.05
		var finish := lens - right * side * 0.7 - Vector3.UP * 0.3 + forward * 0.1
		var control := lens * 2.0 - (start + finish) * 0.5
		tip = start.lerp(control, across).lerp(control.lerp(finish, across), across)
		if across < 0.12: tip = raised.lerp(tip, across / 0.12)
		var back_up := SCORE.smooth(SCORE.ramp(time, SCORE.face_end(entry) + SCORE.SWIPE_LENGTH, SCORE.LIFT_FROM + 0.3))
		tip = tip.lerp(drawn, back_up)
	var blow := SCORE.thrust(time)
	if blow > 0.0:
		var through := face + (face - shoulder).normalized() * 0.28
		tip = drawn.lerp(through, blow)
		tip = tip.lerp(hanging("R"), SCORE.smooth(SCORE.ramp(time, SCORE.DROP_TIME, SCORE.DROP_TIME + 0.5)))
	reach_arm("R", tip, Vector3(-0.7, 0.5, -0.5))

## The head turned to a point in the world, as far as a neck goes, and
## `weight` of the way there; `cock` tilts it on the line it looks along.
func look_at_point(point: Vector3, weight: float, cock: float) -> void:
	var head := skeleton.get_bone_global_pose(bones.Head1)
	var wanted := to_skeleton(point) - head.origin
	if wanted.length() < 0.05 or weight <= 0.0: return
	wanted = wanted.normalized()
	var ahead := Vector3(0, 0, 1)
	var angle := minf(ahead.angle_to(wanted), 1.35)
	var axis := ahead.cross(wanted)
	if axis.length() < 0.001: return
	axis = axis.normalized()
	turn_bone(bones.Neck1, axis, angle * 0.4 * weight)
	turn_bone(bones.Head1, axis, angle * 0.6 * weight)
	if not is_zero_approx(cock): turn_bone(bones.Head1, Basis(axis, angle) * ahead, cock * weight)
