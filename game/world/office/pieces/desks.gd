extends RefCounted
## Desks, tables and counters (spec_rediseno.md 5.1, area 4a): KIT's frame,
## cache and materials (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["desk_walnut", desk_walnut(builder, Vector3(1.6, 0.75, 0.8))],
		["desk_l", desk_l(builder, Vector3(1.6, 0.74, 1.4))],
		["desk_l_walnut", desk_l_walnut(builder, Vector3(1.8, 0.75, 1.5))],
		["desk_steel", desk_steel(builder, Vector3(1.5, 0.75, 0.75))],
		["security_desk", security_desk(builder, Vector3(3.0, 0.87, 0.8))],
		["meeting_table", meeting_table(builder, Vector3(3.6, 0.75, 1.2))],
		["dining_table", dining_table(builder, Vector3(1.2, 0.74, 0.8))],
		["sorting_table", sorting_table(builder, Vector3(2.0, 1.02, 0.9))],
		["consult_table", consult_table(builder, Vector3(1.4, 0.74, 0.7))],
		["reception_counter", reception_counter(builder, Vector3(2.4, 1.1, 1.5))],
		["front_desk", front_desk(builder, Vector3(3.4, 1.08, 0.8))],
		["low_table", low_table(builder, Vector3(0.9, 0.42, 0.5))],
	]

## A walnut desk: a drawer pedestal on the right, a pencil drawer and a back panel.
static func desk_walnut(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("desk_walnut", size), func() -> ArrayMesh: return make_desk_walnut(builder, size))

