extends RefCounted
## The offices' corner pieces (room.props at room.sockets; spec_f1_geometry.md
## 9.3) and their free-standing furniture (room.furniture, build_item(),
## spec_rediseno 5.2). A corner piece stands in its footprint
## (palette.CORNER_SIZES) round the socket, its back at local -Z, under
## FURNITURE_TOP, its big parts with a box collider; the hotel's own kinds (bin,
## cart) go to prop_factory. The furniture is the pieces made in code (pieces/,
## areas 4a and 4c); what is a download or its stand-in (chairs, plants, lamps,
## machines) comes from office_models.gd (area 4c).
const BACK := -0.7
## A basin and its mirror against the washroom's wall (spec_rediseno 6.11):
## the socket stands SOCKET_INSET (1.3) off the wall's centre line and the
## tiles' face 0.1 off it (office_fittings.gd).
const BASIN_Z := -0.973
const MIRROR_Z := -1.183
const HOTEL_KINDS := ["bin", "cart"]
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
## The pieces made in code (area 4a) that build_item() places.
const DESKS := preload("res://game/world/office/pieces/desks.gd")
const CABINETS := preload("res://game/world/office/pieces/cabinets.gd")
const STORAGE := preload("res://game/world/office/pieces/storage.gd")
const MACHINES := preload("res://game/world/office/pieces/machines.gd")
const MOVABLES := preload("res://game/world/office/pieces/movables.gd")
const FIXTURES := preload("res://game/world/office/pieces/fixtures.gd")
const ROOM_EQUIPMENT := preload("res://game/world/office/pieces/room_equipment.gd")
const KIT := preload("res://game/world/office/pieces/kit.gd")
const WALL := preload("res://game/world/office/pieces/wall.gd")
const STATIONERY := preload("res://game/world/office/pieces/stationery.gd")
const STAND := preload("res://game/world/office/pieces/stand_ins.gd")
## The downloads and their stand-ins (area 4c).
const MODELS := preload("res://game/world/office/office_models.gd")
## How each chair was left (area 4c, tramo B).
const CLUTTER := preload("res://game/world/office/office_clutter.gd")

