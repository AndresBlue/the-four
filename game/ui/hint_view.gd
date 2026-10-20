extends Control
## One of the hints of the last planta (hint_placement.gd) as the paper it
## is: a maid's sheet with its block of rooms, a work order, a few lines in
## pencil torn off a notebook, a sign off a door, a carbon copy with the
## circle pressed into it, a torn corner of an evacuation plan, the note about
## the chalk, or somebody else's sheet with four circles on it. Drawn, not
## laid out, at its own size (`card`); whoever shows it scales it.
const STYLE := preload("res://game/ui/osd_style.gd")
const HAND := preload("res://game/ui/handwork.gd")
const PAPER := Color(0.86, 0.82, 0.71)
const PRINT := Color(0.13, 0.12, 0.11)
const GRAPHITE := Color(0.16, 0.15, 0.15, 0.92)
const RULED := Color(0.32, 0.42, 0.66, 0.28)
const RED := Color(0.62, 0.1, 0.08)
const CARBON := Color(0.11, 0.11, 0.19)
## The pencil of the other sheet: the sixth of the sheet's inks.
const OTHER := Color(0.29, 0.1, 0.33)
const PLAN_INK := Color(0.32, 0.17, 0.09)
## The size of each paper, before what it carries makes it longer.
const SIZES := {"limpieza": Vector2(500, 0), "orden": Vector2(560, 0), "indicaciones": Vector2(580, 0), "cartel": Vector2(540, 300), "calco": Vector2(460, 600), "plano": Vector2(640, 480), "tiza": Vector2(460, 240), "hoja": Vector2(700, 460)}
const LINE := 36.0
const ROW := 38.0
var hint: Dictionary
## The walls of the hint's planta, [[a, b]] in plan (x, z), for the plans.
var walls: Array = []
var card := Vector2(500, 400)

func setup(data: Dictionary, plan_walls: Array) -> void:
	hint = data
	walls = plan_walls
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	card = SIZES.get(String(hint.get("kind", "")), Vector2(500, 400))
	var printed: Array = hint.get("printed", [])
	var hand: Array = hint.get("hand", [])
	match String(hint.get("kind", "")):
		"limpieza": card.y = 240.0 + float(hint.get("rows", []).size()) * ROW + float(hand.size()) * LINE + 50.0
		"orden": card.y = 120.0 + float(wrapped(printed.slice(2), 20, card.x - 90.0).size()) * 30.0 + float(hand.size()) * LINE + 90.0
		"indicaciones": card.y = 90.0 + float(wrapped(hand, 24, card.x - 90.0, true).size()) * 44.0 + 40.0
	custom_minimum_size = card
	size = card
	queue_redraw()

func _draw() -> void:
	match String(hint.get("kind", "")):
		"limpieza": cleaning()
		"orden": order()
		"indicaciones": notebook()
		"cartel": door_sign()
		"calco": carbon()
		"plano": evacuation()
		"tiza": chalk_note()
		"hoja": other_sheet()

# --- The papers ---------------------------------------------------------------------------

func cleaning() -> void:
	paper(Rect2(Vector2.ZERO, card), PAPER, 31)
	var printed: Array = hint.get("printed", [])
	words(Vector2(40, 64), String(printed[0]) if printed.size() > 0 else "", 28, PRINT)
	words(Vector2(40, 96), String(printed[1]) if printed.size() > 1 else "", 17, PRINT)
	draw_line(Vector2(36, 116), Vector2(card.x - 36, 116), Color(PRINT, 0.8), 2.0)
	words(Vector2(44, 150), "HAB.", 15, Color(PRINT, 0.75))
	words(Vector2(170, 150), "ESTADO", 15, Color(PRINT, 0.75))
	var y := 190.0
	var rows: Array = hint.get("rows", [])
	for index in rows.size():
		var row: Array = rows[index]
		draw_line(Vector2(36, y + 12), Vector2(card.x - 36, y + 12), Color(PRINT, 0.25), 1.0)
		words(Vector2(44, y), String(row[0]), 21, PRINT)
		words(Vector2(170, y), String(row[1]), 17, PRINT)
		# Her tick, in pencil, beside what she did.
		if String(row[1]) == "HECHA":
			var at := Vector2(card.x - 70, y - 8)
			var lean := HAND.jitter(float(index), 3.0) * 4.0
			draw_polyline(PackedVector2Array([at + Vector2(-9, -2 + lean), at + Vector2(-2, 7), at + Vector2(12, -12 + lean)]), GRAPHITE, 2.4, true)
		y += ROW
	pencil(Vector2(44, y + 24), hint.get("hand", []), card.x - 80.0)