static func make_desk_walnut(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var zf := d * 0.5 - KIT.FRONT
	var t := 0.035
	var top_y := h - t
	var pw := minf(0.42, w * 0.3)
	var px := w / 2.0 - 0.01 - pw / 2.0
	var zb := -d / 2.0 + 0.02
	var cz := (zb + zf) / 2.0
	var cd := zf - zb
	var xl := -w / 2.0 + 0.06
	var xr := w / 2.0 - 0.01 - pw
	KIT.block(p, "walnut_object", Vector3(0.0, h - t / 2.0, 0.0), Vector3(w, t, d), 0.006)
	KIT.block(p, "walnut_object", Vector3(px, (0.06 + top_y) / 2.0, cz), Vector3(pw, top_y - 0.06, cd), 0.003)
	KIT.block(p, "black", Vector3(px, 0.03, cz - 0.03), Vector3(pw - 0.04, 0.06, cd - 0.08))
	var each := (top_y - 0.06) / 3.0
	for i in 3:
		KIT.front(p, "walnut_object", Vector3(px, 0.06 + each * (i + 0.5), zf), Vector2(pw, each), "bar", "gold", each * 0.2, false, 0.015)
	KIT.block(p, "walnut_object", Vector3(-w / 2.0 + 0.035, top_y / 2.0, cz), Vector3(0.05, top_y, cd), 0.003)
	KIT.block(p, "walnut_object", Vector3((xl + xr) / 2.0, (0.3 + top_y) / 2.0, -d / 2.0 + 0.06), Vector3(xr - xl, top_y - 0.3, 0.02))
	KIT.block(p, "walnut_object", Vector3((xl + xr) / 2.0, top_y - 0.045, (-d / 2.0 + 0.08 + zf) / 2.0), Vector3(xr - xl - 0.02, 0.08, zf + d / 2.0 - 0.08))
	KIT.front(p, "walnut_object", Vector3((xl + xr) / 2.0, top_y - 0.045, zf), Vector2(minf(0.6, xr - xl - 0.1), 0.08), "knob", "gold", 0.0, false, 0.015)
	return KIT.finish(builder, p, "desk_walnut", size)

## An L-shaped laminate desk: a main run with a return on the right.
static func desk_l(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("desk_l", size), func() -> ArrayMesh: return make_desk_l(builder, size, "desk_l", "laminate_light", "laminate_light", "metal"))

## desk_l in walnut, with gold pulls.
static func desk_l_walnut(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("desk_l_walnut", size), func() -> ArrayMesh: return make_desk_l(builder, size, "desk_l_walnut", "walnut_object", "walnut_object", "gold"))

## The L desk's two runs as colliders, the main one and the return.
static func make_desk_l(builder: Node3D, size: Vector3, title: String, top_key: String, body_key: String, pull_key: String) -> ArrayMesh:
	const RET := 0.6
	const MAIN := 0.75
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var t := 0.03
	var top_y := h - t
	KIT.block(p, top_key, Vector3(0.0, h - t / 2.0, -d / 2.0 + MAIN / 2.0), Vector3(w, t, MAIN), 0.012)
	KIT.block(p, top_key, Vector3(w / 2.0 - RET / 2.0, h - t / 2.0, MAIN / 2.0), Vector3(RET, t, d - MAIN), 0.012)
	KIT.block(p, body_key, Vector3(-w / 2.0 + 0.0125, top_y / 2.0, -d / 2.0 + MAIN / 2.0), Vector3(0.025, top_y, MAIN - 0.02), 0.003)
	KIT.block(p, body_key, Vector3(w / 2.0 - RET / 2.0, top_y / 2.0, d / 2.0 - 0.0225), Vector3(RET - 0.02, top_y, 0.025), 0.003)
	KIT.block(p, body_key, Vector3(w / 2.0 - RET + 0.03, top_y / 2.0, -d / 2.0 + MAIN - 0.03), Vector3(0.05, top_y, 0.05), 0.004)
	KIT.block(p, body_key, Vector3(0.005, (0.3 + top_y) / 2.0, -d / 2.0 + 0.03), Vector3(w - 0.035, top_y - 0.3, 0.018))
	KIT.block(p, body_key, Vector3(w / 2.0 - 0.02, (0.3 + top_y) / 2.0, (MAIN - 0.035) / 2.0), Vector3(0.018, top_y - 0.3, d - MAIN - 0.035))
	var px := -w / 2.0 + 0.23
	var pw := 0.4
	var zb := -d / 2.0 + 0.05
	var pzf := -d / 2.0 + MAIN - KIT.FRONT
	var cz := (zb + pzf) / 2.0
	var cd := pzf - zb
	var ptop := top_y - 0.005
	KIT.block(p, body_key, Vector3(px, (0.06 + ptop) / 2.0, cz), Vector3(pw, ptop - 0.06, cd), 0.003)
	KIT.block(p, "black", Vector3(px, 0.03, cz - 0.03), Vector3(pw - 0.04, 0.06, cd - 0.08))
	var avail := ptop - 0.06
	var low := 0.06
	for hgt: float in [avail * 0.56, avail * 0.22, avail * 0.22]:
		KIT.front(p, body_key, Vector3(px, low + hgt / 2.0, pzf), Vector2(pw, hgt), "bar", pull_key, 0.0, false, 0.012)
		low += hgt
	var colliders: Array = [
		AABB(Vector3(-w / 2.0, 0.0, -d / 2.0), Vector3(w, h, MAIN)),
		AABB(Vector3(w / 2.0 - RET, 0.0, -d / 2.0 + MAIN), Vector3(RET, h, d - MAIN)),
	]
	return KIT.finish(builder, p, title, size, {"colliders": colliders})

## A steel desk on one pedestal, with a laminate top.
static func desk_steel(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("desk_steel", size), func() -> ArrayMesh: return make_steel(builder, size, "desk_steel", false, false))

## A steel security desk on two pedestals, with a raised shelf for four monitors.
static func security_desk(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("security_desk", size), func() -> ArrayMesh: return make_steel(builder, size, "security_desk", true, true))

static func make_steel(builder: Node3D, size: Vector3, title: String, both: bool, riser: bool) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var work: float = h - 0.12 if riser else h
	var under := work - 0.032
	var pw := 0.42
	var zb := -d / 2.0 + 0.02
	var zf := d * 0.5 - KIT.FRONT
	var cz := (zb + zf) / 2.0
	var cd := zf - zb
	KIT.block(p, "black", Vector3(0.0, work - 0.017, 0.0), Vector3(w, 0.03, d), 0.004)
	KIT.block(p, "laminate_light", Vector3(0.0, work - 0.002, 0.0), Vector3(w - 0.016, 0.004, d - 0.016))
	var xs: Array[float] = [w / 2.0 - 0.01 - pw / 2.0]
	if both: xs.append(-w / 2.0 + 0.01 + pw / 2.0)
	for x: float in xs:
		KIT.block(p, "steel_olive", Vector3(x, (0.03 + under) / 2.0, cz), Vector3(pw, under - 0.03, cd), 0.004)
		KIT.block(p, "black", Vector3(x, 0.015, cz - 0.02), Vector3(pw - 0.03, 0.03, cd - 0.05))
		var avail := under - 0.03
		var low := 0.03
		for hgt: float in [avail * 0.5, avail * 0.25, avail * 0.25]:
			KIT.front(p, "steel_olive", Vector3(x, low + hgt / 2.0, zf), Vector2(pw, hgt), "bar", "metal", 0.0, true, 0.012)
			low += hgt
	if not both: KIT.block(p, "steel_olive", Vector3(-w / 2.0 + 0.025, under / 2.0, cz), Vector3(0.03, under, cd), 0.003)
	var xl: float = (-w / 2.0 + 0.01 + pw) if both else (-w / 2.0 + 0.04)
	var xr := w / 2.0 - 0.01 - pw
	KIT.block(p, "steel_olive", Vector3((xl + xr) / 2.0, (0.25 + under) / 2.0, -d / 2.0 + 0.04), Vector3(xr - xl, under - 0.25, 0.015))
	if riser: KIT.block(p, "steel_olive", Vector3(0.0, work + 0.06, -d / 2.0 + 0.23), Vector3(w - 0.6, 0.12, 0.42), 0.004)
	return KIT.finish(builder, p, title, size)

## A walnut meeting table on two slab legs with black feet and a stretcher.
static func meeting_table(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("meeting_table", size), func() -> ArrayMesh: return make_meeting_table(builder, size))

static func make_meeting_table(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "walnut_object", Vector3(0.0, h - 0.0225, 0.0), Vector3(w, 0.045, d), 0.012)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "walnut_object", Vector3(s * w * 0.32, (0.05 + h - 0.045) / 2.0, 0.0), Vector3(0.06, h - 0.095, d * 0.6), 0.004)
		KIT.block(p, "black", Vector3(s * w * 0.32, 0.025, 0.0), Vector3(0.1, 0.05, d * 0.7), 0.004)
	KIT.block(p, "walnut_object", Vector3(0.0, 0.35, 0.0), Vector3(w * 0.64 - 0.06, 0.1, 0.04), 0.003)
	return KIT.finish(builder, p, "meeting_table", size)

