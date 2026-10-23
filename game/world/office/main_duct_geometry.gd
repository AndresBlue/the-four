extends RefCounted
## The main duct of planta 3 (spec_f1_systems 4.5), its crossing stub, the
## hatch's frame, the plant ladder up to it, the shaft at its far end and the
## remains in it. One holder of its own under the geometry root, built after
## the navigation bake: nobody walks it on the navmesh, they crawl it.
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")

const SHEET := 0.03                ## the duct's sheet, outside the clear main x main
const STUB_BARS := 3               ## bars across the stub's reducer
const MOUTH_IN := 0.6              ## where a climber is put inside the duct, along it from the hatch
## The plant ladder: its plane `out` from the hatch, its foot `stand` out, the
## grab handles `grab` over the sill.
const LADDER := {"width": 0.45, "rung": 0.28, "out": 0.12, "stand": 0.75, "grab": 1.0}
const SHAFT_HEAD := 2.6            ## clear height over the landing
const SHAFT_PIT := 6.5             ## how far the shaft goes down under the landing (black)
const MANHOLE := Vector2(0.7, 0.7)
const SHAFT_WALL := 0.18
## Through a wall: the duct's outer section and a little more.
const HOLE_PAD := 0.02

static var cache_manifest = null
static var cache_boxes: Array[AABB] = []

## The duct's clear section (plenum.main), and the floor it is crawled on.
static func main(manifest: Dictionary) -> float:
	return float(manifest.get("plenum", OFFICE.PLENUM).get("main", OFFICE.PLENUM.main))

static func floor_y(manifest: Dictionary) -> float:
	return float(manifest.air.shaft.floor_y)

## The clear inside of every straight piece, line and stub (OFFICE.crawl_boxes,
## which the generator and the validator already share).
static func boxes(manifest: Dictionary) -> Array[AABB]:
	if is_same(manifest, cache_manifest): return cache_boxes
	cache_boxes = OFFICE.crawl_boxes(manifest)
	cache_manifest = manifest
	return cache_boxes

## Whether a body's feet are in the duct (a crawl space): from its floor to its
## top, padded.
static func inside(manifest: Dictionary, point: Vector3, pad := 0.1) -> bool:
	if not manifest.has("air") or not manifest.air.has("shaft"): return false
	for box in boxes(manifest):
		if box.grow(pad).has_point(point): return true
	return false

## The way a yaw faces (+Z turned by it), and a body's rotation.y that looks
## that way (-Z forward).
static func facing(yaw: float) -> Vector3: return Vector3(sin(yaw), 0.0, cos(yaw))

static func look_yaw(way: Vector3) -> float: return atan2(-way.x, -way.z)

static func hatch_floor(manifest: Dictionary) -> Vector3:
	var p: Array = manifest.air.hatch.point
	return Vector3(float(p[0]), floor_y(manifest), float(p[2]))

## MOUTH_IN in from the hatch, on the duct's floor, facing along the duct.
static func mouth(manifest: Dictionary) -> Transform3D:
	var into := -facing(float(manifest.air.hatch.yaw))
	return Transform3D(Basis(Vector3.UP, look_yaw(into)), hatch_floor(manifest) + into * MOUTH_IN)

## The plant ladder's foot, on the plant's floor, facing the hatch.
static func foot(manifest: Dictionary) -> Transform3D:
	var out := facing(float(manifest.air.hatch.yaw))
	var at := hatch_floor(manifest)
	at.y = float(manifest.rooms[int(manifest.air.plant)].py)
	return Transform3D(Basis(Vector3.UP, look_yaw(-out)), at + out * float(LADDER.stand))

## The shaft's landing as a plan rectangle, and whether a point stands on it.
static func landing(manifest: Dictionary) -> Rect2:
	var r: Array = manifest.air.shaft.rect
	return Rect2(float(r[0]) - float(r[2]) / 2, float(r[1]) - float(r[3]) / 2, float(r[2]), float(r[3]))

static func on_landing(manifest: Dictionary, point: Vector3) -> bool:
	var y := floor_y(manifest)
	return landing(manifest).has_point(Vector2(point.x, point.z)) and point.y >= y - 0.3 and point.y <= y + 2.0

## The duct's outer boxes, padded: what a wall it crosses leaves open.
static func outer_boxes(manifest: Dictionary) -> Array[AABB]:
	var out: Array[AABB] = []
	if not manifest.has("air") or not manifest.air.has("main"): return out
	for box in boxes(manifest):
		var pad := SHEET + HOLE_PAD
		var along_x: bool = box.size.x >= box.size.z
		var across := Vector3(0.0 if along_x else pad, pad, pad if along_x else 0.0)
		out.append(AABB(box.position - across, box.size + across * 2))
	return out

