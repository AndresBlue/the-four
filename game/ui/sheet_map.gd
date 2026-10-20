extends Control
## The plan on the shared sheet (floor_map.gd keeps what it knows): the walls
## of the planta being looked at, drawn as the survivors have seen them, in an
## ink that browns and goes as the page forgets -- iron-gall, the ink of old
## ledgers and old plans. It is the one thing on the sheet nobody drew.
##
## What makes it wrong in the right way: a stretch of wall seen for the first
## time (or again, after it had gone) blooms into the paper, spreading a
## moment before it settles; every line carries a faint afterimage of itself
## a little off to one side, as a bad print does; and as a line ages it does
## not only pale, it comes apart in patches, each fading on its own, before it
## is gone -- never a step you can see (fading()). The lines
## wander a little, the same way at the same place, as a hand's would, with
## round ends, so the corners of the plan are soft.
const STYLE := preload("res://game/ui/osd_style.gd")
const INK := Color(0.32, 0.17, 0.09)
const GHOST := Color(0.48, 0.1, 0.24)
const WIDTH := 2.6
## How long a line takes to bloom into the page, how much wider it is at
## first, and how far off its afterimage lies.
const BLOOM := 0.9
const BLOOM_WIDTH := 1.4
const GHOST_OFFSET := Vector2(1.6, -1.1)
## Below this freshness a line starts to come apart.
const FRAYING := 0.35
## How far a line wanders from true, in pixels.
const WANDER := 0.45
## Redrawn this often while it is open: the ink is alive, but slowly.
const REDRAW := 1.0 / 24.0
var source
var redraw_clock := 0.0
## What of the planta the page frames: what is on it, never less than LEAST
## metres a side, eased towards as more is seen (EASE seconds) -- a few rooms
## drawn large at first, the whole planta small once it has all been seen.
const LEAST := 40.0
const EASE := 1.5
var framed := Rect2()
var framed_planta := -1
## Where the plan was last put on the page: plan point * fit + origin.
var origin := Vector2.ZERO
var fit := 1.0
## The pencil on the plan (paper_sheet.gd's map strokes): the layer under the
## plan they are drawn in, and op_id -> {line, planta, points (plan)}.
var pencil: Control
var pencil_lines := {}
## Circles the hints this player has read put on the plan (code_lock.hint_marks:
## the carbon copy's, the other sheet's four), [{planta, centre (plan), radius,
## ink}]: somebody else's pencil, framed with what has been seen, so a circle
## where nobody has been yet still shows where it is from here.
var marks: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	redraw_clock -= delta
	if redraw_clock > 0.0: return
	redraw_clock = REDRAW
	queue_redraw()

## A point of the plan put down where a hand would have put it: the same small
## miss at the same place, so two lines meeting there still meet.
static func wander(at: Vector2) -> Vector2:
	var key := Vector2(roundf(at.x * 4.0), roundf(at.y * 4.0))
	var h := sin(key.x * 12.9898 + key.y * 78.233) * 43758.5453
	var k := sin(key.x * 39.3468 + key.y * 11.135) * 24634.6345
	return Vector2(h - floorf(h) - 0.5, k - floorf(k) - 0.5) * 2.0 * WANDER

## A point on the page (in the plan's own box) as a point of the building.
func to_plan(local: Vector2) -> Vector2:
	return (local - origin) / maxf(fit, 0.0001)

func add_pencil_point(op_id: String, at: Vector2) -> void:
	if not pencil_lines.has(op_id): return
	var entry: Dictionary = pencil_lines[op_id]
	var points: PackedVector2Array = entry.points
	points.append(at)
	entry.points = points
	entry.line.add_point(origin + at * fit)

## Every stroke on the plan put where the plan is now, and only this planta's.
func lay_pencil(planta: int) -> void:
	for entry in pencil_lines.values():
		var line: Line2D = entry.line
		if not is_instance_valid(line): continue
		line.visible = int(entry.planta) == planta
		if not line.visible: continue
		var placed := PackedVector2Array()
		for at in entry.points: placed.append(origin + at * fit)
		line.points = placed

## The part of the planta to fit on the page, eased there from the last one.
func frame(planta: int, shown: PackedInt32Array) -> Rect2:
	var seen := Rect2()
	var any := false
	for index in shown:
		if not any: seen = Rect2(source.piece_a[index], Vector2.ZERO)
		any = true
		seen = seen.expand(source.piece_a[index]).expand(source.piece_b[index])
	for mark in marks:
		if int(mark.planta) != planta: continue
		var reach := Vector2.ONE * float(mark.radius)
		if not any: seen = Rect2(mark.centre - reach, reach * 2.0)
		any = true
		seen = seen.expand(mark.centre - reach).expand(mark.centre + reach)
	var whole: Rect2 = source.bounds.get(planta, Rect2())
	if not any: seen = Rect2(whole.get_center(), Vector2.ZERO)
	var centre := seen.get_center()
	var extent := Vector2(maxf(seen.size.x, LEAST), maxf(seen.size.y, LEAST))
	var wanted := Rect2(centre - extent * 0.5, extent)
	if framed_planta != planta or framed.size == Vector2.ZERO:
		framed = wanted
		framed_planta = planta
	else:
		var step := clampf(REDRAW / EASE * 3.0, 0.0, 1.0)
		framed = Rect2(framed.position.lerp(wanted.position, step), framed.size.lerp(wanted.size, step))
	return framed

