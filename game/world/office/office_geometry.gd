extends "res://game/world/hotel/hotel_geometry.gd"
## The offices' geometry (.claude/specs/spec_f1_geometry.md) as step 1d begins
## it: the hotel's, through its hooks, on the office's finishes. Until the
## office's own materials are ingested (spec 4.4 and 10), each finish the
## palette names stands in as the nearest hotel material, marked "stand_in".
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
## A finish of the office palette (floor_finish(), wall_material()) and the
## hotel material that stands in for it.
const STAND_INS := {"tgrid": "metal", "troffer_body": "metal", "troffer_lens": "light", "lens_off": "light_off", "grille_metal": "metal", "plenum_dark": "black", "vinyl": "tile", "terrazzo": "tile", "veneer": "panel", "laminate": "wood", "enamel": "ceramic", "steel_olive": "metal", "steel_frame": "metal", "cardboard": "fabric", "bottle": "mirror", "partition_fabric": "fabric"}
const PROPS := preload("res://game/world/office/office_props.gd")
## Finishes that stand in as a plain colour until their scans are ingested:
## the hotel has no plain paint, block or concrete.
const PLAIN := {"office_paint": Color("c4bfae"), "block": Color("a8a59b"), "concrete": Color("8b8780"), "skirting": Color("4a4741")}
## The cove base along the walls and the department stripe in the corridors
## (spec 4.1): height and thickness; bottom and top.
const SKIRT := Vector2(0.10, 0.006)
const STRIPE := Vector2(1.05, 1.20)
const STRIPE_PROUD := 0.003
## The false ceiling (spec 4.1): tile thickness and face over the grid's
## underside, the T-grid's flange width, thickness and web height, the
## troffer's housing depth and lens recess, its light.
const TILE_THICK := 0.015
const TILE_FACE := 0.004
const TEE := Vector3(0.024, 0.004, 0.032)
const TROFFER_BODY := 0.11
const LENS_RECESS := 0.012
const LAMP_ENERGY := 3.6
const LAMP_DROP := 0.35

func _init() -> void:
	super()
	for key in PLAIN:
		var plain := StandardMaterial3D.new()
		plain.albedo_color = PLAIN[key]
		plain.roughness = 0.9
		plain.set_meta("stand_in", true)
		materials[key] = plain
	for key in STAND_INS:
		var path := "res://game/presentation/materials/office/%s.tres" % key
		if ResourceLoader.exists(path):
			materials[key] = load(path).duplicate()
			materials[key].set_meta("lite", key)
			apply_scan(materials[key], small_maps)
		else:
			materials[key] = materials[STAND_INS[key]].duplicate()
			materials[key].set_meta("stand_in", true)

