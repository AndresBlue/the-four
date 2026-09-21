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
const TELEVISION := preload("res://game/world/interactables/hotel_television.gd")
const TV_PLACEMENT := preload("res://game/world/generation/tv_placement.gd")
const CONTAINER := preload("res://game/world/interactables/hotel_container.gd")
const LOCK := preload("res://game/world/interactables/hotel_lock.gd")
const DIGITS := preload("res://game/world/generation/digit_placement.gd")
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
var scream_sound: AudioStreamPlayer
## Seconds spent going through the piece of furniture in front.
var search_time := 0.0
## The sets of the stage in hand, in build order: the index is their name on
## the wire, like doors and wardrobes.
var televisions: Array = []
## Everything with drawers or shelves, in build order, and the numbers found
## in them so far, by place in the code.
var containers: Array = []
var found_digits := {}
## And where each one was found, as it would be said out loud: the number on
## that door, or what the room is when it has no plaque (service rooms, halls
## and corridors carry none). A number without a place is a number nobody can
## check, and checking is what the others are for.
var found_where := {}
## Whether the code has been read into the lock: from then on the last door
## opens and the floor is left by stepping through it.
var code_entered := false
## The keypad of the last door, and what is being typed into it.
var lock: Node3D
var lock_open := false
var typed := ""
var blow_sound: AudioStreamPlayer
var static_sound: AudioStreamPlayer
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
## The local player is holding interact inside the refuge (online, the host
## counts everyone holding).
## Online, Esc opens a menu over the running match instead of pausing it.
var online_menu := false
## A kill in progress: {seat, time, point, yaw, stabs, dropped}. The floor only
## registers the death when the last blow lands.
var execution := {}
## The view of a dead player, over the shoulder of the teammate watched.
var watch_rig: Node3D
var watch_arm: SpringArm3D
var watch_camera: Camera3D
const SCREAM := "res://assets/audio/events/execution_scream.wav"
## A set coming on: the clunk of an old switch, reusing a door latch.
const SWITCH_SOUND := "res://assets/audio/sfx/door/closing/closing1.ogg"
## The power going: the same dead channel the execution uses, from above.
const BLACKOUT_SOUND := "res://assets/audio/events/execution_static.ogg"
## Going through a drawer: the slow creak of a door, which is what it is.
const SEARCH_SOUND := "res://assets/audio/sfx/door/opening/creaky-wooden-door-slow-opening.mp3"
const KILL_BLOW := "res://assets/audio/events/execution_hit.wav"
const DEAD_CHANNEL := "res://assets/audio/events/execution_static.ogg"
## The beats of an execution, in seconds from the grab. The scream is at zero,
## because that is the point of it; then it holds you and looks at you; then
## the arm comes for the lens, covers it and lands; and the picture goes.
const ARM_TIME := 2.58
const KILL_TIME := 2.8
const SIGNAL_TIME := 2.92
const DROP_TIME := 3.1
## How long the arm takes to go from a point to the whole screen.
const ARM_SWING := KILL_TIME - ARM_TIME
## How long the victim's own screen stays lost before it starts watching a
## teammate. Alone, or with everyone else dead, the failure screen takes over
## instead and this never runs out.
const LOST_HOLD := 2.6

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
	sanity = MIND.new()
	sanity.name = "Sanity"
	sanity.level = self
	$Services.add_child(sanity)
	lifts = LIFTS.new()
	lifts.name = "Lifts"
	lifts.level = self
	$Services.add_child(lifts)

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
	session.revived.connect(on_revived)
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
		"online_pause":
			refresh_briefing()
			ui.menu("online_pause")
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
	if match_net != null: match_net.floor_building()
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
	# Nothing of the last floor's lifts survives into this one: a ride still
	# counting would move the body to a room that no longer exists.
	lifts.boarding = {}
	lifts.leaving = -1.0
	lifts.riding.clear()
	lifts.lift_away.clear()
	lifts.cross_clock = 0.0
	player.sanity = 100.0
	player.set_burnt(false)
	sanity.minds.clear()
	sanity.sight_rest = 0.0
	player.camera.rotation = Vector3.ZERO
	player.reset_handheld()
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
	place_televisions()
	place_containers()
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
	# A floor opens on the same card as every sector after it, and the notice
	# of what this one wants follows once the card is gone.
	if not automation and not match_net.local_is_locust():
		ui.show_transit("SECTOR %d" % session.stage, lifts.stage_errand(session.stage), lifts.OPENING_CARD)
	lifts.pending_brief = session.stage
	lifts.brief_wait = lifts.OPENING_CARD if not automation else 0.0

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
	# Coming back into a floor that is already being played says so: the wait
	# is the same, what it means is not.
	ui.menu("loading", false, "Volviendo a la partida…" if match_net.rejoin_snapshot.get("returning", false) else "Esperando a los demás jugadores…")
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
	refresh_briefing()
	ui.menu("online_pause")

## What the pause screens show of the sector in hand. The hunter has no errand.
func refresh_briefing() -> void:
	if match_net.local_is_locust() or manifest.is_empty(): ui.set_briefing("", "", [])
	else: ui.set_briefing("SECTOR %d" % session.stage, lifts.stage_brief(session.stage), lifts.stage_progress())

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
	ui.sheet.open(local_alive(), settings.key_name("sheet"), notes_found())
	player.reading = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if world_audio.enabled: paper_sound.play()

