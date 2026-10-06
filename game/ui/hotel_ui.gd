extends CanvasLayer
## HUD and menus in the camcorder OSD style. Screens are rebuilt from code for
## each state; layout constants live here and HUD positions in interface.tscn.
signal action_requested(action: String)
const STYLE := preload("res://game/ui/osd_style.gd")
const NOISE := preload("res://game/ui/shaders/tape_noise.gdshader")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const VERSION := "v0.5"
## The credits, as they roll: a heading and its lines. Everything the game
## ships that somebody else made is named here, with its licence, and what is
## still unresolved is said out loud. The register of them all, with links and
## the conditions of each one, is docs/ASSETS.md.
const CREDITS := [
	["THE FOUR", [
		"Proyecto fan no oficial, sin ánimo de lucro.",
		"Arquitectura del hotel, generación del piso, cámara de vídeo doméstica, shaders, iluminación, sonido sintetizado, red y código: creados para este juego.",
	]],
	["MOTOR", [
		"Godot Engine 4.7 — © 2014-2026 Juan Linietsky, Ariel Manzur y colaboradores. Licencia MIT.",
		"GodotSteam 4.22.1 — © 2015-actualidad GP Garcia, Chris Ridenour y colaboradores. Licencia MIT.",
		"Steamworks SDK — © Valve Corporation. Steam y el logotipo de Steam son marcas de Valve Corporation.",
	]],
	["PERSONAJES", [
		"The Locust — modelo de Doumty, personaje de Doctor Nowhere (Sketchfab, CC BY-NC-ND).",
		"«detective» — haider706 (Sketchfab, CC BY 4.0).",
		"«Debra — Detective Woman (Game Model)» — Zukomazi (Sketchfab, CC BY 4.0).",
		"«Realistic Female» — Biviyt (Sketchfab, CC BY-SA 4.0).",
	]],
	["MOBILIARIO Y OBJETOS", [
		"Poly Haven, CC0: Kirill Sannikov, James Ray Cock, Ulan Cabanilla, Rico Cilliers, Kuutti Siitonen, Fran Calvente, Yann Kervran, Vibrant Nordic, Ulrich Büch, Rob Tuytel, Rahul Chaudhary, ProgrammerOnCoffee, PierreB3D, Maximilian Schuster, Mateusz Sadek, Luca B, Jurita Burger, Jule Bielitz, John Malcolm, Joe Seabuhr, GurJas Studios, Fabi_G, Caspian Fortune, Benny Weimer y Slinc.",
		"«Sofa (Game Ready / 2K PBR)» — Meerschaum Digital, sobre «Old Sofa (FREE)» de VISJA FILIP RUMIN (Sketchfab, CC BY).",
		"«Monstera Deliciosa Potted Mid-Century plant» — Giora / ChubbyPanda (Sketchfab, CC BY).",
		"«Wall Lamp — 2048px²» — Mark Peters (Sketchfab, CC BY).",
		"«Elevator with Animation LOWPOLY» — EFX (Sketchfab, CC BY): el ascensor.",
		"Televisor, cama de la escena de entrada, puerta de madera y armario: aportados por el usuario; autoría y licencia pendientes de verificar.",
	]],
	["MATERIALES", [
		"ambientCG — Lennart Demes, CC0: moqueta, papel pintado, azulejo, latón, falso techo y todos los decals.",
		"Poly Haven, CC0: Rob Tuytel, Dimitrios Savva, Rico Cilliers, Dario Barresi, Jenelle van Heerden y colormass — madera, yeso, terciopelo, jacquard y cuero.",
	]],
	["CUADROS", [
		"Art Institute of Chicago, colección de acceso abierto (dominio público): Salomon van Ruysdael, Meindert Hobbema, Reinier Nooms, Maxime Maufra, Henry Raeburn, John Wollaston, Arthur Devis, Albert Bierstadt, John Henry Twachtman, Jules Dupré, Jean Charles Cazin, Martin Johnson Heade, Jan Both y Jan Brueghel el Viejo.",
	]],
	["SONIDO — FREESOUND", [
		"«Bed sheets (SoundAction 104)» — alexarje (CC BY 4.0).",
		"«men_sneaker_shoes_walking_sound_09262024» — Artninja (CC BY 4.0).",
		"«Open letter and reading» — dersuperanton (CC BY 4.0).",
		"«horror ambience 161101_1038» — klankbeeld (CC BY 4.0).",
		"«Door Opening» — AUDACITIER (CC BY 4.0).",
		"«Atmosphere 2» — oldaccount (CC BY 3.0).",
		"«DOOR creak — multiple creaks wooden door» — mickfire (CC BY-NC 4.0).",
		"«Sub Riser» — deleted_user_3277771 / Josh Mclelland (CC BY-NC 3.0).",
		"«Jumpscare sound» — EnclosureX_Studios (CC BY 4.0).",
		"«toaster oven or lift/elevator bell» — azumarill (CC BY 3.0).",
		"«custom_heavy_whoosh_punch_kick_thud_impact_sound_10022025» — Artninja (CC BY 4.0).",
		"«Radio Music — A MakeNoise Morphagene Reel» — nlux (CC0).",
	]],
	["SONIDO — EL RESTO", [
		"Pasos, respiración, latido, presencia de la criatura y los golpes del hotel: síntesis creada para el juego.",
		"Música y el resto del paquete de efectos: aportados por el usuario; autoría y licencia pendientes de verificar.",
	]],
	["LETRAS", [
		"El cartel de SALIDA y los números de puerta están dibujados para este juego: no se embarca ningún archivo de tipografía.",
	]],
	["LICENCIAS PENDIENTES", [
		"Dos de los sonidos y el modelo de The Locust llevan cláusula No Comercial, y «Realistic Female» es CompartirIgual: mientras sigan aquí, esto no se puede vender.",
		"El registro completo, con enlaces y condiciones, está en docs/ASSETS.md.",
	]],
]
var settings
var overlay: Control
## Above the tape (the analog filter is layer 5): see _ready.
const OUTSIDE_LAYER := 6
var outside: CanvasLayer
var column: VBoxContainer
var side: VBoxContainer
var hint: Label
var subtitle: Label
var flash_label: Label
## The keypad overlay of the last door.
var lock_panel: Control
var progress: ProgressBar
var settings_open := false
var rebind_action := ""
## The action waiting for a pad button, the same way rebind_action waits for a key.
var rebind_pad := ""
var rebind_button: Button
var display_label: Label
## The pair of buttons that keep or revert a screen change, shown only while
## one is waiting.
var display_row: HBoxContainer
var return_action := "main"
var buttons := {}
## Text fields on the current screen, by setting key.
var fields := {}
var display_was_pending := false
## Current screen id ("main", "pause", "settings", "characters", ...).
var screen := ""
## Seconds on the floor, shown on the end screens.
var elapsed := 0.0
## The floor just finished, as records_service wrote it down, and the places it
## took in the boards (table id -> place). Empty until a floor ends.
var summary := {}
var places := {}
## Everything filing it said (records_service.file()): the places, the
## milestones it reached for the first time and what the board held before.
var outcome := {}
var records
## Where "Volver" goes from the marks: whatever screen sent us there.
var records_back := "main"
## What was being looked at in the marks: the tab, the board, the table.
var records_view := {}
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
## Second line of the loading screen: what the game is busy with now (the
## shader warmup says how far along it is, so the screen is never still).
var loading_step: Label
var tick_player: AudioStreamPlayer
var confirm_player: AudioStreamPlayer
## The keypad of the last door speaks for itself: a key, a code that is not
## it, and the one that is. It used to borrow a door's creak and latch, which
## sounded like a door being tried when nothing moved.
var keypad_players := {}
var quiet_focus := false
var intro: Control
## Open document sheet during play, and the record of found documents.
var reading: Control
var discoveries
## Online play (net_session.gd), for the room screens.
var net
const NET := preload("res://game/net/net_session.gd")
const CATALOG := preload("res://game/discovery/discovery_catalog.gd")
## The board of tapes that got out (records_service.gd), the report of one
## tape and the marks, each in its tabs.
const RECORDS := preload("res://game/services/records_service.gd")
const REPORT := preload("res://game/ui/tape_report.gd")
const BOARD := preload("res://game/ui/records_board.gd")
## The rules of a room (game/floors/match_rules.gd) and their screen.
const MATCH_RULES := preload("res://game/floors/match_rules.gd")
const RULES_SCREEN := preload("res://game/ui/rules_screen.gd")
## The creature's difficulties (game/floors/difficulty.gd).
const DIFFICULTY := preload("res://game/floors/difficulty.gd")
## The button focus_first() marks instead of the first one, when there is one.
var focus_wanted := ""
## The tab of the rules being looked at, and whether the screen has to be
## drawn again on the host's own machine (it put them all back at once).
var rules_view := {}
var rules_stale := false
var intro_tween: Tween
## Small corner note during the opening scene: which key skips it.
var skip_label: Label
## The shared sheet (paper_sheet.gd), above the HUD and below the menus.
var sheet: Control
const SHEET := preload("res://game/ui/paper_sheet.gd")
## How long is left to hold a key (hold_ring.gd): round the aiming dot, and
## beside the words that say how to skip the opening scene.
const HOLD_RING := preload("res://game/ui/hold_ring.gd")
var hold_ring: Control
var skip_ring: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Over the OSD and under the tape (analog.gdshader, layer 5), like every
	# other thing this camcorder shows. A lens does not bend a menu, but the
	# tape records one: what is written on the screen is written on the tape,
	# with its grain, its colour bleed and its scan, or it looks pasted on top
	# of a film of something else.
	layer = 4
	var style := STYLE.theme()
	$HUD.theme = style
	hint = $HUD/InteractionHint
	subtitle = $HUD/Subtitle
	flash_label = $HUD/Flash
	progress = $HUD/ExitProgress
	overlay = $MenuOverlay
	overlay.theme = style
	# What is outside the game -- the menus, the loading and end screens, the
	# boot with its headphones notice and its PLAY -- is drawn above the tape
	# and is not filmed by it. What happens inside the floor (the OSD, the
	# objective, the sector card, the sheet, the keypad, a document being
	# read) stays under it, recorded like the picture.
	outside = CanvasLayer.new()
	outside.name = "Outside"
	outside.layer = OUTSIDE_LAYER
	outside.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(outside)
	remove_child(overlay)
	outside.add_child(overlay)
	build_frame()
	skip_label = STYLE.text("", 17)
	skip_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Starting right after its ring (skip_ring), which fills while it is held.
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	skip_label.offset_left = -440
	skip_label.offset_right = -36
	skip_label.offset_top = 24
	skip_label.offset_bottom = 48
	skip_label.add_theme_color_override("font_color", STYLE.SOFT)
	skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(skip_label)
	hold_ring = HOLD_RING.new()
	hold_ring.name = "HoldRing"
	hold_ring.set_anchors_preset(Control.PRESET_CENTER)
	var half: Vector2 = hold_ring.custom_minimum_size * 0.5
	hold_ring.offset_left = -half.x
	hold_ring.offset_right = half.x
	hold_ring.offset_top = -half.y
	hold_ring.offset_bottom = half.y
	$HUD.add_child(hold_ring)
	skip_ring = HOLD_RING.new()
	skip_ring.name = "SkipRing"
	skip_ring.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var ring_size: Vector2 = skip_ring.custom_minimum_size
	# Level with the first line of the words, just before they start.
	skip_ring.offset_right = -444.0
	skip_ring.offset_left = -444.0 - ring_size.x
	skip_ring.offset_top = 36.0 - ring_size.y * 0.5
	skip_ring.offset_bottom = 36.0 + ring_size.y * 0.5
	$HUD.add_child(skip_ring)
	sheet = SHEET.new()
	# Last in this layer: over the HUD, under the menus (which are above the
	# tape, in their own layer).
	add_child(sheet)
	tick_player = sound_player(STYLE.beep(2400.0, 0.018, 0.12))
	confirm_player = sound_player(STYLE.beep(1250.0, 0.07, 0.25))
	keypad_players = {
		"key": sound_player(STYLE.tones([[1900.0, 0.035]], 0.2)),
		"wrong": sound_player(STYLE.tones([[190.0, 0.13], [0.0, 0.07], [190.0, 0.17]], 0.26, 0.6)),
		"right": sound_player(STYLE.tones([[1046.5, 0.08], [0.0, 0.03], [1568.0, 0.15]], 0.24)),
	}
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

