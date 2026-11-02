extends RefCounted
## Power equipment: the board, its conduits, a lever's handle, the main supply box and a minutero's switch (spec_rediseno.md 6, area 5): KIT's frame,
## cache and materials (pieces/kit.gd).
const KIT := preload("res://game/world/office/pieces/kit.gd")

## The sizes power_objective.gd places these at.
const BOARD := Vector3(2.6, 2.4, 0.2)
const CONDUITS_DEPTH := 0.18
const HANDLE := Vector3(0.05, 0.26, 0.05)
const RED_HANDLE := Vector3(0.07, 0.34, 0.07)
const SUPPLY := Vector3(0.6, 0.75, 0.16)
## The supply box: its gap to the board and the height of its bottom.
const SUPPLY_GAP := 0.15
const SUPPLY_Y := 1.3
const SWITCH := Vector3(0.1, 0.14, 0.05)
## A minutero's pilot lens: its size, its bottom over the switch's and the
## switch's face off the wall.
const SWITCH_LENS := Vector3(0.024, 0.024, 0.012)
const SWITCH_LENS_Y := 0.018
const SWITCH_FACE := 0.028
## The zone plates' height on the board and their face off the wall, in
## power_objective.gd's board frame (origin on the wall, +Z out).
const PLATE_Y := 1.85
const PLATE_Z := 0.1255
## The levers as power_objective.gd lays them out (lever_at()): the first's
## x from the board's middle, their pitch and the red one's gap.
const FIRST := -1.05
const PITCH := 0.3
const GAP := 0.2
## The red cabinet's plate: its width, kept inside the board with seven zones.
const RED_PLATE := 0.26

## The middle of the red cabinet's plate across the board: over its lever,
## or as far right as the board lets it (seven zones).
static func red_plate_x(zones: int) -> float:
	return minf(FIRST + PITCH * zones + GAP, BOARD.x * 0.5 - 0.02 - RED_PLATE * 0.5)

## Every piece of this family at its usual size: [name, mesh] pairs, for the
## sheet and the test (pieces/index.gd).
static func samples(builder: Node3D) -> Array:
	return [
		["power_board_5", power_board(builder, BOARD, 5)],
		["board_conduits", board_conduits(builder, Vector3(2.6, 0.5, CONDUITS_DEPTH))],
		["lever_zone", lever_handle(builder, HANDLE, false)],
		["lever_red", lever_handle(builder, RED_HANDLE, true)],
		["main_supply_box", main_supply_box(builder, SUPPLY)],
		["timer_switch", timer_switch(builder, SWITCH)],
	]

## The board on its wall: one cabinet per zone lever and the red one's apart,
## with its meters, pilots and plates. Its zones are the objective's, 1 to 7.
static func power_board(builder: Node3D, size: Vector3, zones: int) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("power_board", size, str(zones)), func() -> ArrayMesh: return make_power_board(builder, size, zones))

