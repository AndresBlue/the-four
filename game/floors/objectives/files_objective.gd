extends "res://game/floors/objectives/objective.gd"
## Planta 1 of the offices, the card (spec_f1_systems section 2): each survivor
## types a request at the window, the pneumatic tube sends the card to one of
## the stations, it is taken from the tray, and the quota of cards goes through
## the reader beside the freight lift's door, which then opens. The photo goes
## to every machine (match_net.send_photo); the receipt and the card are held
## up when they come (1h, drawn by hint_view.gd), and the pause lines say where
## the card is. The equipment looks as its references (spec_rediseno 6.2, 6.3
## and 6.15, area 5: pieces/mail_equipment.gd).
const ID := &"files"
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const USABLE := preload("res://game/world/interactables/office/office_usable.gd")
const MAIL := preload("res://game/world/office/pieces/mail_equipment.gd")
const MODELS := preload("res://game/world/office/office_models.gd")
const WALL := preload("res://game/world/office/pieces/wall.gd")
const LAYOUT := preload("res://game/world/generation/office_layout.gd")
const ROOM_LAYERS := preload("res://game/world/hotel/room_layers.gd")

enum Card { TRAVELLING, IN_TRAY, HELD, DROPPED }
const ACTIONS := ["type", "take", "swipe", "pick"]
const PICK_TIME := 1.0
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
## The usables: 0 the typewriter, 1.. the stations, then the map, last the reader.
var usables: Array = []
var lamps: Array = []
## Per station, its lamp's lenses [lit, dark], shown in turn with its lamp.
var lenses: Array = []
## The keys going while this machine's player types.
var typing_voice = null
## The tubes' tree from the hub (parent node of each, -1 at the hub), and
## each request's capsule: {node, path (points), length, hiss}.
var tube_parent: Array = []
var capsules := {}
## Owner seat -> the usable of a card lying where its holder fell.
var pickups := {}
## Owner seat -> the ceiling camera's picture of them typing (this machine's).
var textures := {}
var snapping := false
## The picture: its size, and how far into the typing it is taken.
const PHOTO_SIZE := Vector2i(240, 304)
const TYPE_PHOTO_AT := 0.6
## As a JPEG on the wire: its quality, and no bigger than this.
const PHOTO_QUALITY := 0.7
const PHOTO_MAX_BYTES := 24576
## Owner seat -> the JPEG of their photo, as sent and kept (snapshot).
var photos := {}
const TUBE_RADIUS := 0.055
## The kit's straight metre of pipe (tools/props/build_catalogue.gd PARTS).
const PIPE_MODEL := "res://assets/props/hotel/modular_pipes_straight.res"
## The window desk's top (office_geometry.gd POST_DESK).
const DESK_TOP := 0.755

func manifest() -> Dictionary: return level.manifest

func built() -> bool: return manifest().has("mail") and manifest().has("tubes")

func reader_index() -> int: return usables.size() - 1

