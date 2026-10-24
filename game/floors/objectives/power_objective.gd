extends "res://game/floors/objectives/objective.gd"
## Planta 2 of the offices, the power (spec_f1_systems section 3): the board in
## the electrical room has a lever per zone, and no more than `budget` zones
## are lit at once (the oldest drops); the minuteros light their corridor for a
## while; the red lever cuts the whole planta and starts the freight lift's
## clock, and the lift only goes down once it has run out. Beside the board,
## a memo says how it works. Not built yet: the kit's models.
const ID := &"power"
const USABLE := preload("res://game/world/interactables/office/office_usable.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")

enum Red { DOWN, RUNNING, ARMED }
const ACTIONS := ["lever", "red", "switch"]
## The legend memo's paper id, clear of the hotel's hints and the cards.
const MEMO_ID := 2000
const RED_HOLD := 1.0
const USE_REACH := 2.5
const SLACK := 0.5
## The board (spec 3.4): back plate, lever pivots and their pitch.
const BOARD := Vector3(2.6, 1.9, 0.12)
const LEVER_Y := 1.35
const LEVER_PITCH := 0.3
const RED_GAP := 0.2
const LEVER_SWING := deg_to_rad(70.0)

## power.circuits sorted by lever.
var zones: Array = []
var lit_always: Array = []
## Zone indices up, oldest first.
var on_order: Array = []
var red := Red.DOWN
var red_started := 0.0
## The tuning's (spec 1.8, Equilibrada) until difficulty carries them.
var budget := 3
var lift_timer := 60.0
var switch_time := 75.0
## Per power.timers entry, session.elapsed when it goes out (0: out).
var switch_until: Array = []
## Room -> the power last given.
var applied := {}
## The usables: 0..n-1 the zones' levers, n the red one, then the minuteros.
var usables: Array = []
var handles: Array = []
var pilots: Array = []
## The red timer ticking at the board while it runs.
var tick_voice = null

func manifest() -> Dictionary: return level.manifest

func built() -> bool: return manifest().has("power")

func red_index() -> int: return zones.size()

func place() -> void:
	usables.clear()
	handles.clear()
	pilots.clear()
	on_order.clear()
	red = Red.DOWN
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
	piece(origin + basis * Vector3(0, 0.5 + BOARD.y / 2, BOARD.z / 2), BOARD, Color("4d5244"), yaw)
	for i in zones.size() + 1:
		var pivot := origin + basis * lever_at(i)
		var stand := origin + out * 0.8 + basis * Vector3(lever_at(i).x, 0, 0)
		var usable = add_usable(Transform3D(basis, pivot), "red" if i == red_index() else "lever", stand, atan2(out.x, out.z))
		usable.box = Vector3(0.26, 0.4, 0.3)
		# The handle: a flat bar with a grip, swinging up about its pivot.
		var hinge := Node3D.new()
		hinge.transform = Transform3D(basis, pivot)
		level.hotel.add_child(hinge)
		var bar := piece_under(hinge, Vector3(0, -0.12, 0.08), Vector3(0.04, 0.25, 0.03), Color("a3271f") if i == red_index() else Color("2b2b28"))
		bar.position = Vector3(0, -0.12, 0.08)
		handles.append(hinge)
		var label := Label3D.new()
		label.text = "MONTACARGAS" if i == red_index() else "%s\n%s" % [String(zones[i].code), String(zones[i].name)]
		label.font_size = 18 if i == red_index() else 14
		label.pixel_size = 0.0015
		label.modulate = Color("e8e2cf")
		label.position = pivot + out * 0.07 + Vector3(0, -0.3, 0)
		label.rotation.y = yaw
		level.hotel.add_child(label)
	switch_until.clear()
	for entry in m.power.timers:
		var at := Vector3(float(entry.point[0]), float(entry.point[1]), float(entry.point[2]))
		var t_out := Vector3(sin(float(entry.yaw)), 0, cos(float(entry.yaw)))
		add_usable(Transform3D(Basis(Vector3.UP, float(entry.yaw)), at), "switch", at + t_out * 0.6 - Vector3(0, at.y - float(m.rooms[int(entry.room)].py), 0), atan2(t_out.x, t_out.z))
		piece(at + t_out * 0.02, Vector3(0.08, 0.08, 0.04), Color("d8d0bc"), float(entry.yaw))
		var pilot := OmniLight3D.new()
		pilot.light_color = Color(1.0, 0.55, 0.2)
		pilot.omni_range = 0.6
		pilot.light_energy = 0.4
		pilot.position = at + t_out * 0.1
		pilot.visible = false
		level.hotel.add_child(pilot)
		pilots.append(pilot)
		switch_until.append(0.0)
	# The legend, pinned beside the board.
	var memo_at := origin + basis * Vector3(BOARD.x / 2 + 0.4, 1.5, 0.11)
	pin_memo(memo_at, yaw)
	add_usable(Transform3D(basis, memo_at), "read", Vector3.INF, NAN)
	refresh_power(true)
	show_handles()

