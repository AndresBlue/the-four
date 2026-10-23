extends "res://game/floors/objectives/objective.gd"
## Planta 3 of the offices, the air (spec_f1_systems section 4): the hatch of
## the main duct, the climb up into it and back, and the shaft ladder at its far
## end that ends the floor; before that, the security post opened with a
## card from level 1, its console starting the fans on the battery's few
## charges (which lifts the lockdown), and the isolator by the air handler
## that stops them: the hatch opens only once they have run and stand still.
## Not built yet: the fans' mask on what is heard, the kit's models.
const ID := &"air"
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const MAIN_DUCT := preload("res://game/world/office/main_duct_geometry.gd")
const USABLE := preload("res://game/world/interactables/office/office_usable.gd")
const MOVEMENT := preload("res://game/player/survivor_gait.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")

const ACTIONS := ["hatch", "climb", "ladder", "post", "start", "stop"]
## The instructions memo's paper id.
const MEMO_ID := 2001
## How long each is held, and how long a climb takes.
const HATCH_TIME := 2.0
const CLIMB_HOLD := 0.5
const LADDER_HOLD := 1.2
const CLIMB_UP := 2.4
const CLIMB_DOWN := 2.0
## How near a usable a body has to be, and the host's slack for a guest's
## copy running behind (lifts.RIDE_SLACK).
const USE_REACH := 2.5
const SLACK := 0.5
## The post's reader, the console and the isolator; the fans' spin up and
## down (s), and how much of every sound on planta 3 they cover.
const POST_SWIPE := 0.5
const START_HOLD := 1.0
const STOP_HOLD := 1.0
const FAN_SPIN := 2.5
const AIR_MASK := 0.65
## How far from the mouth a crawler may climb back down.
const MOUTH_REACH := 1.0
## The leaf swings this far on its side hinge, over this long.
const HATCH_SWING := deg_to_rad(100.0)
const SWING_TIME := 1.0

## The battery's charges and how long the fans run on one (tuning().fan_charges
## and fan_time to come, 1.8: Equilibrada's).
var charges := 2
var fan_time := 80.0
## session.elapsed when the fans stop; 0: stopped.
var running_until := 0.0
## The lockdown lifted: the fans have been started once.
var released := false
var post_open := false
var hatch_open := false
## 0..1, how far the fans are running, eased (every machine).
var spin := 0.0
var post_door = null
var rotors: Array = []
## The fans' roar at the air handler while they run.
var fans_voice = null
## The usables: 0 the plant ladder (the hatch's release, then the climb), 1
## the climb back down at the mouth, 2 the shaft ladder, 3 the post's reader,
## 4 the console, 5 the isolator.
var usables: Array = []
var leaf: Node3D
var leaf_body: StaticBody3D

func manifest() -> Dictionary: return level.manifest

## Whether this floor has the duct at all (the offices, planta 3).
func built() -> bool: return manifest().has("air") and manifest().air.has("main")

