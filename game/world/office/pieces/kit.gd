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
## Spines of books and binders (book_row(), binder_row()).
const BOOK_KEYS := ["cloth_red", "cloth_green", "cloth_navy", "cardboard", "black"]
const BINDER_KEYS := ["black", "black", "cloth_navy", "cloth_green", "plastic_beige"]
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
	for k in count:
		var shift := Vector3((hash01(pick * 53 + k, 11) - 0.5) * 0.012, height * (k + 0.5) / count, (hash01(pick * 53 + k, 12) - 0.5) * 0.012)
		block(parts, "paper", base + shift, Vector3(size.x, height / count, size.y))

## Books standing along +x from `origin` (the row's left end, on its shelf,
## centred in depth) over `length`, `depth` deep and up to `tall` high, their
## spines flush to the front (+Z); widths, heights and cloths by `pick`.
static func book_row(parts: Dictionary, origin: Vector3, length: float, depth: float, tall: float, pick := 0) -> void:
	var x := 0.0
	var k := 0
	while true:
		var n := pick * 131 + k
		var width := 0.02 + hash01(n, 1) * 0.035
		if x + width > length: break
		var height := tall * (0.72 + hash01(n, 2) * 0.28)
		var deep := depth * (0.8 + hash01(n, 3) * 0.2)
		var key: String = BOOK_KEYS[int(hash01(n, 4) * BOOK_KEYS.size()) % BOOK_KEYS.size()]
		block(parts, key, origin + Vector3(x + width * 0.5, height * 0.5, (depth - deep) * 0.5), Vector3(width, height, deep), 0.002)
		x += width + 0.002
		k += 1

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
## finger ring on +Z (2 mm proud); covers by `pick`.
static func binder_row(parts: Dictionary, origin: Vector3, length: float, depth: float, tall := 0.32, pick := 0) -> void:
	for k in int(length / 0.08):
		var key: String = BINDER_KEYS[int(hash01(pick * 89 + k, 6) * BINDER_KEYS.size()) % BINDER_KEYS.size()]
		var c := origin + Vector3(0.04 + 0.08 * k, tall * 0.5, 0.0)
		block(parts, key, c, Vector3(0.075, tall, depth), 0.003)
		block(parts, "paper", c + Vector3(0.0, tall * 0.15, depth * 0.5 + 0.0005), Vector3(0.045, tall * 0.4, 0.001))
		cylinder(parts, "metal", c + Vector3(0.0, -tall * 0.3, depth * 0.5 + 0.001), 0.012, 0.002, 8, along_z())

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