## Builds an office corner piece; false for a kind it leaves to prop_factory.
static func build(builder: Node3D, node: Node3D, kind: String) -> bool:
	if kind in HOTEL_KINDS: return false
	var seed_pos: Vector3 = node.position + Vector3(0, float(kind.length()), 0)
	match kind:
		"reception":
			# The counter when the recipe's did not fit, its light going out with the room.
			piece(builder, node, DESKS.reception_counter(builder, Vector3(2.2, 1.1, 1.1)), at(0.0, 1.1))
		"shelf":
			# Steel with boxes where things are kept (spec_rediseno 6.13, 6.18); oak elsewhere (6.5).
			var t := int(builder.building_room.get("type", -1))
			var pick: int = int(builder.vary(seed_pos, 6) * 3.0)
			if t == OFFICE.STORE or t == OFFICE.DEPOT or t == OFFICE.ELECTRICAL or t == OFFICE.SECURITY:
				piece(builder, node, STORAGE.archive_shelving(builder, Vector3(2.0, 2.1, 0.4), pick), at(0.0, 0.4))
			else:
				piece(builder, node, STORAGE.wood_shelving(builder, Vector3(1.6, 2.0, 0.4), pick), at(0.0, 0.4))
		"coat_rack":
			# An office's and the director's: a bentwood coat stand in the middle of the corner.
			var t := int(builder.building_room.get("type", -1))
			if (t == OFFICE.OFFICE or t == OFFICE.EXEC_OFFICE) and MODELS.mesh_of(builder, "coat_stand") != null:
				solid(builder, node, Vector3(0.42, 1.8, 0.4))
				MODELS.put(builder, node, "coat_stand", Transform3D(Basis(Vector3.UP, builder.vary(seed_pos, 2) * TAU), at(0.0, 0.4)))
				return true
			# A rail of hooks on two posts: this corner turns any way (not in
			# WALL_KINDS), so it cannot hang on a wall.
			solid(builder, node, Vector3(1.2, 1.75, 0.4))
			for x: float in [-0.585, 0.585]:
				builder.box(node, at(0.875, 0.4) + Vector3(x, 0, 0), Vector3(0.03, 1.75, 0.03), "steel_olive")
				builder.box(node, at(0.015, 0.4) + Vector3(x, 0, 0), Vector3(0.05, 0.03, 0.4), "steel_olive")
			builder.place(node, WALL.coat_hook_rail(builder, Vector3(1.2, 0.12, 0.09)), Transform3D(Basis.IDENTITY, at(1.6, 0.4)))
			if builder.vary(seed_pos, 1) < 0.34: builder.place(node, STAND.coat_hanging(builder, Vector3(0.5, 0.95, 0.14)), Transform3D(Basis.IDENTITY, at(0.75, 0.4) + Vector3(-0.25, 0, 0.1)))
		"bench":
			piece(builder, node, MOVABLES.slat_bench(builder, Vector3(1.5, 0.45, 0.4)), at(0.0, 0.4))
		"sideboard":
			piece(builder, node, CABINETS.sideboard(builder, Vector3(1.8, 0.8, 0.48)), at(0.0, 0.48))
			# The director's globe on it (spec_rediseno 6.7).
			var t := int(builder.building_room.get("type", -1))
			if t == OFFICE.EXEC_OFFICE: MODELS.put(builder, node, "globe", Transform3D(Basis(Vector3.UP, 0.4), at(0.8, 0.48) + Vector3(0.55, 0, 0)))
		"table":
			# Its top at 0.84, where the papers are left (document_placement.SURFACES).
			piece(builder, node, DESKS.dining_table(builder, Vector3(1.6, 0.84, 0.9)), at(0.0, 0.9))
		"board":
			piece(builder, node, MOVABLES.whiteboard_mobile(builder, Vector3(1.5, 1.9, 0.6)), at(0.0, 0.6))
		"projector":
			# On a two-shelf cart, as the printer of the secretary's (its top shelf at 0.71).
			piece(builder, node, MOVABLES.cart(builder, Vector3(0.8, 0.9, 0.5), false), at(0.0, 0.5))
			builder.place(node, MACHINES.overhead_projector(builder, Vector3(0.4, 0.8, 0.45)), Transform3D(Basis.IDENTITY, at(0.71, 0.5)))
		"cooler":
			solid(builder, node, Vector3(0.34, 1.45, 0.34))
			MODELS.put(builder, node, "cooler", Transform3D(Basis.IDENTITY, at(0.0, 0.34)))
		"fridge":
			solid(builder, node, Vector3(0.6, 1.6, 0.65))
			# Laid by its own depth (the old fridge is 0.72 deep), so its back meets the wall.
			MODELS.put(builder, node, "fridge", Transform3D(Basis.IDENTITY, at(0.0, MODELS.size_of(builder, "fridge").z)))
		"desk":
			# A steel typing table and its chair: the papers are left on it at 0.84
			# (document_placement.SURFACES).
			piece(builder, node, DESKS.desk_steel(builder, Vector3(1.5, 0.84, 0.9)), at(0.0, 0.9))
			chair(builder, node, at(0.0, 0.9) + Vector3(0, 0, 0.73), -1.0, "office_chair")
		"filing":
			var t := int(builder.building_room.get("type", -1))
			var key: String = OFFICE.FILING_FINISH.get(t, "steel_olive")
			for x: float in [-0.26, 0.26]: filing(builder, node, at(0.0, 0.62) + Vector3(x, 0, 0), key)
		"chairs":
			var t := int(builder.building_room.get("type", -1))
			var seat: String = OFFICE.WAITING_CHAIR.get(t, "stacking_chair")
			for x: float in [-0.65, 0.0, 0.65]: chair(builder, node, at(0.0, 0.6) + Vector3(x, 0, 0), 1.0, seat)
		"armchair":
			lounge(builder, node, seed_pos, int(builder.building_room.get("id", -1)))
		"reader":
			piece(builder, node, DESKS.consult_table(builder, Vector3(1.4, 0.74, 0.7)), at(0.0, 0.7))
			microfiche(builder, node, at(0.74, 0.7) + Vector3(0, 0, -0.1))
			chair(builder, node, at(0.0, 0.7) + Vector3(0, 0, 0.7), -1.0, "office_chair")
		"sorter":
			piece(builder, node, CABINETS.pigeonholes(builder, Vector3(1.8, 1.9, 0.4)), at(0.0, 0.4))
		"copier":
			# The copy room's copier when the recipe's own did not fit (4b).
			piece(builder, node, MACHINES.copier(builder, Vector3(1.1, 1.05, 0.7)), at(0.0, 0.7))
		"basin":
			# Against the washroom's tiled panel, its mirror over it (6.11).
			piece(builder, node, FIXTURES.basin(builder, Vector3(0.55, 0.92, 0.45)), Vector3(0, 0, BASIN_Z))
			builder.place(node, WALL.mirror(builder, Vector3(0.6, 0.8, 0.03)), Transform3D(Basis.IDENTITY, Vector3(0, 1.1, MIRROR_Z)))
		"vending":
			vending(builder, node, at(0.0, 0.8), int(builder.building_room.get("id", -1)))
		"plant":
			# Centred on its socket, as the hotel's was (its CORNER_SIZES row).
			builder.box(node, Vector3(0, 0.27, 0), Vector3(0.55, 0.54, 0.55), "", true)
			var t := int(builder.building_room.get("type", -1))
			var kind_of: String = "plant" if builder.vary(seed_pos, 5) < 0.5 else "plant_bare"
			# The secretary's tall plant (6.7).
			if t == OFFICE.SECRETARY: kind_of = "plant_tall"
			MODELS.put(builder, node, kind_of, Transform3D(Basis(Vector3.UP, builder.vary(seed_pos, 3) * TAU), Vector3.ZERO), int(builder.vary(seed_pos, 4) * 3.0))
		"cabinet":
			# Two tall steel cabinets of drawers, side by side.
			for x: float in [-0.25, 0.25]: piece(builder, node, CABINETS.filing_cabinet(builder, Vector3(0.49, 1.96, 0.5), 6, "steel_olive"), at(0.0, 0.5) + Vector3(x, 0, 0))
		"gun_rack":
			piece(builder, node, STORAGE.gun_rack(builder, Vector3(1.0, 1.9, 0.45)), at(0.0, 0.45))
		"boxes":
			solid(builder, node, Vector3(1.0, 1.2, 0.45))
			for column in 3:
				var tall: int = 2 + int(builder.vary(seed_pos, 10 + column) * 3)
				for k in tall: MODELS.put(builder, node, "archive_box", Transform3D(Basis.IDENTITY, at(k * 0.25, 0.39) + Vector3(-0.34 + column * 0.34, 0, 0)))
			var t := int(builder.building_room.get("type", -1))
			if t == OFFICE.STORE or t == OFFICE.DEPOT:
				# A step ladder and a work light left by the boxes (6.18).
				builder.box(node, at(0.7, 0.6) + Vector3(0.85, 0, 0), Vector3(0.5, 1.4, 0.6), "", true)
				MODELS.put(builder, node, "step_ladder", Transform3D(Basis.IDENTITY, at(0.0, 0.6) + Vector3(0.85, 0, 0)))
				builder.box(node, at(0.75, 0.4) + Vector3(-0.8, 0, 0), Vector3(0.4, 1.5, 0.4), "", true)
				MODELS.put(builder, node, "work_light", Transform3D(Basis(Vector3.UP, 0.5), at(0.0, 0.4) + Vector3(-0.8, 0, 0)))
	return true

