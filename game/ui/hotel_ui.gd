extends CanvasLayer
## HUD and menus in the camcorder OSD style. Screens are rebuilt from code for
## each state; layout constants live here and HUD positions in interface.tscn.
signal action_requested(action: String)
const STYLE := preload("res://game/ui/osd_style.gd")
const NOISE := preload("res://game/ui/shaders/tape_noise.gdshader")
const VERSION := "v0.5"
var settings
var overlay: Control
var column: VBoxContainer
var side: VBoxContainer
var hint: Label
var subtitle: Label
var flash_label: Label
var progress: ProgressBar
var settings_open := false
var rebind_action := ""
var rebind_button: Button
var display_label: Label
var return_action := "main"
var buttons := {}
## Text fields on the current screen, by setting key.
var fields := {}
var display_was_pending := false
## Current screen id ("main", "pause", "settings", "characters", ...).
var screen := ""
## Seconds on the floor, shown on the end screens.
var elapsed := 0.0
var sounds_enabled := true
var backdrop: TextureRect
var noise: ColorRect
var noise_amount := 0.0
var noise_floor := 0.0
var osd_left: Label
var osd_right: Label
var footer: Label
var menu_clock: Label
var body: HBoxContainer
var clock := 0.0
var flash_time := 0.0
var loading_label: Label
var tick_player: AudioStreamPlayer
var confirm_player: AudioStreamPlayer
var quiet_focus := false
var intro: Control
## Open document sheet during play, and the record of found documents.
var reading: Control
var discoveries
## Online play (net_session.gd), for the room screens.
var net
const NET := preload("res://game/net/net_session.gd")
const CATALOG := preload("res://game/discovery/discovery_catalog.gd")
var intro_tween: Tween
## Small corner note during the opening scene: which key skips it.
var skip_label: Label
## The shared sheet (paper_sheet.gd), above the HUD and below the menus.
var sheet: Control
const SHEET := preload("res://game/ui/paper_sheet.gd")
## Versus: noises The Locust player hears, drawn as rings ({point, time, strength}).
var hunter_marks: Array = []
var hunter_camera: Camera3D
var hunter_layer: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	var style := STYLE.theme()
	$HUD.theme = style
	hint = $HUD/InteractionHint
	subtitle = $HUD/Subtitle
	flash_label = $HUD/Flash
	progress = $HUD/ExitProgress
	overlay = $MenuOverlay
	overlay.theme = style
	build_frame()
	skip_label = STYLE.text("", 15)
	skip_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.offset_left = -440
	skip_label.offset_right = -36
	skip_label.offset_top = 26
	skip_label.offset_bottom = 50
	skip_label.add_theme_color_override("font_color", STYLE.SOFT)
	skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(skip_label)
	hunter_layer = Control.new()
	hunter_layer.name = "HunterMarks"
	hunter_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hunter_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hunter_layer.draw.connect(draw_hunter_marks)
	$HUD.add_child(hunter_layer)
	sheet = SHEET.new()
	add_child(sheet)
	move_child(sheet, overlay.get_index())
	tick_player = sound_player(STYLE.beep(2400.0, 0.018, 0.12))
	confirm_player = sound_player(STYLE.beep(1250.0, 0.07, 0.25))
	if settings != null: settings.display_pending.connect(_display_changed)

func sound_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Effects"
	player.volume_db = -6.0
	add_child(player)
	return player

func tick() -> void:
	if sounds_enabled and not quiet_focus: tick_player.play()

func confirm() -> void:
	if sounds_enabled: confirm_player.play()

# Persistent menu frame: backdrop, tape static, OSD corners and content columns.
func build_frame() -> void:
	backdrop = TextureRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	gradient.colors = PackedColorArray([Color(0.01, 0.01, 0.01, 0.94), Color(0.01, 0.01, 0.01, 0.72), Color(0.01, 0.01, 0.01, 0.18)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	backdrop.texture = texture
	overlay.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key in ["left", "right"]: margin.add_theme_constant_override("margin_" + key, 96)
	margin.add_theme_constant_override("margin_top", 110)
	margin.add_theme_constant_override("margin_bottom", 90)
	overlay.add_child(margin)
	body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 56)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(body)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = 520
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	body.add_child(column)
	side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 12)
	body.add_child(side)
	osd_left = corner_label(Control.PRESET_TOP_LEFT, HORIZONTAL_ALIGNMENT_LEFT, Vector2(48, 34))
	osd_right = corner_label(Control.PRESET_TOP_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(-48, 34))
	menu_clock = corner_label(Control.PRESET_BOTTOM_RIGHT, HORIZONTAL_ALIGNMENT_RIGHT, Vector2(-48, -70))
	footer = corner_label(Control.PRESET_BOTTOM_LEFT, HORIZONTAL_ALIGNMENT_LEFT, Vector2(48, -58))
	footer.add_theme_font_size_override("font_size", 15)
	footer.add_theme_color_override("font_color", STYLE.SOFT)
	noise = ColorRect.new()
	noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = NOISE
	noise.material = material
	overlay.add_child(noise)

