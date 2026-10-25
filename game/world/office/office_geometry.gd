extends "res://game/world/hotel/hotel_geometry.gd"
## The offices' geometry (.claude/specs/spec_f1_geometry.md) as step 1d begins
## it: the hotel's, through its hooks, on the office's finishes. Until the
## office's own materials are ingested (spec 4.4 and 10), each finish the
## palette names stands in as the nearest hotel material, marked "stand_in".
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
## A finish of the office palette (floor_finish(), wall_material()) and the
## hotel material that stands in for it.
const STAND_INS := {"tgrid": "metal", "troffer_body": "metal", "troffer_lens": "light", "lens_off": "light_off", "grille_metal": "metal", "plenum_dark": "black", "veneer": "panel", "laminate": "wood", "enamel": "ceramic", "steel_olive": "metal", "steel_frame": "metal", "cardboard": "fabric", "bottle": "mirror", "partition_fabric": "fabric", "steel_plate": "metal", "cage_mesh": "metal", "gate_steel": "metal", "cork": "leather", "walnut": "trim", "walnut_object": "trim", "oak_door": "door"}
const PROPS := preload("res://game/world/office/office_props.gd")
const GATE := preload("res://game/world/office/scissor_gate.gd")
const MAIN_DUCT := preload("res://game/world/office/main_duct_geometry.gd")
## The freight car's gate (7.4): shut and open x, the fixed end's x.
const GATE_SHUT_X := 0.85
const GATE_OPEN_X := -0.62
const GATE_FIXED_X := -0.85
## Finishes that stand in as a plain colour until their own material is made
## (MATERIAL_DIR): the hotel has no plain paint, block or concrete.
const PLAIN := {"office_paint": Color("b9ad96"), "block": Color("c7bfa5"), "concrete": Color("807b72"), "skirting": Color("2a2420"), "vinyl": Color("b0a68f"), "terrazzo": Color("5a5650"), "opal": Color("f2eee4"), "plaque": Color("1c1b19"), "switch": Color("d8d0bc"), "taupe": Color("857866"), "two_tone_low": Color("7e8174"), "partition": Color("aea594"), "quarry": Color("74695a"), "threshold": Color("9c9686"), "slab": Color("7c7a74")}
## Where the office's own materials are (spec_rediseno 8): a key's <key>.tres
## there takes the place of its stand-in, or of the hotel material of the same
## name (OWN_OVER: the carpet, the ceiling tile).
const MATERIAL_DIR := "res://game/presentation/materials/office/%s.tres"
const OWN_OVER := ["carpet", "ceiling_service"]
## The cove base along the walls (spec 4.1): height and thickness.
const SKIRT := Vector2(0.10, 0.006)
## The lower wall (spec_rediseno 2, wall_trim()): the frieze's taupe up to
## FRIEZE_TOP under a walnut rail (height, proud), the walnut dado up to
## DADO_TOP and its cap (height, proud), the air rooms' darker paint up to
## TWO_TONE_TOP; paint is LINING proud of the wall, the dado DADO_THICK. The
## rail stays inside a door frame's 2 cm.
const FRIEZE_TOP := 1.0
const RAIL := Vector2(0.06, 0.016)
const DADO_TOP := 1.05
const DADO_CAP := Vector2(0.04, 0.018)
const DADO_THICK := 0.015
const TWO_TONE_TOP := 1.2
const LINING := 0.004
## A corridor cell's zone sign (R5): its height, the plate's height and
## depth, its width per letter and its margin, and the swatch of the zone's
## department colour.
const SIGN_Y := 1.6
const SIGN_HIGH := 0.12
const SIGN_DEPTH := 0.006
const SIGN_LETTER := 0.055
const SIGN_MARGIN := 0.03
const SWATCH := 0.05
## A notice board's frame, half its width (wall_art()): what a zone sign must clear.
const BOARD_HALF := 0.63
## A glazed run (6.3): sill and head heights, mullions and the glass.
const GLASS_SILL := 0.95
const GLASS_HEAD := 2.65
const MULLION := 0.05
const MULLION_PITCH := 1.2
const GLASS_THICK := 0.008
const BLIND_PITCH := 0.022
## The walnut sill board over a glazed run's sill wall: thickness, and how far
## past the wall's face (inside a door frame's 2 cm); its top SILL_OVER over
## the sill wall's and the lower wall's, so no two faces share a plane; the
## blinds' beige (6.4).
const SILL_BOARD := Vector2(0.03, 0.016)
const SILL_OVER := 0.002
const BLIND_COLOR := Color("cbbf9f")
const BLIND := preload("res://game/presentation/shaders/venetian_blind.gdshader")
const WIRED_GLASS := preload("res://game/presentation/shaders/wired_glass.gdshader")
## A door's plaque on the wall (6.7): size, height, distance past the frame.
const PLAQUE := Vector2(0.26, 0.09)
const PLAQUE_Y := 1.55
const PLAQUE_FROM_JAMB := 0.22
## The plaque's depth off the wall (proud of a panelled wall too), the
## doorway's frame (jamb width, how far past each face of the wall), the
## metal threshold strip across a doorway (the frame's depth, its height),
## and the share of wooden doors with a vision panel (vary salt 172).
const PLAQUE_DEPTH := 0.019
const JAMB_WIDE := 0.09
const JAMB_PROUD := 0.02
const THRESHOLD := Vector2(0.18 + JAMB_PROUD * 2.0, 0.006)
const VISION := 0.35
const SWITCH_Y := 1.15
## A wall boundary's name (hotel walls(): "Wall_<dx>_<dz>") and its side.
const SIDE_OF := {"Wall_-1_0": "west", "Wall_1_0": "east", "Wall_0_-1": "north", "Wall_0_1": "south"}
## A wall boundary's step to the cell on its other side (FLOOR.beside()).
const SIDE_STEP := {"Wall_-1_0": Vector2i(-1, 0), "Wall_1_0": Vector2i(1, 0), "Wall_0_-1": Vector2i(0, -1), "Wall_0_1": Vector2i(0, 1)}
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
	# Wired glass: a tinted pane with its square mesh of wire (6.3).
	var glass := ShaderMaterial.new()
	glass.shader = WIRED_GLASS
	materials["wired_glass"] = glass
	# Clear glass, a little dirty: the same pane without its wire.
	var clear := ShaderMaterial.new()
	clear.shader = WIRED_GLASS
	clear.set_shader_parameter("wire", 0.0)
	clear.set_shader_parameter("glass_color", Color(0.78, 0.8, 0.76, 0.12))
	materials["clear_glass"] = clear
	for key in PLAIN:
		var plain := StandardMaterial3D.new()
		plain.albedo_color = PLAIN[key]
		plain.roughness = 0.9
		plain.set_meta("stand_in", true)
		materials[key] = plain
	for key in STAND_INS:
		materials[key] = materials[STAND_INS[key]].duplicate()
		materials[key].set_meta("stand_in", true)
	for key in PLAIN.keys() + STAND_INS.keys() + OWN_OVER:
		var path: String = MATERIAL_DIR % key
		if not ResourceLoader.exists(path): continue
		materials[key] = load(path).duplicate()
		# No lite picture of its own: on Muy bajo, its flat_color.
		materials[key].set_meta("lite", "office/" + key)
		apply_scan(materials[key], small_maps)