## This floor's documents, lying on furniture (freed with the hotel).
## The sets of the second and third stages, each lot in the wing its stage
## opens. Everyone works out the same list from the seed and the number of
## survivors, so nothing has to be sent: only which ones are on travels. They
## go into one array, stage by stage, so an index means the same set on every
## machine; each one remembers which stage it belongs to.
func place_televisions() -> void:
	televisions.clear()
	if manifest.get("gates", []).is_empty(): return
	for stage in [2, 3]:
		for spot in TV_PLACEMENT.choose(manifest, session.roster_count, stage):
			var set := TELEVISION.new()
			set.name = "Television_%d" % televisions.size()
			set.stage = stage
			set.position = spot.position
			set.rotation.y = spot.yaw
			hotel.add_child(set)
			televisions.append(set)

## The sets a stage is played on, by index into `televisions`. A stage lights
## its own wing's sets and nobody else's: what was left on behind you neither
## counts for the wing you are in nor is anywhere the creature could step out.
func stage_televisions(stage := -1) -> Array:
	var wanted: int = session.stage if stage < 0 else stage
	var result: Array = []
	for index in televisions.size():
		if is_instance_valid(televisions[index]) and int(televisions[index].stage) == wanted: result.append(index)
	return result

## Switching one on: the host decides, and the noise is made once, there.
func switch_television(set: Node3D) -> void:
	if not is_instance_valid(set) or set.on: return
	match_net.use_television(set)

## Applied everywhere, whoever decided it.
func apply_television(index: int, value: bool) -> void:
	if index < 0 or index >= televisions.size(): return
	var set = televisions[index]
	if not is_instance_valid(set) or not set.set_on(value): return
	if value:
		if world_audio.enabled: world_audio.play_at(SWITCH_SOUND, set.global_position + Vector3(0, 1.4, 0), -8.0)
		if not net.is_client(): on_noise(set.global_position + Vector3(0, 1.4, 0), set.click_radius(), NOISE.Kind.DOOR)

## Travelling by television: a lit set is a way in and a way out. The creature
## steps out of another lit one, wherever it is, which is why lighting them is
## a risk and not only an errand.
const WARP_REACH := 3.4
const WARP_SOUND := "res://assets/audio/events/execution_static.ogg"

## The sets it could step out of, by index, from the one it is standing at:
## the ones of the stage in hand, so it never travels into a wing that is
## already behind everybody.
func lit_televisions() -> Array:
	var result: Array = []
	for index in stage_televisions():
		if televisions[index].on: result.append(index)
	return result

## The lit set the creature is standing at, or -1.
func creature_at_television() -> int:
	if not is_instance_valid(locust): return -1
	for index in stage_televisions():
		var set = televisions[index]
		if set.on and set.global_position.distance_to(locust.global_position) < WARP_REACH: return index
	return -1

## It comes out of the set at `index`, a step in front of it, looking into the
## room. Applied on every machine, whoever decided it.
func warp_creature(index: int) -> void:
	if index < 0 or index >= televisions.size() or not is_instance_valid(locust): return
	var set = televisions[index]
	if not is_instance_valid(set) or not set.on: return
	var facing := Vector3(sin(set.rotation.y), 0, cos(set.rotation.y))
	var from: Vector3 = locust.global_position
	locust.global_position = set.global_position + facing * 1.6 + Vector3(0, 0.04, 0)
	locust.rotation.y = set.rotation.y
	locust.velocity = Vector3.ZERO
	locust.speed = 0.0
	# A puppet interpolates between the states it is sent: without this it
	# would slide across the floor instead of stepping out of a screen.
	locust.net_states.clear()
	locust.net_clock = 0.0
	if is_instance_valid(locust.driver): locust.driver.channel_open = false
	if world_audio.enabled:
		world_audio.play_at(WARP_SOUND, from + Vector3(0, 1.4, 0), -6.0)
		world_audio.play_at(WARP_SOUND, locust.global_position + Vector3(0, 1.4, 0), -4.0)
	# Where it comes out is a noise of its own: the set it steps from spits.
	if not net.is_client(): on_noise(locust.global_position + Vector3(0, 1.4, 0), NOISE.radius("door"), NOISE.Kind.DOOR)

## How many of the stage's own sets are on. What burns in another wing is not
## counted: every stage from the second starts its tally at nothing.
func televisions_on() -> int:
	var count := 0
	for index in stage_televisions():
		if televisions[index].on: count += 1
	return count

## The drawers, shelves and cupboards of the floor, and the four numbers hidden
## in four of them, in the wing of the last stage. Everyone works out the same
## hiding places from the seed; only what has been gone through travels.
func place_containers() -> void:
	containers.clear()
	found_digits.clear()
	found_where.clear()
	code_entered = false
	typed = ""
	lock = null
	close_lock()
	if manifest.get("gates", []).is_empty(): return
	for spot in hotel.containers:
		var piece := CONTAINER.new()
		piece.name = "Container_%d" % containers.size()
		piece.kind = str(spot.kind)
		piece.position = spot.position
		piece.rotation.y = spot.yaw
		# Parented to its room, so it is culled with it, but placed by the
		# world point the dressing worked out.
		var room_node = hotel.room_nodes[int(spot.room)] if int(spot.room) < hotel.room_nodes.size() else hotel
		piece.position = spot.position - room_node.position
		room_node.add_child(piece)
		containers.append(piece)
	# The keypad, beside the last door, on the refuge's side of it.
	if not hotel.lifts.is_empty() and not manifest.gates.is_empty():
		var last: Dictionary = manifest.gates[manifest.gates.size() - 1]
		var out: Array = last.get("out", [1, 0])
		var away := Vector3(int(out[0]), 0, int(out[1]))
		# On the wall the door is in, which is the one the refuge shares with
		# the landing behind it.
		var door_point: Vector3 = FLOOR.portal_between(manifest.rooms[int(last.room)], manifest.rooms[int(last.beyond)])
		lock = LOCK.new()
		lock.name = "CodeLock"
		lock.position = door_point - away * 0.35 + Vector3(away.z, 0, -away.x) * 1.1
		lock.rotation.y = atan2(-away.x, -away.z)
		hotel.add_child(lock)
	for hidden in DIGITS.choose(manifest, hotel.containers):
		var index := int(hidden.container)
		if index < 0 or index >= containers.size(): continue
		containers[index].digit = int(hidden.digit)
		containers[index].slot = int(hidden.slot)
		# The four that hold something say so: a slip of paper left showing.
		containers[index].plant_note()
	camcorder.write_code("")

