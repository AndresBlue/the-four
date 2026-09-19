extends Node3D
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const HIDE := preload("res://game/world/interactables/hiding_place.gd")
const LOCUST := preload("res://game/enemies/locust/locust.tscn")
var world_audio
var locust
const GENERATOR := preload("res://game/world/generation/map_generator.gd")
const VALIDATOR := preload("res://game/world/generation/map_validator.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const DOOR := preload("res://game/world/interactables/hotel_door.gd")
const INTRO := preload("res://game/intro/intro_sequence.gd")
const TITLE := preload("res://game/title/title_scene.gd")
const DOCUMENT := preload("res://game/world/interactables/hotel_document.gd")
const PLACEMENT := preload("res://game/world/generation/document_placement.gd")
const CATALOG := preload("res://game/discovery/discovery_catalog.gd")
const DIRECTOR := preload("res://game/director/pacing_director.gd")
const DISCOVERIES := preload("res://game/services/discovery_service.gd")
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
## Local preview of the hunter's seat (--locust): this machine drives The
## Locust against an idle survivor, with no connection. Everything the hunter
## sees and hears runs in one process, so the acoustic view can be looked at
## and tuned without gathering five players.
var solo_locust := false
var visibility_clock := 0.0
var pressed_door
var press_time := 0.0
var was_held := false
var slow_used := false
var save_error := ""
var physical_errors: Array[String] = []
var intro: Node3D
var title_scene: Node3D
var director
var discoveries
## The document being read, if any.
var reading_document: Node3D
var paper_sound: AudioStreamPlayer
var intro_seed := 0
var skip_time := 0.0
## Online play (net_session.gd) and its in-match replication (match_net.gd).
var net
var match_net
## The local player is holding interact inside the refuge (online, the host
## counts everyone holding).
var exit_held := false
## Online, Esc opens a menu over the running match instead of pausing it.
var online_menu := false
## A kill in progress: {seat, time, point, yaw, stabs, dropped}. The floor only
## registers the death when the last blow lands.
var execution := {}
## The view of a dead player, over the shoulder of the teammate watched.
var watch_rig: Node3D
var watch_arm: SpringArm3D
var watch_camera: Camera3D
const STABS := ["res://assets/audio/events/execution_stab_1.wav", "res://assets/audio/events/execution_stab_2.wav", "res://assets/audio/events/execution_stab_3.wav"]
const BODY_DROP := "res://assets/audio/events/execution_drop.wav"
## When each blow of an execution lands, and when the body is let go.
const STAB_TIMES := [1.0, 1.6, 2.2]
const DROP_TIME := 2.7

func _enter_tree() -> void:
	world_audio = $WorldAudio
	world_audio.level = self
	settings = $Services/Settings
	session = $Services/GameSession
	player = $Player
	ui = $Interface
	var test_name := "default"
	for argument in OS.get_cmdline_args():
		if argument.ends_with(".gd"): test_name = argument.get_file().get_basename()
	if OS.get_cmdline_user_args().has("--test-profile"):
		settings.save_path = "user://test_hotel_%s_settings.json" % test_name
		session.checkpoint_path = "user://test_hotel_%s_checkpoint.json" % test_name
	discoveries = DISCOVERIES.new()
	discoveries.name = "Discoveries"
	if OS.get_cmdline_user_args().has("--test-profile"): discoveries.save_path = "user://test_hotel_%s_discoveries.json" % test_name
	$Services.add_child(discoveries)
	player.settings = settings
	ui.settings = settings
	ui.discoveries = discoveries
	net = NET.new()
	net.level = self
	match_net = net.match_net
	match_net.level = self
	if OS.get_cmdline_user_args().has("--test-profile"): match_net.checkpoint_path = "user://test_coop_%s_checkpoint.json" % test_name
	$Services.add_child(net)
	ui.net = net

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	automation = DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--automation")
	world_audio.enabled = not automation and not OS.get_cmdline_user_args().has("--silent")
	ui.sounds_enabled = world_audio.enabled
	player.hiding_changed.connect(world_audio.hide_cue)
	player.hiding_changed.connect(on_hide_changed)
	ui.action_requested.connect(on_action)
	ui.sheet.chunk_drawn.connect(func(op_id, kind, points): match_net.sheet_local(op_id, kind, points))
	session.changed.connect(on_state)
	net.closed.connect(on_net_closed)
	net.lobby_changed.connect(func(): if ui.screen in ["lobby", "join"] and session.state == session.State.MENU: ui.menu("lobby" if net.local_seat != 0 else "join"))
	net.joined.connect(func(): if session.state == session.State.MENU: ui.menu("lobby"))
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
	if not automation: ui.play_intro()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--playtest-seed="):
			var value := argument.trim_prefix("--playtest-seed=")
			if value.is_valid_int() and int(value) >= 0 and int(value) <= 2147483647:
				if OS.get_cmdline_user_args().has("--locust"): await take_locust(int(value))
				else: start_floor(int(value))

## The local hunter preview: build a floor and hand the creature to this player.
func take_locust(seed_value: int) -> void:
	solo_locust = true
	await start_floor(seed_value)
	if not is_instance_valid(locust): return
	locust.set_control("player")
	locust.grace = 0.0
	player.camera.current = false
	locust.camera.current = true
	# It never hears its own presence, online or here.
	world_audio.set_creature(null)
	apply_settings()
	ui.flash("VISION ACUSTICA - PRUEBA LOCAL", 4.0)

func on_action(action: String) -> void:
	match action:
		"new": start_intro(randi_range(0, 2147483647))
		"continue":
			var data: Dictionary = session.checkpoint()
			if not data.is_empty(): start_floor(int(data.seed), data.get("fallback", false) == true)
			else: ui.menu("main", false, session.message)
		"retry": start_floor(session.run_seed, session.map_fallback)
		"resume": session.set_state(session.State.PLAYING)
		"pause": session.set_state(session.State.PAUSED)
		"main": session.set_state(session.State.MENU)
		"settings": ui.show_settings("pause" if session.state == session.State.PAUSED else "main")
		"credits": ui.menu("credits")
		"characters": ui.show_characters()
		"multiplayer": ui.menu("multiplayer")
		"host":
			if net.host(settings.values.player_name, settings.values.character) == OK: ui.menu("lobby")
			else: ui.menu("multiplayer", false, net.status)
		"join": ui.menu("join")
		"connect":
			if net.join(settings.values.join_address, settings.values.player_name, settings.values.character) != OK: ui.menu("join", false, net.status)
			else: ui.menu("join")
		"lobby_start":
			if not net.start_match(): ui.menu("lobby", false, net.start_problem())
		"lobby_leave":
			net.shutdown("")
			ui.menu("multiplayer")
		"online_resume": close_online_menu()
		"online_settings": ui.show_settings("online_pause")
		"online_pause": ui.menu("online_pause")
		"lobby": ui.menu("lobby")
		"lobby_character": ui.show_characters("lobby")
		"online_retry": net.start_match(int(match_net.config.get("seed", -1)))
		"online_new": net.start_match()
		"online_room": net.return_to_lobby()
		"online_quit":
			net.shutdown("")
			leave_online_floor()
		"archive": ui.menu("archive")
		"quit": get_tree().quit()

## A new game opens with the bedroom scene; its floor is built when it ends.
func start_intro(seed_value: int) -> void:
	if session.state in [session.State.LOADING, session.State.CUTSCENE]: return
	intro_seed = seed_value
	skip_time = 0.0
	intro = INTRO.new()
	intro.name = "Intro"
	intro.position = INTRO_ORIGIN
	add_child(intro)
	intro.finished.connect(finish_intro, CONNECT_ONE_SHOT)
	if is_instance_valid(hotel): hotel.visible = false
	player.visible = false
	# Only the television lights the room: no hotel ambient light.
	environment.ambient_light_energy = 0.0
	session.set_state(session.State.CUTSCENE)
	ui.show_skip(settings.key_name("interact"))
	camera_cut()

func finish_intro() -> void:
	if not is_instance_valid(intro): return
	intro.queue_free()
	intro = null
	ui.hide_skip()
	environment.ambient_light_energy = ambient_energy
	player.visible = true
	player.camera.current = true
	start_floor(intro_seed)

func start_floor(seed_value: int, force_fallback := false) -> void:
	if not await build_floor(seed_value, force_fallback): return
	camcorder.start_tape(seed_value)
	# A new tape starts with the lens wide.
	player.zoom = 1.0
	player.zoom_wanted = 1.0
	session.online = false
	session.start(seed_value, manifest.get("fallback", false))
	save_error = session.message
	ui.sheet.clear()
	populate_floor(true)

## Generates, builds and validates a floor. False (back in the menu) when it
## could not be made playable.
func build_floor(seed_value: int, force_fallback := false) -> bool:
	if session.state == session.State.LOADING: return false
	session.set_state(session.State.LOADING)
	await get_tree().process_frame
	await get_tree().process_frame
	world_audio.reset()
	player.reset_survival()
	if is_instance_valid(locust):
		remove_child(locust)
		locust.queue_free()
	if is_instance_valid(hotel):
		remove_child(hotel)
		hotel.queue_free()
	manifest = GENERATOR.new().generate(seed_value)
	if force_fallback:
		manifest = GENERATOR.new().candidate(404, 0, true)
		manifest["fallback"] = true
		manifest["requested_seed"] = seed_value
	hotel = GEOMETRY.new()
	hotel.name = "GeneratedHotel"
	hotel.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hotel)
	hotel.build(manifest)
	configure_hotel()
	player.spawn = Vector3(0, 0.04, 0)
	player.position = player.spawn
	player.velocity = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	player.handheld = Vector3.ZERO
	player.torch.visible = false
	player.rotation.y = -PI / 2 if manifest.adjacency[0].has(1) else PI
	visibility_clock = 1
	# Physics validation ignores closed door leaves (layer 8), which are openable.
	get_tree().paused = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	physical_errors = VALIDATOR.new().validate_physics(get_world_3d(), manifest)
	if not physical_errors.is_empty():
		push_warning("Physical map rejection: %s" % physical_errors)
		remove_child(hotel)
		hotel.queue_free()
		manifest = GENERATOR.new().candidate(404, 0, true)
		manifest["fallback"] = true
		manifest["requested_seed"] = seed_value
		hotel = GEOMETRY.new()
		hotel.name = "GeneratedHotel"
		hotel.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(hotel)
		hotel.build(manifest)
		configure_hotel()
		await get_tree().physics_frame
		await get_tree().physics_frame
		physical_errors = VALIDATOR.new().validate_physics(get_world_3d(), manifest)
		if not physical_errors.is_empty():
			save_error = "El mapa de respaldo no superó la validación física. No se inició la partida."
			session.set_state(session.State.MENU)
			return false
	# Wait for the new static floor's navigation to be queryable before playing.
	var exit_room: Dictionary = manifest.rooms[manifest.exit]
	var exit_position := FLOOR.position_of(exit_room)
	var navigation_ready := false
	for frame in 12:
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
	place_documents()
	director = null
	if with_director:
		director = DIRECTOR.new()
		director.name = "Director"
		director.setup(self, int(manifest.seed))
		hotel.add_child(director)
	world_audio.set_creature(locust.sound_profile)
	for door in hotel.doors: door.sound_requested.connect(world_audio.door_cue)
	# Easing wardrobe doors creaks: a quiet noise the creature can pick up.
	for hide in hotel.hides: hide.peek_started.connect(on_peek)
	if not automation and not OS.get_cmdline_user_args().has("--silent"):
		ambience.play()
		theme.play()
		ventilation.play()

