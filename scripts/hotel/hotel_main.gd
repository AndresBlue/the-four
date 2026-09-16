extends Node3D
const GENERATOR := preload("res://scripts/hotel/map_generator.gd")
const VALIDATOR := preload("res://scripts/hotel/map_validator.gd")
const GEOMETRY := preload("res://scripts/hotel/hotel_geometry.gd")
const SETTINGS := preload("res://scripts/hotel/settings_service.gd")
const SESSION := preload("res://scripts/hotel/game_session.gd")
const PLAYER := preload("res://scripts/hotel/hotel_player.gd")
const UI := preload("res://scripts/hotel/hotel_ui.gd")
const DOOR := preload("res://scripts/hotel/hotel_door.gd")
var settings
var session
var hotel
var player
var ui
var manifest := {}
var environment: Environment
var post_material: ShaderMaterial
var ambience: AudioStreamPlayer
var theme: AudioStreamPlayer
var ventilation: AudioStreamPlayer3D
var automation := false
var visibility_clock := 0.0
var pressed_door
var press_time := 0.0
var was_held := false
var slow_used := false
var save_error := ""
var physical_errors: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	automation = DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--automation")
	var test_name := "default"
	for argument in OS.get_cmdline_args():
		if argument.ends_with(".gd"): test_name = argument.get_file().get_basename()
	settings = SETTINGS.new()
	if OS.get_cmdline_user_args().has("--test-profile"): settings.save_path = "user://test_hotel_%s_settings.json" % test_name
	add_child(settings)
	session = SESSION.new()
	if OS.get_cmdline_user_args().has("--test-profile"): session.checkpoint_path = "user://test_hotel_%s_checkpoint.json" % test_name
	add_child(session)
	player = PLAYER.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.settings = settings
	add_child(player)
	ui = UI.new()
	ui.settings = settings
	add_child(ui)
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
		"quit": get_tree().quit()

func start_floor(seed_value: int, force_fallback := false) -> void:
	if session.state == session.State.LOADING: return
	session.set_state(session.State.LOADING)
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(hotel):
		remove_child(hotel)
		hotel.queue_free()
	manifest = GENERATOR.new().generate(seed_value)
	if force_fallback:
		manifest = GENERATOR.new().candidate(404, 0, true)
		manifest["fallback"] = true
		manifest["requested_seed"] = seed_value
	hotel = GEOMETRY.new()
	hotel.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(hotel)
	hotel.build(manifest)
	hotel.quality = settings.values.quality
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
	var exit_position := Vector3(exit_room.x * 12, 0, exit_room.z * 12)
	var navigation_ready := false
	for frame in 12:
		await get_tree().physics_frame
		var path := NavigationServer3D.map_get_path(get_world_3d().navigation_map, Vector3.ZERO, exit_position, true)
		if path.size() > 1 and path[-1].distance_to(exit_position) < 0.2:
			navigation_ready = true
			break
	if not navigation_ready:
		save_error = "No se pudo validar la ruta de salida. El nivel no se inició."
		session.set_state(session.State.MENU)
		return
	session.start(seed_value, manifest.get("fallback", false))
	save_error = session.message
	if not automation and not OS.get_cmdline_user_args().has("--silent"):
		ambience.play()
		theme.play()
		ventilation.play()

func on_state() -> void:
	var playing: bool = session.state == session.State.PLAYING
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
		session.State.WON: ui.menu("won")
		session.State.FAILED: ui.menu("failed")

func in_refuge() -> bool:
	if manifest.is_empty(): return false
	var room: Dictionary = manifest.rooms[manifest.exit]
	var center := Vector3(room.x * 12.0, 0, room.z * 12.0)
	return absf(player.position.x - center.x) < 5.45 and absf(player.position.z - center.z) < 5.45 and player.position.y >= -0.1 and player.position.y < 2.0

