extends SceneTree
## What pops near the player: a walk at walking pace through the rooms of each
## planta, the look sweeping side to side, and every thing that appears,
## vanishes or changes at once while it is in the picture, near and in sight
## of the eye -- a mesh cut by its visibility range, a room or a node shown or
## hidden, a lamp lit or put out without fading, a shadow switched, a node made
## or freed (a reflection probe, a spot), a bounce volume -- counted per minute
## of walk and by what it is. A distance fade (a lamp's, a decal's, a range's
## fade mode) is gradual and is not counted. Once a second it also counts what
## is missing far off: meshes in the picture and in sight, beyond their range,
## and rooms in sight that are hidden.
##
##   godot --headless --path . --script res://tools/dev/popping_probe.gd -- --test-profile --automation --silent --no-enemy --floor=2 [--seed=81] [--quality=3] [--rooms=16] [--plantas=1,2,3] [--near=20] [--label=base] [--max=5]
##
## --max: fails (exit 1) past that many pops per minute of walk (tools/verify.ps1).
##
## Writes evidence/popping/<label>.json (every pop, with where it was seen
## from, for tools/capture) and prints POPPING lines. Headless is enough: what
## is drawn is decided by nodes and ranges, not by the renderer.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const WALK_STEP := 3.8 / 60.0
const CHECK_EVERY := 3
const FAR_EVERY := 60
const FAR_MOST := 60.0
const CELL := 8.0
const SWEEP := 0.45
var level
var near := 20.0
var label := "current"
var tracked := {}
var grid := {}
var room_of := {}
var pops: Array = []
var far_checks: Array = []
var frames := 0
var planta_now := 0
var room_root_ids := {}
var rooms_toggled := {}
## Frames after a planta's walk starts in which nothing is noted: the probe
## jumps there, where a player rides the lift, and the planta it left is put
## away and this one shown in that first round.
var quiet_until := 0


func _initialize() -> void: run.call_deferred()


func run() -> void:
	var seed_value := 81
	var quality := 3
	var rooms_each := 16
	var plantas := [1, 2, 3]
	var most := -1.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--rooms="): rooms_each = int(argument.trim_prefix("--rooms="))
		if argument.begins_with("--near="): near = float(argument.trim_prefix("--near="))
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		if argument.begins_with("--max="): most = float(argument.trim_prefix("--max="))
		if argument.begins_with("--plantas="): plantas = Array(argument.trim_prefix("--plantas=").split(",")).map(func(p): return int(p))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.settings.values = level.settings.DEFAULTS.duplicate()
	level.settings.set_designed(quality)
	await level.start_floor(seed_value)
	await level.bounce_ready()
	level.player.set_physics_process(false)
	for i in level.hotel.room_nodes.size(): room_root_ids[level.hotel.room_nodes[i].get_instance_id()] = i
	for node in level.find_children("*", "VisualInstance3D", true, false): track(node)
	node_added.connect(on_added)
	node_removed.connect(on_removed)
	var walked := 0.0
	for planta in plantas:
		var route := tour(planta - 1, rooms_each)
		if route.size() < 2: continue
		planta_now = planta
		quiet_until = frames + 60
		walked += await walk(route)
	var minutes := maxf(walked / 3.8 / 60.0, 0.0001)
	var summary := summarize(minutes)
	summary["seed"] = seed_value
	summary["quality"] = quality
	summary["near"] = near
	summary["walk_minutes"] = minutes
	var out := "res://evidence/popping"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var file := FileAccess.open("%s/%s.json" % [out, label], FileAccess.WRITE)
	file.store_string(JSON.stringify({"summary": summary, "pops": pops, "far": far_checks}, "\t"))
	file.close()
	print("POPPING ", JSON.stringify(summary))
	if most >= 0.0 and float(summary.per_minute) > most:
		print("POPPING_FAIL %.1f pops per minute, over %.1f" % [summary.per_minute, most])
		quit(1)
		return
	quit(0)