# --- Online floors ---------------------------------------------------------------

## The host started a floor: build it, then tell the host we are ready.
func start_online_floor(config: Dictionary) -> void:
	if is_instance_valid(intro):
		intro.queue_free()
		intro = null
	close_online_menu()
	if is_instance_valid(reading_document): close_document()
	if session.state == session.State.LOADING:
		await session.changed
	if not await build_floor(int(config.seed)):
		net.shutdown("No se pudo construir el piso de la partida.")
		return
	ui.menu("loading", false, "Esperando a los demás jugadores…")
	player.visible = true
	player.collision_layer = 4
	player.camera.current = true
	player.slot = net.local_seat
	player.spawn = match_net.spawn_point(net.local_seat)
	player.position = player.spawn
	match_net.floor_built()

## Everyone has the floor: the session, the creature and who controls it.
func begin_online_play(config: Dictionary) -> void:
	camcorder.start_tape(int(config.seed))
	session.online = true
	session.start(int(config.seed), manifest.get("fallback", false), config.survivors)
	save_error = ""
	ui.sheet.clear()
	ui.sheet.seat = net.local_seat
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
		locust.camera.current = true
		# The hunter does not hear its own presence or dread.
		world_audio.set_creature(null)
		ui.flash("ERES THE LOCUST", 4.0)
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
	apply_settings()
	session.set_state(session.State.MENU)