## The director's corner (spec_rediseno 6.7, spec_4e D), in a corner socket
## (build(), "armchair") or as a recipe's piece (build_item(), "lounge"), round
## the holder's origin with its back at BACK: the leather sofa or the lounge
## chair with the low walnut table, and the floor lamp beside it.
static func lounge(builder: Node3D, node: Node3D, seed_pos: Vector3, room_id: int) -> void:
	if builder.vary(seed_pos, 50) < 0.6:
		builder.box(node, at(0.4, 0.85) + Vector3(-0.24, 0, 0), Vector3(1.8, 0.8, 0.85), "", true)
		MODELS.put(builder, node, "sofa", Transform3D(Basis.IDENTITY, at(0.0, 0.85) + Vector3(-0.24, 0, 0)))
		piece(builder, node, DESKS.low_table(builder, Vector3(0.9, 0.42, 0.42)), Vector3(-0.24, 0, 0.49))
	else:
		builder.box(node, at(0.45, 1.2) + Vector3(-0.45, 0, 0), Vector3(1.0, 0.9, 1.2), "", true)
		MODELS.put(builder, node, "lounge_chair", Transform3D(Basis.IDENTITY, at(0.0, 1.2) + Vector3(-0.45, 0, 0)))
		piece(builder, node, DESKS.low_table(builder, Vector3(0.9, 0.42, 0.42)), Vector3(0.6, 0, 0.35))
	MODELS.lamp(builder, node, room_id, "floor_lamp", Transform3D(Basis.IDENTITY, at(0.0, 0.45) + Vector3(0.9, 0, 0)))

