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
##   corridor      a corridor described entirely in grains
##   corridor_wave one frame mid-sweep: the front lighting the grains it passes
##   doorway       a door frame crowded with grains, and a noise hanging by it
##   body_seen     a survivor in plain sight, as a human-shaped cloud
##   body_walled   the same survivor behind a wall: no silhouette at all
##   shriek        the reading flooded red
##   memory        turned away two seconds later: the points stayed put
##   reduced       reduced effects: calm, flat, still navigable
##   preset_0..3   the corridor on each graphics preset: Bajo coarser grains,
##                 Ultra finer ones with its brightest grains blooming
##   lit           a survivor's torch as interference
##   guide_lift    the survivors have gone on and it has not: the way to its
##                 car in blue, through the walls, flowing towards the car
##   guide_tv      in the next wing: the lit sets in yellow and, after Q, the
##                 way to the nearest one
##   guide_screen  a lit set seen from a few metres, through the wall or not
##   channels_*    at a lit set with the map of the others open: the compass
##                 on the floor, level (a line), tilted, and looking down
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
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

## Waits for the next click, then for the front to travel `seconds` worth.
func after_click(echo, seconds: float) -> void:
	var seen: int = echo.clicks
	var ticks := 0
	while echo.clicks == seen and ticks < 180:
		ticks += 1
		await physics_frame
	for i in int(seconds * 60.0): await physics_frame

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
	# The tape screen plays over everything for its first seconds and these
	# shots are about what is behind it.
	level.ui.finish_intro()
	await level.take_locust(81)
	# Unattended: a stray click on the window must not strike the survivor.
	level.locust.driver.set_process_unhandled_input(false)
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

	# One frame caught mid-sweep, by waiting for a click and then letting the
	# front travel a few metres before the shutter.
	await after_click(echo, 0.34)
	await shot("corridor_wave")

	# A doorway, with a noise arriving through it.
	var door = level.hotel.doors[mini(4, level.hotel.doors.size() - 1)]
	look(door.doorway + Vector3(0, 0, 3.2), door.doorway)
	await listen(2.0)
	level.on_noise(door.doorway + Vector3(0, 0.2, -2.5), 12.0, NOISE.Kind.SLAM)
	await listen(0.5)
	await shot("doorway")

	# A survivor in plain sight, then the same one behind a wall.
	look(centre + Vector3(0, 0, 4.0), centre)
	# Close enough to judge whether the grains read as a person, and off to the
	# side so the creature's own shoulders are not in the way.
	level.player.global_position = centre + Vector3(1.7, 0.06, 1.4)
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

	# The survivors have gone on and it has not: the way to its car, in blue.
	level.session.stage = 2
	var car: int = level.lifts.creature_car(2)
	look(Vector3(0, 0, 0), level.hotel.lifts[maxi(car, 0)] if car >= 0 else centre)
	await listen(2.5)
	await shot("guide_lift")
	# In the next wing: the lit sets burn yellow, and Q lays the way to one.
	level.lifts.apply_locust_ride(level.hotel.arrivals[0] + Vector3(0, 0.04, 0))
	level.lifts.lift_away.clear()
	for index in level.stage_televisions(2).slice(0, 3): level.apply_television(int(index), true)
	level.locust.grace = 0.0
	level.locust.driver.trace_cooldown = 0.0
	level.locust.driver.trace()
	var aimed: int = level.locust.driver.trace_target
	look(level.hotel.arrivals[0], level.televisions[aimed].global_position if aimed >= 0 else centre)
	await listen(2.5)
	await shot("guide_tv")
	if aimed >= 0:
		var screen_at: Vector3 = level.televisions[aimed].screen_point()
		look(level.locust.driver.set_front(aimed) + (level.locust.driver.set_front(aimed) - level.televisions[aimed].global_position).normalized() * 3.0, screen_at, 0.0)
		await listen(1.5)
		await shot("guide_screen")
	# At a lit set with the map of the others open: a compass lying on the
	# floor, flat as a line level with the horizon and round looking down.
	var lit: Array = level.lit_televisions()
	if lit.size() >= 2:
		level.locust.global_position = level.television_exit(int(lit[0])) + Vector3(0, 0.04, 0)
		level.locust.driver.channel_open = true
		for view in [["level", 0.0], ["tilted", -0.55], ["down", -1.1]]:
			level.locust.driver.pitch = view[1]
			await listen(0.6)
			await shot("channels_" + String(view[0]))
		level.locust.driver.channel_open = false
	for index in level.stage_televisions(2): level.apply_television(int(index), false)
	level.locust.driver.trace_left = 0.0
	level.session.stage = 1
	look(centre + Vector3(0, 0, 3.0), centre + Vector3(0, 0, -6.0))
	level.settings.values.reduced = true
	level.apply_settings()
	await listen(2.5)
	await shot("reduced")
	level.settings.values.reduced = false
	for quality in PRESETS.count():
		level.settings.set_value("quality", quality)
		await listen(2.5)
		await shot("preset_%d" % quality)

	paused = false
	level.queue_free()
	await process_frame
	quit()