func on_net_closed(reason: String) -> void:
	if match_net.in_match() or session.state != session.State.MENU:
		match_net.end()
		leave_online_floor()
	ui.menu("multiplayer", false, reason)

func open_online_menu() -> void:
	online_menu = true
	player.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.menu("online_pause")

func close_online_menu() -> void:
	if not online_menu: return
	online_menu = false
	ui.overlay.hide()
	ui.settings_open = false
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
		if kind == NOISE.Kind.WARDROBE: radius = maxf(radius, HUNTER_WARDROBE_RADIUS)
		var route: Dictionary = locust.hear_route(point, radius)
		if route.audible: match_net.tell_hunter(point, route, radius, kind)

## The survivor the director measures distances from: this player while alive,
## otherwise any living survivor.
func pacing_anchor() -> Vector3:
	for body in survivors():
		if survivor_active(body): return body.global_position
	return player.global_position

func sheet_snapshot() -> Array:
	return ui.sheet.snapshot()

func restore_sheet(ops: Array) -> void:
	ui.sheet.restore(ops)

## Tab opens and closes the sheet. Dead players may look but not draw; The
## Locust never sees it.
func toggle_sheet() -> void:
	if ui.sheet.visible:
		ui.sheet.close()
		player.reading = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if match_net.local_is_locust() or is_instance_valid(reading_document): return
	ui.sheet.seat = player.slot
	ui.sheet.open(local_alive(), settings.key_name("sheet"))
	player.reading = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if world_audio.enabled: paper_sound.play()

## This floor's documents, lying on furniture (freed with the hotel).
func place_documents() -> void:
	for spot in PLACEMENT.choose(manifest, "locust"):
		var document := DOCUMENT.new()
		document.name = "Document_" + spot.entry
		document.entry_id = spot.entry
		document.position = spot.position
		document.rotation.y = spot.yaw
		hotel.add_child(document)

func open_document(document: Node3D) -> void:
	reading_document = document
	player.reading = true
	ui.show_document(CATALOG.entry(document.entry_id))
	if world_audio.enabled: paper_sound.play()
	if discoveries.record(document.entry_id):
		ui.flash("ARCHIVADO  %d/%d" % [discoveries.found.size(), CATALOG.TOTAL], 3.0)

func close_document() -> void:
	reading_document = null
	player.reading = false
	ui.hide_document()

func on_state() -> void:
	var playing: bool = session.state == session.State.PLAYING
	if session.state in [session.State.MENU, session.State.FAILED, session.State.WON]: world_audio.reset()
	player.active = playing and not online_menu and local_alive() and not match_net.local_is_locust()
	if not playing: player.velocity = Vector3.ZERO
	if not playing and ui.sheet.visible:
		ui.sheet.close()
		player.reading = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing and not online_menu and not ui.sheet.visible else Input.MOUSE_MODE_VISIBLE
	get_tree().paused = session.state in [session.State.MENU, session.State.PAUSED, session.State.WON, session.State.FAILED] and not match_net.in_match()
	press_time = 0
	pressed_door = null
	was_held = Input.is_action_pressed("interact")
	if not playing and is_instance_valid(reading_document): close_document()
	# The aiming dot only while playing: not over the title room or the opening scene.
	ui.get_node("HUD/Crosshair").visible = playing
	update_title_scene()
	if playing and online_menu: return
	if playing or session.state == session.State.CUTSCENE:
		ui.overlay.hide()
		ui.settings_open = false
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
		session.State.PAUSED: ui.menu("pause")
		session.State.LOADING: ui.menu("loading")
		session.State.TRANSITION: ui.menu("transition")
		session.State.WON:
			ui.elapsed = session.elapsed
			if match_net.in_match():
				if net.is_host: match_net.clear_checkpoint()
				ui.menu("online_won")
			else: ui.menu("won")
		session.State.FAILED:
			ui.elapsed = session.elapsed
			ui.menu("online_failed" if match_net.in_match() else "failed")

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
		environment.ambient_light_energy = 0.0 if hunter_seat() else ambient_energy
		if is_instance_valid(hotel): hotel.visible = true
		player.visible = not hunter_seat()
		player.camera.current = not hunter_seat()
		if hunter_seat() and is_instance_valid(locust) and is_instance_valid(locust.camera): locust.camera.current = true

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

## Alive and outside the refuge: fair game.
func survivor_active(body: Node3D) -> bool:
	return session.participants.get(body.slot, session.Life.DEAD) != session.Life.DEAD and not point_in_refuge(body.global_position)

## The creature reached this survivor: the execution starts and the death is
## registered when it ends (host, or offline).
func capture_survivor(body: Node3D) -> void:
	if body == null or net.is_client() or not execution.is_empty() or not is_instance_valid(locust): return
	if session.participants.get(body.slot, session.Life.DEAD) != session.Life.EXPLORING: return
	if match_net.in_match(): match_net.free_victim_hide(body.slot)
	var point: Vector3 = locust.global_position
	var yaw: float = locust.rotation.y
	apply_execution(body.slot, point, yaw)
	if match_net.in_match(): match_net.execute_start.rpc(body.slot, point, yaw)

## Everyone plays out the execution: the creature holds its victim up and
## stabs three times. The victim's own machine takes over its body.
func apply_execution(seat: int, point: Vector3, yaw: float) -> void:
	execution = {"seat": seat, "time": 0.0, "point": point, "yaw": yaw, "stabs": 0, "dropped": false}
	if is_instance_valid(locust) and locust.control != "puppet": locust.begin_execution()
	if seat == player.slot:
		player.active = false
		player.held = true
		player.velocity = Vector3.ZERO
		if player.hidden: player.force_leave_hide()
		if ui.sheet.visible: toggle_sheet()

