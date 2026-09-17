extends Area3D
## A loose sheet of paper that can be read. The Area3D is only the interaction
## target (hiding layer, found by the same focus ray as wardrobes).
var entry_id := ""

func _ready() -> void:
	add_to_group("hotel_documents")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.42, 0.2, 0.42)
	shape.shape = box
	shape.position = Vector3(0, 0.08, 0)
	add_child(shape)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.86, 0.83, 0.74)
	paper.roughness = 0.95
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.25, 0.23, 0.22)
	ink.roughness = 1.0
	# Two sheets, the top one askew, with a few lines of handwriting.
	for sheet in 2:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.21, 0.002, 0.297)
		mesh.material = paper
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = Vector3(0, 0.002 + sheet * 0.002, 0)
		instance.rotation.y = sheet * 0.18
		add_child(instance)
	for line in 7:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.15 - (0.05 if line == 6 else 0.0), 0.0005, 0.006)
		mesh.material = ink
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = Basis(Vector3.UP, 0.18) * Vector3(-0.01 if line == 6 else 0.0, 0.0055, -0.1 + line * 0.03)
		instance.rotation.y = 0.18
		add_child(instance)
