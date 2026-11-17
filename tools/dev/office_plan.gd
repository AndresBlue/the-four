extends SceneTree
## The offices drawn as plans from the manifest, nothing built: a PNG a planta
## from above and a sheet with the three side by side at one scale.
##   godot --headless --script tools/dev/office_plan.gd -- 7 33 [--plan=spine] [--out=evidence/planta/hoy] [--survivors=N]
## Walls dark, doorways pale gaps (fire doors red), rooms filled by type with
## their code, corridors grey, the service gallery tan, unused cells black;
## the lift cars crossed and lettered (A, B, the shaft), the planta's landmarks
## outlined in red, the main duct in orange. The floor is the game's (the
## standby one where no try of the building passes); --plan= forces a typology
## (office_palette.forced_typology()). The validator's complaints are printed.
const GEN := preload("res://game/world/generation/office_generator.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## Pixels a metre, and the margins round a planta.
const PX := 8.0
const MARGIN := 40
const TOP := 70
## Each type's fill and the code written in it ("" none).
## A 3 x 5 font, rows top to bottom.
const GLYPHS := {"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111", "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001001001", "8": "111101111101111", "9": "111101111001111", "A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110", "E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101", "I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111", "M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100", "Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010", "U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101", "Y": "101101010010010", "Z": "111001010100111", " ": "000000000000000", ".": "000000000000010", ",": "000000000010100", ":": "000010000010000", "-": "000000111000000", "/": "001001010100100", "(": "010100100100010", ")": "010001001001010", "=": "000111000111000"}
const PLAIN := {"Á": "A", "É": "E", "Í": "I", "Ó": "O", "Ú": "U", "Ñ": "N", "Ü": "U"}

func _initialize() -> void:
	var seeds: Array = []
	var out := "res://evidence/planta/hoy"
	var survivors := 2
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int(): seeds.append(int(argument))
		elif argument.begins_with("--out="): out = "res://" + argument.get_slice("=", 1).trim_prefix("res://")
		elif argument.begins_with("--survivors="): survivors = int(argument.get_slice("=", 1))
	if seeds.is_empty(): seeds = [7]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	for run_seed in seeds:
		var data := GEN.new().generate(int(run_seed), survivors)
		if data.is_empty():
			print("PLAN semilla %d: ningún intento sale" % run_seed)
			continue
		var errors: Array = GEN.new().validator().validate(data)
		print("PLAN semilla %d intento %d respaldo %s, paseo %d salas, %d errores del validador %s" % [run_seed, int(data.get("attempt", -1)), str(data.get("fallback", false)), int(data.walk), errors.size(), str(codes(errors))])
		var images: Array = []
		for planta in 3:
			var image := draw_planta(data, planta)
			image.save_png(ProjectSettings.globalize_path("%s/s%d_p%d.png" % [out, run_seed, planta + 1]))
			images.append(image)
		sheet(images).save_png(ProjectSettings.globalize_path("%s/s%d_hoja.png" % [out, run_seed]))
	quit()

## The validator's codes without their numbers, counted.
static func codes(errors: Array) -> Dictionary:
	var out := {}
	for error in errors:
		var code := String(error).rstrip("0123456789_")
		out[code] = int(out.get(code, 0)) + 1
	return out

static func draw_planta(data: Dictionary, planta: int) -> Image:
	var dims: Dictionary = data.plantas[planta]
	var rooms: Array = data.rooms
	var cells: Array = []
	for local in int(dims.width) * int(dims.height): cells.append(rooms[int(dims.base) + local])
	var low := Vector2(INF, INF)
	var high := -low
	var used_low := low
	var used_high := high
	for room in cells:
		var r := rect_of(room)
		low = low.min(r.position)
		high = high.max(r.end)
		if FLOOR.is_void(room): continue
		used_low = used_low.min(r.position)
		used_high = used_high.max(r.end)
	var size := Vector2i(int((high.x - low.x) * PX) + 2 * MARGIN, int((high.y - low.y) * PX) + TOP + MARGIN + 30)
	var image := Image.create_empty(maxi(size.x, 520), size.y, false, Image.FORMAT_RGB8)
	image.fill(Color("f7f5ef"))
	var to_px := func(point: Vector2) -> Vector2i: return Vector2i(int(round((point.x - low.x) * PX)) + MARGIN, int(round((point.y - low.y) * PX)) + TOP)
	var box := func(r: Rect2) -> Rect2i:
		var a: Vector2i = to_px.call(r.position)
		var b: Vector2i = to_px.call(r.end)
		return Rect2i(a, b - a)
	var open := {}
	for pair in data.merged: open[Vector2i(int(pair[0]), int(pair[1]))] = true
	# Fills.
	for room in cells: image.fill_rect(box.call(rect_of(room)), OFFICE.plan_fill(room))
	# Walls: every side that is not open to the cell beyond, thicker on the outside.
	var wall_colour := Color("2b2b2b")
	for room in cells:
		if FLOOR.is_void(room): continue
		var r: Rect2i = box.call(rect_of(room))
		for way: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var other := FLOOR.beside(room, way)
			var key := Vector2i(mini(int(room.id), other), maxi(int(room.id), other))
			if other >= 0 and open.has(key): continue
			var outside: bool = other < 0 or FLOOR.is_void(rooms[other])
			var half := 2 if outside else 1
			image.fill_rect(side_rect(r, way, half), wall_colour)
	# Doorways, gaps in the walls: pale, a fire door between corridors red.
	for room in cells:
		for entry in room.get("doors", []):
			var other: Dictionary = rooms[int(entry[0])]
			if int(other.id) < int(room.id): continue
			var centre := FLOOR.portal_between(room, other)
			var across := int(room.x) != int(other.x)
			var half := FLOOR.PORTAL * 0.5
			var a: Vector2i = to_px.call(Vector2(centre.x, centre.z - half) if across else Vector2(centre.x - half, centre.z))
			var b: Vector2i = to_px.call(Vector2(centre.x, centre.z + half) if across else Vector2(centre.x + half, centre.z))
			var fire: bool = bool(room.corridor) and bool(other.corridor)
			var gap := Rect2i(a.x - 2, a.y, 5, b.y - a.y) if across else Rect2i(a.x, a.y - 2, b.x - a.x, 5)
			image.fill_rect(gap, Color("c03030") if fire else Color("fff8d0"))
	# Codes: one per room, a salon's in the middle of its cells.
	var units := {}
	for room in cells:
		if FLOOR.is_void(room) or bool(room.corridor): continue
		var key := int(room.hall) if int(room.hall) >= 0 else int(room.id)
		var r := rect_of(room)
		units[key] = (units[key] as Rect2).merge(r) if units.has(key) else r
	var keys: Array = units.keys()
	keys.sort()
	for key in keys:
		var room: Dictionary = rooms[int(key)]
		var code: String = OFFICE.plan_code(room)
		var r: Rect2i = box.call(units[key])
		var scale := 2 if text_width(code, 2) < r.size.x - 4 else 1
		write(image, r.get_center() - Vector2i(text_width(code, scale) / 2, 5 * scale / 2), code, scale, Color("1a1a1a"))
	# The landmarks: outlined in red; the lift cars crossed and lettered.
	var marks := {}
	var letters := ["A", "B", "POZO"]
	for kind in [OFFICE.RECEPTION, OFFICE.WINDOW, OFFICE.ELECTRICAL, OFFICE.SECURITY, OFFICE.AIR_ROOM, OFFICE.REFUGE, OFFICE.LOBBY]:
		for room in cells:
			if int(room.type) == kind: marks[int(room.id)] = true
	for id in marks: outline(image, box.call(rect_of(rooms[int(id)])), Color("d02020"), 2)
	for index in data.gates.size():
		var gate: Dictionary = data.gates[index]
		for id in [int(gate.beyond), int(gate.get("arrive", -1))]:
			if id < 0 or int(rooms[id].wing) != planta: continue
			var r: Rect2i = box.call(rect_of(rooms[id]))
			cross(image, r, Color("703070"))
			var letter: String = letters[index]
			write(image, r.get_center() - Vector2i(text_width(letter, 3) / 2, 7), letter, 3, Color("ffffff"))
	# The main duct, on the third planta.
	if planta == 2 and data.has("air"):
		var chain: Array = data.air.main.cells
		for i in range(chain.size() - 1):
			var a: Vector2i = to_px.call(Vector2(float(rooms[int(chain[i])].px), float(rooms[int(chain[i])].pz)))
			var b: Vector2i = to_px.call(Vector2(float(rooms[int(chain[i + 1])].px), float(rooms[int(chain[i + 1])].pz)))
			image.fill_rect(Rect2i(mini(a.x, b.x) - 2, mini(a.y, b.y) - 2, absi(b.x - a.x) + 5, absi(b.y - a.y) + 5), Color("e07a10"))
	# Title and scale.
	var plan: Dictionary = data.plans[planta]
	var title := "SEMILLA %d  PLANTA %d %s" % [int(data.seed), planta + 1, plain(OFFICE.PLANTA_NAMES[planta])]
	var below := "%s %s %s  %.1f X %.1f M  %d SALAS" % ["RESERVA" if bool(data.get("fallback", false)) else "EDIFICIO", String(plan.plan), String(plan.shape), used_high.x - used_low.x, used_high.y - used_low.y, int(plan.rooms)]
	write(image, Vector2i(MARGIN, 12), title, 3, Color("1a1a1a"))
	write(image, Vector2i(MARGIN, 38), plain(below), 2, Color("404040"))
	var foot := image.get_height() - 24
	var ten := int(10.0 * PX)
	image.fill_rect(Rect2i(MARGIN, foot, ten, 4), Color("1a1a1a"))
	for tick in [0, ten / 2, ten - 2]: image.fill_rect(Rect2i(MARGIN + tick, foot - 6, 2, 10), Color("1a1a1a"))
	write(image, Vector2i(MARGIN + ten + 8, foot - 3), "10 M", 2, Color("1a1a1a"))
	return image

## The three plantas side by side, tops aligned, at one scale.
static func sheet(images: Array) -> Image:
	var width := 0
	var height := 0
	for image: Image in images:
		width += image.get_width()
		height = maxi(height, image.get_height())
	var out := Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	out.fill(Color("f7f5ef"))
	var x := 0
	for image: Image in images:
		out.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(x, 0))
		x += image.get_width()
	return out

