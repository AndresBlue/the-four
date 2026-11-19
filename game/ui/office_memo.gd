extends Control
## The offices' own paper (assets/hoja-oficina.png, drawn by the author, 19
## November 2026, after a company memorandum of those years): its letterhead
## and, under it, a memorandum's lines filled in on a typewriter, as the
## hotel's form is (hotel_form.gd, whose keys these are). Drawn at the
## picture's own size (CARD), its fields measured on it; whoever shows it
## scales it.
##
## `memo` says what goes where, all of it optional:
##   date, to, from, subject, cc: typed on their lines (the subject in capitals);
##   lines: the body's paragraphs, broken to fit (an empty one, a blank line);
##   note: lines in pen under the body (an answer at its foot);
##   stamp: a word stamped across its foot (DENEGADO);
##   seed: how this one's keys came down.
const FORM := preload("res://game/ui/hotel_form.gd")
const HAND := preload("res://game/ui/handwork.gd")
const INK_SHADER := preload("res://game/presentation/shaders/typewriter_ink.gdshader")
const PAPER := preload("res://assets/hoja-oficina.png")
const CARD := Vector2(1103, 1426)
## How big the keys strike: a little over the sheet's own printed words, for
## the sake of reading it held up.
const TYPE := 23
## Where each field is typed (the start of its line, its baseline) and how
## long its line is.
const FIELDS := {
	"date": [Vector2(806, 217), 206.0],
	"to": [Vector2(206, 348), 800.0],
	"from": [Vector2(206, 412), 800.0],
	"subject": [Vector2(206, 473), 796.0],
	"cc": [Vector2(150, 1260), 850.0],
}
## The body under the row of asterisks: its first line, where its lines end,
## from one to the next and how many fit over the Cc.
const BODY_FROM := Vector2(91, 598)
const BODY_TO := 1012.0
const BODY_STEP := 34.0
const BODY_LINES := 17
## The pen's hand under the body, and a rubber stamp's red.
const NOTE := 34
const NOTE_STEP := 46.0
const STAMP := Color(0.6, 0.09, 0.08, 0.8)
## The paper's worn edge: inside the picture by this much, rounded so.
const EDGE := 10.0
const CORNER := 18.0
var memo: Dictionary
static var ink_material: ShaderMaterial

func setup(data: Dictionary) -> void:
	memo = data
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = CARD
	size = CARD
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for old in get_children(): old.queue_free()
	if ink_material == null:
		ink_material = ShaderMaterial.new()
		ink_material.shader = INK_SHADER
	# What was typed, under the ribbon's grain; the pen and the stamp over it,
	# as they came after.
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
	# The paper cut out of its picture inside its worn edge, and its shadow.
	var outline := FORM.rounded(Rect2(Vector2.ONE * EDGE, CARD - Vector2.ONE * EDGE * 2.0), CORNER)
	var shadow := PackedVector2Array()
	for point in outline: shadow.append(point + Vector2(5, 7))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
	var uvs := PackedVector2Array()
	for point in outline: uvs.append(point / CARD)
	draw_colored_polygon(outline, Color.WHITE, uvs, PAPER)

func draw_typed(on: Control) -> void:
	var keys := int(memo.get("seed", 0)) * 977
	for field in FIELDS:
		var words := String(memo.get(field, ""))
		if words.is_empty(): continue
		if field == "subject": words = words.to_upper()
		var at: Vector2 = FIELDS[field][0]
		FORM.type_line(on, at, words, FORM.fitting(words, float(FIELDS[field][1]), TYPE), keys + int(at.y))
	var lines := typed_lines()
	for i in mini(lines.size(), BODY_LINES):
		if not String(lines[i]).is_empty(): FORM.type_line(on, BODY_FROM + Vector2(0, BODY_STEP * i), String(lines[i]), TYPE, keys + 300 + i)

## The body as typed: paragraphs broken at the margin, a blank line between
## them kept.
func typed_lines() -> Array:
	var out: Array = []
	var per_line := int((BODY_TO - BODY_FROM.x) / FORM.advance(TYPE))
	for paragraph in memo.get("lines", []):
		var current := ""
		for word in String(paragraph).split(" "):
			var trial := word if current.is_empty() else current + " " + word
			if not current.is_empty() and trial.length() > per_line:
				out.append(current)
				current = word
			else: current = trial
		out.append(current)
	return out

func draw_written(on: Control) -> void:
	var seed_value := int(memo.get("seed", 0))
	var foot := BODY_FROM.y + BODY_STEP * (minf(typed_lines().size(), BODY_LINES) + 0.6)
	var notes: Array = memo.get("note", [])
	for i in notes.size():
		HAND.write_line(on, Vector2(BODY_FROM.x + 40.0, foot + NOTE_STEP * (i + 1)), String(notes[i]), NOTE, FORM.PEN, seed_value + i)
	var word := String(memo.get("stamp", ""))
	if word.is_empty(): return
	# Stamped askew over the foot of the body, its frame with it.
	var font := FORM.typewriter()
	var wide := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
	var frame := Rect2(-wide * 0.5 - 22.0, -44.0, wide + 44.0, 66.0)
	on.draw_set_transform(Vector2(CARD.x * 0.66, foot + NOTE_STEP * (notes.size() + 1) + 60.0), -0.12 + HAND.jitter(float(seed_value), 9.0) * 0.08, Vector2.ONE)
	on.draw_rect(frame, STAMP, false, 5.0)
	on.draw_string(font, Vector2(-wide * 0.5, 4.0), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, STAMP)
	on.draw_string(font, Vector2(-wide * 0.5 + 1.0, 4.6), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(STAMP, 0.4))
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
