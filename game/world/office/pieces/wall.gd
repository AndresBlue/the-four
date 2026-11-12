extends RefCounted
## Wall pieces: signs, frames, clock, directory, notice board, key cabinet,
## mirror, hooks, roll-down screen (spec_rediseno.md 5.1, area 4a): KIT's frame,
## cache and materials (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["sign_plate", sign_plate(builder, Vector3(0.3, 0.1, 0.01))],
		["picture_walnut_object", picture_frame(builder, Vector3(0.6, 0.8, 0.03), "walnut_object")],
		["picture_black", picture_frame(builder, Vector3(0.5, 0.4, 0.025), "black")],
		["clock_square", clock_square(builder, Vector3(0.3, 0.3, 0.06))],
		["directory_board", directory_board(builder, Vector3(0.9, 0.7, 0.05))],
		["notice_board", notice_board(builder, Vector3(1.2, 0.9, 0.03))],
		["key_cabinet", key_cabinet(builder, Vector3(0.5, 0.6, 0.08))],
		["mirror", mirror(builder, Vector3(0.6, 0.8, 0.03))],
		["coat_hook_rail", coat_hook_rail(builder, Vector3(1.2, 0.12, 0.09))],
		["roll_screen", roll_screen(builder, Vector3(1.8, 1.6, 0.1))],
	]

## A black sign plate on two screws; its text goes on the text plate, not here.
static func sign_plate(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("sign_plate", size), func() -> ArrayMesh: return make_sign_plate(builder, size))

static func make_sign_plate(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "black", Vector3(0.0, h * 0.5, -0.001), Vector3(w, h, d - 0.002), minf(0.003, (d - 0.002) * 0.4))
	for s: float in [-1.0, 1.0]:
		KIT.cylinder(p, "metal", Vector3(s * (w * 0.5 - 0.015), h * 0.5, d * 0.5 - 0.001), 0.003, 0.002, 8, KIT.along_z())
	var meta := {"wall": true, "mount": 1.55, "solid": false, "text_plate": [Vector3(0.0, h * 0.5, d * 0.5 - 0.001), Vector2(w - 0.04, h - 0.02), Vector3(0.0, 0.0, 1.0)]}
	return KIT.finish(builder, p, "sign_plate", size, meta)

## A four-bar frame round a hole, its bars `fw` wide and the frame `d` deep.
static func frame(p: Dictionary, key: String, w: float, h: float, d: float, fw: float) -> void:
	KIT.block(p, key, Vector3(0.0, h - fw * 0.5, 0.0), Vector3(w, fw, d), 0.004)
	KIT.block(p, key, Vector3(0.0, fw * 0.5, 0.0), Vector3(w, fw, d), 0.004)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, key, Vector3(s * (w * 0.5 - fw * 0.5), h * 0.5, 0.0), Vector3(fw, h - 2.0 * fw, d), 0.004)

## A framed sheet on a card backing; the picture itself goes in its picture area.
static func picture_frame(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("picture", size, key), func() -> ArrayMesh: return make_picture_frame(builder, size, key))

