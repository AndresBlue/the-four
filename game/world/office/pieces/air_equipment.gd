extends RefCounted
## Air equipment: the air handler, a fan's rotor, the hatch's hand wheel, the fans' control box and the security console (spec_rediseno.md 6, area 5): KIT's frame,
## cache and materials (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## The sizes and places air_objective.gd uses.
const CONSOLE := Vector3(1.6, 0.45, 0.42)
## The security desk's middle off the wall and its top (office_geometry.gd
## SECURITY_DESK).
const DESK_MIDDLE := 0.225
const DESK_TOP := 0.755
const ROTOR := Vector3(0.68, 0.68, 0.012)
## The fans' centres on the handler, in its frame: across, up, and out to
## the rotor's plane, between the dark opening and the guard.
const FAN_X := 0.7
const FAN_Y := 1.2
const ROTOR_Z := 0.722
const WHEEL := Vector3(0.36, 0.36, 0.08)
const CONTROL := Vector3(0.3, 0.4, 0.15)
const HATCH_SIGN := Vector3(0.44, 0.13, 0.01)
const DUCT_SIGN := Vector3(0.5, 0.16, 0.01)
## The duct's signs, this far back from the hatch along the duct.
const DUCT_SIGN_BACK := 0.75

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["air_handler", air_handler(builder, Vector3(3.0, 2.2, 1.5))],
		["fan_rotor", fan_rotor(builder, ROTOR)],
		["hand_wheel", hand_wheel(builder, WHEEL)],
		["control_box", control_box(builder, CONTROL)],
		["security_console", security_console(builder, CONSOLE)],
	]

## The air handler AH-1: a cabinet with two fans behind grilles and doors below,
## a pair of gauges on its plate, and its pipes on the +x side.
static func air_handler(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("air_handler", size), func() -> ArrayMesh: return make_air_handler(builder, size))