## A point at height y, centred on a piece of depth d whose back is at BACK.
static func at(y: float, depth: float) -> Vector3:
	return Vector3(0, y, BACK + depth * 0.5)

## The collider of a piece of `size` standing at the back.
static func solid(builder: Node3D, node: Node3D, size: Vector3) -> void:
	builder.box(node, at(size.y * 0.5, size.z), size, "", true)

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
		builder.place(node, mesh, xform, MODELS.casts(mesh, xform))
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
			# The low screen between them that makes the pair an island (the open
			# offices' references), under the pair's 1.3 m.
			piece(builder, holder, MOVABLES.partition_screen(builder, PAIR_SCREEN), Vector3.ZERO)
		"desk_island", "desk_island_6":
			# Desk pairs side by side (office_generator.lay_islands()), straight desks
			# with their chairs out on both long sides; its screens in a cross are
			# partitions of its group (island_screens()).
			var pairs := island_pairs(item)
			for k in pairs:
				var x := (float(k) - float(pairs - 1) / 2.0) * ISLAND_PITCH
				desk(builder, holder, Vector3(x, 0, -0.375), -1.0)
				desk(builder, holder, Vector3(x, 0, 0.375), 1.0)
		"partition":
			piece(builder, holder, MOVABLES.partition_screen(builder, Vector3(size.x, float(item.extra.height), 0.06)), Vector3.ZERO)
		"pigeonholes":
			piece(builder, holder, CABINETS.pigeonholes(builder, Vector3(size.x, 1.9, size.y), variant), Vector3.ZERO)
		"copier":
			piece(builder, holder, MACHINES.copier(builder, Vector3(1.1, 1.05, 0.7)), Vector3.ZERO)
		"vending":
			vending(builder, holder, Vector3.ZERO, int(room.get("id", -1)))
		"card_index":
			piece(builder, holder, CABINETS.card_index(builder, Vector3(size.x, 1.2, size.y)), Vector3.ZERO)
		"exec_desk":
			chair(builder, holder, Vector3(0, 0, -0.8), 1.0, "exec_chair")
			piece(builder, holder, DESKS.desk_walnut(builder, Vector3(2.0, 0.76, 0.9)), Vector3.ZERO, true)
			for x in [-0.5, 0.5]: chair(builder, holder, Vector3(x, 0, 0.85), -1.0, "visitor_chair")
			MODELS.lamp(builder, holder, int(room.get("id", -1)), "desk_lamp_banker", Transform3D(Basis(Vector3.UP, PI), Vector3(-0.75, 0.76, 0.2)))
		"lounge":
			lounge(builder, holder, seed_pos, int(room.get("id", -1)))
		"secretary_desk":
			# The L as long as the footprint lets it and 0.1 narrower (spec_4e D,
			# spec_4e_b G), its wing always on the right; the chair and the lamp keep
			# their place from its back.
			var back := -size.y * 0.5
			piece(builder, holder, DESKS.desk_l_walnut(builder, Vector3(size.x - 0.1, 0.75, size.y - 0.7)), Vector3(0, 0, -0.35))
			chair(builder, holder, Vector3(0, 0, back + 1.85), -1.0, "office_chair")
			MODELS.lamp(builder, holder, int(room.get("id", -1)), "desk_lamp_banker", Transform3D(Basis.IDENTITY, Vector3(-0.7, 0.75, back + 0.15)))
		"work_desk":
			piece(builder, holder, DESKS.desk_steel(builder, Vector3(1.5, 0.75, 0.75)), Vector3(0, 0, -0.325))
			chair(builder, holder, Vector3(0, 0, 0.3), -1.0)
			MODELS.lamp(builder, holder, int(room.get("id", -1)), "desk_lamp_arm", Transform3D(Basis.IDENTITY, Vector3(-0.55, 0.75, -0.5)))
			# The window's clerk types behind the glass (spec_4e D).
			if int(room.get("type", -1)) == OFFICE.WINDOW: MODELS.put(builder, holder, "typewriter", Transform3D(Basis.IDENTITY, Vector3(0.2, 0.75, -0.4)))
		"waiting_row", "waiting_row_4":
			# The chairs its length takes and the low table at its end (spec_rediseno 6.1, 6.8).
			var seats: int = 4 if size.x >= 3.0 else (3 if size.x >= 2.5 else 2)
			var t := int(room.get("type", -1))
			var seat: String = OFFICE.WAITING_CHAIR.get(t, "stacking_chair")
			for k in seats: chair(builder, holder, Vector3(-size.x * 0.5 + 0.22 + 0.65 * k, 0, 0), 1.0, seat)
			piece(builder, holder, DESKS.low_table(builder, Vector3(0.6, 0.42, 0.5), "laminate_light"), Vector3(size.x * 0.5 - 0.33, 0, 0))
		"filing":
			var t := int(room.get("type", -1))
			var key: String = OFFICE.FILING_FINISH.get(t, "steel_olive")
			filing(builder, holder, Vector3.ZERO, key, CLUTTER.drawer_row(builder, room, seed_pos))
		"bookcase":
			# The walnut bookcase with its books (the download) where it is baked, its box the collider.
			if MODELS.mesh_of(builder, "bookcase_model") != null:
				builder.box(holder, Vector3(0, 0.935, 0), Vector3(0.9, 1.867, 0.35), "", true)
				MODELS.put(builder, holder, "bookcase_model", Transform3D.IDENTITY)
			else:
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
			chair(builder, holder, Vector3(0, 0, 0.3), -1.0, "office_chair")
			microfiche(builder, holder, Vector3(0, 0.74, -0.45))
		"work_table":
			piece(builder, holder, DESKS.dining_table(builder, Vector3(2.4, 0.74, 1.2)), Vector3.ZERO)
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
			# The coffee maker and the old microwave on the base unit (6.10).
			MODELS.put(builder, holder, "coffee_maker", Transform3D(Basis.IDENTITY, Vector3(0.62, 0.9, 0.05)))
			MODELS.put(builder, holder, "microwave", Transform3D(Basis.IDENTITY, Vector3(1.18, 0.9, 0.0)))
		"cubicles":
			piece(builder, holder, FIXTURES.toilet_cubicles(builder, Vector3(2.7, 2.0, 1.5), 3), Vector3.ZERO)
		"printer_cart":
			piece(builder, holder, MOVABLES.cart(builder, Vector3(0.8, 0.9, 0.5), false), Vector3.ZERO)
			MODELS.put(builder, holder, "dot_matrix_printer", Transform3D(Basis.IDENTITY, Vector3(0, 0.71, 0)))
		"tv_cart":
			# The set on the cart's top shelf, as the printer on its own.
			piece(builder, holder, MOVABLES.cart(builder, Vector3(0.8, 0.9, 0.5), false), Vector3.ZERO)
			MODELS.put(builder, holder, "television", Transform3D(Basis.IDENTITY, Vector3(0, 0.71, 0)))
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
		"reception_counter_l":
			chair(builder, holder, Vector3(0, 0, -0.75), 1.0, "office_chair")
			piece(builder, holder, DESKS.reception_counter(builder, Vector3(3.6, 1.1, 1.5)), Vector3(0, 0, 0.35))
			MODELS.lamp(builder, holder, int(room.get("id", -1)), "desk_lamp_arm", Transform3D(Basis(Vector3.UP, PI), Vector3(0.8, 0.74, 0.55)))
		"office_suite":
			# Against the wall the sideboard, then the chair and the walnut desk that
			# faces the room, two chairs before it (spec_proporcion D7).
			piece(builder, holder, CABINETS.sideboard(builder, Vector3(1.8, 0.8, 0.48)), Vector3(0, 0, -1.11))
			chair(builder, holder, Vector3(0, 0, -0.62), 1.0, "exec_chair")
			# The antique walnut desk (the download), its drawers to the sitter; else the piece made in code.
			if MODELS.mesh_of(builder, "desk_walnut_suite") != null:
				builder.box(holder, Vector3(0, 0.375, 0.1), Vector3(1.6, 0.75, 0.8), "", true)
				MODELS.put(builder, holder, "desk_walnut_suite", Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 0.1)))
			else:
				piece(builder, holder, DESKS.desk_walnut(builder, Vector3(1.6, 0.75, 0.8)), Vector3(0, 0, 0.1), true)
			for x in [-0.45, 0.45]: chair(builder, holder, Vector3(x, 0, 0.85), -1.0, "visitor_chair")
			MODELS.lamp(builder, holder, int(room.get("id", -1)), "desk_lamp_banker", Transform3D(Basis(Vector3.UP, PI), Vector3(-0.6, 0.75, 0.25)))
		"meeting_table_s", "meeting_table_m", "meeting_table_l":
			# Its local -Z to the room's middle, which stays free (spec_proporcion D6):
			# chairs along its far side and one at each head, all in its footprint; the
			# near side's are items of their own (office_generator.lay_near_chairs()).
			var top := Vector3(size.x - 1.2, 0.75, 1.2)
			var table_z := -size.y * 0.5 + 0.6
			piece(builder, holder, DESKS.meeting_table(builder, top), Vector3(0, 0, table_z))
			var seats_along := int(top.x / 0.7)
			# Leather armchairs, each facing the table, the heads too (spec_rediseno 6.9).
			for k in seats_along: chair(builder, holder, Vector3(-top.x * 0.5 + top.x * (float(k) + 0.5) / float(seats_along), 0, table_z + 0.86), -1.0, "visitor_chair")
			for head: float in [-1.0, 1.0]: chair(builder, holder, Vector3(head * (top.x * 0.5 + 0.3), 0, table_z), 1.0, "visitor_chair", -head * PI / 2)
		"table_chair":
			# A near-side chair of the boardroom's table (office_generator.lay_near_chairs()),
			# as close to it as the far row, its back to the room's middle.
			chair(builder, holder, Vector3(0, 0, 0.04), 1.0, "visitor_chair")
		"locker_bank":
			# Six grey lockers (the download) where they are baked, its box their collider.
			if MODELS.mesh_of(builder, "lockers") != null:
				builder.box(holder, Vector3(0, 0.95, 0), Vector3(2.7, 1.9, 0.45), "", true)
				MODELS.put(builder, holder, "lockers", Transform3D.IDENTITY)
			else:
				piece(builder, holder, ROOM_EQUIPMENT.locker_bank(builder, Vector3(2.7, 1.9, 0.45)), Vector3.ZERO)
		"fan_unit":
			piece(builder, holder, ROOM_EQUIPMENT.fan_unit(builder, Vector3(1.5, 1.6, 1.2)), Vector3.ZERO)
		"air_desk":
			piece(builder, holder, DESKS.desk_steel(builder, Vector3(1.5, 0.75, 0.75)), Vector3(0, 0, -0.325))
			# A stool at it (spec_rediseno 6.14): no piece of its own.
			builder.box(holder, Vector3(0, 0.31, 0.3), Vector3(0.36, 0.62, 0.36), "", true)
			builder.cylinder(holder, Vector3(0, 0.6, 0.3), 0.17, 0.04, "black")
			for k in 3: builder.cylinder(holder, Vector3(0.12 * cos(TAU * k / 3.0), 0.29, 0.3 + 0.12 * sin(TAU * k / 3.0)), 0.012, 0.58, "metal")

