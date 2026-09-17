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
var menu_clock := 0.0
var automation := false
var visibility_clock := 0.0
var pressed_door
var press_time := 0.0
var was_held := false
var slow_used := false
var save_error := ""
var physical_errors: Array[String] = []

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
	player.settings = settings
	ui.settings = settings

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	automation = DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--automation")
	world_audio.enabled = not automation and not OS.get_cmdline_user_args().has("--silent")
	ui.sounds_enabled = world_audio.enabled
	player.hiding_changed.connect(world_audio.hide_cue)
	ui.action_requested.connect(on_action)
	session.changed.connect(on_state)
	NavigationServer3D.map_set_use_async_iterations(get_world_3d().navigation_map, false)
	build_environment()
	build_audio()
	settings.changed.connect(apply_settings)
	apply_settings()
	# A single furnished reception previews the visual language behind the menu.
	var preview := GENERATOR.new().generate(404)
	hotel = GEOMETRY.new()
	hotel.name = "GeneratedHotel"
	hotel.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hotel)
	hotel.manifest = preview
	var lobby := Node3D.new()
	hotel.add_child(lobby)
	hotel.build_room(lobby, preview.rooms[0])
	hotel.flush()
	player.position = Vector3(1, 0.06, 3.8)
	player.rotation.y = 0.15
	var saved: Dictionary = session.checkpoint()
	ui.menu("main", not saved.is_empty(), session.message)
	on_state()
	if not automation: ui.play_intro()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--playtest-seed="):
			var value := argument.trim_prefix("--playtest-seed=")
			if value.is_valid_int() and int(value) >= 0 and int(value) <= 2147483647: start_floor(int(value))

func on_action(action: String) -> void:
	match action:
		"new": start_floor(randi_range(0, 2147483647))
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
		"quit": get_tree().quit()

func start_floor(seed_value: int, force_fallback := false) -> void:
	if session.state == session.State.LOADING: return
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
	hotel.quality = settings.values.quality
	hotel.reduced = settings.values.reduced
	player.spawn = Vector3(0, 0.04, 0)
	player.position = player.spawn
	player.velocity = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
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
		await get_tree().physics_frame
		await get_tree().physics_frame
		physical_errors = VALIDATOR.new().validate_physics(get_world_3d(), manifest)
		if not physical_errors.is_empty():
			save_error = "El mapa de respaldo no superó la validación física. No se inició la partida."
			session.set_state(session.State.MENU)
			return
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
		return
	camcorder.start_tape(seed_value)
	session.start(seed_value, manifest.get("fallback", false))
	ui.flash("ENCUENTRA LA SALIDA", 5.0)
	save_error = session.message
	spawn_locust()
	world_audio.set_creature(locust.sound_profile)
	for door in hotel.doors: door.sound_requested.connect(world_audio.door_cue)
	if not automation and not OS.get_cmdline_user_args().has("--silent"):
		ambience.play()
		theme.play()
		ventilation.play()

func on_state() -> void:
	var playing: bool = session.state == session.State.PLAYING
	if session.state in [session.State.MENU, session.State.FAILED, session.State.WON]: world_audio.reset()
	player.active = playing
	if not playing: player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
	get_tree().paused = session.state in [session.State.MENU, session.State.PAUSED, session.State.WON, session.State.FAILED]
	press_time = 0
	pressed_door = null
	was_held = Input.is_action_pressed("interact")
	if playing:
		ui.overlay.hide()
		ui.settings_open = false
		return
	match session.state:
		session.State.MENU:
			var saved: Dictionary = session.checkpoint()
			ui.menu("main", not saved.is_empty(), save_error if not save_error.is_empty() else session.message)
		session.State.PAUSED: ui.menu("pause")
		session.State.LOADING: ui.menu("loading")
		session.State.TRANSITION: ui.menu("transition")
		session.State.WON:
			ui.elapsed = session.elapsed
			ui.menu("won")
		session.State.FAILED:
			ui.elapsed = session.elapsed
			ui.menu("failed")

func in_refuge() -> bool:
	return point_in_refuge(player.position)

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

func on_noise(point: Vector3, radius: float) -> void:
	if is_instance_valid(locust): locust.hear(point, radius)

func focused_hide():
	var from: Vector3 = player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * 2.0, 1 | 8 | 16)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() and hit.collider is HIDE else null