## One stroke of the plan, and its faint afterimage off to one side; the
## lists are emptied for the next.
func stroke(points: PackedVector2Array, inks: PackedColorArray) -> void:
	if points.size() >= 2:
		var ghosts := PackedColorArray()
		var shifted := PackedVector2Array()
		for k in points.size():
			ghosts.append(Color(GHOST, inks[k].a * 0.13))
			shifted.append(points[k] + GHOST_OFFSET)
		draw_polyline_colors(shifted, ghosts, WIDTH * 0.8, true)
		draw_polyline_colors(points, inks, WIDTH, true)
		draw_circle(points[0], WIDTH * 0.5, inks[0], true, -1.0, true)
		draw_circle(points[points.size() - 1], WIDTH * 0.5, inks[inks.size() - 1], true, -1.0, true)
	points.clear()
	inks.clear()

## How much ink a piece has left. It pales all its life along a curve that
## leaves it with no slope at either end -- it starts going unnoticed and it
## is gone before anybody sees the moment -- and, old enough, each piece goes
## at its own time within FRAYING, softly (FRAY_SOFT either side), so the line
## comes apart in patches instead of all at once. Nothing ever drops out in a
## step: it used to hold its ink, then lose whole thirds of a line from one
## frame to the next.
const FRAY_SOFT := 0.1
func fading(index: int, fresh: float) -> float:
	var pale := smoothstep(0.0, 1.0, fresh)
	var own := chance(index, 0) * FRAYING
	return pale * smoothstep(own - FRAY_SOFT, own + FRAY_SOFT, fresh)

## A circle in pencil, a little out of round and past where it began.
func ring(centre: Vector2, radius: float, ink: Color, seed_value: int) -> void:
	var points := PackedVector2Array()
	var start := chance(seed_value, 1) * TAU
	for step in 41:
		var angle := start + float(step) / 36.0 * TAU
		var wobble := 1.0 + 0.05 * sin(angle * 3.0 + float(seed_value)) + (chance(seed_value, step) - 0.5) * 0.05
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius * wobble)
	draw_polyline(points, Color(ink, 0.8), 2.2, true)

## A stable number in [0, 1) for a piece and a part of it.
static func chance(index: int, part: int) -> float:
	var h := sin(float(index) * 91.3458 + float(part) * 47.853) * 23421.631
	return h - floorf(h)

func _draw() -> void:
	if source == null or source.piece_a.is_empty(): return
	var planta: int = source.viewer_planta()
	var shown: PackedInt32Array = source.live_on(planta)
	var box := frame(planta, shown)
	if box.size.x <= 0.0 or box.size.y <= 0.0: return
	var margin := size * 0.05
	fit = minf((size.x - margin.x * 2.0) / box.size.x, (size.y - margin.y * 2.0) / box.size.y)
	origin = (size - box.size * fit) * 0.5 - box.position * fit
	lay_pencil(planta)
	# Which planta it is, stamped small in the corner the way a plan is titled.
	draw_string(STYLE.font(), Vector2(margin.x * 0.4, margin.y * 0.9), "PLANTA %d" % (planta + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(INK, 0.55))
	# Each wall was cut into pieces one after another, so neighbouring pieces
	# still on the page are drawn as one stroke: one line, round at its ends,
	# its ink paler where its pieces are older.
	var points := PackedVector2Array()
	var inks := PackedColorArray()
	var last := -2
	for index in shown:
		var fresh: float = source.freshness(index)
		if fresh <= 0.0:
			stroke(points, inks)
			last = -2
			continue
		var a: Vector2 = origin + source.piece_a[index] * fit + wander(source.piece_a[index])
		var b: Vector2 = origin + source.piece_b[index] * fit + wander(source.piece_b[index])
		var ink := Color(INK, fading(index, fresh))
		if last != index - 1 or not source.piece_a[index].is_equal_approx(source.piece_b[last]):
			stroke(points, inks)
			points.append(a)
			inks.append(ink)
		points.append(b)
		inks.append(ink)
		last = index
		# Just back on the page: the ink spreads into it before it settles.
		var blooming := clampf(1.0 - float(source.since_bloom(index)) / BLOOM, 0.0, 1.0)
		if blooming > 0.0: draw_line(a, b, Color(INK, 0.2 * blooming), WIDTH * (2.5 + BLOOM_WIDTH * blooming), true)
	stroke(points, inks)
	for index in marks.size():
		var mark: Dictionary = marks[index]
		if int(mark.planta) != planta: continue
		ring(origin + (mark.centre as Vector2) * fit, maxf(6.0, float(mark.radius) * fit), mark.ink, 31 + index * 17)
	# Where this machine's eyes are, faintly, as if the page knew.
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null and source.level != null:
		var at := Vector2(camera.global_position.x, camera.global_position.z)
		var dot := origin + at * fit
		var facing := -camera.global_basis.z
		var tick := Vector2(facing.x, facing.z).normalized() * 9.0
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.2)
		draw_arc(dot, 4.5, 0.0, TAU, 20, Color(GHOST, 0.55 + 0.25 * pulse), 1.6, true)
		if tick.length() > 0.1: draw_line(dot + tick * 0.6, dot + tick * 1.3, Color(GHOST, 0.6), 1.6, true)