static func rect_of(room: Dictionary) -> Rect2:
	var size := Vector2(float(room.span_x), float(room.span_z))
	return Rect2(Vector2(float(room.px), float(room.pz)) - size * 0.5, size)

## The strip of a cell's rect along one side, `half` pixels either side of it.
static func side_rect(r: Rect2i, way: Vector2i, half: int) -> Rect2i:
	match way:
		Vector2i(1, 0): return Rect2i(r.end.x - half, r.position.y - half, 2 * half, r.size.y + 2 * half)
		Vector2i(-1, 0): return Rect2i(r.position.x - half, r.position.y - half, 2 * half, r.size.y + 2 * half)
		Vector2i(0, 1): return Rect2i(r.position.x - half, r.end.y - half, r.size.x + 2 * half, 2 * half)
	return Rect2i(r.position.x - half, r.position.y - half, r.size.x + 2 * half, 2 * half)

static func outline(image: Image, r: Rect2i, colour: Color, width: int) -> void:
	var inner := r.grow(-3)
	image.fill_rect(Rect2i(inner.position, Vector2i(inner.size.x, width)), colour)
	image.fill_rect(Rect2i(Vector2i(inner.position.x, inner.end.y - width), Vector2i(inner.size.x, width)), colour)
	image.fill_rect(Rect2i(inner.position, Vector2i(width, inner.size.y)), colour)
	image.fill_rect(Rect2i(Vector2i(inner.end.x - width, inner.position.y), Vector2i(width, inner.size.y)), colour)

