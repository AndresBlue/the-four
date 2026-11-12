extends RefCounted
## Washroom cubicles and basin, rugs, curtain and blind (spec_rediseno.md 5.1,
## area 4a): KIT's frame, cache and materials (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["toilet_cubicles_3", toilet_cubicles(builder, Vector3(2.7, 2.0, 1.5), 3)],
		["basin", basin(builder, Vector3(0.55, 0.92, 0.45))],
		["rug_carpet_exec", rug(builder, Vector3(3.0, 0.012, 2.0), "carpet_exec")],
		["rug_black", rug(builder, Vector3(1.2, 0.012, 0.8), "black")],
		["curtain", curtain(builder, Vector3(1.4, 2.1, 0.12))],
		["blind", blind(builder, Vector3(1.2, 1.0, 0.04))],
	]

## A row of washroom cabins, a toilet in each, their doors on +Z.
static func toilet_cubicles(builder: Node3D, size: Vector3, count: int) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("toilet_cubicles", size, str(count)), func() -> ArrayMesh: return make_toilet_cubicles(builder, size, count))

static func make_toilet_cubicles(builder: Node3D, size: Vector3, count: int) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var z_f := d * 0.5 - 0.04
	var cw := (w - 0.025) / count
	var hp := h - 0.19
	var ym := (0.15 + h - 0.04) / 2.0
	# Side panels, one more than there are cabins, each with its steel foot.
	for k in count + 1:
		var x := -w * 0.5 + 0.0125 + cw * k
		KIT.block(p, "laminate_light", Vector3(x, ym, (-d * 0.5 + z_f - 0.0125) / 2.0), Vector3(0.025, hp, z_f - 0.0125 + d * 0.5), 0.004)
		KIT.cylinder(p, "metal", Vector3(x, 0.075, z_f - 0.06), 0.012, 0.15, 8)
	for k in count:
		var left := -w * 0.5 + 0.0125 + cw * k + 0.0125
		var right := left + cw - 0.025
		var cx := (left + right) / 2.0
		var inner := right - left
		# Each cabin's two posts, with their feet.
		for xp: float in [left + 0.05, right - 0.05]:
			KIT.block(p, "laminate_light", Vector3(xp, ym, z_f), Vector3(0.1, hp, 0.025), 0.004)
			KIT.cylinder(p, "metal", Vector3(xp, 0.075, z_f), 0.015, 0.15, 8)
		# The door, its latch, and the toilet with its cistern.
		KIT.block(p, "laminate_light", Vector3(cx, (0.15 + h - 0.05) / 2.0, z_f), Vector3(inner - 0.208, h - 0.2, 0.022), 0.004)
		KIT.block(p, "metal", Vector3(cx + (inner - 0.208) * 0.4, 1.0, z_f + 0.017), Vector3(0.02, 0.06, 0.012))
		KIT.cylinder(p, "ceramic", Vector3(cx, 0.2, -d * 0.5 + 0.35), 0.18, 0.4, 16)
		KIT.cylinder(p, "plastic_beige", Vector3(cx, 0.41, -d * 0.5 + 0.35), 0.19, 0.02, 16)
		KIT.block(p, "ceramic", Vector3(cx, 0.75, -d * 0.5 + 0.09), Vector3(0.4, 0.38, 0.16), 0.02)
	# The head rail, along the top of the cabins.
	KIT.block(p, "metal", Vector3(0.0, h - 0.02, z_f), Vector3(w, 0.04, 0.03))
	return KIT.finish(builder, p, "toilet_cubicles_%d" % count, size)

## A standing washbasin with its tap, for the washroom wall.
static func basin(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("basin", size), func() -> ArrayMesh: return make_basin(builder, size))

static func make_basin(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var r_y := h - 0.1
	var z_c := 0.02
	# The rim: front, back and the two sides of the basin's top.
	KIT.block(p, "ceramic", Vector3(0.0, r_y - 0.04, d * 0.5 - 0.04), Vector3(w, 0.08, 0.08), 0.012)
	KIT.block(p, "ceramic", Vector3(0.0, r_y - 0.04, -d * 0.5 + 0.06), Vector3(w, 0.08, 0.12), 0.012)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "ceramic", Vector3(s * (w * 0.5 - 0.04), r_y - 0.04, z_c), Vector3(0.08, 0.08, d - 0.2))
	# The bowl, its pedestal and the drain.
	KIT.block(p, "ceramic", Vector3(0.0, r_y - 0.14, 0.0), Vector3(w - 0.02, 0.12, d - 0.02), 0.02)
	KIT.cylinder(p, "metal", Vector3(0.0, r_y - 0.0795, z_c), 0.02, 0.001, 12)
	KIT.cylinder(p, "ceramic", Vector3(0.0, (r_y - 0.2) / 2.0, -d * 0.5 + 0.12), 0.09, r_y - 0.2, 16)
	# The tap: its base, its spout and two handles.
	KIT.cylinder(p, "metal", Vector3(0.0, r_y + 0.04, -d * 0.5 + 0.06), 0.014, 0.08, 10)
	KIT.cylinder(p, "metal", Vector3(0.0, r_y + 0.075, -d * 0.5 + 0.11), 0.01, 0.1, 10, KIT.along_z())
	for s: float in [-1.0, 1.0]:
		KIT.cylinder(p, "metal", Vector3(s * 0.08, r_y + 0.02, -d * 0.5 + 0.06), 0.018, 0.04, 8)
	return KIT.finish(builder, p, "basin", size)