## The hotel's bins and potted plants, for the corridors and the lobbies.
const BIN_MODELS := ["res://assets/props/hotel/metal_trash_can_clean.res", "res://assets/props/hotel/metal_trash_can_rust.res"]
## Not the hotel's potted_plant_02 (some 35 k triangles): a nave lines up
## dozens of them (dens6, 12 November 2026).
const PLANT_MODELS := ["res://assets/props/hotel/potted_plant_04.res", "res://assets/props/office/potted_plant_01.res"]

## A model scaled to fit `wide` by `tall`, centred on the holder and on its
## floor, turned by `yaw`.
static func fitted(builder: Node3D, holder: Node3D, path: String, wide: float, tall: float, yaw: float) -> void:
	var mesh: Mesh = load(path)
	var bounds := mesh.get_aabb()
	var fit: float = minf(tall / bounds.size.y, wide / maxf(bounds.size.x, bounds.size.z))
	var spin := Basis(Vector3.UP, yaw)
	var foot: Vector3 = spin * Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * fit
	# A plant or a bin: no shadow (office_models.casts()).
	builder.place(holder, mesh, Transform3D(spin.scaled(Vector3.ONE * fit), foot), false)

## A desk of an open office's lattice (spec_rediseno 6.16: stations L-shaped and
## straight): one in three the L in laminate, in the same half of the footprint,
## its main run where the straight desk's top is, its return on the sitter's
## side and its chair clear of the return. Elsewhere, desk().
const DESK_L := Vector3(1.5, 0.76, 1.3)
## The screen between a desk pair's two desks (movables.gd's partition_screen at
## 1.2 m), as wide as the pair's footprint.
const PAIR_SCREEN := Vector3(1.5, 1.2, 0.06)
## A desk pair's width along an island.
const ISLAND_PITCH := 1.5

