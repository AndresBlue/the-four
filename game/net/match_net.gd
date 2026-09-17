extends Node
## Replication of an online floor. The host decides: map seed, doors, wardrobes,
## the creature (its AI, or its strikes when a player is The Locust), deaths,
## leaving the floor and when it ends. Every machine builds the same floor from
## the seed (the generator is deterministic) and checks it with a hash.
##
## Each player moves their own body and sends its state about twenty times a
## second; the others show it as a remote_player.gd body. Actions that change
## the shared world (a door, a wardrobe) are asked of the host, which applies
## them and tells everyone. Noises are sent to the host, which is where the
## creature listens.
const REMOTE := preload("res://game/net/remote_player.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SEND_RATE := 20.0
const SESSION_RATE := 2.0
## A dropped player's body stays on the floor this long before counting as lost.
const RECONNECT_GRACE := 60.0
## Longest wait for everyone's floor to be built before starting without them.
const READY_TIMEOUT := 30.0
## The host's floor to resume after a crash or a quit (online only).
const CHECKPOINT := "user://coop_checkpoint.json"
## A door or wardrobe request from further than this is ignored.
const REACH := 5.0
## Where seats stand when the floor starts (around the reception's red lamp).
const SPAWN_RADIUS := 1.2
signal started
var net
var level
## The running match: {seed, mode, locust_seat, survivors, players}.
var config := {}
## seat -> remote body (survivors other than this machine's player).
var bodies := {}
var ready_seats := {}
var waiting_time := -1.0
var send_clock := 0.0
var session_clock := 0.0
## seat -> seconds since that player dropped.
var away := {}
## Seat whose view a dead player is watching.
var watching := 0
var manifest_hash := 0
## Snapshot to apply once the floor is built (coming back after a drop).
var rejoin_snapshot := {}
var checkpoint_path := CHECKPOINT

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func in_match() -> bool:
	return not config.is_empty()

func versus() -> bool:
	return in_match() and int(config.mode) == net.Mode.VERSUS

func locust_seat() -> int:
	return int(config.get("locust_seat", 0))

## This machine plays The Locust.
func local_is_locust() -> bool:
	return versus() and locust_seat() == net.local_seat

func is_survivor(seat: int) -> bool:
	return in_match() and config.survivors.has(seat)

func end() -> void:
	for body in bodies.values():
		if is_instance_valid(body): body.queue_free()
	bodies.clear()
	config = {}
	ready_seats.clear()
	away.clear()
	waiting_time = -1.0
	rejoin_snapshot = {}
	watching = 0

# --- Start ---------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func begin(data: Dictionary, snapshot := {}) -> void:
	end()
	config = data
	var survivors: Array = []
	for seat in data.survivors: survivors.append(int(seat))
	config.survivors = survivors
	var seats := {}
	for seat in data.players: seats[int(seat)] = data.players[seat]
	config.players = seats
	config.locust_seat = int(data.locust_seat)
	config.mode = int(data.mode)
	rejoin_snapshot = snapshot
	level.start_online_floor(config)

## Called by the level once its floor exists and passed validation.
func floor_built() -> void:
	manifest_hash = hash(JSON.stringify(level.manifest))
	var seat := int(net.local_seat)
	for other in config.survivors:
		if other == seat: continue
		var body := REMOTE.new()
		body.setup(level, other, config.players[other].name, int(config.players[other].character))
		body.process_mode = Node.PROCESS_MODE_PAUSABLE
		level.add_child(body)
		body.place(spawn_point(other), level.player.rotation.y)
		bodies[other] = body
	if net.is_host:
		for index in level.hotel.doors.size():
			var door = level.hotel.doors[index]
			door.swung.connect(func(target, slow, forceful): door_swung.rpc(index, target, slow, forceful))
			door.settled.connect(func(opened): door_settled.rpc(index, opened))
		for index in level.hotel.hides.size():
			level.hotel.hides[index].forced.connect(func(): hide_forced.rpc(index))
		ready_seats = {1: manifest_hash}
		waiting_time = 0.0
		check_ready()
	else:
		report_ready.rpc_id(1, manifest_hash)

func spawn_point(seat: int) -> Vector3:
	var angle := TAU * float(seat - 1) / float(net.MAX_PLAYERS)
	return Vector3(cos(angle), 0.0, sin(angle)) * SPAWN_RADIUS + Vector3(0, 0.04, 0)

@rpc("any_peer", "call_remote", "reliable")
func report_ready(floor_hash: int) -> void:
	if not net.is_host: return
	var id := multiplayer.get_remote_sender_id()
	var seat: int = net.seat_of_peer(id)
	if seat == 0: return
	if floor_hash != manifest_hash:
		push_warning("Seat %d built a different floor" % seat)
		net.refuse(id, "Tu piso no coincide con el del anfitrión: usad todos el mismo exe.")
		return
	if level.session.state in [level.session.State.PLAYING, level.session.State.TRANSITION]:
		# Coming back into a running floor: bring them up to date.
		catch_up(seat, id)
		return
	ready_seats[seat] = floor_hash
	check_ready()

func check_ready() -> void:
	if not net.is_host or waiting_time < 0.0: return
	for seat in net.connected_seats():
		if not ready_seats.has(seat): return
	waiting_time = -1.0
	go.rpc()
	go()

## Everyone has the floor: play.
@rpc("authority", "call_remote", "reliable")
func go() -> void:
	level.begin_online_play(config)
	if net.is_host:
		write_checkpoint()
		for seat in config.survivors:
			if not net.connected_seats().has(seat): seat_dropped(seat)
		push_session()
	started.emit()

# --- Per frame -------------------------------------------------------------------

func _process(delta: float) -> void:
	if not in_match() or not net.active(): return
	if waiting_time >= 0.0:
		waiting_time += delta
		if waiting_time > READY_TIMEOUT:
			# Start without whoever could not build the floor in time.
			for seat in net.connected_seats():
				ready_seats[seat] = manifest_hash
			check_ready()
	if not net.is_host: return
	for seat in away.keys():
		away[seat] += delta
		if away[seat] >= RECONNECT_GRACE:
			away.erase(seat)
			level.session.drop(seat)
			if bodies.has(seat): bodies[seat].visible = false
	session_clock -= delta
	if session_clock <= 0.0:
		session_clock = 1.0 / SESSION_RATE
		push_session()

func _physics_process(delta: float) -> void:
	if not in_match() or not net.active() or level.session.state not in [level.session.State.PLAYING, level.session.State.TRANSITION]: return
	send_clock -= delta
	if send_clock > 0.0: return
	send_clock = 1.0 / SEND_RATE
	if is_survivor(net.local_seat) and level.session.participants.get(net.local_seat, 2) != level.session.Life.DEAD:
		player_state.rpc(net.local_seat, pack_local())
	var creature = level.locust
	if is_instance_valid(creature) and creature.control != "puppet":
		locust_state.rpc(creature.pack_state())

func pack_local() -> Array:
	var player = level.player
	var flags := (1 if player.crouched else 0) | (2 if player.torch.visible else 0) | (4 if level.exit_held else 0) | (8 if player.reading else 0)
	var left := 0.0
	var right := 0.0
	var hide_index := -1
	if player.hidden and is_instance_valid(player.hiding_place):
		left = player.hiding_place.peek.left
		right = player.hiding_place.peek.right
		hide_index = level.hotel.hides.find(player.hiding_place)
	return [player.global_position, player.rotation.y, player.camera.rotation.x, player.velocity, flags, hide_index, left, right]

@rpc("any_peer", "call_remote", "unreliable_ordered")
func player_state(seat: int, data: Array) -> void:
	if net.is_host and net.players.get(seat, {}).get("peer", -1) != multiplayer.get_remote_sender_id(): return
	if bodies.has(seat) and data.size() == 8: bodies[seat].push_state(data)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func locust_state(data: Array) -> void:
	var creature = level.locust
	if not is_instance_valid(creature) or creature.control != "puppet": return
	var author := 1 if not versus() else int(net.players.get(locust_seat(), {}).get("peer", -1))
	if multiplayer.get_remote_sender_id() != author and net.is_host: return
	creature.push_state(data)

# --- Session ---------------------------------------------------------------------

func push_session() -> void:
	if not net.is_host or not in_match(): return
	var session = level.session
	session_state.rpc(session.state, session.participants, session.exit_progress, session.elapsed, session.message)

@rpc("authority", "call_remote", "reliable")
func session_state(state: int, participants: Dictionary, progress: float, elapsed: float, message: String) -> void:
	var session = level.session
	if not in_match() or session.state in [session.State.LOADING, session.State.MENU] and state != session.State.PLAYING: return
	var lives := {}
	for seat in participants: lives[int(seat)] = participants[seat]
	var deaths_changed: bool = lives != session.participants
	session.participants = lives
	session.exit_progress = progress
	session.elapsed = elapsed
	session.message = message
	if state != session.state: session.set_state(state)
	elif deaths_changed: session.changed.emit()

# --- Doors -----------------------------------------------------------------------

## The level asks for a door to swing. Offline or on the host it happens now.
func use_door(door: Node, slow: bool, forceful: bool) -> bool:
	if not in_match() or net.is_host: return door.toggle(slow, true, forceful)
	request_door.rpc_id(1, level.hotel.doors.find(door), slow, forceful)
	return true

@rpc("any_peer", "call_remote", "reliable")
func request_door(index: int, slow: bool, forceful: bool) -> void:
	if not net.is_host or index < 0 or index >= level.hotel.doors.size(): return
	var door = level.hotel.doors[index]
	if not near_sender(door.doorway): return
	door.toggle(slow, true, forceful)

@rpc("authority", "call_remote", "reliable")
func door_swung(index: int, target: bool, slow: bool, forceful: bool) -> void:
	if not is_instance_valid(level.hotel) or index >= level.hotel.doors.size(): return
	level.hotel.doors[index].swing_to(target, slow, forceful)

@rpc("authority", "call_remote", "reliable")
func door_settled(index: int, opened: bool) -> void:
	if not is_instance_valid(level.hotel) or index >= level.hotel.doors.size(): return
	var door = level.hotel.doors[index]
	if door.opened != opened or door.moving: door.set_state(opened)

## The body of whoever sent the current request, and whether it is near.
func near_sender(point: Vector3) -> bool:
	var seat: int = net.seat_of_peer(multiplayer.get_remote_sender_id())
	var body = body_of(seat)
	return body != null and Vector2(body.global_position.x - point.x, body.global_position.z - point.z).length() < REACH

func body_of(seat: int) -> Node3D:
	if seat == net.local_seat: return level.locust if local_is_locust() else level.player
	if seat == locust_seat() and versus(): return level.locust
	return bodies.get(seat)

# --- Wardrobes -------------------------------------------------------------------

## Enter or leave a wardrobe; online, the host decides who gets in.
func use_hide(hide: Node3D, entering: bool) -> bool:
	var index: int = level.hotel.hides.find(hide)
	if not in_match():
		return level.player.enter_hide(hide) if entering else level.player.leave_hide()
	if net.is_host:
		var done: bool = level.player.enter_hide(hide) if entering else level.player.leave_hide()
		if done: hide_state.rpc(index, net.local_seat if entering else -net.local_seat)
		return done
	if entering:
		request_hide.rpc_id(1, index, true)
		return true
	if level.player.leave_hide():
		request_hide.rpc_id(1, index, false)
		return true
	return false

@rpc("any_peer", "call_remote", "reliable")
func request_hide(index: int, entering: bool) -> void:
	if not net.is_host or index < 0 or index >= level.hotel.hides.size(): return
	var seat: int = net.seat_of_peer(multiplayer.get_remote_sender_id())
	var body: Node3D = bodies.get(seat)
	var hide = level.hotel.hides[index]
	if body == null: return
	if entering:
		if is_instance_valid(hide.occupant) or not near_sender(hide.global_position): return
		# Seen climbing in, the creature knows where they are.
		var creature = level.locust
		if is_instance_valid(creature) and creature.control == "ai" and creature.sees(body, true): creature.observed_hide = hide
		remote_enters(hide, body)
		hide_state.rpc(index, seat)
	elif hide.occupant == body:
		remote_leaves(hide, body)
		hide_state.rpc(index, -seat)

@rpc("authority", "call_remote", "reliable")
func hide_state(index: int, seat: int) -> void:
	if not is_instance_valid(level.hotel) or index < 0 or index >= level.hotel.hides.size(): return
	var hide = level.hotel.hides[index]
	if seat == net.local_seat:
		level.player.enter_hide(hide)
	elif seat > 0 and bodies.has(seat):
		remote_enters(hide, bodies[seat])
	elif seat < 0 and -seat != net.local_seat and bodies.has(-seat) and hide.occupant == bodies[-seat]:
		remote_leaves(hide, bodies[-seat])

func remote_enters(hide: Node3D, body: Node3D) -> void:
	hide.enter(body)
	body.hidden = true
	body.hiding_place = hide
	body.torch.visible = false
	level.world_audio.hide_cue(true, hide.global_position)

func remote_leaves(hide: Node3D, body: Node3D) -> void:
	hide.leave()
	body.hidden = false
	body.hiding_place = null
	level.world_audio.hide_cue(false, hide.global_position)

@rpc("authority", "call_remote", "reliable")
func hide_forced(index: int) -> void:
	if is_instance_valid(level.hotel) and index >= 0 and index < level.hotel.hides.size(): level.hotel.hides[index].force_open()

# --- Noise, sounds and the creature's calls ----------------------------------------

## A noise the local player made; the creature listens on the host.
func noise(point: Vector3, radius: float) -> void:
	if not in_match() or net.is_host: level.locust_hear(point, radius)
	else: player_noise.rpc_id(1, point, radius)

@rpc("any_peer", "call_remote", "unreliable")
func player_noise(point: Vector3, radius: float) -> void:
	if net.is_host and net.seat_of_peer(multiplayer.get_remote_sender_id()) != 0: level.locust_hear(point, radius)

## A world sound decided on the host (director events), heard by everyone.
func world_sound(path: String, point: Vector3, gain: float, start: float) -> void:
	if in_match() and net.is_host: play_world_sound.rpc(path, point, gain, start)

@rpc("authority", "call_remote", "reliable")
func play_world_sound(path: String, point: Vector3, gain: float, start: float) -> void:
	if path.begins_with("res://assets/audio/"): level.world_audio.play_at(path, point, gain, RID(), start)

## The creature called out (grunt or strike warning) where it is authoritative.
func creature_call(kind: String, segment: int, pitch: float) -> void:
	if in_match(): locust_call.rpc(kind, segment, pitch)

@rpc("any_peer", "call_remote", "reliable")
func locust_call(kind: String, segment: int, pitch: float) -> void:
	var creature = level.locust
	if is_instance_valid(creature) and creature.control == "puppet": creature.play_call(kind, segment, pitch)

# --- Deaths and watching -----------------------------------------------------------

## Living teammates a dead player can watch, in seat order.
func watchable() -> Array:
	var result: Array = []
	for seat in config.get("survivors", []):
		if seat != net.local_seat and bodies.has(seat) and level.session.participants.get(seat, 2) != level.session.Life.DEAD: result.append(seat)
	return result

func next_watch() -> void:
	var seats := watchable()
	if seats.is_empty():
		watching = 0
		return
	var at := seats.find(watching)
	watching = seats[(at + 1) % seats.size()]

func watched_body() -> Node3D:
	if not watchable().has(watching): next_watch()
	return bodies.get(watching)

# --- Drops and returns ------------------------------------------------------------

func seat_dropped(seat: int) -> void:
	if not in_match() or not config.survivors.has(seat) and seat != locust_seat(): return
	if level.session.participants.get(seat, 2) == level.session.Life.DEAD: return
	away[seat] = 0.0
	if bodies.has(seat): bodies[seat].away = true

func seat_returned(seat: int, _peer_id: int) -> void:
	away.erase(seat)
	if bodies.has(seat): bodies[seat].away = false
	if not in_match(): return
	# They rebuild the same floor, then catch_up() fills in what changed.
	begin.rpc_id(_peer_id, config, {"returning": true})

## Everything a returning player needs after rebuilding the floor.
func catch_up(seat: int, id: int) -> void:
	var doors: Array = level.hotel.doors.map(func(door): return door.opened)
	var hides: Array = level.hotel.hides.map(func(hide):
		for other in bodies:
			if hide.occupant == bodies[other]: return other
		return net.local_seat if hide.occupant == level.player else 0)
	var places := {}
	for other in config.survivors:
		var body := body_of(other)
		if body != null: places[other] = [body.global_position, body.rotation.y]
	var creature = level.locust
	restore.rpc_id(id, doors, hides, places, creature.pack_state() if is_instance_valid(creature) else [], level.sheet_snapshot())
	session_state.rpc_id(id, level.session.state, level.session.participants, level.session.exit_progress, level.session.elapsed, level.session.message)

@rpc("authority", "call_remote", "reliable")
func restore(doors: Array, hides: Array, places: Dictionary, creature: Array, sheet: Array) -> void:
	level.begin_online_play(config)
	for index in mini(doors.size(), level.hotel.doors.size()): level.hotel.doors[index].set_state(doors[index])
	for seat_key in places:
		var seat := int(seat_key)
		if seat == net.local_seat:
			level.player.global_position = places[seat_key][0]
			level.player.rotation.y = places[seat_key][1]
		elif bodies.has(seat): bodies[seat].place(places[seat_key][0], places[seat_key][1])
	for index in mini(hides.size(), level.hotel.hides.size()):
		if int(hides[index]) != 0: hide_state(index, int(hides[index]))
	if not creature.is_empty() and is_instance_valid(level.locust): level.locust.push_state(creature)
	level.restore_sheet(sheet)

@rpc("authority", "call_remote", "reliable")
func back_to_room() -> void:
	end()
	level.leave_online_floor()

# --- Checkpoint ---------------------------------------------------------------------

func write_checkpoint() -> void:
	var file := FileAccess.open(checkpoint_path, FileAccess.WRITE)
	if file: file.store_string(JSON.stringify({"format": 1, "generator": FLOOR.VERSION, "seed": config.seed, "mode": config.mode}))

func clear_checkpoint() -> void:
	if FileAccess.file_exists(checkpoint_path): DirAccess.remove_absolute(checkpoint_path)

func saved_checkpoint() -> Dictionary:
	if not FileAccess.file_exists(checkpoint_path): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path))
	if not data is Dictionary or data.get("format") != 1 or data.get("generator") != FLOOR.VERSION: return {}
	if not (data.get("seed") is float or data.get("seed") is int): return {}
	return data
