extends Node3D
## The freight car's collapsing gate (spec_f1_geometry.md 7.5). lifts.gd moves
## this node's position.x between its shut and open x as it does a hotel leaf;
## the gate keeps its far end at fixed_x and lays its lattice out between the
## two every time it moves. No collider: the hotel's car leaves have none.
@export var fixed_x := -0.85
@export var height := 2.25
@export var bays := 9
var material: Material
var lattice: MultiMeshInstance3D

func _ready() -> void:
	set_notify_local_transform(true)
	build()
	relayout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and lattice != null: relayout()

## The moving stile, its handle and the lattice's one multimesh; every mesh
## carries lobby_side, so the lobby's lamp lights it too (hotel_geometry.lay()).
func build() -> void:
	for part in [[Vector3(0.04, height, 0.04), Vector3(0, height * 0.5, 0)], [Vector3(0.03, 0.18, 0.05), Vector3(-0.03, 1.05, 0.05)]]:
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		mesh.material = material
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.position = part[1]
		piece.set_meta("lobby_side", true)
		add_child(piece)
	var bar := BoxMesh.new()
	bar.size = Vector3.ONE
	bar.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = bar
	multimesh.instance_count = (bays + 1) + bays * 2 + 2
	lattice = MultiMeshInstance3D.new()
	lattice.multimesh = multimesh
	lattice.set_meta("lobby_side", true)
	add_child(lattice)

## Verticals at even steps between the fixed end and this one, an X in every
## bay, a rail at the top and the bottom.
func relayout() -> void:
	var span := maxf(position.x - fixed_x, 0.23)
	lattice.position = Vector3(fixed_x - position.x, 0, 0)
	var step := span / bays
	var k := 0
	for i in bays + 1:
		lattice.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3(0.018, height, 0.006)), Vector3(i * step, height * 0.5, 0)))
		k += 1
	var rise := height - 0.2
	var length := sqrt(step * step + rise * rise)
	var angle := atan2(rise, step)
	for i in bays:
		for sign_of in [-1.0, 1.0]:
			var turn := Basis(Vector3(0, 0, 1), angle * sign_of)
			lattice.multimesh.set_instance_transform(k, Transform3D(turn * Basis.IDENTITY.scaled(Vector3(length, 0.012, 0.004)), Vector3(i * step + step * 0.5, height * 0.5, 0.006)))
			k += 1
	for y in [0.01, height - 0.01]:
		lattice.multimesh.set_instance_transform(k, Transform3D(Basis.IDENTITY.scaled(Vector3(span, 0.02, 0.008)), Vector3(span * 0.5, y, 0)))
		k += 1
