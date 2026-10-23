extends "res://game/world/hotel/hotel_geometry.gd"
## The offices' geometry (.claude/specs/spec_f1_geometry.md) as step 1d begins
## it: the hotel's, through its hooks, on the office's finishes. Until the
## office's own materials are ingested (spec 4.4 and 10), each finish the
## palette names stands in as the nearest hotel material, marked "stand_in".
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
## A finish of the office palette (floor_finish(), wall_material()) and the
## hotel material that stands in for it.
const STAND_INS := {"tgrid": "metal", "troffer_body": "metal", "troffer_lens": "light", "lens_off": "light_off", "grille_metal": "metal", "plenum_dark": "black", "veneer": "panel", "laminate": "wood", "enamel": "ceramic", "steel_olive": "metal", "steel_frame": "metal", "cardboard": "fabric", "bottle": "mirror", "partition_fabric": "fabric", "steel_plate": "metal", "cage_mesh": "metal", "gate_steel": "metal", "cork": "leather"}
const PROPS := preload("res://game/world/office/office_props.gd")
const GATE := preload("res://game/world/office/scissor_gate.gd")
const MAIN_DUCT := preload("res://game/world/office/main_duct_geometry.gd")
## The freight car's gate (7.4): shut and open x, the fixed end's x.
const GATE_SHUT_X := 0.85
const GATE_OPEN_X := -0.62
const GATE_FIXED_X := -0.85
## Finishes that stand in as a plain colour until their scans are ingested:
## the hotel has no plain paint, block or concrete.
const PLAIN := {"office_paint": Color("c4bfae"), "block": Color("a8a59b"), "concrete": Color("8b8780"), "skirting": Color("4a4741"), "vinyl": Color("a9a493"), "terrazzo": Color("bdb6a6"), "opal": Color("f2eee4"), "plaque": Color("2f4a3a"), "switch": Color("d8d0bc")}
## The cove base along the walls and the department stripe in the corridors
## (spec 4.1): height and thickness; bottom and top.
const SKIRT := Vector2(0.10, 0.006)
const STRIPE := Vector2(1.05, 1.20)
const STRIPE_PROUD := 0.003
## A glazed run (6.3): sill and head heights, mullions and the glass.
const GLASS_SILL := 0.95
const GLASS_HEAD := 2.65
const MULLION := 0.05
const MULLION_PITCH := 1.2
const GLASS_THICK := 0.008
const BLIND_PITCH := 0.022
const BLIND := preload("res://game/presentation/shaders/venetian_blind.gdshader")
## A door's plaque on the wall (6.7): size, height, distance past the frame.
const PLAQUE := Vector2(0.26, 0.09)
const PLAQUE_Y := 1.55
const PLAQUE_FROM_JAMB := 0.22
const SWITCH_Y := 1.15
## A wall boundary's name (hotel walls(): "Wall_<dx>_<dz>") and its side.
const SIDE_OF := {"Wall_-1_0": "west", "Wall_1_0": "east", "Wall_0_-1": "north", "Wall_0_1": "south"}
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
const LAMP_ATTENUATION := 0.9      # flatter than the hotel's 1.25: offices are evenly lit
const FAILING := 0.12              # lit rooms with one failing troffer (vary salt 160)

func _init() -> void:
	super()
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.72, 0.8, 0.78, 0.18)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.8
	glass.set_meta("stand_in", true)
	materials["wired_glass"] = glass
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
	# One troffer of some lit rooms fails (salt 160, which one 164): its lens
	# flickers whole, the room's light by its share (room_lamp(), H5).
	var failing := -1
	failing_lens = ""
	if not dark_room(room) and not lamps.is_empty() and vary(node.position, 160) < FAILING:
		failing = int(vary(node.position, 164) * lamps.size()) % lamps.size()
		failing_lens = "troffer_fail_%d" % flickers.size()
		materials[failing_lens] = materials.troffer_lens.duplicate()
		failing_share = 1.0 / lamps.size()
	for k in lamps.size():
		var lamp: Dictionary = lamps[k]
		var size := Vector3(0.6, TROFFER_BODY, 1.2) if bool(lamp.along_z) else Vector3(1.2, TROFFER_BODY, 0.6)
		var at := Vector3(lamp.centre.x, 0, lamp.centre.y) - origin
		box(node, at + Vector3(0, h + TILE_FACE + TROFFER_BODY * 0.5, 0), size, "troffer_body")
		box(node, at + Vector3(0, h + LENS_RECESS, 0), Vector3(size.x - 0.04, 0.01, size.z - 0.04), failing_lens if k == failing else lens)
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
## The failing troffer's lens of the room being built (ceiling() to
## room_lamp()) and its share of the room's light.
var failing_lens := ""
var failing_share := 1.0
## The corridor cells whose zone name is already on a stripe.
var labelled := {}