## The office's own scans leave the static cache with their floor: scan_maps()
## keeps every set it loads, so a hotel built next in this process would carry
## the office's pictures in video memory. A set the hotel shares (officeceiling001)
## only leaves the cache; its picture stays with the hotel's own material.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE: return
	for key in materials:
		var material: Material = materials[key]
		if not material is ShaderMaterial or not material.has_meta("scan"): continue
		if not String(material.get_meta("lite", "")).begins_with("office/"): continue
		var set_name := String(material.get_meta("scan"))
		scans.erase(set_name)
		scans.erase(set_name + "_1k")

## A false ceiling of 0.6 m tiles on the world's lattice (5.2): its collider
## over the tiles, runs of tiles round the troffers, grilles and gaps, the
## T-grid, the troffers, the grilles, and the dark of the plenum over a gap.
## A room with no false ceiling shows the bare concrete slab (spec_rediseno 2).
func ceiling(node: Node3D, room: Dictionary) -> void:
	if not OFFICE.false_ceiling(room):
		# The slab itself, the plenum's concrete (spec_rediseno 2), not the
		# hotel's ceiling over its service rooms.
		var slab_span := FLOOR.size_of(room)
		box(node, Vector3(0, float(room.height) + 0.1, 0), Vector3(slab_span.x, 0.2, slab_span.y), "slab", true)
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
			# Its tile (5.4): hanging from one edge of the hole, or down on
			# the floor below; no collider either way.
			var spot: Vector3 = node.position + at
			if vary(spot, 161) < HANGING:
				var yaw := floori(vary(spot, 166) * 4.0) * PI * 0.5
				var drop := lerpf(HANG_ANGLE.x, HANG_ANGLE.y, vary(spot, 167))
				var hinge := at + Basis(Vector3.UP, yaw) * Vector3(OFFICE.TILE * 0.5, h, 0)
				var swung := Basis.from_euler(Vector3(0, yaw, drop)) * Vector3(-OFFICE.TILE * 0.5, 0, 0)
				box(node, hinge + swung, Vector3(OFFICE.TILE, TILE_THICK, OFFICE.TILE), "ceiling_service", false, "box", Vector3(0, yaw, drop))
			elif vary(spot, 162) < FALLEN:
				box(node, Vector3(at.x, 0.008, at.z) + Vector3(vary(spot, 163) - 0.5, 0, vary(spot, 164) - 0.5) * 0.8, Vector3(OFFICE.TILE, TILE_THICK, OFFICE.TILE), "ceiling_service", false, "box", Vector3(0, vary(spot, 165) * TAU, 0))

## The tiles she goes through (spec_f3_aggression): Vector3i(room, i, j) ->
## its hinge, a node of its own from the first time she moves it. Coming out
## she pushes it down to TILE_DOWN and leaves it hanging there, half open;
## going in by a shut one she lifts it TILE_UP into the plenum and it drops
## shut after her; going in by an open one she pulls it shut. TILE_SWING
## seconds a move.
var moved_tiles := {}
const TILE_DOWN := 1.05
const TILE_UP := 1.22
const TILE_SWING := 0.25

## Moves one of her tiles; where its free edge ends up (her hand takes it
## there), null when the room has no such tile. On this machine (her event
## "tile" brings it to the others: lurker.tell()).
func turn_tile(room_id: int, tile: Vector2i, open: bool, from_below: bool) -> Variant:
	var key := Vector3i(room_id, tile.x, tile.y)
	var hinge: Node3D = moved_tiles.get(key)
	if hinge == null:
		hinge = lift_out(room_id, tile)
		if hinge == null: return null
		moved_tiles[key] = hinge
	var dark: Node3D = hinge.get_meta("dark")
	var angle: float = 0.0
	if open: angle = -TILE_UP if from_below else TILE_DOWN
	if open: dark.visible = true
	var swing := hinge.create_tween()
	swing.tween_property(hinge, "rotation:z", angle, TILE_SWING).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not open: swing.tween_callback(func(): dark.visible = false)
	return hinge.get_parent().to_global(hinge.position + Basis.from_euler(Vector3(0, hinge.rotation.y, angle)) * Vector3(-OFFICE.TILE, 0, 0))

## Takes a whole tile out of the run it was batched in (the run cut round it),
## and gives it a hinge of its own on one of its edges, shut, with the dark of
## the plenum over its hole, hidden. Null with no such tile.
func lift_out(room_id: int, tile: Vector2i) -> Node3D:
	if room_id < 0 or room_id >= room_nodes.size() or not is_instance_valid(room_nodes[room_id]): return null
	var node: Node3D = room_nodes[room_id]
	var runs := node.get_node_or_null("Mesh_ceiling_service") as MultiMeshInstance3D
	if runs == null: return null
	var room: Dictionary = manifest.rooms[room_id]
	var face := float(room.height) + TILE_FACE + TILE_THICK * 0.5
	var size := float(OFFICE.TILE)
	var centre: Vector3 = OFFICE.tile_centre(tile, face) - Vector3(node.position.x, 0, node.position.z)
	var multi := runs.multimesh
	var drawn: Array = service_runs.get(node.get_instance_id(), [[], Color()])
	var custom: Color = drawn[1]
	var kept: Array = []
	var found := false
	for run in drawn[0]:
		var t: Transform3D = run
		var extent := t.basis.get_scale()
		var o := t.origin
		var inside: bool = not found and absf(o.y - face) < 0.003 and absf(o.z - centre.z) < 0.01 and absf(extent.z - size) < 0.01 and centre.x - size * 0.5 > o.x - extent.x * 0.5 - 0.003 and centre.x + size * 0.5 < o.x + extent.x * 0.5 + 0.003 and t.basis.is_equal_approx(Basis.from_scale(extent))
		if not inside:
			kept.append(t)
			continue
		found = true
		var low := o.x - extent.x * 0.5
		var high := o.x + extent.x * 0.5
		var cut_low := centre.x - size * 0.5
		var cut_high := centre.x + size * 0.5
		if cut_low - low > 0.003:
			kept.append(Transform3D(Basis.from_scale(Vector3(cut_low - low, extent.y, extent.z)), Vector3((low + cut_low) * 0.5, o.y, o.z)))
		if high - cut_high > 0.003:
			kept.append(Transform3D(Basis.from_scale(Vector3(high - cut_high, extent.y, extent.z)), Vector3((cut_high + high) * 0.5, o.y, o.z)))
	if not found: return null
	service_runs[node.get_instance_id()] = [kept, custom]
	multi.instance_count = kept.size()
	for i in kept.size():
		multi.set_instance_transform(i, kept[i])
		if multi.use_custom_data: multi.set_instance_custom_data(i, custom)
	# Its hinge on one edge, by its place (salt 168), the tile half a tile in.
	var yaw := floori(vary(node.position + centre, 168) * 4.0) * PI * 0.5
	var hinge := Node3D.new()
	hinge.name = "Tile_%d_%d" % [tile.x, tile.y]
	hinge.position = centre + Basis(Vector3.UP, yaw) * Vector3(size * 0.5, 0, 0)
	hinge.rotation = Vector3(0, yaw, 0)
	node.add_child(hinge)
	hinge.add_child(single(Transform3D(Basis.from_scale(Vector3(size, TILE_THICK, size)), Vector3(-size * 0.5, 0, 0)), "ceiling_service", custom))
	var dark := single(Transform3D(Basis.from_scale(Vector3(size, 1.2, size)), centre + Vector3(0, 0.6 - (face - float(room.height)), 0)), "plenum_dark", custom)
	dark.visible = false
	node.add_child(dark)
	hinge.set_meta("dark", dark)
	return hinge