static func cross(image: Image, r: Rect2i, colour: Color) -> void:
	image.fill_rect(r.grow(-3), colour)
	var steps := maxi(r.size.x, r.size.y)
	for i in steps:
		var t := float(i) / float(steps)
		for p: Vector2i in [Vector2i(r.position.x + int(t * r.size.x), r.position.y + int(t * r.size.y)), Vector2i(r.position.x + int(t * r.size.x), r.end.y - 1 - int(t * r.size.y))]:
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(p): image.set_pixelv(p, Color("c8a0c8"))

static func plain(text: String) -> String:
	var out := text.to_upper()
	for accented in PLAIN: out = out.replace(accented, PLAIN[accented])
	return out

static func text_width(text: String, scale: int) -> int:
	return text.length() * 4 * scale - scale

static func write(image: Image, at: Vector2i, text: String, scale: int, colour: Color) -> void:
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	var x := at.x
	for character in plain(text):
		var glyph: String = GLYPHS.get(character, GLYPHS[" "])
		for row in 5:
			for column in 3:
				if glyph[row * 3 + column] != "1": continue
				var pixel := Rect2i(x + column * scale, at.y + row * scale, scale, scale)
				if bounds.encloses(pixel): image.fill_rect(pixel, colour)
		x += 4 * scale
