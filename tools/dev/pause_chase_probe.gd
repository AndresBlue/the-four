extends SceneTree
## Pausing in the middle of a chase: is the creature still after its quarry
## when the game goes on? The same chase twice on each difficulty -- once
## straight through, once with the pause menu up for three seconds half a
## second into the run -- and what the creature was doing, tick by tick of
## its own time, in both. They are to be the same.
##
##   godot --headless --script res://tools/dev/pause_chase_probe.gd -- --test-profile --automation [--seed=81]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const DIFFICULTY := preload("res://game/floors/difficulty.gd")
var level
var failed := 0

func _initialize() -> void: run.call_deferred()

func biggest_room() -> Dictionary:
	var best := {}
	var best_area := 0.0
	for room in level.manifest.rooms:
		if int(room.get("wing", 0)) != 0 or FLOOR.is_void(room) or level.point_protected(FLOOR.position_of(room)): continue
		var span: Vector2 = FLOOR.size_of(room)
		if span.x * span.y > best_area:
			best_area = span.x * span.y
			best = room
	return best

## The survivor at one end of the biggest room, the creature at the other,
## and the chase begun.
func stage() -> void:
	var room := biggest_room()
	var centre: Vector3 = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	var span: Vector2 = FLOOR.size_of(room)
	var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
	var apart := maxf(span.x, span.y) - 4.4
	var player = level.player
	player.reset_survival()
	player.global_position = centre - along * apart * 0.5
	player.velocity = Vector3.ZERO
	player.rotation.y = atan2(-along.x, -along.z)
	player.active = true
	player.held = false
	level.session.participants[player.slot] = level.session.Life.EXPLORING
	var creature = level.locust
	creature.global_position = centre + along * apart * 0.5
	creature.rotation.y = atan2(along.x, along.z)
	creature.velocity = Vector3.ZERO
	creature.grace = 0.0
	if is_instance_valid(level.director):
		level.director.queue_free()
		level.director = null
	creature.focus = player
	creature.last_known = player.global_position
	creature.detection = 1.2
	creature.lost_time = 0.0
	creature.set_mode(creature.Mode.ALERT)

## The chase for `seconds` of the creature's own time, with the pause menu up
## for `paused` seconds after the first `before` of them: what mode it was in
## and how far from its quarry, every tenth of a second of its time.
func chase(difficulty: String, seconds: float, before: float, paused: float) -> Array:
	await level.start_floor(81, false, [1], difficulty)
	stage()
	var creature = level.locust
	var trace: Array = []
	var began: float = creature.clock
	var held := false
	var guard := 0
	while creature.clock - began < seconds and guard < 4000:
		guard += 1
		await physics_frame
		if not held and paused > 0.0 and creature.clock - began >= before:
			held = true
			level.session.pause()
			var stood: float = creature.clock
			for i in int(paused * 60.0): await physics_frame
			if not is_equal_approx(stood, creature.clock):
				failed += 1
				print("FAIL ", difficulty, ": the creature's clock ran under the pause (", stood, " -> ", creature.clock, ")")
			level.session.set_state(level.session.State.PLAYING)
		if int((creature.clock - began) * 60.0 + 0.5) % 6 == 0:
			trace.append([snappedf(creature.clock - began, 0.1), creature.mode, snappedf(creature.global_position.distance_to(level.player.global_position), 0.05), level.execution.is_empty()])
	return trace

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	for difficulty in DIFFICULTY.ORDER:
		var straight: Array = await chase(difficulty, 5.0, 0.0, 0.0)
		# The pause comes half a second into the run itself, past the cry.
		var broken: Array = await chase(difficulty, 5.0, float(DIFFICULTY.PROFILES[difficulty].alert_time) + 0.5, 3.0)
		var same := straight.size() == broken.size()
		var first := -1
		for i in mini(straight.size(), broken.size()):
			if straight[i][1] != broken[i][1] or absf(float(straight[i][2]) - float(broken[i][2])) > 0.3 or straight[i][3] != broken[i][3]:
				same = false
				if first < 0: first = i
		if not same: failed += 1
		print("PASS " if same else "FAIL ", difficulty, ": the chase with a pause in it is the chase without", "" if same else " -- differs from %s: straight %s, paused %s" % [first, straight[maxi(first, 0)], broken[maxi(first, 0)] if first < broken.size() else "nothing"])
		print("  straight ", straight.filter(func(row): return int(float(row[0]) * 10.0 + 0.5) % 5 == 0))
		print("  paused   ", broken.filter(func(row): return int(float(row[0]) * 10.0 + 0.5) % 5 == 0))
	print("PAUSE_CHASE failed=", failed)
	quit(1 if failed > 0 else 0)
