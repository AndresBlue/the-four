extends SceneTree
## What the 16 November 2026 changes put on a built floor, over many seeds and
## both floors (not part of verify: it builds every floor):
##   godot --headless --path . --script res://tools/dev/extras_probe.gd -- --test-profile --automation [--seeds=7,21,33]
## Coffee machines: 3 to 5, every planta with one, none in a doorway's way or
## over a wall lamp. Keys: two in every planta. On floor 2, one way sign to
## each landmark and other places' signs beside them. Prints each floor and a
## FAIL line for each thing out of place; exit 1 on any.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const LANDMARKS := preload("res://game/world/office/office_landmarks.gd")
var failed := 0

func _initialize() -> void: run.call_deferred()

func fail(what: String) -> void:
	failed += 1
	print("FAIL ", what)

func run() -> void:
	var seeds: Array = [7, 21, 33, 81, 213, 404, 1234, 5150]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="): seeds = Array(argument.trim_prefix("--seeds=").split(",")).map(func(s): return int(s))
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "none"
	for floor_number in [1, 2]:
		for seed_value in seeds:
			await level.start_floor(int(seed_value), false, [1], "apacible", floor_number)
			await physics_frame
			var tag := "piso %d semilla %d" % [floor_number, int(seed_value)]
			var plantas := {}
			for room in level.manifest.rooms:
				if not FLOOR.is_void(room): plantas[int(room.get("wing", 0))] = true
			# The coffee machines.
			var machines: Array = level.coffee.machines
			var wings := {}
			for machine in machines: wings[int(FLOOR.room_at(level.manifest.rooms, machine.global_position).get("wing", -1))] = true
			if machines.size() < 3 or machines.size() > 5: fail("%s: %d máquinas de café" % [tag, machines.size()])
			for wing in plantas:
				if not wings.has(wing): fail("%s: la planta %d sin máquina de café" % [tag, wing])
			for machine in machines:
				for door in level.hotel.doors:
					if is_instance_valid(door) and Vector2(door.global_position.x - machine.global_position.x, door.global_position.z - machine.global_position.z).length() < level.coffee.DOOR_CLEAR: fail("%s: una máquina junto a una puerta" % tag)
				for lamp: Vector3 in level.hotel.sconce_spots:
					if Vector2(lamp.x - machine.global_position.x, lamp.z - machine.global_position.z).length() < level.coffee.LAMP_CLEAR and absf(lamp.y - machine.global_position.y) < 3.0: fail("%s: una máquina sobre un aplique" % tag)
			# The keys (the hotel's: floor 2 has no code).
			var keys := {}
			for index in level.code.key_in:
				var wing := int(FLOOR.room_at(level.manifest.rooms, level.containers[index].global_position).get("wing", -1))
				keys[wing] = int(keys.get(wing, 0)) + 1
			if floor_number == 1:
				for wing in plantas:
					if int(keys.get(wing, 0)) != level.code.KEYS_A_STAGE: fail("%s: la planta %d con %d llaves" % [tag, wing, int(keys.get(wing, 0))])
			# The way signs of the offices.
			var signs := ""
			if floor_number == 2:
				var ways: Dictionary = LANDMARKS.ways(level.hotel)
				var counts := {}
				var decoys := 0
				for rows in ways.values():
					for row in rows:
						if String(row[1]).is_empty(): decoys += 1
						else: counts[String(row[1])] = int(counts.get(String(row[1]), 0)) + 1
				for kind in ["window", "electrical", "security", "machines"]:
					if int(counts.get(kind, 0)) > 1: fail("%s: %d carteles a %s" % [tag, int(counts.get(kind, 0)), kind])
				if decoys < 6: fail("%s: solo %d carteles a otros sitios" % [tag, decoys])
				signs = ", carteles %s y %d a otros sitios" % [str(counts), decoys]
			print("%s: %d máquinas en las plantas %s, llaves %s%s" % [tag, machines.size(), str(wings.keys()), str(keys), signs])
	print("EXTRAS_PROBE %d fallos" % failed)
	quit(1 if failed > 0 else 0)