## How many desk pairs an island item holds (palette.FURNITURE: 3 or 4.5 m).
static func island_pairs(item: Dictionary) -> int:
	return maxi(1, roundi(float(item.size[0]) / ISLAND_PITCH))
static func station(builder: Node3D, holder: Node3D, at: Vector3, face: float, seed_pos: Vector3, room: Dictionary) -> void:
	var t := int(room.get("type", -1))
	if t != OFFICE.OPEN_OFFICE or builder.vary(seed_pos, 44) >= 1.0 / 3.0:
		desk(builder, holder, at, face)
		return
	piece(builder, holder, DESKS.desk_l(builder, DESK_L), at + Vector3(0, 0, face * 0.275), face < 0.0)
	chair(builder, holder, at + Vector3(-face * 0.1, 0, face * 0.55), -face, "office_chair")

## A four-drawer filing cabinet at `at` in the holder, in the room's finish:
## the grey download in a grey room once baked, with a box for its collider and,
## at `row` (office_clutter.drawer_row(), -1 for none), a drawer left out; else
## the piece made in code.
static func filing(builder: Node3D, holder: Node3D, at: Vector3, key: String, row := -1) -> void:
	if not MODELS.grey_filing(builder, key):
		piece(builder, holder, CABINETS.filing_cabinet(builder, Vector3(0.47, 1.32, 0.62), 4, key), at)
		return
	builder.box(holder, at + Vector3(0, 0.66, 0), Vector3(0.52, 1.32, 0.62), "", true)
	if row < 0:
		MODELS.put(builder, holder, "filing_grey", Transform3D(Basis.IDENTITY, at))
		return
	MODELS.put(builder, holder, "filing_grey_body", Transform3D(Basis.IDENTITY, at))
	for k in 4: MODELS.put(builder, holder, "filing_grey_drawer", Transform3D(Basis.IDENTITY, at + Vector3(0, MODELS.GREY_PITCH * k, MODELS.GREY_OUT if k == row else 0.0)))

