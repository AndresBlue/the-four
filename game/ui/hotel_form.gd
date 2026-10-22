extends Control
## The hotel's own form (assets/nota-hotel.png, drawn by the author, 21
## October 2026): what the hotel wrote down about itself is on this paper,
## filled in on a typewriter. A report from reception, a maintenance sheet, a
## maid's list, a work order: the same printed form, its fields typed in a
## cloth ribbon's ink, a box crossed with an X, and now and then something
## added in pencil, or a signature in pen. Drawn at the picture's own size
## (CARD), its fields measured on it; whoever shows it scales it.
##
## `form` says what goes where, all of it optional:
##   number, date [d, m, y], time [h, m], name, post, place, subject;
##   type: observacion, solicitud, tarea, incidente or otro;
##   lines: typed on the ruled lines, broken to fit (an empty one is skipped);
##   rows: [[a, b]] typed in two columns under a heading, ticked in pencil
##     where b is HECHA;
##   action: {sin, terreno, seguimiento: true; derivar, informar, otro: words};
##   priority: baja, media, alta or urgente; state: pendiente, en_curso,
##   resuelto or cerrado; signed: a signature on FIRMA; notes: up to two lines
##   of OBSERVACIONES ADICIONALES; seed: how this one's keys came down.
## And `hand`, lines in pencil written on the ruled lines under what was typed.
const HAND := preload("res://game/ui/handwork.gd")
const INK_SHADER := preload("res://game/presentation/shaders/typewriter_ink.gdshader")
const PAPER := preload("res://assets/nota-hotel.png")
const CARD := Vector2(1024, 1536)
## A cloth ribbon's black, a pencil, and a pen's blue-black.
const RIBBON := Color(0.08, 0.075, 0.09)
const GRAPHITE := Color(0.16, 0.15, 0.15, 0.92)
const PEN := Color(0.1, 0.12, 0.28, 0.9)
## How big the keys strike, in the form's pixels: bigger than a real machine's
## pica would be on a sheet this size, for the sake of reading it held up.
const TYPE := 26
const FIELD := 24
const FIELD_TOP := 21
const BOXED := 24
const HANDWRITTEN := 30
## The detail's ruled lines: the first one's height, from one to the next, how
## many, and where typing starts along them and ends.
const RULED_FIRST := 461.0
const RULED_STEP := 31.78
const RULED := 24
const RULED_FROM := 72.0
const RULED_TO := 968.0
## Where the fields are typed: the start of the line under each (baseline),
## and how long it is. Under the bands with the names of the top two there is
## a line's height and no more: what goes there is typed smaller (FIELD_TOP).
const FIELDS := {
	"name": [Vector2(54, 298), 450.0],
	"post": [Vector2(542, 298), 436.0],
	"place": [Vector2(54, 361), 450.0],
	"subject": [Vector2(542, 361), 436.0],
	"number": [Vector2(772, 84), 210.0],
	"derivar": [Vector2(324, 1290), 200.0],
	"informar": [Vector2(170, 1370), 354.0],
	"otro": [Vector2(131, 1396), 393.0],
}
## The blanks of the date and the time: the middle of each, on its line.
const DATE := [Vector2(810, 146), Vector2(865, 146), Vector2(936, 146)]
const TIME := [Vector2(830, 188), Vector2(906, 188)]
## The middle of each box.
const TYPES := {"observacion": Vector2(512, 418), "solicitud": Vector2(634.5, 418), "tarea": Vector2(741, 418), "incidente": Vector2(826, 418), "otro": Vector2(930.5, 418)}
const ACTIONS := {"sin": Vector2(63.5, 1288), "derivar": Vector2(231, 1288), "terreno": Vector2(63.5, 1315), "seguimiento": Vector2(63.5, 1341), "informar": Vector2(63.5, 1367), "otro": Vector2(64, 1393.5)}
const PRIORITIES := {"baja": Vector2(588, 1288), "media": Vector2(588, 1317), "alta": Vector2(588, 1347.5), "urgente": Vector2(588, 1378)}
const STATES := {"pendiente": Vector2(818, 1288), "en_curso": Vector2(818, 1317), "resuelto": Vector2(818, 1348), "cerrado": Vector2(818, 1378)}
## The signature's line, and the two of the additional remarks.
const SIGNATURE := Rect2(128, 1430, 300, 40)
const NOTES := [[Vector2(700, 1449), 278.0], [Vector2(492, 1475), 486.0]]
## The paper's worn corners: inside the picture by this much, rounded so.
const EDGE := 3.0
const CORNER := 16.0
var form: Dictionary
var hand: Array = []
var card := CARD
static var typeface: Font
static var ink_material: ShaderMaterial