func place() -> void:
	usables.clear()
	lamps.clear()
	lenses.clear()
	station_exits.clear()
	if not built(): return
	var m := manifest()
	for e in m.tubes.exits:
		if String(e.kind) == "station": station_exits.append(e)
		# The hub's central at the window (spec_rediseno 6.3), where the tubes
		# start: its back on the wall, the hub's mouth inside it.
		if String(e.kind) == "hub":
			var central := equipment(MAIL.mail_central(level.hotel, MAIL.CENTRAL), wall_xform(MAIL.CENTRAL, v3(e.point), v3(e.point).y - MAIL.CENTRAL_HUB, float(e.yaw)))
			plate_text("CORREO NEUMÁTICO", plate_spot(central), float(e.yaw), 22)
	var desk: Dictionary = m.mail.desk
	var stand: Dictionary = m.mail.stand
	var desk_at := v3(desk.point) + facing(float(desk.yaw)) * 0.22
	add_usable(Transform3D(Basis(Vector3.UP, float(desk.yaw)), desk_at + Vector3(0, 0.9, 0)), "type", v3(stand.point), look_yaw(-facing(float(stand.yaw))))
	# The typewriter on the window's desk.
	equipment(MODELS.mesh_of(level.hotel, "typewriter"), Transform3D(Basis(Vector3.UP, float(desk.yaw)), desk_at + Vector3(0, DESK_TOP, 0)))
	for e in station_exits:
		var at := v3(e.point)
		var out := facing(float(e.yaw))
		var usable = add_usable(Transform3D(Basis(Vector3.UP, float(e.yaw)), at), "take", at + out * 0.55 - Vector3(0, at.y - floor_y(at), 0), look_yaw(-out))
		# The receiver (spec_rediseno 6.3): its bay where the capsule lies, its
		# number under it, the brass collar where its tube comes in, and the
		# lamp that tells a card is waiting, its lit and dark lenses in turn.
		var receiver := equipment(MAIL.station_receiver(level.hotel, MAIL.RECEIVER), wall_xform(MAIL.RECEIVER, at, at.y - MAIL.RECEIVER_MOUTH, float(e.yaw)))
		plate_text(str(int(e.number)), plate_spot(receiver), float(e.yaw), 36)
		equipment(MAIL.tube_collar(level.hotel, MAIL.COLLAR), Transform3D(Basis.IDENTITY, at + Vector3(0, MAIL.RECEIVER.y - MAIL.RECEIVER_MOUTH, 0)))
		var lens_at := Transform3D(Basis(Vector3.UP, float(e.yaw)), at + Vector3(0, MAIL.RECEIVER_LENS - MAIL.RECEIVER_MOUTH - MAIL.LENS.y * 0.5, 0) + out * (MAIL.RECEIVER.z + MAIL.LENS.z * 0.5))
		var lit := equipment(MAIL.lamp_lens(level.hotel, MAIL.LENS, "glow_amber"), lens_at)
		lit.visible = false
		lenses.append([lit, equipment(MAIL.lamp_lens(level.hotel, MAIL.LENS, "lamp_off"), lens_at)])
		var lamp := OmniLight3D.new()
		lamp.light_color = STATION_LAMP
		lamp.omni_range = 1.5
		lamp.light_energy = 0.6
		lamp.position = at + out * (MAIL.RECEIVER.z + 0.2) + Vector3(0, MAIL.RECEIVER_LENS - MAIL.RECEIVER_MOUTH, 0)
		lamp.visible = false
		level.hotel.add_child(lamp)
		lamps.append(lamp)
		usable.set_meta("number", int(e.number))
	tubes_built(m)
	# The ceiling camera over the window, looking at whoever types.
	var eye := v3(m.mail.camera)
	# Wholly behind the eye the card's photo is taken from (snap()): its lens
	# just in front of that eye, looking where the photo looks.
	var cam_basis := Basis.looking_at(v3(m.mail.camera_target) - eye, Vector3.UP)
	equipment(MAIL.ceiling_camera(level.hotel, MAIL.CAMERA), Transform3D(cam_basis, eye - cam_basis * Vector3(0, 0.04, -0.125)))
	# The network's map on the wall beside the window (read, nothing asked).
	var map_spot: Dictionary = m.mail.map
	var map_at := v3(map_spot.point) + facing(float(map_spot.yaw)) * 0.01
	# As wide as the wall leaves it beside the window (spec_rediseno 6.2).
	var window_room: Dictionary = m.rooms[int(m.mail.window)]
	var map_wide := clampf(2.0 * (LAYOUT.wall_length(window_room, String(map_spot.wall)) * 0.5 - absf(float(map_spot.along)) - 0.05), 0.42, MAIL.MAP.x)
	var map_size := Vector3(snappedf(map_wide, 0.01), MAIL.MAP.y, MAIL.MAP.z)
	var sheet := equipment(MAIL.network_map(level.hotel, map_size), wall_xform(map_size, v3(map_spot.point), v3(map_spot.point).y - map_size.y * 0.5, float(map_spot.yaw)))
	sheet.name = "TubeMap"
	plate_text("RED DE TUBOS", plate_spot(sheet), float(map_spot.yaw), 24, PLATE_DARK)
	add_usable(Transform3D(Basis(Vector3.UP, float(map_spot.yaw)), map_at), "read", Vector3.INF, NAN)
	var reader: Dictionary = m.mail.reader
	var reader_at := v3(reader.point)
	var reader_out := facing(float(reader.yaw))
	add_usable(Transform3D(Basis(Vector3.UP, float(reader.yaw)), reader_at), "swipe", reader_at + reader_out * 0.6 - Vector3(0, reader_at.y - floor_y(reader_at), 0), look_yaw(-reader_out))
	# The reader and, over it, how to use it and who for (spec_rediseno 6.15).
	equipment(MAIL.card_reader(level.hotel, MAIL.READER), wall_xform(MAIL.READER, reader_at, reader_at.y - MAIL.READER.y * 0.5, float(reader.yaw)))
	var steps := equipment(MAIL.instruction_plate(level.hotel, MAIL.STEPS), wall_xform(MAIL.STEPS, reader_at, reader_at.y + 0.22, float(reader.yaw)))
	plate_text("1. INSERTE FICHA\n2. ESPERE SEÑAL\n3. RETIRE FICHA", plate_spot(steps), float(reader.yaw), 17, PLATE_DARK)
	var notice_size := Vector3(0.4, 0.14, 0.01)
	var notice := equipment(WALL.sign_plate(level.hotel, notice_size), wall_xform(notice_size, reader_at, reader_at.y + 0.45, float(reader.yaw)))
	plate_text("USO EXCLUSIVO\nDE PERSONAL", plate_spot(notice), float(reader.yaw), 30)
	show_state()