func corner_label(preset: int, align: int, offset: Vector2) -> Label:
	var result := STYLE.text("", 28)
	result.set_anchors_preset(preset)
	result.horizontal_alignment = align
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		result.offset_left = offset.x - 520
		result.offset_right = offset.x
	else:
		result.offset_left = offset.x
		result.offset_right = offset.x + 900
	result.offset_top = offset.y
	result.offset_bottom = offset.y + 40
	overlay.add_child(result)
	return result

func label(parent: Node, words: String, size := 20) -> Label:
	var result := STYLE.text(words, size)
	parent.add_child(result)
	return result

func paragraph(parent: Node, words: String, size := 18, width := 560.0, color := STYLE.SOFT) -> Label:
	var result := STYLE.text(words, size, color)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.x = width
	parent.add_child(result)
	return result

func spacer(parent: Node, height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(gap)

## Title with a slight chroma split, like a caption burnt onto tape.
func title(parent: Node, words: String, size := 64, ink := STYLE.INK) -> void:
	var main := STYLE.text(words, size, ink)
	parent.add_child(main)
	# Colour ghosts are children drawn behind the title, so layout uses its real size.
	for shift in [[Vector2(-3, 0), Color(0.9, 0.15, 0.1, 0.55)], [Vector2(3, 0), Color(0.1, 0.75, 0.9, 0.45)]]:
		var ghost := STYLE.text(words, size, shift[1])
		ghost.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		ghost.position = shift[0]
		ghost.show_behind_parent = true
		main.add_child(ghost)

func clear() -> void:
	for container in [column, side]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	buttons.clear()
	fields.clear()
	display_label = null
	loading_label = null
	rebind_action = ""
	column.custom_minimum_size.x = 520
	side.visible = true
	noise_floor = 0.0

## Menu entry: bare text with a play cursor on focus. Returns the Button.
func entry(parent: Node, words: String, callback: Callable, disabled := false, size := 28) -> Button:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)
	var cursor := STYLE.text("▶", size - 6)
	cursor.custom_minimum_size.x = 40
	cursor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cursor.modulate.a = 0.0
	row.add_child(cursor)
	var result := Button.new()
	result.text = words.to_upper()
	result.alignment = HORIZONTAL_ALIGNMENT_LEFT
	result.add_theme_font_size_override("font_size", size)
	result.disabled = disabled
	result.focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	result.focus_entered.connect(func():
		cursor.modulate.a = 1.0
		tick()
	)
	result.focus_exited.connect(func(): cursor.modulate.a = 0.0)
	result.mouse_entered.connect(func(): if not result.disabled: result.grab_focus())
	result.pressed.connect(func():
		confirm()
		callback.call()
	)
	row.add_child(result)
	return result

func button(parent: Node, words: String, callback: Callable) -> Button:
	return entry(parent, words, callback, false, 22)

func action(words: String, id: String, disabled := false) -> void:
	buttons[id] = entry(column, words, func(): action_requested.emit(id), disabled)

func set_osd(left: String, right := "", clock_text := "", footer_text := "") -> void:
	osd_left.text = left
	osd_right.text = right
	menu_clock.text = clock_text
	footer.text = footer_text

func focus_first() -> void:
	quiet_focus = true
	for id in buttons:
		if not buttons[id].disabled:
			buttons[id].grab_focus()
			break
	quiet_focus = false

## Brief tape static and a fade-in of the new content.
func transition(strength := 0.5) -> void:
	noise_amount = maxf(noise_amount, strength)
	body.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(body, "modulate:a", 1.0, 0.28).set_delay(0.06)