func build_room(node: Node3D, room: Dictionary) -> void:
	building_room = room
	super(node, room)
	building_room = {}

## The main duct of planta 3 (spec_f1_systems 4.5), its own holder, and the
## outer boxes the walls it crosses leave open.
var main_duct: Node3D = null
var duct_holes: Array[AABB] = []

## The hotel's build, then the main duct and the shaft: after the navigation
## bake, which nobody crawls, and before the physics check, which sees them.
func build(data: Dictionary) -> void:
	duct_holes = MAIN_DUCT.outer_boxes(data)
	await super(data)
	if data.has("air") and data.air.has("main"):
		main_duct = MAIN_DUCT.build(self, data)
		add_child(main_duct)

## Dirección is in lockdown (OFICINAS, planta 3): no power, every room dark
## but those always lit (the arrival lobby, the security post), on top of the
## dark rooms the manifest draws.
func decide_dark(data: Dictionary) -> void:
	super(data)
	var kept: Array = OFFICE.always_lit(data, 2)
	for room in data.rooms:
		if int(room.get("wing", 0)) == 2 and not kept.has(int(room.id)): dark_ids[int(room.id)] = true

## A room's power cut or given back (planta 2's board, spec_f1_systems 3):
## its troffer lenses, battens and globes go dark with its lamp, or they
## would glow over a room with no light.
func set_room_power(room_id: int, on: bool) -> void:
	super(room_id, on)
	if room_id < 0 or room_id >= room_nodes.size(): return
	var glowing: bool = on and not dark and not dark_ids.has(room_id)
	var off: Material = materials.get("lens_off", materials.get("light_off"))
	for mesh in lenses_of(room_id): mesh.material_override = null if glowing else off

## The meshes that glow with a room's lamp, found once.
var room_lenses := {}
func lenses_of(room_id: int) -> Array:
	if room_lenses.has(room_id): return room_lenses[room_id]
	var found: Array = []
	for pattern in ["Mesh_troffer_lens*", "Mesh_light*"]:
		for node in room_nodes[room_id].find_children(pattern, "GeometryInstance3D", true, false):
			if not "_off" in String(node.name): found.append(node)
	room_lenses[room_id] = found
	return found

## Out of sight off planta 3, like every room of the other plantas.
func put_away(here: int) -> void:
	super(here)
	if is_instance_valid(main_duct): main_duct.visible = here == 2

## Where the main duct crosses this stretch of wall: [x0, x1, y0, y1] in the
## boundary's own frame. Only the tall rooms' walls reach the duct's floor.
func duct_cuts(boundary: Node3D, x: float, length: float, height: float) -> Array:
	var cuts: Array = []
	var room_node := boundary.get_parent() as Node3D
	if duct_holes.is_empty() or room_node == null: return cuts
	var to_local := (room_node.transform * boundary.transform).affine_inverse()
	for box in duct_holes:
		var low := Vector3(INF, INF, INF)
		var high := -low
		for i in 8:
			var p: Vector3 = to_local * box.get_endpoint(i)
			low = low.min(p)
			high = high.max(p)
		if low.z > 0.09 or high.z < -0.09 or low.y >= height: continue
		var a := maxf(low.x, x - length * 0.5)
		var b := minf(high.x, x + length * 0.5)
		if b - a > 0.01: cuts.append([a, b, maxf(low.y, 0.0), minf(high.y, height)])
	return cuts