## Every room's batch of "ceiling_service" as flush() draws it, and the
## room's data it wears, by the room node's instance id: kept to cut a tile
## out of (a MultiMesh's transforms are not read back on every renderer).
var service_runs := {}
func flush() -> void:
	service_runs = {}
	for key in batches:
		var batch: Dictionary = batches[key]
		var room: Variant = batch_roots.get(batch.parent.get_instance_id())
		if room != null and batch.groups.has("ceiling_service"): service_runs[batch.parent.get_instance_id()] = [(batch.groups.ceiling_service as Array).duplicate(), room]
	super()

## One box of a room's, batched alone (so it wears the room's data as its
## batches do).
func single(xform: Transform3D, material: String, custom: Color) -> MultiMeshInstance3D:
	var mesh := unit_mesh(material)
	mesh.material = materials[material]
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = 1
	multi.set_instance_transform(0, xform)
	multi.set_instance_custom_data(0, custom)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	return instance

## A gap's tile (spec 5.4): how many hang from the hole and how far they
## drop (radians), and how many lie on the floor below.
const HANG_ANGLE := Vector2(0.6, 1.2)
const HANGING := 0.4
const FALLEN := 0.5

## The room being built, for the walls that need it (its lower wall, its sign).
var building_room := {}
## The failing troffer's lens of the room being built (ceiling() to
## room_lamp()) and its share of the room's light.
var failing_lens := ""
var failing_share := 1.0
## The corridor cells whose zone sign is already up.
var labelled := {}
## The span along its wall of each boundary's zone sign (zone_sign()), by the
## boundary's instance id: wall_art() hangs nothing over it.
var sign_spans := {}
## The secretary's one panelled wall (wall_trim() "panel_wall"): the side
## build_room() chose, "" in any other room.
var panel_side := ""

func build_room(node: Node3D, room: Dictionary) -> void:
	building_room = room
	panel_side = ""
	if OFFICE.wall_trim(room) == "panel_wall":
		for side in ["north", "south", "west", "east"]:
			if not room.get("open_sides", []).has(side) and not room.get("glazed", []).has(side):
				panel_side = side
				break
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
	panes = []
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
	darken_first_stage(data)

## The difficulty the floor is built for (hotel_main.build_floor()).
var difficulty_id := "equilibrada"
## The first stage's dark by difficulty (the author, 24 October 2026;
## .claude/specs/spec_f3_aggression.md): Apacible all lit, Equilibrada the
## manifest's, Desafiante that and DARKER of the rest, Pesadilla all but
## LIT_LEFT. Rooms that may never be dark, and the off-limits ones, keep their
## light. Per room by its place, the same on every machine.
const DARKER := 0.6
const LIT_LEFT := 0.1
func darken_first_stage(data: Dictionary) -> void:
	for room in data.rooms:
		if int(room.get("wing", 0)) != 0 or FLOOR.is_void(room): continue
		var id := int(room.id)
		var roll := vary(FLOOR.position_of(room), 180)
		var may: bool = OFFICE.may_be_dark(room) and not OFFICE.off_limits(room)
		match difficulty_id:
			"apacible": dark_ids.erase(id)
			"desafiante": if may and roll < DARKER: dark_ids[id] = true
			"pesadilla": if may and roll >= LIT_LEFT: dark_ids[id] = true

## A room's power cut or given back (planta 2's board, spec_f1_systems 3):
## its troffer lenses, battens and globes go dark with its lamp, or they
## would glow over a room with no light.
func set_room_power(room_id: int, on: bool) -> void:
	super(room_id, on)
	if room_id < 0 or room_id >= room_nodes.size(): return
	var glowing: bool = on and not dark and not dark_ids.has(room_id)
	var off: Material = materials.get("lens_off", materials.get("light_off"))
	for mesh in lenses_of(room_id):
		# A model keeps its glass apart (the battens): only that goes dark.
		if mesh.has_meta("glow_surface"): (mesh as MeshInstance3D).set_surface_override_material(int(mesh.get_meta("glow_surface")), null if glowing else off)
		else: mesh.material_override = null if glowing else off

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

## A narrow steel desk with its back to a wall spot: no collider, so the
## body put at the spot's stand to work at it is not pushed off.
const POST_DESK := Vector3(1.2, 0.755, 0.45)
func post_desk(node: Node3D, spot: Dictionary) -> void:
	var yaw := float(spot.yaw)
	var holder := Node3D.new()
	holder.name = "PostDesk"
	holder.position = Vector3(float(spot.point[0]), float(spot.point[1]), float(spot.point[2])) - node.position + Basis(Vector3.UP, yaw).z * (POST_DESK.z * 0.5)
	holder.rotation.y = yaw
	node.add_child(holder)
	box(holder, Vector3(0, POST_DESK.y - 0.015, 0), Vector3(POST_DESK.x, 0.03, POST_DESK.z), "laminate")
	for side: float in [-1.0, 1.0]: box(holder, Vector3(side * (POST_DESK.x * 0.5 - 0.02), (POST_DESK.y - 0.03) * 0.5, 0), Vector3(0.04, POST_DESK.y - 0.03, POST_DESK.z - 0.04), "steel_olive")
	box(holder, Vector3(0, 0.45, -POST_DESK.z * 0.5 + 0.02), Vector3(POST_DESK.x - 0.08, 0.5, 0.02), "steel_olive")

## The battery units (spec_f1_geometry 7.2): how high, how far they are lit
## from the player, how many of the nearest cast (on Compatibility, fewer),
## and their light.
const EMERGENCY_Y := 2.45
const EMERGENCY_REACH := 18.0
const EMERGENCY_CAST := 6
const EMERGENCY_CAST_COMPAT := 3
const EMERGENCY_ENERGY := 1.4
const EMERGENCY_RANGE := 9.0
const EMERGENCY_ANGLE := 55.0
const EMERGENCY_KELVIN := 2400.0
## The shortest plain stretch of wall a unit hangs on.
const EMERGENCY_RUN := 1.2
## Every unit: {light, lens, room, planta, spot}.
var emergency: Array = []
## The plain runs of the room being built: [boundary, x, inner].
var emergency_runs: Array = []

## Landings, lobbies, corridors, galleries and the electrical room keep a
## battery unit where the planta has any power at all (not Dirección).
func emergency_room(room: Dictionary) -> bool:
	var t := int(room.type)
	return (t in [OFFICE.LANDING, OFFICE.LOBBY, OFFICE.CORRIDOR, OFFICE.GALLERY, OFFICE.ELECTRICAL]) and String(OFFICE.POWER[int(room.get("wing", 0))]) != "none"

