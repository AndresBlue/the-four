extends SceneTree
## Bakes the camcorder and the tape the author brought (step two, after
## tools/props/ingest_camcorder.py), each a single mesh with its materials:
##
##   assets/props/camcorder/camcorder.res   in lens space: the front glass at
##                                          the origin, looking along -Z like a
##                                          Camera3D, at real size. A camera's
##                                          transform is the prop's transform.
##   assets/props/vhs_tape/vhs_tape.res     lying flat, label up, centred, its
##                                          long side along X, at real size.
##
##   godot --headless --path . --script res://tools/props/build_camcorder.gd
const MATERIALS := "res://game/presentation/materials/"
## A VHS-C palmcorder with its viewfinder out, end to end (metres).
const CAMCORDER_LENGTH := 0.27
## A VHS cassette: 187 mm long.
const TAPE_LENGTH := 0.187

func _initialize() -> void: run.call_deferred()

func vertices_of(mesh: Mesh, transform := Transform3D.IDENTITY) -> PackedVector3Array:
	var points := PackedVector3Array()
	for surface in mesh.get_surface_count():
		for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]: points.append(transform * vertex)
	return points

func bounds_of(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for point in points: box = box.expand(point)
	return box

func run() -> void:
	bake_camcorder()
	bake_tape()
	quit()

func bake_camcorder() -> void:
	var body: Mesh = load("res://assets/props/camcorder/camcorder_body.obj")
	var glass: Mesh = load("res://assets/props/camcorder/camcorder_glass.obj")
	var all := bounds_of(vertices_of(body))
	# The glasses, front to back along the long axis (Z): which end the lens is
	# at is read off the model, the widest glass being its front element.
	var panes := vertices_of(glass)
	var clusters: Array = []
	var sorted: Array = []
	for point in panes: sorted.append(point)
	sorted.sort_custom(func(a, b): return a.z < b.z)
	for point in sorted:
		if clusters.is_empty() or point.z - clusters[-1][-1].z > 1.0: clusters.append([])
		clusters[-1].append(point)
	var front: Array = []
	var widest := 0.0
	for cluster in clusters:
		var packed := PackedVector3Array(cluster)
		var box := bounds_of(packed)
		print("GLASS z=%.2f..%.2f centre=%s wide=%.2f points=%d" % [box.position.z, box.end.z, box.get_center(), maxf(box.size.x, box.size.y), cluster.size()])
		if maxf(box.size.x, box.size.y) > widest:
			widest = maxf(box.size.x, box.size.y)
			front = cluster
	var lens := bounds_of(PackedVector3Array(front))
	var forward := -1.0 if lens.get_center().z < all.get_center().z else 1.0
	var factor := CAMCORDER_LENGTH / all.size.z
	# Lens space: the front glass's centre to the origin, the lens along -Z.
	var origin := Vector3(lens.get_center().x, lens.get_center().y, lens.position.z if forward < 0.0 else lens.end.z)
	var turn := Basis.IDENTITY if forward < 0.0 else Basis(Vector3.UP, PI)
	var fit := Transform3D(turn * Basis.from_scale(Vector3.ONE * factor), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -origin)
	var combined := ArrayMesh.new()
	for part in [[body, "camcorder_body.tres"], [glass, "camcorder_lens.tres"]]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for surface in (part[0] as Mesh).get_surface_count(): tool.append_from(part[0], surface, fit)
		tool.generate_tangents()
		tool.commit(combined)
		combined.surface_set_material(combined.get_surface_count() - 1, load(MATERIALS + part[1]))
	ResourceSaver.save(combined, "res://assets/props/camcorder/camcorder.res")
	print("BAKED camcorder.res aabb=", combined.get_aabb(), " forward=", forward, " factor=", factor)

func bake_tape() -> void:
	var scene: Node3D = load("res://assets/props/vhs_tape/vhs_tape.dae").instantiate()
	root.add_child(scene)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var points := PackedVector3Array()
	for mesh in meshes: points.append_array(vertices_of(mesh.mesh, mesh.global_transform))
	var box := bounds_of(points)
	print("TAPE source aabb=", box, " meshes=", meshes.size())
	# Flat: its thin side up. Whichever axis is thinnest goes to Y, the longest to X.
	var sizes := [box.size.x, box.size.y, box.size.z]
	var thin := sizes.find(sizes.min())
	var long := sizes.find(sizes.max())
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	var x_axis: Vector3 = axes[long]
	var y_axis: Vector3 = axes[thin]
	var z_axis := x_axis.cross(y_axis)
	var turn := Basis(x_axis, y_axis, z_axis).inverse()
	var factor: float = TAPE_LENGTH / float(sizes[long])
	var centre := box.get_center()
	var fit := Transform3D(turn * Basis.from_scale(Vector3.ONE * factor), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -centre)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count(): tool.append_from(mesh.mesh, surface, fit * mesh.global_transform)
	tool.generate_tangents()
	var combined := tool.commit()
	# Resting on the floor: its underside at y = 0.
	var lifted := SurfaceTool.new()
	lifted.begin(Mesh.PRIMITIVE_TRIANGLES)
	lifted.append_from(combined, 0, Transform3D(Basis.IDENTITY, Vector3(0, -combined.get_aabb().position.y, 0)))
	lifted.generate_tangents()
	var mesh := lifted.commit()
	mesh.surface_set_material(0, load(MATERIALS + "vhs_tape.tres"))
	ResourceSaver.save(mesh, "res://assets/props/vhs_tape/vhs_tape.res")
	print("BAKED vhs_tape.res aabb=", mesh.get_aabb())
	scene.queue_free()
