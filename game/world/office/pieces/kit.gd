extends RefCounted
## The offices' pieces made in code (spec_rediseno.md 5.1, area 4a): what
## every family of pieces builds with, and their cache. A piece is one
## ArrayMesh with a surface per material key, baked once per builder (kept in
## its "office_pieces" metadata: the builder's materials follow the preset in
## place, so a mesh made with them stays right) and placed with
## builder.place(), one MultiMesh per room and mesh. Its frame: origin on the
## floor at the middle of its footprint, front to +Z, back at -size.z / 2, all
## of it inside the box of its size ("size" metadata); "collider" is its one
## box collider, that same box unless the piece gives its own.
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
## A piece's own materials: keys office_geometry does not load, loaded here.
const MATERIAL_DIR := "res://game/presentation/materials/office/%s.tres"
## Nothing in a room is taller (office_palette FURNITURE_TOP, OFICINAS 2)...
const TOP := 2.2
## ...but what hangs on a wall no deeper than this (spec_rediseno 0).
const FLAT := 0.2
## What a front and its pull stand out from their carcass, inside the size.
const FRONT := 0.04
## Spines of books and binders (book_row(), binder_row()): muted cloths
## (maroon, bottle green, navy), leather and old board, nothing lighter than
## a dull cream (plastic_beige): under the lamps paper and linen read white.
const BOOK_KEYS := ["cloth_red", "cloth_green", "cloth_navy", "leather", "cardboard", "black", "cloth_red", "leather", "cloth_navy", "plastic_beige"]
const BINDER_KEYS := ["black", "black", "cloth_navy", "cloth_green", "cloth_red", "cardboard"]
## What lies in a pigeonhole (post_pile()): envelopes, manila and plain paper.
const POST_KEYS := ["paper", "plastic_beige", "linen", "cardboard", "paper"]
## A piece's contents at variant v (0 to 2) take their picks from pick + v * VARIANT.
const VARIANT := 1000

## The piece `key` names on this builder, made by `make` the first time.
static func cached(builder: Node3D, key: String, make: Callable) -> ArrayMesh:
	if not builder.has_meta("office_pieces"): builder.set_meta("office_pieces", {})
	var cache: Dictionary = builder.get_meta("office_pieces")
	if not cache.has(key): cache[key] = make.call()
	return cache[key]

## A cache key: the piece's name, its size to the millimetre and its options.
static func key_of(title: String, size: Vector3, options := "") -> String:
	return "%s:%.3f:%.3f:%.3f:%s" % [title, size.x, size.y, size.z, options]

## The builder's material for `key`. A piece's own (a <key>.tres in
## MATERIAL_DIR that office_geometry does not load) joins its materials the
## first time, as office_geometry._init() loads the office's, and follows the
## preset with them.
static func material(builder: Node3D, key: String) -> Material:
	var materials: Dictionary = builder.materials
	if materials.has(key): return materials[key]
	var path: String = MATERIAL_DIR % key
	if not ResourceLoader.exists(path):
		push_error("office piece: no material " + key)
		return materials["metal"]
	var made: Material = load(path).duplicate()
	made.set_meta("lite", "office/" + key)
	GEOMETRY.apply_scan(made, GEOMETRY.small_maps)
	materials[key] = made
	return made

## A piece being made: its SurfaceTools by material key.
static func begin() -> Dictionary:
	return {}

## The SurfaceTool of `key` in a piece being made.
static func tool_for(parts: Dictionary, key: String) -> SurfaceTool:
	if not parts.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		parts[key] = tool
	return parts[key]

## A triangle facing `out`, flat shaded. Godot draws the side from which the
## corners run clockwise, so they go in that order seen from `out`.
static func tri(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-14: return
	if n.dot(out) > 0.0:
		var swap := b
		b = c
		c = swap
		n = -n
	tool.set_normal(-n.normalized())
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)

## A quad a b c d (in order round it) facing `out`.
static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
	tri(tool, a, b, c, out)
	tri(tool, a, c, d, out)

