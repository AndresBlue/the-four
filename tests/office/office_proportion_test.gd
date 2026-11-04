extends SceneTree
## Spec_proporcion's acceptance on eight floors, with no window and nothing built:
## the floor each type's things take, the main piece's width in the frame and the
## free floor in the frame, from office_rooms_capture's camera (room_framing.gd);
## the walk from the board to the lift within lift_timer; and what the recipes
## must keep: tops for the papers, runs that join and do not overlap, the bands
## kept, chairs on the near side of the table, every corner measured.
const GEN := preload("res://game/world/generation/office_generator.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
const FRAMING := preload("res://tools/capture/room_framing.gd")
const GAIT := preload("res://game/player/survivor_gait.gd")
const PAPERS := preload("res://game/world/generation/document_placement.gd")
const SEEDS := [7, 21, 33, 1, 2, 3, 4, 5]
## Floor taken at most, and the main piece's width in the frame at least, in %.
const MOST_FLOOR := 45.0
const LEAST_PIECE := 30.0
## The pictures' 1200 x 800, sampled by this many rays.
const WIDE := 48
const HIGH := 32
## How high a corner piece counts in the frame.
const CORNER_TOP := 1.2
## What a main piece is, by kinds (the board and the handler are the manifest's).
const MAIN_KINDS := {"recepcion": ["reception_counter_l"], "correo": ["pigeonholes"], "aseos": ["locker_bank"], "juntas": ["meeting_table_s", "meeting_table_m", "meeting_table_l"], "reprografia": ["copier", "work_table"], "descanso": ["kitchen", "dining_set"], "despacho": ["office_suite"], "direccion": ["exec_desk"], "secretaria": ["secretary_desk"]}
## The mobile archive: a floor may have none, and its rows fill past MOST_FLOOR.
const NO_CAP := ["archivo_movil"]
## The types that must keep to their band in half their rooms or more.
const BANDED := ["despacho", "recepcion", "juntas", "aseos"]
## [name, the types its floor is measured on, least floor %, most free floor in
## frame %, the types framed, the first with a room]. The air room's recipe is
## measured on its floor, and the frame is the plant's, with the handler (D12).
var rows: Array = [
	["recepcion", [OFFICE.RECEPTION], 16.0, 35.0, [OFFICE.RECEPTION]],
	["ventanilla", [OFFICE.WINDOW], 20.0, 30.0, [OFFICE.WINDOW]],
	["correo", [OFFICE.MAIL], 18.0, 30.0, [OFFICE.MAIL]],
	["archivo", [OFFICE.ARCHIVE], 20.0, 30.0, [OFFICE.ARCHIVE, OFFICE.MOBILE_ARCHIVE]],
	["archivo_movil", [OFFICE.MOBILE_ARCHIVE], 40.0, 30.0, [OFFICE.MOBILE_ARCHIVE]],
	["reprografia", [OFFICE.COPY_ROOM], 22.0, 30.0, [OFFICE.COPY_ROOM]],
	["despacho", [OFFICE.OFFICE], 20.0, 30.0, [OFFICE.OFFICE]],
	["direccion", [OFFICE.EXEC_OFFICE], 22.0, 30.0, [OFFICE.EXEC_OFFICE]],
	["secretaria", [OFFICE.SECRETARY], 20.0, 30.0, [OFFICE.SECRETARY]],
	["juntas", [OFFICE.BOARDROOM], 22.0, 30.0, [OFFICE.BOARDROOM]],
	["descanso", [OFFICE.BREAK_ROOM], 18.0, 30.0, [OFFICE.BREAK_ROOM]],
	["aseos", [OFFICE.TOILETS], 16.0, 35.0, [OFFICE.TOILETS]],
	["seguridad", [OFFICE.SECURITY], 20.0, 30.0, [OFFICE.SECURITY]],
	["electrico", [OFFICE.ELECTRICAL], 16.0, 30.0, [OFFICE.ELECTRICAL]],
	["climatizacion", [OFFICE.AIR_ROOM], 15.0, 35.0, [OFFICE.AIR_PLANT, OFFICE.AIR_ROOM]],
	["montacargas", [OFFICE.REFUGE, OFFICE.LOBBY], 3.0, 30.0, [OFFICE.REFUGE, OFFICE.LOBBY]],
]
## The types whose recipe joins two kinds in a run (D4): the security post's and
## the mail room's runs are of one kind.
var run_types: Array = [OFFICE.RECEPTION, OFFICE.OFFICE, OFFICE.COPY_ROOM, OFFICE.BREAK_ROOM, OFFICE.EXEC_OFFICE, OFFICE.WINDOW, OFFICE.SECRETARY]
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not detail.is_empty() else "")

