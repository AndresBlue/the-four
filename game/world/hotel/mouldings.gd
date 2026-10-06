extends RefCounted
## The moulded kit (graphics preset detail_kit; docs/REALISM.md, phase 6):
## what stands where a wall meets the floor, the dado and the ceiling, run to
## the section a joiner would have given it, in place of the plain boxes that
## stand there on every other preset; the dado's panels raised out of their
## frames; and the plaster rose a ceiling lamp hangs from. All of it is made
## here from a section each: nothing downloaded, nothing stored.
##
## A section is a line in a wall's own cut, as (out, up): `out` in metres from
## the middle of the wall, as hotel_geometry places its boxes (the plaster's
## face is 0.09 out, the dado's 0.145), and `up` from where the piece hangs
## (the floor, the top of the dado, the ceiling). It goes round the piece
## anticlockwise, from the wall and back to it. What lies in the plane the
## piece hangs from (up 0 at both ends: on the floor, against the ceiling) is
## not drawn; nor is the side against the wall.

## Length of a run's mesh. Ten to a metre, so the wood's grain -- which runs
## along whichever side of a piece its scale makes the longest
## (wood.gdshaderinc) -- runs along a moulding however short.
const UNIT := 0.1
## Two faces meeting at less than this (the dot of their normals) are a curve
## and share their normals; at more, an edge.
const SMOOTH := 0.8

## The skirting stands on the floor against the dado: a flat board, a bead
## and a cove back to the wall. From the floor.
const SKIRTING := [Vector2(0.14, 0.0), Vector2(0.172, 0.0), Vector2(0.172, 0.104), Vector2(0.168, 0.11), Vector2(0.17, 0.116), Vector2(0.168, 0.122), Vector2(0.162, 0.127), Vector2(0.154, 0.138), Vector2(0.149, 0.152), Vector2(0.147, 0.16), Vector2(0.14, 0.16)]
## The rail caps the dado and covers where it meets the plaster: a lip under
## it, a rounded nose, and a slope back up the wall. From the dado's top.
const RAIL := [Vector2(0.14, -0.03), Vector2(0.166, -0.03), Vector2(0.168, -0.024), Vector2(0.164, -0.015), Vector2(0.167, -0.007), Vector2(0.173, -0.001), Vector2(0.176, 0.008), Vector2(0.176, 0.017), Vector2(0.173, 0.026), Vector2(0.165, 0.032), Vector2(0.15, 0.036), Vector2(0.118, 0.043), Vector2(0.098, 0.05), Vector2(0.085, 0.052)]
## The cornice: a flat band no further out than a door's casing, which
## reaches up into it (2.80 m of a 2.90 m wall), and over it a cove and a
## quarter round out to the ceiling. From the ceiling, down.
const CORNICE := [Vector2(0.085, -0.16), Vector2(0.104, -0.16), Vector2(0.104, -0.146), Vector2(0.11, -0.14), Vector2(0.11, -0.104), Vector2(0.116, -0.1), Vector2(0.116, -0.092), Vector2(0.1193, -0.0752), Vector2(0.1289, -0.0609), Vector2(0.1432, -0.0513), Vector2(0.16, -0.048), Vector2(0.166, -0.048), Vector2(0.166, -0.04), Vector2(0.178, -0.0368), Vector2(0.1868, -0.028), Vector2(0.19, -0.016), Vector2(0.196, -0.016), Vector2(0.196, 0.0), Vector2(0.085, 0.0)]
const SECTIONS := {"skirting": SKIRTING, "rail": RAIL, "cornice": CORNICE}

## A panel of the dado: a frame, a bevel down into a groove, and the field
## raised again in the middle of it. It stands from behind the skirting to
## inside the rail, one every PANEL_WIDTH along a wall.
const PANEL_WIDTH := 0.6
const PANEL_FOOT := 0.12
const PANEL_HEAD := 0.955
## How far out the frame's face is, the groove's and the field's.
const PANEL_FRAME := 0.16
const PANEL_GROOVE := 0.149
const PANEL_FIELD := 0.155

static var cache := {}

