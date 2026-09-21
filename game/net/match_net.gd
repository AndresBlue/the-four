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

## This machine decides: the host online, and the only machine there is when
## nobody is connected. Everything the hunter asks for goes through here, so
## the local preview takes the same path instead of sending an RPC to itself.
func in_charge() -> bool:
	return not net.is_client()

func versus() -> bool:
	return in_match() and int(config.mode) == net.Mode.VERSUS

func locust_seat() -> int:
	return int(config.get("locust_seat", 0))

## This machine plays The Locust: the hunter's seat in a versus match, or the
## local preview started with --locust (hotel_main.solo_locust).
func local_is_locust() -> bool:
	if is_instance_valid(level) and level.solo_locust: return true
	return versus() and locust_seat() == net.local_seat

func is_survivor(seat: int) -> bool:
	return in_match() and config.survivors.has(seat)

func end() -> void:
	wardrobe_jobs.clear()
	shriek_left = 0.0
	shriek_seen.clear()
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

## Called by the level before it starts putting a floor up: until it is built
## there is nothing to compare anybody else's against.
func floor_building() -> void:
	manifest_hash = 0
	pending_ready.clear()

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
		# Whoever got there first, while this machine still had no floor of
		# its own to compare with.
		for seat_waiting in pending_ready.keys():
			var waited: Array = pending_ready[seat_waiting]
			judge_ready(int(seat_waiting), int(waited[0]), int(waited[1]))
		pending_ready.clear()
		check_ready()
	else:
		report_ready.rpc_id(1, manifest_hash)

func spawn_point(seat: int) -> Vector3:
	var angle := TAU * float(seat - 1) / float(net.MAX_PLAYERS)
	return Vector3(cos(angle), 0.0, sin(angle)) * SPAWN_RADIUS + Vector3(0, 0.04, 0)

## A guest can finish its floor before the host finishes its own -- a floor
## takes a second and a half to put up and machines differ -- so a report that
## arrives early is kept until there is something to compare it against.
## Judging it against nothing threw guests out of matches over floors that
## were identical.
var pending_ready := {}

@rpc("any_peer", "call_remote", "reliable")
func report_ready(floor_hash: int) -> void:
	if not net.is_host: return
	var id := multiplayer.get_remote_sender_id()
	var seat: int = net.seat_of_peer(id)
	if seat == 0: return
	if manifest_hash == 0:
		pending_ready[seat] = [id, floor_hash]
		return
	judge_ready(seat, id, floor_hash)

func judge_ready(seat: int, id: int, floor_hash: int) -> void:
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
	# Wardrobes are searched, and the shriek listens, offline too: the local
	# Locust preview is the same code path with nobody connected.
	if is_instance_valid(level) and is_instance_valid(level.hotel) and in_charge():
		update_wardrobe_jobs(delta)
		if is_instance_valid(level.locust): update_shriek(delta)
	if not in_match() or not net.active(): return
	# Dead teammates leave no body in the way.
	for seat in bodies:
		bodies[seat].set_dead(level.session.participants.get(seat, level.session.Life.DEAD) == level.session.Life.DEAD)
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
	var flags := (1 if player.crouched else 0) | (2 if player.torch.visible else 0) | (4 if player.burnt else 0) | (8 if player.reading else 0)
	var left := 0.0
	var right := 0.0
	var hide_index := -1
	if player.hidden and is_instance_valid(player.hiding_place):
		left = player.hiding_place.peek.left
		right = player.hiding_place.peek.right
		hide_index = level.hotel.hides.find(player.hiding_place)
	return [player.global_position, player.rotation.y, player.look_pitch(), player.velocity, flags, hide_index, left, right]

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
	session_state.rpc(session.state, session.participants, session.elapsed, session.message, session.stage, session.goal)

