extends SceneTree
## The Lurker (game/enemies/lurker/lurker.tscn) set inside the hotel only to
## be looked at; nothing of the game drives it (docs/LURKER.md).
##   godot --path . --rendering-method forward_plus --script res://tools/capture/lurker_capture.gd -- --automation --test-profile --no-enemy --silent [--label=name] [--clip=loom] [--at=0.0]
## By default: in a lit corridor, its back to a wall, holding a clip still (the
## pose of the author's reference picture unless --clip says otherwise), filmed
## from low down the way that picture was. Writes evidence/lurker/<label>_<shot>_raw.png
## and _vhs.png, one with the corridor's own light and one with the torch on.
##
## With --walk (and --fixed-fps 30 before the --): its hands find their own
## holds while it crosses the corridor's floor, climbs the side wall and goes
## along the ceiling, filmed from the far end with the torch on. Writes
## evidence/lurker/<label>_walk_<frame>.jpg, every other frame.
##
## With --passage (and --fixed-fps 30): down a passage a metre wide towards a
## low camera, held up on the walls, like the staircase of the picture. Writes
## evidence/lurker/<label>_passage_<frame>.jpg; --raw without the camcorder.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const LURKER := preload("res://game/enemies/lurker/lurker.tscn")
const SIZE := Vector2i(1920, 1080)
const WALK_SIZE := Vector2i(960, 540)
const CORRIDOR := 11
var level
var out_dir := "res://evidence/lurker"
var label := "current"
## --no-dark: without its fog, to see what the arms are doing.
var bare := false
## --passage: a passage a metre wide, like the staircase of the picture.
var passage := false
## --raw: the passage's frames without the camcorder over them.
var raw := false

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var clip := "loom"
	var at := 0.0
	var distance := 1.55
	var eye := 0.95
	var walking := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		if argument.begins_with("--clip="): clip = argument.trim_prefix("--clip=")
		if argument.begins_with("--at="): at = float(argument.trim_prefix("--at="))
		if argument.begins_with("--distance="): distance = float(argument.trim_prefix("--distance="))
		if argument.begins_with("--eye="): eye = float(argument.trim_prefix("--eye="))
		if argument == "--walk": walking = true
		if argument == "--no-dark": bare = true
		if argument == "--passage": passage = true
		if argument == "--raw": raw = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(81)
	level.settings.set_designed(PRESETS.HIGH)
	await level.bounce_ready()
	DisplayServer.window_set_size(WALK_SIZE if walking or passage else SIZE)
	level.player.set_physics_process(false)
	# The player would put its eye back at standing height every frame, and a
	# mouse moved over the window would turn it.
	level.player.set_process(false)
	level.player.set_process_input(false)
	level.player.set_process_unhandled_input(false)
	if is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
	var room := pick()
	if room.is_empty():
		print("LURKER no lit corridor")
		quit(1)
		return
	var beast: Node3D = LURKER.instantiate()
	level.add_child(beast)
	if bare:
		beast.ink.visible = false
		beast.vapour.visible = false
	report(beast)
	if passage:
		await narrow(room, beast)
	elif walking:
		await walk(room, beast)
	else:
		await pose(room, beast, clip, at, distance, eye)
	level.queue_free()
	await process_frame
	quit()

func pose(room: Dictionary, beast: Node3D, clip: String, at: float, distance: float, eye: float) -> void:
	var centre := FLOOR.position_of(room)
	var span: Vector2 = FLOOR.size_of(room)
	# Its back to the long wall of the corridor, facing across it.
	var along_x := span.x >= span.y
	var back := Vector3(0, 0, -1) if along_x else Vector3(-1, 0, 0)
	var half := (span.y if along_x else span.x) * 0.5
	var spot := centre + back * (half - 0.62)
	spot.y = 0.0
	beast.global_position = spot
	beast.rotation.y = 0.0 if along_x else PI * 0.5
	beast.crawling = false
	beast.play(clip, 0.0)
	beast.animator.seek(at, true)
	beast.animator.speed_scale = 0.0
	# The camera low and close, a little to one side, looking up at the face.
	var from := spot - back * distance + (Vector3(0.03, 0, 0) if along_x else Vector3(0, 0, 0.03))
	place_eye(Vector3(from.x, eye, from.z), 0.0 if along_x else PI * 0.5, 0.16)
	level.player.torch.visible = false
	await capture("lit")
	level.player.torch.visible = true
	level.player.snap_torch()
	await capture("torch")

