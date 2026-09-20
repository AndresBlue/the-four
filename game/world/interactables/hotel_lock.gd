extends Area3D
## The keypad beside the last door: four numbers and it opens. It is the only
## thing between a floor and its end, so it sits where it can be seen, lit by
## its own little lamp, and it is read into by hand -- which in a game of four
## people means saying the numbers out loud.
const KEYS := 4
var lit: MeshInstance3D

func _ready() -> void:
	add_to_group("hotel_locks")
	collision_layer = 16
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.6, 0.35)
	shape.shape = box
	shape.position = Vector3(0, 1.3, 0)
	add_child(shape)
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.1, 0.1, 0.11)
	plate.metallic = 0.6
	plate.roughness = 0.4
	var panel := MeshInstance3D.new()
	panel.name = "Panel"
	var body := BoxMesh.new()
	body.size = Vector3(0.22, 0.34, 0.06)
	body.material = plate
	panel.mesh = body
	panel.position = Vector3(0, 1.3, 0.05)
	add_child(panel)
	# The little display, which is on whether or not anybody knows the code.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.1, 0.22, 0.12)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 1.0, 0.45)
	glow.emission_energy_multiplier = 1.6
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit = MeshInstance3D.new()
	lit.name = "Display"
	var screen := BoxMesh.new()
	screen.size = Vector3(0.16, 0.07, 0.01)
	screen.material = glow
	lit.mesh = screen
	lit.position = Vector3(0, 1.42, 0.09)
	lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lit)

## Green while it is waiting, off once it has been opened.
func set_open(value: bool) -> void:
	if not is_instance_valid(lit): return
	var material := lit.mesh.surface_get_material(0) as StandardMaterial3D
	material.emission = Color(0.85, 0.85, 0.85) if value else Color(0.3, 1.0, 0.45)
