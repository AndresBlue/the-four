extends RefCounted
## The pages of the code (the author's word, 22 October 2026): somebody wrote
## the code of the last door on a letter (assets/carta.png, folded in four)
## and tore it along its folds into four pieces, one number on each, and hid
## them apart, so nobody holding one has it all -- the way a combination is
## split among the people who keep a safe. Which piece it is says which place
## of the code its number is: the top left the first, the top right the
## second, the bottom left the third, the bottom right the fourth. On the sheet
## the pieces found are put back together where they belong (paper_sheet.gd);
## shut in a piece of furniture what shows is the outside of one, blank
## (hotel_container.plant_note(), assets/textures/carta-trozo.png).
const HAND := preload("res://game/ui/handwork.gd")
const STYLE := preload("res://game/ui/osd_style.gd")
const CARTA := preload("res://assets/carta.png")
## Where the folds cross, in the picture's pixels.
const FOLD := Vector2(515, 767)
const GRAPHITE := Color(0.13, 0.12, 0.12)
## How ragged the torn edges are (picture pixels) and how many teeth.
const RAGGED := 9.0
const TEETH := 18

## The quarter of the picture a piece is (place 1 to 4).
static func quarter(place: int) -> Rect2:
	var size: Vector2 = CARTA.get_size()
	var column := (place - 1) % 2
	var row := (place - 1) / 2
	var from := Vector2(0.0 if column == 0 else FOLD.x, 0.0 if row == 0 else FOLD.y)
	var to := Vector2(FOLD.x if column == 0 else size.x, FOLD.y if row == 0 else size.y)
	return Rect2(from, to - from)

## Its outline, in the picture's pixels: straight along the letter's own
## edges, torn along the two folds inside it. The tears are the same on the two
## pieces either side of a fold (seeded by the fold, not the piece), so the
## four fit back together.
static func outline(place: int) -> PackedVector2Array:
	var box := quarter(place)
	var column := (place - 1) % 2
	var row := (place - 1) / 2
	var points := PackedVector2Array()
	# Round the box clockwise from its top left, each side straight or torn.
	var corners := [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]
	for side in 4:
		var a: Vector2 = corners[side]
		var b: Vector2 = corners[(side + 1) % 4]
		# Which sides lie on a fold: the right of a left piece, the left of a
		# right one, the bottom of a top one, the top of a bottom one.
		var on_fold: bool = (side == 1 and column == 0) or (side == 3 and column == 1) or (side == 2 and row == 0) or (side == 0 and row == 1)
		for step in TEETH:
			var t := float(step) / TEETH
			var point: Vector2 = a.lerp(b, t)
			if on_fold and step > 0:
				# The fold's own tear, from the fold's position along it.
				var vertical := side == 1 or side == 3
				var along: float = point.y if vertical else point.x
				var tooth := HAND.jitter(along * 0.07, 3.0 if vertical else 5.0) * RAGGED * 2.0
				point += Vector2(tooth, 0.0) if vertical else Vector2(0.0, tooth)
			points.append(point)
	return points

## A piece drawn into `rect` on `on`: the paper as torn, its number written
## large in pencil over its middle, and under it the room it came out of.
static func draw_piece(on: CanvasItem, place: int, rect: Rect2, digit: int, where := "", turn := 0.0) -> void:
	var box := quarter(place)
	var scale := rect.size / box.size
	var middle := rect.get_center()
	on.draw_set_transform(middle, turn, Vector2.ONE)
	var shadow := PackedVector2Array()
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	for point in outline(place):
		var at := (point - box.get_center()) * scale
		points.append(at)
		shadow.append(at + Vector2(3, 4))
		uvs.append(point / CARTA.get_size())
	on.draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	on.draw_colored_polygon(points, Color.WHITE, uvs, CARTA)
	var size := rect.size
	var figure := Rect2(Vector2(-size.x * 0.24, -size.y * 0.36), Vector2(size.x * 0.48, size.y * 0.46))
	HAND.write_digit(on, digit, figure, GRAPHITE, size.x * 0.07, place * 13 + digit)
	if not where.is_empty():
		var font := STYLE.font()
		var font_size := 11
		var width := font.get_string_size(where, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		on.draw_string(font, Vector2(-minf(width, size.x - 12.0) * 0.5, size.y * 0.3), where, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, font_size, Color(GRAPHITE, 0.8))
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
