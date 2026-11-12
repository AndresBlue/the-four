extends SceneTree
## Floor 2's construction kit (.claude/specs/spec_rediseno.md 2, area 3a): the
## office's own materials and the hotel's untouched, the floors, walls and lower
## walls by type, and on a floor built at seed 7: no stripes and no hotel cornice
## or corner dado, the frieze, the dado, the zone signs, the slab, the grilles,
## the glazed runs, the doors, frames and thresholds.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const OG := preload("res://game/world/office/office_geometry.gd")
const HG := preload("res://game/world/hotel/hotel_geometry.gd")
const DIR := "res://game/presentation/materials/office/%s.tres"
const TYPE_COUNT := 26
## The office's own scanned materials, each with the set it names (3a U3, U4).
const SCANNED := {"vinyl": "office_tiles110", "terrazzo": "office_terrazzo003", "concrete": "office_painted_concrete_02", "slab": "office_concrete_wall_008", "carpet": "office_fabric026", "carpet_exec": "office_fabric028", "ceiling_service": "officeceiling001", "office_paint": "wallpaper001a", "taupe": "wallpaper001a", "block": "office_bricks019", "veneer": "office_walnut_veneer", "walnut": "office_walnut_veneer", "walnut_object": "office_walnut_veneer", "oak_door": "office_teak_veneer", "dado_oak": "office_teak_veneer", "steel_olive": "office_paintedmetal006", "cork": "office_cork003", "partition_fabric": "office_hessian_380", "cardboard": "office_cardboard004", "quarry": "office_anti_skid_tiles"}
## The office's own plain materials, with no scan set (3a U3, U4).
const PLAIN_TRES := ["tgrid", "threshold", "partition"]
## Table 1.2 of office_test.gd on wing 0: the floors, the walls and the lower walls by type.
const FLOOR_WING_0 := ["vinyl", "carpet", "carpet", "vinyl", "vinyl", "vinyl", "terrazzo", "vinyl", "concrete", "terrazzo", "terrazzo", "terrazzo", "concrete", "terrazzo", "terrazzo", "vinyl", "vinyl", "vinyl", "quarry", "terrazzo", "vinyl", "vinyl", "vinyl", "vinyl", "vinyl", "concrete"]
const WALLS_WING_0 := ["office_paint", "office_paint", "office_paint", "office_paint", "office_paint", "office_paint", "office_paint", "partition", "block", "office_paint", "office_paint", "office_paint", "block", "office_paint", "office_paint", "office_paint", "office_paint", "office_paint", "block", "office_paint", "office_paint", "office_paint", "block", "block", "office_paint", "block"]
const TRIMS_WING_0 := ["frieze", "", "", "dado", "", "dado", "", "", "", "", "frieze", "frieze", "", "", "", "", "", "", "", "frieze", "", "dado", "two_tone", "two_tone", "panel_wall", ""]
## The rooms of the floor that are soft underfoot (carpet): the wing 0 naves and wing 2's boardroom, executive office and secretary.
const SOFT_FLOORS := [Vector2i(1, 0), Vector2i(2, 0), Vector2i(5, 2), Vector2i(16, 2), Vector2i(24, 2)]
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed, "detail": detail if not passed else ""})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

## Instances of a batched group under a room node ("Mesh_<group>", "@" as "-"; wildcards allowed).
func count(node: Node, group: String) -> int:
	var total := 0
	for found in node.find_children("Mesh_" + group, "MultiMeshInstance3D", true, false): total += (found as MultiMeshInstance3D).multimesh.instance_count
	return total

## The transforms of a batched group of a room node, in the room's frame, as
## flush() handed them to the bounce light (the dummy renderer keeps none).
var hotel_ref = null
func instances(node: Node, group: String) -> Array:
	var result: Array = []
	for entry in hotel_ref.bounce.groups.get(node.get_instance_id(), []):
		if String(entry[0]) == group: result.append_array(entry[1])
	return result

