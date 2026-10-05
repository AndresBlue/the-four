extends RefCounted
## Draws the floor once, tiny, before it is played: the loading screen pays
## for the graphics pipelines so the game does not pay for them mid-step.
##
## Godot compiles a shader the first time something is drawn with it, and
## builds a pipeline per combination of material, mesh format and pass. Until
## the real one is ready it draws with a slow stand-in, so a floor nobody has
## drawn yet runs heavy for its first seconds and stutters when a room brings
## something new into view. There is no call to build a pipeline on demand
## (the engine exposes none), so the only way to ask for one is to draw with
## it -- which is what this does, in a viewport of a few hundred pixels.
##
## It draws the floor itself, not a rig of stand-ins: the same rooms, lamps,
## furniture, decals and shadows the game will draw, so every pipeline it
## builds is one the game was going to need, and nothing else. The viewport
## copies the real one's antialiasing, because that is part of what a
## pipeline is built against; it skips the camcorder's own stages, which are
## compute shaders built when the effect starts.
##
## Rooms are visited a few per kind (a bedroom is much like the next bedroom,
## but a laundry is not), the torch is turned on for the dark ones, and the
## creature, if it is already on the floor, is shown its frame too: meeting it
## is the worst possible moment for a stall. So is switching a set on: a lit
## television is shown its two frames as well.
##
## Cost, measured at Ultra on seed 81 (docs/PERFORMANCE.md, section 9): some
## 4 s more of loading, with a cold shader cache or a warm one alike -- most of
## it is walking the rooms, not compiling -- and never more than 0.15 s
## without a new frame, so the loading screen does not look hung.

const TELEVISION := preload("res://game/world/interactables/hotel_television.gd")
## The shape of the real frame, small enough that drawing costs nothing.
const SIZE := Vector2i(192, 108)
## Rooms visited per module type, and the two ways the camera looks.
const PER_TYPE := 3
const YAWS := [0.65, 0.65 + PI]

static func run(level) -> Dictionary:
	var started := Time.get_ticks_msec()
	var tree: SceneTree = level.get_tree()
	var main: Viewport = level.get_viewport()
	var viewport := SubViewport.new()
	viewport.name = "ShaderWarmup"
	viewport.size = SIZE
	viewport.world_3d = level.get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# What a pipeline is built against: the real viewport's antialiasing.
	viewport.msaa_3d = main.msaa_3d
	viewport.screen_space_aa = main.screen_space_aa
	viewport.use_taa = main.use_taa
	viewport.use_debanding = main.use_debanding
	viewport.positional_shadow_atlas_size = main.positional_shadow_atlas_size
	viewport.positional_shadow_atlas_16_bits = main.positional_shadow_atlas_16_bits
	var camera := Camera3D.new()
	camera.fov = float(level.player.camera.fov)
	camera.far = float(level.player.camera.far)
	# The world's own environment, so the fog and the ambient are the ones the
	# shaders will be compiled against; but none of the camcorder's stages.
	camera.environment = level.environment
	camera.compositor = Compositor.new()
	viewport.add_child(camera)
	# The player's own torch, for the rooms with no light of their own.
	var torch: SpotLight3D = level.player.torch.duplicate()
	torch.visible = false
	camera.add_child(torch)
	torch.position = Vector3.ZERO
	torch.rotation = Vector3.ZERO
	level.add_child(viewport)
	var stops := stops_of(level)
	var drawn := 0
	# The longest the loading screen went without a new frame: what the
	# player would read as the game hanging.
	var longest := 0
	var tick := Time.get_ticks_usec()
	for stop in stops:
		torch.visible = stop.dark
		level.hotel.update_visibility(stop.at, true)
		for yaw in YAWS:
			camera.global_position = stop.at + Vector3(0, level.player.eye_height, 0)
			camera.global_rotation = Vector3(-0.12, yaw, 0)
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			await tree.process_frame
			drawn += 1
			longest = maxi(longest, Time.get_ticks_usec() - tick)
			tick = Time.get_ticks_usec()
		if is_instance_valid(level.ui): level.ui.loading_note(progress(drawn, stops.size() * YAWS.size()))
	# The creature, if this floor already has one: four metres ahead, the
	# distance it is first seen from, and back where it was.
	var creature_frames := 0
	if is_instance_valid(level.locust) and not stops.is_empty():
		var kept: Transform3D = level.locust.global_transform
		level.locust.global_position = camera.global_position + camera.global_basis.z * -4.0 + Vector3(0, -level.player.eye_height, 0)
		for frame in 2:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			await tree.process_frame
			creature_frames += 1
		level.locust.global_transform = kept
	# A set switched on, a step ahead and facing the camera: its channel and
	# the shadows of its two lights are drawn by nothing else until somebody
	# switches one on, which is no moment for a stall either. The floor's own
	# sets are placed after this, so it is one of its own, gone at once.
	var set_frames := 0
	if not stops.is_empty():
		var probe: Area3D = TELEVISION.new()
		level.hotel.add_child(probe)
		probe.remove_from_group("hotel_televisions")
		var ahead: Vector3 = -camera.global_basis.z
		ahead.y = 0.0
		probe.global_position = Vector3(camera.global_position.x, stops[-1].at.y, camera.global_position.z) + ahead.normalized() * 1.6
		probe.global_rotation = Vector3(0, camera.global_rotation.y, 0)
		probe.set_on(true)
		probe.opening = 1.0
		probe.glow(1.0)
		for frame in 2:
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await RenderingServer.frame_post_draw
			await tree.process_frame
			set_frames += 1
		probe.queue_free()
	viewport.queue_free()
	# The floor is handed back the way it was found: what is drawn round the
	# player, and an iris that has not been metering a broom cupboard.
	level.hotel.update_visibility(level.player.global_position, true)
	if is_instance_valid(level.camera_effect): level.camera_effect.reset = true
	if is_instance_valid(level.ui): level.ui.loading_note("")
	var elapsed := Time.get_ticks_msec() - started
	print_verbose("Shader warmup: %d rooms, %d frames, %d ms, longest frame %d ms" % [stops.size(), drawn + creature_frames + set_frames, elapsed, longest / 1000])
	return {"rooms": stops.size(), "frames": drawn + creature_frames + set_frames, "ms": elapsed, "longest_ms": longest / 1000}

## Where to stand: a few rooms of each kind, dark ones included (they are the
## torch's variants), spread through the floor rather than taken in a row.
static func stops_of(level) -> Array:
	const FLOOR := preload("res://game/world/generation/floor_definition.gd")
	var seen := {}
	var stops: Array = []
	for room in level.manifest.rooms:
		var dark: bool = level.hotel.dark_room(room)
		var kind := "%d:%s" % [int(room.type), dark]
		var count: int = seen.get(kind, 0)
		if count >= PER_TYPE: continue
		seen[kind] = count + 1
		stops.append({"at": FLOOR.position_of(room) + Vector3(0, 0.04, 0), "dark": dark})
	return stops

static func progress(done: int, total: int) -> String:
	return "PREPARANDO LA IMAGEN  %d %%" % int(100.0 * done / maxi(total, 1))
