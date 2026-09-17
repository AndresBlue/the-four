extends SceneTree
## Supplied furniture in place: a sofa, a potted plant, corridor wall lamps and
## a document on a desk. Camera placement only (evidence/props_*.png).
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(filename: String) -> void:
	level.hotel.update_visibility(level.player.position, true)
	for i in 45: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/props_%s.png" % filename)

func look(from: Vector3, at: Vector3) -> void:
	level.player.position = Vector3(from.x, 0.04, from.z)
	var d: Vector3 = at - (level.player.position + Vector3(0, level.player.eye_height, 0))
	level.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	level.player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)

func socket_of(kind: String) -> Array:
	for room in level.manifest.rooms:
		if room.id == level.manifest.exit or int(room.hall) >= 0: continue
		for prop in room.props:
			if prop.kind == kind: return [room, GEOMETRY.prop_transform(room, prop)]
	return []

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.start_floor(81)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.settings.values.quality = 2
	level.apply_settings()
	for kind in ["sofa", "plant"]:
		var found := socket_of(kind)
		if found.is_empty(): continue
		var centre: Vector3 = FLOOR.position_of(found[0]) + found[1].origin
		var front: Vector3 = found[1].basis.z.normalized()
		look(centre + front * 2.6 + found[1].basis.x.normalized() * 0.8, centre + Vector3(0, 0.5, 0))
		await shot(kind)
	for room in level.manifest.rooms:
		if int(room.type) == 11 and int(room.hall) < 0:
			var centre := FLOOR.position_of(room)
			var span := FLOOR.size_of(room)
			var along := Vector3(span.x * 0.35, 0, 0) if span.x >= span.y else Vector3(0, 0, span.y * 0.35)
			look(centre - along, centre + along + Vector3(0, 1.4, 0))
			await shot("corridor")
			break
	var document = get_nodes_in_group("hotel_documents")[0]
	look(document.position + Vector3(0.6, 0, 0.6), document.position)
	await shot("document")
	paused = false
	level.queue_free()
	await process_frame
	quit()
