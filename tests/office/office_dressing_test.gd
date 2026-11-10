extends SceneTree
## Area 4c (spec_rediseno 5, 6 and 7), floor 2, seed 7: every kind of the map
## with its model or stand-in, the office's own models within their
## triangles, the meeting tables' chairs facing them, what hangs on the walls
## clear of doors, glass and each other and under the 2.2 m rule, most rooms
## and corridors dressed, nothing on the ceiling where a troffer or she is, a
## smoke detector in every false ceiling with troffers, Dirección's floor seen
## polished round its rug and still carpet to the ear, none of the hotel's wall
## dressing nor a fuse box left, three accents at most to a room, the washroom's wet end
## tiled, the mail room's central, no text with a middle dot or a long dash,
## and the secretary's tops on its L. OFFICE_DRESSING_RESULT n/n.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
const MODELS := preload("res://game/world/office/office_models.gd")
const DESKS := preload("res://game/world/office/pieces/desks.gd")
const KIT := preload("res://game/world/office/pieces/kit.gd")
const CLUTTER := preload("res://game/world/office/office_clutter.gd")
## The office's own downloads (tools/props/build_catalogue.gd, area 4c U1).
const OWN := ["sofa_02", "mid_century_lounge_chair", "potted_plant_01", "pachira_aquatica_01_c", "pachira_aquatica_01_d", "calathea_orbifolia_01_a", "calathea_orbifolia_01_c", "anthurium_botany_01_a", "anthurium_botany_01_c"]
## The kinds that are only a stand-in (office_models.stand_in()).
const STAND_ONLY := ["desk_lamp_banker", "desk_lamp_arm", "floor_lamp", "vending", "cooler", "fridge", "coffee_maker", "microwave", "globe", "extinguisher", "work_light", "step_ladder", "phone", "phone_off", "typewriter", "microfiche", "mug", "ashtray", "pen_cup", "paper_scatter", "cable", "crt", "keyboard", "tray", "tray_wire", "folders", "paper_stack", "binders", "archive_box", "register"]
const SMALL_TRIANGLES := 5000
const BIG_TRIANGLES := 20000
var checks := 0
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks += 1
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

func run() -> void:
	var heavy: Array = []
	for slug: String in OWN:
		var path := "res://assets/props/office/%s.res" % slug
		if not ResourceLoader.exists(path):
			heavy.append(slug + " no está")
			continue
		var mesh: Mesh = load(path)
		var triangles := 0
		for s in mesh.get_surface_count():
			var indices: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
			triangles += indices.size() / 3
		var size := mesh.get_aabb().size
		var small := size.y < 0.6 and maxf(size.x, size.z) < 0.8
		if triangles >= (SMALL_TRIANGLES if small else BIG_TRIANGLES): heavy.append("%s %d" % [slug, triangles])
	check("Los modelos de la oficina están horneados y caben en su presupuesto de triángulos", heavy.is_empty(), str(heavy))
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "none"
	level.set_floor(2)
	await level.start_floor(7, false, [1], "apacible", 2)
	var hotel = level.hotel
	var missing: Array = []
	for kind in MODELS.MODELS.keys() + STAND_ONLY:
		if MODELS.mesh_of(hotel, String(kind)) == null: missing.append(kind)
	check("Cada tipo del mapa tiene su modelo o su reserva", missing.is_empty(), str(missing))
	var rooms: Array = hotel.manifest.rooms
	var notes: Dictionary = hotel.dressing_log
	chairs_face_tables(rooms, notes)
	walls_clear(rooms, notes)
	walls_dressed(rooms, notes)
	ceilings(rooms, notes)
	floors_and_leftovers(hotel, rooms)
	var most := 0
	var spots := 0
	for room_id in hotel.accents.rooms:
		most = maxi(most, hotel.accents.of_room(int(room_id)).size())
		for entry: Dictionary in hotel.accents.of_room(int(room_id)):
			if int(entry.sconce) < 0: spots += 1
	check("Como mucho tres acentos por sala, y hay flexos y lámparas", most <= 3 and spots > 0, "%d como mucho, %d focos" % [most, spots])
	var centrals: int = notes.walls.filter(func(e: Dictionary) -> bool: return String(e.kind) == "central").size()
	check("El correo tiene su central neumática de adorno", centrals > 0)
	var bad_text: Array = []
	for label: Label3D in hotel.find_children("*", "Label3D", true, false):
		if label.text.contains("·") or label.text.contains("—"): bad_text.append(label.text)
	check("Ningún rótulo lleva «·» ni «—»", bad_text.is_empty(), str(bad_text))
	clutter_checks(hotel, rooms, notes)
	secretary_tops(hotel)
	print("OFFICE_DRESSING_RESULT ", checks - failed, "/", checks)
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)