## Sounds, screen jolts and, on the host, the death at the end.
func update_execution(delta: float) -> void:
	if execution.is_empty(): return
	execution.time += delta
	var point: Vector3 = locust.global_position if is_instance_valid(locust) else execution.point
	var held := point + Vector3(0, 1.7, 0)
	while int(execution.stabs) < STAB_TIMES.size() and execution.time >= STAB_TIMES[int(execution.stabs)]:
		if world_audio.enabled: world_audio.play_at(STABS[int(execution.stabs)], held, -2.0, RID(), 0.0)
		glitch = 1.0
		execution.stabs = int(execution.stabs) + 1
	if not execution.dropped and execution.time >= DROP_TIME:
		execution.dropped = true
		if world_audio.enabled: world_audio.play_at(BODY_DROP, point + Vector3(0, 0.3, 0), -6.0, RID(), 0.0)
	if execution.time >= locust.EXECUTION_TIME + 0.3:
		var seat := int(execution.seat)
		execution = {}
		player.held = false
		if player.avatar != null:
			player.avatar.rotation.x = 0.0
			player.avatar.rotation.z = 0.0
		if not net.is_client(): session.capture(seat)

## The victim: held in the air in front of the creature, looking at it.
func hold_victim(delta: float) -> void:
	var point: Vector3 = locust.global_position if is_instance_valid(locust) else execution.point
	var yaw: float = locust.rotation.y if is_instance_valid(locust) else execution.yaw
	var forward := -Basis(Vector3.UP, yaw).z
	var time: float = execution.time
	var lift := clampf(time / 0.5, 0.0, 1.0) - clampf((time - DROP_TIME) / 0.4, 0.0, 1.0)
	# Held on the blade at the creature's chest height, close in front of it.
	var wanted := point + forward * 1.05 + Vector3(0, 0.1 + lift * 1.0, 0)
	player.velocity = Vector3.ZERO
	player.global_position = player.global_position.lerp(wanted, minf(1.0, delta * 10.0))
	# Run through on the blade: the body hangs back and sags.
	if player.avatar != null:
		player.avatar.rotation.x = -0.5 * lift
		player.avatar.rotation.z = 0.12 * lift
	# It is the last thing you see.
	var head := point + Vector3(0, 2.3, 0)
	var offset: Vector3 = head - player.camera.global_position
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-offset.x, -offset.z), minf(1.0, delta * 8.0))
	player.camera.rotation.x = lerpf(player.camera.rotation.x, atan2(offset.y, Vector2(offset.x, offset.z).length()), minf(1.0, delta * 8.0))
	camcorder.focus("")
	ui.hint.text = ""
	ui.progress.visible = false

## The creature searches a wardrobe: the host opens it leaf by leaf and, if
## somebody is inside, that is where the execution starts.
func open_wardrobe(hide: Node3D) -> void:
	if net.is_client(): return
	match_net.begin_wardrobe_job(hide)

func point_in_refuge(point: Vector3) -> bool:
	if manifest.is_empty(): return false
	var room: Dictionary = manifest.rooms[manifest.exit]
	var center := FLOOR.position_of(room)
	var span := FLOOR.size_of(room)
	return absf(point.x - center.x) < span.x * 0.5 - 0.55 and absf(point.z - center.z) < span.y * 0.5 - 0.55 and point.y >= -0.1 and point.y < 2.0

func spawn_locust() -> void:
	locust = LOCUST.instantiate()
	locust.level = self
	locust.process_mode = Node.PROCESS_MODE_PAUSABLE
	var distances := GENERATOR.distance_map(manifest.adjacency, 0)
	var chosen := 0
	var target := int(distances.max() * 0.55)
	for room in manifest.rooms:
		if room.id != manifest.exit and distances[room.id] >= target and distances[room.id] > 3:
			chosen = room.id
			break
	locust.position = FLOOR.position_of(manifest.rooms[chosen]) + Vector3(0, 0.04, 0)
	locust.patrol_room = chosen
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

func on_hide_changed(entering: bool, point: Vector3) -> void:
	# Climbing in or out of a wardrobe is not silent.
	on_noise(point, NOISE.radius("wardrobe"), NOISE.Kind.WARDROBE)

## Kind defaults to a footstep so older callers (and the tests) still work.
func on_noise(point: Vector3, radius: float, kind := NOISE.Kind.FOOTSTEP) -> void:
	match_net.noise(point, radius, kind)

func focused_area():
	var from: Vector3 = player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * 2.0, 1 | 8 | 16)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() else null

func focused_hide():
	var area = focused_area()
	return area if area is HIDE else null

func focused_document():
	var area = focused_area()
	return area if area is DOCUMENT else null

## Online: the name of the teammate straight ahead, within a few metres.
func focused_teammate() -> String:
	if match_net.bodies.is_empty(): return ""
	var from: Vector3 = player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * 8.0, 1 | 4 | 8)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not "player_name" in hit.collider: return ""
	return hit.collider.player_name.to_upper()

## Doors are reached from further away than wardrobes.
const DOOR_REACH := 3.2
## An open door this close can be shut without looking at it, so it can be
## pulled closed behind you while running away.
const DOOR_BEHIND_REACH := 3.0

func focused_door():
	var from: Vector3 = player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * DOOR_REACH, 1 | 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() and hit.collider is DOOR else null

## Nearest open door within reach, for closing it without looking at it.
func door_behind():
	var best = null
	var best_distance := DOOR_BEHIND_REACH
	for door in hotel.doors:
		if not door.opened or door.moving: continue
		var distance := Vector2(door.doorway.x - player.global_position.x, door.doorway.z - player.global_position.z).length()
		if distance < best_distance:
			best = door
			best_distance = distance
	return best