func focused_door():
	var from: Vector3 = player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * 2.0, 1 | 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() and hit.collider is DOOR else null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(session) or session.state != session.State.PLAYING: return
	var inside := in_refuge()
	session.set_refuge(1, inside)
	camcorder.set_stamina(player.stamina / 100.0, player.exhausted)
	var hiding_target = focused_hide()
	if Input.is_action_just_pressed("interact") and (player.hidden or is_instance_valid(hiding_target)):
		if player.hidden: player.leave_hide()
		else:
			if is_instance_valid(locust) and locust.sees_player(true): locust.observed_hide = hiding_target
			player.enter_hide(hiding_target)
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
	var held := Input.is_action_pressed("interact")
	# Camcorder-style focus brackets replace the old control prompts.
	camcorder.focus("ESCONDERSE" if is_instance_valid(hiding_target) else ("CERRAR" if target.opened else "ABRIR") if is_instance_valid(target) else "")
	if held and not was_held:
		pressed_door = target
		press_time = 0
		slow_used = false
	if held and is_instance_valid(pressed_door) and target == pressed_door:
		press_time += delta
		if press_time >= 1 and not slow_used:
			pressed_door.toggle(true)
			slow_used = true
	elif held:
		pressed_door = null
		press_time = 0
	if was_held and not held:
		if is_instance_valid(pressed_door) and target == pressed_door and not slow_used:
			# Running into a door pushes it open (or shut) with a slam.
			var running := Vector2(player.velocity.x, player.velocity.z).length() > 4.6
			if not pressed_door.toggle(false, true, running): ui.flash("DEJA LIBRE EL UMBRAL")
		pressed_door = null
	was_held = held
	# Deliberate hold inside the refuge; door operations never also start departure.
	session.hold_exit(delta, held and inside and not is_instance_valid(target) and not is_instance_valid(pressed_door))
	ui.progress.visible = session.exit_progress > 0
	ui.progress.value = session.exit_progress
	ui.hint.text = "REFUGIO · MANTÉN [%s] PARA SALIR DEL PISO" % key if inside else ""
	ui.subtitle.text = ""
	if settings.values.subtitles and session.elapsed > 5 and session.elapsed < 10:
		ui.subtitle.text = "[Ventilación constante]"
	if not save_error.is_empty(): ui.subtitle.text = save_error

func _process(delta: float) -> void:
	update_menu_scene(delta)
	camcorder.visible = session.state == session.State.PLAYING
	camcorder.marks = settings.values.osd
	if camcorder.visible: camcorder.show_tape(session.elapsed, delta)
	if not is_instance_valid(hotel) or manifest.is_empty(): return
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
		hotel.update_visibility(player.position, settings.values.shadows)
		ventilation.position = Vector3(round(player.position.x / 12) * 12, 2.8, round(player.position.z / 12) * 12)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_ESCAPE:
		if ui.settings_open:
			if not settings.previous_display.is_empty(): settings.revert_display()
			on_action(ui.return_action)
		elif ui.screen in ["credits", "characters"] and session.state == session.State.MENU: on_action("main")
		elif session.state == session.State.PAUSED: session.set_state(session.State.PLAYING)
		else: session.pause()
	if event.physical_keycode == KEY_F9 and OS.is_debug_build(): session.capture(1)
	if event.physical_keycode == KEY_F11:
		session.pause()
		settings.set_value("fullscreen", not settings.values.fullscreen)
		ui.show_settings("pause" if session.state == session.State.PAUSED else "main")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(session) and not automation: session.pause()

func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func build_environment() -> void:
	environment = $Presentation/WorldEnvironment.environment
	post_material = $Presentation/Analog/Screen.material
	camcorder = $Presentation/Camcorder

func apply_settings() -> void:
	if not is_instance_valid(environment): return
	var advanced := RenderingServer.get_current_rendering_method() == "forward_plus"
	var quality: int = settings.values.quality
	environment.ssao_enabled = advanced and quality > 0
	environment.ssil_enabled = advanced and quality > 0
	# SDFGI leaks light through the 18 cm hotel walls; bounce light is screen-space only.
	environment.sdfgi_enabled = false
	environment.glow_enabled = quality > 0
	environment.volumetric_fog_enabled = advanced and quality > 0 and not settings.values.reduced
	var viewport := get_viewport()
	viewport.msaa_3d = Viewport.MSAA_2X if quality > 0 else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if quality == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = advanced and quality == 2
	for key in ["vhs", "grain", "chromatic", "scanlines"]: post_material.set_shader_parameter(key, 0.0 if settings.values.reduced else settings.values[key])
	post_material.set_shader_parameter("vignette", 0.0 if settings.values.reduced else 0.45)
	player.torch.shadow_enabled = settings.values.shadows
	player.set_character(settings.values.character)
	if is_instance_valid(hotel):
		hotel.quality = settings.values.quality
		hotel.reduced = settings.values.reduced

func build_audio() -> void:
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

# Menu background: a slow handheld drift through the lobby and quiet music.
func update_menu_scene(delta: float) -> void:
	var in_menu: bool = session.state == session.State.MENU
	var audible: bool = in_menu and world_audio.enabled
	if audible and not menu_music.playing: menu_music.play()
	elif not audible and menu_music.playing: menu_music.stop()
	if not in_menu or automation: return
	menu_clock += delta
	player.rotation.y = 0.15 + sin(menu_clock * 0.06) * 0.32
	player.camera.rotation.x = -0.05 + sin(menu_clock * 0.09) * 0.025
	player.camera.rotation.z = sin(menu_clock * 0.13) * 0.006
