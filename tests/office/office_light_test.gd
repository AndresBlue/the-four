extends SceneTree
## Floor 2's light (.claude/specs/spec_rediseno.md 4, area 3b): the lamps'
## colour by type and the troffer families in the palette; the bounce light's
## office colours; and on a floor built at seed 7: each lamp in its room's
## colour, the lenses and tubes put out with their room, each family's face
## under a housing open below, the reception lift's wall lamps, the ceiling
## halo following its lamp, the room lit by its troffers and every fitting
## going with her drain and the power, the lie's dark lens under its family's face, the
## accent register, the reception's beacon and no halo over a hole.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const OG := preload("res://game/world/office/office_geometry.gd")
const HG := preload("res://game/world/hotel/hotel_geometry.gd")
const OB := preload("res://game/world/office/office_bounce.gd")
const BL := preload("res://game/world/hotel/bounce_light.gd")
const LIGHTING := preload("res://game/world/hotel/lighting.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const ACCENTS := preload("res://game/world/office/office_accents.gd")
const LANDMARKS := preload("res://game/world/office/office_landmarks.gd")
const PICTURES := preload("res://game/world/office/office_pictures.gd")
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	var kept: String = detail if not passed else ""
	checks.append({"check": title, "passed": passed, "detail": kept})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, ("  (" + detail + ")") if not passed and not detail.is_empty() else "")

## Instances of a batched group under a room node ("Mesh_<group>"; wildcards allowed).
func count(node: Node, group: String) -> int:
	var total := 0
	for found in node.find_children("Mesh_" + group, "MultiMeshInstance3D", true, false): total += (found as MultiMeshInstance3D).multimesh.instance_count
	return total

func near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.002 and absf(a.g - b.g) < 0.002 and absf(a.b - b.b) < 0.002

func expected(material: Material) -> Variant:
	if material is ShaderMaterial: return (material as ShaderMaterial).get_shader_parameter("flat_color")
	if material is BaseMaterial3D: return (material as BaseMaterial3D).albedo_color
	return null

func kelvin(room_type: int) -> float:
	return OFFICE.lamp_kelvin({"type": room_type, "wing": 0})

func look_of(room_type: int) -> String:
	return OFFICE.troffer_look({"type": room_type, "wing": 0})

## Lights a room of a family with two or more troffers and has one fail (the
## lie): its dark lens's height over the room's ceiling, NAN when the seed has
## no such room, INF when no lens appeared.
func lie_drop(hotel, look: String) -> float:
	var chosen := {}
	for room in hotel.manifest.rooms:
		if not FLOOR.is_void(room) and OFFICE.troffer_look(room) == look and OFFICE.troffers(room).size() >= 2: chosen = room
	if chosen.is_empty():
		print("INFO sin sala de la familia ", look, " con dos pantallas en la semilla 7")
		return NAN
	var id := int(chosen.id)
	hotel.set_room_power(id, false)
	hotel.dark_ids.erase(id)
	hotel.set_room_power(id, true)
	var before: Array = hotel.get_children()
	if not hotel.flicker_one(id, 5.0, 3): return INF
	for child in hotel.get_children():
		if child is MeshInstance3D and not before.has(child): return (child as Node3D).global_position.y - float(chosen.get("py", 0.0)) - float(chosen.height)
	return INF

## The pieces troffer_face() lays for one troffer, by group, in the troffer's
## frame: headless, Godot reads every MultiMesh transform back as identity, so
## they are read from the batch before any flush, under a node of no room.
func face_pieces(hotel, h: float, along_z: bool, look: String) -> Dictionary:
	var scratch := Node3D.new()
	var size: Vector3 = Vector3(0.6, OG.TROFFER_BODY, 1.2) if along_z else Vector3(1.2, OG.TROFFER_BODY, 0.6)
	hotel.troffer_face(scratch, Vector3.ZERO, size, h, "probe_glow", look)
	var key: int = scratch.get_instance_id()
	var groups: Dictionary = hotel.batches[key].groups
	hotel.batches.erase(key)
	scratch.free()
	return groups

## The lamps' colour by type and the troffer families in the palette (U1).
func block_palette() -> void:
	check("Una temperatura por cada uno de los 27 tipos", OFFICE.LAMP_KELVIN.size() == 27)
	check("Las salas, a 3000 K", kelvin(OFFICE.OFFICE) == 3000.0 and kelvin(OFFICE.OPEN_OFFICE) == 3000.0 and kelvin(OFFICE.MAIL) == 3000.0 and kelvin(OFFICE.SECRETARY) == 3000.0)
	check("Los pasillos, a 3500 K", kelvin(OFFICE.CORRIDOR) == 3500.0 and kelvin(OFFICE.GALLERY) == 3500.0)
	check("Ámbar en recepción y descanso", kelvin(OFFICE.RECEPTION) == 2700.0 and kelvin(OFFICE.BREAK_ROOM) == 2700.0)
	check("Neutra en juntas y dirección", kelvin(OFFICE.BOARDROOM) == 3300.0 and kelvin(OFFICE.EXEC_OFFICE) == 3300.0)
	# The reception's plain lens, as its reference (13 November 2026).
	check("Lisa en recepción, estrecha en juntas, parabólica en secretaría, envolvente en dirección", look_of(OFFICE.RECEPTION) == "prismatic" and look_of(OFFICE.BOARDROOM) == "narrow" and look_of(OFFICE.SECRETARY) == "parabolic" and look_of(OFFICE.EXEC_OFFICE) == "wrap")
	check("Prismática en el resto", look_of(OFFICE.OFFICE) == "prismatic" and look_of(OFFICE.CORRIDOR) == "prismatic" and look_of(OFFICE.MAIL) == "prismatic")
	var unknown: Array = range(27).filter(func(t): return not OFFICE.TROFFER_LOOKS.has(look_of(t)))
	check("Toda familia está en TROFFER_LOOKS", unknown.is_empty())
	check("La lámpara de cada tipo no cambia", OFFICE.lamp_of({"type": OFFICE.BOARDROOM, "wing": 0}) == "troffer" and OFFICE.lamp_of({"type": OFFICE.ARCHIVE, "wing": 0}) == "batten" and OFFICE.lamp_of({"type": OFFICE.ELECTRICAL, "wing": 0}) == "emergency")

## The bounce light's stand-in in the office's own colours; the hotel's untouched (U7).
func block_bounce() -> void:
	var office = OG.new()
	var hotel = HG.new()
	check("El piso 2 rebota con lo suyo", office.bounce.get_script() == OB)
	check("El hotel, con el de siempre", hotel.bounce.get_script() == BL)
	var missing: Array = OG.PLAIN.keys().filter(func(k): return not office.bounce.own.has(k))
	check("Cada clave lisa de la oficina tiene su color de rebote " + str(missing), missing.is_empty())
	var wrong: Array = OG.PLAIN.keys().filter(func(k): return office.bounce.own.has(k) and not (office.bounce.own[k].albedo_color as Color).is_equal_approx(expected(office.materials[k])))
	check("Con el color de su material " + str(wrong), wrong.is_empty())
	check("Lo del hotel que la oficina no cambia sigue con su color medido", not office.bounce.own.has("plaster") and not office.bounce.own.has("metal"))
	for key in OG.OWN_OVER:
		if expected(office.materials[key]) is Color: check("La oficina rebota su " + key, office.bounce.own.has(key))
	office.bounce.shapes["office_paint"] = BL.unindexed(HG.unit_mesh("office_paint"))
	office.bounce.shapes["plaster"] = BL.unindexed(HG.unit_mesh("plaster"))
	BL.stand_in_colours()
	var mesh: Mesh = office.bounce.stand_in_mesh([["office_paint", [Transform3D.IDENTITY], Vector3.ZERO], ["plaster", [Transform3D(Basis.IDENTITY, Vector3(3, 0, 0))], Vector3.ZERO]], Vector3.ZERO)
	check("El doble: la pintura de la oficina en su color, el yeso del hotel en el suyo", mesh.get_surface_count() == 2 and mesh.surface_get_material(0) == office.bounce.own.office_paint and mesh.surface_get_material(1) == BL.colours["plaster"])
	check("Las lentes y lo que brilla no rebotan", not office.bounces("troffer_lens_3000") and not office.bounces("troffer_fail_2") and not office.bounces("lens_off") and not office.bounces("glow_screen@plain"))
	check("Las paredes y las placas sí", office.bounces("office_paint") and office.bounces("ceiling_service"))
	office.free()
	hotel.free()