func focused_door():
	var from: Vector3 = player.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - player.camera.global_basis.z * 2.0, 1 | 8)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider if not hit.is_empty() and hit.collider is DOOR else null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(session) or session.state != session.State.PLAYING: return
	var inside := in_refuge()
	session.set_refuge(1, inside)
	var target = focused_door()
	var held := Input.is_action_pressed("interact")
	var key: String = settings.key_name("interact")
	ui.hint.text = "%s · Abrir puerta / mantener para abrir lentamente" % key if is_instance_valid(target) and not target.opened else "%s · Cerrar puerta" % key if is_instance_valid(target) else ""
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
			if not pressed_door.toggle(): ui.hint.text = "Deja libre el umbral para cerrar."
		pressed_door = null
	was_held = held
	# Deliberate hold inside the refuge; door operations never also start departure.
	session.hold_exit(delta, held and inside and not is_instance_valid(target) and not is_instance_valid(pressed_door))
	ui.progress.visible = session.exit_progress > 0
	ui.progress.value = session.exit_progress
	if inside: ui.hint.text = "REFUGIO · Puedes regresar al hotel. Mantén %s durante 3 s para salir." % key
	ui.subtitle.text = ""
	if session.elapsed < 12:
		ui.subtitle.text = "Encuentra la salida.\n%s · Interactuar    %s · Linterna    Esc · Pausa" % [key, settings.key_name("flashlight")]
	elif settings.values.subtitles and session.elapsed < 17:
		ui.subtitle.text = "[Ventilación constante]"
	if not save_error.is_empty(): ui.subtitle.text = save_error

func _process(delta: float) -> void:
	if not is_instance_valid(hotel) or manifest.is_empty(): return
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
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("13140f")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b5ab86")
	environment.ambient_light_energy = 0.24
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("3e4035")
	environment.fog_density = 0.003
	world.environment = environment
	add_child(world)
	var post := CanvasLayer.new()
	post.layer = 5
	add_child(post)
	var screen := ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, filter_linear; uniform float vhs=0.18; uniform float grain=0.12; uniform float chromatic=0.08; void fragment(){vec2 uv=SCREEN_UV; float n=fract(sin(dot(uv+fract(TIME),vec2(12.9898,78.233)))*43758.5453);uv.x+=sin(uv.y*450.0+TIME*2.0)*vhs*0.0004;vec3 c=texture(screen_texture,uv).rgb;c.r=texture(screen_texture,uv+vec2(chromatic*0.001,0.0)).r;c.b=texture(screen_texture,uv-vec2(chromatic*0.001,0.0)).b;c+=(n-0.5)*grain*0.12; c*=1.0-vhs*0.12*(0.5+0.5*sin(uv.y*850.0));COLOR=vec4(c,1.0);}"
	post_material = ShaderMaterial.new()
	post_material.shader = shader
	screen.material = post_material
	post.add_child(screen)

func apply_settings() -> void:
	if not is_instance_valid(environment): return
	var advanced := RenderingServer.get_current_rendering_method() == "forward_plus"
	environment.ssao_enabled = advanced and settings.values.quality > 0
	environment.glow_enabled = settings.values.quality > 0
	environment.volumetric_fog_enabled = advanced and settings.values.quality == 2 and not settings.values.reduced
	environment.volumetric_fog_density = 0.008
	for key in ["vhs", "grain", "chromatic"]: post_material.set_shader_parameter(key, 0.0 if settings.values.reduced else settings.values[key])
	player.torch.shadow_enabled = settings.values.shadows
	if is_instance_valid(hotel): hotel.quality = settings.values.quality

func build_audio() -> void:
	ambience = AudioStreamPlayer.new()
	ambience.process_mode = Node.PROCESS_MODE_PAUSABLE
	ambience.bus = "Ambience"
	ambience.volume_db = -23
	var ambient_stream := load("res://assets/audio/hotel/ambience.wav").duplicate() as AudioStreamWAV
	ambient_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambient_stream.loop_begin = 0
	ambient_stream.loop_end = int(ambient_stream.get_length() * ambient_stream.mix_rate)
	ambience.stream = ambient_stream
	add_child(ambience)
	theme = AudioStreamPlayer.new()
	theme.process_mode = Node.PROCESS_MODE_PAUSABLE
	theme.bus = "Music"
	theme.volume_db = -26
	theme.stream = load("res://assets/audio/the_four_theme.mp3").duplicate()
	theme.stream.loop = true
	add_child(theme)
	ventilation = AudioStreamPlayer3D.new()
	ventilation.process_mode = Node.PROCESS_MODE_PAUSABLE
	ventilation.bus = "Ambience"
	ventilation.volume_db = -28
	ventilation.max_distance = 14
	ventilation.stream = ambient_stream
	add_child(ventilation)