## A laminate dining table on four metal legs, with a steel apron.
static func dining_table(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("dining_table", size), func() -> ArrayMesh: return make_dining_table(builder, size))

static func make_dining_table(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "laminate_light", Vector3(0.0, h - 0.0125, 0.0), Vector3(w, 0.025, d), 0.008)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "steel_grey", Vector3(0.0, h - 0.055, s * (d / 2.0 - 0.06)), Vector3(w - 0.12, 0.06, 0.02))
		KIT.block(p, "steel_grey", Vector3(s * (w / 2.0 - 0.06), h - 0.055, 0.0), Vector3(0.02, 0.06, d - 0.12))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KIT.cylinder(p, "metal", Vector3(sx * (w / 2.0 - 0.07), (0.01 + h - 0.025) / 2.0, sz * (d / 2.0 - 0.07)), 0.016, h - 0.035, 10)
			KIT.cylinder(p, "black", Vector3(sx * (w / 2.0 - 0.07), 0.005, sz * (d / 2.0 - 0.07)), 0.018, 0.01, 10)
	return KIT.finish(builder, p, "dining_table", size)

## The mail sorting table: an oak top on steel legs, with a lower shelf.
static func sorting_table(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("sorting_table", size), func() -> ArrayMesh: return make_sorting_table(builder, size))

static func make_sorting_table(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var work := h - 0.12
	KIT.block(p, "oak_door", Vector3(0.0, work - 0.02, 0.0), Vector3(w, 0.04, d), 0.004)
	KIT.block(p, "oak_door", Vector3(0.0, work + 0.06, -d / 2.0 + 0.01), Vector3(w, 0.12, 0.02), 0.003)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KIT.block(p, "steel_olive", Vector3(sx * (w / 2.0 - 0.05), (work - 0.04) / 2.0, sz * (d / 2.0 - 0.05)), Vector3(0.04, work - 0.04, 0.04), 0.003)
	KIT.block(p, "oak_door", Vector3(0.0, 0.2, 0.0), Vector3(w - 0.06, 0.02, d - 0.06), 0.002)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "steel_olive", Vector3(0.0, work - 0.07, s * (d / 2.0 - 0.05)), Vector3(w - 0.14, 0.05, 0.02))
		KIT.block(p, "steel_olive", Vector3(s * (w / 2.0 - 0.05), work - 0.07, 0.0), Vector3(0.02, 0.05, d - 0.14))
	return KIT.finish(builder, p, "sorting_table", size)

## A small consulting table for the archive: steel legs and a laminate top.
static func consult_table(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("consult_table", size), func() -> ArrayMesh: return make_consult_table(builder, size))

