extends RefCounted
## Cracked CRT glass drawn at runtime where each blow actually lands.
## A blow leaves what real impact fractures show: a crushed, frosted core,
## long radial cracks that run nearly straight with small kinks and forks, and
## concentric ring cracks joining neighbouring radials. Each blow is written to
## its own channel (R, G, B, A for blows 1–4) with anti-aliased lines, so the
## screen shader reveals the damage one knock at a time.
const WIDTH := 1024
const HEIGHT := 768
var image := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
var texture := ImageTexture.create_from_image(image)
var rng := RandomNumberGenerator.new()

func _init(seed_value := 4411) -> void:
	rng.seed = seed_value

## uv: point on the tube (0..1). stage: 0..3 (channel). severity: 0..1.
func add_impact(uv: Vector2, stage: int, severity: float) -> void:
	var centre := uv * Vector2(WIDTH, HEIGHT)
	var reach := lerpf(120.0, 420.0, severity)
	# Crushed core: a dense web of tiny fractures and a frosted spot.
	var core := lerpf(4.0, 11.0, severity)
	for i in 14 + int(severity * 18):
		var a := rng.randf() * TAU
		var from := centre + Vector2(cos(a), sin(a)) * rng.randf() * core
		var b := a + rng.randf_range(-1.2, 1.2)
		stroke(from, from + Vector2(cos(b), sin(b)) * rng.randf_range(3.0, core), stage, rng.randf_range(0.4, 0.8), 0.45)
	disc(centre, core * 0.5, stage, 0.45)
	# Radial cracks with their end points recorded to join the rings.
	var count := 6 + int(severity * 6)
	var rays: Array = []
	var offset := rng.randf() * TAU
	for i in count:
		var angle := offset + TAU * float(i) / count + rng.randf_range(-0.25, 0.25)
		var length := reach * rng.randf_range(0.45, 1.0)
		rays.append(radial(centre, angle, length, stage, 1.0, 2))
	# Ring cracks: straight chords between neighbouring radials at one or two radii.
	for ring in 1 + int(severity > 0.5):
		var radius := reach * (0.22 + 0.25 * ring) * rng.randf_range(0.85, 1.15)
		for i in count:
			if rng.randf() < 0.3: continue
			var p := point_on(rays[i], radius)
			var q := point_on(rays[(i + 1) % count], radius * rng.randf_range(0.9, 1.1))
			if p == Vector2.INF or q == Vector2.INF: continue
			var middle := (p + q) * 0.5 + (p - centre).normalized() * rng.randf_range(-4.0, 6.0)
			stroke(p, middle, stage, 0.6, 0.45)
			stroke(middle, q, stage, 0.6, 0.45)
	texture.update(image)

## A crack that runs outward nearly straight, kinking and sometimes forking.
## Returns its polyline.
func radial(from: Vector2, angle: float, length: float, stage: int, strength: float, depth: int) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var point := from
	var travelled := 0.0
	var heading := angle
	while travelled < length:
		var step := rng.randf_range(8.0, 18.0)
		heading += rng.randf_range(-0.14, 0.14)
		var next := point + Vector2(cos(heading), sin(heading)) * step
		# Thinner and fainter towards the tip.
		var fade := 1.0 - travelled / length
		stroke(point, next, stage, strength * (0.3 + 0.7 * fade), lerpf(0.3, 0.7, fade))
		points.append(next)
		if depth > 0 and travelled > length * 0.25 and rng.randf() < 0.06:
			radial(next, heading + rng.randf_range(0.35, 0.8) * (1.0 if rng.randf() < 0.5 else -1.0), (length - travelled) * rng.randf_range(0.3, 0.6), stage, strength * 0.75, depth - 1)
		point = next
		travelled += step
		if point.x < 0 or point.y < 0 or point.x > WIDTH or point.y > HEIGHT: break
	return points

static func point_on(line: PackedVector2Array, radius: float) -> Vector2:
	var travelled := 0.0
	for i in range(1, line.size()):
		var segment := line[i].distance_to(line[i - 1])
		if travelled + segment >= radius: return line[i - 1].lerp(line[i], (radius - travelled) / segment)
		travelled += segment
	return Vector2.INF

## Anti-aliased line of the given half-width into one channel (keeps the maximum).
func stroke(a: Vector2, b: Vector2, stage: int, strength: float, width: float) -> void:
	var length := a.distance_to(b)
	var count := int(length * 1.5) + 1
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var x := int(p.x) + dx
				var y := int(p.y) + dy
				if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT: continue
				var distance := Vector2(x + 0.5, y + 0.5).distance_to(p)
				var cover := clampf(width + 0.5 - distance, 0.0, 1.0) * strength
				if cover <= 0.0: continue
				var colour := image.get_pixel(x, y)
				if cover > colour[stage]:
					colour[stage] = cover
					image.set_pixel(x, y, colour)

func disc(centre: Vector2, radius: float, stage: int, strength: float) -> void:
	for x in range(int(centre.x - radius) - 1, int(centre.x + radius) + 2):
		for y in range(int(centre.y - radius) - 1, int(centre.y + radius) + 2):
			if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT: continue
			var cover := clampf(radius - Vector2(x + 0.5, y + 0.5).distance_to(centre), 0.0, 1.0) * strength * rng.randf_range(0.6, 1.0)
			var colour := image.get_pixel(x, y)
			if cover > colour[stage]:
				colour[stage] = cover
				image.set_pixel(x, y, colour)
