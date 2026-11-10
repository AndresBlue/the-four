extends RefCounted
## Small things on desks and floors, the open drawer, the persian rug and the
## microfiche reader (spec_rediseno.md 5.1 and 7, area 4c): KIT's frame, cache and materials (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["phone", phone(builder, Vector3(0.22, 0.1, 0.24), false)],
		["phone_off", phone(builder, Vector3(0.22, 0.1, 0.24), true)],
		["mug", mug(builder, Vector3(0.11, 0.1, 0.09))],
		["ashtray", ashtray(builder, Vector3(0.14, 0.03, 0.14))],
		["pen_cup", pen_cup(builder, Vector3(0.08, 0.16, 0.08))],
		["paper_scatter", paper_scatter(builder, Vector3(0.9, 0.01, 0.7))],
		["cable_run", cable_run(builder, Vector3(1.2, 0.012, 0.3))],
		["drawer_out_steel_olive", drawer_out(builder, Vector3(0.42, 0.27, 0.36), "steel_olive")],
		["rug_persian", rug_persian(builder, Vector3(3.0, 0.012, 2.0))],
		["microfiche_reader", microfiche_reader(builder, Vector3(0.45, 0.55, 0.5))],
	]

## Black desk telephone; with off_hook its handset lies beside it.
static func phone(builder: Node3D, size: Vector3, off_hook: bool) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("phone", size, str(off_hook)), func() -> ArrayMesh: return make_phone(builder, size, off_hook))

static func make_phone(builder: Node3D, size: Vector3, off_hook: bool) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "black", Vector3(0, 0.03, 0.03), Vector3(w, 0.06, d - 0.06), 0.01)
	KIT.block(p, "black", Vector3(0, 0.065, 0.04), Vector3(w - 0.02, 0.02, d * 0.5), 0.006, Basis(Vector3.RIGHT, 0.2))
	KIT.cylinder(p, "metal", Vector3(0, 0.08, 0.06), 0.035, 0.006, 16, Basis(Vector3.RIGHT, 0.2))
	if not off_hook:
		KIT.block(p, "black", Vector3(0, h - 0.015, -0.035), Vector3(w, 0.03, 0.05), 0.012)
		for s: float in [-1.0, 1.0]:
			KIT.block(p, "black", Vector3(s * (w / 2 - 0.03), h - 0.025, -0.035), Vector3(0.06, 0.05, 0.06), 0.015)
	else:
		KIT.block(p, "black", Vector3(0, 0.015, -d / 2 + 0.03), Vector3(w, 0.03, 0.05), 0.012)
		for s: float in [-1.0, 1.0]:
			KIT.block(p, "black", Vector3(s * (w / 2 - 0.03), 0.025, -d / 2 + 0.03), Vector3(0.06, 0.05, 0.06), 0.015)
		KIT.cylinder(p, "black", Vector3(w / 2 - 0.02, 0.006, -0.05), 0.004, 0.04, 6, KIT.along_z())
	var title: String = "phone_off" if off_hook else "phone"
	return KIT.finish(builder, p, title, size, {"solid": false})

## Ceramic mug with its handle, standing on a desk.
static func mug(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("mug", size), func() -> ArrayMesh: return make_mug(builder, size))