func run() -> void:
	var office_geo = OG.new()
	var hotel_geo = HG.new()
	check_materials(office_geo, hotel_geo)
	hotel_geo.free()
	check_palette(office_geo)
	office_geo.free()
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "none"
	level.set_floor(2)
	await level.start_floor(7, false, [1], "apacible", 2)
	var hotel = level.hotel
	hotel_ref = hotel
	check_walls(hotel)
	check_glazing(hotel)
	check_doors(hotel)
	await check_scan_cache(level)
	var file := FileAccess.open("res://evidence/office_finishes_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("OFFICE_FINISHES_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)

## The office's own materials and the hotel's untouched (3a U1, U3, U4), no level built.
func check_materials(office_geo, hotel_geo) -> void:
	var keys: Array = OG.PLAIN.keys() + OG.STAND_INS.keys() + OG.OWN_OVER + ["wired_glass", "clear_glass"]
	var missing: Array = keys.filter(func(k): return not office_geo.materials.has(k))
	check("Cada clave de la oficina tiene material", missing.is_empty(), str(missing))
	check("El vidrio claro es el armado sin alambre", office_geo.materials.clear_glass is ShaderMaterial and float(office_geo.materials.clear_glass.get_shader_parameter("wire")) == 0.0)
	check("El hotel no tiene las claves nuevas", not hotel_geo.materials.has("walnut") and not hotel_geo.materials.has("clear_glass") and not hotel_geo.materials.has("taupe") and not hotel_geo.materials.has("slab"))
	check("La moqueta y la placa del hotel siguen siendo las suyas", String(hotel_geo.materials.carpet.get_meta("scan", "")) == "carpet016" and String(hotel_geo.materials.ceiling_service.get_meta("scan", "")) == "officeceiling001")
	for key in SCANNED:
		var material = load(DIR % key)
		check(key + " es un ShaderMaterial con su set de escaneo", material is ShaderMaterial and String(material.get_meta("scan", "")) == SCANNED[key], str(material))
	for key in SCANNED:
		var scanned = load(DIR % key)
		var mode = scanned.get_shader_parameter("map_mode")
		var tint = scanned.get_shader_parameter("map_tint")
		var recolour: bool = mode == null or int(mode) == 1
		check(key + " tiñe su escaneo", not recolour or (tint is Color and not (tint as Color).is_equal_approx(Color.WHITE)), str(tint))
	# The furniture's steels are enamel since the light's fifth pass (satin, 0.45);
	# the dark one stays the bare steel's matt.
	for key in ["steel_olive", "steel_mint", "steel_grey", "steel_dark"]:
		var steel: ShaderMaterial = load(DIR % key)
		var least: float = 0.6 if key == "steel_dark" else 0.4
		check(key + " no dibuja la rugosidad de su escaneo en el brillo", is_zero_approx(float(steel.get_shader_parameter("map_rough_keep"))) and float(steel.get_shader_parameter("roughness")) >= least, "%s %s" % [str(steel.get_shader_parameter("map_rough_keep")), str(steel.get_shader_parameter("roughness"))])
	for key in PLAIN_TRES:
		var plain = load(DIR % key)
		check(key + " existe y no lleva set de escaneo", plain != null and not plain.has_meta("scan"))
	var walnut_object: ShaderMaterial = load(DIR % "walnut_object")
	var oak_door: ShaderMaterial = load(DIR % "oak_door")
	var walnut: ShaderMaterial = load(DIR % "walnut")
	check("walnut_object lleva object_space", walnut_object.get_shader_parameter("object_space") == true)
	check("oak_door lleva object_space", oak_door.get_shader_parameter("object_space") == true)
	check("walnut (lote) no lleva object_space", walnut.get_shader_parameter("object_space") != true)
	for key in SCANNED.keys() + PLAIN_TRES:
		var mat = office_geo.materials.get(key)
		var ok: bool = mat != null and not mat.has_meta("stand_in") and String(mat.get_meta("lite", "")) == "office/" + key
		check("La oficina usa su propio " + key + ", sin stand_in y con su lite", ok)
	var hotel_carpet := String(hotel_geo.materials.carpet.get_meta("scan", ""))
	check("El hotel conserva su moqueta (carpet016)", hotel_carpet == "carpet016", hotel_carpet)
	var hotel_ceiling: String = hotel_geo.materials.ceiling_service.shader.resource_path
	check("El hotel conserva su placa de servicio (ceiling.gdshader)", hotel_ceiling == "res://game/presentation/shaders/ceiling.gdshader", hotel_ceiling)
	var tile_shader: String = load(DIR % "ceiling_service").shader.resource_path
	check("La placa de la oficina usa ceiling_tile.gdshader", tile_shader == "res://game/presentation/materials/office/ceiling_tile.gdshader", tile_shader)

