extends RefCounted
## Furniture recipes; keep the central circulation and reserved sockets clear.
## Colliders (material "") keep the validated footprints; the visible detail is
## layered separately and never adds collision. Back of each piece is -Z.

const BOOKS := ["leather", "fabric", "green", "linen", "black", "trim"]
## Supplied models baked by tools/props/build_model_props.gd (front +Z, floor at 0).
const SOFA := preload("res://assets/props/sofa/sofa.res")
const MONSTERA := preload("res://assets/props/monstera/monstera.res")
## Turn that puts the sofa model's back against the socket's back (-Z).
const SOFA_YAW := 0.0

## Poly Haven furniture (room_dressing.gd, assets/props/hotel).
const DRESSING := preload("res://game/world/hotel/room_dressing.gd")
## Service rooms (laundry, storeroom, maintenance, cloakroom): metal shelving
## and carts instead of the guests' wood.
const SERVICE := [7, 8, 9, 16]

## A catalogue model in a socket, batched with the room (hotel_geometry.place()).
static func put(builder: Node3D, node: Node3D, name: String, pos: Vector3, yaw := 0.0, scale := Vector3.ONE) -> void:
	builder.place(node, DRESSING.mesh(name), Transform3D(Basis(Vector3.UP, yaw).scaled(scale), pos))

## A baked model inside a furniture socket; visual only, colliders stay boxes.
static func model(node: Node3D, mesh: Mesh, offset := Vector3.ZERO, yaw := 0.0) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	instance.rotation.y = yaw
	node.add_child(instance)

