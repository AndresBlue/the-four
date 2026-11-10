extends RefCounted
## Stand-ins for the downloads the offices lack, and their wall and ceiling
## fittings (spec_rediseno.md 5.1, area 4c): KIT's frame, cache and materials
## (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["office_chair", office_chair(builder, Vector3(0.6, 0.95, 0.6))],
		["exec_chair", exec_chair(builder, Vector3(0.68, 1.15, 0.66))],
		["visitor_chair", visitor_chair(builder, Vector3(0.56, 0.88, 0.56))],
		["desk_lamp_banker", desk_lamp(builder, Vector3(0.36, 0.42, 0.22), "banker")],
		["desk_lamp_arm", desk_lamp(builder, Vector3(0.3, 0.5, 0.36), "arm")],
		["floor_lamp", floor_lamp(builder, Vector3(0.45, 1.6, 0.45))],
		["vending_machine", vending_machine(builder, Vector3(0.9, 1.8, 0.8))],
		["water_cooler", water_cooler(builder, Vector3(0.34, 1.45, 0.34))],
		["fridge", fridge(builder, Vector3(0.6, 1.6, 0.65))],
		["coffee_maker", coffee_maker(builder, Vector3(0.22, 0.36, 0.26))],
		["microwave", microwave(builder, Vector3(0.5, 0.3, 0.38))],
		["globe", globe(builder, Vector3(0.36, 0.5, 0.36))],
		["extinguisher", extinguisher(builder, Vector3(0.2, 0.62, 0.18))],
		["work_light", work_light(builder, Vector3(0.4, 1.5, 0.4))],
		["step_ladder", step_ladder(builder, Vector3(0.5, 1.4, 0.6))],
		["plant_pot_steel_dark", plant_pot(builder, Vector3(0.4, 0.38, 0.4), "steel_dark")],
		["plant_pot_ceramic", plant_pot(builder, Vector3(0.2, 0.16, 0.2), "ceramic")],
		["plant_stand_in", plant_stand_in(builder, Vector3(0.6, 0.9, 0.6))],
		["ceiling_diffuser", ceiling_diffuser(builder, Vector3(0.6, 0.05, 0.6))],
		["hose_cabinet", hose_cabinet(builder, Vector3(0.65, 0.75, 0.16))],
		["wall_fountain", wall_fountain(builder, Vector3(0.4, 0.4, 0.2))],
		["thermostat", thermostat(builder, Vector3(0.09, 0.13, 0.03))],
		["coat_hanging", coat_hanging(builder, Vector3(0.5, 0.95, 0.14))],
		["towel", towel(builder, Vector3(0.3, 0.55, 0.04))],
	]

## Swivel office chair on five casters, with a navy cloth seat and back.
static func office_chair(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("office_chair", size), func() -> ArrayMesh: return make_office_chair(builder, size))

