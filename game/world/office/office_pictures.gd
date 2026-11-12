extends RefCounted
## The offices' pictures (spec_rediseno 2 and 6, area 4c), once per builder,
## each on a unit quad facing +Z that a frame's "picture" spot scales
## (pieces/wall.gd picture_frame()). The prints and the city views are the
## Art Institute of Chicago's public-domain engravings, photographs and plans
## (assets/paintings/office/, tools/textures/ingest_dressing.py); what is the
## building's own (diplomas, each planta's evacuation plan) is drawn here, and
## so are the prints if their files are missing. Muted, as prints gone yellow.
const KIT := preload("res://game/world/office/pieces/kit.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SIZE := 256
const PAPER := Color(0.8, 0.76, 0.66)
const INK := Color(0.26, 0.22, 0.18)
## The prints and the maps drawn when there are no works: few textures to a floor.
const PRINTS := 6
const MAPS := 3
const ART := "res://assets/paintings/office/"
## Years under a fluorescent tube: paper yellowed, ink faded.
const AGED := Color(0.88, 0.82, 0.68)
## The openings' proportions (office_walls.gd PIECES): a "print" frame is upright
## (0.72 to 0.78), a "city" one wide (1.45 to 1.49).
const OPENING := {"print": 0.75, "city": 1.47}
## The works by the frame they fit: upright ones for "print", wide ones for "city".
static var works := {}

static func works_for(look: String) -> Array:
	if works.is_empty():
		works = {"print": [], "city": []}
		var entries = JSON.parse_string(FileAccess.get_file_as_string(ART + "paintings.json")) if FileAccess.file_exists(ART + "paintings.json") else null
		if entries is Array:
			for entry in entries:
				if ResourceLoader.exists(ART + "%d.jpg" % int(entry.id)): works["print" if float(entry.aspect) < 1.0 else "city"].append(entry)
	return works.get(look, [])

## The quad of a picture with its own material: look "print" or "city" (pick:
## its variant), "diploma", or "plan" (pick: the planta, of this floor).
static func quad(builder: Node3D, look: String, pick := 0) -> Mesh:
	if not builder.has_meta("office_pictures"): builder.set_meta("office_pictures", {})
	var cache: Dictionary = builder.get_meta("office_pictures")
	var hung := works_for(look)
	var which: int = posmod(pick, hung.size()) if not hung.is_empty() else posmod(pick, PRINTS) if look == "print" else posmod(pick, MAPS) if look == "city" else pick
	var floor_seed: int = int(builder.manifest.get("seed", 0)) if look == "plan" else 0
	var key := "%s_%d_%d" % [look, which, floor_seed]
	if cache.has(key): return cache[key]
	var material := StandardMaterial3D.new()
	if hung.is_empty():
		var image := image_of(builder, look, which)
		image.generate_mipmaps()
		material.albedo_texture = ImageTexture.create_from_image(image)
	else:
		var work: Dictionary = hung[which]
		material.albedo_texture = load(ART + "%d.jpg" % int(work.id))
		material.albedo_color = AGED
		# Cropped to the opening, centred, as the hotel's paintings are.
		var ratio: float = float(OPENING[look]) / float(work.aspect)
		if ratio < 1.0:
			material.uv1_scale = Vector3(ratio, 1, 1)
			material.uv1_offset = Vector3((1.0 - ratio) * 0.5, 0, 0)
		else:
			material.uv1_scale = Vector3(1, 1.0 / ratio, 1)
			material.uv1_offset = Vector3(0, (1.0 - 1.0 / ratio) * 0.5, 0)
	material.roughness = 0.85
	var plane := QuadMesh.new()
	plane.size = Vector2.ONE
	plane.material = material
	plane.resource_name = "picture_" + key
	cache[key] = plane
	return plane

## The picture itself.
static func image_of(builder: Node3D, look: String, pick: int) -> Image:
	match look:
		"city": return city(pick)
		"diploma": return diploma()
		"plan": return plan(builder.manifest, pick)
	return print_of(pick)

## A print when the works are missing: hills under a pale sky, or blocks of colour on cream.
static func print_of(pick: int) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	image.fill(PAPER)
	var inner := Rect2i(16, 16, SIZE - 32, SIZE - 32)
	if pick % 2 == 0:
		image.fill_rect(inner, Color(0.7, 0.72, 0.68).lerp(Color(0.78, 0.7, 0.58), KIT.hash01(pick, 1) * 0.6))
		for layer in 3:
			var shade := Color(0.42, 0.44, 0.36).darkened(0.18 * layer)
			var base := 120 + layer * 30
			for x in range(inner.position.x, inner.end.x):
				var top := base + int(18.0 * sin(float(x) * (0.02 + 0.01 * layer) + KIT.hash01(pick, 2 + layer) * TAU))
				image.fill_rect(Rect2i(x, top, 1, inner.end.y - top), shade)
	else:
		image.fill_rect(inner, Color(0.78, 0.74, 0.63))
		var colours: Array[Color] = [Color(0.7, 0.55, 0.3), Color(0.6, 0.34, 0.25), Color(0.2, 0.24, 0.33)]
		for k in 3:
			var wide := 60 + int(KIT.hash01(pick, 10 + k) * 90.0)
			var tall := 50 + int(KIT.hash01(pick, 20 + k) * 110.0)
			var x := inner.position.x + int(KIT.hash01(pick, 30 + k) * float(inner.size.x - wide))
			var y := inner.position.y + int(KIT.hash01(pick, 40 + k) * float(inner.size.y - tall))
			image.fill_rect(Rect2i(x, y, wide, tall), colours[k])
	return image

## A city map when the works are missing: streets on a grid, two avenues across it, a river, parks.
static func city(pick: int) -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	image.fill(Color(0.8, 0.78, 0.7))
	var street := Color(0.62, 0.6, 0.55)
	for k in range(0, SIZE, 18):
		image.fill_rect(Rect2i(k + (pick % 3) * 4, 0, 2, SIZE), street)
		image.fill_rect(Rect2i(0, k + (pick % 2) * 6, SIZE, 2), street)
	for k in 6:
		var x := 18 * int(KIT.hash01(pick, 50 + k) * 13.0) + 4
		var y := 18 * int(KIT.hash01(pick, 60 + k) * 13.0) + 4
		image.fill_rect(Rect2i(x, y, 14, 14), Color(0.56, 0.62, 0.48))
	for k in 2:
		var slope := 0.25 + KIT.hash01(pick, 80 + k) * 0.5
		var start := int(KIT.hash01(pick, 90 + k) * 120.0)
		for x in SIZE:
			var y := start + int(float(x) * slope)
			if y >= 0 and y < SIZE - 3: image.fill_rect(Rect2i(x, y, 2, 3), Color(0.5, 0.47, 0.42))
	var river := int(SIZE * (0.35 + 0.25 * KIT.hash01(pick, 70)))
	for x in SIZE:
		image.fill_rect(Rect2i(x, river + int(22.0 * sin(float(x) * 0.025 + float(pick))), 1, 12), Color(0.55, 0.62, 0.64))
	for edge: Rect2i in [Rect2i(0, 0, SIZE, 6), Rect2i(0, SIZE - 6, SIZE, 6), Rect2i(0, 0, 6, SIZE), Rect2i(SIZE - 6, 0, 6, SIZE)]:
		image.fill_rect(edge, Color(0.86, 0.84, 0.77))
	return image

## A diploma: its double border, the title, lines of writing and a seal.
static func diploma() -> Image:
	var image := Image.create(SIZE, 192, false, Image.FORMAT_RGB8)
	image.fill(Color(0.84, 0.8, 0.7))
	var brown := Color(0.42, 0.32, 0.22)
	for inset: int in [8, 14]:
		var thick: int = 3 if inset == 8 else 1
		image.fill_rect(Rect2i(inset, inset, SIZE - inset * 2, thick), brown)
		image.fill_rect(Rect2i(inset, 192 - inset - thick, SIZE - inset * 2, thick), brown)
		image.fill_rect(Rect2i(inset, inset, thick, 192 - inset * 2), brown)
		image.fill_rect(Rect2i(SIZE - inset - thick, inset, thick, 192 - inset * 2), brown)
	image.fill_rect(Rect2i(60, 36, SIZE - 120, 10), INK)
	for k in 6: image.fill_rect(Rect2i(40, 70 + k * 14, SIZE - 80 - (k % 3) * 20, 3), Color(0.5, 0.46, 0.4))
	for y in range(130, 170):
		for x in range(170, 210):
			if Vector2(x - 190, y - 150).length() < 18.0: image.set_pixel(x, y, Color(0.7, 0.55, 0.25))
	return image

## A planta's evacuation plan from the floor's own plan: its rooms outlined,
## the corridors in green, the lift's lobby (the way out) in red.
static func plan(manifest: Dictionary, planta: int) -> Image:
	var image := Image.create(SIZE, 192, false, Image.FORMAT_RGB8)
	image.fill(Color(0.86, 0.84, 0.78))
	var rooms: Array = []
	for room in manifest.get("rooms", []):
		if int(room.get("wing", -1)) == planta and int(room.get("type", -1)) != OFFICE.VOID: rooms.append(room)
	if rooms.is_empty(): return image
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for room in rooms:
		var half := Vector2(float(room.span_x), float(room.span_z)) * 0.5
		var centre := Vector2(float(room.px), float(room.pz))
		low = Vector2(minf(low.x, centre.x - half.x), minf(low.y, centre.y - half.y))
		high = Vector2(maxf(high.x, centre.x + half.x), maxf(high.y, centre.y + half.y))
	var fit := minf(float(SIZE - 24) / maxf(high.x - low.x, 1.0), 168.0 / maxf(high.y - low.y, 1.0))
	for room in rooms:
		var t := int(room.type)
		var half := Vector2(float(room.span_x), float(room.span_z)) * 0.5
		var corner := (Vector2(float(room.px), float(room.pz)) - half - low) * fit + Vector2(12, 12)
		var cell := Rect2i(int(corner.x), int(corner.y), maxi(int(half.x * 2.0 * fit), 3), maxi(int(half.y * 2.0 * fit), 3))
		var fill := Color(0.82, 0.8, 0.74)
		if bool(room.get("corridor", false)) or t == OFFICE.CORRIDOR or t == OFFICE.GALLERY: fill = Color(0.7, 0.78, 0.66)
		if t == OFFICE.REFUGE: fill = Color(0.68, 0.24, 0.18)
		image.fill_rect(cell, Color(0.25, 0.25, 0.24))
		image.fill_rect(cell.grow(-1), fill)
	return image
