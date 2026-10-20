extends SceneTree
## The hints of the third stage (game/world/generation/hint_placement.gd) as
## they are seen: the eight papers of a floor side by side (hint_view.gd), and
## the sheet with all of them hanging under the pages and what they mark on
## the plan. With a window:
##   godot --path . --script res://tools/capture/hint_capture.gd -- --test-profile --automation --silent [--seed=81] [--survivors=1]
## Shots in evidence/hints_<seed>_papers.png and evidence/hints_<seed>_sheet.png.
const VIEW := preload("res://game/ui/hint_view.gd")
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
var level

func _initialize() -> void: run.call_deferred()

func shot(name: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://evidence/%s.png" % name)
	print("CAPTURE evidence/%s.png" % name)

func run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var seed_value := 81
	var survivors := 1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--survivors="): survivors = int(argument.trim_prefix("--survivors="))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	var slots: Array = range(1, survivors + 1)
	await level.start_floor(seed_value, false, slots)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.player.set_physics_process(false)
	# The eight on a dark table, in rows.
	var screen: Vector2 = root.get_visible_rect().size
	var board := ColorRect.new()
	board.color = Color(0.07, 0.06, 0.05)
	board.size = screen
	level.ui.add_child(board)
	var walls: Array = level.code.hint_walls()
	var x := 24.0
	var y := 24.0
	var row := 0.0
	for hint in level.code.hints:
		var view := VIEW.new()
		view.setup(hint, walls)
		var shrink := minf((screen.x - 120.0) / 4.0 / view.card.x, (screen.y - 70.0) / 2.0 / view.card.y)
		view.scale = Vector2.ONE * shrink
		if x + view.card.x * shrink > screen.x - 16.0:
			x = 24.0
			y += row + 20.0
			row = 0.0
		view.position = Vector2(x, y)
		board.add_child(view)
		x += view.card.x * shrink + 20.0
		row = maxf(row, view.card.y * shrink)
	await shot("hints_%d_papers" % seed_value)
	board.queue_free()
	# All of them this player's, the four pages too, and the sheet open.
	for hint in level.code.hints: level.code.own_hint(int(hint.id))
	for slot in range(1, DIGITS.COUNT + 1):
		level.found_digits[slot] = (slot * 3) % 10
		level.found_by[slot] = level.player.slot
		level.found_where[slot] = "HABITACIÓN %d" % (300 + slot * 7)
	var lobby: Dictionary = level.manifest.rooms[int(level.manifest.entries[2])]
	level.player.position = Vector3(float(lobby.px), float(lobby.py) + 0.04, float(lobby.pz))
	await physics_frame
	level.floor_map.look_now()
	level.toggle_sheet()
	# The slips come up one after another: all of them up first.
	for i in 90: await process_frame
	await shot("hints_%d_sheet" % seed_value)
	level.ui.sheet.hold_up(level.code.own_hints()[1])
	await shot("hints_%d_held" % seed_value)
	quit(0)
