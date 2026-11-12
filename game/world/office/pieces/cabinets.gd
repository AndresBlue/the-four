extends RefCounted
## Filing cabinets, card index, sideboard, bookcases and pigeonholes (spec_rediseno.md 5.1, area 4a): KIT's frame,
## cache and materials (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["filing_4_steel_olive", filing_cabinet(builder, Vector3(0.47, 1.32, 0.62), 4, "steel_olive")],
		["filing_2_steel_olive", filing_cabinet(builder, Vector3(0.47, 0.72, 0.62), 2, "steel_olive")],
		["filing_4_steel_mint", filing_cabinet(builder, Vector3(0.47, 1.32, 0.62), 4, "steel_mint")],
		["filing_4_plastic_beige", filing_cabinet(builder, Vector3(0.47, 1.32, 0.62), 4, "plastic_beige")],
		["card_index", card_index(builder, Vector3(1.2, 1.0, 0.5))],
		["sideboard", sideboard(builder, Vector3(1.8, 0.8, 0.48))],
		["bookcase", bookcase(builder, Vector3(0.9, 2.0, 0.35), true)],
		["bookcase_empty", bookcase(builder, Vector3(1.0, 2.2, 0.4), false)],
		["pigeonholes", pigeonholes(builder, Vector3(1.8, 1.9, 0.4))],
		["pigeon_counter", pigeon_counter(builder, Vector3(2.4, 1.1, 0.8))],
	]

## A steel or plastic filing cabinet: `drawers` fronts, each with a bar pull and
## a card holder, and a lock above the top one.
static func filing_cabinet(builder: Node3D, size: Vector3, drawers: int, key: String) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("filing", size, "%d:%s" % [drawers, key]), func() -> ArrayMesh: return make_filing_cabinet(builder, size, drawers, key))

static func make_filing_cabinet(builder: Node3D, size: Vector3, drawers: int, key: String) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var zf := d / 2.0 - KIT.FRONT
	KIT.block(p, key, Vector3(0.0, (0.04 + h) / 2.0, (-d / 2.0 + zf) / 2.0), Vector3(w, h - 0.04, zf + d / 2.0), 0.004)
	KIT.block(p, "black", Vector3(0.0, 0.02, -0.03), Vector3(w - 0.04, 0.04, d - 0.1))
	var avail := h - 0.07
	var each := avail / drawers
	for i in drawers:
		KIT.front(p, key, Vector3(0.0, 0.04 + each * (i + 0.5), zf), Vector2(w - 0.03, each), "bar", "metal", -0.02, true, 0.012)
	KIT.cylinder(p, "metal", Vector3(w / 2.0 - 0.05, h - 0.015, zf + 0.005), 0.008, 0.01, 8, KIT.along_z())
	return KIT.finish(builder, p, "filing_%d_%s" % [drawers, key], size)

## An oak card index: rows and columns of small drawers, each with a knob and a card holder.
static func card_index(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("card_index", size), func() -> ArrayMesh: return make_card_index(builder, size))