## An office wall (6.2): plain paint, a cove base on this room's face, and in
## a corridor its department's stripe; none of the hotel's dado, rails,
## sockets or cornice.
func wall_run(boundary: Node3D, x: float, length: float, height: float, inner: int) -> void:
	var side := String(SIDE_OF.get(String(boundary.name), ""))
	if not building_room.is_empty() and building_room.get("glazed", []).has(side):
		glazed_run(boundary, x, length, height, inner)
		return
	# The main duct through a tall room's wall: the stretch either side as
	# usual, and over the opening only the wall under and over it.
	var cuts := duct_cuts(boundary, x, length, height) if height > 3.0 else []
	if not cuts.is_empty():
		var cut: Array = cuts[0]
		var left := float(cut[0]) - (x - length * 0.5)
		var right := x + length * 0.5 - float(cut[1])
		if left > 0.01: wall_run(boundary, x - length * 0.5 + left * 0.5, left, height, inner)
		if right > 0.01: wall_run(boundary, float(cut[1]) + right * 0.5, right, height, inner)
		var mid := float(cut[1]) - float(cut[0])
		var mx := (float(cut[0]) + float(cut[1])) * 0.5
		if float(cut[2]) > 0.01:
			wall_core(boundary, Vector3(mx, float(cut[2]) * 0.5, 0), Vector3(mid, float(cut[2]), 0.18), inner)
			box(boundary, Vector3(mx, SKIRT.x * 0.5, inner * (0.09 + SKIRT.y * 0.5)), Vector3(mid, SKIRT.x, SKIRT.y), "skirting")
		if float(cut[3]) < height - 0.01: wall_core(boundary, Vector3(mx, (float(cut[3]) + height) * 0.5, 0), Vector3(mid, height - float(cut[3]), 0.18), inner)
		return
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
	# Once a corridor cell, on its first run long enough, the zone's name on
	# the stripe.
	if length < 3.0 or labelled.has(int(building_room.id)): return
	var label: String = OFFICE.zone_label(manifest, building_room)
	if label.is_empty(): return
	labelled[int(building_room.id)] = true
	text(boundary, label, Vector3(x, (STRIPE.x + STRIPE.y) * 0.5, inner * (0.09 + STRIPE_PROUD + 0.004)), 0.0 if inner > 0 else PI, 12, NUMBER_REACH, Color("f1ead8"))

## A glazed run (6.3): sill and head as wall, the glass between with its
## collider and a mullion every MULLION_PITCH. Both rooms build their half of
## the sill and head; the glass and mullions only the room whose west or
## north side it is (inner > 0), so the pane is there once.
func glazed_run(boundary: Node3D, x: float, length: float, height: float, inner: int) -> void:
	wall_core(boundary, Vector3(x, GLASS_SILL / 2, 0), Vector3(length, GLASS_SILL, 0.18), inner)
	wall_core(boundary, Vector3(x, (GLASS_HEAD + height) / 2, 0), Vector3(length, height - GLASS_HEAD, 0.18), inner)
	var room_node := boundary.get_parent() as Node3D
	plan_wall(room_node, boundary.transform * Vector3(x - length * 0.5, 0, 0), boundary.transform * Vector3(x + length * 0.5, 0, 0))
	box(boundary, Vector3(x, SKIRT.x * 0.5, inner * (0.09 + SKIRT.y * 0.5)), Vector3(length, SKIRT.x, SKIRT.y), "skirting")
	if inner < 0: return
	var band := GLASS_HEAD - GLASS_SILL
	box(boundary, Vector3(x, GLASS_SILL + band * 0.5, 0), Vector3(length, band, 0.06), "", true)
	box(boundary, Vector3(x, GLASS_SILL + band * 0.5, 0), Vector3(length, band, GLASS_THICK), "wired_glass")
	var count := maxi(1, roundi(length / MULLION_PITCH))
	for k in count + 1:
		var at := x - length * 0.5 + length * k / count
		box(boundary, Vector3(at, GLASS_SILL + band * 0.5, 0), Vector3(MULLION, band, 0.06), "steel_frame")
	for y in [GLASS_SILL, GLASS_HEAD]: box(boundary, Vector3(x, y, 0), Vector3(length, MULLION, 0.07), "steel_frame")
	# Blinds on the office side of each pane (6.4), not the corridor's.
	var office_side: int = -inner if int(building_room.type) in [OFFICE.CORRIDOR, OFFICE.GALLERY] else inner
	for k in count:
		var pane := length / count
		var centre := x - length * 0.5 + pane * (k + 0.5)
		var spot := (room_node.position if room_node != null else Vector3.ZERO) + boundary.transform * Vector3(centre, 0, 0)
		var roll := vary(spot, 170)
		var blind := ShaderMaterial.new()
		blind.shader = BLIND
		blind.set_shader_parameter("pitch", BLIND_PITCH)
		blind.set_shader_parameter("height", band)
		blind.set_shader_parameter("open", 0.05 if roll < 0.33 else 0.0 if roll >= 0.66 else 0.35 + vary(spot, 171) * 0.3)
		blind.set_shader_parameter("drop", 1.0 if roll < 0.66 else 0.25 / band)
		var quad := QuadMesh.new()
		quad.size = Vector2(pane - MULLION, band - 0.06)
		quad.material = blind
		var sheet := MeshInstance3D.new()
		sheet.mesh = quad
		sheet.position = Vector3(centre, GLASS_SILL + band * 0.5 - 0.03, office_side * 0.045)
		boundary.add_child(sheet)
		box(boundary, Vector3(centre, GLASS_HEAD - 0.05, office_side * 0.045), Vector3(pane - MULLION, 0.04, 0.04), "steel_frame")