## Each lamp in its room's colour, its lenses and tubes put out with their room (U2).
func block_lamps(hotel) -> void:
	var colours_ok := true
	var specular_ok := true
	var named := true
	var dark_out := true
	var dark_id := -1
	var refuge_id := -1
	var office_colour := Color()
	var corridor_colour := Color()
	for room in hotel.manifest.rooms:
		if FLOOR.is_void(room): continue
		var id := int(room.id)
		var lamp: String = OFFICE.lamp_of(room)
		if lamp == "emergency": continue
		var light: OmniLight3D = hotel.lights[id]
		if int(room.type) == OFFICE.REFUGE:
			# The refuge keeps the hotel's green (extras()).
			refuge_id = id
		elif not near(light.light_color, LIGHTING.light_color(OFFICE.lamp_kelvin(room))): colours_ok = false
		if absf(light.light_specular - OG.LAMP_SPECULAR) > 0.001: specular_ok = false
		if int(room.type) == OFFICE.OFFICE: office_colour = light.light_color
		if int(room.type) == OFFICE.CORRIDOR: corridor_colour = light.light_color
		if OFFICE.troffers(room).is_empty() or not OFFICE.false_ceiling(room): continue
		var node: Node3D = hotel.room_nodes[id]
		if node.get_node_or_null("Mesh_troffer_lens_%d" % int(OFFICE.lamp_kelvin(room))) == null and node.find_children("Mesh_troffer_fail*", "MultiMeshInstance3D", false, false).is_empty(): named = false
		if hotel.dark_room(room):
			if dark_id < 0: dark_id = id
			for mesh in hotel.lenses_of(id):
				if String(mesh.name).begins_with("Mesh_troffer_lens") and mesh.material_override != hotel.materials.lens_off: dark_out = false
	check("Cada lámpara, del color de su sala", colours_ok)
	check("Pantallas y regletas con su brillo especular", specular_ok)
	check("Cada sala de pantallas tiene su lente troffer_lens_<K>", named)
	check("Hay una sala oscura con pantallas en la semilla 7", dark_id >= 0)
	check("Las lentes de una sala oscura, apagadas", dark_out)
	check("El pasillo, más frío que el despacho", office_colour != Color() and corridor_colour != Color() and corridor_colour.b / corridor_colour.r > office_colour.b / office_colour.r, "%s %s" % [office_colour, corridor_colour])
	if refuge_id < 0: print("INFO sin refugio en la semilla 7")
	else: check("El refugio conserva el verde del hotel", near(hotel.lights[refuge_id].light_color, Color("b8d4b6")))
	if dark_id >= 0:
		hotel.set_room_power(dark_id, false)
		hotel.dark_ids.erase(dark_id)
		hotel.set_room_power(dark_id, true)
		var lenses: Array = hotel.lenses_of(dark_id).filter(func(m): return String(m.name).begins_with("Mesh_troffer"))
		check("Una sala oscura que recupera la luz enciende sus lentes", not lenses.is_empty() and lenses.all(func(m): return m.material_override == null))
	var failing_id := -1
	for room in hotel.manifest.rooms:
		if FLOOR.is_void(room) or not hotel.lit(int(room.id)): continue
		if not hotel.room_nodes[int(room.id)].find_children("Mesh_troffer_fail*", "MultiMeshInstance3D", false, false).is_empty():
			failing_id = int(room.id)
			break
	if failing_id < 0: print("INFO ninguna luminaria falla en una sala con luz en la semilla 7")
	else:
		var fail: Array = hotel.lenses_of(failing_id).filter(func(m): return String(m.name).begins_with("Mesh_troffer_fail"))
		check("lenses_of() encuentra la lente que falla", fail.size() == 1)
		hotel.set_room_power(failing_id, false)
		var out: bool = fail.all(func(m): return m.material_override == hotel.materials.lens_off)
		hotel.set_room_power(failing_id, true)
		check("Sin corriente, la lente que falla se apaga; con ella vuelve", out and fail.all(func(m): return m.material_override == null))
	var tube_id := -1
	for room in hotel.manifest.rooms:
		if FLOOR.is_void(room) or not hotel.lit(int(room.id)): continue
		if not hotel.room_nodes[int(room.id)].find_children("Mesh_tube_*", "MultiMeshInstance3D", false, false).is_empty():
			tube_id = int(room.id)
			break
	if tube_id < 0: print("INFO ninguna regleta del hotel falla en una sala con luz en la semilla 7")
	else:
		var tubes: Array = hotel.lenses_of(tube_id).filter(func(m): return String(m.name).begins_with("Mesh_tube_"))
		check("lenses_of() encuentra la regleta que falla", not tubes.is_empty())
		if not tubes.is_empty():
			var key := String(tubes[0].name).trim_prefix("Mesh_").get_slice("-", 0)
			check("Su tubo brilla del color de la sala", near((hotel.materials[key] as BaseMaterial3D).emission, hotel.lights[tube_id].light_color))
			hotel.set_room_power(tube_id, false)
			var out: bool = tubes.all(func(m): return m.material_override == hotel.materials.lens_off)
			hotel.set_room_power(tube_id, true)
			check("Sin corriente, la regleta que falla se apaga; con ella vuelve", out and tubes.all(func(m): return m.material_override == null))

