extends RefCounted
## `--steam-diagnose`: what this build's GodotSteam really offers, printed to
## the log -- the methods and signals the Steam transport (steam_link.gd) uses,
## with their arguments, and what Steam answers here. For support ("why does
## Steam not work for me?") and to check the transport against the plug-in
## actually shipped, never against a version remembered from somewhere else.
const METHODS := ["steamInitEx", "run_callbacks", "isSteamRunning", "loggedOn", "getAppID", "getSteamID", "getPersonaName", "getFriendPersonaName", "createLobby", "joinLobby", "leaveLobby", "setLobbyData", "getLobbyData", "getLobbyOwner", "getNumLobbyMembers", "getLobbyMemberByIndex", "setLobbyJoinable", "activateGameOverlayInviteDialog", "setRichPresence", "clearRichPresence", "getFriendCount", "getFriendByIndex", "getFriendGamePlayed", "getLaunchCommandLine", "initRelayNetworkAccess"]
const SIGNALS := ["lobby_created", "lobby_joined", "lobby_chat_update", "join_requested", "persona_state_change", "steamworks_error"]

static func args_of(entry: Dictionary) -> String:
	var parts := []
	for argument in entry.args: parts.append("%s: %s" % [argument.name, type_string(argument.type)])
	return ", ".join(parts)

static func run() -> void:
	print("STEAM DIAGNOSE · singleton Steam: %s · SteamMultiplayerPeer: %s" % [Engine.has_singleton("Steam"), ClassDB.class_exists("SteamMultiplayerPeer")])
	if not Engine.has_singleton("Steam"): return
	var api := Engine.get_singleton("Steam")
	var methods := {}
	for entry in ClassDB.class_get_method_list(api.get_class(), true): methods[entry.name] = entry
	for name in METHODS:
		if methods.has(name): print("STEAM method %s(%s) -> %s" % [name, args_of(methods[name]), type_string(methods[name].return.type)])
		else: print("STEAM method %s MISSING" % name)
	var signals := {}
	for entry in ClassDB.class_get_signal_list(api.get_class(), true): signals[entry.name] = entry
	for name in SIGNALS:
		if signals.has(name): print("STEAM signal %s(%s)" % [name, args_of(signals[name])])
		else: print("STEAM signal %s MISSING" % name)
	for constant in ClassDB.class_get_integer_constant_list(api.get_class(), true):
		if constant.begins_with("LOBBY_TYPE_") or constant.begins_with("STEAM_API_INIT_RESULT") or constant == "RESULT_OK" or constant.begins_with("CHAT_MEMBER_STATE_CHANGE_") or constant.begins_with("CHAT_ROOM_ENTER_RESPONSE_SUCCESS"):
			print("STEAM const %s = %d" % [constant, ClassDB.class_get_integer_constant(api.get_class(), constant)])
	if ClassDB.class_exists("SteamMultiplayerPeer"):
		print("STEAM peer parent: %s" % ClassDB.get_parent_class("SteamMultiplayerPeer"))
		for entry in ClassDB.class_get_method_list("SteamMultiplayerPeer", true): print("STEAM peer method %s(%s) -> %s" % [entry.name, args_of(entry), type_string(entry.return.type)])
		for entry in ClassDB.class_get_property_list("SteamMultiplayerPeer", true): print("STEAM peer property %s" % entry.name)
		for entry in ClassDB.class_get_signal_list("SteamMultiplayerPeer", true): print("STEAM peer signal %s(%s)" % [entry.name, args_of(entry)])
	for setting in ProjectSettings.get_property_list():
		if String(setting.name).begins_with("steam"): print("STEAM setting %s = %s" % [setting.name, ProjectSettings.get_setting(setting.name)])
