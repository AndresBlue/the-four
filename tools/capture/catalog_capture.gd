extends SceneTree
## The hotel's papers and its furniture, photographed for the author's
## catalogue (21 October 2026): the hotel's own paperwork held up on its form
## (game/ui/hotel_form.gd) and hanging on the sheet; every piece a paper can be
## found on or in, with one there; and every other piece of furniture, fitting
## and thing the hotel puts in its rooms, one of each, in a lit room. Looked
## for over several floors until each has turned up. With a window:
##   godot --path . --script res://tools/capture/catalog_capture.gd -- --test-profile --automation --silent [--seeds=81,777,202,4242]
## Shots in evidence/cat_*.png, and what each is in evidence/cat_index.json.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const CATALOG := preload("res://game/discovery/discovery_catalog.gd")
const DOCUMENT := preload("res://game/world/interactables/hotel_document.gd")
const HINT_PAPER := preload("res://game/world/interactables/hotel_hint.gd")
const DOOR := preload("res://game/world/interactables/hotel_door.gd")
## What a paper can lie on (document_placement.SURFACES), and which paper is
## put on each for its photograph.
const SURFACES := {"table": ["document", "locust_reception"], "desk": ["hint", "orden"], "nightstand": ["document", "locust_letter"]}
## Pieces that hold papers, by the model the paper sits on (hotel_container).
const HOLDERS := ["GothicCommode_01", "ClassicConsole_01", "drawer_cabinet", "wooden_bookshelf_worn", "painted_wooden_cabinet", "vintage_cabinet_01", "cardboard_box_01", "plastic_crate_02", "vintage_suitcase_b"]
## Corner pieces built out of boxes rather than a model, by their kind.
## (The corner wardrobe is the big hiding place, taken with the hiding places.)
const BUILT := ["table", "desk", "nightstand", "phone", "reception", "lamp", "curtain", "washer", "basin", "tv", "tv_stand", "bed", "shelf", "cart", "bin", "sofa", "plant", "luggage"]
const DOMESTIC := [1, 2, 3, 4, 7, 15, 16]
var level
var index: Array = []
var seen := {}

func _initialize() -> void: run.call_deferred()

func shot(name: String, what: String, kind: String, frames := 40) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in frames: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/cat_%s.png" % name)
	index.append({"file": "cat_%s.png" % name, "what": what, "kind": kind})
	print("CAPTURE cat_%s.png  %s" % [name, what])

## The camera's eye at `eye`, looking at `at`.
func look(eye: Vector3, at: Vector3) -> void:
	level.player.set_physics_process(false)
	level.player.velocity = Vector3.ZERO
	level.player.position = eye - Vector3(0, level.player.eye_height, 0)
	var d := at - eye
	level.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	level.player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
	level.player.snap_torch()

## Looking at `centre` from the side of its room's middle, `distance` away
## and the eye `above` it: the first place round it with nothing between the
## eye and the thing (walls, doors, big furniture), as near that distance as
## there is one. From the room's middle alone, a piece in a corner was taken
## through the partition of an alcove.
func frame(centre: Vector3, room: Dictionary, distance: float, above := 0.35, clear := 0.3) -> void:
	# In the rooms with alcoves (hotel_geometry.build_room()) a corner is
	# behind a partition: it is seen from inside its alcove.
	if DOMESTIC.has(int(room.get("type", -1))): distance = minf(distance, 1.5)
	await physics_frame
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var middle := FLOOR.position_of(room)
	var towards := Vector3(middle.x - centre.x, 0, middle.z - centre.z)
	if towards.length() < 0.3: towards = Vector3(1, 0, 0.4)
	towards = towards.normalized()
	for reach in [1.0, 0.8, 0.6, 0.45]:
		for turn in [0.3, -0.3, 0.7, -0.7, 1.1, -1.1, 1.6, -1.6, 2.2, -2.2, PI]:
			var eye: Vector3 = centre + towards.rotated(Vector3.UP, turn) * distance * reach + Vector3(0, above, 0)
			var way := (eye - centre).normalized()
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(centre + way * clear, eye + way * 0.35, 1 | 8)).is_empty():
				look(eye, centre)
				return
	look(centre + towards * distance * 0.45 + Vector3(0, above, 0), centre)

## The interface and what the camcorder writes over the picture (the level
## shows its layer again every frame; what is in it stays as it is put).
func osd(shown: bool) -> void:
	level.ui.visible = shown
	for child in level.camcorder.get_children():
		if child is CanvasItem: child.visible = shown

func lit(room: Dictionary) -> bool:
	return not room.is_empty() and not bool(room.get("dark", false)) and not bool(room.get("landing", false)) and not level.manifest.get("refuges", [level.manifest.exit]).has(int(room.id))

func room_name(room: Dictionary) -> String:
	return String(FLOOR.NAMES[int(room.type)]) if not room.is_empty() else ""

func socket_of(kind: String, types := []) -> Array:
	for room in level.manifest.rooms:
		if not lit(room) or int(room.get("hall", -1)) >= 0: continue
		if not types.is_empty() and not types.has(int(room.type)): continue
		for prop in room.props:
			if prop.kind == kind: return [room, GEOMETRY.prop_transform(room, prop)]
	return []