## The board's legend: each zone's lever, the budget and the red lever.
func paper_of(_index: int) -> Dictionary:
	var lines: Array = []
	for z in zones: lines.append("%s %s" % [String(z.code), String(z.name)])
	lines.append("")
	lines.append("NO MÁS DE %d ZONAS A LA VEZ." % budget)
	lines.append("PALANCA ROJA: MONTACARGAS. CORTA LA PLANTA. ARRANQUE CON RETARDO.")
	return memo(MEMO_ID, "CUADRO GENERAL", lines)

## A lever's pivot in the board's frame (+Z out of the wall).
func lever_at(i: int) -> Vector3:
	var x := -BOARD.x / 2 + 0.25 + i * LEVER_PITCH + (RED_GAP if i == red_index() else 0.0)
	return Vector3(x, LEVER_Y, BOARD.z + 0.05)

func add_usable(xform: Transform3D, action: String, stand: Vector3, body_yaw: float):
	var usable := USABLE.new()
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

func piece(at: Vector3, size: Vector3, colour: Color, yaw: float) -> MeshInstance3D:
	var mesh := piece_under(level.hotel, at, size, colour)
	mesh.rotation.y = yaw
	return mesh

## A plain box standing in for a model to come.
func piece_under(parent: Node3D, at: Vector3, size: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size
	mesh.mesh = cube
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.6
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh

## The handles where the board stands: a zone's up while it is on, the red
## one up once it is pulled.
func show_handles() -> void:
	for i in handles.size():
		var up: bool = (i == red_index() and red != Red.DOWN) or on_order.has(i)
		handles[i].rotation.x = -LEVER_SWING if up else 0.0

## The rule of a room of planta 2 (spec 3.3): lit always, under a running
## minutero, or in a zone that is on while the red lever is down.
func powered(room_id: int) -> bool:
	if lit_always.has(room_id): return true
	var now: float = level.session.elapsed
	var timers: Array = manifest().power.timers
	for i in timers.size():
		if switch_until[i] > now and timers[i].rooms.has(room_id): return true
	if red == Red.DOWN:
		for z in on_order:
			if zones[int(z)].rooms.has(room_id): return true
	return false

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
		"lever": return ("BAJAR" if on_order.has(int(usable.index)) else "SUBIR") if red == Red.DOWN else ""
		"red": return "SUBIR" if red == Red.DOWN else ""
		"switch": return "PULSAR"
		"read": return "LEER"
	return ""

func hold_of(usable, _seat: int) -> float: return RED_HOLD if String(usable.action) == "red" else 0.0

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

func apply(action: String, index: int, _seat: int, _data: Dictionary, quiet: bool) -> Dictionary:
	var at: Vector3 = usables[index].global_position if index >= 0 and index < usables.size() else Vector3.ZERO
	match action:
		"lever":
			if red == Red.DOWN:
				if not quiet: sound_at("lever_%d.wav" % (index % 3 + 1), at, -4.0)
				if on_order.has(index): on_order.erase(index)
				else:
					on_order.append(index)
					# Over the budget the oldest zone's breaker trips.
					if on_order.size() > budget and not quiet: sound_at("breaker.wav", at, -4.0)
					while on_order.size() > budget: on_order.pop_front()
		"red":
			red = Red.RUNNING
			red_started = level.session.elapsed
			on_order.clear()
			if not quiet:
				sound_at("breaker.wav", at, -4.0)
				stop_loop(tick_voice)
				tick_voice = loop_at("tick.wav", at, -6.0)
		"armed":
			red = Red.ARMED
			stop_loop(tick_voice)
			tick_voice = null
			if not quiet and level.hotel.lifts.size() > 1: sound_at("lift_motor.wav", level.hotel.lifts[1] + Vector3(0, 1.5, 0), -6.0)
		"switch":
			var i := index - red_index() - 1
			if i >= 0 and i < switch_until.size(): switch_until[i] = float(level.session.elapsed) + switch_time
			if not quiet: sound_at("lever_1.wav", at, -8.0)
	show_handles()
	refresh_power()
	return {}

## Every machine: the minuteros go out by the clock; the host arms the lift.
func tick(_delta: float) -> void:
	if not built() or usables.is_empty(): return
	var now: float = level.session.elapsed
	var changed := false
	for i in switch_until.size():
		var running: bool = switch_until[i] > now
		if pilots[i].visible != running:
			pilots[i].visible = running
			changed = true
	if changed: refresh_power()
	if not level.net.is_client() and red == Red.RUNNING and now >= red_started + lift_timer:
		apply("armed", red_index(), -1, {}, false)
		level.match_net.tell_office(ID, "armed", red_index(), -1, {})

## The bots: the red lever, pulled by whoever is nearest; then the clock,
## waited out in the freight lobby (the team's refuge task).
func bot_errands(team) -> Array:
	if usables.is_empty() or red != Red.DOWN or level.session.stage != 2: return []
	return [team.office_task("power:red", usables[red_index()])]

## The freight lift of this level goes down only once the red lever's clock
## has run out, and with the quota in it.
func allows_ride(stage: int, riders: Array) -> bool:
	if not built() or not level.kind.asks(stage, String(ID)): return true
	return red == Red.ARMED and riders.size() >= level.session.minimum_survivors()

func progress(stage: int) -> Dictionary:
	if not built() or not level.kind.asks(stage, String(ID)): return idle()
	var lines: Array = [["ZONAS", "%d / %d" % [on_order.size(), budget]]]
	if red == Red.RUNNING: lines.append(["MONTACARGAS", "%d s" % ceili(red_started + lift_timer - float(level.session.elapsed))])
	return {"ready": red == Red.ARMED, "done": on_order.size(), "needed": budget, "kind": "power", "lines": lines, "extra": {}}

func goal_points(stage: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not built() or not level.kind.asks(stage, String(ID)) or usables.is_empty(): return points
	if red == Red.DOWN: points.append(usables[red_index()].global_position)
	return points

func reset() -> void:
	stop_loop(tick_voice)
	tick_voice = null
	on_order.clear()
	red = Red.DOWN
	for i in switch_until.size(): switch_until[i] = 0.0
	show_handles()
	refresh_power(true)

func snapshotted() -> bool: return true

func snapshot() -> Dictionary: return {"on": on_order.duplicate(), "red": red, "started": red_started, "switches": switch_until.duplicate()}

func restore(data: Dictionary) -> void:
	on_order = data.get("on", []).map(func(z): return int(z))
	red = int(data.get("red", Red.DOWN))
	red_started = float(data.get("started", 0.0))
	var kept: Array = data.get("switches", [])
	for i in mini(kept.size(), switch_until.size()): switch_until[i] = float(kept[i])
	show_handles()
	refresh_power(true)