## The palette's floors, walls, lower walls and soft floors by type (3a U2, U8),
## held to the tables the office test keeps.
func check_palette(office_geo) -> void:
	var missing_types: Array = []
	for type in range(TYPE_COUNT):
		for wing in range(3):
			var room := {"type": type, "wing": wing}
			var bad: Array = []
			if not office_geo.materials.has(OFFICE.floor_finish(room)): bad.append("suelo " + OFFICE.floor_finish(room))
			if not office_geo.materials.has(OFFICE.wall_material(room)): bad.append("pared " + OFFICE.wall_material(room))
			if not OFFICE.TRIMS.has(OFFICE.wall_trim(room)): bad.append("friso " + OFFICE.wall_trim(room))
			if not bad.is_empty(): missing_types.append("%d/%d %s" % [type, wing, str(bad)])
	check("Cada tipo y planta tiene material de suelo y de pared, y friso de TRIMS", missing_types.is_empty(), str(missing_types))
	var floors: Array = range(TYPE_COUNT).map(func(t): return OFFICE.floor_finish({"type": t, "wing": 0}))
	check("Suelos de la planta 0 por tipo, como la tabla de suelos del ala 0", floors == FLOOR_WING_0, str(floors))
	var walls: Array = range(TYPE_COUNT).map(func(t): return OFFICE.wall_material({"type": t, "wing": 0}))
	check("Paredes de la planta 0 por tipo, como WALLS_12", walls == WALLS_WING_0, str(walls))
	var trims: Array = range(TYPE_COUNT).map(func(t): return OFFICE.wall_trim({"type": t, "wing": 0}))
	check("Frisos de la planta 0 por tipo", trims == TRIMS_WING_0, str(trims))
	check("Pared de dirección en el ala 2: nogal", OFFICE.wall_material({"type": OFFICE.EXEC_OFFICE, "wing": 2}) == "veneer")
	check("Pared del tipo 24 en el ala 2: pintura", OFFICE.wall_material({"type": OFFICE.SECRETARY, "wing": 2}) == "office_paint")
	check("Pared de la sala de juntas en el ala 2: pintura", OFFICE.wall_material({"type": OFFICE.BOARDROOM, "wing": 2}) == "office_paint")
	check("Suelo de la sala de juntas en el ala 2: moqueta de dirección", OFFICE.floor_finish({"type": OFFICE.BOARDROOM, "wing": 2}) == "carpet_exec")
	check("Suelo del despacho en la planta 0: vinilo", OFFICE.floor_finish({"type": OFFICE.OFFICE, "wing": 0}) == "vinyl")
	check("Suelo de la oficina abierta en la planta 1: vinilo", OFFICE.floor_finish({"type": OFFICE.OPEN_OFFICE, "wing": 1}) == "vinyl")
	var soft: Array = []
	for type in range(TYPE_COUNT):
		for wing in range(3):
			if not OFFICE.hard_floor({"type": type, "wing": wing}): soft.append(Vector2i(type, wing))
	check("Moqueta en las naves de la planta 1 y en juntas, dirección y secretaría de la planta 3", soft == SOFT_FLOORS, str(soft))

