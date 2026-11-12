extends RefCounted
## The offices' ceilings, floors and wet walls dressed (spec_rediseno 2, 0 and
## 6, area 4c). Under a false ceiling, the smoke detector, the sprinkler where
## the room has them and the square supply diffusers, each on a whole tile
## that neither a troffer nor she has (palette.troffers(), free_tiles() and
## her duct exits) and clear of the columns. Dirección's rug over its polished
## floor and the reception's mat (palette.rug_of(), floor_look()); the
## washroom's wet end tiled up to the false ceiling with its dark band, clear
## of the doorways with their switch and number plate, of the floor's systems
## and of the lockers, a sconce over each basin; each tiled stretch noted in
## builder.dressing_log.walls, where office_walls.gd hangs nothing; the
## director's curtains at the ends of his glass. No collider.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
const KIT := preload("res://game/world/office/pieces/kit.gd")
const STAND := preload("res://game/world/office/pieces/stand_ins.gd")
const THINGS := preload("res://game/world/office/pieces/desk_things.gd")
const FIXTURES := preload("res://game/world/office/pieces/fixtures.gd")
const MODELS := preload("res://game/world/office/office_models.gd")
const SIDE_OF := {"Wall_-1_0": "west", "Wall_1_0": "east", "Wall_0_-1": "north", "Wall_0_1": "south"}
const SIDE_STEP := {"Wall_-1_0": Vector2i(-1, 0), "Wall_1_0": Vector2i(1, 0), "Wall_0_-1": Vector2i(0, -1), "Wall_0_1": Vector2i(0, 1)}
## The tiles' underside over the room's height (office_geometry TILE_FACE).
const FACE := 0.004
## Nothing on a tile this near a column's side (spec_rediseno 3.4).
const POST_CLEAR := 0.45
## The detector, the sprinkler and the diffusers keep this far apart.
const APART := 1.8
## A diffuser to every two troffers, at most this many.
const DIFFUSERS := 4
const DIFFUSER := Vector3(0.6, 0.05, 0.6)
## The rug leaves this much hard floor round it, and is not laid smaller.
const RUG_MARGIN := 0.9
const RUG_LEAST := 1.5
const MAT := Vector3(1.2, 0.012, 0.8)
const MAT_IN := 0.75
## The wet end: the cubicles' wall and this much of the walls beside it, a
## panel this wide behind each basin, the dark band up to WET_BAND.
const WET_DEPTH := 2.4
const BASIN_PANEL := 1.6
const WET_BAND := 0.15
const TILE_DEPTH := 0.01
## Beyond a doorway's opening, untiled: its jamb, its switch and its number
## plate (office_walls.gd DOOR_HALF less half the opening).
const DOOR_CLEAR := 0.6
## Either side of a locker's spot on its wall.
const LOCKER_HALF := 0.75
const SCONCE_Y := 2.05
## A curtain either end of the director's glass, this far in from the end and
## off the glass.
const CURTAIN := Vector3(0.9, 2.1, 0.12)
const CURTAIN_IN := 0.55
const CURTAIN_OFF := 0.05