func _physics_process(delta: float) -> void:
	if is_instance_valid(session) and session.state == session.State.CUTSCENE:
		skip_time = skip_time + delta if Input.is_action_pressed("interact") else 0.0
		if skip_time >= SKIP_HOLD: finish_intro()
		return
	if not is_instance_valid(session) or session.state != session.State.PLAYING: return
	var inside := in_refuge()
	if not net.is_client():
		for body in survivors(): session.set_refuge(body.slot, point_in_refuge(body.global_position))
	if not execution.is_empty() and int(execution.seat) == player.slot:
		hold_victim(delta)
		return
	if Input.is_action_just_pressed("sheet") and not online_menu: toggle_sheet()
	if ui.sheet.visible:
		# Looking at the sheet: the character stands still, the world goes on.
		exit_held = false
		camcorder.focus("")
		if net.is_host or not match_net.in_match(): host_exit(delta)
		if not local_alive(): watch_teammates()
		return
	if not local_alive():
		watch_teammates()
		return
	if online_menu or match_net.local_is_locust():
		exit_held = false
		if net.is_host: host_exit(delta)
		return
	camcorder.set_stamina(player.stamina / 100.0, player.exhausted)
	var floor_room := FLOOR.room_at(manifest.rooms, player.global_position)
	player.hard_floor = not floor_room.is_empty() and int(floor_room.type) in FLOOR.HARD_FLOORS
	if is_instance_valid(reading_document):
		camcorder.focus("")
		if Input.is_action_just_pressed("interact"): close_document()
		was_held = true
		return
	var document_target = focused_document()
	if Input.is_action_just_pressed("interact") and not player.hidden and is_instance_valid(document_target):
		open_document(document_target)
		was_held = true
		return
	var hiding_target = focused_hide()
	if Input.is_action_just_pressed("interact") and (player.hidden or is_instance_valid(hiding_target)):
		if player.hidden: match_net.use_hide(player.hiding_place, false)
		else:
			if is_instance_valid(locust) and locust.control == "ai" and locust.sees(player, true): locust.observed_hide = hiding_target
			match_net.use_hide(hiding_target, true)
		pressed_door = null
		was_held = true
	var key: String = settings.key_name("interact")
	if player.hidden:
		camcorder.focus("SALIR")
		ui.hint.text = ""
		ui.subtitle.text = ""
		ui.progress.visible = false
		return
	var target = focused_door()
	if not is_instance_valid(target) and not is_instance_valid(hiding_target): target = door_behind()
	var held := Input.is_action_pressed("interact")
	# Camcorder-style focus brackets replace the old control prompts.
	camcorder.focus("LEER" if is_instance_valid(document_target) else "ESCONDERSE" if is_instance_valid(hiding_target) else ("CERRAR" if target.opened else "ABRIR") if is_instance_valid(target) else focused_teammate())
	if held and not was_held:
		pressed_door = target
		press_time = 0
		slow_used = false
	if held and is_instance_valid(pressed_door) and target == pressed_door:
		press_time += delta
		if press_time >= 1 and not slow_used:
			match_net.use_door(pressed_door, true, false)
			slow_used = true
	elif held:
		pressed_door = null
		press_time = 0
	if was_held and not held:
		if is_instance_valid(pressed_door) and target == pressed_door and not slow_used:
			# Running into a door pushes it open (or shut) with a slam.
			var running := Vector2(player.velocity.x, player.velocity.z).length() > 4.6
			if not match_net.use_door(pressed_door, false, running): ui.flash("DEJA LIBRE EL UMBRAL")
		pressed_door = null
	was_held = held
	# Deliberate hold inside the refuge; door operations never also start departure.
	exit_held = held and inside and not is_instance_valid(target) and not is_instance_valid(pressed_door)
	if not net.is_client(): host_exit(delta)
	ui.progress.visible = session.exit_progress > 0
	ui.progress.value = session.exit_progress
	ui.hint.text = "REFUGIO · MANTÉN [%s] PARA SALIR DEL PISO" % key if inside else ""
	ui.subtitle.text = ""
	if settings.values.subtitles and session.elapsed > 5 and session.elapsed < 10:
		ui.subtitle.text = "[Ventilación constante]"
	if not save_error.is_empty(): ui.subtitle.text = save_error

## Leaving the floor: offline the local hold; online anyone in the refuge
## holding counts (the session still needs every survivor inside).
func host_exit(delta: float) -> void:
	var holding := exit_held
	for body in match_net.bodies.values():
		if is_instance_valid(body) and body.holding_exit and point_in_refuge(body.global_position): holding = true
	session.hold_exit(delta, holding)

## Dead online: the view follows a living teammate; a click switches to the next.
func watch_teammates() -> void:
	exit_held = false
	player.active = false
	player.visible = false
	player.collision_layer = 0
	var body: Node3D = match_net.watched_body()
	ui.progress.visible = session.exit_progress > 0
	ui.progress.value = session.exit_progress
	camcorder.focus("")
	if body == null:
		ui.hint.text = "HAS MUERTO"
		return
	watch_over(body)
	ui.hint.text = "HAS MUERTO · OBSERVANDO A %s · CLIC PARA CAMBIAR" % body.player_name.to_upper()

## Third person behind the teammate being watched: the arm keeps the camera
## out of walls and wardrobes, so nothing is seen through them.
func watch_over(body: Node3D) -> void:
	if not is_instance_valid(watch_rig):
		watch_rig = Node3D.new()
		watch_rig.name = "WatchRig"
		add_child(watch_rig)
		watch_arm = SpringArm3D.new()
		watch_arm.spring_length = 2.6
		watch_arm.collision_mask = 1 | 8
		watch_arm.margin = 0.25
		var ball := SphereShape3D.new()
		ball.radius = 0.25
		watch_arm.shape = ball
		watch_rig.add_child(watch_arm)
		watch_camera = Camera3D.new()
		watch_camera.name = "WatchCamera"
		watch_camera.fov = LOOK.fov_for(get_viewport(), 76.0)
		watch_camera.far = 95.0
		watch_camera.cull_mask = 1048573
		watch_arm.add_child(watch_camera)
	watch_rig.global_position = body.global_position + Vector3(0, 1.5, 0)
	watch_rig.rotation.y = body.rotation.y
	watch_arm.rotation.x = clampf(body.pitch, -0.6, 0.5)
	if not watch_camera.current: watch_camera.current = true

