extends Node
## Online play over LAN or a direct IP (ENet): one host and up to four guests.
## This node owns the connection and the room (lobby): who is in which seat,
## their names and characters, and the host's match options. The in-match
## replication lives in the child node "Match" (match_net.gd).
##
## Seats are stable for the whole session: the host is seat 1, guests take
## 2..5. A guest who drops during a match keeps their seat and can come back
## with the same name (see match_net.gd for the 60 s grace).
signal lobby_changed
## The connection ended or was refused; `reason` is shown to the player.
signal closed(reason: String)
signal joined
const MATCH := preload("res://game/net/match_net.gd")
const PORT := 38430
const MAX_PLAYERS := 5
const MIN_PLAYERS := 2
## Bumped whenever the messages change: mismatched builds refuse to play.
const PROTOCOL := "the-four-net-3"
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
enum Mode { COOP, VERSUS }
const MODE_NAMES := ["Cooperativo contra IA", "Versus: un jugador es The Locust"]
## Who plays The Locust in versus: RANDOM, or a seat number.
const RANDOM := 0
var level
var match_net
var peer: ENetMultiplayerPeer
var is_host := false
## seat -> {name, character, peer, connected}
var players := {}
## Host options, mirrored to everyone.
var options := {"mode": Mode.COOP, "locust": RANDOM, "resume": false}
## True from the host's start until everyone is back in the room.
var in_match := false
var local_seat := 0
var status := ""

func _init() -> void:
	name = "Net"
	match_net = MATCH.new()
	match_net.name = "Match"
	match_net.net = self
	add_child(match_net)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(func(): shutdown("No se pudo conectar con esa dirección."))
	multiplayer.server_disconnected.connect(func(): shutdown("Se perdió la conexión con el anfitrión."))

## Online (hosting or joined), as opposed to playing alone.
func active() -> bool:
	return peer != null

func is_client() -> bool:
	return active() and not is_host

func host(player_name: String, character: int, port := PORT) -> Error:
	shutdown("")
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_PLAYERS - 1)
	if error != OK:
		peer = null
		status = "No se pudo abrir la sala en el puerto %d (¿ya hay otra abierta?)." % port
		return error
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_seat = 1
	players = {1: {"name": clean_name(player_name), "character": character, "peer": 1, "connected": true}}
	options = {"mode": Mode.COOP, "locust": RANDOM, "resume": false}
	status = ""
	lobby_changed.emit()
	return OK

func join(address: String, player_name: String, character: int, port := PORT) -> Error:
	shutdown("")
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address.strip_edges(), port)
	if error != OK:
		peer = null
		status = "Dirección no válida."
		return error
	multiplayer.multiplayer_peer = peer
	is_host = false
	local_seat = 0
	pending_profile = {"name": clean_name(player_name), "character": character}
	status = "Conectando con %s…" % address
	lobby_changed.emit()
	return OK

var pending_profile := {}

## Leaves the room (or closes it, for the host). `reason` empty: quietly.
func shutdown(reason: String) -> void:
	var was_active := active()
	if is_instance_valid(match_net): match_net.end()
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	is_host = false
	in_match = false
	players = {}
	local_seat = 0
	status = reason
	if was_active: closed.emit(reason)

static func clean_name(words: String) -> String:
	var result := words.strip_edges().replace("\n", " ").left(18)
	return result if not result.is_empty() else "Jugador"

## Private LAN addresses of this machine, to tell friends where to connect.
static func local_addresses() -> Array:
	var result: Array = []
	for address in IP.get_local_addresses():
		if address.count(".") != 3 or address.begins_with("127.") or address.begins_with("169.254."): continue
		result.append(address)
	return result

func seat_of_peer(id: int) -> int:
	for seat in players:
		if players[seat].peer == id: return seat
	return 0

func connected_seats() -> Array:
	var result: Array = players.keys().filter(func(seat): return players[seat].connected)
	result.sort()
	return result

func player_name(seat: int) -> String:
	return players[seat].name if players.has(seat) else "?"

# --- Connection events ---------------------------------------------------------

func _connected() -> void:
	status = "Conectado. Entrando en la sala…"
	register.rpc_id(1, PROTOCOL, FLOOR.VERSION, pending_profile.name, pending_profile.character)

func _peer_connected(_id: int) -> void:
	pass

func _peer_disconnected(id: int) -> void:
	if not is_host: return
	var seat := seat_of_peer(id)
	if seat == 0: return
	if in_match:
		players[seat].connected = false
		players[seat].peer = 0
		match_net.seat_dropped(seat)
	else:
		players.erase(seat)
	broadcast_lobby()

