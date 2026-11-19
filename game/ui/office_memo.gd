extends Control
## The offices' own paper (assets/hoja-oficina.png, drawn by the author, 19
## November 2026, after a company memorandum of those years): its letterhead
## and, under it, a memorandum's lines filled in on a typewriter, with now and
## then an answer in ballpoint and a rubber stamp. Drawn at the picture's own
## size (CARD), its fields measured on it; whoever shows it scales it.
##
## Its three inks go into the paper, not over it (the author, 19 November
## 2026: what was typed looked laid on by a computer): each layer is drawn
## through presentation/shaders/paper_ink.gdshader, which darkens the sheet
## and lets its grain through, with a typewriter's face whose keys are worn
## and a hand's own writing (assets/fonts/, docs/ASSETS.md).
##
## `memo` says what goes where, all of it optional:
##   date, to, from, subject, cc: typed on their lines (the subject in capitals);
##   lines: the body's paragraphs, broken to fit (an empty one, a blank line);
##   note: lines in ballpoint under the body (an answer at its foot);
##   stamp: a word stamped across its foot (DENEGADO);
##   seed: how this one's keys came down.
const FORM := preload("res://game/ui/hotel_form.gd")
const HAND := preload("res://game/ui/handwork.gd")
const INK := preload("res://game/presentation/shaders/paper_ink.gdshader")
const PAPER := preload("res://assets/hoja-oficina.png")
const KEYS := preload("res://assets/fonts/special_elite/SpecialElite-Regular.ttf")
const HANDWRITING := preload("res://assets/fonts/reenie_beanie/ReenieBeanie.ttf")
const CARD := Vector2(1103, 1426)
## A cloth ribbon's black, a ballpoint's blue and a stamp pad's red.
const RIBBON := Color(0.09, 0.085, 0.1)
const BALLPOINT := Color(0.09, 0.17, 0.56)
const PAD := Color(0.62, 0.1, 0.09)
## Each ink in the shader's terms: its grain, how dry it runs, how its edges
## are eaten, how much of it never touched the sheet and how hard it was
## pressed.
const INKS := {
	"ribbon": {"grain": 0.45, "dry": 0.25, "bite": 0.3, "blotch": 0.0, "press": 1.35},
	"pen": {"grain": 0.3, "dry": 0.5, "bite": 0.2, "blotch": 0.0, "press": 1.1},
	"stamp": {"grain": 0.75, "dry": 0.3, "bite": 0.55, "blotch": 0.42, "press": 1.0},
}
## How big the keys strike: a little over the sheet's own printed words, for
## the sake of reading it held up.
const TYPE := 21
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
const BODY_STEP := 32.0
const BODY_LINES := 18
## The hand under the body: how big it writes, and from one line to the next.
const NOTE := 54
const NOTE_STEP := 50.0
## The stamp's letters.
const STAMPED := 56
## The paper's worn edge: inside the picture by this much, rounded so.
const EDGE := 10.0
const CORNER := 18.0
var memo: Dictionary
static var inks := {}

static func ink(kind: String) -> ShaderMaterial:
	if not inks.has(kind):
		var material := ShaderMaterial.new()
		material.shader = INK
		for key in INKS[kind]: material.set_shader_parameter(key, INKS[kind][key])
		inks[kind] = material
	return inks[kind]

func setup(data: Dictionary) -> void:
	memo = data
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = CARD
	size = CARD
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for old in get_children(): old.queue_free()
	# What was typed first; the pen and the stamp over it, as they came after.
	for part: Array in [["Typed", "ribbon", draw_typed], ["Written", "pen", draw_written], ["Stamped", "stamp", draw_stamped]]:
		var layer := Control.new()
		layer.name = String(part[0])
		layer.size = CARD
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.material = ink(String(part[1]))
		layer.draw.connect((part[2] as Callable).bind(layer))
		add_child(layer)
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

# --- Typed -------------------------------------------------------------------

static func key_step(font_size: int) -> float:
	return KEYS.get_char_size("M".unicode_at(0), font_size).x

## The size a field's words are typed at to fit its line.
static func fitting(words: String, width: float, font_size: int) -> int:
	var fitted := font_size
	while fitted > 14 and key_step(fitted) * words.length() > width: fitted -= 1
	return fitted

