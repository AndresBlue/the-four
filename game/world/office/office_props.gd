extends RefCounted
## The offices' corner pieces (room.props at room.sockets; spec_f1_geometry.md
## 9.3), built from boxes and cylinders so they batch with their room. Each
## stands in the hotel desk's footprint (2.3 × 1.4 round the socket), its back
## at local -Z, under FURNITURE_TOP, its big parts with a box collider. The
## kinds that want an ingested model (desk, filing, chairs, armchair, copier,
## reader, sorter, vending) are not built yet; the hotel's own kinds (plant,
## bin, basin, cart) go to prop_factory.
const BACK := -0.7
const HOTEL_KINDS := ["plant", "bin", "basin", "cart"]

## Builds an office corner piece; false for a kind it leaves to prop_factory.
static func build(builder: Node3D, node: Node3D, kind: String) -> bool:
	if kind in HOTEL_KINDS: return false
	var seed_pos: Vector3 = node.position + Vector3(0, float(kind.length()), 0)
	match kind:
		"reception":
			# A counter facing into the room, with a pad on its top.
			solid(builder, node, Vector3(2.2, 0.9, 1.1))
			builder.box(node, at(0.45, 1.1), Vector3(2.2, 0.9, 1.1), "enamel")
			builder.box(node, at(0.92, 1.1), Vector3(2.24, 0.04, 1.14), "laminate")
			builder.box(node, at(0.945, 1.1) + Vector3(0.4, 0, 0.1), Vector3(0.21, 0.01, 0.3), "linen")
		"shelf":
			shelving(builder, node, 2.0, 0.4, 2.1, seed_pos)
		"coat_rack":
			builder.box(node, at(0.9, 0.4), Vector3(0.4, 1.85, 0.4), "", true)
			builder.cylinder(node, at(0.925, 0.4), 0.022, 1.85, "wood")
			for k in 2: builder.box(node, at(0.02, 0.4), Vector3(0.5 if k == 0 else 0.04, 0.04, 0.04 if k == 0 else 0.5), "wood")
			for k in 6:
				var turn := TAU * k / 6.0
				builder.box(node, at(1.7, 0.4) + Vector3(cos(turn) * 0.09, 0, sin(turn) * 0.09), Vector3(0.12, 0.02, 0.02), "wood", false, "box", Vector3(0, -turn, 0))
			if builder.vary(seed_pos, 1) < 0.34: builder.box(node, at(1.3, 0.4) + Vector3(0.12, 0, 0), Vector3(0.12, 0.8, 0.45), "fabric")
		"bench":
			solid(builder, node, Vector3(1.5, 0.45, 0.45))
			for k in 3: builder.box(node, at(0.43, 0.45) + Vector3(0, 0, -0.14 + k * 0.14), Vector3(1.5, 0.03, 0.1), "wood")
			for x in [-0.65, 0.65]: builder.box(node, at(0.2, 0.45) + Vector3(x, 0, 0), Vector3(0.04, 0.4, 0.4), "steel_frame")
		"sideboard":
			solid(builder, node, Vector3(1.8, 0.8, 0.48))
			builder.box(node, at(0.4, 0.48), Vector3(1.8, 0.8, 0.48), "veneer")
		"table":
			solid(builder, node, Vector3(1.6, 0.84, 0.9))
			builder.box(node, at(0.82, 0.9), Vector3(1.6, 0.04, 0.9), "laminate")
			for x in [-0.74, 0.74]:
				for z in [-0.38, 0.38]: builder.box(node, at(0.4, 0.9) + Vector3(x, 0, z), Vector3(0.04, 0.8, 0.04), "steel_frame")
		"board":
			solid(builder, node, Vector3(1.5, 1.9, 0.4))
			builder.box(node, at(1.3, 0.4), Vector3(1.5, 1.0, 0.02), "enamel")
			builder.box(node, at(0.78, 0.4) + Vector3(0, 0, 0.04), Vector3(1.4, 0.03, 0.08), "metal")
			for x in [-0.72, 0.72]: builder.box(node, at(0.95, 0.4) + Vector3(x, 0, 0), Vector3(0.04, 1.9, 0.04), "steel_frame")
		"projector":
			solid(builder, node, Vector3(0.6, 1.25, 0.45))
			builder.box(node, at(0.375, 0.45), Vector3(0.6, 0.75, 0.45), "metal")
			builder.box(node, at(0.88, 0.45), Vector3(0.42, 0.26, 0.38), "enamel")
			builder.cylinder(node, at(1.08, 0.45) + Vector3(0.12, 0, 0), 0.015, 0.3, "metal")
			builder.box(node, at(1.2, 0.45) + Vector3(0.12, 0, 0.05), Vector3(0.12, 0.08, 0.12), "enamel")
		"cooler":
			solid(builder, node, Vector3(0.32, 1.45, 0.32))
			builder.box(node, at(0.5, 0.32), Vector3(0.32, 1.0, 0.32), "enamel")
			builder.cylinder(node, at(1.22, 0.32), 0.14, 0.45, "bottle")
		"fridge":
			solid(builder, node, Vector3(0.6, 1.6, 0.65))
			builder.box(node, at(0.8, 0.65), Vector3(0.6, 1.6, 0.65), "enamel")
			builder.box(node, at(1.2, 0.65) + Vector3(0.24, 0, 0.34), Vector3(0.02, 0.4, 0.03), "metal")
		"cabinet":
			solid(builder, node, Vector3(1.0, 2.0, 0.5))
			builder.box(node, at(1.0, 0.5), Vector3(1.0, 2.0, 0.5), "steel_olive")
			builder.box(node, at(1.0, 0.5) + Vector3(0, 0, 0.252), Vector3(0.006, 1.9, 0.004), "black")
		"gun_rack":
			solid(builder, node, Vector3(1.0, 1.9, 0.45))
			builder.box(node, at(0.95, 0.04), Vector3(1.0, 1.9, 0.02), "steel_olive")
			for x in [-0.49, 0.49]: builder.box(node, at(0.95, 0.45) + Vector3(x, 0, 0), Vector3(0.02, 1.9, 0.45), "steel_olive")
			for y in [0.01, 1.89]: builder.box(node, at(y, 0.45), Vector3(1.0, 0.02, 0.45), "steel_olive")
			for k in 6: builder.box(node, at(0.35, 0.45) + Vector3(-0.4 + k * 0.16, 0, 0.1), Vector3(0.05, 0.05, 0.1), "black")
			builder.cylinder(node, at(1.5, 0.45) + Vector3(0.3, 0, 0.15), 0.008, 0.6, "metal")
		"boxes":
			solid(builder, node, Vector3(1.0, 1.2, 0.45))
			for column in 3:
				var tall: int = 2 + int(builder.vary(seed_pos, 10 + column) * 3)
				for k in tall: builder.box(node, at(0.125 + k * 0.25, 0.39) + Vector3(-0.34 + column * 0.34, 0, 0), Vector3(0.33, 0.25, 0.39), "cardboard")
	return true