static func make_power_board(builder: Node3D, size: Vector3, zones: int) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var d := size.z
	var n := zones
	var zf := -d / 2.0 + 0.12
	var xr := FIRST + PITCH * n + GAP
	var pc := red_plate_x(n)
	var rb := minf(0.14, 2.0 * (w / 2.0 - 0.005 - xr))
	var left := -w / 2.0 + 0.1
	var zone_end := left + PITCH * n
	var red_l := zone_end + 0.02
	var red_r := minf(w / 2.0 - 0.02, maxf(w / 2.0 - 0.1, xr + 0.16))
	var rw := red_r - red_l
	var rx := (red_l + red_r) / 2.0
	KIT.block(p, "black", Vector3(0.0, 1.25, -d / 2.0 + 0.002), Vector3(w - 0.2, 2.3, 0.004))
	KIT.block(p, "black", Vector3(0.0, 0.05, -0.04), Vector3(w - 0.04, 0.1, 0.12))
	for s: float in [-1.0, 1.0]:
		KIT.block(p, "steel_olive", Vector3(s * (w / 2.0 - 0.05), 1.25, -0.04), Vector3(0.1, 2.3, 0.12), 0.004)
	KIT.block(p, "steel_olive", Vector3(0.0, 2.25, -0.04), Vector3(w - 0.2, 0.3, 0.12), 0.004)
	KIT.block(p, "black", Vector3(0.0, 2.25, zf + 0.002), Vector3(0.7, 0.12, 0.004))
	for i in n:
		var x: float = FIRST + PITCH * i
		KIT.block(p, "steel_olive", Vector3(x, 1.45, -0.04), Vector3(0.296, 1.3, 0.12), 0.004)
		KIT.block(p, "steel_olive", Vector3(x, 0.45, -0.04), Vector3(0.296, 0.7, 0.12), 0.004)
		for k in 4:
			KIT.block(p, "black", Vector3(x, 0.3 + k * 0.03, zf + 0.001), Vector3(0.16, 0.012, 0.002))
		KIT.block(p, "black", Vector3(x, PLATE_Y, zf + 0.002), Vector3(0.26, 0.1, 0.004))
		KIT.block(p, "black", Vector3(x, 1.62, zf + 0.006), Vector3(0.1, 0.1, 0.012), 0.003)
		KIT.block(p, "ceramic", Vector3(x, 1.625, zf + 0.0125), Vector3(0.082, 0.07, 0.001))
		KIT.block(p, "black", Vector3(x + 0.01, 1.615, zf + 0.0135), Vector3(0.003, 0.045, 0.001), 0.0, Basis(Vector3.BACK, -0.5))
		for s: float in [-1.0, 1.0]:
			KIT.cylinder(p, "lamp_off", Vector3(x + s * 0.04, 1.53, zf + 0.004), 0.009, 0.008, 8, KIT.along_z())
		KIT.block(p, "black", Vector3(x, 1.3, zf + 0.025), Vector3(0.09, 0.26, 0.05), 0.004)
		KIT.block(p, "metal", Vector3(x, 1.1, zf + 0.002), Vector3(0.1, 0.03, 0.004))
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				KIT.cylinder(p, "metal", Vector3(x + sx * 0.12, 1.45 + sy * 0.6, zf + 0.002), 0.005, 0.004, 6, KIT.along_z())
	KIT.block(p, "black", Vector3((zone_end + red_l) / 2.0, 1.1, -0.06), Vector3(red_l - zone_end, 2.0, 0.08))
	KIT.block(p, "steel_olive", Vector3(rx, 1.1, -0.04), Vector3(rw, 2.0, 0.12), 0.004)
	KIT.block(p, "black", Vector3(pc, PLATE_Y, zf + 0.002), Vector3(RED_PLATE, 0.1, 0.004))
	for k in 3:
		KIT.cylinder(p, "lamp_off", Vector3(pc - 0.05 + k * 0.05, 1.66, zf + 0.004), 0.011, 0.008, 10, KIT.along_z())
	KIT.block(p, "black", Vector3(xr, 1.3, zf + 0.025), Vector3(rb, 0.34, 0.05), 0.004)
	KIT.block(p, "metal", Vector3(pc, 0.95, zf + 0.002), Vector3(RED_PLATE, 0.12, 0.004))
	for k in 4:
		KIT.block(p, "black", Vector3(rx, 0.3 + k * 0.03, zf + 0.001), Vector3(minf(0.2, rw - 0.08), 0.012, 0.002))
	var meta := {"wall": true, "mount": 0.0, "text_plate": [Vector3(0.0, 2.25, zf + 0.005), Vector2(0.66, 0.1), Vector3(0.0, 0.0, 1.0)]}
	return KIT.finish(builder, p, "power_board_%d" % n, size, meta)

## The collector and the conduits of a board, up the wall to the ceiling.
static func board_conduits(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("board_conduits", size), func() -> ArrayMesh: return make_board_conduits(builder, size))

static func make_board_conduits(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "steel_olive", Vector3(0.0, 0.08, -d / 2.0 + 0.06), Vector3(w - 0.1, 0.16, 0.12), 0.004)
	var count := maxi(3, int((w - 0.3) / 0.22))
	for k in count:
		var x: float = -w / 2.0 + 0.2 + (w - 0.4) * k / (count - 1)
		KIT.cylinder(p, "metal", Vector3(x, (0.16 + h) / 2.0, -d / 2.0 + 0.04), 0.022, h - 0.16, 10)
		KIT.cylinder(p, "metal", Vector3(x, 0.2, -d / 2.0 + 0.04), 0.028, 0.03, 10)
	KIT.cylinder(p, "metal", Vector3(0.0, 0.19, -d / 2.0 + 0.12), 0.018, w - 0.2, 10, KIT.along_x())
	var meta := {"wall": true, "mount": 2.4}
	return KIT.finish(builder, p, "board_conduits", size, meta)

