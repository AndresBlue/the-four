extends Control
## One of the hints of the last planta (hint_placement.gd) as the paper it
## is: a maid's sheet with its block of rooms and a work order, both typed on
## the hotel's own form (hotel_form.gd), a few lines in pencil on a page of a
## notebook torn off before the end (ruled_paper.gd), a Polaroid of where a
## page is (its picture taken on the floor itself: code_lock.develop_photos()),
## a carbon copy with the circle pressed into it, which lets the light through,
## a torn corner of an evacuation plan with the rooms' numbers on it, the "do
## not disturb" card off a door, front and back, or somebody else's sheet,
## folded in four, with the plan and four circles on it (the author's
## pictures and word, 22 October 2026). Drawn, not laid out, at its own size
## (`card`); whoever shows it scales it.
const STYLE := preload("res://game/ui/osd_style.gd")
const HAND := preload("res://game/ui/handwork.gd")
const FORM := preload("res://game/ui/hotel_form.gd")
const RULED_PAPER := preload("res://game/ui/ruled_paper.gd")
## The other sheet's paper: a sheet folded in four, opened out.
const MAP_PAPER := preload("res://assets/papel-mapa.png")
## Where on it the plan is drawn, clear of its worn edges.
const MAP_FRAME := Rect2(120, 110, 1250, 830)
## The hints that are the hotel's own paperwork, on its form.
const FORMS := ["limpieza", "orden"]
const PAPER := Color(0.86, 0.82, 0.71)
const PRINT := Color(0.13, 0.12, 0.11)
const GRAPHITE := Color(0.16, 0.15, 0.15, 0.92)
const RED := Color(0.62, 0.1, 0.08)
## Carbon paper, thin enough to see the room through.
const CARBON := Color(0.11, 0.11, 0.19, 0.62)
## The pencil of the other sheet: the sixth of the sheet's inks.
const OTHER := Color(0.29, 0.1, 0.33)
const PLAN_INK := Color(0.32, 0.17, 0.09)
## The size of each paper, before what it carries makes it longer.
const SIZES := {"red": Vector2(960, 680), "memo": Vector2(520, 720), "resguardo": Vector2(300, 620), "ficha": Vector2(720, 450), "polaroid": Vector2(440, 540), "calco": Vector2(460, 600), "plano": Vector2(640, 480), "nomolestar": Vector2(500, 590), "hoja": Vector2(1491, 1055)}
## The card's printed front and its back (tools/textures/bake_do_not_disturb.py),
## and the Polaroid's picture square in its frame.
const CARD_FACE := preload("res://assets/textures/no-molestar.png")
const CARD_BACK := preload("res://assets/textures/no-molestar-reverso.png")
const PHOTO := Rect2(24, 24, 392, 392)
static var vignette: GradientTexture2D
const LINE := 36.0
var hint: Dictionary
## The walls of the hint's planta, [[a, b]] in plan (x, z), for the plans.
var walls: Array = []
var card := Vector2(500, 400)

func setup(data: Dictionary, plan_walls: Array) -> void:
	hint = data
	walls = plan_walls
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for old in get_children(): old.queue_free()
	if FORMS.has(String(hint.get("kind", ""))):
		var sheet := FORM.new()
		sheet.setup(hint.get("form", {}))
		add_child(sheet)
		card = FORM.CARD
		custom_minimum_size = card
		size = card
		return
	if String(hint.get("kind", "")) == "indicaciones":
		var page := RULED_PAPER.new()
		page.setup("libreta", hint.get("hand", []), true, true, int(hint.get("room", 0)))
		add_child(page)
		card = page.card
		custom_minimum_size = card
		size = card
		return
	card = SIZES.get(String(hint.get("kind", "")), Vector2(500, 400))
	custom_minimum_size = card
	size = card
	queue_redraw()

## The Polaroid's picture comes a moment after it is first held up
## (code_lock.develop_photo()): drawn again when it does.
func _process(_delta: float) -> void:
	if String(hint.get("kind", "")) == "polaroid" and not hint.has("photo"): return
	queue_redraw()
	set_process(false)

