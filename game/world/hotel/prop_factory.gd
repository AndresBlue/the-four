extends RefCounted
## Furniture recipes; keep the central circulation and reserved sockets clear.

static func build(builder: Node3D, node: Node3D, kind: String) -> void:
	match kind:
		"bed":
			builder.box(node, Vector3(0, 0.23, 0), Vector3(1.9, 0.46, 2.6), "wood", true)
			builder.box(node, Vector3(0, 0.54, 0), Vector3(1.85, 0.22, 2.55), "linen")
			builder.box(node, Vector3(0, 0.69, 0.25), Vector3(1.86, 0.09, 1.8), "fabric")
			builder.box(node, Vector3(0, 0.66, -0.93), Vector3(1.55, 0.19, 0.48), "linen")
			builder.box(node, Vector3(0, 0.72, -1.32), Vector3(2.0, 1.44, 0.13), "wood")
		"sofa":
			builder.box(node, Vector3(0, 0.34, 0), Vector3(2.3, 0.55, 0.9), "fabric", true)
			builder.box(node, Vector3(0, 0.87, -0.42), Vector3(2.3, 0.65, 0.25), "fabric")
			for side in [-1, 1]: builder.box(node, Vector3(side * 1.08, 0.7, 0), Vector3(0.2, 0.4, 0.95), "wood")
		"table", "desk", "nightstand", "phone":
			var width := 0.85 if kind in ["nightstand", "phone"] else 2.2
			builder.box(node, Vector3(0, 0.77, 0), Vector3(width, 0.12, 1.1), "wood", true)
			for side in [-1, 1]: builder.box(node, Vector3(side * (width / 2 - 0.08), 0.36, 0), Vector3(0.1, 0.72, 0.95), "wood", true)
			if kind in ["desk", "table"]:
				builder.box(node, Vector3(0, 0.45, 0.95), Vector3(0.65, 0.12, 0.65), "fabric", true)
				builder.box(node, Vector3(0, 0.84, 1.23), Vector3(0.65, 0.75, 0.09), "wood")
				for side in [-1, 1]: builder.box(node, Vector3(side * 0.26, 0.22, 0.95), Vector3(0.08, 0.44, 0.55), "wood")
			if kind == "phone":
				builder.box(node, Vector3(0, 0.9, 0), Vector3(0.45, 0.13, 0.28), "black")
				builder.box(node, Vector3(0, 1.0, -0.02), Vector3(0.53, 0.07, 0.13), "black")
		"wardrobe", "shelf", "reception":
			var height := 1.12 if kind == "reception" else 2.45
			builder.box(node, Vector3(0, height / 2, -0.38), Vector3(2.2, height, 0.16), "wood", true)
			for side in [-1, 1]: builder.box(node, Vector3(side * 1.05, height / 2, 0), Vector3(0.12, height, 0.9), "wood", true)
			for y in [0.1, height * 0.5, height]: builder.box(node, Vector3(0, y, 0), Vector3(2.2, 0.1, 0.9), "wood", true)
			if kind == "wardrobe":
				builder.box(node, Vector3(0, height / 2, 0.46), Vector3(2.0, height - 0.1, 0.09), "wood", true)
				for x in [-0.12, 0.12]: builder.box(node, Vector3(x, 1.2, 0.54), Vector3(0.05, 0.24, 0.04), "gold")
		"lamp":
			builder.box(node, Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.5), "gold", true)
			builder.box(node, Vector3(0, 0.86, 0), Vector3(0.07, 1.62, 0.07), "gold")
			builder.box(node, Vector3(0, 1.7, 0), Vector3(0.6, 0.45, 0.6), "linen")
		"tv":
			builder.box(node, Vector3(0, 0.5, 0), Vector3(1.7, 1.0, 0.8), "wood", true)
			builder.box(node, Vector3(0, 1.43, 0), Vector3(1.15, 0.83, 0.63), "black", true)
			builder.box(node, Vector3(-0.06, 1.44, 0.33), Vector3(0.89, 0.62, 0.03), "green")
		"luggage":
			builder.box(node, Vector3(0, 0.38, 0), Vector3(1.0, 0.76, 0.36), "fabric", true)
			builder.box(node, Vector3(0, 0.83, 0), Vector3(0.35, 0.06, 0.08), "black")
			for x in [-0.32, 0.32]: builder.box(node, Vector3(x, 0.4, 0.2), Vector3(0.07, 0.74, 0.02), "gold")
		"cart":
			for y in [0.2, 0.9]: builder.box(node, Vector3(0, y, 0), Vector3(1.35, 0.12, 0.75), "metal", true)
			for x in [-0.6, 0.6]: builder.box(node, Vector3(x, 0.66, 0), Vector3(0.08, 1.2, 0.75), "metal", true)
			builder.box(node, Vector3(0, 1.05, 0), Vector3(1.05, 0.18, 0.6), "linen")
		"plant":
			builder.box(node, Vector3(0, 0.27, 0), Vector3(0.55, 0.54, 0.55), "ceramic", true)
			builder.box(node, Vector3(0, 0.87, 0), Vector3(0.09, 1.3, 0.09), "wood")
			for y in [0.7, 1.05, 1.4]:
				builder.box(node, Vector3(0, y, 0), Vector3(1.12 - y * 0.4, 0.16, 0.52), "green")
		"bin": builder.box(node, Vector3(0, 0.32, 0), Vector3(0.5, 0.64, 0.5), "metal", true)
		"curtain":
			builder.box(node, Vector3(0, 1.45, -0.65), Vector3(2.3, 2.7, 0.1), "black", true)
			for i in 12: builder.box(node, Vector3(-1.1 + i * 0.2, 1.4, -0.48 + (i % 2) * 0.08), Vector3(0.19, 2.65, 0.1), "curtain")
		"washer":
			builder.box(node, Vector3(0, 0.53, 0), Vector3(1.1, 1.06, 0.9), "ceramic", true)
			builder.box(node, Vector3(0, 0.52, 0.46), Vector3(0.69, 0.69, 0.04), "black")
			builder.box(node, Vector3(0, 0.9, 0.48), Vector3(0.8, 0.12, 0.04), "metal")
		"basin":
			builder.box(node, Vector3(0, 0.43, 0), Vector3(0.5, 0.86, 0.5), "ceramic", true)
			builder.box(node, Vector3(0, 0.92, 0), Vector3(1.1, 0.17, 0.75), "ceramic", true)
			builder.box(node, Vector3(0, 1.07, -0.24), Vector3(0.06, 0.25, 0.12), "metal")