## A typewriter's face: Courier, which is what the machines of those years
## struck, from the system (Courier New is on every Windows and every Mac),
## a little heavier than the screen's, as a ribbon prints it.
static func typewriter() -> Font:
	if typeface == null:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["Courier New", "Courier", "Nimbus Mono PS", "Liberation Mono", "monospace"])
		var heavier := FontVariation.new()
		heavier.base_font = system
		heavier.variation_embolden = 0.5
		typeface = heavier
	return typeface

func setup(data: Dictionary, pencil: Array = []) -> void:
	form = data
	hand = pencil
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = CARD
	size = CARD
	# Held up it is shown at two thirds of its size, and hanging on the sheet
	# at a tenth: its ruled lines would shimmer without the smaller copies.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for old in get_children(): old.queue_free()
	if ink_material == null:
		ink_material = ShaderMaterial.new()
		ink_material.shader = INK_SHADER
	# What was typed, under the ribbon's grain; what was written by hand, over
	# it, as it was done after.
	var typed := Control.new()
	typed.name = "Typed"
	typed.size = CARD
	typed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	typed.material = ink_material
	typed.draw.connect(draw_typed.bind(typed))
	add_child(typed)
	var written := Control.new()
	written.name = "Written"
	written.size = CARD
	written.mouse_filter = Control.MOUSE_FILTER_IGNORE
	written.draw.connect(draw_written.bind(written))
	add_child(written)
	queue_redraw()

func _draw() -> void:
	# The paper cut out of its picture along its worn corners, and the shadow
	# it throws.
	var outline := rounded(Rect2(Vector2.ONE * EDGE, CARD - Vector2.ONE * EDGE * 2.0), CORNER)
	var shadow := PackedVector2Array()
	for point in outline: shadow.append(point + Vector2(5, 7))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
	var uvs := PackedVector2Array()
	for point in outline: uvs.append(point / CARD)
	draw_colored_polygon(outline, Color.WHITE, uvs, PAPER)

