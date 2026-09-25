extends Node
## Steam as a way into a room (net_session.gd, transport "steam"): a Steam
## lobby to meet in and to invite friends to, and GodotSteam's
## SteamMultiplayerPeer to play over, through Steam's relay, so nobody opens a
## port. Everything above the peer is the game's own multiplayer, unchanged:
## the host makes its peer with create_host() and every guest dials the host
## with create_client(), the same star the IP rooms are, with the host as the
## authority. The lobby is only where friends find the room.
##
## GodotSteam (addons/godotsteam) is optional: without it, or without the
## Steam client running and logged in, this says why and the game plays over
## IP as ever. Nothing here names a GodotSteam class in the source -- the
## singleton and the peer are looked up by name -- so the game loads either
## way. (The Steam edition of the Godot editor ships an older steam_api64.dll
## and cannot load the plug-in, so in the editor Steam is never available; the
## exported game carries the right one beside it.)
##
## Every call below was checked against the plug-in shipped
## (--steam-diagnose, steam_diagnose.gd): GodotSteam 4.22.1, Steamworks 1.65.
##
## The AppID is the plug-in's own project setting (APP_ID_SETTING): 480,
## Valve's Spacewar, while developing; the game's own when it has one, and
## nothing else changes with it.
signal join_asked(lobby_id: int)
const APP_ID_SETTING := "steam/initialization/app_data/app_id"
const DEV_APP_ID := 480
## Lobby data: which game and which build a lobby belongs to (with AppID 480
## every Spacewar test in the world shares the lobbies).
const GAME_KEY := "the_four"

var net
## GodotSteam's singleton, or null.
var api: Object
## Steam answered at start-up (the client is running and logged in).
var started := false
var start_problem := ""
## The lobby this machine is in (0 none), and what it went to do there.
var lobby := 0
var pending := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start()

## Whether GodotSteam is installed (and could load) at all.
static func installed() -> bool:
	return Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")

static func app_id() -> int:
	var id := int(ProjectSettings.get_setting(APP_ID_SETTING, 0))
	return id if id > 0 else DEV_APP_ID

func constant(name: String, fallback: int) -> int:
	return ClassDB.class_get_integer_constant(api.get_class(), name) if ClassDB.class_has_integer_constant(api.get_class(), name) else fallback

func start() -> void:
	if OS.get_cmdline_user_args().has("--steam-diagnose"): preload("res://game/net/steam_diagnose.gd").run()
	if not installed():
		start_problem = "Steam no está disponible en esta versión del juego (falta GodotSteam)."
		print_verbose("Steam: GodotSteam not installed; IP only.")
		return
	# Tests and tools never go near the player's Steam account.
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--automation"):
		start_problem = "Steam no se usa en pruebas automáticas."
		return
	api = Engine.get_singleton("Steam")
	# What steam_appid.txt would say, so a build run from anywhere is this app.
	OS.set_environment("SteamAppId", str(app_id()))
	OS.set_environment("SteamGameId", str(app_id()))
	var result: Dictionary = api.steamInitEx(app_id(), false)
	print("Steam: init with AppID %d -> %s" % [app_id(), result])
	if int(result.get("status", -1)) != constant("STEAM_API_INIT_RESULT_OK", 0):
		start_problem = "No se pudo conectar con Steam: ¿está abierto y con la sesión iniciada? (%s)" % result.get("verbal", "sin respuesta")
		return
	if not api.loggedOn():
		start_problem = "Steam está abierto pero sin conexión."
		print("Steam: running but not logged on")
		return
	started = true
	start_problem = ""
	print("Steam: ready · AppID %d · SteamID %d · %s · overlay %s" % [api.getAppID(), api.getSteamID(), api.getPersonaName(), "on" if api.isOverlayEnabled() else "off"])
	if OS.get_cmdline_user_args().has("--steam-diagnose"): print("Steam: %d friend(s) online to invite" % online_friends().size())
	# The relay network takes a few seconds to come up: start now, not when
	# someone is waiting to get into a room.
	api.initRelayNetworkAccess()
	api.lobby_created.connect(_lobby_created)
	api.lobby_joined.connect(_lobby_joined)
	api.lobby_chat_update.connect(_lobby_chat_update)
	api.join_requested.connect(_join_requested)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	# Launched by Steam from an invitation: "+connect_lobby <id>" (only with
	# the game's own AppID; with 480 an invitation starts Spacewar instead).
	var launch: String = api.getLaunchCommandLine() + " " + " ".join(OS.get_cmdline_args())
	var at := launch.find("+connect_lobby")
	if at >= 0:
		var id := launch.substr(at + 14).strip_edges().get_slice(" ", 0)
		if id.is_valid_int():
			print("Steam: launched to join lobby %s" % id)
			join_asked.emit.call_deferred(int(id))

