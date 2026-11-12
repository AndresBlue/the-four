extends RefCounted
## Mail equipment: the pneumatic central, a station's receiver, the typewriter, the card reader, the ceiling camera, the tube's collar, a lamp's lens, the network map and an instruction plate (spec_rediseno.md 6, area 5): KIT's frame,
## cache and materials (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")
## The sizes the handlers place these at (files_objective.gd, air_objective.gd,
## power_objective.gd).
const CENTRAL := Vector3(0.56, 1.15, 0.2)
## The hub's mouth over the central's bottom (its tube rises from there).
const CENTRAL_HUB := 0.4
const RECEIVER := Vector3(0.36, 0.5, 0.16)
## A station's mouth over its receiver's bottom, and its lamp's socket.
const RECEIVER_MOUTH := 0.3
const RECEIVER_LENS := 0.43
const TYPEWRITER := Vector3(0.46, 0.3, 0.38)
const READER := Vector3(0.2, 0.28, 0.09)
const CAMERA := Vector3(0.12, 0.12, 0.26)
const COLLAR := Vector3(0.14, 0.06, 0.14)
const LENS := Vector3(0.05, 0.05, 0.02)
const MAP := Vector3(0.9, 0.62, 0.025)
const STEPS := Vector3(0.3, 0.16, 0.006)

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["mail_central", mail_central(builder, CENTRAL)],
		["station_receiver", station_receiver(builder, RECEIVER)],
		["typewriter", typewriter(builder, TYPEWRITER)],
		["card_reader", card_reader(builder, READER)],
		["ceiling_camera", ceiling_camera(builder, CAMERA)],
		["tube_collar", tube_collar(builder, COLLAR)],
		["lamp_glow_amber", lamp_lens(builder, LENS, "glow_amber")],
		["lamp_lamp_off", lamp_lens(builder, LENS, "lamp_off")],
		["network_map", network_map(builder, MAP)],
		["instruction_plate", instruction_plate(builder, STEPS)],
	]

## The pneumatic central: a green-grey panel with two rows of lamps, the mouth
## the capsules come out of, and brass tubes that rise and go into the wall.
## Its back is on the wall. Not `lit`, every lamp is out: the mail room's
## central for show (office_walls.gd, area 4c), which nothing lights.
static func mail_central(builder: Node3D, size: Vector3, lit := true) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("mail_central", size, "" if lit else "out"), func() -> ArrayMesh: return make_mail_central(builder, size, lit))

static func make_mail_central(builder: Node3D, size: Vector3, lit := true) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var ph := 0.75
	var zb := d * 0.5 - 0.02
	KIT.block(p, "steel_olive", Vector3(0, ph * 0.5 + 0.02, -0.01), Vector3(w, ph - 0.04, d - 0.02), 0.01)
	KIT.block(p, "black", Vector3(0, 0.02, -0.02), Vector3(w - 0.04, 0.04, d - 0.06))
	# The badge, then the lamps: two rows of seven, lit where the hash says so.
	KIT.block(p, "black", Vector3(0, ph - 0.06, zb + 0.002), Vector3(w - 0.08, 0.07, 0.004))
	for r in 2:
		for c in 7:
			var x := -w * 0.5 + 0.07 + c * (w - 0.14) / 6.0
			var y := ph - 0.16 - r * 0.1
			var key: String = "glow_amber" if lit and KIT.hash01(r * 7 + c, 31) < 0.3 else "lamp_off"
			KIT.block(p, "black", Vector3(x, y, zb + 0.003), Vector3(0.034, 0.034, 0.006))
			KIT.cylinder(p, key, Vector3(x, y, zb + 0.009), 0.012, 0.006, 10, KIT.along_z())
			KIT.block(p, "metal", Vector3(x, y - 0.036, zb + 0.006), Vector3(0.008, 0.016, 0.012))
	# The mouth the capsules come out of, and the tray under it.
	KIT.block(p, "black", Vector3(0, 0.24, zb + 0.001), Vector3(w - 0.14, 0.12, 0.002))
	KIT.block(p, "steel_grey", Vector3(0, 0.17, d * 0.5 - 0.02), Vector3(w - 0.1, 0.02, 0.04), 0.003)
	# The tubes: glass risers in brass (a collar at the foot, bands up them, a
	# cap and an elbow into the wall), a capsule waiting in some.
	var run := h - 0.05 - ph
	var z := -d * 0.5 + 0.05
	for k in 4:
		var x: float = [-0.21, -0.12, 0.12, 0.21][k]
		# Dark glossy glass: clear_glass draws white in a baked MultiMesh.
		KIT.cylinder(p, "screen", Vector3(x, ph + run * 0.5, z), 0.024, run, 10)
		KIT.cylinder(p, "gold", Vector3(x, ph + 0.03, z), 0.032, 0.06, 10)
		for b in range(1, 3):
			KIT.cylinder(p, "gold", Vector3(x, ph + run * b / 3.0, z), 0.028, 0.025, 10)
		KIT.cylinder(p, "gold", Vector3(x, h - 0.05, z), 0.03, 0.04, 10)
		KIT.cylinder(p, "gold", Vector3(x, h - 0.03, -d * 0.5 + 0.025), 0.022, 0.05, 10, KIT.along_z())
		if KIT.hash01(k, 32) < 0.5:
			# Its brass end showing through the glass, which hides the rest.
			KIT.cylinder(p, "gold", Vector3(x, ph + 0.14 + (run - 0.28) * KIT.hash01(k, 33), z), 0.0245, 0.012, 10)
	return KIT.finish(builder, p, "mail_central", size, {"wall": true, "mount": 0.85, "text_plate": [Vector3(0, ph - 0.06, zb + 0.005), Vector2(w - 0.1, 0.06), Vector3(0, 0, 1)]})