## The fittings of a room with a false ceiling (office_geometry.ceiling_fittings()).
static func ceiling(builder: Node3D, node: Node3D, room: Dictionary) -> void:
	var t := int(room.type)
	var h := float(room.height)
	var lamps: Array = OFFICE.troffers(room)
	var taken := {}
	for lamp in lamps:
		for tile in lamp.tiles: taken[tile] = true
	for tile in OFFICE.free_tiles(room): taken[tile] = true
	# Her duct exits' tiles too, whether or not free_tiles() still lists them.
	var exits: Array = builder.manifest.get("ducts", {}).get("exits", []).filter(func(e): return int(e.room) == int(room.id) and String(e.kind) in ["ceiling", "gap"])
	for e in exits: taken[OFFICE.tile_of(Vector3(float(e.point[0]), 0, float(e.point[2])))] = true
	var posts := OFFICE.column_rects(room)
	var origin := Vector3(float(room.px), 0, float(room.pz))
	var tiles := OFFICE.full_tiles(room)
	var spots: Array = []
	for j in range(tiles.position.y, tiles.end.y):
		for i in range(tiles.position.x, tiles.end.x):
			var tile := Vector2i(i, j)
			if taken.has(tile): continue
			var by_post := false
			for post in posts:
				if post.grow(POST_CLEAR).has_point(centre_of(tile)): by_post = true
			if not by_post: spots.append(tile)
	if spots.is_empty(): return
	var middle := Vector2(origin.x, origin.z)
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return centre_of(a).distance_to(middle) < centre_of(b).distance_to(middle))
	var kinds: Array = ["detector"]
	if t in OFFICE.SPRINKLER_ROOMS: kinds.append("sprinkler")
	var count: int = mini(maxi(lamps.size() / 2, 1), DIFFUSERS) if not lamps.is_empty() else 0
	for k in count: kinds.append("diffuser")
	var chosen: Array = []
	for what in kinds:
		for tile: Vector2i in spots:
			if chosen.any(func(other: Dictionary) -> bool: return centre_of(other.tile).distance_to(centre_of(tile)) < APART): continue
			chosen.append({"tile": tile, "what": what})
			break
	for entry: Dictionary in chosen:
		var at := OFFICE.tile_centre(entry.tile, 0.0) - origin
		match String(entry.what):
			"detector":
				# The download, hung by its top, where it is baked; else two ceramic discs.
				var detector := MODELS.mesh_of(builder, "smoke_detector")
				if detector != null:
					builder.place(node, detector, Transform3D(Basis.IDENTITY, at + Vector3(0, h + FACE - detector.get_aabb().size.y, 0)), false)
				else:
					builder.box(node, at + Vector3(0, h + FACE - 0.006, 0), Vector3(0.14, 0.012, 0.14), "ceramic", false, "detail_cylinder")
					builder.box(node, at + Vector3(0, h + FACE - 0.026, 0), Vector3(0.11, 0.03, 0.11), "ceramic", false, "detail_cylinder")
			"sprinkler":
				builder.box(node, at + Vector3(0, h + FACE - 0.004, 0), Vector3(0.07, 0.008, 0.07), "metal", false, "detail_cylinder")
				builder.box(node, at + Vector3(0, h + FACE - 0.03, 0), Vector3(0.022, 0.05, 0.022), "gold", false, "detail_cylinder")
				builder.box(node, at + Vector3(0, h + FACE - 0.058, 0), Vector3(0.05, 0.004, 0.05), "gold", false, "detail_cylinder")
			"diffuser":
				builder.place(node, STAND.ceiling_diffuser(builder, DIFFUSER), Transform3D(Basis.IDENTITY, at + Vector3(0, h + FACE - DIFFUSER.y, 0)), false)
		builder.dressing_log.ceiling.append({"room": int(room.id), "tile": entry.tile, "what": String(entry.what)})

## A tile's centre in world x and z.
static func centre_of(tile: Vector2i) -> Vector2:
	var c := OFFICE.tile_centre(tile, 0.0)
	return Vector2(c.x, c.z)

## A room's floor things and wet walls (office_geometry.extras(), before
## office_walls.gd).
static func dress(builder: Node3D, node: Node3D, room: Dictionary) -> void:
	rug(builder, node, room)
	var t := int(room.type)
	if t == OFFICE.TOILETS: wet_walls(builder, node, room)
	if t == OFFICE.EXEC_OFFICE: curtains(builder, node, room)

## The rug of palette.rug_of(): Dirección's over most of its floor, along its
## longer side; the reception's mat inside its first doorway.
static func rug(builder: Node3D, node: Node3D, room: Dictionary) -> void:
	var look := OFFICE.rug_of(room)
	if look.is_empty(): return
	if look == "mat":
		var ways: Array = FLOOR.doorways(room)
		if ways.is_empty(): return
		var way: Dictionary = ways[0]
		var wall := String(way.wall)
		var across := wall == "west" or wall == "east"
		var on_wall: Vector2 = Vector2(LAYOUT.face(room, wall), float(way.along)) if across else Vector2(float(way.along), LAYOUT.face(room, wall))
		var spot := on_wall + LAYOUT.inward(wall) * MAT_IN
		builder.place(node, FIXTURES.rug(builder, MAT, "black"), Transform3D(Basis(Vector3.UP, PI / 2 if across else 0.0), Vector3(spot.x, 0, spot.y)))
		return
	var inner := LAYOUT.inner(room).grow(-RUG_MARGIN)
	if inner.size.x < RUG_LEAST or inner.size.y < RUG_LEAST: return
	var along_x := inner.size.x >= inner.size.y
	var major: float = snappedf(maxf(inner.size.x, inner.size.y) - 0.05, 0.1)
	var minor: float = snappedf(minf(inner.size.x, inner.size.y) - 0.05, 0.1)
	var size := Vector3(major, 0.012, minor)
	var mesh: Mesh = THINGS.rug_persian(builder, size) if look == "persian" else FIXTURES.rug(builder, size, "carpet_exec")
	builder.place(node, mesh, Transform3D(Basis(Vector3.UP, 0.0 if along_x else PI / 2), Vector3(inner.get_center().x, 0, inner.get_center().y)))

