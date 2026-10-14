extends SceneTree
## From inside a wardrobe, as played: with the doors shut (looking ahead and
## turned as far as they let you), and holding forward -- looking ahead, to
## the left and to the right. For each, where the head is in the wardrobe,
## how far each leaf stands open and how wide the gap between them is; and,
## before any of it, how far apart the two leaves are when they are shut.
##
##   godot --rendering-method forward_plus --script res://tools/dev/wardrobe_look.gd -- --test-profile --automation --no-enemy --silent [--seed=81] [--big] [--nth=0] [--label=wardrobe]
##
## "--big": the double wardrobe (two inside); "--nth=2": the third wardrobe
## of that kind in a lit room instead of the first. Writes evidence/<label>.png,
## the five views in the order the log names them. Needs a window.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
var level

func _initialize() -> void: run.call_deferred()

## How far apart the shut leaves are (millimetres; less than nothing where
## one laps over the other), at forty heights: each leaf cut level there, and
## the nearest it comes to the other taken.
func crack(hide) -> PackedFloat32Array:
	# Every edge of each leaf's triangles, in the wardrobe's own space.
	var edges := {"left": [], "right": []}
	for side in edges:
		var leaf: MeshInstance3D = hide.pivots[side].get_child(0)
		var stood: Transform3D = hide.pivots[side].transform * leaf.transform
		for surface in leaf.mesh.get_surface_count():
			var arrays: Array = leaf.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = stood * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
			var corners: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(points.size()))
			for triangle in range(0, corners.size() - 2, 3):
				for corner in 3: edges[side].append([points[corners[triangle + corner]], points[corners[triangle + (corner + 1) % 3]]])
	var gaps := PackedFloat32Array()
	for step in 40:
		var cut: float = hide.height * (0.06 + step * 0.022)
		var reach := {"left": -INF, "right": INF}
		for side in edges:
			for edge in edges[side]:
				var a: Vector3 = edge[0]
				var b: Vector3 = edge[1]
				if (a.y - cut) * (b.y - cut) > 0.0 or absf(a.y - b.y) < 0.00001: continue
				var x: float = lerpf(a.x, b.x, (cut - a.y) / (b.y - a.y))
				if side == "left": reach.left = maxf(reach.left, x)
				else: reach.right = minf(reach.right, x)
		gaps.append(snappedf((reach.right - reach.left) * 1000.0, 0.1))
	return gaps

func picture(frames: int) -> Image:
	for frame in frames: await process_frame
	await RenderingServer.frame_post_draw
	var seen: Image = root.get_texture().get_image()
	seen.convert(Image.FORMAT_RGB8)
	return seen

func run() -> void:
	var quality := PRESETS.ULTRA
	var seed_value := 81
	var label := "wardrobe"
	var big := false
	var nth := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		if argument.begins_with("--nth="): nth = int(argument.trim_prefix("--nth="))
		if argument == "--big": big = true
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(seed_value)
	level.settings.set_designed(quality)
	await level.bounce_ready()
	if is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
	var player = level.player
	var hide: Node3D
	for place in get_nodes_in_group("hotel_hides"):
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, place.global_position)
		if place.big != big or room.is_empty() or int(room.get("wing", 0)) != 0 or level.hotel.lights[int(room.id)].has_meta("off"): continue
		if nth == 0:
			hide = place
			break
		nth -= 1
	if hide == null:
		print("WARDROBE_LOOK no such wardrobe in a lit room")
		quit(1)
		return
	var home: Dictionary = FLOOR.room_at(level.manifest.rooms, hide.global_position)
	print("WARDROBE_LOOK seed=", seed_value, " room ", home.id, " type ", home.type, " big=", big, " width=", snappedf(hide.width, 0.01), " hinge=", hide.hinge.snapped(Vector3.ONE * 0.001))
	var gaps := crack(hide)
	var sorted := Array(gaps)
	sorted.sort()
	print("  shut, the leaves stand apart (mm) from ", sorted[0], " to ", sorted[-1], ", half of the way up or more at ", sorted[sorted.size() / 2], ": ", gaps)
	player.global_position = hide.to_global(hide.exit_of(player))
	player.torch.visible = false
	level.hotel.update_visibility(player.global_position, true)
	player.active = true
	player.enter_hide(hide)
	for frame in 90: await physics_frame
	var page: Image
	var shots := [["shut", false, 0.0], ["shut, turned", false, 2.0], ["ajar", true, 0.0], ["ajar, to the left", true, 2.0], ["ajar, to the right", true, -2.0]]
	for index in shots.size():
		if shots[index][1]: Input.action_press("forward")
		else: Input.action_release("forward")
		# Asked for more than it gives: the wardrobe says how far the head turns.
		for frame in 150:
			player.rotation.y = player.hide_yaw + float(shots[index][2])
			await physics_frame
		var seen := await picture(40)
		var head: Vector3 = hide.to_local(player.camera.global_position)
		var gap: float = (hide.pivots.right.position + hide.pivots.right.basis * Vector3(-hide.hinge.x, 0, 0)).distance_to(hide.pivots.left.position + hide.pivots.left.basis * Vector3(hide.hinge.x, 0, 0))
		print("  ", shots[index][0], ": turned ", snappedf(rad_to_deg(wrapf(player.rotation.y - player.hide_yaw, -PI, PI)), 0.1), " deg, head at ", head.snapped(Vector3.ONE * 0.01), " (the doors' plane is z=", snappedf(hide.hinge.z, 0.01), "), leaves open ", snappedf(rad_to_deg(hide.leaf_angle("left")), 0.1), " and ", snappedf(rad_to_deg(hide.leaf_angle("right")), 0.1), " deg, their free edges ", snappedf(gap, 0.001), " m apart")
		if index == 0: page = Image.create(seen.get_width() * shots.size(), seen.get_height(), false, Image.FORMAT_RGB8)
		page.blit_rect(seen, Rect2i(Vector2i.ZERO, seen.get_size()), Vector2i(seen.get_width() * index, 0))
	Input.action_release("forward")
	page.save_png("res://evidence/%s.png" % label)
	print("WARDROBE_LOOK evidence/%s.png: " % label, ", ".join(shots.map(func(shot): return shot[0])))
	level.queue_free()
	await process_frame
	quit()
