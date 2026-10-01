extends Node
## Online play: one host and up to four guests. This node owns the connection
## and the room (lobby): who is in which seat, their names and characters, and
## the host's match options. The in-match replication lives in the child node
## "Match" (match_net.gd).
##
## Everything above the connection is Godot's MultiplayerAPI (RPCs, peer ids,
## the host as authority), so the connection itself is interchangeable: a
## MultiplayerPeer is made here and handed to `multiplayer`, and nothing else
## in the game knows which one it is.
##   ip     ENet, to an address and port (LAN, or the Internet with the
##          host's port open). host() / join().
##   steam  Steam's own relay, through a Steam lobby: no ports to open
##          (steam_link.gd, only when GodotSteam is installed).
##          host_steam() / join_steam().
##
## Seats are stable for the whole session: the host is seat 1, guests take
## 2..5. A guest who drops during a match keeps their seat and can come back
## with the same name (see match_net.gd for the 60 s grace).
signal lobby_changed
## The connection ended or was refused; `reason` is shown to the player.
signal closed(reason: String)
signal joined
const MATCH := preload("res://game/net/match_net.gd")
const STEAM_LINK := preload("res://game/net/steam_link.gd")
## The port a room opens on unless the host picks another.
const PORT := 38430
const MAX_PLAYERS := 5
## A room keeps one slot over its seats for somebody who only watches: the
## observer (tools, --observer) connects like anybody else, takes no seat,
## has no body and is nobody's business in the match -- it is sent everything
## and sends nothing back.
const OBSERVERS := 2
const MIN_PLAYERS := 2
## Bumped whenever the messages change: mismatched builds refuse to play.
const PROTOCOL := "the-four-net-12"
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
enum Mode { COOP, VERSUS }
const MODE_NAMES := ["Cooperativo contra IA", "Versus: un jugador es The Locust"]
## Who plays The Locust in versus: RANDOM, or a seat number.
const RANDOM := 0
var level
var match_net
## Steam's side of things (lobbies, invites, its MultiplayerPeer).
var steam
var peer: MultiplayerPeer
## Which connection the room is on: "ip" or "steam".
var transport := "ip"
## Where an IP room can be reached, as the host's room shows it.
var host_port := PORT
var host_bind := "*"
var is_host := false
## seat -> {name, character, peer, connected}
var players := {}
## Host options, mirrored to everyone.
var options := {"mode": Mode.COOP, "locust": RANDOM, "resume": false}
## True from the host's start until everyone is back in the room.
var in_match := false
var local_seat := 0
var status := ""
## This machine is only watching (no seat, no body).
var observing := false
## Host: peer ids that are only watching.
var observers := {}

func _init() -> void:
	name = "Net"
	match_net = MATCH.new()
	match_net.name = "Match"
	match_net.net = self
	add_child(match_net)
	steam = STEAM_LINK.new()
	steam.name = "Steam"
	steam.net = self
	add_child(steam)

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

## A room over IP, on `port` and the address `bind` ("*": every network this
## machine is on).
func host(player_name: String, character: int, port := PORT, bind := "*") -> Error:
	shutdown("")
	if port < 1024 or port > 65535:
		status = "El puerto tiene que estar entre 1024 y 65535."
		return ERR_INVALID_PARAMETER
	var enet := ENetMultiplayerPeer.new()
	enet.set_bind_ip(bind if not bind.is_empty() else "*")
	var error := enet.create_server(port, MAX_PLAYERS - 1 + OBSERVERS)
	if error != OK:
		status = "No se pudo abrir la sala en %s, puerto %d (¿ya hay otra abierta, o esa dirección no es de este equipo?)." % ["todas las redes" if bind == "*" else bind, port]
		return error
	host_port = port
	host_bind = bind
	as_host(enet, "ip", player_name, character)
	return OK

## Whichever connection it is, once it is open this is what makes it a room.
func as_host(opened: MultiplayerPeer, kind: String, player_name: String, character: int) -> void:
	peer = opened
	transport = kind
	# No passing of one guest's messages on to another behind the game's
	# back: Steam's connection has none, and with it on over IP the two
	# behaved differently (match_net.to_everyone()). What a guest has to say
	# to the others, the host hears, judges and passes on.
	if multiplayer is SceneMultiplayer: (multiplayer as SceneMultiplayer).server_relay = false
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_seat = 1
	players = {1: {"name": clean_name(player_name), "character": character, "peer": 1, "connected": true}}
	observers.clear()
	options = {"mode": Mode.COOP, "locust": RANDOM, "resume": false}
	status = ""
	lobby_changed.emit()

## Watch a room without playing in it: the same connection, and the host is
## told that this one is not asking for a seat.
func join_observer(address: String, port := PORT) -> Error:
	var error := join(address, "Observador", 0, port)
	if error == OK: pending_profile["observer"] = true
	return error

func join(address: String, player_name: String, character: int, port := PORT) -> Error:
	shutdown("")
	if port < 1 or port > 65535:
		status = "Puerto no válido."
		return ERR_INVALID_PARAMETER
	var enet := ENetMultiplayerPeer.new()
	var error := enet.create_client(address.strip_edges(), port)
	if error != OK:
		status = "Dirección no válida."
		return error
	as_guest(enet, "ip", player_name, character, "%s, puerto %d" % [address.strip_edges(), port])
	return OK

