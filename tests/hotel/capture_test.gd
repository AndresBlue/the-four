extends SceneTree
## The capture (docs/EXECUTION.md): the scene the creature plays out on
## whoever it catches, and what that survivor's own camcorder makes of it.
##
## What is held here: the score is in order and its curves do what their names
## say; how somebody is caught is read off where they and the creature are; a
## capture runs its length on its clock with the camera never anywhere it
## cannot be, the mask the right way up, and one death at the end of it; cut
## short at any second it leaves nothing behind; the camera lands where it
## can see, in room after room; a body with no room to lie sits down inside
## the room instead of leaning through its wall; the creature, sure of who is
## in a wardrobe, opens it from in front of its doors or waits for them, and
## does each for the right reason; a wardrobe can be left quietly; and the
## second time is shorter, the option softer, the tape rewound.
##
## That the scene is the same on every machine is tests/net/net_test.gd's.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SCORE := preload("res://game/app/capture_score.gd")
const FALL := preload("res://game/app/camera_fall.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
const DIFFICULTY := preload("res://game/floors/difficulty.gd")
const SEED := 81
var level
var checks: Array = []
var failed := 0

func _initialize() -> void: run.call_deferred()

func check(title: String, passed: bool, detail := "") -> void:
	checks.append({"check": title, "passed": passed})
	if not passed: failed += 1
	print("PASS " if passed else "FAIL ", title, "" if passed or detail.is_empty() else "  [" + detail + "]")

func frames(count: int) -> void:
	for i in count: await physics_frame

func seconds(length: float) -> void:
	await frames(int(round(length * 60.0)))

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## The biggest room of the first sector the creature may take somebody in.
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

## The long way of that room.
func along_of(room: Dictionary) -> Vector3:
	var span: Vector2 = FLOOR.size_of(room)
	return Vector3(1, 0, 0) if span.x >= span.y else Vector3(0, 0, 1)

## A floor to be caught on, as many times as it takes (in Apacible a stage is
## always given back), with nothing of the last one left.
func fresh_floor() -> void:
	Input.action_release("forward")
	Input.action_release("interact")
	await level.start_floor(SEED, false, [1], "apacible")
	level.ui.hide_transit()
	level.lifts.brief_wait = 0.0
	if is_instance_valid(level.director):
		level.director.queue_free()
		level.director = null
	level.locust.set_physics_process(false)
	level.locust.grace = 0.0
	await frames(3)

## The survivor at a spot, looking a way, and the creature somewhere, at rest.
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
	level.executions.forced = {}
	level.clear_screen_cues()

## In the middle of the big room, the creature a step and a half in front.
func face_to_face(apart := 1.5) -> void:
	var room := staging_room()
	var centre: Vector3 = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	var along := along_of(room)
	put(centre, along, centre + along * apart)

## Runs the capture in hand to the end of it, a frame at a time, and says
## what it saw: {frames, finite, upright, landed, lifted_after, kill, drop,
## low, death}.
func watch(until := -1.0) -> Dictionary:
	var player = level.player
	var seen := {"frames": 0, "finite": true, "upright": true, "worst_up": 1.0, "first_up": 1.0, "landed": -1.0, "lifted_at": -1.0, "kill": false, "drop": false, "held": true, "near": INF}
	var entry := String(level.execution.get("entry", "front"))
	var guard := 0
	while not level.execution.is_empty() and guard < 600:
		await process_frame
		guard += 1
		if level.execution.is_empty(): break
		var time := float(level.execution.time)
		var camera: Camera3D = player.camera
		seen.frames += 1
		var pose := camera.global_transform
		if not pose.origin.is_finite() or not pose.basis.x.is_finite() or not pose.basis.y.is_finite() or not pose.basis.z.is_finite(): seen.finite = false
		if not player.held or player.active: seen.held = false
		# The face: the mask's own top is towards the top of the picture.
		if time > SCORE.face_start(entry) + SCORE.ARRIVE and time < SCORE.face_end(entry) and level.tape.thrown_at < 0.0 and entry != "above":
			var mask: Transform3D = level.locust.visual.mask_transform()
			var up := pose.basis.y.dot(mask.basis.y.normalized())
			seen.worst_up = minf(float(seen.worst_up), up)
			if up < 0.2: seen.upright = false
			seen.near = minf(float(seen.near), pose.origin.distance_to(mask.origin))
		# And before it has got there, in the frames it takes to come down.
		if time <= SCORE.face_start(entry) + SCORE.ARRIVE and time >= SCORE.face_start(entry) and entry != "above":
			seen.first_up = minf(float(seen.first_up), pose.basis.y.dot((level.locust.visual.mask_transform() as Transform3D).basis.y.normalized()))
		if level.tape.landed_at >= 0.0 and float(seen.landed) < 0.0: seen.landed = float(level.tape.landed_at)
		if SCORE.lift(time) > 0.02 and float(seen.lifted_at) < 0.0: seen.lifted_at = time
		if time >= SCORE.KILL_TIME + 0.02 and int(level.execution.stabs) >= 2: seen.kill = true
		if time >= SCORE.DROP_TIME + 0.02 and bool(level.execution.dropped): seen.drop = true
		if until >= 0.0 and time >= until: break
	return seen

## Nothing of a capture left on the machine of whoever was in it.
func clean(title: String, torch_was := false) -> void:
	var player = level.player
	var material: ShaderMaterial = level.post_material
	var faults: Array = []
	if not level.execution.is_empty(): faults.append("execution")
	if level.tape.recording(): faults.append("tape running")
	if player.camera.top_level: faults.append("camera loose")
	if not player.camera.position.is_equal_approx(Vector3(0.0, player.eye_height, 0.0)) and absf(player.camera.position.y - player.eye_height) > 0.2: faults.append("camera off its eyes")
	if not player.camera.global_transform.origin.is_finite(): faults.append("camera not finite")
	if player.pilot_as.x >= 0.0: faults.append("lamp left up")
	if not player.avatar.transform.is_equal_approx(Transform3D.IDENTITY): faults.append("body left posed")
	if not level.executions.torch.is_empty() or not level.executions.camcorder.is_empty(): faults.append("props in hand")
	if torch_was and not player.torch.visible: faults.append("torch not given back")
	if material != null and (float(material.get_shader_parameter("tape_hit")) != 0.0 or float(material.get_shader_parameter("tape_fray")) != 0.0): faults.append("picture left torn")
	for wardrobe in level.hotel.hides:
		if wardrobe.held_open: faults.append("wardrobe left open")
	check(title, faults.is_empty(), ", ".join(faults))

func run() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	Engine.max_fps = 0
	level.ui.finish_intro()
	score_checks()
	await fresh_floor()
	await entry_checks()
	await scene_checks()
	await overhang_checks()
	await cut_checks()
	await landing_checks()
	await room_checks()
	await wardrobe_checks()
	await quiet_checks()
	await again_checks()
	await blood_checks()
	var file := FileAccess.open("res://evidence/capture_tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks}, "\t"))
	file.close()
	print("CAPTURE_RESULT ", checks.size() - failed, "/", checks.size())
	paused = false
	Input.action_release("forward")
	Input.action_release("interact")
	level.queue_free()
	await process_frame
	quit(0 if failed == 0 else 1)

# --- Blood (game/app/blood.gd) --------------------------------------------------------

## Where every stain of the capture in hand is and when it lands, as text.
func blood_print() -> String:
	var blood = level.executions.blood
	if blood.records.is_empty(): return ""
	var said: Array = []
	for entry in blood.records[-1].stains:
		var at: Vector3 = (entry.transform as Transform3D).origin
		said.append("%.3f,%.3f,%.3f@%.3f" % [at.x, at.y, at.z, float(entry.born)])
	said.sort()
	return ",".join(said)

func blood_checks() -> void:
	var player = level.player
	var blood = level.executions.blood
	await fresh_floor()
	level.settings.values["gore"] = true
	face_to_face()
	level.executions.forced = {"entry": "front", "glance": false, "seed": 4242, "side": 1.0}
	level.capture_survivor(player)
	var record: Dictionary = blood.records[-1] if not blood.records.is_empty() else {}
	var stains := 0
	var sound := true
	var early := INF
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var carried := 0
	for node in record.get("nodes", []):
		if node is MultiMeshInstance3D and node != record.get("air"): carried += (node as MultiMeshInstance3D).multimesh.instance_count
	for entry in record.get("stains", []):
		stains += 1
		var placed: Transform3D = entry.transform
		early = minf(early, float(entry.born))
		# On something, and in the room it says it is in.
		var normal := placed.basis.y.normalized()
		var query := PhysicsRayQueryParameters3D.create(placed.origin + normal * 0.04, placed.origin - normal * 0.04, 1)
		query.exclude = [player.get_rid(), level.locust.get_rid()]
		if space.intersect_ray(query).is_empty(): sound = false
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, placed.origin)
		if room.is_empty() or int(room.id) != int(entry.room): sound = false
	if carried != stains: sound = false
	check("Una captura deja su sangre calculada desde el primer instante: manchas y una poza", stains > 40 and record.get("pool") != null, "stains=%d" % stains)
	check("Nada cae antes de la primera herida, y cada mancha está sobre algo y en su sala", sound and early >= 0.03, "first=%.3f" % early)
	# The pool: no further any way than the room it is in.
	var held := true
	if record.get("pool") != null:
		var reach: PackedFloat32Array = (record.pool as ShaderMaterial).get_shader_parameter("reach")
		var middle: Vector3 = record.pool_at
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, middle)
		var rect := Rect2(FLOOR.position_of(room).x - FLOOR.size_of(room).x * 0.5, FLOOR.position_of(room).z - FLOOR.size_of(room).y * 0.5, FLOOR.size_of(room).x, FLOOR.size_of(room).y)
		for index in reach.size():
			var angle := TAU * float(index) / 16.0
			if not rect.has_point(Vector2(middle.x, middle.z) + Vector2(cos(angle), sin(angle)) * reach[index] * 0.98): held = false
		if reach.size() != 16: held = false
	check("La poza no pasa de la sala en ninguna dirección", held)
	var first := blood_print()
	await seconds(0.3)
	check("El reloj de la sangre es el de la escena mientras dura", absf(float(record.clock) - float(level.execution.time)) < 0.05, "blood=%.2f scene=%.2f" % [float(record.get("clock", -1.0)), float(level.execution.time)])
	check("Y el cuerpo lleva su mancha", player.avatar.stain != null or player.avatar.rig == null)
	level.release_execution()
	await frames(3)
	var left := 0
	for node in level.hotel.find_children("Blood*", "", true, false): left += 1
	check("Soltada viva, no queda nada: ni en el suelo ni en la ropa", blood.records.is_empty() and left == 0 and player.avatar.stain == null, "left=%d" % left)
	# The same capture again is the same blood.
	face_to_face()
	level.executions.forced = {"entry": "front", "glance": false, "seed": 4242, "side": 1.0}
	level.capture_survivor(player)
	check("La misma captura deja la misma sangre, mancha por mancha", not first.is_empty() and blood_print() == first)
	level.release_execution()
	await frames(3)
	face_to_face()
	level.executions.forced = {"entry": "front", "glance": false, "seed": 4243, "side": 1.0}
	level.capture_survivor(player)
	check("Y otra, otra", not blood_print().is_empty() and blood_print() != first)
	await watch()
	check("Acabada la escena, la sangre se queda en el piso", not blood.records.is_empty() and not (blood.records[-1].nodes as Array).is_empty())
	level.executions.clear_leavings()
	await frames(3)
	check("Y se va con la etapa", blood.records.is_empty() and level.hotel.find_children("Blood*", "", true, false).is_empty())
	# Switched off, there is none of it.
	await fresh_floor()
	level.settings.values["gore"] = false
	face_to_face()
	level.executions.forced = {"entry": "front", "glance": false}
	level.capture_survivor(player)
	await seconds(0.3)
	check("Con «Sangre» apagada no hay nada", blood.records.is_empty() and player.avatar.stain == null and level.hotel.find_children("Blood*", "", true, false).is_empty())
	level.release_execution()
	level.settings.values["gore"] = true
	await frames(2)