## The freight car (7.4) inside the hotel's CAR_INSIDE, so riding, arriving
## and the car's rect are untouched: a steel floor, sides and back of steel
## plate to 1.1 m and cage mesh above, a steel roof, corner posts, a guarded
## bulb, and the scissor gate as its leaves.
func car_body(car: Node3D, _room: Dictionary) -> Array:
	var inside := CAR_INSIDE
	var centre := inside.get_center()
	var top := inside.end.y
	box(car, Vector3(centre.x, 0.01, centre.z), Vector3(inside.size.x, 0.02, inside.size.z), "steel_plate")
	box(car, Vector3(centre.x, top + 0.01, centre.z), Vector3(inside.size.x, 0.02, inside.size.z), "steel_plate")
	for band in [[0.0, 1.1, "steel_plate"], [1.1, top, "cage_mesh"]]:
		var low: float = band[0]
		var high: float = band[1]
		var y := (low + high) * 0.5
		box(car, Vector3(centre.x, y, inside.position.z - 0.01), Vector3(inside.size.x, high - low, 0.02), String(band[2]))
		for x in [inside.position.x - 0.01, inside.end.x + 0.01]: box(car, Vector3(x, y, centre.z), Vector3(0.02, high - low, inside.size.z), String(band[2]))
	for x in [inside.position.x, inside.end.x]:
		for z in [inside.position.z, inside.end.z]: box(car, Vector3(x, top * 0.5, z), Vector3(0.05, top, 0.05), "gate_steel")
	box(car, Vector3(centre.x, top - 0.08, centre.z), Vector3(0.1, 0.1, 0.1), "light")
	var gate = GATE.new()
	gate.name = "ScissorGate"
	gate.material = materials.gate_steel
	gate.fixed_x = GATE_FIXED_X
	gate.position = Vector3(GATE_SHUT_X, 0, -0.03)
	car.add_child(gate)
	return [{"node": gate, "shut": GATE_SHUT_X, "open": GATE_OPEN_X}]

## The car's one lamp, warm as a bulb (7.4).
func build_car(room: Dictionary, facing: Vector2i) -> Vector3:
	var at := super(room, facing)
	car_lamps.back().light_color = LIGHTING.light_color(2700.0)
	return at

## The lift the floor is come down by (7.7): on the reception's wall that
## arrival_lift names, the hotel lift's front, shut, in a steel casing; its
## screen dark, no car behind it and nothing to use (phase 5's).
func arrival_lift(node: Node3D, room: Dictionary) -> void:
	var back := Vector3(float(manifest.arrival_lift[0]), 0, float(manifest.arrival_lift[1]))
	var span := FLOOR.size_of(room)
	var half: float = span.x * 0.5 if back.x != 0 else span.y * 0.5
	var front := Node3D.new()
	front.name = "ArrivalLift"
	front.position = back * (half - 0.09 - LIFT_PROUD)
	front.rotation.y = atan2(-back.x, -back.z)
	node.add_child(front)
	var bounds := AABB()
	for k in LIFT_LEAVES.size():
		var leaf := MeshInstance3D.new()
		leaf.name = "Leaf"
		leaf.mesh = LIFT_LEAVES[k]
		front.add_child(leaf)
		bounds = LIFT_LEAVES[k].get_aabb() if k == 0 else bounds.merge(LIFT_LEAVES[k].get_aabb())
	for part in [[LIFT_CALL, Vector3(CALL_AT.x, CALL_AT.y, 0.0)], [LIFT_SCREEN, Vector3(0, SCREEN_AT, 0.0)]]:
		var piece := MeshInstance3D.new()
		piece.mesh = part[0]
		piece.position = part[1]
		front.add_child(piece)
	# The casing round the leaves.
	var x0 := bounds.position.x - 0.04
	var x1 := bounds.end.x + 0.04
	var top := bounds.end.y + 0.04
	for x in [x0, x1]: box(front, Vector3(x, top * 0.5, 0.02), Vector3(0.08, top, 0.04), "steel_frame")
	box(front, Vector3((x0 + x1) * 0.5, top, 0.02), Vector3(x1 - x0 + 0.08, 0.08, 0.04), "steel_frame")

