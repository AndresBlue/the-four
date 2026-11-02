extends SceneTree
## The offices' pieces made in code (.claude/specs/spec_rediseno.md 5.1, area
## 4a): every sample of game/world/office/pieces/index.gd inside its size and
## filling it, under the 2.2 m rule, on the builder's own materials with no
## wood mapped per batched box, within its triangles and baked once per
## builder; and the kit's faces turned out and wound the way Godot draws them;
## text plates off their faces, light strips inside the size, who has no solid
## body, and a glow_strip box that goes out with its room.
const OG := preload("res://game/world/office/office_geometry.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const KIT := preload("res://game/world/office/pieces/kit.gd")
const INDEX := preload("res://game/world/office/pieces/index.gd")
const DESKS := preload("res://game/world/office/pieces/desks.gd")
const CABINETS := preload("res://game/world/office/pieces/cabinets.gd")
const STORAGE := preload("res://game/world/office/pieces/storage.gd")
const STATIONERY := preload("res://game/world/office/pieces/stationery.gd")
## Area 5's pieces at the sizes their handlers place them at (power_objective,
## files_objective, office_geometry), not only at their samples'.
const EQ_MAIL := preload("res://game/world/office/pieces/mail_equipment.gd")
const EQ_POWER := preload("res://game/world/office/pieces/power_equipment.gd")
const EQ_DESKS := preload("res://game/world/office/pieces/desks.gd")
## The samples the families give (area 4a U2 to U9, area 5 U2 to U4: 10, 6 and 5).
const PIECES := 88
## The pieces' own materials (kit.gd, area 4a U1).
const OWN := ["paper", "laminate_light", "plastic_beige", "steel_mint", "steel_grey", "steel_dark", "cloth_red", "cloth_green", "cloth_navy"]
## Woods mapped per batched box (no object_space): wrong on a baked mesh.
const WORLD_WOOD := ["walnut", "veneer", "wood", "trim", "panel", "dado_oak", "laminate"]
## Triangles at most (spec_rediseno 5.1): a small piece, any other.
const SMALL_TRIANGLES := 5000
const BIG_TRIANGLES := 20000
## How much of its size a piece's mesh spans at least, across and up: a
## recipe that drew half of it would pass the bounds alone.
const FILL := 0.75
## The pieces whose one box would fill an open corner: two colliders instead.
const TWO_BOXES := ["desk_l", "desk_l_walnut", "reception_counter"]
## What lies on something or flat on a wall: no StaticBody ("solid" false).
const NOT_SOLID := ["rug_carpet_exec", "rug_black", "curtain", "blind", "keyboard", "calculator", "crt_plastic_beige", "crt_black", "dot_matrix_printer", "paper_stack", "folders", "tray", "tray_wire", "register_book", "books", "binders", "sign_plate", "picture_walnut_object", "picture_black", "clock_square", "mirror", "directory_board", "notice_board", "key_cabinet", "coat_hook_rail", "roll_screen"]
## The pieces that leave their light to the room ("light_strip").
const STRIPS := ["reception_counter", "kitchen_wall"]
## How far a text plate's centre stands off its face, at least and at most.
const PROUD := 0.0005
const PROUD_MOST := 0.005
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	var builder = OG.new()
	check("KIT.TOP es FURNITURE_TOP", is_equal_approx(KIT.TOP, OFFICE.FURNITURE_TOP))
	check_kit()
	var began := Time.get_ticks_usec()
	var first: Array = INDEX.samples(builder)
	var bake_ms := float(Time.get_ticks_usec() - began) / 1000.0
	check("Las %d familias dan sus %d piezas" % [INDEX.FAMILIES.size(), PIECES], first.size() == PIECES, str(first.size()))
	var names := {}
	for entry: Array in first:
		var title: String = entry[0]
		check(title + " tiene un nombre que no se repite", not names.has(title))
		names[title] = true
		check_piece(builder, title, entry[1])
	# What the handlers place at other sizes than the samples' (area 5): the
	# board with one to seven zones, the narrowest map, low and high conduits,
	# the window's and the security post's desks.
	for zones in range(1, 8): check_piece(builder, "power_board_%d" % zones, EQ_POWER.power_board(builder, EQ_POWER.BOARD, zones))
	check_piece(builder, "network_map", EQ_MAIL.network_map(builder, Vector3(0.42, 0.62, 0.025)))
	for high: float in [0.25, 0.54]: check_piece(builder, "board_conduits", EQ_POWER.board_conduits(builder, Vector3(2.6, high, EQ_POWER.CONDUITS_DEPTH)))
	for wide: float in [1.2, 1.8]: check_piece(builder, "desk_steel", EQ_DESKS.desk_steel(builder, Vector3(wide, 0.755, 0.45)))
	var again: Array = INDEX.samples(builder)
	var same: bool = again.size() == first.size()
	for i in mini(again.size(), first.size()):
		if not is_same(again[i][1], first[i][1]): same = false
	check("Cada pieza se hornea una vez por constructor", same)
	var narrow: ArrayMesh = DESKS.dining_table(builder, Vector3(1.2, 0.74, 0.8))
	var wide: ArrayMesh = DESKS.dining_table(builder, Vector3(1.4, 0.74, 0.8))
	var wide_size: Vector3 = wide.get_meta("size")
	check("Otra medida es otra malla, con su medida", not is_same(narrow, wide) and is_equal_approx(wide_size.x, 1.4))
	check_variants(builder)
	var waiting: ArrayMesh = DESKS.low_table(builder, Vector3(0.9, 0.42, 0.5), "laminate_light")
	check_piece(builder, "low_table", waiting)
	check("low_table en laminado es otra malla, en laminate_light", not is_same(waiting, DESKS.low_table(builder, Vector3(0.9, 0.42, 0.5))) and waiting.surface_get_name(0) == "laminate_light")
	check_glow_strip(builder)
	for key: String in OWN:
		var made = builder.materials.get(key)
		check(key + " es material propio de la oficina, con su lite", made is ShaderMaterial and String(made.get_meta("lite", "")) == "office/" + key and not made.has_meta("stand_in"))
	print("OFFICE_PIECES_BAKE_MS %.1f" % bake_ms)
	var file := FileAccess.open("res://evidence/office_pieces_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks, "bake_ms": bake_ms}, "\t"))
	print("OFFICE_PIECES_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	builder.free()
	quit(1 if failed > 0 else 0)

## The kit's shapes (kit.gd): their triangles, each facing out from the
## shape's middle and wound clockwise seen from the front (Godot's front face).
func check_kit() -> void:
	var shapes := {"bloque": [KIT.begin(), 12], "bloque biselado": [KIT.begin(), 44], "bloque girado": [KIT.begin(), 44], "cilindro": [KIT.begin(), 48]}
	KIT.block(shapes["bloque"][0], "metal", Vector3(0, 0.5, 0), Vector3(1.0, 0.6, 0.8))
	KIT.block(shapes["bloque biselado"][0], "metal", Vector3(0, 0.5, 0), Vector3(1.0, 0.6, 0.8), 0.1)
	KIT.block(shapes["bloque girado"][0], "metal", Vector3(0, 0.5, 0), Vector3(1.0, 0.6, 0.8), 0.05, Basis(Vector3.UP, 0.7))
	KIT.cylinder(shapes["cilindro"][0], "metal", Vector3(0, 0.5, 0), 0.3, 0.6, 12, KIT.along_x())
	for title: String in shapes:
		var tool: SurfaceTool = shapes[title][0]["metal"]
		var arrays := tool.commit_to_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var outward := true
		var clockwise := true
		for t in range(0, vertices.size(), 3):
			var a := vertices[t]
			var b := vertices[t + 1]
			var c := vertices[t + 2]
			if normals[t].dot((a + b + c) / 3.0 - Vector3(0, 0.5, 0)) <= 0.0: outward = false
			if (b - a).cross(c - a).dot(normals[t]) >= 0.0: clockwise = false
		var expected: int = shapes[title][1]
		check("El %s del kit tiene %d triángulos" % [title, expected], vertices.size() / 3 == expected, str(vertices.size() / 3))
		check("El %s del kit mira hacia fuera" % title, outward)
		check("El %s del kit gira como Godot dibuja el frente" % title, clockwise)

## The pieces with contents: three variants under one title, each its own
## mesh with other contents and each a sound piece.
func check_variants(builder) -> void:
	var makers := {
		"archive_shelving": func(v: int) -> ArrayMesh: return STORAGE.archive_shelving(builder, Vector3(2.0, 2.1, 0.4), v),
		"mobile_archive": func(v: int) -> ArrayMesh: return STORAGE.mobile_archive(builder, Vector3(3.0, 2.1, 0.8), v),
		"wood_shelving": func(v: int) -> ArrayMesh: return STORAGE.wood_shelving(builder, Vector3(1.2, 1.8, 0.4), v),
		"bookcase": func(v: int) -> ArrayMesh: return CABINETS.bookcase(builder, Vector3(0.9, 2.0, 0.35), true, v),
		"pigeonholes": func(v: int) -> ArrayMesh: return CABINETS.pigeonholes(builder, Vector3(1.8, 1.9, 0.4), v),
		"pigeon_counter": func(v: int) -> ArrayMesh: return CABINETS.pigeon_counter(builder, Vector3(2.4, 1.1, 0.8), v),
		"binders": func(v: int) -> ArrayMesh: return STATIONERY.binders(builder, Vector3(0.4, 0.32, 0.29), v),
	}
	for title: String in makers:
		var make: Callable = makers[title]
		var first: ArrayMesh = make.call(0)
		var other_contents := true
		for v: int in [1, 2]:
			var other: ArrayMesh = make.call(v)
			check_piece(builder, title, other)
			if is_same(other, first) or other.get_faces() == first.get_faces(): other_contents = false
		check(title + " da tres variantes de contenido distinto", other_contents)

## A sample: its name, size, collider and triangles; inside its size and
## filling it; its text and picture spots inside it; under the 2.2 m rule; on
## the builder's materials, no wood of the batches and no stand-in; within its
## triangles.
func check_piece(builder, title: String, mesh: ArrayMesh) -> void:
	var tagged: bool = mesh != null and mesh.resource_name == title and String(mesh.get_meta("piece", "")) == title and mesh.has_meta("size") and mesh.has_meta("collider") and mesh.has_meta("triangles")
	check(title + " lleva su nombre, su medida, su colisionador y sus triángulos", tagged)
	if not tagged: return
	var size: Vector3 = mesh.get_meta("size")
	var bounds := AABB(Vector3(-size.x * 0.5, 0.0, -size.z * 0.5), size).grow(0.002)
	var box := mesh.get_aabb()
	check(title + " cabe en su medida", bounds.encloses(box), "%s en %s" % [box, size])
	check(title + " llena su medida", box.size.x >= size.x * FILL and box.size.y >= size.y * FILL, "%s en %s" % [box.size, size])
	var collider: AABB = mesh.get_meta("collider")
	check(title + " tiene el colisionador dentro de su medida", collider.has_volume() and bounds.encloses(collider), str(collider))
	for part: AABB in mesh.get_meta("colliders", []):
		check(title + " tiene sus colisionadores dentro de su medida", part.has_volume() and bounds.encloses(part), str(part))
	if title in TWO_BOXES: check(title + " lleva sus dos colisionadores", mesh.get_meta("colliders", []).size() == 2)
	var solid: bool = mesh.get_meta("solid", true)
	check(title + (" no pide cuerpo sólido" if title in NOT_SOLID else " pide su cuerpo sólido"), solid != (title in NOT_SOLID))
	check(title + (" deja su tira a la sala" if title in STRIPS else " no lleva tira"), mesh.has_meta("light_strip") == (title in STRIPS))
	if mesh.has_meta("light_strip"):
		var strip: Array = mesh.get_meta("light_strip")
		var strip_size: Vector3 = strip[1]
		var strip_box := AABB((strip[0] as Vector3) - strip_size * 0.5, strip_size)
		check(title + " tiene su light_strip dentro de su medida", strip_box.has_volume() and bounds.encloses(strip_box), str(strip))
	for spot_key: String in ["text_plate", "picture"]:
		if not mesh.has_meta(spot_key): continue
		var spot: Array = mesh.get_meta(spot_key)
		var spot_centre: Vector3 = spot[0]
		var facing: Vector3 = spot[2]
		check(title + " tiene su " + spot_key + " dentro de su medida", bounds.has_point(spot_centre) and is_equal_approx(facing.length(), 1.0), str(spot))
		if spot_key == "text_plate":
			var proud := clearance(mesh, spot_centre, facing)
			check(title + " tiene el texto despegado de su cara", proud >= PROUD and proud <= PROUD_MOST, "%.5f" % proud)
	var wall: bool = mesh.get_meta("wall", false)
	var mount: float = mesh.get_meta("mount", 0.0)
	var under: bool = size.y <= KIT.TOP + 0.001
	if wall: under = size.z <= KIT.FLAT + 0.001 or mount + size.y <= KIT.TOP + 0.001
	check(title + " respeta los 2,2 m", under, "%s, pared %s a %.2f" % [size, wall, mount])
	var bad: Array = []
	for s in mesh.get_surface_count():
		var key := mesh.surface_get_name(s)
		var used := mesh.surface_get_material(s)
		if used == null or not is_same(used, builder.materials.get(key)): bad.append(key + ": no es el del constructor")
		elif key in WORLD_WOOD: bad.append(key + ": madera de los lotes")
		elif used.has_meta("stand_in"): bad.append(key + ": sustituto")
	check(title + " usa los materiales del constructor, sin madera de los lotes ni sustitutos", bad.is_empty(), str(bad))
	var triangles: int = mesh.get_meta("triangles")
	var small: bool = size.y < 0.6 and maxf(size.x, size.z) < 0.8
	check(title + " cabe en su presupuesto de triángulos", triangles > 0 and triangles < (SMALL_TRIANGLES if small else BIG_TRIANGLES), str(triangles))

## How far a spot stands off the piece's geometry along its normal: the least
## over every face a ray through it crosses, negative if a face is in front of
## it, INF over none. The ray goes 3 mm aside, off the diagonal of the quad
## centred on the spot, where it could slip between the two triangles.
func clearance(mesh: ArrayMesh, centre: Vector3, facing: Vector3) -> float:
	var faces := mesh.get_faces()
	var spot := centre + facing.cross(Vector3(0.3, 0.5, 0.7)).normalized() * 0.003
	var least := INF
	for t in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(spot + facing * 10.0, -facing, faces[t], faces[t + 1], faces[t + 2])
		if hit is Vector3: least = minf(least, (spot - (hit as Vector3)).dot(facing))
	return least

## The strip the pieces leave to whoever places them ("light_strip"): warm, its
## own material, and a box of it is a Mesh_glow_* node that goes out with its room.
func check_glow_strip(builder) -> void:
	var strip = builder.materials.get("glow_strip")
	var warm: bool = strip is StandardMaterial3D and strip.emission_enabled and strip.emission.r > strip.emission.g and strip.emission.g > strip.emission.b and strip.emission.b < 0.8
	check("glow_strip es material propio de la oficina, emisivo y cálido", warm and not strip.has_meta("stand_in") and String(strip.get_meta("lite", "")) == "office/glow_strip", str(strip))
	check("glow_strip brilla apagado", strip is StandardMaterial3D and strip.emission_energy_multiplier <= 1.0)
	var room := Node3D.new()
	builder.room_nodes.append(room)
	builder.box(room, Vector3.ZERO, Vector3(1.0, 0.012, 0.03), "glow_strip")
	builder.flush()
	var found: Array = builder.lenses_of(0)
	var named: bool = found.size() == 1 and String(found[0].name).begins_with("Mesh_glow_")
	check("Una caja de glow_strip es un nodo Mesh_glow_* que lenses_of() encuentra", named, str(found))
	if named:
		builder.glow_room(0, false)
		check("La caja de glow_strip se apaga con su sala", found[0].material_override == builder.materials.lens_off)
		builder.glow_room(0, true)
		check("La caja de glow_strip vuelve a encenderse con su sala", found[0].material_override == null)
	check("La caja de glow_strip no rebota", not builder.bounces("glow_strip"))
	builder.room_nodes.clear()
	room.free()
