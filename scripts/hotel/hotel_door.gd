extends StaticBody3D
var opened := false
var moving := false
var closed_rotation := 0.0
var doorway := Vector3.ZERO
var motion: Tween

func occupied() -> bool:
	for player in get_tree().get_nodes_in_group("hotel_players"):
		if Vector2(player.global_position.x - doorway.x, player.global_position.z - doorway.z).length() < 1.65:
			return true
	return false

func toggle(slow := false) -> bool:
	if moving or (opened and occupied()): return false
	moving = true
	# A swinging leaf must not sweep a CharacterBody into its door frame.
	collision_layer = 0
	var target := not opened
	motion = create_tween()
	motion.tween_property(self, "rotation:y", closed_rotation + (1.48 if target else 0.0), 1.5 if slow else 0.55).set_trans(Tween.TRANS_SINE)
	motion.finished.connect(func():
		if not target and occupied():
			rotation.y = closed_rotation + 1.48
			opened = true
		else: opened = target
		moving = false
	)
	return true

func _physics_process(_delta: float) -> void:
	if moving or collision_layer != 0: return
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape == null: return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape.shape
	query.transform = global_transform * shape.transform
	query.collision_mask = 4
	if get_world_3d().direct_space_state.intersect_shape(query).is_empty(): collision_layer = 8

func open_immediately() -> void:
	if is_instance_valid(motion): motion.kill()
	rotation.y = closed_rotation + 1.48
	opened = true
	moving = false