static func make_picture_frame(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var fw := 0.04
	frame(p, key, w, h, d, fw)
	KIT.block(p, "paper", Vector3(0.0, h * 0.5, d * 0.5 - 0.012), Vector3(w - 2.0 * fw, h - 2.0 * fw, 0.004))
	KIT.block(p, "cardboard", Vector3(0.0, h * 0.5, -d * 0.5 + 0.002), Vector3(w - 0.01, h - 0.01, 0.004))
	var meta := {"wall": true, "mount": 1.2, "solid": false, "picture": [Vector3(0.0, h * 0.5, d * 0.5 - 0.0095), Vector2((w - 2.0 * fw) * 0.75, (h - 2.0 * fw) * 0.75), Vector3(0.0, 0.0, 1.0)]}
	return KIT.finish(builder, p, "picture_" + key, size, meta)

## A square wooden clock stopped at ten past ten, the pose that reads as a clock.
static func clock_square(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("clock_square", size), func() -> ArrayMesh: return make_clock_square(builder, size))

static func make_clock_square(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "walnut_object", Vector3(0.0, h * 0.5, -0.003), Vector3(w, h, d - 0.006), 0.006)
	KIT.block(p, "paper", Vector3(0.0, h * 0.5, d * 0.5 - 0.0045), Vector3(w * 0.8, h * 0.8, 0.003))
	for k in 12:
		var a := TAU * k / 12.0
		KIT.block(p, "black", Vector3(sin(a) * w * 0.34, h * 0.5 + cos(a) * w * 0.34, d * 0.5 - 0.0025), Vector3(0.006, 0.018, 0.001), 0.0, Basis(Vector3.BACK, -a))
	var ah := TAU * 10.17 / 12.0
	KIT.block(p, "black", Vector3(sin(ah) * w * 0.1, h * 0.5 + cos(ah) * w * 0.1, d * 0.5 - 0.0015), Vector3(0.008, w * 0.2, 0.001), 0.0, Basis(Vector3.BACK, -ah))
	var am := TAU * 2.0 / 12.0
	KIT.block(p, "black", Vector3(sin(am) * w * 0.15, h * 0.5 + cos(am) * w * 0.15, d * 0.5 - 0.0005), Vector3(0.006, w * 0.3, 0.001), 0.0, Basis(Vector3.BACK, -am))
	return KIT.finish(builder, p, "clock_square", size, {"wall": true, "mount": 1.85, "solid": false})

## A wooden directory board: rows of white letters on black felt.
static func directory_board(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("directory_board", size), func() -> ArrayMesh: return make_directory_board(builder, size))

static func make_directory_board(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var fw := 0.03
	frame(p, "walnut_object", w, h, d, fw)
	KIT.block(p, "black", Vector3(0.0, h * 0.5, -d * 0.5 + 0.02), Vector3(w - 2.0 * fw, h - 2.0 * fw, 0.01))
	KIT.block(p, "paper", Vector3(0.0, h - fw - 0.04, -d * 0.5 + 0.026), Vector3(w * 0.5, 0.025, 0.002))
	var rows := int((h - 2.0 * fw - 0.1) / 0.035)
	for r in rows:
		var y := h - fw - 0.08 - r * 0.035
		var ln := (w - 2.0 * fw) * (0.3 + 0.35 * KIT.hash01(r, 13))
		KIT.block(p, "paper", Vector3(-w * 0.5 + fw + 0.03 + ln * 0.5, y, -d * 0.5 + 0.026), Vector3(ln, 0.012, 0.002))
		KIT.block(p, "paper", Vector3(w * 0.5 - fw - 0.05, y, -d * 0.5 + 0.026), Vector3(0.04, 0.012, 0.002))
	return KIT.finish(builder, p, "directory_board", size, {"wall": true, "mount": 1.1, "solid": false})

## What goes on a notice board (make_notice_board()): sheet sizes (A4 twice,
## A5, A4 across, an index card, a memo slip, a calendar), papers and pins.
const NOTICE_SHEETS := [Vector2(0.21, 0.297), Vector2(0.21, 0.297), Vector2(0.148, 0.21), Vector2(0.297, 0.21), Vector2(0.127, 0.076), Vector2(0.1, 0.14), Vector2(0.26, 0.38)]
const NOTICE_PAPERS := ["paper", "paper", "paper", "linen", "plastic_beige", "cardboard"]
const NOTICE_PINS := ["cloth_red", "cloth_navy", "cloth_green", "plastic_beige", "gold", "cloth_red"]
## How far each sheet lies over the one before: enough for the depth
## buffer, and twenty of them stay inside the frame's depth.
const NOTICE_LAYER := 0.0004

## A cork notice board in an oak frame, full of notices: sheets of many sizes
## and papers, each a little askew, with typed or written lines, ruled forms
## and a calendar, pinned with coloured pins; a loose grid of cells so they
## overlap a little and none clumps.
static func notice_board(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("notice_board", size), func() -> ArrayMesh: return make_notice_board(builder, size))

static func make_notice_board(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var fw := 0.03
	var cw := w - 2.0 * fw
	var ch := h - 2.0 * fw
	frame(p, "oak_door", w, h, d, fw)
	KIT.block(p, "cork", Vector3(0.0, h * 0.5, -d * 0.5 + 0.008), Vector3(cw, ch, 0.016))
	var face := -d * 0.5 + 0.0162
	var cols := maxi(2, roundi(cw / 0.24))
	var rows := maxi(2, roundi(ch / 0.28))
	var layer := 0
	for r in rows:
		for c in cols:
			for extra in 2:
				var n := r * cols + c + extra * 100
				var roll := KIT.hash01(n, 14)
				if (extra == 0 and roll < 0.08) or (extra == 1 and roll > 0.3): continue
				var sheet: Vector2 = NOTICE_SHEETS[int(KIT.hash01(n, 15) * NOTICE_SHEETS.size()) % NOTICE_SHEETS.size()]
				sheet = Vector2(minf(sheet.x, cw * 0.7), minf(sheet.y, ch * 0.7))
				var a := (KIT.hash01(n, 19) - 0.5) * 0.14
				var reach := Vector2(sheet.x * cos(a) + sheet.y * absf(sin(a)), sheet.x * absf(sin(a)) + sheet.y * cos(a)) * 0.5 + Vector2(0.008, 0.008)
				var x := clampf(-cw * 0.5 + cw * (c + 0.2 + 0.6 * KIT.hash01(n, 16)) / cols, -cw * 0.5 + reach.x, cw * 0.5 - reach.x)
				var y := clampf(h * 0.5 - ch * 0.5 + ch * (r + 0.2 + 0.6 * KIT.hash01(n, 18)) / rows, h * 0.5 - ch * 0.5 + reach.y, h * 0.5 + ch * 0.5 - reach.y)
				notice(p, Vector3(x, y, face + NOTICE_LAYER * layer), sheet, a, n)
				layer += 1
	return KIT.finish(builder, p, "notice_board", size, {"wall": true, "mount": 1.0, "solid": false})

## One sheet pinned at `centre`, turned `a` in its plane: its paper, what is on
## it (typed lines under a heading, a hand's lines, a ruled form or a calendar
## under its picture) and one pin, or two on a wide one; by `n`.
static func notice(p: Dictionary, centre: Vector3, sheet: Vector2, a: float, n: int) -> void:
	var turn := Basis(Vector3.BACK, a)
	var key: String = NOTICE_PAPERS[int(KIT.hash01(n, 20) * NOTICE_PAPERS.size()) % NOTICE_PAPERS.size()]
	KIT.stroke(p, key, centre, sheet, turn)
	var ink := centre + Vector3(0.0, 0.0, 0.00015)
	var m := minf(0.015, sheet.x * 0.1)
	var top := sheet.y * 0.5 - m
	var style := KIT.hash01(n, 21)
	if sheet.y > 0.35:
		# A calendar: its picture over a grid of seven days by five weeks.
		var picture: String = "cloth_green" if KIT.hash01(n, 22) < 0.5 else "cloth_navy"
		KIT.stroke(p, picture, ink + turn * Vector3(0.0, top - sheet.y * 0.2, 0.0), Vector2(sheet.x - 2.0 * m, sheet.y * 0.4), turn)
		var grid_top := top - sheet.y * 0.46
		var grid_h := grid_top - (-sheet.y * 0.5 + m)
		for row in 6:
			KIT.stroke(p, "steel_grey", ink + turn * Vector3(0.0, grid_top - grid_h * row / 5.0, 0.0), Vector2(sheet.x - 2.0 * m, 0.0015), turn)
		for col in 8:
			KIT.stroke(p, "steel_grey", ink + turn * Vector3(-sheet.x * 0.5 + m + (sheet.x - 2.0 * m) * col / 7.0, grid_top - grid_h * 0.5, 0.0), Vector2(0.0015, grid_h), turn)
	elif style < 0.25 and sheet.y > 0.15:
		# A ruled form: full rules, and one down its first column.
		var count := int((sheet.y - 2.0 * m - 0.03) / 0.022)
		KIT.stroke(p, "black", ink + turn * Vector3(0.0, top - 0.008, 0.0), Vector2(sheet.x * 0.5, 0.007), turn)
		for i in count:
			KIT.stroke(p, "steel_grey", ink + turn * Vector3(0.0, top - 0.03 - i * 0.022, 0.0), Vector2(sheet.x - 2.0 * m, 0.0015), turn)
		KIT.stroke(p, "steel_grey", ink + turn * Vector3(-sheet.x * 0.15, top - 0.03 - (count - 1) * 0.011, 0.0), Vector2(0.0015, (count - 1) * 0.022), turn)
	else:
		# Typed lines under a heading, or a hand's in blue on the small ones.
		var hand := sheet.x < 0.15 or style > 0.8
		var pitch := 0.018 if hand else 0.012
		var count := mini(16, int((sheet.y - 2.0 * m - 0.02) / pitch))
		var line_ink: String = "cloth_navy" if hand else "steel_grey"
		if not hand: KIT.stroke(p, "black", ink + turn * Vector3(-sheet.x * 0.1, top - 0.006, 0.0), Vector2(sheet.x * 0.55, 0.008), turn)
		for i in count:
			var long := (sheet.x - 2.0 * m) * (0.55 + 0.45 * KIT.hash01(n * 7 + i, 23))
			KIT.stroke(p, line_ink, ink + turn * Vector3(-sheet.x * 0.5 + m + long * 0.5, top - 0.024 - i * pitch, 0.0), Vector2(long, 0.003 if hand else 0.0025), turn)
	var pin: String = NOTICE_PINS[int(KIT.hash01(n, 24) * NOTICE_PINS.size()) % NOTICE_PINS.size()]
	var heads: Array = [0.0] if sheet.x < 0.25 else [-sheet.x * 0.38, sheet.x * 0.38]
	for hx: float in heads:
		KIT.cylinder(p, pin, centre + turn * Vector3(hx, sheet.y * 0.5 - 0.012, 0.0) + Vector3(0.0, 0.0, 0.0018), 0.005, 0.003, 6, KIT.along_z())

## An open key cabinet: a steel box with hooks on a cork back, some with a key.
static func key_cabinet(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("key_cabinet", size), func() -> ArrayMesh: return make_key_cabinet(builder, size))

static func make_key_cabinet(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "steel_olive", Vector3(0.0, h * 0.5, -d * 0.5 + 0.005), Vector3(w, h, 0.01))
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "steel_olive", Vector3(s * (w * 0.5 - 0.01), h * 0.5, 0.005), Vector3(0.02, h, d - 0.01), 0.002)
	for y: float in [h - 0.01, 0.01]:
		KIT.block(p, "steel_olive", Vector3(0.0, y, 0.005), Vector3(w - 0.04, 0.02, d - 0.01), 0.002)
	KIT.block(p, "cork", Vector3(0.0, h * 0.5, -d * 0.5 + 0.013), Vector3(w - 0.04, h - 0.04, 0.006))
	for r in 4:
		for c in 6:
			var hx := -w * 0.5 + 0.02 + (w - 0.04) * (c + 0.5) / 6.0
			var hy := 0.02 + (h - 0.04) * (r + 0.75) / 4.0
			KIT.cylinder(p, "metal", Vector3(hx, hy, -d * 0.5 + 0.031), 0.003, 0.03, 6, KIT.along_z())
			if KIT.hash01(r * 6 + c, 19) < 0.6:
				KIT.block(p, "gold", Vector3(hx, hy - 0.022, -d * 0.5 + 0.03), Vector3(0.012, 0.04, 0.003))
				KIT.block(p, "paper", Vector3(hx, hy - 0.049, -d * 0.5 + 0.03), Vector3(0.022, 0.014, 0.002))
	return KIT.finish(builder, p, "key_cabinet", size, {"wall": true, "mount": 1.3, "solid": false})

## A framed mirror: a metal frame round the glass, on a black backing.
static func mirror(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("mirror", size), func() -> ArrayMesh: return make_mirror(builder, size))

static func make_mirror(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	frame(p, "metal", w, h, d, 0.02)
	KIT.block(p, "mirror", Vector3(0.0, h * 0.5, d * 0.5 - 0.006), Vector3(w - 0.036, h - 0.036, 0.004))
	KIT.block(p, "black", Vector3(0.0, h * 0.5, -d * 0.5 + 0.004), Vector3(w - 0.01, h - 0.01, 0.008))
	return KIT.finish(builder, p, "mirror", size, {"wall": true, "mount": 1.1, "solid": false})

## A coat hook rail: a row of metal hooks on an oak plate.
static func coat_hook_rail(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("coat_hook_rail", size), func() -> ArrayMesh: return make_coat_hook_rail(builder, size))

static func make_coat_hook_rail(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "oak_door", Vector3(0.0, h * 0.5, -d * 0.5 + 0.011), Vector3(w, h, 0.022), 0.004)
	var n := maxi(2, int(w / 0.22))
	for k in n:
		var x := -w * 0.5 + w * (k + 0.5) / n
		KIT.cylinder(p, "metal", Vector3(x, h * 0.4, -d * 0.5 + 0.052), 0.006, 0.06, 8, KIT.along_z())
		KIT.cylinder(p, "metal", Vector3(x, h * 0.4 + 0.02, -d * 0.5 + 0.076), 0.006, 0.04, 8)
	return KIT.finish(builder, p, "coat_hook_rail", size, {"wall": true, "mount": 1.6, "solid": false})

## A roll-down screen: its ceramic roller up top, a paper screen and a cord.
static func roll_screen(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("roll_screen", size), func() -> ArrayMesh: return make_roll_screen(builder, size))

static func make_roll_screen(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.cylinder(p, "ceramic", Vector3(0.0, h - 0.04, -d * 0.5 + 0.05), 0.038, w - 0.04, 16, KIT.along_x())
	for s: float in [-1.0, 1.0]:
		KIT.cylinder(p, "black", Vector3(s * (w * 0.5 - 0.01), h - 0.04, -d * 0.5 + 0.05), 0.04, 0.02, 16, KIT.along_x())
	KIT.block(p, "paper", Vector3(0.0, (0.04 + h - 0.078) * 0.5, -d * 0.5 + 0.05), Vector3(w - 0.1, h - 0.118, 0.002))
	KIT.block(p, "black", Vector3(0.0, 0.03, -d * 0.5 + 0.05), Vector3(w - 0.08, 0.025, 0.015), 0.003)
	KIT.cylinder(p, "black", Vector3(0.0, 0.009, -d * 0.5 + 0.05), 0.0015, 0.018, 4)
	return KIT.finish(builder, p, "roll_screen", size, {"wall": true, "mount": 1.15, "solid": false})