## A point at height y, centred on a piece of depth d whose back is at BACK.
static func at(y: float, depth: float) -> Vector3:
	return Vector3(0, y, BACK + depth * 0.5)

## The collider of a piece of `size` standing at the back.
static func solid(builder: Node3D, node: Node3D, size: Vector3) -> void:
	builder.box(node, at(size.y * 0.5, size.z), size, "", true)

## Slotted-angle shelving: bays a metre wide, six shelves to `height`,
## archive boxes on 60 to 90 % of the places by vary.
static func shelving(builder: Node3D, node: Node3D, width: float, depth: float, height: float, seed_pos: Vector3) -> void:
	solid(builder, node, Vector3(width, height, depth))
	var bays := maxi(1, roundi(width))
	for k in bays + 1:
		var x := -width * 0.5 + width * k / bays
		for z in [-depth * 0.5 + 0.015, depth * 0.5 - 0.015]: builder.box(node, at(height * 0.5, depth) + Vector3(x, 0, z), Vector3(0.03, height, 0.03), "steel_olive")
	var fill: float = 0.6 + builder.vary(seed_pos, 20) * 0.3
	for s in 6:
		var y := 0.05 + (height - 0.1) * s / 5.0
		builder.box(node, at(y, depth), Vector3(width, 0.02, depth), "steel_olive")
		if s == 5: continue
		for k in int(width / 0.36):
			if builder.vary(seed_pos + Vector3(k, s, 0), 21) > fill: continue
			builder.box(node, at(y + 0.135, depth) + Vector3(-width * 0.5 + 0.2 + k * 0.36, 0, 0), Vector3(0.33, 0.25, minf(0.39, depth - 0.02)), "cardboard")