func _process(delta: float) -> void:
	update_menu_scene(delta)
	if session.state == session.State.PLAYING: update_execution(delta)
	elif not execution.is_empty(): execution = {}
	# A victim held up can be carried across a wall plane, and the walls are
	# occluders: no occlusion culling while an execution lasts.
	var cull: bool = execution.is_empty() and ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling", false)
	if get_viewport().use_occlusion_culling != cull: get_viewport().use_occlusion_culling = cull
	# The camera stage runs on the game's clock (what Movie Maker records).
	if is_instance_valid(camera_effect):
		camera_effect.frame_delta = delta
		blur_effect.frame_delta = delta
	update_fields(delta)
	camcorder.visible = session.state == session.State.PLAYING
	# The creature records nothing: its seat keeps only the meter and notices.
	camcorder.hunter = hunter_seat()
	if not camcorder.hunter: camcorder.announce("")
	camcorder.marks = settings.values.osd
	update_zoom_lens()
	camcorder.set_zoom(player.zoom_fraction(), delta)
	if camcorder.visible: camcorder.show_tape(session.elapsed, delta)
	if not is_instance_valid(hotel) or manifest.is_empty(): return
	update_screen_cues(delta)
	var warning_active: bool = is_instance_valid(locust) and locust.mode == locust.Mode.WINDUP
	# The bed and music recede as the dread aura rises, leaving room for it.
	var dread: float = world_audio.aura.intensity if world_audio.aura != null else 0.0
	ambience.volume_db = (-25.0 if warning_active else -17.0) - dread * 9.0
	theme.volume_db = (-30.0 if warning_active else -24.0) - dread * 22.0
	if settings.values.subtitles and session.state == session.State.PLAYING and not world_audio.caption_text.is_empty() and not warning_active:
		ui.subtitle.text = world_audio.caption_text
	visibility_clock += delta
	if visibility_clock > 0.25:
		visibility_clock = 0
		if is_instance_valid(hotel): hotel.update_visibility(world_audio.listener_position(), settings.values.shadows and not hunter_seat())
		ventilation.position = Vector3(round(player.position.x / 12) * 12, 2.8, round(player.position.z / 12) * 12)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not local_alive() and session.state == session.State.PLAYING and not online_menu:
		match_net.next_watch()
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
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
	if event.physical_keycode == KEY_ESCAPE:
		if session.state == session.State.CUTSCENE: finish_intro()
		elif is_instance_valid(reading_document): close_document()
		elif ui.settings_open:
			if not settings.previous_display.is_empty(): settings.revert_display()
			on_action(ui.return_action)
		elif ui.screen == "join" and session.state == session.State.MENU: on_action("multiplayer")
		elif ui.screen == "characters" and session.state == session.State.MENU: on_action("lobby" if net.active() else "multiplayer")
		elif ui.screen in ["credits", "multiplayer"] and session.state == session.State.MENU: on_action("main")
		elif session.state == session.State.PAUSED: session.set_state(session.State.PLAYING)
		else: session.pause()
	if event.physical_keycode == KEY_F9 and OS.is_debug_build() and not net.is_client(): session.capture(player.slot)
	if event.physical_keycode == KEY_F11:
		session.pause()
		settings.set_value("fullscreen", not settings.values.fullscreen)
		ui.show_settings("pause" if session.state == session.State.PAUSED else "main")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(session) and not automation and not match_net.in_match(): session.pause()

func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The camera's compositor effects free their GPU resources while the
	# RenderingDevice still exists (left to themselves they outlive it on quit).
	if has_node("Presentation/WorldEnvironment"): $Presentation/WorldEnvironment.compositor = null
	if is_instance_valid(lens_material): lens_material.set_shader_parameter("gain_map", null)
	for effect in [blur_effect, camera_effect]:
		if is_instance_valid(effect): effect.release()

var ambient_energy := 0.16
const LOOK := preload("res://game/presentation/camcorder_look.gd")
const CAMERA_EFFECT := preload("res://game/presentation/camera/camcorder_effect.gd")
const BLUR_EFFECT := preload("res://game/presentation/camera/motion_blur_effect.gd")
## How deep the volumetric fog reaches when lamps light it.
const LIT_FOG_LENGTH := 14.0
var blur_effect: CompositorEffect
## The camcorder's lens and sensor layer (lens.gdshader), under the OSD.
var lens_material: ShaderMaterial
var lens_layer: CanvasLayer
## The camcorder's HDR stage (iris, video knee, CCD smear) as a compositor
## effect on the world environment, and the tonemapper it replaces.
var camera_effect: CompositorEffect
var authored_tone := {}
func build_environment() -> void:
	environment = $Presentation/WorldEnvironment.environment
	ambient_energy = environment.ambient_light_energy
	post_material = $Presentation/Analog/Screen.material
	lens_material = $Presentation/Lens/Screen.material
	lens_layer = $Presentation/Lens
	camcorder = $Presentation/Camcorder
	get_viewport().size_changed.connect(func(): apply_lens(hunter_seat(), settings.values.reduced))
	authored_tone = {"mode": environment.tonemap_mode, "exposure": environment.tonemap_exposure, "glow": environment.glow_hdr_threshold, "fog_length": environment.volumetric_fog_length}
	# Only where there is a RenderingDevice to run it (not headless, not
	# Compatibility): elsewhere the game keeps AgX.
	if RenderingServer.get_rendering_device() != null:
		camera_effect = CAMERA_EFFECT.new()
		# The light smears while it is being exposed: blur first, then the camera.
		blur_effect = BLUR_EFFECT.new()
		var compositor := Compositor.new()
		compositor.compositor_effects = [blur_effect, camera_effect]
		$Presentation/WorldEnvironment.compositor = compositor

## The camera's HDR stage on or off, with the tonemapper that goes with it.
func apply_camera(preset: Dictionary, hunter: bool) -> void:
	var on := is_instance_valid(camera_effect) and not hunter
	if is_instance_valid(camera_effect):
		camera_effect.enabled = on
		camera_effect.smear = preset.ccd_smear
		camera_effect.glare = preset.glare
		# Reduced effects: no smearing of the picture while turning.
		blur_effect.samples = 0 if settings.values.reduced else preset.motion_blur
		blur_effect.enabled = on and blur_effect.samples > 0
	# The camera's own video knee does the tonemapping; Godot's stays linear.
	# Its highlights end just under 1, so the bloom starts lower.
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR if on else authored_tone.mode
	environment.tonemap_exposure = 1.0 if on else authored_tone.exposure
	environment.glow_hdr_threshold = 0.9 if on else authored_tone.glow
	# The sensor's noise grows with the gain the iris had to add, which the
	# lens reads straight from the camera stage on the GPU.
	if is_instance_valid(lens_material): lens_material.set_shader_parameter("gain_map", camera_effect.exposure_texture if on else null)

## A cut (a new floor, the opening scene): the iris jumps to the new light
## instead of adjusting across it.
func camera_cut() -> void:
	if is_instance_valid(camera_effect): camera_effect.reset = true
	field_camera = null

