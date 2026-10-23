extends Node3D
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const HIDE := preload("res://game/world/interactables/hiding_place.gd")
## Kept loaded, so the hotel's creature is not read from disk as a floor is put up; which creature a floor has is its kind's (CREATURE).
const LOCUST := preload("res://game/enemies/locust/locust.tscn")
var world_audio
var locust
## The floor's creature (game/enemies/creature.gd): the same body as `locust`,
## the name everything still reads it by. That one keeps holding it, so the
## many places that read it every frame have no getter in the way.
var creature:
	get: return locust
	set(value): locust = value
const GENERATOR := preload("res://game/world/generation/map_generator.gd")
const VALIDATOR := preload("res://game/world/generation/map_validator.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const DOOR := preload("res://game/world/interactables/hotel_door.gd")
const INTRO := preload("res://game/intro/intro_sequence.gd")
const TITLE := preload("res://game/title/title_scene.gd")
const DOCUMENT := preload("res://game/world/interactables/hotel_document.gd")
const PLACEMENT := preload("res://game/world/generation/document_placement.gd")
const TELEVISION := preload("res://game/world/interactables/hotel_television.gd")
const TV_PLACEMENT := preload("res://game/world/generation/tv_placement.gd")
const FLOOR_MAP := preload("res://game/app/floor_map.gd")
const CONTAINER := preload("res://game/world/interactables/hotel_container.gd")
const LOCK := preload("res://game/world/interactables/hotel_lock.gd")
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
const CATALOG := preload("res://game/discovery/discovery_catalog.gd")
const DIRECTOR := preload("res://game/director/pacing_director.gd")
const DISCOVERIES := preload("res://game/services/discovery_service.gd")
## The tapes that got out, and the board they make (records_service.gd).
const RECORDS := preload("res://game/services/records_service.gd")
## Watching from outside (observer_view.gd), with --observer.
const OBSERVER := preload("res://game/app/observer_view.gd")
const NET := preload("res://game/net/net_session.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
## The opening scene is built far from the hotel so the two never overlap.
const INTRO_ORIGIN := Vector3(600, 0, 0)
const TITLE_ORIGIN := Vector3(-600, 0, 0)
## Ambient light while the title room is on screen: its own lamps do the work.
const TITLE_AMBIENT := 0.03
## Holding interact this long skips the opening scene.
const SKIP_HOLD := 0.8
var settings
var session
var hotel
var player
var ui
var manifest := {}
var environment: Environment
var post_material: ShaderMaterial
var camcorder
var ambience: AudioStreamPlayer
var theme: AudioStreamPlayer
var ventilation: AudioStreamPlayer3D
# Quiet theme behind the menus; the in-game players pause with the tree.
var menu_music: AudioStreamPlayer
var automation := false
## Watching, not playing (--observer): no body, a camera that goes where it
## likes and everything the floor is doing written down the side
## (observer_view.gd). If a room is open on this machine it joins it without
## taking a seat; if there is none, it builds a floor of its own to walk.
var observer := false
var observer_view

## Local preview of the hunter's seat (--locust): this machine drives The
## Locust against an idle survivor, with no connection. Everything the hunter
## sees and hears runs in one process, so the acoustic view can be looked at
## and tuned without gathering five players.
var solo_locust := false
var visibility_clock := 0.0
## Which part of the floor's round comes next (0: none until the clock says).
var round_part := 0
var save_error := ""
var physical_errors: Array[String] = []
var intro: Node3D
var title_scene: Node3D
var director
var discoveries
var records
var paper_sound: AudioStreamPlayer
var scream_sound: AudioStreamPlayer
var static_sound: AudioStreamPlayer
## The snow of a lift ride, heard as well as seen (update_ride_hiss).
var ride_hiss: AudioStreamPlayer
var intro_seed := 0
var skip_time := 0.0
## Online play (net_session.gd) and its in-match replication (match_net.gd).
var net
var match_net
## The mind of the local survivor (sanity.gd).
const MIND := preload("res://game/app/sanity.gd")
var sanity
## The lifts, the rides and the sectors' words (lifts.gd).
const LIFTS := preload("res://game/app/lifts.gd")
var lifts
## The plan the survivors' eyes draw on the shared sheet (floor_map.gd).
var floor_map
## What this floor asks for, stage by stage (game/floors/hotel_floor.gd):
## the level, the lifts, the sets and the bots ask it rather than the stage's
## number.
const HOTEL_FLOOR := preload("res://game/floors/hotel_floor.gd")
var kind: GDScript = HOTEL_FLOOR
## The floors of the building by number: set_floor() picks this one's kind.
const FLOORS := preload("res://game/floors/floor_index.gd")
## Its objectives (game/floors/objectives/), one handler for each its kind
## lists, built with the floor: host_gate(), the lifts' lines and the
## director ask them rather than naming each.
var objectives := {}
const TELEVISIONS := preload("res://game/app/televisions.gd")
var tvs
const CODE_LOCK := preload("res://game/app/code_lock.gd")
var code
const EXECUTIONS := preload("res://game/app/executions.gd")
var executions
const DEATH_TAPE := preload("res://game/app/death_tape.gd")
var tape
const REVIVAL := preload("res://game/app/revival.gd")
var revival
const INTERACTION := preload("res://game/app/interaction.gd")
var interaction
const PRESENTATION_RIG := preload("res://game/app/presentation_rig.gd")
var rig
## What the floor has been, written down as it is played (run_ledger.gd).
const LEDGER := preload("res://game/app/run_ledger.gd")
var ledger
## The rules this floor is played with (game/floors/match_rules.gd): the
## defaults, with what the room changed over them. Asked for with rule().
const MATCH_RULES := preload("res://game/floors/match_rules.gd")
var rules: Dictionary = MATCH_RULES.defaults()

func rule(id: String) -> int:
	return int(rules.get(id, 0))

## The difficulty of the floor (game/floors/difficulty.gd): set as it starts,
## from the player's choice, the checkpoint or the room. Asked for with
## tuning(), the whole profile, with the floor's creature's own levers over
## it (kind.CREATURE_KEY; on the hotel, PROFILES as they are).
const DIFFICULTY := preload("res://game/floors/difficulty.gd")
var difficulty := DIFFICULTY.REFERENCE

func tuning() -> Dictionary:
	return DIFFICULTY.profile(difficulty, kind.CREATURE_KEY)

func set_difficulty(id: Variant) -> void:
	difficulty = DIFFICULTY.valid(id)
	session.difficulty = difficulty
	apply_tuning()

## The rules of the floor about to be played: `said` is what the room changed
## (nothing, alone). One of another creature or another floor stays at its
## default (MATCH_RULES.applies), so the tape does not count it as changed.
func set_rules(said: Variant) -> void:
	rules = MATCH_RULES.settled(said, kind.CREATURE_KEY, int(kind.NUMBER))
	apply_tuning()

## What the difficulty and the rules ask of everything that keeps a copy of
## its numbers: the session, the plan, the lifts and the creature (the
## director is given its part as it is made, in populate_floor).
func apply_tuning() -> void:
	var profile := tuning()
	var mercy := rule("restarts")
	session.restarts_allowed = int(profile.restarts) if mercy == MATCH_RULES.BY_DIFFICULTY else mercy
	session.solo_restarts = int(profile.solo_restarts)
	floor_map.forget = float(rule("plan_fade"))
	lifts.wait_lobby = float(profile.lift_wait)
	lifts.hold_after = float(profile.lift_hold)
	arm_creature()

## What the difficulty and the rules ask of the creature, on the one this
## floor has. Onslaught: it sees and hears further, and does not ease off.
func arm_creature() -> void:
	if not is_instance_valid(locust): return
	locust.tune(tuning())
	locust.arm(rule("onslaught") == 1)
## The local player is holding interact inside the refuge (online, the host
## counts everyone holding).
## Online, Esc opens a menu over the running match instead of pausing it.
var online_menu := false
## The power going: the same dead channel the execution uses, from above.
const BLACKOUT_SOUND := "res://assets/audio/events/execution_static.ogg"

func _enter_tree() -> void:
	world_audio = $WorldAudio
	world_audio.level = self
	settings = $Services/Settings
	session = $Services/GameSession
	player = $Player
	ui = $Interface
	var test_name := "default"
	var scripted := false
	for argument in OS.get_cmdline_args():
		if argument.ends_with(".gd"):
			test_name = argument.get_file().get_basename()
			scripted = true
	# Several runs of one script at once (tools/bots.ps1 -Parallel) each keep
	# their own files: sharing them, each overwrote the others' settings.
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--profile-tag="): test_name += "_" + argument.trim_prefix("--profile-tag=").validate_filename()
	if OS.get_cmdline_user_args().has("--test-profile"):
		settings.save_path = "user://test_hotel_%s_settings.json" % test_name
		session.checkpoint_path = "user://test_hotel_%s_checkpoint.json" % test_name
	# A floor a script runs -- a test, a probe, a capture, a bench -- is
	# nobody's game. With --test-profile it has files of its own; without it
	# it reads the player's settings, and it used to write over the player's
	# Continuar as well. The stuck probe of tools/verify.ps1 did, every time
	# it ran, and what it left to go on with was its own floor, with the
	# survivor where the probe keeps them: two hundred metres under the hotel.
	elif scripted: session.keeps_checkpoint = false
	# The floor every start_floor() builds until another is chosen (--floor=N).
	set_floor(floor_asked())
	discoveries = DISCOVERIES.new()
	discoveries.name = "Discoveries"
	if OS.get_cmdline_user_args().has("--test-profile"): discoveries.save_path = "user://test_hotel_%s_discoveries.json" % test_name
	$Services.add_child(discoveries)
	records = RECORDS.new()
	records.name = "Records"
	if OS.get_cmdline_user_args().has("--test-profile"): records.save_path = "user://test_hotel_%s_records.json" % test_name
	$Services.add_child(records)
	player.settings = settings
	ui.settings = settings
	ui.discoveries = discoveries
	ui.records = records
	net = NET.new()
	net.level = self
	match_net = net.match_net
	match_net.level = self
	if OS.get_cmdline_user_args().has("--test-profile"): match_net.checkpoint_path = "user://test_coop_%s_checkpoint.json" % test_name
	$Services.add_child(net)
	ui.net = net
	sanity = MIND.new()
	sanity.name = "Sanity"
	sanity.level = self
	$Services.add_child(sanity)
	lifts = LIFTS.new()
	lifts.name = "Lifts"
	lifts.level = self
	$Services.add_child(lifts)
	floor_map = FLOOR_MAP.new()
	floor_map.name = "FloorMap"
	floor_map.level = self
	$Services.add_child(floor_map)
	tvs = TELEVISIONS.new()
	tvs.name = "Televisions"
	tvs.level = self
	$Services.add_child(tvs)
	code = CODE_LOCK.new()
	code.name = "CodeLock"
	code.level = self
	$Services.add_child(code)
	executions = EXECUTIONS.new()
	executions.name = "Executions"
	executions.level = self
	$Services.add_child(executions)
	tape = DEATH_TAPE.new()
	tape.name = "DeathTape"
	tape.level = self
	$Services.add_child(tape)
	revival = REVIVAL.new()
	revival.name = "Revival"
	revival.level = self
	$Services.add_child(revival)
	interaction = INTERACTION.new()
	interaction.name = "Interaction"
	interaction.level = self
	$Services.add_child(interaction)
	rig = PRESENTATION_RIG.new()
	rig.name = "PresentationRig"
	rig.level = self
	$Services.add_child(rig)
	ledger = LEDGER.new()
	ledger.name = "Ledger"
	ledger.level = self
	$Services.add_child(ledger)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	automation = DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--automation")
	world_audio.enabled = not automation and not OS.get_cmdline_user_args().has("--silent")
	ui.sounds_enabled = world_audio.enabled
	player.hiding_changed.connect(world_audio.hide_cue)
	player.hiding_changed.connect(on_hide_changed)
	ui.action_requested.connect(on_action)
	ui.sheet.chunk_drawn.connect(func(op_id, kind, points): match_net.sheet_local(op_id, kind, points))
	ui.sheet.map_source = floor_map
	session.changed.connect(on_state)
	session.revived.connect(on_revived)
	net.closed.connect(on_net_closed)
	# A seat means a room; until then, the screen that is waiting for one.
	net.lobby_changed.connect(func(): if ui.screen in ["lobby", "join", "steam_wait"] and session.state == session.State.MENU: ui.menu("lobby" if net.local_seat != 0 else ("steam_wait" if ui.screen == "steam_wait" else "join")))
	# The rules being read while the host changes them. The host's own screen
	# is left alone: it is the one changing them, with a list open.
	net.lobby_changed.connect(func(): if ui.screen == "rules" and session.state == session.State.MENU and (not net.is_host or ui.rules_stale): ui.menu("rules"))
	net.joined.connect(func(): if session.state == session.State.MENU: ui.menu("lobby"))
	# An invitation accepted in Steam (or "Join game" on a friend's profile):
	# straight into that room, from the menus; mid-floor it waits for later.
	# The milestones reached are Steam achievements as well: whatever Steam
	# does not have yet, now and each time the marks change.
	var tell_steam := func() -> void: net.steam.unlock(records.milestones.keys())
	records.changed.connect(tell_steam)
	tell_steam.call_deferred()
	net.steam.join_asked.connect(func(lobby_id: int):
		if session.state != session.State.MENU or net.active(): return
		if net.join_steam(lobby_id, settings.values.player_name, settings.values.character): ui.menu("steam_wait")
		else: ui.menu("multiplayer", false, net.status))
	NavigationServer3D.map_set_use_async_iterations(get_world_3d().navigation_map, false)
	build_environment()
	build_audio()
	settings.changed.connect(apply_settings)
	apply_settings()
	# Behind the menu: an ordinary room, and something watching from its doorway.
	title_scene = TITLE.new()
	title_scene.name = "TitleScene"
	title_scene.position = TITLE_ORIGIN
	add_child(title_scene)
	player.position = Vector3(1, 0.06, 3.8)
	var saved: Dictionary = session.checkpoint()
	ui.menu("main", not saved.is_empty(), session.message)
	on_state()
	# The observer opens on what it watches: the tape's boot is the game's, and
	# stayed up over the tool until a key -- the first one it was given -- put it away.
	var replay_folder := ""
	var replay_at := 0.0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--bots-replay="): replay_folder = argument.trim_prefix("--bots-replay=")
		if argument.begins_with("--bots-at="): replay_at = float(argument.trim_prefix("--bots-at="))
	var watching_bots: bool = OS.get_cmdline_user_args().has("--bots-watch")
	var hunting_bots: bool = OS.get_cmdline_user_args().has("--bots-hunt")
	if not automation and not OS.get_cmdline_user_args().has("--observer") and replay_folder.is_empty() and not watching_bots and not hunting_bots: ui.play_intro()
	if not replay_folder.is_empty():
		await begin_replay(replay_folder, replay_at)
		return
	if watching_bots or hunting_bots:
		begin_bot_watch(hunting_bots)
		return
	var seed_wanted := -1
	# --steam-host: straight into a Steam room from the menus, for testing
	# Steam between two machines without clicking through them.
	if OS.get_cmdline_user_args().has("--steam-host"): on_action.call_deferred("host_steam")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--playtest-seed="):
			var value := argument.trim_prefix("--playtest-seed=")
			if value.is_valid_int() and int(value) >= 0 and int(value) <= 2147483647: seed_wanted = int(value)
	if OS.get_cmdline_user_args().has("--observer"):
		await begin_observing(seed_wanted)
	elif seed_wanted >= 0:
		if OS.get_cmdline_user_args().has("--locust"): await take_locust(seed_wanted)
		else: start_floor(seed_wanted)

## --bots-replay=<folder> [--bots-at=<second>]: a recorded bot match watched
## again in the observer. The replay lives with the test bots (tools/bots),
## which the exported game does not carry.
const REPLAY_SCRIPT := "res://tools/bots/bot_replay.gd"
func begin_replay(folder: String, at: float) -> void:
	if not ResourceLoader.exists(REPLAY_SCRIPT):
		ui.menu("main", false, "El repaso de partidas de bots no viene con el juego.")
		return
	var replay = load(REPLAY_SCRIPT).new()
	replay.setup(self, folder)
	add_child(replay)
	await replay.begin(at)

## --bots-watch [--bots=N] [--seed=S] [--mercy]: test bots playing floor after
## floor, watched live in the observer (tools/bots/bot_watch.gd, which ships
## with the tools and not the game).
## --bots-hunt [--bots=N] [--seed=S]: the same floors, with this machine's
## player as The Locust hunting the bots (hunt): a versus against bots, with
## no connection -- the hunter's seat as in take_locust(), its grace and all.
const WATCH_SCRIPT := "res://tools/bots/bot_watch.gd"
var bot_watch
func begin_bot_watch(hunt := false) -> void:
	if not ResourceLoader.exists(WATCH_SCRIPT):
		ui.menu("main", false, "Los bots de prueba no vienen con el juego.")
		return
	session.keeps_checkpoint = false
	if hunt: solo_locust = true
	else:
		observer = true
		settings.force_window = true
		settings.apply_display()
	var options := {"bots": 5 if hunt else 3, "seed": 81, "mercy": OS.get_cmdline_user_args().has("--mercy"), "knowledge": "discover", "hunt": hunt}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--bots="): options.bots = clampi(int(argument.trim_prefix("--bots=")), 1, 5)
		if argument.begins_with("--seed="): options.seed = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--knowledge="): options.knowledge = argument.trim_prefix("--knowledge=")
	bot_watch = load(WATCH_SCRIPT).new()
	bot_watch.setup(self, options)
	add_child(bot_watch)
	bot_watch.run()

## R in the observer while bots play: the floor on screen ends, the next one
## starts.
func skip_bot_floor() -> void:
	if is_instance_valid(bot_watch): bot_watch.skip()

## --observer: knock on a room on this machine (or wherever --address says),
## and if nobody answers within OBSERVER_WAIT seconds, build a floor here and
## watch that instead.
const OBSERVER_WAIT := 2.5
## Where it knocks, and how often it knocks again while nobody answers: the
## room may not be open yet, and a tool that only asked once had to be closed
## and opened again to catch a match.
var observer_address := "127.0.0.1"
var observer_port := 0
var observer_seed := -1
## A floor played by test bots (tools/bots): this machine's player is not in
## it -- parked, out of sight and out of reach -- and nothing it would do is
## done. The bots are bodies like a teammate's (match_net.bodies).
var bot_match := false
## A recorded bot match being watched again (tools/bots/bot_replay.gd): the
## floor is put up and nothing on it runs of itself.
var replaying := false
## Mercy for the bots (-Mercy): given the body the creature was about to take,
## true when it is spared instead. Only a bot match sets it.
var spare := Callable()
## Seat -> seconds it cannot be taken: a bot just spared, getting away.
var untouchable := {}
const OBSERVER_KNOCK := 3.0
var observer_knock := 0.0

func begin_observing(seed_value: int) -> void:
	observer = true
	# A tool belongs in a window: it is looked at beside the game, and the
	# player's own screen setting is left alone (settings.force_window).
	settings.force_window = true
	settings.apply_display()
	# The floors it builds to look at are nobody's game: each one used to take
	# the menu's Continue (session.keeps_checkpoint).
	session.keeps_checkpoint = false
	observer_port = net.PORT
	observer_seed = seed_value if seed_value >= 0 else randi_range(0, 2147483647)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--address="): observer_address = argument.trim_prefix("--address=")
		if argument.begins_with("--port="): observer_port = int(argument.trim_prefix("--port="))
	ui.menu("loading", false, "Buscando una partida en %s…" % observer_address)
	if net.join_observer(observer_address, observer_port) == OK:
		var waited := 0.0
		while waited < OBSERVER_WAIT and not net.observing:
			await get_tree().process_frame
			waited += get_process_delta_time()
	if not net.observing: net.shutdown("")
	# Whatever happened, there is something to look at: a floor of this
	# machine's own until a match starts. When one does, the room's own floor
	# replaces it on its own (match_net.begin).
	if not match_net.in_match(): await start_floor(observer_seed)
	enter_observer_mode()

## Knocking again while nobody has answered. The moment a room opens, this is
## what gets in without anybody having to reopen the tool.
func observer_seek(delta: float) -> void:
	if not observer or net.active(): return
	observer_knock -= delta
	if observer_knock > 0.0: return
	observer_knock = OBSERVER_KNOCK
	net.join_observer(observer_address, observer_port)

## No body of its own: the player is put away and the observer's camera takes
## over. Called on connecting, and after every floor this machine builds.
func enter_observer_mode() -> void:
	observer = true
	player.active = false
	player.visible = false
	player.collision_layer = 0
	player.torch.visible = false
	# Watching is not being hunted: the creature's own presence, its aura and
	# everything on the threat bus are off here. They are made for whoever it
	# is coming for, and this machine is nobody.
	world_audio.set_creature(null)
	if world_audio.aura != null:
		world_audio.aura.reset()
		world_audio.aura.process_mode = Node.PROCESS_MODE_DISABLED
	settings.mute_threat = true
	var threat := AudioServer.get_bus_index("Threat")
	if threat >= 0: AudioServer.set_bus_mute(threat, true)
	ui.close_menus()
	ui.overlay.hide()
	camcorder.visible = false
	$Presentation/Analog.visible = false
	lens_layer.visible = false
	if observer_view == null:
		observer_view = OBSERVER.new()
		observer_view.setup(self)
		add_child(observer_view)
	observer_view.camera.current = true
	observer_view.apply_roof()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## R on the observer: another floor, when there is no match to watch (Shift+R:
## the one before). This is what watching floors being generated is.
func observer_rebuild(seed_value: int) -> void:
	if match_net.in_match() or session.state == session.State.LOADING or bot_match or is_instance_valid(bot_watch): return
	await start_floor(seed_value)
	enter_observer_mode()

## The local hunter preview: build a floor and hand the creature to this player.
func take_locust(seed_value: int) -> void:
	solo_locust = true
	await start_floor(seed_value)
	if not is_instance_valid(locust): return
	hand_creature_to_player()
	locust.grace = 0.0
	ui.flash("VISION ACUSTICA - PRUEBA LOCAL", 4.0)

## This machine's player drives the creature of the floor up (solo_locust).
func hand_creature_to_player() -> void:
	if not is_instance_valid(locust): return
	locust.set_control("player")
	player.camera.current = false
	if locust.hunter_camera() != null: locust.hunter_camera().current = true
	# It never hears its own presence, online or here.
	world_audio.set_creature(null)
	apply_settings()

## Hunting bots given up (back to the menu): the player is its own again, and
## the next floor started from the menu is an ordinary one.
func end_bot_hunt() -> void:
	solo_locust = false
	player.visible = true
	player.collision_layer = 4
	player.held = false
	player.camera.current = true
	apply_settings()

## A port typed in the multiplayer menus (kept as text there), or the usual
## one if what is typed is not a number.
func port_setting(key: String) -> int:
	var text := str(settings.values.get(key, "")).strip_edges()
	return int(text) if text.is_valid_int() else net.PORT

func on_action(action: String) -> void:
	match action:
		# A new game asks first which creature it is played against.
		"new": ui.menu("difficulty")
		"begin": start_intro(randi_range(0, 2147483647))
		"continue":
			var data: Dictionary = session.checkpoint()
			if not data.is_empty(): continue_floor(data)
			else: ui.menu("main", false, session.message)
		# Never the same floor again: a floor lost, or given up on, is
		# followed by another one (on the same difficulty).
		"retry": start_floor(randi_range(0, 2147483647), false, [1], difficulty)
		"resume": session.set_state(session.State.PLAYING)
		"pause": session.set_state(session.State.PAUSED)
		"main": session.set_state(session.State.MENU)
		"settings": ui.show_settings("pause" if session.state == session.State.PAUSED else "main")
		"credits": ui.menu("credits")
		"characters": ui.show_characters()
		"multiplayer": ui.menu("multiplayer")
		"mp_steam": ui.menu("mp_steam")
		"mp_ip": ui.menu("mp_ip")
		# The four ways into a room: open one or join one, over IP / LAN or
		# over Steam (net_session.gd). The room itself is the same either way.
		"host": ui.menu("host_ip")
		"host_open":
			if net.host(settings.values.player_name, settings.values.character, port_setting("host_port"), str(settings.values.host_bind)) == OK: ui.menu("lobby")
			else: ui.menu("host_ip", false, net.status)
		"host_steam":
			if net.host_steam(settings.values.player_name, settings.values.character): ui.menu("steam_wait")
			else: ui.menu("mp_steam", false, net.status)
		"join": ui.menu("join")
		"join_steam": ui.menu("join_steam")
		"connect":
			if net.join(settings.values.join_address, settings.values.player_name, settings.values.character, port_setting("join_port")) != OK: ui.menu("join", false, net.status)
			else: ui.menu("join")
		"steam_invite": ui.menu("steam_invite")
		"steam_overlay_invite": net.steam.invite_friends()
		"lobby_back": ui.menu("lobby")
		"lobby_start":
			if not net.start_match(): ui.menu("lobby", false, net.start_problem())
		"lobby_leave":
			net.shutdown("")
			ui.menu("multiplayer")
		"online_resume": close_online_menu()
		"online_settings": ui.show_settings("online_pause")
		"online_pause":
			refresh_briefing()
			ui.menu("online_pause")
		"lobby": ui.menu("lobby")
		"lobby_character": ui.show_characters("lobby")
		"lobby_rules": ui.menu("rules")
		"rules_reset":
			ui.rules_stale = true
			net.set_option("rules", {})
		"online_retry": net.start_match()
		"online_new": net.start_match()
		"online_room": net.return_to_lobby()
		"online_quit":
			net.shutdown("")
			leave_online_floor()
		"archive": ui.menu("archive")
		"records":
			ui.records_back = ui.screen
			ui.menu("records")
		"achievements": ui.menu("achievements")
		"quit": get_tree().quit()

## A new game opens with the bedroom scene; its floor is built when it ends.
func start_intro(seed_value: int) -> void:
	if session.state in [session.State.LOADING, session.State.CUTSCENE]: return
	intro_seed = seed_value
	skip_time = 0.0
	intro = INTRO.new()
	intro.motion = 0.0 if settings.values.reduced else clampf(settings.values.bob / 0.1, 0.0, 3.0)
	intro.name = "Intro"
	intro.position = INTRO_ORIGIN
	add_child(intro)
	intro.finished.connect(finish_intro, CONNECT_ONE_SHOT)
	if is_instance_valid(hotel): hotel.visible = false
	# The floor played before is still standing behind the menu, and leaving
	# the pause for this scene would let its music and air run on over it.
	for loop in [ambience, theme, ventilation]: loop.stop()
	world_audio.reset()
	world_audio.mood.reset()
	# The last floor's final ride still gave its static, and the scene played
	# under it until the floor was built.
	lifts.reset()
	player.visible = false
	# Only the television lights the room: no hotel ambient light.
	environment.ambient_light_energy = 0.0
	session.set_state(session.State.CUTSCENE)
	ui.show_skip(settings.prompt_name("interact"))
	camera_cut()

func finish_intro() -> void:
	if not is_instance_valid(intro): return
	intro.queue_free()
	intro = null
	ui.hide_skip()
	environment.ambient_light_energy = ambient_energy
	player.visible = true
	player.camera.current = true
	# A new game is the floor --floor asks for, not the one continued last.
	start_floor(intro_seed, false, [1], "", floor_asked())

## The floor built next, by its number in the building (game/floors/floor_index.gd):
## its kind says how it is drawn, built and checked, and how many stages it has.
## A number with no floor built gets the hotel, and the session keeps 1.
func set_floor(number: int) -> void:
	kind = FLOORS.kind(number)
	session.floor_number = int(kind.NUMBER)
	session.stages = int(kind.count())

## --floor=N: the floor a test, a probe, the bots or the observer play; 1 without
## it. Only a whole number counts (some probes have a --floor of their own).
static func floor_asked() -> int:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--floor="):
			var value: String = argument.trim_prefix("--floor=")
			if value.is_valid_int(): return int(value)
	return 1

## slots: the seats playing it (session.start); the bots bring their own.
## `difficulty_id`: the creature's (game/floors/difficulty.gd); empty, the one
## the player last chose.
## `floor_number`: the floor to build (set_floor()); 0, the one chosen last.
func start_floor(seed_value: int, force_fallback := false, slots: Array = [1], difficulty_id := "", floor_number := 0) -> void:
	if floor_number > 0: set_floor(floor_number)
	if not await build_floor(seed_value, force_fallback, slots.size()): return
	set_difficulty(difficulty_id if not difficulty_id.is_empty() else String(settings.values.difficulty))
	camcorder.start_tape(seed_value)
	# A new tape starts with the lens wide.
	player.zoom = 1.0
	player.zoom_wanted = 1.0
	session.online = false
	session.authority = true
	session.start(seed_value, manifest.get("fallback", false), slots)
	save_error = session.message
	ui.sheet.clear()
	populate_floor(true)

## Continuar: the floor that was left, from where it was left
## (game/app/floor_save.gd). With nothing kept of it -- a checkpoint from
## before floors were kept, or one that cannot be read -- from its beginning.
func continue_floor(data: Dictionary) -> void:
	var seed_value := int(data.seed)
	# Its floor first: what was kept of it is read against that floor's generator.
	set_floor(int(data.get("floor", 1)))
	# Read before the floor starts: starting one forgets what was kept.
	var state: Dictionary = session.read_state(seed_value)
	await start_floor(seed_value, data.get("fallback", false) == true, [1], String(data.get("difficulty", DIFFICULTY.REFERENCE)))
	if state.is_empty() or session.state != session.State.PLAYING or session.run_seed != seed_value: return
	SAVE.give(self, state)
	keep_floor()

## The tape's own clock (the one on the picture), which is not the floor's: a
## stage given back is the tape rewound to where that stage began and recorded
## over (docs/EXECUTION.md, 14.4), so its clock goes back there while the
## floor's time -- the one a record is made of -- goes on. `tape_rewound` is
## how far behind it is, `stage_tape` what it read when the stage in hand
## began, and `rewind` the rewinding itself while it is shown: {from, to,
## time}, seconds of that clock.
const REWIND_TIME := 1.4
var tape_rewound := 0.0
var stage_tape := 0.0
var rewind := {}

func tape_seconds() -> float:
	return maxf(0.0, session.elapsed - tape_rewound)

## A stage is given back (revival.apply_revival, on every machine): the
## picture is the tape running back, and whoever films it waits for it.
func begin_rewind() -> void:
	if observer or bot_match or match_net.local_is_locust(): return
	rewind = {"from": tape_seconds(), "to": minf(stage_tape, tape_seconds()), "time": 0.0}
	lost_signal = REWIND_TIME + 0.1
	player.held = true
	player.active = false

func update_rewind(delta: float) -> void:
	if rewind.is_empty(): return
	rewind.time = float(rewind.time) + delta
	var share := clampf(float(rewind.time) / REWIND_TIME, 0.0, 1.0)
	# Fast at first and settling on the second it stops at, as a counter does.
	var shown := lerpf(float(rewind.from), float(rewind.to), 1.0 - pow(1.0 - share, 2.4))
	ui.show_rewind(camcorder.clock_text(shown))
	# With reduced effects the snow stays as it is: the mark and the clock
	# running back say it.
	if post_material != null: post_material.set_shader_parameter("rewinding", 0.0 if settings.values.reduced else 1.0)
	if share < 1.0 and session.state == session.State.PLAYING: return
	# Recorded over from there: the clock goes on from where the stage began.
	tape_rewound = session.elapsed - float(rewind.to)
	rewind = {}
	ui.hide_rewind()
	if post_material != null: post_material.set_shader_parameter("rewinding", 0.0)
	lost_signal = 0.0
	static_level = 0.0
	if execution.is_empty() and local_alive():
		player.held = not lifts.boarding.is_empty() or lifts.leaving >= 0.0
		player.active = session.state == session.State.PLAYING and not online_menu
	camera_cut()

## The floor as it stands, kept for Continuar. Alone only (a room has its own
## checkpoint, and the observer's and the bots' floors are nobody's to go on
## with), and only while there is something to go back to: not being
## executed, not waiting to be stood up again, not dead.
const SAVE := preload("res://game/app/floor_save.gd")
## Seconds of play between one keeping and the next: what a crash can cost.
const KEEP_EVERY := 30.0
var keep_clock := 0.0

func can_keep() -> bool:
	if net.active() or session.online or not session.keeps_checkpoint or observer or bot_match or replaying: return false
	if session.state not in [session.State.PLAYING, session.State.PAUSED]: return false
	if not is_instance_valid(hotel) or manifest.is_empty() or not is_instance_valid(player): return false
	if not execution.is_empty() or session.restart_wait > 0.0: return false
	return session.participants.get(player.slot, session.Life.DEAD) != session.Life.DEAD

func keep_floor() -> bool:
	keep_clock = 0.0
	return can_keep() and session.write_state(SAVE.take(self))

## Generates, builds and validates a floor. False (back in the menu) when it
## could not be made playable. `survivors`: how many play it, which decides
## how big the floor is (the palette's AREA) and how many sets each stage has (the
## rest of the hotel's are only cabinets).
## The survivors a floor is drawn for when it is not the ones playing it: the
## tests that walk known places of a floor as it is for two or three set it.
## 0, as in the game, is the ones who play it.
var drawn_for := 0

func build_floor(seed_value: int, force_fallback := false, survivors := 1) -> bool:
	if session.state == session.State.LOADING: return false
	session.set_state(session.State.LOADING)
	await get_tree().process_frame
	await get_tree().process_frame
	world_audio.reset()
	world_audio.mood.reset()
	player.reset_survival()
	# Every floor starts with the lens wide, online ones too.
	player.zoom = 1.0
	player.zoom_wanted = 1.0
	ledger.reset()
	# Nothing left lying by the last floor's captures, nor seen of them.
	executions.reset()
	tape.reset()
	tape_rewound = 0.0
	stage_tape = 0.0
	rewind = {}
	ui.hide_rewind()
	# The game's own rules until a room says otherwise (begin_online_play).
	set_rules({})
	ui.summary = {}
	ui.places = {}
	ui.outcome = {}
	if is_instance_valid(locust):
		remove_child(locust)
		locust.queue_free()
	if is_instance_valid(hotel):
		remove_child(hotel)
		hotel.queue_free()
	if match_net != null: match_net.floor_building()
	manifest = kind.GENERATOR.new().generate(seed_value, drawn_for if drawn_for > 0 else survivors)
	if force_fallback:
		manifest = kind.GENERATOR.new().candidate(404, 0, true)
		manifest["fallback"] = true
		manifest["requested_seed"] = seed_value
	build_objectives()
	tv_sets = settle_objectives(survivors).get("televisions", {})
	hotel = kind.GEOMETRY.new()
	hotel.name = "GeneratedHotel"
	hotel.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hotel)
	await hotel.build(manifest)
	configure_hotel()
	player.spawn = Vector3(0, 0.04, 0)
	player.position = player.spawn
	player.velocity = Vector3.ZERO
	# Nothing of the last floor's lifts survives into this one.
	lifts.reset()
	player.sanity = 100.0
	player.set_burnt(false)
	sanity.minds.clear()
	sanity.sight_rest = 0.0
	sanity.sight_paid = 0.0
	player.reset_handheld()
	player.camera.rotation = Vector3.ZERO
	player.torch.visible = false
	# Looking at the reception's door, whichever way the floor put it.
	player.rotation.y = float(manifest.get("start_facing", PI))
	visibility_clock = 1
	# Physics validation ignores closed door leaves (layer 8), which are openable.
	get_tree().paused = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	physical_errors = kind.VALIDATOR.new().validate_physics(get_world_3d(), manifest)
	if not physical_errors.is_empty():
		push_warning("Physical map rejection: %s" % str(physical_errors))
		remove_child(hotel)
		hotel.queue_free()
		manifest = kind.GENERATOR.new().candidate(404, 0, true)
		manifest["fallback"] = true
		manifest["requested_seed"] = seed_value
		tv_sets = settle_objectives(survivors).get("televisions", {})
		hotel = kind.GEOMETRY.new()
		hotel.name = "GeneratedHotel"
		hotel.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(hotel)
		await hotel.build(manifest)
		configure_hotel()
		await get_tree().physics_frame
		await get_tree().physics_frame
		physical_errors = kind.VALIDATOR.new().validate_physics(get_world_3d(), manifest)
		if not physical_errors.is_empty():
			save_error = "El mapa de respaldo no superó la validación física. No se inició la partida."
			session.set_state(session.State.MENU)
			return false
	# Wait for the new static floor's navigation to be queryable before playing.
	var exit_room: Dictionary = manifest.rooms[manifest.exit]
	var exit_position := FLOOR.position_of(exit_room)
	var navigation_ready := false
	# A second and a half of frames: the mesh is baked inside build(), but the
	# server needs a few frames to take it, and it is baked fine now (10 cm
	# cells), so twelve frames was cutting it close on a machine that is busy
	# -- a guest that gave up here ended up on the standby floor and was
	# thrown out of the match for not having the host's.
	for frame in 90:
		await get_tree().physics_frame
		var path := FLOOR.navigation_path(get_world_3d().navigation_map, Vector3.ZERO, exit_position)
		if path.size() > 1 and path[-1].distance_to(exit_position) < 0.5:
			navigation_ready = true
			break
	if not navigation_ready:
		save_error = "No se pudo validar la ruta de salida. El nivel no se inició."
		session.set_state(session.State.MENU)
		return false
	# The floor starts with its bounce light in place, not popping in.
	await bounce_ready()
	# And with its pipelines built: the loading screen pays for them, not the
	# first step into a room (presentation/shader_warmup.gd). --no-warmup
	# leaves them to be built during play, which is what it cost before.
	# Nothing to warm up where nothing is drawn (headless tests).
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--no-warmup"):
		await WARMUP.run(self)
	return true

## Waits for the bounce light, which bakes on worker threads after a floor is
## built or a preset first asks for it (hotel_geometry.start_bounce).
func bounce_ready() -> void:
	while is_instance_valid(hotel) and hotel.bounce.baking():
		hotel.bounce.poll()
		await get_tree().process_frame

## Creature, documents, director and sounds of a floor that is about to be played.
func populate_floor(with_director: bool) -> void:
	camera_cut()
	spawn_locust()
	# The sets, then the drawers with the numbers and the keypad: each by its
	# objective, in the order the floor lists them.
	for objective_name in objectives: objectives[objective_name].place()
	# After the furniture: a document may be shut in a suitcase, and the key
	# goes in a drawer with nothing else in it.
	place_documents()
	code.place_key()
	director = null
	if with_director:
		director = DIRECTOR.new()
		director.name = "Director"
		director.tune(tuning())
		director.setup(self, int(manifest.seed))
		hotel.add_child(director)
	# Watching, its presence is nobody's: a floor built again (the host started
	# another one) would otherwise bring the sound back.
	world_audio.set_creature(null if observer else locust.presence_sound())
	for door in hotel.doors: door.sound_requested.connect(world_audio.door_cue)
	# Easing wardrobe doors creaks: a quiet noise the creature can pick up.
	for hide in hotel.hides: hide.peek_started.connect(on_peek)
	if not automation and not OS.get_cmdline_user_args().has("--silent"):
		ambience.play()
		theme.play()
		ventilation.play()
	# A floor opens on the same card as every sector after it, and the notice
	# of what this one wants follows once the card is gone. Not over the
	# observer: watching is not filming, and the card covered every floor R put up.
	if not automation and not observer and not match_net.local_is_locust():
		ui.show_transit(kind.title_of(session.stage), lifts.stage_errand(session.stage), lifts.OPENING_CARD)
	lifts.pending_brief = session.stage
	lifts.brief_wait = lifts.OPENING_CARD if not automation else 0.0

# --- Online floors ---------------------------------------------------------------

## The host started a floor: build it, then tell the host we are ready.
func start_online_floor(config: Dictionary) -> void:
	if is_instance_valid(intro):
		intro.queue_free()
		intro = null
	close_online_menu()
	if reading_paper(): close_document()
	if session.state == session.State.LOADING:
		await session.changed
	# The room's floor, by its number (net_session.start_match() puts it in the config).
	set_floor(int(config.get("floor", 1)))
	if not await build_floor(int(config.seed), false, config.survivors.size()):
		if is_same(match_net.config, config): net.shutdown("No se pudo construir el piso de la partida.")
		return
	# The match this floor was for may have gone while it was being put up
	# (the host left, or started again): reporting it then broke on an empty
	# match and left the loading screen up over the menu.
	if not match_net.in_match() or not is_same(match_net.config, config): return
	# Coming back into a floor that is already being played says so: the wait
	# is the same, what it means is not.
	ui.menu("loading", false, "Volviendo a la partida…" if match_net.rejoin_snapshot.get("returning", false) else "Esperando a los demás jugadores…")
	player.visible = true
	player.collision_layer = 4
	player.camera.current = true
	player.slot = net.local_seat
	player.spawn = match_net.spawn_point(net.local_seat)
	player.position = player.spawn
	# Watching: the floor just built is the room's, and this machine still has
	# no body in it. Without this, a match starting over a floor of its own
	# handed the camera back to a player nobody is playing.
	if observer: enter_observer_mode()
	match_net.floor_built()

## Everyone has the floor: the session, the creature and who controls it.
func begin_online_play(config: Dictionary) -> void:
	camcorder.start_tape(int(config.seed))
	session.online = true
	session.authority = not net.is_client()
	session.start(int(config.seed), manifest.get("fallback", false), config.survivors)
	save_error = ""
	ui.sheet.clear()
	ui.sheet.seat = net.local_seat
	set_difficulty(config.get("difficulty", DIFFICULTY.REFERENCE))
	set_rules(config.get("rules", {}))
	populate_floor(net.is_host and int(config.mode) == NET.Mode.COOP)
	if int(config.mode) == NET.Mode.VERSUS:
		locust.set_control("player" if match_net.local_is_locust() else "puppet")
	else:
		locust.set_control("ai" if net.is_host else "puppet")
	var locust_player: bool = match_net.local_is_locust()
	player.visible = not locust_player
	player.collision_layer = 0 if locust_player else 4
	player.torch.visible = false
	player.camera.current = not locust_player
	execution = {}
	if locust_player:
		if locust.hunter_camera() != null: locust.hunter_camera().current = true
		# The hunter does not hear its own presence or dread.
		world_audio.set_creature(null)
	# Re-derived, never remembered: the Environment is shared, so the hunter's
	# grade has to come back out of apply_settings() on the way in and out.
	apply_settings()
	on_state()

## Back in the room: the floor stays hidden behind the menu until the next one.
func leave_online_floor() -> void:
	close_online_menu()
	if is_instance_valid(locust):
		remove_child(locust)
		locust.queue_free()
	player.visible = true
	player.collision_layer = 4
	player.slot = 1
	solo_locust = false
	session.online = false
	session.authority = true
	apply_settings()
	session.set_state(session.State.MENU)

func on_net_closed(reason: String) -> void:
	# Watching a floor of its own, what closed was a knock nobody answered (or
	# a room that shut before its match): the floor goes on as it was. Taken
	# down like a match's, it lost its creature and was left paused about every
	# half minute while nobody was hosting.
	var own_floor: bool = observer and not session.online and session.state == session.State.PLAYING
	if match_net.in_match() or (session.state != session.State.MENU and not own_floor):
		match_net.end()
		leave_online_floor()
	# Watching: a room that closed, or a knock nobody answered, leaves the tool
	# as it was -- looking at a floor of its own and knocking again.
	if observer:
		if manifest.is_empty(): await start_floor(observer_seed)
		if not own_floor: enter_observer_mode()
		if observer_view != null and not reason.is_empty(): observer_view.note("sin partida: %s" % reason)
		return
	ui.menu("multiplayer", false, reason)

func open_online_menu() -> void:
	online_menu = true
	player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_briefing()
	ui.menu("online_pause")

## What the pause screens show of the sector in hand. The hunter has no errand.
func refresh_briefing() -> void:
	if match_net.local_is_locust() or manifest.is_empty(): ui.set_briefing("", "", [])
	else: ui.set_briefing(kind.title_of(session.stage), lifts.stage_brief(session.stage), lifts.stage_progress())

func close_online_menu() -> void:
	if not online_menu: return
	online_menu = false
	ui.close_menus()
	on_state()

## A player hunting hears a wardrobe door as far as an ordinary door: getting
## in or out has to show from the next rooms, not only from beside it. The AI
## keeps the quieter radius (on_hide_changed). Both in noise_kinds.HEARD.
const HUNTER_WARDROBE_RADIUS: float = NOISE.HEARD["wardrobe_hunter"] / NOISE.HEARING_SCALE

## A noise the creature may hear, wherever the creature is decided.
func locust_hear(point: Vector3, radius: float, kind := NOISE.Kind.FOOTSTEP) -> void:
	if not is_instance_valid(locust): return
	if locust.control == "ai":
		locust.hear(point, radius)
	elif not net.is_client() and (match_net.versus() or match_net.local_is_locust()) and locust.grace <= 0.0:
		# Whoever is in charge decides, which online is the host even when the
		# host is a survivor and its copy of the creature is only a puppet.
		# The machine in charge measures how the noise reaches the creature and
		# sends that, not the bare position: the hunter is told what it hears.
		# (The quiet way out reaches it as much less far as it does the AI.)
		if kind == NOISE.Kind.WARDROBE: radius = maxf(radius, HUNTER_WARDROBE_RADIUS * (NOISE.QUIET if radius < NOISE.radius("wardrobe") - 0.01 else 1.0))
		var route: Dictionary = locust.hear_route(point, radius)
		if route.audible: match_net.tell_hunter(point, route, radius, kind)

func sheet_snapshot() -> Array:
	return ui.sheet.snapshot()

func restore_sheet(ops: Array) -> void:
	ui.sheet.restore(ops)

## The stage's own sets, all of them on. A stage with no sets of its own asks
## for nothing here.
func sets_lit() -> bool:
	return stage_televisions().is_empty() or televisions_on() >= TV_PLACEMENT.needed(session.roster_count)

func on_state() -> void:
	var playing: bool = session.state == session.State.PLAYING
	# The online menu belongs to the stretch of play it was opened in. Kept
	# over a stage change or the end of the floor, it came back as a player
	# frozen with a cursor and no menu, or under the next floor's loading screen.
	if not playing: online_menu = false
	if session.state in [session.State.MENU, session.State.FAILED, session.State.WON]:
		world_audio.reset()
		if is_instance_valid(scream_sound): scream_sound.stop()
	player.active = playing and not online_menu and local_alive() and not match_net.local_is_locust() and not bot_match
	if not playing: player.velocity = Vector3.ZERO
	if not playing and ui.sheet.visible:
		ui.sheet.close()
		player.reading = false
	# The keypad as well: left open under the pause it still took digits, and
	# Escape shut it instead of resuming.
	if not playing and lock_open: close_lock()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing and not online_menu and not ui.sheet.visible else Input.MOUSE_MODE_VISIBLE
	get_tree().paused = session.state in [session.State.MENU, session.State.PAUSED, session.State.WON, session.State.FAILED] and not match_net.in_match()
	if session.state in [session.State.MENU, session.State.LOADING, session.State.CUTSCENE]: clear_screen_cues()
	if is_instance_valid(hotel) and not manifest.is_empty():
		hotel.open_gates(session.stage, session.goal.get("ready", false))
		if session.goal.get("blackout", false) and not hotel.dark: apply_blackout()
		elif not session.goal.get("blackout", false) and hotel.dark: restore_power()
		if playing and session.stage > last_stage:
			lifts.follow_players(session.stage)
			# What the captures of the sector behind left on its floor goes with it.
			executions.clear_leavings()
			# Where the tape was when this sector began: what it is rewound to
			# if the sector is given back.
			stage_tape = tape_seconds()
			# What the sector just closed took, for the line this floor leaves.
			if not net.is_client(): ledger.note_sector(last_stage)
	# Only a stage being played counts as reached (a change announced in the
	# transition used to count it, and the creature never got its road), and
	# a new floor starts the count again.
	if playing or session.stage < last_stage: last_stage = session.stage
	press_time = 0
	pressed_door = null
	was_held = Input.is_action_pressed("interact")
	if not playing and reading_paper(): close_document()
	# The aiming dot only while playing: not over the title room or the opening scene.
	ui.get_node("HUD/Crosshair").visible = playing
	update_title_scene()
	# The title room behind the main menu is outside the game: no tape over it.
	# Watching is not filming: the observer sees the hotel, not the tape.
	$Presentation/Analog.visible = session.state != session.State.MENU and not observer
	if playing and online_menu: return
	if playing or session.state == session.State.CUTSCENE:
		ui.close_menus()
		if not playing:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_tree().paused = false
		return
	match session.state:
		session.State.MENU:
			if net.active(): ui.menu("lobby" if net.local_seat != 0 else "join")
			else:
				var saved: Dictionary = session.checkpoint()
				ui.menu("main", not saved.is_empty(), save_error if not save_error.is_empty() else session.message)
		session.State.PAUSED:
			# Pausing is where a floor is left from, by the menu or by
			# closing the game: it is kept as it stands.
			keep_floor()
			refresh_briefing()
			ui.menu("pause")
		session.State.LOADING: ui.menu("loading")
		session.State.TRANSITION:
			# Between stages the floor goes on: a held beat and a notice, not
			# the end-of-floor screen. Only the last stage brings that.
			if session.more_stages():
				ui.close_menus()
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				# Only for whoever is not left behind in the old wing: a
				# survivor still there hears about the next sector when their
				# own car takes them to it (lifts.apply_ride).
				var here := int(FLOOR.room_at(manifest.rooms, player.global_position).get("wing", -1))
				if not local_alive() or here != session.stage - 1: lifts.pending_brief = session.stage + 1
			else: ui.menu("transition")
		session.State.WON:
			ui.elapsed = session.elapsed
			if not net.is_client() and ui.summary.is_empty(): file_run(true)
			if match_net.in_match():
				if net.is_host: match_net.clear_checkpoint()
				ui.menu("online_won")
			else: ui.menu("won")
		session.State.FAILED:
			ui.elapsed = session.elapsed
			# Lost online too: the room's saved floor goes with it.
			if match_net.in_match() and net.is_host: match_net.clear_checkpoint()
			# A tape that never got out is read too: who did what, and how it went.
			if not net.is_client() and ui.summary.is_empty(): file_run(false)
			ui.menu("online_failed" if match_net.in_match() else "failed")

## What this floor has been so far, as the bots' summary reads it: how long
## each sector took, how many fell, how many hid. The whole of it is the
## ledger's (run_ledger.gd), kept by whoever runs the floor.
var run_stats: Dictionary:
	get: return {"sectors": ledger.sectors, "deaths": ledger.deaths, "hides": ledger.hides}

## A survivor has climbed into a wardrobe. Only the machine in charge counts.
func note_hide(seat := -1) -> void:
	if not net.is_client(): ledger.note_hide(int(player.slot) if seat < 0 else seat)

## The floor is over, won or lost: the line it leaves, written by whoever ran
## it and sent to the rest, so every machine files the same floor.
func file_run(won: bool) -> void:
	var line := close_run(won)
	take_run(line)
	if match_net.in_match(): match_net.tell_summary(line)

## The line of the floor, filed on this machine: the board (a tape that got
## out), the career and the milestones of whoever plays here. A floor that is
## nobody's game -- the bots', the observer's own -- leaves nothing.
func take_run(line: Dictionary) -> void:
	ui.summary = line
	var mine: bool = session.keeps_checkpoint and not observer
	if mine:
		for who in match_net.cards.values(): records.played_with(String(who))
	ui.outcome = records.file(line, int(net.local_seat) if match_net.in_match() else int(player.slot), mine)
	ui.places = ui.outcome.places

## The floor is over and everybody who was going to get out is out. The line
## is written on every machine, so a guest's board has the run too, but only
## the one in charge decides what it says.
func close_run(won := true) -> Dictionary: return ledger.close(won)

## What to call a seat on the board: the name it joined under, or the survivor
## it is playing, which is all there is on your own.
func seat_name(seat: int) -> String:
	var players: Dictionary = match_net.config.get("players", {}) if match_net.in_match() else {}
	if players.has(seat) and not String(players[seat].get("name", "")).is_empty(): return String(players[seat].name)
	# The name the player gave itself (the card, or the multiplayer screen).
	if seat == player.slot and not match_net.in_match() and not bot_match and not String(settings.values.player_name).strip_edges().is_empty(): return NET.clean_name(String(settings.values.player_name))
	if seat == player.slot: return AVATAR_NAMES[clampi(settings.values.character, 0, AVATAR_NAMES.size() - 1)]
	var body = match_net.bodies.get(seat)
	if is_instance_valid(body) and not String(body.player_name).is_empty(): return String(body.player_name)
	return "Superviviente %d" % seat

## The body sitting in a seat: this machine's player, or anybody else's.
func body_of_seat(seat: int) -> Node3D:
	if seat == player.slot and session.participants.has(seat): return player
	var body = match_net.bodies.get(seat)
	return body if is_instance_valid(body) else null

const AVATAR_NAMES := ["Detective", "Detective", "Exploradora"]

## The pad in the hands, when something happens to the body it is holding: the
## creature's grip, each stab, and the board being thrown. Off by the player's
## own setting, and nothing at all when there is no pad.
func rumble(weak: float, strong: float, seconds: float) -> void:
	if settings == null or not settings.values.rumble or not settings.pad_present(): return
	for pad in Input.get_connected_joypads(): Input.start_joy_vibration(pad, weak, strong, seconds)

## Out of whatever is open, and one step at a time: the opening scene, a
## document, the settings, the screen before this one, the pause. Escape and
## the pad's own way back are the same thing and go through here.
func step_back() -> void:
	if session.state == session.State.CUTSCENE: finish_intro()
	elif reading_paper(): close_document()
	elif ui.settings_open:
		# Closed first: the revert would otherwise reopen these settings.
		ui.settings_open = false
		if not settings.previous_display.is_empty(): settings.revert_display()
		on_action(ui.return_action)
	elif match_net.in_match() and session.state == session.State.PLAYING:
		if online_menu: close_online_menu()
		else: open_online_menu()
	elif net.active() and session.state == session.State.MENU and ui.screen in ["lobby", "join"]: on_action("lobby_leave")
	elif ui.screen == "join" and session.state == session.State.MENU: on_action("multiplayer")
	elif ui.screen == "characters" and session.state == session.State.MENU: on_action("lobby" if net.active() else "multiplayer")
	elif ui.screen == "tape": ui.menu("records")
	elif ui.screen == "rules" and net.active(): ui.menu("lobby")
	elif ui.screen == "records" and ui.records_back != "main": ui.menu(ui.records_back)
	elif ui.screen in ["credits", "multiplayer", "records", "archive", "difficulty"] and session.state == session.State.MENU: on_action("main")
	elif session.state == session.State.PAUSED: session.set_state(session.State.PLAYING)
	elif session.state == session.State.PLAYING: session.pause()

## A pad button the game itself answers, wherever it is pressed: the menu
## button is the pause (the Escape of a pad), and while the keypad is up the
## cross and the two face buttons work its numbers, because a pad has nowhere
## to type a code. Everything else a pad does is bound to an action and
## arrives as one (settings_service.PAD_KEYS).
func pad_pressed(button: int) -> void:
	if lock_open:
		match button:
			JOY_BUTTON_DPAD_LEFT: lock_digit = (lock_digit + 9) % 10
			JOY_BUTTON_DPAD_RIGHT: lock_digit = (lock_digit + 1) % 10
			JOY_BUTTON_DPAD_UP: lock_digit = (lock_digit + 5) % 10
			JOY_BUTTON_DPAD_DOWN: lock_digit = (lock_digit + 5) % 10
			JOY_BUTTON_A: type_code(str(lock_digit))
			JOY_BUTTON_X: type_code("borrar")
			JOY_BUTTON_B, JOY_BUTTON_START: close_lock()
			_: return
		if lock_open: ui.show_lock(typed, DIGITS.COUNT, "", noted_code(), lock_digit)
		return
	if button == JOY_BUTTON_B and ui.sheet.visible:
		toggle_sheet()
		return
	# Dead and watching, the bottom button is the click that goes to the next.
	if button == JOY_BUTTON_A and not local_alive() and session.state == session.State.PLAYING and not online_menu and not ui.sheet.visible:
		match_net.next_watch()
		return
	# B goes back, the menu button pauses; in play they meet at the same place.
	if button not in [JOY_BUTTON_B, JOY_BUTTON_START]: return
	if button == JOY_BUTTON_B and session.state == session.State.PLAYING and not ui.settings_open and not online_menu and not reading_paper(): return
	step_back()

## The stage the floor was on when it was last looked at, to tell a change.
var last_stage := 1

## The power goes, everywhere at once. Nothing says so in words: the hotel
## drops into the dark with a dead channel from overhead, wherever you are, and
## in the creature's reading the ceilings it can no longer hear humming come
## back at it in one burst. In the hands, the board being thrown is one short
## knock. The set that tripped it plays that same static: beside it, it is not
## played twice.
func apply_blackout() -> void:
	rumble(0.35, 0.0, 0.25)
	hotel.blackout(true)
	if world_audio.enabled and not world_audio.long_playing(BLACKOUT_SOUND, 1.5, "warp"): world_audio.play_long(BLACKOUT_SOUND, Vector3(0, 2.5, 0), 0.0, RID(), true)
	if is_instance_valid(locust): locust.blackout()

## And the power comes back, in the wing ahead. What went out belonged to the
## wing where the last set was lit: crossing into the next one finds its lights
## on. Whoever is riding into it hears a moment of the dead channel overhead,
## the board thrown back on. It used to be placed at the body, which at this
## point of the ride is still standing in the car being left behind.
const POWER_BACK := 1.6
func restore_power() -> void:
	hotel.blackout(false)
	if world_audio.enabled and not lifts.boarding.is_empty(): world_audio.play_long(BLACKOUT_SOUND, Vector3(0, 2.5, 0), -4.0, RID(), true, POWER_BACK)

## The title room is shown only on the main menu; any other state gets the
## hotel's light back and, outside the opening scene, the player's camera.
func update_title_scene() -> void:
	if not is_instance_valid(title_scene): return
	var in_menu: bool = session.state == session.State.MENU
	if not in_menu and not title_scene.visible: return
	title_scene.set_active(in_menu)
	if in_menu:
		environment.ambient_light_energy = TITLE_AMBIENT
		if is_instance_valid(hotel): hotel.visible = false
		player.visible = false
	elif session.state != session.State.CUTSCENE:
		# Leaving the menu: the hotel's own light back, unless the creature is
		# being driven from here, in which case it has none and keeps its camera.
		environment.ambient_light_energy = 0.0 if rig.echo_seat() else ambient_energy
		# Not while it is still being put up: it shows itself when it is done.
		if is_instance_valid(hotel): hotel.visible = not hotel.building
		player.visible = not hunter_seat()
		player.camera.current = not hunter_seat()
		if hunter_seat() and is_instance_valid(locust) and locust.hunter_camera() != null: locust.hunter_camera().current = true

func in_refuge() -> bool:
	return point_in_refuge(player.position)

## Everyone the creature can hunt on this floor: the local player and, in an
## online match, the other survivors' bodies. Each has slot, camera, torch,
## hidden, hiding_place, crouched and velocity.
func survivors() -> Array:
	var result: Array = []
	# The hunter has no survivor of its own, except in the local preview, where
	# this body is left standing as something to hunt.
	if session.participants.has(player.slot) and (solo_locust or not match_net.local_is_locust()): result.append(player)
	for body in match_net.bodies.values():
		if is_instance_valid(body): result.append(body)
	return result

## This machine's survivor is still alive (always true for The Locust player).
func local_alive() -> bool:
	return not match_net.in_match() or match_net.local_is_locust() or session.participants.get(player.slot, session.Life.DEAD) != session.Life.DEAD

## Alive and outside every refuge and lift lobby: fair game.
## Riding a lift is out of reach as well: the doors are shut.
func survivor_active(body: Node3D) -> bool:
	return session.participants.get(body.slot, session.Life.DEAD) != session.Life.DEAD and not point_protected(body.global_position) and not lifts.riding.has(int(body.slot)) and not untouchable.has(int(body.slot))

## Back to a clean picture: leaving for the menu, or starting a floor. The
## filter's material outlives the floor, so a signal that was lost when the
## hotel was freed would still be lost over the title room.
func clear_screen_cues() -> void:
	lost_signal = 0.0
	static_level = 0.0
	enclosure = 0.0
	if is_instance_valid(static_sound) and static_sound.playing: static_sound.stop()
	if is_instance_valid(camcorder): camcorder.signal_lost = false
	if post_material != null:
		post_material.set_shader_parameter("signal_loss", 0.0)
		post_material.set_shader_parameter("tape_hit", 0.0)
		post_material.set_shader_parameter("tape_band", -1.0)
		post_material.set_shader_parameter("tape_fray", 0.0)
		post_material.set_shader_parameter("lens_blood", 0.0)
		post_material.set_shader_parameter("rewinding", 0.0)
		post_material.set_shader_parameter("enclosure", 0.0)

## The creature searches a wardrobe: the host throws it open and, if
## somebody is inside, that is where the execution starts.
func open_wardrobe(hide: Node3D) -> void:
	if net.is_client(): return
	match_net.begin_wardrobe_job(hide)

## The creature throws both doors of a wardrobe open at once, searching it
## or done waiting beside it (hotel_locust.pounce): on the host, and
## everybody sees it.
func burst_wardrobe(hide: Node3D) -> void:
	if net.is_client() or not is_instance_valid(hide): return
	hide.force_open(0.1)
	if match_net.in_match(): match_net.hide_forced.rpc(hotel.hides.find(hide))

## Rooms the creature is never sent to: every refuge, and the lift lobby each
## one leads to.
## The list is the palette's (off_limits_rooms()), in the order it was.
func off_limits_rooms() -> Array:
	return FLOOR.palette(manifest).off_limits_rooms(manifest)

## Where nobody can be touched, for the whole floor: those same rooms -- every
## refuge, the exit and the lobby of every lift -- wall to wall. Nothing in
## them is seen, heard or struck. The protection used to be the refuge of the
## stage in hand only, and 0.55 m short of its walls: whoever waited in a
## crossed refuge or a lobby for the car to come back was fair game, and
## somebody pressed into a corner of the exit was heard, seen and killed from
## outside. The footprint of a room runs to the middle of its walls, so a body
## on the other side of one is never inside it.
func point_protected(point: Vector3) -> bool:
	if manifest.is_empty(): return false
	# Asked for every survivor several times a frame: the rooms are kept for
	# as long as the floor is the same one.
	if not is_same(protected_for, manifest):
		protected_for = manifest
		protected_rooms = {}
		for id in off_limits_rooms(): protected_rooms[int(id)] = true
	var room: Dictionary = FLOOR.room_at(manifest.rooms, point)
	return not room.is_empty() and protected_rooms.has(int(room.id))
var protected_for = null
var protected_rooms := {}

## The refuge of the stage in hand: the room holding the door on. The creature
## will not walk into it (it walks through a crossed one to reach its lift),
## and it is where the stage is won; who is safe is point_protected().
func refuge_room() -> int:
	var refuges: Array = manifest.get("refuges", [])
	if refuges.is_empty(): return int(manifest.exit)
	return int(refuges[clampi(session.stage - 1, 0, refuges.size() - 1)])

func point_in_refuge(point: Vector3) -> bool:
	if manifest.is_empty(): return false
	var room: Dictionary = manifest.rooms[refuge_room()]
	var center := FLOOR.position_of(room)
	var span := FLOOR.size_of(room)
	# Standing in it, on its own planta: the refuge of the floor above or below
	# is the same square in plan.
	var rise := point.y - center.y
	return absf(point.x - center.x) < span.x * 0.5 - 0.55 and absf(point.z - center.z) < span.y * 0.5 - 0.55 and rise >= -0.1 and rise < 2.0

## The floor's creature under its old name.
func spawn_locust() -> void: spawn_creature()

func spawn_creature() -> void:
	locust = (load(kind.CREATURE) as PackedScene).instantiate()
	locust.level = self
	locust.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Where it starts the first stage (start_room(), The Locust's den_room()):
	# well into the first planta, away from the door everyone comes in by and
	# from the refuge. It goes back there if that stage is given back
	# (den_point()).
	var chosen: int = locust.start_room(1)
	if chosen < 0: chosen = int(manifest.get("start", 0))
	locust.position = FLOOR.position_of(manifest.rooms[chosen]) + Vector3(0, 0.04, 0)
	locust.place_at(chosen)
	arm_creature()
	locust.grace = float(tuning().grace)
	add_child(locust)
	if not player.noise.is_connected(on_noise): player.noise.connect(on_noise)
	for door in hotel.doors: door.noise.connect(on_noise)
	# Architecture regression tests opt out explicitly; normal/headless games keep AI.
	if OS.get_cmdline_user_args().has("--no-enemy"):
		locust.set_physics_process(false)
		locust.collision_layer = 0
		locust.collision_mask = 0

func on_peek(point: Vector3) -> void:
	world_audio.play_at(world_audio.choose("open_slow"), point, -25.0, RID(), 0.4)
	# Online the host hears every wardrobe itself (it mirrors everyone's peeking).
	if not net.is_client(): locust_hear(point, NOISE.radius("peek"), NOISE.Kind.PEEK)

func on_hide_changed(entering: bool, point: Vector3, quiet := false) -> void:
	# Climbing in or out of a wardrobe is not silent; out the slow way, less.
	on_noise(point, NOISE.radius("wardrobe_slow" if quiet and not entering else "wardrobe"), NOISE.Kind.WARDROBE)
	if entering: note_hide()

## Kind defaults to a footstep so older callers (and the tests) still work.
func on_noise(point: Vector3, radius: float, kind := NOISE.Kind.FOOTSTEP) -> void:
	if observer_view != null: observer_view.gizmos.note_noise(point, radius)
	match_net.noise(point, radius, kind)

## A player back in a running floor: what it rebuilt knows nothing of what
## happened meanwhile (match_net.catch_up). Its card named sector 1, its
## drawers were full again -- and the host would not let them be searched a
## second time, so those digits were lost to it -- and its keypad was locked.
func catch_up_progress(progress: Dictionary) -> void:
	if progress.is_empty(): return
	for entry in progress.get("searched", []):
		if entry is Array: apply_search(int(entry[0]), true, true, int(entry[1]))
		else: apply_search(int(entry), true, true)
	if bool(progress.get("code", false)) and not code_entered:
		code_entered = true
		if is_instance_valid(lock): lock.set_open(true)
	for index in progress.get("panels", []): code.apply_panel(int(index), "open", true)
	# The offices' handlers: the card, the board, the air, as the host has them.
	var kept: Dictionary = progress.get("objectives", {})
	for objective_name in kept:
		if objectives.has(String(objective_name)): objectives[String(objective_name)].restore(kept[objective_name])
	var away: Dictionary = progress.get("lift_away", {})
	for index in away: lifts.lift_away[int(index)] = float(away[index])
	var stage := int(progress.get("stage", session.stage))
	if stage != session.stage:
		session.stage = stage
		if not automation and not match_net.local_is_locust():
			ui.show_transit(kind.title_of(stage), lifts.stage_errand(stage), lifts.OPENING_CARD)
		lifts.pending_brief = stage

func _physics_process(delta: float) -> void:
	# Watching a recording: what moves is what was recorded (bot_replay.gd).
	if replaying: return
	# Watching: the floor runs itself (online it is the host's, alone it is the
	# creature's own), and this machine only counts the lifts and looks.
	if observer:
		# Bots playing under the observer: nobody to knock for, and their
		# floor needs what a player's would (the refuge and minds).
		if not bot_match and not is_instance_valid(bot_watch): observer_seek(delta)
		lifts.ride_along(delta)
		lifts.ride_out(delta)
		lifts.update_cars(delta)
		if is_instance_valid(session) and session.state == session.State.PLAYING:
			lifts.count_away(delta)
			if rule("plan") == 1: floor_map.tick(delta)
			if bot_match:
				track_refuges()
				sanity.tick(delta)
				ledger.tick(delta)
			if not net.active(): host_gate(delta)
		return
	if is_instance_valid(session) and session.state == session.State.CUTSCENE:
		skip_time = skip_time + delta if Input.is_action_pressed("interact") else 0.0
		# Touched once: the words that say it has to be held, again, and the
		# ring beside them filling while it is.
		if Input.is_action_just_pressed("interact"): ui.show_skip(settings.prompt_name("interact"))
		if skip_time > 0.0: ui.hold_skip(skip_time / SKIP_HOLD)
		if skip_time >= SKIP_HOLD: finish_intro()
		return
	# The ride is counted before the rest: closing a stage puts the session
	# into its transition for a moment, and everything below stops there -- a
	# lift that stopped counting would hold somebody in the dark for good.
	# But not under the pause (offline, where this node still runs): the ride
	# went on without anybody, moving the body and ending the floor behind it.
	if is_instance_valid(session) and session.state == session.State.PAUSED: return
	lifts.ride_along(delta)
	lifts.ride_out(delta)
	lifts.update_cars(delta)
	if not is_instance_valid(session) or session.state != session.State.PLAYING: return
	lifts.count_away(delta)
	if rule("plan") == 1: floor_map.tick(delta)
	# The notice of the sector waits for the card to be gone and for the lift
	# to have opened its doors: it is what the picture comes back to.
	lifts.announce_sector(delta)
	drive_local(delta)
	sanity.tick(delta)
	# Whoever is in charge counts the hold at the exit once a frame, whatever
	# its own player happens to be doing. It used to be called from inside the
	# branches below, and the one for a dead player had no call: with the host
	# dead, its guests could hold at the refuge for ever and never leave.
	if not net.is_client():
		host_gate(delta)
		ledger.tick(delta)

## Who of the survivors is in the refuge of the stage in hand, for the
## session (the machine in charge).
func track_refuges() -> void:
	if net.is_client(): return
	for body in survivors(): session.set_refuge(body.slot, point_in_refuge(body.global_position))

## One handler for each objective the floor's kind can ask for, in the order
## it lists them; built before anything of the floor is settled.
func build_objectives() -> void:
	objectives.clear()
	for objective_name in kind.OBJECTIVES:
		var handler = load(kind.OBJECTIVES[objective_name]).new()
		handler.setup(self)
		objectives[objective_name] = handler

## What each objective fixes of the manifest before the hotel is built, by
## name (the sets it keeps: tv_sets).
func settle_objectives(survivors: int) -> Dictionary:
	var settled := {}
	for objective_name in objectives:
		var handler_script = load(kind.OBJECTIVES[objective_name])
		settled[objective_name] = handler_script.settle(manifest, survivors, kind)
	return settled

## The handler of that objective on this floor, or null.
func objective(id: StringName):
	return objectives.get(String(id))

## Whether a point is in a crawl space of this floor (the offices' main duct).
func crawling_at(point: Vector3) -> bool:
	var air = objectives.get("air")
	return air != null and air.crawling_at(point)

## Whether the car of a lift may leave with these riders: every handler of
## its stage agrees (the hotel's always do).
func ride_allowed(index: int, riders: Array) -> bool:
	for handler in stage_objectives(index + 1):
		if not handler.allows_ride(index + 1, riders): return false
	return true

## What this machine's player keeps on the sheet: the hints of the code,
## and every handler's papers (the offices' receipt and card).
func own_papers() -> Array:
	var papers: Array = code.own_hints().duplicate()
	for handler in objectives.values(): papers.append_array(handler.own_papers(player.slot))
	return papers

## The state of the handlers that carry it in the floor's snapshot, by name.
func objective_snapshots() -> Dictionary:
	var kept := {}
	for objective_name in objectives:
		if objectives[objective_name].snapshotted(): kept[objective_name] = objectives[objective_name].snapshot()
	return kept

## The host: a survivor fell where it stood; every handler hears of it (the
## offices' cards drop with their holder).
func objectives_on_death(seat: int, point: Vector3) -> void:
	for handler in objectives.values(): handler.on_death(seat, point)

## The handlers a stage asks, in the order it lists them (kind.STAGES).
func stage_objectives(stage := -1) -> Array:
	var number: int = session.stage if stage < 0 else stage
	var result: Array = []
	if number < 1 or number > kind.count(): return result
	for objective_name in kind.stage(number).objectives:
		if objectives.has(objective_name): result.append(objectives[objective_name])
	return result

## Where what the stage in hand still asks stands, objective by objective in
## its order: the director's goals and ambushes.
func goal_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for handler in stage_objectives(): points.append_array(handler.goal_points(session.stage))
	return points

func host_gate(delta: float) -> void:
	for seat in untouchable.keys():
		untouchable[seat] = float(untouchable[seat]) - delta
		if untouchable[seat] <= 0.0: untouchable.erase(seat)
	# Every objective of the floor, every frame, whatever the stage: the
	# creature's hop between lit sets runs on any of them, and what an
	# objective writes of its own into the goal is there before it is read.
	for objective_name in objectives: objectives[objective_name].tick(delta)
	# What the stage asks, in its order. One that does not apply neither holds
	# the door nor names the goal; the last that does names it (the code, on
	# top of the sets), and a stage with none that applies is met in its refuge.
	var met := true
	var naming := {}
	for handler in stage_objectives():
		var progress: Dictionary = handler.progress(session.stage)
		if String(progress.kind).is_empty(): continue
		met = met and bool(progress.ready)
		for key in progress.extra: session.goal[key] = progress.extra[key]
		naming = progress
	if naming.is_empty(): session.update_goal(delta, session.can_depart())
	else:
		session.goal["kind"] = String(naming.kind)
		session.goal["done"] = int(naming.done)
		session.goal["needed"] = int(naming.needed)
		session.update_goal(delta, met)
	lifts.ride_lifts()

func _process(delta: float) -> void:
	update_menu_scene(delta)
	# The hotel's clocks keep the camcorder's time, and go back with its tape.
	if is_instance_valid(hotel) and is_instance_valid(camcorder): hotel.tell_time(int(camcorder.start_seconds) + int(tape_seconds()))
	if session.state == session.State.PLAYING:
		update_execution(delta)
		keep_clock += delta
		if keep_clock >= KEEP_EVERY: keep_floor()
	# Paused, it waits where it was. Anything else -- the stage closing under
	# it, the floor ending -- lets the victim go: wiping it without that left
	# them held in the air for good, neither dead nor able to move.
	elif not execution.is_empty() and session.state != session.State.PAUSED: release_execution()
	# A victim held up can be carried across a wall plane, and the walls are
	# occluders: no occlusion culling while an execution lasts.
	# Watching, walls must not hide what is behind them either.
	var cull: bool = not observer and execution.is_empty() and rig.occlusion and ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling", false)
	if get_viewport().use_occlusion_culling != cull: get_viewport().use_occlusion_culling = cull
	# The camera stage runs on the game's clock (what Movie Maker records).
	if is_instance_valid(camera_effect):
		camera_effect.frame_delta = delta
		blur_effect.frame_delta = delta
	update_fields(delta)
	camcorder.visible = session.state == session.State.PLAYING and not observer
	# The creature records nothing: its seat keeps only the meter and notices.
	camcorder.hunter = hunter_seat()
	if not camcorder.hunter: camcorder.announce("")
	camcorder.marks = settings.values.osd
	update_zoom_lens()
	camcorder.set_zoom(player.zoom_fraction(), delta)
	camcorder.covered = ui.sheet.visible
	if camcorder.visible: camcorder.show_tape(tape_seconds(), delta)
	update_rewind(delta)
	# The lamp on the camcorder's front is the dot beside REC: on while the
	# tape of this machine's own survivor runs, steady with reduced effects.
	player.set_pilot(camcorder.lamp_lit() or settings.values.reduced, camcorder.visible and not camcorder.hunter and not camcorder.signal_lost and local_alive() and player.camera.current)
	if not is_instance_valid(hotel) or manifest.is_empty(): return
	update_screen_cues(delta)
	# The bed recedes as the dread aura rises, leaving room for it; the theme
	# goes with what frightens (theme_mood), and comes back only once it has
	# been quiet for a while.
	var dread: float = world_audio.aura.intensity if world_audio.aura != null else 0.0
	ambience.volume_db = -17.0 - dread * 9.0 + world_audio.duck_db()
	# The music is on the hotel's power: it goes with the lights, at once, and
	# comes back with them in the next wing, more gently.
	var powered: bool = not (is_instance_valid(hotel) and hotel.dark)
	music_power = move_toward(music_power, 1.0 if powered else 0.0, delta / (MUSIC_RETURN if powered else MUSIC_CUT))
	theme.volume_db = -24.0 + linear_to_db(maxf(world_audio.mood.gain() * music_power, 0.0001)) + world_audio.duck_db()
	if settings.values.subtitles and session.state == session.State.PLAYING and not world_audio.caption_text.is_empty():
		ui.subtitle.text = world_audio.caption_text
	visibility_clock += delta
	# The floor's round, four times a second, in its parts on the frames one
	# after the other (hotel_geometry.update_part): the first starts it, the
	# rest follow while round_part says what is left.
	var due := visibility_clock > 0.25
	if due or round_part > 0:
		if due:
			visibility_clock = 0
			round_part = 0
		# Rooms are drawn round whoever is looking, and watching, that is the
		# observer's camera and not the body it does not have; from above it
		# asks for the whole floor at once.
		if is_instance_valid(hotel):
			# Watching, nothing is hidden: the whole floor is drawn wherever the
			# camera is, which is the point of looking at it from outside.
			var eye: Vector3 = observer_view.global_position if observer and observer_view != null else world_audio.listener_position()
			# One planta at a time: the watcher's, or the one the eye is on.
			var shown: int = observer_view.planta if observer and observer_view != null else -1
			# Walking about, one reflection probe a round at most: each is its
			# room drawn six times over.
			hotel.probes_at_once = 1
			hotel.update_part(round_part, eye, settings.values.shadows and not rig.echo_seat() and not observer, 0.0, observer, shown)
			hotel.probes_at_once = 0
		round_part = (round_part + 1) % hotel.ROUND_PARTS if is_instance_valid(hotel) else 0
	if due:
		ventilation.position = Vector3(round(player.position.x / 12) * 12, FLOOR.planta_y(FLOOR.planta_of(player.position.y)) + 2.8, round(player.position.z / 12) * 12)

func _unhandled_input(event: InputEvent) -> void:
	# Watching: the keys belong to the observer's own camera and panels.
	if observer: return
	if event is InputEventMouseButton and event.pressed and not local_alive() and session.state == session.State.PLAYING and not online_menu:
		match_net.next_watch()
		return
	if event is InputEventJoypadButton and event.pressed:
		pad_pressed(int((event as InputEventJoypadButton).button_index))
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if lock_open:
		if event.physical_keycode == KEY_ESCAPE: close_lock()
		elif event.physical_keycode == KEY_BACKSPACE: type_code("borrar")
		elif event.physical_keycode >= KEY_0 and event.physical_keycode <= KEY_9: type_code(str(event.physical_keycode - KEY_0))
		elif event.physical_keycode >= KEY_KP_0 and event.physical_keycode <= KEY_KP_9: type_code(str(event.physical_keycode - KEY_KP_0))
		return
	if event.physical_keycode == KEY_ESCAPE and ui.sheet.visible:
		toggle_sheet()
		return
	if event.physical_keycode == KEY_ESCAPE and match_net.in_match() and session.state == session.State.PLAYING and not ui.settings_open:
		if online_menu: close_online_menu()
		else: open_online_menu()
		return
	if event.physical_keycode == KEY_ESCAPE and net.active() and session.state == session.State.MENU and ui.screen in ["lobby", "join"] and not ui.settings_open:
		on_action("lobby_leave")
		return
	if event.physical_keycode == KEY_ESCAPE: step_back()
	if event.physical_keycode == KEY_F9 and OS.is_debug_build() and not net.is_client(): session.capture(player.slot)
	if event.physical_keycode == KEY_F11:
		# Online nobody pauses the floor for everyone: the online menu opens
		# over it instead. Between stages, at the end of a match, in the
		# opening scene or while loading there is no menu to return to (from
		# the opening scene, "back" went to the main menu with the scene still
		# running, and its end started a floor behind it), so F11 waits.
		if match_net.in_match():
			if session.state != session.State.PLAYING: return
			if not online_menu: open_online_menu()
			settings.set_value("window_mode", settings.WINDOWED if settings.fullscreen else settings.FULLSCREEN)
			ui.show_settings("online_pause")
			return
		if session.state not in [session.State.PLAYING, session.State.PAUSED, session.State.MENU]: return
		session.pause()
		settings.set_value("window_mode", settings.WINDOWED if settings.fullscreen else settings.FULLSCREEN)
		ui.show_settings("pause" if session.state == session.State.PAUSED else "main")

func _notification(what: int) -> void:
	# Not the observer's floor: the tool is looked at beside something else, and
	# going to that paused the floor and put the pause menu over it, out of reach
	# of its keys (it stops time with P).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(session) and not automation and not observer and not match_net.in_match(): session.pause()
	# The window shut on a floor being played: kept as it stands.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_instance_valid(session) and is_instance_valid(net): keep_floor()

func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The camera's compositor effects free their GPU resources while the
	# RenderingDevice still exists (left to themselves they outlive it on quit).
	if has_node("Presentation/WorldEnvironment"): $Presentation/WorldEnvironment.compositor = null
	if is_instance_valid(lens_material): lens_material.set_shader_parameter("gain_map", null)
	for effect in [blur_effect, camera_effect]:
		if is_instance_valid(effect): effect.release()

const LOOK := preload("res://game/presentation/camcorder_look.gd")
const WARMUP := preload("res://game/presentation/shader_warmup.gd")

# Quiet music behind the menus (the title room is its own scene).

# --- Televisions (televisions.gd) ---------------------------------------------
## Kept here so that what reaches them through the level (the network, the
## bots, the tests, the other services) keeps working unchanged.
var televisions:
	get: return tvs.televisions
	set(value): tvs.televisions = value
var tv_sets:
	get: return tvs.tv_sets
	set(value): tvs.tv_sets = value
func place_televisions() -> void: tvs.place_televisions()
func stage_televisions(stage := -1) -> Array: return tvs.stage_televisions(stage)
func switch_television(set: Node3D, seat := -1) -> void: tvs.switch_television(set, seat)
const TV_BURST := TELEVISIONS.TV_BURST
func apply_television(index: int, value: bool, quiet := false) -> void: tvs.apply_television(index, value, quiet)
const WARP_REACH := TELEVISIONS.WARP_REACH
func lit_televisions() -> Array: return tvs.lit_televisions()
func creature_at_television(reach := WARP_REACH) -> int: return tvs.creature_at_television(reach)
func television_exit(index: int) -> Vector3: return tvs.television_exit(index)
func warp_creature(index: int) -> void: tvs.warp_creature(index)
func televisions_on() -> int: return tvs.televisions_on()
var hop_rest:
	get: return tvs.hop_rest
	set(value): tvs.hop_rest = value
var hop_wait:
	get: return tvs.hop_wait
	set(value): tvs.hop_wait = value
const HOP_PATIENCE := TELEVISIONS.HOP_PATIENCE
func creature_channel_hop(delta: float) -> void: tvs.creature_channel_hop(delta)

# --- CodeLock (code_lock.gd) --------------------------------------------------
## Kept here so that what reaches them through the level (the network, the
## bots, the tests, the other services) keeps working unchanged.
var containers:
	get: return code.containers
	set(value): code.containers = value
var found_digits:
	get: return code.found_digits
	set(value): code.found_digits = value
var found_by:
	get: return code.found_by
	set(value): code.found_by = value
var found_where:
	get: return code.found_where
	set(value): code.found_where = value
var code_entered:
	get: return code.code_entered
	set(value): code.code_entered = value
var lock:
	get: return code.lock
	set(value): code.lock = value
var lock_open:
	get: return code.lock_open
	set(value): code.lock_open = value
var typed:
	get: return code.typed
	set(value): code.typed = value
func place_containers() -> void: code.place_containers()
func search_container(piece: Node3D) -> void: code.search_container(piece)
func apply_search(index: int, value: bool, quiet := false, seat := -1) -> void: code.apply_search(index, value, quiet, seat)
func notes_found() -> Array: return code.notes_found()
func noted_code() -> String: return code.noted_code()
func code_so_far(own := false) -> String: return code.code_so_far(own)
var lock_digit:
	get: return code.lock_digit
	set(value): code.lock_digit = value
func type_code(character: String) -> void: code.type_code(character)
func code_verdict(text: String) -> String: return code.code_verdict(text)
func open_lock() -> void: code.open_lock()
func close_lock() -> void: code.close_lock()
func apply_code() -> void: code.apply_code()

# --- Executions (executions.gd) -----------------------------------------------
## Kept here so that what reaches them through the level (the network, the
## bots, the tests, the other services) keeps working unchanged.
var execution:
	get: return executions.execution
	set(value): executions.execution = value
const SCREAM := EXECUTIONS.SCREAM
const KILL_BLOW := EXECUTIONS.KILL_BLOW
const DEAD_CHANNEL := EXECUTIONS.DEAD_CHANNEL
const ARM_TIME := EXECUTIONS.ARM_TIME
const KILL_TIME := EXECUTIONS.KILL_TIME
const SIGNAL_TIME := EXECUTIONS.SIGNAL_TIME
const DROP_TIME := EXECUTIONS.DROP_TIME
const ARM_SWING := EXECUTIONS.ARM_SWING
func capture_survivor(body: Node3D) -> void: executions.capture_survivor(body)
func apply_execution(seat: int, point: Vector3, yaw: float, data := {}) -> void: executions.apply_execution(seat, point, yaw, data)
func update_execution(delta: float) -> void: executions.update_execution(delta)
func release_execution() -> void: executions.release_execution()
func hold_victim(delta: float) -> void: executions.hold_victim(delta)
func victim_hold_point() -> Vector3: return executions.victim_hold_point()

# --- Revival (revival.gd) -----------------------------------------------------
## Kept here so that what reaches them through the level (the network, the
## bots, the tests, the other services) keeps working unchanged.
var watch_rig:
	get: return revival.watch_rig
	set(value): revival.watch_rig = value
var watch_camera:
	get: return revival.watch_camera
	set(value): revival.watch_camera = value
func on_revived(restart: bool) -> void: revival.on_revived(restart)
func return_place(remembered: Vector3) -> Vector3: return revival.return_place(remembered)
func revival_point() -> Vector3: return revival.revival_point()
func apply_revival(places: Dictionary, restart: bool, creature_at := Vector3.INF) -> void: revival.apply_revival(places, restart, creature_at)
func stop_watching() -> void: revival.stop_watching()
func watch_teammates() -> void: revival.watch_teammates()
var watched_body:
	get: return revival.watched_body
	set(value): revival.watched_body = value

# --- Interaction (interaction.gd) ---------------------------------------------
## Kept here so that what reaches them through the level (the network, the
## bots, the tests, the other services) keeps working unchanged.
var pressed_door:
	get: return interaction.pressed_door
	set(value): interaction.pressed_door = value
var press_time:
	get: return interaction.press_time
	set(value): interaction.press_time = value
var was_held:
	get: return interaction.was_held
	set(value): interaction.was_held = value
var reading_document:
	get: return interaction.reading_document
	set(value): interaction.reading_document = value
## A document or a hint up in front of the camera.
func reading_paper() -> bool: return interaction.reading()
func toggle_sheet() -> void: interaction.toggle_sheet()
func place_documents() -> void: interaction.place_documents()
func open_document(document: Node3D) -> void: interaction.open_document(document)
func close_document() -> void: interaction.close_document()
func focused_area(): return interaction.focused_area()
func focused_hide(): return interaction.focused_hide()
func focused_document(): return interaction.focused_document()
func focused_door(): return interaction.focused_door()
func door_behind(): return interaction.door_behind()
func drive_local(delta: float) -> void: interaction.drive_local(delta)

# --- PresentationRig (presentation_rig.gd) ------------------------------------
## Kept here so that what reaches them through the level (the network, the
## bots, the tests, the other services) keeps working unchanged.
var ambient_energy:
	get: return rig.ambient_energy
	set(value): rig.ambient_energy = value
var blur_effect:
	get: return rig.blur_effect
	set(value): rig.blur_effect = value
var lens_material:
	get: return rig.lens_material
	set(value): rig.lens_material = value
var lens_layer:
	get: return rig.lens_layer
	set(value): rig.lens_layer = value
var camera_effect:
	get: return rig.camera_effect
	set(value): rig.camera_effect = value
func build_environment() -> void: rig.build_environment()
func camera_cut() -> void: rig.camera_cut()
func update_fields(delta: float) -> void: rig.update_fields(delta)
func apply_lens(hunter: bool, reduced: bool) -> void: rig.apply_lens(hunter, reduced)
func update_zoom_lens() -> void: rig.update_zoom_lens()
func hunter_seat() -> bool: return rig.hunter_seat()
const PRESETS := PRESENTATION_RIG.PRESETS
func apply_settings() -> void: rig.apply_settings()
func configure_hotel() -> void: rig.configure_hotel()
var enclosure:
	get: return rig.enclosure
	set(value): rig.enclosure = value
var lost_signal:
	get: return rig.lost_signal
	set(value): rig.lost_signal = value
var static_level:
	get: return rig.static_level
	set(value): rig.static_level = value
func update_screen_cues(delta: float) -> void: rig.update_screen_cues(delta)
func update_ride_hiss(amount: float) -> void: rig.update_ride_hiss(amount)
func build_audio() -> void: rig.build_audio()
var music_power:
	get: return rig.music_power
	set(value): rig.music_power = value
const MUSIC_CUT := PRESENTATION_RIG.MUSIC_CUT
const MUSIC_RETURN := PRESENTATION_RIG.MUSIC_RETURN
func update_menu_scene(_delta: float) -> void: rig.update_menu_scene(_delta)