static func make_consult_table(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KIT.block(p, "steel_grey", Vector3(sx * (w / 2.0 - 0.04), (h - 0.025) / 2.0, sz * (d / 2.0 - 0.04)), Vector3(0.035, h - 0.025, 0.035), 0.003)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "steel_grey", Vector3(0.0, h - 0.055, s * (d / 2.0 - 0.04)), Vector3(w - 0.1, 0.06, 0.02))
		KIT.block(p, "steel_grey", Vector3(s * (w / 2.0 - 0.04), h - 0.055, 0.0), Vector3(0.02, 0.06, d - 0.1))
	KIT.block(p, "laminate_light", Vector3(0.0, h - 0.0125, 0.0), Vector3(w, 0.025, d), 0.004)
	return KIT.finish(builder, p, "consult_table", size)

## The reception's front desk (its reference): a long straight counter, its
## front of walnut panels with dark reveals over a black plinth set back,
## walnut ends, a high dark ledge with a walnut edge standing FRONT_OVER proud
## of the front, and behind it, on the sitter's side (-Z), the work top at desk
## height. The warm strip under the overhang is the room's ("light_strip").
const FRONT_OVER := 0.12
const FRONT_TOP := 0.05
## How deep the high ledge is, from its front edge, and the work top's height.
const FRONT_LEDGE := 0.4
const FRONT_WORK := 0.74
static func front_desk(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("front_desk", size), func() -> ArrayMesh: return make_front_desk(builder, size))

static func make_front_desk(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var zf := d / 2.0 - FRONT_OVER
	var low := h - FRONT_TOP
	var inner := d / 2.0 - FRONT_LEDGE
	KIT.block(p, "black", Vector3(0.0, 0.05, -0.06), Vector3(w - 0.1, 0.1, d - FRONT_OVER - 0.12))
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "reception_teak", Vector3(s * (w / 2.0 - 0.025), low / 2.0, (zf + inner) / 2.0), Vector3(0.05, low, zf - inner), 0.004)
		KIT.block(p, "reception_teak", Vector3(s * (w / 2.0 - 0.025), FRONT_WORK / 2.0, (inner - d / 2.0) / 2.0), Vector3(0.05, FRONT_WORK, inner + d / 2.0), 0.004)
	KIT.block(p, "black", Vector3(0.0, (0.1 + low) / 2.0, zf - 0.02), Vector3(w - 0.1, low - 0.1, 0.04), 0.002)
	# The upright under the ledge, over the work top, on the sitter's side.
	KIT.block(p, "walnut_object", Vector3(0.0, (FRONT_WORK + low) / 2.0, inner + 0.01), Vector3(w - 0.1, low - FRONT_WORK, 0.02), 0.002)
	# Smooth teak panels in bays with hairline reveals, a teak rail over and under them.
	var bays := maxi(3, roundi((w - 0.1) / 0.8))
	var bay := (w - 0.1) / bays
	for k in bays:
		var x := -w / 2.0 + 0.05 + bay * (float(k) + 0.5)
		KIT.block(p, "reception_teak", Vector3(x, (0.16 + low - 0.06) / 2.0, zf + 0.003), Vector3(bay - 0.012, low - 0.06 - 0.16, 0.006), 0.002)
	for y: float in [0.13, low - 0.03]: KIT.block(p, "reception_teak", Vector3(0.0, y, zf + 0.004), Vector3(w - 0.1, 0.04, 0.008), 0.002)
	# The ledge, dark, with its walnut edge; the work top behind it.
	KIT.block(p, "black", Vector3(0.0, h - FRONT_TOP / 2.0, (inner + d / 2.0 - 0.03) / 2.0), Vector3(w, FRONT_TOP - 0.004, FRONT_LEDGE - 0.03), 0.004)
	KIT.block(p, "black", Vector3(0.0, h - FRONT_TOP / 2.0, d / 2.0 - 0.015), Vector3(w, FRONT_TOP, 0.03), 0.006)
	KIT.block(p, "walnut_object", Vector3(0.0, FRONT_WORK - 0.015, (inner - d / 2.0) / 2.0), Vector3(w - 0.06, 0.03, inner + d / 2.0), 0.004)
	return KIT.finish(builder, p, "front_desk", size, {"colliders": [AABB(Vector3(-w / 2.0, 0.0, -d / 2.0), Vector3(w, h, d))], "light_strip": [Vector3(0.0, low - 0.008, zf + 0.035), Vector3(w - 0.2, 0.012, 0.02)]})

## A reception counter: a walnut front on a black plinth, a black top and a
## return on the left. The strip under the lip is the room's to place
## ("light_strip"): baked, it would stay lit with its room out.
static func reception_counter(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("reception_counter", size), func() -> ArrayMesh: return make_reception_counter(builder, size))