## The frieze, the dado, the two tones, the panelled secretary, the zone signs,
## the grilles and the slab, on a floor built at seed 7 (3a U5).
func check_walls(hotel) -> void:
	var stripes := 0
	var cornices := 0
	var dado_panels := 0
	var frieze_bare: Array = []
	var rail_missing: Array = []
	var dado_bare: Array = []
	var two_tone_bare: Array = []
	var wrong_oak: Array = []
	var secretaries := 0
	var veneer_walls := 0
	var bad_slabs: Array = []
	for room in hotel.manifest.rooms:
		if FLOOR.is_void(room): continue
		var node: Node3D = hotel.room_nodes[int(room.id)]
		if not is_instance_valid(node): continue
		var trim: String = OFFICE.wall_trim(room)
		var walls := count(node, "skirting")
		stripes += count(node, "stripe_*")
		cornices += count(node, "trim-plain")
		dado_panels += count(node, "panel")
		if trim == "frieze" and walls > 0:
			if count(node, "dado_oak") == 0: frieze_bare.append(int(room.id))
			# A frieze room glazed on every walled side has no rail: its lower wall stops at the sill.
			var walled: Array = ["north", "south", "west", "east"].filter(func(s): return not room.get("open_sides", []).has(s) and not room.get("glazed", []).has(s))
			var rail := walled.is_empty()
			for t in instances(node, "walnut"):
				if absf(t.origin.y - OG.FRIEZE_TOP) < 0.01: rail = true
			if not rail: rail_missing.append(int(room.id))
		if trim == "dado" and walls > 0 and count(node, "walnut") == 0: dado_bare.append(int(room.id))
		if trim == "two_tone" and walls > 0 and count(node, "two_tone_low") == 0: two_tone_bare.append(int(room.id))
		if trim != "frieze" and count(node, "dado_oak") > 0: wrong_oak.append(int(room.id))
		if trim == "panel_wall":
			secretaries += 1
			for t in instances(node, "veneer"):
				if t.basis.get_scale().y > 2.0:
					veneer_walls += 1
					break
		if not OFFICE.false_ceiling(room):
			if count(node, "slab") == 0 or count(node, "ceiling") > 0 or count(node, "ceiling_service") > 0: bad_slabs.append(int(room.id))
	# Zone signs: one per labelled corridor cell, a plate and a swatch at 1,6 m.
	var signed := 0
	var swatches := 0
	for id in hotel.labelled:
		var labelled_room: Dictionary = hotel.manifest.rooms[int(id)]
		var labelled_node: Node3D = hotel.room_nodes[int(id)]
		if not is_instance_valid(labelled_node): continue
		var want: String = OFFICE.zone_label(hotel.manifest, labelled_room)
		var lettered := false
		for label in labelled_node.find_children("*", "Label3D", true, false):
			var text_node := label as Label3D
			if text_node.text == want and absf(text_node.global_position.y - labelled_node.global_position.y - OG.SIGN_Y) < 0.02: lettered = true
		var plated := false
		for t in instances(labelled_node, "plaque"):
			if absf(t.origin.y - OG.SIGN_Y) < 0.01: plated = true
		if lettered and plated: signed += 1
		swatches += count(labelled_node, "swatch_*")
	# Duct grilles on a wall: in front of the lower wall's face, not buried in it.
	var buried: Array = []
	for e in hotel.manifest.get("ducts", {}).get("exits", []):
		if String(e.kind) != "wall": continue
		var grille_node: Node3D = hotel.room_nodes[int(e.room)]
		if not is_instance_valid(grille_node): continue
		var grille_trim: String = OFFICE.wall_trim(hotel.manifest.rooms[int(e.room)])
		var face := Basis(Vector3.UP, float(e.yaw)).z
		var local := Vector3(float(e.point[0]), float(e.point[1]), float(e.point[2])) - grille_node.position
		var lift_of := {"frieze": OG.DADO_THICK, "two_tone": OG.LINING, "dado": OG.DADO_THICK, "panel_wall": OG.DADO_THICK}
		var lifts: Array = [0.002 + float(lift_of.get(grille_trim, 0.0))]
		if grille_trim == "panel_wall": lifts.append(0.002)
		var placed := false
		for t in instances(grille_node, "black"):
			var off: Vector3 = t.origin - local
			var out := off.dot(face)
			if (off - face * out).length() < 0.01 and lifts.any(func(w): return absf(out - float(w)) < 0.001): placed = true
		if not placed: buried.append(int(e.room))
	check("Sin franjas de color", stripes == 0, str(stripes))
	check("Sin cornisa del hotel", cornices == 0, str(cornices))
	check("Sin el arrimadero del hotel en las esquinas", dado_panels == 0, str(dado_panels))
	check("Friso en cada sala que lo lleva", frieze_bare.is_empty(), str(frieze_bare))
	check("Moldura de nogal a 1 m en cada friso", rail_missing.is_empty(), str(rail_missing))
	check("Zócalo de nogal donde va", dado_bare.is_empty(), str(dado_bare))
	check("Dos tonos en climatización", two_tone_bare.is_empty(), str(two_tone_bare))
	check("El roble solo en el friso", wrong_oak.is_empty(), str(wrong_oak))
	check("La pared de nogal de secretaría", secretaries > 0 and veneer_walls == secretaries, "%d secretarías, %d con chapa" % [secretaries, veneer_walls])
	check("Losa vista sin techo del hotel donde no hay falso techo", bad_slabs.is_empty(), str(bad_slabs))
	check("Un rótulo de zona a 1,6 m en cada celda rotulada", not hotel.labelled.is_empty() and signed == hotel.labelled.size(), "%d de %d" % [signed, hotel.labelled.size()])
	check("Un cuadradito por rótulo", swatches == hotel.labelled.size(), "%d de %d" % [swatches, hotel.labelled.size()])
	check("Rejillas bajas por delante del revestimiento", buried.is_empty(), str(buried))