## A guest introduces itself. The host seats it, or refuses with a reason.
@rpc("any_peer", "call_remote", "reliable")
func register(protocol: String, generator: int, player_name: String, character: int) -> void:
	if not is_host: return
	var id := multiplayer.get_remote_sender_id()
	var wanted := clean_name(player_name)
	if protocol != PROTOCOL or generator != FLOOR.VERSION:
		refuse(id, "Versiones distintas del juego: actualizad todos al mismo exe.")
		return
	var seat := 0
	if in_match:
		# Only someone who dropped can come back, under the same name.
		for candidate in players:
			if not players[candidate].connected and players[candidate].name == wanted: seat = candidate
		if seat == 0:
			refuse(id, "La partida ya empezó. Espera a que vuelvan a la sala.")
			return
		players[seat].connected = true
		players[seat].peer = id
	else:
		if players.size() >= MAX_PLAYERS:
			refuse(id, "La sala está llena (máximo %d jugadores)." % MAX_PLAYERS)
			return
		# Names must tell players apart.
		var taken: Array = players.values().map(func(entry): return entry.name)
		var base := wanted
		var number := 2
		while wanted in taken:
			wanted = "%s %d" % [base.left(15), number]
			number += 1
		for candidate in range(2, MAX_PLAYERS + 1):
			if not players.has(candidate):
				seat = candidate
				break
		players[seat] = {"name": wanted, "character": clampi(character, 0, 2), "peer": id, "connected": true}
	welcome.rpc_id(id, seat)
	broadcast_lobby()
	if in_match: match_net.seat_returned(seat, id)

func refuse(id: int, reason: String) -> void:
	refused.rpc_id(id, reason)
	# Give the message a moment to leave before dropping the guest.
	get_tree().create_timer(0.5).timeout.connect(func(): if peer != null: peer.disconnect_peer(id))

@rpc("authority", "call_remote", "reliable")
func refused(reason: String) -> void:
	shutdown(reason)

@rpc("authority", "call_remote", "reliable")
func welcome(seat: int) -> void:
	local_seat = seat
	status = ""
	joined.emit()

# --- Room --------------------------------------------------------------------

func broadcast_lobby() -> void:
	if not is_host: return
	lobby_state.rpc(players, options, in_match)
	lobby_changed.emit()

@rpc("authority", "call_remote", "reliable")
func lobby_state(seats: Dictionary, host_options: Dictionary, playing: bool) -> void:
	players = {}
	for seat in seats: players[int(seat)] = seats[seat]
	options = host_options
	in_match = playing
	lobby_changed.emit()

## The host changes a match option.
func set_option(key: String, value: Variant) -> void:
	if not is_host or in_match: return
	options[key] = value
	if key == "mode" and value == Mode.COOP: options.locust = RANDOM
	broadcast_lobby()

## A player picks another character in the room.
func set_character(character: int) -> void:
	if not active() or local_seat == 0: return
	if is_host:
		players[1].character = character
		broadcast_lobby()
	else: profile.rpc_id(1, character)

@rpc("any_peer", "call_remote", "reliable")
func profile(character: int) -> void:
	var seat := seat_of_peer(multiplayer.get_remote_sender_id())
	if not is_host or seat == 0 or in_match: return
	players[seat].character = clampi(character, 0, 2)
	broadcast_lobby()

## Why the host cannot start yet, or "" when it can.
func start_problem() -> String:
	var count := connected_seats().size()
	if count < MIN_PLAYERS: return "Hacen falta al menos %d jugadores." % MIN_PLAYERS
	if count > MAX_PLAYERS: return "Demasiados jugadores."
	if options.mode == Mode.VERSUS and options.locust != RANDOM and not connected_seats().has(int(options.locust)):
		return "El jugador elegido como The Locust ya no está."
	return ""

## Host: everyone into a floor. `seed_value` negative picks a new one.
func start_match(seed_value := -1) -> bool:
	if not is_host or not start_problem().is_empty(): return false
	var seats := connected_seats()
	var locust_seat := 0
	if options.mode == Mode.VERSUS:
		locust_seat = int(options.locust) if options.locust != RANDOM else seats[randi() % seats.size()]
	if seed_value < 0:
		var saved: Dictionary = match_net.saved_checkpoint() if options.get("resume", false) else {}
		seed_value = int(saved.seed) if not saved.is_empty() else randi_range(0, 2147483647)
	var config := {
		"seed": seed_value,
		"mode": options.mode,
		"locust_seat": locust_seat,
		"survivors": seats.filter(func(seat): return seat != locust_seat),
		"players": players.duplicate(true),
	}
	in_match = true
	broadcast_lobby()
	match_net.begin.rpc(config)
	match_net.begin(config)
	return true

## Host: everyone back to the room after a floor ends.
func return_to_lobby() -> void:
	if not is_host: return
	match_net.back_to_room.rpc()
	match_net.back_to_room()
	# Seats that never came back are freed.
	for seat in players.keys():
		if not players[seat].connected: players.erase(seat)
	in_match = false
	broadcast_lobby()