## One triangle, wound as Godot wants its fronts (clockwise, seen from where
## the normals point) whatever order it comes in.
static func tri(vertices: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (b - a).cross(c - a).dot(na + nb + nc) > 0.0:
		vertices.append_array([a, c, b])
		normals.append_array([na, nc, nb])
	else:
		vertices.append_array([a, b, c])
		normals.append_array([na, nb, nc])

static func quad(vertices: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, na: Vector3, nb: Vector3, nc: Vector3, nd: Vector3) -> void:
	tri(vertices, normals, a, b, c, na, nb, nc)
	tri(vertices, normals, a, c, d, na, nc, nd)

static func finish(title: String, vertices: PackedVector3Array, normals: PackedVector3Array, casts: bool) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.resource_name = title
	# Low as they are, these cast: a rail's shadow on its dado and a
	# cornice's on the ceiling over a wall lamp are half of what they are for
	# (hotel_geometry.flush() leaves anything this low without one).
	if casts: mesh.set_meta("casts", true)
	cache[title] = mesh
	return mesh

## Each stretch of a section's outward normal, as (out, up).
static func faces_of(section: Array) -> Array:
	var faces := []
	for i in section.size() - 1:
		var along: Vector2 = section[i + 1] - section[i]
		faces.append(Vector2(along.y, -along.x).normalized())
	return faces

## Whether a stretch of a section is drawn (the header).
static func drawn(section: Array, i: int) -> bool:
	return absf(section[i].y) > 0.000001 or absf(section[i + 1].y) > 0.000001

## The normal at a section's point, for the stretch on one side of it: shared
## with the stretch on the other side where the two make a curve.
static func normal_at(section: Array, faces: Array, point: int, stretch: int) -> Vector2:
	var other := point - 1 if stretch == point else point
	if other < 0 or other >= faces.size() or other == stretch or not drawn(section, other): return faces[stretch]
	if (faces[other] as Vector2).dot(faces[stretch]) < SMOOTH: return faces[stretch]
	return (faces[other] + faces[stretch]).normalized()

## A length of moulding, UNIT long along x and centred, its section in (z, y)
## and its ends closed: stretched to a wall's length where it is placed.
static func run(kind: String) -> ArrayMesh:
	var title := "moulding_" + kind
	if cache.has(title): return cache[title]
	var section: Array = SECTIONS[kind]
	var faces := faces_of(section)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var half := UNIT * 0.5
	for i in section.size() - 1:
		if not drawn(section, i): continue
		var p: Vector2 = section[i]
		var q: Vector2 = section[i + 1]
		var np := normal_at(section, faces, i, i)
		var nq := normal_at(section, faces, i + 1, i)
		var from := Vector3(0, np.y, np.x)
		var to := Vector3(0, nq.y, nq.x)
		quad(vertices, normals, Vector3(-half, p.y, p.x), Vector3(half, p.y, p.x), Vector3(half, q.y, q.x), Vector3(-half, q.y, q.x), from, from, to, to)
	var outline := PackedVector2Array(section)
	var corners := Geometry2D.triangulate_polygon(outline)
	for side in [-1.0, 1.0]:
		var facing := Vector3(side, 0, 0)
		for at in range(0, corners.size(), 3):
			var a: Vector2 = outline[corners[at]]
			var b: Vector2 = outline[corners[at + 1]]
			var c: Vector2 = outline[corners[at + 2]]
			tri(vertices, normals, Vector3(side * half, a.y, a.x), Vector3(side * half, b.y, b.x), Vector3(side * half, c.y, c.x), facing, facing, facing)
	return finish(title, vertices, normals, true)

## The same moulding round a corner that sticks out into a room, mitred. The
## corner is at the origin and the room towards -x and -z: one wall's run
## ends at x = 0 with its face towards -z, the other's at z = 0 with its face
## towards -x, and this carries both on to where they meet.
static func corner(kind: String) -> ArrayMesh:
	var title := "moulding_corner_" + kind
	if cache.has(title): return cache[title]
	var section: Array = SECTIONS[kind]
	var faces := faces_of(section)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in section.size() - 1:
		if not drawn(section, i): continue
		var p: Vector2 = section[i]
		var q: Vector2 = section[i + 1]
		var np := normal_at(section, faces, i, i)
		var nq := normal_at(section, faces, i + 1, i)
		# The run along x, carried on from x = 0 to the mitre.
		var from := Vector3(0, np.y, -np.x)
		var to := Vector3(0, nq.y, -nq.x)
		quad(vertices, normals, Vector3(0, p.y, -p.x), Vector3(-p.x, p.y, -p.x), Vector3(-q.x, q.y, -q.x), Vector3(0, q.y, -q.x), from, from, to, to)
		# And the one along z.
		from = Vector3(-np.x, np.y, 0)
		to = Vector3(-nq.x, nq.y, 0)
		quad(vertices, normals, Vector3(-p.x, p.y, 0), Vector3(-p.x, p.y, -p.x), Vector3(-q.x, q.y, -q.x), Vector3(-q.x, q.y, 0), from, from, to, to)
	return finish(title, vertices, normals, true)

## The band between two rectangles standing at different depths: [left,
## bottom, right, top] and how far out, each. Four faces, each flat.
static func band(vertices: PackedVector3Array, normals: PackedVector3Array, outer: Array, outer_out: float, inner: Array, inner_out: float) -> void:
	var a := [Vector3(outer[0], outer[1], outer_out), Vector3(outer[2], outer[1], outer_out), Vector3(outer[2], outer[3], outer_out), Vector3(outer[0], outer[3], outer_out)]
	var b := [Vector3(inner[0], inner[1], inner_out), Vector3(inner[2], inner[1], inner_out), Vector3(inner[2], inner[3], inner_out), Vector3(inner[0], inner[3], inner_out)]
	for k in 4:
		var next := (k + 1) % 4
		var facing: Vector3 = ((a[next] - a[k]) as Vector3).cross(b[k] - a[k]).normalized()
		# Every face of a panel looks out of the wall.
		if facing.z < 0.0: facing = -facing
		quad(vertices, normals, a[k], a[next], b[next], b[k], facing, facing, facing, facing)

static func inset(rect: Array, by: float) -> Array:
	return [rect[0] + by, rect[1] + by, rect[2] - by, rect[3] - by]

## A raised panel of the dado, PANEL_WIDTH wide and centred on x, its face
## towards +z.
static func panel() -> ArrayMesh:
	var title := "moulding_panel"
	if cache.has(title): return cache[title]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var whole := [-PANEL_WIDTH * 0.5, PANEL_FOOT, PANEL_WIDTH * 0.5, PANEL_HEAD]
	# Stiles of 5 cm (10 between two panels), and rails that show some 7 cm
	# over the skirting and under the dado rail.
	var opening := [whole[0] + 0.05, whole[1] + 0.085, whole[2] - 0.05, whole[3] - 0.095]
	var groove := inset(opening, 0.02)
	var rise := inset(groove, 0.028)
	var field := inset(rise, 0.02)
	band(vertices, normals, whole, PANEL_FRAME, opening, PANEL_FRAME)
	band(vertices, normals, opening, PANEL_FRAME, groove, PANEL_GROOVE)
	band(vertices, normals, groove, PANEL_GROOVE, rise, PANEL_GROOVE)
	band(vertices, normals, rise, PANEL_GROOVE, field, PANEL_FIELD)
	var out := Vector3(0, 0, 1)
	quad(vertices, normals, Vector3(field[0], field[1], PANEL_FIELD), Vector3(field[2], field[1], PANEL_FIELD), Vector3(field[2], field[3], PANEL_FIELD), Vector3(field[0], field[3], PANEL_FIELD), out, out, out, out)
	return finish(title, vertices, normals, false)

## The plaster rose round a ceiling lamp: rings turned about the lamp's own
## axis, hanging from y = 0. As (radius, up), from the rim in to where the
## lamp's brass ring covers it.
const ROSE := [Vector2(0.5, 0.0), Vector2(0.5, -0.008), Vector2(0.486, -0.014), Vector2(0.472, -0.012), Vector2(0.46, -0.018), Vector2(0.44, -0.014), Vector2(0.4, -0.016), Vector2(0.385, -0.026), Vector2(0.365, -0.03), Vector2(0.345, -0.026), Vector2(0.33, -0.018), Vector2(0.3, -0.02), Vector2(0.285, -0.032), Vector2(0.24, -0.034)]
const ROSE_TURNS := 48

static func rose() -> ArrayMesh:
	var title := "moulding_rose"
	if cache.has(title): return cache[title]
	var faces := []
	for i in ROSE.size() - 1:
		var along: Vector2 = ROSE[i + 1] - ROSE[i]
		# Out of the ceiling: down, and away from the lamp at the rim.
		faces.append(Vector2(-along.y, along.x).normalized())
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for turn in ROSE_TURNS:
		var a := TAU * float(turn) / ROSE_TURNS
		var b := TAU * float(turn + 1) / ROSE_TURNS
		for i in ROSE.size() - 1:
			var p: Vector2 = ROSE[i]
			var q: Vector2 = ROSE[i + 1]
			var np: Vector2 = faces[i] if i == 0 or (faces[i - 1] as Vector2).dot(faces[i]) < SMOOTH else (faces[i - 1] + faces[i]).normalized()
			var nq: Vector2 = faces[i] if i == faces.size() - 1 or (faces[i + 1] as Vector2).dot(faces[i]) < SMOOTH else (faces[i + 1] + faces[i]).normalized()
			quad(vertices, normals,
				Vector3(cos(a) * p.x, p.y, sin(a) * p.x), Vector3(cos(b) * p.x, p.y, sin(b) * p.x), Vector3(cos(b) * q.x, q.y, sin(b) * q.x), Vector3(cos(a) * q.x, q.y, sin(a) * q.x),
				Vector3(cos(a) * np.x, np.y, sin(a) * np.x), Vector3(cos(b) * np.x, np.y, sin(b) * np.x), Vector3(cos(b) * nq.x, nq.y, sin(b) * nq.x), Vector3(cos(a) * nq.x, nq.y, sin(a) * nq.x))
	return finish(title, vertices, normals, false)
