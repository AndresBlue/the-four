extends SceneTree
## Floor 2's light (.claude/specs/spec_rediseno.md 4, area 3b): the lamps'
## colour by type and the troffer families in the palette; the bounce light's
## office colours; and on a floor built at seed 7: each lamp in its room's
## colour, the lenses and tubes put out with their room, each family's face
## under a housing open below, the reception lift's wall lamps, the ceiling
## halo following its lamp, the lie's dark lens under its family's face, the
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
	check("Una temperatura por cada uno de los 26 tipos", OFFICE.LAMP_KELVIN.size() == 26)
	check("Las salas, a 3000 K", kelvin(OFFICE.OFFICE) == 3000.0 and kelvin(OFFICE.OPEN_OFFICE) == 3000.0 and kelvin(OFFICE.MAIL) == 3000.0 and kelvin(OFFICE.SECRETARY) == 3000.0)
	check("Los pasillos, a 3500 K", kelvin(OFFICE.CORRIDOR) == 3500.0 and kelvin(OFFICE.GALLERY) == 3500.0)
	check("Ámbar en recepción y descanso", kelvin(OFFICE.RECEPTION) == 2700.0 and kelvin(OFFICE.BREAK_ROOM) == 2700.0)
	check("Neutra en juntas y dirección", kelvin(OFFICE.BOARDROOM) == 3300.0 and kelvin(OFFICE.EXEC_OFFICE) == 3300.0)
	# The reception's plain lens, as its reference (13 November 2026).
	check("Lisa en recepción, estrecha en juntas, parabólica en secretaría, envolvente en dirección", look_of(OFFICE.RECEPTION) == "prismatic" and look_of(OFFICE.BOARDROOM) == "narrow" and look_of(OFFICE.SECRETARY) == "parabolic" and look_of(OFFICE.EXEC_OFFICE) == "wrap")
	check("Prismática en el resto", look_of(OFFICE.OFFICE) == "prismatic" and look_of(OFFICE.CORRIDOR) == "prismatic" and look_of(OFFICE.MAIL) == "prismatic")
	var unknown: Array = range(26).filter(func(t): return not OFFICE.TROFFER_LOOKS.has(look_of(t)))
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
		check("La luz, 22 cm sobre el aplique", absf(light.global_position.y - (m0.global_position.y + 0.22)) < 0.01)
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
	block_wrap_lie(hotel)
	block_accents(hotel)
	await block_holes(hotel)
	var file := FileAccess.open("res://evidence/office_light_test.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"checks": checks}, "\t"))
	print("OFFICE_LIGHT_TEST_RESULT ", checks.size() - failed, "/", checks.size())
	level.queue_free()
	await process_frame
	quit(1 if failed > 0 else 0)
