extends RefCounted
## The offices' corner pieces (room.props at room.sockets; spec_f1_geometry.md
## 9.3), built from boxes and cylinders so they batch with their room. Each
## stands in the hotel desk's footprint (2.3 × 1.4 round the socket), its back
## at local -Z, under FURNITURE_TOP, its big parts with a box collider. The
## corner kinds that want an ingested model (desk, filing, chairs, armchair,
## copier, reader, sorter, vending) are not built yet; the hotel's own kinds
## (plant, bin, basin, cart) go to prop_factory. The free-standing furniture
## (room.furniture, build_item()) is the pieces made in code (pieces/).
const BACK := -0.7
const HOTEL_KINDS := ["plant", "bin", "basin", "cart"]
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
## The pieces made in code (area 4a) that build_item() places.
const DESKS := preload("res://game/world/office/pieces/desks.gd")
const CABINETS := preload("res://game/world/office/pieces/cabinets.gd")
const STORAGE := preload("res://game/world/office/pieces/storage.gd")
const MACHINES := preload("res://game/world/office/pieces/machines.gd")
const MOVABLES := preload("res://game/world/office/pieces/movables.gd")
const FIXTURES := preload("res://game/world/office/pieces/fixtures.gd")
const KIT := preload("res://game/world/office/pieces/kit.gd")

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

## A tramo of a row, by metres of row: its piece's sample.
const ROW_TRAMO := 2.0
const ROW_TRAMO_MOBILE := 3.0
## A row cut this thin by a cell's edge (the naves) takes no piece: its boxes
## would not fit.
const ROW_THIN := 0.2
## The number's letters, on a plate of 16 by 10 cm.
const ROW_FONT := 44

## An archive row (spec 9.4, spec_rediseno 6.4), room-local: tramos of grey steel
## shelving, or of a mobile unit on its two floor rails, along x (`along_x`) or z,
## filling `length`, each with its own contents, under the one collider of the
## row. Each piece's end, with its plate and hand wheel, looks along `to_spine`
## (1 or -1 along the row): the row's other end meets the long wall. `number`
## goes on the last tramo's plate, the one at the spine (0: none).
static func row(builder: Node3D, node: Node3D, centre: Vector3, length: float, depth: float, height: float, along_x: bool, mobile: bool, seed_pos: Vector3, to_spine := 1.0, number := 0) -> void:
	var size := Vector3(length, height, depth) if along_x else Vector3(depth, height, length)
	builder.box(node, centre + Vector3(0, height * 0.5, 0), size, "", true)
	var along := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var across := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	if mobile:
		var rail: Vector3 = Vector3(length + 0.4, 0.01, 0.04) if along_x else Vector3(0.04, 0.01, length + 0.4)
		for side: float in [-1.0, 1.0]: builder.box(node, centre + across * side * (depth * 0.5 - 0.06) + Vector3(0, 0.005, 0), rail, "steel_frame")
	if depth < ROW_THIN:
		KIT.material(builder, "steel_grey")
		builder.box(node, centre + Vector3(0, height * 0.5, 0), size, "steel_grey")
		return
	var each: float = ROW_TRAMO_MOBILE if mobile else ROW_TRAMO
	var tramos: int = maxi(1, roundi(length / each))
	var wide: float = length / tramos
	var end: Vector3 = along * to_spine
	var turn := Basis(Vector3.UP, atan2(-end.z, end.x))
	var part := Vector3(wide, height, depth)
	for k in tramos:
		var variant: int = int(builder.vary(seed_pos + along * float(k), 30) * 3.0)
		var mesh: ArrayMesh = STORAGE.mobile_archive(builder, part, variant) if mobile else STORAGE.archive_shelving(builder, part, variant)
		var xform := Transform3D(turn, centre + end * (-length * 0.5 + wide * (float(k) + 0.5)))
		builder.place(node, mesh, xform)
		if k == tramos - 1 and number > 0: plate_text(node, mesh, xform, str(number), ROW_FONT)