static func make_air_handler(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var d := size.z
	var bw := w - 0.3
	var bx := -0.15
	var zb := d / 2.0 - 0.04
	KIT.block(p, "black", Vector3(bx, 0.05, -0.02), Vector3(bw - 0.06, 0.1, d - 0.1))
	KIT.block(p, "steel_olive", Vector3(bx, 1.15, -0.02), Vector3(bw, 2.1, d - 0.04), 0.01)
	for k in range(1, 4):
		KIT.block(p, "black", Vector3(-w / 2.0 + bw * k / 4.0, 1.15, zb + 0.001), Vector3(0.006, 2.06, 0.002))
	for s: float in [-1.0, 1.0]:
		var fx: float = s * FAN_X
		KIT.cylinder(p, "black", Vector3(fx, FAN_Y, zb + 0.0015), 0.36, 0.003, 24, KIT.along_z())
		for r: float in [0.38, 0.26, 0.14]:
			for k in 24:
				var a := TAU * k / 24.0
				KIT.block(p, "metal", Vector3(fx + cos(a) * r, FAN_Y + sin(a) * r, zb + 0.03), Vector3(TAU * r / 24.0 + 0.004, 0.008, 0.008), 0.0, Basis(Vector3.BACK, a + PI / 2.0))
		for k in 4:
			KIT.block(p, "metal", Vector3(fx, FAN_Y, zb + 0.03), Vector3(0.76, 0.006, 0.006), 0.0, Basis(Vector3.BACK, k * PI / 4.0))
	for x: float in [-1.0, -0.15, 0.7]:
		KIT.front(p, "steel_olive", Vector3(x, 0.45, zb), Vector2(0.62, 0.56), "bar", "metal", 0.0, false, 0.012)
	KIT.block(p, "paper", Vector3(-1.0, 0.62, zb + 0.0125), Vector3(0.15, 0.1, 0.001))
	KIT.block(p, "paper", Vector3(0.7, 0.62, zb + 0.0125), Vector3(0.12, 0.08, 0.001))
	KIT.block(p, "black", Vector3(0.0, 1.88, zb + 0.002), Vector3(0.52, 0.16, 0.004))
	for k in 2:
		var gx := 0.6 + k * 0.3
		KIT.cylinder(p, "black", Vector3(gx, 1.88, zb + 0.01), 0.065, 0.02, 16, KIT.along_z())
		KIT.cylinder(p, "ceramic", Vector3(gx, 1.88, zb + 0.0205), 0.055, 0.001, 16, KIT.along_z())
		KIT.block(p, "black", Vector3(gx, 1.89, zb + 0.0215), Vector3(0.004, 0.05, 0.001), 0.0, Basis(Vector3.BACK, -0.7 + k))
	for k in 2:
		var px := 1.27 + k * 0.14
		var pz := 0.3 - k * 0.35
		KIT.cylinder(p, "metal", Vector3(px, 1.1, pz), 0.045, 2.0, 12)
		for y: float in [0.3, 1.9]:
			KIT.cylinder(p, "metal", Vector3(px, y, pz), 0.06, 0.03, 12)
		KIT.cylinder(p, "metal", Vector3((px + 1.18) / 2.0, 1.9, pz), 0.035, px - 1.18, 10, KIT.along_x())
	KIT.cylinder(p, "paint_red", Vector3(1.27, 1.0, 0.351), 0.05, 0.012, 12, KIT.along_z())
	KIT.block(p, "steel_grey", Vector3(1.3, 1.4, 0.62), Vector3(0.2, 0.26, 0.12), 0.004)
	return KIT.finish(builder, p, "air_handler", size, {"text_plate": [Vector3(0.0, 1.88, zb + 0.005), Vector2(0.48, 0.14), Vector3(0.0, 0.0, 1.0)]})

## One fan's blades: a black hub and four steel blades, turning in the XY plane.
static func fan_rotor(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("fan_rotor", size), func() -> ArrayMesh: return make_fan_rotor(builder, size))

static func make_fan_rotor(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var h := size.y
	var d := size.z
	KIT.cylinder(p, "black", Vector3(0.0, h / 2.0, 0.0), 0.06, d, 16, KIT.along_z())
	for k in 4:
		var a := TAU * k / 4.0 + 0.3
		KIT.block(p, "steel_dark", Vector3(cos(a) * 0.19, h / 2.0 + sin(a) * 0.19, 0.0), Vector3(0.26, 0.1, 0.004), 0.0, Basis(Vector3.BACK, a) * Basis(Vector3.RIGHT, 0.1))
	return KIT.finish(builder, p, "fan_rotor", size)

## The hatch's red hand wheel: its axle at the back, its rim at the front, facing +Z.
static func hand_wheel(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("hand_wheel", size), func() -> ArrayMesh: return make_hand_wheel(builder, size))

static func make_hand_wheel(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var h := size.y
	var d := size.z
	KIT.cylinder(p, "metal", Vector3(0.0, h / 2.0, -d / 4.0), 0.018, d / 2.0, 10, KIT.along_z())
	KIT.cylinder(p, "paint_red", Vector3(0.0, h / 2.0, 0.012), 0.03, 0.024, 12, KIT.along_z())
	for k in 5:
		var a := TAU * k / 5.0
		KIT.block(p, "paint_red", Vector3(cos(a) * 0.08, h / 2.0 + sin(a) * 0.08, 0.016), Vector3(0.14, 0.016, 0.012), 0.0, Basis(Vector3.BACK, a))
	for k in 20:
		var a := TAU * k / 20.0
		KIT.block(p, "paint_red", Vector3(cos(a) * 0.16, h / 2.0 + sin(a) * 0.16, 0.024), Vector3(TAU * 0.16 / 20.0 + 0.006, 0.022, 0.02), 0.004, Basis(Vector3.BACK, a + PI / 2.0))
	return KIT.finish(builder, p, "hand_wheel", size)

## The box that stops the fans: green grey on a wall, a red button, pilots that
## stay off until the lamp is lit, and a selector.
static func control_box(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("control_box", size), func() -> ArrayMesh: return make_control_box(builder, size))

static func make_control_box(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "steel_olive", Vector3(0.0, h / 2.0, -0.01), Vector3(w, h, d - 0.02), 0.006)
	KIT.cylinder(p, "black", Vector3(0.0, 0.26, 0.063), 0.05, 0.016, 16, KIT.along_z())
	KIT.cylinder(p, "paint_red", Vector3(0.0, 0.26, 0.067), 0.045, 0.012, 16, KIT.along_z())
	for s: float in [-1.0, 1.0]:
		KIT.cylinder(p, "lamp_off", Vector3(s * 0.09, 0.35, 0.059), 0.012, 0.008, 10, KIT.along_z())
	KIT.cylinder(p, "black", Vector3(0.0, 0.1, 0.063), 0.03, 0.016, 12, KIT.along_z())
	KIT.block(p, "ceramic", Vector3(0.0, 0.115, 0.0715), Vector3(0.006, 0.025, 0.001))
	KIT.block(p, "metal", Vector3(0.0, 0.17, 0.056), Vector3(0.16, 0.04, 0.002))
	return KIT.finish(builder, p, "control_box", size, {"wall": true, "mount": 1.1})

## The guard's console on its desk: four monitors on a shelf, the control keyboard,
## the recorder and the log book; its front, +Z, faces the guard.
static func security_console(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("security_console", size), func() -> ArrayMesh: return make_security_console(builder, size))

static func make_security_console(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var d := size.z
	KIT.block(p, "steel_olive", Vector3(0.0, 0.06, -d / 2.0 + 0.11), Vector3(w, 0.12, 0.22), 0.004)
	for k in 4:
		var x := -0.6 + k * 0.4
		KIT.block(p, "black", Vector3(x, 0.27, -d / 2.0 + 0.15), Vector3(0.36, 0.3, 0.28), 0.012)
		KIT.block(p, "steel_dark", Vector3(x, 0.27, 0.075), Vector3(0.36, 0.3, 0.01), 0.006)
		KIT.block(p, "screen", Vector3(x, 0.28, 0.0805), Vector3(0.27, 0.21, 0.001))
		for j in 3:
			KIT.block(p, "ceramic", Vector3(x + 0.1 + j * 0.022, 0.14, 0.0805), Vector3(0.012, 0.008, 0.001))
	KIT.block(p, "black", Vector3(0.45, 0.035, 0.13), Vector3(0.4, 0.07, 0.16), 0.004)
	KIT.block(p, "screen", Vector3(0.4, 0.05, 0.2105), Vector3(0.18, 0.008, 0.001))
	KIT.block(p, "glow_green", Vector3(0.58, 0.05, 0.2105), Vector3(0.06, 0.014, 0.001))
	KIT.block(p, "plastic_beige", Vector3(-0.15, 0.025, 0.12), Vector3(0.34, 0.05, 0.17), 0.006)
	for r in 3:
		for c in 7:
			var key: String = "black" if (r + c) % 4 == 0 else "ceramic"
			KIT.block(p, key, Vector3(-0.285 + c * 0.045, 0.053, 0.06 + r * 0.05), Vector3(0.03, 0.006, 0.03), 0.002)
	KIT.block(p, "cloth_green", Vector3(-0.6, 0.015, 0.11), Vector3(0.3, 0.03, 0.2), 0.003)
	KIT.block(p, "paper", Vector3(-0.6, 0.031, 0.11), Vector3(0.28, 0.002, 0.19))
	return KIT.finish(builder, p, "security_console", size)