## Going through one: the host decides, as with everything else.
func search_container(piece: Node3D) -> void:
	if not is_instance_valid(piece) or piece.searched: return
	match_net.use_container(piece)

## Applied everywhere, whoever decided it.
func apply_search(index: int, value: bool) -> void:
	if index < 0 or index >= containers.size(): return
	var piece = containers[index]
	if not is_instance_valid(piece) or not piece.set_searched(value): return
	if not value: return
	if world_audio.enabled: world_audio.play_at(SEARCH_SOUND, piece.global_position + Vector3(0, 0.8, 0), -10.0)
	if not net.is_client(): on_noise(piece.global_position + Vector3(0, 0.8, 0), piece.noise_radius(), NOISE.Kind.DOOR)
	if piece.digit >= 0:
		found_digits[piece.slot] = piece.digit
		var room: Dictionary = FLOOR.room_at(manifest.rooms, piece.global_position)
		var number := int(room.get("number", 0))
		found_where[piece.slot] = ("HABITACIÓN %d" % number) if number > 0 else String(FLOOR.NAMES[int(room.get("type", 0))]).to_upper()
		# The paper leaves with whoever took it, and what it said stays written
		# on the tape until the floor is over.
		piece.take_note()
		if not match_net.local_is_locust():
			camcorder.write_code(noted_code())

## The stage's own sets, all of them on. A stage with no sets of its own asks
## for nothing here.
func sets_lit() -> bool:
	return stage_televisions().is_empty() or televisions_on() >= TV_PLACEMENT.needed(session.roster_count)

## The slips this player took, in the order the code reads: which place, the
## number on it, and the room it came out of. Only its own -- what the others
## found is theirs to say out loud, which is half of playing together.
func notes_found() -> Array:
	var slips: Array = []
	for slot in range(1, DIGITS.COUNT + 1):
		if not found_digits.has(slot): continue
		slips.append({"slot": slot, "digit": int(found_digits[slot]), "where": String(found_where.get(slot, ""))})
	return slips

## What is written down: nothing until the first number turns up, and from
## then on the code with a dash in the places still missing.
func noted_code() -> String: return "" if found_digits.is_empty() else code_so_far()

## The code as it is known so far, with a dash where a number is missing.
func code_so_far() -> String:
	var text := ""
	for slot in range(1, DIGITS.COUNT + 1): text += str(found_digits[slot]) if found_digits.has(slot) else "–"
	return text

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
	discoveries.record(document.entry_id)

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
	if session.state in [session.State.MENU, session.State.LOADING, session.State.CUTSCENE]: clear_screen_cues()
	if is_instance_valid(hotel) and not manifest.is_empty():
		hotel.open_gates(session.stage, session.goal.get("ready", false))
		if session.goal.get("blackout", false) and not hotel.dark: apply_blackout()
		elif not session.goal.get("blackout", false) and hotel.dark: restore_power()
		if playing and session.stage > last_stage: lifts.follow_players(session.stage)
	last_stage = session.stage
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
		session.State.PAUSED:
			refresh_briefing()
			ui.menu("pause")
		session.State.LOADING: ui.menu("loading")
		session.State.TRANSITION:
			# Between stages the floor goes on: a held beat and a notice, not
			# the end-of-floor screen. Only the last stage brings that.
			if session.more_stages():
				ui.overlay.hide()
				ui.settings_open = false
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				lifts.pending_brief = session.stage + 1
			else: ui.menu("transition")
		session.State.WON:
			ui.elapsed = session.elapsed
			if match_net.in_match():
				if net.is_host: match_net.clear_checkpoint()
				ui.menu("online_won")
			else: ui.menu("won")
		session.State.FAILED:
			ui.elapsed = session.elapsed
			ui.menu("online_failed" if match_net.in_match() else "failed")

## The stage the floor was on when it was last looked at, to tell a change.
var last_stage := 1

## The power goes, everywhere at once. Nothing says so in words: the hotel
## drops into the dark with a sound, and in the creature's reading the ceilings
## it can no longer hear humming come back at it in one burst.
func apply_blackout() -> void:
	hotel.blackout(true)
	if world_audio.enabled: world_audio.play_at(BLACKOUT_SOUND, player.global_position + Vector3(0, 2.5, 0), 0.0)
	if is_instance_valid(locust) and is_instance_valid(locust.driver) and locust.driver.has_method("mark_blackout"): locust.driver.mark_blackout()

## And the power comes back, in the wing ahead. What went out belonged to the
## wing where the last set was lit: crossing into the next one finds its lights
## on, with the same clunk of a board being thrown. A stage played in the dark
## is that stage's doing, not a floor that never recovers.
func restore_power() -> void:
	hotel.blackout(false)
	if world_audio.enabled: world_audio.play_at(BLACKOUT_SOUND, player.global_position + Vector3(0, 2.5, 0), -4.0)