static func build(builder: Node3D, node: Node3D, kind: String) -> void:
	var seed_pos: Vector3 = node.position + Vector3(0, float(kind.length()), 0)
	match kind:
		"bed":
			builder.box(node, Vector3(0, 0.23, 0), Vector3(1.9, 0.46, 2.6), "", true)
			# The carved bed over the socket (head at -Z), and a nightstand on
			# one side of its head with a clock on it.
			put(builder, node, "GothicBed_01", Vector3(0, 0, 0), 0.0, Vector3(1.9 / 1.49, 1.0, 2.6 / 2.04))
			var side: float = -1.0 if builder.vary(seed_pos, 5) < 0.5 else 1.0
			var stand := Vector3(side * 1.28, 0, -1.02)
			put(builder, node, "ClassicNightstand_01", stand)
			builder.box(node, stand + Vector3(0, 0.35, 0), Vector3(0.57, 0.7, 0.42), "", true)
			put(builder, node, "alarm_clock_01", stand + Vector3(0.1 * side, 0.7, 0.02), builder.vary(seed_pos, 6) * 0.6 - 0.3)
		"sofa":
			builder.box(node, Vector3(0, 0.34, 0), Vector3(2.3, 0.55, 0.9), "", true)
			# The Chesterfield, the floral three-seater or the camelback.
			var which: float = builder.vary(seed_pos, 7)
			if which < 0.4: model(node, SOFA, Vector3(0, 0, 0.02), SOFA_YAW)
			elif which < 0.7: put(builder, node, "sofa_03", Vector3(0, 0, 0.0), 0.0, Vector3.ONE * (2.3 / 2.73))
			else: put(builder, node, "Sofa_01", Vector3(0, 0, 0.1), 0.0, Vector3.ONE * 1.3)
		"nightstand", "phone":
			# The classic nightstand, a fifth larger: its top at 0.84 m, where
			# document_placement.gd lays papers. The collider fits it.
			put(builder, node, "ClassicNightstand_01", Vector3(0, 0, 0), 0.0, Vector3.ONE * 1.2)
			builder.box(node, Vector3(0, 0.42, 0), Vector3(0.68, 0.84, 0.5), "", true)
			if kind == "phone":
				builder.box(node, Vector3(0, 0.89, 0), Vector3(0.3, 0.1, 0.26), "black")
				builder.box(node, Vector3(0, 0.96, 0.04), Vector3(0.26, 0.05, 0.14), "black", false, "box", Vector3(-0.35, 0, 0))
				builder.cylinder(node, Vector3(0, 0.955, 0.07), 0.07, 0.012, "metal", Vector3(-0.35, 0, 0))
				builder.cylinder(node, Vector3(0, 0.98, -0.08), 0.03, 0.34, "black", Vector3(0, 0, PI / 2))
				for side in [-1, 1]: builder.box(node, Vector3(side * 0.16, 0.96, -0.08), Vector3(0.08, 0.05, 0.09), "black")
			else:
				put(builder, node, "alarm_clock_01", Vector3(0.22, 0.84, -0.12), builder.vary(seed_pos, 8) * 0.6 - 0.3)
		"table", "desk":
			var width := 2.2
			builder.box(node, Vector3(0, 0.77, 0), Vector3(width, 0.12, 1.1), "", true)
			builder.box(node, Vector3(0, 0.8, 0), Vector3(width, 0.05, 1.1), "wood")
			builder.box(node, Vector3(0, 0.745, 0), Vector3(width - 0.08, 0.06, 1.02), "trim")
			for side in [-1, 1]: builder.box(node, Vector3(side * (width / 2 - 0.08), 0.36, 0), Vector3(0.1, 0.72, 0.95), "" if kind == "table" else "wood", true)
			if kind == "table":
				for side in [-1, 1]:
					for end in [-1, 1]: builder.cylinder(node, Vector3(side * (width / 2 - 0.14), 0.36, end * 0.42), 0.035, 0.72, "wood")
				builder.box(node, Vector3(0, 0.83, 0), Vector3(width * 0.8, 0.012, 0.5), "linen")
			elif kind == "desk":
				for y in [0.6, 0.4, 0.2]:
					builder.box(node, Vector3(width / 2 - 0.36, y, 0.47), Vector3(0.44, 0.17, 0.02), "wood")
					builder.box(node, Vector3(width / 2 - 0.36, y, 0.49), Vector3(0.12, 0.025, 0.02), "gold")
				builder.box(node, Vector3(-0.5, 0.84, -0.3), Vector3(0.42, 0.03, 0.3), "linen", false, "box", Vector3(0, 0.3, 0))
			# The chair, pulled up to it, and what lies on it (clear of the middle,
			# where a document may lie).
			builder.box(node, Vector3(0, 0.45, 0.95), Vector3(0.65, 0.12, 0.65), "", true)
			put(builder, node, "dining_chair_02", Vector3(0, 0, 0.92), PI + builder.vary(seed_pos, 9) * 0.3 - 0.15)
			if kind == "desk":
				put(builder, node, "office_notepads_pad", Vector3(0.62, 0.825, -0.1), builder.vary(seed_pos, 10) * 0.4 + 1.4, Vector3.ONE * 0.7)
				put(builder, node, "stationery_supplies", Vector3(-0.88, 0.825, 0.25), builder.vary(seed_pos, 11) * 0.4)
			else:
				put(builder, node, "jug_01" if builder.vary(seed_pos, 12) < 0.5 else "ceramic_vase_01", Vector3(-0.78, 0.835, 0.05), builder.vary(seed_pos, 13) * TAU)
				put(builder, node, DRESSING.BOTTLES[int(builder.vary(seed_pos, 14) * 4)], Vector3(0.75, 0.835, -0.1))
		"wardrobe", "shelf", "reception":
			var height := 1.12 if kind == "reception" else 2.45
			# A shelf's carcass only collides: the shelving is models.
			var carcass := "" if kind == "shelf" else "wood"
			builder.box(node, Vector3(0, height / 2, -0.38), Vector3(2.2, height, 0.16), carcass, true)
			for side in [-1, 1]: builder.box(node, Vector3(side * 1.05, height / 2, 0), Vector3(0.12, height, 0.9), carcass, true)
			for y in [0.1, height * 0.5, height]: builder.box(node, Vector3(0, y, 0), Vector3(2.2, 0.1, 0.9), carcass, true)
			if kind != "shelf": builder.box(node, Vector3(0, height + 0.08, 0.02), Vector3(2.3, 0.06, 0.96), "trim")
			if kind == "wardrobe":
				builder.box(node, Vector3(0, height / 2, 0.46), Vector3(2.0, height - 0.1, 0.09), "", true)
				for side in [-1, 1]:
					builder.box(node, Vector3(side * 0.505, height / 2, 0.46), Vector3(0.99, height - 0.12, 0.09), "wood")
					for y in [0.65, 1.75]: builder.box(node, Vector3(side * 0.505, y, 0.51), Vector3(0.7, 0.8 if y > 1 else 0.9, 0.015), "panel")
					builder.cylinder(node, Vector3(side * 0.08, 1.2, 0.53), 0.018, 0.22, "gold")
			elif kind == "shelf":
				# Two units side by side, filled: metal shelving and stores in
				# service rooms, worn bookcases and books elsewhere.
				var service: bool = builder.building_type in SERVICE
				for side in [-1, 1]:
					var unit: String = ("steel_frame_shelves_01" if side < 0 else "worn_metal_rack") if service else "wooden_bookshelf_worn"
					var s := 1.0 if service else 0.8
					var at := Vector3(side * 0.56, 0, -0.12)
					put(builder, node, unit, at, 0.0, Vector3.ONE * s)
					DRESSING.fill_shelves(builder, node, unit, at, s, DRESSING.STORE_THINGS if service else ["book_encyclopedia_set_01", "book_encyclopedia_set_01", "book_encyclopedia_set_01", "ceramic_vase_01"], seed_pos + Vector3(side, 0, 0))
			else:
				builder.box(node, Vector3(0, 0.56, 0.46), Vector3(2.2, 1.0, 0.06), "panel")
				builder.box(node, Vector3(0, 1.2, 0.1), Vector3(2.4, 0.05, 1.1), "wood")
				# The till faces the clerk (-Z); papers and a clipboard beside it.
				put(builder, node, "CashRegister_01", Vector3(0.6, 1.225, 0.05), PI)
				builder.box(node, Vector3(-0.5, 1.24, 0.0), Vector3(0.5, 0.02, 0.36), "linen", false, "box", Vector3(0, -0.2, 0))
				put(builder, node, "clipboard", Vector3(-0.95, 1.225, 0.1), builder.vary(seed_pos, 15) * 0.6 + 2.8)
				builder.practical(node, Vector3(0, 1.6, 0), Color("ffc27a"), 0.3, 3.0)
		"lamp":
			builder.box(node, Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.5), "", true)
			builder.cylinder(node, Vector3(0, 0.03, 0), 0.2, 0.06, "gold")
			builder.cylinder(node, Vector3(0, 0.86, 0), 0.018, 1.62, "gold")
			builder.box(node, Vector3(0, 1.72, 0), Vector3(0.6, 0.42, 0.6), "shade_off" if builder.building_dark else "shade", false, "cone")
			builder.practical(node, Vector3(0, 1.58, 0), Color("ffb36b"), 0.38, 3.6)
		# The cabinet of a set no stage is played on, without the set: see
		# tv_placement.settle().
		"tv_stand":
			builder.box(node, Vector3(0, 0.5, 0), Vector3(1.7, 1.0, 0.8), "wood", true)
			for side in [-1, 1]: builder.box(node, Vector3(side * 0.42, 0.5, 0.41), Vector3(0.78, 0.86, 0.02), "panel")
		"tv":
			builder.box(node, Vector3(0, 0.5, 0), Vector3(1.7, 1.0, 0.8), "wood", true)
			for side in [-1, 1]: builder.box(node, Vector3(side * 0.42, 0.5, 0.41), Vector3(0.78, 0.86, 0.02), "panel")
			builder.box(node, Vector3(0, 1.43, 0), Vector3(1.15, 0.83, 0.63), "", true)
			builder.box(node, Vector3(0, 1.43, -0.06), Vector3(1.1, 0.8, 0.5), "black")
			builder.box(node, Vector3(0, 1.4, -0.38), Vector3(0.7, 0.55, 0.3), "black")
			builder.box(node, Vector3(0, 1.43, 0.2), Vector3(1.15, 0.83, 0.02), "trim")
			builder.box(node, Vector3(-0.1, 1.44, 0.215), Vector3(0.78, 0.6, 0.02), "screen")
			for y in [1.62, 1.46]: builder.cylinder(node, Vector3(0.43, y, 0.22), 0.04, 0.03, "metal", Vector3(PI / 2, 0, 0))
			for side in [-1, 1]: builder.cylinder(node, Vector3(side * 0.18, 2.1, -0.05), 0.008, 0.6, "metal", Vector3(0, 0, side * -0.5))
			builder.cylinder(node, Vector3(0, 1.86, -0.05), 0.06, 0.04, "black")
		"luggage":
			builder.box(node, Vector3(0, 0.38, 0), Vector3(1.0, 0.76, 0.36), "", true)
			# Two old suitcases, one leaning on the other.
			put(builder, node, "vintage_suitcase_a", Vector3(-0.17, 0, 0.02), builder.vary(seed_pos, 16) * 0.2 - 0.1)
			put(builder, node, "vintage_suitcase_b", Vector3(0.2, 0, 0.0), builder.vary(seed_pos, 17) * 0.3 - 0.15)
		"cart":
			for y in [0.2, 0.9]: builder.box(node, Vector3(0, y, 0), Vector3(1.35, 0.12, 0.75), "", true)
			for x in [-0.6, 0.6]: builder.box(node, Vector3(x, 0.66, 0), Vector3(0.08, 1.2, 0.75), "", true)
			if builder.building_type in SERVICE:
				# A metal storage cart where staff work, a bottle and a box on it.
				put(builder, node, "industrial_storage_cart", Vector3.ZERO, 0.0, Vector3.ONE * 0.84)
				put(builder, node, "bleach_bottle", Vector3(0.4, 1.16, 0.05), builder.vary(seed_pos, 18) * TAU)
				put(builder, node, "cardboard_box_01", Vector3(-0.25, 1.16, 0.0), builder.vary(seed_pos, 19) * 0.4)
				return
			builder.box(node, Vector3(0, 0.2, 0), Vector3(1.3, 0.05, 0.72), "linen")
			builder.box(node, Vector3(0, 0.9, 0), Vector3(1.3, 0.04, 0.72), "metal")
			for x in [-0.6, 0.6]:
				for z in [-0.32, 0.32]: builder.cylinder(node, Vector3(x, 0.66, z), 0.018, 1.2, "gold")
				builder.cylinder(node, Vector3(x, 1.26, 0), 0.02, 0.66, "gold", Vector3(PI / 2, 0, 0))
				for z in [-0.3, 0.3]: builder.cylinder(node, Vector3(x, 0.06, z), 0.05, 0.04, "black", Vector3(0, 0, PI / 2))
			builder.cylinder(node, Vector3(0, 1.28, 0), 0.02, 1.2, "gold", Vector3(0, 0, PI / 2))
			for i in 4: builder.box(node, Vector3(0.1, 0.97 + i * 0.045, 0.05), Vector3(0.9, 0.04, 0.55), "linen", false, "box", Vector3(0, i * 0.06, 0))
		"plant":
			builder.box(node, Vector3(0, 0.27, 0), Vector3(0.55, 0.54, 0.55), "", true)
			# Each plant turned differently so neighbours do not look copied.
			model(node, MONSTERA, Vector3.ZERO, builder.vary(seed_pos, 3) * TAU)
		"bin":
			builder.box(node, Vector3(0, 0.32, 0), Vector3(0.5, 0.64, 0.5), "", true)
			put(builder, node, "metal_trash_can_rust" if builder.vary(seed_pos, 20) < 0.5 else "metal_trash_can_clean", Vector3(0.08, 0, 0), builder.vary(seed_pos, 21) * TAU, Vector3.ONE * 0.62)
		"curtain":
			builder.box(node, Vector3(0, 1.45, -0.65), Vector3(2.3, 2.7, 0.1), "black", true)
			# A night window behind: frame, mullions and a faint cold glass.
			builder.box(node, Vector3(0, 1.45, -0.59), Vector3(1.8, 2.2, 0.03), "screen")
			builder.box(node, Vector3(0, 1.45, -0.575), Vector3(0.05, 2.2, 0.03), "trim")
			builder.box(node, Vector3(0, 1.9, -0.575), Vector3(1.8, 0.05, 0.03), "trim")
			builder.cylinder(node, Vector3(0, 2.78, -0.42), 0.022, 2.5, "gold", Vector3(0, 0, PI / 2))
			for i in 12: builder.box(node, Vector3(-1.1 + i * 0.2, 1.4, -0.48 + (i % 2) * 0.08), Vector3(0.19, 2.65, 0.1), "curtain")
		"washer":
			builder.box(node, Vector3(0, 0.53, 0), Vector3(1.1, 1.06, 0.9), "ceramic", true)
			builder.cylinder(node, Vector3(0, 0.48, 0.46), 0.3, 0.04, "metal", Vector3(PI / 2, 0, 0))
			builder.cylinder(node, Vector3(0, 0.48, 0.475), 0.24, 0.02, "screen", Vector3(PI / 2, 0, 0))
			builder.box(node, Vector3(0, 0.93, 0.44), Vector3(1.0, 0.16, 0.04), "metal")
			for x in [-0.3, 0.3]: builder.cylinder(node, Vector3(x, 0.93, 0.47), 0.04, 0.03, "black", Vector3(PI / 2, 0, 0))
			builder.box(node, Vector3(0, 0.02, 0), Vector3(1.04, 0.04, 0.86), "black")
		"basin":
			builder.box(node, Vector3(0, 0.43, 0), Vector3(0.5, 0.86, 0.5), "", true)
			builder.cylinder(node, Vector3(0, 0.43, 0), 0.17, 0.86, "ceramic")
			builder.box(node, Vector3(0, 0.92, 0), Vector3(1.1, 0.17, 0.75), "ceramic", true)
			builder.box(node, Vector3(0, 1.005, 0.05), Vector3(0.7, 0.01, 0.45), "screen")
			builder.cylinder(node, Vector3(0, 1.1, -0.26), 0.02, 0.2, "metal")
			builder.cylinder(node, Vector3(0, 1.19, -0.19), 0.015, 0.16, "metal", Vector3(PI / 2, 0, 0))
			for x in [-0.14, 0.14]: builder.cylinder(node, Vector3(x, 1.03, -0.27), 0.03, 0.05, "metal")
			# Vanity mirror on two posts.
			for x in [-0.44, 0.44]: builder.box(node, Vector3(x, 1.55, -0.37), Vector3(0.05, 1.1, 0.05), "trim")
			builder.box(node, Vector3(0, 1.75, -0.37), Vector3(0.84, 0.94, 0.03), "trim")
			builder.box(node, Vector3(0, 1.75, -0.35), Vector3(0.74, 0.84, 0.01), "mirror")
