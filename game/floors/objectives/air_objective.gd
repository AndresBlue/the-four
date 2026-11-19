extends "res://game/floors/objectives/objective.gd"
## Planta 3 of the offices, the air (spec_f1_systems section 4, remade by
## .claude/specs/cordura_y_edificio.md 3.11): the security post opened with a
## card from level 1; sat at its console, the cameras (security_cams.gd): the
## planta's plan, the eight rooms behind electric locks one of which is the air
## room, and the light of any room, LIGHTS_MOST at a time, each a decoy that
## goes out after DECOY_TIME or once she is DECOY_NEAR. The air room unlocked,
## the hatch of the main duct, the climb up into it and back, and the shaft
## ladder at its far end that ends the floor. The fans are a machine of the
## room and no step any more. The equipment looks as its references
## (spec_rediseno 6.12 and 6.14, area 5: pieces/air_equipment.gd).
const ID := &"air"
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const MAIN_DUCT := preload("res://game/world/office/main_duct_geometry.gd")
const USABLE := preload("res://game/world/interactables/office/office_usable.gd")
const MOVEMENT := preload("res://game/player/survivor_gait.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const AIR_LOOK := preload("res://game/world/office/pieces/air_equipment.gd")
const MAIL := preload("res://game/world/office/pieces/mail_equipment.gd")
const WALL := preload("res://game/world/office/pieces/wall.gd")
const MODELS := preload("res://game/world/office/office_models.gd")
## The console's monitors: the green-screen terminals of the kit (office_models
## "crt"), on its back shelf, in its frame (x across, z out of the wall).
const MONITORS := [Vector3(-0.55, 0.12, -0.05), Vector3(0.0, 0.12, -0.05), Vector3(0.55, 0.12, -0.05)]
## Its chair's middle, out from the desk's wall.
const SEAT_OUT := 1.0

const ACTIONS := ["hatch", "climb", "ladder", "post", "sit", "stand", "lock", "light", "unlit"]
const CAMS := preload("res://game/ui/security_cams.gd")
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
## The air handler's in-line fan and its round duct (tools/props/build_catalogue.gd).
const FAN_MODEL := "res://assets/props/hotel/modular_airduct_circular_01_fan.res"
const ROUND_DUCT_MODEL := "res://assets/props/hotel/modular_airduct_circular_01_duct.res"
## The post's reader.
const POST_SWIPE := 0.5
## The battery's lights at once, how long one lasts, and how near her a lit
## room puts itself out (the decoy she came to).
const LIGHTS_MOST := 4
const DECOY_TIME := 60.0
const DECOY_NEAR := 6.0
## How far from the mouth a crawler may climb back down.
const MOUTH_REACH := 1.0
## The leaf swings this far on its side hinge, over this long.
const HATCH_SWING := deg_to_rad(100.0)
const SWING_TIME := 1.0

var post_open := false
var hatch_open := false
## Per camera (manifest air.cams), its room's lock open; its doors' nodes and,
## over each outside, its pilot's lenses [red, green].
var unlocked: Array = []
var cam_doors: Array = []
var cam_pilots: Array = []
## The rooms lit from the console: room id -> session.elapsed when lit.
var lights := {}
## The seat sat at the console, -1 nobody; the local one's screen, and when
## it last stood up: the key that stands is the key that sits, and must not
## sit again in the same press.
var operator := -1
var console = null
var stood_msec := -100000
const RESIT_MS := 400
var post_door = null
## The post reader's pilot: its red lens and its green one.
var post_pilot: Array = []
## Beside the reader's white light (mail_equipment.gd card_reader()).
const PILOT_X := 0.055
const PILOT_Y := 0.235
const PILOT := Vector3(0.03, 0.03, 0.012)
## The usables: 0 the plant ladder (the hatch's release, then the climb), 1
## the climb back down at the mouth, 2 the shaft ladder, 3 the post's reader,
## 4 the console's seat, 5 the memo.
var usables: Array = []
var leaf: Node3D
var leaf_body: StaticBody3D

func manifest() -> Dictionary: return level.manifest

## Whether this floor has the duct at all (the offices, planta 3).
func built() -> bool: return manifest().has("air") and manifest().air.has("main")

func place() -> void:
	close_console()
	operator = -1
	lights.clear()
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
		wall_use(m.air.security.desk, "sit", 0.95),
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
	# The equipment (spec_rediseno 6.12 and 6.14): the post's reader and its
	# console on the desk with its monitors and its chair, the air handler and
	# its two fans' rotors, and its control box.
	var reader: Dictionary = m.air.security.reader
	var reader_at := wall_xform(MAIL.READER, spot_point(reader), spot_point(reader).y - MAIL.READER.y * 0.5, float(reader.yaw))
	equipment(MAIL.card_reader(level.hotel, MAIL.READER), reader_at)
	# Its pilot beside its white light (office_landmarks.gd): red while the
	# post is shut, green once a card has opened it (show_post()).
	var pilot_at := reader_at * Transform3D(Basis.IDENTITY, Vector3(PILOT_X, PILOT_Y - PILOT.y * 0.5, MAIL.READER.z * 0.5 - 0.002))
	post_pilot = [equipment(MAIL.lamp_lens(level.hotel, PILOT, "glow_red"), pilot_at), equipment(MAIL.lamp_lens(level.hotel, PILOT, "glow_green"), pilot_at)]
	var desk_spot: Dictionary = m.air.security.desk
	var console_at := Transform3D(Basis(Vector3.UP, float(desk_spot.yaw)), spot_point(desk_spot) + MAIN_DUCT.facing(float(desk_spot.yaw)) * AIR_LOOK.DESK_MIDDLE + Vector3(0, AIR_LOOK.DESK_TOP, 0))
	equipment(AIR_LOOK.security_console(level.hotel, AIR_LOOK.CONSOLE), console_at)
	var crt: Mesh = MODELS.mesh_of(level.hotel, "crt")
	if crt != null:
		for spot in MONITORS: equipment(crt, console_at * Transform3D(Basis.IDENTITY, spot) * MODELS.fit_of("crt", crt))
	# Its chair, turned to the desk, with no collider: whoever sits is put before it.
	var seat: Mesh = MODELS.mesh_of(level.hotel, "office_chair")
	if seat != null: equipment(seat, Transform3D(Basis(Vector3.UP, float(desk_spot.yaw) + PI), spot_point(desk_spot) + MAIN_DUCT.facing(float(desk_spot.yaw)) * SEAT_OUT) * MODELS.fit_of("office_chair", seat))
	var unit: Dictionary = m.air.unit
	var unit_face := MAIN_DUCT.facing(float(unit.yaw))
	var unit_size: Vector3 = OFFICE.AIR_UNIT
	var unit_basis := Basis(Vector3.UP, float(unit.yaw))
	var unit_middle := spot_point(unit) + unit_face * unit_size.z / 2
	var unit_body := equipment(AIR_LOOK.air_handler(level.hotel, unit_size), Transform3D(unit_basis, unit_middle))
	plate_text("CLIMATIZADORA\nAH-1", plate_spot(unit_body), float(unit.yaw), 36)
	for k in 2:
		# Each rotor on a pivot at its own middle (they stand still: the fans are no step any more).
		var pivot := Node3D.new()
		pivot.name = "FanRotor"
		pivot.transform = Transform3D(unit_basis, unit_middle + unit_basis * Vector3(-AIR_LOOK.FAN_X + k * AIR_LOOK.FAN_X * 2.0, AIR_LOOK.FAN_Y, AIR_LOOK.ROTOR_Z))
		level.hotel.add_child(pivot)
		equipment(AIR_LOOK.fan_rotor(level.hotel, AIR_LOOK.ROTOR), Transform3D(Basis.IDENTITY, Vector3(0, -AIR_LOOK.ROTOR.y * 0.5, 0)), pivot)
	var stop: Dictionary = m.air.stop
	equipment(AIR_LOOK.control_box(level.hotel, AIR_LOOK.CONTROL), wall_xform(AIR_LOOK.CONTROL, spot_point(stop), spot_point(stop).y - AIR_LOOK.CONTROL.y * 0.5, float(stop.yaw)))
	# On the handler's top, the kit's in-line fan, axis up, and its round duct
	# on to the slab (Poly Haven's circular air duct, CC0).
	if ResourceLoader.exists(FAN_MODEL) and ResourceLoader.exists(ROUND_DUCT_MODEL):
		var top := spot_point(unit) + unit_face * unit_size.z / 2 + Vector3(0, unit_size.y, 0)
		var upright := Basis(Vector3.RIGHT, -PI / 2)
		model_at(FAN_MODEL, Transform3D(upright, top + Vector3(0, 0.075, 0)))
		var duct_mesh: Mesh = load(ROUND_DUCT_MODEL)
		var piece := duct_mesh.get_aabb().size.z
		var slab := float(m.rooms[int(m.air.plant)].py) + float(m.get("plenum", OFFICE.PLENUM).get("slab", 4.4))
		var y := top.y + 0.15
		while y + piece * 0.5 < slab:
			model_at(ROUND_DUCT_MODEL, Transform3D(upright, Vector3(top.x, y + piece * 0.5, top.z)))
			y += piece
	# The instructions, pinned on the post's wall beside the console.
	var desk: Dictionary = m.air.security.desk
	# On a cork board beside the console; with no room there, over the desk's end.
	var memo_turn := Basis(Vector3.UP, float(desk.yaw))
	var memo_at := memo_place(m.rooms[int(m.air.security.room)], desk, [[-0.95, 0.95]], 1.45)
	if memo_at == Vector3.INF: memo_at = spot_point(desk) + memo_turn * Vector3(0.8, 1.6, 0.0)
	pin_memo(memo_at, float(desk.yaw))
	var reading := USABLE.new()
	reading.name = "AirUsable_memo"
	reading.level = level
	reading.handler = self
	reading.index = usables.size()
	reading.action = "read"
	reading.transform = Transform3D(memo_turn, memo_at + memo_turn.z * 0.06)
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
	# The cameras' rooms: every door of each shut and locked until the
	# console opens it.
	unlocked.clear()
	cam_doors.clear()
	cam_pilots.clear()
	for cam in m.air.get("cams", []):
		var nodes: Array = []
		var lenses: Array = []
		for door_key in cam.doors:
			var pair: PackedStringArray = String(door_key).split(":")
			var at: Vector3 = FLOOR.portal_between(m.rooms[int(pair[0])], m.rooms[int(pair[1])])
			var out_room: Dictionary = m.rooms[int(pair[1]) if int(pair[0]) == int(cam.room) else int(pair[0])]
			for door in level.hotel.doors:
				if Vector2(door.doorway.x - at.x, door.doorway.z - at.z).length() < 0.1 and absf(door.doorway.y - at.y) < 1.0:
					nodes.append(door)
					var normal: Vector3 = Basis(Vector3.UP, door.closed_rotation).z
					lenses.append(door_pilot_lenses(at, float(out_room.py), normal * signf((FLOOR.position_of(out_room) - at).dot(normal))))
					break
		cam_doors.append(nodes)
		cam_pilots.append(lenses)
		unlocked.append(false)
	for i in unlocked.size(): show_lock(i)
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
	# Its red hand wheel and its plate (spec_rediseno 6.14), swinging with it.
	var leaf_middle := Vector3(across * (size / 2 + 0.03), size / 2, 0)
	equipment(AIR_LOOK.hand_wheel(level.hotel, AIR_LOOK.WHEEL), Transform3D(Basis.IDENTITY, leaf_middle + Vector3(0, -AIR_LOOK.WHEEL.y * 0.5, 0.02 + AIR_LOOK.WHEEL.z * 0.5)), hinge)
	var leaf_sign := equipment(WALL.sign_plate(level.hotel, AIR_LOOK.HATCH_SIGN), Transform3D(Basis.IDENTITY, leaf_middle + Vector3(0, 0.15 - size / 2, 0.02 + AIR_LOOK.HATCH_SIGN.z * 0.5)), hinge)
	plate_text("COMPUERTA\nDUCTO PRINCIPAL", plate_spot(leaf_sign), 0.0, 30, PLATE_INK, hinge)
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
	# Both sides of the duct's last stretch say what it is (spec_rediseno 6.14).
	for s: float in [-1.0, 1.0]:
		var away := side * s
		var away_yaw := atan2(away.x, away.z)
		var face_at := hatch_at - out * AIR_LOOK.DUCT_SIGN_BACK + away * (size / 2 + MAIN_DUCT.SHEET)
		var duct_sign := equipment(WALL.sign_plate(level.hotel, AIR_LOOK.DUCT_SIGN), wall_xform(AIR_LOOK.DUCT_SIGN, face_at, hatch_at.y + size * 0.62 - AIR_LOOK.DUCT_SIGN.y * 0.5, away_yaw))
		plate_text("DUCTO PRINCIPAL\nAIRE DE IMPULSIÓN", plate_spot(duct_sign), away_yaw, 30)
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

## A baked model of the props pipeline, as it is.
func model_at(path: String, xform: Transform3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = load(path)
	mesh.transform = xform
	level.hotel.add_child(mesh)

## The post's door locked while the post is shut, swung open once it is not.
func show_post() -> void:
	if post_pilot.size() == 2:
		post_pilot[0].visible = not post_open
		post_pilot[1].visible = post_open
	if post_door == null: return
	post_door.locked = not post_open
	if post_open and not post_door.opened: post_door.set_state(true)
	elif not post_open and post_door.opened: post_door.set_state(false)

## A camera room's doors shut and locked until the console opens its lock,
## the pilot over each red till then and green after; opened, they are doors
## like any other (the console never locks one again: nobody is shut in).
func show_lock(i: int) -> void:
	for lenses in cam_pilots[i]:
		lenses[0].visible = not unlocked[i]
		lenses[1].visible = bool(unlocked[i])
	for door in cam_doors[i]:
		if not is_instance_valid(door): continue
		door.locked = not unlocked[i]
		if door.locked and (door.opened or door.moving): door.set_state(false)

## The camera of the air room, -1 with none.
func vent_cam() -> int:
	var cams: Array = manifest().air.get("cams", [])
	for i in cams.size():
		if int(cams[i].room) == int(manifest().air.room): return i
	return -1

func vent_open() -> bool:
	var i := vent_cam()
	return i >= 0 and i < unlocked.size() and bool(unlocked[i])

## Whether a room may be lit from the console: one of planta 3, not lit
## always (the arrival, the post).
func lightable(room_id: int) -> bool:
	var rooms: Array = manifest().rooms
	if room_id < 0 or room_id >= rooms.size(): return false
	var room: Dictionary = rooms[room_id]
	return int(room.get("wing", -1)) == 2 and not FLOOR.is_void(room) and not OFFICE.always_lit(manifest(), 2).has(room_id)

## The room a light is kept by: the air room for its plant too (one space,
## open to each other, the camera in the plant), any other its own.
func lit_key(room_id: int) -> int:
	return int(manifest().air.room) if room_id == int(manifest().air.plant) else room_id

## A kept light given or taken in its rooms.
func give_light(key: int, on: bool) -> void:
	power_room(key, on)
	if key == int(manifest().air.room): power_room(int(manifest().air.plant), on)

## A room's light given or taken (every machine): out of the dark ones while
## lit. Its power taken first: set_room_power() only acts on a change, and a
## dark room of planta 3 has its power and its lamp built out.
func power_room(room_id: int, on: bool) -> void:
	if on:
		level.hotel.set_room_power(room_id, false)
		level.hotel.dark_ids.erase(room_id)
		level.hotel.set_room_power(room_id, true)
	else:
		level.hotel.set_room_power(room_id, false)
		level.hotel.dark_ids[room_id] = true

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
		"hatch": return "ABRIR" if vent_open() and not hatch_open else ""
		"post": return "PASAR FICHA" if not post_open and has_card(seat) else ""
		"sit": return "SENTARSE" if post_open and not seated(operator) and Time.get_ticks_msec() - stood_msec > RESIT_MS else ""
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

## Whether a seat sits at the console, alive.
func seated(seat: int) -> bool:
	return seat >= 0 and seat == operator and int(level.session.participants.get(seat, level.session.Life.DEAD)) != level.session.Life.DEAD

## What the host checks before anybody's use is applied. The console's own
## (a lock by its camera, a light by its room) only from whoever sits there.
func allow(action: String, index: int, seat: int, body) -> bool:
	if not built() or body == null or not ACTIONS.has(action): return false
	match action:
		"stand": return seated(seat)
		"lock": return seated(seat) and index >= 0 and index < unlocked.size() and not bool(unlocked[index])
		"light": return seated(seat) and lightable(lit_key(index)) and (lights.has(lit_key(index)) or lights.size() < LIGHTS_MOST)
		"unlit": return false
	if index < 0 or index >= usables.size(): return false
	if int(level.session.participants.get(seat, level.session.Life.DEAD)) == level.session.Life.DEAD: return false
	if bool(body.get("hidden")) or level.lifts.riding.has(seat): return false
	if FLOOR.planta_of(body.global_position.y) != 2: return false
	var usable = usables[index]
	var reach := USE_REACH + (0.0 if body == level.player else SLACK)
	if body.global_position.distance_to(usable.global_position) > reach + 1.2: return false
	if String(usable.action) != action: return false
	match action:
		"hatch": return vent_open() and not hatch_open
		"post": return not post_open and has_card(seat)
		"sit": return post_open and not seated(operator)
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
		"sit":
			operator = seat
			# The test bots have no screen (as at the keypad, code_verdict()):
			# sat, they open the air room and stand up again.
			if level.bot_match and level.body_of_seat(seat) != level.player:
				var i := vent_cam()
				if i >= 0:
					unlocked[i] = true
					show_lock(i)
				operator = -1
			elif seat == level.player.slot: open_console()
		"stand":
			if operator == seat: operator = -1
			if seat == level.player.slot: close_console()
		"lock":
			unlocked[index] = true
			show_lock(index)
			if not quiet and not cam_doors[index].is_empty() and is_instance_valid(cam_doors[index][0]): sound_at("lever_2.wav", cam_doors[index][0].doorway + Vector3(0, 1.2, 0), -6.0)
		"light":
			var key := lit_key(index)
			if lights.has(key):
				lights.erase(key)
				give_light(key, false)
			else:
				lights[key] = float(level.session.elapsed)
				give_light(key, true)
				if not level.net.is_client(): lure(key)
			if not quiet: sound_at("lever_1.wav", usables[4].global_position, -10.0)
		"unlit":
			if lights.has(index):
				lights.erase(index)
				give_light(index, false)
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
	return memo(MEMO_ID, "VIGILANCIA", ["CIERRES ELÉCTRICOS: SALAS TÉCNICAS Y DE ARCHIVO.", "", "BATERÍA DE EMERGENCIA: %d LUCES A LA VEZ, %d SEGUNDOS CADA UNA." % [LIGHTS_MOST, int(DECOY_TIME)]], "Seguridad", "Puesto de vigilancia")

## The local player sat at the console: held, crouched at the desk, and the
## cameras on its screen.
func open_console() -> void:
	var player = level.player
	player.reading = true
	MOVEMENT.set_crouch(player, true)
	var stand: Vector3 = usables[4].stand
	player.transit = {"from": player.global_position, "to": stand, "yaw_from": player.rotation.y, "yaw_to": usables[4].face_yaw, "time": 0.0, "length": 0.3}
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# In the interface's own layer: under the tape, and under the menus.
	if console == null:
		console = CAMS.new()
		console.setup(level, self)
		level.ui.add_child(console)

## The local player up from the console at once (a pause, a capture, the floor
## over), and the host told.
func leave_console() -> void:
	if console == null: return
	close_console()
	level.match_net.use_office(ID, "stand", 4)

func close_console() -> void:
	if console != null:
		console.queue_free()
		console = null
		stood_msec = Time.get_ticks_msec()
		level.cams_eye = Vector3.INF
		# The floor round the player again at once, not at the next round.
		level.visibility_clock = 1.0
		level.player.reading = false
		MOVEMENT.set_crouch(level.player, false)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## The host: a room lit from the console is a presence she may go and look
## at, as likely as her difficulty says (tuning "decoy"); only the AI's.
func lure(room_id: int) -> void:
	var creature = level.get("creature")
	if creature == null or not creature.has_method("investigate") or String(creature.get("control")) != "ai": return
	var odds := float(creature.get("tuning").get("decoy", 0.0)) if creature.get("tuning") is Dictionary else 0.0
	if odds >= 1.0 or randf() < odds: creature.investigate(FLOOR.position_of(manifest().rooms[room_id]) + Vector3(0, 1.0, 0))

## Whether a seat holds a card from level 1 (the files handler's).
func has_card(seat: int) -> bool:
	var files = level.objective(&"files")
	return files != null and files.has_card(seat)

## The host: a lit room goes out after DECOY_TIME, or once she stands within
## DECOY_NEAR of it; whoever sat and died, or left the game, stands up.
func tick(_delta: float) -> void:
	if not built() or level.net.is_client(): return
	if operator >= 0 and (not seated(operator) or level.match_net.away.has(operator)):
		apply("stand", 4, operator, {}, false)
		level.match_net.tell_office(ID, "stand", 4, operator, {})
	if lights.is_empty(): return
	# (The null creature of the floor without her is nowhere.)
	var creature = level.get("creature")
	var her: Vector3 = creature.global_position if creature is Node3D and creature.is_inside_tree() and creature.has_method("kind_id") and creature.kind_id() != &"none" else Vector3.INF
	for room_id in lights.keys():
		var middle := FLOOR.position_of(manifest().rooms[int(room_id)])
		# Over its ceiling counts: on its planta, near it in plan.
		var near: bool = her != Vector3.INF and FLOOR.planta_of(her.y) == FLOOR.planta_of(middle.y + 1.0) and Vector2(her.x - middle.x, her.z - middle.z).length() < DECOY_NEAR
		if near or float(level.session.elapsed) - float(lights[room_id]) >= DECOY_TIME:
			apply("unlit", int(room_id), -1, {}, false)
			level.match_net.tell_office(ID, "unlit", int(room_id), -1, {})

## The bots: a card holder opens the post, somebody sits at the console
## (which opens the air room for a bot), the hatch; then each climbs up,
## crawls the duct to the landing, and once the quota is there the ladder down.
func bot_errands(team) -> Array:
	var errands: Array = []
	if not built() or level.session.stage != 3 or usables.is_empty(): return errands
	if not post_open:
		for brain in team.brains:
			if brain.alive() and has_card(brain.seat):
				errands.append(team.office_task("air:post", usables[3], brain.seat))
				break
		return errands
	if not vent_open():
		if not seated(operator): errands.append(team.office_task("air:sit", usables[4]))
		return errands
	if not hatch_open:
		errands.append(team.office_task("air:hatch", usables[0]))
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
	return {"ready": hatch_open, "done": int(post_open) + int(vent_open()) + int(hatch_open), "needed": 3, "kind": "air", "lines": [["LUCES", "%d / %d" % [lights.size(), LIGHTS_MOST]]], "extra": {}}

func goal_points(stage: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not built() or not level.kind.asks(stage, String(ID)): return points
	var m := manifest()
	if not post_open: points.append(usables[3].global_position)
	elif not vent_open(): points.append(usables[4].global_position)
	points.append(MAIN_DUCT.foot(m).origin)
	var p: Array = m.air.shaft.point
	points.append(Vector3(float(p[0]), MAIN_DUCT.floor_y(m), float(p[2])))
	return points

## A stage given back: the hatch shut, and whoever is in the duct put back at
## the ladder's foot (each machine its own player).
func reset() -> void:
	close_console()
	operator = -1
	for room_id in lights.keys(): give_light(int(room_id), false)
	lights.clear()
	for i in unlocked.size():
		unlocked[i] = false
		show_lock(i)
	post_open = false
	show_post()
	hatch_open = false
	show_hatch(false)
	if built() and crawling_at(level.player.global_position):
		level.player.transit = {}
		level.player.global_position = MAIN_DUCT.foot(manifest()).origin + Vector3(0, 0.04, 0)

func snapshotted() -> bool: return true

## The console's operator is not kept: whoever comes back stands.
func snapshot() -> Dictionary: return {"post": post_open, "hatch": hatch_open, "unlocked": unlocked.duplicate(), "lights": lights.duplicate()}

func restore(data: Dictionary) -> void:
	post_open = bool(data.get("post", false))
	hatch_open = bool(data.get("hatch", false))
	var kept: Array = data.get("unlocked", [])
	for i in unlocked.size():
		unlocked[i] = i < kept.size() and bool(kept[i])
		show_lock(i)
	for room_id in lights.keys(): give_light(int(room_id), false)
	lights.clear()
	var lit: Dictionary = data.get("lights", {})
	for room_id in lit:
		lights[int(room_id)] = float(lit[room_id])
		give_light(int(room_id), true)
	show_post()
	show_hatch(false)