## A room.furniture item (spec 9.2, spec_rediseno 5.2) in its holder (at its
## `at`, turned by `turn`, its back at local -Z): the pieces made in code
## (pieces/, area 4a), each with its collider, and the stand-in desk and
## chairs until their models (area 4c). `room` gives the filing cabinets'
## finish (palette.FILING_FINISH).
static func build_item(builder: Node3D, holder: Node3D, item: Dictionary, seed_pos: Vector3, room := {}) -> void:
	var size := Vector2(float(item.size[0]), float(item.size[1]))
	# The contents of the shelving and the bookcases: one variant per item (4a, 0 to 2).
	var variant: int = int(builder.vary(seed_pos, 50) * 3.0)
	match String(item.kind):
		"desk":
			station(builder, holder, Vector3(0, 0, -size.y * 0.5 + 0.375), 1.0, seed_pos, room)
		"desk_pair":
			# Back to back, each chair out on its own side (the pair's 2.6 m).
			station(builder, holder, Vector3(0, 0, -0.375), -1.0, seed_pos, room)
			station(builder, holder, Vector3(0, 0, 0.375), 1.0, seed_pos + Vector3(0.5, 0, 0), room)
		"partition":
			piece(builder, holder, MOVABLES.partition_screen(builder, Vector3(size.x, 1.5, 0.06)), Vector3.ZERO)
		"meeting_table":
			piece(builder, holder, DESKS.meeting_table(builder, Vector3(size.x, 0.75, size.y)), Vector3.ZERO)
			var each := 4 + int(builder.vary(seed_pos, 40) * 2)
			for side in [-1.0, 1.0]:
				for k in each:
					var x: float = -size.x * 0.5 + size.x * (k + 0.5) / each
					chair(builder, holder, Vector3(x, 0, side * (size.y * 0.5 + 0.05)), side)
		"pigeonholes":
			piece(builder, holder, CABINETS.pigeonholes(builder, Vector3(size.x, 1.9, size.y), variant), Vector3.ZERO)
		"copier":
			piece(builder, holder, MACHINES.copier(builder, Vector3(1.1, 1.05, 0.7)), Vector3.ZERO)
		"vending":
			builder.box(holder, Vector3(0, 0.9, 0), Vector3(size.x, 1.8, size.y), "enamel", true)
			builder.box(holder, Vector3(-0.1, 1.05, size.y * 0.5 + 0.005), Vector3(size.x * 0.6, 1.2, 0.01), "black")
		"card_index":
			piece(builder, holder, CABINETS.card_index(builder, Vector3(size.x, 1.2, size.y)), Vector3.ZERO)
		"office_desk":
			# The walnut desk faces the room: its drawers to the chair behind it,
			# two chairs before it (spec_rediseno 6.6).
			chair(builder, holder, Vector3(0, 0, -0.72), 1.0)
			piece(builder, holder, DESKS.desk_walnut(builder, Vector3(1.6, 0.75, 0.8)), Vector3.ZERO, true)
			for x in [-0.45, 0.45]: chair(builder, holder, Vector3(x, 0, 0.75), -1.0)
		"exec_desk":
			chair(builder, holder, Vector3(0, 0, -0.8), 1.0)
			piece(builder, holder, DESKS.desk_walnut(builder, Vector3(2.0, 0.76, 0.9)), Vector3.ZERO, true)
			for x in [-0.5, 0.5]: chair(builder, holder, Vector3(x, 0, 0.85), -1.0)
		"secretary_desk":
			piece(builder, holder, DESKS.desk_l_walnut(builder, Vector3(1.8, 0.75, 1.5)), Vector3(0, 0, -0.35))
			chair(builder, holder, Vector3(0, 0, 0.75), -1.0)
		"work_desk":
			piece(builder, holder, DESKS.desk_steel(builder, Vector3(1.5, 0.75, 0.75)), Vector3(0, 0, -0.325))
			chair(builder, holder, Vector3(0, 0, 0.3), -1.0)
		"reception_counter":
			chair(builder, holder, Vector3(0, 0, -0.75), 1.0)
			piece(builder, holder, DESKS.reception_counter(builder, Vector3(2.4, 1.1, 1.5)), Vector3(0, 0, 0.35))
		"waiting_row":
			# The chairs its length takes and the low table at its end (spec_rediseno 6.1, 6.8).
			var seats: int = 3 if size.x >= 2.5 else 2
			for k in seats: chair(builder, holder, Vector3(-size.x * 0.5 + 0.22 + 0.65 * k, 0, 0), 1.0)
			piece(builder, holder, DESKS.low_table(builder, Vector3(0.6, 0.42, 0.5), "laminate_light"), Vector3(size.x * 0.5 - 0.33, 0, 0))
		"filing":
			var t := int(room.get("type", -1))
			var key: String = OFFICE.FILING_FINISH.get(t, "steel_olive")
			piece(builder, holder, CABINETS.filing_cabinet(builder, Vector3(0.47, 1.32, 0.62), 4, key), Vector3.ZERO)
		"bookcase":
			piece(builder, holder, CABINETS.bookcase(builder, Vector3(0.9, 2.0, 0.35), true, variant), Vector3.ZERO)
		"sideboard":
			piece(builder, holder, CABINETS.sideboard(builder, Vector3(1.8, 0.8, 0.48)), Vector3.ZERO)
		"wood_shelving":
			piece(builder, holder, STORAGE.wood_shelving(builder, Vector3(1.2, 1.8, 0.4), variant), Vector3.ZERO)
		"shelving":
			piece(builder, holder, STORAGE.archive_shelving(builder, Vector3(2.0, 2.1, 0.4), variant), Vector3.ZERO)
		"cart_boxes":
			piece(builder, holder, MOVABLES.cart(builder, Vector3(0.8, 1.0, 0.5), true), Vector3.ZERO)
		"mail_cart":
			var sack: ArrayMesh = MOVABLES.mail_cart(builder, Vector3(0.9, 0.9, 0.6))
			piece(builder, holder, sack, Vector3.ZERO)
			plate_text(holder, sack, Transform3D.IDENTITY, "CORREO", 60, PLATE_DARK)
		"pigeon_counter":
			piece(builder, holder, CABINETS.pigeon_counter(builder, Vector3(2.4, 1.1, 0.8), variant), Vector3.ZERO)
		"sorting_table":
			piece(builder, holder, DESKS.sorting_table(builder, Vector3(2.0, 1.02, 0.9)), Vector3.ZERO)
		"reader_table":
			piece(builder, holder, DESKS.consult_table(builder, Vector3(1.4, 0.74, 0.7)), Vector3(0, 0, -0.35))
			chair(builder, holder, Vector3(0, 0, 0.3), -1.0)
		"work_table":
			piece(builder, holder, DESKS.dining_table(builder, Vector3(2.0, 0.74, 1.0)), Vector3.ZERO)
		"dining_set":
			piece(builder, holder, DESKS.dining_table(builder, Vector3(1.2, 0.74, 0.8)), Vector3.ZERO)
			for x in [-0.3, 0.3]:
				chair(builder, holder, Vector3(x, 0, -0.65), 1.0)
				chair(builder, holder, Vector3(x, 0, 0.65), -1.0)
		"kitchen":
			# The sink unit and a base unit side by side, the wall unit over the
			# sink (its top at 2.15, under FURNITURE_TOP).
			piece(builder, holder, STORAGE.kitchen_base(builder, Vector3(1.8, 1.2, 0.6), true), Vector3(-0.6, 0, 0))
			piece(builder, holder, STORAGE.kitchen_base(builder, Vector3(1.2, 0.9, 0.6), false), Vector3(0.9, 0, 0))
			piece(builder, holder, STORAGE.kitchen_wall(builder, Vector3(1.8, 0.7, 0.35)), Vector3(-0.6, 1.45, -0.125))
		"cubicles":
			piece(builder, holder, FIXTURES.toilet_cubicles(builder, Vector3(2.7, 2.0, 1.5), 3), Vector3.ZERO)
		"printer_cart":
			piece(builder, holder, MOVABLES.cart(builder, Vector3(0.8, 0.9, 0.5), false), Vector3.ZERO)
			builder.place(holder, MACHINES.dot_matrix_printer(builder, Vector3(0.6, 0.25, 0.42)), Transform3D(Basis.IDENTITY, Vector3(0, 0.71, 0)))
		"whiteboard":
			piece(builder, holder, MOVABLES.whiteboard_mobile(builder, Vector3(1.5, 1.9, 0.6)), Vector3.ZERO)
		"bench_slat":
			piece(builder, holder, MOVABLES.slat_bench(builder, Vector3(1.5, 0.45, 0.4)), Vector3.ZERO)
		"bin_floor":
			builder.box(holder, Vector3(0, 0.31, 0), Vector3(0.4, 0.62, 0.4), "", true)
			fitted(builder, holder, String(BIN_MODELS[int(builder.vary(seed_pos, 45) * 2.0)]), 0.42, 0.62, builder.vary(seed_pos, 46) * TAU)
		"plant_floor":
			builder.box(holder, Vector3(0, 0.27, 0), Vector3(0.45, 0.54, 0.45), "", true)
			fitted(builder, holder, String(PLANT_MODELS[int(builder.vary(seed_pos, 47) * 2.0)]), 0.55, 1.3, builder.vary(seed_pos, 48) * TAU)
		"air_desk":
			piece(builder, holder, DESKS.desk_steel(builder, Vector3(1.5, 0.75, 0.75)), Vector3(0, 0, -0.325))
			# A stool at it (spec_rediseno 6.14): no piece of its own.
			builder.box(holder, Vector3(0, 0.31, 0.3), Vector3(0.36, 0.62, 0.36), "", true)
			builder.cylinder(holder, Vector3(0, 0.6, 0.3), 0.17, 0.04, "black")
			for k in 3: builder.cylinder(holder, Vector3(0.12 * cos(TAU * k / 3.0), 0.29, 0.3 + 0.12 * sin(TAU * k / 3.0)), 0.012, 0.58, "metal")