static func make_office_chair(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	for k in 5:
		var a := TAU * k / 5
		KIT.block(p, "black", Vector3(sin(a) * w * 0.22, 0.06, cos(a) * w * 0.22), Vector3(0.05, 0.03, w * 0.44), 0.005, Basis(Vector3.UP, a))
		KIT.cylinder(p, "black", Vector3(sin(a) * w * 0.4, 0.025, cos(a) * w * 0.4), 0.025, 0.03, 8, KIT.along_x())
	KIT.cylinder(p, "metal", Vector3(0, 0.24, 0), 0.025, 0.36, 10)
	KIT.block(p, "cloth_navy", Vector3(0, 0.46, 0.02), Vector3(w * 0.8, 0.08, d * 0.78), 0.02)
	KIT.block(p, "black", Vector3(0, 0.56, -d * 0.36), Vector3(0.05, 0.16, 0.03))
	KIT.block(p, "cloth_navy", Vector3(0, h - 0.2, -d * 0.4), Vector3(w * 0.72, 0.36, 0.07), 0.02)
	return KIT.finish(builder, p, "office_chair", size)

## Executive armchair: leather seat, tall buttoned back and arms, on five casters.
static func exec_chair(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("exec_chair", size), func() -> ArrayMesh: return make_exec_chair(builder, size))

static func make_exec_chair(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	for k in 5:
		var a := TAU * k / 5
		KIT.block(p, "black", Vector3(sin(a) * w * 0.22, 0.06, cos(a) * w * 0.22), Vector3(0.05, 0.03, w * 0.44), 0.005, Basis(Vector3.UP, a))
		KIT.cylinder(p, "black", Vector3(sin(a) * w * 0.4, 0.025, cos(a) * w * 0.4), 0.025, 0.03, 8, KIT.along_x())
	KIT.cylinder(p, "metal", Vector3(0, 0.24, 0), 0.028, 0.36, 10)
	KIT.block(p, "leather", Vector3(0, 0.47, 0.03), Vector3(w * 0.78, 0.1, d * 0.76), 0.03)
	KIT.block(p, "leather", Vector3(0, h * 0.68, -d * 0.38), Vector3(w * 0.74, h * 0.52, 0.1), 0.03)
	for r in 3:
		for c in 3:
			KIT.cylinder(p, "black", Vector3(-w * 0.2 + c * w * 0.2, h * 0.55 + r * h * 0.13, -d * 0.38 + 0.052), 0.008, 0.006, 6, KIT.along_z())
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "leather", Vector3(s * w * 0.42, 0.64, 0.0), Vector3(0.07, 0.07, d * 0.6), 0.02)
		KIT.block(p, "black", Vector3(s * w * 0.42, 0.56, 0.05), Vector3(0.03, 0.1, 0.04))
	return KIT.finish(builder, p, "exec_chair", size)

## Walnut visitor chair with a leather seat and back, for the desks and the boardroom.
static func visitor_chair(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("visitor_chair", size), func() -> ArrayMesh: return make_visitor_chair(builder, size))

static func make_visitor_chair(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var d := size.z
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KIT.block(p, "walnut_object", Vector3(sx * (w / 2 - 0.03), 0.22, sz * (d / 2 - 0.03)), Vector3(0.035, 0.44, 0.035), 0.004)
	KIT.block(p, "leather", Vector3(0, 0.47, 0.0), Vector3(w - 0.04, 0.07, d - 0.06), 0.015)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "walnut_object", Vector3(s * (w / 2 - 0.03), 0.66, -d / 2 + 0.035), Vector3(0.035, 0.44, 0.035), 0.004)
		KIT.block(p, "walnut_object", Vector3(s * (w / 2 - 0.03), 0.66, 0.0), Vector3(0.05, 0.03, d - 0.06), 0.006)
		KIT.block(p, "walnut_object", Vector3(s * (w / 2 - 0.03), 0.57, d / 2 - 0.05), Vector3(0.03, 0.15, 0.03), 0.004)
	KIT.block(p, "leather", Vector3(0, 0.7, -d / 2 + 0.04), Vector3(w - 0.1, 0.3, 0.04), 0.012)
	return KIT.finish(builder, p, "visitor_chair", size)

## Desk lamp: a banker's brass lamp with a green shade, or a black arm lamp.
static func desk_lamp(builder: Node3D, size: Vector3, look: String) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("desk_lamp", size, look), func() -> ArrayMesh: return make_desk_lamp(builder, size, look))

static func make_desk_lamp(builder: Node3D, size: Vector3, look: String) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	if look == "banker":
		KIT.block(p, "gold", Vector3(0, 0.012, 0), Vector3(w * 0.6, 0.024, d * 0.7), 0.006)
		KIT.cylinder(p, "gold", Vector3(0, (0.024 + h - 0.07) / 2, -d * 0.15), 0.01, h - 0.094, 8)
		KIT.cylinder(p, "gold", Vector3(0, h - 0.07, -d * 0.075), 0.008, d * 0.25, 8, KIT.along_z())
		KIT.cylinder(p, "cloth_green", Vector3(0, h - 0.07, 0.02), 0.07, w - 0.02, 12, KIT.along_x())
		KIT.block(p, "lamp_off", Vector3(0, h - 0.145, 0.02), Vector3(w - 0.08, 0.004, 0.06))
	else:
		KIT.cylinder(p, "black", Vector3(0, 0.012, 0), w * 0.4, 0.024, 16)
		KIT.block(p, "black", Vector3(0, 0.17, -0.02), Vector3(0.015, 0.3, 0.015), 0.0, Basis(Vector3.RIGHT, 0.25))
		KIT.block(p, "black", Vector3(0, 0.38, 0.06), Vector3(0.015, 0.28, 0.015), 0.0, Basis(Vector3.RIGHT, 1.0))
		KIT.cylinder(p, "black", Vector3(0, h - 0.08, d / 2 - 0.08), 0.06, 0.1, 12, Basis(Vector3.RIGHT, 0.5))
	return KIT.finish(builder, p, "desk_lamp_" + look, size)

