extends "res://game/floors/objectives/objective.gd"
## Planta 1 of the offices, the card (spec_f1_systems section 2): each survivor
## types a request at the window, the pneumatic tube sends the card to one of
## the stations, it is taken from the tray, and the quota of cards goes through
## the reader beside the freight lift's door, which then opens. Not built yet:
## the photo (2.4), the papers (1h), the capsule seen and heard travelling
## and a dropped card: the station and where the card is are the pause lines.
const ID := &"files"
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const USABLE := preload("res://game/world/interactables/office/office_usable.gd")

enum Card { TRAVELLING, IN_TRAY, HELD, DROPPED }
const ACTIONS := ["type", "take", "swipe"]
## The hold at the typewriter (tuning().typing_time to come, 1.8: Desafiante's),
## at the tray and at the reader.
const TYPE_TIME := 5.0
const TAKE_TIME := 1.5
const SWIPE_TIME := 0.5
## The typing bell, then the capsule leaves; how fast it runs in the tube.
const SEND_DELAY := 1.2
const CAPSULE_SPEED := 6.0
const USE_REACH := 2.5
const SLACK := 0.5
const STATION_LAMP := Color(1.0, 0.62, 0.25)

## Seat -> {station, state, holder, swiped, number, sent, arrive}.
var requests := {}
## Owner seats whose card went through the reader, in order.
var swiped: Array = []
## The "station" entries of tubes.exits, in list order (station index = place here).
var station_exits: Array = []
## The usables: 0 the typewriter, 1.. the stations, last the reader.
var usables: Array = []
var lamps: Array = []
## The keys going while this machine's player types.
var typing_voice = null

func manifest() -> Dictionary: return level.manifest

func built() -> bool: return manifest().has("mail") and manifest().has("tubes")

func reader_index() -> int: return usables.size() - 1

func place() -> void:
	usables.clear()
	lamps.clear()
	station_exits.clear()
	if not built(): return
	var m := manifest()
	for e in m.tubes.exits:
		if String(e.kind) == "station": station_exits.append(e)
	var desk: Dictionary = m.mail.desk
	var stand: Dictionary = m.mail.stand
	var desk_at := v3(desk.point) + facing(float(desk.yaw)) * 0.4
	add_usable(Transform3D(Basis(Vector3.UP, float(desk.yaw)), desk_at + Vector3(0, 0.9, 0)), "type", v3(stand.point), look_yaw(-facing(float(stand.yaw))))
	# The typewriter on the window's desk.
	piece(desk_at + Vector3(0, 0.82, 0), Vector3(0.46, 0.2, 0.38), Color("3a3d3a"), float(desk.yaw))
	for e in station_exits:
		var at := v3(e.point)
		var out := facing(float(e.yaw))
		var usable = add_usable(Transform3D(Basis(Vector3.UP, float(e.yaw)), at), "take", at + out * 0.55 - Vector3(0, at.y - floor_y(at), 0), look_yaw(-out))
		# The receiver: its body over the tray, its number under it, and the
		# lamp that tells a card is waiting.
		piece(at + Vector3(0, 0.14, 0) - out * 0.06, Vector3(0.36, 0.52, 0.24), Color("6f6a5c"), float(e.yaw))
		var plate := Label3D.new()
		plate.text = str(int(e.number))
		plate.font_size = 48
		plate.pixel_size = 0.002
		plate.modulate = Color("e8e2cf")
		plate.position = at + out * 0.07 + Vector3(0, -0.2, 0)
		plate.rotation.y = float(e.yaw)
		level.hotel.add_child(plate)
		var lamp := OmniLight3D.new()
		lamp.light_color = STATION_LAMP
		lamp.omni_range = 1.5
		lamp.light_energy = 0.6
		lamp.position = at + out * 0.2 + Vector3(0, 0.45, 0)
		lamp.visible = false
		level.hotel.add_child(lamp)
		lamps.append(lamp)
		usable.set_meta("number", int(e.number))
	var reader: Dictionary = m.mail.reader
	var reader_at := v3(reader.point)
	var reader_out := facing(float(reader.yaw))
	add_usable(Transform3D(Basis(Vector3.UP, float(reader.yaw)), reader_at), "swipe", reader_at + reader_out * 0.6 - Vector3(0, reader_at.y - floor_y(reader_at), 0), look_yaw(-reader_out))
	piece(reader_at + reader_out * 0.03, Vector3(0.12, 0.2, 0.06), Color("2c2e30"), float(reader.yaw))
	show_state()

