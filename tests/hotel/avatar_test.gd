extends SceneTree
## What the survivors' animation has to do, measured on the skeleton instead
## of judged by eye: feet that stay where they are planted, knees that bend,
## arms that swing, a crouch that really goes down and puts a hand out, and
## legs that let go of the ground in the air. The look itself is checked with
## tools/capture/avatar_gait_capture.gd.
const AVATAR := preload("res://game/player/avatars/avatar_visual.gd")
var checks: Array = []
var failed := 0
var body: Node3D
var avatar

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title)

## Where a bone of the map is, in the world.
func bone_at(key: String) -> Vector3:
	var id: int = avatar.bones.get(key, -1)
	if id < 0 or avatar.rig == null: return Vector3.INF
	return avatar.rig.global_transform * avatar.rig.get_bone_global_pose(id).origin

## Walks the body for so many frames and returns what was sampled each one.
func walk(speed: float, seconds: float, crouching := false, grounded := true, keys := ["lf"]) -> Array:
	var samples: Array = []
	var frames := int(seconds * 60.0)
	for i in frames:
		var delta := 1.0 / 60.0
		body.position.x += speed * delta
		avatar.update_pose(Vector3(speed, 0, 0), crouching, delta, grounded)
		await process_frame
		var row := {}
		for key in keys: row[key] = bone_at(key)
		row["at"] = body.position.x
		samples.append(row)
	return samples

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	body = Node3D.new()
	world.add_child(body)
	# The rig walks along +X, so the body faces that way: forward is -Z.
	body.rotation.y = -PI / 2
	for character in [1, 2]:
		avatar = AVATAR.new()
		avatar.character = character
		avatar.first_person = false
		body.add_child(avatar)
		await process_frame
		var name: String = AVATAR.NAMES[character]
		check("%s: el esqueleto y sus huesos están" % name, avatar.rig != null and avatar.bones.get("hip", -1) >= 0 and avatar.bones.get("lf", -1) >= 0 and avatar.bones.get("rh", -1) >= 0)
		# --- Walking ---------------------------------------------------------------
		var standing_hip := bone_at("hip").y
		var samples: Array = await walk(3.4, 2.0, false, true, ["lf", "rf", "lk", "lt", "rh", "hip"])
		# A planted foot does not slide: between one step and the next its world
		# position holds still while the body moves on.
		var still := 0
		var slid := 0.0
		for i in range(20, samples.size()):
			var moved: float = samples[i].lf.distance_to(samples[i - 1].lf)
			var body_moved: float = samples[i].at - samples[i - 1].at
			if moved < body_moved * 0.25:
				still += 1
				slid = maxf(slid, moved)
		check("%s: el pie plantado no patina" % name, still > samples.size() / 4 and slid < 0.02)
		# The knee bends over a stride instead of the leg being a stilt.
		var bend_min := PI
		var bend_max := 0.0
		for row in samples.slice(20):
			var thigh: Vector3 = (row.lk - row.lt).normalized()
			var calf: Vector3 = (row.lf - row.lk).normalized()
			var angle: float = thigh.angle_to(calf)
			bend_min = minf(bend_min, angle)
			bend_max = maxf(bend_max, angle)
		check("%s: la rodilla se dobla al caminar" % name, bend_max - bend_min > 0.3 and bend_max > 0.35)
		# The arms swing: the hand travels back and forth against the body.
		var hand_min := INF
		var hand_max := -INF
		for row in samples.slice(20):
			var ahead: float = row.rh.x - row.hip.x
			hand_min = minf(hand_min, ahead)
			hand_max = maxf(hand_max, ahead)
		check("%s: los brazos se balancean" % name, hand_max - hand_min > 0.1)
		# --- Crouching -------------------------------------------------------------
		var crouched: Array = await walk(0.0, 2.5, true, true, ["hip", "rh", "lf"])
		var crouch_hip: float = crouched[crouched.size() - 1].hip.y
		check("%s: agacharse baja de verdad las caderas" % name, standing_hip - crouch_hip > 0.25)
		var hand_low: float = crouched[crouched.size() - 1].rh.y - body.global_position.y
		check("%s: quieto y agachado, una mano va al suelo" % name, hand_low < 0.55)
		var crouch_moving: Array = await walk(1.6, 1.5, true, true, ["rh"])
		var hand_up: float = crouch_moving[crouch_moving.size() - 1].rh.y - body.global_position.y
		check("%s: al avanzar agachado, la mano se levanta" % name, hand_up > hand_low + 0.1)
		# --- In the air ------------------------------------------------------------
		# Stood still for a moment first, so the baseline is a foot on the
		# floor and not one caught mid-step.
		var settled: Array = await walk(0.0, 0.6, false, true, ["lf"])
		var standing_foot: float = settled[settled.size() - 1].lf.y - body.global_position.y
		var airborne: Array = await walk(2.0, 1.0, false, false, ["lf", "rf"])
		var tucked: float = airborne[airborne.size() - 1].lf.y - body.global_position.y
		check("%s: en el aire las piernas se recogen" % name, tucked > standing_foot + 0.08)
		avatar.queue_free()
		await process_frame
	# The model with no bones at all still poses without complaining.
	avatar = AVATAR.new()
	avatar.character = 0
	body.add_child(avatar)
	await process_frame
	avatar.update_pose(Vector3(3.0, 0, 0), false, 1.0 / 60.0, true)
	avatar.update_pose(Vector3.ZERO, true, 1.0 / 60.0, true)
	check("El modelo sin esqueleto no se rompe", avatar.model != null and avatar.rig == null)
	var file := FileAccess.open("res://evidence/avatar_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("AVATAR_RESULT ", checks.size() - failed, "/", checks.size())
	quit(0 if failed == 0 else 1)