@rpc("authority", "call_remote", "reliable")
func session_state(state: int, participants: Dictionary, elapsed: float, message: String, stage: int, goal: Dictionary) -> void:
	var session = level.session
	if not in_match() or session.state in [session.State.LOADING, session.State.MENU] and state != session.State.PLAYING: return
	var stage_changed: bool = stage != session.stage or goal != session.goal
	session.stage = stage
	session.goal = goal
	var lives := {}
	for seat in participants: lives[int(seat)] = participants[seat]
	var deaths_changed: bool = lives != session.participants
	session.participants = lives
	session.elapsed = elapsed
	session.message = message
	if state != session.state: session.set_state(state)
	elif deaths_changed or stage_changed: session.changed.emit()

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

# --- Televisions -----------------------------------------------------------------

## Switching a set on. Offline or on the host it happens now; a guest asks,
## and the host tells everyone. They only ever go on, so there is nothing to
## undo and no order to get wrong.
func use_television(set: Node3D) -> void:
	var index: int = level.televisions.find(set)
	if index < 0: return
	if not in_match() or net.is_host:
		level.apply_television(index, true)
		if in_match(): television_state.rpc(index, true)
		return
	request_television.rpc_id(1, index)

@rpc("any_peer", "call_remote", "reliable")
func request_television(index: int) -> void:
	if not net.is_host or index < 0 or index >= level.televisions.size(): return
	var set = level.televisions[index]
	if not is_instance_valid(set) or set.on or not near_sender(set.global_position): return
	level.apply_television(index, true)
	television_state.rpc(index, true)

@rpc("authority", "call_remote", "reliable")
func television_state(index: int, value: bool) -> void:
	level.apply_television(index, value)

## The creature travels by television: from the lit set it is standing at to
## any other lit one. The host judges it, as it judges a strike.
func locust_warp(index: int) -> void:
	if not in_match() or net.is_host:
		if level.creature_at_television() >= 0:
			level.warp_creature(index)
			if in_match(): warp_state.rpc(index)
		return
	request_warp.rpc_id(1, index)

@rpc("any_peer", "call_remote", "reliable")
func request_warp(index: int) -> void:
	if not net.is_host or not versus() or multiplayer.get_remote_sender_id() != locust_peer(): return
	if level.creature_at_television() < 0 or not level.lit_televisions().has(index): return
	level.warp_creature(index)
	warp_state.rpc(index)

@rpc("authority", "call_remote", "reliable")
func warp_state(index: int) -> void:
	level.warp_creature(index)

# --- Drawers and shelves ---------------------------------------------------------

## Going through a piece of furniture. Like a television, it only ever goes one
## way, so there is nothing to undo.
func use_container(piece: Node3D) -> void:
	var index: int = level.containers.find(piece)
	if index < 0: return
	if not in_match() or net.is_host:
		level.apply_search(index, true)
		if in_match(): container_state.rpc(index, true)
		return
	request_container.rpc_id(1, index)

@rpc("any_peer", "call_remote", "reliable")
func request_container(index: int) -> void:
	if not net.is_host or index < 0 or index >= level.containers.size(): return
	var piece = level.containers[index]
	if not is_instance_valid(piece) or piece.searched or not near_sender(piece.global_position): return
	level.apply_search(index, true)
	container_state.rpc(index, true)

@rpc("authority", "call_remote", "reliable")
func container_state(index: int, value: bool) -> void:
	level.apply_search(index, value)

## The code read into the last door's keypad. A guest asks; the host checks the
## numbers itself, so a client cannot open a floor by saying it did.
func use_code() -> void:
	if not in_match() or net.is_host:
		level.apply_code()
		if in_match(): code_state.rpc()
		return
	request_code.rpc_id(1, level.typed)

@rpc("any_peer", "call_remote", "reliable")
func request_code(text: String) -> void:
	if not net.is_host or level.code_entered: return
	var right: String = "".join(level.DIGITS.code(level.manifest).map(func(digit): return str(digit)))
	if text != right: return
	level.apply_code()
	code_state.rpc()

