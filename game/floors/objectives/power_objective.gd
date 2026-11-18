extends "res://game/floors/objectives/objective.gd"
## Planta 2 of the offices, the power (spec_f1_systems section 3, remade by
## .claude/specs/cordura_y_edificio.md 3.10): the board in the electrical room
## has a lever per sector, up and down at will; the backup system takes BACKUP
## sectors at once and a lever more trips them all, the planta back to its
## emergency lights. The minuteros light their corridor for a while. The
## maneuver room's door opens only with its sector's power, slowly on its
## motor, and once started it ends open whatever the board does; the lever
## inside frees the freight lift at once. Beside the board, its sign says what
## the backup takes. The board, its levers and the minuteros look as their
## reference (spec_rediseno 6.13, area 5: pieces/power_equipment.gd).
const ID := &"power"
const USABLE := preload("res://game/world/interactables/office/office_usable.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const POWER_LOOK := preload("res://game/world/office/pieces/power_equipment.gd")
const MAIL := preload("res://game/world/office/pieces/mail_equipment.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")

const ACTIONS := ["lever", "switch", "door", "lift"]
## The legend memo's paper id, clear of the hotel's hints and the cards.
const MEMO_ID := 2000
## The sectors the backup system takes at once, on every difficulty.
const BACKUP := 3
const LIFT_HOLD := 1.0
const USE_REACH := 2.5
const SLACK := 0.5
## The board (spec 3.4): back plate, lever pivots and their pitch.
const BOARD := Vector3(2.6, 1.9, 0.12)
const LEVER_Y := 1.35
const LEVER_PITCH := 0.3
const LEVER_SWING := deg_to_rad(70.0)
## The backup cabinet's three lamps (power_board(), the old red lever's
## cabinet): one lit for each sector up.
const BACKUP_LENS := Vector3(0.026, 0.026, 0.012)
const BACKUP_LENS_Y := 1.66
## The maneuver room's door: how long its motor takes. Its pilot over the
## frame's head outside (objective.door_pilot_lenses()) is red without power,
## green with it.
const DOOR_TIME := 4.5
## Its button is the whole leaf from the corridor (a box over it, just out):
## aimed anywhere at the door, E is the motor's, never the locked leaf's.
const DOOR_BOX := Vector3(1.1, 2.2, 0.3)
## The lift's cabinet in the maneuver room and its lever beside it.
const LIFT_LEVER := Vector3(0.45, 1.35, 0.12)

## power.circuits sorted by lever.
var zones: Array = []
var lit_always: Array = []
## Zone indices up, oldest first.
var on_order: Array = []
var switch_time := 75.0
## Per power.timers entry, session.elapsed when it goes out (0: out).
var switch_until: Array = []
## The maneuver door's motor has run (or is running), and the lift is freed.
var motor_started := false
var freed := false
## Room -> the power last given.
var applied := {}
## The usables: 0..n-1 the zones' levers, then the minuteros, the maneuver
## door, the lift's lever and the memo.
var usables: Array = []
var handles: Array = []
var pilots: Array = []
## Per minutero, its pilot's lenses [lit, dark], shown in turn with its pilot.
var pilot_lenses: Array = []
## Per backup lamp, [lit, dark].
var backup_lenses: Array = []
var maneuver_room := -1
var motor_door = null
## The door's pilot: its red lens, its green one and its glow.
var door_pilot: Array = []
var lift_handle: Node3D = null

func manifest() -> Dictionary: return level.manifest

func built() -> bool: return manifest().has("power")

func door_index() -> int: return zones.size() + switch_until.size()

func lift_index() -> int: return door_index() + 1

func place() -> void:
	usables.clear()
	handles.clear()
	pilots.clear()
	pilot_lenses.clear()
	backup_lenses.clear()
	door_pilot.clear()
	on_order.clear()
	motor_started = false
	freed = false
	motor_door = null
	lift_handle = null
	applied.clear()
	if not built(): return
	var m := manifest()
	zones = m.power.circuits.duplicate()
	zones.sort_custom(func(a, b): return int(a.lever) < int(b.lever))
	lit_always = OFFICE.always_lit(m, 1)
	var board: Dictionary = m.power.board
	var yaw := float(board.yaw)
	var out := Vector3(sin(yaw), 0, cos(yaw))
	var basis := Basis(Vector3.UP, yaw)
	var origin := Vector3(float(board.point[0]), float(board.point[1]), float(board.point[2]))
	# The board (spec_rediseno 6.13): a row of cabinets from the floor, one a
	# lever, the backup's apart, its conduits on to the ceiling and the main
	# supply box beside it. BOARD and lever_at() still lay the levers out.
	var board_piece := equipment(POWER_LOOK.power_board(level.hotel, POWER_LOOK.BOARD, zones.size()), wall_xform(POWER_LOOK.BOARD, origin, origin.y, yaw))
	plate_text("TABLERO ELÉCTRICO", plate_spot(board_piece), yaw, 40)
	var el_room: Dictionary = m.rooms[int(m.power.room)]
	var rise := float(el_room.height) - POWER_LOOK.BOARD.y - 0.01
	if rise >= 0.25:
		var conduit_size := Vector3(POWER_LOOK.BOARD.x, snappedf(rise, 0.01), POWER_LOOK.CONDUITS_DEPTH)
		equipment(POWER_LOOK.board_conduits(level.hotel, conduit_size), wall_xform(conduit_size, origin, origin.y + POWER_LOOK.BOARD.y, yaw))
	supply_box(m, origin, yaw)
	for i in zones.size():
		var pivot := origin + basis * lever_at(i)
		var stand := origin + out * 0.8 + basis * Vector3(lever_at(i).x, 0, 0)
		var usable = add_usable(Transform3D(basis, pivot), "lever", stand, atan2(out.x, out.z))
		usable.box = Vector3(0.26, 0.4, 0.3)
		handles.append(hang_lever(Transform3D(basis, pivot), POWER_LOOK.HANDLE, false))
		plate_text(String(zones[i].name), origin + basis * Vector3(lever_at(i).x, POWER_LOOK.PLATE_Y, POWER_LOOK.PLATE_Z), yaw, 14)
	# The backup's cabinet: its plate and its three lamps, lit as sectors go up.
	var backup_x: float = POWER_LOOK.red_plate_x(zones.size())
	plate_text("RESPALDO", origin + basis * Vector3(backup_x, POWER_LOOK.PLATE_Y, POWER_LOOK.PLATE_Z), yaw, 18)
	for k in BACKUP:
		var lens_at := Transform3D(basis, origin + basis * Vector3(backup_x - 0.05 + k * 0.05, BACKUP_LENS_Y - BACKUP_LENS.y * 0.5, POWER_LOOK.PLATE_Z + 0.002))
		backup_lenses.append([equipment(MAIL.lamp_lens(level.hotel, BACKUP_LENS, "glow_amber"), lens_at), equipment(MAIL.lamp_lens(level.hotel, BACKUP_LENS, "lamp_off"), lens_at)])
	switch_until.clear()
	for entry in m.power.timers:
		var at := Vector3(float(entry.point[0]), float(entry.point[1]), float(entry.point[2]))
		var t_out := Vector3(sin(float(entry.yaw)), 0, cos(float(entry.yaw)))
		add_usable(Transform3D(Basis(Vector3.UP, float(entry.yaw)), at), "switch", at + t_out * 0.6 - Vector3(0, at.y - float(m.rooms[int(entry.room)].py), 0), atan2(t_out.x, t_out.z))
		equipment(POWER_LOOK.timer_switch(level.hotel, POWER_LOOK.SWITCH), wall_xform(POWER_LOOK.SWITCH, at, at.y - POWER_LOOK.SWITCH.y * 0.5, float(entry.yaw)))
		# Its pilot's lenses, under the button, lit while it runs (tick()).
		var lens_at := Transform3D(Basis(Vector3.UP, float(entry.yaw)), at + Vector3(0, POWER_LOOK.SWITCH_LENS_Y - POWER_LOOK.SWITCH.y * 0.5, 0) + t_out * (POWER_LOOK.SWITCH_FACE + POWER_LOOK.SWITCH_LENS.z * 0.5))
		var lit := equipment(MAIL.lamp_lens(level.hotel, POWER_LOOK.SWITCH_LENS, "glow_amber"), lens_at)
		lit.visible = false
		pilot_lenses.append([lit, equipment(MAIL.lamp_lens(level.hotel, POWER_LOOK.SWITCH_LENS, "lamp_off"), lens_at)])
		var pilot := OmniLight3D.new()
		pilot.light_color = Color(1.0, 0.55, 0.2)
		pilot.omni_range = 0.6
		pilot.light_energy = 0.4
		pilot.position = at + t_out * 0.1
		pilot.visible = false
		level.hotel.add_child(pilot)
		pilots.append(pilot)
		switch_until.append(0.0)
	place_maneuver(m)
	# The legend, pinned beside the board.
	var memo_at := origin + basis * Vector3(BOARD.x / 2 + 0.4, 1.5, 0.11)
	pin_memo(memo_at, yaw)
	add_usable(Transform3D(basis, memo_at), "read", Vector3.INF, NAN)
	refresh_power(true)
	show_handles()

## A lever's handle hanging from its pivot, swinging up about it.
func hang_lever(pivot: Transform3D, size: Vector3, red: bool) -> Node3D:
	var hinge := Node3D.new()
	hinge.transform = pivot
	level.hotel.add_child(hinge)
	equipment(POWER_LOOK.lever_handle(level.hotel, size, red), Transform3D(Basis.IDENTITY, Vector3(0, 0.02 - size.y, 0.02)), hinge)
	return hinge

## The maneuver room: its motorised door (the floor's own leaf, locked), its
## pilot and its button outside; inside, the lift's cabinet and its red lever.
func place_maneuver(m: Dictionary) -> void:
	var man: Dictionary = m.power.get("maneuver", {})
	if man.is_empty():
		add_usable(Transform3D(), "door", Vector3.INF, NAN)
		add_usable(Transform3D(), "lift", Vector3.INF, NAN)
		return
	maneuver_room = int(man.room)
	var inside: Dictionary = m.rooms[maneuver_room]
	var outside: Dictionary = m.rooms[int(man.outside)]
	var portal := FLOOR.portal_between(inside, outside)
	for door in level.hotel.doors:
		if Vector2(door.doorway.x - portal.x, door.doorway.z - portal.z).length() < 0.1 and absf(door.doorway.y - portal.y) < 1.0:
			motor_door = door
			break
	# No hand opens it: only its motor, and nobody shuts it after.
	if motor_door != null: motor_door.locked = true
	var normal := Basis(Vector3.UP, motor_door.closed_rotation).z if motor_door != null else Vector3.FORWARD
	var away := normal * signf((FLOOR.position_of(outside) - portal).dot(normal))
	var face_yaw := atan2(away.x, away.z)
	var face := Basis(Vector3.UP, face_yaw)
	var floor_at := Vector3(portal.x, float(outside.py), portal.z)
	door_pilot = door_pilot_lenses(portal, float(outside.py), away)
	var glow := OmniLight3D.new()
	glow.omni_range = 0.9
	glow.light_energy = 0.3
	glow.position = (door_pilot[0] as Node3D).transform * Vector3(0, DOOR_PILOT.y * 0.5, 0.08)
	level.hotel.add_child(glow)
	door_pilot.append(glow)
	add_usable(Transform3D(face, floor_at + away * 0.05 + Vector3(0, DOOR_BOX.y * 0.5, 0)), "door", floor_at + away * 0.9, atan2(-away.x, -away.z), DOOR_BOX)
	# The lift's cabinet on its wall, its plate, its conduits up to the ceiling
	# and its red lever beside it.
	var spot: Dictionary = man.lever
	var yaw := float(spot.yaw)
	var basis := Basis(Vector3.UP, yaw)
	var out := basis.z
	var origin := Vector3(float(spot.point[0]), float(spot.point[1]), float(spot.point[2]))
	var cabinet := equipment(POWER_LOOK.main_supply_box(level.hotel, POWER_LOOK.SUPPLY), wall_xform(POWER_LOOK.SUPPLY, origin, origin.y + POWER_LOOK.SUPPLY_Y, yaw))
	plate_text("MONTACARGAS\nMANIOBRA", plate_spot(cabinet), yaw, 22)
	var top := POWER_LOOK.SUPPLY_Y + POWER_LOOK.SUPPLY.y
	var rise := float(inside.height) - top - 0.01
	if rise >= 0.25:
		var conduit_size := Vector3(POWER_LOOK.SUPPLY.x, snappedf(rise, 0.01), POWER_LOOK.CONDUITS_DEPTH)
		equipment(POWER_LOOK.board_conduits(level.hotel, conduit_size), wall_xform(conduit_size, origin, origin.y + top, yaw))
	var pivot := Transform3D(basis, origin + basis * LIFT_LEVER)
	lift_handle = hang_lever(pivot, POWER_LOOK.RED_HANDLE, true)
	var usable = add_usable(pivot, "lift", origin + out * 0.8 + basis * Vector3(LIFT_LEVER.x, 0, 0), atan2(out.x, out.z))
	usable.box = Vector3(0.26, 0.45, 0.3)

## The board's legend: each zone's lever and what the backup takes.
func paper_of(_index: int) -> Dictionary:
	var lines: Array = []
	for z in zones: lines.append(String(z.name))
	lines.append("")
	lines.append("DURANTE UN APAGÓN EL SISTEMA DE RESPALDO SOLO PUEDE MANEJAR %d SECTORES DE ELECTRICIDAD." % BACKUP)
	lines.append("POR FAVOR, NO SOBRECARGAR EL SISTEMA.")
	return memo(MEMO_ID, "CUADRO GENERAL", lines)

## A lever's pivot in the board's frame (+Z out of the wall).
func lever_at(i: int) -> Vector3:
	return Vector3(-BOARD.x / 2 + 0.25 + i * LEVER_PITCH, LEVER_Y, BOARD.z + 0.05)

## The main supply box with its three meters (spec_rediseno 6.13), left of the
## board when the wall has room for it there: clear of the wall's end, of its
## doorways and of its wardrobes; none otherwise.
func supply_box(m: Dictionary, origin: Vector3, yaw: float) -> void:
	var board: Dictionary = m.power.board
	var room: Dictionary = m.rooms[int(m.power.room)]
	var wall := String(board.wall)
	# The board's +x runs with the wall's along on north and east, against it on south and west.
	var way: float = 1.0 if wall == "north" or wall == "east" else -1.0
	var x := -POWER_LOOK.BOARD.x * 0.5 - POWER_LOOK.SUPPLY_GAP - POWER_LOOK.SUPPLY.x * 0.5
	var along := float(board.along) + way * x
	var half := POWER_LOOK.SUPPLY.x * 0.5
	if absf(along) + half > LAYOUT.wall_length(room, wall) * 0.5 - 0.15: return
	for h in room.get("hides", []):
		var hw := LAYOUT.hide_wall(h)
		if String(hw.wall) == wall and absf(float(hw.along) - along) < half + 0.9: return
	for door in FLOOR.doorways(room):
		if String(door.wall) == wall and absf(float(door.along) - along) < half + 0.75: return
	var box := equipment(POWER_LOOK.main_supply_box(level.hotel, POWER_LOOK.SUPPLY), wall_xform(POWER_LOOK.SUPPLY, origin + Basis(Vector3.UP, yaw) * Vector3(x, 0, 0), origin.y + POWER_LOOK.SUPPLY_Y, yaw))
	plate_text("ALIMENTACIÓN\nPRINCIPAL", plate_spot(box), yaw, 22)

func add_usable(xform: Transform3D, action: String, stand: Vector3, body_yaw: float, box := Vector3.ZERO):
	var usable := USABLE.new()
	if box != Vector3.ZERO: usable.box = box
	usable.name = "PowerUsable_%d" % usables.size()
	usable.level = level
	usable.handler = self
	usable.index = usables.size()
	usable.action = action
	usable.stand = stand
	usable.face_yaw = body_yaw
	usable.transform = xform
	level.hotel.add_child(usable)
	usables.append(usable)
	return usable

## The handles where the board stands, a lamp of the backup lit for each
## sector up, the lift's lever up once pulled, and the door's pilot.
func show_handles() -> void:
	for i in handles.size():
		handles[i].rotation.x = -LEVER_SWING if on_order.has(i) else 0.0
	for k in backup_lenses.size():
		backup_lenses[k][0].visible = k < on_order.size()
		backup_lenses[k][1].visible = k >= on_order.size()
	if is_instance_valid(lift_handle): lift_handle.rotation.x = -LEVER_SWING if freed else 0.0
	# Once its motor has run the door's box stops taking the aim.
	if door_index() < usables.size(): usables[door_index()].collision_layer = 0 if motor_started else 16
	if door_pilot.size() == 3:
		var on := door_powered()
		door_pilot[0].visible = not on
		door_pilot[1].visible = on
		door_pilot[2].light_color = Color(0.3, 1.0, 0.4) if on else Color(1.0, 0.15, 0.08)

## The rule of a room of planta 2 (spec 3.3): lit always, under a running
## minutero, or in a zone that is up.
func powered(room_id: int) -> bool:
	if lit_always.has(room_id): return true
	var now: float = level.session.elapsed
	var timers: Array = manifest().power.timers
	for i in timers.size():
		if switch_until[i] > now and timers[i].rooms.has(room_id): return true
	for z in on_order:
		if zones[int(z)].rooms.has(room_id): return true
	return false

## Whether the maneuver room's sector has power: its door's motor runs.
func door_powered() -> bool: return maneuver_room >= 0 and powered(maneuver_room)

## The lever of the zone a room is in, -1 in none.
func zone_of(room_id: int) -> int:
	for i in zones.size():
		if zones[i].rooms.has(room_id): return i
	return -1

## Whether the team's power keeps The Lurker off a room (spec_f2_movement
## 6.2; the author, 24 October 2026: a minutero's light herds her like the
## board's zones): powered by them, not lit always.
func herds(room_id: int) -> bool:
	return built() and not lit_always.has(room_id) and powered(room_id)

## Each room's power given again only where it changed.
func refresh_power(all := false) -> void:
	if not built(): return
	for room in manifest().rooms:
		if int(room.get("wing", 0)) != 1 or int(room.type) == OFFICE.VOID: continue
		var id := int(room.id)
		var on := powered(id)
		if not all and applied.get(id) == on: continue
		applied[id] = on
		level.hotel.set_room_power(id, on)

func alive(seat: int) -> bool:
	return int(level.session.participants.get(seat, level.session.Life.DEAD)) != level.session.Life.DEAD

func word_of(usable, seat: int) -> String:
	if not alive(seat): return ""
	match String(usable.action):
		"lever": return "BAJAR" if on_order.has(int(usable.index)) else "SUBIR"
		"switch": return "PULSAR"
		"door": return "ABRIR" if not motor_started and motor_door != null else ""
		"lift": return "BAJAR" if not freed and motor_door != null and motor_door.opened else ""
		"read": return "LEER"
	return ""

func hold_of(usable, _seat: int) -> float: return LIFT_HOLD if String(usable.action) == "lift" else 0.0

func begin_use(_usable, _seat: int) -> void: pass

func holding(_usable, _seat: int, _fraction: float) -> void: pass

func cancel_use(_usable, _seat: int) -> void: pass

func refused(_action: String, _index: int, _seat: int) -> void: pass

func allow(action: String, index: int, seat: int, body) -> bool:
	if not built() or body == null or index < 0 or index >= usables.size() or not ACTIONS.has(action): return false
	if not alive(seat) or bool(body.get("hidden")) or level.lifts.riding.has(seat): return false
	var usable = usables[index]
	if String(usable.action) != action: return false
	if body.global_position.distance_to(usable.global_position) > USE_REACH + (0.0 if body == level.player else SLACK): return false
	return not word_of(usable, seat).is_empty()

## The host decides whether the door's motor runs ({"open"}), from the board
## as it stands there; every machine plays it the same.
func apply(action: String, index: int, _seat: int, data: Dictionary, quiet: bool) -> Dictionary:
	var at: Vector3 = usables[index].global_position if index >= 0 and index < usables.size() else Vector3.ZERO
	var told := {}
	match action:
		"lever":
			if not quiet: sound_at("lever_%d.wav" % (index % 3 + 1), at, -4.0)
			if on_order.has(index): on_order.erase(index)
			else:
				on_order.append(index)
				# Past what the backup takes every breaker trips, the planta back to
				# its emergency lights.
				if on_order.size() > BACKUP:
					on_order.clear()
					if not quiet: sound_at("breaker.wav", at, 0.0)
		"switch":
			var i := index - zones.size()
			if i >= 0 and i < switch_until.size(): switch_until[i] = float(level.session.elapsed) + switch_time
			if not quiet: sound_at("lever_1.wav", at, -8.0)
		"door":
			var open: bool = bool(data.get("open", door_powered()))
			told = {"open": open}
			if open and not motor_started:
				motor_started = true
				run_motor(quiet)
			elif not open and not quiet: sound_at("door_lock.wav", at, -10.0)
		"lift":
			freed = true
			if not quiet:
				sound_at("breaker.wav", at, -4.0)
				if level.hotel.lifts.size() > 1: sound_at("lift_motor.wav", level.hotel.lifts[1] + Vector3(0, 1.5, 0), -6.0)
	show_handles()
	refresh_power()
	return told

## The door swung open on its motor over DOOR_TIME, locked still: nobody
## shuts it again. Its tween is the leaf's own (hotel_door.motion), so the
## host's settled state snaps a guest that runs behind.
func run_motor(quiet: bool) -> void:
	if motor_door == null: return
	if not quiet: sound_at("heavy_door.wav", motor_door.doorway + Vector3(0, 1.5, 0), -8.0)
	if is_instance_valid(motor_door.motion): motor_door.motion.kill()
	motor_door.moving = true
	motor_door.collision_layer = motor_door.GHOST
	var tween: Tween = motor_door.create_tween()
	tween.tween_property(motor_door, "rotation:y", motor_door.closed_rotation + motor_door.open_turn, DOOR_TIME).set_trans(Tween.TRANS_SINE)
	motor_door.motion = tween
	var door = motor_door
	tween.finished.connect(func():
		door.opened = true
		door.moving = false
		door.settled.emit(true)
	)

## Every machine: the minuteros go out by the clock.
func tick(_delta: float) -> void:
	if not built() or usables.is_empty(): return
	var now: float = level.session.elapsed
	var changed := false
	for i in switch_until.size():
		var running: bool = switch_until[i] > now
		if pilots[i].visible != running:
			pilots[i].visible = running
			if i < pilot_lenses.size():
				pilot_lenses[i][0].visible = running
				pilot_lenses[i][1].visible = not running
			changed = true
	if changed:
		refresh_power()
		show_handles()

## The bots: power to the maneuver room's sector (the oldest lever down first
## when the backup is full), its door, then the lift's lever inside.
func bot_errands(team) -> Array:
	if usables.is_empty() or freed or level.session.stage != 2 or maneuver_room < 0 or motor_door == null: return []
	if motor_started:
		return [team.office_task("power:lift", usables[lift_index()])] if motor_door.opened else []
	if door_powered(): return [team.office_task("power:door", usables[door_index()])]
	var lever := zone_of(maneuver_room)
	if lever < 0: return []
	if on_order.size() >= BACKUP: lever = int(on_order[0])
	return [team.office_task("power:lever:%d" % lever, usables[lever])]

## The freight lift of this level goes down once the maneuver room's lever
## has freed it, and with the quota in it.
func allows_ride(stage: int, riders: Array) -> bool:
	if not built() or not level.kind.asks(stage, String(ID)): return true
	return freed and riders.size() >= level.session.minimum_survivors()

func progress(stage: int) -> Dictionary:
	if not built() or not level.kind.asks(stage, String(ID)): return idle()
	var lines: Array = [["SECTORES", "%d / %d" % [on_order.size(), BACKUP]]]
	return {"ready": freed, "done": on_order.size(), "needed": BACKUP, "kind": "power", "lines": lines, "extra": {}}

## Where the team still has to go: the board until the maneuver room has
## power, its door until it opens, then the lift's lever.
func goal_points(stage: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not built() or not level.kind.asks(stage, String(ID)) or usables.is_empty() or freed or maneuver_room < 0: return points
	if motor_started: points.append(usables[lift_index()].global_position)
	elif door_powered(): points.append(usables[door_index()].global_position)
	else:
		var lever := zone_of(maneuver_room)
		if lever >= 0: points.append(usables[lever].global_position)
	return points

func reset() -> void:
	on_order.clear()
	motor_started = false
	freed = false
	if motor_door != null:
		motor_door.set_state(false)
		motor_door.locked = true
	for i in switch_until.size(): switch_until[i] = 0.0
	show_handles()
	refresh_power(true)

func snapshotted() -> bool: return true

func snapshot() -> Dictionary: return {"on": on_order.duplicate(), "switches": switch_until.duplicate(), "motor": motor_started, "freed": freed}

func restore(data: Dictionary) -> void:
	on_order = data.get("on", []).map(func(z): return int(z))
	motor_started = bool(data.get("motor", false))
	freed = bool(data.get("freed", false))
	if motor_door != null:
		motor_door.locked = true
		motor_door.set_state(motor_started)
	var kept: Array = data.get("switches", [])
	for i in mini(kept.size(), switch_until.size()): switch_until[i] = float(kept[i])
	show_handles()
	refresh_power(true)
