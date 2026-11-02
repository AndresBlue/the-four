extends RefCounted
## Archive shelving, wood shelving, the gun rack and kitchen units
## (spec_rediseno.md 5.1, area 4a): KIT's frame, cache and materials
## (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["archive_shelving", archive_shelving(builder, Vector3(2.0, 2.1, 0.4))],
		["mobile_archive", mobile_archive(builder, Vector3(3.0, 2.1, 0.8))],
		["wood_shelving", wood_shelving(builder, Vector3(1.2, 1.8, 0.4))],
		["gun_rack", gun_rack(builder, Vector3(1.0, 1.9, 0.45))],
		["kitchen_base_sink", kitchen_base(builder, Vector3(1.8, 1.2, 0.6), true)],
		["kitchen_base", kitchen_base(builder, Vector3(1.2, 0.9, 0.6), false)],
		["kitchen_wall", kitchen_wall(builder, Vector3(1.8, 0.7, 0.35))],
	]

## Steel archive shelving: grey angle iron, with boxes and binders on each shelf.
## `variant` (0 to 2) gives other contents under the same title.
static func archive_shelving(builder: Node3D, size: Vector3, variant := 0) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("archive_shelving", size, str(variant)), func() -> ArrayMesh: return make_archive_shelving(builder, size, variant))

static func make_archive_shelving(builder: Node3D, size: Vector3, variant: int) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var bays := maxi(1, roundi(w))
	var bw: float = (w - 0.035) / bays
	var gap: float = (h - 0.1) / 5.0 - 0.02
	# Uprights: angle iron, a flange on each face.
	for k in bays + 1:
		var x := -w / 2.0 + 0.0175 + bw * k
		var side_x: float = -1.0 if k == 0 else 1.0
		for sz: float in [-1.0, 1.0]:
			KIT.block(p, "steel_grey", Vector3(x, h / 2.0, sz * (d / 2.0 - 0.001)), Vector3(0.035, h, 0.002))
			KIT.block(p, "steel_grey", Vector3(x + side_x * 0.0165, h / 2.0, sz * (d / 2.0 - 0.0175)), Vector3(0.002, h, 0.035))
	# Six shelves; the five above the floor carry the files, bay by bay.
	for s in 6:
		var y: float = 0.05 + (h - 0.1) * s / 5.0
		KIT.block(p, "steel_grey", Vector3(0.0, y, 0.0), Vector3(w - 0.006, 0.02, d - 0.006))
		for sz: float in [-1.0, 1.0]:
			KIT.block(p, "steel_grey", Vector3(0.0, y - 0.02, sz * (d / 2.0 - 0.002)), Vector3(w - 0.01, 0.04, 0.002))
		if s < 5:
			for b in bays:
				var ux := -w / 2.0 + 0.0175 + bw * b
				var i: int = s * 10 + b + variant * KIT.VARIANT
				if KIT.hash01(i, 9) < 0.6:
					KIT.box_row(p, Vector3(ux + 0.03, y + 0.01, 0.0), bw - 0.06, minf(0.39, d - 0.04), 0.85, i)
				else:
					KIT.binder_row(p, Vector3(ux + 0.03, y + 0.01, 0.0), bw - 0.06, minf(0.29, d - 0.06), minf(0.32, gap - 0.03), i)
	# The number on a plate at the end, where the text plate goes.
	var py: float = minf(1.5, h - 0.2)
	KIT.block(p, "steel_grey", Vector3(w / 2.0 - 0.005, py, 0.0), Vector3(0.002, 0.14, d - 0.004))
	KIT.block(p, "black", Vector3(w / 2.0 - 0.0025, py, 0.0), Vector3(0.003, 0.1, 0.16))
	return KIT.finish(builder, p, "archive_shelving", size, {"text_plate": [Vector3(w / 2.0, py, 0.0), Vector2(0.16, 0.1), Vector3(1.0, 0.0, 0.0)]})

## Mobile archive: two faces of boxes on a base, with a hand wheel on the end panel.
## `variant` (0 to 2) gives other contents under the same title.
static func mobile_archive(builder: Node3D, size: Vector3, variant := 0) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("mobile_archive", size, str(variant)), func() -> ArrayMesh: return make_mobile_archive(builder, size, variant))

