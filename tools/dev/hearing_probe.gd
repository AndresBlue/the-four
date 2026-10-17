extends SceneTree
## Where the creature is heard from by somebody standing on the furniture: how
## many pieces of the navigation start well above their floor (the tops of
## beds, sofas and desks used to be islands of their own), and, with the
## listener standing on a few tops of furniture and the creature far off on
## the same planta, what the sound's route and the aura make of the distance
## between them, against the straight line between the two.
##
##   godot --headless --path . --script res://tools/dev/hearing_probe.gd -- --test-profile --automation --silent [--seeds=81,213]
##
## Exits 1 if any route comes out shorter than the straight line across, by
## more than two metres (a walked route never is), or if any piece of the
## navigation is left on the furniture. tools/verify.ps1 runs it.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

## The middles of the navigation's polygons that stand above their planta's
## floor by more than `above`: [middle, height over the floor].
func islands(above: float) -> Array:
	var found: Array = []
	for region in level.hotel.find_children("Navigation_*", "NavigationRegion3D", true, false):
		var mesh: NavigationMesh = region.navigation_mesh
		var vertices := mesh.get_vertices()
		for i in mesh.get_polygon_count():
			var middle := Vector3.ZERO
			var polygon := mesh.get_polygon(i)
			for index in polygon: middle += vertices[index]
			middle /= float(polygon.size())
			var over: float = middle.y - FLOOR.planta_y(FLOOR.planta_of(middle.y))
			if over > above: found.append([region.global_transform * middle, over])
	return found

func run() -> void:
	var seeds: Array = [81]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seeds = [int(argument.trim_prefix("--seed="))]
		if argument.begins_with("--seeds="): seeds = Array(argument.trim_prefix("--seeds=").split(",")).map(func(text): return int(text))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	var failed := false
	for seed_value in seeds:
		if not await probe(int(seed_value)): failed = true
	level.queue_free()
	await process_frame
	quit(1 if failed else 0)

## One floor: whether nothing walkable is left on the furniture, and no route
## heard from up there comes out shorter than the straight line.
func probe(seed_value: int) -> bool:
	await level.start_floor(seed_value)
	for frame in 10: await physics_frame
	var creature = level.locust
	creature.set_physics_process(false)
	var raised: int = islands(0.35).size()
	print("HEARING seed=", seed_value, ": ", raised, " walkable polygons start more than 35 cm above their floor")
	# Tops of furniture on the first planta, found from above: wherever a ray
	# down from head height meets something 0.35 to 1.4 m over the floor.
	var found: Array = []
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	for room in level.manifest.rooms:
		if int(room.get("wing", 0)) != 0 or FLOOR.is_void(room) or found.size() >= 40: continue
		var centre := FLOOR.position_of(room)
		var span: Vector2 = FLOOR.size_of(room)
		for step in 25:
			var at := centre + Vector3((step % 5 - 2) * span.x * 0.18, 2.0, (step / 5 - 2) * span.y * 0.18)
			var down := PhysicsRayQueryParameters3D.create(at, at - Vector3(0, 2.2, 0), 1)
			var hit := space.intersect_ray(down)
			if hit.is_empty(): continue
			var over: float = (hit.position as Vector3).y - centre.y
			if over > 0.35 and over < 1.4:
				found.append([hit.position, over])
				break
	var aura = level.world_audio.aura
	var worst := 0.0
	var tried := 0
	for island in found + [[Vector3.INF, 0.0]]:
		if tried >= 10: break
		var top: Vector3 = island[0]
		if top == Vector3.INF: break
		var planta := FLOOR.planta_of(top.y)
		if planta != 0: continue
		# The creature some way off on the same planta, wherever the floor is.
		var far_spot: Vector3 = FLOOR.closest(level.get_world_3d().navigation_map, top + Vector3(14.0, 0.0, 9.0))
		creature.global_position = far_spot
		level.player.global_position = top + Vector3(0.0, 0.02, 0.0)
		level.player.velocity = Vector3.ZERO
		await physics_frame
		# Each spot asks afresh, not from the route remembered for the last.
		level.world_audio.route_memo = {}
		var listener: Vector3 = level.world_audio.listener_position()
		var heard: Dictionary = level.world_audio.route_source(far_spot + Vector3(0, 1.4, 0), creature.get_rid())
		var felt: Array = aura.route_to(listener, far_spot)
		# A walked route is never shorter than the straight line across.
		var straight := Vector2(far_spot.x - listener.x, far_spot.z - listener.z).length()
		var shortfall := maxf(straight - float(felt[0]), straight - float(heard.get("distance", INF)))
		if is_finite(shortfall): worst = maxf(worst, shortfall)
		tried += 1
		print("  standing %.2f m up at %s, the creature %.1f m off in a straight line: the sound's route %.1f m (placed %.1f m from the ear), the aura's %.1f m" % [float(island[1]), top.snapped(Vector3.ONE * 0.1), straight, float(heard.get("distance", INF)), (heard.get("position", far_spot) as Vector3).distance_to(listener), float(felt[0])])
	print("HEARING seed=", seed_value, " done: ", tried, " spots stood on, the worst route shorter than the straight line by ", snappedf(worst, 0.1), " m")
	return worst <= 2.0 and raised == 0 and tried > 0