func v3(p: Array) -> Vector3: return Vector3(float(p[0]), float(p[1]), float(p[2]))

## The tubes drawn (spec 2.6: brass-coloured stand-ins until the kit's pipes),
## and the tree the capsules run, from the hub.
func tubes_built(m: Dictionary) -> void:
	var nodes: Array = m.tubes.nodes
	var edges: Array = m.tubes.edges
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var pipe := CylinderMesh.new()
	pipe.top_radius = TUBE_RADIUS
	pipe.bottom_radius = TUBE_RADIUS
	pipe.height = 1.0
	pipe.radial_segments = 10
	pipe.rings = 1
	# Worn brass, as the reference's (spec_rediseno 6.3), the tubes and their
	# kit's pipe alike. Little metal: the hotel's gold, all metal, gave back the
	# dark offices round it and read as a black tube on the ceiling.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9c8656")
	material.metallic = 0.3
	material.roughness = 0.5
	pipe.material = material
	multi.mesh = pipe
	# Poly Haven's straight steel pipe when it is baked: a metre along its y
	# from its end, so each run is laid from its first node.
	var kit: bool = ResourceLoader.exists(PIPE_MODEL)
	if kit: multi.mesh = load(PIPE_MODEL)
	multi.instance_count = edges.size()
	var near: Array = []
	near.resize(nodes.size())
	for i in nodes.size(): near[i] = []
	for k in edges.size():
		var a := v3(nodes[int(edges[k][0])])
		var b := v3(nodes[int(edges[k][1])])
		near[int(edges[k][0])].append(int(edges[k][1]))
		near[int(edges[k][1])].append(int(edges[k][0]))
		# The unit cylinder stretched along the edge: its y is the edge.
		var run := b - a
		var up := run.normalized() if run.length() > 0.001 else Vector3.UP
		var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		multi.set_instance_transform(k, Transform3D(Basis(side, up * maxf(run.length(), 0.001), side.cross(up)), a if kit else (a + b) / 2))
	var holder := MultiMeshInstance3D.new()
	holder.name = "PneumaticTubes"
	holder.multimesh = multi
	holder.material_override = material
	# They cross many rooms: on every room's layer, and not moved by the floor
	# to the layer of the one at their origin (hotel_geometry.late_arrival()).
	holder.set_meta("laid", true)
	level.hotel.add_child(holder)
	ROOM_LAYERS.put_on(holder, ROOM_LAYERS.ROOMS)
	# A brass collar a little way into each run, at both its ends.
	var collars := MultiMesh.new()
	collars.transform_format = MultiMesh.TRANSFORM_3D
	collars.mesh = MAIL.tube_collar(level.hotel, MAIL.COLLAR)
	collars.instance_count = edges.size() * 2
	for k in edges.size():
		var ca := v3(nodes[int(edges[k][0])])
		var cb := v3(nodes[int(edges[k][1])])
		var crun := cb - ca
		var cup: Vector3 = crun.normalized() if crun.length() > 0.001 else Vector3.UP
		var cside := cup.cross(Vector3.FORWARD if absf(cup.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var turn := Basis(cside, cup, cside.cross(cup))
		var reach := minf(0.02, crun.length() * 0.25)
		collars.set_instance_transform(k * 2, Transform3D(turn, ca + cup * reach))
		collars.set_instance_transform(k * 2 + 1, Transform3D(turn, cb - cup * (reach + MAIL.COLLAR.y)))
	var ring := MultiMeshInstance3D.new()
	ring.name = "PneumaticCollars"
	ring.multimesh = collars
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.set_meta("laid", true)
	level.hotel.add_child(ring)
	ROOM_LAYERS.put_on(ring, ROOM_LAYERS.ROOMS)
	tube_parent.clear()
	tube_parent.resize(nodes.size())
	tube_parent.fill(-2)
	var hub := int(m.tubes.hub)
	tube_parent[hub] = -1
	var queue: Array = [hub]
	while not queue.is_empty():
		var n: int = queue.pop_front()
		for other in near[n]:
			if int(tube_parent[other]) == -2:
				tube_parent[other] = n
				queue.append(other)

## The way a capsule runs, from the hub to a node, as points.
func tube_path(to: int) -> Array:
	var points: Array = []
	var n := to
	while n >= 0 and n < tube_parent.size():
		points.push_front(v3(manifest().tubes.nodes[n]))
		n = int(tube_parent[n])
	return points

## A point `metres` along a path.
static func along(points: Array, metres: float) -> Vector3:
	var left := metres
	for i in range(1, points.size()):
		var piece: float = (points[i] as Vector3).distance_to(points[i - 1])
		if left <= piece: return (points[i - 1] as Vector3).lerp(points[i], left / maxf(piece, 0.001))
		left -= piece
	return points.back() if not points.is_empty() else Vector3.ZERO

## The capsule of a request, made on every machine from the request alone.
func capsule_for(seat: int) -> Dictionary:
	if capsules.has(seat): return capsules[seat]
	var r: Dictionary = requests[seat]
	var body := MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.radius = 0.045
	shape.height = 0.26
	body.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b8b2a2")
	material.metallic = 0.5
	body.material_override = material
	body.set_meta("laid", true)
	level.hotel.add_child(body)
	# It travels through many rooms, as the tubes: lit by any of them.
	ROOM_LAYERS.put_on(body, ROOM_LAYERS.ROOMS)
	var path := tube_path(int(station_exits[int(r.station)].node))
	capsules[seat] = {"node": body, "path": path, "hiss": null}
	return capsules[seat]

## The capsules where their request has them: running, in the tray, gone.
func show_capsules() -> void:
	var now: float = level.session.elapsed
	for seat in requests:
		var r: Dictionary = requests[seat]
		var state := int(r.state)
		if state == Card.HELD or state == Card.DROPPED:
			if capsules.has(seat):
				capsules[seat].node.queue_free()
				stop_loop(capsules[seat].hiss)
				capsules.erase(seat)
			continue
		var c := capsule_for(int(seat))
		var node: MeshInstance3D = c.node
		if state == Card.IN_TRAY:
			var exit: Dictionary = station_exits[int(r.station)]
			node.position = v3(exit.point) + facing(float(exit.yaw)) * 0.05 - Vector3(0, 0.05, 0)
			node.rotation = Vector3(0, float(exit.yaw), PI / 2)
			if c.hiss != null:
				stop_loop(c.hiss)
				c.hiss = null
			continue
		var run: float = (now - float(r.sent)) * CAPSULE_SPEED
		node.visible = run >= 0.0
		if run < 0.0: continue
		node.position = along(c.path, run)
		if c.hiss == null: c.hiss = loop_at("tube_hiss.wav", node.position, -8.0)
		else: move_loop(c.hiss, node.position)

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

## The station lamps: on while a card waits in their tray.
func show_state() -> void:
	for i in lamps.size():
		var waiting := false
		for seat in requests:
			if int(requests[seat].station) == i and int(requests[seat].state) == Card.IN_TRAY: waiting = true
		lamps[i].visible = waiting
		if i < lenses.size():
			lenses[i][0].visible = waiting
			lenses[i][1].visible = not waiting

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
	if String(usable.action) == "read": return "LEER"
	if not alive(seat) or level.session.stage != 1: return ""
	match String(usable.action):
		"type": return "ESCRIBIR" if not requests.has(seat) else ""
		"take":
			for owner in requests:
				var r: Dictionary = requests[owner]
				if int(r.station) == int(usable.index) - 1 and int(r.state) == Card.IN_TRAY and (int(owner) == seat or not alive(int(owner))): return "RECOGER"
			return ""
		"swipe": return "PASAR FICHA" if held_unswiped(seat) >= 0 else ""
		"pick": return "COGER"
		"read": return "LEER"
	return ""

func hold_of(usable, _seat: int) -> float:
	match String(usable.action):
		"type": return TYPE_TIME
		"take": return TAKE_TIME
		"swipe": return SWIPE_TIME
		"pick": return PICK_TIME
	return 0.0

func begin_use(usable, seat: int) -> void:
	# A new attempt is a new picture.
	if String(usable.action) == "type" and seat == level.player.slot: textures.erase(seat)
	if String(usable.action) == "type" and seat == level.player.slot:
		stop_loop(typing_voice)
		typing_voice = loop_at("typing.wav", usable.global_position, -6.0)

## Partway into the typing the ceiling camera takes this machine's player.
func holding(usable, seat: int, fraction: float) -> void:
	if String(usable.action) == "type" and seat == level.player.slot and fraction >= TYPE_PHOTO_AT and not snapping and not textures.has(seat): snap(seat)

## The ceiling camera's picture (spec 2.4): the world as it is, from the
## camera to the typist, grey and grainy as a security monitor. Nothing on a
## headless machine.
func snap(seat: int) -> void:
	if DisplayServer.get_name() == "headless": return
	snapping = true
	var m := manifest()
	var view := SubViewport.new()
	view.name = "CardPhoto"
	view.size = PHOTO_SIZE
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var camera := Camera3D.new()
	camera.fov = 48.0
	# Not layer 2, as the players' cameras: the lens ghosts are the probes' alone
	# (office_geometry.PROBE_ONLY).
	camera.cull_mask = 1048573
	camera.current = true
	view.add_child(camera)
	level.add_child(view)
	camera.look_at_from_position(v3(m.mail.camera), v3(m.mail.camera_target), Vector3.UP)
	var room_node: Node3D = level.hotel.room_nodes[int(m.mail.window)]
	for frame in 2:
		await RenderingServer.frame_pre_draw
		if not is_instance_valid(view):
			snapping = false
			return
		room_node.visible = true
		view.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	view.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(m.seed), "photo", seat])
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			var grey := clampf(c.r * 0.3 + c.g * 0.59 + c.b * 0.11 + rng.randf_range(-0.05, 0.05), 0.0, 1.0)
			image.set_pixel(x, y, Color(grey * 0.92, grey, grey * 0.9))
	textures[seat] = ImageTexture.create_from_image(image)
	snapping = false