@rpc("authority", "call_remote", "reliable")
func code_state() -> void:
	level.apply_code()

## Everybody up again, and where. The host decides; every machine puts its own
## body back and the others where it is told.
func revive_everyone(places: Dictionary, restart: bool) -> void:
	if in_match(): revived_state.rpc(places, restart)

@rpc("authority", "call_remote", "reliable")
func revived_state(places: Dictionary, restart: bool) -> void:
	level.apply_revival(places, restart)

## Somebody took a lift: the host says who, and where they come out.
func ride_lift(seat: int, point: Vector3) -> void:
	if in_match(): ride_state.rpc(seat, point)

@rpc("authority", "call_remote", "reliable")
func ride_state(seat: int, point: Vector3) -> void:
	level.apply_ride(seat, point)

## The creature took it too. In versus the machine that drives it owns where
## it stands, so this is the one move the host gets to make for it: everybody
## is told, and the hunter's own body goes with the car like anybody else's.
func locust_ride(point: Vector3) -> void:
	level.apply_locust_ride(point)
	if in_match(): locust_rode.rpc(point)

@rpc("authority", "call_remote", "reliable")
func locust_rode(point: Vector3) -> void:
	level.apply_locust_ride(point)

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
func noise(point: Vector3, radius: float, kind := 0) -> void:
	if not in_match() or net.is_host: level.locust_hear(point, radius, kind)
	else: player_noise.rpc_id(1, point, radius, kind)

@rpc("any_peer", "call_remote", "unreliable")
func player_noise(point: Vector3, radius: float, kind: int) -> void:
	if net.is_host and net.seat_of_peer(multiplayer.get_remote_sender_id()) != 0: level.locust_hear(point, radius, kind)

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

# --- Versus: a player is The Locust --------------------------------------------------

## Angle either side of its facing within which a strike connects.
const STRIKE_ANGLE := 70.0
## The shriek: how far it listens, how long it keeps listening and how often
## it sends what it found.
const SHRIEK_RANGE := 26.0
const SHRIEK_TIME := 4.0
const SHRIEK_RATE := 5.0
var shriek_left := 0.0
var shriek_clock := 0.0

func locust_peer() -> int:
	return int(net.players.get(locust_seat(), {}).get("peer", -1))

## The Locust player's strike ended its wind-up here, facing this way.
func locust_strike(origin: Vector3, facing: Vector3) -> void:
	if in_charge(): resolve_strike(origin, facing)
	else: strike.rpc_id(1, origin, facing)

@rpc("any_peer", "call_remote", "reliable")
func strike(origin: Vector3, facing: Vector3) -> void:
	if not net.is_host or not versus() or multiplayer.get_remote_sender_id() != locust_peer(): return
	resolve_strike(origin, facing)

## The host judges a strike with its own copy of everyone's positions: the
## nearest living survivor in reach, in front and in clear sight (a hidden one
## only through open wardrobe doors) is struck down.
func resolve_strike(origin: Vector3, facing: Vector3) -> void:
	var creature = level.locust
	if not is_instance_valid(creature) or creature.grace > 0.0: return
	# The claimed spot must match where the host sees the creature.
	if origin.distance_to(creature.global_position) > 3.0: origin = creature.global_position
	facing.y = 0.0
	var best: Node3D = null
	var best_distance: float = creature.STRIKE_REACH
	for body in level.survivors():
		if not level.survivor_active(body): continue
		var offset: Vector3 = body.global_position - origin
		offset.y = 0.0
		var distance := offset.length()
		if distance >= best_distance: continue
		if distance > 0.8 and facing.length() > 0.1 and rad_to_deg(facing.angle_to(offset)) > STRIKE_ANGLE: continue
		if body.hidden and not (is_instance_valid(body.hiding_place) and body.hiding_place.ajar()): continue
		var ray := PhysicsRayQueryParameters3D.create(origin + Vector3(0, creature.EYE_HEIGHT, 0), body.camera.global_position, 1 | 8 | 64)
		ray.exclude = [creature.get_rid()]
		if not creature.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		best = body
		best_distance = distance
	level.capture_survivor(best)