## The cars of the stage gates (7.8): Dirección's is a shaft, with no car
## at either end, so it files the empty entries the hotel's own branches do and
## every list keeps one entry per gate. The other gates are the hotel's.
func build_lifts(data: Dictionary) -> void:
	for gate in data.get("gates", []):
		if String(gate.get("kind", "lift")) == "shaft":
			lifts.append(Vector3.ZERO)
			car_frames.append(Transform3D())
			depart_leaves.append([])
			arrivals.append(Vector3.ZERO)
			arrive_leaves.append([])
			arrival_cars.append(Vector3.ZERO)
			arrival_facing.append(Vector3.ZERO)
			continue
		var out: Array = gate.get("out", [1, 0])
		var lobby := int(gate.get("beyond", -1))
		lifts.append(build_car(data.rooms[lobby], Vector2i(-int(out[0]), -int(out[1]))) if lobby >= 0 else Vector3.ZERO)
		car_frames.append(car_frame if lobby >= 0 else Transform3D())
		depart_leaves.append(car_leaves.duplicate() if lobby >= 0 else [])
		var arrive := int(gate.get("arrive", -1))
		if arrive < 0:
			arrivals.append(Vector3.ZERO)
			arrive_leaves.append([])
			arrival_cars.append(Vector3.ZERO)
			arrival_facing.append(Vector3.ZERO)
			continue
		var facing := Vector2i(-int(out[0]), -int(out[1]))
		var car := build_car(data.rooms[arrive], facing)
		arrive_leaves.append(car_leaves.duplicate())
		arrival_cars.append(car)
		arrival_facing.append(Vector3(facing.x, 0, facing.y))
		arrivals.append(car + Vector3(facing.x, 0, facing.y) * 1.8)

## No exit door on a shaft (7.8): the air room and the plant are one salon,
## and the way out is the ladder (1g).
func build_exit_door(data: Dictionary) -> void:
	var gates_list: Array = data.get("gates", [])
	if not gates_list.is_empty() and String(gates_list[-1].get("kind", "lift")) == "shaft": return
	super(data)

## The light switch beside the door (6.1): a beige plastic rocker plate at
## SWITCH_Y instead of the hotel's brass one.
func switch_plate(boundary: Node3D, x: float, inner: int) -> void:
	box(boundary, Vector3(x, SWITCH_Y, inner * 0.094), Vector3(0.08, 0.12, 0.008), "switch", false, "detail")
	box(boundary, Vector3(x, SWITCH_Y, inner * 0.1), Vector3(0.03, 0.05, 0.008), "switch", false, "detail", Vector3(inner * -0.2, 0, 0))

## The hotel hangs a vent grille on a bare wall; the offices' grilles are
## the duct network's (extras(), ceiling()).
func grille(_boundary: Node3D, _x: float, _inner: int) -> void: pass

## What hangs on an office wall instead of the hotel's paintings and sconces
## (6.5), by vary: a cork notice board in offices and corridors, the hotel's
## wall clock in offices, the break room and the archives; otherwise the spot
## is kept for 1h's rule posters (poster_spots). Nothing on glass.
func wall_art(boundary: Node3D, room: Dictionary, at: float, inner: int) -> void:
	if room.get("glazed", []).has(String(SIDE_OF.get(String(boundary.name), ""))): return
	var t := int(room.type)
	var roll := vary(node_point(boundary, at), 170)
	var face := inner * 0.09
	var turn := Basis(Vector3.UP, PI if inner < 0 else 0.0)
	if t in [OFFICE.OFFICE, OFFICE.EXEC_OFFICE, OFFICE.CORRIDOR] and roll < 0.4:
		box(boundary, Vector3(at, 1.5, face + inner * 0.012), Vector3(1.2, 0.9, 0.02), "cork")
		box(boundary, Vector3(at, 1.5, face + inner * 0.01), Vector3(1.26, 0.96, 0.016), "steel_frame")
	elif t in [OFFICE.OFFICE, OFFICE.EXEC_OFFICE, OFFICE.BREAK_ROOM, OFFICE.ARCHIVE] and roll < 0.7:
		DRESSING.place(self, boundary, "wall_clock", Transform3D(turn, Vector3(at, 2.05, face + inner * 0.027)))
	else:
		poster_spots.append({"room": int(room.id), "transform": boundary.global_transform * Transform3D(turn, Vector3(at, 1.5, face + inner * 0.005)) if boundary.is_inside_tree() else Transform3D(turn, Vector3(at, 1.5, face))})

## A point along a wall boundary, for vary().
func node_point(boundary: Node3D, at: float) -> Vector3:
	var room_node := boundary.get_parent() as Node3D
	return (room_node.position if room_node != null else Vector3.ZERO) + boundary.transform * Vector3(at, 0, 0)

## Free wall spots for 1h's rule posters: {room, transform}.
var poster_spots: Array[Dictionary] = []

