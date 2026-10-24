extends SceneTree
## How far the body of whoever is caught goes into the walls, the ceiling and
## the furniture during a capture (docs/EXECUTION.md, 8.6): the scene staged
## against a wall, in a corner, along a wall and in the open, caught from the
## front, from behind and from a side, and in a wardrobe; and at every frame
## of each, every joint of the body looked for on the wrong side of something.
##
##   godot --headless --fixed-fps 60 --script res://tools/dev/body_clip_probe.gd -- --test-profile [--character=2] [--strict] [--only=corner] [--trace]
##
## A joint is through something when the ray to it from the joint it hangs
## from (the hips, from where the creature stands) is stopped short of it, by
## as much as is left of the way plus the joint's own thickness; and it grazes
## something that is nearer its middle than it is thick. Prints the deepest of
## each scene, joint by joint, and with --strict fails over LIMIT.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SCORE := preload("res://game/app/capture_score.gd")
## What a body may not be in: walls and furniture, and doors shut.
const SOLID := 1 | 8
## Deeper than this, anywhere, is a fault (metres).
const LIMIT := 0.04
## The joints: [key, the one it hangs from, half its thickness].
const JOINTS := [
	["hip", "", 0.13], ["chest", "hip", 0.14], ["head", "chest", 0.11],
	["la", "chest", 0.06], ["le", "la", 0.05], ["lh", "le", 0.06],
	["ra", "chest", 0.06], ["re", "ra", 0.05], ["rh", "re", 0.06],
	["lk", "hip", 0.07], ["lf", "lk", 0.05], ["lo", "lf", 0.04],
	["rk", "hip", 0.07], ["rf", "rk", 0.05], ["ro", "rf", 0.04],
]
var level
var options := {}
var worst_of_all := 0.0
var faults := 0

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame

func staging_room() -> Dictionary:
	var best := {}
	var best_area := 0.0
	for room in level.manifest.rooms:
		if int(room.get("wing", 0)) != 0 or FLOOR.is_void(room) or level.point_protected(FLOOR.position_of(room)): continue
		var span: Vector2 = FLOOR.size_of(room)
		if span.x * span.y > best_area:
			best_area = span.x * span.y
			best = room
	return best

func put(at: Vector3, looking: Vector3, creature_at: Vector3) -> void:
	var player = level.player
	if not level.execution.is_empty(): level.release_execution()
	player.reset_survival()
	player.global_position = at
	player.velocity = Vector3.ZERO
	player.rotation.y = atan2(-looking.x, -looking.z)
	player.camera.rotation = Vector3.ZERO
	player.active = true
	player.held = false
	player.torch.visible = false
	level.session.participants[player.slot] = level.session.Life.EXPLORING
	var creature = level.locust
	creature.set_physics_process(false)
	creature.global_position = creature_at
	var to_them := at - creature_at
	creature.rotation.y = atan2(-to_them.x, -to_them.z)
	creature.velocity = Vector3.ZERO
	creature.grace = 0.0
	creature.detection = 0.0
	creature.focus = null
	creature.observed_hide = null
	creature.pouncing = false
	creature.set_mode(creature.Mode.PATROL)
	creature.destination = creature.global_position
	level.clear_screen_cues()

## The first thing between two points, as how far along it is; INF: nothing.
func stopped(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array) -> float:
	if from.distance_to(to) < 0.001: return INF
	var query := PhysicsRayQueryParameters3D.create(from, to, SOLID)
	query.exclude = exclude
	query.hit_from_inside = true
	var hit := space.intersect_ray(query)
	if not hit.is_empty() and options.has("what"): print("    hit ", (hit.collider as Node).get_path(), " at ", hit.position, " from ", from, " to ", to)
	return from.distance_to(hit.position) if not hit.is_empty() else INF