func cancel_use(_usable, _seat: int) -> void:
	stop_loop(typing_voice)
	typing_voice = null

func refused(_action: String, _index: int, _seat: int) -> void: pass

## What the host checks before anybody's use is applied.
func allow(action: String, index: int, seat: int, body) -> bool:
	if not built() or body == null or index < 0 or index >= usables.size() or not ACTIONS.has(action): return false
	if not alive(seat) or bool(body.get("hidden")) or level.lifts.riding.has(seat): return false
	# A card on the floor: its usable is not in the list, its owner is the index.
	if action == "pick": return pickups.has(index) and body.global_position.distance_to(pickups[index].global_position) <= USE_REACH + SLACK
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
			if seat == level.player.slot and not quiet: level.interaction.read_paper(receipt(seat))
			# The typist's own machine sends the photo it took, now that the
			# request is real.
			if seat == level.player.slot and textures.has(seat): send_photo(seat)
		"arrived":
			if requests.has(seat): requests[seat].state = Card.IN_TRAY
			if not quiet and index + 1 < usables.size(): sound_at("tube_bell.wav", usables[index + 1].global_position, -2.0)
		"take":
			for owner in requests:
				var r: Dictionary = requests[owner]
				if int(r.station) == index - 1 and int(r.state) == Card.IN_TRAY and (int(owner) == seat or not alive(int(owner))):
					r.state = Card.HELD
					r.holder = seat
					if seat == level.player.slot and not quiet: level.interaction.read_paper(office_card(int(owner)))
					break
		"drop":
			if requests.has(index):
				requests[index].state = Card.DROPPED
				requests[index].holder = -1
				var at: Vector3 = data.get("at", Vector3.ZERO)
				requests[index]["drop"] = at
				lay_card(index, at)
		"pick":
			if requests.has(index) and int(requests[index].state) == Card.DROPPED:
				requests[index].state = Card.HELD
				requests[index].holder = seat
				if pickups.has(index):
					pickups[index].queue_free()
					pickups.erase(index)
				if seat == level.player.slot and not quiet: level.interaction.read_paper(office_card(index))
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

