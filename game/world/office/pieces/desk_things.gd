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

## Black push-button desk telephone of the eighties: a body with its sloped
## keypad, the cradle's two prongs, the curved handset on them (with
## off_hook, lying behind it) and its coiled cord down the left side.
static func phone(builder: Node3D, size: Vector3, off_hook: bool) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("phone", size, str(off_hook)), func() -> ArrayMesh: return make_phone(builder, size, off_hook))

static func make_phone(builder: Node3D, size: Vector3, off_hook: bool) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var bw := w - 0.03
	KIT.block(p, "black", Vector3(0, 0.0225, 0.03), Vector3(bw, 0.045, d - 0.06), 0.014)
	# The keypad on its slope, front down: twelve grey keys, four rows of three.
	var slope := Basis(Vector3.RIGHT, 0.18)
	var deck := Vector3(0, 0.05, 0.055)
	KIT.block(p, "black", deck, Vector3(bw * 0.7, 0.014, 0.11), 0.005, slope)
	for r in 4:
		for c in 3:
			KIT.block(p, "steel_grey", deck + slope * Vector3((c - 1) * 0.03, 0.009, -0.039 + r * 0.026), Vector3(0.02, 0.006, 0.016), 0.0, slope)
	# The cradle's prongs over the body's back.
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "black", Vector3(s * 0.08, 0.05, -0.03), Vector3(0.034, 0.02, 0.05), 0.007)
		# With the handset off, the hook switch's plungers stand up out of them.
		if off_hook: KIT.block(p, "steel_grey", Vector3(s * 0.08, 0.07, -0.03), Vector3(0.016, 0.022, 0.016), 0.0)
	# The handset: two cups and the arched grip between them; on its prongs,
	# or off them, lying on the desk behind the body.
	var at := Vector3(0, 0.0, -0.03) if not off_hook else Vector3(0, -0.051, -0.09)
	# One grip from cup to cup, the cups hanging below its ends: a jointed
	# arch reads as a chain of blocks.
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "black", at + Vector3(s * 0.08, 0.069, 0), Vector3(0.048, 0.028, 0.05), 0.012, Basis(Vector3.BACK, s * 0.12))
	KIT.block(p, "black", at + Vector3(0, 0.084, 0), Vector3(0.19, 0.02, 0.036), 0.009)
	# The coiled cord: rings down from the handset's left cup, then along the
	# desk by the body's left side.
	var cord_x := -bw * 0.5 - 0.007
	if not off_hook:
		for k in 4:
			KIT.cylinder(p, "black", Vector3(cord_x, 0.05 - k * 0.011, -0.03), 0.006, 0.005, 5)
		for k in 8:
			KIT.cylinder(p, "black", Vector3(cord_x, 0.007, -0.02 + k * 0.011), 0.006, 0.005, 5, KIT.along_z())
	else:
		for k in 8:
			KIT.cylinder(p, "black", Vector3(cord_x, 0.007, -0.075 + k * 0.011), 0.006, 0.005, 5, KIT.along_z())
	var title: String = "phone_off" if off_hook else "phone"
	return KIT.finish(builder, p, title, size, {"solid": false})

## A cream stoneware mug of coffee: a thin rim over the coffee and a D handle.
static func mug(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("mug", size), func() -> ArrayMesh: return make_mug(builder, size))

static func make_mug(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var h := size.y
	var c := Vector3(-0.007, 0.0, 0.0)
	var r := 0.04
	var level := h - 0.012
	# The body up to the coffee, the coffee, and the thin wall round it.
	KIT.cylinder(p, "plastic_beige", c + Vector3(0, level * 0.5, 0), r, level, 16)
	KIT.cylinder(p, "screen", c + Vector3(0, level + 0.0005, 0), r - 0.004, 0.001, 16)
	for k in 16:
		var a := TAU * (k + 0.5) / 16.0
		KIT.block(p, "plastic_beige", c + Vector3(cos(a) * (r - 0.002), level + 0.006, sin(a) * (r - 0.002)), Vector3(0.004, 0.012, TAU * r / 16.0 + 0.001), 0.0, Basis(Vector3.UP, -a))
	# The handle: a half ellipse of eight pieces from the wall and back.
	var hub := Vector3(c.x + r - 0.007, h * 0.5, 0.0)
	var reach := Vector2(0.023, 0.026)
	for k in 8:
		var t0 := -PI * 0.5 + PI * k / 8.0
		var t1 := -PI * 0.5 + PI * (k + 1) / 8.0
		var a0 := hub + Vector3(cos(t0) * reach.x, sin(t0) * reach.y, 0.0)
		var a1 := hub + Vector3(cos(t1) * reach.x, sin(t1) * reach.y, 0.0)
		KIT.block(p, "plastic_beige", (a0 + a1) * 0.5, Vector3((a1 - a0).length() + 0.003, 0.008, 0.01), 0.0, Basis(Vector3.BACK, atan2(a1.y - a0.y, a1.x - a0.x)))
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

## Black pen pot, open, its rim thin: pens with their caps and clips, a
## pencil and a steel rule, each leaning its own way.
static func pen_cup(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("pen_cup", size), func() -> ArrayMesh: return make_pen_cup(builder, size))

static func make_pen_cup(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var r := 0.034
	var level := 0.092
	KIT.cylinder(p, "black", Vector3(0, level * 0.5, 0), r, level, 12)
	for k in 12:
		var a := TAU * (k + 0.5) / 12.0
		KIT.block(p, "black", Vector3(cos(a) * (r - 0.002), level + 0.004, sin(a) * (r - 0.002)), Vector3(0.004, 0.008, TAU * r / 12.0 + 0.001), 0.0, Basis(Vector3.UP, -a))
	# Pens: a body, a darker cap over its top and a steel clip down the cap.
	var pens := [["cloth_navy", 0.4], ["cloth_red", 2.5], ["black", 4.4]]
	for k in pens.size():
		var key: String = pens[k][0]
		var turn := Basis(Vector3.UP, float(pens[k][1])) * Basis(Vector3.RIGHT, 0.13)
		var foot := Vector3(cos(k * 2.1) * 0.012, 0.03, sin(k * 2.1) * 0.012)
		KIT.cylinder(p, key, foot + turn * Vector3(0, 0.055, 0), 0.0045, 0.11, 6, turn)
		KIT.cylinder(p, "black", foot + turn * Vector3(0, 0.105, 0), 0.0055, 0.04, 6, turn)
		KIT.block(p, "metal", foot + turn * Vector3(0, 0.1, 0.0065), Vector3(0.003, 0.03, 0.0015), 0.0, turn)
	# A pencil, sharpened, and a steel rule.
	var lean := Basis(Vector3.UP, 1.4) * Basis(Vector3.RIGHT, -0.12)
	var stub := Vector3(-0.014, 0.03, 0.006)
	KIT.cylinder(p, "plastic_beige", stub + lean * Vector3(0, 0.055, 0), 0.0038, 0.11, 6, lean)
	KIT.cylinder(p, "cardboard", stub + lean * Vector3(0, 0.116, 0), 0.0028, 0.012, 6, lean)
	var rule := Basis(Vector3.UP, 3.5) * Basis(Vector3.RIGHT, -0.1)
	KIT.block(p, "steel_grey", Vector3(0.006, 0.03, -0.012) + rule * Vector3(0, 0.06, 0), Vector3(0.022, 0.12, 0.0015), 0.0, rule)
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