## The troffers (built by ceiling()) light the room as a fluorescent tube
## does (7.1); the battens and the boardroom's pendant are the hotel's.
func lamp_fixture(node: Node3D, room: Dictionary) -> Dictionary:
	var lamp: String = OFFICE.lamp_of(room)
	var h := float(room.height)
	var tube := {"tube": true, "failing": "", "specular": 0.45, "color": LIGHTING.light_color(LIGHTING.FLUORESCENT, LIGHTING.TUBE_TINT), "energy": LAMP_ENERGY * LIGHTING.PROFILE_GAIN, "profile": LIGHTING.profile("tube"), "position": Vector3(0, h - LAMP_DROP, 0)}
	match lamp:
		"troffer":
			return tube
		"batten":
			if not archive_battens(node, room): return super(node, room)
			tube.energy = float(tube.energy) * 0.85
			return tube
		"pendant":
			# Two opal globes on rods over the meeting table.
			var at := Vector3.ZERO
			var long := Vector3(1, 0, 0)
			for item in room.get("furniture", []):
				if String(item.kind) != "meeting_table": continue
				at = Vector3(float(item.at[0]), 0, float(item.at[1]))
				long = Vector3(1, 0, 0) if int(item.turn) % 2 == 0 else Vector3(0, 0, 1)
			for side in [-1.0, 1.0]:
				var globe: Vector3 = at + long * float(side) * 0.9
				box(node, globe + Vector3(0, (h + 2.25) * 0.5, 0), Vector3(0.012, h - 2.25, 0.012), "metal", false, "cylinder")
				box(node, globe + Vector3(0, 2.15, 0), Vector3(0.32, 0.32, 0.32), "light_off" if dark_room(room) else "light", false, "cylinder")
			return {"tube": false, "failing": "", "specular": 0.6, "color": LIGHTING.light_color(3000.0), "energy": 3.6 * LIGHTING.PROFILE_GAIN, "profile": LIGHTING.profile("dome"), "position": at + Vector3(0, 2.0, 0)}
		"emergency":
			# No lamp of its own: the electrical room's battery unit lights it (7.2).
			tube.energy = 0.0
			return tube
	return super(node, room)

## Over each narrow aisle of an archive cell, a fluorescent batten on chains
## along the aisle (7.1); false when the room has no aisles here.
func archive_battens(node: Node3D, room: Dictionary) -> bool:
	if int(room.type) != OFFICE.ARCHIVE and int(room.type) != OFFICE.MOBILE_ARCHIVE: return false
	var cell := Rect2(float(room.px) - float(room.span_x) / 2, float(room.pz) - float(room.span_z) / 2, float(room.span_x), float(room.span_z))
	var y := minf(float(room.height) - 0.6, 2.9)
	var any := false
	for unit in manifest.get("archives", []):
		if not unit.rooms.has(int(room.id)): continue
		for a in unit.aisles:
			var piece := Rect2(float(a[0]), float(a[1]), float(a[2]) - float(a[0]), float(a[3]) - float(a[1])).intersection(cell)
			if piece.size.x < 0.3 or piece.size.y < 0.3: continue
			var along_x := piece.size.x >= piece.size.y
			var length := minf(1.5, maxf(piece.size.x, piece.size.y) - 0.3)
			var at := Vector3(piece.get_center().x - float(room.px), y, piece.get_center().y - float(room.pz))
			box(node, at, Vector3(length, 0.07, 0.16) if along_x else Vector3(0.16, 0.07, length), "metal")
			box(node, at - Vector3(0, 0.05, 0), Vector3(length - 0.1, 0.03, 0.05) if along_x else Vector3(0.05, 0.03, length - 0.1), "light_off" if dark_room(room) else "light")
			any = true
	return any

## The electrical room's lamp is made (lights[id] must exist) but stays out.
func room_lamp(node: Node3D, room: Dictionary) -> void:
	var light := lamp_light(node, room, lamp_fixture(node, room))
	if OFFICE.lamp_of(room) == "troffer":
		light.omni_attenuation = LAMP_ATTENUATION
		if not failing_lens.is_empty():
			flickers.append({"light": light, "energy": light.light_energy, "phase": vary(node.position, 9) * 50.0, "material": materials[failing_lens], "glow": materials.troffer_lens.emission_energy_multiplier, "share": failing_share})
	failing_lens = ""
	if OFFICE.lamp_of(room) == "emergency":
		light.set_meta("off", true)
		light.visible = false