static func median(values: Array) -> float:
	if values.is_empty(): return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])

static func mean(values: Array) -> float:
	var sum := 0.0
	for value in values: sum += float(value)
	return sum / float(maxi(values.size(), 1))

## What stands on a room's floor, room-local: {rect, top, what}.
func things_of(m: Dictionary, room: Dictionary) -> Array:
	var id := int(room.id)
	var out: Array = []
	for it in room.get("furniture", []): out.append({"rect": LAYOUT.footprint(it), "top": float(it.extra.height), "what": String(it.kind)})
	for prop in room.get("props", []): out.append({"rect": OFFICE.corner_rect(String(prop.kind), room.sockets[int(prop.slot)], int(prop.rotation)), "top": CORNER_TOP, "what": "corner"})
	for h in room.get("hides", []):
		var hw := LAYOUT.hide_wall(h)
		out.append({"rect": LAYOUT.wall_rect(room, String(hw.wall), float(hw.along), LAYOUT.LOCKER.x / 2, LAYOUT.LOCKER.y), "top": 2.3, "what": "locker"})
	if int(m.power.room) == id: out.append({"rect": LAYOUT.wall_rect(room, String(m.power.board.wall), float(m.power.board.along), 1.3, 0.2), "top": 2.4, "what": "board"})
	if int(m.mail.window) == id: out.append({"rect": LAYOUT.wall_rect(room, String(m.mail.desk.wall), float(m.mail.desk.along), 0.6, 0.8), "top": 0.76, "what": "post"})
	if int(m.air.security.room) == id: out.append({"rect": LAYOUT.wall_rect(room, String(m.air.security.desk.wall), float(m.air.security.desk.along), 0.9, 0.8), "top": 0.76, "what": "console"})
	if int(m.air.plant) == id: out.append({"rect": LAYOUT.wall_rect(room, String(m.air.unit.wall), float(m.air.unit.along), OFFICE.AIR_UNIT.x / 2, OFFICE.AIR_UNIT.z), "top": OFFICE.AIR_UNIT.y, "what": "handler"})
	var middle := Vector2(float(room.px), float(room.pz))
	for unit in m.get("archives", []):
		if not unit.rooms.any(func(r): return int(r) == id): continue
		for row in unit.rows:
			out.append({"rect": Rect2(Vector2(float(row[0]), float(row[1])) - middle, Vector2(float(row[2]) - float(row[0]), float(row[3]) - float(row[1]))), "top": 2.1, "what": "row"})
	return out

## A room and the cells open to it (a salon's, the air plant's room), each with
## what stands on its floor: {room, things}.
func open_cells(m: Dictionary, room: Dictionary) -> Array:
	var out: Array = []
	var seen := {int(room.id): true}
	var queue: Array = [room]
	while not queue.is_empty():
		var cell: Dictionary = queue.pop_back()
		out.append({"room": cell, "things": things_of(m, cell)})
		for side in cell.get("open_sides", []):
			var next := FLOOR.beside(cell, LAYOUT.way_of(String(side)))
			if next >= 0 and not seen.has(next):
				seen[next] = true
				queue.append(m.rooms[next])
	return out

