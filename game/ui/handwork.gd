extends RefCounted
## Things made by hand on paper: numbers written with a pencil, and the wear a
## sheet picks up being carried about a hotel. Drawn, not set or imported --
## there is no handwritten typeface in the project, and a sheet worn by a
## texture file would be the same sheet on every floor.
##
## The numbers are the ones the pages in this hotel are written in: thick,
## shaky, gone over twice, nothing quite straight, the way the pages a certain
## tall man left in a forest were written. Every wobble comes from the number
## and the seed, so the same page always looks the same on every machine.

## Each digit as the strokes a hand would make, in a unit box (y down). A loop
## is written out as its points; a stroke with one point is a dot.
const STROKES := {
	0: [[[0.5, 0.06], [0.74, 0.16], [0.84, 0.42], [0.8, 0.72], [0.62, 0.92], [0.4, 0.93], [0.2, 0.76], [0.16, 0.46], [0.24, 0.18], [0.46, 0.06], [0.58, 0.09]]],
	1: [[[0.3, 0.24], [0.56, 0.06], [0.54, 0.94]]],
	2: [[[0.18, 0.28], [0.3, 0.1], [0.52, 0.05], [0.74, 0.14], [0.8, 0.32], [0.68, 0.52], [0.18, 0.93], [0.84, 0.9]]],
	3: [[[0.18, 0.14], [0.44, 0.05], [0.72, 0.13], [0.76, 0.32], [0.46, 0.47], [0.78, 0.6], [0.8, 0.82], [0.52, 0.95], [0.18, 0.86]]],
	4: [[[0.62, 0.94], [0.62, 0.05], [0.14, 0.66], [0.86, 0.64]]],
	5: [[[0.8, 0.07], [0.28, 0.08], [0.22, 0.46], [0.5, 0.38], [0.78, 0.5], [0.8, 0.77], [0.56, 0.94], [0.2, 0.86]]],
	6: [[[0.74, 0.1], [0.46, 0.08], [0.26, 0.34], [0.2, 0.7], [0.36, 0.93], [0.64, 0.93], [0.8, 0.72], [0.68, 0.52], [0.4, 0.5], [0.22, 0.66]]],
	7: [[[0.16, 0.08], [0.84, 0.07], [0.4, 0.94]]],
	8: [[[0.5, 0.48], [0.28, 0.36], [0.28, 0.14], [0.5, 0.05], [0.72, 0.14], [0.7, 0.36], [0.5, 0.48], [0.22, 0.62], [0.24, 0.86], [0.5, 0.95], [0.78, 0.86], [0.78, 0.62], [0.5, 0.48]]],
	9: [[[0.78, 0.36], [0.64, 0.08], [0.36, 0.08], [0.2, 0.3], [0.32, 0.5], [0.62, 0.5], [0.78, 0.36], [0.74, 0.7], [0.56, 0.94], [0.28, 0.9]]],
}

## A number between -0.5 and 0.5 that only depends on its arguments.
static func jitter(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0) - 0.5

## Writes `value` into `box` on `on`: the strokes cut into short pieces, each
## piece nudged a little, and the whole thing gone over a second time a hair
## off the first, which is what makes a pencil line look like one.
static func write_digit(on: CanvasItem, value: int, box: Rect2, ink: Color, weight: float, seed_value := 0) -> void:
	for stroke in STROKES.get(clampi(value, 0, 9), []):
		for pass_index in 2:
			# Each turn of the stroke is put down a little off where it should
			# be, and the line runs smoothly between them: a hand wanders, it
			# does not tremble at every millimetre. Only the grain of the
			# pencil is added along the way.
			var turns: Array = []
			for k in stroke.size():
				var wander := Vector2(jitter(float(k), seed_value + pass_index * 3.1), jitter(float(k) + 7.7, seed_value - pass_index * 1.9)) * 0.07
				turns.append(Vector2(stroke[k][0], stroke[k][1]) + wander)
			var points := PackedVector2Array()
			for k in turns.size() - 1:
				for step in 4:
					var t := float(step) / 4.0
					var grain := Vector2(jitter(float(k * 4 + step), seed_value + 11.0), jitter(float(k * 4 + step) + 3.3, seed_value + 5.0)) * 0.012
					points.append(box.position + (turns[k].lerp(turns[k + 1], t) + grain) * box.size)
			points.append(box.position + turns[turns.size() - 1] * box.size)
			on.draw_polyline(points, Color(ink, ink.a * (1.0 if pass_index == 0 else 0.55)), weight * (1.0 if pass_index == 0 else 0.7), true)