func v3(p: Array) -> Vector3: return Vector3(float(p[0]), float(p[1]), float(p[2]))

## The way a yaw faces (+Z turned by it), and a body's rotation.y that looks
## that way (-Z forward).
func facing(yaw: float) -> Vector3: return Vector3(sin(yaw), 0.0, cos(yaw))

func look_yaw(way: Vector3) -> float: return atan2(-way.x, -way.z)

## The floor of the planta a point is on.
func floor_y(point: Vector3) -> float: return FLOOR.planta_y(FLOOR.planta_of(point.y))

func add_usable(xform: Transform3D, action: String, stand: Vector3, yaw: float):
	var usable := USABLE.new()
	usable.name = "FilesUsable_%d" % usables.size()
	usable.level = level
	usable.handler = self
	usable.index = usables.size()
	usable.action = action
	usable.stand = stand
	usable.face_yaw = yaw
	usable.transform = xform
	level.hotel.add_child(usable)
	usables.append(usable)
	return usable

## A plain box standing in for a model to come (1h and the ingest).
func piece(at: Vector3, size: Vector3, colour: Color, yaw: float) -> void:
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

## The station lamps: on while a card waits in their tray.
func show_state() -> void:
	for i in lamps.size():
		var waiting := false
		for seat in requests:
			if int(requests[seat].station) == i and int(requests[seat].state) == Card.IN_TRAY: waiting = true
		lamps[i].visible = waiting

func alive(seat: int) -> bool:
	return int(level.session.participants.get(seat, level.session.Life.DEAD)) != level.session.Life.DEAD

## The first unswiped card a seat holds (its owner), or -1.
func held_unswiped(seat: int) -> int:
	for owner in requests:
		var r: Dictionary = requests[owner]
		if int(r.state) == Card.HELD and int(r.holder) == seat and not bool(r.swiped): return int(owner)
	return -1

## For planta 3's post: the cards a seat holds, and whether it holds any.
func held_cards(seat: int) -> Array:
	var owners: Array = []
	for owner in requests:
		if int(requests[owner].state) == Card.HELD and int(requests[owner].holder) == seat: owners.append(int(owner))
	return owners

func has_card(seat: int) -> bool: return not held_cards(seat).is_empty()

func word_of(usable, seat: int) -> String:
	if not alive(seat) or level.session.stage != 1: return ""
	match String(usable.action):
		"type": return "ESCRIBIR" if not requests.has(seat) else ""
		"take":
			for owner in requests:
				var r: Dictionary = requests[owner]
				if int(r.station) == int(usable.index) - 1 and int(r.state) == Card.IN_TRAY and (int(owner) == seat or not alive(int(owner))): return "RECOGER"
			return ""
		"swipe": return "PASAR FICHA" if held_unswiped(seat) >= 0 else ""
	return ""

func hold_of(usable, _seat: int) -> float:
	match String(usable.action):
		"type": return TYPE_TIME
		"take": return TAKE_TIME
		"swipe": return SWIPE_TIME
	return 0.0

func begin_use(usable, seat: int) -> void:
	if String(usable.action) == "type" and seat == level.player.slot:
		stop_loop(typing_voice)
		typing_voice = loop_at("typing.wav", usable.global_position, -6.0)

func holding(_usable, _seat: int, _fraction: float) -> void: pass

func cancel_use(_usable, _seat: int) -> void:
	stop_loop(typing_voice)
	typing_voice = null

func refused(_action: String, _index: int, _seat: int) -> void: pass

## What the host checks before anybody's use is applied.
func allow(action: String, index: int, seat: int, body) -> bool:
	if not built() or body == null or index < 0 or index >= usables.size() or not ACTIONS.has(action): return false
	if not alive(seat) or bool(body.get("hidden")) or level.lifts.riding.has(seat): return false
	var usable = usables[index]
	if String(usable.action) != action: return false
	if body.global_position.distance_to(usable.global_position) > USE_REACH + (0.0 if body == level.player else SLACK): return false
	return not word_of(usable, seat).is_empty()