func order() -> void:
	paper(Rect2(Vector2.ZERO, card), Color(0.88, 0.86, 0.8), 53)
	var printed: Array = hint.get("printed", [])
	draw_rect(Rect2(28, 28, card.x - 56, 64), Color(PRINT, 0.08))
	words(Vector2(44, 66), String(printed[0]) if printed.size() > 0 else "", 24, PRINT)
	words(Vector2(44, 120), String(printed[1]) if printed.size() > 1 else "", 17, PRINT)
	var y := 160.0
	for line in wrapped(printed.slice(2), 20, card.x - 90.0):
		words(Vector2(44, y), line, 20, PRINT)
		y += 30.0
	stamp(Vector2(card.x - 160, 128), "PENDIENTE", -0.18)
	pencil(Vector2(44, y + 30), hint.get("hand", []), card.x - 80.0)

func notebook() -> void:
	var torn := torn_bottom(Rect2(Vector2.ZERO, card), 77)
	draw_colored_polygon(shifted(torn, Vector2(4, 5)), Color(0, 0, 0, 0.35))
	draw_colored_polygon(torn, Color(0.9, 0.88, 0.8))
	draw_texture_rect(HAND.wear(Vector2i(50, int(card.y / 10.0)), 77), Rect2(Vector2.ZERO, card), false)
	for y in range(70, int(card.y) - 30, 44): draw_line(Vector2(16, y + 8), Vector2(card.x - 16, y + 8), RULED, 1.0)
	draw_line(Vector2(54, 10), Vector2(54, card.y - 30), Color(0.66, 0.18, 0.14, 0.32), 1.0)
	var y := 70.0
	for line in wrapped(hint.get("hand", []), 24, card.x - 90.0, true):
		handwriting(Vector2(66, y), line, 24, int(y))
		y += 44.0

func door_sign() -> void:
	var plate := Rect2(Vector2(10, 10), card - Vector2(20, 20))
	draw_rect(Rect2(plate.position + Vector2(4, 5), plate.size), Color(0, 0, 0, 0.4))
	draw_rect(plate, Color(0.9, 0.89, 0.85))
	draw_rect(plate.grow(-10), Color(0.2, 0.19, 0.18), false, 2.0)
	for corner in [Vector2(28, 28), Vector2(card.x - 28, 28), Vector2(28, card.y - 28), Vector2(card.x - 28, card.y - 28)]:
		draw_circle(corner, 5.0, Color(0.55, 0.5, 0.42))
		draw_circle(corner, 2.0, Color(0.25, 0.23, 0.2))
	var printed: Array = hint.get("printed", [])
	centred(Vector2(card.x * 0.5, 104), String(printed[0]) if printed.size() > 0 else "", 40, PRINT)
	centred(Vector2(card.x * 0.5, 150), String(printed[1]) if printed.size() > 1 else "", 20, Color(PRINT, 0.8))
	pencil(Vector2(64, 214), hint.get("hand", []), card.x - 120.0)