## The meeting tables' chairs face the table (office_props.build_item()), as
## drawn: the table's top stands at its holder's local -Z (table_z); a
## near-side chair (table_chair) is held apart, so its room's table is brought
## into its holder. Each holder stands where extras() put it (it is freed once
## its room is batched). One standing chair turned away a room at most (tramo
## B's odd thing); a fallen one does not count.
func chairs_face_tables(rooms: Array, notes: Dictionary) -> void:
	var tables := {}
	var table_at := {}
	var near: Array = []
	for room: Dictionary in rooms:
		if FLOOR.is_void(room): continue
		var items: Array = room.get("furniture", [])
		for k in items.size():
			var kind := String(items[k].kind)
			var key := "%d:Furniture_%d" % [int(room.id), k]
			var place := Transform3D(Basis(Vector3.UP, int(items[k].turn) * PI / 2), Vector3(float(items[k].at[0]), 0, float(items[k].at[1])))
			if kind in OFFICE.TABLE_KINDS:
				var top := Vector3(0, 0, -float(items[k].size[1]) * 0.5 + 0.6)
				tables[key] = [top, int(room.id)]
				table_at[int(room.id)] = place * top
			elif kind == "table_chair": near.append([key, place, int(room.id)])
	for pair: Array in near:
		var place: Transform3D = pair[1]
		if table_at.has(int(pair[2])): tables[pair[0]] = [place.affine_inverse() * (table_at[int(pair[2])] as Vector3), int(pair[2])]
	var chairs := 0
	var wrong := {}
	for entry: Dictionary in notes.chairs:
		var key := "%d:%s" % [int(entry.room), String(entry.holder)]
		if not tables.has(key): continue
		var front: Vector3 = entry.front
		if absf(front.y) > 0.5: continue
		chairs += 1
		var table: Array = tables[key]
		var to_table: Vector3 = (table[0] as Vector3) - (entry.at as Vector3)
		if front.dot(to_table) <= 0.0: wrong[int(table[1])] = int(wrong.get(int(table[1]), 0)) + 1
	var worst := 0
	for n in wrong.values(): worst = maxi(worst, int(n))
	check("Las sillas de las mesas de juntas miran a la mesa", chairs > 0 and worst <= 1, "%d sillas, hasta %d del revés en una sala" % [chairs, worst])