## Floor lamp with a linen shade on a brass pole, for a corner by a sofa.
static func floor_lamp(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("floor_lamp", size), func() -> ArrayMesh: return make_floor_lamp(builder, size))

static func make_floor_lamp(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	KIT.cylinder(p, "black", Vector3(0, 0.015, 0), 0.16, 0.03, 16)
	KIT.cylinder(p, "gold", Vector3(0, 0.65, 0), 0.012, 1.24, 8)
	KIT.cylinder(p, "linen", Vector3(0, h - 0.16, 0), w * 0.5 - 0.005, 0.3, 16)
	KIT.cylinder(p, "lamp_off", Vector3(0, h - 0.315, 0), w * 0.5 - 0.03, 0.004, 16)
	return KIT.finish(builder, p, "floor_lamp", size)

## Vending machine of dark steel with a screen window, for the break room.
static func vending_machine(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("vending_machine", size), func() -> ArrayMesh: return make_vending_machine(builder, size))

static func make_vending_machine(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "steel_dark", Vector3(0, h / 2, -0.02), Vector3(w, h, d - 0.04), 0.01)
	KIT.block(p, "black", Vector3(-0.1, 1.05, d / 2 - 0.035), Vector3(w * 0.62, 1.15, 0.03))
	KIT.block(p, "screen", Vector3(-0.1, 1.05, d / 2 - 0.018), Vector3(w * 0.56, 1.05, 0.004))
	for r in 5:
		var key: String = "cloth_red" if r % 2 == 0 else "plastic_beige"
		KIT.block(p, key, Vector3(-0.1, 0.62 + r * 0.21, d / 2 - 0.011), Vector3(w * 0.5, 0.05, 0.006))
	KIT.block(p, "metal", Vector3(w / 2 - 0.12, 1.15, d / 2 - 0.03), Vector3(0.14, 0.5, 0.04), 0.004)
	for k in 6:
		KIT.block(p, "black", Vector3(w / 2 - 0.12, 1.33 - k * 0.07, d / 2 - 0.008), Vector3(0.06, 0.03, 0.006))
	KIT.block(p, "black", Vector3(w / 2 - 0.12, 0.82, d / 2 - 0.008), Vector3(0.03, 0.06, 0.006))
	KIT.block(p, "black", Vector3(-0.1, 0.25, d / 2 - 0.03), Vector3(w * 0.5, 0.18, 0.04))
	return KIT.finish(builder, p, "vending_machine", size)

## Water cooler: a beige body with a dark water bottle on top, for the break room.
static func water_cooler(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("water_cooler", size), func() -> ArrayMesh: return make_water_cooler(builder, size))

static func make_water_cooler(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "plastic_beige", Vector3(0, 0.5, -0.02), Vector3(w, 1.0, d - 0.04), 0.012)
	KIT.block(p, "plastic_beige", Vector3(0, 1.03, 0), Vector3(w - 0.04, 0.06, d - 0.04), 0.01)
	KIT.cylinder(p, "screen", Vector3(0, 1.24, 0), 0.14, 0.36, 16)
	KIT.cylinder(p, "screen", Vector3(0, h - 0.015, 0), 0.05, 0.03, 12)
	KIT.block(p, "cloth_red", Vector3(-0.06, 0.88, d / 2 - 0.025), Vector3(0.03, 0.04, 0.03))
	KIT.block(p, "cloth_navy", Vector3(0.06, 0.88, d / 2 - 0.025), Vector3(0.03, 0.04, 0.03))
	KIT.block(p, "black", Vector3(0, 0.72, d / 2 - 0.04), Vector3(0.2, 0.02, 0.08))
	return KIT.finish(builder, p, "water_cooler", size)

## Fridge with two handles, for the break room.
static func fridge(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("fridge", size), func() -> ArrayMesh: return make_fridge(builder, size))

static func make_fridge(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "ceramic", Vector3(0, h / 2, -0.01), Vector3(w, h, d - 0.02), 0.02)
	KIT.block(p, "black", Vector3(0, 1.12, d / 2 - 0.024), Vector3(w - 0.02, 0.006, 0.006))
	KIT.block(p, "metal", Vector3(w / 2 - 0.06, 1.35, d / 2 - 0.012), Vector3(0.025, 0.3, 0.02), 0.004)
	KIT.block(p, "metal", Vector3(w / 2 - 0.06, 0.95, d / 2 - 0.012), Vector3(0.025, 0.2, 0.02), 0.004)
	KIT.block(p, "black", Vector3(0, 0.04, d / 2 - 0.04), Vector3(w - 0.04, 0.08, 0.02))
	return KIT.finish(builder, p, "fridge", size)

## Filter coffee maker with its jug, on the break room counter.
static func coffee_maker(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("coffee_maker", size), func() -> ArrayMesh: return make_coffee_maker(builder, size))

static func make_coffee_maker(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "black", Vector3(0, 0.02, 0), Vector3(w, 0.04, d), 0.006)
	KIT.block(p, "black", Vector3(0, h / 2, -d / 2 + 0.05), Vector3(w, h, 0.1), 0.01)
	KIT.block(p, "black", Vector3(0, h - 0.04, 0.0), Vector3(w, 0.08, d - 0.02), 0.01)
	KIT.cylinder(p, "screen", Vector3(0, 0.12, 0.05), 0.065, 0.16, 12)
	KIT.block(p, "black", Vector3(0.08, 0.12, 0.05), Vector3(0.015, 0.1, 0.02))
	return KIT.finish(builder, p, "coffee_maker", size)

## Old beige microwave, on the break room counter.
static func microwave(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("microwave", size), func() -> ArrayMesh: return make_microwave(builder, size))

static func make_microwave(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "plastic_beige", Vector3(0, h / 2, -0.01), Vector3(w, h, d - 0.02), 0.01)
	KIT.block(p, "screen", Vector3(-0.07, h / 2, 0.172), Vector3(w * 0.6, h * 0.62, 0.004))
	KIT.block(p, "metal", Vector3(w / 2 - 0.07, h / 2, 0.172), Vector3(0.1, h - 0.04, 0.004))
	for k in 2:
		KIT.cylinder(p, "black", Vector3(w / 2 - 0.07, h * 0.68 - k * 0.1, 0.18), 0.018, 0.012, 12, KIT.along_z())
	KIT.block(p, "metal", Vector3(w * 0.24, h / 2, 0.18), Vector3(0.015, h * 0.5, 0.02))
	return KIT.finish(builder, p, "microwave", size)

## Old globe on a walnut foot, for the top of a sideboard.
static func globe(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("globe", size), func() -> ArrayMesh: return make_globe(builder, size))

static func make_globe(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var r_big := w / 2 - 0.01
	var cy := h - r_big - 0.01
	KIT.cylinder(p, "walnut_object", Vector3(0, 0.015, 0), 0.12, 0.03, 16)
	KIT.cylinder(p, "gold", Vector3(0, 0.09, 0), 0.012, 0.12, 8)
	for k in 7:
		var t := -0.9 + 0.3 * k
		KIT.cylinder(p, "cardboard", Vector3(0, cy + t * r_big, 0), r_big * sqrt(1.0 - t * t), r_big * 0.28, 16)
	return KIT.finish(builder, p, "globe", size)

## Red fire extinguisher on its wall bracket, for the corridors.
static func extinguisher(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("extinguisher", size), func() -> ArrayMesh: return make_extinguisher(builder, size))

static func make_extinguisher(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var d := size.z
	KIT.block(p, "metal", Vector3(0, 0.42, -d / 2 + 0.01), Vector3(0.06, 0.12, 0.02))
	KIT.cylinder(p, "paint_red", Vector3(0, 0.27, 0.0), 0.075, 0.5, 16)
	KIT.block(p, "black", Vector3(0, 0.55, 0.0), Vector3(0.05, 0.06, 0.05))
	KIT.block(p, "black", Vector3(0.0, 0.6, 0.02), Vector3(0.12, 0.015, 0.03))
	KIT.cylinder(p, "black", Vector3(w / 2 - 0.015, 0.33, 0.03), 0.01, 0.5, 8)
	return KIT.finish(builder, p, "extinguisher", size, {"wall": true, "mount": 0.3})

## Work light on a tripod, for the store and the depot.
static func work_light(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("work_light", size), func() -> ArrayMesh: return make_work_light(builder, size))

static func make_work_light(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var h := size.y
	for k in 3:
		var a := TAU * k / 3
		KIT.block(p, "black", Vector3(sin(a) * 0.085, 0.42, cos(a) * 0.085), Vector3(0.02, 0.85, 0.02), 0.0, Basis(Vector3(cos(a), 0, -sin(a)), -0.25))
	KIT.cylinder(p, "metal", Vector3(0, 1.05, 0), 0.012, 0.5, 8)
	KIT.block(p, "metal", Vector3(0, 1.3, 0.0), Vector3(0.34, 0.02, 0.02))
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "metal", Vector3(s * 0.16, 1.33, 0.0), Vector3(0.02, 0.08, 0.02))
	KIT.block(p, "black", Vector3(0, h - 0.13, 0.05), Vector3(0.3, 0.24, 0.12), 0.01)
	KIT.block(p, "lamp_off", Vector3(0, h - 0.13, 0.113), Vector3(0.26, 0.2, 0.006))
	return KIT.finish(builder, p, "work_light", size)

## Aluminum step ladder, for the store and the depot.
static func step_ladder(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("step_ladder", size), func() -> ArrayMesh: return make_step_ladder(builder, size))

static func make_step_ladder(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "metal", Vector3(s * (w / 2 - 0.02), 0.695, 0.13), Vector3(0.03, 1.4, 0.06), 0.0, Basis(Vector3.RIGHT, -0.2))
		KIT.block(p, "metal", Vector3(s * (w / 2 - 0.02), 0.695, -0.13), Vector3(0.03, 1.4, 0.04), 0.0, Basis(Vector3.RIGHT, 0.2))
	for k in 4:
		var y := 0.3 + k * 0.3
		KIT.block(p, "metal", Vector3(0, y, 0.269 - 0.2027 * y), Vector3(w - 0.06, 0.025, 0.08))
	KIT.block(p, "metal", Vector3(0, 1.36, 0.0), Vector3(w - 0.04, 0.03, 0.16))
	return KIT.finish(builder, p, "step_ladder", size)

## Round pot with its soil, for the plant that stands on top of it.
static func plant_pot(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("plant_pot", size, key), func() -> ArrayMesh: return make_plant_pot(builder, size, key))

static func make_plant_pot(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	KIT.cylinder(p, key, Vector3(0, (h - 0.01) / 2, 0), w / 2, h - 0.01, 20)
	KIT.cylinder(p, "black", Vector3(0, h - 0.005, 0), w / 2 - 0.02, 0.01, 20)
	return KIT.finish(builder, p, "plant_pot_" + key, size)

## Steel pot with leaves, standing in for a plant.
static func plant_stand_in(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("plant_stand_in", size), func() -> ArrayMesh: return make_plant_stand_in(builder, size))

static func make_plant_stand_in(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	KIT.cylinder(p, "steel_dark", Vector3(0, 0.18, 0), 0.18, 0.36, 16)
	for k in 8:
		var a := TAU * k / 8
		var tilt := 0.35 + 0.3 * KIT.hash01(k, 51)
		KIT.block(p, "cloth_green", Vector3(sin(a) * 0.12, 0.36 + 0.25 * cos(tilt), cos(a) * 0.12), Vector3(0.14, 0.5, 0.01), 0.0, Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, tilt))
	return KIT.finish(builder, p, "plant_stand_in", size)

## Square ceiling diffuser, 60 cm, beside the light panels.
static func ceiling_diffuser(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("ceiling_diffuser", size), func() -> ArrayMesh: return make_ceiling_diffuser(builder, size))

static func make_ceiling_diffuser(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "metal", Vector3(0, h - 0.004, 0), Vector3(w - 0.005, 0.008, d - 0.005))
	for k in 4:
		var s := w * (0.9 - k * 0.2)
		KIT.block(p, "metal", Vector3(0, h - 0.013 - k * 0.01, 0), Vector3(s, 0.01, s), 0.002)
	return KIT.finish(builder, p, "ceiling_diffuser", size)

## Red hose cabinet with a glass door, on a corridor wall.
static func hose_cabinet(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("hose_cabinet", size), func() -> ArrayMesh: return make_hose_cabinet(builder, size))

static func make_hose_cabinet(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "paint_red", Vector3(0, h / 2, -0.02), Vector3(w, h, d - 0.04), 0.006)
	KIT.block(p, "paint_red", Vector3(0, h - 0.03, d / 2 - 0.03), Vector3(w, 0.06, 0.02))
	KIT.block(p, "paint_red", Vector3(0, 0.03, d / 2 - 0.03), Vector3(w, 0.06, 0.02))
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "paint_red", Vector3(s * (w / 2 - 0.03), h / 2, d / 2 - 0.03), Vector3(0.06, h - 0.12, 0.02))
	KIT.cylinder(p, "cloth_red", Vector3(0, h / 2 + 0.05, 0.041), 0.2, 0.002, 20, KIT.along_z())
	KIT.cylinder(p, "metal", Vector3(0, h / 2 + 0.05, 0.0415), 0.05, 0.002, 12, KIT.along_z())
	KIT.block(p, "screen", Vector3(0, h / 2, d / 2 - 0.035), Vector3(w - 0.12, h - 0.12, 0.004))
	KIT.block(p, "metal", Vector3(w / 2 - 0.05, h / 2, d / 2 - 0.012), Vector3(0.02, 0.1, 0.02))
	KIT.block(p, "paper", Vector3(0, 0.03, d / 2 - 0.019), Vector3(0.2, 0.03, 0.002))
	return KIT.finish(builder, p, "hose_cabinet", size, {"wall": true, "mount": 1.0})

## Steel wall fountain with its push tap, on a corridor wall.
static func wall_fountain(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("wall_fountain", size), func() -> ArrayMesh: return make_wall_fountain(builder, size))

static func make_wall_fountain(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "metal", Vector3(0, h / 2, -d / 2 + 0.01), Vector3(w, h, 0.02), 0.004)
	KIT.block(p, "metal", Vector3(0, h * 0.3, -0.03), Vector3(w * 0.6, h * 0.4, d - 0.08), 0.01)
	KIT.block(p, "metal", Vector3(0, h * 0.62, 0.0), Vector3(w - 0.04, 0.12, d - 0.02), 0.015)
	KIT.block(p, "black", Vector3(0, h * 0.62 + 0.0605, 0.0), Vector3(w - 0.1, 0.002, d - 0.08))
	KIT.cylinder(p, "metal", Vector3(0.06, h * 0.62 + 0.08, 0.0), 0.008, 0.04, 8)
	KIT.block(p, "black", Vector3(w / 2 - 0.03, h * 0.62, d / 2 - 0.005), Vector3(0.03, 0.03, 0.01))
	return KIT.finish(builder, p, "wall_fountain", size, {"wall": true, "mount": 0.75})

## Wall thermostat in beige plastic, for the corridors.
static func thermostat(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("thermostat", size), func() -> ArrayMesh: return make_thermostat(builder, size))

static func make_thermostat(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "plastic_beige", Vector3(0, h / 2, -0.003), Vector3(w, h, d - 0.006), 0.004)
	KIT.cylinder(p, "metal", Vector3(0, h * 0.55, d / 2 - 0.005), 0.025, 0.008, 12, KIT.along_z())
	KIT.block(p, "black", Vector3(0, h * 0.2, d / 2 - 0.006), Vector3(0.04, 0.008, 0.002))
	return KIT.finish(builder, p, "thermostat", size, {"wall": true, "mount": 1.5})

## Navy coat hung on a hook, on a washroom wall.
static func coat_hanging(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("coat_hanging", size), func() -> ArrayMesh: return make_coat_hanging(builder, size))

static func make_coat_hanging(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "cloth_navy", Vector3(0, h - 0.08, 0), Vector3(w * 0.8, 0.1, d - 0.02), 0.03)
	KIT.block(p, "cloth_navy", Vector3(0, h * 0.48, 0.0), Vector3(w * 0.9, h * 0.8, d - 0.04), 0.03)
	KIT.block(p, "cloth_navy", Vector3(0, h - 0.03, -0.01), Vector3(0.14, 0.06, 0.06))
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "cloth_navy", Vector3(s * (w / 2 - 0.04), h * 0.5, 0.01), Vector3(0.08, h * 0.62, d - 0.06), 0.02)
	return KIT.finish(builder, p, "coat_hanging", size, {"wall": true, "mount": 0.75})

## Folded towel over a hook, on a washroom wall.
static func towel(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("towel", size), func() -> ArrayMesh: return make_towel(builder, size))

static func make_towel(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "linen", Vector3(0, h / 2, -d / 4), Vector3(w, h, d / 2), 0.003)
	KIT.block(p, "linen", Vector3(0, h * 0.75, d / 4), Vector3(w, h / 2, d / 2), 0.003)
	return KIT.finish(builder, p, "towel", size, {"wall": true, "mount": 1.1})