## A box less another: the pieces of `a` outside `b`, at most six.
static func minus(a: AABB, b: AABB) -> Array[AABB]:
	var out: Array[AABB] = []
	if not a.intersects(b): return [a]
	var cut := a.intersection(b)
	var rest := a
	# Slab by slab along each axis, what lies before and after the cut.
	for axis in 3:
		var low := rest.position[axis]
		var high := rest.end[axis]
		if cut.position[axis] > low + 0.0005:
			var piece := rest
			piece.size[axis] = cut.position[axis] - low
			out.append(piece)
		if cut.end[axis] < high - 0.0005:
			var piece := rest
			piece.position[axis] = cut.end[axis]
			piece.size[axis] = high - cut.end[axis]
			out.append(piece)
		rest.position[axis] = cut.position[axis]
		rest.size[axis] = cut.size[axis]
	return out

## The holder "MainDuct": every box merged by material, and its colliders.
static func build(builder, manifest: Dictionary) -> Node3D:
	var holder := Node3D.new()
	holder.name = "MainDuct"
	var body := StaticBody3D.new()
	body.name = "MainDuctBody"
	body.collision_layer = 1
	body.collision_mask = 0
	holder.add_child(body)
	var parts := {}
	var size := main(manifest)
	var clear := boxes(manifest)
	# The duct: four sheets round each piece, a sheet longer at either end so
	# the corners close, less every other piece's clear inside.
	for c in clear:
		var along_x: bool = c.size.x >= c.size.z
		var grow_along := Vector3(SHEET, 0, 0) if along_x else Vector3(0, 0, SHEET)
		var lo := c.position - grow_along
		var span := c.size + grow_along * 2
		var sheets: Array[AABB] = [
			AABB(Vector3(lo.x, lo.y - SHEET, lo.z) - (Vector3(0, 0, SHEET) if along_x else Vector3(SHEET, 0, 0)), Vector3(span.x, SHEET, span.z) + (Vector3(0, 0, SHEET * 2) if along_x else Vector3(SHEET * 2, 0, 0))),
			AABB(Vector3(lo.x, c.end.y, lo.z) - (Vector3(0, 0, SHEET) if along_x else Vector3(SHEET, 0, 0)), Vector3(span.x, SHEET, span.z) + (Vector3(0, 0, SHEET * 2) if along_x else Vector3(SHEET * 2, 0, 0))),
		]
		if along_x:
			sheets.append(AABB(Vector3(lo.x, c.position.y, c.position.z - SHEET), Vector3(span.x, c.size.y, SHEET)))
			sheets.append(AABB(Vector3(lo.x, c.position.y, c.end.z), Vector3(span.x, c.size.y, SHEET)))
		else:
			sheets.append(AABB(Vector3(c.position.x - SHEET, c.position.y, lo.z), Vector3(SHEET, c.size.y, span.z)))
			sheets.append(AABB(Vector3(c.end.x, c.position.y, lo.z), Vector3(SHEET, c.size.y, span.z)))
		for sheet in sheets:
			var pieces: Array[AABB] = [sheet]
			for other in clear:
				var next: Array[AABB] = []
				for piece in pieces: next.append_array(minus(piece, other))
				pieces = next
			for piece in pieces: solid(parts, body, "galvanized", piece)
	# The crossing's stub ends in a reducer: a plate with the network's opening,
	# the dark beyond and bars across it, crawled to and no further.
	var main_data: Dictionary = manifest.air.main
	var nodes: Array = manifest.ducts.nodes
	var cross_node: Array = nodes[int(main_data.cross)]
	var stub_way := Vector3(float(main_data.stub[0]), 0, float(main_data.stub[1]))
	var stub_end := Vector3(float(cross_node[0]), floor_y(manifest) + size / 2, float(cross_node[2])) + stub_way * (size / 2 + float(OFFICE.STUB))
	var flat: bool = absf(stub_way.x) < 0.5
	var dark_size := Vector3(size, size, 0.6) if flat else Vector3(0.6, size, size)
	solid(parts, null, "black", AABB(stub_end + stub_way * 0.3 - dark_size / 2, dark_size))
	for k in STUB_BARS:
		var off := (float(k) - (STUB_BARS - 1) / 2.0) * size / (STUB_BARS + 1) * 1.6
		var bar_at := stub_end + (Vector3(off, 0, 0) if flat else Vector3(0, 0, off))
		solid(parts, body, "steel_frame", AABB(bar_at - Vector3(0.015, size / 2, 0.015), Vector3(0.03, size, 0.03)))
	# The hatch's frame round the duct's open end in the plant.
	var out := facing(float(manifest.air.hatch.yaw))
	var hatch_at := hatch_floor(manifest)
	var side := Vector3(out.z, 0, -out.x)
	for s: float in [-1.0, 1.0]:
		var rail_at := hatch_at + side * s * (size / 2 + SHEET + 0.03) + Vector3(0, size / 2, 0)
		solid(parts, null, "galvanized", AABB(rail_at - (Vector3(0.03, size / 2 + 0.06, 0.03)), Vector3(0.06, size + 0.12, 0.06)))
		var bar_at := hatch_at + Vector3(0, (size + SHEET + 0.03) if s > 0 else -SHEET - 0.03, 0)
		solid(parts, null, "galvanized", AABB(bar_at - (Vector3(absf(side.x) * (size / 2 + 0.09) + 0.03, 0.03, absf(side.z) * (size / 2 + 0.09) + 0.03)), Vector3(absf(side.x) * (size + 0.18) + 0.06, 0.06, absf(side.z) * (size + 0.18) + 0.06)))
	# The plant ladder, its plane LADDER.out from the frame, from the floor to
	# the sill, and the grab handles over it.
	var plant_y := float(manifest.rooms[int(manifest.air.plant)].py)
	var plane := hatch_at + out * float(LADDER.out)
	var rise := floor_y(manifest) - plant_y
	for s: float in [-1.0, 1.0]:
		var rail := plane + side * s * float(LADDER.width) / 2
		solid(parts, null, "steel_frame", AABB(Vector3(rail.x - 0.025, plant_y, rail.z - 0.025), Vector3(0.05, rise + float(LADDER.grab), 0.05)))
	var rungs := int(rise / float(LADDER.rung))
	for k in range(1, rungs + 1):
		var rung_at := plane + Vector3(0, plant_y - floor_y(manifest) + k * float(LADDER.rung), 0)
		solid(parts, null, "steel_frame", AABB(rung_at - Vector3(absf(side.x) * float(LADDER.width) / 2 + 0.012, 0.012, absf(side.z) * float(LADDER.width) / 2 + 0.012), Vector3(absf(side.x) * float(LADDER.width) + 0.024, 0.024, absf(side.z) * float(LADDER.width) + 0.024)))
	var ladder_box := AABB(Vector3(plane.x, plant_y, plane.z) - Vector3(absf(side.x) * 0.25 + absf(out.x) * 0.03, 0, absf(side.z) * 0.25 + absf(out.z) * 0.03), Vector3(absf(side.x) * 0.5 + absf(out.x) * 0.06, rise, absf(side.z) * 0.5 + absf(out.z) * 0.06))
	collider(body, ladder_box)
	# The shaft: four concrete walls from the pit to over the landing, a roof,
	# the landing with its manhole, and the rung ladder down into the dark.
	var rect := landing(manifest)
	var y := floor_y(manifest)
	var bottom := y - SHAFT_PIT
	var top := y + SHAFT_HEAD
	var shaft_side: Array = manifest.air.shaft.side
	var e := Vector3(float(shaft_side[0]), 0, float(shaft_side[1]))
	var w := SHAFT_WALL
	var walls: Array = [
		[Vector3(-1, 0, 0), AABB(Vector3(rect.position.x - w, bottom, rect.position.y - w), Vector3(w, top - bottom, rect.size.y + w * 2))],
		[Vector3(1, 0, 0), AABB(Vector3(rect.end.x, bottom, rect.position.y - w), Vector3(w, top - bottom, rect.size.y + w * 2))],
		[Vector3(0, 0, -1), AABB(Vector3(rect.position.x, bottom, rect.position.y - w), Vector3(rect.size.x, top - bottom, w))],
		[Vector3(0, 0, 1), AABB(Vector3(rect.position.x, bottom, rect.end.y), Vector3(rect.size.x, top - bottom, w))],
	]
	var mouth_cut := AABB()
	for c in clear: if mouth_cut.size == Vector3.ZERO and c.grow(0.5).has_point(Vector3(float(manifest.air.shaft.point[0]), y + size / 2, float(manifest.air.shaft.point[2]))): mouth_cut = c
	for entry in walls:
		var piece_box: AABB = entry[1]
		var pieces: Array[AABB] = [piece_box]
		if (entry[0] as Vector3).is_equal_approx(-e) and mouth_cut.size != Vector3.ZERO:
			var hole := mouth_cut.grow(SHEET)
			hole.position -= e.abs() * 0.5
			hole.size += e.abs() * 1.0
			pieces = minus(piece_box, hole)
		for piece in pieces: solid(parts, body, "concrete", piece)
	solid(parts, body, "concrete", AABB(Vector3(rect.position.x - w, top, rect.position.y - w), Vector3(rect.size.x + w * 2, w, rect.size.y + w * 2)))
	var ladder_p: Array = manifest.air.shaft.ladder.point
	var hole_at := Vector2(float(ladder_p[0]), float(ladder_p[2]))
	var manhole := AABB(Vector3(hole_at.x - MANHOLE.x / 2, y - 0.1, hole_at.y - MANHOLE.y / 2), Vector3(MANHOLE.x, 0.2, MANHOLE.y))
	for piece in minus(AABB(Vector3(rect.position.x, y - 0.04, rect.position.y), Vector3(rect.size.x, 0.04, rect.size.y)), manhole): solid(parts, null, "steel_plate", piece)
	# Nobody falls in: the landing is solid over the manhole too.
	collider(body, AABB(Vector3(rect.position.x, y - 0.04, rect.position.y), Vector3(rect.size.x, 0.04, rect.size.y)))
	solid(parts, null, "black", AABB(Vector3(rect.position.x, bottom, rect.position.y), Vector3(rect.size.x, 0.05, rect.size.y)))
	for s: float in [-1.0, 1.0]:
		var rail := Vector3(hole_at.x, 0, hole_at.y) + Vector3(-e.z, 0, e.x) * s * 0.2
		solid(parts, null, "steel_frame", AABB(Vector3(rail.x - 0.025, bottom, rail.z - 0.025), Vector3(0.05, y - bottom + 1.1, 0.05)))
	for k in int((y - bottom) / 0.3):
		var rung_y := bottom + 0.3 * (k + 1)
		solid(parts, null, "steel_frame", AABB(Vector3(hole_at.x - 0.2 * absf(e.z) - 0.012, rung_y, hole_at.y - 0.2 * absf(e.x) - 0.012), Vector3(0.4 * absf(e.z) + 0.024, 0.024, 0.4 * absf(e.x) + 0.024)))
	# The remains of whoever tried before (OFICINAS 3), against one side wall.
	var remains_p: Array = manifest.air.remains.point
	var r_at := Vector3(float(remains_p[0]), y, float(remains_p[2]))
	var r_side := Vector3.ZERO
	for c in clear:
		if c.grow(0.05).has_point(r_at + Vector3(0, 0.1, 0)):
			r_side = Vector3(0, 0, 1) if c.size.x >= c.size.z else Vector3(1, 0, 0)
			break
	var skull := r_at + r_side * 0.3 + Vector3(0, 0.07, 0)
	solid(parts, null, "bone", AABB(skull - Vector3(0.07, 0.07, 0.08), Vector3(0.14, 0.14, 0.16)))
	var along := Vector3(r_side.z, 0, r_side.x)
	for k in 5:
		var bone_at := r_at + r_side * (0.22 - k * 0.04) + along * (-0.25 + k * 0.12) + Vector3(0, 0.02, 0)
		var bone_size := Vector3(0.04, 0.04, 0.04) + along * 0.32
		solid(parts, null, "bone", AABB(bone_at - bone_size / 2, bone_size))
	solid(parts, null, "coverall", AABB(r_at + r_side * 0.12 - Vector3(0.18, 0.0, 0.18), Vector3(0.36, 0.01, 0.36)))
	for key in parts: holder.add_child(merged(builder, key, parts[key]))
	return holder

