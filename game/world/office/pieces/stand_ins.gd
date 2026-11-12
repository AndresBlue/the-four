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

## Executive armchair in dark leather on five casters: a deep seat cushion with
## a rolled front, a tall back reclined a little, its face buttoned into
## pillows (capitoné) under a head roll, and padded arms on steel loops.
static func exec_chair(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("exec_chair", size), func() -> ArrayMesh: return make_exec_chair(builder, size))

static func make_exec_chair(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	# The star: five legs dropping to their casters from a hub, a gas column.
	for k in 5:
		var a := TAU * k / 5
		var out := Vector3(sin(a), 0.0, cos(a))
		KIT.block(p, "black", out * w * 0.22 + Vector3(0, 0.075, 0), Vector3(0.045, 0.035, w * 0.42), 0.008, Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.1))
		KIT.cylinder(p, "black", out * w * 0.4 + Vector3(0, 0.025, 0), 0.025, 0.035, 8, Basis(Vector3.UP, a) * KIT.along_x())
	KIT.cylinder(p, "black", Vector3(0, 0.09, 0), 0.05, 0.06, 10)
	KIT.cylinder(p, "metal", Vector3(0, 0.25, 0), 0.026, 0.3, 10)
	KIT.block(p, "black", Vector3(0, 0.405, -0.02), Vector3(0.22, 0.04, 0.24), 0.008)
	# The seat: a cushion with eased edges, its front rolled over.
	var seat_w := w * 0.76
	KIT.block(p, "leather", Vector3(0, 0.465, 0.02), Vector3(seat_w, 0.1, d * 0.74), 0.04)
	KIT.cylinder(p, "leather", Vector3(0, 0.46, 0.02 + d * 0.37 - 0.035), 0.05, seat_w - 0.06, 12, KIT.along_x())
	# The back, in its own frame: a pivot over the seat's rear, reclined.
	var back := Transform3D(Basis(Vector3.RIGHT, -0.14), Vector3(0, 0.52, -d * 0.27))
	var tall := h - 0.55
	var back_w := w * 0.78
	KIT.block(p, "leather", back * Vector3(0, tall * 0.48, -0.025), Vector3(back_w, tall * 0.96, 0.07), 0.03, back.basis)
	# Its face: one padded cushion, buttoned in a diamond (capitoné): rows of
	# big buttons offset row by row, a dark pleat from each to the ones above.
	# Separate pillows read as a grid of blocks from across the room.
	var face_h := tall * 0.74
	KIT.block(p, "leather", back * Vector3(0, 0.06 + face_h * 0.5, 0.022), Vector3(back_w - 0.04, face_h, 0.05), 0.03, back.basis)
	var step := Vector2((back_w - 0.12) / 4.0, face_h / 5.0)
	var face_z := 0.047
	for r in 5:
		for c in 5:
			if (r + c) % 2 == 1: continue
			var at := Vector2((c - 2) * step.x, 0.06 + step.y * (r + 0.5))
			KIT.cylinder(p, "black", back * Vector3(at.x, at.y, face_z + 0.001), 0.011, 0.006, 8, back.basis * KIT.along_z())
			if r == 4: continue
			for s: float in [-1.0, 1.0]:
				if c + int(s) < 0 or c + int(s) > 4: continue
				var mid := at + Vector2(s * step.x, step.y) * 0.5
				var lean := atan2(-s * step.x, step.y)
				KIT.stroke(p, "black", back * Vector3(mid.x, mid.y, face_z + 0.0005), Vector2(0.004, step.length()), back.basis * Basis(Vector3.BACK, lean))
	KIT.cylinder(p, "leather", back * Vector3(0, tall * 0.88, 0.005), 0.045, back_w - 0.04, 12, back.basis * KIT.along_x())
	# The arms: a padded rest on a steel loop from the seat's side.
	for s: float in [-1.0, 1.0]:
		var x := s * (w * 0.5 - 0.05)
		KIT.block(p, "leather", Vector3(x, 0.665, 0.02), Vector3(0.075, 0.05, d * 0.6), 0.022)
		for z: float in [-0.12, 0.13]:
			KIT.block(p, "metal", Vector3(x, 0.565, z), Vector3(0.022, 0.19, 0.03), 0.005)
		KIT.block(p, "metal", Vector3(x, 0.47, 0.005), Vector3(0.022, 0.022, 0.28), 0.005)
		KIT.block(p, "metal", Vector3((x + s * seat_w * 0.5) * 0.5, 0.47, 0.005), Vector3(absf(x) - seat_w * 0.5 + 0.01, 0.02, 0.04))
	return KIT.finish(builder, p, "exec_chair", size)

