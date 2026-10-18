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
	for character in [0, 1, 2]:
		avatar = AVATAR.new()
		avatar.character = character
		avatar.first_person = false
		body.add_child(avatar)
		await process_frame
		var name: String = AVATAR.NAMES[character]
		check("%s: el esqueleto y sus huesos están" % name, avatar.rig != null and avatar.bones.get("hip", -1) >= 0 and avatar.bones.get("lf", -1) >= 0 and avatar.bones.get("rh", -1) >= 0)
		# --- Walking ---------------------------------------------------------------
		var standing_hip := bone_at("hip").y
		var samples: Array = await walk(3.4, 2.0, false, true, ["lf", "rf", "lk", "lt", "rh", "hip", "lo"])
		# A planted foot does not slide: while the ball of it is on the floor it
		# holds still across it while the body moves on, and it is on the floor
		# a good part of every step.
		var low := INF
		for row in samples.slice(20): low = minf(low, (row.lo as Vector3).y)
		var still := 0
		var slid := 0.0
		for i in range(21, samples.size()):
			if (samples[i].lo as Vector3).y > low + 0.03 or (samples[i - 1].lo as Vector3).y > low + 0.03: continue
			still += 1
			var across: Vector3 = samples[i].lo - samples[i - 1].lo
			slid = maxf(slid, Vector2(across.x, across.z).length())
		check("%s: el pie plantado no patina" % name, still > samples.size() / 6 and slid < 0.01)
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
		# Off the floor it jumps instead of walking on: once the jump has come
		# in, the feet stop taking steps under the body.
		var airborne: Array = await walk(2.0, 0.8, false, false, ["lf", "hip"])
		var stepping := 0.0
		for row in airborne.slice(airborne.size() / 2):
			stepping = maxf(stepping, absf(((row.lf as Vector3) - (row.hip as Vector3)).x - ((airborne[airborne.size() / 2].lf as Vector3) - (airborne[airborne.size() / 2].hip as Vector3)).x))
		check("%s: en el aire salta en vez de seguir andando" % name, stepping < 0.08)
		# And back on the floor after it the knees take the landing: the hips go
		# down, and come back up.
		var landing: Array = await walk(0.0, 1.0, false, true, ["hip"])
		var lowest := INF
		for row in landing: lowest = minf(lowest, (row.hip as Vector3).y - body.global_position.y)
		var stood: float = (landing[landing.size() - 1].hip as Vector3).y - body.global_position.y
		check("%s: al caer, las rodillas amortiguan" % name, lowest < standing_hip - body.global_position.y - 0.06 and stood > lowest + 0.05)
		avatar.queue_free()
		await process_frame
	# The detective's skin came from Mixamo without materials: each part wears
	# the OBJ's, relief and all.
	avatar = AVATAR.new()
	avatar.character = 0
	body.add_child(avatar)
	await process_frame
	var dressed: Array = avatar.meshes.filter(func(mesh): return mesh.get_surface_override_material(0) != null and mesh.get_surface_override_material(0).albedo_texture != null)
	check("El detective lleva su ropa y su piel", dressed.size() == avatar.meshes.size())
	check("El detective lleva el relieve que trae su modelo", avatar.meshes[0].get_surface_override_material(0).normal_texture != null)
	avatar.queue_free()
	await process_frame
	# What the importer gets wrong, put right as the body is put together.
	avatar = AVATAR.new()
	avatar.character = 2
	body.add_child(avatar)
	await process_frame
	var occlusion: Array = avatar.meshes.filter(func(mesh): return String(mesh.name).to_lower().contains("eyeocclusion"))
	check("La Exploradora no mira a través de dos bolas blancas", not occlusion.is_empty() and occlusion.all(func(mesh): return not mesh.visible))
	var hair_ok := true
	var chalk := false
	for mesh in avatar.meshes:
		if not mesh.visible: continue
		if mesh.lod_bias < avatar.AVATAR_LOD_BIAS: hair_ok = false
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
			if material == null: continue
			var name := material.resource_name.to_lower()
			if name.contains("hair") and material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS: hair_ok = false
			if name.contains("skin") and material.roughness >= 0.99: chalk = true
	check("Su pelo se funde en vez de cortarse en escalones, y nada se dibuja reducido de cerca", hair_ok)
	check("Y la piel no es de tiza", not chalk)
	var file := FileAccess.open("res://evidence/avatar_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("AVATAR_RESULT ", checks.size() - failed, "/", checks.size())
	quit(0 if failed == 0 else 1)