## A box drawn with this material, and, with a body, solid.
static func solid(parts: Dictionary, body: StaticBody3D, material: String, box: AABB) -> void:
	if box.size.x < 0.001 or box.size.y < 0.001 or box.size.z < 0.001: return
	if not parts.has(material): parts[material] = []
	parts[material].append(box)
	if body != null: collider(body, box)

static func collider(body: StaticBody3D, box: AABB) -> void:
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = box.size
	shape.shape = cube
	shape.position = box.get_center()
	body.add_child(shape)

## One mesh of every box of a material.
static func merged(builder, material: String, list: Array) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cube := BoxMesh.new()
	for item in list:
		var box: AABB = item
		tool.append_from(cube, 0, Transform3D(Basis.from_scale(box.size), box.get_center()))
	var mesh := MeshInstance3D.new()
	mesh.name = "MainDuct_%s" % material
	mesh.mesh = tool.commit()
	mesh.material_override = material_of(builder, material)
	mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return mesh

## The builder's material of that name, or a plain one for the few it lacks.
static func material_of(builder, material: String) -> Material:
	if builder != null and builder.materials.has(material): return builder.materials[material]
	var plain := StandardMaterial3D.new()
	plain.albedo_color = {"galvanized": Color("8d9296"), "bone": Color("d8cfb8"), "coverall": Color("5b5d58"), "black": Color(0.01, 0.01, 0.01), "concrete": Color("8b8780"), "steel_plate": Color("6f7275"), "steel_frame": Color("4a4c4e")}.get(material, Color.GRAY)
	plain.metallic = 0.6 if material in ["galvanized", "steel_plate", "steel_frame"] else 0.0
	plain.roughness = 0.45 if material == "galvanized" else 0.8
	if builder != null: builder.materials[material] = plain
	return plain