## A piece of an archive row (spec 9.4), room-local: slotted-angle shelving
## `height` tall along x (`along_x`) or z, uprights every metre, six shelves,
## archive boxes on 60 to 90 % of the places; on a mobile row, a carriage
## 0.1 high with a crank wheel and two floor rails. One collider for it all.
static func row(builder: Node3D, node: Node3D, centre: Vector3, length: float, depth: float, height: float, along_x: bool, mobile: bool, seed_pos: Vector3) -> void:
	var size := Vector3(length, height, depth) if along_x else Vector3(depth, height, length)
	builder.box(node, centre + Vector3(0, height * 0.5, 0), size, "", true)
	var along := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var across := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var flat := func(l: float, h: float, d: float) -> Vector3: return Vector3(l, h, d) if along_x else Vector3(d, h, l)
	var base := 0.0
	if mobile:
		base = 0.1
		builder.box(node, centre + Vector3(0, 0.05, 0), flat.call(length, 0.1, depth), "steel_frame")
		for side in [-1.0, 1.0]: builder.box(node, centre + across * side * (depth * 0.5 - 0.06) + Vector3(0, 0.005, 0), flat.call(length + 0.4, 0.01, 0.04), "steel_frame")
		builder.cylinder(node, centre + along * (length * 0.5 + 0.03) + Vector3(0, 1.0, 0), 0.12, 0.03, "metal", Vector3(0, 0, PI / 2) if along_x else Vector3(PI / 2, 0, 0))
	var bays := maxi(1, roundi(length))
	for k in bays + 1:
		var a := -length * 0.5 + length * k / bays
		for side in [-1.0, 1.0]: builder.box(node, centre + along * a + across * side * (depth * 0.5 - 0.015) + Vector3(0, base + (height - base) * 0.5, 0), flat.call(0.03, height - base, 0.03), "steel_olive")
	var fill: float = 0.6 + builder.vary(seed_pos, 30) * 0.3
	for s in 6:
		var y := base + 0.05 + (height - base - 0.1) * s / 5.0
		builder.box(node, centre + Vector3(0, y, 0), flat.call(length, 0.02, depth), "steel_olive")
		if s == 5: continue
		for k in int(length / 0.36):
			if builder.vary(seed_pos + Vector3(k, s, 0), 31) > fill: continue
			builder.box(node, centre + along * (-length * 0.5 + 0.2 + k * 0.36) + Vector3(0, y + 0.135, 0), flat.call(0.33, 0.25, minf(0.39, depth - 0.02)), "cardboard")