## A box of `size` centred at `centre`, turned by `turn` round its centre, its
## twelve edges chamfered by `bevel` (square at 0): 44 triangles, 12 square.
static func block(parts: Dictionary, key: String, centre: Vector3, size: Vector3, bevel := 0.0, turn := Basis.IDENTITY) -> void:
	var tool := tool_for(parts, key)
	var h := size * 0.5
	var b := clampf(bevel, 0.0, minf(h.x, minf(h.y, h.z)) * 0.9)
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for side: float in [-1.0, 1.0]:
			var face: Array[Vector3] = []
			for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var s := Vector3.ZERO
				s[axis] = side
				s[u] = corner.x
				s[v] = corner.y
				face.append(centre + turn * point(h, b, s, axis))
			var out := Vector3.ZERO
			out[axis] = side
			quad(tool, face[0], face[1], face[2], face[3], turn * out)
	if b <= 0.0: return
	# The chamfers along each axis, between the faces square to the other two.
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		for su: float in [-1.0, 1.0]:
			for sv: float in [-1.0, 1.0]:
				var lo := Vector3.ZERO
				lo[axis] = -1.0
				lo[u] = su
				lo[v] = sv
				var hi := lo
				hi[axis] = 1.0
				var out := Vector3.ZERO
				out[u] = su
				out[v] = sv
				quad(tool, centre + turn * point(h, b, lo, u), centre + turn * point(h, b, hi, u), centre + turn * point(h, b, hi, v), centre + turn * point(h, b, lo, v), turn * out)
	# The corners.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var s := Vector3(sx, sy, sz)
				tri(tool, centre + turn * point(h, b, s, 0), centre + turn * point(h, b, s, 1), centre + turn * point(h, b, s, 2), turn * s)

## The corner of a chamfered box on the side `s` (each of x, y, z is -1 or 1)
## where it touches the face square to `axis`.
static func point(h: Vector3, b: float, s: Vector3, axis: int) -> Vector3:
	var p := Vector3(s.x * (h.x - b), s.y * (h.y - b), s.z * (h.z - b))
	p[axis] = s[axis] * h[axis]
	return p

## A cylinder of `radius` and `height` centred at `centre`, its axis up turned
## by `turn`, with `sides` flat sides and both caps.
static func cylinder(parts: Dictionary, key: String, centre: Vector3, radius: float, height: float, sides := 12, turn := Basis.IDENTITY) -> void:
	var tool := tool_for(parts, key)
	var top := Vector3(0.0, height * 0.5, 0.0)
	for k in sides:
		var a0 := TAU * k / sides
		var a1 := TAU * (k + 1) / sides
		var p0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
		var p1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
		quad(tool, centre + turn * (p0 - top), centre + turn * (p1 - top), centre + turn * (p1 + top), centre + turn * (p0 + top), turn * (p0 + p1))
		tri(tool, centre + turn * top, centre + turn * (p0 + top), centre + turn * (p1 + top), turn * Vector3.UP)
		tri(tool, centre - turn * top, centre + turn * (p1 - top), centre + turn * (p0 - top), turn * Vector3.DOWN)

## Turns a cylinder's axis (up) to x.
static func along_x() -> Basis:
	return Basis(Vector3.BACK, -PI / 2)

## Turns a cylinder's axis (up) to z.
static func along_z() -> Basis:
	return Basis(Vector3.RIGHT, PI / 2)

## A bar pull `width` long across x, its back on a front face at `back`: two
## posts and the bar, `depth` proud in all.
static func handle(parts: Dictionary, key: String, back: Vector3, width: float, depth := 0.025) -> void:
	for x: float in [-width * 0.5 + 0.008, width * 0.5 - 0.008]:
		block(parts, key, back + Vector3(x, 0.0, depth * 0.3), Vector3(0.01, 0.01, depth * 0.6))
	block(parts, key, back + Vector3(0.0, 0.0, depth * 0.8), Vector3(width, 0.012, depth * 0.4), 0.003)

## A flat mark of `size` (x, y) centred at `centre`, facing +Z turned by `turn`:
## two triangles, for what is printed or written on a face (a line of text, a
## label, a sheet on a board) where a box's sides would be wasted.
static func stroke(parts: Dictionary, key: String, centre: Vector3, size: Vector2, turn := Basis.IDENTITY) -> void:
	var a := centre + turn * Vector3(-size.x * 0.5, -size.y * 0.5, 0.0)
	var b := centre + turn * Vector3(size.x * 0.5, -size.y * 0.5, 0.0)
	var c := centre + turn * Vector3(size.x * 0.5, size.y * 0.5, 0.0)
	var d := centre + turn * Vector3(-size.x * 0.5, size.y * 0.5, 0.0)
	quad(tool_for(parts, key), a, b, c, d, turn * Vector3.BACK)