## The Locust player searches a wardrobe: the host runs the ritual (leaf by
## leaf, then a look inside).
func locust_open_hide(hide: Node3D) -> void:
	var index: int = level.hotel.hides.find(hide)
	if in_charge(): level.open_wardrobe(hide)
	else: request_force.rpc_id(1, index)

@rpc("any_peer", "call_remote", "reliable")
func request_force(index: int) -> void:
	if not net.is_host or not versus() or multiplayer.get_remote_sender_id() != locust_peer(): return
	if index < 0 or index >= level.hotel.hides.size(): return
	var hide = level.hotel.hides[index]
	if hide.global_position.distance_to(level.locust.global_position) < REACH: level.open_wardrobe(hide)

## The Locust player shrieked: the host listens for it for a few seconds.
func locust_shriek() -> void:
	shriek_seen.clear()
	if in_charge(): shriek_left = SHRIEK_TIME
	else: request_shriek.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func request_shriek() -> void:
	if net.is_host and versus() and multiplayer.get_remote_sender_id() == locust_peer(): shriek_left = SHRIEK_TIME

## Metres per second below which a survivor is standing still enough that the
## shriek finds nothing to come back from. Holding still is the counter to
## being shrieked at. Measured as ground actually covered between two of its
## readings, not from a velocity field: what matters is whether they moved.
const SHRIEK_STIR := 0.45
## Where each survivor was at the shriek's last reading.
var shriek_seen := {}

## While the shriek lasts, where the survivors within earshot are. It only
## finds what is moving and out in the open: someone frozen, or shut in a
## wardrobe, gives it nothing.
func update_shriek(delta: float) -> void:
	if shriek_left <= 0.0: return
	shriek_left -= delta
	shriek_clock -= delta
	if shriek_clock > 0.0: return
	shriek_clock = 1.0 / SHRIEK_RATE
	var creature = level.locust
	if not is_instance_valid(creature): return
	var points := PackedVector3Array()
	for body in level.survivors():
		if not level.survivor_active(body): continue
		var here: Vector3 = body.global_position
		var before = shriek_seen.get(body.slot)
		shriek_seen[body.slot] = here
		if body.hidden: continue
		# The first reading has nothing to compare against, so the cry takes a
		# fifth of a second to tell anyone apart from the furniture.
		if before == null: continue
		if (here - before).length() * SHRIEK_RATE < SHRIEK_STIR: continue
		if here.distance_to(creature.global_position) > SHRIEK_RANGE: continue
		points.append(here + Vector3(0, 1.2, 0))
	if locust_seat() == net.local_seat or not net.active():
		if is_instance_valid(creature.driver): creature.driver.reveal(points)
	elif locust_peer() > 0: shriek_reveal.rpc_id(locust_peer(), points)

## The way on has opened somewhere else: the creature is shown the road to it
## in its own reading, so it does not keep hunting a wing nobody is in.
func tell_stage(points: PackedVector3Array) -> void:
	if not in_match() or locust_seat() == net.local_seat:
		var creature = level.locust
		if is_instance_valid(creature) and is_instance_valid(creature.driver) and creature.driver.has_method("mark_stage"): creature.driver.mark_stage(points)
		return
	if locust_peer() > 0: stage_road.rpc_id(locust_peer(), points)

@rpc("authority", "call_remote", "reliable")
func stage_road(points: PackedVector3Array) -> void:
	if local_is_locust() and is_instance_valid(level.locust) and is_instance_valid(level.locust.driver): level.locust.driver.mark_stage(points)