## A piece made in code (pieces/, area 4a) at `at` in the holder, its front to
## +Z or, with `back`, to -Z: its colliders as solid boxes (the mesh's
## "colliders" when it has them, else its "collider"; none where it says
## "solid" false), and its "light_strip" as a glow_ box of its own, which goes
## out with its room (lenses_of()) as a placed mesh would not. place() draws
## the piece, with the room's other copies, in one MultiMesh.
static func piece(builder: Node3D, holder: Node3D, mesh: ArrayMesh, at: Vector3, back := false) -> void:
	var turn: Basis = Basis(Vector3.UP, PI) if back else Basis.IDENTITY
	builder.place(holder, mesh, Transform3D(turn, at), MODELS.casts(mesh, Transform3D(turn, at)))
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
const DESK_MODEL := "res://assets/props/office/retro_oficina_yj_desk.res"
const DESK_FIT := Vector3.ONE
static var desk_mesh: Mesh = null

## A steel desk (top at 0.74) with its chair pulled up on the side `face`
## looks to (+Z for 1).
static func desk(builder: Node3D, holder: Node3D, at: Vector3, face: float) -> void:
	builder.box(holder, at + Vector3(0, 0.38, 0), Vector3(1.5, 0.76, 0.75), "", true)
	if desk_mesh == null and ResourceLoader.exists(DESK_MODEL): desk_mesh = load(DESK_MODEL)
	if desk_mesh != null:
		# YJ_'s green tanker desk, baked at the generator's 1.5 x 0.76 x 0.75
		# footprint (tools/props/fit_models.json), its drawers to the chair.
		builder.place(holder, desk_mesh, Transform3D(Basis(Vector3.UP, 0.0 if face > 0.0 else PI).scaled(DESK_FIT), at))
	else:
		builder.box(holder, at + Vector3(0, 0.74, 0), Vector3(1.5, 0.03, 0.75), "laminate")
		builder.box(holder, at + Vector3(0.5, 0.36, 0), Vector3(0.42, 0.72, 0.7), "steel_olive")
		builder.box(holder, at + Vector3(-0.72, 0.36, 0), Vector3(0.04, 0.72, 0.7), "steel_olive")
	chair(builder, holder, at + Vector3(0, 0, face * 0.55), -face, "office_chair")