## The rooms of a planta, nearest first from where its walk starts, as one
## path along the navigation; rooms it cannot reach are left out.
func tour(planta: int, count: int) -> PackedVector3Array:
	var left: Array = []
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or FLOOR.planta_of(FLOOR.position_of(room).y) != planta: continue
		left.append(room)
	if left.is_empty(): return PackedVector3Array()
	var start: Dictionary = level.manifest.rooms[int(level.manifest.start)]
	if FLOOR.planta_of(FLOOR.position_of(start).y) != planta: start = left[0]
	var here := FLOOR.position_of(start)
	var path := PackedVector3Array([here])
	var map: RID = level.get_world_3d().navigation_map
	for step in count:
		left.sort_custom(func(a, b): return FLOOR.position_of(a).distance_squared_to(here) < FLOOR.position_of(b).distance_squared_to(here))
		while not left.is_empty():
			var room: Dictionary = left.pop_front()
			var leg := FLOOR.navigation_path(map, here, FLOOR.position_of(room))
			if leg.size() < 2 or leg[-1].distance_to(FLOOR.position_of(room)) > 2.0: continue
			path.append_array(leg)
			here = leg[-1]
			break
	return path


func along(route: PackedVector3Array, distance: float) -> Vector3:
	var left := distance
	for i in range(1, route.size()):
		var leg := route[i - 1].distance_to(route[i])
		if left <= leg: return route[i - 1].lerp(route[i], left / maxf(leg, 0.0001))
		left -= leg
	return route[-1]


## Walks the route, returning the metres walked.
func walk(route: PackedVector3Array) -> float:
	var length := 0.0
	for i in range(1, route.size()): length += route[i - 1].distance_to(route[i])
	var walked := 0.0
	while walked < length:
		var point := along(route, walked)
		var ahead := along(route, walked + 1.5)
		level.player.position = point + Vector3(0, 0.04, 0)
		var direction := Vector3(ahead.x - point.x, 0, ahead.z - point.z)
		var sweep := sin(walked * 0.35) * SWEEP
		if direction.length() > 0.01: level.player.rotation.y = atan2(-direction.x, -direction.z) + sweep
		await process_frame
		frames += 1
		walked += WALK_STEP
		if frames % CHECK_EVERY == 0: check()
		if frames % FAR_EVERY == 0: far_check()
	return length


func track(node: Node) -> void:
	if not node is VisualInstance3D or not node.is_inside_tree(): return
	# What the player carries (the torch, the camcorder's lamp) is not the world.
	if level.player.is_ancestor_of(node): return
	var key := node.get_instance_id()
	var at := (node as Node3D).global_position
	var cell := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
	tracked[key] = {"node": node, "state": [], "cell": cell}
	if not grid.has(cell): grid[cell] = {}
	grid[cell][key] = true
	var up := node.get_parent()
	while up != null and up != level:
		if room_root_ids.has(up.get_instance_id()):
			room_of[key] = room_root_ids[up.get_instance_id()]
			break
		up = up.get_parent()


func on_added(node: Node) -> void:
	if not node is VisualInstance3D: return
	# Added in this tree but not yet placed: wait a frame for its transform.
	await process_frame
	if not is_instance_valid(node) or not node.is_inside_tree(): return
	track(node)
	if not tracked.has(node.get_instance_id()): return
	var entry: Dictionary = tracked[node.get_instance_id()]
	entry.state = state_of(node, eye())
	if entry.state[0] and seen(node, eye(), camera().get_frustum()): note(node, "creado", "aparece")


func on_removed(node: Node) -> void:
	if not node is VisualInstance3D: return
	var key := node.get_instance_id()
	if not tracked.has(key): return
	var entry: Dictionary = tracked[key]
	tracked.erase(key)
	if grid.has(entry.cell): grid[entry.cell].erase(key)
	if not entry.state.is_empty() and entry.state[0] and seen(node, eye(), camera().get_frustum()): note(node, "borrado", "desaparece")


func camera() -> Camera3D: return level.get_viewport().get_camera_3d()
func eye() -> Vector3: return camera().global_position


## [drawn, casting, shown]. A lamp past the end of its distance fade gives no
## light: shown or hidden there, nothing changes in the picture, and crossing
## the fade is gradual. So a lamp pops only when `shown` changes inside it.
func state_of(node: Node, from: Vector3) -> Array:
	var drawn := (node as Node3D).is_visible_in_tree()
	var shown := drawn
	var casting := false
	if node is GeometryInstance3D:
		var g := node as GeometryInstance3D
		if drawn and g.visibility_range_fade_mode == GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED and (g.visibility_range_end > 0.0 or g.visibility_range_begin > 0.0):
			var d := from.distance_to(middle(g))
			drawn = (g.visibility_range_begin <= 0.0 or d >= g.visibility_range_begin) and (g.visibility_range_end <= 0.0 or d < g.visibility_range_end)
	elif node is Light3D:
		var l := node as Light3D
		drawn = drawn and l.light_energy > 0.001
		if l.distance_fade_enabled and from.distance_to(l.global_position) >= l.distance_fade_begin + l.distance_fade_length: drawn = false
		casting = drawn and l.shadow_enabled
	return [drawn, casting, shown]