## The unit of a room, on its plain run nearest the room's middle: an enamel
## box with two heads, a lens that lights when the room has no power, a red
## charge pip, and a spot light along the wall, down.
func emergency_unit(node: Node3D, room: Dictionary) -> void:
	var runs := emergency_runs
	emergency_runs = []
	if runs.is_empty() or not emergency_room(room): return
	var best: Array = []
	var best_distance := INF
	for run in runs:
		var boundary: Node3D = run[0]
		var at: Vector3 = boundary.transform * Vector3(float(run[1]), 0, 0)
		if Vector2(at.x, at.z).length() < best_distance:
			best_distance = Vector2(at.x, at.z).length()
			best = run
	var wall: Node3D = best[0]
	var inner := int(best[2])
	var unit := Node3D.new()
	unit.name = "EmergencyUnit"
	unit.transform = wall.transform * Transform3D(Basis(Vector3.UP, 0.0 if inner > 0 else PI), Vector3(float(best[1]), EMERGENCY_Y, inner * 0.09))
	node.add_child(unit)
	unit_box(unit, Vector3(0, 0, 0.05), Vector3(0.32, 0.18, 0.10), plain_material(Color("e6e1d3")))
	var lens := MeshInstance3D.new()
	var lens_mesh := BoxMesh.new()
	lens_mesh.size = Vector3(0.24, 0.04, 0.012)
	lens.mesh = lens_mesh
	lens.position = Vector3(0, -0.05, 0.105)
	unit.add_child(lens)
	for side: float in [-1.0, 1.0]:
		var head := unit_box(unit, Vector3(side * 0.11, -0.11, 0.08), Vector3(0.07, 0.07, 0.08), plain_material(Color("d9d3c3")))
		head.rotation = Vector3(deg_to_rad(-35.0), side * deg_to_rad(30.0), 0)
	var pip_material := StandardMaterial3D.new()
	pip_material.albedo_color = Color(0.5, 0.02, 0.02)
	pip_material.emission_enabled = true
	pip_material.emission = Color(1.0, 0.05, 0.03)
	pip_material.emission_energy_multiplier = 2.0
	unit_box(unit, Vector3(0.13, 0.05, 0.102), Vector3(0.004, 0.004, 0.004), pip_material)
	var light := SpotLight3D.new()
	light.name = "EmergencyLight"
	light.light_color = LIGHTING.light_color(EMERGENCY_KELVIN)
	light.light_energy = EMERGENCY_ENERGY
	light.spot_range = EMERGENCY_RANGE
	light.spot_angle = EMERGENCY_ANGLE
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	light.light_bake_mode = Light3D.BAKE_DISABLED
	light.light_volumetric_fog_energy = 0.0
	# Out of the wall and 35 degrees down: -Z of the light along +Z of the unit.
	light.transform = Transform3D(Basis.looking_at(Vector3(0, -sin(deg_to_rad(35.0)), cos(deg_to_rad(35.0)))), Vector3(0, -0.1, 0.15))
	light.visible = false
	unit.add_child(light)
	emergency.append({"light": light, "lens": lens, "room": int(room.id), "planta": int(room.get("wing", 0)), "spot": node.position + unit.transform.origin})

func unit_box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh

## A plain stand-in colour, one material per colour.
func plain_material(colour: Color) -> StandardMaterial3D:
	var key := "unit_%s" % colour.to_html(false)
	if not materials.has(key):
		var plain := StandardMaterial3D.new()
		plain.albedo_color = colour
		plain.roughness = 0.5
		materials[key] = plain
	return materials[key]

## The emergency lens alight.
var emergency_glow: StandardMaterial3D = null
func emergency_on() -> StandardMaterial3D:
	if emergency_glow == null:
		emergency_glow = StandardMaterial3D.new()
		emergency_glow.albedo_color = Color(1.0, 0.8, 0.55)
		emergency_glow.emission_enabled = true
		emergency_glow.emission = LIGHTING.light_color(EMERGENCY_KELVIN)
		emergency_glow.emission_energy_multiplier = 3.0
	return emergency_glow

## The hotel's round, then the battery units: on where their room has no
## light, on this planta and near, the nearest few casting and the rest out
## (an unshadowed lamp would shine through the walls).
func round_lamps() -> void:
	super()
	if emergency.is_empty() or round_at.is_empty(): return
	var at: Vector3 = round_at.position
	var casting: bool = round_at.shadows and not echo_view
	var most := EMERGENCY_CAST_COMPAT if RenderingServer.get_current_rendering_method() == "gl_compatibility" else EMERGENCY_CAST
	var near: Array = []
	for k in emergency.size():
		var e: Dictionary = emergency[k]
		var out: bool = int(e.planta) == int(round_at.here) and not lit(int(e.room))
		var lens: MeshInstance3D = e.lens
		var lens_material: Material = emergency_on() if out else plain_material(Color("bdb8a8"))
		if lens.material_override != lens_material: lens.material_override = lens_material
		var distance: float = (e.spot as Vector3).distance_to(at)
		if out and casting and distance < EMERGENCY_REACH: near.append([distance, k])
		elif e.light.visible: e.light.visible = false
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for place in near.size():
		var light: SpotLight3D = emergency[int(near[place][1])].light
		var shown: bool = place < most
		if light.visible != shown: light.visible = shown

## A body in the main duct is on no room's layers (-1, which follow_bodies()
## puts on none): the lamp of the room under it cannot light it through the
## false ceiling; the torches still do.
func body_bit(at: Vector3) -> int:
	if not manifest.is_empty() and MAIN_DUCT.inside(manifest, at, 0.1): return -1
	return super(at)

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

## An office wall (6.2; spec_rediseno 2): its paint, a cove base and the
## room's lower wall on this room's face, and once in a corridor cell its zone
## sign; none of the hotel's dado, rails, sockets or cornice.
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
			lower_wall(boundary, mx, mid, height, inner, float(cut[2]))
		if float(cut[3]) < height - 0.01: wall_core(boundary, Vector3(mx, (float(cut[3]) + height) * 0.5, 0), Vector3(mid, height - float(cut[3]), 0.18), inner)
		return
	wall_core(boundary, Vector3(x, height / 2, 0), Vector3(length, height, 0.18), inner)
	var room_node := boundary.get_parent() as Node3D
	plan_wall(room_node, boundary.transform * Vector3(x - length * 0.5, 0, 0), boundary.transform * Vector3(x + length * 0.5, 0, 0))
	box(boundary, Vector3(x, SKIRT.x * 0.5, inner * (0.09 + SKIRT.y * 0.5)), Vector3(length, SKIRT.x, SKIRT.y), "skirting")
	lower_wall(boundary, x, length, height, inner)
	if not building_room.is_empty() and length >= EMERGENCY_RUN and emergency_room(building_room): emergency_runs.append([boundary, x, inner])
	if building_room.is_empty() or not (int(building_room.type) in [OFFICE.CORRIDOR, OFFICE.GALLERY]): return
	# Once a corridor cell, on its first run long enough, the zone's sign.
	if length < 3.0 or labelled.has(int(building_room.id)): return
	var label: String = OFFICE.zone_label(manifest, building_room)
	if label.is_empty(): return
	labelled[int(building_room.id)] = true
	zone_sign(boundary, x, inner, label, OFFICE.stripe_color(manifest, building_room))