## A round knob, its back on a front face at `back`, `depth` proud.
static func knob(parts: Dictionary, key: String, back: Vector3, radius := 0.012, depth := 0.022) -> void:
	cylinder(parts, key, back + Vector3(0.0, 0.0, depth * 0.5), radius, depth, 10, along_z())

## A card holder on a front face at `back`: a brass frame and its paper card.
static func label(parts: Dictionary, back: Vector3, size := Vector2(0.075, 0.03)) -> void:
	block(parts, "gold", back + Vector3(0.0, 0.0, 0.002), Vector3(size.x, size.y, 0.004))
	block(parts, "paper", back + Vector3(0.0, 0.0, 0.0045), Vector3(size.x - 0.01, size.y - 0.008, 0.001))

## A drawer or door front of `size` (x, y) whose back is on the carcass face at
## `back`: `proud` deep, 4 mm short (the shadow line between fronts), its edges
## eased; a pull ("bar", "knob", "grip" or "") `pull_y` from its middle and,
## with `card`, a card holder 45 mm above the pull. Inside FRONT: proud 0.015
## at most with a bar, 0.018 with a knob.
static func front(parts: Dictionary, key: String, back: Vector3, size: Vector2, pull := "bar", pull_key := "metal", pull_y := 0.0, card := false, proud := 0.012) -> void:
	block(parts, key, back + Vector3(0.0, 0.0, proud * 0.5), Vector3(size.x - 0.004, size.y - 0.004, proud), minf(0.004, proud * 0.4))
	var face := back + Vector3(0.0, pull_y, proud)
	match pull:
		"bar": handle(parts, pull_key, face, minf(0.16, size.x * 0.5))
		"knob": knob(parts, pull_key, face)
		"grip": block(parts, "black", face + Vector3(0.0, 0.0, 0.001), Vector3(minf(0.14, size.x * 0.5), 0.02, 0.002))
	if card: label(parts, face + Vector3(0.0, 0.045, 0.0))

## A stack of `count` sheets of `size` (x, z) from `base` (the middle of its
## underside) up to `height`, each a little askew by `pick`.
static func sheets(parts: Dictionary, base: Vector3, size: Vector2, height: float, pick := 0, count := 4) -> void:
	# Each lot of sheets a little askew and off the one under it, a manila
	# folder among them now and then, so the stack shows its edges and is no slab.
	for k in count:
		var n := pick * 53 + k
		var shift := Vector3((hash01(n, 11) - 0.5) * 0.024, height * (k + 0.5) / count, (hash01(n, 12) - 0.5) * 0.024)
		var turn := Basis(Vector3.UP, (hash01(n, 13) - 0.5) * 0.14)
		var key := "paper_manila" if hash01(n, 14) < 0.22 else "paper"
		var grow := 0.008 if key == "paper_manila" else 0.0
		block(parts, key, base + shift, Vector3(size.x + grow, height / count * 0.86, size.y + grow), 0.0, turn)