## A room.furniture item (spec 9.2) in its holder (at its `at`, turned by
## `turn`, its back at local -Z). The desk and the chairs are procedural
## stand-ins for metal_office_desk and school_chair_01 until their ingest; the
## card index stands in for vintage_wooden_drawer_01.
static func build_item(builder: Node3D, holder: Node3D, item: Dictionary, seed_pos: Vector3) -> void:
	var size := Vector2(float(item.size[0]), float(item.size[1]))
	match String(item.kind):
		"desk":
			desk(builder, holder, Vector3(0, 0, -size.y * 0.5 + 0.375), 1.0, seed_pos)
		"desk_pair":
			desk(builder, holder, Vector3(0, 0, -0.375), 1.0, seed_pos)
			desk(builder, holder, Vector3(0, 0, 0.375), -1.0, seed_pos + Vector3(0.5, 0, 0))
		"partition":
			builder.box(holder, Vector3(0, 0.75, 0), Vector3(size.x, 1.5, 0.05), "partition_fabric", true)
			builder.box(holder, Vector3(0, 1.51, 0), Vector3(size.x, 0.02, 0.06), "steel_frame")
		"meeting_table":
			builder.box(holder, Vector3(0, 0.38, 0), Vector3(size.x, 0.76, size.y), "", true)
			builder.box(holder, Vector3(0, 0.74, 0), Vector3(size.x, 0.04, size.y), "veneer")
			for x in [-size.x * 0.35, size.x * 0.35]: builder.box(holder, Vector3(x, 0.36, 0), Vector3(0.05, 0.72, size.y * 0.8), "veneer")
			var each := 4 + int(builder.vary(seed_pos, 40) * 2)
			for side in [-1.0, 1.0]:
				for k in each:
					var x: float = -size.x * 0.5 + size.x * (k + 0.5) / each
					chair(builder, holder, Vector3(x, 0, side * (size.y * 0.5 + 0.05)), side)
		"pigeonholes":
			builder.box(holder, Vector3(0, 0.95, 0), Vector3(size.x, 1.9, size.y), "", true)
			for c in 7:
				builder.box(holder, Vector3(-size.x * 0.5 + size.x * c / 6.0, 0.95, 0), Vector3(0.015, 1.9, size.y), "laminate")
			for r in 9:
				builder.box(holder, Vector3(0, 0.02 + 1.86 * r / 8.0, 0), Vector3(size.x, 0.015, size.y), "laminate")
		"copier":
			builder.box(holder, Vector3(0, 0.475, 0), Vector3(size.x, 0.95, size.y), "enamel", true)
			builder.box(holder, Vector3(0, 0.96, 0), Vector3(size.x * 0.8, 0.02, size.y * 0.8), "black")
			builder.box(holder, Vector3(size.x * 0.5 + 0.12, 0.6, 0), Vector3(0.24, 0.03, size.y * 0.7), "enamel")
		"vending":
			builder.box(holder, Vector3(0, 0.9, 0), Vector3(size.x, 1.8, size.y), "enamel", true)
			builder.box(holder, Vector3(-0.1, 1.05, size.y * 0.5 + 0.005), Vector3(size.x * 0.6, 1.2, 0.01), "black")
		"card_index":
			builder.box(holder, Vector3(0, 0.6, 0), Vector3(size.x, 1.2, size.y), "wood", true)
			for r in 4:
				for c in 3: builder.box(holder, Vector3(-size.x / 3.0 + c * size.x / 3.0, 0.18 + r * 0.28, size.y * 0.5 + 0.004), Vector3(0.12, 0.03, 0.01), "gold")

## A steel desk (top at 0.74) with its chair pulled up on the side `face`
## looks to (+Z for 1).
static func desk(builder: Node3D, holder: Node3D, at: Vector3, face: float, seed_pos: Vector3) -> void:
	builder.box(holder, at + Vector3(0, 0.38, 0), Vector3(1.5, 0.76, 0.75), "", true)
	builder.box(holder, at + Vector3(0, 0.74, 0), Vector3(1.5, 0.03, 0.75), "laminate")
	builder.box(holder, at + Vector3(0.5, 0.36, 0), Vector3(0.42, 0.72, 0.7), "steel_olive")
	builder.box(holder, at + Vector3(-0.72, 0.36, 0), Vector3(0.04, 0.72, 0.7), "steel_olive")
	if builder.vary(seed_pos, 41) < 0.5: builder.box(holder, at + Vector3(-0.3, 0.77, 0), Vector3(0.21, 0.02, 0.3), "linen")
	chair(builder, holder, at + Vector3(0, 0, face * 0.55), -face)

## A stacking chair facing `face` (+Z for 1): seat 0.45 high, back behind.
static func chair(builder: Node3D, holder: Node3D, at: Vector3, face: float) -> void:
	builder.box(holder, at + Vector3(0, 0.23, 0), Vector3(0.44, 0.46, 0.42), "", true)
	builder.box(holder, at + Vector3(0, 0.45, 0), Vector3(0.44, 0.03, 0.42), "steel_olive")
	builder.box(holder, at + Vector3(0, 0.7, -face * 0.2), Vector3(0.42, 0.4, 0.03), "steel_olive")
	for x in [-0.19, 0.19]:
		for z in [-0.17, 0.17]: builder.box(holder, at + Vector3(x, 0.22, z), Vector3(0.025, 0.44, 0.025), "steel_frame")