func menu(kind: String, can_continue := false, message := "") -> void:
	settings_open = false
	clear()
	screen = kind
	overlay.show()
	hint.text = ""
	flash_label.text = ""
	progress.hide()
	backdrop.modulate.a = 1.0
	match kind:
		"main":
			set_osd("▶ PLAY", "", "12:00", "")
			title(column, "THE FOUR", 104)
			label(column, "H  O  T  E  L", 24).add_theme_color_override("font_color", STYLE.SOFT)
			spacer(column, 40)
			action("Nueva partida", "new")
			action("Continuar", "continue", not can_continue)
			action("Multijugador", "multiplayer")
			action("Archivo", "archive")
			action("Ajustes", "settings")
			action("Créditos", "credits")
			action("Salir", "quit")
		"pause":
			set_osd("❚❚ PAUSA", "", "", "")
			backdrop.modulate.a = 0.9
			title(column, "PAUSA", 72)
			spacer(column, 28)
			action("Continuar", "resume")
			action("Ajustes", "settings")
			action("Reintentar piso", "retry")
			action("Menú principal", "main")
			controls_panel(side)
		"won":
			set_osd("■ STOP", "", "", "")
			title(column, "SALISTE DEL PISO", 58)
			spacer(column, 8)
			label(column, "TIEMPO DE GRABACIÓN  %s" % tape_time(elapsed), 24).add_theme_color_override("font_color", STYLE.AMBER)
			spacer(column, 10)
			paragraph(column, "El hotel queda atrás. Por ahora.")
			spacer(column, 28)
			action("Nueva partida", "new")
			action("Menú principal", "main")
		"failed":
			set_osd("SEÑAL PERDIDA", "", "", "")
			osd_left.add_theme_color_override("font_color", STYLE.ALERT)
			noise_floor = 0.16
			title(column, "SEÑAL PERDIDA", 70, STYLE.ALERT)
			spacer(column, 8)
			label(column, "TIEMPO DE GRABACIÓN  %s" % tape_time(elapsed), 22).add_theme_color_override("font_color", STYLE.SOFT)
			spacer(column, 28)
			action("Reintentar", "retry")
			action("Menú principal", "main")
		"loading":
			set_osd("◀◀ REW", "", "", "")
			title(column, "CARGANDO CINTA", 58)
			spacer(column, 6)
			loading_label = label(column, "EL HOTEL ESTÁ TOMANDO FORMA", 22)
			loading_label.add_theme_color_override("font_color", STYLE.SOFT)
			controls_panel(side)
		"transition":
			set_osd("■ STOP", "", "", "")
			title(column, "FIN DEL PISO", 64)
			side.visible = false
		"archive":
			set_osd("▶ PLAY", "", "", "")
			title(column, "ARCHIVO", 64)
			var count: int = discoveries.found.size() if discoveries != null else 0
			label(column, "DOCUMENTOS  %d / %d" % [count, CATALOG.TOTAL], 20).add_theme_color_override("font_color", STYLE.AMBER)
			spacer(column, 14)
			var shown := false
			for item in CATALOG.ENTRIES:
				var known: bool = discoveries != null and discoveries.has(item.id)
				var entry_data: Dictionary = item
				buttons[item.id] = entry(column, item.title if known else "— sin descubrir —", func(): show_archive_entry(entry_data), not known, 22)
				if known and not shown:
					show_archive_entry(item)
					shown = true
			if not shown: paragraph(side, "Los documentos que leas en el hotel se guardan aquí, también entre partidas.", 18, 560)
			spacer(column, 20)
			action("Volver", "main")
		"multiplayer":
			set_osd("MENU ▸ MULTIJUGADOR", "", "", "")
			title(column, "MULTIJUGADOR", 64)
			label(column, "DE 2 A %d JUGADORES · LAN O IP" % NET.MAX_PLAYERS, 20).add_theme_color_override("font_color", STYLE.SOFT)
			spacer(column, 18)
			field(column, "Tu nombre", "player_name", "Jugador")
			spacer(column, 10)
			action("Crear sala", "host")
			action("Unirse a una sala", "join")
			action("Personaje", "characters")
			spacer(column, 12)
			action("Volver", "main")
			paragraph(side, "Quien crea la sala es el anfitrión: elige el tipo de partida y, en versus, quién es The Locust. Los demás se unen con su dirección IP (en la misma red, la local; por Internet, la pública con el puerto %d UDP abierto)." % NET.PORT, 18, 560)
		"join":
			set_osd("MULTIJUGADOR ▸ UNIRSE", "", "", "")
			title(column, "UNIRSE", 64)
			spacer(column, 18)
			field(column, "Dirección del anfitrión", "join_address", "192.168.1.20")
			spacer(column, 10)
			if net != null and net.active():
				label(column, net.status if not net.status.is_empty() else "Conectando…", 20).add_theme_color_override("font_color", STYLE.AMBER)
			else: action("Conectar", "connect")
			spacer(column, 12)
			action("Volver", "lobby_leave" if net != null and net.active() else "multiplayer")
			side.visible = false
		"lobby":
			lobby_screen()
		"online_pause":
			set_osd("❚❚ MENÚ", "", "", "LA PARTIDA SIGUE")
			backdrop.modulate.a = 0.75
			title(column, "MENÚ", 72)
			label(column, "LA PARTIDA NO SE DETIENE", 20).add_theme_color_override("font_color", STYLE.AMBER)
			spacer(column, 24)
			action("Continuar", "online_resume")
			action("Ajustes", "online_settings")
			action("Cerrar la sala" if net != null and net.is_host else "Salir de la partida", "online_quit")
			controls_panel(side)
		"online_won", "online_failed":
			online_end(kind == "online_won")
		"credits":
			set_osd("▶ PLAY", "", "", "%s  ·  PROYECTO FAN NO OFICIAL" % VERSION)
			title(column, "CRÉDITOS", 64)
			spacer(column, 18)
			column.custom_minimum_size.x = 720
			for block in [["THE LOCUST", "Modelo de Doumty."], ["ARQUITECTURA Y MOBILIARIO", "Arquitectura creada para The Four. Televisor, cama, sofá, lámpara de pared y monstera: modelos aportados por el usuario; autoría y licencias por verificar."], ["AUDIO", "Aportado por el usuario. Autoría y licencias por verificar."], ["DISTRIBUCIÓN", "Los permisos de los assets siguen pendientes."]]:
				label(column, block[0], 18).add_theme_color_override("font_color", STYLE.AMBER)
				paragraph(column, block[1], 18, 700)
				spacer(column, 6)
			spacer(column, 16)
			action("Volver", "main")
			side.visible = false
	if osd_left.text != "SEÑAL PERDIDA": osd_left.remove_theme_color_override("font_color")
	if not message.is_empty():
		spacer(column, 14)
		paragraph(column, message, 16, 560, STYLE.AMBER)
	transition(0.35 if kind != "failed" else 0.9)
	focus_first()

