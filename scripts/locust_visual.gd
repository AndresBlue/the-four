@tool
extends Node3D

# A static presentation pose. This does not add animation or AI.
func _ready() -> void:
	var skeletons := find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton: Skeleton3D = skeletons[0]
	for side in ["L", "R"]:
		var index := skeleton.find_bone("ValveBiped.Bip01_" + side + "_UpperArm")
		if index < 0:
			continue
		var global_pose := skeleton.get_bone_global_pose(index)
		var parent := skeleton.get_bone_parent(index)
		var parent_rotation := skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
		var angle := deg_to_rad(-38.0 if side == "L" else 38.0)
		var target := Quaternion(Vector3.FORWARD * -1, angle) * global_pose.basis.get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(index, parent_rotation.inverse() * target)