func carbon() -> void:
	var sheet := Rect2(Vector2.ZERO, card)
	draw_rect(Rect2(sheet.position + Vector2(4, 5), sheet.size), Color(0, 0, 0, 0.4))
	draw_rect(sheet, CARBON)
	# What was written through it before, faintly, and the sheen of it.
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	for n in 26:
		var from := Vector2(rng.randf_range(30, card.x - 120), rng.randf_range(40, card.y - 40))
		draw_line(from, from + Vector2(rng.randf_range(30, 110), rng.randf_range(-3, 3)), Color(0.5, 0.52, 0.7, 0.12), 1.6, true)
	draw_rect(Rect2(0, 0, card.x * 0.35, card.y), Color(1, 1, 1, 0.03))
	# The circle, where it was pressed through.
	circle(card * 0.5 + Vector2(HAND.jitter(3.0, 1.0) * 30.0, HAND.jitter(5.0, 2.0) * 40.0), minf(card.x, card.y) * 0.24, Color(0.72, 0.75, 0.92, 0.55), 3.2, 29)

func evacuation() -> void:
	var torn := torn_edges(Rect2(Vector2.ZERO, card), 131)
	draw_colored_polygon(shifted(torn, Vector2(4, 5)), Color(0, 0, 0, 0.35))
	draw_colored_polygon(torn, Color(0.9, 0.9, 0.86))
	draw_texture_rect(HAND.wear(Vector2i(64, 48), 131, false), Rect2(Vector2.ZERO, card), false)
	var printed: Array = hint.get("printed", [])
	words(Vector2(36, 46), String(printed[0]) if printed.size() > 0 else "", 20, Color(0.55, 0.08, 0.06))
	var frame := Rect2(30, 64, card.x - 60, card.y - 120)
	var window: Rect2 = hint.get("window", Rect2())
	if window.size.x > 0.0:
		var scale := minf(frame.size.x / window.size.x, frame.size.y / window.size.y)
		var to_card := func(point: Vector2) -> Vector2: return frame.get_center() + (point - window.get_center()) * scale
		var clip := PackedVector2Array([window.position, Vector2(window.end.x, window.position.y), window.end, Vector2(window.position.x, window.end.y)])
		for wall in walls:
			for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([wall[0], wall[1]]), clip):
				if piece.size() >= 2: draw_line(to_card.call(piece[0]), to_card.call(piece[piece.size() - 1]), Color(0.18, 0.18, 0.2), 2.2, true)
		var cross: Vector2 = to_card.call(hint.get("cross", window.get_center()))
		draw_line(cross + Vector2(-11, -11), cross + Vector2(11, 11), RED, 4.0, true)
		draw_line(cross + Vector2(-11, 11), cross + Vector2(11, -11), RED, 4.0, true)
	words(Vector2(36, card.y - 22), String(printed[1]) if printed.size() > 1 else "", 16, PRINT)

func chalk_note() -> void:
	paper(Rect2(Vector2.ZERO, card), Color(0.9, 0.86, 0.68), 211)
	pencil(Vector2(40, 84), hint.get("hand", []), card.x - 70.0)

func other_sheet() -> void:
	paper(Rect2(Vector2.ZERO, card), PAPER.darkened(0.06), 1187)
	draw_texture_rect(HAND.wear(Vector2i(70, 46), 523), Rect2(Vector2.ZERO, card), false)
	if walls.is_empty(): return
	var bounds := Rect2(walls[0][0], Vector2.ZERO)
	for wall in walls: bounds = bounds.expand(wall[0]).expand(wall[1])
	var frame := Rect2(40, 40, card.x - 80, card.y - 80)
	var scale := minf(frame.size.x / maxf(bounds.size.x, 1.0), frame.size.y / maxf(bounds.size.y, 1.0))
	var to_card := func(point: Vector2) -> Vector2: return frame.get_center() + (point - bounds.get_center()) * scale
	for wall in walls: draw_line(to_card.call(wall[0]), to_card.call(wall[1]), Color(PLAN_INK, 0.32), 1.6, true)
	var points: Array = hint.get("points", [])
	for index in points.size():
		circle(to_card.call(points[index]), maxf(9.0, float(hint.get("radius", 2.6)) * scale * 1.6), OTHER, 2.6, 400 + index)

