extends Node3D

const SESSION := preload("res://legacy/fuse_prototype/scripts/game_session.gd")
const GAMEPLAY := preload("res://legacy/fuse_prototype/scripts/level_gameplay.gd")
const UI := preload("res://legacy/fuse_prototype/scripts/session_ui.gd")
const ITEM := preload("res://legacy/fuse_prototype/scripts/interactable.gd")

@onready var player: CharacterBody3D = $Player
@onready var hint: Label = $HUD/Hint
@onready var status: Label = $HUD/Status
@onready var music: AudioStreamPlayer = $Music
@onready var music_label: Label = $HUD/MusicStatus
var session
var gameplay
var ui
var focused: StaticBody3D
var pressed_target: StaticBody3D
var hold_time := 0.0
var long_action_used := false
var was_interacting := false
var capture_path := ""
var frame_count := 0
var automation := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	music.process_mode = Node.PROCESS_MODE_PAUSABLE
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var event := InputEventKey.new()
		event.physical_keycode = KEY_E
		InputMap.action_add_event("interact", event)
	gameplay = GAMEPLAY.new()
	gameplay.name = "Gameplay"
	add_child(gameplay)
	ui = UI.new()
	ui.name = "SessionUI"
	add_child(ui)
	session = SESSION.new()
	session.name = "Session"
	add_child(session)
	session.state_changed.connect(_on_state_changed)
	session.objectives_changed.connect(_on_objectives_changed)
	session.run_reset.connect(_reset_world)
	ui.action_requested.connect(_menu_action)
	$HUD/Subtitle.text = "PISO JUGABLE   /   HITO 1"
	player.spawn_position = Vector3(0, 0.07, 11.3)
	player.reset_position()
	automation = DisplayServer.get_name() == "headless"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
			automation = true
	_update_music_label()
	_on_state_changed(session.state)
	if capture_path != "" and not OS.get_cmdline_user_args().has("--capture-menu"):
		begin_run()
		if OS.get_cmdline_user_args().has("--closeup"):
			player.position = Vector3(0, 0.05, -7.8)
			player.camera.rotation.x = 0.035
		if OS.get_cmdline_user_args().has("--overview"):
			player.position = Vector3(10.8, 0.05, 3.8)
			player.rotation.y = 1.0

func begin_run() -> void:
	session.start_run()

func _reset_world() -> void:
	gameplay.reset_level()
	player.reset_position()
	_reset_interaction()
	if music.playing: music.seek(0.0)

func _menu_action(action: String) -> void:
	match action:
		"start", "retry": begin_run()
		"resume": session.resume_run()
		"menu": session.return_to_menu()
		"quit": get_tree().quit()

func _on_state_changed(state: int) -> void:
	_reset_interaction()
	get_tree().paused = state in [session.State.MENU, session.State.PAUSED, session.State.DEAD, session.State.WON]
	player.set_active(state == session.State.PLAYING)
	if state != session.State.PLAYING: player.velocity = Vector3.ZERO
	music.stream_paused = state != session.State.PLAYING
	$HUD.visible = state == session.State.PLAYING
	ui.show_state(session)
	_on_objectives_changed()
	hint.text = "WASD  MOVERSE    /    E  INTERACTUAR    /    SHIFT  CORRER    /    ESPACIO  SALTAR    /    ESC  PAUSA"
	if state == session.State.EXITING: gameplay.close_elevator()

func _on_objectives_changed() -> void:
	ui.update_objectives(session)
	gameplay.panel.update_indicators(session.installed.size())

func _reset_interaction() -> void:
	focused = null
	pressed_target = null
	hold_time = 0.0
	long_action_used = false
	was_interacting = Input.is_action_pressed("interact")
	if is_instance_valid(ui):
		ui.interaction.text = ""
		ui.progress.value = 0.0
		ui.progress.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_M:
				music.set_music_muted(not music.muted)
				_update_music_label()
			KEY_EQUAL, KEY_KP_ADD:
				music.adjust_volume(3.0)
				_update_music_label()
			KEY_MINUS, KEY_KP_SUBTRACT:
				music.adjust_volume(-3.0)
				_update_music_label()
			KEY_ESCAPE:
				if session.state == session.State.PAUSED: session.resume_run()
				else: session.pause_run()
			KEY_F9:
				if OS.is_debug_build(): session.capture("Derrota de prueba (F9). La IA de The Locust todavía no está activa.")
			KEY_F11:
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(session) and not automation:
		session.pause_run()

func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _update_music_label() -> void:
	music_label.text = "M  MÚSICA %s   /   − +  VOLUMEN %d dB" % ["OFF" if music.muted else "ON", int(music.target_volume)]

func get_focused_item() -> StaticBody3D:
	var from: Vector3 = player.camera.global_position
	var to: Vector3 = from - player.camera.global_basis.z * 2.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is ITEM and hit.collider.visible:
		return hit.collider
	return null

func _physics_process(delta: float) -> void:
	if not is_instance_valid(session) or session.state != session.State.PLAYING:
		return
	focused = get_focused_item()
	ui.interaction.text = focused.prompt(session) if is_instance_valid(focused) else ""
	var holding := Input.is_action_pressed("interact")
	var released_now := was_interacting and not holding
	if holding and not was_interacting:
		pressed_target = focused
		hold_time = 0.0
		long_action_used = false
		if is_instance_valid(focused) and focused.kind != "door":
			# Installing a fuse must never also start the elevator in the same press.
			long_action_used = focused.activate(session)
	if holding and is_instance_valid(pressed_target) and focused == pressed_target:
		hold_time += delta
		if focused.kind == "door" and hold_time >= 1.0 and not long_action_used:
			focused.activate(session, true)
			long_action_used = true
	elif not released_now:
		pressed_target = null
		hold_time = 0.0
	if released_now:
		if is_instance_valid(pressed_target) and focused == pressed_target and focused.kind == "door" and not long_action_used:
			if not focused.activate(session): ui.interaction.text = "APÁRTATE DEL UMBRAL PARA CERRAR"
		pressed_target = null
		hold_time = 0.0
	was_interacting = holding
	var eligible: bool = is_instance_valid(focused) and focused.kind == "panel" and focused == pressed_target and not long_action_used and Input.is_action_pressed("interact") and gameplay.contains_player(player.global_position)
	session.advance_exit(delta, eligible)
	ui.progress.visible = session.exit_progress > 0.0
	ui.progress.value = session.exit_progress
	if is_instance_valid(focused) and focused.kind == "panel" and session.installed.size() == 3 and not gameplay.contains_player(player.global_position):
		ui.interaction.text = "ENTRA COMPLETAMENTE EN LA CABINA"

func _process(_delta: float) -> void:
	frame_count += 1
	status.text = "PISO 01   /   %s" % ("ASCENSOR" if gameplay.contains_player(player.position) else "OBSERVACIÓN" if player.position.z < -5 else "ACCESO" if absf(player.position.x) < 3.5 else "SALAS LATERALES")
	if capture_path != "" and frame_count == 40:
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(capture_path)
		print("CAPTURE_RESULT=", error, " PATH=", capture_path)
		get_tree().quit(error)