## The hotel's bins and potted plants, for the corridors and the lobbies.
const BIN_MODELS := ["res://assets/props/hotel/metal_trash_can_clean.res", "res://assets/props/hotel/metal_trash_can_rust.res"]
const PLANT_MODELS := ["res://assets/props/hotel/potted_plant_02.res", "res://assets/props/hotel/potted_plant_04.res"]

## A model scaled to fit `wide` by `tall`, centred on the holder and on its
## floor, turned by `yaw`.
static func fitted(builder: Node3D, holder: Node3D, path: String, wide: float, tall: float, yaw: float) -> void:
	var mesh: Mesh = load(path)
	var bounds := mesh.get_aabb()
	var fit: float = minf(tall / bounds.size.y, wide / maxf(bounds.size.x, bounds.size.z))
	var spin := Basis(Vector3.UP, yaw)
	var foot: Vector3 = spin * Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * fit
	builder.place(holder, mesh, Transform3D(spin.scaled(Vector3.ONE * fit), foot))

## A desk of an open office's lattice (spec_rediseno 6.16: stations L-shaped and
## straight): one in three the L in laminate, in the same half of the footprint,
## its main run where the straight desk's top is, its return on the sitter's
## side and its chair clear of the return. Elsewhere, desk().
const DESK_L := Vector3(1.5, 0.76, 1.3)
static func station(builder: Node3D, holder: Node3D, at: Vector3, face: float, seed_pos: Vector3, room: Dictionary) -> void:
	var t := int(room.get("type", -1))
	if t != OFFICE.OPEN_OFFICE or builder.vary(seed_pos, 44) >= 1.0 / 3.0:
		desk(builder, holder, at, face, seed_pos)
		return
	piece(builder, holder, DESKS.desk_l(builder, DESK_L), at + Vector3(0, 0, face * 0.275), face < 0.0)
	chair(builder, holder, at + Vector3(-face * 0.1, 0, face * 0.55), -face)