## The glazed runs: the walnut sill and its board, the frieze under the sill, the
## glass (wired only by the security post) and the beige blinds (3a U6).
func check_glazing(hotel) -> void:
	var frieze_uneven: Array = []
	var bare_sills: Array = []
	var glazed_rooms := 0
	var glass := 0
	var wired_total := 0
	var stray_wire: Array = []
	var bad_blinds: Array = []
	for room in hotel.manifest.rooms:
		if FLOOR.is_void(room): continue
		var node: Node3D = hotel.room_nodes[int(room.id)]
		if not is_instance_valid(node): continue
		# The frieze's oak and the skirting under it stand equally many times.
		if OFFICE.wall_trim(room) == "frieze" and count(node, "dado_oak") != count(node, "skirting"): frieze_uneven.append(int(room.id))
		var glazed: Array = room.get("glazed", [])
		if not glazed.is_empty():
			glazed_rooms += 1
			var has_sill := false
			for t in instances(node, "walnut"):
				if absf(t.origin.y - (OG.GLASS_SILL + OG.SILL_OVER - OG.SILL_BOARD.x * 0.5)) < 0.001: has_sill = true
			if not has_sill: bare_sills.append(int(room.id))
		glass += count(node, "clear_glass") + count(node, "wired_glass")
		var wired := count(node, "wired_glass")
		wired_total += wired
		if wired > 0:
			var types: Array = [int(room.type)]
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var id: int = FLOOR.beside(room, v)
				if id >= 0: types.append(int(hotel.manifest.rooms[id].type))
			if not types.has(OFFICE.SECURITY): stray_wire.append(int(room.id))
	# Every blind: beige, and none at the window counter or the security post.
	for sheet in hotel.panes:
		var boundary: Node = sheet.get_parent()
		var holder: Node = boundary.get_parent()
		var id: int = hotel.room_nodes.find(holder)
		var room: Dictionary = hotel.manifest.rooms[id]
		var other_id: int = FLOOR.beside(room, OG.SIDE_STEP.get(String(boundary.name), Vector2i.ZERO))
		var types: Array = [int(room.type)]
		if other_id >= 0: types.append(int(hotel.manifest.rooms[other_id].type))
		var colour: Color = (sheet.mesh.material as ShaderMaterial).get_shader_parameter("color")
		if not colour.is_equal_approx(OG.BLIND_COLOR) or types.has(OFFICE.WINDOW) or types.has(OFFICE.SECURITY): bad_blinds.append(int(room.id))
	check("Friso igual de largo que el rodapié, también bajo las cristaleras", frieze_uneven.is_empty(), str(frieze_uneven))
	check("Repisa de nogal en cada sala acristalada", bare_sills.is_empty(), str(bare_sills))
	check("Hay vidrio donde hay cristalera", glazed_rooms == 0 or glass > 0, "%d salas, %d vidrios" % [glazed_rooms, glass])
	check("Vidrio armado solo junto a seguridad", stray_wire.is_empty(), str(stray_wire))
	check("Persianas beige y ninguna en ventanilla ni seguridad, mirando las dos salas", bad_blinds.is_empty(), str(bad_blinds))