## A text field bound to a setting (saved as it is typed).
func field(parent: Node, title_text: String, key: String, placeholder: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	label(row, title_text, 19).custom_minimum_size.x = 240
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(300, 40)
	edit.add_theme_font_size_override("font_size", 20)
	edit.placeholder_text = placeholder
	edit.text = settings.values[key]
	edit.max_length = 40
	edit.text_changed.connect(func(value): settings.set_value(key, value))
	row.add_child(edit)
	fields[key] = edit
	return edit

## The room: who is in, the host's options and the way into the match.
func lobby_screen() -> void:
	var hosting: bool = net.is_host
	set_osd("MULTIJUGADOR ▸ SALA", "", "", "ANFITRIÓN" if hosting else "")
	title(column, "SALA", 64)
	var seats: Array = net.players.keys()
	seats.sort()
	label(column, "JUGADORES  %d / %d" % [net.connected_seats().size(), NET.MAX_PLAYERS], 20).add_theme_color_override("font_color", STYLE.AMBER)
	spacer(column, 12)
	# Options: editable by the host, shown as text to the others.
	var mode: int = int(net.options.mode)
	if hosting:
		choice(column, "Tipo de partida", NET.MODE_NAMES, mode, func(index): net.set_option("mode", index))
		if mode == NET.Mode.VERSUS:
			var names: Array = ["Al azar"]
			var ids: Array = [NET.RANDOM]
			for seat in net.connected_seats():
				names.append(net.player_name(seat))
				ids.append(seat)
			choice(column, "The Locust", names, maxi(0, ids.find(int(net.options.locust))), func(index): net.set_option("locust", ids[index]))
		if not net.match_net.saved_checkpoint().is_empty():
			var resume := CheckButton.new()
			resume.text = "Retomar el piso guardado"
			resume.add_theme_font_size_override("font_size", 19)
			resume.button_pressed = net.options.get("resume", false)
			resume.toggled.connect(func(value): tick(); net.set_option("resume", value))
			column.add_child(resume)
	else:
		label(column, NET.MODE_NAMES[mode], 20)
		if mode == NET.Mode.VERSUS:
			label(column, "The Locust: %s" % ("al azar" if int(net.options.locust) == NET.RANDOM else net.player_name(int(net.options.locust))), 20)
	spacer(column, 18)
	if hosting:
		var problem: String = net.start_problem()
		action("Empezar", "lobby_start", not problem.is_empty())
		if not problem.is_empty(): label(column, problem, 17).add_theme_color_override("font_color", STYLE.SOFT)
	else:
		label(column, "Esperando a que el anfitrión empiece…", 19).add_theme_color_override("font_color", STYLE.SOFT)
	action("Personaje", "lobby_character")
	action("Cerrar la sala" if hosting else "Salir de la sala", "lobby_leave")
	# Seats on the right.
	var visual_script := preload("res://game/player/avatars/avatar_visual.gd")
	for seat in seats:
		var entry_data: Dictionary = net.players[seat]
		var tags: Array = []
		if seat == 1: tags.append("anfitrión")
		if seat == net.local_seat: tags.append("tú")
		if not entry_data.connected: tags.append("desconectado")
		if mode == NET.Mode.VERSUS and int(net.options.locust) == seat: tags.append("The Locust")
		var line := label(side, "%d · %s" % [seat, entry_data.name.to_upper()], 22)
		if seat == net.local_seat: line.add_theme_color_override("font_color", STYLE.AMBER)
		paragraph(side, "%s%s" % [visual_script.NAMES[clampi(int(entry_data.character), 0, 2)], ("  ·  " + ", ".join(tags)) if not tags.is_empty() else ""], 16, 560)
	if hosting:
		spacer(side, 14)
		var addresses: Array = NET.local_addresses()
		paragraph(side, "Para unirse: %s · puerto %d" % [" / ".join(addresses) if not addresses.is_empty() else "tu IP", NET.PORT], 17, 560, STYLE.AMBER)

func choice(parent: Node, title_text: String, labels: Array, selected: int, on_pick: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	label(row, title_text, 19).custom_minimum_size.x = 240
	var control := OptionButton.new()
	control.custom_minimum_size.x = 420
	control.add_theme_font_size_override("font_size", 19)
	for words in labels: control.add_item(words)
	control.select(selected)
	control.item_selected.connect(func(index): tick(); on_pick.call(index))
	row.add_child(control)

## End of an online floor. Only the host chooses what comes next.
func online_end(won: bool) -> void:
	var hunter: bool = net.match_net.local_is_locust()
	var headline := ("SE TE ESCAPARON" if hunter else "SALISTE DEL PISO") if won else ("CAZA COMPLETA" if hunter else "SEÑAL PERDIDA")
	var bad := won == hunter
	set_osd("■ STOP" if not bad else "SEÑAL PERDIDA", "", "", "")
	if bad: osd_left.add_theme_color_override("font_color", STYLE.ALERT)
	title(column, headline, 58, STYLE.ALERT if bad else STYLE.INK)
	spacer(column, 8)
	label(column, "TIEMPO DE GRABACIÓN  %s" % tape_time(elapsed), 22).add_theme_color_override("font_color", STYLE.SOFT)
	spacer(column, 28)
	if net.is_host:
		if not won: action("Reintentar piso", "online_retry")
		action("Nueva partida", "online_new")
		action("Volver a la sala", "online_room")
		action("Cerrar la sala", "online_quit")
	else:
		label(column, "El anfitrión decide cómo seguir…", 19).add_theme_color_override("font_color", STYLE.SOFT)
		action("Salir de la sala", "online_quit")
	side.visible = false

func show_archive_entry(item: Dictionary) -> void:
	for child in side.get_children():
		side.remove_child(child)
		child.queue_free()
	label(side, item.title.to_upper(), 26)
	label(side, item.header, 16).add_theme_color_override("font_color", STYLE.SOFT)
	spacer(side, 8)
	paragraph(side, item.body, 19, 620, STYLE.INK)

## A document held up to the camera while play goes on behind it.
func show_document(item: Dictionary) -> void:
	hide_document()
	reading = Control.new()
	reading.name = "Document"
	reading.set_anchors_preset(Control.PRESET_FULL_RECT)
	reading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reading)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reading.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reading.add_child(center)
	var sheet := PanelContainer.new()
	sheet.custom_minimum_size = Vector2(720, 0)
	sheet.add_theme_stylebox_override("panel", STYLE.flat(Color(0.05, 0.05, 0.045, 0.92), STYLE.FAINT, 1, 34.0))
	center.add_child(sheet)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 8)
	sheet.add_child(text)
	label(text, item.title.to_upper(), 28)
	label(text, item.header, 16).add_theme_color_override("font_color", STYLE.SOFT)
	spacer(text, 6)
	paragraph(text, item.body, 20, 640, STYLE.INK)
	spacer(text, 10)
	var key: String = settings.key_name("interact") if settings != null else "E"
	label(text, "[%s] GUARDAR" % key, 16).add_theme_color_override("font_color", STYLE.FAINT)

