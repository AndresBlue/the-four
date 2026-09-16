extends CanvasLayer
signal action_requested(action: String)
var settings
var overlay: ColorRect
var column: VBoxContainer
var hint: Label
var subtitle: Label
var progress: ProgressBar
var settings_open := false
var rebind_action := ""
var rebind_button: Button
var display_label: Label
var return_action := "main"
var buttons := {}
var display_was_pending := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	hint = label(hud, "", 17)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_left = -480
	hint.offset_right = 480
	hint.offset_top = -90
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle = label(hud, "", 16)
	subtitle.position = Vector2(36, 30)
	progress = ProgressBar.new()
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	progress.offset_left = -140
	progress.offset_right = 140
	progress.offset_top = -48
	progress.offset_bottom = -42
	progress.max_value = 3
	progress.show_percentage = false
	hud.add_child(progress)
	var cross := label(hud, "·", 20)
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.035, 0.03, 0.025, 0.9)
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	column = VBoxContainer.new()
	column.custom_minimum_size = Vector2(640, 0)
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)
	settings.display_pending.connect(_display_changed)

func label(parent: Node, words: String, size := 18) -> Label:
	var result := Label.new()
	result.text = words
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", Color("e0d6bc"))
	result.add_theme_color_override("font_shadow_color", Color.BLACK)
	result.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(result)
	return result

func clear() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	buttons.clear()
	display_label = null
	rebind_action = ""