func settle() -> void:
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.settings.values.quality = 2
	for key in ["vhs", "grain", "chromatic", "scanlines"]: level.settings.values[key] = 0.0
	level.settings.values.reduced = true
	level.apply_settings()
	level.apply_lens(false, true)
	for key in ["vhs", "grain", "chromatic", "scanlines", "noise"]:
		if level.post_material.get_shader_parameter(key) != null: level.post_material.set_shader_parameter(key, 0.0)
	level.player.torch.visible = true
	for i in 120: await process_frame

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var seeds := [81, 777, 202, 4242, 9001, 31337]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="): seeds = Array(argument.trim_prefix("--seeds=").split(",")).map(func(s): return int(s))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	for seed_value in seeds:
		await level.start_floor(seed_value)
		await settle()
		# The papers are shown by the interface; the furniture without it, nor
		# the camcorder's writing (its focus frame would sit on every paper).
		osd(true)
		await forms(seed_value)
		osd(false)
		await surfaces()
		await holders()
		await others()
	var file := FileAccess.open("res://evidence/cat_index.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(index, "\t"))
	print("CATALOG ", index.size(), " shots")
	quit()

# --- The papers -----------------------------------------------------------------------------

func forms(seed_value: int) -> void:
	# Held up in the reception, over the room.
	var lobby: Dictionary = level.manifest.rooms[int(level.manifest.entries[0])]
	var stand := FLOOR.position_of(lobby)
	look(stand + Vector3(0, 1.64, 0), stand + Vector3(3, 1.4, 0))
	for id in ["locust_reception", "locust_maintenance"]:
		if seen.has("form_" + id): continue
		seen["form_" + id] = true
		level.ui.show_document(CATALOG.entry(id))
		await shot("hoja_" + id.trim_prefix("locust_"), String(CATALOG.entry(id).title), "hoja")
		level.ui.hide_document()
	for hint in level.code.hints:
		var kind := String(hint.kind)
		if not kind in ["limpieza", "orden"] or seen.has("form_" + kind): continue
		seen["form_" + kind] = true
		level.ui.show_hint(hint, level.code.hint_walls())
		await shot("hoja_" + kind, "Pista: " + kind, "hoja")
		level.ui.hide_document()
	if not seen.has("sheet") and level.code.hints.any(func(hint): return String(hint.kind) in ["limpieza", "orden"]):
		seen["sheet"] = true
		for hint in level.code.hints: level.code.own_hint(int(hint.id))
		level.toggle_sheet()
		for i in 90: await process_frame
		await shot("hoja_en_la_hoja", "Las pistas en la hoja", "hoja")
		level.toggle_sheet()
		for i in 10: await process_frame

func surfaces() -> void:
	for kind in SURFACES:
		if seen.has("on_" + kind): continue
		var found := socket_of(kind)
		if found.is_empty(): continue
		seen["on_" + kind] = true
		var room: Dictionary = found[0]
		var socket: Transform3D = found[1]
		var top: Vector3 = FLOOR.position_of(room) + socket * Vector3(0.0, 0.84, -0.05)
		var yaw := socket.basis.get_euler().y + 0.3
		var paper
		if String(SURFACES[kind][0]) == "document":
			paper = DOCUMENT.new()
			paper.entry_id = String(SURFACES[kind][1])
		else:
			paper = HINT_PAPER.new()
			paper.kind = String(SURFACES[kind][1])
		level.hotel.room_nodes[int(room.id)].add_child(paper)
		paper.global_transform = Transform3D(Basis(Vector3.UP, yaw), top + Vector3(0, 0.004, 0))
		var what := "%s (%s), con %s" % [kind, room_name(room), String(SURFACES[kind][1])]
		await frame(top, room, 1.5, 0.75)
		await shot("nota_" + kind, what, "nota")
		# Over it, as whoever reads it stands.
		await frame(top, room, 0.6, 0.6)
		await shot("nota_%s_cerca" % kind, what + ", de cerca", "nota")
		paper.queue_free()

func holders() -> void:
	for piece in level.containers:
		var model := String(piece.note_spot.get("model", ""))
		if model.is_empty() or seen.has("in_" + model): continue
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, piece.global_position)
		if not lit(room): continue
		seen["in_" + model] = true
		piece.plant_note()
		var note: Node3D = piece.note
		var at: Vector3 = note.global_position if is_instance_valid(note) else piece.global_position + Vector3(0, 0.9, 0)
		var out: Vector3 = piece.global_basis.z.normalized()
		var side: Vector3 = piece.global_basis.x.normalized()
		var floor_y: float = piece.global_position.y
		var what := "%s (%s, %s)" % [piece.kind, model, room_name(room)]
		var middle := Vector3(at.x, floor_y + 0.8, at.z)
		look(Vector3(at.x, floor_y + 1.5, at.z) + out * 2.0 + side * 0.5, middle)
		await shot("mueble_" + model, what, "mueble")
		look(Vector3(at.x, floor_y + 1.64, at.z) + out * 0.9 + side * 0.3, at)
		await shot("mueble_%s_cerca" % model, what + ", de cerca", "mueble")
		# A piece that opens, gone through: how it is left.
		if not piece.main.is_empty() and piece.digit < 0 and piece.hint < 0 and piece.document.is_empty():
			level.apply_search(level.containers.find(piece), true, false, level.player.slot)
			look(Vector3(at.x, floor_y + 1.5, at.z) + out * 2.0 + side * 0.5, middle)
			await shot("mueble_%s_abierto" % model, what + ", registrado", "mueble", 80)
			continue
		piece.take_note()
		if piece.digit >= 0 or piece.hint >= 0: piece.plant_note()