## A piece made in code (pieces/, area 4a) at `at` in the holder, its front to
## +Z or, with `back`, to -Z: its colliders as solid boxes (the mesh's
## "colliders" when it has them, else its "collider"; none where it says
## "solid" false), and its "light_strip" as a glow_ box of its own, which goes
## out with its room (lenses_of()) as a placed mesh would not. place() draws
## the piece, with the room's other copies, in one MultiMesh.
static func piece(builder: Node3D, holder: Node3D, mesh: ArrayMesh, at: Vector3, back := false) -> void:
	var turn: Basis = Basis(Vector3.UP, PI) if back else Basis.IDENTITY
	builder.place(holder, mesh, Transform3D(turn, at))
	if mesh.get_meta("solid", true):
		var boxes: Array = mesh.get_meta("colliders", [mesh.get_meta("collider")])
		for box: AABB in boxes:
			builder.box(holder, at + turn * box.get_center(), box.size, "", true)
	if mesh.has_meta("light_strip"):
		var strip: Array = mesh.get_meta("light_strip")
		var middle: Vector3 = strip[0]
		var measure: Vector3 = strip[1]
		KIT.material(builder, "glow_strip")
		builder.box(holder, at + turn * middle, measure, "glow_strip")

## The letters on a piece's "text_plate" (pieces/), which already stands 1 mm
## off its plate: a Label3D under `parent`, where `at` puts the piece, lit like
## everything else and not drawn past PLATE_REACH.
const PLATE_PIXEL := 0.0015
const PLATE_REACH := 20.0
const PLATE_LIGHT := Color("e8e4d6")
const PLATE_DARK := Color(0.07, 0.06, 0.05)
static func plate_text(parent: Node3D, mesh: Mesh, at: Transform3D, words: String, font: int, ink := PLATE_LIGHT) -> void:
	var spot: Array = mesh.get_meta("text_plate")
	var centre: Vector3 = spot[0]
	var facing: Vector3 = spot[2]
	facing = at.basis * facing
	var label := Label3D.new()
	label.text = words
	label.font_size = font
	label.pixel_size = PLATE_PIXEL
	label.modulate = ink
	label.outline_size = 0
	label.shaded = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.visibility_range_end = PLATE_REACH
	label.position = at * centre
	# A label reads from its +Z.
	label.rotation.y = atan2(facing.x, facing.z)
	parent.add_child(label)