## A chair of `kind` (office_models.gd: its model or its stand-in) facing
## `face` (+Z for 1) and turned `yaw` more, the stand-in's seat box its
## collider; noted, as drawn, for the dressing test (builder.dressing_log.chairs).
static func chair(builder: Node3D, holder: Node3D, at: Vector3, face: float, kind := "stacking_chair", yaw := 0.0) -> void:
	builder.box(holder, at + Vector3(0, 0.23, 0), Vector3(0.44, 0.46, 0.42), "", true)
	var pose := CLUTTER.chair_pose(builder, holder, at, face, kind, yaw)
	# Which of the kind's models, by where it stands: the naves' chairs are not all one.
	var parent := holder.get_parent() as Node3D
	var spot: Vector3 = (parent.position if parent != null else Vector3.ZERO) + holder.transform * at
	MODELS.put(builder, holder, kind, pose, int(builder.vary(spot, 476) * 8.0))
	# By room and holder name: drop_empty() frees the emptied holders once the room is batched.
	builder.dressing_log.chairs.append({"room": int(builder.building_room.get("id", -1)), "holder": String(holder.name), "at": pose.origin, "front": pose.basis.z, "kind": kind})

## The break room's vending machine (spec_rediseno 6.10): its stand-in and
## collider, a tube lit at the head of its window while its room is (a glow_
## box, which office_geometry.lenses_of() puts out with the room; a lit pane
## over the whole window hid the trays) and a soft light on the floor before
## it (an accent, office_accents.gd).
static func vending(builder: Node3D, holder: Node3D, at: Vector3, room_id: int) -> void:
	var mesh := MODELS.mesh_of(builder, "vending")
	KIT.material(builder, "glow_white")
	if mesh.has_meta("piece"):
		piece(builder, holder, mesh as ArrayMesh, at)
		builder.box(holder, at + Vector3(-0.125, 1.665, 0.33), Vector3(0.56, 0.012, 0.02), "glow_white")
	else:
		# The download (expendedora_attheseedof): its box the collider, the tube over its window.
		builder.box(holder, at + Vector3(0, 0.9, 0), Vector3(0.9, 1.8, 0.8), "", true)
		MODELS.put(builder, holder, "vending", Transform3D(Basis.IDENTITY, at))
		builder.box(holder, at + Vector3(-0.07, 1.68, 0.36), Vector3(0.5, 0.012, 0.02), "glow_white")
		# The window's back lit behind the trays (dens6: the tube alone left it a
		# dark box; the accent lights the floor before it).
		builder.box(holder, at + Vector3(-0.07, 1.12, -0.2), Vector3(0.56, 1.0, 0.01), "glow_white")
	MODELS.light(builder, holder, room_id, "vending", Transform3D(Basis.IDENTITY, at))

## A microfiche reader (6.5) on its table, its screen lit while its room is.
static func microfiche(builder: Node3D, holder: Node3D, at: Vector3) -> void:
	builder.place(holder, MODELS.mesh_of(builder, "microfiche"), Transform3D(Basis.IDENTITY, at))
	KIT.material(builder, "glow_white")
	builder.box(holder, at + Vector3(0, 0.39, 0.1795), Vector3(0.36, 0.23, 0.001), "glow_white")