func middle(node: VisualInstance3D) -> Vector3:
	return (node.global_transform * node.get_aabb()).get_center()


func box_of(node: VisualInstance3D) -> AABB:
	if node is OmniLight3D: return AABB(node.global_position - Vector3.ONE * node.omni_range, Vector3.ONE * node.omni_range * 2.0)
	if node is SpotLight3D: return AABB(node.global_position - Vector3.ONE * node.spot_range, Vector3.ONE * node.spot_range * 2.0)
	return node.global_transform * node.get_aabb()


## In the picture, near and in sight: its box in the frustum, its nearest
## point within `near`, and nothing solid between the eye and its middle (a
## lamp is seen by what it lights, so it needs no sight line).
func seen(node: Node, from: Vector3, planes: Array) -> bool:
	var box := box_of(node)
	for plane: Plane in planes:
		var inside := Vector3(box.position.x if plane.normal.x > 0.0 else box.end.x, box.position.y if plane.normal.y > 0.0 else box.end.y, box.position.z if plane.normal.z > 0.0 else box.end.z)
		if plane.is_point_over(inside): return false
	var closest := from.clamp(box.position, box.end)
	if node is Light3D: return from.distance_to(node.global_position) <= near
	if from.distance_to(closest) > near: return false
	return in_sight(from, box)


func in_sight(from: Vector3, box: AABB) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, box.get_center())
	query.exclude = [level.player.get_rid()]
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or box.grow(0.3).has_point(hit.position)


func check() -> void:
	var from := eye()
	var planes := camera().get_frustum()
	var here := Vector2i(floori(from.x / CELL), floori(from.z / CELL))
	var span := ceili((near + CELL) / CELL)
	# Rooms first: a room shown or hidden is one pop, not one per piece in it.
	rooms_toggled.clear()
	for i in level.hotel.room_nodes.size():
		var room_node: Node3D = level.hotel.room_nodes[i]
		var shown := room_node.visible
		if room_node.has_meta("_probe_shown") and bool(room_node.get_meta("_probe_shown")) != shown:
			rooms_toggled[i] = true
			var spot: Vector3 = level.hotel.room_spots[i]
			if frames >= quiet_until and from.distance_to(spot) <= near + 12.0 and in_sight(from, AABB(spot + Vector3(-1, 0.5, -1), Vector3(2, 1.5, 2))):
				pops.append(record(room_node, "sala", "aparece" if shown else "desaparece", from, "room %d" % i, from.distance_to(spot)))
		room_node.set_meta("_probe_shown", shown)
	for x in range(here.x - span, here.x + span + 1):
		for z in range(here.y - span, here.y + span + 1):
			var cell := Vector2i(x, z)
			if not grid.has(cell): continue
			for key in grid[cell].keys():
				var entry: Dictionary = tracked.get(key, {})
				if entry.is_empty() or not is_instance_valid(entry.node):
					grid[cell].erase(key)
					continue
				var now := state_of(entry.node, from)
				var before: Array = entry.state
				entry.state = now
				if before.is_empty() or before == now: continue
				if rooms_toggled.has(room_of.get(key, -1)): continue
				if not seen(entry.node, from, planes): continue
				# A lamp crossing the end of its fade, shown all along, is gradual.
				if before[0] != now[0] and entry.node is Light3D and before[2] == now[2]: continue
				if before[0] != now[0]: note(entry.node, "rango" if why_range(entry.node) else "visible", "aparece" if now[0] else "desaparece")
				elif before[1] != now[1]: note(entry.node, "sombra", "enciende" if now[1] else "apaga")


func why_range(node: Node) -> bool:
	return node is GeometryInstance3D and (node as Node3D).is_visible_in_tree() and ((node as GeometryInstance3D).visibility_range_end > 0.0 or (node as GeometryInstance3D).visibility_range_begin > 0.0)


func note(node: Node, how: String, change: String) -> void:
	if frames < quiet_until: return
	var from := eye()
	pops.append(record(node, how, change, from, what(node), from.distance_to(box_of(node).get_center())))