## The washroom's wet end (spec_rediseno 6.11): tiled from the floor to the
## false ceiling, its bottom WET_BAND dark, on the wall its cubicles back on
## to, WET_DEPTH of the two walls beside it and a panel behind each basin;
## a sconce over each basin (an accent).
static func wet_walls(builder: Node3D, node: Node3D, room: Dictionary) -> void:
	var wet := ""
	for item in room.get("furniture", []):
		if String(item.kind) == "cubicles": wet = back_wall(int(item.turn))
	var panels: Array = []
	if room.has("sockets"):
		for prop in room.get("props", []):
			if String(prop.kind) != "basin": continue
			var socket: Array = room.sockets[int(prop.slot)]
			var wall := back_wall(int(prop.rotation))
			var along: float = float(socket[1]) if wall == "west" or wall == "east" else float(socket[0])
			panels.append({"wall": wall, "along": along})
	if wet.is_empty() and panels.is_empty(): return
	KIT.material(builder, "wet_tile")
	KIT.material(builder, "wet_band")
	var h := float(room.height)
	var span := FLOOR.size_of(room)
	for boundary in node.get_children():
		var side := String(SIDE_OF.get(String(boundary.name), ""))
		if side.is_empty(): continue
		var step: Vector2i = SIDE_STEP[String(boundary.name)]
		var inner := -(step.x + step.y)
		var length: float = span.y if side == "west" or side == "east" else span.x
		var runs: Array = []
		if side == wet: runs.append(Vector2(-length * 0.5, length * 0.5))
		elif not wet.is_empty() and beside(side, wet):
			var end := wet_end(side, wet, length)
			var toward := end - signf(end) * WET_DEPTH
			runs.append(Vector2(minf(end, toward), maxf(end, toward)))
		for panel: Dictionary in panels:
			if String(panel.wall) != side: continue
			var x := to_wall(side, float(panel.along))
			runs.append(Vector2(x - BASIN_PANEL * 0.5, x + BASIN_PANEL * 0.5))
			builder.accent_sconce(boundary, int(room.id), Vector3(x, SCONCE_Y, inner * (0.09 + TILE_DEPTH)), PI if inner < 0 else 0.0)
		for run: Vector2 in merged(runs): tile_run(builder, boundary, room, side, run, length, h, inner)

## Tiles from the floor to the false ceiling along a run of a wall (its x),
## cut at its doorways, its systems' spots and its lockers, the bottom
## WET_BAND dark; each piece noted (builder.dressing_log.walls, "tiles").
static func tile_run(builder: Node3D, boundary: Node3D, room: Dictionary, side: String, run: Vector2, length: float, h: float, inner: int) -> void:
	var pieces: Array = [Vector2(maxf(run.x, -length * 0.5), minf(run.y, length * 0.5))]
	for way in FLOOR.doorways(room):
		if String(way.wall) != side: continue
		var x := to_wall(side, float(way.along))
		pieces = cut(pieces, Vector2(x - FLOOR.PORTAL * 0.5 - DOOR_CLEAR, x + FLOOR.PORTAL * 0.5 + DOOR_CLEAR))
	for fx in LAYOUT.fixtures(builder.manifest, int(room.id)):
		if String(fx.wall) != side: continue
		var x := to_wall(side, float(fx.along))
		pieces = cut(pieces, Vector2(x - float(fx.half), x + float(fx.half)))
	for spot in room.get("hides", []):
		var hw: Dictionary = LAYOUT.hide_wall(spot)
		if String(hw.wall) != side: continue
		var x := to_wall(side, float(hw.along))
		pieces = cut(pieces, Vector2(x - LOCKER_HALF, x + LOCKER_HALF))
	var z := inner * (0.09 + TILE_DEPTH * 0.5)
	for piece: Vector2 in pieces:
		var wide := piece.y - piece.x
		if wide < 0.05: continue
		var mid := (piece.x + piece.y) * 0.5
		builder.box(boundary, Vector3(mid, WET_BAND * 0.5, z), Vector3(wide, WET_BAND, TILE_DEPTH), "wet_band")
		builder.box(boundary, Vector3(mid, (WET_BAND + h) * 0.5, z), Vector3(wide, h - WET_BAND, TILE_DEPTH), "wet_tile")
		builder.dressing_log.walls.append({"room": int(room.id), "side": side, "kind": "tiles", "from": piece.x, "to": piece.y, "low": 0.0, "high": h, "depth": TILE_DEPTH})