static func make_card_index(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var zf := d / 2.0 - KIT.FRONT
	KIT.block(p, "oak_door", Vector3(0.0, (0.08 + h - 0.025) / 2.0, (-d / 2.0 + zf) / 2.0), Vector3(w, h - 0.105, zf + d / 2.0), 0.006)
	KIT.block(p, "oak_door", Vector3(0.0, h - 0.0125, -0.01), Vector3(w, 0.025, d - 0.02), 0.006)
	KIT.block(p, "black", Vector3(0.0, 0.04, -0.03), Vector3(w - 0.04, 0.08, d - 0.1))
	var cols := maxi(1, roundi((w - 0.04) / 0.15))
	var rows := maxi(1, roundi((h - 0.145) / 0.11))
	var cw := (w - 0.04) / cols
	var rh := (h - 0.125) / rows
	for c in cols:
		for r in rows:
			KIT.front(p, "oak_door", Vector3(-w / 2.0 + 0.02 + cw * (c + 0.5), 0.09 + rh * (r + 0.5), zf), Vector2(cw, rh), "knob", "gold", -rh * 0.22, true, 0.012)
	return KIT.finish(builder, p, "card_index", size)

## A walnut sideboard: doors with gold knobs under a top, on a black plinth.
static func sideboard(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("sideboard", size), func() -> ArrayMesh: return make_sideboard(builder, size))

static func make_sideboard(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var zf := d / 2.0 - KIT.FRONT
	KIT.block(p, "walnut_object", Vector3(0.0, (0.08 + h - 0.03) / 2.0, (-d / 2.0 + zf) / 2.0), Vector3(w, h - 0.11, zf + d / 2.0), 0.003)
	KIT.block(p, "walnut_object", Vector3(0.0, h - 0.015, (zf + 0.02 - d / 2.0) / 2.0), Vector3(w, 0.03, zf + 0.02 + d / 2.0), 0.006)
	KIT.block(p, "black", Vector3(0.0, 0.04, -0.03), Vector3(w - 0.06, 0.08, d - 0.12))
	var n := maxi(2, roundi(w / 0.45))
	var dw := w / n
	for k in n:
		KIT.front(p, "walnut_object", Vector3(-w / 2.0 + dw * (k + 0.5), (0.08 + h - 0.03) / 2.0, zf), Vector2(dw, h - 0.11), "knob", "gold", (h - 0.11) * 0.3, false, 0.018)
	return KIT.finish(builder, p, "sideboard", size)

## A walnut bookcase open at the front. `filled` stands books (KIT.book_row()),
## some shelves led by a few ring binders, on its shelves; the
## filled and the empty one are two pieces, with two titles.
## `variant` (0 to 2) gives other contents under the same title.
static func bookcase(builder: Node3D, size: Vector3, filled: bool, variant := 0) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("bookcase", size, "%s:%d" % [filled, variant]), func() -> ArrayMesh: return make_bookcase(builder, size, filled, variant))

static func make_bookcase(builder: Node3D, size: Vector3, filled: bool, variant: int) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "walnut_object", Vector3(s * (w / 2.0 - 0.0125), h / 2.0, 0.0), Vector3(0.025, h, d), 0.003)
	KIT.block(p, "walnut_object", Vector3(0.0, h - 0.015, 0.0), Vector3(w - 0.05, 0.03, d))
	KIT.block(p, "walnut_object", Vector3(0.0, (h - 0.03) / 2.0, -d / 2.0 + 0.004), Vector3(w - 0.05, h - 0.03, 0.008))
	KIT.block(p, "walnut_object", Vector3(0.0, 0.04, d / 2.0 - 0.03), Vector3(w - 0.05, 0.08, 0.02))
	KIT.block(p, "walnut_object", Vector3(0.0, 0.091, 0.0), Vector3(w - 0.05, 0.022, d - 0.01))
	var n := maxi(2, roundi((h - 0.13) / 0.34))
	var s_gap := (h - 0.132) / n
	for k in range(1, n):
		KIT.block(p, "walnut_object", Vector3(0.0, 0.102 + s_gap * k - 0.011, -0.007), Vector3(w - 0.05, 0.022, d - 0.03))
	if filled:
		for k in n:
			var pick: int = k + variant * KIT.VARIANT
			var origin := Vector3(-w / 2.0 + 0.03, 0.102 + s_gap * k, 0.004)
			var length := (w - 0.06) * (0.8 + 0.2 * KIT.hash01(pick, 7))
			var tall := minf(0.3, s_gap - 0.052)
			# Some shelves start with a few ring binders, their spines flush with the books'.
			if KIT.hash01(pick, 22) < 0.35:
				var bd := minf(0.28, d - 0.06)
				var run := (2 + int(KIT.hash01(pick, 23) * 4.0)) * 0.08
				KIT.binder_row(p, origin + Vector3(0.0, 0.0, (d - 0.04 - bd) * 0.5), run, bd, tall, pick)
				origin.x += run + 0.004
				length -= run + 0.004
			KIT.book_row(p, origin, length, d - 0.04, tall, pick)
	var title: String = "bookcase" if filled else "bookcase_empty"
	return KIT.finish(builder, p, title, size)

## Oak pigeonholes for the post: a grid of open cells, most with a loose pile of post (KIT.post_pile()).
## `variant` (0 to 2) gives other contents under the same title.
static func pigeonholes(builder: Node3D, size: Vector3, variant := 0) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("pigeonholes", size, str(variant)), func() -> ArrayMesh: return make_pigeonholes(builder, size, variant))

