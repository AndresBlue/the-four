extends RefCounted
## Office machines: copier, printer, computer, monitors, keyboard, calculator, projector (spec_rediseno.md 5.1, area 4a): KIT's frame,
## cache and materials (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["copier", copier(builder, Vector3(1.1, 1.05, 0.7))],
		["dot_matrix_printer", dot_matrix_printer(builder, Vector3(0.6, 0.25, 0.42))],
		["computer_tower", computer_tower(builder, Vector3(0.2, 0.45, 0.45))],
		["crt_plastic_beige", crt_monitor(builder, Vector3(0.4, 0.4, 0.42), "plastic_beige")],
		["crt_black", crt_monitor(builder, Vector3(0.38, 0.36, 0.4), "black")],
		["keyboard", keyboard(builder, Vector3(0.46, 0.035, 0.17))],
		["calculator", calculator(builder, Vector3(0.2, 0.09, 0.26))],
		["overhead_projector", overhead_projector(builder, Vector3(0.4, 0.8, 0.45))],
	]

## A photocopier: a beige body with a lid, a control panel and an output tray.
## Its height is its sample's: it does not read size.y.
static func copier(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("copier", size), func() -> ArrayMesh: return make_copier(builder, size))

static func make_copier(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var d := size.z
	var zf := d * 0.5 - KIT.FRONT
	var bw := w - 0.25
	var bx := -w * 0.5 + bw * 0.5
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KIT.cylinder(p, "black", Vector3(bx + sx * (bw * 0.5 - 0.05), 0.025, sz * (d * 0.5 - 0.08)), 0.025, 0.03, 10, KIT.along_x())
	KIT.block(p, "plastic_beige", Vector3(bx, 0.335, (-d * 0.5 + zf) * 0.5), Vector3(bw, 0.57, zf + d * 0.5), 0.01)
	for y: float in [0.2, 0.43]:
		KIT.front(p, "plastic_beige", Vector3(bx, y, zf), Vector2(bw - 0.02, 0.2), "grip", "black", 0.06, false, 0.012)
	KIT.block(p, "plastic_beige", Vector3(bx, 0.795, -0.0025), Vector3(bw, 0.35, d - 0.005), 0.02)
	# The lid, its catch, and the control panel with its keys and display.
	KIT.block(p, "plastic_beige", Vector3(bx - bw * 0.1, 0.99, -d * 0.5 + 0.22), Vector3(bw * 0.75, 0.04, d * 0.6), 0.008)
	KIT.block(p, "black", Vector3(bx - bw * 0.1, 0.99, -d * 0.5 + 0.22 + d * 0.3 + 0.006), Vector3(0.12, 0.015, 0.012))
	var pxc := bx + bw * 0.5 - bw * 0.15 - 0.01
	KIT.block(p, "plastic_beige", Vector3(pxc, 0.9875, d * 0.5 - 0.1), Vector3(bw * 0.3, 0.035, 0.16), 0.006)
	KIT.block(p, "black", Vector3(pxc - 0.03, 1.0055, d * 0.5 - 0.1), Vector3(0.09, 0.002, 0.04))
	for col in 3:
		for row in 4:
			KIT.block(p, "ceramic", Vector3(pxc + 0.03 + col * 0.02, 1.007, d * 0.5 - 0.15 + row * 0.02), Vector3(0.014, 0.004, 0.014))
	# The output tray at the right end, with its sheets.
	KIT.block(p, "plastic_beige", Vector3(w * 0.5 - 0.125, 0.6, 0.0), Vector3(0.25, 0.015, d * 0.6), 0.004)
	KIT.block(p, "black", Vector3(w * 0.5 - 0.245, 0.58, 0.0), Vector3(0.01, 0.04, d * 0.3))
	KIT.sheets(p, Vector3(w * 0.5 - 0.13, 0.6075, 0.0), Vector2(0.21, 0.297), 0.02, 1, 3)
	return KIT.finish(builder, p, "copier", size)

## A dot-matrix printer: a beige case with a platen knob, a screen window and
## its folio leaving through the back.
## Its height is its sample's: it does not read size.y.
static func dot_matrix_printer(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("dot_matrix_printer", size), func() -> ArrayMesh: return make_dot_matrix_printer(builder, size))

static func make_dot_matrix_printer(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var d := size.z
	KIT.block(p, "plastic_beige", Vector3(0.0, 0.07, 0.05), Vector3(w - 0.04, 0.14, d - 0.1), 0.01)
	KIT.cylinder(p, "black", Vector3(w * 0.5 - 0.015, 0.09, 0.0), 0.02, 0.03, 10, KIT.along_x())
	KIT.block(p, "screen", Vector3(0.0, 0.142, -0.02), Vector3(w * 0.55, 0.004, 0.12))
	KIT.block(p, "black", Vector3(0.0, 0.1405, d * 0.5 - 0.12), Vector3(w * 0.6, 0.001, 0.015))
	# The folio leaves through the back and leans on the case.
	KIT.block(p, "paper", Vector3(0.0, 0.17, -d * 0.5 + 0.09), Vector3(w * 0.55, 0.16, 0.002), 0.0, Basis(Vector3.RIGHT, -0.3))
	for k in 3:
		KIT.block(p, "ceramic", Vector3(w * 0.5 - 0.1 + k * 0.02, 0.1405, d * 0.5 - 0.03), Vector3(0.008, 0.001, 0.008))
	return KIT.finish(builder, p, "dot_matrix_printer", size, {"solid": false})

## A desktop computer tower: a beige case with a black front bezel, two drive
## bays, a power button and a row of vents at its foot.
static func computer_tower(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("computer_tower", size), func() -> ArrayMesh: return make_computer_tower(builder, size))

static func make_computer_tower(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "plastic_beige", Vector3(0.0, h * 0.5, -0.003), Vector3(w, h, d - 0.006), 0.006)
	for y: float in [h - 0.06, h - 0.11]:
		KIT.block(p, "black", Vector3(0.0, y, d * 0.5 - 0.0045), Vector3(w - 0.04, 0.042, 0.003))
	KIT.block(p, "black", Vector3(0.0, h - 0.16, d * 0.5 - 0.0045), Vector3(0.1, 0.008, 0.003))
	KIT.block(p, "ceramic", Vector3(0.06, h - 0.175, d * 0.5 - 0.0045), Vector3(0.012, 0.008, 0.003))
	KIT.block(p, "ceramic", Vector3(0.0, 0.12, d * 0.5 - 0.003), Vector3(0.022, 0.022, 0.006), 0.002)
	for k in 5:
		KIT.block(p, "black", Vector3(0.0, 0.03 + k * 0.012, d * 0.5 - 0.0055), Vector3(w - 0.06, 0.004, 0.001))
	return KIT.finish(builder, p, "computer_tower", size)

## A CRT monitor in the plastic `key` names: a bulging front bezel, a screen,
## a tapering rear housing and a foot. Keyed by its colour, so each is baked once.
static func crt_monitor(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("crt", size, key), func() -> ArrayMesh: return make_crt_monitor(builder, size, key))

static func make_crt_monitor(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var y0 := 0.05
	var bh := h - y0
	var ym := (y0 + h) * 0.5
	var rd := (d - 0.064) * 0.5
	KIT.cylinder(p, key, Vector3(0.0, 0.012, 0.02), minf(w, d) * 0.3, 0.024, 16)
	# The neck, run up into the housing.
	KIT.block(p, key, Vector3(0.0, (0.024 + y0 + bh * 0.1) * 0.5, 0.02), Vector3(0.1, y0 + bh * 0.1 - 0.024, 0.1))
	KIT.block(p, key, Vector3(0.0, ym, d * 0.5 - 0.034), Vector3(w, bh, 0.06), 0.012)
	KIT.block(p, "screen", Vector3(0.0, ym + 0.01, d * 0.5 - 0.003), Vector3(w * 0.76, bh * 0.7, 0.002), 0.0)
	KIT.block(p, key, Vector3(0.0, ym, d * 0.5 - 0.064 - rd * 0.5), Vector3(w * 0.88, bh * 0.88, rd), 0.02)
	KIT.block(p, key, Vector3(0.0, ym - 0.01, -d * 0.5 + rd * 0.5), Vector3(w * 0.6, bh * 0.6, rd), 0.02)
	for k in 3:
		KIT.block(p, "ceramic", Vector3(w * 0.3 - 0.025 + k * 0.025, y0 + 0.02, d * 0.5 - 0.003), Vector3(0.012, 0.008, 0.002))
	return KIT.finish(builder, p, "crt_" + key, size, {"solid": false})

## A keyboard: a low beige base with rows of ceramic keys. The front row's
## middle is the space bar, laid over the keys it replaces.
## Its height is its sample's: it does not read size.y.
static func keyboard(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("keyboard", size), func() -> ArrayMesh: return make_keyboard(builder, size))

static func make_keyboard(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var d := size.z
	KIT.block(p, "plastic_beige", Vector3(0.0, 0.011, 0.0), Vector3(w, 0.022, d), 0.004)
	var px := (w - 0.04) / 15.0
	var pz := (d - 0.04) / 5.0
	for r in 5:
		for c in 15:
			if r == 0 and c >= 4 and c <= 10: continue
			KIT.block(p, "ceramic", Vector3(-w * 0.5 + 0.02 + px * (c + 0.5), 0.0265, d * 0.5 - 0.02 - pz * (r + 0.5)), Vector3(px * 0.82, 0.009, pz * 0.82), 0.0015)
	KIT.block(p, "ceramic", Vector3(-w * 0.5 + 0.02 + px * 7.5, 0.0265, d * 0.5 - 0.02 - pz * 0.5), Vector3(px * 6.65, 0.009, pz * 0.82), 0.0015)
	return KIT.finish(builder, p, "keyboard", size, {"solid": false})

## A desk calculator: a flat beige body with a paper roll in holders at the
## back, a display strip and four columns of ceramic keys.
## Its height is its sample's: it does not read size.y.
static func calculator(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("calculator", size), func() -> ArrayMesh: return make_calculator(builder, size))

static func make_calculator(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var d := size.z
	KIT.block(p, "plastic_beige", Vector3(0.0, 0.03, 0.0), Vector3(w, 0.06, d), 0.008)
	KIT.cylinder(p, "paper", Vector3(0.0, 0.075, -d * 0.5 + 0.02), 0.015, w * 0.5, 12, KIT.along_x())
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "black", Vector3(s * (w * 0.25 + 0.006), 0.07, -d * 0.5 + 0.02), Vector3(0.008, 0.02, 0.02))
	KIT.block(p, "paper", Vector3(0.0, 0.0605, -d * 0.5 + 0.07), Vector3(w * 0.45, 0.001, 0.05))
	KIT.block(p, "black", Vector3(0.0, 0.0605, -d * 0.5 + 0.115), Vector3(w * 0.6, 0.001, 0.025))
	for c in 4:
		for r in 5:
			KIT.block(p, "ceramic", Vector3(-w * 0.3 + c * w * 0.2, 0.065, d * 0.5 - 0.03 - r * 0.025), Vector3(0.018, 0.01, 0.018), 0.002)
	return KIT.finish(builder, p, "calculator", size, {"solid": false})

## An overhead projector: a steel base with a glass stage, a post and arm
## carrying the lamp head, and a fold mirror over the stage.
static func overhead_projector(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("overhead_projector", size), func() -> ArrayMesh: return make_overhead_projector(builder, size))

static func make_overhead_projector(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var bd := minf(d - 0.04, 0.38)
	var zb := 0.02
	var post_z := zb - bd * 0.5 + 0.015
	KIT.block(p, "steel_grey", Vector3(0.0, 0.065, zb), Vector3(minf(w, 0.38), 0.13, bd), 0.01)
	KIT.block(p, "screen", Vector3(0.0, 0.1315, zb), Vector3(0.29, 0.003, 0.29))
	KIT.block(p, "steel_grey", Vector3(0.0, (0.13 + h - 0.06) * 0.5, post_z), Vector3(0.03, h - 0.19, 0.03), 0.003)
	KIT.block(p, "steel_grey", Vector3(0.0, h - 0.07, (post_z + zb) * 0.5), Vector3(0.025, 0.025, zb - post_z))
	KIT.block(p, "black", Vector3(0.0, h - 0.045, zb), Vector3(0.12, 0.08, 0.16), 0.008)
	KIT.cylinder(p, "black", Vector3(0.0, h - 0.1, zb), 0.035, 0.03, 12)
	KIT.block(p, "mirror", Vector3(0.0, h - 0.045, zb + 0.11), Vector3(0.1, 0.002, 0.08), 0.0, Basis(Vector3.RIGHT, PI / 4))
	return KIT.finish(builder, p, "overhead_projector", size)