## The lower part of this room's face of a wall (wall_trim()): nothing, the
## frieze (taupe under a walnut rail), the walnut dado and its cap, the air
## rooms' darker paint, or a panelled wall of walnut veneer on the
## secretary's panel_side. A glazed run or a duct cuts it at `top`.
func lower_wall(boundary: Node3D, x: float, length: float, height: float, inner: int, top := INF) -> void:
	if building_room.is_empty() or top <= SKIRT.x + 0.01: return
	var face := inner * 0.09
	match OFFICE.wall_trim(building_room):
		"frieze":
			var high := minf(FRIEZE_TOP, top)
			box(boundary, Vector3(x, (SKIRT.x + high) * 0.5, face + inner * LINING * 0.5), Vector3(length, high - SKIRT.x, LINING), "taupe")
			if top > FRIEZE_TOP: box(boundary, Vector3(x, FRIEZE_TOP, face + inner * RAIL.y * 0.5), Vector3(length, RAIL.x, RAIL.y), "walnut")
		"dado":
			var high := minf(DADO_TOP, top)
			box(boundary, Vector3(x, (SKIRT.x + high) * 0.5, face + inner * DADO_THICK * 0.5), Vector3(length, high - SKIRT.x, DADO_THICK), "walnut")
			if top > DADO_TOP: box(boundary, Vector3(x, DADO_TOP + DADO_CAP.x * 0.5, face + inner * DADO_CAP.y * 0.5), Vector3(length, DADO_CAP.x, DADO_CAP.y), "walnut")
		"two_tone":
			var high := minf(TWO_TONE_TOP, top)
			box(boundary, Vector3(x, (SKIRT.x + high) * 0.5, face + inner * LINING * 0.5), Vector3(length, high - SKIRT.x, LINING), "two_tone_low")
		"panel_wall":
			if String(SIDE_OF.get(String(boundary.name), "")) != panel_side: return
			var high := minf(height, top)
			box(boundary, Vector3(x, (SKIRT.x + high) * 0.5, face + inner * DADO_THICK * 0.5), Vector3(length, high - SKIRT.x, DADO_THICK), "veneer")

## How far this room's lower wall stands off the face of its wall on `side`
## (wall_trim()), for what is fixed low on it: the duct's wall grilles.
func lining(side: String) -> float:
	if building_room.is_empty(): return 0.0
	match OFFICE.wall_trim(building_room):
		"frieze", "two_tone": return LINING
		"dado": return DADO_THICK
		"panel_wall": return DADO_THICK if side == panel_side else 0.0
	return 0.0

## How far the secretary's panelled wall stands off a wall boundary's face:
## DADO_THICK on panel_side, 0 elsewhere (the switch and the posters sit on it).
func panel_lift(boundary: Node3D) -> float:
	return DADO_THICK if not panel_side.is_empty() and String(SIDE_OF.get(String(boundary.name), "")) == panel_side else 0.0

## A corridor cell's zone sign (R5): a black plate at SIGN_Y with the zone's
## name in light letters and a swatch of its department's colour.
func zone_sign(boundary: Node3D, x: float, inner: int, label: String, colour: Color) -> void:
	var key := "swatch_%s" % colour.to_html(false)
	if not materials.has(key):
		var swatch := StandardMaterial3D.new()
		swatch.albedo_color = colour
		swatch.roughness = 0.7
		materials[key] = swatch
	var wide := SIGN_MARGIN * 3.0 + SWATCH + SIGN_LETTER * label.length()
	# wall_art() keeps its board and its posters off this span.
	sign_spans[boundary.get_instance_id()] = Vector2(x - wide * 0.5, x + wide * 0.5)
	var face := inner * 0.09
	box(boundary, Vector3(x, SIGN_Y, face + inner * SIGN_DEPTH * 0.5), Vector3(wide, SIGN_HIGH, SIGN_DEPTH), "plaque")
	box(boundary, Vector3(x - wide * 0.5 + SIGN_MARGIN + SWATCH * 0.5, SIGN_Y, face + inner * (SIGN_DEPTH + 0.0005)), Vector3(SWATCH, SWATCH, 0.001), key)
	text(boundary, label, Vector3(x + (SIGN_MARGIN + SWATCH) * 0.5, SIGN_Y, face + inner * (SIGN_DEPTH + 0.001)), 0.0 if inner > 0 else PI, 12, NUMBER_REACH, Color("e8e4d6"))

## Whether this boundary's zone sign reaches within `half` of `at` along the wall.
func sign_under(boundary: Node3D, at: float, half: float) -> bool:
	if not sign_spans.has(boundary.get_instance_id()): return false
	var span: Vector2 = sign_spans[boundary.get_instance_id()]
	return at + half > span.x and at - half < span.y

## No cornice in the offices (spec_rediseno 2): the wall meets the false
## ceiling's grid, and over a doorway the frame's head is all there is.
func cornice(_boundary: Node3D, _x: float, _length: float, _height: float, _inner: int, _both := true) -> void:
	pass

## The corner round a cell that is not part of the room (found as the
## hotel's corner_posts() finds it): the wall's post, its skirting and its
## lower wall carried round, none of the hotel's dado, rails or cornice.
func corner_posts(node: Node3D, room: Dictionary) -> void:
	var span := FLOOR.size_of(room)
	var height: float = room.height
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var a: int = FLOOR.beside(room, Vector2i(sx, 0))
			var b: int = FLOOR.beside(room, Vector2i(0, sz))
			if a < 0 or b < 0 or not opens_on(int(room.id), a) or not opens_on(int(room.id), b): continue
			var d: int = FLOOR.beside(manifest.rooms[a], Vector2i(0, sz))
			if d < 0 or opens_on(a, d) or opens_on(b, d): continue
			var corner := Vector3(sx * span.x * 0.5, 0, sz * span.y * 0.5)
			var into := Vector3(-sx, 0, -sz)
			box(node, corner + into * 0.045 + Vector3(0, height * 0.5, 0), Vector3(0.09, height, 0.09), wall_material)
			corner_piece(node, corner, into, 0.0, SKIRT.x, SKIRT.y, "skirting")
			match OFFICE.wall_trim(room):
				"frieze":
					corner_piece(node, corner, into, SKIRT.x, FRIEZE_TOP, LINING, "taupe")
					corner_piece(node, corner, into, FRIEZE_TOP - RAIL.x * 0.5, FRIEZE_TOP + RAIL.x * 0.5, RAIL.y, "walnut")
				"dado":
					corner_piece(node, corner, into, SKIRT.x, DADO_TOP, DADO_THICK, "walnut")
					corner_piece(node, corner, into, DADO_TOP, DADO_TOP + DADO_CAP.x, DADO_CAP.y, "walnut")
				"two_tone":
					corner_piece(node, corner, into, SKIRT.x, TWO_TONE_TOP, LINING, "two_tone_low")