## A line struck key by key: each letter in the middle of its own step, a
## little off its line the way its type bar always puts it and a little more
## by the stroke, as dark as the key came down, the ink spread a hair round it.
static func strike(on: CanvasItem, at: Vector2, text: String, font_size: int, seed_value: int) -> void:
	var step := key_step(font_size)
	for i in text.length():
		var key := text.unicode_at(i)
		if key == 32: continue
		var stroke := float(seed_value * 131 + i)
		var bar := Vector2(HAND.jitter(float(key), 1.0) * 0.9, HAND.jitter(float(key), 2.0) * 2.0)
		var spot := at + Vector2(step * i + (step - KEYS.get_char_size(key, font_size).x) * 0.5, 0.0) + bar + Vector2(HAND.jitter(stroke, 3.0) * 0.8, HAND.jitter(stroke, 4.0) * 1.0)
		var struck := 0.78 + (HAND.jitter(stroke, 5.0) + 0.5) * 0.22
		for way: Vector2 in [Vector2(0.7, 0.0), Vector2(-0.7, 0.0), Vector2(0.0, 0.7), Vector2(0.0, -0.7)]:
			on.draw_char(KEYS, spot + way, text[i], font_size, Color(RIBBON, struck * 0.24))
		on.draw_char(KEYS, spot, text[i], font_size, Color(RIBBON, struck))

func draw_typed(on: Control) -> void:
	var keys := int(memo.get("seed", 0)) * 977
	for field in FIELDS:
		var words := String(memo.get(field, ""))
		if words.is_empty(): continue
		if field == "subject": words = words.to_upper()
		var at: Vector2 = FIELDS[field][0]
		strike(on, at, words, fitting(words, float(FIELDS[field][1]), TYPE), keys + int(at.y))
	var lines := typed_lines()
	for i in mini(lines.size(), BODY_LINES):
		if not String(lines[i]).is_empty(): strike(on, BODY_FROM + Vector2(0, BODY_STEP * i), String(lines[i]), TYPE, keys + 300 + i)

## The body as typed: paragraphs broken at the margin, a blank line between
## them kept.
func typed_lines() -> Array:
	var out: Array = []
	var per_line := int((BODY_TO - BODY_FROM.x) / key_step(TYPE))
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

## Where the body ends: what is written and stamped goes under it.
func foot() -> float:
	return BODY_FROM.y + BODY_STEP * (minf(typed_lines().size(), BODY_LINES) + 0.6)

# --- Written and stamped -----------------------------------------------------

## A line in ballpoint: word by word, each leaning its own way and a little
## off the line, the whole climbing a hair, gone over where the pen pressed.
static func pen(on: CanvasItem, at: Vector2, text: String, seed_value: int) -> void:
	var along := 0.0
	var words := text.split(" ")
	for w in words.size():
		var word := String(words[w])
		var lean := -0.05 + HAND.jitter(float(seed_value), float(w)) * 0.05
		var lift := -along * 0.03 + HAND.jitter(float(seed_value) + 3.0, float(w)) * 3.0
		on.draw_set_transform_matrix(Transform2D(lean, Vector2.ONE, -0.1, at + Vector2(along, lift)))
		on.draw_string(HANDWRITING, Vector2.ZERO, word, HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE, Color(BALLPOINT, 0.92))
		on.draw_string(HANDWRITING, Vector2(0.6, 0.3), word, HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE, Color(BALLPOINT, 0.4))
		along += HANDWRITING.get_string_size(word + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, NOTE).x
	on.draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_written(on: Control) -> void:
	var notes: Array = memo.get("note", [])
	for i in notes.size():
		pen(on, Vector2(BODY_FROM.x + 44.0, foot() + NOTE_STEP * (i + 1)), String(notes[i]), int(memo.get("seed", 0)) + i)

## A word stamped askew over the foot of the body, in its frame: pressed
## harder on one side, so its letters are gone over.
func draw_stamped(on: Control) -> void:
	var word := String(memo.get("stamp", ""))
	if word.is_empty(): return
	var seed_value := int(memo.get("seed", 0))
	var wide := KEYS.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMPED).x
	var frame := Rect2(-wide * 0.5 - 26.0, -50.0, wide + 52.0, 76.0)
	var notes: Array = memo.get("note", [])
	on.draw_set_transform(Vector2(CARD.x * 0.66, foot() + NOTE_STEP * (notes.size() + 1) + 64.0), -0.12 + HAND.jitter(float(seed_value), 9.0) * 0.08, Vector2.ONE)
	on.draw_rect(frame, PAD, false, 6.0)
	on.draw_rect(frame.grow(-10.0), Color(PAD, 0.85), false, 2.0)
	for way: Vector2 in [Vector2.ZERO, Vector2(1.1, 0.0), Vector2(0.0, 0.9), Vector2(1.1, 0.9)]:
		on.draw_string(KEYS, Vector2(-wide * 0.5, 8.0) + way, word, HORIZONTAL_ALIGNMENT_LEFT, -1, STAMPED, Color(PAD, 0.9))
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