## "key", "wrong" or "right": only whoever is typing hears it.
func keypad(kind: String) -> void:
	if sounds_enabled and keypad_players.has(kind): keypad_players[kind].play()

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
	display_row = null
	loading_label = null
	loading_step = null
	rebind_action = ""
	rebind_pad = ""
	settings_tabs = null
	chained_back = null
	pad_scroll = null
	column.custom_minimum_size.x = 520
	side.visible = true
	noise_floor = 0.0

## Menu entry: bare text with a play cursor on focus. Returns the Button.
func entry(parent: Node, words: String, callback: Callable, disabled := false, size := 28) -> Button:
	var row := HBoxContainer.new()
	# The cursor against its own word, a little gap between: left in its
	# cell, it was nearer the entry before it in a row than its own.
	row.add_theme_constant_override("separation", 7)
	parent.add_child(row)
	var cursor := STYLE.text("▶", size - 6)
	cursor.custom_minimum_size.x = 33
	cursor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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

## What the loading screen is waiting on; empty leaves the line blank.
func loading_note(words: String) -> void:
	if is_instance_valid(loading_step): loading_step.text = words

## The first thing a pad can press on this screen. Without it a screen built
## out of plain entries (the board of times) came up with nothing highlighted,
## and a pad had no way in at all.
func focus_first() -> void:
	quiet_focus = true
	var wanted := focus_wanted
	focus_wanted = ""
	if buttons.has(wanted) and not buttons[wanted].disabled:
		buttons[wanted].grab_focus()
		quiet_focus = false
		return
	for id in buttons:
		if not buttons[id].disabled:
			buttons[id].grab_focus()
			quiet_focus = false
			return
	for node in overlay.find_children("*", "Button", true, false):
		if not (node as Button).disabled and (node as Button).is_visible_in_tree():
			(node as Button).grab_focus()
			break
	quiet_focus = false

## Brief tape static and a fade-in of the new content.
func transition(strength := 0.5) -> void:
	noise_amount = maxf(noise_amount, strength)
	body.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(body, "modulate:a", 1.0, 0.28).set_delay(0.06)