## The share of a room's floor they take, in %, on a grid of 20 cm.
static func floor_taken(room: Dictionary, things: Array) -> float:
	var space := LAYOUT.inner(room)
	var inside := 0
	var taken := 0
	var x := space.position.x + 0.1
	while x < space.end.x:
		var z := space.position.y + 0.1
		while z < space.end.y:
			inside += 1
			var p := Vector2(x, z)
			for thing in things:
				if (thing.rect as Rect2).has_point(p):
					taken += 1
					break
			z += 0.2
		x += 0.2
	return 100.0 * float(taken) / float(maxi(inside, 1))

## The camera of a room's view: {from, ahead, right, up, spread}.
static func camera_of(view: Dictionary) -> Dictionary:
	var from: Vector3 = view.from
	var ahead: Vector3 = (view.at - from).normalized()
	var right: Vector3 = ahead.cross(Vector3.UP).normalized()
	return {"from": from, "ahead": ahead, "right": right, "up": right.cross(ahead), "spread": tan(deg_to_rad(FRAMING.FOV) * 0.5)}

## How much of the picture's width these things span, in %, by their boxes.
static func width_in_frame(camera: Dictionary, room: Dictionary, things: Array) -> float:
	if things.is_empty(): return 0.0
	var c := FLOOR.position_of(room)
	var low := 1.0
	var high := -1.0
	for thing in things:
		var r: Rect2 = thing.rect
		for corner: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			var v := Vector3(c.x + corner.x, c.y, c.z + corner.y) - (camera.from as Vector3)
			var x: float = v.dot(camera.right) / (maxf(v.dot(camera.ahead), 0.05) * float(camera.spread))
			low = minf(low, clampf(x, -1.0, 1.0))
			high = maxf(high, clampf(x, -1.0, 1.0))
	return 50.0 * maxf(high - low, 0.0)

## The share of the picture that is free floor of these cells (open_cells()), in
## %: the rays that reach their floor before any box.
static func free_in_frame(camera: Dictionary, cells: Array) -> float:
	var boxes: Array = []
	for cell in cells:
		var c := FLOOR.position_of(cell.room)
		for thing in cell.things:
			var r: Rect2 = thing.rect
			boxes.append(AABB(Vector3(c.x + r.position.x, c.y, c.z + r.position.y), Vector3(r.size.x, float(thing.top), r.size.y)))
	var floor_y: float = FLOOR.position_of(cells[0].room).y
	var from: Vector3 = camera.from
	var free := 0
	for j in HIGH:
		for i in WIDE:
			var x := (float(i) + 0.5) / float(WIDE) * 2.0 - 1.0
			var y := (float(j) + 0.5) / float(HIGH) * 2.0 - 1.0
			var ray: Vector3 = camera.ahead + camera.right * x * float(camera.spread) - camera.up * y * float(camera.spread) * float(HIGH) / float(WIDE)
			if ray.y >= -0.0001: continue
			var t := (floor_y - from.y) / ray.y
			var hit := from + ray * t
			var on_floor := false
			for cell in cells:
				var c := FLOOR.position_of(cell.room)
				if LAYOUT.inner(cell.room).has_point(Vector2(hit.x - c.x, hit.z - c.z)): on_floor = true
			if not on_floor: continue
			var blocked := false
			for box: AABB in boxes:
				var on = box.intersects_ray(from, ray)
				if on != null and from.distance_to(on) < from.distance_to(hit) - 0.001:
					blocked = true
					break
			if not blocked: free += 1
	return 100.0 * float(free) / float(WIDE * HIGH)

## Whether a group of these items holds two kinds: a run that joined (D4).
static func joined_kinds(items: Array) -> bool:
	var kinds_of := {}
	for it in items:
		var group := int(it.extra.group)
		if not kinds_of.has(group): kinds_of[group] = {}
		kinds_of[group][String(it.kind)] = true
		if kinds_of[group].size() >= 2: return true
	return false