static func make_mobile_archive(builder: Node3D, size: Vector3, variant: int) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var sw := w - 0.07
	var sx := -0.035
	var bays := maxi(1, roundi(sw))
	var bw: float = (sw - 0.035) / bays
	# The base, the back panel and the uprights.
	KIT.block(p, "steel_grey", Vector3(sx, 0.05, 0.0), Vector3(sw, 0.1, d), 0.004)
	KIT.block(p, "steel_grey", Vector3(sx, (0.1 + h) / 2.0, 0.0), Vector3(sw, h - 0.1, 0.004))
	for k in bays + 1:
		var x: float = sx - sw / 2.0 + 0.0175 + bw * k
		for sz: float in [-1.0, 1.0]:
			KIT.block(p, "steel_grey", Vector3(x, (0.1 + h) / 2.0, sz * (d / 2.0 - 0.0175)), Vector3(0.035, h - 0.1, 0.035))
	# Six shelves, with boxes on both faces of each bay below the top one.
	for s in 6:
		var y: float = 0.15 + (h - 0.2) * s / 5.0
		KIT.block(p, "steel_grey", Vector3(sx, y, 0.0), Vector3(sw - 0.006, 0.02, d - 0.006))
		if s < 5:
			for b in bays:
				var ux: float = sx - sw / 2.0 + 0.0175 + bw * b
				var i: int = s * 10 + b + variant * KIT.VARIANT
				KIT.box_row(p, Vector3(ux + 0.03, y + 0.01, d / 4.0), bw - 0.06, d / 2.0 - 0.03, 0.8, i, 1.0)
				KIT.box_row(p, Vector3(ux + 0.03, y + 0.01, -d / 4.0), bw - 0.06, d / 2.0 - 0.03, 0.8, i + 100, -1.0)
	# The end panel, and the hand wheel on it: a ring of 16 pieces, a hub and three spokes.
	KIT.block(p, "steel_grey", Vector3(w / 2.0 - 0.055, h / 2.0, 0.0), Vector3(0.03, h, d), 0.006)
	var wy: float = minf(1.0, h * 0.5)
	for k in 16:
		var a: float = TAU * k / 16.0
		KIT.block(p, "metal", Vector3(w / 2.0 - 0.0125, wy + cos(a) * 0.11, sin(a) * 0.11), Vector3(0.02, 0.045, 0.012), 0.0, Basis(Vector3.RIGHT, a + PI / 2.0))
	KIT.cylinder(p, "metal", Vector3(w / 2.0 - 0.025, wy, 0.0), 0.03, 0.03, 10, KIT.along_x())
	for k in 3:
		KIT.block(p, "metal", Vector3(w / 2.0 - 0.0125, wy, 0.0), Vector3(0.01, 0.22, 0.012), 0.0, Basis(Vector3.RIGHT, k * PI / 3.0))
	# The number, as on the archive.
	KIT.block(p, "black", Vector3(w / 2.0 - 0.038, h - 0.25, 0.0), Vector3(0.004, 0.1, 0.16))
	return KIT.finish(builder, p, "mobile_archive", size, {"text_plate": [Vector3(w / 2.0 - 0.035, h - 0.25, 0.0), Vector2(0.16, 0.1), Vector3(1.0, 0.0, 0.0)]})

## Open oak shelving, five boards with boxes between them and a back rail at each end.
## `variant` (0 to 2) gives other contents under the same title.
static func wood_shelving(builder: Node3D, size: Vector3, variant := 0) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("wood_shelving", size, str(variant)), func() -> ArrayMesh: return make_wood_shelving(builder, size, variant))