## Everybody is on their feet again: between stages, or because the floor gave
## this stage back after it was lost. The authority says where, and every
## machine puts the bodies there.
func on_revived(restart: bool) -> void:
	if net.is_client() or manifest.is_empty(): return
	var point := revival_point()
	var places := {}
	for seat in session.participants: places[seat] = point + Vector3(randf_range(-1.2, 1.2), 0.1, randf_range(-1.2, 1.2))
	apply_revival(places, restart)
	if match_net.in_match(): match_net.revive_everyone(places, restart)

## Where somebody who comes back after dropping is put: the place the floor
## remembers for them. Unless the floor crossed to another wing while they were
## away -- their old place is then behind a stage door with half a hotel
## between them and everybody else, and nobody would call that coming back.
## The stage in hand starts them where a revival would.
func return_place(remembered: Vector3) -> Vector3:
	if manifest.is_empty(): return remembered
	var wing := int(FLOOR.room_at(manifest.rooms, remembered).get("wing", -1))
	if wing == session.stage - 1: return remembered
	return revival_point() + Vector3(0, 0.1, 0)

## Where a stage starts: just inside the wing it is played in.
func revival_point() -> Vector3:
	var gates_list: Array = manifest.get("gates", [])
	# A negative index wraps round in GDScript, so the first stage asking for
	# this would have been sent to the last gate of the floor.
	var index: int = session.stage - 2
	if index < 0 or index >= gates_list.size(): return Vector3(0, 0.04, 0)
	var gate: Dictionary = gates_list[index]
	var arrive := int(gate.get("arrive", -1))
	if arrive < 0: return FLOOR.position_of(manifest.rooms[refuge_room()])
	return FLOOR.position_of(manifest.rooms[arrive])

## Applied on every machine: the local body comes back where it is told, the
## others are placed, and a stage that was lost starts again as it was found.
func apply_revival(places: Dictionary, restart: bool) -> void:
	# The message itself says these seats are up. A guest's session is pushed
	# twice a second, so waiting for it to say so leaves up to half a second in
	# which the body is put away again every frame -- and its torch with it,
	# because the light hangs off the camera: hidden for its owner and lit for
	# everybody else.
	var raised := false
	for seat_key in places:
		var seat := int(seat_key)
		if session.participants.get(seat, session.Life.DEAD) == session.Life.DEAD:
			session.participants[seat] = session.Life.EXPLORING
			raised = true
	if raised: session.changed.emit()
	for seat_key in places:
		var seat := int(seat_key)
		if seat == player.slot: restore_local_player(places[seat_key])
		elif match_net.bodies.has(seat) and is_instance_valid(match_net.bodies[seat]):
			match_net.bodies[seat].place(places[seat_key], 0.0)
			# Its head clear too, the same as the local one's.
			sanity.minds.erase(seat)
			match_net.bodies[seat].set_burnt(false)
	if restart:
		# The stage as it was found: its own wing's sets go out again. What was
		# lit in the wings behind is not this stage's to undo.
		for index in stage_televisions():
			if televisions[index].on:
				apply_television(index, false)
				if not net.is_client() and match_net.in_match(): match_net.television_state.rpc(index, false)
		# And the power with them: the cut came with the sets, and a stage
		# given back is given back whole. The authority says so, as always.
		if not net.is_client() and bool(session.goal.get("blackout", false)):
			session.goal["blackout"] = false
			session.changed.emit()

## The inverse of watching a teammate: its own body, its own camera.
func restore_local_player(point: Vector3) -> void:
	# On its feet again with its head clear: what it went through belonged to
	# the stage it lost.
	player.sanity = 100.0
	player.set_burnt(false)
	player.active = session.state == session.State.PLAYING and not online_menu and not match_net.local_is_locust()
	player.velocity = Vector3.ZERO
	player.reset_handheld()
	player.global_position = point
	# Whoever closed the stage is put on their feet by the session at the same
	# moment their lift is carrying them: the ride keeps the hold and the
	# picture until the doors open.
	player.held = not lifts.boarding.is_empty() or lifts.leaving >= 0.0
	if player.hidden: player.force_leave_hide()
	stop_watching()
	clear_screen_cues()

## Back behind its own eyes. Everything watching a teammate did to the body --
## hidden, without collision, with somebody else's camera in front -- is undone
## here, and the torch is brought back to the hand: it is not parented to the
## camera but trails it, so a body that jumps leaves its own light behind.
## Called on a revival and again from the loop, because a single frame spent
## believing it was dead would otherwise leave the body away for the rest of
## the floor.
func stop_watching() -> void:
	var hunter: bool = match_net.local_is_locust()
	player.visible = not hunter
	player.collision_layer = 0 if hunter else 4
	if is_instance_valid(player.camera): player.camera.current = not hunter
	if is_instance_valid(watch_camera): watch_camera.current = false
	if is_instance_valid(watch_rig):
		watch_rig.queue_free()
		watch_rig = null
		watch_camera = null
		watch_arm = null
	match_net.watching = 0
	player.snap_torch()

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
	strike_uv = Vector2(0.35, 0.55)
	if is_instance_valid(locust) and locust.control != "puppet": locust.begin_execution()
	if seat == player.slot:
		player.active = false
		player.held = true
		player.velocity = Vector3.ZERO
		if player.hidden: player.force_leave_hide()
		if ui.sheet.visible: toggle_sheet()
	# The scream is the moment it has you: flat and loud in the victim's own
	# ears, and out in the room for everybody else.
	if not world_audio.enabled: return
	if seat == player.slot:
		if is_instance_valid(scream_sound): scream_sound.play()
	else: world_audio.play_at(SCREAM, point + Vector3(0, 2.0, 0), -4.0, RID(), 0.0)