## Walnut visitor chair with an upholstered leather seat and back, for the desks
## and the boardroom: square legs, the back ones raked into the back posts,
## side and front rails, a padded back between the posts under a top rail,
## and wooden arms on turned supports.
static func visitor_chair(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("visitor_chair", size), func() -> ArrayMesh: return make_visitor_chair(builder, size))

static func make_visitor_chair(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var lx := w / 2 - 0.035
	var seat := 0.43
	var rake := Basis(Vector3.RIGHT, -0.08)
	for s: float in [-1.0, 1.0]:
		# Front leg, and the back leg and its post leaning back.
		KIT.block(p, "walnut_object", Vector3(s * lx, seat * 0.5, d / 2 - 0.05), Vector3(0.036, seat, 0.036), 0.005)
		KIT.block(p, "walnut_object", Vector3(s * lx, seat * 0.5, -d / 2 + 0.07), Vector3(0.036, seat, 0.036), 0.005)
		KIT.block(p, "walnut_object", Vector3(s * lx, (seat + h - 0.01) * 0.5, -d / 2 + 0.07 - 0.0165), Vector3(0.034, h - 0.01 - seat, 0.034), 0.005, rake)
		# Rails: the seat's side, the stretcher low down.
		KIT.block(p, "walnut_object", Vector3(s * lx, seat - 0.03, 0.0), Vector3(0.026, 0.06, d - 0.12), 0.004)
		KIT.block(p, "walnut_object", Vector3(s * lx, 0.14, 0.0), Vector3(0.02, 0.025, d - 0.12), 0.004)
		# The arm: a rest from the post to the front, on a support over the front leg.
		KIT.block(p, "walnut_object", Vector3(s * lx, 0.655, 0.01), Vector3(0.05, 0.028, d - 0.11), 0.01)
		KIT.block(p, "walnut_object", Vector3(s * lx, (seat + 0.65) * 0.5, d / 2 - 0.07), Vector3(0.03, 0.65 - seat, 0.03), 0.006, Basis(Vector3.RIGHT, 0.12))
	KIT.block(p, "walnut_object", Vector3(0, seat - 0.03, d / 2 - 0.05), Vector3(2 * lx, 0.06, 0.026), 0.004)
	KIT.block(p, "walnut_object", Vector3(0, seat - 0.03, -d / 2 + 0.07), Vector3(2 * lx, 0.06, 0.026), 0.004)
	# The seat: a cushion over the rails, eased all round.
	KIT.block(p, "leather", Vector3(0, seat + 0.04, 0.01), Vector3(2 * lx - 0.02, 0.08, d - 0.1), 0.03)
	# The back: a pad between the posts, leaning with them, under a top rail.
	var pad := Transform3D(rake, Vector3(0, seat + 0.07, -d / 2 + 0.07))
	KIT.block(p, "leather", pad * Vector3(0, (h - seat - 0.12) * 0.5, 0.0), Vector3(2 * lx - 0.04, h - seat - 0.17, 0.055), 0.022, rake)
	KIT.block(p, "walnut_object", pad * Vector3(0, h - seat - 0.1, -0.012), Vector3(2 * lx, 0.035, 0.03), 0.006, rake)
	return KIT.finish(builder, p, "visitor_chair", size)

## Desk lamp: a banker's lamp (a green half-round shade on a turned brass
## stem and foot) or a black arm lamp (a weighted foot, two jointed arms with
## their springs, a conical shade over its bulb).
static func desk_lamp(builder: Node3D, size: Vector3, look: String) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("desk_lamp", size, look), func() -> ArrayMesh: return make_desk_lamp(builder, size, look))