## The first room of the first of these types with one (office_rooms_capture.room_of()).
static func first_room(m: Dictionary, types: Array) -> Dictionary:
	for kind in types:
		for room in m.rooms:
			if int(room.type) == int(kind) and not FLOOR.is_void(room) and (not room.get("doors", []).is_empty() or int(room.type) == OFFICE.AIR_PLANT): return room
	return {}

func run() -> void:
	var floors := {}
	var frees := {}
	var widths := {}
	var bands := {}
	for row in rows:
		floors[row[0]] = []
		frees[row[0]] = []
		widths[row[0]] = []
		bands[row[0]] = []
	var fallen: Array = []
	var walk_most := 0.0
	var tops_least := 1000
	var overlaps: Array = []
	var joined := 0
	var joinable := 0
	var tables := 0
	var near_seated := 0
	var strays: Array = []
	for seed_value in SEEDS:
		var m: Dictionary = GEN.new().generate(int(seed_value), 2)
		if m.is_empty() or bool(m.get("fallback", false)):
			fallen.append(seed_value)
			continue
		for row in rows:
			var name_of := String(row[0])
			for room in m.rooms:
				if (row[1] as Array).has(int(room.type)) and not FLOOR.is_void(room):
					floors[name_of].append(floor_taken(room, things_of(m, room)))
					bands[name_of].append(100.0 if OFFICE.fits_band(int(room.type), room) else 0.0)
			var framed := first_room(m, row[4])
			if framed.is_empty(): continue
			var camera := camera_of(FRAMING.view_of(framed, FRAMING.door_of(m.rooms, framed)))
			var things := things_of(m, framed)
			frees[name_of].append(free_in_frame(camera, open_cells(m, framed)))
			var main: Array = things.filter(func(thing): return String(thing.what) == "board" or String(thing.what) == "handler" or (MAIN_KINDS.get(name_of, []) as Array).has(String(thing.what)))
			if name_of in ["electrico", "climatizacion"] or MAIN_KINDS.has(name_of): widths[name_of].append(width_in_frame(camera, framed, main))
		walk_most = maxf(walk_most, float(FLOOR.route_metres(m, int(m.power.room)).get(int(m.refuges[1]), INF)))
		var tops := [0, 0, 0]
		# Only where document_placement.choose() would leave a paper: past its `least`.
		var reach_of := {}
		var least_of := {}
		for planta in 3:
			var metres := FLOOR.route_metres(m, FLOOR.entry_of(m, planta))
			var deepest := 0.0
			for id in metres: deepest = maxf(deepest, float(metres[id]))
			reach_of[planta] = metres
			least_of[planta] = maxf(PAPERS.MIN_FROM_START, deepest * PAPERS.SHARE_IN)
		for room in m.rooms:
			if FLOOR.is_void(room) or m.refuges.has(int(room.id)) or bool(room.get("landing", false)): continue
			if int(room.type) == OFFICE.OFFICE and int(room.wing) == 2 and (m.air.main.cells as Array).has(int(room.id)) and maxf(float(room.span_x), float(room.span_z)) > 7.501: strays.append("%d: %d" % [int(seed_value), int(room.id)])
			for prop in room.get("props", []):
				if PAPERS.SURFACES.has(String(prop.kind)) and float(reach_of[int(room.wing)].get(int(room.id), 0.0)) >= float(least_of[int(room.wing)]): tops[int(room.wing)] += 1
			if int(room.type) in [OFFICE.OPEN_OFFICE, OFFICE.CUBICLES]: continue
			var items: Array = room.get("furniture", [])
			if int(room.type) == OFFICE.BOARDROOM and items.any(func(it): return String(it.kind).begins_with("meeting_table")):
				tables += 1
				if items.any(func(it): return String(it.kind) == "table_chair"): near_seated += 1
			for i in items.size():
				for j in range(i + 1, items.size()):
					if int(items[i].extra.group) == int(items[j].extra.group) and LAYOUT.footprint(items[i]).grow(-0.01).intersects(LAYOUT.footprint(items[j])): overlaps.append("%d: %d" % [int(seed_value), int(room.id)])
			if run_types.has(int(room.type)) and int(room.get("hall", -1)) < 0:
				joinable += 1
				if joined_kinds(items): joined += 1
		tops_least = mini(tops_least, int(tops.min()))
	check("Ninguna de las semillas sale en piso de reserva", fallen.is_empty(), str(fallen))
	var figures := {}
	for row in rows:
		var name_of := String(row[0])
		var count := (floors[name_of] as Array).size()
		var taken := median(floors[name_of])
		var free := median(frees[name_of])
		var width := median(widths[name_of])
		var in_band := mean(bands[name_of])
		figures[name_of] = {"suelo": snappedf(taken, 0.1), "salas": count, "banda": int(in_band), "libre": snappedf(free, 0.1), "pieza": snappedf(width, 0.1)}
		print("PROPORCION %s suelo=%.1f salas=%d banda=%d libre=%.1f pieza=%.1f" % [name_of, taken, count, int(in_band), free, width])
		if count == 0 and NO_CAP.has(name_of): continue
		var most: float = 100.0 if NO_CAP.has(name_of) else MOST_FLOOR
		check("Suelo ocupado en %s: mediana entre %.0f y %.0f" % [name_of, float(row[2]), most], taken >= float(row[2]) and taken <= most, "%.1f" % taken)
		check("Suelo libre en cuadro en %s: %.0f o menos" % [name_of, float(row[3])], free <= float(row[3]), "%.1f" % free)
		if name_of in ["electrico", "climatizacion"] or MAIN_KINDS.has(name_of): check("Pieza principal en cuadro en %s: %.0f o más" % [name_of, LEAST_PIECE], width >= LEAST_PIECE, "%.1f" % width)
		if BANDED.has(name_of): check("Las salas de %s en su banda: la mitad o más" % name_of, in_band >= 50.0, "%d" % int(in_band))
	check("El paseo del cuadro al montacargas cabe andando en los 60 s de lift_timer", walk_most <= 60.0 * GAIT.SPEED_WALK, "%.1f m" % walk_most)
	check("Cada planta conserva dos o más mesas para los papeles", tops_least >= 2, str(tops_least))
	check("Ninguna pieza de un tramo pisa a otra de su grupo", overlaps.is_empty(), str(overlaps.slice(0, 5)))
	check("Los tramos juntan piezas distintas en la mitad de las salas o más", joinable > 0 and joined * 2 >= joinable, "%d de %d" % [joined, joinable])
	check("Las salas de juntas con mesa llevan silla del lado cercano: el 80 % o más", tables > 0 and near_seated * 5 >= tables * 4, "%d de %d" % [near_seated, tables])
	check("Ningún despacho fuera de banda sobre el conducto principal de la tercera planta", strays.is_empty(), str(strays.slice(0, 5)))
	var unmeasured: Array = []
	for recipe in OFFICE.RECIPES:
		for kind in recipe:
			if String(kind) != "" and not OFFICE.CORNER_SIZES.has(kind): unmeasured.append(kind)
	check("Cada pieza de esquina tiene su huella en CORNER_SIZES", unmeasured.is_empty(), str(unmeasured))
	var file := FileAccess.open("res://evidence/office_proportion.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks, "figures": figures, "walk_most": walk_most, "tops_least": tops_least, "joined": joined, "joinable": joinable, "tables": tables, "near_seated": near_seated}, "\t"))
	print("OFFICE_PROPORTION_RESULT ", checks.size() - failed, "/", checks.size())
	quit(1 if failed > 0 else 0)
