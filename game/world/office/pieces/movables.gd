extends RefCounted
## Carts, the mobile whiteboard, partition screens and the slatted bench (spec_rediseno.md 5.1, area 4a): KIT's frame,
## cache and materials (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["cart_two_shelf", cart(builder, Vector3(0.8, 0.9, 0.5), false)],
		["cart_boxes", cart(builder, Vector3(0.8, 1.0, 0.5), true)],
		["mail_cart", mail_cart(builder, Vector3(0.9, 0.9, 0.6))],
		["whiteboard_mobile", whiteboard_mobile(builder, Vector3(1.5, 1.9, 0.6))],
		["partition_screen_120", partition_screen(builder, Vector3(1.6, 1.2, 0.06))],
		["partition_screen_150", partition_screen(builder, Vector3(1.6, 1.5, 0.06))],
		["slat_bench", slat_bench(builder, Vector3(1.5, 0.45, 0.4))],
	]

## A two-shelf cart, or one with archive boxes on its shelves when `loaded`.
## Loaded, it asks for h of 1.0 or more: the top boxes reach 0.96 m.
static func cart(builder: Node3D, size: Vector3, loaded: bool) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("cart", size, str(loaded)), func() -> ArrayMesh: return make_cart(builder, size, loaded))

static func make_cart(builder: Node3D, size: Vector3, loaded: bool) -> ArrayMesh:
	var title: String = "cart_boxes" if loaded else "cart_two_shelf"
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	castors(p, w, d)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var top: float = h - 0.012 if sz < 0.0 else 0.75
			KIT.cylinder(p, "metal", Vector3(sx * (w / 2.0 - 0.02), (0.09 + top) / 2.0, sz * (d / 2.0 - 0.02)), 0.0125, top - 0.09, 10)
	for k in 2:
		var yt: float = 0.0975 if k == 0 else 0.7
		KIT.block(p, "steel_grey", Vector3(0, yt, 0), Vector3(w - 0.01, 0.015, d - 0.01), 0.002)
		for s: float in [-1.0, 1.0]:
			KIT.block(p, "steel_grey", Vector3(0, yt + 0.02, s * (d / 2.0 - 0.01)), Vector3(w - 0.01, 0.04, 0.008))
			KIT.block(p, "steel_grey", Vector3(s * (w / 2.0 - 0.01), yt + 0.02, 0), Vector3(0.008, 0.04, d - 0.01))
		if loaded:
			KIT.box_row(p, Vector3(-w / 2.0 + 0.03, yt + 0.0075, 0), w - 0.06, minf(0.39, d - 0.06), 1.0, k + 30)
	KIT.cylinder(p, "metal", Vector3(0, h - 0.012, -d / 2.0 + 0.02), 0.012, w - 0.04, 10, KIT.along_x())
	return KIT.finish(builder, p, title, size)

## A canvas mail cart: a steel frame round a grey sack, sheets in its bottom,
## and a text plate on its front.
static func mail_cart(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("mail_cart", size), func() -> ArrayMesh: return make_mail_cart(builder, size))

static func make_mail_cart(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	castors(p, w, d)
	for y: float in [0.09, h - 0.012]:
		for s: float in [-1.0, 1.0]:
			KIT.cylinder(p, "metal", Vector3(0, y, s * (d / 2.0 - 0.02)), 0.012, w - 0.04, 8, KIT.along_x())
			KIT.cylinder(p, "metal", Vector3(s * (w / 2.0 - 0.02), y, 0), 0.012, d - 0.04, 8, KIT.along_z())
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KIT.cylinder(p, "metal", Vector3(sx * (w / 2.0 - 0.02), (0.09 + h - 0.012) / 2.0, sz * (d / 2.0 - 0.02)), 0.012, h - 0.102, 8)
	KIT.block(p, "partition_fabric", Vector3(0, 0.3, 0), Vector3(w - 0.076, 0.008, d - 0.076))
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "partition_fabric", Vector3(0, (0.3 + h - 0.03) / 2.0, s * (d / 2.0 - 0.034)), Vector3(w - 0.076, h - 0.33, 0.008))
		KIT.block(p, "partition_fabric", Vector3(s * (w / 2.0 - 0.034), (0.3 + h - 0.03) / 2.0, 0), Vector3(0.008, h - 0.33, d - 0.06))
	for k in 3:
		KIT.sheets(p, Vector3(-w / 4.0 + k * w / 4.0, 0.304, 0), Vector2(0.2, 0.16), 0.08, k + 40, 4)
	return KIT.finish(builder, p, "mail_cart", size, {"text_plate": [Vector3(0, (0.3 + h) / 2.0, d / 2.0 - 0.029), Vector2(0.4, 0.12), Vector3(0, 0, 1)]})