## Books standing along +x from `origin` (the row's left end, on its shelf,
## centred in depth) over `length`, `depth` deep and up to `tall` high, their
## spines flush to the front (+Z): sets of one to seven volumes of one cloth,
## height and depth, some with a thin band on the spine; the row may end in
## a book leaning on the last one or a few lying
## flat. Widths, heights, cloths and the end by `pick`.
static func book_row(parts: Dictionary, origin: Vector3, length: float, depth: float, tall: float, pick := 0) -> void:
	var roll := hash01(pick, 21)
	var ending := 0
	if roll < 0.3 and length > tall * 0.45 + 0.25: ending = 1
	elif roll < 0.5 and length > tall + 0.25: ending = 2
	var reserve := 0.0
	if ending == 1: reserve = tall * 0.45 + 0.05
	elif ending == 2: reserve = tall * 0.85 + 0.03
	var x := 0.0
	var k := 0
	var run := 0
	var key := ""
	var width := 0.0
	var height := 0.0
	var deep := 0.0
	var marked := 0.0
	while true:
		var n := pick * 131 + k
		if run <= 0:
			run = 1 + int(hash01(n, 1) * hash01(n, 9) * 7.0)
			key = BOOK_KEYS[int(hash01(n, 4) * BOOK_KEYS.size()) % BOOK_KEYS.size()]
			width = 0.022 + hash01(n, 5) * 0.03
			height = tall * (0.66 + hash01(n, 2) * 0.34)
			deep = depth * (0.7 + hash01(n, 3) * 0.3)
			marked = hash01(n, 7)
		if x + width > length - reserve: break
		var c := origin + Vector3(x + width * 0.5, height * 0.5, (depth - deep) * 0.5)
		block(parts, key, c, Vector3(width, height, deep))
		# On the spine, at most a thin band: gilt on a dark cloth, leather on a
		# light one. A label reads as a white square under the lamps.
		if marked < 0.5:
			var light: bool = key in ["cardboard", "plastic_beige"]
			stroke(parts, "leather" if light else "gold", c + Vector3(0.0, height * 0.36, deep * 0.5 + 0.0005), Vector2(width * 0.8, 0.004))
		x += width + 0.001
		k += 1
		run -= 1
	var n_end := pick * 131 + 500
	var end_key: String = BOOK_KEYS[int(hash01(n_end, 4) * BOOK_KEYS.size()) % BOOK_KEYS.size()]
	if ending == 1:
		# Turned about its bottom left edge until its top meets the last book.
		var a := 0.2 + hash01(n_end, 1) * 0.25
		var bw := 0.025 + hash01(n_end, 2) * 0.02
		var bh := tall * (0.75 + hash01(n_end, 3) * 0.2)
		var bd := depth * 0.85
		var left := x + bh * sin(a)
		if left + bw * cos(a) <= length:
			var turn := Basis(Vector3.BACK, a)
			block(parts, end_key, origin + Vector3(left, 0.0, (depth - bd) * 0.5) + turn * Vector3(bw * 0.5, bh * 0.5, 0.0), Vector3(bw, bh, bd), 0.0, turn)
	elif ending == 2:
		var y := 0.0
		var long := tall * 0.8
		for i in 2 + int(hash01(n_end, 5) * 3.0):
			var m := n_end + i
			var thick := 0.025 + hash01(m, 6) * 0.02
			var bd := depth * (0.75 + hash01(m, 3) * 0.1)
			var lie_key: String = BOOK_KEYS[int(hash01(m, 4) * BOOK_KEYS.size()) % BOOK_KEYS.size()]
			# Set back by what the turn swings out of the front.
			var c := origin + Vector3(x + 0.01 + long * 0.5 + (hash01(m, 8) - 0.5) * 0.02, y + thick * 0.5, (depth - bd) * 0.5 - long * 0.03)
			block(parts, lie_key, c, Vector3(long * (0.85 + hash01(m, 2) * 0.15), thick, bd), 0.0, Basis(Vector3.UP, (hash01(m, 1) - 0.5) * 0.1))
			y += thick

## Archive boxes (0.33 wide, 0.25 high, `depth` deep) side by side along +x
## from `origin` (left end, on the shelf, centred in depth) over `length`, a
## place filled when its hash is under `fill`; each with its label and hand
## hole on the side `facing` (1: +Z, -1: -Z), 1 mm proud.
static func box_row(parts: Dictionary, origin: Vector3, length: float, depth: float, fill := 1.0, pick := 0, facing := 1.0) -> void:
	for k in int(length / 0.345):
		if hash01(pick * 97 + k, 5) >= fill: continue
		var c := origin + Vector3(0.0075 + 0.345 * k + 0.165, 0.125, 0.0)
		block(parts, "cardboard", c, Vector3(0.33, 0.25, depth), 0.004)
		block(parts, "paper", c + Vector3(0.0, 0.03, facing * (depth * 0.5 + 0.0005)), Vector3(0.12, 0.07, 0.001))
		block(parts, "black", c + Vector3(0.0, -0.06, facing * (depth * 0.5 + 0.0005)), Vector3(0.07, 0.025, 0.001))

