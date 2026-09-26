extends SceneTree
const GEN := preload("res://game/world/generation/map_generator.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SIGNS := preload("res://game/world/generation/exit_route_signs.gd")
## The corridors' way-out signs (game/world/generation/exit_route_signs.gd)
## over fifty floors: how many each planta gets, and every arrow checked to be
## a real way on towards its refuge (one more than a cell's length of walking
## the other way is reported: the signs keep to the corridors, and a room cut
## through can be shorter).
##   godot --headless --path . --script res://tools/dev/exit_signs_probe.gd
func _initialize() -> void:
	var counts := {}
	var bad := 0
	var total := 0
	for s in range(81, 131):
		var m: Dictionary = GEN.new().generate(s)
		for planta in 3:
			var signs: Array = SIGNS.planta_signs(m, planta)
			counts[signs.size()] = int(counts.get(signs.size(), 0)) + 1
			var metres := FLOOR.route_metres(m, int(m.refuges[planta]))
			for sign in signs:
				total += 1
				var here: int = int(sign.room)
				var ahead: int = FLOOR.beside(m.rooms[here], sign.way)
				# the way must be an open connection and lead nearer the refuge
				if ahead < 0 or not m.adjacency[here].has(ahead) or float(metres.get(ahead, INF)) >= float(metres.get(here, INF)) + 12.5:
					bad += 1
					print("seed %d planta %d sala %d: %s · vecino %d · adyacente %s · %.0f m -> %.0f m" % [s, planta, here, sign.way, ahead, ahead >= 0 and m.adjacency[here].has(ahead), float(metres.get(here, INF)), float(metres.get(ahead, INF))])
	print("reparto ", counts, " · flechas malas ", bad, " de ", total)
	quit()