# --- Everything else ----------------------------------------------------------------------

## A model not worth a photograph of its own: a clock's hand, a part of a
## piece that opens, part of what has its own (a wardrobe's leaves, a door's
## frame, a television's screen, the lift's screen), or one already taken.
const PARTS := ["_hour", "_minute", "_second", "_body", "_drawer", "_door", "_glass", "wardrobe_leaf", "door_", "tv_", "lift_screen"]
func skipped(name: String) -> bool:
	for part in PARTS:
		if name.contains(part): return true
	return HOLDERS.has(name) or seen.has("model_" + name)

func others() -> void:
	for kind in BUILT:
		if kind in SURFACES: continue
		var types: Array = [7, 8, 9] if kind == "shelf" else []
		for variant in ([["", types], ["_madera", [4, 6, 13, 15]]] if kind == "shelf" else [["", types]]):
			var key: String = "corner_" + kind + String(variant[0])
			if seen.has(key): continue
			var found := socket_of(kind, variant[1])
			if found.is_empty(): continue
			seen[key] = true
			var room: Dictionary = found[0]
			var centre: Vector3 = FLOOR.position_of(room) + (found[1] as Transform3D).origin + Vector3(0, 0.7, 0)
			await frame(centre, room, 2.6, 0.6)
			await shot("pieza_" + kind + String(variant[0]), "%s (%s)" % [kind + String(variant[0]), room_name(room)], "pieza")
	# The models the rooms are dressed with, one of each that is not already a
	# piece a paper is found in.
	var models := {}
	for batch in level.hotel.find_children("Model_*", "MultiMeshInstance3D", true, false):
		var multi: MultiMesh = batch.multimesh
		if multi == null or multi.mesh == null or not String(multi.mesh.resource_path).begins_with("res://assets/props/"): continue
		var name := String(multi.mesh.resource_path).get_file().get_basename()
		if skipped(name): continue
		for i in multi.instance_count:
			var at: Transform3D = batch.global_transform * multi.get_instance_transform(i)
			if at.basis.get_scale().length() < 0.01: continue
			var room: Dictionary = FLOOR.room_at(level.manifest.rooms, at.origin)
			if not lit(room): continue
			models[name] = [at, multi.mesh.get_aabb(), room]
			break
	# And the models drawn as nodes of their own: lamps, frames, the lift.
	for node in level.hotel.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = node.mesh
		if mesh == null or not String(mesh.resource_path).begins_with("res://assets/props/"): continue
		var name := String(mesh.resource_path).get_file().get_basename()
		if skipped(name) or models.has(name): continue
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, node.global_position)
		if not lit(room): continue
		models[name] = [node.global_transform, mesh.get_aabb(), room]
	for name in models:
		seen["model_" + name] = true
		var at: Transform3D = models[name][0]
		var box: AABB = models[name][1]
		var room: Dictionary = models[name][2]
		var size: Vector3 = box.size * at.basis.get_scale()
		var centre: Vector3 = at * box.get_center()
		var high := centre.y - FLOOR.position_of(room).y > 2.2
		var distance := clampf(maxf(size.x, maxf(size.y, size.z)) * 1.6 + 0.5, 0.8, 3.2)
		if high: await frame(centre, room, 2.4, -1.2)
		else: await frame(centre, room, distance, 0.25 + size.y * 0.3)
		await shot("modelo_" + name, "%s (%s)" % [name, room_name(room)], "modelo")
	if not seen.has("door"):
		for door in level.hotel.find_children("*", "StaticBody3D", true, false):
			if door.get_script() != DOOR: continue
			var room: Dictionary = FLOOR.room_at(level.manifest.rooms, door.global_position + door.global_basis.z)
			if not lit(room): continue
			seen["door"] = true
			await frame(door.global_position + Vector3(0, 1.1, 0), room, 2.2, 0.45, 0.5)
			await shot("pieza_puerta", "puerta (%s)" % room_name(room), "pieza")
			break
	for hide in level.get_tree().get_nodes_in_group("hotel_hides"):
		var big := bool(hide.big)
		var key := "hide_" + ("big" if big else "small")
		if seen.has(key): continue
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, hide.global_position + hide.global_basis.z)
		if not lit(room): continue
		seen[key] = true
		await frame(hide.global_position + Vector3(0, 1.0, 0), room, 2.4, 0.5, 0.9)
		await shot("pieza_" + key, "escondite %s (%s)" % [String(hide.name), room_name(room)], "pieza")