## Sounds, screen jolts and, on the host, the death at the end.
func update_execution(delta: float) -> void:
	if execution.is_empty(): return
	execution.time += delta
	var point: Vector3 = locust.global_position if is_instance_valid(locust) else execution.point
	var held := point + Vector3(0, 1.7, 0)
	# The whoosh starts with the arm, so its impact lands as the lens goes.
	if int(execution.stabs) == 0 and execution.time >= ARM_TIME:
		if world_audio.enabled:
			if int(execution.seat) == player.slot and is_instance_valid(blow_sound): blow_sound.play()
			else: world_audio.play_at(KILL_BLOW, held, -1.0, RID(), 0.0)
		execution.stabs = 1
	if int(execution.stabs) == 1 and execution.time >= KILL_TIME:
		glitch = 1.0
		execution.stabs = 2
	# The dead channel starts with the snow, not before it: sound and picture
	# are the same event.
	if int(execution.stabs) == 2 and execution.time >= SIGNAL_TIME:
		execution.stabs = 3
		if int(execution.seat) == player.slot and world_audio.enabled and is_instance_valid(static_sound): static_sound.play()
	# The body going down is not heard: right after the blow it read as a
	# second stab, and nothing is lost by letting it fall in silence.
	if not execution.dropped and execution.time >= DROP_TIME: execution.dropped = true
	if execution.time >= locust.EXECUTION_TIME + 0.3:
		var seat := int(execution.seat)
		# Its own picture is gone: it keeps the lost signal a moment before it
		# ends up watching somebody else's camera.
		if seat == player.slot:
			lost_signal = LOST_HOLD
			ui.lost_signal(LOST_HOLD)
		execution = {}
		player.held = false
		if player.avatar != null:
			player.avatar.rotation.x = 0.0
			player.avatar.rotation.z = 0.0
		if not net.is_client(): session.capture(seat)

## Back to a clean picture: leaving for the menu, or starting a floor. The
## filter's material outlives the floor, so a signal that was lost when the
## hotel was freed would still be lost over the title room.
func clear_screen_cues() -> void:
	lost_signal = 0.0
	static_level = 0.0
	strike_uv = Vector2(0.35, 0.55)
	enclosure = 0.0
	glitch = 0.0
	if is_instance_valid(static_sound) and static_sound.playing: static_sound.stop()
	if is_instance_valid(camcorder): camcorder.signal_lost = false
	if post_material != null:
		post_material.set_shader_parameter("signal_loss", 0.0)
		post_material.set_shader_parameter("strike_fill", 0.0)
		post_material.set_shader_parameter("enclosure", 0.0)
		post_material.set_shader_parameter("threat_glitch", 0.0)

## Where the striking arm is on the victim's screen, as a UV: the black
## spreads from there, so it reads as an arm arriving and not as a fade.
var strike_uv := Vector2(0.35, 0.55)
func strike_on_screen() -> Vector2:
	if not is_instance_valid(locust) or not is_instance_valid(player.camera): return strike_uv
	# The hand that is actually coming: the creature holds with its left and
	# strikes with its right (locust_visual), and facing you its right is on
	# your left, which is where the black has to start.
	var hand: Vector3 = locust.global_position + Vector3(0, 2.0, 0) + locust.global_basis.x * 0.45
	var visual = locust.visual
	if is_instance_valid(visual) and "skeleton" in visual and "bones" in visual and visual.bones.has("R_Hand"):
		hand = visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(int(visual.bones["R_Hand"])).origin
	var size: Vector2 = player.camera.get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0: return strike_uv
	# Once the hand is past the lens it would project inverted, so the last
	# place it was seen is kept: the black goes on spreading from there instead
	# of jumping to the middle of the screen.
	if player.camera.is_position_behind(hand): return strike_uv
	var point: Vector2 = player.camera.unproject_position(hand)
	# Kept inside the frame and on the left half: the arm that strikes is the
	# creature's right, which facing you is on your left, and a black growing
	# from a corner reads as a shadow instead of as something arriving.
	strike_uv = Vector2(clampf(point.x / size.x, 0.08, 0.5), clampf(point.y / size.y, 0.18, 0.82))
	return strike_uv

## The victim: held in the air in front of the creature, looking at it.
func hold_victim(delta: float) -> void:
	var point: Vector3 = locust.global_position if is_instance_valid(locust) else execution.point
	var yaw: float = locust.rotation.y if is_instance_valid(locust) else execution.yaw
	var forward := -Basis(Vector3.UP, yaw).z
	var time: float = execution.time
	var lift := clampf(time / 0.5, 0.0, 1.0) - clampf((time - DROP_TIME) / 0.4, 0.0, 1.0)
	# Held on the blade at the creature's chest height, and drawn slowly in:
	# the mask arriving is the whole point of the wait before the blow.
	var closing := ease(clampf((time - 0.5) / maxf(KILL_TIME - 0.5, 0.01), 0.0, 1.0), 0.45)
	var wanted := point + forward * lerpf(1.15, 0.6, closing) + Vector3(0, 0.1 + lift * 1.0, 0)
	player.velocity = Vector3.ZERO
	player.global_position = player.global_position.lerp(wanted, minf(1.0, delta * 10.0))
	# Run through on the blade: the body hangs back and sags, and goes limp
	# once the arm is through its face.
	var limp := clampf((time - KILL_TIME) / 0.35, 0.0, 1.0)
	if player.avatar != null:
		player.avatar.rotation.x = -(0.5 + 0.5 * limp) * lift
		player.avatar.rotation.z = (0.12 + 0.25 * limp) * lift
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