func hide_document() -> void:
	if is_instance_valid(reading): reading.queue_free()
	reading = null

func tape_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]

func controls_panel(parent: Node) -> void:
	if settings == null: return
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.custom_minimum_size.x = 420
	parent.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	panel.add_child(list)
	label(list, "CONTROLES", 20).add_theme_color_override("font_color", STYLE.AMBER)
	spacer(list, 4)
	var moves := "%s %s %s %s" % [settings.key_name("forward"), settings.key_name("left"), settings.key_name("backward"), settings.key_name("right")]
	for row in [[moves, "Moverse"], ["RATÓN", "Mirar"], [settings.key_name("sprint"), "Correr"], [settings.key_name("crouch"), "Agacharse"], [settings.key_name("jump"), "Saltar"], [settings.key_name("interact"), "Puertas y escondites"], [settings.key_name("interact") + " MANTENER", "Abrir despacio · Salir del refugio"], [settings.key_name("flashlight"), "Linterna"], [settings.key_name("sheet"), "Hoja (dibujar y borrar con el ratón)"], ["ESC", "Pausa"]]:
		var line := HBoxContainer.new()
		list.add_child(line)
		var key := label(line, row[0].to_upper(), 17)
		key.custom_minimum_size.x = 190
		label(line, row[1], 17).add_theme_color_override("font_color", STYLE.SOFT)