static func make_desk_lamp(builder: Node3D, size: Vector3, look: String) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	if look == "banker":
		# The foot, turned: a plinth, a step and a dome; the stem with its knop.
		var sx := -d * 0.15
		KIT.cylinder(p, "gold", Vector3(0, 0.008, sx), 0.075, 0.016, 16)
		KIT.cylinder(p, "gold", Vector3(0, 0.022, sx), 0.06, 0.012, 16)
		KIT.cylinder(p, "gold", Vector3(0, 0.036, sx), 0.036, 0.016, 12)
		var top := h - 0.1
		KIT.cylinder(p, "gold", Vector3(0, (0.044 + top) * 0.5, sx), 0.009, top - 0.044, 8)
		KIT.cylinder(p, "gold", Vector3(0, top * 0.45, sx), 0.016, 0.02, 10)
		KIT.cylinder(p, "gold", Vector3(0, top, (sx + 0.02) * 0.5), 0.007, 0.02 - sx, 8, KIT.along_z())
		# The shade: a half round of green glass along x, open below, its lips in brass.
		var cy := h - 0.08
		var cz := 0.02
		var rad := 0.07
		var span := w - 0.04
		var n := 9
		for k in n:
			var th := -0.2 + (PI + 0.4) * (k + 0.5) / n
			var chord := 2.0 * rad * sin((PI + 0.4) / n * 0.5) + 0.002
			KIT.block(p, "cloth_green", Vector3(0, cy + sin(th) * rad, cz + cos(th) * rad), Vector3(span, 0.005, chord), 0.0, Basis(Vector3.RIGHT, PI * 0.5 - th))
		for th: float in [-0.2, PI + 0.2]:
			KIT.cylinder(p, "gold", Vector3(0, cy + sin(th) * rad, cz + cos(th) * rad), 0.004, span + 0.006, 6, KIT.along_x())
		KIT.block(p, "lamp_off", Vector3(0, cy - 0.02, cz), Vector3(span - 0.06, 0.004, 0.06))
		KIT.cylinder(p, "gold", Vector3(span * 0.3, cy - rad * 0.2 - 0.03, cz + rad * 0.7), 0.002, 0.06, 4)
	else:
		# The foot, and the lower arm from its hinge to the elbow, the upper on
		# to the head: each a pair of rods with a spring beside them.
		KIT.cylinder(p, "black", Vector3(0, 0.0125, -0.055), w * 0.4, 0.025, 16)
		KIT.cylinder(p, "black", Vector3(0, 0.04, -0.1), 0.018, 0.03, 10)
		var hinge := Vector3(0, 0.05, -0.1)
		var elbow := Vector3(0, 0.33, -0.06)
		var head := Vector3(0, 0.45, 0.03)
		for arm: Array in [[hinge, elbow], [elbow, head]]:
			var a: Vector3 = arm[0]
			var b: Vector3 = arm[1]
			var turn := Basis(Vector3.RIGHT, atan2(b.z - a.z, b.y - a.y))
			var length := (b - a).length()
			for s: float in [-1.0, 1.0]:
				KIT.block(p, "black", (a + b) * 0.5 + Vector3(s * 0.012, 0, 0), Vector3(0.007, length, 0.007), 0.0, turn)
			KIT.cylinder(p, "metal", (a + b) * 0.5 + Vector3(0.024, 0, 0), 0.005, length * 0.6, 6, turn)
		KIT.cylinder(p, "black", elbow, 0.014, 0.034, 10, KIT.along_x())
		# The shade: a cone of twelve leaves from its cap, aimed down and forward.
		var aim := Basis(Vector3.RIGHT, -0.5)
		var apex := Vector3(0, 0.445, 0.06)
		var deep := 0.11
		var r1 := 0.025
		var r2 := 0.065
		var tilt := atan2(r2 - r1, deep)
		var leaves := 12
		for k in leaves:
			var a := TAU * k / leaves
			var spin := Basis(Vector3.UP, a)
			KIT.block(p, "black", apex + aim * spin * Vector3(0, -deep * 0.5, (r1 + r2) * 0.5), Vector3(TAU * r2 / leaves * 1.05, deep / cos(tilt), 0.003), 0.0, aim * spin * Basis(Vector3.RIGHT, -tilt))
		KIT.cylinder(p, "black", apex + aim * Vector3(0, 0.01, 0), r1 + 0.004, 0.03, 10, aim)
		KIT.cylinder(p, "lamp_off", apex + aim * Vector3(0, -0.05, 0), 0.022, 0.04, 8, aim)
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
	# A drum of cloth narrowing upwards, in rings.
	for k in 5:
		KIT.cylinder(p, "linen", Vector3(0, h - 0.31 + 0.03 + k * 0.06, 0), (w * 0.5 - 0.005) * (1.0 - 0.09 * k), 0.06, 20)
	KIT.cylinder(p, "lamp_off", Vector3(0, h - 0.315, 0), w * 0.5 - 0.03, 0.004, 16)
	return KIT.finish(builder, p, "floor_lamp", size)

## What a snack machine sells, by column pair and row: bags and bars in muted
## colours (make_vending_machine()).
const SNACKS := ["cloth_red", "plastic_beige", "cloth_navy", "gold", "cloth_green", "cardboard", "paint_red", "leather"]

