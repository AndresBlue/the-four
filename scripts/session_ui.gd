extends CanvasLayer

signal action_requested(action: String)
var overlay: ColorRect
var title_label: Label
var body_label: Label
var buttons: VBoxContainer
var button_by_action: Dictionary = {}
var objective: Label
var interaction: Label
var progress: ProgressBar
var notice: Label
var play_hud: Control

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	play_hud = Control.new()
	play_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(play_hud)
	objective = make_label(play_hud, "", 19)
	objective.position = Vector2(38, 99)
	interaction = make_label(play_hud, "", 17)
	interaction.position = Vector2(250, 562)
	interaction.size = Vector2(780, 34)
	interaction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress = ProgressBar.new()
	progress.position = Vector2(440, 602)
	progress.size = Vector2(400, 9)
	progress.show_percentage = false
	progress.max_value = 3.0
	play_hud.add_child(progress)
	notice = make_label(play_hud, "", 14)
	notice.position = Vector2(38, 144)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.032, 0.025, 0.89)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(560, 0)
	column.add_theme_constant_override("separation", 22)
	center.add_child(column)
	title_label = make_label(column, "THE FOUR", 38)
	body_label = make_label(column, "", 17)
	body_label.custom_minimum_size.x = 560
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)

func make_label(parent: Node, words: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = words
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.88, 0.87, 0.76))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func menu_button(words: String, action: String) -> void:
	var button := Button.new()
	button.text = words
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(func(): action_requested.emit(action))
	buttons.add_child(button)
	button_by_action[action] = button
	if button_by_action.size() == 1: button.grab_focus()

func show_state(session) -> void:
	for child in buttons.get_children():
		buttons.remove_child(child)
		child.queue_free()
	button_by_action.clear()
	overlay.visible = session.state != session.State.PLAYING
	play_hud.visible = session.state == session.State.PLAYING
	match session.state:
		session.State.MENU:
			title_label.text = "T H E   F O U R"
			body_label.text = "PISO 01 / RESTABLECE LA ENERGÍA\n\nEncuentra los tres fusibles en las salas, instálalos en el panel y activa el ascensor desde dentro.\n\nWASD · Moverse     Ratón · Mirar     E · Interactuar\nShift · Correr     Espacio · Saltar     Esc · Pausa\n\nEn esta versión, The Locust permanece estático."
			menu_button("Entrar al piso", "start")
			menu_button("Salir del juego", "quit")
		session.State.PAUSED:
			title_label.text = "EN PAUSA"
			body_label.text = "La partida está detenida.\n\nFusibles instalados: %d / 3\nFusibles en inventario: %d" % [session.installed.size(), session.carried.size()]
			menu_button("Continuar", "resume")
			menu_button("Reiniciar piso", "retry")
			menu_button("Volver al menú", "menu")
			menu_button("Salir del juego", "quit")
		session.State.DYING:
			title_label.text = "SEÑAL PERDIDA"
			body_label.text = session.death_cause
		session.State.DEAD:
			title_label.text = "NO LOGRASTE SALIR"
			body_label.text = session.death_cause + "\n\nAl reintentar, el piso y sus objetos vuelven al estado inicial."
			menu_button("Reintentar piso", "retry")
			menu_button("Volver al menú", "menu")
			menu_button("Salir del juego", "quit")
		session.State.EXITING:
			title_label.text = "ASCENSOR ACTIVADO"
			body_label.text = "Cerrando la cabina…"
			overlay.color.a = 0.35
		session.State.WON:
			title_label.text = "PISO SUPERADO"
			body_label.text = "Restableciste la energía y activaste el ascensor.\n\nTiempo: %02d:%02d\n\nFin del primer piso de prueba. Los siguientes pisos están en desarrollo." % [int(session.elapsed) / 60, int(session.elapsed) % 60]
			menu_button("Jugar de nuevo", "retry")
			menu_button("Volver al menú", "menu")
			menu_button("Salir del juego", "quit")
	if session.state != session.State.EXITING:
		overlay.color.a = 0.89

func update_objectives(session) -> void:
	objective.text = "FUSIBLES INSTALADOS  %d / 3     ·     EN INVENTARIO  %d" % [session.installed.size(), session.carried.size()]
	if session.installed.size() == 3:
		notice.text = "ENERGÍA RESTABLECIDA · Vuelve a la cabina y mantén E sobre el panel."
	elif session.carried.size() + session.installed.size() == 3:
		notice.text = "Tienes todos los fusibles. Regresa al ascensor."
	else:
		notice.text = "Explora las salas laterales. Las botoneras abren sus puertas."