func show_settings(back: String) -> void:
	clear()
	screen = "settings"
	settings_open = true
	return_action = back
	overlay.show()
	backdrop.modulate.a = 1.0
	set_osd("MENU ▸ AJUSTES", "", "", "")
	side.visible = false
	column.custom_minimum_size.x = 1000
	title(column, "AJUSTES", 58)
	spacer(column, 10)
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(1000, 380)
	tabs.add_theme_font_size_override("font_size", 20)
	column.add_child(tabs)
	var graphics := page(tabs, "GRÁFICOS")
	check(graphics, "Pantalla completa", "fullscreen")
	options(graphics, "Tamaño de ventana", "resolution", ["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440"], [0, 1, 2, 3], settings.values.fullscreen)
	options(graphics, "Calidad", "quality", ["Baja", "Media", "Alta"], [0, 1, 2])
	slider(graphics, "Escala de render", "scale", 0.5, 1.0, 0.05)
	check(graphics, "Sombras", "shadows")
	options(graphics, "Límite de FPS", "fps", ["Sin límite", "30", "60", "120", "144"], [0, 30, 60, 120, 144])
	check(graphics, "Sincronización vertical", "vsync")
	var picture := page(tabs, "IMAGEN")
	for item in [["Cinta VHS", "vhs"], ["Grano", "grain"], ["Aberración cromática", "chromatic"], ["Líneas de barrido", "scanlines"], ["Movimiento de cámara", "bob"]]: slider(picture, item[0], item[1], 0, 1, 0.05)
	check(picture, "Marcas de videocámara (REC, fecha y hora)", "osd")
	check(picture, "Efectos reducidos", "reduced")
	var controls := page(tabs, "CONTROLES")
	slider(controls, "Sensibilidad", "sensitivity", 0.0005, 0.008, 0.0001)
	check(controls, "Invertir mirada vertical", "invert")
	var titles := {"forward": "Adelante", "backward": "Atrás", "left": "Izquierda", "right": "Derecha", "sprint": "Correr", "jump": "Saltar", "interact": "Interactuar", "flashlight": "Linterna", "crouch": "Agacharse", "sheet": "Hoja"}
	for id in titles:
		var row := HBoxContainer.new()
		controls.add_child(row)
		label(row, titles[id], 19).custom_minimum_size.x = 340
		var key_button := Button.new()
		key_button.theme_type_variation = "BoxButton"
		key_button.text = settings.key_name(id)
		key_button.custom_minimum_size = Vector2(300, 38)
		row.add_child(key_button)
		key_button.pressed.connect(func():
			confirm()
			rebind_action = id
			rebind_button = key_button
			key_button.text = "PULSA UNA TECLA · ESC CANCELA"
		)
	var reset := Button.new()
	reset.theme_type_variation = "BoxButton"
	reset.text = "RESTAURAR CONTROLES"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func():
		confirm()
		settings.reset_controls()
		show_settings.call_deferred(return_action)
	)
	controls.add_child(reset)
	var audio_page := page(tabs, "AUDIO")
	for item in [["General", "master"], ["Ambiente", "ambience"], ["Música", "music"], ["Efectos", "effects"], ["Señales de peligro", "threat"]]: slider(audio_page, item[0], item[1], 0, 1, 0.05)
	check(audio_page, "Subtítulos de sonidos relevantes", "subtitles")
	display_label = paragraph(column, "", 16, 900, STYLE.AMBER)
	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 12)
	column.add_child(confirm_row)
	for pair in [["CONSERVAR PANTALLA", func(): settings.confirm_display()], ["REVERTIR PANTALLA", func(): settings.revert_display(); show_settings.call_deferred(return_action)]]:
		var box := Button.new()
		box.theme_type_variation = "BoxButton"
		box.text = pair[0]
		box.pressed.connect(pair[1])
		confirm_row.add_child(box)
	var leave := func():
		if not settings.previous_display.is_empty(): settings.revert_display()
		settings_open = false
		action_requested.emit(return_action)
	buttons["back"] = entry(column, "Volver", leave, false, 24)
	_display_changed(int(ceil(settings.countdown)))
	transition(0.3)
	quiet_focus = true
	tabs.get_tab_bar().grab_focus()
	quiet_focus = false