## Paper ids, clear of the hotel's hints: PAPER_BASE + seat * 10, + 1 for the card.
const PAPER_BASE := 1000
const MAP_ID := 2002

## The network's map (1h, "red"): the planta's walls, the tubes, the
## stations with their numbers and the window, in plan.
func paper_of(_index: int) -> Dictionary:
	var m := manifest()
	var walls: Array = []
	for wall in level.hotel.plan_walls:
		if int(wall[2]) == 0: walls.append([wall[0], wall[1]])
	var flat := func(p: Array) -> Vector2: return Vector2(float(p[0]), float(p[2]))
	var pipes: Array = []
	for edge in m.tubes.edges: pipes.append([flat.call(m.tubes.nodes[int(edge[0])]), flat.call(m.tubes.nodes[int(edge[1])])])
	var stations: Array = []
	for e in station_exits: stations.append([flat.call(e.point), int(e.number)])
	var window: Dictionary = m.rooms[int(m.mail.window)]
	return {"id": MAP_ID, "kind": "red", "plan_walls": walls, "tubes": pipes, "stations": stations, "window": Vector2(float(window.px), float(window.pz))}

## The receipt of a seat's request: the station it went to, its number and
## the time on the tape.
func receipt(seat: int) -> Dictionary:
	var r: Dictionary = requests.get(seat, {})
	if r.is_empty(): return {}
	var clock := int(level.camcorder.start_seconds + level.tape_seconds())
	return {"id": PAPER_BASE + seat * 10, "kind": "resguardo", "planta": 0, "form": {"paper": "resguardo", "station": str(int(station_exits[int(r.station)].number)), "number": String(r.number), "time": [clock / 3600, (clock / 60) % 60]}}

