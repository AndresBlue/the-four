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
			builder.box(node, Vector3(0, 0.17, 0.02), Vector3(1.86, 0.3, 2.5), "wood")
			builder.box(node, Vector3(0, 0.44, 0.02), Vector3(1.8, 0.24, 2.46), "linen")
			# Bedspread with hanging sides and a folded top edge.
			builder.box(node, Vector3(0, 0.575, 0.28), Vector3(1.9, 0.04, 1.98), "bedspread")
			for side in [-1, 1]: builder.box(node, Vector3(side * 0.94, 0.4, 0.28), Vector3(0.03, 0.34, 1.98), "bedspread")
			builder.box(node, Vector3(0, 0.4, 1.265), Vector3(1.9, 0.34, 0.03), "bedspread")
			builder.box(node, Vector3(0, 0.6, -0.68), Vector3(1.9, 0.06, 0.18), "linen", false, "box", Vector3(0.12, 0, 0))
			for side in [-1, 1]: builder.box(node, Vector3(side * 0.43, 0.64, -0.98), Vector3(0.74, 0.16, 0.42), "linen", false, "box", Vector3(-0.35, side * 0.06, 0))
			builder.box(node, Vector3(0, 0.72, -1.32), Vector3(2.0, 1.44, 0.13), "wood")
			builder.box(node, Vector3(0, 0.92, -1.245), Vector3(1.7, 0.72, 0.04), "fabric")
			builder.box(node, Vector3(0, 1.46, -1.32), Vector3(2.08, 0.06, 0.17), "trim")
		"sofa":
			builder.box(node, Vector3(0, 0.34, 0), Vector3(2.3, 0.55, 0.9), "", true)
			model(node, SOFA, Vector3(0, 0, 0.02), SOFA_YAW)
		"table", "desk", "nightstand", "phone":
			var width := 0.85 if kind in ["nightstand", "phone"] else 2.2
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
			else:
				builder.box(node, Vector3(0, 0.45, 0.46), Vector3(width - 0.2, 0.5, 0.02), "wood")
				builder.cylinder(node, Vector3(0, 0.55, 0.49), 0.025, 0.03, "gold", Vector3(PI / 2, 0, 0))
			if kind in ["desk", "table"]:
				builder.box(node, Vector3(0, 0.45, 0.95), Vector3(0.65, 0.12, 0.65), "", true)
				builder.box(node, Vector3(0, 0.44, 0.95), Vector3(0.62, 0.06, 0.62), "wood")
				builder.box(node, Vector3(0, 0.5, 0.95), Vector3(0.56, 0.07, 0.56), "fabric")
				builder.box(node, Vector3(0, 0.84, 1.23), Vector3(0.6, 0.62, 0.05), "wood")
				builder.box(node, Vector3(0, 0.86, 1.2), Vector3(0.48, 0.44, 0.02), "fabric")
				for side in [-1, 1]:
					for end in [0.7, 1.2]: builder.cylinder(node, Vector3(side * 0.26, 0.21, end), 0.025, 0.42, "wood")
			if kind == "phone":
				builder.box(node, Vector3(0, 0.88, 0), Vector3(0.3, 0.1, 0.26), "black")
				builder.box(node, Vector3(0, 0.95, 0.04), Vector3(0.26, 0.05, 0.14), "black", false, "box", Vector3(-0.35, 0, 0))
				builder.cylinder(node, Vector3(0, 0.945, 0.07), 0.07, 0.012, "metal", Vector3(-0.35, 0, 0))
				builder.cylinder(node, Vector3(0, 0.97, -0.08), 0.03, 0.34, "black", Vector3(0, 0, PI / 2))
				for side in [-1, 1]: builder.box(node, Vector3(side * 0.16, 0.95, -0.08), Vector3(0.08, 0.05, 0.09), "black")
		"wardrobe", "shelf", "reception":
			var height := 1.12 if kind == "reception" else 2.45
			builder.box(node, Vector3(0, height / 2, -0.38), Vector3(2.2, height, 0.16), "wood", true)
			for side in [-1, 1]: builder.box(node, Vector3(side * 1.05, height / 2, 0), Vector3(0.12, height, 0.9), "wood", true)
			for y in [0.1, height * 0.5, height]: builder.box(node, Vector3(0, y, 0), Vector3(2.2, 0.1, 0.9), "wood", true)
			builder.box(node, Vector3(0, height + 0.08, 0.02), Vector3(2.3, 0.06, 0.96), "trim")
			if kind == "wardrobe":
				builder.box(node, Vector3(0, height / 2, 0.46), Vector3(2.0, height - 0.1, 0.09), "", true)
				for side in [-1, 1]:
					builder.box(node, Vector3(side * 0.505, height / 2, 0.46), Vector3(0.99, height - 0.12, 0.09), "wood")
					for y in [0.65, 1.75]: builder.box(node, Vector3(side * 0.505, y, 0.51), Vector3(0.7, 0.8 if y > 1 else 0.9, 0.015), "panel")
					builder.cylinder(node, Vector3(side * 0.08, 1.2, 0.53), 0.018, 0.22, "gold")
			elif kind == "shelf":
				# Rows of books; their colours are stable for this position.
				for y in [0.15, height * 0.5 + 0.05]:
					var x := -0.95
					var i := 0
					while x < 0.9:
						var w: float = 0.04 + builder.vary(seed_pos + Vector3(x, y, 0), 1) * 0.05
						var h: float = 0.24 + builder.vary(seed_pos + Vector3(x, y, 0), 2) * 0.16
						var lean: float = 0.12 if builder.vary(seed_pos + Vector3(x, y, i), 4) > 0.92 else 0.0
						builder.box(node, Vector3(x + w / 2, y + h / 2, -0.1), Vector3(w, h, 0.22), BOOKS[int(builder.vary(seed_pos + Vector3(x, y, 0), 3) * BOOKS.size())], false, "box", Vector3(0, 0, lean))
						x += w + 0.004 + (0.12 if builder.vary(seed_pos + Vector3(x, y, i), 5) > 0.93 else 0.0)
						i += 1
			else:
				builder.box(node, Vector3(0, 0.56, 0.46), Vector3(2.2, 1.0, 0.06), "panel")
				builder.box(node, Vector3(0, 1.2, 0.1), Vector3(2.4, 0.05, 1.1), "wood")
				builder.cylinder(node, Vector3(0.6, 1.25, 0.1), 0.05, 0.04, "gold")
				builder.box(node, Vector3(-0.5, 1.24, 0.0), Vector3(0.5, 0.02, 0.36), "linen", false, "box", Vector3(0, -0.2, 0))
				builder.practical(node, Vector3(0, 1.6, 0), Color("ffc27a"), 0.3, 3.0)
		"lamp":
			builder.box(node, Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.5), "", true)
			builder.cylinder(node, Vector3(0, 0.03, 0), 0.2, 0.06, "gold")
			builder.cylinder(node, Vector3(0, 0.86, 0), 0.018, 1.62, "gold")
			builder.box(node, Vector3(0, 1.72, 0), Vector3(0.6, 0.42, 0.6), "shade_off" if builder.building_dark else "shade", false, "cone")
			builder.practical(node, Vector3(0, 1.58, 0), Color("ffb36b"), 0.38, 3.6)
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
			builder.box(node, Vector3(0, 0.38, 0), Vector3(0.96, 0.72, 0.32), "leather")
			builder.box(node, Vector3(0, 0.38, 0), Vector3(1.0, 0.74, 0.02), "black")
			builder.box(node, Vector3(0, 0.77, 0), Vector3(0.3, 0.035, 0.05), "black")
			for x in [-0.32, 0.32]: builder.box(node, Vector3(x, 0.38, 0.17), Vector3(0.06, 0.74, 0.02), "leather")
			for x in [-0.4, 0.4]: builder.box(node, Vector3(x, 0.7, 0.17), Vector3(0.07, 0.05, 0.02), "gold")
		"cart":
			for y in [0.2, 0.9]: builder.box(node, Vector3(0, y, 0), Vector3(1.35, 0.12, 0.75), "", true)
			for x in [-0.6, 0.6]: builder.box(node, Vector3(x, 0.66, 0), Vector3(0.08, 1.2, 0.75), "", true)
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
			builder.box(node, Vector3(0, 0.32, 0), Vector3(0.44, 0.64, 0.44), "metal", false, "cone", Vector3(PI, 0, 0))
			builder.cylinder(node, Vector3(0, 0.64, 0), 0.23, 0.02, "metal")
			builder.box(node, Vector3(0.05, 0.6, 0.02), Vector3(0.16, 0.08, 0.12), "linen", false, "box", Vector3(0.4, 0.6, 0.3))
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