func page(tabs: TabContainer, title_text: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title_text
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	return content

func check(parent: Node, title_text: String, key: String) -> void:
	var control := CheckButton.new()
	control.text = title_text
	control.add_theme_font_size_override("font_size", 19)
	control.button_pressed = settings.values[key]
	control.toggled.connect(func(value):
		tick()
		settings.set_value(key, value)
		# The window size only applies outside fullscreen; refresh its state.
		if key == "fullscreen": show_settings.call_deferred(return_action)
	)
	parent.add_child(control)

func options(parent: Node, title_text: String, key: String, labels: Array, values: Array, disabled := false) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	label(row, title_text, 19).custom_minimum_size.x = 340
	var control := OptionButton.new()
	control.custom_minimum_size.x = 300
	control.add_theme_font_size_override("font_size", 19)
	for words in labels: control.add_item(words)
	control.select(values.find(settings.values[key]))
	control.disabled = disabled
	control.item_selected.connect(func(index): tick(); settings.set_value(key, values[index]))
	row.add_child(control)

func slider(parent: Node, title_text: String, key: String, low: float, high: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	label(row, title_text, 19).custom_minimum_size.x = 340
	var control := HSlider.new()
	control.custom_minimum_size = Vector2(300, 30)
	control.min_value = low
	control.max_value = high
	control.step = step
	control.value = settings.values[key]
	row.add_child(control)
	# Sliders from 0 to 1 read as percentages; others show their raw value.
	var percent := low == 0.0 and high == 1.0
	var number := label(row, ("%d%%" % roundi(control.value * 100)) if percent else ("%.4f" % control.value), 17)
	number.add_theme_color_override("font_color", STYLE.SOFT)
	control.value_changed.connect(func(value): settings.set_value(key, value); number.text = ("%d%%" % roundi(value * 100)) if percent else ("%.4f" % value))

func show_characters(back := "multiplayer") -> void:
	clear()
	screen = "characters"
	overlay.show()
	set_osd("MULTIJUGADOR ▸ PERSONAJE", "", "", "")
	title(column, "PERSONAJE", 64)
	spacer(column, 24)
	var visual_script := preload("res://game/player/avatars/avatar_visual.gd")
	var visual := visual_script.new()
	var chosen := STYLE.text("", 20, STYLE.AMBER)
	for index in visual_script.NAMES.size():
		buttons["character_%d" % index] = entry(column, visual_script.NAMES[index], func():
			settings.set_value("character", index)
			if net != null and net.active(): net.set_character(index)
			visual.configure(index, false)
			chosen.text = "SELECCIONADO · %s" % visual_script.NAMES[index].to_upper()
		)
	spacer(column, 18)
	action("Volver", back)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(460, 500)
	container.stretch = true
	container.size_flags_horizontal = Control.SIZE_SHRINK_END
	side.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(460, 500)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var preview := Node3D.new()
	viewport.add_child(preview)
	visual.character = settings.values.character
	preview.add_child(visual)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_CLEAR_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("d8c9a8")
	world.environment.ambient_light_energy = 0.45
	world.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	preview.add_child(world)
	var key_light := SpotLight3D.new()
	key_light.position = Vector3(1.4, 2.6, -2.2)
	key_light.light_color = Color("ffcf94")
	key_light.light_energy = 6.0
	key_light.spot_range = 8.0
	key_light.spot_angle = 35.0
	preview.add_child(key_light)
	key_light.look_at_from_position(key_light.position, Vector3(0, 1.0, 0))
	var camera := Camera3D.new()
	preview.add_child(camera)
	camera.position = Vector3(0.35, 1.05, -3.3)
	camera.look_at(Vector3(0, 0.92, 0))
	camera.fov = 38
	chosen.text = "SELECCIONADO · %s" % visual_script.NAMES[settings.values.character].to_upper()
	chosen.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chosen.size_flags_horizontal = Control.SIZE_SHRINK_END
	side.add_child(chosen)
	transition(0.35)
	quiet_focus = true
	buttons["character_%d" % settings.values.character].grab_focus()
	quiet_focus = false

## Short OSD message in the top-left corner of the recording.
## Shows the skip key in the top right corner, fading out after a few seconds.
func show_skip(key: String, seconds := 6.0) -> void:
	skip_label.text = "%s  para saltar cinemática" % key
	skip_label.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_interval(seconds)
	fade.tween_property(skip_label, "modulate:a", 0.0, 1.2)

func hide_skip() -> void:
	skip_label.text = ""

func flash(words: String, seconds := 2.5) -> void:
	flash_label.text = words
	flash_time = seconds

## Heard noises as widening rings where they came from; off-screen ones sit on
## the nearest edge of the picture.
func draw_hunter_marks() -> void:
	if hunter_marks.is_empty() or not is_instance_valid(hunter_camera): return
	var now := Time.get_ticks_msec() / 1000.0
	var rect := hunter_layer.get_rect().grow(-40.0)
	for mark in hunter_marks:
		var age: float = now - mark.time
		var fade := clampf(1.0 - age / 1.6, 0.0, 1.0)
		var point: Vector3 = mark.point
		var screen_point: Vector2
		if hunter_camera.is_position_behind(point):
			var local := hunter_camera.global_transform.affine_inverse() * point
			screen_point = rect.get_center() + Vector2(local.x, -local.y).normalized() * rect.size.length()
		else: screen_point = hunter_camera.unproject_position(point)
		screen_point = screen_point.clamp(rect.position, rect.end)
		var radius: float = lerpf(8.0, 46.0, clampf(age / 1.6, 0.0, 1.0)) * (0.6 + mark.strength * 0.6)
		hunter_layer.draw_arc(screen_point, radius, 0.0, TAU, 32, Color(0.9, 0.15, 0.1, fade * 0.85), 3.0, true)
		hunter_layer.draw_arc(screen_point, radius * 0.45, 0.0, TAU, 24, Color(0.9, 0.2, 0.15, fade * 0.5), 2.0, true)

func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(hunter_layer):
		if not hunter_marks.is_empty() or hunter_layer.get_meta("drawn", false): hunter_layer.queue_redraw()
		hunter_layer.set_meta("drawn", not hunter_marks.is_empty())
	noise_amount = move_toward(noise_amount, noise_floor, delta * 2.2)
	(noise.material as ShaderMaterial).set_shader_parameter("amount", noise_amount if overlay.visible else 0.0)
	if screen == "main" and overlay.visible:
		menu_clock.modulate.a = 1.0 if fposmod(clock, 1.0) < 0.55 else 0.0
	else:
		menu_clock.modulate.a = 1.0
	osd_left.modulate.a = 1.0 if screen != "failed" or fposmod(clock, 1.0) < 0.6 else 0.25
	if is_instance_valid(loading_label):
		loading_label.text = "EL HOTEL ESTÁ TOMANDO FORMA" + ".".repeat(int(clock * 3.0) % 4)
	if flash_time > 0:
		flash_time -= delta
		flash_label.modulate.a = 1.0 if flash_time > 1.0 or fposmod(flash_time, 0.4) < 0.25 else 0.0
		if flash_time <= 0: flash_label.text = ""

func _display_changed(seconds: int) -> void:
	if is_instance_valid(display_label):
		display_label.text = "Confirma la pantalla: se revertirá en %d s." % seconds if seconds > 0 else ""
	var refresh := seconds == 0 and display_was_pending and settings_open
	display_was_pending = seconds > 0
	if refresh: show_settings.call_deferred(return_action)

func _input(event: InputEvent) -> void:
	if is_instance_valid(intro) and event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		finish_intro()
		return
	if rebind_action.is_empty() or not event is InputEventKey or not event.pressed: return
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		rebind_button.text = settings.key_name(rebind_action)
		rebind_action = ""
	elif settings.bind(rebind_action, event.physical_keycode):
		rebind_button.text = settings.key_name(rebind_action)
		rebind_action = ""
	else: rebind_button.text = "TECLA RESERVADA O EN USO"

## Boot sequence: VCR blue screen with PLAY, then a long stretch of tape static
## into the menu. A key skips it; mouse clicks do not.
func play_intro() -> void:
	if is_instance_valid(intro): finish_intro()
	intro = Control.new()
	intro.name = "Intro"
	intro.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(intro)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro.add_child(black)
	var blue := ColorRect.new()
	blue.color = STYLE.VCR_BLUE
	blue.set_anchors_preset(Control.PRESET_FULL_RECT)
	blue.modulate.a = 0.0
	intro.add_child(blue)
	var channel := STYLE.text("VIDEO 1", 34)
	channel.position = Vector2(56, 40)
	blue.add_child(channel)
	var play := STYLE.text("▶ PLAY", 44)
	play.set_anchors_preset(Control.PRESET_CENTER)
	play.offset_left = -120
	play.offset_right = 120
	play.offset_top = -30
	play.offset_bottom = 30
	play.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blue.add_child(play)
	var static_layer := ColorRect.new()
	static_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	static_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = NOISE
	static_layer.material = material
	intro.add_child(static_layer)
	var hiss := AudioStreamPlayer.new()
	hiss.bus = "Effects"
	hiss.stream = load("res://assets/audio/intro/tv_static.wav")
	hiss.volume_db = -60.0
	intro.add_child(hiss)
	var amount := func(value: float) -> void: material.set_shader_parameter("amount", value)
	intro_tween = create_tween()
	intro_tween.tween_interval(0.6)
	intro_tween.tween_callback(func(): if sounds_enabled: confirm_player.play())
	intro_tween.tween_property(blue, "modulate:a", 1.0, 0.05)
	intro_tween.tween_interval(1.8)
	# The picture breaks up slowly into static, holds, and clears into the menu.
	intro_tween.tween_callback(func(): if sounds_enabled: hiss.play())
	intro_tween.parallel().tween_property(hiss, "volume_db", -16.0, 0.9)
	intro_tween.parallel().tween_method(amount, 0.0, 0.65, 0.9)
	intro_tween.tween_method(amount, 0.65, 1.0, 0.5)
	intro_tween.tween_callback(func(): blue.hide(); black.hide())
	intro_tween.tween_interval(0.5)
	intro_tween.tween_method(amount, 1.0, 0.0, 1.6).set_trans(Tween.TRANS_SINE)
	intro_tween.parallel().tween_property(hiss, "volume_db", -60.0, 1.6)
	intro_tween.tween_callback(finish_intro)

func finish_intro() -> void:
	if is_instance_valid(intro_tween): intro_tween.kill()
	if is_instance_valid(intro):
		intro.queue_free()
		intro = null
		transition(0.6)
		focus_first()