## The card of a seat (its owner's, whoever holds it).
func office_card(owner: int) -> Dictionary:
	var r: Dictionary = requests.get(owner, {})
	if r.is_empty(): return {}
	var date: Array = level.camcorder.date_parts
	return {"id": PAPER_BASE + owner * 10 + 1, "kind": "ficha", "planta": 0, "form": {"paper": "ficha", "name": level.seat_name(owner).to_upper(), "number": String(r.number), "department": "SERVICIOS GENERALES", "date": "%02d/%02d/%02d" % [int(date[0]), int(date[1]), int(date[2])], "level": "1", "photo": textures.get(owner)}}

## A seat's papers: the receipt of its own request, and every card it holds.
func own_papers(seat: int) -> Array:
	var papers: Array = []
	if requests.has(seat): papers.append(receipt(seat))
	for owner in held_cards(seat): papers.append(office_card(int(owner)))
	return papers

## This machine's photo of a seat as a JPEG, kept and sent to the others.
func send_photo(seat: int) -> void:
	var image: Image = (textures[seat] as ImageTexture).get_image()
	var bytes := image.save_jpg_to_buffer(PHOTO_QUALITY)
	if bytes.size() > PHOTO_MAX_BYTES: bytes = image.save_jpg_to_buffer(0.55)
	if bytes.size() > PHOTO_MAX_BYTES: return
	photos[seat] = bytes
	print("PHOTO_BYTES seat=%d bytes=%d" % [seat, bytes.size()])
	level.match_net.send_photo(seat, bytes)