## A square piece filling a corner post's notch from `low` to `high`, `proud`
## past the faces of its two walls.
func corner_piece(node: Node3D, corner: Vector3, into: Vector3, low: float, high: float, proud: float, material: String) -> void:
	var side := 0.09 + proud
	box(node, corner + into * (side * 0.5) + Vector3(0, (low + high) * 0.5, 0), Vector3(side, high - low, side), material)

## A glazed run (6.3; spec_rediseno 2): the sill and the head as wall, this
## room's lower wall up to the sill under a walnut sill board, the glass
## between with its collider, walnut mullions every MULLION_PITCH. Both rooms
## build their half of the sill, the board and the head; the glass and
## mullions only the room whose west or north side it is (inner > 0), so the
## pane is there once. Clear glass, wired beside the security post; a beige
## blind on the office side of each pane, none at the window counter or the
## security post (spec_rediseno 8: not in panes).
func glazed_run(boundary: Node3D, x: float, length: float, height: float, inner: int) -> void:
	wall_core(boundary, Vector3(x, GLASS_SILL / 2, 0), Vector3(length, GLASS_SILL, 0.18), inner)
	wall_core(boundary, Vector3(x, (GLASS_HEAD + height) / 2, 0), Vector3(length, height - GLASS_HEAD, 0.18), inner)
	var room_node := boundary.get_parent() as Node3D
	plan_wall(room_node, boundary.transform * Vector3(x - length * 0.5, 0, 0), boundary.transform * Vector3(x + length * 0.5, 0, 0))
	box(boundary, Vector3(x, SKIRT.x * 0.5, inner * (0.09 + SKIRT.y * 0.5)), Vector3(length, SKIRT.x, SKIRT.y), "skirting")
	lower_wall(boundary, x, length, height, inner, GLASS_SILL)
	box(boundary, Vector3(x, GLASS_SILL + SILL_OVER - SILL_BOARD.x * 0.5, inner * (0.09 + SILL_BOARD.y) * 0.5), Vector3(length, SILL_BOARD.x, 0.09 + SILL_BOARD.y), "walnut")
	if inner < 0: return
	var band := GLASS_HEAD - GLASS_SILL
	var both: Array = [int(building_room.type), int(room_across(boundary).get("type", -1))]
	box(boundary, Vector3(x, GLASS_SILL + band * 0.5, 0), Vector3(length, band, 0.06), "", true)
	box(boundary, Vector3(x, GLASS_SILL + band * 0.5, 0), Vector3(length, band, GLASS_THICK), "wired_glass" if OFFICE.SECURITY in both else "clear_glass")
	var count := maxi(1, roundi(length / MULLION_PITCH))
	for k in count + 1:
		var at := x - length * 0.5 + length * k / count
		box(boundary, Vector3(at, GLASS_SILL + band * 0.5, 0), Vector3(MULLION, band, 0.06), "walnut")
	for y in [GLASS_SILL, GLASS_HEAD]: box(boundary, Vector3(x, y, 0), Vector3(length, MULLION, 0.07), "walnut")
	if OFFICE.SECURITY in both or OFFICE.WINDOW in both: return
	# Blinds on the office side of each pane (6.4), not the corridor's.
	var office_side: int = -inner if int(building_room.type) in [OFFICE.CORRIDOR, OFFICE.GALLERY] else inner
	for k in count:
		var pane := length / count
		var centre := x - length * 0.5 + pane * (k + 0.5)
		var spot: Vector3 = (room_node.position if room_node != null else Vector3.ZERO) + boundary.transform * Vector3(centre, 0, 0)
		var roll := vary(spot, 170)
		var blind := ShaderMaterial.new()
		blind.shader = BLIND
		blind.set_shader_parameter("pitch", BLIND_PITCH)
		blind.set_shader_parameter("height", band)
		blind.set_shader_parameter("color", BLIND_COLOR)
		blind.set_shader_parameter("open", 0.05 if roll < 0.33 else 0.0 if roll >= 0.66 else 0.35 + vary(spot, 171) * 0.3)
		# Most of them half down (spec_rediseno 2), some right down, a few up.
		var drop: float = 1.0 if roll < 0.25 else 0.5 if roll < 0.8 else 0.25 / band
		blind.set_shader_parameter("drop", drop)
		var quad := QuadMesh.new()
		quad.size = Vector2(pane - MULLION, band - 0.06)
		quad.material = blind
		var sheet := MeshInstance3D.new()
		sheet.mesh = quad
		sheet.position = Vector3(centre, GLASS_SILL + band * 0.5 - 0.03, office_side * 0.045)
		boundary.add_child(sheet)
		panes.append(sheet)
		box(boundary, Vector3(centre, GLASS_HEAD - 0.05, office_side * 0.045), Vector3(pane - MULLION, 0.04, 0.04), "tgrid")

## The room on the other side of a wall boundary of the room being built, or
## {} past the planta's edge.
func room_across(boundary: Node3D) -> Dictionary:
	var step: Vector2i = SIDE_STEP.get(String(boundary.name), Vector2i.ZERO)
	if step == Vector2i.ZERO: return {}
	var id: int = FLOOR.beside(building_room, step)
	if id < 0 or id >= manifest.rooms.size(): return {}
	return manifest.rooms[id]

## Every blind of a glazed run, its sheet (The Lurker's lie of a shadow
## behind one, lurker_hallucinations).
var panes: Array = []

## A lie (lurker_hallucinations, "lampara"): one troffer of a lit room fails
## for `seconds`, on this machine only, as a failing troffer does: a dark lens
## (lens_off) just under its lens, shown with the flicker, and the room's light
## moved by that troffer's share at most (H5). No new material and never
## drain(). False when the room has fewer than two troffers or already
## flickers.
func flicker_one(room_id: int, seconds: float, seed_value: int) -> bool:
	if room_id < 0 or room_id >= lights.size() or not lit(room_id): return false
	var room: Dictionary = manifest.rooms[room_id]
	var lamps: Array = OFFICE.troffers(room)
	if lamps.size() < 2: return false
	var light: OmniLight3D = lights[room_id]
	for entry in flickers:
		if entry.light == light: return false
	var lamp: Dictionary = lamps[posmod(seed_value, lamps.size())]
	var quad := MeshInstance3D.new()
	quad.name = "LensFailing"
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.56, 1.16) if bool(lamp.along_z) else Vector2(1.16, 0.56)
	quad.mesh = mesh
	quad.material_override = materials.get("lens_off", materials.get("light_off"))
	quad.visible = false
	add_child(quad)
	quad.global_transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(lamp.centre.x, float(room.get("py", 0.0)) + float(room.height) + LENS_RECESS - 0.007, lamp.centre.y))
	adopt(quad)
	var entry := {"light": light, "energy": float(drain_from.get(room_id, light.light_energy)), "phase": 0.0, "material": null, "glow": 0.0, "share": 1.0 / lamps.size(), "quad": quad}
	flickers.append(entry)
	get_tree().create_timer(seconds).timeout.connect(func(): end_flicker(entry, room_id))
	return true

