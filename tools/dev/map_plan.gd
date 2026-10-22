extends SceneTree
## The floor drawn as a plan, in text, a planta at a time, to look at a seed
## without loading it:
##   godot --headless --script tools/dev/map_plan.gd -- 81
## Cells: # corridor, S service, . room, h salon, @ reception, A the lobby the
## lift arrives at, R refuge, L the lift lobby behind it, blank a cell the
## planta does not use. A dash or a pipe between two cells is a door, an
## equals sign no wall at all (a corridor running on, a salon), a gap a wall.
const GEN := preload("res://game/world/generation/map_generator.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const WALKER := preload("res://game/world/generation/wall_walker.gd")

func _initialize() -> void:
	var seed_value := 81
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int(): seed_value = argument.to_int()
	var data := GEN.new().generate(seed_value)
	var open := {}
	for pair in data.merged: open[Vector2i(int(pair[0]), int(pair[1]))] = true
	print("semilla ", seed_value, "  recorrido ", int(data.walk), " salas  respaldo ", data.fallback)
	for planta in 3:
		var plan: Dictionary = data.plans[planta]
		var width := int(data.plantas[planta].width)
		var height := int(data.plantas[planta].height)
		var base := int(data.plantas[planta].base)
		print("")
		print("planta ", planta + 1, ": ", plan.plan, ", ", plan.shape, ", ", int(plan.rooms), " habitaciones, rejilla ", width, "x", height)
		for z in height:
			var line := ""
			var below := ""
			for x in width:
				var id: int = base + z * width + x
				line += mark(data, id)
				if x < width - 1: line += door_mark(data, open, id, id + 1, "-")
				if z < height - 1: below += door_mark(data, open, id, id + width, "|") + " "
			print(line)
			if z < height - 1: print(below)
		var refuge: int = int(data.refuges[planta])
		var found: int = WALKER.hits(data.rooms, data.adjacency, int(data.entries[planta]), refuge)
		var doors: Array = data.adjacency[refuge].filter(func(id): return not bool(data.rooms[id].get("landing", false)))
		print("refugio ", refuge, " con ", doors.size(), " puerta(s); la mano en la pared lo encuentra ", found, "/8 veces")
	quit()

static func mark(data: Dictionary, id: int) -> String:
	var room: Dictionary = data.rooms[id]
	if FLOOR.is_void(room): return " "
	if data.refuges.has(id): return "R"
	if bool(room.get("landing", false)): return "L"
	if id == int(data.start): return "@"
	if data.entries.has(id): return "A"
	if bool(room.corridor): return "#"
	if bool(room.service): return "S"
	if int(room.hall) >= 0: return "h"
	return "."

## A door between two cells, an equals sign where there is no wall at all, and
## a space where there is a wall.
static func door_mark(data: Dictionary, open: Dictionary, one: int, two: int, line: String) -> String:
	if not data.adjacency[one].has(two): return " "
	return "=" if open.has(Vector2i(mini(one, two), maxi(one, two))) else line