## Each family's face at its height, with its width and pieces, under a housing open below (U3).
func block_faces(hotel) -> void:
	var seen := {}
	var bad: Array = []
	for room in hotel.manifest.rooms:
		if FLOOR.is_void(room): continue
		var lamps: Array = OFFICE.troffers(room)
		if lamps.is_empty() or not OFFICE.false_ceiling(room): continue
		var id := int(room.id)
		var node: Node3D = hotel.room_nodes[id]
		var h := float(room.height)
		var look: String = OFFICE.troffer_look(room)
		if count(node, "troffer_lens_%d" % int(OFFICE.lamp_kelvin(room))) == 0: continue
		var faces: Dictionary = face_pieces(hotel, h, bool(lamps[0].along_z), look)
		var lenses: Array = faces.get("probe_glow", [])
		if lenses.size() != 1: bad.append("%s lentes %d en %d" % [look, lenses.size(), id])
		seen[look] = true
		var y: float = h + OG.LENS_RECESS
		if look == "parabolic": y = h + OG.PARABOLIC_DEPTH
		elif look == "wrap": y = h - (0.03 + OG.WRAP_DROP) * 0.5
		if not lenses.all(func(t: Transform3D): return absf(t.origin.y - y) < 0.002): bad.append("%s altura %d" % [look, id])
		var narrowest: float = lenses.map(func(t: Transform3D): return minf(t.basis.x.length(), t.basis.z.length())).min()
		if look == "narrow" and absf(narrowest - OG.NARROW_LENS) > 0.002: bad.append("narrow ancho %d" % id)
		if look == "prismatic" and narrowest < 0.5: bad.append("prismatic ancho %d" % id)
		var per := 0
		if look == "narrow": per = 1 + int(1.16 / OG.LOUVRE_PITCH)
		elif look == "parabolic": per = 2 + maxi(1, roundi(1.16 / OG.PARABOLIC_PITCH))
		elif look == "wrap": per = 1
		var pieces := count(node, "enamel")
		if pieces < per * lamps.size(): bad.append("%s piezas %d de %d en %d" % [look, pieces, per * lamps.size(), id])
		var bodies: Array = faces.get("troffer_body", [])
		var want_bodies: int = 0 if look == "wrap" else 5 * lamps.size()
		if count(node, "troffer_body") != want_bodies: bad.append("%s carcasas %d de %d en %d" % [look, count(node, "troffer_body"), want_bodies, id])
		var hidden := false
		for l: Transform3D in lenses:
			for b: Transform3D in bodies:
				var covers: bool = absf(b.origin.x - l.origin.x) < b.basis.x.length() * 0.5 - 0.001 and absf(b.origin.z - l.origin.z) < b.basis.z.length() * 0.5 - 0.001
				if covers and b.origin.y - b.basis.y.length() * 0.5 < l.origin.y + l.basis.y.length() * 0.5 - 0.0005: hidden = true
		if hidden: bad.append("%s carcasa bajo la lente en %d" % [look, id])
	check("Cada familia a su altura, con su ancho, sus piezas y su carcasa abierta " + str(bad), bad.is_empty())
	for look in ["prismatic", "narrow"]: check("Hay pantallas de la familia " + look, seen.has(look))
	for look in ["parabolic", "wrap"]:
		if not seen.has(look): print("INFO sin sala de la familia ", look, " en la semilla 7")