static func rounded(rect: Rect2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var corners := [[rect.position + Vector2(radius, radius), PI], [Vector2(rect.end.x - radius, rect.position.y + radius), PI * 1.5], [rect.end - Vector2(radius, radius), 0.0], [Vector2(rect.position.x + radius, rect.end.y - radius), PI * 0.5]]
	for corner in corners:
		for step in 7:
			var angle: float = corner[1] + PI * 0.5 * float(step) / 6.0
			points.append(corner[0] + Vector2(cos(angle), sin(angle)) * radius)
	return points

# --- Typed ---------------------------------------------------------------------------------

func draw_typed(on: Control) -> void:
	var keys := int(form.get("seed", 0)) * 977
	for field in FIELDS:
		var words := ""
		if field in ["derivar", "informar", "otro"]: words = String(form.get("action", {}).get(field, "")) if form.get("action", {}).get(field) is String else ""
		else: words = String(form.get(field, ""))
		if words.is_empty(): continue
		var at: Vector2 = FIELDS[field][0]
		type_line(on, at, words.to_upper(), fitting(words, float(FIELDS[field][1]), 30 if field == "number" else FIELD_TOP if field in ["name", "post"] else FIELD), keys + int(at.y))
	var date: Array = form.get("date", [])
	for i in mini(date.size(), DATE.size()): type_centred(on, DATE[i], String(date[i]), keys + 31 * i)
	var time: Array = form.get("time", [])
	for i in mini(time.size(), TIME.size()): type_centred(on, TIME[i], String(time[i]), keys + 57 * i)
	cross(on, TYPES, String(form.get("type", "")), keys + 1)
	var action: Dictionary = form.get("action", {})
	for key in action:
		if (action[key] is bool and action[key]) or (action[key] is String and not String(action[key]).is_empty()): cross(on, ACTIONS, String(key), keys + 2)
	cross(on, PRIORITIES, String(form.get("priority", "")), keys + 3)
	cross(on, STATES, String(form.get("state", "")), keys + 4)
	var notes: Array = form.get("notes", [])
	for i in mini(notes.size(), NOTES.size()):
		type_line(on, NOTES[i][0], String(notes[i]), fitting(String(notes[i]), float(NOTES[i][1]), TYPE), keys + 70 + i)
	var line := 0
	var rows: Array = form.get("rows", [])
	if not rows.is_empty():
		type_line(on, ruled(line), "HAB.        ESTADO", TYPE, keys + 90)
		line += 1
		for row in rows:
			if line >= RULED: break
			type_line(on, ruled(line), String(row[0]), TYPE, keys + 100 + line)
			type_line(on, ruled(line) + Vector2(advance(TYPE) * 12.0, 0), String(row[1]), TYPE, keys + 200 + line)
			line += 1
	for text in typed_lines():
		if line >= RULED: break
		if not text.is_empty(): type_line(on, ruled(line), text, TYPE, keys + 300 + line)
		line += 1

## The detail's lines as typed: paragraphs broken at the margin, a blank line
## between them kept.
func typed_lines() -> Array:
	var out: Array = []
	var per_line := int((RULED_TO - RULED_FROM) / advance(TYPE))
	for paragraph in form.get("lines", []):
		var text := String(paragraph)
		if text.is_empty():
			out.append("")
			continue
		var current := ""
		for word in text.split(" "):
			var trial := word if current.is_empty() else current + " " + word
			if not current.is_empty() and trial.length() > per_line:
				out.append(current)
				current = word
			else: current = trial
		out.append(current)
	return out

## Where the typing of a ruled line starts: just above it.
static func ruled(line: int) -> Vector2:
	return Vector2(RULED_FROM, RULED_FIRST + RULED_STEP * line - 6.0)

static func advance(font_size: int) -> float:
	return typewriter().get_char_size("M".unicode_at(0), font_size).x

## The size a field's words are typed at to fit its line: a smaller face is
## what an office machine with a second ball would have used.
static func fitting(words: String, width: float, font_size: int) -> int:
	var fitted := font_size
	while fitted > 14 and advance(fitted) * words.length() > width: fitted -= 1
	return fitted

## A line struck key by key: each letter a little off its line, the way a
## type bar that is out of true always puts it (by the letter), and a little
## more by the stroke; each as dark as the key came down, with the ink that
## spread round it.
static func type_line(on: CanvasItem, at: Vector2, text: String, font_size: int, seed_value: int) -> void:
	var font := typewriter()
	var step := advance(font_size)
	for i in text.length():
		var key := text.unicode_at(i)
		if key == 32: continue
		var stroke := float(seed_value * 131 + i)
		var bar := Vector2(HAND.jitter(float(key), 1.0) * 0.8, HAND.jitter(float(key), 2.0) * 1.8)
		var spot := at + Vector2(step * i, 0.0) + bar + Vector2(HAND.jitter(stroke, 3.0) * 0.8, HAND.jitter(stroke, 4.0) * 1.0)
		var struck := 0.74 + (HAND.jitter(stroke, 5.0) + 0.5) * 0.26
		on.draw_char(font, spot, text[i], font_size, Color(RIBBON, struck))
		on.draw_char(font, spot + Vector2(0.5, 0.4), text[i], font_size, Color(RIBBON, struck * 0.28))

static func type_centred(on: CanvasItem, middle: Vector2, text: String, seed_value: int) -> void:
	type_line(on, middle - Vector2(advance(TYPE) * text.length() * 0.5, 0.0), text, TYPE, seed_value)

## An X struck over a box, as a typist marks one: a little bigger than it.
static func cross(on: CanvasItem, boxes: Dictionary, which: String, seed_value: int) -> void:
	if not boxes.has(which): return
	var middle: Vector2 = boxes[which]
	var font := typewriter()
	var glyph := font.get_char_size("X".unicode_at(0), BOXED)
	type_line(on, middle + Vector2(-glyph.x * 0.5, font.get_ascent(BOXED) * 0.36), "X", BOXED, seed_value)

# --- Written -------------------------------------------------------------------------------

func draw_written(on: Control) -> void:
	var seed_value := int(form.get("seed", 0))
	# The maid's ticks beside what she did.
	var rows: Array = form.get("rows", [])
	for index in rows.size():
		if String(rows[index][1]) != "HECHA" or index + 1 >= RULED: continue
		var at := Vector2(RULED_TO - 60.0, RULED_FIRST + RULED_STEP * (index + 1) - 14.0)
		var lean := HAND.jitter(float(index + seed_value), 3.0) * 5.0
		on.draw_polyline(PackedVector2Array([at + Vector2(-11, -2 + lean), at + Vector2(-2, 9), at + Vector2(15, -15 + lean)]), GRAPHITE, 2.8, true)
	# The pencil under what was typed, a line left between.
	var line := 0
	if not rows.is_empty(): line = rows.size() + 1
	line += typed_lines().size()
	if line > 0: line += 1
	for text in wrapped_hand():
		if line >= RULED: break
		HAND.write_line(on, Vector2(RULED_FROM + 6.0, RULED_FIRST + RULED_STEP * line - 7.0), text, HANDWRITTEN, GRAPHITE, int(line * 13 + seed_value))
		line += 1
	if bool(form.get("signed", false)): signature(on, SIGNATURE, seed_value)

func wrapped_hand() -> Array:
	var font := ThemeDB.fallback_font
	var out: Array = []
	for text in hand:
		var current := ""
		for word in String(text).split(" "):
			var trial := word if current.is_empty() else current + " " + word
			if not current.is_empty() and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, HANDWRITTEN).x > RULED_TO - RULED_FROM - 20.0:
				out.append(current)
				current = word
			else: current = trial
		out.append(current)
	return out