# --- The score ----------------------------------------------------------------------

func score_checks() -> void:
	var beats := [0.0, SCORE.ARRIVE, SCORE.JERK_TIME, SCORE.FACE_TIME, SCORE.LIFT_FROM, SCORE.LIFT_TO, SCORE.ARM_TIME, SCORE.KILL_TIME, SCORE.DROP_TIME, SCORE.GLANCE_FROM, SCORE.GLANCE_COCK, SCORE.CUT_TIME, SCORE.END_TIME]
	var ordered := true
	for index in range(1, beats.size()):
		if float(beats[index]) <= float(beats[index - 1]): ordered = false
	# The body is down before the picture goes, and the turn of whoever is
	# caught from behind ends before its face does.
	check("Los golpes de la escena van en su orden", ordered and SCORE.DROP_TIME + SCORE.FALL_LENGTH < SCORE.CUT_TIME and SCORE.BACK_TURN_FROM < SCORE.BACK_TURN_TO and SCORE.BACK_TURN_TO < SCORE.BACK_FACE_TIME)
	# The longest a camcorder takes from a standing hand to the floor, and from
	# there to lying still.
	var down: float = (FALL.TOSS.y + sqrt(FALL.TOSS.y * FALL.TOSS.y + 2.0 * FALL.GRAVITY * 1.75)) / FALL.GRAVITY
	var still: float = down + 2.0 * sqrt(2.0 * FALL.HOP.y / FALL.GRAVITY) + FALL.ROCK
	for length in FALL.KNOCK_TIME: still += float(length)
	var swiped: float = SCORE.face_end("back") + SCORE.SWIPE_REACH
	check("El cuerpo se levanta cuando la cámara ya ha tocado el suelo, y el golpe llega con ella quieta", SCORE.LIFT_FROM >= swiped + down and SCORE.ARM_TIME >= swiped + still, "down=%.2f still=%.2f" % [down, still])
	check("La cámara cae lo que tarda en caer una cosa: más de medio segundo desde la mano", down > 0.55 and (FALL.TOSS.x + sqrt(FALL.TOSS.x * FALL.TOSS.x + 2.0 * FALL.GRAVITY * 1.6)) / FALL.GRAVITY > 0.55)
	check("El grito llega con la máscara en la lente, nunca antes", SCORE.scream_time("front") == SCORE.SCREAM_AFTER and is_equal_approx(SCORE.scream_time("back"), SCORE.BACK_TURN_TO + SCORE.SCREAM_AFTER) and SCORE.scream_time("back", true) == SCORE.SCREAM_AFTER)
	var monotone := true
	var bounded := true
	var before := {"closing": 0.0, "limp": 0.0, "fall": 0.0, "thrust": 0.0, "glance": 0.0, "swipe": 0.0, "turned": 0.0}
	var time := 0.0
	while time <= SCORE.END_TIME:
		var now := {"closing": SCORE.closing(time), "limp": SCORE.limp(time), "fall": SCORE.fall(time), "thrust": SCORE.thrust(time), "glance": SCORE.glance(time), "swipe": SCORE.swipe("front", time), "turned": SCORE.turned("back", time)}
		for key in now:
			if float(now[key]) < float(before[key]) - 0.0001: monotone = false
			if float(now[key]) < 0.0 or float(now[key]) > 1.0: bounded = false
		for value in [SCORE.lift(time), SCORE.stoop(time)]:
			if value < 0.0 or value > 1.0: bounded = false
		before = now
		time += 1.0 / 120.0
	check("Sus curvas no retroceden ni se salen de 0 a 1", monotone and bounded)
	check("En alto solo entre el alzado y la caída", SCORE.lift(SCORE.LIFT_FROM) == 0.0 and SCORE.lift(SCORE.LIFT_TO) == 1.0 and SCORE.lift(SCORE.DROP_TIME) == 1.0 and SCORE.lift(SCORE.DROP_TIME + SCORE.FALL_LENGTH) == 0.0)
	# Folded up: the hips and the lean stay inside the room there is behind.
	var seated := true
	var room := 0.2
	var last := Vector2.ZERO
	while room <= SCORE.LIE_ROOM:
		var back := SCORE.seat_back(room)
		var lean := SCORE.seat_lean(room)
		if back < 0.08 or back > 0.35 or lean < 0.08 or lean > 1.45: seated = false
		if back < last.x - 0.0001 or lean < last.y - 0.0001: seated = false
		if room >= 0.45 and back + 0.14 + 0.55 * sin(lean) > room + 0.02: seated = false
		last = Vector2(back, lean)
		room += 0.05
	check("Sentado sin sitio: la cadera y el respaldo caben en lo que hay detrás", seated)

