extends SceneTree
## The hotel's wood under each thing a preset adds to its shine, to tell
## which of them is in a picture: a desk seen from standing beside it and
## from the doorway's height, and the side of a wardrobe seen along it, on
## the same floor (seed 81) and from the same marks -- as the preset draws
## them, and then with one thing changed at a time: the varnish's coat as
## the engine has it seen edge on ("uncapped"), no coat, no reflection
## probes, no screen-space reflections, no varnish at all.
##
##   godot --rendering-method forward_plus --script res://tools/dev/wood_look.gd -- --test-profile --automation --no-enemy --silent [--quality=3] [--label=wood]
##
## Writes evidence/<label>_<shot>.png: the variants side by side, named in
## the log in the order they are laid out. Needs a window.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const SIZE := Vector2i(1280, 720)
## What is taken away, as forced preset values (graphics_presets.gd keys).
const VARIANTS := [["as_is", {}], ["uncapped", {}], ["no_lacquer", {"surface_detail": 4.0}], ["no_probes", {"probes": 0}], ["no_ssr", {"ssr_steps": 0}], ["matt", {}]]
var level
var varnish := 0.65

func _initialize() -> void: run.call_deferred()

func lit(room: Dictionary) -> bool:
	return not level.hotel.lights[int(room.id)].has_meta("off")

## The first room with a prop of this kind, lit or not as asked: [room, prop].
func find(kind: String, wanted_lit: bool) -> Array:
	for room in level.manifest.rooms:
		if lit(room) != wanted_lit: continue
		for prop in room.get("props", []):
			if String(prop.kind) == kind: return [room, prop]
	return []

func look(from: Vector3, at: Vector3) -> void:
	level.player.global_position = Vector3(from.x, 0.04, from.z)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	var eye: float = level.player.camera.global_position.y
	level.player.camera.rotation.x = atan2(at.y - eye, flat.length())
	level.player.snap_torch()

## Whether a point is in plain view of somebody standing at `from`.
func seen_from(from: Vector3, at: Vector3) -> bool:
	var eye := Vector3(from.x, 1.6, from.z)
	var query := PhysicsRayQueryParameters3D.create(eye, at, 1 | 8)
	query.exclude = [level.player.get_rid()]
	var hit: Dictionary = level.player.get_world_3d().direct_space_state.intersect_ray(query)
	# Standing somewhere a body fits, too: nothing between the floor and the eye.
	var feet := PhysicsRayQueryParameters3D.create(eye, Vector3(from.x, 0.3, from.z), 1 | 8)
	feet.exclude = [level.player.get_rid()]
	return (hit.is_empty() or (hit.position as Vector3).distance_to(at) < 0.25) and level.player.get_world_3d().direct_space_state.intersect_ray(feet).is_empty()

func shot(name: String, label: String, from: Vector3, at: Vector3) -> void:
	var page := Image.create(SIZE.x * VARIANTS.size(), SIZE.y, false, Image.FORMAT_RGB8)
	for index in VARIANTS.size():
		PRESETS.overrides = VARIANTS[index][1].duplicate()
		level.apply_settings()
		# "matt": the varnish off the wood itself, to tell its shine from the rest.
		(level.hotel.materials["wood"] as ShaderMaterial).set_shader_parameter("varnish", 0.0 if String(VARIANTS[index][0]) == "matt" else varnish)
		# "uncapped": the coat as the engine has it, seen edge on (wood.gdshaderinc).
		(level.hotel.materials["wood"] as ShaderMaterial).set_shader_parameter("lacquer_edge", 1.0 if String(VARIANTS[index][0]) == "uncapped" else null)
		look(from, at)
		level.hotel.update_visibility(level.player.position, true)
		for frame in 50: await process_frame
		await RenderingServer.frame_post_draw
		var seen: Image = root.get_texture().get_image()
		seen.convert(Image.FORMAT_RGB8)
		seen.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_BILINEAR)
		page.blit_rect(seen, Rect2i(Vector2i.ZERO, SIZE), Vector2i(SIZE.x * index, 0))
	PRESETS.overrides = {}
	page.save_png("res://evidence/%s_%s.png" % [label, name])
	print("WOOD_LOOK ", name, " ", VARIANTS.map(func(variant): return variant[0]))

func run() -> void:
	var quality := PRESETS.ULTRA
	var label := "wood"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(81)
	level.settings.set_designed(quality)
	await level.bounce_ready()
	DisplayServer.window_set_size(SIZE)
	level.player.set_physics_process(false)
	level.player.torch.visible = false
	if is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
	# A desk's top and a wardrobe's side of the hotel's own wood, stood by a
	# lit papered wall of the biggest lit room that has one: what a varnished
	# top gives back of a bright wall is what there is to look at.
	var room := {}
	for candidate in level.manifest.rooms:
		if int(candidate.get("wing", 0)) != 0 or FLOOR.is_void(candidate) or not lit(candidate) or int(candidate.type) not in [0, 1, 2, 3, 5, 10]: continue
		if room.is_empty() or FLOOR.size_of(candidate).x * FLOOR.size_of(candidate).y > FLOOR.size_of(room).x * FLOOR.size_of(room).y: room = candidate
	var centre: Vector3 = FLOOR.position_of(room)
	var span: Vector2 = FLOOR.size_of(room)
	var wood: ShaderMaterial = level.hotel.materials["wood"]
	varnish = float(wood.get_shader_parameter("varnish")) if wood.get_shader_parameter("varnish") != null else 0.65
	var by_wall := centre + Vector3(0, 0, -span.y * 0.5 + 1.3)
	for piece in [[Vector3(0, 0.8, 0), Vector3(2.2, 0.05, 1.1)], [Vector3(0, 0.4, 0.5), Vector3(2.2, 0.8, 0.05)], [Vector3(2.4, 1.22, 0.4), Vector3(0.9, 2.45, 0.12)]]:
		var body := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = piece[1]
		body.mesh = mesh
		body.material_override = wood
		level.hotel.room_nodes[int(room.id)].add_child(body)
		body.global_position = by_wall + piece[0]
	print("WOOD_LOOK room=", room.id, " type=", room.type, " size=", span, " shader=", wood.shader.resource_path, " varnish=", varnish)
	var top := by_wall + Vector3(0, 0.83, 0)
	# Standing over it, from the middle of the room, and from the far side of
	# it: the top at some forty, twenty and ten degrees to the eye.
	await shot("top_40", label, by_wall + Vector3(0.4, 0, 1.5), top)
	await shot("top_20", label, by_wall + Vector3(0.6, 0, 2.6), top)
	await shot("top_10", label, by_wall + Vector3(0.8, 0, minf(5.0, span.y - 2.4)), top)
	# And the panel beside it, along its face.
	await shot("panel_along", label, by_wall + Vector3(5.2, 0, 0.75), by_wall + Vector3(2.4, 1.3, 0.47))
	level.queue_free()
	await process_frame
	quit()