## Snack machine of dark steel, for the break room: an open window over six
## trays of bags and bars (two deep, a column sold out here and there, a price
## tag under each), a steel panel at the side with its display, its keypad, the
## coin slot and return and the instructions card, and the pick-up flap below.
static func vending_machine(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("vending_machine", size), func() -> ArrayMesh: return make_vending_machine(builder, size))

static func make_vending_machine(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	# The cabinet's face, the window's hollow behind it and the window's edges.
	var front := d / 2 - 0.04
	var hollow := 0.2
	var left := -w / 2 + 0.03
	var right := w / 2 - 0.28
	var low := h * 0.235
	var top := h - 0.12
	var zc := front - hollow * 0.5
	var mx := (left + right) * 0.5
	var my := (low + top) * 0.5
	# The cabinet round the hollow: its body behind, the panel's column, the
	# side, the bands over and under the window.
	KIT.block(p, "steel_dark", Vector3(0, h / 2, (front - hollow - d / 2) * 0.5), Vector3(w, h, front - hollow + d / 2), 0.008)
	KIT.block(p, "steel_dark", Vector3((right + w / 2) * 0.5, h / 2, zc), Vector3(w / 2 - right, h, hollow))
	KIT.block(p, "steel_dark", Vector3((left - w / 2) * 0.5, h / 2, zc), Vector3(left + w / 2, h, hollow))
	KIT.block(p, "steel_dark", Vector3(mx, (top + h) * 0.5, zc), Vector3(right - left, h - top, hollow))
	KIT.block(p, "steel_dark", Vector3(mx, low * 0.5, zc), Vector3(right - left, low, hollow))
	KIT.block(p, "black", Vector3(mx, my, front - hollow + 0.002), Vector3(right - left, top - low, 0.004))
	# The trays: each a shelf with its price rail, and the goods two deep.
	var rows := 6
	var cols := 6
	var rh := (top - low) / rows
	var cw := (right - left) / cols
	for r in rows:
		var y := low + rh * r
		KIT.block(p, "metal", Vector3(mx, y + 0.004, zc), Vector3(right - left, 0.008, hollow))
		KIT.block(p, "black", Vector3(mx, y + 0.02, front - 0.008), Vector3(right - left, 0.024, 0.016))
		for c in cols:
			var x := left + cw * (c + 0.5)
			KIT.stroke(p, "paper", Vector3(x, y + 0.02, front + 0.0005), Vector2(0.03, 0.012))
			var n := r * 10 + c
			if KIT.hash01(n, 60) < 0.12:
				# Sold out: its coil shows.
				KIT.cylinder(p, "metal", Vector3(x, y + 0.045, zc), 0.03, hollow - 0.02, 6, KIT.along_z())
				continue
			var key: String = SNACKS[int(KIT.hash01(r * 10 + int(c / 2.0), 61) * SNACKS.size()) % SNACKS.size()]
			var ph := rh * (0.55 + 0.15 * KIT.hash01(r, 62))
			var lean := Basis(Vector3.RIGHT, -0.1)
			KIT.block(p, key, Vector3(x, y + 0.035 + ph * 0.5, front - 0.045), Vector3(cw - 0.018, ph, 0.03), 0.008, lean)
			KIT.block(p, key, Vector3(x, y + 0.035 + ph * 0.5, front - 0.12), Vector3(cw - 0.018, ph, 0.03), 0.0, lean)
	# The window's black gasket. No pane: clear_glass baked into a MultiMesh
	# draws as a flat white sheet over the goods, and the goods are the point.
	for y: float in [low, top]:
		KIT.block(p, "black", Vector3(mx, y, front + 0.012), Vector3(right - left + 0.05, 0.025, 0.024), 0.004)
	for x: float in [left, right]:
		KIT.block(p, "black", Vector3(x, my, front + 0.012), Vector3(0.025, top - low - 0.025, 0.024), 0.004)
	# The panel: display, keypad, coin slot and return, coin cup, card.
	var px := (right + w / 2) * 0.5
	var pw := w / 2 - right - 0.05
	var face := front + 0.012
	KIT.block(p, "steel_grey", Vector3(px, (h * 0.47 + top - 0.04) * 0.5, front + 0.006), Vector3(pw, top - 0.04 - h * 0.47, 0.012), 0.003)
	var dy := top - 0.1
	KIT.block(p, "black", Vector3(px, dy, face + 0.003), Vector3(pw * 0.7, 0.055, 0.006), 0.002)
	KIT.stroke(p, "screen", Vector3(px, dy, face + 0.0065), Vector2(pw * 0.6, 0.035))
	for r in 4:
		for c in 3:
			KIT.block(p, "plastic_beige", Vector3(px + (c - 1) * 0.045, dy - 0.08 - r * 0.04, face + 0.004), Vector3(0.032, 0.024, 0.008))
	var cy := dy - 0.3
	KIT.block(p, "metal", Vector3(px - 0.04, cy, face + 0.004), Vector3(0.06, 0.09, 0.008), 0.003)
	KIT.stroke(p, "black", Vector3(px - 0.04, cy + 0.01, face + 0.0085), Vector2(0.007, 0.04))
	KIT.knob(p, "black", Vector3(px + 0.05, cy, face), 0.014, 0.012)
	KIT.block(p, "black", Vector3(px, cy - 0.11, face + 0.002), Vector3(0.08, 0.06, 0.004))
	KIT.block(p, "metal", Vector3(px, cy - 0.145, face + 0.008), Vector3(0.09, 0.012, 0.016), 0.003)
	var card_y := h * 0.47 + 0.09
	KIT.stroke(p, "paper", Vector3(px, card_y, face + 0.0005), Vector2(pw * 0.8, 0.11))
	for i in 5:
		KIT.stroke(p, "steel_grey", Vector3(px - pw * 0.05, card_y + 0.035 - i * 0.017, face + 0.0008), Vector2(pw * (0.5 + 0.15 * KIT.hash01(i, 63)), 0.004))
	# The pick-up flap under the window, and the kick strip.
	var fy := low * 0.55
	KIT.block(p, "black", Vector3(mx, fy, front + 0.002), Vector3(right - left - 0.08, 0.17, 0.004))
	KIT.block(p, "steel_grey", Vector3(mx, fy + 0.005, front + 0.012), Vector3(right - left - 0.12, 0.14, 0.01), 0.003, Basis(Vector3.RIGHT, 0.08))
	KIT.block(p, "black", Vector3(mx, fy + 0.065, front + 0.022), Vector3(right - left - 0.2, 0.015, 0.01), 0.003)
	KIT.block(p, "black", Vector3(0, 0.03, front + 0.005), Vector3(w - 0.02, 0.06, 0.01))
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

## Filter coffee maker of black plastic, on the break room counter: its base
## with the hot plate and the red switch, the tower behind, the hood with the
## filter basket under it, and the glass jug with its lid and handle.
static func coffee_maker(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("coffee_maker", size), func() -> ArrayMesh: return make_coffee_maker(builder, size))

static func make_coffee_maker(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var jz := 0.035
	KIT.block(p, "black", Vector3(0, 0.0175, 0), Vector3(w, 0.035, d), 0.008)
	KIT.cylinder(p, "metal", Vector3(0, 0.037, jz), 0.062, 0.004, 16)
	KIT.block(p, "paint_red", Vector3(w / 2 - 0.03, 0.018, d / 2 - 0.0005), Vector3(0.018, 0.012, 0.001))
	KIT.block(p, "black", Vector3(0, h / 2, -d / 2 + 0.04), Vector3(w, h, 0.08), 0.012)
	KIT.block(p, "black", Vector3(0, h - 0.035, 0.0), Vector3(w, 0.07, d - 0.02), 0.014)
	KIT.cylinder(p, "black", Vector3(0, h - 0.085, jz), 0.05, 0.03, 12)
	# The jug: its belly of dark glass with the coffee, its neck, lid and handle.
	KIT.cylinder(p, "screen", Vector3(0, 0.039 + 0.045, jz), 0.064, 0.09, 16)
	KIT.cylinder(p, "screen", Vector3(0, 0.129 + 0.018, jz), 0.05, 0.036, 16)
	KIT.cylinder(p, "black", Vector3(0, 0.171, jz), 0.054, 0.012, 16)
	KIT.block(p, "black", Vector3(0.082, 0.165, jz), Vector3(0.044, 0.014, 0.022), 0.004)
	KIT.block(p, "black", Vector3(0.097, 0.115, jz), Vector3(0.014, 0.1, 0.022), 0.004)
	KIT.block(p, "black", Vector3(0.08, 0.07, jz), Vector3(0.034, 0.014, 0.022), 0.004)
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
	# Painted aluminium, as the T-grid: metal with nothing to mirror read as a
	# black hole beside each lamp (spec "huecos negros junto a las pantallas").
	KIT.block(p, "tgrid", Vector3(0, h - 0.004, 0), Vector3(w - 0.005, 0.008, d - 0.005))
	for k in 4:
		var s := w * (0.9 - k * 0.2)
		KIT.block(p, "tgrid", Vector3(0, h - 0.013 - k * 0.01, 0), Vector3(s, 0.01, s), 0.002)
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