# --- How somebody is caught, from where everybody is --------------------------------

func entry_checks() -> void:
	var player = level.player
	var creature = level.locust
	var room := staging_room()
	var centre: Vector3 = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	var along := along_of(room)
	var beside := along.cross(Vector3.UP)
	var chosen := func(looking: Vector3, creature_at: Vector3) -> Array:
		put(centre, looking, creature_at)
		var away: Vector3 = player.global_position - creature.global_position
		away.y = 0.0
		return level.executions.choose_entry(player, away)
	var front: Array = chosen.call(along, centre + along * 1.5)
	var back: Array = chosen.call(-along, centre + along * 1.5)
	check("Mirándola, de frente; de espaldas, por la espalda", front[0] == "front" and back[0] == "back")
	# Its side is the hand it is on: looking along, the right hand is +beside... of the body.
	var right_hand: Vector3 = Basis(Vector3.UP, atan2(-along.x, -along.z)).x
	var from_right: Array = chosen.call(along, centre + right_hand * 1.5)
	var from_left: Array = chosen.call(along, centre - right_hand * 1.5)
	check("De lado, por la mano en que está", from_right[0] == "side" and float(from_right[1]) == 1.0 and from_left[0] == "side" and float(from_left[1]) == -1.0)
	put(centre, along, centre + along * 1.5)
	player.crouched = true
	var above: Array = level.executions.choose_entry(player, player.global_position - creature.global_position)
	player.crouched = false
	check("Agachado, desde arriba", above[0] == "above")
	var hide: Node3D = level.hotel.hides[0]
	player.hidden = true
	player.hiding_place = hide
	var wardrobe: Array = level.executions.choose_entry(player, player.global_position - creature.global_position)
	creature.pouncing = true
	var ambush: Array = level.executions.choose_entry(player, player.global_position - creature.global_position)
	creature.pouncing = false
	player.hidden = false
	player.hiding_place = null
	check("En un armario, la del armario; tras la finta, la emboscada", wardrobe[0] == "wardrobe" and ambush[0] == "ambush")
	# What the host hands every machine: all of it there, and of its kind.
	put(centre, along, centre + along * 1.5)
	var data: Dictionary = level.executions.stage_capture(player)
	var whole := true
	for key in ["entry", "side", "straight", "slump", "room", "yaw", "hide", "far", "from", "facing", "crouched", "torch", "glance", "seed", "id"]:
		if not data.has(key): whole = false
	check("Lo que decide el anfitrión va entero a todas las máquinas", whole and data.entry in SCORE.ENTRIES and absf(float(data.side)) == 1.0 and is_finite(float(data.yaw)) and float(data.far) >= SCORE.HOLD_FAR.x and float(data.far) <= SCORE.HOLD_FAR.y and int(data.hide) == -1 and int(data.id) >= 1)
	# And a machine told less than that still plays the scene.
	level.apply_execution(player.slot, creature.global_position, float(data.yaw))
	await frames(4)
	var bare: bool = not level.execution.is_empty() and level.execution.entry == "front" and level.tape.recording()
	level.release_execution()
	await frames(2)
	check("Con menos datos de los que hay, la escena se juega igual", bare)
	clean("Y al soltarla no queda nada")

