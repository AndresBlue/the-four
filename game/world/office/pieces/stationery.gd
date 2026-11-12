extends RefCounted
## Stationery: binders, folders, archive box, books, paper, trays, the register
## (spec_rediseno.md 5.1, area 4a): KIT's frame, cache and materials
## (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["binders", binders(builder, Vector3(0.4, 0.32, 0.29))],
		["folders", folders(builder, Vector3(0.35, 0.05, 0.25))],
		["archive_box", archive_box(builder, Vector3(0.33, 0.25, 0.39))],
		["books", books(builder, Vector3(0.6, 0.25, 0.2))],
		["paper_stack", paper_stack(builder, Vector3(0.22, 0.05, 0.31))],
		["tray", tray(builder, Vector3(0.26, 0.07, 0.34), false)],
		["tray_wire", tray(builder, Vector3(0.26, 0.07, 0.34), true)],
		["register_book", register_book(builder, Vector3(0.5, 0.03, 0.35))],
	]

## A row of ring binders on a shelf, their spines flush to the front.
## `variant` (0 to 2) gives other contents under the same title.
static func binders(builder: Node3D, size: Vector3, variant := 0) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("binders", size, str(variant)), func() -> ArrayMesh: return make_binders(builder, size, variant))

static func make_binders(builder: Node3D, size: Vector3, variant: int) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.binder_row(p, Vector3(-w / 2.0, 0.0, -0.002), w, d - 0.004, h, 3 + variant * KIT.VARIANT)
	return KIT.finish(builder, p, "binders", size, {"solid": false})

## A stack of cardboard folders, each with its sheets inside.
static func folders(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("folders", size), func() -> ArrayMesh: return make_folders(builder, size))

static func make_folders(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var n := maxi(2, int(h / 0.008))
	for k in n:
		var sx := (KIT.hash01(k, 21) - 0.5) * 0.012
		var sz := (KIT.hash01(k, 22) - 0.5) * 0.012
		KIT.block(p, "cardboard", Vector3(sx, 0.004 + k * 0.008, sz), Vector3(w - 0.012, 0.006, d - 0.012), 0.001)
		KIT.block(p, "paper", Vector3(sx, 0.0075 + k * 0.008, sz), Vector3(w - 0.02, 0.0015, d - 0.02))
	return KIT.finish(builder, p, "folders", size, {"solid": false})

## An archive box: cardboard with a label card and a dark grip on its front.
static func archive_box(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("archive_box", size), func() -> ArrayMesh: return make_archive_box(builder, size))

static func make_archive_box(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "cardboard", Vector3(0.0, h / 2.0, -0.001), Vector3(w, h, d - 0.002), 0.004)
	KIT.block(p, "paper", Vector3(0.0, h * 0.62, d / 2.0 - 0.0005), Vector3(w * 0.36, h * 0.28, 0.001))
	KIT.block(p, "black", Vector3(0.0, h * 0.25, d / 2.0 - 0.0005), Vector3(w * 0.2, h * 0.1, 0.001))
	return KIT.finish(builder, p, "archive_box", size)

## Books standing along a shelf, their spines flush to the front.
static func books(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("books", size), func() -> ArrayMesh: return make_books(builder, size))

static func make_books(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.book_row(p, Vector3(-w / 2.0, 0.0, 0.0), w, d, h, 5)
	return KIT.finish(builder, p, "books", size, {"solid": false})

## A ream of loose sheets, each a little askew.
static func paper_stack(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("paper_stack", size), func() -> ArrayMesh: return make_paper_stack(builder, size))

static func make_paper_stack(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	# Room inside its measure for its sheets to lie askew (KIT.sheets()).
	KIT.sheets(p, Vector3.ZERO, Vector2(w - 0.06, d - 0.06), h, 6, maxi(3, int(h / 0.008)))
	return KIT.finish(builder, p, "paper_stack", size, {"solid": false})

## A desk tray: black plastic, or wire mesh when wire, with a few sheets in it.
static func tray(builder: Node3D, size: Vector3, wire: bool) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("tray", size, str(wire)), func() -> ArrayMesh: return make_tray(builder, size, wire))

static func make_tray(builder: Node3D, size: Vector3, wire: bool) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	if not wire:
		KIT.block(p, "black", Vector3(0.0, 0.003, 0.0), Vector3(w, 0.006, d), 0.002)
		KIT.block(p, "black", Vector3(0.0, h / 2.0, -d / 2.0 + 0.003), Vector3(w, h, 0.006))
		for s: float in [-1.0, 1.0]:
			KIT.block(p, "black", Vector3(s * (w / 2.0 - 0.003), h * 0.4, 0.0), Vector3(0.006, h * 0.8, d - 0.012))
		KIT.block(p, "black", Vector3(0.0, 0.015, d / 2.0 - 0.003), Vector3(w - 0.012, 0.03, 0.006))
	else:
		for k in int(d / 0.02):
			KIT.cylinder(p, "metal", Vector3(0.0, 0.003, -d / 2.0 + 0.01 + k * 0.02), 0.002, w, 4, KIT.along_x())
		for s: float in [-1.0, 1.0]:
			KIT.cylinder(p, "metal", Vector3(s * (w / 2.0 - 0.003), h - 0.003, 0.0), 0.003, d, 6, KIT.along_z())
		KIT.cylinder(p, "metal", Vector3(0.0, h - 0.003, -d / 2.0 + 0.003), 0.003, w, 6, KIT.along_x())
		KIT.cylinder(p, "metal", Vector3(0.0, 0.025, d / 2.0 - 0.003), 0.003, w, 6, KIT.along_x())
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				KIT.cylinder(p, "metal", Vector3(sx * (w / 2.0 - 0.003), h / 2.0, sz * (d / 2.0 - 0.003)), 0.003, h, 6)
	KIT.sheets(p, Vector3(0.0, 0.007, 0.0), Vector2(0.21, 0.297), minf(0.03, h - 0.02), 7, 3)
	var title: String = "tray_wire" if wire else "tray"
	return KIT.finish(builder, p, title, size, {"solid": false})

## An open register: a green cloth cover with a page on each side of the spine.
static func register_book(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("register_book", size), func() -> ArrayMesh: return make_register_book(builder, size))

static func make_register_book(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "cloth_green", Vector3(0.0, 0.002, 0.0), Vector3(w, 0.004, d), 0.001)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "paper", Vector3(s * w / 4.0, (0.004 + h) / 2.0, 0.0), Vector3(w / 2.0 - 0.01, h - 0.004, d - 0.01), 0.002)
	KIT.block(p, "cloth_green", Vector3(0.0, (0.004 + h) / 2.0, 0.0), Vector3(0.008, h - 0.006, d - 0.004))
	return KIT.finish(builder, p, "register_book", size, {"solid": false})