## A false ceiling of 0.6 m tiles on the world's lattice (5.2): its collider
## over the tiles, runs of tiles round the troffers, grilles and gaps, the
## T-grid, the troffers, the grilles, and the dark of the plenum over a gap.
## A room with no false ceiling keeps the hotel's slab (5.3).
func ceiling(node: Node3D, room: Dictionary) -> void:
	if not OFFICE.false_ceiling(room):
		super(node, room)
		return
	var h := float(room.height)
	var span := FLOOR.size_of(room)
	var origin := Vector3(float(room.px), 0, float(room.pz))
	var tile: float = OFFICE.TILE
	box(node, Vector3(0, h + TILE_FACE + 0.025, 0), Vector3(span.x, 0.05, span.y), "", true)
	var rect: Rect2 = OFFICE.ceiling_rect(room)
	var holes := {}
	var lamps: Array = OFFICE.troffers(room)
	for lamp in lamps:
		for t in lamp.tiles: holes[t] = true
	var exits: Array = manifest.get("ducts", {}).get("exits", []).filter(func(e): return int(e.room) == int(room.id) and String(e.kind) in ["ceiling", "gap"])
	for e in exits: holes[OFFICE.tile_of(Vector3(float(e.point[0]), 0, float(e.point[2])))] = true
	var face := h + TILE_FACE + TILE_THICK * 0.5
	for j in range(floori(rect.position.y / tile), ceili(rect.end.y / tile)):
		var z0 := maxf(j * tile, rect.position.y)
		var z1 := minf((j + 1) * tile, rect.end.y)
		if z1 - z0 < 0.005: continue
		var start := INF
		var i_end := ceili(rect.end.x / tile)
		for i in range(floori(rect.position.x / tile), i_end + 1):
			var cut := i == i_end or holes.has(Vector2i(i, j))
			if cut and start < INF:
				var stop := minf(i * tile, rect.end.x)
				box(node, Vector3((start + stop) * 0.5, face, (z0 + z1) * 0.5) - origin, Vector3(stop - start, TILE_THICK, z1 - z0), "ceiling_service")
				start = INF
			elif not cut and start == INF: start = maxf(i * tile, rect.position.x)
	# The T-grid: a line on every lattice line inside the rect (on a shared
	# edge, drawn by the cell on its low side).
	for i in range(ceili(rect.position.x / tile), ceili(rect.end.x / tile)):
		var x := i * tile
		box(node, Vector3(x, h + TEE.y * 0.5, rect.get_center().y) - origin, Vector3(TEE.x, TEE.y, rect.size.y), "tgrid")
		box(node, Vector3(x, h + TEE.y + TEE.z * 0.5, rect.get_center().y) - origin, Vector3(0.006, TEE.z, rect.size.y), "tgrid")
	for j in range(ceili(rect.position.y / tile), ceili(rect.end.y / tile)):
		var z := j * tile
		box(node, Vector3(rect.get_center().x, h + TEE.y * 0.5, z) - origin, Vector3(rect.size.x, TEE.y, TEE.x), "tgrid")
	# The troffers: a housing over two tiles and its prismatic lens.
	var lens := "lens_off" if dark_room(room) else "troffer_lens"
	for lamp in lamps:
		var size := Vector3(0.6, TROFFER_BODY, 1.2) if bool(lamp.along_z) else Vector3(1.2, TROFFER_BODY, 0.6)
		var at := Vector3(lamp.centre.x, 0, lamp.centre.y) - origin
		box(node, at + Vector3(0, h + TILE_FACE + TROFFER_BODY * 0.5, 0), size, "troffer_body")
		box(node, at + Vector3(0, h + LENS_RECESS, 0), Vector3(size.x - 0.04, 0.01, size.z - 0.04), lens)
	# The grilles in their tiles; over a gap, the dark of the plenum.
	for e in exits:
		var at := OFFICE.tile_centre(OFFICE.tile_of(Vector3(float(e.point[0]), 0, float(e.point[2]))), 0.0) - origin
		if String(e.kind) == "ceiling":
			box(node, at + Vector3(0, h + 0.15, 0), Vector3(0.58, 0.3, 0.58), "black")
			box(node, at + Vector3(0, h + 0.01, 0), Vector3(0.595, 0.02, 0.595), "grille_metal")
		else:
			box(node, at + Vector3(0, h + 0.6, 0), Vector3(0.6, 1.2, 0.6), "plenum_dark")

## The room being built, for the walls that need it (its stripe).
var building_room := {}

func build_room(node: Node3D, room: Dictionary) -> void:
	building_room = room
	super(node, room)
	building_room = {}

