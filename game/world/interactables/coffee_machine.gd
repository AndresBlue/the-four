extends Area3D
## A coffee machine (coffee.gd): a cup from it gives a survivor's mind back.
## "SCP-294 'The Coffee Machine'" by Anquietas System (Sketchfab, CC BY 4.0),
## its body alone (its loose keys and cup come piled at its feet), at its
## real size: a black machine with a cup of coffee on its screen. The model
## faces +X: turned a quarter, its front faces +Z, the way the node does.
const MODEL := preload("res://assets/props/coffee/coffee_machine.glb")
const BODY := "SCP-294"
const SIZE := Vector3(0.96, 1.75, 0.88)
## Seats that have had their cup here.
var served := {}

func _ready() -> void:
	add_to_group("coffee_machines")
	collision_layer = 16
	collision_mask = 0
	var model: Node3D = MODEL.instantiate()
	model.rotation.y = -PI / 2.0
	add_child(model)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name) != BODY: mesh.visible = false
	# Aimed at, and in the way. What is aimed at stands a little proud of the
	# solid body: the same box, and the look's ray met the body first, never
	# the machine (the author could not get a cup).
	for owner_node in [self, StaticBody3D.new()]:
		var aimed: bool = owner_node == self
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = SIZE + (Vector3(0.1, 0.1, 0.2) if aimed else Vector3.ZERO)
		shape.shape = box
		shape.position = Vector3(0, SIZE.y * 0.5, 0.1 if aimed else 0.0)
		owner_node.add_child(shape)
		if not aimed: add_child(owner_node)