## The reception lift's two wall lamps, the reception's accents (U6).
func block_lift(hotel) -> void:
	var start := int(hotel.manifest.get("start", -1))
	# Only the wall lamps: area 4c's desk lamp on the counter is an accent too (no mesh).
	var entries: Array = hotel.accents.of_room(start).filter(func(e: Dictionary): return e.mesh != null)
	check("Dos apliques en la recepción", entries.size() == 2, str(entries.size()))
	if entries.size() == 2:
		var m0: MeshInstance3D = entries[0].mesh
		var m1: MeshInstance3D = entries[1].mesh
		check("Los dos, en el ascensor de llegada", String(m0.get_parent().name) == "ArrivalLift" and String(m1.get_parent().name) == "ArrivalLift")
		check("A la misma altura, a la misma distancia de la pared y a los dos lados", is_equal_approx(m0.position.y, OG.LIFT_SCONCE.y) and is_equal_approx(m1.position.y, OG.LIFT_SCONCE.y) and is_equal_approx(m0.position.z, m1.position.z) and is_equal_approx(m0.position.x, -m1.position.x) and m1.position.x - m0.position.x > 1.0)
		check("Lejos del pulsador", absf(m0.position.x - HG.CALL_AT.x) > 0.25 and absf(m1.position.x - HG.CALL_AT.x) > 0.25, "%.2f %.2f" % [m0.position.x, m1.position.x])
		var room: Dictionary = hotel.manifest.rooms[start]
		var back := Vector3(float(hotel.manifest.arrival_lift[0]), 0, float(hotel.manifest.arrival_lift[1]))
		var span := FLOOR.size_of(room)
		var along: float = (span.y if back.x != 0 else span.x) * 0.5
		check("Dentro de su pared", absf(m0.position.x) < along - 0.3 and absf(m1.position.x) < along - 0.3, "%.2f %.2f" % [m1.position.x, along])
		var light: OmniLight3D = entries[0].light
		check("Su luz, en el registro de apliques", hotel.sconce_lights.has(light) and int(hotel.accents.by_sconce.get(int(entries[0].sconce), -1)) == start)
		check("La luz, a la altura del aplique y BOX_LAMP_OUT delante de la pared", absf(light.global_position.y - m0.global_position.y) < 0.01 and absf(light.global_position.distance_to(m0.global_position) - OG.BOX_LAMP_OUT) < 0.01)
		check("El aplique no proyecta sombra sobre su propia luz", m0.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		check("Las dos luces, en las capas de su sala", hotel.kept_lamps.has(light.get_instance_id()) and hotel.kept_lamps.has((entries[1].light as Object).get_instance_id()))
	# Area 4c hangs lamps in other rooms too; what holds is the register's cap per room.
	# The reception takes its own cap (office_accents.caps, OG.RECEPTION_ACCENTS); the rest ACCENTS.MOST.
	var over: Array = []
	for room_id: int in hotel.accents.rooms:
		if hotel.accents.of_room(room_id).size() > hotel.accents.cap_of(room_id): over.append(room_id)
	check("Ninguna sala pasa de su tope de acentos", over.is_empty() and hotel.accents.cap_of(start) == OG.RECEPTION_ACCENTS, str(over))
	check("Las demás salas, a su tope de siempre", hotel.accents.rooms.keys().all(func(id: int) -> bool: return id == start or hotel.accents.cap_of(id) == ACCENTS.MOST))
	# No red beacon in the offices' reception (the author, 12 November 2026).
	check("La recepción no lleva baliza", not hotel.beacons.any(func(e: Dictionary) -> bool: return int(e.room) == start) and hotel.room_nodes[start].find_child("StartBeacon", true, false) == null)
	if not hotel.halos.has(start) or hotel.flickers.any(func(e): return e.light == hotel.lights[start]): print("INFO la lámpara de la recepción falla o no tiene halo en la semilla 7")
	else: check("La lámpara de la recepción, entera", absf(hotel.lights[start].light_energy - float(hotel.halos[start].base)) < 0.001, "%.3f de %.3f" % [hotel.lights[start].light_energy, float(hotel.halos[start].base)])

## The ceiling halo of each troffer room, following its lamp (U4).
func block_halos(hotel) -> void:
	var all_halos := true
	var shadowless := true
	var layered_ok := true
	for room in hotel.manifest.rooms:
		if FLOOR.is_void(room): continue
		var lamps: Array = OFFICE.troffers(room)
		if lamps.is_empty(): continue
		if not OFFICE.false_ceiling(room): continue
		var id := int(room.id)
		var halo := hotel.room_nodes[id].get_node_or_null("CeilingHalo") as MeshInstance3D
		# A rectangle per troffer, and one more for each open cell its glow
		# reaches over the seam (ceiling_halo(), luz6).
		var corners: int = 0 if halo == null else halo.mesh.surface_get_array_len(0)
		if halo == null or not hotel.halos.has(id) or corners < 6 * lamps.size() or corners % 6 != 0: all_halos = false
		else:
			if halo.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF: shadowless = false
			var bit: int = 0 if hotel.room_layers.is_empty() else int(hotel.room_layers.layer[id])
			if bit != 0 and (halo.layers & bit) == 0: layered_ok = false
	check("Cada sala de pantallas tiene su halo, un rectángulo por pantalla (y su paso a las celdas abiertas)", all_halos)
	check("El halo no proyecta sombra", shadowless)
	check("El halo, en la capa de su sala", layered_ok)
	var hue_ok := true
	for id: int in hotel.halos:
		# An archive's battens light without a halo (archive_battens()).
		if hotel.halos[id].material == null: continue
		if not ((hotel.halos[id].material as ShaderMaterial).get_shader_parameter("glow") as Color).is_equal_approx(hotel.lights[id].light_color): hue_ok = false
	check("Cada halo, del color de su lámpara", hue_ok)
	var start := int(hotel.manifest.get("start", -1))
	var lit_room := {}
	var dark_room := {}
	for room in hotel.manifest.rooms:
		if FLOOR.is_void(room) or OFFICE.troffers(room).is_empty() or not OFFICE.false_ceiling(room): continue
		var rid := int(room.id)
		if lit_room.is_empty() and int(room.get("wing", 0)) == 0 and rid != start and int(room.type) != OFFICE.REFUGE and hotel.lit(rid) and not hotel.flickers.any(func(e): return e.light == hotel.lights[rid]): lit_room = room
		if dark_room.is_empty() and hotel.dark_room(room): dark_room = room
	check("Hay una sala con luz y pantallas en la planta 1", not lit_room.is_empty())
	if not lit_room.is_empty():
		var id := int(lit_room.id)
		var spot := FLOOR.position_of(lit_room) + Vector3(0, 1.5, 0)
		hotel.update_visibility(spot, true)
		hotel._process(0.016)
		var full: float = float(hotel.halos[id].energy)
		check("Con la lámpara entera, el halo a HALO_ENERGY", absf(full - OG.HALO_ENERGY) < 0.01, "%.3f" % full)
		check("La base del halo es la energía de su lámpara", absf(float(hotel.halos[id].base) - hotel.lights[id].light_energy) < 0.001)
		hotel.drain(id, 0.5)
		hotel._process(0.016)
		check("Ella bebe la mitad: el halo, a la mitad", absf(float(hotel.halos[id].energy) - OG.HALO_ENERGY * 0.5) < 0.01, "%.3f" % float(hotel.halos[id].energy))
		hotel.drain(id, 0.0)
		hotel.set_room_power(id, false)
		hotel._process(0.016)
		check("Sin corriente, sin halo", float(hotel.halos[id].energy) == 0.0)
		hotel.set_room_power(id, true)
		hotel.update_visibility(spot, true)
		hotel._process(0.016)
		check("Con la corriente, vuelve", absf(float(hotel.halos[id].energy) - OG.HALO_ENERGY) < 0.01)
		var material: ShaderMaterial = hotel.halos[id].material
		check("El halo, del color de su sala", (material.get_shader_parameter("glow") as Color).is_equal_approx(LIGHTING.light_color(OFFICE.lamp_kelvin(lit_room))))
	if not dark_room.is_empty(): check("Una sala oscura, sin halo", float(hotel.halos[int(dark_room.id)].energy) == 0.0)

## What a lit fitting glows with now: its override, else its own material
## (a batten's glass by its surface); 0 when that does not glow.
func glow_of(mesh: GeometryInstance3D) -> float:
	var material: Material = mesh.material_override
	if mesh.has_meta("glow_surface"): material = (mesh as MeshInstance3D).get_surface_override_material(int(mesh.get_meta("glow_surface")))
	elif material == null: material = ((mesh as MultiMeshInstance3D).multimesh.mesh if mesh is MultiMeshInstance3D else (mesh as MeshInstance3D).mesh).surface_get_material(0)
	if not material is BaseMaterial3D or not (material as BaseMaterial3D).emission_enabled: return 0.0
	return (material as BaseMaterial3D).emission_energy_multiplier

## A room's light from its fittings (the author, 14 November 2026), at Alto:
## its lamp lights nothing and casts nothing, its troffers light and the
## nearest cast; she drinks it or the power goes and every fitting of it goes
## at once, by the same share, lenses too; and all of them come back.
func block_fittings(hotel) -> void:
	hotel.apply_quality(PRESETS.of(PRESETS.HIGH))
	var room := {}
	for candidate in hotel.manifest.rooms:
		var rid := int(candidate.id)
		if FLOOR.is_void(candidate) or int(candidate.get("wing", 0)) != 0 or OFFICE.troffers(candidate).size() < 4 or not hotel.lit(rid) or not hotel.halos.has(rid): continue
		if hotel.flickers.any(func(e): return e.light == hotel.lights[rid]): continue
		room = candidate
		break
	check("Hay una sala con luz y cuatro pantallas o más en la planta 1", not room.is_empty())
	if room.is_empty(): return
	if not hotel.pools_shown():
		print("INFO sin charcos con el método ", RenderingServer.get_current_rendering_method(), ": no se mira la luz de las pantallas")
		return
	var id := int(room.id)
	var n := OFFICE.troffers(room).size()
	var spot := FLOOR.position_of(room) + Vector3(0, 1.5, 0)
	var lamp: OmniLight3D = hotel.lights[id]
	var pools: Array = hotel.halos[id].pools
	var lenses: Array = hotel.lenses_of(id)
	var own: Array = lenses.map(func(m): return glow_of(m))
	hotel.update_visibility(spot, true)
	hotel._process(0.016)
	hotel.update_visibility(spot, true)
	check("La sala tiene %d pantallas, cada una con su foco y su rebote, y sus lentes" % n, pools.size() == n * 2 and pools.filter(func(p): return p.has_meta("casts")).size() == n and not lenses.is_empty(), "%d luces, %d lentes" % [pools.size(), lenses.size()])
	check("Su lámpara sigue, encendida, pero no alumbra ni da sombra", lamp.visible and lamp.light_cull_mask == 0 and not lamp.shadow_enabled and lamp.light_energy > 0.0)
	check("Alumbran sus pantallas", pools.all(func(p): return p.visible and p.light_energy > 0.0))
	# Each troffer's bounce: what its floor gives back, in the room's volume; the lamp out of it.
	var bounces: Array = pools.filter(func(p): return not p.has_meta("casts"))
	var back_of: Dictionary = hotel.bounce_of(room)
	var wanted := OG.POOL_ENERGY * OG.dim_of(room) * float(back_of.share)
	check("Cada rebote sale de su suelo: la energía de su foco por lo que devuelve la sala, en su volumen de rebote", bounces.size() == n and bounces.all(func(p): return absf(float(p.get_meta("energy")) - wanted) < 0.001 and p.spot_angle == OG.BOUNCE_ANGLE and p.light_bake_mode == Light3D.BAKE_DYNAMIC), "%.3f" % wanted)
	check("La lámpara de la sala no entra en el volumen", lamp.light_bake_mode == Light3D.BAKE_DISABLED)
	# A corridor's vinyl tile against a nave's carpet: the darker floor gives back less, and less of its colour.
	var hall: Dictionary = hotel.bounce_of({"type": OFFICE.CORRIDOR})
	var carpet: Dictionary = hotel.bounce_of({"type": OFFICE.OPEN_OFFICE, "wing": 0})
	var hall_tint: Color = hall.tint
	var carpet_tint: Color = carpet.tint
	print("INFO rebote de la sala %.3f, de un pasillo %.3f, de una nave con moqueta %.3f" % [back_of.share, hall.share, carpet.share])
	check("Un suelo más oscuro devuelve menos, y menos de su color", float(carpet.share) > 0.0 and float(carpet.share) < float(hall.share) and carpet_tint.r - carpet_tint.b < hall_tint.r - hall_tint.b, "%s %s" % [hall_tint, carpet_tint])
	# The reception gives back RECEPTION_BOUNCE of what its floor alone would (rev13).
	var reception: Dictionary = hotel.manifest.rooms[int(hotel.manifest.start)]
	var ground: Color = hotel.bounce.colour_of(OFFICE.floor_look(reception)).srgb_to_linear()
	var mean: float = OG.FLOOR_SHARE * maxf(ground.get_luminance(), 0.01) + (1.0 - OG.FLOOR_SHARE) * OG.ROOM_REFLECT
	var plain_share: float = OG.BOUNCE_SHARE * mean / (1.0 - mean)
	check("La recepción devuelve RECEPTION_BOUNCE de lo que daría su suelo", absf(float(hotel.bounce_of(reception).share) - OG.RECEPTION_BOUNCE * plain_share) < 0.0005, "%.3f" % float(hotel.bounce_of(reception).share))
	var casting := 0
	for rid: int in hotel.halos:
		for p in hotel.halos[rid].pools: if p.has_meta("casts") and p.shadow_enabled: casting += 1
	check("Dan sombra las pantallas más cercanas, POOLS_CAST como mucho", pools.any(func(p): return p.shadow_enabled) and casting <= OG.POOLS_CAST, "%d con sombra" % casting)
	hotel.drain(id, 0.5)
	hotel._process(0.016)
	var half_pools: bool = pools.all(func(p): return absf(p.light_energy - float(p.get_meta("energy")) * 0.5) < 0.01)
	var half_lenses := true
	for k in lenses.size(): if absf(glow_of(lenses[k]) - float(own[k]) * 0.5) > 0.01: half_lenses = false
	check("Ella bebe la mitad: las %d pantallas, sus rebotes y sus lentes, a la mitad a la vez" % n, half_pools and half_lenses)
	check("Sus rebotes, a la mitad de los suyos", bounces.all(func(p): return p.visible and absf(p.light_energy - wanted * 0.5) < 0.01))
	hotel.drain(id, 1.0)
	hotel._process(0.016)
	var dark_pools: bool = pools.all(func(p): return not p.visible or p.light_energy == 0.0)
	check("Bebida entera: las %d a oscuras a la vez, lentes incluidas" % n, dark_pools and lenses.all(func(m): return glow_of(m) == 0.0) and lamp.light_energy == 0.0)
	hotel.drain(id, 0.0)
	hotel._process(0.016)
	check("Al soltarla vuelven las %d, con sus lentes" % n, pools.all(func(p): return p.visible and absf(p.light_energy - float(p.get_meta("energy"))) < 0.01) and lenses.all(func(m): return m.material_override == null or m.has_meta("glow_surface")))
	check("Y sus rebotes enteros", bounces.all(func(p): return p.visible and absf(p.light_energy - wanted) < 0.01))
	hotel.set_room_power(id, false)
	hotel._process(0.016)
	check("Sin corriente, las %d a oscuras, lentes incluidas" % n, pools.all(func(p): return not p.visible) and lenses.all(func(m): return glow_of(m) == 0.0))
	hotel.set_room_power(id, true)
	hotel.update_visibility(spot, true)
	hotel._process(0.016)
	var back := true
	for k in lenses.size(): if absf(glow_of(lenses[k]) - float(own[k])) > 0.001: back = false
	check("Con la corriente, vuelven todas", back and pools.all(func(p): return p.visible))
	hotel.apply_quality(PRESETS.of(PRESETS.MEDIUM))
	hotel.update_visibility(spot, true)
	hotel._process(0.016)
	check("En Medio la lámpara alumbra como siempre y las pantallas no", lamp.light_cull_mask != 0 and pools.all(func(p): return not p.visible))
	check("En Medio la lámpara vuelve a su volumen", lamp.light_bake_mode == Light3D.BAKE_DYNAMIC)

## Dust in the air (14 November 2026): the offices' air by planta through the
## rig's grade, the torch lighting it, each light lighting it only while it
## casts (a fitted lamp, a bounce and an unshadowed pool never), the battery
## units at theirs; the motes round the eye instead of the hotel's, gone with
## reduced effects and on Bajo.
func block_air(level, hotel) -> void:
	hotel.apply_quality(PRESETS.of(PRESETS.HIGH))
	var spot := FLOOR.position_of(hotel.manifest.rooms[int(hotel.manifest.start)]) + Vector3(0, 1.5, 0)
	hotel.update_visibility(spot, true)
	level.rig.apply_grade()
	check("Planta 1: el aire de las oficinas y la linterna en él", is_equal_approx(level.environment.volumetric_fog_density, OG.AIR_DENSITY[0]) and is_equal_approx(level.environment.volumetric_fog_anisotropy, OG.AIR_ANISOTROPY) and is_equal_approx(level.player.torch.light_volumetric_fog_energy, OG.TORCH_AIR), "%.4f %.2f %.2f" % [level.environment.volumetric_fog_density, level.environment.volumetric_fog_anisotropy, level.player.torch.light_volumetric_fog_energy])
	hotel.eye_planta = 2
	level.rig.follow_grade()
	check("Planta 3: más polvo en el aire", is_equal_approx(level.environment.volumetric_fog_density, OG.AIR_DENSITY[2]) and OG.AIR_DENSITY[2] > OG.AIR_DENSITY[0])
	hotel.update_visibility(spot, true)
	var fitted: Array = []
	var pools_ok := true
	for id: int in hotel.things_on(0).rooms:
		var lamp = hotel.lights[id] if id < hotel.lights.size() else null
		if lamp != null and is_instance_valid(lamp) and hotel.lit_by_fittings(lamp): fitted.append(lamp)
		if not hotel.halos.has(id): continue
		for p: Light3D in hotel.halos[id].pools:
			var wanted: float = OG.POOL_AIR if p.rotation.x < 0.0 and p.shadow_enabled else 0.0
			if not is_equal_approx(p.light_volumetric_fog_energy, wanted): pools_ok = false
	if hotel.pools_shown(): check("Una lámpara que no alumbra no alumbra el aire", not fitted.is_empty() and fitted.all(func(l): return l.light_volumetric_fog_energy == 0.0), "%d lámparas" % fitted.size())
	check("Las pantallas, poco y solo con sombra; los rebotes, nada", pools_ok)
	check("Los focos de emergencia alumbran el aire", not hotel.emergency.is_empty() and hotel.emergency.all(func(e): return e.light.light_volumetric_fog_energy == (OG.EMERGENCY_AIR if e.light.shadow_enabled else 0.0)))
	check("Las motas de las oficinas, no las del hotel: %d en Alto" % (PRESETS.of(PRESETS.HIGH).dust * OG.MOTES_PER_DUST), hotel.dust == null and hotel.motes.visible and hotel.motes.multimesh.visible_instance_count == int(PRESETS.of(PRESETS.HIGH).dust) * OG.MOTES_PER_DUST)
	hotel.reduced = true
	hotel.update_visibility(spot, true)
	check("Con efectos reducidos no hay motas", not hotel.motes.visible)
	hotel.reduced = false
	hotel.apply_quality(PRESETS.of(PRESETS.MEDIUM))
	hotel.update_visibility(spot, true)
	var lit_room: bool = hotel.motes.visible
	var dark := {}
	for room in hotel.manifest.rooms:
		if not FLOOR.is_void(room) and hotel.dark_ids.has(int(room.id)): dark = room
	if not dark.is_empty(): hotel.update_visibility(FLOOR.position_of(dark) + Vector3(0, 1.5, 0), true)
	if not hotel.layered: check("En Medio, motas solo donde la sala de quien mira está a oscuras", not lit_room and not dark.is_empty() and hotel.motes.visible)
	hotel.apply_quality(PRESETS.of(PRESETS.LOW))
	hotel.update_visibility(spot, true)
	check("En Bajo no hay motas ni luz en el aire", not hotel.motes.visible and hotel.emergency.all(func(e): return e.light.light_volumetric_fog_energy == 0.0))
	hotel.apply_quality(PRESETS.of(PRESETS.HIGH))
	hotel.eye_planta = 0
	level.rig.follow_grade()

## A room of the hotel's battens (a service gallery, a store) at Alto (rev12,
## 14 November 2026): its battens light it, down, up and from the floor, and
## its lamp nothing; she drinks it or the power goes and they go with their
## tubes, and all come back; at Medio the lamp as always.
func block_battens(hotel) -> void:
	hotel.apply_quality(PRESETS.of(PRESETS.HIGH))
	var room := {}
	for candidate in hotel.manifest.rooms:
		var rid := int(candidate.id)
		if FLOOR.is_void(candidate) or int(candidate.get("wing", 0)) != 0 or OFFICE.lamp_of(candidate) != "batten" or not hotel.lit(rid) or not hotel.halos.has(rid): continue
		if not hotel.halos[rid].pools.any(func(p): return String(p.name).begins_with("BattenUp")): continue
		if hotel.flickers.any(func(e): return e.light == hotel.lights[rid]): continue
		room = candidate
		break
	check("Hay una sala de regletas con luz en la planta 1", not room.is_empty())
	if room.is_empty() or not hotel.pools_shown(): return
	var id := int(room.id)
	var spot := FLOOR.position_of(room) + Vector3(0, 1.5, 0)
	var lamp: OmniLight3D = hotel.lights[id]
	var lights: Array = hotel.halos[id].pools
	var tubes: Array = hotel.lenses_of(id)
	var own: Array = tubes.map(func(m): return glow_of(m))
	hotel.update_visibility(spot, true)
	hotel._process(0.016)
	print("INFO regletas de la sala %d (%s): %d luces, %d tubos" % [id, OFFICE.label(room), lights.size(), tubes.size()])
	var down: Array = lights.filter(func(p): return p.has_meta("casts"))
	var bounce: Array = lights.filter(func(p): return String(p.name).begins_with("BattenBounce"))
	var share := float(hotel.bounce_of(room).share)
	check("Su regleta: un foco abajo que da sombra larga, uno arriba y el rebote de su suelo en su volumen", lights.size() == 3 and down.size() == 1 and is_equal_approx((down[0] as Light3D).light_size, float(OG.BATTEN_DOWN.size)) and bounce.size() == 1 and absf(float(bounce[0].get_meta("energy")) - float(OG.BATTEN_DOWN.energy) * share) < 0.001 and bounce[0].light_bake_mode == Light3D.BAKE_DYNAMIC, "%d luces, %d abajo, %d rebotes" % [lights.size(), down.size(), bounce.size()])
	# Up from just under the ceiling, raking it; its floor's bounce falling off with the distance (rev13).
	var up: Array = lights.filter(func(p): return String(p.name).begins_with("BattenUp"))
	check("Su luz arriba sale de BATTEN_UP_FROM bajo el techo y su rebote cae con BATTEN_BOUNCE_FALL", up.size() == 1 and is_equal_approx((up[0] as Node3D).position.y, float(room.height) - OG.BATTEN_UP_FROM) and bounce.size() == 1 and is_equal_approx((bounce[0] as SpotLight3D).spot_attenuation, OG.BATTEN_BOUNCE_FALL))
	check("Su lámpara sigue, encendida, pero no alumbra, no da sombra ni entra en el volumen", lamp.visible and lamp.light_cull_mask == 0 and not lamp.shadow_enabled and lamp.light_bake_mode == Light3D.BAKE_DISABLED)
	check("Alumbran la regleta y sus tubos", lights.all(func(p): return p.visible and p.light_energy > 0.0) and not tubes.is_empty() and own.all(func(g): return float(g) > 0.0), "%d tubos" % tubes.size())
	hotel.drain(id, 1.0)
	hotel._process(0.016)
	check("Bebida entera: la regleta y sus tubos, a oscuras", lights.all(func(p): return not p.visible or p.light_energy == 0.0) and tubes.all(func(m): return glow_of(m) == 0.0))
	hotel.drain(id, 0.0)
	hotel._process(0.016)
	var back := true
	for k in tubes.size(): if absf(glow_of(tubes[k]) - float(own[k])) > 0.001: back = false
	check("Al soltarla vuelven enteras, tubos incluidos", back and lights.all(func(p): return p.visible and absf(p.light_energy - float(p.get_meta("energy"))) < 0.01))
	hotel.set_room_power(id, false)
	hotel._process(0.016)
	check("Sin corriente, a oscuras, tubos incluidos", lights.all(func(p): return not p.visible) and tubes.all(func(m): return glow_of(m) == 0.0))
	hotel.set_room_power(id, true)
	hotel.update_visibility(spot, true)
	hotel._process(0.016)
	back = true
	for k in tubes.size(): if absf(glow_of(tubes[k]) - float(own[k])) > 0.001: back = false
	check("Con la corriente vuelven enteras", back and lights.all(func(p): return p.visible))
	hotel.apply_quality(PRESETS.of(PRESETS.MEDIUM))
	hotel.update_visibility(spot, true)
	hotel._process(0.016)
	check("En Medio la lámpara de la regleta alumbra como siempre, en su volumen, y sus focos no", lamp.light_cull_mask != 0 and lamp.light_bake_mode == Light3D.BAKE_DYNAMIC and lights.all(func(p): return not p.visible))

## The lie's dark lens under the wraparound and the parabolic faces (U3).
func block_wrap_lie(hotel) -> void:
	for pair in [["wrap", -OG.WRAP_DROP - 0.002], ["parabolic", OG.PARABOLIC_DEPTH - 0.007]]:
		var drop: float = lie_drop(hotel, pair[0])
		if not is_nan(drop): check("La lente oscura de la mentira, bajo la cara " + String(pair[0]), absf(drop - float(pair[1])) < 0.003, "%.3f" % drop)

## The accent register: an accent spot and a wall lamp with their room's power, her drain, the round of lamps and the presets (U5).
func block_accents(hotel) -> void:
	hotel.apply_quality(PRESETS.of(PRESETS.MEDIUM))
	var compat: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	print("INFO método de dibujo ", RenderingServer.get_current_rendering_method())
	var rooms: Array = hotel.manifest.rooms.filter(func(r): return not FLOOR.is_void(r) and int(r.get("wing", 0)) == 0 and hotel.lit(int(r.id)) and hotel.accents.of_room(int(r.id)).is_empty())
	check("Hay dos salas con luz en la planta 1", rooms.size() >= 2)
	if rooms.size() >= 2:
		var a: Dictionary = rooms[0]
		var b: Dictionary = rooms[1]
		var ida := int(a.id)
		var made: Array = []
		for k in 4: made.append(hotel.accent_spot(hotel.room_nodes[ida], ida, Vector3(0, 1.2, 0), Vector3(0.3, 0.75, 0), Color(1.0, 0.85, 0.6), 2.0, 4.0, 40.0))
		check("Tres acentos por sala y no más", made[0] != null and made[1] != null and made[2] != null and made[3] == null)
		var spots_kept: bool = made.slice(0, 3).all(func(l): return l != null and hotel.kept_lamps.has((l as Object).get_instance_id()) and int(hotel.kept_lamps[(l as Object).get_instance_id()].mask) == int(hotel.room_layers.mask[ida]))
		check("Los focos hechos con el piso ya montado, en las capas de su sala", spots_kept)
		var spot: SpotLight3D = made[0]
		check("El foco, con sombra y apagado hasta la ronda", spot.shadow_enabled and not spot.visible and spot.spot_angle == 40.0)
		var here := FLOOR.position_of(a) + Vector3(0, 1.5, 0)
		hotel.update_visibility(here, true)
		check("En la ronda, cerca y con luz: encendido (no en Compatibilidad)", spot.visible == (not compat))
		hotel.drain(ida, 0.5)
		check("Ella bebe la sala: el foco, a la mitad", absf(spot.light_energy - 1.0) < 0.001)
		hotel.drain(ida, 0.0)
		check("Y vuelve entero", absf(spot.light_energy - 2.0) < 0.001)
		hotel.set_room_power(ida, false)
		var cut: bool = not spot.visible
		hotel.update_visibility(here, true)
		cut = cut and not spot.visible
		hotel.set_room_power(ida, true)
		hotel.update_visibility(here, true)
		check("Sin corriente se apaga y sigue apagado en la ronda; con ella vuelve", cut and spot.visible == (not compat))
		hotel.blackout(true)
		var black: bool = not spot.visible
		hotel.blackout(false)
		hotel.update_visibility(here, true)
		check("Un apagón lo apaga y vuelve", black and spot.visible == (not compat))
		var far := {}
		for room in hotel.manifest.rooms:
			if not FLOOR.is_void(room) and int(room.get("wing", 0)) == 0 and FLOOR.position_of(room).distance_to(FLOOR.position_of(a)) > 40.0: far = room
		if far.is_empty(): print("INFO ninguna sala a más de 40 m")
		else:
			hotel.update_visibility(FLOOR.position_of(far) + Vector3(0, 1.5, 0), true)
			check("Más allá de furniture_lamps, apagado", not spot.visible)
		hotel.apply_quality(PRESETS.of(PRESETS.VERY_LOW))
		hotel.update_visibility(here, true)
		check("En Muy bajo, apagado", not spot.visible)
		hotel.apply_quality(PRESETS.of(PRESETS.MEDIUM))
		var idb := int(b.id)
		var sconce: MeshInstance3D = hotel.accent_sconce(hotel.room_nodes[idb], idb, Vector3(0, 1.6, 0), 0.0)
		check("Un aplique de acento", sconce != null)
		var bit_b: int = int(hotel.room_layers.layer[idb])
		check("El aplique hecho con el piso ya montado y su luz, en las capas de su sala", sconce != null and bit_b != 0 and (sconce.layers & bit_b) != 0 and hotel.kept_lamps.has((hotel.sconce_lights.back() as Object).get_instance_id()))
		hotel.update_visibility(here, true)
		var k: int = hotel.sconce_lights.size() - 1
		check("El aplique, en el registro por su índice", int(hotel.accents.by_sconce.get(k, -1)) == idb)
		hotel.set_sconce(k, 1)
		var on: bool = hotel.sconce_lights[k].visible
		hotel.set_room_power(idb, false)
		hotel.set_sconce(k, 1)
		var dark_mesh: bool = range(sconce.mesh.get_surface_count()).any(func(s): return sconce.get_surface_override_material(s) != null)
		var off: bool = not hotel.sconce_lights[k].visible and dark_mesh
		hotel.set_room_power(idb, true)
		hotel.set_sconce(k, 1)
		var back: bool = hotel.sconce_lights[k].visible and range(sconce.mesh.get_surface_count()).all(func(s): return sconce.get_surface_override_material(s) == null)
		check("El aplique se apaga con su sala, también su pantalla, y vuelve", on and off and back, "%s %s %s" % [on, off, back])
		# Made in a room already out, or in one she drinks: as its room from the first frame.
		hotel.set_room_power(idb, false)
		var late: MeshInstance3D = hotel.accent_sconce(hotel.room_nodes[idb], idb, Vector3(0.6, 1.6, 0), 0.0)
		var late_dark: bool = late != null and range(late.mesh.get_surface_count()).any(func(s): return late.get_surface_override_material(s) != null)
		hotel.set_room_power(idb, true)
		hotel.drain(idb, 0.5)
		var drunk: SpotLight3D = hotel.accent_spot(hotel.room_nodes[idb], idb, Vector3(0, 1.2, 0.6), Vector3(0.3, 0.75, 0.6), Color(1.0, 0.85, 0.6), 2.0, 4.0, 40.0)
		var drunk_energy: float = drunk.light_energy if drunk != null else -1.0
		hotel.drain(idb, 0.0)
		check("Un aplique hecho en una sala sin luz sale apagado; un foco hecho en una sala que ella bebe, a lo que ella deja", late_dark and absf(drunk_energy - 1.0) < 0.001, "%s %.3f" % [late_dark, drunk_energy])

## No halo over a hole (T5): the dark of the plenum over a gap, and over a
## tile she opens from the moment it opens, comes HOLE_CAP below the tiles,
## past the halo (HALO_BELOW), which is depth-tested behind it.
func block_holes(hotel) -> void:
	check("Lo oscuro de un hueco baja más que el halo", OG.HOLE_CAP > OG.HALO_BELOW)
	var capped := true
	var gaps := 0
	for id: int in hotel.halos:
		var want := 0
		for e in hotel.manifest.ducts.exits:
			if int(e.room) == id and String(e.kind) == "gap": want += 1
		gaps += want
		if count(hotel.room_nodes[id], "plenum_dark") != want: capped = false
	check("Cada hueco de una sala con halo, con lo oscuro del plénum encima", capped and gaps > 0, "%d huecos" % gaps)
	var room := {}
	var tile := Vector2i.ZERO
	for candidate in hotel.manifest.rooms:
		if not room.is_empty(): break
		var id := int(candidate.id)
		if FLOOR.is_void(candidate) or int(candidate.get("wing", 0)) != 0 or not hotel.halos.has(id) or not hotel.lit(id): continue
		for t: Vector2i in OFFICE.free_tiles(candidate):
			if hotel.turn_tile(id, t, true, false) != null:
				room = candidate
				tile = t
				break
	check("Hay una placa que ella puede abrir en una sala con halo", not room.is_empty())
	if room.is_empty(): return
	var hinge: Node3D = hotel.moved_tiles[Vector3i(int(room.id), tile.x, tile.y)]
	var dark: Node3D = hinge.get_meta("dark")
	var at_once: bool = dark.visible
	await create_timer(OG.TILE_SWING + 0.2).timeout
	var open: bool = dark.visible
	hotel.turn_tile(int(room.id), tile, false, false)
	var closing: bool = dark.visible
	await create_timer(OG.TILE_SWING + 0.2).timeout
	check("Una placa que ella abre muestra lo oscuro desde que se abre, mientras está abierta y hasta que vuelve a su sitio", at_once and open and closing and not dark.visible, "%s %s %s %s" % [at_once, open, closing, dark.visible])

## The landmark rooms (office_landmarks.gd, 14 November 2026): each has its
## door lamp and, since 16 November, no banner and one way sign, and its object its own light; the door lamps
## stay on through a cut and a blackout and never cast; the window's light
## goes and comes back with its room; the plant's casts only with the eye in
## the plant; the post reader's pilot turns green when the post opens; the
## red lever's pilot is lit while it waits.
func block_landmarks(level, hotel) -> void:
	hotel.apply_quality(PRESETS.of(PRESETS.HIGH))
	var m: Dictionary = hotel.manifest
	var compat: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var marks := {int(m.mail.window): "window", int(m.power.room): "electrical", int(m.air.security.room): "security", int(m.air.room): "machines"}
	var labels: Array = []
	var banner_height: Array = []
	for node in hotel.room_nodes:
		for l: Label3D in node.find_children("*", "Label3D", false, false):
			labels.append(l.text)
			# The banner's words were on both its faces, at its height (a way sign
			# naming the same place has them once, about as high).
			if absf(l.position.y - LANDMARKS.BANNER_Y) < 0.05: banner_height.append(l.text)
	for id: int in marks:
		var kind: String = marks[id]
		var halos: Array = hotel.landmark_lamps.filter(func(e): return int(e.room) == id and String(e.light.name) == "LandmarkDoorHalo")
		var washes: Array = hotel.landmark_lamps.filter(func(e): return int(e.room) == id and String(e.light.name) == "LandmarkDoorWash")
		# The author's nerf (16 November 2026): no banner, its lamp, one way sign.
		var ways_to: int = LANDMARKS.ways(hotel).values().filter(func(rows): return rows.any(func(row): return String(row[1]) == kind)).size()
		check("%s: sin banderola, con su aplique y un solo cartel de dirección" % kind, banner_height.count(String(LANDMARKS.KINDS[kind].banner)) <= ways_to and not halos.is_empty() and halos.size() == washes.size() and ways_to == 1, "%d banderolas, %d apliques, %d carteles" % [banner_height.count(String(LANDMARKS.KINDS[kind].banner)), halos.size(), ways_to])
	var decoys: int = LANDMARKS.ways(hotel).values().map(func(rows): return rows.filter(func(row): return String(row[1]).is_empty()).size()).reduce(func(a, c): return a + c, 0)
	check("Y muchos carteles a otros sitios de la empresa", decoys >= 6, str(decoys))
	check("Las salidas de las plantas 1 y 2: su cartel y ni banderola ni aplique", labels.has("MONTACARGAS") and hotel.landmark_lamps.all(func(e): return LANDMARKS.kind_of(m, int(e.room)) != "lift"))
	var window := int(m.mail.window)
	var accent: Array = hotel.accents.of_room(window).filter(func(e): return int(e.sconce) < 0)
	check("La ventanilla: el flexo sobre la máquina de escribir", accent.size() == 1 and is_equal_approx(float(accent[0].energy), OG.WINDOW_LAMP_ENERGY))
	check("El puesto de seguridad: su luz sobre la consola", not hotel.accents.of_room(int(m.air.security.room)).is_empty())
	var unit: Array = hotel.emergency.filter(func(e): return int(e.room) == int(m.power.room))
	var board := Vector3(float(m.power.board.point[0]), float(m.power.board.point[1]) + OG.EMERGENCY_ON_BOARD, float(m.power.board.point[2]))
	check("El cuarto eléctrico: su foco de emergencia en el tablero", unit.size() == 1 and (-(unit[0].light as Node3D).global_basis.z).dot(((board - (unit[0].light as Node3D).global_position)).normalized()) > 0.99)
	var plant: Array = hotel.landmark_lamps.filter(func(e): return bool(e.focal) and int(e.room) == int(m.air.plant))
	check("La climatizadora: su luz sobre el paro", plant.size() == 1)
	# The window's light with its room's power and her drain.
	var here := FLOOR.position_of(m.rooms[window]) + Vector3(0, 1.5, 0)
	var lamp: SpotLight3D = accent[0].light if not accent.is_empty() else null
	hotel.update_visibility(here, true)
	var lit: bool = lamp != null and lamp.visible == (not compat)
	hotel.set_room_power(window, false)
	hotel.update_visibility(here, true)
	var cut: bool = lamp != null and not lamp.visible
	hotel.set_room_power(window, true)
	hotel.update_visibility(here, true)
	check("La luz de la ventanilla se corta con su sala y vuelve entera", lit and cut and lamp.visible == (not compat) and is_equal_approx(lamp.light_energy, OG.WINDOW_LAMP_ENERGY))
	# The door lamps: batteries, never casting, the halo in the air.
	var doors: Array = hotel.landmark_lamps.filter(func(e): return not bool(e.focal))
	var cut_before: Dictionary = hotel.unpowered.duplicate()
	hotel.blackout(true)
	for e: Dictionary in doors: hotel.set_room_power(int(e.room), false)
	hotel.update_visibility(here, true)
	var kept: bool = doors.all(func(e): return (e.light as Light3D).visible and (e.light as Light3D).light_energy > 0.0 and not (e.light as Light3D).shadow_enabled)
	hotel.blackout(false)
	for e: Dictionary in doors: hotel.set_room_power(int(e.room), not cut_before.has(int(e.room)))
	check("Los apliques de las puertas siguen encendidos con la planta a oscuras, y sin sombra en Alto", not doors.is_empty() and kept)
	# The evacuation plans keep the freight lift's way out hidden (no red).
	var red := false
	for planta in 2:
		var plan: Image = PICTURES.plan(m, planta)
		for y in range(0, plan.get_height(), 2):
			for x in range(0, plan.get_width(), 2):
				var c := plan.get_pixel(x, y)
				if c.r > 0.5 and c.g < 0.4 and c.b < 0.4: red = true
	check("El plano de pared no pinta el vestíbulo del montacargas", not red)
	# A lit room's light out of its doors into the corridor: every spill aimed
	# into its corridor, its cone all on the corridor's side of the wall.
	var spills: Array = hotel.spills
	var astray: Array = spills.filter(func(s): return FLOOR.room_at(m.rooms, (s.light as Node3D).global_position + (-(s.light as Node3D).global_basis.z) * 0.5).get("id", -1) != int(s.corridor) or (s.light as Light3D).shadow_enabled)
	check("Cada puerta de una sala a un pasillo tiene su luz hacia el pasillo, sin sombra", not spills.is_empty() and OG.SPILL_DOWN + OG.SPILL_ANGLE < 90.0 and astray.is_empty(), "%d de %d: %s" % [astray.size(), spills.size(), astray.slice(0, 3).map(func(s): return [s.room, s.corridor, FLOOR.room_at(m.rooms, (s.light as Node3D).global_position).get("id", -1), (s.light as Light3D).shadow_enabled])])
	check("Solo el halo alumbra el aire", doors.all(func(e): return (e.light as Light3D).light_volumetric_fog_energy == (OG.LANDMARK_AIR if bool(e.get("air", false)) else 0.0)))
	# The plant's lamp: casting only with the eye in the plant.
	if not plant.is_empty():
		var light: SpotLight3D = plant[0].light
		hotel.update_visibility(FLOOR.position_of(m.rooms[int(m.air.plant)]) + Vector3(0, 1.5, 0), true)
		var inside: bool = light.shadow_enabled and light.light_volumetric_fog_energy == OG.FOCAL_AIR
		hotel.update_visibility(FLOOR.position_of(m.rooms[int(m.air.security.room)]) + Vector3(0, 1.5, 0), true)
		check("La luz de la climatizadora da sombra y alumbra el aire solo con quien mira dentro", inside and not light.shadow_enabled and light.light_volumetric_fog_energy == 0.0 and light.visible)
	hotel.update_visibility(here, true)
	# The pilots.
	var air = level.objective(&"air")
	var shut: bool = air.post_pilot.size() == 2 and air.post_pilot[0].visible and not air.post_pilot[1].visible
	air.post_open = true
	air.show_post()
	var open: bool = air.post_pilot[1].visible and not air.post_pilot[0].visible
	air.post_open = false
	air.show_post()
	check("El piloto del lector de la seguridad: rojo cerrada, verde al abrir", shut and open and air.post_pilot[0].visible)
	var power = level.objective(&"power")
	var unpowered: bool = power.door_pilot.size() == 3 and power.door_pilot[0].visible and not power.door_pilot[1].visible
	var zone: int = power.zone_of(power.maneuver_room)
	power.apply("lever", zone, -1, {}, true)
	var powered: bool = power.door_pilot[1].visible and not power.door_pilot[0].visible
	power.apply("lever", zone, -1, {}, true)
	check("El piloto de la puerta de la sala de maniobra: rojo sin corriente, verde con ella", unpowered and powered and power.door_pilot[0].visible)

func run() -> void:
	block_palette()
	block_bounce()
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "none"
	level.set_floor(2)
	await level.start_floor(7, false, [1], "apacible", 2)
	var hotel = level.hotel
	block_lamps(hotel)
	block_faces(hotel)
	block_lift(hotel)
	block_halos(hotel)
	block_fittings(hotel)
	block_air(level, hotel)
	block_battens(hotel)
	block_wrap_lie(hotel)
	block_accents(hotel)
	block_landmarks(level, hotel)
	await block_holes(hotel)
	var file := FileAccess.open("res://evidence/office_light_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("OFFICE_LIGHT_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)