func _process(_delta: float) -> void:
	if started and api != null: api.run_callbacks()

## Ready to host or join over Steam.
func ready_to_play() -> bool:
	return started

## Why Steam cannot be used right now, for the menu.
func problem() -> String:
	return start_problem

# --- Host -------------------------------------------------------------------

func create_lobby(player_name: String, character: int) -> void:
	pending = {"role": "host", "name": player_name, "character": character}
	print("Steam: creating a friends-only lobby for %d players" % net.MAX_PLAYERS)
	api.createLobby(constant("LOBBY_TYPE_FRIENDS_ONLY", 1), net.MAX_PLAYERS)

func _lobby_created(connect: int, lobby_id: int) -> void:
	if pending.get("role", "") != "host": return
	if connect != constant("RESULT_OK", 1):
		print("Steam: lobby creation failed, result %d" % connect)
		net.steam_failed("Steam no pudo crear la sala (código %d)." % connect)
		return
	lobby = lobby_id
	api.setLobbyData(lobby, "game", GAME_KEY)
	api.setLobbyData(lobby, "protocol", net.PROTOCOL)
	api.setLobbyData(lobby, "host", api.getPersonaName())
	api.setLobbyJoinable(lobby, true)
	# "Join game" on this player's Steam profile, for friends.
	api.setRichPresence("connect", "+connect_lobby %d" % lobby)
	# Untyped: its own methods (create_host...) are not MultiplayerPeer's.
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	var error: int = peer.create_host(0)
	if error != OK:
		print("Steam: create_host failed, error %d" % error)
		net.steam_failed("No se pudo abrir la sala sobre Steam (error %d)." % error)
		return
	print("Steam: lobby %d created · host SteamID %d" % [lobby, api.getSteamID()])
	net.as_host(peer, "steam", pending.name, pending.character)
	pending = {}

## Whether Steam's overlay (Shift+Tab) is drawn over this game. It hooks the
## renderer when Steam is started before the graphics device, or when Steam
## launched the game; here Steam starts later, so outside a Steam launch it is
## off, and the room invites through its own list (online_friends / invite).
func overlay_ready() -> bool:
	return started and api.isOverlayEnabled()

## Steam's own invitation window, when the overlay is there to show it.
func invite_friends() -> void:
	if overlay_ready() and lobby != 0: api.activateGameOverlayInviteDialog(lobby)

## This player's friends who are on Steam now, by name: [{name, id}].
func online_friends() -> Array:
	var friends: Array = []
	if not started: return friends
	var flags := constant("FRIEND_FLAG_IMMEDIATE", 4)
	var offline := constant("PERSONA_STATE_OFFLINE", 0)
	for i in api.getFriendCount(flags):
		var friend: int = api.getFriendByIndex(i, flags)
		if api.getFriendPersonaState(friend) == offline: continue
		friends.append({"name": api.getFriendPersonaName(friend), "id": friend})
	friends.sort_custom(func(a, b): return String(a.name).nocasecmp_to(b.name) < 0)
	return friends

## An invitation to this room, straight to a friend's Steam chat: no overlay
## needed. Accepting it with the game open brings them in (join_requested).
func invite(friend: int) -> bool:
	if not started or lobby == 0: return false
	var sent: bool = api.inviteUserToLobby(lobby, friend)
	print("Steam: invitation to lobby %d for %s (SteamID %d) -> %s" % [lobby, api.getFriendPersonaName(friend), friend, "sent" if sent else "refused"])
	return sent