func _draw() -> void:
	match String(hint.get("kind", "")):
		"polaroid": polaroid()
		"calco": carbon()
		"plano": evacuation()
		"nomolestar": do_not_disturb()
		"hoja": other_sheet()
		"resguardo": receipt()
		"ficha": office_card()
		"memo": office_memo()
		"red": tube_map()

# --- The papers ---------------------------------------------------------------------------

func carbon() -> void:
	var sheet := Rect2(Vector2.ZERO, card)
	draw_rect(Rect2(sheet.position + Vector2(4, 5), sheet.size), Color(0, 0, 0, 0.18))
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
		# The numbers of the rooms and the names of the rest, as printed.
		for label in hint.get("labels", []):
			centred(to_card.call(label[0]) + Vector2(0, 5), String(label[1]), 13, Color(PRINT, 0.85))
		var cross: Vector2 = to_card.call(hint.get("cross", window.get_center()))
		draw_line(cross + Vector2(-11, -11), cross + Vector2(11, 11), RED, 4.0, true)
		draw_line(cross + Vector2(-11, 11), cross + Vector2(11, -11), RED, 4.0, true)
	words(Vector2(36, card.y - 22), String(printed[1]) if printed.size() > 1 else "", 16, PRINT)

## A Polaroid: the picture in its white frame, wider at the foot, a little
## warm and darker at its corners, as they come out. With no picture (a run
## with nothing drawn on a screen) the square is left dark.
func polaroid() -> void:
	var frame := Rect2(Vector2.ZERO, card)
	draw_rect(Rect2(frame.position + Vector2(5, 7), frame.size), Color(0, 0, 0, 0.4))
	draw_rect(frame, Color(0.93, 0.92, 0.88))
	draw_rect(PHOTO, Color(0.1, 0.09, 0.08))
	var picture = hint.get("photo")
	if picture is Texture2D: draw_texture_rect(picture, PHOTO, false, Color(1.0, 0.95, 0.86))
	if vignette == null:
		vignette = GradientTexture2D.new()
		vignette.fill = GradientTexture2D.FILL_RADIAL
		vignette.fill_from = Vector2(0.5, 0.5)
		vignette.fill_to = Vector2(1.05, 1.05)
		var shade := Gradient.new()
		shade.set_color(0, Color(0, 0, 0, 0.0))
		shade.set_color(1, Color(0.05, 0.03, 0.02, 0.55))
		vignette.gradient = shade
	draw_texture_rect(vignette, PHOTO, false)
	draw_texture_rect(HAND.wear(Vector2i(44, 54), 4411, false), frame, false, Color(1, 1, 1, 0.5))

## The card off a door, held up: its printed front, and its back, where on
## the one that matters somebody wrote in pencil.
func do_not_disturb() -> void:
	var face := Vector2(220, 550)
	var front := Rect2(Vector2(20, 20), face)
	var back := Rect2(Vector2(card.x - 20 - face.x, 20), face)
	for side in [[front, CARD_FACE], [back, CARD_BACK]]:
		draw_texture_rect(side[1], Rect2((side[0] as Rect2).position + Vector2(4, 6), face), false, Color(0, 0, 0, 0.4))
		draw_texture_rect(side[1], side[0], false)
	pencil(back.position + Vector2(22, 210), hint.get("hand", []), face.x - 40.0)

