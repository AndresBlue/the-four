extends SceneTree
## Bakes the supplied old wooden door (assets/props/door/door.fbx, see
## docs/ASSETS.md) into the two meshes every hotel doorway uses:
##   door_leaf.res   the leaf with its hinges and knob, in the space of the
##                   door body (hotel_door.gd): hinge at the origin, leaf
##                   along +X, floor at y = 0, centred on its thickness
##   door_frame.res  the casing round the opening, centred on the doorway,
##                   floor at y = 0, centred on the wall's thickness
## Fitted to the hotel's opening (FLOOR.PORTAL wide, OPENING_HIGH tall), not to
## the model's own size: the casing grows round the opening and the leaf fills
## it but for a crack. The file has two copies (shut and ajar); "01" is used.
##   godot --headless --path . --script res://tools/props/build_door.gd
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SOURCE := "res://assets/props/door/door.fbx"
const OUTPUT := "res://assets/props/door/"
const MATERIALS := "res://game/presentation/materials/"
## Height of the hotel's door opening (the wall header starts there).
const OPENING_HIGH := 2.65
## The leaf stops short of the opening by this much on its free side and at
## the top, and clears the floor by FLOOR_CRACK.
const CRACK := 0.012
const FLOOR_CRACK := 0.012

func _initialize() -> void: run.call_deferred()

## A node's transform relative to the copy ("01") it belongs to.
func local_to(node: Node3D, top: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = node
	while at != top:
		t = (at as Node3D).transform * t
		at = at.get_parent()
	return t

func bounds(mesh: MeshInstance3D, to: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	for surface in mesh.mesh.get_surface_count():
		for v in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			box = AABB(to * v, Vector3.ZERO) if first else box.expand(to * v)
			first = false
	return box

func bake(parts: Array, fit: Transform3D, output: String) -> void:
	var groups := {}
	for entry in parts:
		var mesh: MeshInstance3D = entry[0]
		for surface in mesh.mesh.get_surface_count():
			# The model's "door" slot is the leaf's wood; everything else (casing,
			# hinges, knob) takes the casing's maps, which hold the metal too.
			var source = mesh.mesh.surface_get_material(surface)
			var key := "door_leaf.tres" if source != null and source.resource_name == "door" else "door_frame.tres"
			if not groups.has(key):
				groups[key] = SurfaceTool.new()
				groups[key].begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key].append_from(mesh.mesh, surface, fit * entry[1])
	var combined := ArrayMesh.new()
	for key in groups:
		var tool: SurfaceTool = groups[key]
		tool.generate_tangents()
		tool.commit(combined)
		combined.surface_set_material(combined.get_surface_count() - 1, load(MATERIALS + key))
	ResourceSaver.save(combined, output)
	print("BAKED ", output, " surfaces=", combined.get_surface_count(), " aabb=", combined.get_aabb())

func run() -> void:
	var scene: Node3D = load(SOURCE).instantiate()
	root.add_child(scene)
	var copy: Node3D = scene.get_node("01")
	var frame: MeshInstance3D = copy.get_node("F")
	var leaf: MeshInstance3D = copy.get_node("door")
	var knob: MeshInstance3D = leaf.get_node("handel")
	# Everything in the leaf's own space (origin on the hinge, leaf along -X,
	# centimetres), so the casing and the leaf stay in register.
	var to_leaf := local_to(leaf, copy).affine_inverse()
	var leaf_box := bounds(leaf, Transform3D.IDENTITY)
	var frame_box := bounds(frame, to_leaf * local_to(frame, copy))
	# Turned half round: the leaf then runs along +X from its hinge, the way
	# the hotel's doors swing, with the knob at the far end.
	var turn := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var mid_z := leaf_box.position.z + leaf_box.size.z * 0.5
	# The opening in the model is the leaf's span; the hotel's is PORTAL wide,
	# starting half its spare width before the hinge.
	var spare := (FLOOR.PORTAL - FLOOR.LEAF_WIDTH) * 0.5
	var width := FLOOR.PORTAL - CRACK
	var high := OPENING_HIGH - CRACK - FLOOR_CRACK
	var leaf_scale := Vector3(width / leaf_box.size.x, high / leaf_box.size.y, 0.01)
	# After the turn the hinge edge sits at -end.x: shift it back to the hinge,
	# then half the spare width before it, and scale into the opening.
	var leaf_fit := Transform3D(Basis.from_scale(leaf_scale), Vector3(-spare, FLOOR_CRACK, 0.0)) * Transform3D(Basis.IDENTITY, Vector3(leaf_box.end.x, -leaf_box.position.y, mid_z)) * turn
	bake([[leaf, Transform3D.IDENTITY], [knob, local_to(knob, leaf)]], leaf_fit, OUTPUT + "door_leaf.res")
	# The casing: same stretch as the leaf's opening, centred on the doorway.
	# The model's opening runs from the casing's foot to the top of the leaf.
	var frame_scale := Vector3(FLOOR.PORTAL / leaf_box.size.x, OPENING_HIGH / (leaf_box.end.y - frame_box.position.y), 0.01)
	var centre_x := leaf_box.position.x + leaf_box.size.x * 0.5
	var frame_fit := Transform3D(Basis.from_scale(frame_scale), Vector3.ZERO) * Transform3D(Basis.IDENTITY, Vector3(centre_x, -frame_box.position.y, mid_z)) * turn
	bake([[frame, to_leaf * local_to(frame, copy)]], frame_fit, OUTPUT + "door_frame.res")
	print("MODEL leaf ", leaf_box, " frame ", frame_box)
	scene.queue_free()
	quit()