## A signature nobody could read, in pen: a tall first letter, the rest a run
## of loops of any height and width, leaning on and climbing a little, and a
## stroke back under the whole of it.
static func signature(on: CanvasItem, room: Rect2, seed_value: int) -> void:
	var points := PackedVector2Array()
	var base := room.end.y - 8.0
	var x := room.position.x
	var letter := 0
	while x < room.position.x + room.size.x * 0.8:
		var wide := 12.0 + (HAND.jitter(float(seed_value), float(letter)) + 0.5) * 24.0
		var tall := room.size.y * (1.05 if letter == 0 else 0.25 + (HAND.jitter(float(seed_value) + 1.0, float(letter)) + 0.5) * 0.6)
		for step in 12:
			var turn := float(step) / 12.0 * TAU
			var y := base - (0.5 - 0.5 * cos(turn)) * tall - (x - room.position.x) * 0.04
			points.append(Vector2(x + float(step) / 12.0 * wide + sin(turn) * wide * 0.3 + (base - y) * 0.3, y))
		x += wide
		letter += 1
	on.draw_polyline(points, PEN, 2.4, true)
	var under := PackedVector2Array()
	for step in 13:
		var t := float(step) / 12.0
		under.append(Vector2(room.end.x - t * room.size.x * 0.9, room.end.y - 2.0 + sin(t * PI) * 5.0 + HAND.jitter(float(seed_value), float(step)) * 2.0))
	on.draw_polyline(under, PEN, 2.0, true)
