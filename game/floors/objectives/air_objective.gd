extends "res://game/floors/objectives/objective.gd"
## Planta 3 of the offices, the air (spec_f1_systems section 4): the hatch of
## the main duct, the climb up into it and back, and the shaft ladder at its far
## end that ends the floor. The post, its console and the fans are not built
## yet: until they are, the lockdown counts as lifted (`released`) and the
## hatch opens whenever nothing runs.
const ID := &"air"
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const MAIN_DUCT := preload("res://game/world/office/main_duct_geometry.gd")
const USABLE := preload("res://game/world/interactables/office/office_usable.gd")
const MOVEMENT := preload("res://game/player/survivor_gait.gd")

const ACTIONS := ["hatch", "climb", "ladder"]
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
## How far from the mouth a crawler may climb back down.
const MOUTH_REACH := 1.0
## The leaf swings this far on its side hinge, over this long.
const HATCH_SWING := deg_to_rad(100.0)
const SWING_TIME := 1.0

## The lockdown lifted (the fans started once): true until the post exists.
var released := true
var hatch_open := false
## The usables: 0 the plant ladder (the hatch's release, then the climb), 1
## the climb back down at the mouth, 2 the shaft ladder.
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
		"hatch": return "ABRIR" if released and not hatch_open else ""
		"climb":
			if int(usable.index) == 0: return "ENTRAR" if hatch_open and not crawling_at(body.global_position) else ""
			return "BAJAR" if crawling_at(body.global_position) and body.global_position.distance_to(MAIN_DUCT.mouth(manifest()).origin) <= MOUTH_REACH else ""
		"ladder": return "BAJAR" if in_shaft() >= level.session.minimum_survivors() else ""
	return ""

func hold_of(usable, _seat: int) -> float:
	match String(usable.action):
		"hatch": return HATCH_TIME
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
		"hatch": return released and not hatch_open
		"climb":
			if index == 0: return hatch_open and not crawling_at(body.global_position)
			return crawling_at(body.global_position)
		"ladder": return in_shaft() >= level.session.minimum_survivors()
	return false

## Applied on every machine (the host first): the hatch swings, a climber's
## own machine moves it, and the shaft ladder takes the floor with it.
func apply(action: String, index: int, seat: int, _data: Dictionary, _quiet: bool) -> Dictionary:
	match action:
		"hatch":
			hatch_open = true
			show_hatch(true)
		"climb":
			if seat == level.player.slot and level.body_of_seat(seat) == level.player: climb(index)
		"ladder":
			if not level.net.is_client(): level.lifts.leave_floor()
	return {}

## The local player up the ladder into the duct, or back down to its foot.
func climb(index: int) -> void:
	var player = level.player
	var to := MAIN_DUCT.mouth(manifest()) if index == 0 else MAIN_DUCT.foot(manifest())
	if index == 0: MOVEMENT.set_crouch(player, true)
	player.transit = {"from": player.global_position, "to": to.origin + Vector3(0, 0.04, 0), "yaw_from": player.rotation.y, "yaw_to": to.basis.get_euler().y, "time": 0.0, "length": CLIMB_UP if index == 0 else CLIMB_DOWN}

func progress(stage: int) -> Dictionary:
	if not built() or not level.kind.asks(stage, String(ID)): return idle()
	return {"ready": hatch_open, "done": int(released) * 2 + int(hatch_open), "needed": 3, "kind": "air", "lines": [], "extra": {}}

func goal_points(stage: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not built() or not level.kind.asks(stage, String(ID)): return points
	var m := manifest()
	points.append(MAIN_DUCT.foot(m).origin)
	var p: Array = m.air.shaft.point
	points.append(Vector3(float(p[0]), MAIN_DUCT.floor_y(m), float(p[2])))
	return points

## A stage given back: the hatch shut, and whoever is in the duct put back at
## the ladder's foot (each machine its own player).
func reset() -> void:
	hatch_open = false
	show_hatch(false)
	if built() and crawling_at(level.player.global_position):
		level.player.transit = {}
		level.player.global_position = MAIN_DUCT.foot(manifest()).origin + Vector3(0, 0.04, 0)

func snapshot() -> Dictionary: return {"released": released, "hatch": hatch_open}

func restore(data: Dictionary) -> void:
	released = bool(data.get("released", released))
	hatch_open = bool(data.get("hatch", false))
	show_hatch(false)
