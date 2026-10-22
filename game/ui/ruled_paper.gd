extends Control
## A sheet of ruled paper found about the hotel (the author's pictures, 22
## October 2026): a letter paper folded in four (assets/carta.png) and a page
## out of a notebook (assets/libreta.png). What is on it is typed on its lines
## the way the hotel's form is (hotel_form.gd), or written on them in pencil;
## a page can be torn across under the last thing written on it. Drawn at the
## picture's own size (`card`, shorter when torn); whoever shows it scales it.
const FORM := preload("res://game/ui/hotel_form.gd")
const HAND := preload("res://game/ui/handwork.gd")
const INK_SHADER := preload("res://game/presentation/shaders/typewriter_ink.gdshader")
## Each paper: its picture, its ruled lines (their heights, measured on it),
## where along them writing starts and ends, how big the keys strike on it,
## and where the paper is in its picture when the picture has no alpha of its
## own (a rectangle with rounded corners), or an empty one when it has.
const PAPERS := {
	"carta": {
		"texture": preload("res://assets/carta.png"),
		"lines": [158, 199, 238, 275, 315, 354, 393, 432, 470, 510, 549, 587, 626, 665, 706, 746, 790, 829, 869, 907, 945, 984, 1024, 1064, 1101, 1138, 1179, 1218, 1256, 1293, 1332, 1372, 1409],
		"from": 66.0, "to": 966.0, "type": 26, "outline": Rect2(), "radius": 0.0,
	},
	"libreta": {
		"texture": preload("res://assets/libreta.png"),
		"lines": [182, 239, 295, 350, 406, 462, 518, 574, 631, 686, 742, 798, 855, 911, 967, 1022, 1078, 1133, 1189, 1244, 1300, 1356, 1413],
		"from": 100.0, "to": 948.0, "type": 28, "outline": Rect2(12, 18, 994, 1497), "radius": 34.0,
	},
}
const GRAPHITE := Color(0.16, 0.15, 0.15, 0.92)
const HANDWRITTEN := 32
## How far under the last line written a page is torn, and how ragged.
const TEAR_BELOW := 46.0
const TEAR_RAGGED := 18.0
var paper := "carta"
var written: Array = []
var by_hand := false
var torn := false
var seed_value := 0
var card := Vector2(1024, 1536)
static var ink_material: ShaderMaterial

func setup(paper_name: String, text_lines: Array, hand := false, tear := false, seed_number := 0) -> void:
	paper = paper_name if PAPERS.has(paper_name) else "carta"
	by_hand = hand
	torn = tear
	seed_value = seed_number
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var spec: Dictionary = PAPERS[paper]
	var size_of: Vector2 = (spec.texture as Texture2D).get_size()
	written = wrapped(text_lines)
	card = size_of
	var ruled: Array = spec.lines
	if torn and not written.is_empty(): card.y = minf(size_of.y, float(ruled[mini(written.size(), ruled.size()) - 1]) + TEAR_BELOW + TEAR_RAGGED)
	custom_minimum_size = card
	size = card
	for old in get_children(): old.queue_free()
	var layer := Control.new()
	layer.name = "Written" if by_hand else "Typed"
	layer.size = card
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not by_hand:
		if ink_material == null:
			ink_material = ShaderMaterial.new()
			ink_material.shader = INK_SHADER
		layer.material = ink_material
	layer.draw.connect(draw_words.bind(layer))
	add_child(layer)
	queue_redraw()

## The lines as they go on the paper: typed ones broken at the margin by
## letters (the keys are all one width), pencilled ones by how wide the words
## are; an empty one is a line left blank.
func wrapped(text_lines: Array) -> Array:
	var spec: Dictionary = PAPERS[paper]
	var width: float = float(spec.to) - float(spec.from)
	var per_line := int(width / FORM.advance(int(spec.type)))
	var font := ThemeDB.fallback_font
	var out: Array = []
	for line in text_lines:
		var text := String(line)
		if text.is_empty():
			out.append("")
			continue
		var current := ""
		for word in text.split(" "):
			var trial := word if current.is_empty() else current + " " + word
			var too_long: bool = font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, HANDWRITTEN).x > width - 20.0 if by_hand else trial.length() > per_line
			if not current.is_empty() and too_long:
				out.append(current)
				current = word
			else: current = trial
		out.append(current)
	return out

func _draw() -> void:
	var spec: Dictionary = PAPERS[paper]
	var texture: Texture2D = spec.texture
	var full: Vector2 = texture.get_size()
	var outline: Rect2 = spec.outline
	# A picture with its own alpha is drawn as it is, its shadow the same
	# picture darkened; one without is cut out along the paper's edge.
	if outline.size == Vector2.ZERO and not torn:
		draw_texture_rect(texture, Rect2(Vector2(5, 7), full), false, Color(0, 0, 0, 0.4))
		draw_texture_rect(texture, Rect2(Vector2.ZERO, full), false)
		return
	if outline.size == Vector2.ZERO: outline = Rect2(Vector2(18, 46), full - Vector2(36, 92))
	var points := FORM.rounded(outline, float(spec.radius)) if not torn else ragged(outline)
	var shadow := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(5, 7))
		uvs.append(point / full)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.4))
	draw_colored_polygon(points, Color.WHITE, uvs, texture)

## The page down to where it was torn: its top corners rounded, its sides
## straight, and a ragged edge across.
func ragged(outline: Rect2) -> PackedVector2Array:
	var spec: Dictionary = PAPERS[paper]
	var radius: float = maxf(float(spec.radius), 12.0)
	var points := PackedVector2Array()
	var top := FORM.rounded(Rect2(outline.position, Vector2(outline.size.x, radius * 2.0 + 2.0)), radius)
	# The two top corners of the rounded box: its first and second quarter.
	for i in 14: points.append(top[i])
	var bottom := card.y - TEAR_RAGGED
	points.append(Vector2(outline.end.x, bottom))
	var steps := 22
	for step in range(steps, -1, -1):
		var x := outline.position.x + outline.size.x * float(step) / steps
		points.append(Vector2(x, bottom + HAND.jitter(float(seed_value) + 3.0, float(step)) * TEAR_RAGGED * 2.0))
	return points

func draw_words(on: Control) -> void:
	var spec: Dictionary = PAPERS[paper]
	var ruled: Array = spec.lines
	for index in mini(written.size(), ruled.size()):
		var text := String(written[index])
		if text.is_empty(): continue
		var y := float(ruled[index])
		if by_hand: HAND.write_line(on, Vector2(float(spec.from) + 6.0, y - 9.0), text, HANDWRITTEN, GRAPHITE, int(y) + seed_value)
		else: FORM.type_line(on, Vector2(float(spec.from), y - 7.0), text, int(spec.type), seed_value * 977 + index)