func place() -> void:
	usables.clear()
	if not built(): return
	var m := manifest()
	var out := MAIN_DUCT.facing(float(m.air.hatch.yaw))
	var hatch_at := MAIN_DUCT.hatch_floor(m)
	var size := MAIN_DUCT.main(m)
	var plant_y := float(m.rooms[int(m.air.plant)].py)
	var foot := MAIN_DUCT.foot(m)
	var mouth := MAIN_DUCT.mouth(m)
	var ladder_p: Array = m.air.shaft.ladder.point
	var spots := [
		[Transform3D(Basis(Vector3.UP, float(m.air.hatch.yaw)), Vector3(hatch_at.x, plant_y + 1.2, hatch_at.z) + out * float(MAIN_DUCT.LADDER.out)), "hatch", foot.origin, foot.basis.get_euler().y],
		[Transform3D(Basis(Vector3.UP, float(m.air.hatch.yaw) + PI), hatch_at - out * 0.05 + Vector3(0, 0.45, 0)), "climb", Vector3.INF, NAN],
		[Transform3D(Basis(Vector3.UP, float(m.air.shaft.ladder.yaw)), Vector3(float(ladder_p[0]), MAIN_DUCT.floor_y(m) + 0.9, float(ladder_p[2]))), "ladder", Vector3.INF, NAN],
		wall_use(m.air.security.reader, "post", 0.0),
		wall_use(m.air.security.desk, "start", 0.95),
		wall_use(m.air.stop, "stop", 0.0),
	]
	for i in spots.size():
		var usable := USABLE.new()
		usable.name = "AirUsable_%d" % i
		usable.level = level
		usable.handler = self
		usable.index = i
		usable.action = String(spots[i][1])
		usable.stand = spots[i][2]
		usable.face_yaw = spots[i][3]
		usable.transform = spots[i][0]
		level.hotel.add_child(usable)
		usables.append(usable)
	# The stand-ins: the reader, the console on the post's desk, the air
	# handler with its two fan rotors, and the isolator.
	box_at(spot_point(m.air.security.reader), float(m.air.security.reader.yaw), Vector3(0.12, 0.2, 0.06), Color("2c2e30"))
	box_at(spot_point(m.air.security.desk) + Vector3(0, 0.88, 0) + MAIN_DUCT.facing(float(m.air.security.desk.yaw)) * 0.22, float(m.air.security.desk.yaw), Vector3(0.6, 0.25, 0.4), Color("4d5244"))
	var unit: Dictionary = m.air.unit
	var unit_face := MAIN_DUCT.facing(float(unit.yaw))
	var unit_size: Vector3 = OFFICE.AIR_UNIT
	box_at(spot_point(unit) + unit_face * unit_size.z / 2 + Vector3(0, unit_size.y / 2, 0), float(unit.yaw), unit_size, Color("8d9296"))
	for k in 2:
		var side_way := Basis(Vector3.UP, float(unit.yaw)) * Vector3(-0.7 + k * 1.4, 0, 0)
		rotors.append(box_at(spot_point(unit) + unit_face * (unit_size.z + 0.03) + side_way + Vector3(0, 1.2, 0), float(unit.yaw), Vector3(0.9, 0.08, 0.02), Color("2b2b28")))
	box_at(spot_point(m.air.stop), float(m.air.stop.yaw), Vector3(0.2, 0.3, 0.12), Color("a3271f"))
	# The instructions, pinned on the post's wall beside the console.
	var desk: Dictionary = m.air.security.desk
	var memo_at := spot_point(desk) + Basis(Vector3.UP, float(desk.yaw)) * Vector3(0.8, 1.45, 0.01)
	pin_memo(memo_at, float(desk.yaw))
	var reading := USABLE.new()
	reading.name = "AirUsable_memo"
	reading.level = level
	reading.handler = self
	reading.index = 6
	reading.action = "read"
	reading.transform = Transform3D(Basis(Vector3.UP, float(desk.yaw)), memo_at)
	level.hotel.add_child(reading)
	usables.append(reading)
	# The post's door: shut and locked until a card goes through its reader.
	var key: PackedStringArray = String(m.air.security.door).split(":")
	if key.size() == 2:
		var portal: Vector3 = FLOOR.portal_between(m.rooms[int(key[0])], m.rooms[int(key[1])])
		for door in level.hotel.doors:
			if Vector2(door.doorway.x - portal.x, door.doorway.z - portal.z).length() < 0.1 and absf(door.doorway.y - portal.y) < 1.0:
				post_door = door
				break
	show_post()
	# The hatch's leaf: a framed galvanised panel shutting the duct's end, on
	# a hinge at its side.
	var side := Vector3(out.z, 0, -out.x)
	var hinge := Node3D.new()
	hinge.name = "HatchLeaf"
	hinge.position = hatch_at + side * (size / 2 + 0.03) + out * 0.04
	hinge.rotation.y = float(m.air.hatch.yaw)
	level.hotel.add_child(hinge)
	var panel := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(size + 0.06, size + 0.06, 0.04)
	panel.mesh = plate
	# The hinge's frame: +Z out of the duct, the leaf reaching across -X.
	var across := -1.0 if Basis(Vector3.UP, float(m.air.hatch.yaw)).x.dot(side) > 0.0 else 1.0
	panel.position = Vector3(across * (size / 2 + 0.03), size / 2, 0)
	panel.material_override = MAIN_DUCT.material_of(level.hotel, "galvanized")
	hinge.add_child(panel)
	leaf_body = StaticBody3D.new()
	leaf_body.collision_layer = 1
	leaf_body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = plate.size
	shape.shape = cube
	shape.position = panel.position
	leaf_body.add_child(shape)
	hinge.add_child(leaf_body)
	leaf = hinge
	leaf.set_meta("across", across)
	show_hatch(false)