## The spans left of `pieces` (each from x to y along a wall) once `gap` is
## taken out of them.
static func cut(pieces: Array, gap: Vector2) -> Array:
	var kept: Array = []
	for piece: Vector2 in pieces:
		if piece.y <= gap.x or piece.x >= gap.y:
			kept.append(piece)
			continue
		if piece.x < gap.x: kept.append(Vector2(piece.x, gap.x))
		if piece.y > gap.y: kept.append(Vector2(gap.y, piece.y))
	return kept

## Runs along a wall joined where they overlap: no two tiled boxes in one plane.
static func merged(runs: Array) -> Array:
	var sorted: Array = runs.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var out: Array = []
	for run: Vector2 in sorted:
		if not out.is_empty():
			var last: Vector2 = out.back()
			if run.x <= last.y:
				out[out.size() - 1] = Vector2(last.x, maxf(last.y, run.y))
				continue
		out.append(run)
	return out

## The director's glass (spec_rediseno 6.7) with a velvet curtain drawn back
## at either end, on the room's side, clear of a doorway.
static func curtains(builder: Node3D, node: Node3D, room: Dictionary) -> void:
	var glazed: Array = room.get("glazed", [])
	if glazed.is_empty(): return
	var span := FLOOR.size_of(room)
	var mesh := FIXTURES.curtain(builder, CURTAIN)
	for boundary in node.get_children():
		var side := String(SIDE_OF.get(String(boundary.name), ""))
		if side.is_empty() or not glazed.has(side): continue
		var step: Vector2i = SIDE_STEP[String(boundary.name)]
		var inner := -(step.x + step.y)
		var length: float = span.y if side == "west" or side == "east" else span.x
		var turn := Basis(Vector3.UP, PI if inner < 0 else 0.0)
		for s: float in [-1.0, 1.0]:
			var x := s * (length * 0.5 - CURTAIN_IN)
			if near_door(room, side, x, CURTAIN.x * 0.5 + FLOOR.PORTAL * 0.5 + 0.2): continue
			builder.place(boundary, mesh, Transform3D(turn, Vector3(x, 0, inner * (0.09 + CURTAIN_OFF + CURTAIN.z * 0.5))))

## The wall a piece turned `turn` quarters backs on to (its back is -Z).
static func back_wall(turn: int) -> String:
	return ["north", "west", "south", "east"][posmod(turn, 4)]

## Whether two walls meet at a corner (one runs along x, the other along z).
static func beside(side: String, other: String) -> bool:
	return (side == "west" or side == "east") != (other == "west" or other == "east")

## The end of a wall beside the wet one that meets it, in the wall's own x:
## the west and east walls run along -z, the north and south ones along x.
static func wet_end(side: String, wet: String, length: float) -> float:
	if side == "west" or side == "east": return length * 0.5 if wet == "north" else -length * 0.5
	return -length * 0.5 if wet == "west" else length * 0.5

## A room-local point along a wall (doorways()' along) in the wall's own x.
static func to_wall(side: String, along: float) -> float:
	return -along if side == "west" or side == "east" else along

## Whether a doorway on `side` is within `half` of x along it.
static func near_door(room: Dictionary, side: String, x: float, half: float) -> bool:
	for way in FLOOR.doorways(room):
		if String(way.wall) == side and absf(to_wall(side, float(way.along)) - x) < half: return true
	return false