## A line of words written by hand: the fallback typeface (there is no
## handwritten one), leaning a little and a little off true by the seed, and
## gone over twice, the second time a hair off the first.
static func write_line(on: CanvasItem, at: Vector2, text: String, font_size: int, ink: Color, seed_value := 0) -> void:
	var font := ThemeDB.fallback_font
	var tilt := jitter(float(seed_value), 7.0) * 0.035
	on.draw_set_transform_matrix(Transform2D(tilt, Vector2.ONE, -0.18, at))
	on.draw_string(font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
	on.draw_string(font, Vector2(0.7, 0.4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(ink, ink.a * 0.38))
	on.draw_set_transform_matrix(Transform2D.IDENTITY)

## A short dash either side of a small number: how a page is numbered.
static func write_page(on: CanvasItem, value: int, centre: Vector2, height: float, ink: Color, seed_value := 0) -> void:
	var width := height * 0.62
	write_digit(on, value, Rect2(centre - Vector2(width, height) * 0.5, Vector2(width, height)), ink, maxf(1.2, height * 0.12), seed_value)
	for side in [-1.0, 1.0]:
		var near := centre + Vector2(side * height * 0.62, 0.0)
		var far := centre + Vector2(side * height * 1.25, jitter(side, seed_value) * height * 0.15)
		on.draw_line(near, far, ink, maxf(1.0, height * 0.1), true)

## What a sheet picks up being folded into a pocket and carried round a hotel:
## pulp in the paper, the yellowing towards the edges, a coffee ring or two, a
## fold. Brown with an alpha, to lay over a clean page -- over the pencil too,
## so rubbing something out never rubs the stains out with it. Built once per
## size and seed.
static var worn := {}
## `marked`: false for a page kept flat and clean -- the shared sheet, which
## carries the plan: no coffee rings and no fold across it.
static func wear(size: Vector2i, seed_value: int, marked := true) -> ImageTexture:
	var key := "%d:%d:%d:%s" % [size.x, size.y, seed_value, marked]
	if worn.has(key): return worn[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rings: Array = []
	for n in (rng.randi_range(1, 3) if marked else 0):
		rings.append([Vector2(rng.randf_range(0.08, 0.92), rng.randf_range(0.08, 0.92)), rng.randf_range(0.06, 0.13), rng.randf_range(0.5, 1.0)])
	var blots: Array = []
	for n in rng.randi_range(2, 5):
		blots.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.05, 0.2), rng.randf_range(0.2, 0.55)])
	var fold := rng.randf_range(0.35, 0.65)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var aspect := float(size.x) / float(size.y)
	for y in size.y:
		for x in size.x:
			var uv := Vector2((float(x) + 0.5) / size.x, (float(y) + 0.5) / size.y)
			# Pulp: a fine grain, and the paper yellowing from the edges in.
			var amount := 0.05 + jitter(float(x), float(y) + seed_value) * 0.06
			var edge := minf(minf(uv.x, 1.0 - uv.x) * aspect, minf(uv.y, 1.0 - uv.y))
			amount += pow(clampf(1.0 - edge / 0.12, 0.0, 1.0), 2.0) * 0.45
			# The fold across it, a darker line with a soft side.
			if marked: amount += exp(-pow((uv.x - fold) * size.x / 2.2, 2.0)) * 0.22
			for ring in rings:
				var d: float = Vector2((uv.x - ring[0].x) * aspect, uv.y - ring[0].y).length() / ring[1]
				# A coffee ring is darker at its rim than inside it.
				amount += (exp(-pow((d - 1.0) * 9.0, 2.0)) * 0.34 + (0.07 if d < 1.0 else 0.0)) * ring[2]
			for blot in blots:
				var d: float = Vector2((uv.x - blot[0].x) * aspect, uv.y - blot[0].y).length() / blot[1]
				amount += exp(-d * d * 2.0) * blot[2] * 0.35
			image.set_pixel(x, y, Color(0.42, 0.29, 0.14, clampf(amount, 0.0, 0.85)))
	var texture := ImageTexture.create_from_image(image)
	worn[key] = texture
	return texture