## Floor, wall, ceiling: a stretch of the corridor whose side wall is whole for
## two metres, so no doorway breaks the climb.
func walk(room: Dictionary, beast: Node3D) -> void:
	var centre := FLOOR.position_of(room)
	var span: Vector2 = FLOOR.size_of(room)
	var along_x := span.x >= span.y
	var along := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var toward := Vector3(0, 0, -1) if along_x else Vector3(-1, 0, 0)
	for i in 4: await physics_frame
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var length := (span.x if along_x else span.y) * 0.5 - 1.0
	var best := {}
	var offset := -length
	while offset <= length and best.is_empty():
		var hits := []
		for k in 5:
			var o := offset + (k - 2) * 0.5
			var p := Vector3(centre.x, centre.y + 1.2, centre.z) + along * o
			hits.append(ray(space, p, p + toward * 6.0))
		var whole := hits.all(func(h): return not h.is_empty())
		if whole:
			var flat := true
			for h in hits:
				if absf((h.position - hits[2].position).dot(toward)) > 0.03: flat = false
			if flat: best = {"offset": offset, "wall": hits[2]}
		offset += 0.5
	if best.is_empty():
		print("LURKER no whole wall in the corridor")
		return
	var mid: Vector3 = Vector3(centre.x, centre.y + 1.2, centre.z) + along * float(best.offset)
	var ceiling := ray(space, mid, mid + Vector3.UP * 5.0)
	var ground := ray(space, mid, mid + Vector3.DOWN * 3.0)
	if ceiling.is_empty() or ground.is_empty():
		print("LURKER no floor or ceiling")
		return
	var floor_y: float = ground.position.y
	var ceil_y: float = ceiling.position.y
	var wall: Vector3 = best.wall.position
	var wn: Vector3 = best.wall.normal
	var base := Vector3(mid.x, floor_y, mid.z)

	var at_wall := func(height: float, slide: float) -> Vector3:
		return Vector3(wall.x, height, wall.z) + along * slide
	var keys := [
		[0.0, base - along * 2.3 + wn * 0.2, Vector3.UP, along],
		[2.5, Vector3(wall.x, floor_y, wall.z) + wn * 0.55 - along * 0.55, Vector3.UP, (along - wn * 0.7).normalized()],
		[3.4, at_wall.call(floor_y + 0.62, -0.3), wn, Vector3.UP],
		[5.0, at_wall.call(ceil_y - 0.66, 0.0), wn, Vector3.UP],
		[6.0, Vector3(wall.x, ceil_y, wall.z) + wn * 0.62 + along * 0.25, Vector3.DOWN, wn],
		[8.4, Vector3(mid.x, ceil_y, mid.z) + wn * 0.5 + along * 1.6, Vector3.DOWN, along],
	]
	# from across the corridor, near the other wall, a little ahead
	var across := ray(space, mid, mid + wn * 8.0)
	var width: float = (across.position - wall).dot(wn) if not across.is_empty() else 3.0
	print("LURKER walk: floor %.2f ceiling %.2f wall %s width %.2f" % [floor_y, ceil_y, wall, width])
	# a camera across the corridor that keeps the creature in the middle
	var eye := Vector3(wall.x, 1.25, wall.z) + wn * minf(2.3, width - 0.35) + along * 1.3
	var look := Vector3(wall.x, 1.0, wall.z) + wn * 0.4 - along * 0.6
	aim_eye(eye, look)
	level.player.torch.visible = true
	level.player.snap_torch()
	level.hotel.update_visibility(level.player.global_position, true)
	level.ui.visible = false
	var frames := int(8.6 * 30.0)
	for frame in frames:
		var t := frame / 30.0
		beast.global_transform = sample(keys, t)
		var body: Vector3 = beast.global_transform * Vector3(0.0, 0.3, 0.0)
		look = look.lerp(body, 0.15 if frame > 0 else 1.0)
		aim_eye(eye, look)
		await process_frame
		if frame % 2 == 0 and frame > 6:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(out_dir + "/%s_walk_%03d.jpg" % [label, frame], 0.86)
	print("LURKER walk ", frames, " frames")