# --- A capture, its whole length ----------------------------------------------------

func scene_checks() -> void:
	var player = level.player
	var creature = level.locust
	for entry in ["front", "back", "side"]:
		face_to_face()
		if entry == "back": player.rotation.y += PI
		level.executions.forced = {"entry": entry, "glance": false}
		var captures_before: int = level.executions.captures
		var elapsed_before: float = level.session.elapsed
		var tape_before: float = level.tape_seconds()
		level.capture_survivor(player)
		var began: bool = not level.execution.is_empty() and level.execution.entry == entry and player.held and not player.active and level.tape.recording() and creature.mode == creature.Mode.EXECUTE
		var id := int(level.execution.get("id", -1))
		# Whoever is being executed is not caught again.
		level.capture_survivor(player)
		var once: bool = int(level.execution.get("id", -2)) == id and level.executions.captures == captures_before + 1
		var seen: Dictionary = await watch()
		check("Captura %s: empieza en el acto, con el control quitado y la cinta rodando" % entry, began)
		check("Captura %s: una sola, aunque la toquen dos veces" % entry, once)
		check("Captura %s: la cámara no sale nunca de lo que puede ser" % entry, bool(seen.finite) and int(seen.frames) > 200, "frames=%d" % int(seen.frames))
		check("Captura %s: la máscara, del derecho en la lente y a un palmo" % entry, bool(seen.upright) and float(seen.near) > 0.07 and float(seen.near) < 0.12, "up=%.2f near=%.3f" % [float(seen.worst_up), float(seen.near)])
		check("Captura %s: la cámara ya está en el suelo cuando levantan el cuerpo" % entry, float(seen.landed) > 0.0 and float(seen.lifted_at) > float(seen.landed), "landed=%.2f lifted=%.2f" % [float(seen.landed), float(seen.lifted_at)])
		check("Captura %s: el golpe y la caída llegan a su segundo, y nunca se le devuelve el control" % entry, bool(seen.kill) and bool(seen.drop) and bool(seen.held))
		# The end of it: the death is counted, and alone the stage is given back.
		var dead: bool = level.session.participants.get(player.slot) == level.session.Life.DEAD or level.session.restart_wait > 0.0
		check("Captura %s: al acabar hay una muerte, y la etapa en camino de devolverse" % entry, level.execution.is_empty() and dead and level.session.state == level.session.State.PLAYING)
		# The stage back: the tape runs back to where the stage began, the
		# floor's own time does not.
		var rewound := false
		var guard := 0
		while guard < 600 and (level.session.restart_wait > 0.0 or not level.rewind.is_empty() or level.lost_signal > 0.0):
			await process_frame
			guard += 1
			if not level.rewind.is_empty(): rewound = true
		await frames(3)
		check("Captura %s: la etapa vuelve con la cinta rebobinada y el tiempo del piso corriendo" % entry, rewound and level.tape_seconds() < tape_before + 0.5 and level.session.elapsed > elapsed_before + 4.0 and level.session.participants.get(player.slot) == level.session.Life.EXPLORING and not player.held, "tape %.2f -> %.2f, floor %.2f -> %.2f" % [tape_before, level.tape_seconds(), elapsed_before, level.session.elapsed])
		clean("Captura %s: y no queda nada de ella" % entry)
		check("Captura %s: ni la cámara ni la linterna de aquella muerte siguen en el suelo" % entry, level.executions.leavings.is_empty())