## The counter's two runs as colliders: the front run and the return on the left.
static func make_reception_counter(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var lip := 0.04
	KIT.block(p, "walnut_object", Vector3(0.0, (0.1 + h - lip) / 2.0, d / 2.0 - 0.07), Vector3(w, h - lip - 0.1, 0.04), 0.003)
	KIT.block(p, "black", Vector3(0.0, 0.05, d / 2.0 - 0.12), Vector3(w - 0.1, 0.1, 0.04))
	# The high shelf in walnut, its edge standing proud of the front.
	KIT.block(p, "walnut_object", Vector3(0.0, h - lip / 2.0, d / 2.0 - 0.175), Vector3(w, lip, 0.35), 0.006)
	var n := maxi(2, int(w / 0.6)) + 1
	for k in n:
		var x := -w / 2.0 + 0.05 + (w - 0.1) * k / (n - 1)
		KIT.block(p, "walnut_object", Vector3(x, (0.1 + h - lip) / 2.0, d / 2.0 - 0.045), Vector3(0.06, h - lip - 0.1, 0.01), 0.002)
		# A raised oak panel in each bay, with a rail over and under it.
		if k < n - 1:
			var bay := (w - 0.1) / (n - 1)
			KIT.block(p, "oak_door", Vector3(x + bay / 2.0, (0.1 + h - lip) / 2.0, d / 2.0 - 0.047), Vector3(bay - 0.12, h - lip - 0.34, 0.006), 0.003)
			for y: float in [0.16, h - lip - 0.06]:
				KIT.block(p, "walnut_object", Vector3(x + bay / 2.0, y, d / 2.0 - 0.046), Vector3(bay - 0.06, 0.04, 0.008), 0.002)
	KIT.block(p, "walnut_object", Vector3(-w / 2.0 + 0.07, (0.1 + h - lip) / 2.0, -0.045), Vector3(0.04, h - lip - 0.1, d - 0.09), 0.003)
	KIT.block(p, "black", Vector3(-w / 2.0 + 0.12, 0.05, -0.07), Vector3(0.04, 0.1, d - 0.14))
	KIT.block(p, "walnut_object", Vector3(-w / 2.0 + 0.175, h - lip / 2.0, -0.175), Vector3(0.35, lip, d - 0.35), 0.006)
	KIT.block(p, "laminate_light", Vector3(0.025, 0.725, d / 2.0 - 0.39), Vector3(w - 0.13, 0.03, 0.6), 0.004)
	KIT.block(p, "laminate_light", Vector3(-w / 2.0 + 0.39, 0.725, -0.325), Vector3(0.6, 0.03, d - 0.73), 0.004)
	KIT.block(p, "walnut_object", Vector3(w / 2.0 - 0.02, (h - lip) / 2.0, d / 2.0 - 0.39), Vector3(0.04, h - lip, 0.6), 0.003)
	KIT.block(p, "walnut_object", Vector3(-w / 2.0 + 0.39, (h - lip) / 2.0, -d / 2.0 + 0.02), Vector3(0.6, h - lip, 0.04), 0.003)
	var colliders: Array = [
		AABB(Vector3(-w / 2.0, 0.0, d / 2.0 - 0.69), Vector3(w, h, 0.69)),
		AABB(Vector3(-w / 2.0, 0.0, -d / 2.0), Vector3(0.69, h, d - 0.69)),
	]
	return KIT.finish(builder, p, "reception_counter", size, {"colliders": colliders, "light_strip": [Vector3(0.0, h - lip - 0.006, d / 2.0 - 0.02), Vector3(w - 0.12, 0.012, 0.016)]})

## A low table for a corner or a waiting room: a top on four square legs tied
## by an apron, all in `key` (walnut for the director's corner, laminate_light
## for the waiting room).
static func low_table(builder: Node3D, size: Vector3, key := "walnut_object") -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("low_table", size, key), func() -> ArrayMesh: return make_low_table(builder, size, key))

static func make_low_table(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var t := 0.03
	var inset := 0.045
	KIT.block(p, key, Vector3(0.0, h - t / 2.0, 0.0), Vector3(w, t, d), 0.006)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, key, Vector3(0.0, h - t - 0.025, s * (d / 2.0 - inset)), Vector3(w - 0.12, 0.05, 0.018))
		KIT.block(p, key, Vector3(s * (w / 2.0 - inset), h - t - 0.025, 0.0), Vector3(0.018, 0.05, d - 0.12))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			KIT.block(p, key, Vector3(sx * (w / 2.0 - inset), (h - t) / 2.0, sz * (d / 2.0 - inset)), Vector3(0.04, h - t, 0.04), 0.003)
	return KIT.finish(builder, p, "low_table", size)
