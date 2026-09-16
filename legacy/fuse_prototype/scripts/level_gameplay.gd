extends Node3D

const ITEM := preload("res://legacy/fuse_prototype/scripts/interactable.gd")
const CABIN := AABB(Vector3(-1.7, -0.2, 10.0), Vector3(3.4, 3.1, 3.7))
var items: Array[StaticBody3D] = []
var elevator_doors: Array[MeshInstance3D] = []
var exit_tween: Tween
var panel: StaticBody3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for info in [["fuse_a", Vector3(-8, 0.92, 8)], ["fuse_b", Vector3(8, 0.92, 8)], ["fuse_c", Vector3(8, 0.92, -8)]]:
		var item = ITEM.new()
		item.name = info[0]
		item.item_id = info[0]
		item.kind = "fuse"
		item.position = info[1]
		add_child(item)
		items.append(item)
		mesh_box(item, Vector3.ZERO, Vector3(0.38, 0.24, 0.20), Color(0.85, 0.52, 0.17), 0.7)
		mesh_box(item, Vector3(-0.22, 0, 0), Vector3(0.08, 0.17, 0.16), Color(0.7, 0.72, 0.68))
		mesh_box(item, Vector3(0.22, 0, 0), Vector3(0.08, 0.17, 0.16), Color(0.7, 0.72, 0.68))
		collision(item, Vector3.ZERO, Vector3(0.55, 0.32, 0.35))
		static_box(info[1] - Vector3(0, 0.5, 0), Vector3(0.85, 0.75, 0.85), Color(0.20, 0.22, 0.20))
		label_at("FUSIBLE", info[1] + Vector3(0, 0.55, 0), 0, 32)
	for side in [-1, 1]:
		for z in [6.5, -4.5]:
			var door = ITEM.new()
			door.name = "Door_%s_%s" % [side, z]
			door.kind = "door"
			door.position = Vector3(side * 3.3, 1.3, z + 1.65)
			add_child(door)
			items.append(door)
			mesh_box(door, Vector3.ZERO, Vector3(0.32, 0.48, 0.30), Color(0.22, 0.32, 0.29))
			collision(door, Vector3.ZERO, Vector3(0.32, 0.48, 0.30))
			mesh_box(door, Vector3(-side * 0.18, 0, 0), Vector3(0.04, 0.12, 0.12), Color(0.75, 0.66, 0.32), 0.5)
			var leaf := StaticBody3D.new()
			leaf.position = Vector3(side * 0.2, 0.065, -1.65)
			door.add_child(leaf)
			mesh_box(leaf, Vector3.ZERO, Vector3(0.12, 2.7, 2.7), Color(0.26, 0.27, 0.21))
			door.door_leaf = leaf
			door.door_shape = collision(leaf, Vector3.ZERO, Vector3(0.12, 2.7, 2.7))
			door.closed_position = leaf.position
			label_at("E / PUERTA", door.position + Vector3(0, 0.55, 0), -side * PI / 2, 22)
	# The elevator is at the rear of the existing corridor; geometry remains editable.
	static_box(Vector3(0, 0.015, 11.9), Vector3(3.4, 0.03, 3.6), Color(0.16, 0.20, 0.19))
	for side in [-1, 1]:
		static_box(Vector3(side * 1.9, 1.4, 11.9), Vector3(0.16, 2.8, 3.6), Color(0.19, 0.22, 0.21))
		var door_mesh := mesh_box(self, Vector3(side * 2.65, 1.4, 10.03), Vector3(1.70, 2.8, 0.08), Color(0.22, 0.25, 0.23))
		elevator_doors.append(door_mesh)
	label_at("ASCENSOR / 01", Vector3(0, 3.07, 10.1), PI, 45)
	label_at("ASCENSOR / 01", Vector3(0, 3.07, 9.97), 0, 45)
	panel = ITEM.new()
	panel.name = "ElevatorPanel"
	panel.kind = "panel"
	panel.position = Vector3(-1.68, 1.3, 11.9)
	add_child(panel)
	items.append(panel)
	mesh_box(panel, Vector3.ZERO, Vector3(0.22, 0.95, 0.65), Color(0.07, 0.10, 0.10))
	collision(panel, Vector3.ZERO, Vector3(0.22, 0.95, 0.65))
	for i in 3:
		var light := mesh_box(panel, Vector3(0.13, 0.26 - i * 0.22, 0), Vector3(0.03, 0.10, 0.28), Color(0.32, 0.12, 0.08), 0.5)
		panel.indicators.append(light)
	label_at("ENERGÍA\n3 FUSIBLES", Vector3(-1.48, 2.15, 11.9), PI / 2, 24)

func contains_player(player_position: Vector3) -> bool:
	# The entire player capsule must fit inside the cab, not just its center.
	return CABIN.has_point(player_position + Vector3(0.28, 0.1, 0.28)) and CABIN.has_point(player_position - Vector3(0.28, 0, 0.28))

func reset_level() -> void:
	if is_instance_valid(exit_tween): exit_tween.kill()
	for i in elevator_doors.size():
		elevator_doors[i].position.x = -2.65 if i == 0 else 2.65
	for item in items: item.reset_item()
	panel.update_indicators(0)

func close_elevator() -> void:
	exit_tween = create_tween().set_parallel(true)
	for i in elevator_doors.size():
		exit_tween.tween_property(elevator_doors[i], "position:x", -0.85 if i == 0 else 0.85, 0.9)

func mesh_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.position = pos
	node.mesh = BoxMesh.new()
	node.mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mat.emission_enabled = emission > 0
	mat.emission = color
	mat.emission_energy_multiplier = emission
	node.material_override = mat
	parent.add_child(node)
	return node

func collision(parent: CollisionObject3D, pos: Vector3, size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	shape.position = pos
	parent.add_child(shape)
	return shape

func static_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var node := StaticBody3D.new()
	node.position = pos
	add_child(node)
	mesh_box(node, Vector3.ZERO, size, color)
	collision(node, Vector3.ZERO, size)

func label_at(words: String, pos: Vector3, angle: float, font_size: int) -> void:
	var label := Label3D.new()
	label.text = words
	label.position = pos
	label.rotation.y = angle
	label.font_size = font_size
	label.pixel_size = 0.005
	label.outline_size = 4
	label.modulate = Color(0.8, 0.79, 0.63)
	add_child(label)