## An office wall lamp of 1987: an opal glass box between brass caps on a
## brass back plate, its back at z 0 and its middle at y 0 (the reception's
## lift, office_geometry.arrival_lift()). The glass glows with its room.
static func box_sconce(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("box_sconce", size), func() -> ArrayMesh: return make_box_sconce(builder, size))

static func make_box_sconce(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "gold", Vector3(0.0, 0.0, 0.006), Vector3(w, h, 0.012), 0.002)
	KIT.block(p, "glow_strip", Vector3(0.0, 0.0, 0.012 + (d - 0.012) * 0.5), Vector3(w - 0.03, h - 0.05, d - 0.012), 0.004)
	for s: float in [-1.0, 1.0]: KIT.block(p, "gold", Vector3(0.0, s * (h * 0.5 - 0.0125), 0.012 + (d - 0.012) * 0.5), Vector3(w - 0.02, 0.025, d - 0.008), 0.003)
	return KIT.finish(builder, p, "box_sconce", size, {"solid": false})

## A rug of `key`'s material, fringed at both ends of its width.
static func rug(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("rug", size, key), func() -> ArrayMesh: return make_rug(builder, size, key))

static func make_rug(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, key, Vector3(0.0, h * 0.5, 0.0), Vector3(w - 0.06, h, d), minf(0.004, h * 0.4))
	# The fringe: thin linen strands in a row at each end, outside the body;
	# none on a ribbed door mat.
	for s: float in ([] if key.begins_with("mat") else [-1.0, 1.0]):
		for k in int(d / 0.02):
			KIT.block(p, "linen", Vector3(s * (w * 0.5 - 0.015), 0.001, -d * 0.5 + 0.01 + k * 0.02), Vector3(0.03, 0.002, 0.006))
	return KIT.finish(builder, p, "rug_" + key, size, {"solid": false})

## A pleated velvet curtain on its rod, standing from the floor: no wall piece.
static func curtain(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("curtain", size), func() -> ArrayMesh: return make_curtain(builder, size))

static func make_curtain(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var n := maxi(4, int(w / 0.08))
	var pwid := (w / n) / cos(0.5)
	# Pleats turned alternately a little either way, so the folds read.
	for k in n:
		var yaw: float = 0.5 if k % 2 == 0 else -0.5
		KIT.block(p, "fabric", Vector3(-w * 0.5 + w * (k + 0.5) / n, (h - 0.03) / 2.0, 0.0), Vector3(pwid, h - 0.03, 0.006), 0.0, Basis(Vector3.UP, yaw))
	KIT.cylinder(p, "metal", Vector3(0.0, h - 0.015, 0.0), 0.012, w, 10, KIT.along_x())
	return KIT.finish(builder, p, "curtain", size, {"solid": false})

## A beige venetian blind for a wall, its base 1.4 m up (the meta says so).
static func blind(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("blind", size), func() -> ArrayMesh: return make_blind(builder, size))

static func make_blind(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "plastic_beige", Vector3(0.0, h - 0.02, 0.0), Vector3(w, 0.04, d), 0.004)
	# The slats, each tilted the same way.
	var n := int((h - 0.08) / 0.025)
	for k in n:
		KIT.block(p, "plastic_beige", Vector3(0.0, h - 0.05 - k * 0.025, 0.0), Vector3(w - 0.01, 0.002, 0.025), 0.0, Basis(Vector3.RIGHT, 0.35))
	var yb := h - 0.06 - n * 0.025
	KIT.block(p, "plastic_beige", Vector3(0.0, yb, 0.0), Vector3(w, 0.012, 0.025), 0.002)
	# The cords, from the bottom rail up to the head.
	for s: float in [-1.0, 1.0]:
		KIT.cylinder(p, "linen", Vector3(s * w * 0.3, (yb + h - 0.04) / 2.0, 0.0), 0.0015, h - 0.04 - yb, 4)
	return KIT.finish(builder, p, "blind", size, {"wall": true, "mount": 1.4, "solid": false})