@rpc("authority", "call_remote", "unreliable")
func shriek_reveal(points: PackedVector3Array) -> void:
	if local_is_locust() and is_instance_valid(level.locust) and is_instance_valid(level.locust.driver): level.locust.driver.reveal(points)

## A noise the creature would hear: shown to the player who is The Locust.
## A noise the creature hears, as it hears it. `point` is where it happened and
## `route` is hotel_locust.hear_route: close by, the image paints the real spot;
## far away, only the opening the sound came through.
func tell_hunter(point: Vector3, route: Dictionary, radius: float, kind: int) -> void:
	var strength := clampf(radius / 16.0, 0.25, 1.0)
	if locust_seat() == net.local_seat or not net.active():
		if is_instance_valid(level.locust.driver): level.locust.driver.hear_contact(point, route.apparent, route.distance, strength, kind, route.muffle)
	elif locust_peer() > 0:
		heard_contact.rpc_id(locust_peer(), point, route.apparent, route.distance, strength, kind, route.muffle)

@rpc("authority", "call_remote", "unreliable")
func heard_contact(point: Vector3, apparent: Vector3, distance: float, strength: float, kind: int, muffle: float) -> void:
	if local_is_locust() and is_instance_valid(level.locust) and is_instance_valid(level.locust.driver): level.locust.driver.hear_contact(point, apparent, distance, strength, kind, muffle)

# --- Wardrobes searched by the creature, and executions -------------------------------

## Wardrobes being searched: {hide, index, time, step}.
var wardrobe_jobs: Array = []

## The creature plants itself and searches this wardrobe (host, or offline).
func begin_wardrobe_job(hide: Node3D) -> void:
	if not is_instance_valid(hide): return
	for job in wardrobe_jobs:
		if job.hide == hide: return
	wardrobe_jobs.append({"hide": hide, "index": level.hotel.hides.find(hide), "time": 0.0, "step": 0})

## One leaf at a time, then a look inside: whoever is in there is pulled out.
func update_wardrobe_jobs(delta: float) -> void:
	for job in wardrobe_jobs.duplicate():
		if not is_instance_valid(job.hide):
			wardrobe_jobs.erase(job)
			continue
		job.time += delta
		var steps: Dictionary = level.locust.WARDROBE_TIME if is_instance_valid(level.locust) else {"right": 0.85, "left": 1.3, "reach": 1.7, "done": 2.5}
		if job.step == 0 and job.time >= steps.right:
			job.step = 1
			pull_leaf(job, "right")
		elif job.step == 1 and job.time >= steps.left:
			job.step = 2
			pull_leaf(job, "left")
		elif job.step == 2 and job.time >= steps.reach:
			job.step = 3
			var occupant = job.hide.occupant
			var creature = level.locust
			if is_instance_valid(occupant) and level.survivor_active(occupant) and is_instance_valid(creature) and creature.global_position.distance_to(job.hide.global_position) < 3.4:
				level.capture_survivor(occupant)
		elif job.step == 3 and job.time >= steps.done + 0.4:
			job.hide.close_timer = 2.0
			wardrobe_jobs.erase(job)

func pull_leaf(job: Dictionary, side: String) -> void:
	job.hide.open_leaf(side)
	if in_match(): leaf_opened.rpc(job.index, side)

@rpc("authority", "call_remote", "reliable")
func leaf_opened(index: int, side: String) -> void:
	if is_instance_valid(level.hotel) and index >= 0 and index < level.hotel.hides.size(): level.hotel.hides[index].open_leaf(side)

## An execution decided by the host: everyone plays it out (hotel_main).
@rpc("authority", "call_remote", "reliable")
func execute_start(seat: int, point: Vector3, yaw: float) -> void:
	level.apply_execution(seat, point, yaw)