# --- Guest ------------------------------------------------------------------

func join_lobby(lobby_id: int, player_name: String, character: int) -> void:
	pending = {"role": "guest", "name": player_name, "character": character}
	print("Steam: joining lobby %d" % lobby_id)
	api.joinLobby(lobby_id)

func _lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	# The host is told it joined its own lobby as well: nothing to do there.
	if pending.get("role", "") != "guest": return
	if response != constant("CHAT_ROOM_ENTER_RESPONSE_SUCCESS", 1):
		print("Steam: could not enter lobby %d, response %d" % [lobby_id, response])
		net.steam_failed("No se pudo entrar en la sala de Steam (código %d): quizá ya se cerró o está llena." % response)
		return
	lobby = lobby_id
	if api.getLobbyData(lobby, "game") != GAME_KEY:
		net.steam_failed("Esa sala de Steam no es de The Four.")
		return
	if api.getLobbyData(lobby, "protocol") != net.PROTOCOL:
		net.steam_failed("Versiones distintas del juego: actualizad todos al mismo exe.")
		return
	var owner: int = api.getLobbyOwner(lobby)
	# Untyped: its own methods (create_host...) are not MultiplayerPeer's.
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	var error: int = peer.create_client(owner, 0)
	if error != OK:
		print("Steam: create_client to %d failed, error %d" % [owner, error])
		net.steam_failed("No se pudo conectar con el anfitrión por Steam (error %d)." % error)
		return
	print("Steam: in lobby %d · dialling host SteamID %d (%s)" % [lobby, owner, api.getFriendPersonaName(owner)])
	net.as_guest(peer, "steam", pending.name, pending.character, "la sala de %s" % api.getFriendPersonaName(owner))
	pending = {}

## An invitation accepted, or "Join game" on a friend's profile, while the
## game is running.
func _join_requested(lobby_id: int, steam_id: int) -> void:
	print("Steam: asked to join lobby %d (from %d)" % [lobby_id, steam_id])
	join_asked.emit(lobby_id)

## Friends of this player with a room of this game open: [{name, lobby}].
func friend_rooms() -> Array:
	var rooms: Array = []
	if not started: return rooms
	var flags := constant("FRIEND_FLAG_IMMEDIATE", 4)
	for i in api.getFriendCount(flags):
		var friend: int = api.getFriendByIndex(i, flags)
		var playing: Dictionary = api.getFriendGamePlayed(friend)
		if playing.is_empty() or int(playing.get("id", 0)) != app_id(): continue
		var room := int(playing.get("lobby", 0))
		if room == 0: continue
		rooms.append({"name": api.getFriendPersonaName(friend), "lobby": room})
	print("Steam: %d friend room(s) open" % rooms.size())
	return rooms

# --- Both -------------------------------------------------------------------

func leave_lobby() -> void:
	pending = {}
	if not started or lobby == 0: return
	print("Steam: leaving lobby %d" % lobby)
	api.leaveLobby(lobby)
	api.clearRichPresence()
	lobby = 0

func _lobby_chat_update(lobby_id: int, changed_id: int, _making_change_id: int, chat_state: int) -> void:
	if lobby_id != lobby: return
	var what := "entered" if chat_state == constant("CHAT_MEMBER_STATE_CHANGE_ENTERED", 1) else "left (%d)" % chat_state
	print("Steam: %s (SteamID %d) %s lobby %d" % [api.getFriendPersonaName(changed_id), changed_id, what, lobby_id])

## Who a Godot peer is on Steam, for the log.
func _peer_connected(id: int) -> void:
	if net.transport != "steam" or net.peer == null: return
	var steam_id: int = net.peer.get_steam_id_for_peer_id(id)
	print("Steam: peer %d connected · SteamID %d (%s)" % [id, steam_id, api.getFriendPersonaName(steam_id)])

func _peer_disconnected(id: int) -> void:
	if net.transport != "steam": return
	print("Steam: peer %d disconnected" % id)
