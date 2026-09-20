extends SceneTree
## What the floors actually come out like, in numbers: how much of a wing is
## corridor, how many rings it has, how far the refuge is, how many dead ends,
## how the order field falls -- and whether walking with one hand on the wall
## finds the refuge, which is the thing the layout is meant to defeat.
##
## Run it before and after touching the generator:
##   godot --headless --script tools/dev/map_metrics.gd
## A number of floors can be asked for with `-- 200`.
const GEN := preload("res://game/world/generation/map_generator.gd")
const VALIDATOR := preload("res://game/world/generation/map_validator.gd")
const WALKER := preload("res://game/world/generation/wall_walker.gd")

func _initialize() -> void:
	var floors := 200
	for argument in OS.get_cmdline_user_args():
		if argument.is_valid_int(): floors = argument.to_int()
	var generator := GEN.new()
	var failures: Array = []
	var fallbacks := 0
	var elapsed := Time.get_ticks_msec()
	# Everything is gathered per wing, because that is the shape of the run.
	var corridor := [0.0, 0.0, 0.0]
	var service := [0.0, 0.0, 0.0]
	var rings := [0.0, 0.0, 0.0]
	var dead_ends := [0.0, 0.0, 0.0]
	var doors := [0.0, 0.0, 0.0]
	var between_rooms := [0.0, 0.0, 0.0]
	var to_refuge := [0.0, 0.0, 0.0]
	var tidy := [0.0, 0.0, 0.0]
	var unruly := [0.0, 0.0, 0.0]
	var order_mean := [0.0, 0.0, 0.0]
	var refuge_doors := [0.0, 0.0, 0.0]
	var joined := [0.0, 0.0, 0.0]
	var middling := [0.0, 0.0, 0.0]
	var walker_found := [0, 0, 0]
	var walker_seen := [0.0, 0.0, 0.0]
	for seed_value in floors:
		var data := generator.generate(seed_value)
		if data.fallback: fallbacks += 1
		var errors := VALIDATOR.new().validate(data)
		if not errors.is_empty(): failures.append([seed_value, errors])
		var entrance: int = int(data.start)
		for wing in 3:
			var band: Array = data.rooms.filter(func(room): return int(room.wing) == wing)
			var inside := 0
			for room in band:
				if bool(room.corridor): corridor[wing] += 1.0 / float(band.size()) * 100.0 / float(floors)
				if bool(room.service): service[wing] += 1.0 / float(band.size()) * 100.0 / float(floors)
				if float(room.order) > 0.7: tidy[wing] += 1.0 / float(band.size()) * 100.0 / float(floors)
				elif float(room.order) < 0.4: unruly[wing] += 1.0 / float(band.size()) * 100.0 / float(floors)
				else: middling[wing] += 1.0 / float(band.size()) * 100.0 / float(floors)
				order_mean[wing] += float(room.order) / float(band.size()) / float(floors)
				var degree := 0
				for n in data.adjacency[int(room.id)]:
					if int(data.rooms[n].wing) == wing: degree += 1
				if degree == 1: dead_ends[wing] += 1.0 / float(floors)
				inside += degree
			doors[wing] += float(inside) / 2.0 / float(floors)
			var walls := 0
			var pairs := 0
			for edge in data.edges:
				var a: Dictionary = data.rooms[int(edge[0])]
				var b: Dictionary = data.rooms[int(edge[1])]
				if int(a.wing) != wing or int(b.wing) != wing: continue
				pairs += 1
				if not bool(a.corridor) and not bool(b.corridor): walls += 1
			between_rooms[wing] += float(walls) / float(floors)
			# Out of every wall two rooms share, how many have a door in them:
			# that is what tells a tidy stretch from a tangled one, and the
			# bare count does not, because wings differ in size.
			var shared := 0
			for room in band:
				for step in [1, int(data.width)]:
					var next: int = int(room.id) + step
					if next >= data.rooms.size() or int(data.rooms[next].wing) != wing: continue
					if step == 1 and int(data.rooms[next].z) != int(room.z): continue
					if bool(room.corridor) or bool(data.rooms[next].corridor): continue
					shared += 1
			if shared > 0: joined[wing] += float(walls) / float(shared) * 100.0 / float(floors)
			rings[wing] += float(pairs - band.size() + 1) / float(floors)
			var refuge: int = int(data.refuges[wing])
			var reach := GEN.distance_map(data.adjacency, entrance)
			to_refuge[wing] += float(maxi(0, reach[refuge])) / float(floors)
			var ways := 0
			for n in data.adjacency[refuge]:
				if int(data.rooms[n].wing) == wing: ways += 1
			refuge_doors[wing] += float(ways) / float(floors)
			# One hand on the wall, from the way into the wing: both hands and
			# all four ways of setting off, because a player picks one.
			var walk: Dictionary = WALKER.follow(data, entrance, refuge)
			if WALKER.reaches(data.rooms, data.adjacency, int(data.width), int(data.height), entrance, refuge): walker_found[wing] += 1
			walker_seen[wing] += float(walk.rooms) / float(band.size()) * 100.0 / float(floors)
			if wing < data.gates.size() and int(data.gates[wing].get("beyond", -1)) >= 0: entrance = int(data.gates[wing].beyond)
	print("%d pisos en %.1f s, respaldo %d, invalidos %d" % [floors, float(Time.get_ticks_msec() - elapsed) / 1000.0, fallbacks, failures.size()])
	for failure in failures.slice(0, 5): print("  semilla ", failure[0], " ", failure[1])
	print("ala | pasillo | servicio | orden | ordenado | medio | revuelto | puertas | entre salas | de las que se pueden | anillos | sin salida | al refugio | puertas refugio | mano en la pared | visto")
	for wing in 3:
		print("  %d | %5.1f%% | %5.1f%% | %.2f | %5.1f%% | %5.1f%% | %5.1f%% | %5.1f | %5.1f | %5.1f%% | %4.1f | %4.1f | %5.1f | %.2f | %3d/%d | %4.1f%%" % [wing + 1, corridor[wing], service[wing], order_mean[wing], tidy[wing], middling[wing], unruly[wing], doors[wing], between_rooms[wing], joined[wing], rings[wing], dead_ends[wing], to_refuge[wing], refuge_doors[wing], walker_found[wing], floors, walker_seen[wing]])
	quit()