## The desk's model (tools/props/build_catalogue.gd) and its scale to the
## generator's desk; loaded once.
const DESK_MODEL := "res://assets/props/hotel/metal_office_desk.res"
const DESK_FIT := Vector3(0.75, 0.96, 0.79)
static var desk_mesh: Mesh = null
## The chair's model, likewise.
const CHAIR_MODEL := "res://assets/props/hotel/SchoolChair_01.res"
const CHAIR_FIT := 0.8
static var chair_mesh: Mesh = null

## A steel desk (top at 0.74) with its chair pulled up on the side `face`
## looks to (+Z for 1).
static func desk(builder: Node3D, holder: Node3D, at: Vector3, face: float, seed_pos: Vector3) -> void:
	builder.box(holder, at + Vector3(0, 0.38, 0), Vector3(1.5, 0.76, 0.75), "", true)
	if desk_mesh == null and ResourceLoader.exists(DESK_MODEL): desk_mesh = load(DESK_MODEL)
	if desk_mesh != null:
		# Poly Haven's metal desk (2.00 x 0.79 x 0.95) brought to the
		# generator's 1.5 x 0.76 x 0.75 footprint, its front to the chair.
		builder.place(holder, desk_mesh, Transform3D(Basis(Vector3.UP, 0.0 if face > 0.0 else PI).scaled(DESK_FIT), at))
	else:
		builder.box(holder, at + Vector3(0, 0.74, 0), Vector3(1.5, 0.03, 0.75), "laminate")
		builder.box(holder, at + Vector3(0.5, 0.36, 0), Vector3(0.42, 0.72, 0.7), "steel_olive")
		builder.box(holder, at + Vector3(-0.72, 0.36, 0), Vector3(0.04, 0.72, 0.7), "steel_olive")
	if builder.vary(seed_pos, 41) < 0.5: builder.box(holder, at + Vector3(-0.3, 0.77, 0), Vector3(0.21, 0.02, 0.3), "linen")
	chair(builder, holder, at + Vector3(0, 0, face * 0.55), -face)

## A stacking chair facing `face` (+Z for 1): seat 0.45 high, back behind.
static func chair(builder: Node3D, holder: Node3D, at: Vector3, face: float) -> void:
	builder.box(holder, at + Vector3(0, 0.23, 0), Vector3(0.44, 0.46, 0.42), "", true)
	if chair_mesh == null and ResourceLoader.exists(CHAIR_MODEL): chair_mesh = load(CHAIR_MODEL)
	if chair_mesh != null:
		# Poly Haven's stacking chair, 1.01 m tall as downloaded: at 0.8, a
		# real one's height.
		builder.place(holder, chair_mesh, Transform3D(Basis(Vector3.UP, 0.0 if face > 0.0 else PI).scaled(Vector3.ONE * CHAIR_FIT), at))
		return
	builder.box(holder, at + Vector3(0, 0.45, 0), Vector3(0.44, 0.03, 0.42), "steel_olive")
	builder.box(holder, at + Vector3(0, 0.7, -face * 0.2), Vector3(0.42, 0.4, 0.03), "steel_olive")
	for x in [-0.19, 0.19]:
		for z in [-0.17, 0.17]: builder.box(holder, at + Vector3(x, 0.22, z), Vector3(0.025, 0.44, 0.025), "steel_frame")