func other_sheet() -> void:
	draw_texture_rect(MAP_PAPER, Rect2(Vector2(6, 8), card), false, Color(0, 0, 0, 0.4))
	draw_texture_rect(MAP_PAPER, Rect2(Vector2.ZERO, card), false)
	if walls.is_empty(): return
	var bounds := Rect2(walls[0][0], Vector2.ZERO)
	for wall in walls: bounds = bounds.expand(wall[0]).expand(wall[1])
	var frame := MAP_FRAME
	var scale := minf(frame.size.x / maxf(bounds.size.x, 1.0), frame.size.y / maxf(bounds.size.y, 1.0))
	var to_card := func(point: Vector2) -> Vector2: return frame.get_center() + (point - bounds.get_center()) * scale
	for wall in walls: draw_line(to_card.call(wall[0]), to_card.call(wall[1]), Color(PLAN_INK, 0.6), 2.4, true)
	var points: Array = hint.get("points", [])
	for index in points.size():
		circle(to_card.call(points[index]), maxf(16.0, float(hint.get("radius", 2.6)) * scale * 1.6), OTHER, 4.2, 400 + index)

## The pneumatic tube's receipt (the offices, planta 1): a strip of thermal
## paper torn at both ends, the station the capsule went to in big figures.
func receipt() -> void:
	var form: Dictionary = hint.get("form", {})
	var strip := PackedVector2Array()
	var teeth := 14
	for k in teeth + 1: strip.append(Vector2(card.x * k / teeth, 8.0 if k % 2 == 0 else 0.0))
	for k in range(teeth, -1, -1): strip.append(Vector2(card.x * k / teeth, card.y - (8.0 if k % 2 == 0 else 0.0)))
	draw_colored_polygon(shifted(strip, Vector2(4, 5)), Color(0, 0, 0, 0.35))
	draw_colored_polygon(strip, Color8(240, 238, 230))
	centred(Vector2(card.x / 2, 56), "LA OFICINA", 22, PRINT)
	centred(Vector2(card.x / 2, 88), "TUBO NEUMÁTICO", 15, PRINT)
	centred(Vector2(card.x / 2, 136), "RESGUARDO", 20, PRINT)
	draw_line(Vector2(30, 160), Vector2(card.x - 30, 160), Color(PRINT, 0.6), 1.5)
	centred(Vector2(card.x / 2, 210), "ENVIADA A ESTACIÓN", 15, PRINT)
	centred(Vector2(card.x / 2, 330), String(form.get("station", "")), 110, PRINT)
	draw_line(Vector2(30, 380), Vector2(card.x - 30, 380), Color(PRINT, 0.6), 1.5)
	words(Vector2(36, 430), "N.º  " + String(form.get("number", "")), 17, PRINT)
	var time: Array = form.get("time", [0, 0])
	words(Vector2(36, 470), "HORA  %d:%02d" % [int(time[0]), int(time[1])], 17, PRINT)

## The pneumatic network's map beside the window: the planta's walls, the
## tubes as double lines, the stations as numbered circles and the window.
func tube_map() -> void:
	var face := Rect2(Vector2.ZERO, card)
	paper(face, Color(0.9, 0.9, 0.86), 5101)
	words(Vector2(40, 52), "LA OFICINA", 20, PRINT)
	words(Vector2(40, 82), "RED DE TUBOS NEUMÁTICOS. PLANTA 1, PERSONAL", 14, PRINT)
	if walls.is_empty(): return
	var bounds := Rect2(walls[0][0], Vector2.ZERO)
	for wall in walls: bounds = bounds.expand(wall[0]).expand(wall[1])
	var frame := Rect2(40, 110, card.x - 80, card.y - 150)
	var scale := minf(frame.size.x / maxf(bounds.size.x, 1.0), frame.size.y / maxf(bounds.size.y, 1.0))
	var to_card := func(point: Vector2) -> Vector2: return frame.get_center() + (point - bounds.get_center()) * scale
	for wall in walls: draw_line(to_card.call(wall[0]), to_card.call(wall[1]), Color(0.18, 0.18, 0.2, 0.7), 1.6, true)
	var tube_ink := Color(0.45, 0.3, 0.12)
	for pipe in hint.get("tubes", []):
		var a: Vector2 = to_card.call(pipe[0])
		var b: Vector2 = to_card.call(pipe[1])
		var across := (b - a).orthogonal().normalized() * 1.6 if a.distance_to(b) > 0.01 else Vector2.ZERO
		draw_line(a + across, b + across, tube_ink, 1.2, true)
		draw_line(a - across, b - across, tube_ink, 1.2, true)
	var window: Vector2 = to_card.call(hint.get("window", Vector2.ZERO))
	draw_rect(Rect2(window - Vector2(8, 8), Vector2(16, 16)), RED)
	words(window + Vector2(12, -10), "VENTANILLA", 13, RED)
	for station in hint.get("stations", []):
		var at: Vector2 = to_card.call(station[0])
		draw_circle(at, 13.0, Color(0.9, 0.9, 0.86))
		draw_arc(at, 13.0, 0.0, TAU, 24, tube_ink, 2.0, true)
		centred(at + Vector2(0, 5), str(int(station[1])), 13, PRINT)