func record(node: Node, how: String, change: String, from: Vector3, name: String, distance: float) -> Dictionary:
	var look := -camera().global_basis.z
	return {"t": snappedf(frames / 60.0, 0.01), "planta": planta_now, "how": how, "change": change, "class": node.get_class(), "what": name,
		"distance": snappedf(distance, 0.1), "eye": [snappedf(from.x, 0.01), snappedf(from.y, 0.01), snappedf(from.z, 0.01)],
		"look": [snappedf(look.x, 0.001), snappedf(look.y, 0.001), snappedf(look.z, 0.001)], "path": str(node.get_path()).right(90)}


## A name for the kind of thing: its mesh, its text, or its own name without
## the numbers the engine adds.
func what(node: Node) -> String:
	var text := ""
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		text = mesh.resource_name if not mesh.resource_name.is_empty() else mesh.resource_path.get_file()
	elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null and (node as MultiMeshInstance3D).multimesh.mesh != null:
		var mesh: Mesh = (node as MultiMeshInstance3D).multimesh.mesh
		text = "lote " + (mesh.resource_name if not mesh.resource_name.is_empty() else mesh.resource_path.get_file())
	elif node is Label3D: text = "texto"
	if text.is_empty(): text = String(node.name)
	var regex := RegEx.create_from_string("[@0-9_]+$")
	return node.get_class() + " " + regex.sub(text.replace("@", ""), "")


## What is missing far off: meshes in the picture and in sight beyond their
## range, and rooms in sight that are hidden.
func far_check() -> void:
	var from := eye()
	var planes := camera().get_frustum()
	var cut := 0
	var kinds := {}
	for key in tracked:
		var entry: Dictionary = tracked[key]
		var node = entry.node
		if not is_instance_valid(node) or not node is GeometryInstance3D: continue
		var g := node as GeometryInstance3D
		if g.visibility_range_end <= 0.0 or not g.is_visible_in_tree(): continue
		var d := from.distance_to(middle(g))
		if d < g.visibility_range_end or d > FAR_MOST: continue
		var box := box_of(g)
		var outside := false
		for plane: Plane in planes:
			var inside := Vector3(box.position.x if plane.normal.x > 0.0 else box.end.x, box.position.y if plane.normal.y > 0.0 else box.end.y, box.position.z if plane.normal.z > 0.0 else box.end.z)
			if plane.is_point_over(inside):
				outside = true
				break
		if outside or not in_sight(from, box): continue
		cut += 1
		var name := what(g)
		kinds[name] = int(kinds.get(name, 0)) + 1
	var hidden_rooms := 0
	for i in level.hotel.room_nodes.size():
		if level.hotel.room_nodes[i].visible or level.hotel.room_planta[i] != planta_now - 1: continue
		var spot: Vector3 = level.hotel.room_spots[i] + Vector3(0, 1.5, 0)
		if from.distance_to(spot) > 120.0: continue
		if camera().is_position_behind(spot) or not camera().is_position_in_frustum(spot): continue
		if in_sight(from, AABB(spot - Vector3.ONE, Vector3.ONE * 2.0)): hidden_rooms += 1
	far_checks.append({"t": snappedf(frames / 60.0, 0.01), "planta": planta_now, "cut": cut, "rooms": hidden_rooms, "kinds": kinds})


func summarize(minutes: float) -> Dictionary:
	var by_how := {}
	var by_what := {}
	for pop in pops:
		by_how[pop.how] = int(by_how.get(pop.how, 0)) + 1
		var key: String = "%s: %s" % [pop.how, pop.what]
		if not by_what.has(key): by_what[key] = {"count": 0, "distances": []}
		by_what[key].count += 1
		by_what[key].distances.append(pop.distance)
	var worst: Array = []
	for key in by_what:
		var d: Array = by_what[key].distances
		d.sort()
		worst.append({"what": key, "count": by_what[key].count, "median_m": d[d.size() / 2]})
	worst.sort_custom(func(a, b): return a.count > b.count)
	var cut: Array = far_checks.map(func(f): return f.cut)
	var rooms: Array = far_checks.map(func(f): return f.rooms)
	return {"pops": pops.size(), "per_minute": snappedf(pops.size() / minutes, 0.1), "by_how": by_how, "top": worst.slice(0, 25),
		"far_cut_mean": snappedf(float(cut.reduce(func(a, b): return a + b, 0)) / maxf(cut.size(), 1), 0.1),
		"far_rooms_mean": snappedf(float(rooms.reduce(func(a, b): return a + b, 0)) / maxf(rooms.size(), 1), 0.1), "tracked": tracked.size()}