## A lunge that ended with its head over its victim: the lens looks straight
## up at the mask for the frame or two it takes to bend down to it.
func overhang_checks() -> void:
	var player = level.player
	face_to_face(0.65)
	level.executions.forced = {"entry": "front", "glance": false}
	level.capture_survivor(player)
	var seen: Dictionary = await watch(SCORE.FACE_TIME - 0.05)
	check("Con la cabeza encima de su víctima, la máscara no sale del revés ni en el primer fotograma", float(seen.first_up) > 0.2 and bool(seen.upright) and bool(seen.finite), "first=%.2f worst=%.2f" % [float(seen.first_up), float(seen.worst_up)])
	level.release_execution()
	await frames(2)

# --- Cut short at any second --------------------------------------------------------

func cut_checks() -> void:
	var player = level.player
	for cut in [0.05, 0.4, 0.8, 1.7, 2.9, 3.3]:
		face_to_face()
		player.torch.visible = true
		level.executions.forced = {"entry": "front"}
		level.capture_survivor(player)
		var taken: bool = not level.execution.is_empty() and not player.torch.visible
		await watch(cut)
		level.release_execution()
		await frames(2)
		check("Cortada a los %.2f s: la víctima vuelve a ser dueña de sí" % cut, taken and level.execution.is_empty() and not player.held and level.session.participants.get(player.slot) == level.session.Life.EXPLORING)
		clean("Cortada a los %.2f s: sin restos" % cut, true)
	# And a floor torn down under it.
	face_to_face()
	level.capture_survivor(player)
	await watch(1.2)
	await fresh_floor()
	clean("Un piso que se reconstruye en plena captura no deja nada")
	check("Y en el piso nuevo no se ha visto todavía ninguna entrada", level.tape.seen.is_empty() and level.executions.captures == 0)

# --- Where the camera comes to lie --------------------------------------------------

