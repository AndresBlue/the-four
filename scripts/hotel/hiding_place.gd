extends Area3D
var occupant: CharacterBody3D
var exit_offset := Vector3(0, 0.04, 1.1)

func _ready() -> void:
	add_to_group("hotel_hides")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.95, 1.9, 0.8)
	shape.shape = box
	shape.position.y = 0.95
	add_child(shape)

func available_exit(player: CharacterBody3D) -> Vector3:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.05
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1 | 8 | 4 | 32
	query.exclude = [player.get_rid()]
	var destination := to_global(exit_offset)
	query.transform = Transform3D(Basis.IDENTITY, destination + Vector3(0, 0.54, 0))
	if get_world_3d().direct_space_state.intersect_shape(query).is_empty(): return destination
	return Vector3.INF