## The victim was inside a wardrobe: it is pulled out of it first.
func free_victim_hide(seat: int) -> void:
	var body = bodies.get(seat)
	if body == null or not body.hidden or not is_instance_valid(body.hiding_place): return
	var index: int = level.hotel.hides.find(body.hiding_place)
	remote_leaves(body.hiding_place, body)
	if in_match() and index >= 0: hide_state.rpc(index, -seat)

# --- The shared sheet ----------------------------------------------------------------

## Most sheet chunks a player may send per second.
const SHEET_RATE := 30.0
var sheet_budget := {}

## A chunk of a stroke drawn here: offline it counts at once, online the host
## puts it in order for everyone.
func sheet_local(op_id: String, kind: int, points: PackedVector2Array) -> void:
	if not in_match() or net.is_host:
		level.ui.sheet.apply_confirmed(op_id, kind, points)
		if in_match(): sheet_confirmed.rpc(op_id, kind, points)
	else:
		sheet_chunk.rpc_id(1, op_id, kind, points)

@rpc("any_peer", "call_remote", "reliable")
func sheet_chunk(op_id: String, kind: int, points: PackedVector2Array) -> void:
	if not net.is_host or not in_match(): return
	var seat: int = net.seat_of_peer(multiplayer.get_remote_sender_id())
	# Only living survivors draw, under their own seat, within the traffic limit.
	if not is_survivor(seat) or level.session.participants.get(seat, 2) == level.session.Life.DEAD: return
	if not op_id.begins_with("%d:" % seat) or kind not in [0, 1] or points.size() > 128: return
	var now := Time.get_ticks_msec() / 1000.0
	var budget: Array = sheet_budget.get(seat, [SHEET_RATE, now])
	budget[0] = minf(SHEET_RATE, budget[0] + (now - budget[1]) * SHEET_RATE)
	budget[1] = now
	sheet_budget[seat] = budget
	if budget[0] < 1.0 or level.ui.sheet.log.size() >= level.ui.sheet.MAX_OPS: return
	budget[0] -= 1.0
	level.ui.sheet.apply_confirmed(op_id, kind, points)
	sheet_confirmed.rpc(op_id, kind, points)

@rpc("authority", "call_remote", "reliable")
func sheet_confirmed(op_id: String, kind: int, points: PackedVector2Array) -> void:
	level.ui.sheet.apply_confirmed(op_id, kind, points)

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
	var sets: Array = []
	for set in level.televisions: sets.append(is_instance_valid(set) and set.on)
	restore.rpc_id(id, doors, hides, places, creature.pack_state() if is_instance_valid(creature) else [], level.sheet_snapshot(), sets)
	session_state.rpc_id(id, level.session.state, level.session.participants, level.session.elapsed, level.session.message, level.session.stage, level.session.goal)

@rpc("authority", "call_remote", "reliable")
func restore(doors: Array, hides: Array, places: Dictionary, creature: Array, sheet: Array, sets: Array) -> void:
	level.begin_online_play(config)
	for index in mini(doors.size(), level.hotel.doors.size()): level.hotel.doors[index].set_state(doors[index])
	for seat_key in places:
		var seat := int(seat_key)
		if seat == net.local_seat:
			level.player.global_position = places[seat_key][0]
			level.player.rotation.y = places[seat_key][1]
			# Back where it was, torch and all: the light trails the camera
			# rather than hanging from it.
			level.player.snap_torch()
		elif bodies.has(seat): bodies[seat].place(places[seat_key][0], places[seat_key][1])
	for index in mini(hides.size(), level.hotel.hides.size()):
		if int(hides[index]) != 0: hide_state(index, int(hides[index]))
	if not creature.is_empty() and is_instance_valid(level.locust):
		if local_is_locust():
			# Back in control where the creature was left standing.
			level.locust.global_position = creature[0]
			level.locust.rotation.y = creature[1]
		else: level.locust.push_state(creature)
	for index in mini(sets.size(), level.televisions.size()):
		if bool(sets[index]): level.apply_television(index, true)
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