func landing_checks() -> void:
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var player = level.player
	var creature = level.locust
	var tally := [0, 0, 0]
	var sound := true
	# The fall itself: never under the floor, never a jump, and it ends lying
	# where it was said it would.
	var fell := true
	var worst_step := 0.0
	var lowest := INF
	var rolls := 0
	var trials := 0
	var rooms := 0
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or level.point_protected(FLOOR.position_of(room)): continue
		var span: Vector2 = FLOOR.size_of(room)
		if span.x < 3.5 or span.y < 3.5: continue
		rooms += 1
		if rooms > 45: break
		var centre: Vector3 = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
		for index in 3:
			# In the middle of it, and off towards two of its corners.
			var offset := Vector3.ZERO if index == 0 else Vector3((span.x * 0.5 - 1.6) * (1.0 if index == 1 else -1.0), 0, (span.y * 0.5 - 1.6) * (1.0 if index == 1 else -1.0))
			var point: Vector3 = centre + offset
			var yaw := 0.9 * float(rooms) + 1.7 * float(index)
			var forward := -Basis(Vector3.UP, yaw).z
			var far := 0.9
			var way: Vector3 = level.executions.fall_way(yaw, 1.0 if (rooms + index) % 2 == 0 else -1.0)
			var hold: Vector3 = point + forward * SCORE.HOLD_NEAR
			var scene := {
				"from": point + forward * far + Vector3(0, SCORE.HOLD_STAND + 1.64, 0), "middle": point + forward * far * 0.5, "hold": hold,
				"body": hold + way * 0.85, "head": hold + way * 1.7, "creature": point, "torch": Vector3.INF, "dark": false,
				"exclude": [player.get_rid(), creature.get_rid()],
				"allowed": func(spot: Vector3) -> bool: return not level.point_protected(spot),
			}
			var take: Dictionary = FALL.solve(space, scene, 7919 * rooms + index)
			trials += 1
			tally[int(take.kind)] += 1
			var rest: Transform3D = take.rest
			if not rest.origin.is_finite() or not rest.basis.x.is_finite() or float(take.duration) <= 0.0: sound = false
			var hand := Transform3D(Basis(Vector3.UP, yaw), scene.from)
			var before := hand
			var length := float(take.duration) + FALL.ROCK
			if float(take.landed) < 0.4 or float(take.duration) < float(take.hopped) or (take.times as Array).size() != (take.knocks as Array).size(): fell = false
			rolls += (take.times as Array).size()
			for step in int(length * 120.0) + 2:
				var at: Transform3D = FALL.pose(take, hand, float(step) / 120.0)
				if not at.origin.is_finite() or not at.basis.x.is_finite() or absf(at.basis.determinant() - 1.0) > 0.01: fell = false
				worst_step = maxf(worst_step, at.origin.distance_to(before.origin))
				lowest = minf(lowest, at.origin.y - rest.origin.y)
				before = at
			if not before.is_equal_approx(rest): fell = false
			# On the floor of that place, a step or two from where it was taken.
			if absf(rest.origin.y - centre.y) > 0.45 or flat(rest.origin, scene.middle) > 3.2: sound = false
	print("CAPTURE_LANDING ve=", tally[0], " a medias=", tally[1], " boca abajo=", tally[2], " de ", trials, " en ", mini(rooms, 45), " salas")
	check("La cámara cae siempre en algún sitio, en el suelo y cerca", sound and trials >= 60, "trials=%d" % trials)
	check("Cae sin saltos ni atravesar el suelo, y acaba donde se dijo", fell and worst_step < 0.08 and lowest > -0.02, "step=%.3f lowest=%.3f" % [worst_step, lowest])
	check("Y casi siempre rueda sobre sus cantos antes de quedarse quieta", float(rolls) >= 1.5 * float(trials), "vuelcos=%d de %d caídas" % [rolls, trials])
	check("En siete de cada diez sitios ve la escena", float(tally[FALL.VIEW]) >= 0.7 * float(trials), "ve=%d a medias=%d boca abajo=%d de %d" % [tally[0], tally[1], tally[2], trials])
	check("Y boca abajo, una de cada diez como mucho", float(tally[FALL.DOWN]) <= 0.1 * float(trials), "boca abajo=%d de %d" % [tally[2], trials])

# --- The body, with room to lie and without -----------------------------------------

func room_checks() -> void:
	var player = level.player
	var creature = level.locust
	var room := staging_room()
	var centre: Vector3 = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
	var span: Vector2 = FLOOR.size_of(room)
	var along := along_of(room)
	var half := maxf(span.x, span.y) * 0.5
	var open: Array = level.executions.fall_room(centre, 0.0, 1.0, [player.get_rid(), creature.get_rid()])
	check("Con sitio, el cuerpo cae tendido", not bool(open[1]) and not bool(open[2]))
	# Their back to the end wall of the room: the creature between them and
	# the room, a step and a half off.
	var at_wall: Vector3 = centre - along * (half - 0.45)
	put(at_wall, along, at_wall + along * 1.5)
	level.executions.forced = {"entry": "front", "glance": false}
	level.capture_survivor(player)
	var slump := bool(level.execution.get("slump", false))
	var behind := float(level.execution.get("room", -1.0))
	check("De espaldas a una pared no hay sitio: se dobla donde cae", slump and behind > 0.3 and behind < SCORE.LIE_ROOM, "slump=%s room=%.2f" % [slump, behind])
	await watch(SCORE.DROP_TIME + SCORE.FALL_LENGTH + 0.3)
	# Sat down inside the room: no part of the trunk or the head past the wall.
	var avatar = player.avatar
	var inside := true
	var deepest := 0.0
	if avatar.rig != null:
		for key in ["hip", "chest", "head"]:
			var bone: int = avatar.bones.get(key, -1)
			if bone < 0: continue
			var at: Vector3 = avatar.rig.global_transform * avatar.rig.get_bone_global_pose(bone).origin
			var depth := (centre - at).dot(along)
			deepest = maxf(deepest, depth)
			if depth > half - 0.05: inside = false
			if key == "hip" and absf(at.y - centre.y) > 0.4: inside = false
	check("Y queda sentado dentro de la sala, no a través de la pared", inside and avatar.rig != null, "deepest=%.2f wall=%.2f" % [deepest, half])
	level.release_execution()
	await frames(2)
	clean("Soltada después de caer sentada: sin restos")

# --- Wardrobes: the search, the feint, the doors -------------------------------------

## The nearest small wardrobe to the big room that the creature may go to.
func staging_wardrobe() -> Node3D:
	var centre: Vector3 = FLOOR.position_of(staging_room())
	var best: Node3D = null
	for hide in level.hotel.hides:
		if level.point_protected(hide.global_position) or hide.big: continue
		if best == null or hide.global_position.distance_to(centre) < best.global_position.distance_to(centre): best = hide
	return best