## How far each joint is into something at this instant: {key: metres}.
func measure() -> Dictionary:
	var player = level.player
	var avatar = player.avatar
	var said := {}
	if avatar.rig == null: return said
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var exclude: Array = [player.get_rid(), level.locust.get_rid()]
	var rig: Skeleton3D = avatar.rig
	var at := {"": level.locust.global_position + Vector3.UP * 1.1}
	for joint in JOINTS:
		var bone: int = avatar.bones.get(joint[0], -1)
		if bone < 0: continue
		at[joint[0]] = rig.global_transform * rig.get_bone_global_pose(bone).origin
	# The top of the head is not a joint, and it is what meets a lintel.
	var head: int = avatar.bones.get("head", -1)
	if head >= 0:
		at["top"] = at["head"] + ((at["head"] as Vector3) - (at["chest"] as Vector3)).normalized() * 0.17
	var joints: Array = JOINTS.duplicate()
	if at.has("top"): joints.append(["top", "head", 0.07])
	for joint in joints:
		if not at.has(joint[0]) or not at.has(joint[1]): continue
		var point: Vector3 = at[joint[0]]
		var from: Vector3 = at[joint[1]]
		var thick := float(joint[2])
		var depth := 0.0
		var reach := stopped(space, from, point, exclude)
		if reach != INF: depth = from.distance_to(point) - reach + thick
		else:
			# Not through anything: how near its middle the nearest thing is,
			# to every side and above (below it is the floor it lies on).
			for way in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK, Vector3.UP, Vector3(0.7, 0, 0.7), Vector3(-0.7, 0, 0.7), Vector3(0.7, 0, -0.7), Vector3(-0.7, 0, -0.7)]:
				var near := stopped(space, point, point + (way as Vector3).normalized() * thick, exclude)
				if near != INF: depth = maxf(depth, thick - near)
			# And under the floor.
			var floor_y: float = level.locust.global_position.y - 0.04
			if point.y - thick * 0.5 < floor_y - 0.02: depth = maxf(depth, floor_y - (point.y - thick * 0.5))
		if depth > 0.0: said[joint[0]] = depth
		if depth > 0.3 and options.has("why"): print("    ", joint[0], " depth=", snappedf(depth, 0.01), " at ", point, " from ", from, " reach=", reach, " creature=", level.locust.global_position, " body=", player.global_position, " t=", level.execution.get("time", -1.0))
	return said

## One capture watched to the body lying still: the deepest each joint went,
## and when. {key: [metres, second]}.
func watch(title: String) -> void:
	var player = level.player
	if level.execution.is_empty():
		print("CLIP %-34s NOT CAUGHT" % title)
		faults += 1
		return
	var worst := {}
	var guard := 0
	var beat = level.executions.score()
	var until: float = beat.DROP_TIME + beat.FALL_LENGTH + 0.35
	while not level.execution.is_empty() and guard < 700 and float(level.execution.time) < until:
		await process_frame
		guard += 1
		if level.execution.is_empty(): break
		var time := float(level.execution.time)
		# The scene has not posed it yet: it is as the last one left it.
		if time <= 0.0: continue
		var now := measure()
		for key in now:
			if not worst.has(key) or float(now[key]) > float(worst[key][0]): worst[key] = [float(now[key]), time]
		if options.has("trace") and guard % 12 == 0: print("  t=%.2f %s" % [time, str(now)])
	if options.has("pose") and not level.execution.is_empty():
		# Where each joint ended up, over the floor and from the hips.
		var avatar = player.avatar
		var hips: Vector3 = avatar.bone_point(avatar.bones.hip)
		for joint in JOINTS:
			var bone: int = avatar.bones.get(joint[0], -1)
			if bone < 0: continue
			var point: Vector3 = avatar.bone_point(bone)
			print("  %-5s up=%.2f  off=(%.2f, %.2f)" % [joint[0], point.y - level.locust.global_position.y + 0.04, point.x - hips.x, point.z - hips.z])
	var deepest := 0.0
	var parts: Array = []
	for key in worst:
		deepest = maxf(deepest, float(worst[key][0]))
		if float(worst[key][0]) > LIMIT: parts.append("%s %.2f@%.1f" % [key, float(worst[key][0]), float(worst[key][1])])
	worst_of_all = maxf(worst_of_all, deepest)
	if deepest > LIMIT: faults += 1
	var how := "slump" if bool(level.execution.get("slump", false)) else ("straight" if bool(level.execution.get("straight", false)) else "laid")
	print("CLIP %-34s %s %-8s room=%.2f worst=%.2f  %s" % [title, "ok  " if deepest <= LIMIT else "FAIL", how, float(level.execution.get("room", 0.0)), deepest, " ".join(parts)])
	level.release_execution()
	await frames(3)

