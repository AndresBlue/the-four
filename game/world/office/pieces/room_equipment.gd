extends RefCounted
## The bank of padlocked lockers and the fan unit (spec_proporcion D7): KIT's
## frame, cache and materials (pieces/kit.gd). Neither opens nor works, and
## neither looks as if it did: the lockers players hide in are of another
## make, and the air plant's handler is another machine.
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["locker_bank", locker_bank(builder, Vector3(2.7, 1.9, 0.45))],
		["fan_unit", fan_unit(builder, Vector3(1.5, 1.6, 1.2))],
	]

## Six narrow grey lockers on a plinth, a padlock through each hasp.
static func locker_bank(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("locker_bank", size), func() -> ArrayMesh: return make_locker_bank(builder, size))

static func make_locker_bank(builder: Node3D, size: Vector3) -> ArrayMesh:
	const DOORS := 6
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var each := w / DOORS
	KIT.block(p, "steel_dark", Vector3(0.0, 0.05, -0.02), Vector3(w - 0.04, 0.1, d - 0.08))
	KIT.block(p, "steel_grey", Vector3(0.0, (0.1 + h) * 0.5, -0.02), Vector3(w, h - 0.1, d - 0.04), 0.003)
	for k in DOORS:
		var x := -w * 0.5 + each * (float(k) + 0.5)
		KIT.block(p, "steel_grey", Vector3(x, (0.12 + h) * 0.5, d * 0.5 - 0.02), Vector3(each - 0.012, h - 0.14, 0.02), 0.002)
		for slot in 3: KIT.block(p, "black", Vector3(x, h - 0.16 - float(slot) * 0.035, d * 0.5 - 0.009), Vector3(each * 0.5, 0.012, 0.002))
		KIT.block(p, "metal", Vector3(x + each * 0.33, 1.05, d * 0.5 - 0.006), Vector3(0.05, 0.03, 0.012))
		KIT.block(p, "black", Vector3(x + each * 0.33, 1.0, d * 0.5 - 0.008), Vector3(0.035, 0.045, 0.016), 0.003)
	return KIT.finish(builder, p, "locker_bank", size)

## A grey fan cabinet on a plinth: a round grille on its front, a collar on top.
static func fan_unit(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("fan_unit", size), func() -> ArrayMesh: return make_fan_unit(builder, size))

static func make_fan_unit(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var top := h - 0.2
	KIT.block(p, "steel_dark", Vector3(0.0, 0.06, 0.0), Vector3(w - 0.06, 0.12, d - 0.06))
	KIT.block(p, "steel_grey", Vector3(0.0, (0.12 + top) * 0.5, 0.0), Vector3(w, top - 0.12, d - 0.02), 0.004)
	KIT.block(p, "steel_plate", Vector3(0.0, (top + h) * 0.5, -0.1), Vector3(w * 0.5, 0.18, d * 0.45), 0.004)
	for y: float in [top + 0.025, h - 0.008]:
		KIT.block(p, "steel_dark", Vector3(0, y, -0.1), Vector3(w * 0.52, 0.015, d * 0.47), 0.002)
	var y := (0.12 + top) * 0.5
	var radius := minf(w, top) * 0.32
	var face := d * 0.5 - 0.018
	KIT.cylinder(p, "steel_plate", Vector3(0.0, y, face), radius + 0.035, 0.026, 32, KIT.along_z())
	KIT.cylinder(p, "black", Vector3(0.0, y, face + 0.013), radius, 0.004, 32, KIT.along_z())
	for k in range(-8, 9):
		var dy := float(k) * radius / 9.0
		var chord := 2.0 * sqrt(radius * radius - dy * dy)
		KIT.block(p, "steel_dark", Vector3(0, y + dy, face + 0.0145), Vector3(chord, 0.012, 0.006), 0.001)
	for x: float in [-0.44, 0.44]:
		for bolt_y: float in [0.18, top - 0.07]:
			KIT.cylinder(p, "metal", Vector3(x * w, bolt_y, d * 0.5 - 0.009), 0.012, 0.005, 6, KIT.along_z())
	return KIT.finish(builder, p, "fan_unit", size)