## The survivor inside it, and the creature a pace to one side of its doors,
## after them: sure of who is in there, or only suspecting.
func at_wardrobe(hide: Node3D, sure: bool, feint: float) -> void:
	var player = level.player
	var creature = level.locust
	put(hide.to_global(hide.exit_offset), -hide.global_basis.z, hide.to_global(hide.exit_offset + Vector3(0.8, 0, 0.3)))
	await frames(2)
	player.enter_hide(hide)
	await seconds(1.4)
	creature.feint = feint
	creature.set_physics_process(true)
	creature.focus = player
	creature.observed_hide = hide
	creature.certain = sure
	creature.last_known = hide.global_position
	creature.detection = 1.5
	creature.lost_time = 1.0
	creature.set_mode(creature.Mode.CHASE)

func wardrobe_checks() -> void:
	var player = level.player
	var creature = level.locust
	var hide := staging_wardrobe()
	var front: Vector3 = hide.to_global(hide.exit_offset)
	check("Apacible no finta nunca; las demás, cada vez más", float(DIFFICULTY.value("apacible", "feint")) == 0.0 and float(DIFFICULTY.value("equilibrada", "feint")) > 0.0 and float(DIFFICULTY.value("desafiante", "feint")) > float(DIFFICULTY.value("equilibrada", "feint")) and float(DIFFICULTY.value("pesadilla", "feint")) > float(DIFFICULTY.value("desafiante", "feint")))
	# Only suspecting, it never waits: it opens the wardrobe, from in front.
	await at_wardrobe(hide, false, 1.0)
	var mode := -1
	var guard := 0
	while guard < 120 and creature.mode == creature.Mode.CHASE:
		await physics_frame
		guard += 1
	mode = creature.mode
	check("Sin haberle visto entrar no hay finta: registra el armario", mode == creature.Mode.WARDROBE, "mode=%s" % creature.Mode.keys()[mode])
	guard = 0
	while guard < 400 and level.execution.is_empty():
		await physics_frame
		guard += 1
	var from_front := flat(creature.global_position, front)
	check("Lo abre plantada ante las puertas, y se lo lleva de ahí", not level.execution.is_empty() and level.execution.entry == "wardrobe" and from_front < 0.3, "off=%.2f" % from_front)
	check("Sacado del armario, sus puertas se quedan abiertas y no entra nadie", hide.held_open and not hide.has_room() and int(level.execution.hide) == level.hotel.hides.find(hide))
	check("Dentro no hay sitio para tenderse: se dobla", bool(level.execution.slump) and float(level.execution.room) < SCORE.LIE_ROOM)
	var seen: Dictionary = await watch()
	check("La captura en el armario llega a su fin con la cámara en su sitio", bool(seen.finite) and bool(seen.kill) and bool(seen.drop) and float(seen.landed) > 0.0)
	guard = 0
	while guard < 600 and (level.session.restart_wait > 0.0 or not level.rewind.is_empty() or level.lost_signal > 0.0):
		await process_frame
		guard += 1
	await frames(3)
	check("Devuelta la etapa, el armario se cierra y vuelve a servir", not hide.held_open and hide.has_room())
	clean("La captura en el armario no deja nada")
	# Sure of it, and the floor's odds say so: it looks, steps aside and waits.
	await at_wardrobe(hide, true, 1.0)
	guard = 0
	while guard < 120 and creature.mode == creature.Mode.CHASE:
		await physics_frame
		guard += 1
	check("Segura de quién hay dentro, espera en vez de abrir", creature.mode == creature.Mode.LURK, "mode=%s" % creature.Mode.keys()[creature.mode])
	guard = 0
	while guard < 500 and not (String(creature.lurk.get("phase", "")) == "wait" and creature.hushed()):
		await physics_frame
		guard += 1
	await frames(20)
	check("Apartada, quieta, con las puertas a la vista, y lo que la delata se apaga", creature.mode == creature.Mode.LURK and creature.hushed() and creature.velocity.length() < 0.05 and creature.doors_seen_from(hide, creature.global_position) and flat(creature.global_position, front) > 0.9, "apart=%.2f" % flat(creature.global_position, front))
	# A leaf barely ajar tells it nothing; a leaf open does.
	hide.set_peek(0.2, 0.2, player)
	await seconds(0.8)
	var patient: bool = creature.mode == creature.Mode.LURK and String(creature.lurk.phase) == "wait" and not hide.ajar()
	Input.action_press("forward")
	guard = 0
	while guard < 300 and level.execution.is_empty():
		await physics_frame
		guard += 1
	Input.action_release("forward")
	from_front = flat(creature.global_position, front)
	check("Una rendija no la mueve; una hoja abierta sí: revienta las puertas y se lo lleva de frente", patient and not level.execution.is_empty() and level.execution.entry == "ambush" and from_front < 0.3, "patient=%s off=%.2f" % [patient, from_front])
	await watch()
	guard = 0
	while guard < 600 and (level.session.restart_wait > 0.0 or not level.rewind.is_empty() or level.lost_signal > 0.0):
		await process_frame
		guard += 1
	await frames(3)
	clean("La emboscada no deja nada")
	# Whoever comes out while it waits has it on them.
	await at_wardrobe(hide, true, 1.0)
	guard = 0
	while guard < 600 and not (String(creature.lurk.get("phase", "")) == "wait" and creature.hushed()):
		await physics_frame
		guard += 1
	level.match_net.use_hide(hide, false)
	await frames(3)
	check("Quien sale mientras espera la tiene encima", not player.hidden and creature.mode in [creature.Mode.CHASE, creature.Mode.WINDUP] and creature.focus == player and flat(creature.last_known, front) < 1.0)
	creature.set_physics_process(false)
	creature.set_mode(creature.Mode.PATROL)
	await seconds(1.5)
	# And whoever waits it out hears it go: it was never sure for ever.
	await at_wardrobe(hide, true, 1.0)
	creature.feint_wait = Vector2(1.0, 1.2)
	guard = 0
	while guard < 900 and creature.mode in [creature.Mode.CHASE, creature.Mode.LURK]:
		await physics_frame
		guard += 1
	check("Quien aguanta dentro la oye marcharse: se cansa y ya no está segura", creature.mode not in [creature.Mode.LURK, creature.Mode.WARDROBE, creature.Mode.EXECUTE] and creature.observed_hide == null and not creature.certain and player.hidden and level.execution.is_empty(), "mode=%s after %d frames" % [creature.Mode.keys()[creature.mode], guard])
	creature.set_physics_process(false)
	player.leave_hide()
	await seconds(1.6)