## A usable on a wall spot (its point, facing into the room), the body stood
## in front of it, facing it.
func wall_use(spot: Dictionary, action: String, up: float) -> Array:
	var face := MAIN_DUCT.facing(float(spot.yaw))
	var at := spot_point(spot) + Vector3(0, up, 0)
	var ground := FLOOR.planta_y(FLOOR.planta_of(at.y))
	return [Transform3D(Basis(Vector3.UP, float(spot.yaw)), at), action, Vector3(at.x, ground, at.z) + face * 0.6, MAIN_DUCT.look_yaw(-face)]

func spot_point(spot: Dictionary) -> Vector3:
	return Vector3(float(spot.point[0]), float(spot.point[1]), float(spot.point[2]))

## A plain box standing in for a model to come.
func box_at(at: Vector3, yaw: float, size: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.6
	mesh.material_override = material
	mesh.position = at
	mesh.rotation.y = yaw
	level.hotel.add_child(mesh)
	return mesh

## The post's door locked while the post is shut, swung open once it is not.
func show_post() -> void:
	if post_door == null: return
	post_door.locked = not post_open
	if post_open and not post_door.opened: post_door.set_state(true)
	elif not post_open and post_door.opened: post_door.set_state(false)

func running() -> bool: return running_until > 0.0

## How much of every sound at a point the fans cover (phase 3 hooks it to
## the creature's hearing and world_audio), and whether her ducts are shut.
func sound_mask(point: Vector3) -> float:
	return AIR_MASK * spin if FLOOR.planta_of(point.y) == 2 else 0.0

func ducts_closed() -> bool: return spin > 0.5

## The leaf shut or swung open, now or over SWING_TIME.
func show_hatch(swing: bool) -> void:
	if not is_instance_valid(leaf): return
	var yaw := float(manifest().air.hatch.yaw) + (float(leaf.get_meta("across")) * -HATCH_SWING if hatch_open else 0.0)
	if swing: leaf.create_tween().tween_property(leaf, "rotation:y", yaw, SWING_TIME)
	else: leaf.rotation.y = yaw
	if is_instance_valid(leaf_body): leaf_body.process_mode = Node.PROCESS_MODE_DISABLED if hatch_open else Node.PROCESS_MODE_INHERIT
	if not usables.is_empty(): usables[0].action = "climb" if hatch_open else "hatch"

## Whether a body's feet are in the duct.
func crawling_at(point: Vector3) -> bool: return built() and MAIN_DUCT.inside(manifest(), point, 0.1)

func word_of(usable, seat: int) -> String:
	var body = level.body_of_seat(seat)
	if body == null: return ""
	match String(usable.action):
		"hatch": return "ABRIR" if released and spin == 0.0 and not running() and not hatch_open else ""
		"post": return "PASAR FICHA" if not post_open and has_card(seat) else ""
		"start": return "ENCENDER" if charges > 0 and not running() else ""
		"stop": return "PARAR" if running() else ""
		"read": return "LEER"
		"climb":
			if int(usable.index) == 0: return "ENTRAR" if hatch_open and not crawling_at(body.global_position) else ""
			return "BAJAR" if crawling_at(body.global_position) and body.global_position.distance_to(MAIN_DUCT.mouth(manifest()).origin) <= MOUTH_REACH else ""
		"ladder": return "BAJAR" if in_shaft() >= level.session.minimum_survivors() else ""
	return ""

func hold_of(usable, _seat: int) -> float:
	match String(usable.action):
		"hatch": return HATCH_TIME
		"post": return POST_SWIPE
		"start": return START_HOLD
		"stop": return STOP_HOLD
		"climb": return CLIMB_HOLD
		"ladder": return LADDER_HOLD
	return 0.0

func begin_use(_usable, _seat: int) -> void: pass

func holding(_usable, _seat: int, _fraction: float) -> void: pass

func cancel_use(_usable, _seat: int) -> void: pass

func refused(_action: String, _index: int, _seat: int) -> void: pass

## The living survivors standing on the shaft's landing.
func in_shaft() -> int:
	var count := 0
	for body in level.survivors():
		if int(level.session.participants.get(int(body.slot), level.session.Life.DEAD)) == level.session.Life.DEAD: continue
		if MAIN_DUCT.on_landing(manifest(), body.global_position): count += 1
	return count

## What the host checks before anybody's use is applied.
func allow(action: String, index: int, seat: int, body) -> bool:
	if not built() or body == null or index < 0 or index >= usables.size() or not ACTIONS.has(action): return false
	if int(level.session.participants.get(seat, level.session.Life.DEAD)) == level.session.Life.DEAD: return false
	if bool(body.get("hidden")) or level.lifts.riding.has(seat): return false
	if FLOOR.planta_of(body.global_position.y) != 2: return false
	var usable = usables[index]
	var reach := USE_REACH + (0.0 if body == level.player else SLACK)
	if body.global_position.distance_to(usable.global_position) > reach + 1.2: return false
	if String(usable.action) != action: return false
	match action:
		"hatch": return released and spin == 0.0 and not running() and not hatch_open
		"post": return not post_open and has_card(seat)
		"start": return charges > 0 and not running()
		"stop": return running()
		"climb":
			if index == 0: return hatch_open and not crawling_at(body.global_position)
			return crawling_at(body.global_position)
		"ladder": return in_shaft() >= level.session.minimum_survivors()
	return false

## Applied on every machine (the host first): the hatch swings, a climber's
## own machine moves it, and the shaft ladder takes the floor with it.
func apply(action: String, index: int, seat: int, _data: Dictionary, quiet: bool) -> Dictionary:
	match action:
		"hatch":
			hatch_open = true
			show_hatch(true)
			if not quiet: sound_at("hatch.wav", MAIN_DUCT.hatch_floor(manifest()), 0.0)
		"post":
			post_open = true
			show_post()
			if not quiet: sound_at("lever_1.wav", usables[3].global_position, -4.0)
		"start":
			charges -= 1
			running_until = float(level.session.elapsed) + fan_time
			released = true
			if not quiet:
				stop_loop(fans_voice)
				fans_voice = loop_at("fans.wav", usables[5].global_position + Vector3(0, 1.0, 0), 0.0)
		"stop", "stopped":
			running_until = 0.0
			stop_loop(fans_voice)
			fans_voice = null
		"climb":
			if not quiet: sound_at("ladder.wav", MAIN_DUCT.foot(manifest()).origin + Vector3(0, 1.5, 0), -4.0)
			var climber = level.body_of_seat(seat)
			if climber == level.player and seat == level.player.slot: climb(index)
			# A bot's body (offline: this machine owns it) is put up there.
			elif climber != null and level.bot_match and climber.has_method("place"):
				var to := MAIN_DUCT.mouth(manifest()) if index == 0 else MAIN_DUCT.foot(manifest())
				climber.place(to.origin + Vector3(0, 0.05, 0), to.basis.get_euler().y)
		"ladder":
			if not level.net.is_client(): level.lifts.leave_floor()
	return {}

## The post's instructions.
func paper_of(_index: int) -> Dictionary:
	return memo(MEMO_ID, "VENTILACIÓN", ["1. PASE LA FICHA.", "2. ARRANQUE DESDE ESTA CONSOLA. BATERÍA: %d CARGAS." % charges, "3. CON LOS VENTILADORES EN MARCHA NO SE ABRE LA COMPUERTA."])

## Whether a seat holds a card from level 1 (the files handler's).
func has_card(seat: int) -> bool:
	var files = level.objective(&"files")
	return files != null and files.has_card(seat)

## Every machine: the fans ease up and down; the host stops them when their
## time is out.
func tick(delta: float) -> void:
	if not built(): return
	spin = move_toward(spin, 1.0 if running() else 0.0, delta / FAN_SPIN)
	for rotor in rotors: rotor.rotate_object_local(Vector3(0, 0, 1), spin * delta * 18.0)
	if not level.net.is_client() and running() and float(level.session.elapsed) >= running_until:
		apply("stopped", 4, -1, {}, false)
		level.match_net.tell_office(ID, "stopped", 4, -1, {})

## The bots: a card holder opens the post and starts the fans, somebody
## stops them, the hatch; then each climbs up, crawls the duct to the landing,
## and once the quota is there the ladder down.
func bot_errands(team) -> Array:
	var errands: Array = []
	if not built() or level.session.stage != 3 or usables.is_empty(): return errands
	if not post_open:
		for brain in team.brains:
			if brain.alive() and has_card(brain.seat):
				errands.append(team.office_task("air:post", usables[3], brain.seat))
				break
		return errands
	if not released:
		if charges > 0 and not running(): errands.append(team.office_task("air:start", usables[4]))
		return errands
	if running():
		errands.append(team.office_task("air:stop", usables[5]))
		return errands
	if not hatch_open:
		if spin == 0.0: errands.append(team.office_task("air:hatch", usables[0]))
		return errands
	var m := manifest()
	var line: Array = []
	for n in m.air.main.nodes.slice(1):
		var node: Array = m.ducts.nodes[int(n)]
		line.append(Vector3(float(node[0]), MAIN_DUCT.floor_y(m) + 0.05, float(node[2])))
	var r: Array = m.air.shaft.rect
	line.append(Vector3(float(r[0]), MAIN_DUCT.floor_y(m) + 0.05, float(r[1])))
	var ladder_given := false
	for brain in team.brains:
		if not brain.alive(): continue
		var at: Vector3 = brain.body.global_position
		if MAIN_DUCT.on_landing(m, at):
			# One goes down the ladder for all; the others wait on the landing.
			if in_shaft() >= level.session.minimum_survivors() and not ladder_given:
				ladder_given = true
				errands.append({"kind": "use", "key": "air:ladder", "label": "la escalerilla del pozo", "node": usables[2], "aim": usables[2].global_position, "stands": [at], "reached": true, "seat": brain.seat})
			# Waiting on the landing for the others, off the navigation.
			else: errands.append({"kind": "hold", "key": "air:wait:%d" % brain.seat, "label": "el pozo", "stands": [at], "seat": brain.seat})
		elif crawling_at(at):
			errands.append({"kind": "route", "key": "air:crawl:%d" % brain.seat, "label": "el ducto", "route": [MAIN_DUCT.mouth(m).origin + Vector3(0, 0.05, 0)] + line, "stands": [at], "seat": brain.seat})
		else:
			errands.append(team.office_task("air:climb:%d" % brain.seat, usables[0], brain.seat))
	return errands

## The local player up the ladder into the duct, or back down to its foot.
func climb(index: int) -> void:
	var player = level.player
	var to := MAIN_DUCT.mouth(manifest()) if index == 0 else MAIN_DUCT.foot(manifest())
	if index == 0: MOVEMENT.set_crouch(player, true)
	player.transit = {"from": player.global_position, "to": to.origin + Vector3(0, 0.04, 0), "yaw_from": player.rotation.y, "yaw_to": to.basis.get_euler().y, "time": 0.0, "length": CLIMB_UP if index == 0 else CLIMB_DOWN}

func progress(stage: int) -> Dictionary:
	if not built() or not level.kind.asks(stage, String(ID)): return idle()
	return {"ready": hatch_open, "done": int(post_open) + int(released) + int(hatch_open), "needed": 3, "kind": "air", "lines": [["CARGAS", "%d" % charges]], "extra": {}}

func goal_points(stage: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not built() or not level.kind.asks(stage, String(ID)): return points
	var m := manifest()
	if not post_open: points.append(usables[3].global_position)
	elif not released: points.append(usables[4].global_position)
	elif running(): points.append(usables[5].global_position)
	points.append(MAIN_DUCT.foot(m).origin)
	var p: Array = m.air.shaft.point
	points.append(Vector3(float(p[0]), MAIN_DUCT.floor_y(m), float(p[2])))
	return points

## A stage given back: the hatch shut, and whoever is in the duct put back at
## the ladder's foot (each machine its own player).
func reset() -> void:
	stop_loop(fans_voice)
	fans_voice = null
	charges = 2
	running_until = 0.0
	spin = 0.0
	released = false
	post_open = false
	show_post()
	hatch_open = false
	show_hatch(false)
	if built() and crawling_at(level.player.global_position):
		level.player.transit = {}
		level.player.global_position = MAIN_DUCT.foot(manifest()).origin + Vector3(0, 0.04, 0)

func snapshotted() -> bool: return true

func snapshot() -> Dictionary: return {"charges": charges, "running_until": running_until, "released": released, "post": post_open, "hatch": hatch_open}

func restore(data: Dictionary) -> void:
	charges = int(data.get("charges", charges))
	running_until = float(data.get("running_until", 0.0))
	released = bool(data.get("released", false))
	post_open = bool(data.get("post", false))
	hatch_open = bool(data.get("hatch", false))
	show_post()
	show_hatch(false)