## Door plaques (6.7, H2): not on the leaf but on the wall beside the door,
## latch side, PLAQUE_FROM_JAMB past the frame: the number of the room behind
## (OFFICE.plaque()) on the face of the room it is read from, parented to
## that room so it batches and layers with it. Not yet kept off reserved spots.
func door_plaques(_door: Node3D, a: Dictionary, b: Dictionary, center: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var normal := turn.z
	var along := turn.x
	for pair in [[a, b], [b, a]]:
		var viewer: Dictionary = pair[0]
		var behind: Dictionary = pair[1]
		var words: String = OFFICE.plaque(behind)
		if words.is_empty(): continue
		var side := signf((FLOOR.position_of(viewer) - center).dot(normal))
		var holder: Node3D = room_nodes[int(viewer.id)]
		var at := center + along * (FLOOR.PORTAL * 0.5 + 0.05 + PLAQUE_FROM_JAMB + PLAQUE.x * 0.5) + normal * side * (0.09 + 0.002) + Vector3(0, PLAQUE_Y, 0) - holder.position
		box(holder, at, Vector3(PLAQUE.x, PLAQUE.y, 0.004), "plaque", false, "box", Vector3(0, yaw, 0))
		text(holder, words, at + normal * side * 0.004, yaw + (0.0 if side > 0 else PI), 20, NUMBER_REACH, Color("e8e4d6"))

## The office's lockers (9.7): the wardrobe's measures and hinges in olive
## steel, louvred at eye height, made once and kept (the baked locker of
## tools/props/build_locker.gd stands for later).
static var locker := {}
const WARDROBE := preload("res://game/world/interactables/hiding_place.gd")

func hide_skin(_room: Dictionary) -> Dictionary:
	if locker.is_empty():
		var steel := StandardMaterial3D.new()
		steel.albedo_color = Color("5f6650")
		steel.metallic = 0.5
		steel.roughness = 0.55
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color("1c1d19")
		var shell := WARDROBE.BODY.get_aabb()
		var body := SurfaceTool.new()
		body.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in [[Vector3(shell.size.x, shell.size.y, 0.02), Vector3(shell.get_center().x, shell.get_center().y, shell.position.z + 0.01)], [Vector3(0.02, shell.size.y, shell.size.z), Vector3(shell.position.x + 0.01, shell.get_center().y, shell.get_center().z)], [Vector3(0.02, shell.size.y, shell.size.z), Vector3(shell.end.x - 0.01, shell.get_center().y, shell.get_center().z)], [Vector3(shell.size.x, 0.02, shell.size.z), Vector3(shell.get_center().x, shell.end.y - 0.01, shell.get_center().z)], [Vector3(shell.size.x, 0.02, shell.size.z), Vector3(shell.get_center().x, shell.position.y + 0.01, shell.get_center().z)]]:
			var piece := BoxMesh.new()
			piece.size = part[0]
			body.append_from(piece, 0, Transform3D(Basis.IDENTITY, part[1]))
		var body_mesh := body.commit()
		body_mesh.surface_set_material(0, steel)
		locker["body"] = body_mesh
		for side in ["left", "right"]:
			var leaf_mesh: Mesh = WARDROBE.LEAVES[side]
			var bounds := leaf_mesh.get_aabb()
			var mesh := ArrayMesh.new()
			var face := SurfaceTool.new()
			face.begin(Mesh.PRIMITIVE_TRIANGLES)
			var slab := BoxMesh.new()
			slab.size = bounds.size
			face.append_from(slab, 0, Transform3D(Basis.IDENTITY, bounds.get_center()))
			face.commit(mesh)
			mesh.surface_set_material(0, steel)
			var slots := SurfaceTool.new()
			slots.begin(Mesh.PRIMITIVE_TRIANGLES)
			for k in 5:
				var slot := BoxMesh.new()
				slot.size = Vector3(bounds.size.x * 0.5, 0.012, bounds.size.z + 0.004)
				slots.append_from(slot, 0, Transform3D(Basis.IDENTITY, Vector3(bounds.get_center().x, 1.55 + k * 0.035, bounds.get_center().z)))
			slots.commit(mesh)
			mesh.surface_set_material(1, dark)
			if leaf_mesh.has_meta("hinge"): mesh.set_meta("hinge", leaf_mesh.get_meta("hinge"))
			locker[side] = mesh
	return locker

## Office doors (6.6), made once and kept: the hotel leaf's bounds and
## conventions (hinge at the origin, the leaf along +X, centred on its
## thickness), so the seal, the collider, the swing and the halves are the
## hotel's. A painted leaf with a vision panel; a steel one with a panic bar
## for service rooms, the plant rooms and the stage gates; a pressed-steel frame.
static var office_doors := {}

func leaf_mesh(a: Dictionary, b: Dictionary) -> Mesh:
	var steel: bool = bool(a.get("service", false)) or bool(b.get("service", false)) or [int(a.type), int(b.type)].any(func(t): return t in [OFFICE.ELECTRICAL, OFFICE.AIR_ROOM, OFFICE.AIR_PLANT]) or gate_stage(manifest, int(a.id), int(b.id)) > 0
	var key := "service" if steel else "vision"
	if not office_doors.has(key): office_doors[key] = door_leaf_mesh(steel)
	return office_doors[key]

func frame_mesh(_a: Dictionary, _b: Dictionary) -> Mesh:
	if not office_doors.has("frame"): office_doors["frame"] = door_frame_mesh()
	return office_doors["frame"]

## A flat leaf the hotel leaf's size; its face one surface, the vision panel
## (or the panic bar) another.
func door_leaf_mesh(steel: bool) -> ArrayMesh:
	var bounds := DOOR_LEAF.get_aabb()
	var mesh := ArrayMesh.new()
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slab := BoxMesh.new()
	slab.size = bounds.size
	face.append_from(slab, 0, Transform3D(Basis.IDENTITY, bounds.get_center()))
	face.commit(mesh)
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("6f7069") if steel else Color("9a8f78")
	paint.roughness = 0.5 if steel else 0.75
	paint.metallic = 0.6 if steel else 0.0
	mesh.surface_set_material(0, paint)
	var extra := SurfaceTool.new()
	extra.begin(Mesh.PRIMITIVE_TRIANGLES)
	var piece := BoxMesh.new()
	if steel:
		# The panic bar across the push side, at 1.0.
		piece.size = Vector3(bounds.size.x * 0.75, 0.05, 0.05)
		extra.append_from(piece, 0, Transform3D(Basis.IDENTITY, Vector3(bounds.get_center().x, 1.0, bounds.size.z * 0.5 + 0.04)))
	else:
		# The vision panel, 0.2 by 0.6 from 1.15 to 1.75, proud of both faces.
		piece.size = Vector3(0.2, 0.6, bounds.size.z + 0.004)
		extra.append_from(piece, 0, Transform3D(Basis.IDENTITY, Vector3(bounds.get_center().x, 1.45, bounds.get_center().z)))
	extra.commit(mesh)
	mesh.surface_set_material(1, materials.steel_frame if steel else materials.wired_glass)
	return mesh

## A pressed-steel frame round the doorway: two jambs and a head.
func door_frame_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := FLOOR.PORTAL * 0.5
	for part in [[Vector3(0.05, OPENING_HIGH, 0.22), Vector3(-half - 0.025, OPENING_HIGH * 0.5, 0)], [Vector3(0.05, OPENING_HIGH, 0.22), Vector3(half + 0.025, OPENING_HIGH * 0.5, 0)], [Vector3(FLOOR.PORTAL + 0.1, 0.05, 0.22), Vector3(0, OPENING_HIGH + 0.025, 0)]]:
		var box_mesh := BoxMesh.new()
		box_mesh.size = part[0]
		tool.append_from(box_mesh, 0, Transform3D(Basis.IDENTITY, part[1]))
	var mesh := tool.commit()
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("5d5f5a")
	steel.metallic = 0.5
	steel.roughness = 0.55
	mesh.surface_set_material(0, steel)
	return mesh

## The office's corner pieces first (9.3); the hotel's own kinds as the hotel.
func build_prop(node: Node3D, kind: String) -> void:
	if not PROPS.build(self, node, kind): super(node, kind)

## An archive cell's share of its unit's rows (9.4): each row rectangle cut
## at the cell's edges and built under the cell, so it batches and layers
## with it.
func extras(node: Node3D, room: Dictionary) -> void:
	super(node, room)
	# The duct network's low wall grilles (ducts.exits of kind "wall"), where
	# the generator put them: a frame and slats over the dark of the duct.
	for e in manifest.get("ducts", {}).get("exits", []):
		if int(e.room) != int(room.id) or String(e.kind) != "wall": continue
		var at := Vector3(float(e.point[0]), float(e.point[1]), float(e.point[2])) - node.position
		var face := Basis(Vector3.UP, float(e.yaw)).z
		var flat: bool = absf(face.z) > 0.5
		box(node, at + face * 0.002, Vector3(0.45, 0.25, 0.004) if flat else Vector3(0.004, 0.25, 0.45), "black")
		for k in 5: box(node, at + face * 0.01 + Vector3(0, -0.1 + k * 0.05, 0), Vector3(0.43, 0.012, 0.016) if flat else Vector3(0.016, 0.012, 0.43), "grille_metal")
	if int(room.id) == int(manifest.get("start", -1)) and manifest.has("arrival_lift"): arrival_lift(node, room)
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
