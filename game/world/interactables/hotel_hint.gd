extends Area3D
## One of the hints of the last planta (hint_placement.gd), as it is found:
## a paper lying on a table or a desk (the maid's sheet and the work order
## are the hotel's form, as its documents are, hotel_document.gd; the
## directions a notebook's page), a Polaroid lying there, or the "do not
## disturb" card hanging on a door's knob (code_lock.hang_card()), read where
## it is. Like a document, the Area3D is only what the focus ray finds (layer
## 16); reading it leaves it there for whoever comes next.
const DOCUMENT := preload("res://game/world/interactables/hotel_document.gd")
const VIEW := preload("res://game/ui/hint_view.gd")
const CARD_FACE := preload("res://assets/textures/no-molestar.png")
const CARD_BACK := preload("res://assets/textures/no-molestar-reverso.png")
## The card, in metres (the picture's proportions), and a Polaroid.
const CARD := Vector2(0.09, 0.225)
const POLAROID := Vector2(0.088, 0.107)
var hint_id := -1
var kind := ""
## A card left on another door, with nothing on its back.
var blank := false

func _ready() -> void:
	add_to_group("hotel_hints")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	add_child(shape)
	shape.shape = box
	if kind == "nomolestar":
		# Upright against the leaf, its front out.
		box.size = Vector3(0.16, 0.3, 0.1)
		hang_card()
		return
	box.size = Vector3(0.36, 0.16, 0.36)
	shape.position = Vector3(0, 0.06, 0)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.92, 0.91, 0.87) if kind == "polaroid" else Color(0.87, 0.84, 0.75)
	paper.roughness = 0.9 if kind == "polaroid" else 0.95
	# The hotel's paperwork on its form, the directions on a notebook's page.
	var on_paper := "form" if VIEW.FORMS.has(kind) else "libreta" if kind == "indicaciones" else ""
	var form := not on_paper.is_empty()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(POLAROID.x, 0.003, POLAROID.y) if kind == "polaroid" else Vector3(DOCUMENT.FORM_SHEET.x, 0.002, DOCUMENT.FORM_SHEET.y) if form else Vector3(0.16, 0.002, 0.22)
	mesh.material = paper
	var sheet := MeshInstance3D.new()
	sheet.mesh = mesh
	sheet.position = Vector3(0, 0.003, 0)
	add_child(sheet)
	if form:
		var face := DOCUMENT.sheet_of(on_paper)
		face.position = Vector3(0, 0.0042, 0)
		add_child(face)
		return
	if kind == "polaroid":
		# The picture: dark, under its glossy skin, in the white frame's top.
		var picture := StandardMaterial3D.new()
		picture.albedo_color = Color(0.16, 0.13, 0.11)
		picture.roughness = 0.25
		var square := PlaneMesh.new()
		square.size = Vector2(POLAROID.x * 0.88, POLAROID.x * 0.88)
		square.material = picture
		var shown := MeshInstance3D.new()
		shown.name = "Picture"
		shown.mesh = square
		shown.position = Vector3(0, 0.0048, -POLAROID.y * 0.5 + POLAROID.x * 0.06 + POLAROID.x * 0.44)
		add_child(shown)

## Once its picture is taken (code_lock.develop_photo()), it is on the one
## lying here too, a little warm, as it is held up.
func show_photo(picture: Texture2D) -> void:
	var shown := get_node_or_null("Picture") as MeshInstance3D
	if shown == null: return
	var material: StandardMaterial3D = (shown.mesh as PlaneMesh).material.duplicate()
	material.albedo_texture = picture
	material.albedo_color = Color(1.0, 0.95, 0.86)
	shown.material_override = material

## The card: its printed front out from the door, plain on the back.
func hang_card() -> void:
	var front := StandardMaterial3D.new()
	front.albedo_texture = CARD_FACE
	front.roughness = 0.9
	front.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	front.alpha_scissor_threshold = 0.5
	front.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var back: StandardMaterial3D = front.duplicate()
	back.albedo_texture = CARD_BACK
	for side in [1.0, -1.0]:
		var quad := QuadMesh.new()
		quad.size = CARD
		var face := MeshInstance3D.new()
		face.name = "Front" if side > 0.0 else "Back"
		face.mesh = quad
		face.material_override = front if side > 0.0 else back
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		face.transform = Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3(0, 0, side * 0.0012))
		add_child(face)