## The doors: a walnut frame round each doorway and the steel door's own steel
## frame, steel leaves for service and the stages, honey oak for the rest (plain
## or with a vision panel), each the download of office_geometry.DOOR_MODELS (or
## the leaf made in code where one is missing), and a metal threshold on each
## half of every doorway (3a U7).
func check_doors(hotel) -> void:
	var thresholds := 0
	for room in hotel.manifest.rooms:
		if FLOOR.is_void(room): continue
		var node: Node3D = hotel.room_nodes[int(room.id)]
		if not is_instance_valid(node): continue
		thresholds += count(node, "threshold")
	var plaqued := 0
	var vision := 0
	var plain := 0
	var bad_casings: Array = []
	var bad_steel: Array = []
	var bad_leaves: Array = []
	for i in range(hotel.doors.size()):
		var door: Node = hotel.doors[i]
		var casing: MeshInstance3D = hotel.door_fixtures[i][0]
		var leaf := door.get_node("Leaf") as MeshInstance3D
		var face: Material = leaf.mesh.surface_get_material(0)
		var model := leaf.mesh.resource_path
		var steel: bool = hotel.gates.has(door)
		if String(door.name).begins_with("Door_"):
			plaqued += 1
			var ids := String(door.name).split("_")
			var a: Dictionary = hotel.manifest.rooms[int(ids[1])]
			var b: Dictionary = hotel.manifest.rooms[int(ids[2])]
			steel = steel or OG.service_room(a) or OG.service_room(b) or [int(a.type), int(b.type)].any(func(t): return t in [OFFICE.ELECTRICAL, OFFICE.AIR_ROOM, OFFICE.AIR_PLANT])
		var walnut_frame: bool = casing.mesh.surface_get_material(0) == hotel.materials.walnut_object
		if (steel and not (casing.mesh.resource_path == OG.STEEL_FRAME or walnut_frame)) or (not steel and not walnut_frame): bad_casings.append(i)
		if steel and model != OG.DOOR_MODELS.service and face != hotel.materials.steel_olive: bad_steel.append(i)
		if not steel:
			if model == OG.DOOR_MODELS.vision or (model.is_empty() and face == hotel.materials.oak_door and leaf.mesh.get_surface_count() == 3): vision += 1
			elif model == OG.DOOR_MODELS.plain or (model.is_empty() and face == hotel.materials.oak_door): plain += 1
			else: bad_leaves.append(i)
	check("Marco de nogal en cada puerta, de acero en las de acero", bad_casings.is_empty(), str(bad_casings))
	check("Acero verde gris en servicio, cuartos técnicos y etapas", bad_steel.is_empty(), str(bad_steel))
	check("Roble en las demás", bad_leaves.is_empty(), str(bad_leaves))
	check("Puertas de roble con y sin ventanuco", vision > 0 and plain > 0, "%d con ventanuco, %d lisas" % [vision, plain])
	check("Un umbral partido en dos por vano", thresholds == 2 * plaqued, "%d medias tiras, %d vanos" % [thresholds, plaqued])

## The office's sets leave the hotel's scan cache with their floor: a floor 1
## built after this one, in the same process, keeps none of them in memory (3a fix D1).
func check_scan_cache(level) -> void:
	check("Piso 2: sus sets de oficina están en la caché de escaneos", not office_keys().is_empty(), str(office_keys()))
	await level.start_floor(7, false, [1], "apacible", 1)
	check("El piso 1 es el hotel", not String(level.hotel.get_script().resource_path).ends_with("office_geometry.gd"), String(level.hotel.get_script().resource_path))
	check("Tras el piso 1 no queda ningún set de oficina en la caché", office_keys().is_empty(), str(office_keys()))

## The cache's keys that belong to the office's own sets (scan_maps() in hotel_geometry.gd).
func office_keys() -> Array:
	var keys: Array = []
	for key in HG.scans.keys():
		if String(key).begins_with("office_"): keys.append(key)
	return keys