## A passage a metre wide built inside the corridor, plain plaster like the
## staircase of the picture: the creature comes down it towards the camera
## held up off the floor by its hands on the walls, its face on the lens.
func narrow(room: Dictionary, beast: Node3D) -> void:
	var centre := FLOOR.position_of(room)
	var span: Vector2 = FLOOR.size_of(room)
	var along_x := span.x >= span.y
	var along := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var side := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	var base := Vector3(centre.x, 0.0, centre.z)
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color(0.62, 0.55, 0.45)
	plaster.roughness = 0.95
	for k in [-1.0, 1.0]:
		var wall := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var size := Vector3(7.0, 2.7, 0.12) if along_x else Vector3(0.12, 2.7, 7.0)
		box.size = size
		shape.shape = box
		wall.add_child(shape)
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = size
		mesh.mesh = cube
		mesh.material_override = plaster
		wall.add_child(mesh)
		level.add_child(wall)
		wall.global_position = base + side * k * (0.55 + 0.06) + Vector3.UP * 1.35
	for i in 4: await physics_frame
	beast.cling = 1.0
	beast.play("crawl", 0.0)
	var start := base + along * 2.6 + Vector3.UP * 0.95
	var finish := base + along * 0.2 + Vector3.UP * 0.95
	# the camera at the bottom of it, low, looking up the passage, the torch on
	# it the way the picture's flash is
	var eye := base - along * 1.3 + Vector3.UP * 0.7
	aim_eye(eye, base + along * 1.0 + Vector3.UP * 1.05)
	level.player.torch.visible = true
	level.player.snap_torch()
	level.hotel.update_visibility(level.player.global_position, true)
	level.ui.visible = false
	if raw:
		level.set_process(false)
		for layer in ["Presentation/Analog/Screen", "Presentation/Lens", "Presentation/Camcorder"]:
			level.get_node(layer).visible = false
	var frames := int(7.0 * 30.0)
	var look := base + along * 1.0 + Vector3.UP * 1.05
	var skeleton: Skeleton3D = beast.skeleton
	var head := skeleton.find_bone("head")
	for frame in frames:
		var u := clampf(frame / 30.0 / 6.0, 0.0, 1.0)
		var at := start.lerp(finish, u * u * (3.0 - 2.0 * u))
		# head first, as it comes down the stairs of the picture
		var pitched := frame_basis(Vector3.UP, -along).rotated(along.cross(Vector3.UP).normalized(), deg_to_rad(18.0))
		beast.global_transform = Transform3D(pitched, at)
		# the lens and the torch on the face
		var face: Vector3 = skeleton.global_transform * (skeleton.get_bone_global_pose(head) * Vector3(0.0, 0.05, 0.0))
		look = look.lerp(face, 0.12 if frame > 0 else 0.0)
		aim_eye(eye, look)
		await process_frame
		if frame % 2 == 0 and frame > 6:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_jpg(out_dir + "/%s_passage_%03d.jpg" % [label, frame], 0.86)
	print("LURKER passage ", frames, " frames")

func frame_basis(up: Vector3, forward: Vector3) -> Basis:
	return frame(up, forward)

func sample(keys: Array, t: float) -> Transform3D:
	var i := 0
	while i < keys.size() - 2 and t >= keys[i + 1][0]: i += 1
	var a: Array = keys[i]
	var b: Array = keys[i + 1]
	var u := clampf((t - a[0]) / (b[0] - a[0]), 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var qa := frame(a[2], a[3]).get_rotation_quaternion()
	var qb := frame(b[2], b[3]).get_rotation_quaternion()
	return Transform3D(Basis(qa.slerp(qb, u)), (a[1] as Vector3).lerp(b[1], u))

func frame(up: Vector3, forward: Vector3) -> Basis:
	var y := up.normalized()
	var z := (forward - y * forward.dot(y)).normalized()
	return Basis(y.cross(z), y, z)

func ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))

func aim_eye(eye: Vector3, look: Vector3) -> void:
	var d := look - eye
	place_eye(eye, atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))

func place_eye(eye: Vector3, yaw: float, pitch: float) -> void:
	var height := 1.0
	level.player.global_position = eye - Vector3.UP * height
	level.player.eye_height = height
	level.player.camera.position = Vector3(0, height, 0)
	level.player.rotation.y = yaw
	level.player.camera.rotation.x = pitch
	level.player.snap_torch()

func lit(room: Dictionary) -> bool:
	return not level.hotel.lights[int(room.id)].has_meta("off")

func pick() -> Dictionary:
	for room in level.manifest.rooms:
		if int(room.get("hall", -1)) >= 0 and int(room.hall) != int(room.id): continue
		if int(room.type) == CORRIDOR and lit(room): return room
	return {}

func report(beast: Node3D) -> void:
	for mesh_instance in beast.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mesh_instance.mesh
		for surface in mesh.get_surface_count():
			var material = mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				print("LURKER %s/%d %s shading=%d vertex_color=%s specular=%.2f rough=%.2f cull=%d" % [mesh_instance.name, surface, material.resource_name,
					material.shading_mode, material.vertex_color_use_as_albedo, material.metallic_specular, material.roughness, material.cull_mode])

func capture(shot: String) -> void:
	level.hotel.update_visibility(level.player.global_position, true)
	level.hotel.flicker_clock = 0.4
	level.hotel._process(0.0)
	level.hotel.set_process(false)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 1500: await process_frame
	# The objective's lines belong to playing, not to this picture.
	level.ui.visible = false
	var screen: CanvasItem = level.get_node("Presentation/Analog/Screen")
	var lens: CanvasLayer = level.get_node("Presentation/Lens")
	var camcorder: CanvasLayer = level.get_node("Presentation/Camcorder")
	level.set_process(false)
	screen.visible = false
	lens.visible = false
	camcorder.visible = false
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/%s_%s_raw.png" % [label, shot])
	screen.visible = true
	lens.visible = true
	camcorder.visible = true
	level.set_process(true)
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/%s_%s_vhs.png" % [label, shot])
	level.hotel.set_process(true)
	print("LURKER ", shot)
