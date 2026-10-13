extends SceneTree
## A long corridor looked down from one end, as played: what its far cells
## look like from far away, from the same spot zoomed in, and from half way
## -- they are to be lit the same in all three. With it, what every lamp of
## the run was doing when the far picture was taken.
##
##   godot --rendering-method forward_plus --script res://tools/dev/corridor_look.gd -- --test-profile --automation --no-enemy --silent [--seed=81] [--quality=3] [--set=key:value,...] [--label=corridor]
##
## Writes evidence/<label>.png (far, zoomed, half way). Needs a window.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
var level

func _initialize() -> void: run.call_deferred()

## The longest row of corridor cells open on to each other with their lamps
## on, in order.
func longest_run() -> Array:
	var best: Array = []
	for room in level.manifest.rooms:
		if not bool(room.get("corridor", false)) or int(room.get("wing", 0)) != 0 or level.hotel.lights[int(room.id)].has_meta("off"): continue
		for way in [Vector2i(1, 0), Vector2i(0, 1)]:
			var back: int = FLOOR.beside(room, -way)
			if back >= 0 and level.hotel.open_pairs.has(Vector2i(mini(int(room.id), back), maxi(int(room.id), back))): continue
			var run: Array = [int(room.id)]
			while true:
				var next: int = FLOOR.beside(level.manifest.rooms[run[-1]], way)
				if next < 0 or not level.hotel.open_pairs.has(Vector2i(mini(run[-1], next), maxi(run[-1], next))) or level.hotel.lights[next].has_meta("off"): break
				run.append(next)
			if run.size() > best.size(): best = run
	return best

func look(from: Vector3, at: Vector3, zoom: float) -> void:
	level.player.global_position = Vector3(from.x, from.y + 0.04, from.z)
	var flat := Vector2(at.x - from.x, at.z - from.z)
	level.player.rotation.y = atan2(-flat.x, -flat.y)
	level.player.camera.rotation.x = -0.06
	level.player.zoom = zoom
	level.player.zoom_wanted = zoom
	level.player.snap_torch()

func run() -> void:
	var quality := PRESETS.ULTRA
	var seed_value := 81
	var label := "corridor"
	# "--slots=16": every quarter of the shadow atlas cut into that many (1, 4,
	# 16, 64...), so a far lamp's shadow is drawn as fine as a near one's.
	var slots := 0
	# "--turn": the run's ceiling lamps turned a quarter about X, so the seam
	# between the two halves of their shadow lies level instead of standing
	# through the floor under them. "--bare": the same lamps without their
	# profile, to tell what is the shadow's from what is the profile's.
	var turn := false
	var bare := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		if argument.begins_with("--slots="): slots = int(argument.trim_prefix("--slots="))
		if argument == "--turn": turn = true
		if argument == "--bare": bare = true
		if argument.begins_with("--set="):
			for pair in argument.trim_prefix("--set=").split(","):
				var text := pair.get_slice(":", 1)
				PRESETS.overrides[pair.get_slice(":", 0)] = (text == "true") if text in ["true", "false"] else (float(text) if "." in text else int(text))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(seed_value)
	level.settings.set_designed(quality)
	await level.bounce_ready()
	level.player.set_physics_process(false)
	level.player.torch.visible = false
	if is_instance_valid(level.locust):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
	if slots > 0:
		var cut := {1: Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1, 4: Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_4, 16: Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16, 64: Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_64, 256: Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_256}
		for quarter in 4: root.set_positional_shadow_atlas_quadrant_subdiv(quarter, cut[slots])
	print("CORRIDOR_LOOK atlas ", root.positional_shadow_atlas_size, " quarters ", range(4).map(func(quarter): return root.get_positional_shadow_atlas_quadrant_subdiv(quarter)))
	var cells := longest_run()
	if cells.size() < 3:
		print("CORRIDOR_LOOK no run of three cells")
		quit(1)
		return
	for cell in cells:
		var lamp: OmniLight3D = level.hotel.lights[cell]
		if turn: lamp.rotation.x = -PI / 2.0
		if bare:
			lamp.set_meta("profile", null)
			lamp.light_projector = null
	var first: Vector3 = FLOOR.position_of(level.manifest.rooms[cells[0]])
	var last: Vector3 = FLOOR.position_of(level.manifest.rooms[cells[-1]])
	var along := (last - first).normalized()
	var start := first - along * (maxf(FLOOR.size_of(level.manifest.rooms[cells[0]]).x, FLOOR.size_of(level.manifest.rooms[cells[0]]).y) * 0.5 - 1.2)
	print("CORRIDOR_LOOK seed=", seed_value, " quality=", quality, " cells=", cells, " metres=", snappedf(start.distance_to(last), 0.1))
	var page: Image
	var shots := [["far", start, 1.0], ["zoomed", start, 3.0], ["half way", start.lerp(last, 0.5), 1.0]]
	for index in shots.size():
		look(shots[index][1], last, shots[index][2])
		for frame in 90:
			await process_frame
			# The floor's own rounds of what is near (every quarter of a second).
		await RenderingServer.frame_post_draw
		var seen: Image = root.get_texture().get_image()
		seen.convert(Image.FORMAT_RGB8)
		if index == 0: page = Image.create(seen.get_width() * shots.size(), seen.get_height(), false, Image.FORMAT_RGB8)
		page.blit_rect(seen, Rect2i(Vector2i.ZERO, seen.get_size()), Vector2i(seen.get_width() * index, 0))
		if index == 0:
			for cell in cells:
				var under: Vector3 = level.hotel.lights[cell].global_position
				under.y = first.y + 0.02
				print("  under the lamp of cell ", cell, ": on screen at ", level.player.camera.unproject_position(under).round())
			print("  bounce volumes shown: ", level.hotel.bounce.volumes.filter(func(volume): return volume.visible).size(), " of ", level.hotel.bounce.volumes.size())
			for cell in cells:
				var lamp: OmniLight3D = level.hotel.lights[cell]
				# Whether the bounced light of its cell is being drawn (eight volumes at most are).
				var bounced := "none"
				for volume in level.hotel.bounce.volumes:
					var inside: Vector3 = (FLOOR.position_of(level.manifest.rooms[cell]) + Vector3(0, 1, 0)) - volume.global_position
					if absf(inside.x) < volume.size.x * 0.5 and absf(inside.y) < volume.size.y * 0.5 and absf(inside.z) < volume.size.z * 0.5: bounced = "shown" if volume.visible else "not shown"
				print("  cell ", cell, " at ", snappedf(lamp.global_position.distance_to(level.player.global_position), 0.1), " m: lit=", lamp.visible, " casts=", lamp.shadow_enabled, " bounce=", bounced, " mask=", "%x" % lamp.light_cull_mask, " range=", snappedf(lamp.omni_range, 0.1))
	page.save_png("res://evidence/%s.png" % label)
	print("CORRIDOR_LOOK evidence/%s.png: far, zoomed, half way" % label)
	level.queue_free()
	await process_frame
	quit()