## Whichever connection it is, once it is dialling this is a guest waiting to
## be seated (_connected() introduces it to the host).
func as_guest(dialling: MultiplayerPeer, kind: String, player_name: String, character: int, where: String) -> void:
	peer = dialling
	transport = kind
	multiplayer.multiplayer_peer = peer
	is_host = false
	local_seat = 0
	pending_profile = {"name": clean_name(player_name), "character": character}
	status = "Conectando con %s…" % where
	lobby_changed.emit()

## A room on Steam: a lobby friends can be invited to, and Steam's relay in
## place of an open port. The room itself is ready when the lobby is
## (steam_link.gd calls as_host()); false if Steam is not there to ask.
func host_steam(player_name: String, character: int) -> bool:
	shutdown("")
	if not steam.ready_to_play():
		status = steam.problem()
		return false
	status = "Creando la sala en Steam…"
	steam.create_lobby(player_name, character)
	lobby_changed.emit()
	return true

## Steam could not make or find the room: back to the menu with the reason
## (shutdown() only reports a connection that was already open).
func steam_failed(reason: String) -> void:
	shutdown("")
	status = reason
	closed.emit(reason)

## Into a friend's Steam lobby (from the list, or an invitation).
func join_steam(lobby_id: int, player_name: String, character: int) -> bool:
	shutdown("")
	if not steam.ready_to_play():
		status = steam.problem()
		return false
	status = "Entrando en la sala de Steam…"
	steam.join_lobby(lobby_id, player_name, character)
	lobby_changed.emit()
	return true

var pending_profile := {}

## Leaves the room (or closes it, for the host). `reason` empty: quietly.
func shutdown(reason: String) -> void:
	var was_active := active()
	if is_instance_valid(match_net): match_net.end()
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	# A Steam room is also a lobby, which is left (or, for the host, closed).
	if is_instance_valid(steam): steam.leave_lobby()
	is_host = false
	in_match = false
	players = {}
	local_seat = 0
	status = reason
	if was_active: closed.emit(reason)

static func clean_name(words: String) -> String:
	var result := words.strip_edges().replace("\n", " ").left(18)
	return result if not result.is_empty() else "Jugador"

## How the others get in, as the host's room shows it: what to type, and
## what it takes over the Internet.
func where_to_join() -> Array:
	if transport == "steam": return ["Por Steam: invita a tus amigos.", "También pueden entrar desde tu perfil: Unirse a la partida."]
	var addresses: Array = [host_bind] if host_bind != "*" else local_addresses()
	var shown := " / ".join(addresses) if not addresses.is_empty() else "tu IP"
	return ["Para unirse: %s · puerto %d" % [shown, host_port], "Por Internet: puerto %d UDP abierto hacia este equipo." % host_port]

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
	register.rpc_id(1, PROTOCOL, FLOOR.VERSION, pending_profile.name, pending_profile.character, bool(pending_profile.get("observer", false)))

func _peer_connected(_id: int) -> void:
	pass

func _peer_disconnected(id: int) -> void:
	if not is_host: return
	if observers.erase(id): return
	var seat := seat_of_peer(id)
	if seat == 0: return
	if in_match:
		players[seat].connected = false
		players[seat].peer = 0
		match_net.seat_dropped(seat)
		# Still waiting for everybody's floor: whoever left is not coming,
		# and the others waited out the whole timeout for them.
		match_net.check_ready()
	else:
		players.erase(seat)
	broadcast_lobby()

## A guest introduces itself. The host seats it, or refuses with a reason.
@rpc("any_peer", "call_remote", "reliable")
func register(protocol: String, generator: int, player_name: String, character: int, observer := false) -> void:
	if not is_host: return
	var id := multiplayer.get_remote_sender_id()
	var wanted := clean_name(player_name)
	if protocol != PROTOCOL or generator != FLOOR.VERSION:
		refuse(id, "Versiones distintas del juego: actualizad todos al mismo exe.")
		return
	if observer:
		# It takes no seat and is not in the room: it is only sent what is
		# already being sent to everybody, and the floor if one is being played.
		observers[id] = true
		welcome.rpc_id(id, 0)
		if in_match and not match_net.config.is_empty(): match_net.begin.rpc_id(id, match_net.config, {"observer": true})
		return
	var seat := 0
	if in_match:
		# Only someone who dropped can come back, under the same name.
		for candidate in players:
			if not players[candidate].connected and players[candidate].name == wanted: seat = candidate
		# The room numbers repeated names ("Jugador 2"), and the one coming
		# back asks with the name it has, not the one it was given: without
		# this, nobody with a common name could ever come back.
		if seat == 0:
			for candidate in players:
				var entry: Dictionary = players[candidate]
				if entry.connected or not String(entry.name).begins_with(wanted + " "): continue
				if not String(entry.name).trim_prefix(wanted + " ").is_valid_int(): continue
				if seat == 0 or int(entry.character) == clampi(character, 0, 2): seat = candidate
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
	observing = seat == 0
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