## Every menu off, and whatever one was waiting for with it: hidden without
## this, a key being rebound kept listening in play and took the next key
## pressed as the new binding.
func close_menus() -> void:
	overlay.hide()
	settings_open = false
	rebind_action = ""
	rebind_pad = ""

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
			spacer(column, 22)
			action("Nueva partida", "new")
			action("Continuar", "continue", not can_continue)
			action("Multijugador", "multiplayer")
			action("Records", "records")
			action("Archivo", "archive")
			action("Ajustes", "settings")
			action("Créditos", "credits")
			action("Salir", "quit")
		"pause":
			set_osd("❚❚ PAUSA", "", "", "")
			backdrop.modulate.a = 0.9
			title(column, "PAUSA", 72)
			briefing_panel(column)
			spacer(column, 28)
			action("Continuar", "resume")
			action("Ajustes", "settings")
			action("Reintentar piso", "retry")
			action("Menú principal", "main")
			controls_panel(side)
		"won":
			set_osd("■ STOP", "", "", "")
			tape_screen("SALISTE DEL PISO", STYLE.INK, summary, outcome, [["Nueva partida", "new"], ["Records", "records"], ["Menú principal", "main"]])
		"failed":
			set_osd("SEÑAL PERDIDA", "", "", "")
			osd_left.add_theme_color_override("font_color", STYLE.ALERT)
			noise_floor = 0.16
			tape_screen("SEÑAL PERDIDA", STYLE.ALERT, summary, outcome, [["Reintentar", "retry"], ["Records", "records"], ["Menú principal", "main"]])
		"loading":
			set_osd("◀◀ REW", "", "", "")
			title(column, "CARGANDO CINTA", 58)
			spacer(column, 6)
			loading_label = label(column, "EL HOTEL ESTÁ TOMANDO FORMA", 22)
			loading_label.add_theme_color_override("font_color", STYLE.SOFT)
			loading_step = label(column, "", 18)
			loading_step.add_theme_color_override("font_color", STYLE.AMBER)
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
		"records":
			set_osd("▶ PLAY", "", "", "")
			side.visible = false
			column.custom_minimum_size.x = BOARD.SIZE.x
			title(column, "RECORDS", 44)
			var tabs := BOARD.build(self, column, records_view)
			footer.text = tab_hint()
			spacer(column, 4)
			# Back where it was opened from; the main menu is asked for, so it
			# comes up knowing whether there is a floor to go on with.
			var back_to: String = records_back
			var leave := func() -> void:
				if back_to == "main": action_requested.emit("main")
				else: menu(back_to)
			buttons["back"] = entry(column, "Volver", leave, false, 24)
			chain_settings(tabs, buttons["back"])
		"multiplayer":
			set_osd("MENU ▸ MULTIJUGADOR", "", "", "")
			title(column, "MULTIJUGADOR", 64)
			label(column, "DE 2 A %d JUGADORES · IP / LAN O STEAM" % NET.MAX_PLAYERS, 20).add_theme_color_override("font_color", STYLE.SOFT)
			spacer(column, 18)
			# Left empty, the room calls this player "Jugador" (clean_name).
			field(column, "", "player_name", "Ingresa tu nombre")
			spacer(column, 10)
			# First the connection, then open a room or join one on it: the
			# room itself is the same either way (net_session.gd). The
			# character is chosen in the room.
			var steam_ready: bool = net != null and net.steam.ready_to_play()
			action("Steam", "mp_steam", not steam_ready)
			if net != null and not steam_ready: paragraph(column, net.steam.problem(), 16, 560)
			action("IP / LAN", "mp_ip")
			spacer(column, 12)
			action("Volver", "main")
		"mp_steam":
			set_osd("MULTIJUGADOR ▸ STEAM", "", "", "")
			title(column, "STEAM", 64)
			label(column, "CON TUS AMIGOS DE STEAM · SIN ABRIR PUERTOS", 20).add_theme_color_override("font_color", STYLE.SOFT)
			spacer(column, 18)
			action("Crear sala", "host_steam")
			action("Unirse a una sala", "join_steam")
			spacer(column, 12)
			action("Volver", "multiplayer")
			side.visible = false
		"mp_ip":
			set_osd("MULTIJUGADOR ▸ IP / LAN", "", "", "")
			title(column, "IP / LAN", 64)
			label(column, "EN TU RED LOCAL, O POR INTERNET CON UN PUERTO ABIERTO", 20).add_theme_color_override("font_color", STYLE.SOFT)
			spacer(column, 18)
			action("Crear sala", "host")
			action("Unirse a una sala", "join")
			spacer(column, 12)
			action("Volver", "multiplayer")
			side.visible = false
		"host_ip":
			set_osd("MULTIJUGADOR ▸ CREAR SALA", "", "", "")
			title(column, "CREAR SALA", 64)
			label(column, "IP / LAN", 20).add_theme_color_override("font_color", STYLE.SOFT)
			spacer(column, 18)
			field(column, "Puerto", "host_port", str(NET.PORT))
			# Which of this machine's networks to open it on: all of them, or
			# one (a machine on two networks, or a VPN such as Radmin/ZeroTier).
			var networks: Array = ["*"] + NET.local_addresses()
			var names: Array = ["Todas las redes de este equipo"] + NET.local_addresses()
			var picked: String = str(settings.values.host_bind)
			if not networks.has(picked): picked = "*"
			choice(column, "Red", names, networks.find(picked), func(index): settings.set_value("host_bind", networks[index]))
			spacer(column, 10)
			action("Abrir la sala", "host_open")
			paragraph(column, "En tu red local basta con esto. Para jugar por Internet, el puerto tiene que estar abierto en tu router hacia este equipo (UDP); si no puedes abrirlo, usa Steam.", 16, 560)
			spacer(column, 12)
			action("Volver", "mp_ip")
			side.visible = false
		"join_steam":
			set_osd("MULTIJUGADOR ▸ UNIRSE", "", "", "STEAM")
			title(column, "UNIRSE", 64)
			label(column, "STEAM · SALAS DE TUS AMIGOS", 20).add_theme_color_override("font_color", STYLE.SOFT)
			spacer(column, 18)
			var rooms: Array = net.steam.friend_rooms() if net != null else []
			for room in rooms:
				var lobby_id: int = room.lobby
				entry(column, room.name, func(): if net.join_steam(lobby_id, settings.values.player_name, settings.values.character): menu("steam_wait"), false, 24)
			if rooms.is_empty(): label(column, "Ningún amigo tiene una sala abierta ahora.", 19).add_theme_color_override("font_color", STYLE.SOFT)
			spacer(column, 10)
			action("Actualizar", "join_steam")
			paragraph(column, "También puedes aceptar una invitación desde Steam (Mayús+Tab), o entrar desde el perfil de un amigo con «Unirse a la partida».", 16, 560)
			spacer(column, 12)
			action("Volver", "mp_steam")
			side.visible = false
		"steam_invite":
			set_osd("SALA ▸ INVITAR", "", "", "STEAM")
			title(column, "INVITAR", 64)
			label(column, "TUS AMIGOS CONECTADOS A STEAM", 20).add_theme_color_override("font_color", STYLE.SOFT)
			spacer(column, 14)
			var friends: Array = net.steam.online_friends() if net != null else []
			if friends.is_empty(): label(column, "Ninguno de tus amigos está conectado ahora.", 19).add_theme_color_override("font_color", STYLE.SOFT)
			else:
				# However many friends are online, the list scrolls inside the
				# screen instead of pushing the buttons off it.
				var scroll := ScrollContainer.new()
				scroll.follow_focus = true
				scroll.custom_minimum_size = Vector2(560, mini(friends.size(), 7) * 38)
				scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
				column.add_child(scroll)
				var list := VBoxContainer.new()
				list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				scroll.add_child(list)
				for friend in friends:
					var who: String = friend.name
					var id: int = friend.id
					entry(list, who, func():
						var sent: bool = net.steam.invite(id)
						menu("steam_invite", false, ("Invitación enviada a %s: le llega al chat de Steam." % who) if sent else "Steam no dejó enviar la invitación a %s." % who), false, 22)
			spacer(column, 10)
			if net != null and net.steam.overlay_ready(): action("Abrir la ventana de Steam", "steam_overlay_invite")
			action("Actualizar", "steam_invite")
			spacer(column, 8)
			action("Volver a la sala", "lobby_back")
			side.visible = false
		"steam_wait":
			set_osd("MULTIJUGADOR ▸ STEAM", "", "", "")
			title(column, "STEAM", 64)
			spacer(column, 18)
			label(column, net.status if net != null and not net.status.is_empty() else "Conectando…", 20).add_theme_color_override("font_color", STYLE.AMBER)
			spacer(column, 12)
			action("Cancelar", "lobby_leave")
			side.visible = false
		"join":
			set_osd("MULTIJUGADOR ▸ UNIRSE", "", "", "")
			title(column, "UNIRSE", 64)
			spacer(column, 18)
			label(column, "IP / LAN", 20).add_theme_color_override("font_color", STYLE.SOFT)
			spacer(column, 8)
			field(column, "Dirección del anfitrión", "join_address", "192.168.1.20")
			field(column, "Puerto", "join_port", str(NET.PORT))
			spacer(column, 10)
			if net != null and net.active():
				label(column, net.status if not net.status.is_empty() else "Conectando…", 20).add_theme_color_override("font_color", STYLE.AMBER)
			else: action("Conectar", "connect")
			spacer(column, 12)
			action("Volver", "lobby_leave" if net != null and net.active() else "mp_ip")
			side.visible = false
		"lobby":
			lobby_screen()
		"difficulty":
			difficulty_screen()
		"rules":
			var hosting: bool = net != null and net.is_host
			set_osd("SALA ▸ REGLAS", "", "", "ANFITRIÓN" if hosting else "")
			side.visible = false
			column.custom_minimum_size.x = RULES_SCREEN.SIZE.x
			title(column, "REGLAS", 44)
			label(column, "LAS DE ESTA SALA: VALEN PARA CADA PISO QUE EMPIECE DESDE ELLA" if hosting else "LAS PONE EL ANFITRIÓN · EN ÁMBAR, LO QUE CAMBIÓ", 15).add_theme_color_override("font_color", STYLE.SOFT)
			var tabs := RULES_SCREEN.build(self, column, rules_view)
			footer.text = tab_hint()
			rules_stale = false
			var row := HFlowContainer.new()
			row.add_theme_constant_override("h_separation", 4)
			column.add_child(row)
			buttons["lobby"] = entry(row, "Volver a la sala", func(): action_requested.emit("lobby"), false, 21)
			if hosting: buttons["rules_reset"] = entry(row, "Las del juego", func(): action_requested.emit("rules_reset"), false, 21)
			chain_settings(tabs, buttons["lobby"])
		"online_pause":
			set_osd("❚❚ MENÚ", "", "", "LA PARTIDA SIGUE")
			backdrop.modulate.a = 0.75
			title(column, "MENÚ", 72)
			label(column, "LA PARTIDA NO SE DETIENE", 20).add_theme_color_override("font_color", STYLE.AMBER)
			briefing_panel(column)
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
			spacer(column, 14)
			column.custom_minimum_size.x = 720
			credits_roll()
			spacer(column, 14)
			action("Volver", "main")
			side.visible = false
	if osd_left.text != "SEÑAL PERDIDA": osd_left.remove_theme_color_override("font_color")
	# First start on an integrated GPU: it starts on Muy bajo; the lighter
	# renderer is the player's call (it restarts the game).
	if kind == "main" and message.is_empty() and settings.integrated_gpu and settings.values.renderer == "forward_plus":
		message = "Gráfica integrada: preset Muy bajo. Si va sobrado, sube el preset en Ajustes ▸ Gráficos; si aun así va lento, prueba ahí el renderizador Compatibilidad."
	if not message.is_empty():
		spacer(column, 14)
		paragraph(column, message, 16, 560, STYLE.AMBER)
	transition(0.35 if kind != "failed" else 0.9)
	focus_first()