static func make_pigeonholes(builder: Node3D, size: Vector3, variant: int) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var cols := maxi(1, roundi(w / 0.3))
	var rows := maxi(1, roundi(h / 0.27))
	var iw := w - 0.04
	var ih := h - 0.04
	var cw := iw / cols
	var rh := ih / rows
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "oak_door", Vector3(s * (w / 2.0 - 0.01), h / 2.0, 0.0), Vector3(0.02, h, d), 0.002)
	KIT.block(p, "oak_door", Vector3(0.0, h - 0.01, 0.0), Vector3(iw, 0.02, d))
	KIT.block(p, "oak_door", Vector3(0.0, 0.01, 0.0), Vector3(iw, 0.02, d))
	KIT.block(p, "oak_door", Vector3(0.0, h / 2.0, -d / 2.0 + 0.004), Vector3(iw, ih, 0.008))
	for c in range(1, cols):
		KIT.block(p, "oak_door", Vector3(-w / 2.0 + 0.02 + cw * c, h / 2.0, 0.003), Vector3(0.012, ih, d - 0.01))
	for r in range(1, rows):
		KIT.block(p, "oak_door", Vector3(0.0, 0.02 + rh * r, 0.003), Vector3(iw, 0.012, d - 0.01))
	for c in cols:
		for r in range(1, rows):
			KIT.block(p, "paper", Vector3(-w / 2.0 + 0.02 + cw * (c + 0.5), 0.02 + rh * r, d / 2.0 - 0.0015), Vector3(cw * 0.4, 0.01, 0.001))
	# The post: most cells hold a loose pile, a working rack and not a new one.
	for c in cols:
		for r in rows:
			var i: int = r * cols + c + variant * KIT.VARIANT
			if KIT.hash01(i, 8) < 0.87:
				var floor_y: float = 0.02 if r == 0 else 0.02 + rh * r + 0.006
				KIT.post_pile(p, Vector3(-w / 2.0 + 0.02 + cw * (c + 0.5), floor_y, 0.004), Vector2(cw - 0.012, d - 0.012), rh - 0.06, i)
	return KIT.finish(builder, p, "pigeonholes", size)

## A central counter of pigeonholes for the post, open to both faces: oak
## dividers, and post in most cells of each face.
## `variant` (0 to 2) gives other contents under the same title.
static func pigeon_counter(builder: Node3D, size: Vector3, variant := 0) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("pigeon_counter", size, str(variant)), func() -> ArrayMesh: return make_pigeon_counter(builder, size, variant))

static func make_pigeon_counter(builder: Node3D, size: Vector3, variant: int) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "oak_door", Vector3(0.0, h - 0.02, 0.0), Vector3(w, 0.04, d), 0.006)
	KIT.block(p, "black", Vector3(0.0, 0.04, 0.0), Vector3(w - 0.1, 0.08, d - 0.1))
	var ym := (0.08 + h - 0.04) / 2.0
	var hh := h - 0.12
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "oak_door", Vector3(s * (w / 2.0 - 0.03), ym, 0.0), Vector3(0.02, hh, d - 0.04))
	KIT.block(p, "oak_door", Vector3(0.0, ym, 0.0), Vector3(w - 0.08, hh, 0.012))
	KIT.block(p, "oak_door", Vector3(0.0, 0.09, 0.0), Vector3(w - 0.08, 0.02, d - 0.04))
	var cols := maxi(1, roundi((w - 0.08) / 0.3))
	var rows := maxi(1, roundi((hh - 0.02) / 0.25))
	var cw := (w - 0.08) / cols
	var rh := (hh - 0.02) / rows
	for f: float in [-1.0, 1.0]:
		for c in range(1, cols):
			KIT.block(p, "oak_door", Vector3(-w / 2.0 + 0.04 + cw * c, ym, f * (d / 4.0 - 0.007)), Vector3(0.012, hh, d / 2.0 - 0.026))
		for r in range(1, rows):
			KIT.block(p, "oak_door", Vector3(0.0, 0.1 + rh * r, f * (d / 4.0 - 0.007)), Vector3(w - 0.08, 0.012, d / 2.0 - 0.026))
		for c in cols:
			for r in rows:
				var shelf_y: float = 0.1 if r == 0 else 0.1 + rh * r + 0.006
				var cell: int = r * cols + c + variant * KIT.VARIANT
				var slot: int = cell + (100 if f > 0.0 else 0)
				if KIT.hash01(slot, 8) < 0.85:
					KIT.post_pile(p, Vector3(-w / 2.0 + 0.04 + cw * (c + 0.5), shelf_y, f * (d / 4.0 + 0.001)), Vector2(cw - 0.012, d / 2.0 - 0.046), rh - 0.05, slot, f)
	return KIT.finish(builder, p, "pigeon_counter", size)