## An office wall (6.2): plain paint, a cove base on this room's face, and in
## a corridor its department's stripe; none of the hotel's dado, rails,
## sockets or cornice.
func wall_run(boundary: Node3D, x: float, length: float, height: float, inner: int) -> void:
	wall_core(boundary, Vector3(x, height / 2, 0), Vector3(length, height, 0.18), inner)
	var room_node := boundary.get_parent() as Node3D
	plan_wall(room_node, boundary.transform * Vector3(x - length * 0.5, 0, 0), boundary.transform * Vector3(x + length * 0.5, 0, 0))
	box(boundary, Vector3(x, SKIRT.x * 0.5, inner * (0.09 + SKIRT.y * 0.5)), Vector3(length, SKIRT.x, SKIRT.y), "skirting")
	if building_room.is_empty() or not (int(building_room.type) in [OFFICE.CORRIDOR, OFFICE.GALLERY]): return
	var colour: Color = OFFICE.stripe_color(manifest, building_room)
	var key := "stripe_%s" % colour.to_html(false)
	if not materials.has(key):
		var stripe := StandardMaterial3D.new()
		stripe.albedo_color = colour
		stripe.roughness = 0.7
		materials[key] = stripe
	box(boundary, Vector3(x, (STRIPE.x + STRIPE.y) * 0.5, inner * (0.09 + STRIPE_PROUD)), Vector3(length, STRIPE.y - STRIPE.x, 0.004), key)

## No paintings and no sconces on an office wall (6.5: the notice boards,
## clocks and poster spots come later).
func wall_art(_boundary: Node3D, _room: Dictionary, _at: float, _inner: int) -> void: pass

## The troffers (built by ceiling()) light the room as a fluorescent tube
## does (7.1); the battens and the boardroom's pendant are the hotel's.
func lamp_fixture(node: Node3D, room: Dictionary) -> Dictionary:
	if OFFICE.lamp_of(room) != "troffer": return super(node, room)
	var h := float(room.height)
	return {"tube": true, "failing": "", "specular": 0.45, "color": LIGHTING.light_color(LIGHTING.FLUORESCENT, LIGHTING.TUBE_TINT), "energy": LAMP_ENERGY * LIGHTING.PROFILE_GAIN, "profile": LIGHTING.profile("tube"), "position": Vector3(0, h - LAMP_DROP, 0)}

## The office's corner pieces first (9.3); the hotel's own kinds as the hotel.
func build_prop(node: Node3D, kind: String) -> void:
	if not PROPS.build(self, node, kind): super(node, kind)

## An archive cell's share of its unit's rows (9.4): each row rectangle cut
## at the cell's edges and built under the cell, so it batches and layers
## with it.
func extras(node: Node3D, room: Dictionary) -> void:
	super(node, room)
	# The room's free-standing furniture (9.2), each item in a holder of its own.
	var items: Array = room.get("furniture", [])
	for k in items.size():
		var item: Dictionary = items[k]
		var holder := Node3D.new()
		holder.name = "Furniture_%d" % k
		holder.position = Vector3(float(item.at[0]), 0, float(item.at[1]))
		holder.rotation.y = int(item.turn) * PI / 2
		node.add_child(holder)
		PROPS.build_item(self, holder, item, node.position + holder.position)
	if int(room.type) != OFFICE.ARCHIVE and int(room.type) != OFFICE.MOBILE_ARCHIVE: return
	var cell := Rect2(float(room.px) - float(room.span_x) / 2, float(room.pz) - float(room.span_z) / 2, float(room.span_x), float(room.span_z))
	for unit in manifest.get("archives", []):
		if not unit.rooms.has(int(room.id)): continue
		for r in unit.rows:
			var piece := Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1])).intersection(cell)
			if piece.size.x < 0.05 or piece.size.y < 0.05: continue
			# A row runs across the unit's axis, from the spine to the long wall.
			var along_x := piece.size.x >= piece.size.y
			var centre := Vector3(piece.get_center().x - float(room.px), 0, piece.get_center().y - float(room.pz))
			var length: float = piece.size.x if along_x else piece.size.y
			var depth: float = piece.size.y if along_x else piece.size.x
			PROPS.row(self, node, centre, length, depth, float(unit.height), along_x, bool(unit.mobile), node.position + centre)

## Archives are all shelving: no dressing on their walls (9.5).
func wall_stretches(room: Dictionary) -> Array:
	if int(room.type) == OFFICE.ARCHIVE or int(room.type) == OFFICE.MOBILE_ARCHIVE: return []
	return super(room)

## Furniture keeps clear of the walls by less in an office (H3).
func nav_agent_radius() -> float: return 0.3