## What hangs on the walls: not on glass nor an open side, not over a door
## (below its head), under the 2.2 m rule unless flat, never over another.
func walls_clear(rooms: Array, notes: Dictionary) -> void:
	var bad: Array = []
	var by_wall := {}
	for entry: Dictionary in notes.walls:
		var room: Dictionary = rooms[int(entry.room)]
		var side := String(entry.side)
		var tag := "%d %s %s" % [int(entry.room), side, String(entry.kind)]
		if room.get("glazed", []).has(side) or room.get("open_sides", []).has(side): bad.append(tag + " en cristal o abierto")
		if float(entry.high) > OFFICE.FURNITURE_TOP + 0.001 and float(entry.depth) > 0.2: bad.append(tag + " pasa de 2,2 m")
		for way in FLOOR.doorways(room):
			if String(way.wall) != side: continue
			var x: float = -float(way.along) if side == "west" or side == "east" else float(way.along)
			if float(entry.from) < x + FLOOR.PORTAL * 0.5 + 0.09 and float(entry.to) > x - FLOOR.PORTAL * 0.5 - 0.09 and float(entry.low) < 2.65: bad.append(tag + " sobre una puerta")
		var key := "%d:%s" % [int(entry.room), side]
		if not by_wall.has(key): by_wall[key] = []
		for other: Dictionary in by_wall[key]:
			if float(entry.from) < float(other.to) and float(entry.to) > float(other.from) and float(entry.low) < float(other.high) and float(entry.high) > float(other.low): bad.append(tag + " pisa " + String(other.kind))
		by_wall[key].append(entry)
	check("Lo colgado no va en cristal ni sobre una puerta, no se pisa y cumple los 2,2 m", bad.is_empty(), str(bad.slice(0, 8)))

## Most rooms with a list have something on their walls (the washroom's tiles
## do not count), most corridor cells their fittings.
func walls_dressed(rooms: Array, notes: Dictionary) -> void:
	var dressed := {}
	for entry: Dictionary in notes.walls:
		if String(entry.kind) != "tiles": dressed[int(entry.room)] = true
	var want := 0
	var have := 0
	var halls := 0
	var hung := 0
	for room: Dictionary in rooms:
		if FLOOR.is_void(room): continue
		var t := int(room.type)
		if OFFICE.WALL_DRESSING.has(t):
			want += 1
			if dressed.has(int(room.id)): have += 1
		if t == OFFICE.CORRIDOR:
			halls += 1
			if dressed.has(int(room.id)): hung += 1
	check("Seis de cada diez salas con lista tienen algo colgado", want > 0 and have * 10 >= want * 6, "%d de %d" % [have, want])
	check("Seis de cada diez celdas de pasillo tienen su mobiliario", halls > 0 and hung * 10 >= halls * 6, "%d de %d" % [hung, halls])

## Nothing on a troffer's tile nor on one of hers (free_tiles()); a detector
## in nineteen of every twenty rooms with a false ceiling and troffers.
func ceilings(rooms: Array, notes: Dictionary) -> void:
	var bad: Array = []
	var detectors := {}
	for entry: Dictionary in notes.ceiling:
		var room: Dictionary = rooms[int(entry.room)]
		var tile: Vector2i = entry.tile
		var lamp_tiles := {}
		for lamp in OFFICE.troffers(room):
			for other in lamp.tiles: lamp_tiles[other] = true
		if lamp_tiles.has(tile) or OFFICE.free_tiles(room).has(tile): bad.append("%d %s" % [int(entry.room), str(tile)])
		if String(entry.what) == "detector": detectors[int(entry.room)] = true
	check("Nada en el techo sobre una pantalla ni en una placa de ella", bad.is_empty(), str(bad.slice(0, 8)))
	var want := 0
	var have := 0
	for room: Dictionary in rooms:
		if FLOOR.is_void(room) or not OFFICE.false_ceiling(room) or OFFICE.troffers(room).is_empty(): continue
		want += 1
		if detectors.has(int(room.id)): have += 1
	check("Las salas con falso techo y pantallas tienen su detector de humo", want > 0 and have * 20 >= want * 19, "%d de %d" % [have, want])

