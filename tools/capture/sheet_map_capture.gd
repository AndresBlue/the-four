extends SceneTree
## The shared sheet with its plan (game/app/floor_map.gd, game/ui/sheet_map.gd):
## the player is walked along the way to the refuge looking about, the plan
## fills in, and the sheet is shot fresh, blooming, and old enough to fray;
## with the four pages of the code hanging in their chain. With a window:
##   godot --path . --script res://tools/capture/sheet_map_capture.gd -- --test-profile --automation --silent [--seed=81]
## Shots in evidence/sheet_map_*.png.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(filename: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/sheet_map_%s.png" % filename)
	print("CAPTURE evidence/sheet_map_%s.png" % filename)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	var seed_value := 81
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
	await level.start_floor(seed_value)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	# Along the way to the refuge, looking round at every room.
	var refuge := int(level.manifest.refuges[0])
	var metres := FLOOR.route_metres(level.manifest, refuge)
	var at := FLOOR.entry_of(level.manifest, 0)
	var walked := 0
	while at != refuge and walked < 60:
		walked += 1
		var here := FLOOR.position_of(level.manifest.rooms[at])
		level.player.position = here + Vector3(0, 0.04, 0)
		for turn in 8:
			level.player.rotation.y = TAU * turn / 8.0
			await physics_frame
			level.floor_map.look_now()
		var best := at
		for other in level.manifest.adjacency[at]:
			if float(metres.get(int(other), INF)) < float(metres.get(best, INF)): best = int(other)
		if best == at: break
		at = best
		# A little time between rooms, so the oldest lines are older.
		level.floor_map.clock += 3.0
	# The pages of the code, all four found by this player.
	for slot in range(1, DIGITS.COUNT + 1):
		level.found_digits[slot] = (slot * 3) % 10
		level.found_by[slot] = level.player.slot
		level.found_where[slot] = "HABITACIÓN %d" % (100 + slot * 7)
	level.toggle_sheet()
	await shot("fresh")
	# Two minutes on: what was seen first is fraying, the rest paler.
	level.floor_map.clock += 120.0
	await shot("fraying")
	# All of it gone, and the last room looked at again: the ink blooms back.
	level.floor_map.clock += 70.0
	level.floor_map.look_now()
	level.floor_map.clock += 0.25
	await shot("bloom")
	level.toggle_sheet()
	level.queue_free()
	await process_frame
	quit()