## Which creature a new game is played against: the four, the one chosen last
## marked, and beside them what the one under the cursor is like. Picking one
## keeps it and starts the game.
func difficulty_screen() -> void:
	set_osd("MENU ▸ NUEVA PARTIDA", "", "", "")
	title(column, "DIFICULTAD", 64)
	label(column, "LA BESTIA QUE TE ESPERA EN EL HOTEL", 20).add_theme_color_override("font_color", STYLE.SOFT)
	spacer(column, 24)
	var chosen := DIFFICULTY.valid(settings.values.get("difficulty", DIFFICULTY.REFERENCE))
	for id in DIFFICULTY.ORDER:
		var which: String = id
		var button := entry(column, DIFFICULTY.title(which), func():
			settings.set_value("difficulty", which)
			action_requested.emit("begin"), false, 30)
		button.focus_entered.connect(func(): describe_difficulty(which))
		buttons[which] = button
	spacer(column, 18)
	action("Volver", "main")
	focus_wanted = chosen
	describe_difficulty(chosen)

func describe_difficulty(id: String) -> void:
	for child in side.get_children():
		side.remove_child(child)
		child.queue_free()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.add_theme_stylebox_override("panel", STYLE.flat(Color(0.02, 0.02, 0.02, 0.82), STYLE.FAINT, 1, 22))
	side.add_child(panel)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 8)
	panel.add_child(text)
	label(text, DIFFICULTY.title(id).to_upper(), 30).add_theme_color_override("font_color", STYLE.AMBER)
	paragraph(text, String(DIFFICULTY.NOTES[id]), 18, 440, STYLE.INK)
	spacer(text, 4)
	for line in DIFFICULTY.TRAITS[id]: paragraph(text, "·  " + String(line), 16, 440)
	if id == DIFFICULTY.REFERENCE:
		spacer(text, 4)
		paragraph(text, "Es la bestia de siempre: la de antes de que hubiera dificultades.", 15, 440, STYLE.SOFT)

## A text field bound to a setting (saved as it is typed).
func field(parent: Node, title_text: String, key: String, placeholder: String) -> LineEdit:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	if not title_text.is_empty(): label(row, title_text, 19).custom_minimum_size.x = 240
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

## Width of the room's right-hand column: what is left beside the options at
## the 1280 px the menus are laid out in. Wider, it ran off the screen, and
## every line in it wrapped at the wider width.
const LOBBY_SIDE := 340

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
		# Against the machine's creature, which one; the host's choice is kept
		# for its next room too.
		if mode == NET.Mode.COOP:
			var names: Array = DIFFICULTY.ORDER.map(func(id): return DIFFICULTY.title(id))
			choice(column, "Dificultad", names, DIFFICULTY.rank(net.options.get("difficulty")), func(index):
				net.set_option("difficulty", DIFFICULTY.ORDER[index])
				settings.set_value("difficulty", DIFFICULTY.ORDER[index]))
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
		if mode == NET.Mode.COOP: label(column, "Dificultad: %s" % DIFFICULTY.title(net.options.get("difficulty")), 20)
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
	action("Reglas", "lobby_rules")
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
		paragraph(side, "%s%s" % [visual_script.NAMES[clampi(int(entry_data.character), 0, 2)], ("  ·  " + ", ".join(tags)) if not tags.is_empty() else ""], 16, LOBBY_SIDE)
	# What the room changed of the rules, for everybody to see before it starts.
	var differs: Array = MATCH_RULES.described(net.options.get("rules", {}))
	spacer(side, 10)
	label(side, "REGLAS: LAS DEL JUEGO" if differs.is_empty() else "REGLAS CAMBIADAS (%d)" % differs.size(), 16).add_theme_color_override("font_color", STYLE.SOFT if differs.is_empty() else STYLE.AMBER)
	for words in differs.slice(0, 4): paragraph(side, words, 15, LOBBY_SIDE, STYLE.INK)
	if differs.size() > 4: paragraph(side, "…y %d más" % (differs.size() - 4), 15, LOBBY_SIDE)
	if hosting:
		spacer(side, 14)
		var how: Array = net.where_to_join()
		paragraph(side, how[0], 17, LOBBY_SIDE, STYLE.AMBER)
		paragraph(side, how[1], 15, LOBBY_SIDE)
		# Steam's own invitation window, as in any Steam game; the game's
		# list only where the overlay is off (turned off in the player's Steam).
		if net.transport == "steam": button(side, "Invitar amigos", func():
			if net.steam.overlay_ready(): action_requested.emit("steam_overlay_invite")
			else: menu("steam_invite"))

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
	var actions: Array = []
	var note := ""
	if net.is_host:
		if not won: actions.append(["Reintentar piso", "online_retry"])
		actions.append_array([["Nueva partida", "online_new"], ["Volver a la sala", "online_room"], ["Records", "records"], ["Cerrar la sala", "online_quit"]])
	else:
		note = "El anfitrión decide cómo seguir…"
		actions.append_array([["Records", "records"], ["Salir de la sala", "online_quit"]])
	tape_screen(headline, STYLE.ALERT if bad else STYLE.INK, summary, outcome, actions, note)

## A floor's end, or a tape taken off the board: its headline, which tape it
## is, the report in tabs (tape_report.gd) and, in one row under it, what can
## be done next. `actions`: [words, an action's id or what to call].
func tape_screen(headline: String, ink: Color, line: Dictionary, result: Dictionary, actions: Array, note := "") -> void:
	side.visible = false
	column.custom_minimum_size.x = REPORT.SIZE.x
	title(column, headline, 44, ink)
	var tabs: TabContainer
	if line.is_empty():
		# A guest the host's line has not reached yet: the screen is drawn
		# again when it does (match_net.floor_summary).
		spacer(column, 8)
		label(column, "TIEMPO DE GRABACIÓN  %s" % tape_time(elapsed), 22).add_theme_color_override("font_color", STYLE.SOFT)
		spacer(column, 20)
	else:
		label(column, REPORT.heading(line, headline == "SEÑAL PERDIDA"), 15).add_theme_color_override("font_color", STYLE.SOFT)
		tabs = REPORT.build(self, column, line, result)
		footer.text = tab_hint()
	if not note.is_empty(): label(column, note, 17).add_theme_color_override("font_color", STYLE.SOFT)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	column.add_child(row)
	for item in actions:
		var what = item[1]
		var words: String = item[0]
		buttons[what if what is String else words] = entry(row, words, (func(): action_requested.emit(what)) if what is String else what, false, 21)
	if tabs != null and not buttons.is_empty(): chain_settings(tabs, buttons.values()[0])

## A tape taken off the board, read whole.
func show_tape(line: Dictionary) -> void:
	settings_open = false
	clear()
	screen = "tape"
	overlay.show()
	backdrop.modulate.a = 1.0
	set_osd("▶ PLAY", "", "", "")
	osd_left.remove_theme_color_override("font_color")
	tape_screen("PARTE DE LA CINTA", STYLE.INK, line, {}, [["Volver a los records", func(): menu("records")]])
	transition(0.3)
	focus_first()

## How the tabs of a report or of the marks are turned, for the corner of the
## screen: the keys, or the shoulders of the pad in the hands.
func tab_hint() -> String:
	if settings != null and settings.using_pad and settings.pad_present():
		return "%s  ·  PESTAÑAS  ·  %s" % [settings.button_name(JOY_BUTTON_LEFT_SHOULDER), settings.button_name(JOY_BUTTON_RIGHT_SHOULDER)]
	return "Q  ·  PESTAÑAS  ·  E"

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
	var key: String = settings.prompt_name("interact") if settings != null else "E"
	label(text, "[%s] GUARDAR" % key, 16).add_theme_color_override("font_color", STYLE.FAINT)