## Dirección's floor, the hotel's wall dressing and fuse boxes gone, the washroom tiled.
func floors_and_leftovers(hotel, rooms: Array) -> void:
	var soft := 0
	var wrong: Array = []
	var stretches := 0
	var toilets := 0
	var tiled := 0
	for room: Dictionary in rooms:
		if FLOOR.is_void(room): continue
		var node: Node3D = hotel.room_nodes[int(room.id)]
		if not is_instance_valid(node): continue
		# Asked of the floor: the Stretch_ holders are freed once their room is batched.
		stretches += hotel.wall_stretches(room).size()
		var look := OFFICE.rug_of(room)
		if look == "persian" or look == "plain":
			soft += 1
			if node.find_children("Mesh_vinyl*", "", true, false).is_empty() or node.find_children("Model_rug*", "", true, false).is_empty() or OFFICE.hard_floor(room): wrong.append(int(room.id))
		var t := int(room.type)
		if t == OFFICE.TOILETS and room.get("furniture", []).any(func(item: Dictionary) -> bool: return String(item.kind) == "cubicles"):
			toilets += 1
			if not node.find_children("Mesh_wet_tile*", "", true, false).is_empty(): tiled += 1
	check("Dirección: vinilo a la vista con su alfombra encima, y suena a moqueta", soft > 0 and wrong.is_empty(), "%d salas, mal: %s" % [soft, str(wrong)])
	check("Ninguna sala lleva los tramos de pared del hotel, y el piso no tiene cuadros de fusibles", stretches == 0 and hotel.panels.is_empty(), "%d tramos, %d cuadros" % [stretches, hotel.panels.size()])
	check("Los aseos con cabinas tienen su zona húmeda alicatada", toilets > 0 and tiled == toilets, "%d de %d" % [tiled, toilets])

## Tramo B (office_clutter.gd): things on the desks, no paper on the card's
## way (paper_clear(), worked out here), one odd thing at most to a room, the
## corridors' floor clear, and planta 3 left worse than planta 1: chairs
## fallen or turned away and drawers out, among chairs and filing cabinets.
func clutter_checks(hotel, rooms: Array, notes: Dictionary) -> void:
	var on_tops := 0
	var near: Array = []
	var odd := {}
	var hall_floor := 0
	var bad: Array = [0, 0, 0]
	var all: Array = [0, 0, 0]
	var spots: Array = []
	LAYOUT.gather(hotel.manifest.get("mail", {}), spots)
	for exit in hotel.manifest.get("tubes", {}).get("exits", []):
		if exit is Dictionary and exit.has("point"): spots.append(exit)
	for entry: Dictionary in notes.clutter:
		var room: Dictionary = rooms[int(entry.room)]
		var t := int(room.type)
		var kind := String(entry.kind)
		if kind in ["phone", "phone_off", "crt", "tray", "mug", "typewriter"]: on_tops += 1
		if bool(entry.paper) and not paper_clear(rooms, room, entry.at, spots): near.append("%d %s" % [int(entry.room), kind])
		if bool(entry.odd): odd[int(entry.room)] = int(odd.get(int(entry.room), 0)) + 1
		if bool(entry.floor) and (t == OFFICE.CORRIDOR or t == OFFICE.GALLERY): hall_floor += 1
		var planta := clampi(int(room.get("wing", 0)), 0, 2)
		if kind in ["chair_fallen", "chair_odd", "drawer"]: bad[planta] = int(bad[planta]) + 1
		if kind.begins_with("chair_") or kind == "drawer" or kind == "filing_shut": all[planta] = int(all[planta]) + 1
	check("Hay teléfonos, pantallas, bandejas y tazas encima de las mesas", on_tops > 0, str(on_tops))
	check("Ningún papel del suelo en la ruta de la ficha ni a menos de 2 m de una puerta, un lado abierto o la recta entre dos accesos", near.is_empty(), str(near.slice(0, 8)))
	check("Como mucho un detalle raro por sala", odd.values().all(func(n) -> bool: return int(n) <= 1), str(odd))
	check("Nada en el suelo de los pasillos", hall_floor == 0, str(hall_floor))
	var first: float = float(bad[0]) / maxf(float(all[0]), 1.0)
	var third: float = float(bad[2]) / maxf(float(all[2]), 1.0)
	check("La planta 3 está más abandonada que la 1", int(all[0]) > 0 and int(all[2]) > 0 and third > first, "%.2f frente a %.2f" % [third, first])