## Ring binders 0.075 wide every 0.08 along +x from `origin` (left end, on the
## shelf, centred in depth) over `length`, `tall` high, their spine label and
## finger ring on the side `facing` (1: +Z, -1: -Z), 2 mm proud; covers by `pick`.
static func binder_row(parts: Dictionary, origin: Vector3, length: float, depth: float, tall := 0.32, pick := 0, facing := 1.0) -> void:
	var turn: Basis = Basis.IDENTITY if facing > 0.0 else Basis(Vector3.UP, PI)
	for k in int(length / 0.08):
		var key: String = BINDER_KEYS[int(hash01(pick * 89 + k, 6) * BINDER_KEYS.size()) % BINDER_KEYS.size()]
		var c := origin + Vector3(0.04 + 0.08 * k, tall * 0.5, 0.0)
		block(parts, key, c, Vector3(0.075, tall, depth))
		# A cream label, not paper white: under the lamps it would burn.
		stroke(parts, "plastic_beige", c + Vector3(0.0, tall * 0.15, facing * (depth * 0.5 + 0.0005)), Vector2(0.045, tall * 0.4), turn)
		cylinder(parts, "metal", c + Vector3(0.0, -tall * 0.3, facing * (depth * 0.5 + 0.001)), 0.012, 0.002, 6, along_z())

## Files along a shelf from `origin` (left end, on the shelf, centred in depth)
## over `length`, `depth` deep and `tall` high at most, flush to the side
## `facing` (1: +Z, -1: -Z), filling 85 to 95 % of it as an archive's shelves
## are: runs of archive boxes spine out (each with its written label and its
## finger hole), runs of ring binders and piles of folders lying flat; by `pick`.
static func file_row(parts: Dictionary, origin: Vector3, length: float, depth: float, tall: float, pick := 0, facing := 1.0) -> void:
	var turn: Basis = Basis.IDENTITY if facing > 0.0 else Basis(Vector3.UP, PI)
	var stop := length * (0.85 + 0.1 * hash01(pick, 30))
	var x := 0.0
	var k := 0
	while x < stop and k < 40:
		var n := pick * 173 + k
		k += 1
		var kind := hash01(n, 31)
		if kind < 0.55:
			var key: String = "cardboard" if hash01(n, 33) < 0.65 else "linen"
			var bh := minf(tall, 0.25 + 0.025 * hash01(n, 34))
			var bd := minf(0.33, depth)
			for i in 2 + int(hash01(n, 32) * 5.0):
				if x + 0.1 > length: break
				var c := origin + Vector3(x + 0.05, bh * 0.5, facing * (depth - bd) * 0.5)
				block(parts, key, c, Vector3(0.098, bh, bd))
				var face := c + Vector3(0.0, 0.0, facing * (bd * 0.5 + 0.0005))
				stroke(parts, "paper", face + Vector3(0.0, bh * 0.2, 0.0), Vector2(0.07, bh * 0.32), turn)
				for line in 3:
					var ink := face + Vector3(-0.005 + 0.01 * hash01(n + i, 35 + line), bh * (0.3 - 0.07 * line), facing * 0.0003)
					stroke(parts, "cloth_navy", ink, Vector2(0.03 + 0.02 * hash01(n + i, 38 + line), 0.004), turn)
				stroke(parts, "black", face + Vector3(0.0, -bh * 0.3, 0.0), Vector2(0.032, 0.026), turn)
				x += 0.1
		elif kind < 0.8:
			var count := mini(3 + int(hash01(n, 35) * 6.0), int((length - x) / 0.08))
			if count <= 0: break
			var bd := minf(0.29, depth)
			binder_row(parts, origin + Vector3(x, 0.0, facing * (depth - bd) * 0.5), count * 0.08, bd, minf(0.32, tall), n, facing)
			x += count * 0.08
		else:
			var wide := 0.25 + 0.04 * hash01(n, 36)
			if x + wide > length: break
			var fd := minf(0.31, depth)
			var y := 0.0
			for i in 3 + int(hash01(n, 37) * 5.0):
				var thick := 0.006 + 0.01 * hash01(n + i, 39)
				if y + thick > minf(tall * 0.6, 0.16): break
				var key: String = "cardboard" if hash01(n + i, 40) < 0.6 else "paper"
				# Swung a little, and set in by what the swing takes.
				var a := (hash01(n + i, 41) - 0.5) * 0.08
				var c := origin + Vector3(x + wide * 0.5, y + thick * 0.5, facing * ((depth - fd) * 0.5 - 0.012))
				block(parts, key, c, Vector3(wide - 0.03, thick, fd - 0.012), 0.0, Basis(Vector3.UP, a))
				y += thick
			x += wide
		x += 0.006