static func make_wood_shelving(builder: Node3D, size: Vector3, variant: int) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "oak_door", Vector3(s * (w / 2.0 - 0.012), h / 2.0, 0.0), Vector3(0.024, h, d), 0.003)
	for k in 5:
		var y: float = 0.06 + (h - 0.08) * k / 4.0
		KIT.block(p, "oak_door", Vector3(0.0, y, 0.0), Vector3(w - 0.048, 0.022, d), 0.002)
		if k < 4:
			KIT.box_row(p, Vector3(-w / 2.0 + 0.03, y + 0.011, 0.0), w - 0.06, minf(0.39, d - 0.04), 0.7, k + 20 + variant * KIT.VARIANT)
	KIT.block(p, "oak_door", Vector3(0.0, h - 0.06, -d / 2.0 + 0.0075), Vector3(w - 0.048, 0.06, 0.015))
	KIT.block(p, "oak_door", Vector3(0.0, 0.15, -d / 2.0 + 0.0075), Vector3(w - 0.048, 0.06, 0.015))
	return KIT.finish(builder, p, "wood_shelving", size)

## Open dark steel gun rack, empty, with clips and a bar across it.
static func gun_rack(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("gun_rack", size), func() -> ArrayMesh: return make_gun_rack(builder, size))

static func make_gun_rack(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "steel_dark", Vector3(0.0, h / 2.0, -d / 2.0 + 0.01), Vector3(w, h, 0.02))
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "steel_dark", Vector3(s * (w / 2.0 - 0.01), h / 2.0, 0.01), Vector3(0.02, h, d - 0.02), 0.003)
	KIT.block(p, "steel_dark", Vector3(0.0, h - 0.01, 0.01), Vector3(w - 0.04, 0.02, d - 0.02))
	KIT.block(p, "steel_dark", Vector3(0.0, 0.04, 0.01), Vector3(w - 0.04, 0.08, d - 0.02))
	KIT.block(p, "steel_dark", Vector3(0.0, h - 0.3, 0.0), Vector3(w - 0.04, 0.015, d - 0.06))
	KIT.block(p, "steel_dark", Vector3(0.0, 0.25, d / 2.0 - 0.12), Vector3(w - 0.04, 0.06, 0.16), 0.003)
	var yr: float = h * 0.7
	KIT.block(p, "steel_dark", Vector3(0.0, yr, d / 2.0 - 0.07), Vector3(w - 0.04, 0.04, 0.1))
	for k in 6:
		var x: float = -w / 2.0 + 0.1 + (w - 0.2) * k / 5.0
		KIT.block(p, "black", Vector3(x, 0.281, d / 2.0 - 0.12), Vector3(0.05, 0.002, 0.12))
		KIT.block(p, "black", Vector3(x, yr, d / 2.0 - 0.025), Vector3(0.04, 0.045, 0.012))
	KIT.cylinder(p, "metal", Vector3(0.0, yr + 0.1, d / 2.0 - 0.015), 0.006, w - 0.04, 8, KIT.along_x())
	return KIT.finish(builder, p, "gun_rack", size)

## Oak base unit with its doors; the sink version is open on top, with a
## worktop round a steel bowl and a tap.
static func kitchen_base(builder: Node3D, size: Vector3, sink: bool) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("kitchen_base", size, str(sink)), func() -> ArrayMesh: return make_kitchen_base(builder, size, sink))