## A photo of a seat that came over the wire (or from a snapshot).
func keep_photo(seat: int, bytes: PackedByteArray) -> void:
	var image := Image.new()
	if image.load_jpg_from_buffer(bytes) != OK: return
	photos[seat] = bytes
	textures[seat] = ImageTexture.create_from_image(image)

## The bots: whoever has no request types; a card in its tray is taken by
## its owner (who read the receipt); a card in hand goes through the reader.
func bot_errands(team) -> Array:
	var errands: Array = []
	if usables.is_empty() or level.session.stage != 1: return errands
	for brain in team.brains:
		if not brain.alive(): continue
		var seat: int = brain.seat
		if not requests.has(seat): errands.append(team.office_task("files:type:%d" % seat, usables[0], seat))
		elif int(requests[seat].state) == Card.IN_TRAY: errands.append(team.office_task("files:take:%d" % seat, usables[int(requests[seat].station) + 1], seat))
		if held_unswiped(seat) >= 0: errands.append(team.office_task("files:swipe:%d" % seat, usables[reader_index()], seat))
	return errands

## The host: whoever falls drops the cards they hold where they fell, on what
## is under them (the duct's floor in the duct), told to everyone.
func on_death(seat: int, point: Vector3) -> void:
	if level.net.is_client(): return
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3(0, 0.5, 0), point - Vector3(0, 2.0, 0), 1)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(ray)
	var at: Vector3 = (hit.position as Vector3) + Vector3(0, 0.01, 0) if not hit.is_empty() else point
	for owner in held_cards(seat):
		apply("drop", int(owner), seat, {"at": at}, false)
		level.match_net.tell_office(ID, "drop", int(owner), seat, {"at": at})

## A dropped card lying on the floor: the card's colour on a small plate, a
## usable to pick it up (its index is the card's owner).
func lay_card(owner: int, at: Vector3) -> void:
	if pickups.has(owner): pickups[owner].queue_free()
	var usable := USABLE.new()
	usable.name = "DroppedCard_%d" % owner
	usable.level = level
	usable.handler = self
	usable.index = owner
	usable.action = "pick"
	usable.box = Vector3(0.4, 0.3, 0.4)
	usable.position = at - Vector3(0, 0, 0.2)
	level.hotel.add_child(usable)
	var card_mesh := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(0.2, 0.004, 0.13)
	card_mesh.mesh = plate
	var material := StandardMaterial3D.new()
	material.albedo_color = Color8(222, 205, 165)
	card_mesh.material_override = material
	card_mesh.position = Vector3(0, 0.002, 0.2)
	card_mesh.rotation.y = randf() * TAU
	usable.add_child(card_mesh)
	pickups[owner] = usable

## Every machine moves the capsules; the host: a capsule that has run its
## tube arrives in its tray.
func tick(_delta: float) -> void:
	if not built() or tube_parent.is_empty(): return
	show_capsules()
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
	for seat in capsules:
		capsules[seat].node.queue_free()
		stop_loop(capsules[seat].hiss)
	capsules.clear()
	for owner in pickups: pickups[owner].queue_free()
	pickups.clear()
	textures.clear()
	photos.clear()
	requests.clear()
	swiped.clear()
	show_state()

func snapshotted() -> bool: return true

func snapshot() -> Dictionary: return {"requests": requests.duplicate(true), "swiped": swiped.duplicate(), "photos": photos.duplicate()}

func restore(data: Dictionary) -> void:
	requests = {}
	var kept: Dictionary = data.get("requests", {})
	for seat in kept: requests[int(seat)] = kept[seat]
	swiped = data.get("swiped", []).map(func(seat): return int(seat))
	var kept_photos: Dictionary = data.get("photos", {})
	for seat in kept_photos: keep_photo(int(seat), kept_photos[seat])
	for owner in requests:
		if int(requests[owner].state) == Card.DROPPED: lay_card(int(owner), requests[owner].get("drop", Vector3.ZERO))
	show_state()
