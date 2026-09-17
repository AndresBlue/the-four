extends SceneTree
## Frames of The Locust's acoustic view, from the local hunter preview.
## Needs a window (it reads the rendered image), never --headless.
##
##   godot --path . --script res://tools/capture/echo_capture.gd --
##       -- --automation --silent --test-profile --prefix=echo
##
## --automation is what skips the VCR boot animation, which would otherwise sit
## over every frame.
##
## Produces evidence/<prefix>_*.png:
##   corridor      depth bands and corner returns on real geometry
##   corridor_wave one frame mid-sweep: the front as an arc across the walls
##   doorway       a landmark outline and a noise arriving through a door
##   body_seen     a survivor in plain sight, as a human-shaped cloud
##   body_walled   the same survivor behind a wall: no silhouette at all
##   shriek        the reading flooded red
##   memory        turned away two seconds later: the points stayed put
##   reduced       reduced effects: calm, flat, still navigable
##   quality0      the field alone, no point cloud
##   lit           a survivor's torch as interference
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
var level
var prefix := "echo"

func _initialize() -> void: run.call_deferred()

func shot(filename: String) -> void:
	level.hotel.update_visibility(level.locust.global_position, false)
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/%s_%s.png" % [prefix, filename])
	print("SHOT ", filename)

## Put the creature somewhere, looking at something.
func look(from: Vector3, target: Vector3, pitch := -0.1) -> void:
	level.locust.global_position = from + Vector3(0, 0.04, 0)
	var offset := target - from
	level.locust.rotation = Vector3(0, atan2(-offset.x, -offset.z), 0)
	level.locust.driver.pitch = pitch

## Let the clicks run for a while so the memory fills in.
func listen(seconds: float) -> void:
	var until := seconds
	while until > 0.0:
		until -= 1.0 / 60.0
		await physics_frame

func first_room(test: Callable) -> Dictionary:
	for room in level.manifest.rooms:
		if test.call(room): return room
	return {}

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--prefix="): prefix = argument.trim_prefix("--prefix=")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.take_locust(81)
	level.settings.values.quality = 2
	level.apply_settings()
	var echo = level.locust.driver.echo
	# The survivor stands still and out of the way unless a shot needs it.
	level.player.global_position = Vector3(0, 0.06, 40.0)

	var corridor := first_room(func(r): return int(r.type) in [11, 12] and int(r.get("hall", -1)) == -1)
	var centre: Vector3 = FLOOR.position_of(corridor)
	look(centre + Vector3(0, 0, 3.0), centre + Vector3(0, 0, -6.0))
	await listen(3.0)
	await shot("corridor")

	# One frame caught mid-sweep: freeze the clicks and place the front by hand
	# six metres out, which is the only way to prove the shell on a still image.
	level.locust.set_physics_process(false)
	echo.shells.clear()
	echo.shells.push_back([echo.creature.global_position + Vector3(0, level.locust.driver.EYE.y, 0), echo.clock - 6.0 / echo.WAVE_SPEED, 1.0, echo.REACH])
	echo.push_uniforms()
	await shot("corridor_wave")
	level.locust.set_physics_process(true)

	# A doorway, with a noise arriving through it.
	var door = level.hotel.doors[mini(4, level.hotel.doors.size() - 1)]
	look(door.doorway + Vector3(0, 0, 3.2), door.doorway)
	await listen(2.0)
	level.on_noise(door.doorway + Vector3(0, 0.2, -2.5), 12.0, NOISE.Kind.SLAM)
	await listen(0.5)
	await shot("doorway")

	# A survivor in plain sight, then the same one behind a wall.
	look(centre + Vector3(0, 0, 4.0), centre)
	level.player.global_position = centre + Vector3(0, 0.06, -2.0)
	await listen(2.0)
	await shot("body_seen")
	level.player.global_position = centre + Vector3(0, 0.06, 40.0)
	await listen(1.5)
	await shot("body_walled")

	# Its own shriek: the reading floods red.
	level.player.global_position = centre + Vector3(0, 0.06, -3.0)
	await listen(1.0)
	echo.flash_shriek()
	await listen(0.4)
	await shot("shriek")
	echo.shriek_hold = 0.0
	await listen(4.0)

	# A lit torch pointed at it is interference, not an image.
	level.player.torch.visible = true
	level.player.rotation.y = level.locust.rotation.y + PI
	await listen(0.8)
	await shot("lit")
	level.player.torch.visible = false

	# Turned away: the points it stamped are still where the walls really are.
	await listen(2.0)
	look(centre + Vector3(0, 0, 4.0), centre + Vector3(6.0, 0, 4.0))
	await listen(0.1)
	await shot("memory")

	look(centre + Vector3(0, 0, 3.0), centre + Vector3(0, 0, -6.0))
	level.settings.values.reduced = true
	level.apply_settings()
	await listen(2.5)
	await shot("reduced")
	level.settings.values.reduced = false
	level.settings.values.quality = 0
	level.apply_settings()
	await listen(2.0)
	await shot("quality0")

	paused = false
	level.queue_free()
	await process_frame
	quit()