static func make_kitchen_base(builder: Node3D, size: Vector3, sink: bool) -> ArrayMesh:
	var title: String = "kitchen_base_sink" if sink else "kitchen_base"
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var zf := d / 2.0 - KIT.FRONT
	var work: float = h - 0.3 if sink else h
	var ym := (0.1 + work - 0.035) / 2.0
	var hh := work - 0.135
	var cz := (-d / 2.0 + zf) / 2.0
	var cd := zf + d / 2.0
	KIT.block(p, "black", Vector3(0.0, 0.05, -0.03), Vector3(w, 0.1, d - 0.12))
	var n := maxi(1, roundi(w / 0.6))
	var dw: float = w / n
	for k in n:
		KIT.front(p, "oak_door", Vector3(-w / 2.0 + dw * (k + 0.5), ym, zf), Vector2(dw, hh), "bar", "metal", hh * 0.35, false, 0.015)
	var collider := AABB()
	if not sink:
		KIT.block(p, "oak_door", Vector3(0.0, ym, cz), Vector3(w, hh, cd), 0.003)
		KIT.block(p, "laminate_light", Vector3(0.0, work - 0.0175, 0.0), Vector3(w, 0.035, d), 0.006)
	else:
		# The carcass, open on top.
		for s: float in [-1.0, 1.0]:
			KIT.block(p, "oak_door", Vector3(s * (w / 2.0 - 0.009), ym, cz), Vector3(0.018, hh, cd))
		KIT.block(p, "oak_door", Vector3(0.0, ym, -d / 2.0 + 0.009), Vector3(w - 0.036, hh, 0.018))
		KIT.block(p, "oak_door", Vector3(0.0, (0.1 + work - 0.2) / 2.0, cz), Vector3(w - 0.036, work - 0.3, cd - 0.036))
		# The hole for the bowl, and the worktop round it in four pieces.
		var hx: float = minf(0.5, w * 0.4)
		var hz := 0.38
		var sx := w * 0.15
		var sz := 0.02
		var y := work - 0.0175
		KIT.block(p, "laminate_light", Vector3((-w / 2.0 + sx - hx / 2.0) / 2.0, y, 0.0), Vector3(sx - hx / 2.0 + w / 2.0, 0.035, d), 0.004)
		KIT.block(p, "laminate_light", Vector3((sx + hx / 2.0 + w / 2.0) / 2.0, y, 0.0), Vector3(w / 2.0 - sx - hx / 2.0, 0.035, d), 0.004)
		KIT.block(p, "laminate_light", Vector3(sx, y, (sz + hz / 2.0 + d / 2.0) / 2.0), Vector3(hx, 0.035, d / 2.0 - sz - hz / 2.0))
		KIT.block(p, "laminate_light", Vector3(sx, y, (sz - hz / 2.0 - d / 2.0) / 2.0), Vector3(hx, 0.035, sz - hz / 2.0 + d / 2.0))
		# The bowl: a steel plate with its walls, and its drain.
		KIT.block(p, "metal", Vector3(sx, work - 0.18, sz), Vector3(hx, 0.005, hz))
		for s: float in [-1.0, 1.0]:
			KIT.block(p, "metal", Vector3(sx + s * (hx / 2.0 - 0.0025), work - 0.09, sz), Vector3(0.005, 0.18, hz))
			KIT.block(p, "metal", Vector3(sx, work - 0.09, sz + s * (hz / 2.0 - 0.0025)), Vector3(hx, 0.18, 0.005))
		KIT.cylinder(p, "black", Vector3(sx, work - 0.177, sz), 0.025, 0.002, 12)
		# The tap: a stem, its spout along z, and two handles.
		KIT.cylinder(p, "metal", Vector3(sx, work + 0.125, -d / 2.0 + 0.07), 0.012, 0.25, 10)
		KIT.cylinder(p, "metal", Vector3(sx, work + 0.24, -d / 2.0 + 0.16), 0.01, 0.18, 10, KIT.along_z())
		for s: float in [-1.0, 1.0]:
			KIT.cylinder(p, "metal", Vector3(sx + s * 0.07, work + 0.03, -d / 2.0 + 0.07), 0.018, 0.06, 8)
		collider = AABB(Vector3(-w / 2.0, 0.0, -d / 2.0), Vector3(w, work, d))
	return KIT.finish(builder, p, title, size, {}, collider)

## Oak wall unit hung 1.45 m up. The strip under its lip is the room's to place
## ("light_strip"): baked, it would stay lit with its room out.
static func kitchen_wall(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("kitchen_wall", size), func() -> ArrayMesh: return make_kitchen_wall(builder, size))

static func make_kitchen_wall(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var zf := d / 2.0 - KIT.FRONT
	KIT.block(p, "oak_door", Vector3(0.0, (0.012 + h) / 2.0, (-d / 2.0 + zf) / 2.0), Vector3(w, h - 0.012, zf + d / 2.0), 0.003)
	var n := maxi(1, roundi(w / 0.6))
	var dw: float = w / n
	for k in n:
		KIT.front(p, "oak_door", Vector3(-w / 2.0 + dw * (k + 0.5), (0.012 + h) / 2.0, zf), Vector2(dw, h - 0.012), "bar", "metal", -(h - 0.012) * 0.38, false, 0.015)
	return KIT.finish(builder, p, "kitchen_wall", size, {"wall": true, "mount": 1.45, "light_strip": [Vector3(0.0, 0.006, zf - 0.04), Vector3(w - 0.1, 0.012, 0.03)]})