## A memo of La Oficina: water-green paper, two filing holes, the ruled
## heading and its lines typed under it.
func office_memo() -> void:
	var form: Dictionary = hint.get("form", {})
	var face := Rect2(Vector2.ZERO, card)
	paper(face, Color8(214, 232, 220), 3301)
	for k in 2: draw_circle(Vector2(26, card.y * (k + 1) / 3.0), 9.0, Color(0, 0, 0, 0.55))
	words(Vector2(60, 64), "LA OFICINA", 20, PRINT)
	words(Vector2(60, 100), "MEMORÁNDUM INTERNO", 16, PRINT)
	var y := 150.0
	for field in [["DE", "MANTENIMIENTO"], ["PARA", "TODO EL PERSONAL"], ["ASUNTO", String(form.get("subject", ""))]]:
		words(Vector2(60, y), String(field[0]), 12, Color(PRINT, 0.7))
		words(Vector2(150, y), String(field[1]), 15, Color(0.1, 0.1, 0.12))
		draw_line(Vector2(146, y + 8), Vector2(card.x - 40, y + 8), Color(PRINT, 0.35), 1.0)
		y += 36.0
	y += 24.0
	for line in wrapped(form.get("lines", []), 15, card.x - 110):
		words(Vector2(60, y), String(line), 15, Color(0.1, 0.1, 0.12))
		y += 30.0

## The card of La Oficina (planta 1): beige, punched along the top, the
## photo box, the typed fields and the red PROVISIONAL band.
func office_card() -> void:
	var form: Dictionary = hint.get("form", {})
	var face := Rect2(Vector2.ZERO, card)
	paper(face, Color8(222, 205, 165), 2207)
	for k in 18: draw_circle(Vector2(40 + k * 36, 16), 5.0, Color(0, 0, 0, 0.55))
	words(Vector2(36, 66), "LA OFICINA", 24, PRINT)
	words(Vector2(card.x - 250, 66), "FICHA DE PERSONAL", 16, PRINT)
	var photo := Rect2(36, 96, 190, 240)
	draw_rect(photo, Color(PRINT, 0.7), false, 2.0)
	var picture = form.get("photo")
	if picture is Texture2D: draw_texture_rect(picture, photo.grow(-6), false)
	else: centred(photo.get_center() + Vector2(0, 6), "FOTO", 16, Color(PRINT, 0.5))
	var y := 120.0
	for field in [["NOMBRE", "name"], ["NÚMERO", "number"], ["DEPARTAMENTO", "department"], ["ALTA", "date"], ["NIVEL DE ACCESO", "level"]]:
		words(Vector2(260, y), String(field[0]), 12, Color(PRINT, 0.7))
		draw_line(Vector2(260, y + 34), Vector2(card.x - 40, y + 34), Color(PRINT, 0.35), 1.0)
		words(Vector2(270, y + 28), String(form.get(String(field[1]), "")), 19, Color(0.1, 0.1, 0.12))
		y += 54.0
	draw_rect(Rect2(0, card.y - 70, card.x, 44), Color8(170, 30, 25))
	centred(Vector2(card.x / 2, card.y - 38), "PROVISIONAL", 24, Color8(222, 205, 165))

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
	HAND.write_line(self, at, text, font_size, GRAPHITE, seed_value)

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