static func make_mug(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var h := size.y
	KIT.cylinder(p, "ceramic", Vector3(-0.007, h / 2, 0), 0.04, h, 12)
	KIT.block(p, "ceramic", Vector3(0.04, h / 2, 0), Vector3(0.014, 0.06, 0.012))
	return KIT.finish(builder, p, "mug", size, {"solid": false})

## Glass ashtray holding a cigarette end, on a desk.
static func ashtray(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("ashtray", size), func() -> ArrayMesh: return make_ashtray(builder, size))

static func make_ashtray(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	KIT.cylinder(p, "screen", Vector3(0, 0.01, 0), w / 2, 0.02, 12)
	KIT.cylinder(p, "black", Vector3(0, 0.0205, 0), w / 2 - 0.02, 0.001, 12)
	KIT.block(p, "paper", Vector3(0.02, 0.025, 0.01), Vector3(0.03, 0.008, 0.008), 0.0, Basis(Vector3.UP, 0.6))
	return KIT.finish(builder, p, "ashtray", size, {"solid": false})

## Pen pot with four pens standing in it, on a desk.
static func pen_cup(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("pen_cup", size), func() -> ArrayMesh: return make_pen_cup(builder, size))

static func make_pen_cup(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	KIT.cylinder(p, "black", Vector3(0, 0.05, 0), 0.035, 0.1, 10)
	for k in 4:
		var key: String = ["cloth_red", "cloth_navy", "black", "gold"][k]
		var tilt: float = 0.12 if k % 2 == 0 else -0.12
		KIT.cylinder(p, key, Vector3(cos(k * 1.6) * 0.015, 0.09, sin(k * 1.6) * 0.015), 0.004, 0.13, 6, Basis(Vector3.RIGHT, tilt))
	return KIT.finish(builder, p, "pen_cup", size, {"solid": false})

## Loose sheets of paper lying flat and scattered over a floor or a desk.
static func paper_scatter(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("paper_scatter", size), func() -> ArrayMesh: return make_paper_scatter(builder, size))

static func make_paper_scatter(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var reach_x := size.x * 0.5 - 0.185
	var reach_z := size.z * 0.5 - 0.185
	for k in 7:
		var x: float = -reach_x if k == 0 else reach_x if k == 1 else lerpf(-reach_x, reach_x, KIT.hash01(k, 61))
		var z := lerpf(-reach_z, reach_z, KIT.hash01(k, 62))
		KIT.block(p, "paper", Vector3(x, 0.001 + k * 0.0012, z), Vector3(0.21, 0.001, 0.297), 0.0, Basis(Vector3.UP, KIT.hash01(k, 63) * TAU))
	return KIT.finish(builder, p, "paper_scatter", size, {"solid": false})

## A loose cable lying across a floor or a desk, in long bends.
static func cable_run(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("cable_run", size), func() -> ArrayMesh: return make_cable_run(builder, size))

static func make_cable_run(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var n := 12
	for k in n:
		var a := cable_point(size.x, size.z, float(k) / n)
		var b := cable_point(size.x, size.z, float(k + 1) / n)
		KIT.block(p, "black", (a + b) * 0.5, Vector3((b - a).length() + 0.004, 0.01, 0.008), 0.0, Basis(Vector3.UP, atan2(-(b.z - a.z), b.x - a.x)))
	return KIT.finish(builder, p, "cable_run", size, {"solid": false})

## A point along the cable, t from 0 to 1.
static func cable_point(w: float, d: float, t: float) -> Vector3:
	return Vector3(-w * 0.5 + 0.01 + (w - 0.02) * t, 0.006, (d * 0.5 - 0.02) * sin(t * TAU * 1.25))

## Filing cabinet drawer pulled out with its folders, standing in front of the closed front.
static func drawer_out(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("drawer_out", size, key), func() -> ArrayMesh: return make_drawer_out(builder, size, key))

static func make_drawer_out(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	for s: float in [-1.0, 1.0]:
		KIT.block(p, key, Vector3(s * (w / 2 - 0.005), 0.12, -0.02), Vector3(0.01, 0.22, d - 0.04))
	KIT.block(p, key, Vector3(0, 0.012, -0.02), Vector3(w - 0.02, 0.01, d - 0.04))
	KIT.block(p, key, Vector3(0, 0.12, -d / 2 + 0.005), Vector3(w - 0.02, 0.22, 0.01))
	for k in 6:
		KIT.block(p, "cardboard", Vector3(0, 0.11, -0.14 + k * 0.045), Vector3(w - 0.05, 0.19, 0.006), 0.0, Basis(Vector3.RIGHT, (KIT.hash01(k, 72) - 0.5) * 0.3))
	KIT.block(p, key, Vector3(0, h / 2, d / 2 - 0.03), Vector3(w, h, 0.02), 0.004)
	KIT.handle(p, "metal", Vector3(0, h * 0.62, d / 2 - 0.02), 0.14, 0.018)
	return KIT.finish(builder, p, "drawer_out_" + key, size)

## Persian rug: red field, navy border, linen lines and medallion, fringe on the short sides.
static func rug_persian(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("rug_persian", size), func() -> ArrayMesh: return make_rug_persian(builder, size))

static func make_rug_persian(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var d := size.z
	KIT.block(p, "cloth_red", Vector3(0, 0.004, 0), Vector3(w - 0.06, 0.008, d), 0.002)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "cloth_navy", Vector3(0, 0.0085, s * (d / 2 - 0.12)), Vector3(w - 0.18, 0.001, 0.14))
		KIT.block(p, "cloth_navy", Vector3(s * (w / 2 - 0.15), 0.0085, 0), Vector3(0.14, 0.001, d - 0.38))
		KIT.block(p, "linen", Vector3(0, 0.0092, s * (d / 2 - 0.22)), Vector3(w - 0.5, 0.0006, 0.02))
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "linen", Vector3(s * (w / 2 - 0.25), 0.0092, 0), Vector3(0.02, 0.0006, d - 0.44))
	KIT.block(p, "cloth_navy", Vector3(0, 0.0088, 0), Vector3(minf(w, d) * 0.32, 0.0012, minf(w, d) * 0.32), 0.0, Basis(Vector3.UP, PI / 4))
	KIT.block(p, "gold", Vector3(0, 0.0096, 0), Vector3(minf(w, d) * 0.16, 0.0008, minf(w, d) * 0.16), 0.0, Basis(Vector3.UP, PI / 4))
	for i in 6:
		for j in 4:
			KIT.block(p, "linen", Vector3(-w / 2 + 0.45 + i * (w - 0.9) / 5, 0.0084, -d / 2 + 0.45 + j * (d - 0.9) / 3), Vector3(0.06, 0.0006, 0.06), 0.0, Basis(Vector3.UP, PI / 4))
	for s: float in [-1.0, 1.0]:
		for k in int(d / 0.02):
			KIT.block(p, "linen", Vector3(s * (w / 2 - 0.015), 0.001, -d / 2 + 0.01 + k * 0.02), Vector3(0.03, 0.002, 0.006))
	return KIT.finish(builder, p, "rug_persian", size, {"solid": false})

## Beige microfiche reader; the lit screen is put on by office_props, here it is a screen.
static func microfiche_reader(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("microfiche_reader", size), func() -> ArrayMesh: return make_microfiche_reader(builder, size))

static func make_microfiche_reader(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "plastic_beige", Vector3(0, 0.06, 0.02), Vector3(w, 0.12, d - 0.04), 0.01)
	KIT.block(p, "plastic_beige", Vector3(0, 0.25, -d / 2 + 0.08), Vector3(w * 0.6, 0.3, 0.12), 0.01)
	KIT.block(p, "plastic_beige", Vector3(0, h - 0.16, 0.0), Vector3(w, 0.32, d * 0.7), 0.015)
	KIT.block(p, "screen", Vector3(0, h - 0.16, d * 0.35 + 0.002), Vector3(w - 0.08, 0.24, 0.004))
	KIT.block(p, "screen", Vector3(0, 0.125, 0.12), Vector3(w * 0.5, 0.01, 0.16))
	return KIT.finish(builder, p, "microfiche_reader", size)