func end_flicker(entry: Dictionary, room_id: int) -> void:
	flickers.erase(entry)
	if is_instance_valid(entry.quad): entry.quad.queue_free()
	if is_instance_valid(entry.light): entry.light.light_energy = float(entry.energy) * (1.0 - drained(room_id))

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
	# Clear of the frieze's rail; the casing reaches back to the wall.
	var proud: float = RAIL.y if OFFICE.wall_trim(room) == "frieze" else 0.0
	front.position = back * (half - 0.09 - LIFT_PROUD - proud)
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
	for x in [x0, x1]: box(front, Vector3(x, top * 0.5, 0.02 - proud * 0.5), Vector3(0.08, top, 0.04 + proud), "steel_frame")
	box(front, Vector3((x0 + x1) * 0.5, top, 0.02 - proud * 0.5), Vector3(x1 - x0 + 0.08, 0.08, 0.04 + proud), "steel_frame")

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
	# Proud of the secretary's panelled wall where it is on it.
	var lift := panel_lift(boundary)
	box(boundary, Vector3(x, SWITCH_Y, inner * (0.094 + lift)), Vector3(0.08, 0.12, 0.008), "switch", false, "detail")
	box(boundary, Vector3(x, SWITCH_Y, inner * (0.1 + lift)), Vector3(0.03, 0.05, 0.008), "switch", false, "detail", Vector3(inner * -0.2, 0, 0))

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
	# The board clear of the frieze's rail and the dado's cap.
	var board_y: float = 1.6 if OFFICE.wall_trim(room) in ["frieze", "dado"] else 1.5
	# Nothing hangs over a zone sign (zone_sign()): not the board, not a poster.
	var signed := sign_under(boundary, at, BOARD_HALF)
	if t in [OFFICE.OFFICE, OFFICE.EXEC_OFFICE, OFFICE.CORRIDOR] and roll < 0.4:
		if not signed:
			box(boundary, Vector3(at, board_y, face + inner * 0.012), Vector3(1.2, 0.9, 0.02), "cork")
			box(boundary, Vector3(at, board_y, face + inner * 0.01), Vector3(1.26, 0.96, 0.016), "steel_frame")
	elif t in [OFFICE.OFFICE, OFFICE.EXEC_OFFICE, OFFICE.BREAK_ROOM, OFFICE.ARCHIVE] and roll < 0.7:
		DRESSING.place(self, boundary, "wall_clock", Transform3D(turn, Vector3(at, 2.05, face + inner * 0.027)))
	elif not signed:
		var lift := panel_lift(boundary)
		poster_spots.append({"room": int(room.id), "transform": boundary.global_transform * Transform3D(turn, Vector3(at, 1.5, face + inner * (0.005 + lift))) if boundary.is_inside_tree() else Transform3D(turn, Vector3(at, 1.5, face + inner * lift))})

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
			if ResourceLoader.exists(BATTEN_MODEL): batten_model(node, room, at, along_x, length)
			else:
				box(node, at, Vector3(length, 0.07, 0.16) if along_x else Vector3(0.16, 0.07, length), "metal")
				box(node, at - Vector3(0, 0.05, 0), Vector3(length - 0.1, 0.03, 0.05) if along_x else Vector3(0.05, 0.03, length - 0.1), "light_off" if dark_room(room) else "light")
			any = true
	return any

## Poly Haven's mounted fluorescent light (CC0, tools/props/build_catalogue.gd
## PARTS), stretched along its aisle; its glass glows with the room's power
## (set_room_power(), through the "glow_surface" it keeps).
const BATTEN_MODEL := "res://assets/props/hotel/mounted_fluorescent_lights_batten.res"
func batten_model(node: Node3D, room: Dictionary, at: Vector3, along_x: bool, length: float) -> void:
	var batten := MeshInstance3D.new()
	batten.name = "Mesh_light_batten_%d" % node.get_child_count()
	batten.mesh = load(BATTEN_MODEL)
	var glass := 0
	for i in batten.mesh.get_surface_count():
		var material := batten.mesh.surface_get_material(i)
		if material != null and "glass" in material.resource_path: glass = i
	batten.set_meta("glow_surface", glass)
	var stretch: float = length / maxf(batten.mesh.get_aabb().size.x, 0.01)
	batten.transform = Transform3D(Basis(Vector3.UP, 0.0 if along_x else PI / 2) * Basis.from_scale(Vector3(stretch, 1.6, 1.6)), at)
	if dark_room(room): batten.set_surface_override_material(glass, materials.light_off)
	node.add_child(batten)

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
## that room so it batches and layers with it, proud enough to stand off a
## panelled wall; not yet kept off reserved spots. The doorway's threshold
## strip too.
func door_plaques(_door: Node3D, a: Dictionary, b: Dictionary, center: Vector3, yaw: float) -> void:
	var turn := Basis(Vector3.UP, yaw)
	var normal := turn.z
	var along := turn.x
	# The threshold (spec_rediseno 2): a metal strip across the doorway where
	# one floor meets the next, each room's half on its own batch.
	for room: Dictionary in [a, b]:
		var floor_holder: Node3D = room_nodes[int(room.id)]
		var toward := signf((FLOOR.position_of(room) - center).dot(normal))
		box(floor_holder, center + normal * toward * THRESHOLD.x * 0.25 + Vector3(0, THRESHOLD.y * 0.5, 0) - floor_holder.position, Vector3(FLOOR.PORTAL, THRESHOLD.y, THRESHOLD.x * 0.5), "threshold", false, "box", Vector3(0, yaw, 0))
	for pair in [[a, b], [b, a]]:
		var viewer: Dictionary = pair[0]
		var behind: Dictionary = pair[1]
		var words: String = OFFICE.plaque(behind)
		if words.is_empty(): continue
		var side := signf((FLOOR.position_of(viewer) - center).dot(normal))
		var holder: Node3D = room_nodes[int(viewer.id)]
		var at := center + along * (FLOOR.PORTAL * 0.5 + JAMB_WIDE + PLAQUE_FROM_JAMB + PLAQUE.x * 0.5) + normal * side * (0.09 + PLAQUE_DEPTH * 0.5) + Vector3(0, PLAQUE_Y, 0) - holder.position
		box(holder, at, Vector3(PLAQUE.x, PLAQUE.y, PLAQUE_DEPTH), "plaque", false, "box", Vector3(0, yaw, 0))
		text(holder, words, at + normal * side * (PLAQUE_DEPTH * 0.5 + 0.001), yaw + (0.0 if side > 0 else PI), 20, NUMBER_REACH, Color("e8e4d6"))

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

## Office doors (spec_rediseno 2), made once a floor and kept: the honey oak
## leaf, plain or with its narrow vision panel, with a worn brass lever; the
## green-grey steel one with the panic bar for service and the stages; a
## walnut frame round every doorway. Per builder, so they wear this floor's
## materials (presets and lacquer change them in place).
var office_doors := {}

