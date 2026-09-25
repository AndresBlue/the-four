extends Node
## Steam as a way into a room (net_session.gd, transport "steam"): a Steam
## lobby to meet in and to invite friends to, and Steam's MultiplayerPeer to
## play over, relayed by Steam, so nobody opens a port. Everything above the
## peer is the game's own multiplayer, unchanged.
##
## GodotSteam (addons/godotsteam) is optional: without it, or without the
## Steam client running, this says why and the game plays over IP as ever.
## Nothing here names a GodotSteam class in the source -- the singleton and
## the peer are looked up by name -- so the game loads either way.
##
## The AppID comes from the project settings (APP_ID_SETTING): 480, Valve's
## Spacewar, while developing; the game's own when it has one. Nothing else
## changes with it.
const APP_ID_SETTING := "the_four/steam/app_id"
const DEV_APP_ID := 480

var net
## GodotSteam's singleton, or null.
var api: Object
## Steam answered at start-up (the client is running, logged in).
var started := false
var start_problem := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start()

## Whether GodotSteam is installed at all.
static func installed() -> bool:
	return Engine.has_singleton("Steam") and ClassDB.class_exists("SteamMultiplayerPeer")

static func app_id() -> int:
	return int(ProjectSettings.get_setting(APP_ID_SETTING, DEV_APP_ID))

func start() -> void:
	if not installed():
		start_problem = "Steam no está disponible en esta versión del juego (falta GodotSteam)."
		print_verbose("Steam: GodotSteam not installed; IP only.")
		return
	start_problem = "Steam todavía no está conectado."

## Ready to host or join over Steam.
func ready_to_play() -> bool:
	return started

## Why Steam cannot be used right now, for the menu.
func problem() -> String:
	return start_problem

func create_lobby(_player_name: String, _character: int) -> void:
	pass

func join_lobby(_lobby_id: int, _player_name: String, _character: int) -> void:
	pass

func leave_lobby() -> void:
	pass

## Friends of this player with a room of this game open: [{name, lobby}].
func friend_rooms() -> Array:
	return []

## Steam's own invite window, for the host of a Steam room.
func invite_friends() -> void:
	pass
