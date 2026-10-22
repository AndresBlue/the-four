extends Area3D
## One of the hints of the last planta left lying on a table or a desk
## (hint_placement.gd): a single paper, or a card for a sign off a door, read
## where it lies; the maid's sheet and the work order are the hotel's form
## (as its documents are, hotel_document.gd). Like a document, the Area3D is
## only what the focus ray finds (layer 16); reading it leaves it there for
## whoever comes next.
const DOCUMENT := preload("res://game/world/interactables/hotel_document.gd")
const VIEW := preload("res://game/ui/hint_view.gd")
var hint_id := -1
var kind := ""

func _ready() -> void:
	add_to_group("hotel_hints")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.36, 0.16, 0.36)
	shape.shape = box
	shape.position = Vector3(0, 0.06, 0)
	add_child(shape)
	var card := kind == "cartel"
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.9, 0.89, 0.84) if card else Color(0.87, 0.84, 0.75)
	paper.roughness = 0.95
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.2, 0.19, 0.18)
	ink.roughness = 1.0
	var form := VIEW.FORMS.has(kind)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.26, 0.004, 0.14) if card else Vector3(DOCUMENT.FORM_SHEET.x, 0.002, DOCUMENT.FORM_SHEET.y) if form else Vector3(0.16, 0.002, 0.22)
	mesh.material = paper
	var sheet := MeshInstance3D.new()
	sheet.mesh = mesh
	sheet.position = Vector3(0, 0.003, 0)
	add_child(sheet)
	if form:
		var face := DOCUMENT.form_sheet()
		face.position = Vector3(0, 0.0042, 0)
		add_child(face)
		return
	# A few lines of what is on it, only to say it is written on.
	for line in (2 if card else 6):
		var stroke := BoxMesh.new()
		stroke.size = Vector3((0.18 if card else 0.11) - (0.04 if line % 3 == 2 else 0.0), 0.0005, 0.012 if card else 0.005)
		stroke.material = ink
		var instance := MeshInstance3D.new()
		instance.mesh = stroke
		instance.position = Vector3(0, 0.0055 if card else 0.0045, (-0.025 + line * 0.05) if card else (-0.07 + line * 0.026))
		add_child(instance)
