extends RefCounted
## Poses The Locust's skeleton bone by bone for staged scenes (the television
## in the opening, the title screen). The gameplay IK is not used.
## All directions and axes are in skeleton space unless stated.
const BONE := "ValveBiped.Bip01_"
## Length of the blade beyond the hand, in model units along the forearm.
const BLADE := 0.36
var skeleton: Skeleton3D
var bones := {}

func _init(model: Node3D) -> void:
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]

func index(bone: String) -> int:
	if not bones.has(bone): bones[bone] = skeleton.find_bone(BONE + bone)
	return bones[bone]

func reset() -> void:
	skeleton.reset_bone_poses()

## World position of a bone as currently posed.
func point(bone: String) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(index(bone)).origin

## Rotates a bone so the direction to its child points along `direction`,
## keeping everything above it as posed.
func aim(bone: String, child: String, direction: Vector3) -> void:
	var id := index(bone)
	var parent := skeleton.get_bone_parent(id)
	var parent_pose := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var current := parent_pose * skeleton.get_bone_pose(id)
	var child_offset := skeleton.get_bone_rest(index(child)).origin
	var now_direction := (current.basis * child_offset).normalized()
	var rotation := Quaternion(now_direction, direction.normalized())
	var wanted := Basis(rotation) * current.basis
	skeleton.set_bone_pose_rotation(id, (parent_pose.basis.inverse() * wanted).get_rotation_quaternion())

## Turns a bone about an axis by an angle.
func turn(bone: String, axis: Vector3, angle: float) -> void:
	var id := index(bone)
	var parent := skeleton.get_bone_parent(id)
	var parent_pose := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D()
	var current := parent_pose * skeleton.get_bone_pose(id)
	var wanted := Basis(axis.normalized(), angle) * current.basis
	skeleton.set_bone_pose_rotation(id, (parent_pose.basis.inverse() * wanted).get_rotation_quaternion())

## Two-bone reach of an arm ("R" or "L") so the point `blade` beyond the hand
## lands on a world target. `pole` is where the elbow bends to.
func reach(side: String, target: Vector3, pole: Vector3, blade := BLADE) -> void:
	var upper := side + "_UpperArm"
	var fore := side + "_Forearm"
	var hand := side + "_Hand"
	var tip_local := skeleton.global_transform.affine_inverse() * target
	var upper_rest := skeleton.get_bone_global_rest(index(upper)).origin
	var fore_rest := skeleton.get_bone_global_rest(index(fore)).origin
	var hand_rest := skeleton.get_bone_global_rest(index(hand)).origin
	var a := upper_rest.distance_to(fore_rest)
	var b := fore_rest.distance_to(hand_rest) + blade
	var shoulder := skeleton.get_bone_global_pose(index(upper)).origin
	var span := tip_local - shoulder
	var d := clampf(span.length(), absf(a - b) + 0.001, a + b - 0.001)
	var direction := span.normalized()
	var bend := pole.normalized()
	var side_axis := (bend - direction * bend.dot(direction)).normalized()
	var along := (a * a - b * b + d * d) / (2.0 * d)
	var height := sqrt(maxf(a * a - along * along, 0.0))
	var elbow := shoulder + direction * along + side_axis * height
	aim(upper, fore, elbow - shoulder)
	aim(fore, hand, (shoulder + direction * d) - elbow)

static func ease_out(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return 1.0 - (1.0 - t) * (1.0 - t)

static func ease_in(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t