# --- How things are put on paper ---------------------------------------------------------

func paper(rect: Rect2, colour: Color, seed_value: int) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 5), rect.size), Color(0, 0, 0, 0.35))
	draw_rect(rect, colour)
	draw_texture_rect(HAND.wear(Vector2i(int(rect.size.x / 10.0), int(rect.size.y / 10.0)), seed_value), rect, false)

func words(at: Vector2, text: String, font_size: int, ink: Color) -> void:
	draw_string(STYLE.font(), at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

func centred(at: Vector2, text: String, font_size: int, ink: Color) -> void:
	var width := STYLE.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(STYLE.font(), at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

## Lines in pencil, a little off true each, gone over twice.
func pencil(at: Vector2, lines: Array, width: float) -> void:
	var y := at.y
	for line in wrapped(lines, 22, width, true):
		handwriting(Vector2(at.x, y), line, 22, int(y))
		y += LINE

func handwriting(at: Vector2, text: String, font_size: int, seed_value: int) -> void:
	var font := ThemeDB.fallback_font
	var tilt := HAND.jitter(float(seed_value), 7.0) * 0.035
	draw_set_transform_matrix(Transform2D(tilt, Vector2.ONE, -0.18, at))
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, GRAPHITE)
	draw_string(font, Vector2(0.7, 0.4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(GRAPHITE, 0.35))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func stamp(at: Vector2, text: String, turn: float) -> void:
	var font := STYLE.font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_set_transform(at, turn, Vector2.ONE)
	draw_rect(Rect2(-8, -24, width + 16, 32), Color(RED, 0.7), false, 2.0)
	draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(RED, 0.7))
	draw_set_transform_matrix(Transform2D.IDENTITY)

## A circle drawn by hand: a little out of round, its end past its start.
func circle(centre: Vector2, radius: float, ink: Color, weight: float, seed_value: int) -> void:
	var points := PackedVector2Array()
	var start := HAND.jitter(float(seed_value), 1.0) * TAU
	for step in 41:
		var angle := start + float(step) / 36.0 * TAU
		var wobble := 1.0 + 0.06 * sin(angle * 3.0 + float(seed_value)) + HAND.jitter(float(seed_value), float(step)) * 0.03
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius * wobble)
	draw_polyline(points, ink, weight, true)

## Lines broken to fit `width` at `font_size`.
func wrapped(lines: Array, font_size: int, width: float, by_hand := false) -> Array:
	var font: Font = ThemeDB.fallback_font if by_hand else STYLE.font()
	var out: Array = []
	for line in lines:
		var text := String(line)
		if text.is_empty():
			out.append("")
			continue
		var current := ""
		for word in text.split(" "):
			var trial := word if current.is_empty() else current + " " + word
			if not current.is_empty() and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
				out.append(current)
				current = word
			else: current = trial
		out.append(current)
	return out

func torn_bottom(rect: Rect2, seed_value: int) -> PackedVector2Array:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y)])
	var steps := 18
	for step in range(steps, -1, -1):
		var x := rect.position.x + rect.size.x * float(step) / steps
		points.append(Vector2(x, rect.end.y - 14.0 + HAND.jitter(float(seed_value), float(step)) * 22.0))
	return points

func torn_edges(rect: Rect2, seed_value: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 14
	for step in steps + 1: points.append(Vector2(rect.position.x + rect.size.x * float(step) / steps, rect.position.y + 8.0 + HAND.jitter(float(seed_value), float(step)) * 14.0))
	for step in range(1, steps + 1): points.append(Vector2(rect.end.x - 8.0 + HAND.jitter(float(seed_value) + 1.0, float(step)) * 14.0, rect.position.y + rect.size.y * float(step) / steps))
	points.append(Vector2(rect.position.x, rect.end.y))
	return points

static func shifted(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in points: out.append(point + by)
	return out