## The keypad of the last door: four places, what has been typed so far, a
## word when it refuses or gives way, and the numbers already written down --
## standing at the keypad is exactly where nobody should have to remember them.
func show_lock(entered: String, places: int, word: String, known := "", dial := -1) -> void:
	hide_lock()
	lock_panel = Control.new()
	lock_panel.name = "Lock"
	lock_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lock_panel)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_panel.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	center.add_child(column)
	var slots := ""
	for place in places: slots += (entered[place] if place < entered.length() else "_") + "  "
	label(column, slots.strip_edges(), 64).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not known.is_empty():
		var note := label(column, "ANOTADO  " + known, 22)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_color_override("font_color", STYLE.SOFT)
	# With a pad there is nowhere to type: the numbers are dialled with the
	# cross and pressed with the bottom button.
	var padded: bool = dial >= 0 and settings != null and settings.pad_present()
	if padded:
		var strip := HBoxContainer.new()
		strip.add_theme_constant_override("separation", 14)
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(strip)
		for digit in 10:
			var one := label(strip, str(digit), 30)
			one.add_theme_color_override("font_color", STYLE.AMBER if digit == dial else STYLE.SOFT)
	var foot_words := word
	if foot_words.is_empty(): foot_words = "CRUCETA: ELIGE · %s: MARCA · %s: BORRA · %s: SALIR" % [settings.button_name(JOY_BUTTON_A), settings.button_name(JOY_BUTTON_X), settings.button_name(JOY_BUTTON_B)] if padded else "TECLEA EL CÓDIGO · [ESC] SALIR"
	var foot := label(column, foot_words, 18)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_color_override("font_color", STYLE.ALERT if word == "NO ES" else STYLE.SOFT)

func hide_lock() -> void:
	if is_instance_valid(lock_panel): lock_panel.queue_free()
	lock_panel = null

func hide_document() -> void:
	if is_instance_valid(reading): reading.queue_free()
	reading = null

func tape_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]

## The sector's errand, kept where anybody can go and look at it again, with
## what is counted in this one: the sets that are on, and the numbers found.
func briefing_panel(parent: Node) -> void:
	if String(briefing.get("objective", "")).is_empty(): return
	spacer(parent, 18)
	label(parent, String(briefing.sector), 22).add_theme_color_override("font_color", STYLE.AMBER)
	spacer(parent, 4)
	paragraph(parent, String(briefing.objective), 20, 520, STYLE.INK)
	for row in briefing.get("progress", []):
		spacer(parent, 6)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		parent.add_child(line)
		var key := label(line, String(row[0]), 18)
		key.custom_minimum_size.x = 260
		key.add_theme_color_override("font_color", STYLE.SOFT)
		label(line, String(row[1]), 18).add_theme_color_override("font_color", STYLE.AMBER)

