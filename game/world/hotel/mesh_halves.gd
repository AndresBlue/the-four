extends RefCounted
## A mesh that stands in a wall, cut in two along the wall's middle (its own
## z = 0): the half that looks into the room in front of it (+z) and the half
## that looks into the room behind.
##
## For the lowest graphics preset (hotel_geometry.gd, "Light that stays in its
## room"), where no lamp casts a shadow and each lights only what is on its
## own room's layer. A door's casing stands in two rooms; whole, it would be
## on both layers, and the lamp of the room in front lit the jambs of the side
## behind through the wall -- two thin bright lines round a shut door in a
## room that is supposed to be black (tools/dev/light_leak.gd). In halves,
## each is on its own room's layer.
##
## A triangle that faces one of the two rooms goes whole to that room's half,
## wherever it is: it can only ever be lit from that side. One that faces
## along the wall (a jamb's lining, the return of a moulding) is cut at z = 0.
const FACING := 0.3
static var cache := {}

## [front, back] of a mesh, made once.
static func of(mesh: Mesh) -> Array:
	if cache.has(mesh): return cache[mesh]
	var halves: Array = [ArrayMesh.new(), ArrayMesh.new()]
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents = arrays[Mesh.ARRAY_TANGENT]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(points.size()))
		var tools: Array = [SurfaceTool.new(), SurfaceTool.new()]
		for tool in tools: tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for at in range(0, indices.size() - 2, 3):
			var corners: Array = []
			var facing := 0.0
			for k in 3:
				var i := indices[at + k]
				facing += normals[i].z / 3.0
				corners.append({
					"point": points[i], "normal": normals[i],
					"tangent": Plane(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2], tangents[i * 4 + 3]) if tangents != null else Plane(1, 0, 0, 1),
					"uv": uvs[i] if uvs != null else Vector2.ZERO,
				})
			if absf(facing) > FACING: emit(tools[0 if facing > 0.0 else 1], corners)
			else:
				emit(tools[0], clip(corners, 1.0))
				emit(tools[1], clip(corners, -1.0))
		for side in 2:
			var tool: SurfaceTool = tools[side]
			tool.index()
			tool.set_material(mesh.surface_get_material(surface))
			tool.commit(halves[side])
	cache[mesh] = halves
	return halves

## What of a triangle (or of what is left of one) lies on the side of z = 0
## that `side` names, as a polygon: the corners there, and a new one wherever
## an edge crosses.
static func clip(corners: Array, side: float) -> Array:
	var out: Array = []
	for k in corners.size():
		var a: Dictionary = corners[k]
		var b: Dictionary = corners[(k + 1) % corners.size()]
		var za: float = a.point.z * side
		var zb: float = b.point.z * side
		if za >= 0.0: out.append(a)
		if (za > 0.0 and zb < 0.0) or (za < 0.0 and zb > 0.0):
			var t := za / (za - zb)
			var along: Plane = a.tangent
			out.append({
				"point": (a.point as Vector3).lerp(b.point, t), "normal": (a.normal as Vector3).lerp(b.normal, t).normalized(),
				"tangent": Plane((along.normal).lerp((b.tangent as Plane).normal, t).normalized(), along.d),
				"uv": (a.uv as Vector2).lerp(b.uv, t),
			})
	return out

## A polygon into a surface, as a fan of triangles.
static func emit(tool: SurfaceTool, polygon: Array) -> void:
	for k in range(1, polygon.size() - 1):
		var corners := [polygon[0], polygon[k], polygon[k + 1]]
		# What a cut leaves with no area is left out.
		if ((corners[1].point - corners[0].point) as Vector3).cross(corners[2].point - corners[0].point).length_squared() < 1e-12: continue
		for corner in corners:
			tool.set_normal(corner.normal)
			tool.set_tangent(corner.tangent)
			tool.set_uv(corner.uv)
			tool.add_vertex(corner.point)