## Interlaced fields (lens.gdshader, field_shift): how far the picture moved in
## the 1/60 s between a frame's two fields, from the camera's turn since the
## last frame. Only fast turns comb: under FIELD_FROM pixels (of a 1080-line
## picture) nothing shows, from FIELD_TO the full offset, never past
## FIELD_MAX. Reduced effects: none.
const FIELD_TIME := 1.0 / 60.0
const FIELD_FROM := 12.0
const FIELD_TO := 30.0
const FIELD_MAX := 48.0
var field_camera: Camera3D
var field_basis := Basis.IDENTITY
func update_fields(delta: float) -> void:
	if not is_instance_valid(lens_material): return
	var camera := get_viewport().get_camera_3d()
	var shift := Vector2.ZERO
	if camera != null and camera == field_camera and delta > 0.0 and not settings.values.reduced:
		# Last frame's view centre, seen from this frame's view.
		var before: Vector3 = camera.global_basis.orthonormalized().inverse() * -field_basis.z
		if before.z < -0.01:
			var projection := camera.get_camera_projection()
			var moved := Vector2(projection.x.x * before.x, -projection.y.y * before.y) / -before.z * 0.5 * FIELD_TIME / delta
			var size := get_viewport().get_visible_rect().size
			var pixels := Vector2(moved.x * size.x / maxf(size.y, 1.0), moved.y).length() * 1080.0
			shift = moved * smoothstep(FIELD_FROM, FIELD_TO, pixels) * minf(1.0, FIELD_MAX / maxf(pixels, 0.001))
	field_camera = camera
	if camera != null: field_basis = camera.global_basis.orthonormalized()
	lens_material.set_shader_parameter("field_shift", shift)

## The lens remaps a picture rendered wider than the view (camcorder_look.gd):
## the cameras that film the hotel render at the lens's field of view.
func apply_lens(hunter: bool, reduced: bool) -> void:
	if not is_instance_valid(lens_material): return
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	lens_layer.visible = not hunter
	update_zoom_lens()
	lens_material.set_shader_parameter("noise", 0.0 if reduced else settings.values.grain)
	lens_material.set_shader_parameter("chromatic", 0.0 if reduced else settings.values.chromatic)
	lens_material.set_shader_parameter("vignette", 0.0 if reduced else 0.45)
	lens_material.set_shader_parameter("detail", 0.0 if reduced else 0.35)
	if hunter:
		player.camera.fov = LOOK.VIEW_FOV
		if is_instance_valid(watch_camera): watch_camera.fov = LOOK.VIEW_FOV

## The lens as the zoom stands (hotel_player.zoom): the field of view it sees,
## how wide the picture is rendered and how much the barrel bends it. A long
## lens bends far less, so the remap follows the zoom (camcorder_look.gd).
func update_zoom_lens() -> void:
	if hunter_seat() or not is_instance_valid(player) or not is_instance_valid(lens_material): return
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var barrel: float = LOOK.barrel_for(player.zoom)
	var design: float = LOOK.zoom_fov(player.zoom)
	lens_material.set_shader_parameter("barrel", barrel)
	lens_material.set_shader_parameter("scale", LOOK.corner_scale(aspect, barrel))
	var fov: float = LOOK.render_fov(aspect, design, barrel)
	player.camera.fov = fov
	if is_instance_valid(watch_camera): watch_camera.fov = fov

## This machine drives The Locust: the hunter's seat online, or the local
## preview. Its screen is the acoustic image, not the lit hotel.
func hunter_seat() -> bool:
	return is_instance_valid(net) and match_net.local_is_locust()

## Every value that changes with the quality setting (graphics_presets.gd).
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
## The torch's source size as built (player.tscn), for presets without penumbra.
var torch_size := -1.0
func apply_settings() -> void:
	if not is_instance_valid(environment): return
	var preset: Dictionary = PRESETS.of(settings.values.quality)
	# Before any set is built (title, intro, floor): the size of the scans.
	GEOMETRY.small_maps = preset.small_maps
	# The acoustic view replaces the lit image entirely, so none of this would
	# ever be seen; switching it off is what pays for its own screen pass.
	var hunter := hunter_seat()
	environment.ssao_enabled = preset.ssao >= 0 and not hunter
	if preset.ssao >= 0: RenderingServer.environment_set_ssao_quality(preset.ssao, preset.ssao_half, ProjectSettings.get_setting("rendering/environment/ssao/adaptive_target"), ProjectSettings.get_setting("rendering/environment/ssao/blur_passes"), ProjectSettings.get_setting("rendering/environment/ssao/fadeout_from"), ProjectSettings.get_setting("rendering/environment/ssao/fadeout_to"))
	environment.ssil_enabled = preset.ssil >= 0 and not hunter
	if preset.ssil >= 0: RenderingServer.environment_set_ssil_quality(preset.ssil, preset.ssil_half, ProjectSettings.get_setting("rendering/environment/ssil/adaptive_target"), ProjectSettings.get_setting("rendering/environment/ssil/blur_passes"), ProjectSettings.get_setting("rendering/environment/ssil/fadeout_from"), ProjectSettings.get_setting("rendering/environment/ssil/fadeout_to"))
	environment.ssr_enabled = preset.ssr_steps > 0 and not hunter
	if preset.ssr_steps > 0:
		environment.ssr_max_steps = preset.ssr_steps
		RenderingServer.environment_set_ssr_roughness_quality(preset.ssr_roughness)
	# SDFGI leaks light through the 18 cm hotel walls; bounce light is screen-space only.
	environment.sdfgi_enabled = false
	environment.glow_enabled = preset.glow and not hunter
	RenderingServer.environment_glow_set_use_bicubic_upscale(preset.glow_bicubic)
	RenderingServer.gi_set_use_half_resolution(preset.bounce_half)
	# Ambient light reaches every surface whether or not a lamp does, so for the
	# creature it has to go too: anything still lit leaks the seen hotel into a
	# reading that is supposed to be made of echoes.
	environment.ambient_light_energy = 0.0 if hunter else ambient_energy
	environment.fog_enabled = not hunter
	environment.volumetric_fog_enabled = preset.fog_size > 0 and not settings.values.reduced and not hunter
	# Lamps that light the fog (preset lamp_fog) need short cells, or a room's
	# glow would spread into the next one through the wall (docs/REALISM.md,
	# trial 7).
	environment.volumetric_fog_length = LIT_FOG_LENGTH if preset.lamp_fog else authored_tone.fog_length
	if preset.fog_size > 0:
		RenderingServer.environment_set_volumetric_fog_volume_size(preset.fog_size, preset.fog_depth)
		RenderingServer.environment_set_volumetric_fog_filter_active(preset.fog_filter)
	var viewport := get_viewport()
	# Every lamp shares one shadow atlas. At 4096 the rooms further off got
	# cells so coarse that shadows came out as saw-teeth along door frames and
	# a lamp's shadow bias grew past a 7 cm leaf: light through shut doors.
	# No preset goes under 4096.
	viewport.positional_shadow_atlas_size = preset.shadow_atlas
	# Soft shadow filtering is paid per pixel for every shadowed lamp on it.
	RenderingServer.positional_soft_shadow_filter_set_quality(preset.shadow_filter)
	viewport.msaa_3d = preset.msaa
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if preset.fxaa and not hunter else Viewport.SCREEN_SPACE_AA_DISABLED
	# Temporal accumulation has nothing to work with here: the echo field writes
	# POSITION itself (no motion vectors) and the point cloud is restamped
	# fifteen times a second, so TAA smears it into paste.
	viewport.use_taa = preset.taa and not hunter
	viewport.mesh_lod_threshold = preset.lod_threshold
	viewport.anisotropic_filtering_level = preset.anisotropy
	viewport.use_debanding = preset.debanding
	RenderingServer.screen_space_roughness_limiter_set_active(preset.roughness_limiter, ProjectSettings.get_setting("rendering/anti_aliasing/screen_space_roughness_limiter/amount"), ProjectSettings.get_setting("rendering/anti_aliasing/screen_space_roughness_limiter/limit"))
	# Octaves of every procedural surface (surface.gdshaderinc) and the tape
	# filter's chroma reads.
	RenderingServer.global_shader_parameter_set("surface_detail", preset.surface_detail)
	post_material.set_shader_parameter("chroma_taps", preset.chroma_taps)
	var reduced: bool = settings.values.reduced
	# The camcorder's lens and sensor (lens.gdshader) take the grain, the colour
	# fringes and the vignette; the tape filter keeps the tape. The creature's
	# acoustic view has no lens: it keeps the tape filter's own versions.
	for key in ["vhs", "scanlines"]: post_material.set_shader_parameter(key, 0.0 if reduced else settings.values[key])
	post_material.set_shader_parameter("grain", 0.0 if reduced or not hunter else settings.values.grain)
	post_material.set_shader_parameter("chromatic", 0.0 if reduced or not hunter else settings.values.chromatic * 0.5)
	post_material.set_shader_parameter("vignette", 0.0 if reduced or not hunter else 0.45)
	apply_lens(hunter, reduced)
	apply_camera(preset, hunter)
	# The warm tape cast would break the monochrome reading.
	post_material.set_shader_parameter("tint", Vector3.ONE if hunter else Vector3(1.02, 1.0, 0.9))
	if settings.values.reduced:
		post_material.set_shader_parameter("enclosure", 0.0)
		post_material.set_shader_parameter("threat_glitch", 0.0)
	player.torch.shadow_enabled = settings.values.shadows
	if torch_size < 0.0: torch_size = player.torch.light_size
	player.torch.light_size = torch_size * minf(preset.penumbra, 1.0)
	player.set_character(settings.values.character)
	# Your own body, walking, re-renders the shadow of every lamp round it.
	player.avatar.set_body_shadow(preset.body_shadow)
	player.autofocus = preset.autofocus and not hunter
	configure_hotel()
	if is_instance_valid(locust) and locust.driver != null and is_instance_valid(locust.driver.echo): locust.driver.echo.apply_quality()