## Whether a paper lies clear of the card's way, worked out here and not by
## office_clutter.gd: not in a room it crosses for certain (circulation,
## corridors, the refuge, the window, a room or nave with a mail or tube spot)
## and 2 m or more from each of its doorways, its open sides (all their length)
## and the straight way between two of them.
func paper_clear(rooms: Array, room: Dictionary, at: Vector3, spots: Array) -> bool:
	var t := int(room.type)
	if t in OFFICE.CIRCULATION or t == OFFICE.CORRIDOR or t == OFFICE.REFUGE or t == OFFICE.WINDOW: return false
	var hall := int(room.get("hall", -1))
	for spot: Dictionary in spots:
		var p: Array = spot.point
		var here := FLOOR.room_at(rooms, Vector3(float(p[0]), float(p[1]), float(p[2])))
		if here.is_empty(): continue
		if int(here.id) == int(room.id) or (hall >= 0 and int(here.get("hall", -1)) == hall): return false
	var centre := FLOOR.position_of(room)
	var local := Vector2(at.x - centre.x, at.z - centre.z)
	var span := FLOOR.size_of(room)
	var ways: Array = []
	for way in FLOOR.doorways(room):
		var wall := String(way.wall)
		var face := LAYOUT.face(room, wall)
		ways.append(Vector2(face, float(way.along)) if wall == "west" or wall == "east" else Vector2(float(way.along), face))
	for side in room.get("open_sides", []):
		var wall := String(side)
		var face := LAYOUT.face(room, wall)
		var across := wall == "west" or wall == "east"
		var a: Vector2 = Vector2(face, -span.y * 0.5) if across else Vector2(-span.x * 0.5, face)
		var b: Vector2 = Vector2(face, span.y * 0.5) if across else Vector2(span.x * 0.5, face)
		if Geometry2D.get_closest_point_to_segment(local, a, b).distance_to(local) < 2.0: return false
		ways.append((a + b) * 0.5)
	for i in ways.size():
		var a: Vector2 = ways[i]
		if local.distance_to(a) < 2.0: return false
		for j in range(i + 1, ways.size()):
			if Geometry2D.get_closest_point_to_segment(local, a, ways[j]).distance_to(local) < 2.0: return false
	return true

## The secretary's tops (office_clutter.TOPS, off by tops_shift()) each stand
## on one of the L's two runs: make_desk_l()'s colliders, sized and set as
## office_props.build_item() lays the L (spec_4e_b G). The floor drew the L at
## that size: its builder's piece cache (kit.cached()) holds it.
func secretary_tops(hotel) -> void:
	var size: Vector2 = OFFICE.FURNITURE["secretary_desk"].size
	var board := Vector3(size.x - 0.1, 0.75, size.y - 0.7)
	var drawn: bool = (hotel.get_meta("office_pieces", {}) as Dictionary).has(KIT.key_of("desk_l_walnut", board))
	var boxes: Array = DESKS.desk_l_walnut(hotel, board).get_meta("colliders")
	var shift: Vector3 = CLUTTER.tops_shift("secretary_desk", {"size": [size.x, size.y]})
	var loose: Array = []
	for thing: Array in CLUTTER.TOPS["secretary_desk"]:
		var at: Vector3 = (thing[1] as Vector3) + shift
		var held := false
		for box: AABB in boxes:
			var top := Rect2(box.position.x, box.position.z - 0.35, box.size.x, box.size.z).grow(-0.05)
			if top.has_point(Vector2(at.x, at.z)) and absf(at.y - box.end.y) < 0.01: held = true
		if not held: loose.append(String(thing[0]))
	check("Lo de encima de la mesa de secretaría cae sobre su L", drawn and loose.is_empty(), "dibujada=%s %s" % [str(drawn), str(loose)])