## A lever's handle: the shaft across the top, the grip under it and, on the
## red one, a steel ring. The objective hangs it from its pivot.
static func lever_handle(builder: Node3D, size: Vector3, red: bool) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("lever", size, str(red)), func() -> ArrayMesh: return make_lever_handle(builder, size, red))

static func make_lever_handle(builder: Node3D, size: Vector3, red: bool) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var shaft_key: String = "paint_red" if red else "black"
	var bar: float = 0.03 if red else 0.022
	KIT.cylinder(p, "metal", Vector3(0.0, h - 0.02, 0.0), 0.02, w, 10, KIT.along_x())
	KIT.block(p, shaft_key, Vector3(0.0, (0.05 + h - 0.03) / 2.0, 0.0), Vector3(bar, h - 0.08, bar), 0.004)
	KIT.cylinder(p, shaft_key, Vector3(0.0, 0.03, 0.0), w * 0.45, 0.06, 12)
	if red: KIT.cylinder(p, "metal", Vector3(0.0, 0.07, 0.0), w * 0.4, 0.01, 12)
	var title: String = "lever_red" if red else "lever_zone"
	return KIT.finish(builder, p, title, size)

## The main supply box: a steel door with three meters, a plate and a brass lock.
static func main_supply_box(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("main_supply_box", size), func() -> ArrayMesh: return make_main_supply_box(builder, size))

static func make_main_supply_box(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	var zd := d / 2.0 - 0.008
	KIT.block(p, "steel_olive", Vector3(0.0, h / 2.0, -0.01), Vector3(w, h, d - 0.02), 0.008)
	KIT.front(p, "steel_olive", Vector3(0.0, h / 2.0, d / 2.0 - 0.02), Vector2(w - 0.04, h - 0.04), "", "metal", 0.0, false, 0.012)
	for k in 3:
		var gauge_x: float = -0.17 + k * 0.17
		var gauge_y: float = h - 0.17
		KIT.block(p, "black", Vector3(gauge_x, gauge_y, zd + 0.003), Vector3(0.12, 0.12, 0.006), 0.002)
		KIT.block(p, "ceramic", Vector3(gauge_x, gauge_y + 0.005, zd + 0.0065), Vector3(0.1, 0.085, 0.001))
		KIT.block(p, "black", Vector3(gauge_x + 0.012, gauge_y - 0.005, zd + 0.0075), Vector3(0.003, 0.06, 0.001), 0.0, Basis(Vector3.BACK, -0.6 + k * 0.5))
	KIT.block(p, "black", Vector3(0.0, 0.32, zd + 0.002), Vector3(0.38, 0.13, 0.004))
	KIT.cylinder(p, "metal", Vector3(w / 2.0 - 0.06, 0.32, zd + 0.004), 0.012, 0.008, 10, KIT.along_z())
	for hinge_y: float in [0.15, h - 0.15]:
		KIT.block(p, "metal", Vector3(-w / 2.0 + 0.01, hinge_y, d / 2.0 - 0.02), Vector3(0.02, 0.06, 0.02))
	var meta := {"wall": true, "mount": 1.3, "text_plate": [Vector3(0.0, 0.32, zd + 0.005), Vector2(0.36, 0.11), Vector3(0.0, 0.0, 1.0)]}
	return KIT.finish(builder, p, "main_supply_box", size, meta)

## A minutero's switch: a beige plate with a round black button. The objective
## puts its pilot lens under it.
static func timer_switch(builder: Node3D, size: Vector3) -> ArrayMesh:
	return KIT.cached(builder, KIT.key_of("timer_switch", size), func() -> ArrayMesh: return make_timer_switch(builder, size))

static func make_timer_switch(builder: Node3D, size: Vector3) -> ArrayMesh:
	var p := KIT.begin()
	var w := size.x
	var h := size.y
	var d := size.z
	KIT.block(p, "plastic_beige", Vector3(0.0, h / 2.0, -d / 2.0 + 0.006), Vector3(w, h, 0.012), 0.003)
	KIT.block(p, "plastic_beige", Vector3(0.0, h / 2.0, -d / 2.0 + 0.02), Vector3(w - 0.016, h - 0.016, 0.016), 0.004)
	KIT.cylinder(p, "metal", Vector3(0.0, 0.08, 0.0045), 0.027, 0.002, 14, KIT.along_z())
	KIT.cylinder(p, "black", Vector3(0.0, 0.08, 0.0115), 0.022, 0.016, 14, KIT.along_z())
	var meta := {"wall": true, "mount": 1.13}
	return KIT.finish(builder, p, "timer_switch", size, meta)