## The floor's share of the settings: preset, reduced effects, creature's view.
func configure_hotel() -> void:
	if not is_instance_valid(hotel): return
	hotel.reduced = settings.values.reduced
	hotel.echo_view = hunter_seat()
	hotel.apply_quality(PRESETS.of(settings.values.quality))

## Wardrobe enclosure and strike glitch on the analog filter (off when reduced).
var enclosure := 0.0
var glitch := 0.0
func update_screen_cues(delta: float) -> void:
	var wanted_enclosure: float = (1.0 - player.peek * 0.8) if player.hidden and session.state == session.State.PLAYING else 0.0
	enclosure = move_toward(enclosure, wanted_enclosure, delta * 2.0)
	var striking: bool = is_instance_valid(locust) and locust.mode == locust.Mode.WINDUP
	glitch = 1.0 if striking else move_toward(glitch, 0.0, delta * 4.0)
	if settings.values.reduced: return
	post_material.set_shader_parameter("enclosure", enclosure)
	post_material.set_shader_parameter("threat_glitch", glitch)

func build_audio() -> void:
	# Handling a document: a local sound, not a noise the creature can hear.
	paper_sound = AudioStreamPlayer.new()
	paper_sound.name = "Paper"
	paper_sound.bus = "Effects"
	paper_sound.volume_db = -8.0
	paper_sound.stream = load("res://assets/audio/sfx/paper/paper.ogg")
	add_child(paper_sound)
	ambience = AudioStreamPlayer.new()
	ambience.name = "AmbientLoop"
	ambience.process_mode = Node.PROCESS_MODE_PAUSABLE
	ambience.bus = "Ambience"
	ambience.volume_db = -17
	var ambient_stream := load("res://assets/audio/sfx/ambience/dark_hotel.wav").duplicate() as AudioStreamWAV
	ambient_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambient_stream.loop_begin = 0
	ambient_stream.loop_end = int(ambient_stream.get_length() * ambient_stream.mix_rate)
	ambience.stream = ambient_stream
	add_child(ambience)
	theme = AudioStreamPlayer.new()
	theme.name = "Music"
	theme.process_mode = Node.PROCESS_MODE_PAUSABLE
	theme.bus = "Music"
	theme.volume_db = -24
	theme.stream = load("res://assets/audio/the_four_theme.mp3").duplicate()
	theme.stream.loop = true
	add_child(theme)
	ventilation = AudioStreamPlayer3D.new()
	ventilation.name = "Ventilation"
	ventilation.process_mode = Node.PROCESS_MODE_PAUSABLE
	ventilation.bus = "Ambience"
	ventilation.volume_db = -19
	ventilation.max_distance = 16
	ventilation.area_mask = world_audio.ACOUSTIC_MASK
	ventilation.stream = preload("res://game/audio/world_audio.gd").loop_stream(load("res://assets/audio/hotel/ambience.wav"))
	add_child(ventilation)
	menu_music = AudioStreamPlayer.new()
	menu_music.name = "MenuMusic"
	menu_music.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_music.bus = "Music"
	menu_music.volume_db = -12
	menu_music.stream = load("res://assets/audio/the_four_theme.mp3").duplicate()
	menu_music.stream.loop = true
	add_child(menu_music)

# Quiet music behind the menus (the title room is its own scene).
func update_menu_scene(_delta: float) -> void:
	var in_menu: bool = session.state == session.State.MENU
	var audible: bool = in_menu and world_audio.enabled
	if audible and not menu_music.playing: menu_music.play()
	elif not audible and menu_music.playing: menu_music.stop()