func leaf_mesh(a: Dictionary, b: Dictionary) -> Mesh:
	var steel: bool = bool(a.get("service", false)) or bool(b.get("service", false)) or [int(a.type), int(b.type)].any(func(t): return t in [OFFICE.ELECTRICAL, OFFICE.AIR_ROOM, OFFICE.AIR_PLANT]) or gate_stage(manifest, int(a.id), int(b.id)) > 0
	var key: String = "service" if steel else ("vision" if vary(FLOOR.portal_between(a, b), 172) < VISION else "plain")
	if not office_doors.has(key): office_doors[key] = door_leaf_mesh(steel, key == "vision")
	return office_doors[key]

func frame_mesh(_a: Dictionary, _b: Dictionary) -> Mesh:
	if not office_doors.has("frame"): office_doors["frame"] = door_frame_mesh()
	return office_doors["frame"]

## A flat leaf the hotel leaf's size: its face one surface (oak or steel),
## the lever or the panic bar another, and a vision panel's clear glass a
## third, in a hole cut through the face.
func door_leaf_mesh(steel: bool, vision: bool) -> ArrayMesh:
	var bounds := DOOR_LEAF.get_aabb()
	var c := bounds.get_center()
	var hole := Rect2(c.x - 0.075, 1.2, 0.15, 0.6)
	var pieces: Array = [[bounds.size, c]]
	if vision: pieces = [[Vector3(bounds.size.x, hole.position.y - bounds.position.y, bounds.size.z), Vector3(c.x, (bounds.position.y + hole.position.y) * 0.5, c.z)], [Vector3(bounds.size.x, bounds.end.y - hole.end.y, bounds.size.z), Vector3(c.x, (hole.end.y + bounds.end.y) * 0.5, c.z)], [Vector3(hole.position.x - bounds.position.x, hole.size.y, bounds.size.z), Vector3((bounds.position.x + hole.position.x) * 0.5, hole.get_center().y, c.z)], [Vector3(bounds.end.x - hole.end.x, hole.size.y, bounds.size.z), Vector3((hole.end.x + bounds.end.x) * 0.5, hole.get_center().y, c.z)]]
	var mesh := ArrayMesh.new()
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	for part in pieces:
		var slab := BoxMesh.new()
		slab.size = part[0]
		face.append_from(slab, 0, Transform3D(Basis.IDENTITY, part[1]))
	face.commit(mesh)
	mesh.surface_set_material(0, materials.steel_olive if steel else materials.oak_door)
	var extra := SurfaceTool.new()
	extra.begin(Mesh.PRIMITIVE_TRIANGLES)
	if steel:
		# The panic bar across the push side, at 1.0.
		var bar := BoxMesh.new()
		bar.size = Vector3(bounds.size.x * 0.75, 0.05, 0.05)
		extra.append_from(bar, 0, Transform3D(Basis.IDENTITY, Vector3(c.x, 1.0, bounds.size.z * 0.5 + 0.04)))
	else:
		# A lever on each face at the latch side, 1.0 up: its rose, its spindle
		# and its handle turned towards the hinge.
		var latch := bounds.end.x - 0.08
		for side: float in [-1.0, 1.0]:
			var out := c.z + side * bounds.size.z * 0.5
			for part in [[Vector3(0.05, 0.05, 0.012), Vector3(latch, 1.0, out + side * 0.006)], [Vector3(0.018, 0.018, 0.04), Vector3(latch, 1.0, out + side * 0.025)], [Vector3(0.12, 0.018, 0.018), Vector3(latch - 0.05, 1.0, out + side * 0.045)]]:
				var piece := BoxMesh.new()
				piece.size = part[0]
				extra.append_from(piece, 0, Transform3D(Basis.IDENTITY, part[1]))
	extra.commit(mesh)
	mesh.surface_set_material(1, materials.steel_frame if steel else materials.gold)
	if vision:
		var glass := SurfaceTool.new()
		glass.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pane := BoxMesh.new()
		pane.size = Vector3(hole.size.x, hole.size.y, 0.006)
		glass.append_from(pane, 0, Transform3D(Basis.IDENTITY, Vector3(hole.get_center().x, hole.get_center().y, c.z)))
		glass.commit(mesh)
		mesh.surface_set_material(2, materials.clear_glass)
	return mesh

## A walnut frame round the doorway: two jambs JAMB_WIDE wide, JAMB_PROUD past
## each face of the wall, and the head.
func door_frame_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := FLOOR.PORTAL * 0.5
	var deep := 0.18 + JAMB_PROUD * 2.0
	for part in [[Vector3(JAMB_WIDE, OPENING_HIGH, deep), Vector3(-half - JAMB_WIDE * 0.5, OPENING_HIGH * 0.5, 0)], [Vector3(JAMB_WIDE, OPENING_HIGH, deep), Vector3(half + JAMB_WIDE * 0.5, OPENING_HIGH * 0.5, 0)], [Vector3(FLOOR.PORTAL + JAMB_WIDE * 2.0, JAMB_WIDE, deep), Vector3(0, OPENING_HIGH + JAMB_WIDE * 0.5, 0)]]:
		var box_mesh := BoxMesh.new()
		box_mesh.size = part[0]
		tool.append_from(box_mesh, 0, Transform3D(Basis.IDENTITY, part[1]))
	var mesh := tool.commit()
	mesh.surface_set_material(0, materials.walnut_object)
	return mesh

## The office's corner pieces first (9.3); the hotel's own kinds as the hotel.
func build_prop(node: Node3D, kind: String) -> void:
	if not PROPS.build(self, node, kind): super(node, kind)

## An archive cell's share of its unit's rows (9.4): each row rectangle cut
## at the cell's edges and built under the cell, so it batches and layers
## with it.
func extras(node: Node3D, room: Dictionary) -> void:
	super(node, room)
	emergency_unit(node, room)
	# The window's typing desk and the post's console desk (stand-ins for
	# 1d's metal_office_desk), against their wall spots.
	var mail: Dictionary = manifest.get("mail", {})
	if not mail.is_empty() and int(room.id) == int(mail.window): post_desk(node, mail.desk)
	var air: Dictionary = manifest.get("air", {})
	if air.has("security") and int(room.id) == int(air.security.room): post_desk(node, air.security.desk)
	# The duct network's low wall grilles (ducts.exits of kind "wall"), where
	# the generator put them: a frame and slats over the dark of the duct.
	for e in manifest.get("ducts", {}).get("exits", []):
		if int(e.room) != int(room.id) or String(e.kind) != "wall": continue
		var at := Vector3(float(e.point[0]), float(e.point[1]), float(e.point[2])) - node.position
		var face := Basis(Vector3.UP, float(e.yaw)).z
		var flat: bool = absf(face.z) > 0.5
		# Proud of the room's lower wall on the wall it faces away from.
		var wall_side: String = ("north" if face.z > 0.0 else "south") if flat else ("west" if face.x > 0.0 else "east")
		var lift := lining(wall_side)
		box(node, at + face * (0.002 + lift), Vector3(0.45, 0.25, 0.004) if flat else Vector3(0.004, 0.25, 0.45), "black")
		for k in 5: box(node, at + face * (0.01 + lift) + Vector3(0, -0.1 + k * 0.05, 0), Vector3(0.43, 0.012, 0.016) if flat else Vector3(0.016, 0.012, 0.43), "grille_metal")
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
