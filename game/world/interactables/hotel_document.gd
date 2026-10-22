extends Area3D
## A loose sheet of paper that can be read. The Area3D is only the interaction
## target (hiding layer, found by the same focus ray as wardrobes).
const CATALOG := preload("res://game/discovery/discovery_catalog.gd")
## The papers as they are seen lying there (tools/textures/
## bake_hotel_note.py): the hotel's form for its own paperwork, the letter
## folded in four and the notebook's page, here and among the hints
## (hotel_hint.gd); read held up whole (hotel_form.gd, ruled_paper.gd).
const FAR := {
	"form": preload("res://assets/textures/nota-hotel-lejos.png"),
	"carta": preload("res://assets/textures/carta-lejos.png"),
	"libreta": preload("res://assets/textures/libreta-lejos.png"),
}
## A sheet of any of them, in metres: the pictures' proportions, near enough
## an A4.
const FORM_SHEET := Vector2(0.2, 0.3)
static var materials := {}
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
	var item: Dictionary = CATALOG.entry(entry_id)
	var on_paper := "form" if item.has("form") else String(item.get("paper", ""))
	var official := not on_paper.is_empty()
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color(0.86, 0.83, 0.74)
	paper.roughness = 0.95
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.25, 0.23, 0.22)
	ink.roughness = 1.0
	# Two sheets, the top one askew, with a few lines of handwriting; the
	# hotel's own paperwork is its form on top.
	for sheet in 2:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(FORM_SHEET.x, 0.002, FORM_SHEET.y) if official and sheet == 1 else Vector3(0.21, 0.002, 0.297)
		mesh.material = paper
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = Vector3(0, 0.002 + sheet * 0.002, 0)
		instance.rotation.y = sheet * 0.18
		add_child(instance)
	if official:
		var form := sheet_of(on_paper)
		form.position = Vector3(0, 0.0052, 0)
		form.rotation.y = 0.18
		add_child(form)
		return
	for line in 7:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.15 - (0.05 if line == 6 else 0.0), 0.0005, 0.006)
		mesh.material = ink
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.position = Basis(Vector3.UP, 0.18) * Vector3(-0.01 if line == 6 else 0.0, 0.0055, -0.1 + line * 0.03)
		instance.rotation.y = 0.18
		add_child(instance)

## A paper face up, its top away from whoever put it down: a plane with its
## picture, cut out along the paper's worn edges.
static func sheet_of(paper: String) -> MeshInstance3D:
	if not materials.has(paper):
		var material := StandardMaterial3D.new()
		material.albedo_texture = FAR.get(paper, FAR.form)
		material.roughness = 0.95
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		materials[paper] = material
	var plane := PlaneMesh.new()
	plane.size = FORM_SHEET
	plane.material = materials[paper]
	var instance := MeshInstance3D.new()
	instance.name = "Paper"
	instance.mesh = plane
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