## The post in one pigeonhole from `base` (the middle of its floor): two to
## five envelopes, manila folders and sheets in a loose pile inside `room` (x
## across, y deep, centred on `base`) and up to `high`, pushed to the side
## `facing` (1: +Z, -1: -Z), each swung a little; by `pick`.
static func post_pile(parts: Dictionary, base: Vector3, room: Vector2, high: float, pick := 0, facing := 1.0) -> void:
	var y := 0.0
	for k in 2 + int(hash01(pick, 40) * 4.0):
		var n := pick * 61 + k
		var kind := hash01(n, 41)
		var flat := Vector2(0.22, 0.11)
		if kind > 0.75: flat = Vector2(0.21, 0.297)
		elif kind > 0.5: flat = Vector2(0.24, 0.31)
		var key: String = POST_KEYS[int(hash01(n, 42) * POST_KEYS.size()) % POST_KEYS.size()]
		if kind > 0.5 and kind <= 0.75: key = "cardboard"
		flat = Vector2(minf(flat.x, room.x - 0.02), minf(flat.y, room.y - 0.02))
		var thick := 0.003 + 0.007 * hash01(n, 43)
		# A bundle of envelopes in one block: a fuller cell at no cost.
		if hash01(n, 47) < 0.35: thick = 0.015 + 0.03 * hash01(n, 48)
		if y + thick > high: break
		var a := (hash01(n, 44) - 0.5) * 0.16
		var reach := Vector2(flat.x * cos(a) + flat.y * absf(sin(a)), flat.x * absf(sin(a)) + flat.y * cos(a)) * 0.5
		var slack_x := maxf(0.0, room.x * 0.5 - reach.x)
		var slack_z := maxf(0.0, room.y * 0.5 - reach.y)
		var c := base + Vector3((hash01(n, 45) * 2.0 - 1.0) * slack_x, y + thick * 0.5, facing * slack_z * (1.0 - 0.4 * hash01(n, 46)))
		block(parts, key, c, Vector3(flat.x, thick, flat.y), 0.0, Basis(Vector3.UP, a))
		y += thick

## A number in [0, 1) from `n` and `salt`, the same on every run and machine.
static func hash01(n: int, salt := 0) -> float:
	return fposmod(sin(float(n) * 12.9898 + float(salt) * 78.233) * 43758.5453, 1.0)

## The piece's mesh: one surface per key, in name order, with the builder's
## material and named by its key. `size` bounds it; `collider` is the size's box
## unless given; `meta` adds "wall", "mount", "text_plate", "picture",
## "colliders", "solid" and "light_strip". "solid" false: whoever places it
## spends no StaticBody on it (it lies on something or flat on a wall); its
## collider stays, for measuring. "light_strip" [centre, size]: where the room
## puts a box of glow_strip, not baked because lenses_of() puts out nodes, not
## a surface of a MultiMesh. A text plate's centre stands 1 mm off its face.
static func finish(builder: Node3D, parts: Dictionary, title: String, size: Vector3, meta := {}, collider := AABB()) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var keys: Array = parts.keys()
	keys.sort()
	var triangles := 0
	for key: String in keys:
		var tool: SurfaceTool = parts[key]
		tool.index()
		var arrays := tool.commit_to_arrays()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		triangles += indices.size() / 3
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var surface := mesh.get_surface_count() - 1
		mesh.surface_set_material(surface, material(builder, key))
		mesh.surface_set_name(surface, key)
	var bounds := AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size)
	mesh.resource_name = title
	mesh.set_meta("piece", title)
	mesh.set_meta("size", size)
	mesh.set_meta("collider", collider if collider.has_volume() else bounds)
	mesh.set_meta("triangles", triangles)
	for entry: String in meta: mesh.set_meta(entry, meta[entry])
	return mesh