## The refuge of the stage in hand: the room holding the door on. Each one
## protects only while its stage lasts; once crossed it is a room like any
## other.
func refuge_room() -> int:
	var refuges: Array = manifest.get("refuges", [])
	if refuges.is_empty(): return int(manifest.exit)
	return int(refuges[clampi(session.stage - 1, 0, refuges.size() - 1)])

func point_in_refuge(point: Vector3) -> bool:
	if manifest.is_empty(): return false
	var room: Dictionary = manifest.rooms[refuge_room()]
	var center := FLOOR.position_of(room)
	var span := FLOOR.size_of(room)
	return absf(point.x - center.x) < span.x * 0.5 - 0.55 and absf(point.z - center.z) < span.y * 0.5 - 0.55 and point.y >= -0.1 and point.y < 2.0

func spawn_locust() -> void:
	locust = LOCUST.instantiate()
	locust.level = self
	locust.process_mode = Node.PROCESS_MODE_PAUSABLE
	# As far into the first wing as that wing goes: the stage is played there
	# and the creature has to start away from the door everyone comes in by.
	var distances := GENERATOR.distance_map(manifest.adjacency, 0)
	var reach := 0
	for room in manifest.rooms:
		if int(room.get("wing", 0)) == 0 and room.id != manifest.exit: reach = maxi(reach, int(distances[room.id]))
	var chosen := 0
	var target := int(reach * 0.75)
	for room in manifest.rooms:
		if int(room.get("wing", 0)) != 0 or room.id == manifest.exit: continue
		if distances[room.id] >= target and distances[room.id] > 3:
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

func focused_television():
	var area = focused_area()
	return area if area is TELEVISION else null

func focused_container():
	var area = focused_area()
	return area if area is CONTAINER else null

func focused_lock():
	var area = focused_area()
	return area if area is LOCK else null

## The keypad: numbers go in, a wrong code clears itself, the right one opens
## the door for everybody.
func type_code(character: String) -> void:
	if character == "borrar": typed = typed.substr(0, maxi(0, typed.length() - 1))
	elif typed.length() < DIGITS.COUNT: typed += character
	if typed.length() < DIGITS.COUNT:
		ui.show_lock(typed, DIGITS.COUNT, "", noted_code())
		return
	var right: String = "".join(DIGITS.code(manifest).map(func(digit): return str(digit)))
	# The right code on a wing whose sets are still dark: the door is not
	# going to move, and it is better said here than guessed at the door.
	if typed == right and not sets_lit():
		typed = ""
		ui.show_lock("", DIGITS.COUNT, "FALTAN TELEVISORES", noted_code())
		return
	if typed == right:
		match_net.use_code()
		ui.show_lock(typed, DIGITS.COUNT, "ABIERTA", noted_code())
		close_lock()
	else:
		typed = ""
		ui.show_lock("", DIGITS.COUNT, "NO ES", noted_code())
		if world_audio.enabled: world_audio.play_at(SEARCH_SOUND, lock.global_position, -12.0)

func open_lock() -> void:
	lock_open = true
	typed = ""
	player.reading = true
	ui.show_lock("", DIGITS.COUNT, "", noted_code())

func close_lock() -> void:
	lock_open = false
	player.reading = false
	ui.hide_lock()

## The code is in: the last door gives way, on every machine.
func apply_code() -> void:
	if code_entered: return
	code_entered = true
	if is_instance_valid(lock): lock.set_open(true)
	if world_audio.enabled: world_audio.play_at(SWITCH_SOUND, hotel.lifts[hotel.lifts.size() - 1] if not hotel.lifts.is_empty() else player.global_position, -4.0)

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
	# 64 too: a leaf somebody is standing in is not solid yet, and it must
	# still be there to be used -- to open again the door just shut on you.
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * DOOR_REACH, 1 | 8 | 64)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is DOOR: return hit.collider
	# And from inside it, doors only: the head can be in the leaf of a door
	# shut on it, and a ray starting inside a shape does not see that shape.
	query.collision_mask = 8 | 64
	query.hit_from_inside = true
	hit = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() and hit.collider is DOOR and hit.position.distance_to(from) < 0.01 else null

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
	# The ride is counted before the rest: closing a stage puts the session
	# into its transition for a moment, and everything below stops there -- a
	# lift that stopped counting would hold somebody in the dark for good.
	lifts.ride_along(delta)
	lifts.ride_out(delta)
	if not is_instance_valid(session) or session.state != session.State.PLAYING: return
	# The notice of the sector waits for the card to be gone and for the lift
	# to have opened its doors: it is what the picture comes back to.
	lifts.announce_sector(delta)
	drive_local(delta)
	sanity.tick(delta)
	# Whoever is in charge counts the hold at the exit once a frame, whatever
	# its own player happens to be doing. It used to be called from inside the
	# branches below, and the one for a dead player had no call: with the host
	# dead, its guests could hold at the refuge for ever and never leave.
	if not net.is_client(): host_gate(delta)

