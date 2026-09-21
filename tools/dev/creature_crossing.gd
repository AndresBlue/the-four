extends SceneTree
## How long the creature takes to cross a wing on its own feet: the survivors
## take the lift, the floor tells it where the car is, and from there it walks
## there, waits for the car to come back down and rides it. Nothing is moved
## by hand here -- this measures the thing as it is played.
##
##   godot --headless --path . --rendering-method forward_plus --fixed-fps 60 \
##       --script tools/dev/creature_crossing.gd -- --seeds=81,213,404
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame

## Where the creature stands, by wing.
func creature_wing() -> int:
	return int(FLOOR.room_at(level.manifest.rooms, level.locust.global_position).get("wing", -1))

func run() -> void:
	var seeds: Array = [81]
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seeds="): seeds = Array(argument.trim_prefix("--seeds=").split(",")).map(func(text): return int(text))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for run_seed in seeds:
		await level.start_floor(int(run_seed))
		var session = level.session
		# The survivors are out of it: this is about the creature and the car.
		level.player.set_physics_process(false)
		level.locust.grace = 0.0
		var start_wing := creature_wing()
		var far: float = level.locust.global_position.distance_to(level.hotel.lifts[0])
		# Closing the first stage the way a player does: into the car.
		session.goal["ready"] = true
		session.changed.emit()
		await frames(4)
		level.player.global_position = level.hotel.lifts[0] + Vector3(0, 0.04, 0)
		await frames(140)
		if session.stage != 2:
			print("SEED ", run_seed, " no cerró la etapa")
			continue
		# The player is put out of reach, so nothing it does distracts it.
		level.player.global_position = Vector3(0, -200, 0)
		var crossed := -1.0
		var boarded := -1.0
		var trace: bool = OS.get_cmdline_user_args().has("--trace")
		for i in 9000:
			await physics_frame
			var seconds := float(i) / 60.0
			# --trace: where it is every five seconds, and whether it is moving.
			# One standing still with a route in front of it is jammed against
			# something solid, which is how the door leaves were found.
			if trace and i % 300 == 0:
				print("   %5.1f s · modo %d · ala %d · a %.1f m del coche · destino a %.1f m · velocidad %.2f · %s" % [
					seconds, level.locust.mode, creature_wing(),
					level.locust.global_position.distance_to(level.hotel.lifts[0]),
					level.locust.destination.distance_to(level.hotel.lifts[0]),
					level.locust.velocity.length(),
					("coche arriba %.1f s" % float(level.lift_away.get(0, 0.0))) if level.lift_gone(0) else "coche abajo"])
			if boarded < 0.0 and level.locust.global_position.distance_to(level.hotel.lifts[0]) < 2.0: boarded = seconds
			if creature_wing() == 1:
				crossed = seconds
				break
		print("SEED %d · empezó en el ala %d a %.1f m del coche · llegó al coche %s · cruzó %s" % [
			run_seed, start_wing, far,
			("a los %.1f s" % boarded) if boarded >= 0.0 else "nunca",
			("a los %.1f s" % crossed) if crossed >= 0.0 else "NUNCA (150 s)"])
	quit()
