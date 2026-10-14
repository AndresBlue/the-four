extends SceneTree
## Bakes the imported wardrobe model into three meshes for the hiding place:
## a static body and two door leaves split at the centre seam, each leaf
## expressed relative to its hinge so it can swing. Output in wardrobe space:
## floor at y = 0, doors facing +Z, centred on X, scaled to SIZE.
##   godot --headless --path . --script res://tools/props/build_wardrobe.gd
const SOURCE := "res://assets/props/wardrobe/wardrobe.fbx"
const OUTPUT := "res://assets/props/wardrobe/"
## Parts that belong to the two doors (panels, stiles, rails, handles).
const DOOR_PARTS := ["7_low", "17_low", "18_low", "6_low", "1_low", "20_low"]
## Target outer size (width, height, depth) in metres: a person fits inside.
const SIZE := Vector3(1.25, 2.3, 0.78)
## The crack left between the two leaves (metres), for whoever is inside to
## look out through with the doors shut. The model's doors close on each
## other: the right one carries a strip that lies behind the left one's edge,
## and where the two met only a hairline of the lit room came through, burnt
## white by a lens wide open in the dark. The left leaf is cut back this far
## from where it ended and the right one's strip is taken off, each with its
## new edge closed. Every wardrobe has it, with somebody inside or with
## nobody: it says nothing about who is in which.
const SLIT := 0.015

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene: Node3D = load(SOURCE).instantiate()
	root.add_child(scene)
	var bounds := AABB()
	var first := true
	# Bounds from real vertices: transformed AABBs of rotated parts overestimate.
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p: Vector3 = mesh.global_transform * vertex
			bounds = AABB(p, Vector3.ZERO) if first else bounds.expand(p)
			first = false
	# Model: front faces +X, width along Z. Rotate so the front faces +Z,
	# then scale to SIZE and sit on the floor.
	var turn := Basis(Vector3.UP, -PI / 2)
	var rotated := AABB()
	first = true
	for corner in 8:
		var p: Vector3 = turn * bounds.get_endpoint(corner)
		rotated = AABB(p, Vector3.ZERO) if first else rotated.expand(p)
		first = false
	var scale := Vector3(SIZE.x / rotated.size.x, SIZE.y / rotated.size.y, SIZE.z / rotated.size.z)
	var offset := -Vector3(rotated.position.x + rotated.size.x * 0.5, rotated.position.y, rotated.position.z + rotated.size.z * 0.5)
	var fit := Transform3D(Basis.from_scale(scale), Vector3.ZERO) * Transform3D(Basis.IDENTITY, offset) * Transform3D(turn, Vector3.ZERO)
	var body := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaves := {"left": [], "right": []}
	var door_front := -INF
	var door_half := 0.0
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		var to_space: Transform3D = fit * mesh.global_transform
		if not mesh.name in DOOR_PARTS:
			body.append_from(mesh.mesh, 0, to_space)
			continue
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices.resize(vertices.size())
			for i in vertices.size(): indices[i] = i
		var normal_basis := to_space.basis.inverse().transposed()
		for t in range(0, indices.size(), 3):
			var tri := []
			var centre := Vector3.ZERO
			for k in 3:
				var index := indices[t + k]
				var p: Vector3 = to_space * vertices[index]
				centre += p / 3.0
				tri.append([p, (normal_basis * normals[index]).normalized(), uvs[index] if uvs.size() > index else Vector2.ZERO])
				door_front = maxf(door_front, p.z)
				door_half = maxf(door_half, absf(p.x))
			leaves["left" if centre.x < 0.0 else "right"].append(tri)
	# The crack: from where the left leaf ended, SLIT back into it.
	var seam := -INF
	for tri in leaves.left:
		for v in tri: seam = maxf(seam, v[0].x)
	var cuts := {"left": [seam - SLIT, -1.0], "right": [seam, 1.0]}
	var inner := INF
	for side in leaves:
		var kept := []
		var rim := []
		for tri in leaves[side]: kept.append_array(clip(tri, cuts[side][0], cuts[side][1], rim))
		# The new edge, closed: a board across what the cut left open.
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for v in rim:
			low = Vector2(minf(low.x, v[0].y), minf(low.y, v[0].z))
			high = Vector2(maxf(high.x, v[0].y), maxf(high.y, v[0].z))
		var facing := Vector3(-cuts[side][1], 0, 0)
		var corners := [Vector3(cuts[side][0], low.x, low.y), Vector3(cuts[side][0], high.x, low.y), Vector3(cuts[side][0], high.x, high.y), Vector3(cuts[side][0], low.x, high.y)]
		for pair in [[0, 1, 2], [0, 2, 3]]: kept.append(pair.map(func(k): return [corners[k], facing, rim[0][2]]))
		leaves[side] = kept
		if side == "left": inner = low.y
		print("CRACK ", side, " cut at x=", snappedf(cuts[side][0], 0.0001), ", its edge from y=", snappedf(low.x, 0.001), " to ", snappedf(high.x, 0.001), " and z=", snappedf(low.y, 0.001), " to ", snappedf(high.y, 0.001))
	var material := load("res://game/presentation/materials/wardrobe.tres")
	var body_mesh := body.commit()
	body_mesh.surface_set_material(0, material)
	ResourceSaver.save(body_mesh, OUTPUT + "wardrobe_body.res")
	# Hinges sit on the outer edges of the door leaves, at the door face.
	for side in ["left", "right"]:
		var hinge := Vector3(-door_half if side == "left" else door_half, 0.0, door_front)
		var leaf := SurfaceTool.new()
		leaf.begin(Mesh.PRIMITIVE_TRIANGLES)
		for tri in leaves[side]:
			for v in tri:
				leaf.set_normal(v[1])
				leaf.set_uv(v[2])
				leaf.add_vertex(v[0] - hinge)
		leaf.generate_tangents()
		var leaf_mesh := leaf.commit()
		leaf_mesh.surface_set_material(0, material)
		# Where the crack is, for whoever puts an eye to it (hiding_place.gd):
		# its middle across, how wide it is, and how far out its inner mouth.
		leaf_mesh.set_meta("slit", Vector3(seam - SLIT * 0.5, SLIT, inner))
		ResourceSaver.save(leaf_mesh, OUTPUT + "wardrobe_leaf_%s.res" % side)
		print("LEAF ", side, " triangles=", leaves[side].size(), " hinge=", hinge)
	print("DOOR front=", door_front, " half_width=", door_half, " body_aabb=", body_mesh.get_aabb())
	quit()

## What of a triangle (three of [point, normal, uv]) lies on one side of a
## plane across X (`keep` 1: at or past `at`; -1: at or short of it), as
## triangles; the points it was cut at are added to `rim`.
static func clip(tri: Array, at: float, keep: float, rim: Array) -> Array:
	var outline := []
	for k in 3:
		var a: Array = tri[k]
		var b: Array = tri[(k + 1) % 3]
		var a_in: bool = (a[0].x - at) * keep >= 0.0
		var b_in: bool = (b[0].x - at) * keep >= 0.0
		if a_in: outline.append(a)
		if a_in != b_in:
			var t: float = (at - a[0].x) / (b[0].x - a[0].x)
			var cut := [(a[0] as Vector3).lerp(b[0], t), (a[1] as Vector3).lerp(b[1], t).normalized(), (a[2] as Vector2).lerp(b[2], t)]
			outline.append(cut)
			rim.append(cut)
	var pieces := []
	for k in range(1, outline.size() - 1): pieces.append([outline[0], outline[k], outline[k + 1]])
	return pieces