## This machine's own player: looking, opening, reading, hiding, or watching a
## teammate once it is dead.
func drive_local(delta: float) -> void:
	if not net.is_client():
		for body in survivors(): session.set_refuge(body.slot, point_in_refuge(body.global_position))
	if not execution.is_empty() and int(execution.seat) == player.slot:
		hold_victim(delta)
		return
	if Input.is_action_just_pressed("sheet") and not online_menu: toggle_sheet()
	if ui.sheet.visible:
		# Looking at the sheet: the character stands still, the world goes on.
		camcorder.focus("")
		if not local_alive(): watch_teammates()
		return
	if not local_alive():
		# Its own picture went with it: the lost signal holds a moment before
		# the view ends up over a teammate's shoulder.
		if lost_signal > 0.0:
			camcorder.focus("")
			ui.hint.text = ""
			return
		watch_teammates()
		return
	if online_menu or match_net.local_is_locust(): return
	# On its feet and still put away: whatever watching a teammate did to the
	# body is undone now. The word that it is up and the replicated session
	# that says so do not always arrive in that order, and a body left hidden
	# is a body whose own torch only the others can see.
	if is_instance_valid(watch_rig) or not player.visible: stop_watching()
	camcorder.set_stamina(player.stamina / 100.0, player.exhausted)
	var floor_room := FLOOR.room_at(manifest.rooms, player.global_position)
	player.hard_floor = not floor_room.is_empty() and int(floor_room.type) in FLOOR.HARD_FLOORS
	if is_instance_valid(reading_document):
		camcorder.focus("")
		if Input.is_action_just_pressed("interact"): close_document()
		was_held = true
		return
	if lock_open:
		camcorder.focus("")
		ui.hint.text = ""
		return
	var lock_target = focused_lock()
	if Input.is_action_just_pressed("interact") and is_instance_valid(lock_target) and not code_entered:
		open_lock()
		was_held = true
		return
	var container_target = focused_container()
	if is_instance_valid(container_target) and not container_target.searched:
		if Input.is_action_pressed("interact"):
			search_time += delta
			if search_time >= CONTAINER.SEARCH_TIME:
				search_container(container_target)
				search_time = 0.0
			camcorder.focus("REGISTRAR")
			ui.hint.text = ""
			was_held = true
			return
		search_time = 0.0
	else: search_time = 0.0
	var television_target = focused_television()
	if Input.is_action_just_pressed("interact") and not player.hidden and is_instance_valid(television_target) and not television_target.on:
		switch_television(television_target)
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
	camcorder.focus("TECLADO" if is_instance_valid(lock_target) and not code_entered else "ENCENDER" if is_instance_valid(television_target) and not television_target.on else "LEER" if is_instance_valid(document_target) else "ESCONDERSE" if is_instance_valid(hiding_target) else ("CERRAR" if target.opened else "ABRIR") if is_instance_valid(target) else focused_teammate())
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
			match_net.use_door(pressed_door, false, running)
		pressed_door = null
	was_held = held
	# Nothing is written about where the survivor stands: not the refuge and
	# what it still waits for, not the open door, not the car on its way back.
	# The door that opens and the lift that is not there say it themselves.
	ui.hint.text = ""
	ui.subtitle.text = ""
	if settings.values.subtitles and session.elapsed > 5 and session.elapsed < 10:
		ui.subtitle.text = "[Ventilación constante]"
	if not save_error.is_empty(): ui.subtitle.text = save_error

## The authority, every frame: whether the stage in hand is met -- which
## unlocks the door on -- and whether somebody has already crossed it, which
## is what carries the floor to the next stage. Nothing is held down any more.
## The AI travels by television too, so a lit set is never safe just because
## the creature is far: after a while looking for nobody, standing at one, it
## steps out of another. Seconds left before it may do that again.
var hop_rest := 0.0
const HOP_REST := 25.0
const HOP_PATIENCE := 8.0
func creature_channel_hop(delta: float) -> void:
	hop_rest = maxf(0.0, hop_rest - delta)
	if not is_instance_valid(locust) or locust.control != "ai" or hop_rest > 0.0: return
	if locust.mode != locust.Mode.SEARCH or locust.state_time < HOP_PATIENCE: return
	var here: int = creature_at_television()
	var lit: Array = lit_televisions()
	if here < 0 or lit.size() < 2: return
	var choices: Array = lit.filter(func(index): return index != here)
	var pick: int = choices[locust.rng.randi_range(0, choices.size() - 1)]
	hop_rest = HOP_REST
	warp_creature(pick)
	if match_net.in_match(): match_net.warp_state.rpc(pick)

func host_gate(delta: float) -> void:
	creature_channel_hop(delta)
	sanity.haunt_burnt(delta)
	# From the second stage on, the wing is played on its own sets: each stage
	# counts the ones standing in its wing and starts from nothing.
	var sets: Array = stage_televisions() if session.stage >= 2 else []
	var lit_enough := true
	if not sets.is_empty():
		var needed: int = TV_PLACEMENT.needed(session.roster_count)
		var done: int = televisions_on()
		lit_enough = done >= needed
		session.goal["sets_done"] = done
		session.goal["sets_needed"] = needed
		# With one set left to light, this wing loses its power and the
		# creature hunts without tiring. It is the wing's power, not the
		# floor's: the next one is found lit.
		if done >= needed - 1 and not session.goal.get("blackout", false):
			session.goal["blackout"] = true
			session.changed.emit()
	if session.stage == session.STAGES and not containers.is_empty():
		# The last stage asks for both: the sets of its wing lit, and the four
		# numbers read into the keypad.
		session.goal["kind"] = "code"
		session.goal["done"] = found_digits.size()
		session.goal["needed"] = DIGITS.COUNT
		session.update_goal(delta, code_entered and lit_enough)
	elif not sets.is_empty():
		session.goal["kind"] = "televisions"
		session.goal["done"] = int(session.goal.get("sets_done", 0))
		session.goal["needed"] = int(session.goal.get("sets_needed", 0))
		session.update_goal(delta, lit_enough)
	else: session.update_goal(delta, session.can_depart())
	lifts.ride_lifts()