func button(parent: Node, words: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = words
	result.custom_minimum_size.y = 40
	result.add_theme_font_size_override("font_size", 17)
	result.pressed.connect(callback)
	parent.add_child(result)
	return result

func action(words: String, id: String, disabled := false) -> void:
	var result := button(column, words, func(): action_requested.emit(id))
	result.disabled = disabled
	buttons[id] = result

func menu(kind: String, can_continue := false, message := "") -> void:
	settings_open = false
	clear()
	overlay.show()
	hint.text = ""
	progress.hide()
	match kind:
		"main":
			label(column, "T H E   F O U R", 42)
			label(column, "UN HOTEL SIN RECUERDOS", 17)
			label(column, "Explora. Escucha. Encuentra la salida.\n\nPrimer piso procedural · Exploración individual\nLas criaturas todavía no persiguen al jugador.", 16)
			action("Jugar · nuevo recorrido", "new")
			action("Continuar", "continue", not can_continue)
			action("Ajustes", "settings")
			action("Créditos", "credits")
			action("Salir", "quit")
		"pause":
			label(column, "UN MOMENTO DE SILENCIO", 30)
			label(column, "Partida individual en pausa.\nContinuar desde el menú restaura el inicio de este mismo piso.", 16)
			action("Volver al hotel", "resume")
			action("Ajustes", "settings")
			action("Reintentar este piso", "retry")
			action("Menú principal", "main")
		"won":
			label(column, "ENCONTRASTE LA SALIDA", 30)
			label(column, "El hotel queda atrás. Por ahora.\n\nFin del primer piso de exploración.\nLos otros pisos y el cooperativo están en desarrollo.", 17)
			action("Explorar un nuevo recorrido", "new")
			action("Menú principal", "main")
		"failed":
			label(column, "SEÑAL PERDIDA", 32)
			label(column, "Derrota de prueba. Las criaturas aún no atacan.\nEl reintento conserva la distribución del piso.", 17)
			action("Reintentar", "retry")
			action("Menú principal", "main")
		"loading": label(column, "EL HOTEL ESTÁ TOMANDO FORMA…", 27)
		"transition": label(column, "DEJANDO EL PISO…", 30)
		"credits":
			label(column, "CRÉDITOS", 30)
			label(column, "Universo y criaturas: Doctor Nowhere.\nProyecto fan en desarrollo; no oficial.\nArquitectura y mobiliario provisional: creados para The Four.\nLocust del prototipo histórico: modelo de Doumty.\nAudio aportado por el usuario: autoría y licencias por verificar.\n\nEsta entrega usa mobiliario original provisional.\nLos permisos de distribución de los assets siguen pendientes.", 16)
			action("Volver", "main")
	if not message.is_empty():
		var info := label(column, message, 14)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size.x = 640
	if not buttons.is_empty(): buttons.values()[0].grab_focus()

func show_settings(back: String) -> void:
	clear()
	settings_open = true
	return_action = back
	overlay.show()
	label(column, "AJUSTES", 30)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(680, 400)
	column.add_child(tabs)
	var graphics := page(tabs, "Gráficos")
	check(graphics, "Pantalla completa", "fullscreen")
	options(graphics, "Resolución", "resolution", ["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440"], [0, 1, 2, 3])
	options(graphics, "Calidad", "quality", ["Baja", "Media", "Alta"], [0, 1, 2])
	slider(graphics, "Escala de render", "scale", 0.5, 1.0, 0.05)
	check(graphics, "Sombras", "shadows")
	options(graphics, "Límite de FPS", "fps", ["Sin límite", "30", "60", "120", "144"], [0, 30, 60, 120, 144])
	check(graphics, "Sincronización vertical", "vsync")
	var picture := page(tabs, "Imagen")
	for item in [["VHS", "vhs"], ["Grano", "grain"], ["Aberración cromática", "chromatic"], ["Movimiento de cámara", "bob"]]: slider(picture, item[0], item[1], 0, 1, 0.05)
	check(picture, "Efectos reducidos", "reduced")
	label(picture, "Los menús y las indicaciones no reciben el filtro VHS.\nDesenfoque de movimiento desactivado.", 14)
	var controls := page(tabs, "Controles")
	slider(controls, "Sensibilidad", "sensitivity", 0.0005, 0.008, 0.0001)
	check(controls, "Invertir mirada vertical", "invert")
	var titles := {"forward": "Adelante", "backward": "Atrás", "left": "Izquierda", "right": "Derecha", "sprint": "Correr", "jump": "Saltar", "interact": "Interactuar", "flashlight": "Linterna"}
	for id in titles:
		var row := HBoxContainer.new()
		controls.add_child(row)
		var name_label := label(row, titles[id], 16)
		name_label.custom_minimum_size.x = 280
		var key_button := Button.new()
		key_button.text = settings.key_name(id)
		key_button.custom_minimum_size = Vector2(260, 32)
		row.add_child(key_button)
		key_button.pressed.connect(func():
			rebind_action = id
			rebind_button = key_button
			key_button.text = "Pulsa una tecla · Esc cancela"
		)
	button(controls, "Restaurar controles", func():
		settings.reset_controls()
		show_settings.call_deferred(return_action)
	)
	var audio_page := page(tabs, "Audio")
	for item in [["General", "master"], ["Ambiente", "ambience"], ["Música", "music"], ["Efectos", "effects"], ["Señales de peligro", "threat"]]: slider(audio_page, item[0], item[1], 0, 1, 0.05)
	check(audio_page, "Subtítulos de sonidos relevantes", "subtitles")
	display_label = label(column, "", 14)
	var confirm_row := HBoxContainer.new()
	column.add_child(confirm_row)
	button(confirm_row, "Conservar pantalla", func(): settings.confirm_display())
	button(confirm_row, "Revertir pantalla", func(): settings.revert_display(); show_settings.call_deferred(return_action))
	button(column, "Volver", func():
		if not settings.previous_display.is_empty(): settings.revert_display()
		settings_open = false
		action_requested.emit(return_action)
	)
	_display_changed(int(ceil(settings.countdown)))

func page(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	return content

func check(parent: Node, title: String, key: String) -> void:
	var control := CheckButton.new()
	control.text = title
	control.button_pressed = settings.values[key]
	control.toggled.connect(func(value): settings.set_value(key, value))
	parent.add_child(control)

func options(parent: Node, title: String, key: String, labels: Array, values: Array) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	label(row, title, 16).custom_minimum_size.x = 280
	var control := OptionButton.new()
	control.custom_minimum_size.x = 260
	for words in labels: control.add_item(words)
	control.select(values.find(settings.values[key]))
	control.item_selected.connect(func(index): settings.set_value(key, values[index]))
	row.add_child(control)

func slider(parent: Node, title: String, key: String, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	label(row, title, 16).custom_minimum_size.x = 280
	var control := HSlider.new()
	control.custom_minimum_size = Vector2(210, 28)
	control.min_value = low
	control.max_value = high
	control.step = step
	control.value = settings.values[key]
	row.add_child(control)
	var number := label(row, "%.2f" % control.value, 14)
	control.value_changed.connect(func(value): settings.set_value(key, value); number.text = "%.2f" % value)

func _display_changed(seconds: int) -> void:
	if is_instance_valid(display_label):
		display_label.text = "Confirma la pantalla: se revertirá en %d s." % seconds if seconds > 0 else "Los ajustes se guardan en este equipo."
	var refresh := seconds == 0 and display_was_pending and settings_open
	display_was_pending = seconds > 0
	if refresh: show_settings.call_deferred(return_action)

func _input(event: InputEvent) -> void:
	if rebind_action.is_empty() or not event is InputEventKey or not event.pressed: return
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		rebind_button.text = settings.key_name(rebind_action)
		rebind_action = ""
	elif settings.bind(rebind_action, event.physical_keycode):
		rebind_button.text = settings.key_name(rebind_action)
		rebind_action = ""
	else: rebind_button.text = "Tecla reservada o ya utilizada"