## A mobile whiteboard on two castored posts, with a tray of pens and an eraser.
static func whiteboard_mobile(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("whiteboard_mobile", size), func() -> ArrayMesh: return make_whiteboard_mobile(builder, size))

static func make_whiteboard_mobile(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var pw := w - 0.1
	var by := h - 1.15
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "metal", Vector3(s * (w / 2.0 - 0.02), 0.085, 0), Vector3(0.04, 0.03, d - 0.08))
		for sz: float in [-1.0, 1.0]:
			KIT.cylinder(p, "black", Vector3(s * (w / 2.0 - 0.02), 0.035, sz * (d / 2.0 - 0.04)), 0.035, 0.025, 12, KIT.along_x())
		KIT.cylinder(p, "metal", Vector3(s * (w / 2.0 - 0.02), (0.1 + h) / 2.0, 0), 0.015, h - 0.1, 10)
		KIT.block(p, "metal", Vector3(s * (pw / 2.0 + 0.0125), by + 0.5, 0), Vector3(0.025, 1.0, 0.03))
	KIT.block(p, "ceramic", Vector3(0, by + 0.5, 0), Vector3(pw, 1.0, 0.018))
	KIT.block(p, "metal", Vector3(0, by + 1.0125, 0), Vector3(pw + 0.05, 0.025, 0.03))
	KIT.block(p, "metal", Vector3(0, by - 0.0125, 0), Vector3(pw + 0.05, 0.025, 0.03))
	KIT.block(p, "metal", Vector3(0, by - 0.03, 0.035), Vector3(pw * 0.5, 0.012, 0.05))
	KIT.cylinder(p, "black", Vector3(-0.05, by - 0.018, 0.04), 0.009, 0.12, 8, KIT.along_x())
	KIT.cylinder(p, "cloth_red", Vector3(0.1, by - 0.018, 0.04), 0.009, 0.12, 8, KIT.along_x())
	return KIT.finish(builder, p, "whiteboard_mobile", size)

## A cubicle partition: a fabric panel edged in beige plastic, on a black foot.
static func partition_screen(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("partition_screen", size), func() -> ArrayMesh: return make_partition_screen(builder, size))

static func make_partition_screen(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "partition_fabric", Vector3(0, (0.04 + h - 0.03) / 2.0, 0), Vector3(w - 0.06, h - 0.07, 0.05), 0.004)
	KIT.block(p, "plastic_beige", Vector3(0, h - 0.015, 0), Vector3(w, 0.03, d), 0.008)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "plastic_beige", Vector3(s * (w / 2.0 - 0.015), (h - 0.03) / 2.0, 0), Vector3(0.03, h - 0.03, d), 0.006)
	KIT.block(p, "black", Vector3(0, 0.02, 0), Vector3(w - 0.06, 0.04, d - 0.01))
	var title: String = "partition_screen_%d" % roundi(h * 100.0)
	return KIT.finish(builder, p, title, size)

## A slatted bench of the changing rooms: oak slats on a steel frame.
static func slat_bench(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("slat_bench", size), func() -> ArrayMesh: return make_slat_bench(builder, size))

static func make_slat_bench(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var gap := (d - 4.0 * 0.085) / 3.0
	for k in 4:
		KIT.block(p, "oak_door", Vector3(0, h - 0.0125, -d / 2.0 + 0.0425 + k * (0.085 + gap)), Vector3(w, 0.025, 0.085), 0.004)
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * (w / 2.0 - 0.12)
		for sz: float in [-1.0, 1.0]:
			KIT.block(p, "steel_olive", Vector3(x, (h - 0.025) / 2.0, sz * (d / 2.0 - 0.03)), Vector3(0.03, h - 0.025, 0.03), 0.003)
		KIT.block(p, "steel_olive", Vector3(x, h - 0.04, 0), Vector3(0.03, 0.03, d - 0.03))
		KIT.block(p, "steel_olive", Vector3(x, 0.015, 0), Vector3(0.04, 0.03, d - 0.02))
	KIT.block(p, "steel_olive", Vector3(0, h - 0.04, 0), Vector3(w - 0.24, 0.03, 0.03))
	return KIT.finish(builder, p, "slat_bench", size)

## The four castors under a footprint of w by d: a black wheel and its bracket.
static func castors(p: Dictionary, w: float, d: float) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KIT.cylinder(p, "black", Vector3(sx * (w / 2.0 - 0.05), 0.035, sz * (d / 2.0 - 0.05)), 0.035, 0.025, 12, KIT.along_x())
			KIT.block(p, "metal", Vector3(sx * (w / 2.0 - 0.05), 0.08, sz * (d / 2.0 - 0.05)), Vector3(0.03, 0.02, 0.05))