## Dead online: the view follows a living teammate; a click switches to the next.
func watch_teammates() -> void:
	player.active = false
	player.visible = false
	player.collision_layer = 0
	var body: Node3D = match_net.watched_body()
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
		# The creature's view has no lens and no zoom; leaving that seat the
		# lens is written again.
		player.camera.fov = LOOK.VIEW_FOV
		if is_instance_valid(watch_camera): watch_camera.fov = LOOK.VIEW_FOV
		lens_zoom = -1.0

## The lens as the zoom stands (hotel_player.zoom): the field of view it sees,
## how wide the picture is rendered and how much the barrel bends it. A long
## lens bends far less, so the remap follows the zoom (camcorder_look.gd).
var lens_zoom := -1.0
var lens_aspect := -1.0

func update_zoom_lens() -> void:
	if hunter_seat() or not is_instance_valid(player) or not is_instance_valid(lens_material): return
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	# Written only when it moves: setting a camera's field of view rebuilds
	# its projection, every frame, for nothing.
	if is_equal_approx(player.zoom, lens_zoom) and is_equal_approx(aspect, lens_aspect): return
	lens_zoom = player.zoom
	lens_aspect = aspect
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

## Wardrobe enclosure, strike glitch and lost signal on the analog filter.
## The first two are off with reduced effects; the picture going is not an
## effect, it is how a victim is told it died, so it stays (milder).
var enclosure := 0.0
var glitch := 0.0
## Seconds of lost picture left for the local victim, and how far gone it is.
var lost_signal := 0.0
var static_level := 0.0
func update_screen_cues(delta: float) -> void:
	var wanted_enclosure: float = (1.0 - player.peek * 0.8) if player.hidden and session.state == session.State.PLAYING else 0.0
	enclosure = move_toward(enclosure, wanted_enclosure, delta * 2.0)
	var striking: bool = is_instance_valid(locust) and locust.mode == locust.Mode.WINDUP
	glitch = 1.0 if striking else move_toward(glitch, 0.0, delta * 4.0)
	lost_signal = maxf(0.0, lost_signal - delta)
	var mine: bool = not execution.is_empty() and int(execution.seat) == player.slot
	var dying: bool = mine and float(execution.time) >= SIGNAL_TIME
	var riding_now: float = lifts.ride_static()
	var wanted_static: float = 1.0 if dying or lost_signal > 0.0 else riding_now
	# Straight to static once the arm has landed: the picture does not fade,
	# it goes. Coming back (a new floor) it clears gently.
	# Gone at once when the view is already somebody else's camera; otherwise
	# it comes in hard and clears gently.
	if wanted_static <= 0.0 and not local_alive() and execution.is_empty(): static_level = 0.0
	elif riding_now > 0.0 or not lifts.boarding.is_empty(): static_level = wanted_static
	else: static_level = move_toward(static_level, wanted_static, delta * (14.0 if wanted_static > static_level else 1.6))
	post_material.set_shader_parameter("signal_loss", static_level * (0.75 if settings.values.reduced else 1.0))
	# The arm arriving: black spreading from where its hand is on screen.
	var arm := 0.0
	if mine and float(execution.time) >= ARM_TIME and static_level < 0.9:
		arm = clampf((float(execution.time) - ARM_TIME) / ARM_SWING, 0.0, 1.0)
		post_material.set_shader_parameter("strike_point", strike_on_screen())
	post_material.set_shader_parameter("strike_fill", arm)
	camcorder.signal_lost = static_level > 0.35 or arm > 0.25
	# The dead channel stops with the snow, not a moment later.
	if is_instance_valid(static_sound) and static_sound.playing and static_level < 0.05: static_sound.stop()
	if settings.values.reduced: return
	post_material.set_shader_parameter("enclosure", enclosure)
	post_material.set_shader_parameter("threat_glitch", glitch)
	# The tape frays with the mind: the picture drags and the colours start to
	# run. With no bar anywhere, this is what says the meter is there at all.
	if not hunter_seat():
		var frayed: float = clampf(1.0 - player.sanity / sanity.SANITY_UNEASY, 0.0, 1.0)
		post_material.set_shader_parameter("vhs", settings.values.vhs * (1.0 + frayed * 1.6))
		post_material.set_shader_parameter("chromatic", settings.values.chromatic * frayed * 0.7)

func build_audio() -> void:
	# Handling a document: a local sound, not a noise the creature can hear.
	paper_sound = AudioStreamPlayer.new()
	paper_sound.name = "Paper"
	paper_sound.bus = "Effects"
	paper_sound.volume_db = -8.0
	paper_sound.stream = load("res://assets/audio/sfx/paper/paper.ogg")
	add_child(paper_sound)
	# The scream of being caught: not a sound in the room, a sound in your head.
	scream_sound = AudioStreamPlayer.new()
	scream_sound.name = "Scream"
	scream_sound.bus = "Threat"
	scream_sound.volume_db = 0.0
	scream_sound.stream = load(SCREAM)
	add_child(scream_sound)
	# The blow and the dead channel that follows it, in the victim's own ears.
	blow_sound = AudioStreamPlayer.new()
	blow_sound.name = "Blow"
	blow_sound.bus = "Threat"
	blow_sound.volume_db = -1.0
	blow_sound.stream = load(KILL_BLOW)
	add_child(blow_sound)
	static_sound = AudioStreamPlayer.new()
	static_sound.name = "DeadChannel"
	static_sound.bus = "Effects"
	static_sound.volume_db = -2.0
	static_sound.stream = load(DEAD_CHANNEL)
	add_child(static_sound)
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