# --- Out of a wardrobe, the quiet way -----------------------------------------------

func quiet_checks() -> void:
	var player = level.player
	var creature = level.locust
	var hide := staging_wardrobe()
	check("Salir en silencio se oye a tres cuartos de la distancia", NOISE.QUIET == 0.75 and is_equal_approx(NOISE.radius("wardrobe_slow"), NOISE.radius("wardrobe") * 0.75))
	put(hide.to_global(hide.exit_offset), -hide.global_basis.z, hide.to_global(Vector3(0, 0.04, 30.0)))
	creature.global_position += Vector3(0, 40, 0)
	var heard: Array = []
	var listen := func(entering: bool, _point: Vector3, quiet: bool) -> void: heard.append([entering, quiet])
	player.hiding_changed.connect(listen)
	await frames(2)
	player.enter_hide(hide)
	await seconds(1.5)
	# The key let go half way: the doors fall shut and nothing has happened.
	Input.action_press("interact")
	await seconds(1.4)
	var eased: bool = player.hidden and player.easing > 0.2 and hide.leaf_angle("left") > 0.3 and hide.leaf_angle("right") > 0.3
	Input.action_release("interact")
	await seconds(0.3)
	check("Mantener la tecla entreabre las dos hojas; soltarla a medias no saca a nadie", eased and player.hidden and player.easing == 0.0 and hide.leaf_angle("left") < 0.05)
	# Held to the end: out, and said to be the quiet way.
	Input.action_press("interact")
	var guard := 0
	while guard < 400 and player.hidden:
		await physics_frame
		guard += 1
	Input.action_release("interact")
	var held_for := float(guard) / 60.0
	await seconds(1.0)
	check("Mantenida hasta el final, sale, y sale callado", not player.hidden and held_for > hide.QUIET_EXIT - 0.2 and held_for < hide.QUIET_EXIT + 0.4 and not heard.is_empty() and heard[-1] == [false, true], "held %.2f s, heard=%s" % [held_for, str(heard)])
	# A touch is the way out it always was.
	player.global_position = hide.to_global(hide.exit_offset)
	await frames(2)
	player.enter_hide(hide)
	await seconds(1.5)
	Input.action_press("interact")
	await frames(6)
	Input.action_release("interact")
	await seconds(0.8)
	check("Un toque sale como siempre", not player.hidden and heard[-1] == [false, false], "heard=%s" % str(heard))
	player.hiding_changed.disconnect(listen)
	creature.global_position -= Vector3(0, 40, 0)

# --- The second time, the option, the tape ------------------------------------------

func again_checks() -> void:
	var player = level.player
	await fresh_floor()
	# The first of a way in is whole; the second loses its picture on landing.
	face_to_face()
	level.executions.forced = {"entry": "front", "glance": false}
	level.capture_survivor(player)
	var whole: bool = not level.tape.brief
	var first: Dictionary = await watch(SCORE.LIFT_FROM + 0.4)
	var kept: bool = not level.tape.gone and not level.tape.lost(float(level.execution.time))
	level.release_execution()
	await frames(2)
	face_to_face()
	level.executions.forced = {"entry": "front", "glance": false}
	level.capture_survivor(player)
	var short: bool = level.tape.brief
	await watch(SCORE.ARM_TIME)
	var gone: bool = level.tape.gone and level.tape.lost(float(level.execution.time))
	level.release_execution()
	await frames(2)
	check("La primera vez de una entrada se ve entera; la segunda pierde la imagen al caer la cámara", whole and kept and short and gone and float(first.landed) > 0.0)
	# Another way in is still new.
	face_to_face()
	player.rotation.y += PI
	level.executions.forced = {"entry": "back", "glance": false}
	level.capture_survivor(player)
	check("Otra entrada sigue siendo nueva", not level.tape.brief)
	level.release_execution()
	await frames(2)
	# Soft startle: no face, the picture already on the floor.
	level.settings.values["startle_soft"] = true
	face_to_face()
	level.executions.forced = {"entry": "side", "glance": false}
	level.capture_survivor(player)
	await frames(3)
	var room := staging_room()
	var floor_y: float = FLOOR.position_of(room).y
	check("Sobresaltos suaves: sin rostro, la imagen ya en el suelo", level.tape.soft and level.tape.landed_at == 0.0 and player.camera.global_position.y - floor_y < 0.6, "height=%.2f" % (player.camera.global_position.y - floor_y))
	level.release_execution()
	level.settings.values["startle_soft"] = false
	await frames(2)
	clean("Y con todo ello, limpio")
