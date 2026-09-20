extends SceneTree
## The floor drawn as a plan, in text, to look at a seed without loading it:
##   godot --headless --script tools/dev/map_plan.gd -- 81
## Cells: # corridor, S service, . room, @ reception, R refuge, L the landing
## behind the last door. A dash or a pipe between two cells is a door; a gap
## is a wall. The wings are told apart by the columns they take up.
const GEN := preload("res://game/world/generation/map_generator.gd")
const WALKER := preload("res://game/world/generation/wall_walker.gd")

func _initialize() -> void:
	var seed_value := 81
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int(): seed_value = argument.to_int()
	var data := GEN.new().generate(seed_value)
	var width := int(data.width)
	var height := int(data.height)
	print("semilla ", seed_value, "  ", width, "x", height, " salas ", data.rooms.size(), "  recorrido ", int(data.walk), " salas  respaldo ", data.fallback)
	for z in height:
		var line := ""
		var below := ""
		for x in width:
			var id: int = z * width + x
			var room: Dictionary = data.rooms[id]
			var mark := "."
			if bool(room.corridor): mark = "#"
			if bool(room.service): mark = "S"
			if int(room.id) == 0: mark = "@"
			if bool(room.get("landing", false)): mark = "L"
			if data.refuges.has(int(room.id)): mark = "R"
			line += mark
			if x < width - 1: line += door_mark(data, id, id + 1, "-")
			if z < height - 1: below += door_mark(data, id, id + width, "|") + " "
		print(line)
		if z < height - 1: print(below)
	var entrance: int = int(data.start)
	for wing in 3:
		var refuge: int = int(data.refuges[wing])
		var found: int = WALKER.hits(data.rooms, data.adjacency, width, height, entrance, refuge)
		var doors: Array = data.adjacency[refuge].filter(func(id): return int(data.rooms[id].wing) == wing and not bool(data.rooms[id].get("landing", false)))
		print("ala ", wing + 1, ": refugio ", refuge, " con ", doors.size(), " puerta(s), la mano en la pared lo encuentra ", found, "/8 veces")
		if wing < data.gates.size() and int(data.gates[wing].get("beyond", -1)) >= 0 and int(data.rooms[int(data.gates[wing].beyond)].wing) != wing: entrance = int(data.gates[wing].beyond)
	quit()

## A door between two cells, an equals sign where the wall came down because
## they are one room, and a space where there is a wall.
static func door_mark(data: Dictionary, one: int, two: int, line: String) -> String:
	if not data.adjacency[one].has(two): return " "
	return "=" if data.get("merged", []).has([mini(one, two), maxi(one, two)]) else line