## The keys, beside the pause menu. It sits over the right of the screen,
## where the menu's shade has thinned to almost nothing, so its own backing is
## nearly opaque, and every column has a fixed width with the words wrapping
## inside it: nothing here may run off the edge of the screen.
func controls_panel(parent: Node) -> void:
	if settings == null: return
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.add_theme_stylebox_override("panel", STYLE.flat(Color(0.02, 0.02, 0.02, 0.86), STYLE.FAINT, 1, 20))
	parent.add_child(panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	panel.add_child(list)
	label(list, "CONTROLES", 20).add_theme_color_override("font_color", STYLE.AMBER)
	spacer(list, 4)
	var moves := "%s %s %s %s" % [settings.key_name("forward"), settings.key_name("left"), settings.key_name("backward"), settings.key_name("right")]
	var rows: Array = [[moves, "Moverse"], ["RATÓN", "Mirar"], [settings.key_name("sprint"), "Correr"], [settings.key_name("crouch"), "Agacharse"], [settings.key_name("jump"), "Saltar"], [settings.key_name("interact"), "Puertas, escondites, teles y documentos"], [settings.key_name("interact") + " MANTENER", "Registrar un mueble · Abrir una puerta despacio"], [settings.key_name("flashlight"), "Linterna"], ["RUEDA DEL RATÓN", "Zoom de la cámara"], [settings.key_name("sheet"), "Hoja (dibujar y borrar con el ratón)"], ["CLIC", "Muerto en equipo: cambiar a quién miras"], ["ESC", "Pausa"]]
	# Played on a pad, the card names its buttons, and says which ones flip.
	if settings.using_pad and settings.pad_present():
		var flip := func(action: String) -> String: return settings.pad_name(action) + (" (ALTERNA)" if settings.values.get("pad_%s_toggle" % action, false) else "")
		rows = [["STICK IZQ.", "Moverse (cuanto más lo empujas, más deprisa)"], ["STICK DER.", "Mirar"], [flip.call("sprint"), "Correr"], [flip.call("crouch"), "Agacharse"], [settings.pad_name("jump"), "Saltar"], [settings.pad_name("interact"), "Puertas, escondites, teles y documentos"], [settings.pad_name("interact") + " MANTENER", "Registrar un mueble · Abrir una puerta despacio"], [settings.pad_name("flashlight"), "Linterna"], ["CRUCETA ↑ ↓", "Zoom de la cámara"], [settings.pad_name("sheet"), "Hoja (stick izq. lleva el lápiz, %s dibuja, %s borra)" % [settings.trigger_name(true), settings.trigger_name(false)]], [settings.button_name(JOY_BUTTON_START), "Pausa"]]
	for row in rows:
		var line := HBoxContainer.new()
		list.add_child(line)
		line.add_theme_constant_override("separation", 12)
		var key := label(line, row[0].to_upper(), 17)
		key.custom_minimum_size.x = 150
		paragraph(line, row[1], 17, 250, Color(STYLE.INK, 0.78))

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
	# On a pad the shoulders change tab (_input), from anywhere on the screen.
	if settings.pad_present():
		var hint := label(column, "%s  ·  CAMBIA DE PESTAÑA  ·  %s" % [settings.button_name(JOY_BUTTON_LEFT_SHOULDER), settings.button_name(JOY_BUTTON_RIGHT_SHOULDER)], 16)
		hint.add_theme_color_override("font_color", STYLE.SOFT)
	spacer(column, 10)
	var tabs := TabContainer.new()
	settings_tabs = tabs
	tabs.custom_minimum_size = Vector2(1000, 380)
	tabs.add_theme_font_size_override("font_size", 20)
	column.add_child(tabs)
	# IMAGEN is the screen: the window, how many pixels are drawn and how they
	# are brought up to it. GRÁFICOS is what the picture looks like.
	var picture := page(tabs, "IMAGEN")
	options(picture, "Modo de ventana", "window_mode", settings.WINDOW_MODES, range(settings.WINDOW_MODES.size()))
	options(picture, "Tamaño de ventana", "resolution", ["1280 × 720", "1600 × 900", "1920 × 1080", "2560 × 1440"], [0, 1, 2, 3], settings.fullscreen)
	var forward: bool = RenderingServer.get_current_rendering_method() == "forward_plus"
	options(picture, "Escalado", "upscaler", PRESETS.UPSCALER_NAMES, PRESETS.UPSCALERS, not forward)
	scaling_modes(picture)
	slider(picture, "Escala de render", "scale", PRESETS.SCALING_MODES[PRESETS.SCALING_MODES.size() - 1], 1.0, 0.01, false, true)
	var mode: int = PRESETS.scaling_mode(settings.values)
	slider(picture, "Nitidez del escalado", "sharpness", 0.0, 1.0, 0.05, mode == Viewport.SCALING_3D_MODE_BILINEAR)
	options(picture, "Suavizado de bordes", "aa", PRESETS.ANTIALIASING_NAMES, PRESETS.ANTIALIASING, mode == Viewport.SCALING_3D_MODE_FSR2)
	if not forward:
		paragraph(picture, "Compatibilidad no tiene FSR: la imagen se estira sin reconstruir. Cambia el renderizador en GRÁFICOS para usarlo.", 16, 900, STYLE.SOFT)
	elif mode == Viewport.SCALING_3D_MODE_FSR2:
		paragraph(picture, "FSR 2.2 reconstruye la imagen con el movimiento de cada píxel y hace de suavizado él mismo, así que el de abajo no se usa.", 16, 900, STYLE.SOFT)
	elif settings.values.scale < 1.0 and mode == Viewport.SCALING_3D_MODE_BILINEAR:
		paragraph(picture, "Por debajo de la resolución nativa, FSR 2.2 se ve bastante más nítido que este estirado.", 16, 900, STYLE.SOFT)
	options(picture, "Límite de FPS", "fps", ["Sin límite", "30", "60", "120", "144"], [0, 30, 60, 120, 144])
	check(picture, "Sincronización vertical", "vsync")
	var graphics := page(tabs, "GRÁFICOS")
	options(graphics, "Preset gráfico", "quality", PRESETS.ORDER.map(func(index: int) -> String: return PRESETS.NAMES[index]), PRESETS.ORDER)
	if int(settings.values.quality) == PRESETS.VERY_LOW:
		paragraph(graphics, "Muy bajo es para gráficas integradas: las lámparas alumbran sin proyectar sombra (solo la linterna la proyecta), los materiales llevan texturas pequeñas y sin relieve, y la imagen no pasa por la lente. El juego y sus reglas son los mismos. Rinde como se pensó con la escala en Rendimiento (50 %).", 16, 900, STYLE.SOFT)
	# The scale and the upscaler are the player's own and no preset touches
	# them: on the two presets for modest machines, what FSR 2.2 costs is said.
	if int(settings.values.quality) in [PRESETS.VERY_LOW, PRESETS.LOW] and PRESETS.scaling_mode(settings.values) == Viewport.SCALING_3D_MODE_FSR2:
		paragraph(graphics, "El escalado está en FSR 2.2, que en una gráfica modesta cuesta más que todo lo demás de este preset junto. En IMAGEN ▸ Escalado, «Automático» usa el del preset.", 16, 900, STYLE.AMBER)
	options(graphics, "Renderizador", "renderer", ["Forward+ (completo)", "Compatibilidad (gráfica integrada)"], ["forward_plus", "gl_compatibility"])
	if settings.renderer_pending():
		paragraph(graphics, "El renderizador cambia al reiniciar el juego.", 16, 900, STYLE.AMBER)
		# Only from the main menu: a restart mid-floor would lose the floor.
		if return_action == "main" and not (net != null and net.active()):
			var restart := Button.new()
			restart.theme_type_variation = "BoxButton"
			restart.text = "REINICIAR AHORA"
			restart.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			restart.pressed.connect(func():
				confirm()
				var arguments := OS.get_cmdline_args()
				if not OS.get_cmdline_user_args().is_empty(): arguments += PackedStringArray(["--"]) + OS.get_cmdline_user_args()
				OS.set_restart_on_exit(true, arguments)
				get_tree().quit()
			)
			graphics.add_child(restart)
	check(graphics, "Sombras", "shadows")
	# The heavy ones, each one the preset's unless it is asked for by hand.
	for key in PRESETS.SWITCHES: options(graphics, PRESETS.SWITCHES[key], key, ["Del preset", "Desactivado", "Activado"], [-1, 0, 1])
	spacer(graphics, 6)
	for item in [["Cinta VHS", "vhs"], ["Grano", "grain"], ["Aberración cromática", "chromatic"], ["Líneas de barrido", "scanlines"], ["Movimiento de cámara", "bob"]]: slider(graphics, item[0], item[1], 0, 1, 0.05)
	check(graphics, "Marcas de videocámara (REC, fecha y hora)", "osd")
	check(graphics, "Efectos reducidos", "reduced")
	var controls := page(tabs, "CONTROLES")
	slider(controls, "Sensibilidad", "sensitivity", 0.0005, 0.008, 0.0001)
	check(controls, "Invertir mirada vertical", "invert")
	if settings.pad_present():
		slider(controls, "Sensibilidad del mando", "pad_look", 0.6, 6.0, 0.2)
		check(controls, "Correr con el mando: pulsar para alternar", "pad_sprint_toggle")
		check(controls, "Agacharse con el mando: pulsar para alternar", "pad_crouch_toggle")
		check(controls, "Vibración del mando", "rumble")
		paragraph(controls, "Mando: %s. El stick izquierdo anda —cuanto más lo empujas, más deprisa—, el derecho mira y %s hace de pausa; mover y mirar son los sticks y no se cambian. Con la hoja abierta, el stick izquierdo lleva el lápiz, %s dibuja y %s borra." % [FAMILY_NAMES[settings.pad_family()], settings.button_name(JOY_BUTTON_START), settings.trigger_name(true), settings.trigger_name(false)], 16, 900, STYLE.SOFT)
	var titles := {"forward": "Adelante", "backward": "Atrás", "left": "Izquierda", "right": "Derecha", "sprint": "Correr", "jump": "Saltar", "interact": "Interactuar", "flashlight": "Linterna", "crouch": "Agacharse", "sheet": "Hoja", "locust_trace": "The Locust: rastro a la tele"}
	for id in titles:
		var row := HBoxContainer.new()
		controls.add_child(row)
		label(row, titles[id], 19).custom_minimum_size.x = 300
		var key_button := Button.new()
		key_button.theme_type_variation = "BoxButton"
		key_button.text = settings.key_name(id)
		key_button.custom_minimum_size = Vector2(240, 38)
		row.add_child(key_button)
		key_button.pressed.connect(func():
			confirm()
			rebind_action = id
			rebind_button = key_button
			key_button.text = "PULSA UNA TECLA · ESC CANCELA"
		)
		# And what the same thing is on a pad, where it is a button at all.
		if not settings.pad_present(): continue
		var pad_button := Button.new()
		pad_button.theme_type_variation = "BoxButton"
		pad_button.custom_minimum_size = Vector2(200, 38)
		pad_button.disabled = not settings.PAD_KEYS.has(id)
		# The trace is the torch's button: the creature has no torch.
		pad_button.text = settings.pad_name(id) if settings.PAD_KEYS.has(id) else ("EL DE LA LINTERNA" if id == "locust_trace" else "STICK IZQ.")
		row.add_child(pad_button)
		if pad_button.disabled: continue
		pad_button.pressed.connect(func():
			confirm()
			rebind_pad = id
			rebind_button = pad_button
			pad_button.text = "PULSA UN BOTÓN · %s CANCELA" % settings.button_name(JOY_BUTTON_B)
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
	# Only while a screen change is waiting to be kept: they did nothing the
	# rest of the time, and stood where the eye looks for "Volver".
	confirm_row.visible = not settings.previous_display.is_empty()
	display_row = confirm_row
	column.add_child(confirm_row)
	for pair in [["CONSERVAR PANTALLA", func(): settings.confirm_display()], ["REVERTIR PANTALLA", func(): settings.revert_display(); show_settings.call_deferred(return_action)]]:
		var box := Button.new()
		box.theme_type_variation = "BoxButton"
		box.text = pair[0]
		box.pressed.connect(pair[1])
		confirm_row.add_child(box)
	var leave := func():
		# Closed first: the revert would otherwise reopen these settings.
		settings_open = false
		if not settings.previous_display.is_empty(): settings.revert_display()
		action_requested.emit(return_action)
	buttons["back"] = entry(column, "Volver", leave, false, 24)
	chain_settings(tabs, buttons["back"])
	_display_changed(int(ceil(settings.countdown)))
	transition(0.3)
	quiet_focus = true
	tabs.get_tab_bar().grab_focus()
	quiet_focus = false

## The credits, in a panel that rolls by itself: there are more of them than
## fit on the screen, and nobody should have to drag them by hand to read to
## the end. The roll stops the moment the reader takes the wheel.
func credits_roll() -> void:
	var roll := ScrollContainer.new()
	roll.custom_minimum_size = Vector2(720, 384)
	roll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(roll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	roll.add_child(list)
	for block in CREDITS:
		label(list, block[0], 18).add_theme_color_override("font_color", STYLE.AMBER)
		for line in block[1]: paragraph(list, line, 17, 660)
		spacer(list, 12)
	start_roll(roll, list)

func start_roll(roll: ScrollContainer, list: VBoxContainer) -> void:
	# Two frames, for the wrapped lines to find their height.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(roll) or not is_instance_valid(list): return
	var span := list.size.y - roll.size.y
	if span <= 1.0: return
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(roll, "scroll_vertical", int(span), span / 26.0)
	var stop := func(event):
		if event is InputEventMouseButton or event is InputEventPanGesture: tween.kill()
	roll.gui_input.connect(stop)
	roll.get_v_scroll_bar().gui_input.connect(stop)

## How much of the picture is drawn, in the modes a player knows by name, with
## the slider under it for anything in between. A scale that is not one of them
## reads as "Personalizada" and is kept until another is chosen.
func scaling_modes(parent: Node) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	label(row, "Calidad del escalado", 19).custom_minimum_size.x = 340
	var control := OptionButton.new()
	control.custom_minimum_size.x = 300
	control.add_theme_font_size_override("font_size", 19)
	for words in PRESETS.SCALING_NAMES: control.add_item(words)
	var chosen := -1
	for index in PRESETS.SCALING_MODES.size():
		if is_equal_approx(float(PRESETS.SCALING_MODES[index]), float(settings.values.scale)): chosen = index
	if chosen < 0:
		control.add_item("Personalizada (%d%%)" % roundi(settings.values.scale * 100))
		chosen = PRESETS.SCALING_MODES.size()
	control.select(chosen)
	control.item_selected.connect(func(index):
		tick()
		if index >= PRESETS.SCALING_MODES.size(): return
		settings.set_value("scale", PRESETS.SCALING_MODES[index])
		show_settings.call_deferred(return_action)
	)
	row.add_child(control)

## The tabs of the screen that is up -- the settings', a tape's report, the
## marks -- and on each page the rows a pad can stop on.
var settings_tabs: TabContainer
var settings_rows: Array = []
## What is under the tabs, where "down" ends up from the last row of a page.
var chained_back: Control
## A page with nothing to mark on it (a tape's report, the credits of a
## floor): the right stick rolls it.
var pad_scroll: ScrollContainer
const FAMILY_NAMES := {"xbox": "Xbox o compatible", "playstation": "PlayStation", "nintendo": "Nintendo"}

## Down and up on a pad walk every row of a page, in order, and only then
## reach "Volver"; the page rolls to follow what is marked. Left to Godot, the
## next control down was looked for on the screen, and the rows the page had
## not rolled to yet were not on it: at the last row showing, down went
## straight to "Volver" and the rest could not be reached.
func chain_settings(tabs: TabContainer, back: Control) -> void:
	settings_tabs = tabs
	chained_back = back
	settings_rows.clear()
	var bar := tabs.get_tab_bar()
	for index in tabs.get_tab_count():
		var scroll := tabs.get_tab_control(index) as ScrollContainer
		scroll.follow_focus = true
		var rows: Array = []
		rows_of(scroll.get_child(0), rows)
		settings_rows.append(rows)
		for i in rows.size():
			for k in rows[i].size():
				var control: Control = rows[i][k]
				var above: Control = bar if i == 0 else rows[i - 1][mini(k, rows[i - 1].size() - 1)]
				var below: Control = back if i == rows.size() - 1 else rows[i + 1][mini(k, rows[i + 1].size() - 1)]
				control.focus_neighbor_top = control.get_path_to(above)
				control.focus_neighbor_bottom = control.get_path_to(below)
	aim_tab(tabs.current_tab)
	if not tabs.tab_changed.is_connected(aim_tab): tabs.tab_changed.connect(aim_tab)

## The rows of a page: each thing in it is one, and a list inside the page (a
## board's lines) gives one for each of its own.
func rows_of(holder: Node, rows: Array) -> void:
	for child in holder.get_children():
		if child is VBoxContainer:
			rows_of(child, rows)
			continue
		var row: Array = []
		focusable(child, row)
		if not row.is_empty(): rows.append(row)

## Between the tab bar and what is under the tabs lie the rows of the page
## that is showing, or nothing: then the two lead to each other.
func aim_tab(index: int) -> void:
	if not is_instance_valid(settings_tabs) or not is_instance_valid(chained_back): return
	var bar := settings_tabs.get_tab_bar()
	var rows: Array = settings_rows[index] if index < settings_rows.size() else []
	pad_scroll = (settings_tabs.get_tab_control(index) as ScrollContainer) if rows.is_empty() else null
	if rows.is_empty():
		bar.focus_neighbor_bottom = bar.get_path_to(chained_back)
		chained_back.focus_neighbor_top = chained_back.get_path_to(bar)
		return
	bar.focus_neighbor_bottom = bar.get_path_to(rows[0][0])
	chained_back.focus_neighbor_top = chained_back.get_path_to(rows[rows.size() - 1][0])

## The rows of a page changed under it (a board showing another table).
func rechain() -> void:
	if is_instance_valid(settings_tabs) and is_instance_valid(chained_back) and settings_tabs.is_inside_tree(): chain_settings(settings_tabs, chained_back)

func focusable(node: Node, into: Array) -> void:
	if node is Control and (node as Control).focus_mode != Control.FOCUS_NONE and (node as Control).visible: into.append(node)
	for child in node.get_children(): focusable(child, into)

## The shoulders: the tab before or after, its first row marked.
func turn_tab(step: int) -> void:
	if not is_instance_valid(settings_tabs): return
	settings_tabs.current_tab = posmod(settings_tabs.current_tab + step, settings_tabs.get_tab_count())
	tick()
	var rows: Array = settings_rows[settings_tabs.current_tab] if settings_tabs.current_tab < settings_rows.size() else []
	var scroll := settings_tabs.get_current_tab_control() as ScrollContainer
	if scroll != null: scroll.scroll_vertical = 0
	if not rows.is_empty(): (rows[0][0] as Control).grab_focus()
	else:
		# Nothing to mark on this page: what was marked stays so, unless it
		# went with the page left behind.
		var marked := get_viewport().gui_get_focus_owner()
		if marked == null or not marked.is_visible_in_tree(): settings_tabs.get_tab_bar().grab_focus()

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
	control.item_selected.connect(func(index):
		tick()
		settings.set_value(key, values[index])
		# A preset, renderer, upscaler or window change redraws what depends
		# on it (the notes under the preset, what the upscaler leaves usable).
		if key in ["quality", "renderer", "upscaler", "window_mode"]: show_settings.call_deferred(return_action)
	)
	row.add_child(control)

## refresh: the rest of the screen depends on this value (the scale names the
## quality of the reconstruction above it), so it is redrawn once the hand
## lets the slider go -- not on every step of the drag.
func slider(parent: Node, title_text: String, key: String, low: float, high: float, step: float, disabled := false, refresh := false) -> void:
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
	control.editable = not disabled
	row.add_child(control)
	# Sliders that end at 1 read as percentages; others show their raw value.
	var percent := high == 1.0
	var number := label(row, ("%d%%" % roundi(control.value * 100)) if percent else ("%.4f" % control.value), 17)
	number.add_theme_color_override("font_color", STYLE.SOFT)
	control.value_changed.connect(func(value): settings.set_value(key, value); number.text = ("%d%%" % roundi(value * 100)) if percent else ("%.4f" % value))
	if refresh: control.drag_ended.connect(func(changed): if changed: show_settings.call_deferred(return_action))

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
	camera.current = true
	chosen.text = "SELECCIONADO · %s" % visual_script.NAMES[settings.values.character].to_upper()
	chosen.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chosen.size_flags_horizontal = Control.SIZE_SHRINK_END
	side.add_child(chosen)
	transition(0.35)
	quiet_focus = true
	buttons["character_%d" % settings.values.character].grab_focus()
	quiet_focus = false

## How far along a key held in play is (0 to 1), for the ring round the dot;
## below nought, nothing is being held. Called every frame it is held.
func hold(fraction: float) -> void:
	if is_instance_valid(hold_ring): hold_ring.hold(fraction)

## The same for skipping the opening scene, beside the words that say how.
func hold_skip(fraction: float) -> void:
	if is_instance_valid(skip_ring): skip_ring.hold(fraction)

## Short OSD message in the top-left corner of the recording.
## Shows the skip key in the top right corner, fading out after a few seconds.
## Held, not tapped: people pressed the key once and waited. Said again, in
## full, every time the key is touched.
func show_skip(key: String, seconds := 6.0) -> void:
	skip_label.text = "Mantén %s para saltar la cinemática" % key
	skip_label.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_interval(seconds)
	fade.tween_property(skip_label, "modulate:a", 0.0, 1.2)

func hide_skip() -> void:
	skip_label.text = ""

## The cut between one wing and the next. The car takes the picture with it,
## and on that black the tape puts up where this is and what the stage wants.
## It is the only pause a floor has: the one moment an errand can be read
## instead of glimpsed over a shoulder while something walks towards you.
var transit: Control
var transit_tween: Tween

func show_transit(title: String, errand: String, seconds: float) -> void:
	hide_transit()
	transit = ColorRect.new()
	transit.name = "Transit"
	transit.color = Color.BLACK
	transit.set_anchors_preset(Control.PRESET_FULL_RECT)
	transit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transit.modulate.a = 0.0
	add_child(transit)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	transit.add_child(column)
	var head := STYLE.text(title, 54)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(head)
	var rule := ColorRect.new()
	rule.color = STYLE.FAINT
	rule.custom_minimum_size = Vector2(280, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(rule)
	var line := STYLE.text(errand, 26, STYLE.AMBER)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(line)
	# Up after the picture has gone, and down before it comes back, so the
	# card is the whole of what there is to look at while it is up.
	var span := maxf(1.2, seconds)
	transit_tween = create_tween()
	transit_tween.tween_interval(span * 0.12)
	transit_tween.tween_property(transit, "modulate:a", 1.0, span * 0.14)
	transit_tween.tween_interval(span * 0.5)
	transit_tween.tween_property(transit, "modulate:a", 0.0, span * 0.16)
	transit_tween.tween_callback(hide_transit)

## The notice of a sector, once the card is gone and the picture is back: what
## this one wants, small in the top left corner under the OSD line, for six
## seconds. It comes in out of the snow and goes back into it the way a weak
## analogue signal goes -- the lines roll like water, the picture smears and the
## static eats it -- which is why it is drawn into its own little picture first:
## the shader works on that picture as a whole, not letter by letter.
const BRIEF_HOLD := 6.0
## Seconds the first floor's warning is up on its own before its objective.
const BRIEF_LEAD := 2.2
const BRIEF_IN := 0.45
const BRIEF_OUT := 1.5
const BRIEF_SIZE := Vector2i(560, 170)
const WASH := preload("res://game/ui/shaders/signal_wash.gdshader")
var brief: Control
var brief_tween: Tween
## What the pause screen keeps of it: the sector, what it asks for, and how it
## is going, set by the level before the screen is built.
var briefing := {"sector": "", "objective": "", "progress": []}

## `lead`: a line said first, before the objective comes up under it (the
## very first floor somebody plays); `hold`: how long it all stays.
func show_brief(sector: String, words: String, lead := "", hold := BRIEF_HOLD) -> void:
	hide_brief()
	brief = Control.new()
	brief.name = "Brief"
	brief.set_anchors_preset(Control.PRESET_FULL_RECT)
	brief.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brief)
	# Under the sheet: whoever opens it is looking at the sheet, and a notice
	# on top of the page would be written over what they are drawing.
	if is_instance_valid(sheet): move_child(brief, sheet.get_index())
	var picture := SubViewport.new()
	picture.size = BRIEF_SIZE
	picture.transparent_bg = true
	picture.disable_3d = true
	picture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	brief.add_child(picture)
	# A smudge of shade behind the words, soft all round and darkest behind
	# them, so they read over a lit wall as well as over a dark corridor.
	var smudge := Gradient.new()
	smudge.set_color(0, Color(0, 0, 0, 0.66))
	smudge.set_color(1, Color(0, 0, 0, 0))
	var soft := GradientTexture2D.new()
	soft.gradient = smudge
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.28, 0.5)
	soft.fill_to = Vector2(0.98, 0.5)
	var shade := TextureRect.new()
	shade.texture = soft
	shade.size = Vector2(BRIEF_SIZE)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.add_child(shade)
	# Room is left round the words so the swell has somewhere to roll to.
	var column := VBoxContainer.new()
	column.position = Vector2(18, 16)
	column.size = Vector2(BRIEF_SIZE.x - 36, BRIEF_SIZE.y - 32)
	column.add_theme_constant_override("separation", 4)
	picture.add_child(column)
	var head := STYLE.text("OBJETIVO · %s" % sector, 18, STYLE.AMBER)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(head)
	if not lead.is_empty():
		var warning := STYLE.text(lead, 26, STYLE.ALERT)
		warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		column.add_child(warning)
	var line := STYLE.text(words, 24)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = BRIEF_SIZE.x - 36
	column.add_child(line)
	# After the warning has been read, the objective comes up under it.
	if not lead.is_empty():
		line.modulate.a = 0.0
		var after := line.create_tween()
		after.tween_interval(BRIEF_LEAD)
		after.tween_property(line, "modulate:a", 1.0, 0.6)
	var screen := TextureRect.new()
	screen.texture = picture.get_texture()
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	# The words start where the OSD's own line starts.
	screen.offset_left = 30
	screen.offset_right = 30 + BRIEF_SIZE.x
	screen.offset_top = 112
	screen.offset_bottom = 112 + BRIEF_SIZE.y
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = WASH
	look.set_shader_parameter("wash", 1.0)
	screen.material = look
	brief.add_child(screen)
	var wash := func(amount: float): look.set_shader_parameter("wash", amount)
	brief_tween = create_tween()
	brief_tween.tween_method(wash, 1.0, 0.0, BRIEF_IN).set_ease(Tween.EASE_OUT)
	brief_tween.tween_interval(hold - BRIEF_IN - BRIEF_OUT)
	brief_tween.tween_method(wash, 0.0, 1.0, BRIEF_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	brief_tween.tween_callback(hide_brief)

func hide_brief() -> void:
	if is_instance_valid(brief_tween): brief_tween.kill()
	brief_tween = null
	if is_instance_valid(brief): brief.queue_free()
	brief = null

func set_briefing(sector: String, objective: String, progress: Array) -> void:
	briefing = {"sector": sector, "objective": objective, "progress": progress}

func hide_transit() -> void:
	if is_instance_valid(transit_tween): transit_tween.kill()
	transit_tween = null
	if is_instance_valid(transit): transit.queue_free()
	transit = null

func flash(words: String, seconds := 2.5) -> void:
	flash_label.text = words
	flash_time = seconds

## A victim in a match that goes on without it: the same words as the failure
## screen, over the static, without stopping anybody else's game.
func lost_signal(seconds := 2.6) -> void:
	flash_label.add_theme_color_override("font_color", STYLE.ALERT)
	flash("SEÑAL PERDIDA", seconds)

func _process(delta: float) -> void:
	clock += delta
	if is_instance_valid(pad_scroll) and pad_scroll.is_visible_in_tree():
		var roll := Input.get_axis("look_up", "look_down")
		if absf(roll) > 0.0: pad_scroll.scroll_vertical += int(roll * 900.0 * delta)
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
		if flash_time <= 0:
			flash_label.text = ""
			flash_label.remove_theme_color_override("font_color")

func _display_changed(seconds: int) -> void:
	if is_instance_valid(display_label):
		display_label.text = "Confirma la pantalla: se revertirá en %d s." % seconds if seconds > 0 else ""
	if is_instance_valid(display_row):
		if seconds > 0 and not display_row.visible and settings.using_pad and display_row.get_child_count() > 0: (display_row.get_child(0) as Control).grab_focus.call_deferred()
		display_row.visible = seconds > 0
	var refresh := seconds == 0 and display_was_pending and settings_open
	display_was_pending = seconds > 0
	if refresh: show_settings.call_deferred(return_action)

func _input(event: InputEvent) -> void:
	if is_instance_valid(intro) and event is InputEventKey and event.pressed:
		get_viewport().set_input_as_handled()
		finish_intro()
		return
	if not rebind_pad.is_empty() and event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		var button := int((event as InputEventJoypadButton).button_index)
		if button == JOY_BUTTON_B or settings.bind_pad(rebind_pad, button):
			rebind_button.text = settings.pad_name(rebind_pad)
			rebind_pad = ""
		else: rebind_button.text = "BOTÓN RESERVADO · %s CANCELA" % settings.button_name(JOY_BUTTON_B)
		return
	# The tabs of whatever screen has them: the shoulders of a pad, and on the
	# reports and the marks Q and E as well (the settings take keys to bind).
	var tabbed: bool = is_instance_valid(settings_tabs) and overlay.visible and settings_tabs.is_visible_in_tree()
	if tabbed and event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		get_viewport().set_input_as_handled()
		turn_tab(1 if event.button_index == JOY_BUTTON_RIGHT_SHOULDER else -1)
		return
	if tabbed and screen != "settings" and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_Q, KEY_E] and not (get_viewport().gui_get_focus_owner() is LineEdit):
		get_viewport().set_input_as_handled()
		turn_tab(1 if event.physical_keycode == KEY_E else -1)
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
	outside.add_child(intro)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro.add_child(black)
	var blue := ColorRect.new()
	blue.name = "Tape"
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
	# Before the tape starts, on the black it opens with: put your headphones
	# on. The floor is played by ear -- the distances, which way the creature
	# is, a door two rooms off -- and whoever opens the game on speakers has no
	# way of knowing what they are missing. A notice, not a menu: it is read,
	# and it goes with the black.
	var notice := CenterContainer.new()
	notice.name = "Headphones"
	notice.set_anchors_preset(Control.PRESET_FULL_RECT)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.modulate.a = 0.0
	intro.add_child(notice)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 30)
	notice.add_child(column)
	var mark := STYLE.headphones(104.0)
	mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(mark)
	var words := STYLE.text("AURICULARES SUGERIDOS", 30, STYLE.MUTED)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(words)
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
	# The notice comes up out of the black, is held long enough to read, and
	# goes before anything else happens.
	intro_tween.tween_interval(0.3)
	intro_tween.tween_property(notice, "modulate:a", 1.0, 0.45)
	intro_tween.tween_interval(1.6)
	intro_tween.tween_property(notice, "modulate:a", 0.0, 0.45)
	intro_tween.tween_interval(0.3)
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