func stage(title: String, at: Vector3, looking: Vector3, creature_at: Vector3, entry: String, side := 0.0) -> void:
	if options.has("only") and not title.contains(String(options.only)): return
	put(at, looking, creature_at)
	await frames(2)
	var forced := {"entry": entry, "glance": false}
	if side != 0.0: forced["side"] = side
	level.executions.forced = forced
	level.capture_survivor(level.player)
	await watch(title)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair := argument.trim_prefix("--").split("=")
			options[pair[0]] = pair[1]
		elif argument.begins_with("--"): options[argument.trim_prefix("--")] = true
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(int(options.get("seed", 81)), false, [1], "apacible")
	level.ui.hide_transit()
	level.lifts.brief_wait = 0.0
	level.settings.values.character = int(options.get("character", 2))
	level.apply_settings()
	if is_instance_valid(level.director):
		level.director.queue_free()
		level.director = null
	level.locust.set_physics_process(false)
	level.locust.grace = 0.0
	await frames(5)
	var room := staging_room()
	var centre: Vector3 = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	var span: Vector2 = FLOOR.size_of(room)
	var along := Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)
	var across := along.cross(Vector3.UP)
	var half := maxf(span.x, span.y) * 0.5
	var half_across := minf(span.x, span.y) * 0.5
	for entry in ["front", "back", "side"]:
		await stage("open, %s" % entry, centre, along if entry != "back" else -along, centre + along * 1.5, entry)
		for gap in [0.4, 0.7, 1.2]:
			# Their back to the end wall, the creature between them and the room.
			var at_wall: Vector3 = centre - along * (half - float(gap))
			await stage("back to wall %.1f, %s" % [gap, entry], at_wall, along if entry != "back" else -along, at_wall + along * 1.5, entry)
			# The creature's back to that wall, they between it and the room.
			var it_at: Vector3 = centre - along * (half - 0.7)
			await stage("it against wall, %s, %.1f apart" % [entry, 0.6 + float(gap)], it_at + along * (0.6 + float(gap)), -along if entry != "back" else along, it_at, entry)
			# Along a side wall, that near it: on the side it would fall to and the other.
			for hand in [1.0, -1.0]:
				var by: Vector3 = centre + across * (half_across - float(gap)) * hand
				await stage("along wall %.1f %s, %s" % [gap, "R" if hand > 0.0 else "L", entry], by, along if entry != "back" else -along, by + along * 1.5, entry)
			# In a corner, the creature coming along the diagonal.
			var corner: Vector3 = centre - along * (half - float(gap)) + across * (half_across - float(gap))
			var out := (along - across).normalized()
			await stage("corner %.1f, %s" % [gap, entry], corner, out if entry != "back" else -out, corner + out * 1.5, entry)
	# In doorways: under the lintel, the creature a step and a half into each room.
	var tried := 0
	for door in level.hotel.doors_near(centre, 40.0):
		if tried >= 3 or level.point_protected(door.doorway): continue
		tried += 1
		var through: Vector3 = door.along().cross(Vector3.UP).normalized() if door.has_method("along") else Vector3.FORWARD
		var spot := Vector3(door.doorway.x, centre.y, door.doorway.z)
		await stage("doorway %d, front" % tried, spot, through, spot + through * 1.5, "front")
		await stage("doorway %d, back" % tried, spot, -through, spot + through * 1.5, "back")
	# In a wardrobe, the two kinds.
	for big in [false, true]:
		var hide: Node3D = null
		for other in level.hotel.hides:
			if level.point_protected(other.global_position) or bool(other.big) != big: continue
			if hide == null or other.global_position.distance_to(centre) < hide.global_position.distance_to(centre): hide = other
		var title := "wardrobe%s" % (" (big)" if big else "")
		if hide == null or (options.has("only") and not title.contains(String(options.only))): continue
		put(hide.to_global(hide.exit_offset), -hide.global_basis.z, hide.to_global(hide.exit_offset + Vector3(0, 0, 0.05)))
		await frames(2)
		level.player.enter_hide(hide)
		await frames(90)
		level.locust.global_position = hide.to_global(hide.exit_offset)
		level.locust.rotation.y = hide.global_rotation.y
		level.executions.forced = {"glance": false}
		hide.force_open(0.1)
		await frames(12)
		level.capture_survivor(level.player)
		await watch(title)
	print("CLIP_RESULT worst=%.2f faults=%d" % [worst_of_all, faults])
	level.queue_free()
	await process_frame
	quit(1 if options.has("strict") and faults > 0 else 0)
