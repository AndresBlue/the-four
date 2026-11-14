extends RefCounted
## The bank of padlocked lockers (spec_proporcion D7): KIT's frame, cache and
## materials (pieces/kit.gd). It neither opens nor looks as if it did: the
## lockers players hide in are of another make. (The air rooms' units are a
## download, office_models.gd "fan_unit".)
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["locker_bank", locker_bank(builder, Vector3(2.7, 1.9, 0.45))],
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
