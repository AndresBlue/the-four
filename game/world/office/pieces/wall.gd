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

## A cork notice board with papers pinned to it, each placed by its hash.
static func notice_board(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("notice_board", size), func() -> ArrayMesh: return make_notice_board(builder, size))

static func make_notice_board(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var fw := 0.025
	var cw := w - 2.0 * fw
	var ch := h - 2.0 * fw
	frame(p, "oak_door", w, h, d, fw)
	KIT.block(p, "cork", Vector3(0.0, h * 0.5, -d * 0.5 + 0.008), Vector3(cw, ch, 0.016))
	var n := 6 + int(KIT.hash01(1, 14) * 4.0)
	for k in n:
		var sx := 0.15 + 0.06 * KIT.hash01(k, 15)
		var sy := 0.2 + 0.08 * KIT.hash01(k, 16)
		# The golden ratio spreads them across the board; a hash can clump them.
		var x := lerpf(-(cw * 0.5 - sx * 0.5 - 0.02), cw * 0.5 - sx * 0.5 - 0.02, fposmod((k + 0.5) * 0.618034, 1.0))
		var y := h * 0.5 + lerpf(-(ch * 0.5 - sy * 0.5 - 0.02), ch * 0.5 - sy * 0.5 - 0.02, KIT.hash01(k, 18))
		var z := -d * 0.5 + 0.0165 + 0.001 * k
		KIT.block(p, "paper", Vector3(x, y, z), Vector3(sx, sy, 0.0005), 0.0, Basis(Vector3.BACK, (KIT.hash01(k, 19) - 0.5) * 0.12))
		KIT.cylinder(p, "cloth_red", Vector3(x, y + sy * 0.5 - 0.015, z + 0.003), 0.004, 0.005, 6, KIT.along_z())
	return KIT.finish(builder, p, "notice_board", size, {"wall": true, "mount": 1.0, "solid": false})

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
