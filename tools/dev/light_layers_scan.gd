extends SceneTree
## Whether sixteen render layers are enough to keep every lamp of a floor in
## its own room on the lowest graphics preset (game/world/hotel/room_layers.gd),
## over many seeds. Only the manifests: nothing is built.
##
##   godot --headless --script tools/dev/light_layers_scan.gd -- 200
##   ... -- 20 --floor=2   (the offices: their generator is slower, about 2.5 s a floor)
## Prints, per seed with anything to say and in all: clashes (a lamp that
## reaches another room on its own layer: a leak, and the reason this exits
## with 1), seams (a lamp that cannot light an open neighbour: only a darker
## edge), the most layers a floor used and how long the colouring took.
const GEN := preload("res://game/world/generation/map_generator.gd")
const LAYERS := preload("res://game/world/hotel/room_layers.gd")
## The offices' generator, for --floor=2 (game/floors/office_floor.gd GENERATOR).
const OFFICE_GEN := preload("res://game/world/generation/office_generator.gd")

func _initialize() -> void:
	var count := 100
	var floor_number := 1
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int(): count = int(argument)
		if argument.begins_with("--floor=") and argument.trim_prefix("--floor=").is_valid_int(): floor_number = int(argument.trim_prefix("--floor="))
	var generator: Object = OFFICE_GEN.new() if floor_number == 2 else GEN.new()
	var clashes := 0
	var seams := 0
	var most := 0
	var slowest := 0
	for seed_value in range(1, count + 1):
		var data: Dictionary = generator.generate(seed_value)
		var started := Time.get_ticks_msec()
		var result := LAYERS.assign(data)
		slowest = maxi(slowest, Time.get_ticks_msec() - started)
		var used := {}
		for bit in result.layer:
			if bit != 0: used[bit] = true
		for room in result.cars: used[result.cars[room]] = true
		most = maxi(most, used.size())
		clashes += int(result.clashes)
		seams += int(result.seams)
		if int(result.clashes) > 0 or int(result.seams) > 0: print("seed %d: %d clashes, %d seams, %d layers" % [seed_value, result.clashes, result.seams, used.size()])
	var head: String = "LIGHT_LAYERS floor=2" if floor_number == 2 else "LIGHT_LAYERS"
	print("%s seeds=%d clashes=%d seams=%d most_layers=%d slowest_ms=%d" % [head, count, clashes, seams, most, slowest])
	quit(1 if clashes > 0 else 0)