## A station's receiver: a steel housing with an open bay where the capsule
## waits, a hood where the tube enters, a base with the station's number plate.
static func station_receiver(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("station_receiver", size), func() -> ArrayMesh: return make_station_receiver(builder, size))

static func make_station_receiver(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "steel_olive", Vector3(0, h * 0.5, -d * 0.5 + 0.002), Vector3(w - 0.04, h, 0.004))
	KIT.block(p, "black", Vector3(0, 0.265, -d * 0.5 + 0.0045), Vector3(w - 0.04, 0.13, 0.001))
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "steel_olive", Vector3(s * (w * 0.5 - 0.01), h * 0.5, 0), Vector3(0.02, h, d), 0.003)
	KIT.block(p, "steel_olive", Vector3(0, 0.415, -0.001), Vector3(w - 0.04, 0.17, d - 0.002), 0.006)
	KIT.block(p, "steel_olive", Vector3(0, 0.1, -0.001), Vector3(w - 0.04, 0.2, d - 0.002), 0.006)
	KIT.block(p, "steel_grey", Vector3(0, 0.215, d * 0.5 - 0.008), Vector3(w - 0.04, 0.03, 0.016), 0.003)
	KIT.cylinder(p, "gold", Vector3(0, 0.322, -d * 0.5 + 0.042), 0.04, 0.016, 12)
	KIT.block(p, "black", Vector3(0, RECEIVER_LENS, d * 0.5 - 0.002), Vector3(0.056, 0.056, 0.004))
	KIT.block(p, "black", Vector3(0, 0.1, d * 0.5 - 0.002), Vector3(0.14, 0.09, 0.004))
	for s: float in [-1.0, 1.0]:
		KIT.cylinder(p, "metal", Vector3(s * (w * 0.5 - 0.03), 0.47, d * 0.5 - 0.001), 0.005, 0.004, 6, KIT.along_z())
	return KIT.finish(builder, p, "station_receiver", size, {"wall": true, "mount": 0.95, "text_plate": [Vector3(0, 0.1, d * 0.5 + 0.001), Vector2(0.12, 0.07), Vector3(0, 0, 1)]})

## An electric typewriter, green-grey, with a sheet in it; its front, where the
## keys are, faces +Z.
static func typewriter(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("typewriter", size), func() -> ArrayMesh: return make_typewriter(builder, size))

