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
## The crack left between the two leaves (metres): a thin line of the room
## for whoever is inside, with the doors shut. The model's doors close on each
## other: the right one carries a strip that lies behind the left one's edge,
## and where the two met only a hairline of the lit room came through, burnt
## white by a lens wide open in the dark. The left leaf is cut back this far
## from where it ended and the right one's strip is taken off, each with its
## new edge closed. Every wardrobe has it, with somebody inside or with
## nobody: it says nothing about who is in which. (It was 1.5 cm for a few
## days: through that the room was a strip, not a line.)
const SLIT := 0.005
## How far behind the doors' front something of theirs has to be to be one
## of the hinges' leaves fixed to the carcass (metres): those stay with the
## body. Swinging with the doors from an axis in front of them, they came away
## from the side boards with the leaf.
const HARDWARE_BEHIND := 0.07
## Where on the colour map the inside of each leaf is taken from: a plain
## board of the carcass's. The model has no inside to its doors -- what was
## seen from in there, and on a door left open, was the back of their fronts,
## with the worn frames and scratches of the front texture, pale and
## glittering in a torch.
const BOARD_UV := Rect2(0.012, 0.512, 0.28, 0.47)
## How far behind the doors' back the board is (metres): in the same plane as
## the backs of their stiles, the two flickered into each other. It is a mesh
## of its own, wardrobe_leaf_<side>_inside.res, which hiding_place.gd hangs on
## the leaf with no shadow: casting one a few millimetres behind the door that
## casts it as well, it shadowed itself in slanting stripes wherever a lamp's
## light came in through the gap. Its material has no normal map
## (materials/wardrobe_inside.tres): where it takes its wood the model's map
## leans well to one side, and the board took the room's light from the gap
## as if it faced it.
const BOARD_BEHIND := 0.003

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
	var boards := {"left": [], "right": []}
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
	# The hinges' fixed leaves, well behind the doors: on the body.
	var fixed := []
	for side in leaves:
		var kept := []
		for tri in leaves[side]:
			var centre: Vector3 = (tri[0][0] + tri[1][0] + tri[2][0]) / 3.0
			if centre.z < door_front - HARDWARE_BEHIND: fixed.append(tri)
			else: kept.append(tri)
		leaves[side] = kept
	# The doors' back, from what is left of them: where they turn.
	var back := INF
	door_half = 0.0
	for side in leaves:
		for tri in leaves[side]:
			for v in tri:
				back = minf(back, v[0].z)
				door_half = maxf(door_half, absf(v[0].x))
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
		# Its inside: a plain board across its back, from hinge to crack.
		var across := Vector2(INF, -INF)
		var up := Vector2(INF, -INF)
		for tri in kept:
			for v in tri:
				across = Vector2(minf(across.x, v[0].x), maxf(across.y, v[0].x))
				up = Vector2(minf(up.x, v[0].y), maxf(up.y, v[0].y))
		var board := []
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			var at := Vector3(lerpf(across.x, across.y, corner.x), lerpf(up.x, up.y, corner.y), back - BOARD_BEHIND)
			var uv := BOARD_UV.position + BOARD_UV.size * Vector2(corner.x, 1.0 - corner.y)
			board.append([at, Vector3.BACK * -1.0, uv])
		# Wound to face in: the material draws both sides, and a face seen from
		# its back is lit as if it faced the other way -- from the room, through
		# the door in front of it, whose shadow fell on it in stripes.
		for pair in [[0, 1, 2], [0, 2, 3]]: boards[side].append(pair.map(func(k): return board[k]))
		leaves[side] = kept
		if side == "left": inner = back
		print("CRACK ", side, " cut at x=", snappedf(cuts[side][0], 0.0001), ", its edge from y=", snappedf(low.x, 0.001), " to ", snappedf(high.x, 0.001), " and z=", snappedf(low.y, 0.001), " to ", snappedf(high.y, 0.001))
	var material := load("res://game/presentation/materials/wardrobe.tres")
	var body_mesh := body.commit()
	body_mesh.surface_set_material(0, material)
	var hardware := SurfaceTool.new()
	hardware.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in fixed:
		for v in tri:
			hardware.set_normal(v[1])
			hardware.set_uv(v[2])
			hardware.add_vertex(v[0])
	hardware.generate_tangents()
	hardware.commit(body_mesh)
	body_mesh.surface_set_material(1, material)
	ResourceSaver.save(body_mesh, OUTPUT + "wardrobe_body.res")
	print("HINGES ", fixed.size(), " triangles kept on the body")
	# Each leaf turns about its outer edge at its back, where it meets the
	# side board: turning about its front (the knobs' front, 2.4 cm out), its
	# back came away from the side by a few centimetres, and the room showed
	# through where the hinges should have been.
	for side in ["left", "right"]:
		var hinge := Vector3(-door_half if side == "left" else door_half, 0.0, back)
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
		# And where it turns, in the wardrobe's space (hiding_place.gd puts
		# its hinge there).
		leaf_mesh.set_meta("hinge", hinge)
		ResourceSaver.save(leaf_mesh, OUTPUT + "wardrobe_leaf_%s.res" % side)
		var inside := SurfaceTool.new()
		inside.begin(Mesh.PRIMITIVE_TRIANGLES)
		for tri in boards[side]:
			for v in tri:
				inside.set_normal(v[1])
				inside.set_uv(v[2])
				inside.add_vertex(v[0] - hinge)
		inside.generate_tangents()
		var inside_mesh := inside.commit()
		inside_mesh.surface_set_material(0, load("res://game/presentation/materials/wardrobe_inside.tres"))
		ResourceSaver.save(inside_mesh, OUTPUT + "wardrobe_leaf_%s_inside.res" % side)
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