## Applied on every machine (the host first, deciding the station).
func apply(action: String, index: int, seat: int, data: Dictionary, quiet: bool) -> Dictionary:
	var out := data
	match action:
		"type":
			if out.is_empty(): out = choose(seat)
			var exit: Dictionary = station_exits[int(out.station)]
			var sent: float = float(level.session.elapsed) + SEND_DELAY
			requests[seat] = {"station": int(out.station), "state": Card.TRAVELLING, "holder": -1, "swiped": false, "number": String(out.number), "sent": sent, "arrive": sent + float(exit.tube) / CAPSULE_SPEED}
			if seat == level.player.slot:
				stop_loop(typing_voice)
				typing_voice = null
			if not quiet: sound_at("typing_bell.wav", usables[0].global_position, -2.0)
		"arrived":
			if requests.has(seat): requests[seat].state = Card.IN_TRAY
			if not quiet and index + 1 < usables.size(): sound_at("tube_bell.wav", usables[index + 1].global_position, -2.0)
		"take":
			for owner in requests:
				var r: Dictionary = requests[owner]
				if int(r.station) == index - 1 and int(r.state) == Card.IN_TRAY and (int(owner) == seat or not alive(int(owner))):
					r.state = Card.HELD
					r.holder = seat
					break
		"swipe":
			var owner := held_unswiped(seat)
			if owner >= 0:
				requests[owner].swiped = true
				swiped.append(owner)
				if not quiet: sound_at("lever_1.wav", usables[index].global_position, -4.0)
	show_state()
	return out

## The host's choice of a station for a seat's request: one nobody's live
## request has, in an order of its own for the seat, else the least used.
func choose(seat: int) -> Dictionary:
	var free: Array = range(station_exits.size())
	var used := {}
	for owner in requests: used[int(requests[owner].station)] = int(used.get(int(requests[owner].station), 0)) + 1
	var order := free.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(manifest().seed), "station", seat, int(level.session.get("restarts") if level.session.get("restarts") != null else 0)])
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = order[i]
		order[i] = order[j]
		order[j] = swap
	var station := -1
	for s in order:
		if not used.has(int(s)):
			station = int(s)
			break
	if station < 0:
		station = int(order[0])
		for s in order:
			if int(used.get(int(s), 0)) < int(used.get(station, 0)): station = int(s)
	return {"station": station, "number": "P-%04d" % (absi(hash([int(manifest().seed), "ficha", seat])) % 9000 + 1000)}

## The host: a capsule that has run its tube arrives in its tray.
func tick(_delta: float) -> void:
	if level.net.is_client(): return
	for seat in requests:
		var r: Dictionary = requests[seat]
		if int(r.state) == Card.TRAVELLING and float(level.session.elapsed) >= float(r.arrive):
			apply("arrived", int(r.station), int(seat), {}, false)
			level.match_net.tell_office(ID, "arrived", int(r.station), int(seat), {})

func progress(stage: int) -> Dictionary:
	if not built() or not level.kind.asks(stage, String(ID)): return idle()
	var quota: int = level.session.minimum_survivors()
	var lines: Array = []
	var mine: Dictionary = requests.get(level.player.slot, {})
	if not mine.is_empty():
		var where := "ESTACIÓN %d" % int(station_exits[int(mine.station)].number)
		if int(mine.state) == Card.TRAVELLING: where += ", EN CAMINO"
		elif int(mine.state) == Card.IN_TRAY: where += ", EN LA BANDEJA"
		elif bool(mine.swiped): where = "PASADA"
		elif int(mine.state) == Card.HELD: where = "EN LA MANO"
		lines.append(["TU FICHA", where])
	lines.append(["FICHAS", "%d / %d" % [swiped.size(), quota]])
	return {"ready": swiped.size() >= quota, "done": swiped.size(), "needed": quota, "kind": "files", "lines": lines, "extra": {}}

func goal_points(stage: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if not built() or not level.kind.asks(stage, String(ID)) or usables.is_empty(): return points
	points.append(usables[0].global_position)
	for seat in requests:
		var r: Dictionary = requests[seat]
		if int(r.state) == Card.IN_TRAY: points.append(usables[int(r.station) + 1].global_position)
		elif int(r.state) == Card.HELD and not bool(r.swiped): points.append(usables[reader_index()].global_position)
	return points

## A stage given back: this stage's requests and cards are gone.
func reset() -> void:
	requests.clear()
	swiped.clear()
	show_state()

func snapshot() -> Dictionary: return {"requests": requests.duplicate(true), "swiped": swiped.duplicate()}

func restore(data: Dictionary) -> void:
	requests = {}
	var kept: Dictionary = data.get("requests", {})
	for seat in kept: requests[int(seat)] = kept[seat]
	swiped = data.get("swiped", []).duplicate()
	show_state()