static func make_typewriter(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var d := size.z
	KIT.block(p, "steel_mint", Vector3(0, 0.04, 0.02), Vector3(w, 0.08, d - 0.04), 0.012)
	KIT.block(p, "steel_mint", Vector3(0, 0.085, 0.09), Vector3(w - 0.04, 0.03, 0.18), 0.008, Basis(Vector3.RIGHT, 0.18))
	for r in 4:
		for c in 11:
			KIT.block(p, "black", Vector3(-0.165 + c * 0.033, 0.095 + r * 0.0055, 0.15 - r * 0.03), Vector3(0.026, 0.012, 0.024), 0.002)
	KIT.block(p, "black", Vector3(0, 0.09, 0.178), Vector3(0.2, 0.01, 0.022), 0.002)
	KIT.block(p, "steel_mint", Vector3(0, 0.12, -0.08), Vector3(w, 0.08, 0.2), 0.015)
	KIT.cylinder(p, "black", Vector3(0, 0.165, -0.1), 0.03, w - 0.06, 16, KIT.along_x())
	for s: float in [-1.0, 1.0]:
		KIT.cylinder(p, "black", Vector3(s * (w * 0.5 - 0.012), 0.165, -0.1), 0.022, 0.024, 12, KIT.along_x())
	KIT.block(p, "paper", Vector3(0, 0.225, -0.13), Vector3(0.21, 0.15, 0.002), 0.0, Basis(Vector3.RIGHT, -0.3))
	KIT.block(p, "metal", Vector3(0, 0.19, -0.065), Vector3(w - 0.1, 0.008, 0.008))
	return KIT.finish(builder, p, "typewriter", size)

## A card reader on a wall: a green-grey box with its slot, a white light over
## the slot and a plate with no mark; the card goes in at the slot.
static func card_reader(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("card_reader", size), func() -> ArrayMesh: return make_card_reader(builder, size))

static func make_card_reader(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "steel_olive", Vector3(0, h * 0.5, -0.004), Vector3(w, h, d - 0.008), 0.01)
	KIT.block(p, "steel_grey", Vector3(0, 0.12, d * 0.5 - 0.006), Vector3(w - 0.05, 0.11, 0.004))
	KIT.block(p, "black", Vector3(0, 0.135, d * 0.5 - 0.003), Vector3(0.07, 0.008, 0.004))
	KIT.block(p, "steel_olive", Vector3(0, 0.16, d * 0.5 - 0.008), Vector3(0.09, 0.02, 0.016), 0.003)
	KIT.block(p, "black", Vector3(0, 0.235, d * 0.5 - 0.006), Vector3(0.034, 0.022, 0.004))
	KIT.block(p, "glow_white", Vector3(0, 0.235, d * 0.5 - 0.0025), Vector3(0.026, 0.014, 0.003))
	KIT.cylinder(p, "metal", Vector3(0, 0.075, d * 0.5 - 0.004), 0.01, 0.008, 10, KIT.along_z())
	KIT.block(p, "metal", Vector3(0, 0.035, d * 0.5 - 0.005), Vector3(0.07, 0.022, 0.004))
	return KIT.finish(builder, p, "card_reader", size, {"wall": true, "mount": 1.06})

## A ceiling camera: a beige body on a stem, its lens at -Z, where
## Basis.looking_at() points (the objective aims it).
static func ceiling_camera(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("ceiling_camera", size), func() -> ArrayMesh: return make_ceiling_camera(builder, size))

static func make_ceiling_camera(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	KIT.block(p, "steel_grey", Vector3(0, h - 0.005, 0.07), Vector3(0.08, 0.01, 0.08))
	KIT.block(p, "steel_grey", Vector3(0, h - 0.035, 0.07), Vector3(0.02, 0.05, 0.02))
	KIT.block(p, "plastic_beige", Vector3(0, 0.04, 0), Vector3(0.1, 0.08, 0.24), 0.01)
	KIT.block(p, "plastic_beige", Vector3(0, 0.082, -0.01), Vector3(w, 0.004, 0.24))
	KIT.cylinder(p, "black", Vector3(0, 0.04, -0.115), 0.03, 0.01, 12, KIT.along_z())
	KIT.cylinder(p, "screen", Vector3(0, 0.04, -0.1195), 0.022, 0.001, 12, KIT.along_z())
	return KIT.finish(builder, p, "ceiling_camera", size)

## A brass collar at a tube's joint, its axis up.
static func tube_collar(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("tube_collar", size), func() -> ArrayMesh: return make_tube_collar(builder, size))

static func make_tube_collar(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var h := size.y
	KIT.cylinder(p, "gold", Vector3(0, h * 0.5, 0), 0.068, h, 14)
	KIT.cylinder(p, "gold", Vector3(0, 0.006, 0), 0.07, 0.012, 14)
	KIT.cylinder(p, "gold", Vector3(0, h - 0.006, 0), 0.07, 0.012, 14)
	return KIT.finish(builder, p, "tube_collar", size)

## A pilot lamp's lens in its black ring; key is the lens's glow material
## (glow_amber when lit, lamp_off when not).
static func lamp_lens(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("lamp", size, key), func() -> ArrayMesh: return make_lamp_lens(builder, size, key))

static func make_lamp_lens(builder: Node3D, size: Vector3, key: String) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.cylinder(p, "black", Vector3(0, h * 0.5, -d * 0.5 + d * 0.2), minf(w, h) * 0.5, d * 0.4, 12, KIT.along_z())
	KIT.cylinder(p, key, Vector3(0, h * 0.5, d * 0.1), minf(w, h) * 0.42, d * 0.8, 12, KIT.along_z())
	return KIT.finish(builder, p, "lamp_" + key, size)

## The network map: an aluminium frame round a light board with navy lines and
## red stops; the objective writes its title.
static func network_map(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("network_map", size), func() -> ArrayMesh: return make_network_map(builder, size))

static func make_network_map(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "metal", Vector3(0, h - 0.01, 0), Vector3(w, 0.02, d), 0.003)
	KIT.block(p, "metal", Vector3(0, 0.01, 0), Vector3(w, 0.02, d), 0.003)
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "metal", Vector3(s * (w * 0.5 - 0.01), h * 0.5, 0), Vector3(0.02, h - 0.04, d), 0.003)
	KIT.block(p, "paper", Vector3(0, h * 0.5, -d * 0.5 + 0.005), Vector3(w - 0.03, h - 0.03, 0.01))
	# The trunk lines across, then the risers, then the stops.
	for k in 4:
		var y := h * (0.25 + 0.17 * k)
		var ln := (w - 0.1) * (0.45 + 0.5 * KIT.hash01(k, 41))
		var xc := -w * 0.5 + 0.05 + ln * 0.5 + (w - 0.1 - ln) * KIT.hash01(k, 42)
		KIT.block(p, "cloth_navy", Vector3(xc, y, -0.001), Vector3(ln, 0.004, 0.002))
	for k in 6:
		var x := -w * 0.5 + 0.06 + (w - 0.12) * KIT.hash01(k, 43)
		var y0 := h * 0.2
		var ln := h * (0.2 + 0.45 * KIT.hash01(k, 44))
		KIT.block(p, "cloth_navy", Vector3(x, y0 + ln * 0.5, -0.001), Vector3(0.004, ln, 0.002))
	for k in 12:
		var x := -w * 0.5 + 0.06 + (w - 0.12) * KIT.hash01(k, 45)
		var y := 0.06 + (h - 0.18) * KIT.hash01(k, 46)
		KIT.block(p, "cloth_red", Vector3(x, y, -0.0005), Vector3(0.012, 0.012, 0.002))
	return KIT.finish(builder, p, "network_map", size, {"wall": true, "mount": 1.19, "text_plate": [Vector3(w * 0.5 - 0.17, h - 0.07, 0.0), Vector2(0.28, 0.05), Vector3(0, 0, 1)]})

## An instruction plate: a light metal sheet with four screws; the objective
## writes its three steps on it.
static func instruction_plate(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("instruction_plate", size), func() -> ArrayMesh: return make_instruction_plate(builder, size))

static func make_instruction_plate(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "metal", Vector3(0, h * 0.5, 0), Vector3(w, h, d), 0.0015)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			KIT.cylinder(p, "black", Vector3(sx * (w * 0.5 - 0.012), h * 0.5 + sy * (h * 0.5 - 0.012), d * 0.5), 0.003, 0.002, 6, KIT.along_z())
	return KIT.finish(builder, p, "instruction_plate", size, {"wall": true, "mount": 1.42, "text_plate": [Vector3(0, h * 0.5, d * 0.5 + 0.001), Vector2(w - 0.04, h - 0.03), Vector3(0, 0, 1)]})
