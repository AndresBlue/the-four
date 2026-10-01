extends RefCounted
## The marks a player keeps, in tabs: the boards of each floor (TABLONES), the
## player's own career (FICHA), the milestones of every floor (HITOS) and the
## cards of the people played with, side by side with one's own (COMPARAR).
## Everything is read out of records_service.gd; a line picked on a board
## opens its whole report (tape_report.gd, through hotel_ui.show_tape).
##
## Built into the menus by hotel_ui.gd, which owns the helpers used here and
## remembers what was being looked at (`view`: the tab, the board, the table).
const STYLE := preload("res://game/ui/osd_style.gd")
const SCORE := preload("res://game/services/run_score.gd")
const RECORDS := preload("res://game/services/records_service.gd")
const FLOORS := preload("res://game/floors/floor_index.gd")
const REPORT := preload("res://game/ui/tape_report.gd")
const SIZE := Vector2(1040, 404)
## How many cards fit beside one's own.
const RIVALS_SHOWN := 3

static func build(ui, parent: Node, view: Dictionary) -> TabContainer:
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = SIZE
	tabs.add_theme_font_size_override("font_size", 18)
	parent.add_child(tabs)
	boards(ui, REPORT.sheet(ui, tabs, "TABLONES"), view)
	profile(ui, REPORT.sheet(ui, tabs, "FICHA"))
	milestones(ui, REPORT.sheet(ui, tabs, "HITOS"))
	compare(ui, REPORT.sheet(ui, tabs, "COMPARAR"), view)
	tabs.current_tab = clampi(int(view.get("tab", 0)), 0, tabs.get_tab_count() - 1)
	tabs.tab_changed.connect(func(index: int): view["tab"] = index)
	return tabs

# --- TABLONES ---------------------------------------------------------------------

## The columns of a board: [heading, width].
const COLUMNS := [["", 44], ["TIEMPO", 104], ["PUNTOS", 84], ["", 30], ["QUIÉN", 330], ["CINTA Nº", 150], ["FECHA", 110]]

static func boards(ui, page: VBoxContainer, view: Dictionary) -> void:
	page.add_theme_constant_override("separation", 4)
	var records = ui.records
	# The board looked at last; the first time, the one with something on it.
	if not view.has("company"):
		view["company"] = RECORDS.SOLO
		for company in RECORDS.COMPANIES:
			if not records.table_of("time", 1, company).is_empty():
				view["company"] = company
				break
	if not view.has("table"): view["table"] = "time"
	var picks := REPORT.row_in(page, 18)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	var names: Array = RECORDS.COMPANIES.map(func(company): return String(RECORDS.COMPANY_NAMES[company]))
	option(ui, picks, "TABLÓN", names, RECORDS.COMPANIES.find(String(view.company)), 290, func(index: int):
		view["company"] = RECORDS.COMPANIES[index]
		fill(ui, list, view))
	var titles: Array = RECORDS.TABLES.map(func(table): return String(table.title))
	var ids: Array = RECORDS.TABLES.map(func(table): return String(table.id))
	option(ui, picks, "TABLA", titles, ids.find(String(view.table)), 250, func(index: int):
		view["table"] = ids[index]
		fill(ui, list, view))
	page.add_child(list)
	fill(ui, list, view)

static func option(ui, parent: Node, caption: String, names: Array, selected: int, width: float, on_pick: Callable) -> void:
	ui.label(parent, caption, 16).add_theme_color_override("font_color", STYLE.SOFT)
	var control := OptionButton.new()
	control.custom_minimum_size.x = width
	control.add_theme_font_size_override("font_size", 17)
	for words in names: control.add_item(words)
	control.select(maxi(selected, 0))
	control.item_selected.connect(func(index: int):
		ui.tick()
		on_pick.call(index))
	parent.add_child(control)

## The lines of the board and table being looked at.
static func fill(ui, list: VBoxContainer, view: Dictionary) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	var records = ui.records
	var table: Dictionary = RECORDS.TABLES[0]
	for candidate in RECORDS.TABLES:
		if String(candidate.id) == String(view.table): table = candidate
	ui.label(list, String(table.note), 14).add_theme_color_override("font_color", STYLE.SOFT)
	ui.spacer(list, 4)
	var lines: Array = records.table_of(String(table.id), 1, String(view.company))
	if lines.is_empty():
		ui.spacer(list, 12)
		ui.paragraph(list, "Todavía no hay ninguna cinta en este tablón.", 18, 900)
		ui.rechain()
		return
	var head := REPORT.row_in(list, 10)
	for column in COLUMNS: STYLE.cell(head, column[0], column[1], 13, STYLE.SOFT)
	# The tape that has just got out, picked out of the list.
	var mine: Dictionary = ui.summary if SCORE.won(ui.summary) and ui.summary.has("date") else {}
	for index in lines.size():
		var line: Dictionary = lines[index]
		var own: bool = not mine.is_empty() and String(line.get("date", "")) == String(mine.date) and int(line.get("seed", 0)) == int(mine.get("seed", 0)) and is_equal_approx(float(line.get("time", 0.0)), float(mine.get("time", 0.0)))
		var ink := STYLE.AMBER if own else STYLE.INK
		var names: Array = line.get("team", []).map(func(member): return String(member.get("name", "")))
		var who := " · ".join(names) if not names.is_empty() else "%d superviviente%s" % [int(line.get("players", 1)), "" if int(line.get("players", 1)) == 1 else "s"]
		var cells := [
			["%d." % (index + 1), STYLE.SOFT if index > 0 else STYLE.AMBER],
			[ui.tape_time(float(line.get("time", 0.0))), ink],
			[STYLE.grouped(int(line.score)) if line.has("score") else "—", ink],
			[String(line.get("grade", "")), STYLE.AMBER],
			[who.to_upper(), ink],
			[str(int(line.get("seed", 0))), STYLE.SOFT],
			[String(line.get("date", "")).left(10), STYLE.SOFT],
		]
		line_button(ui, list, cells, func(): ui.show_tape(line))
	ui.spacer(list, 6)
	ui.label(list, "ELIGE UNA CINTA PARA LEER SU PARTE ENTERO.", 13).add_theme_color_override("font_color", STYLE.FAINT)
	ui.rechain()

## One line of a board: a row that can be marked and picked.
static func line_button(ui, parent: Node, cells: Array, on_pick: Callable) -> void:
	var button := Button.new()
	button.custom_minimum_size.y = 27
	button.add_theme_stylebox_override("hover", STYLE.flat(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 0))
	button.add_theme_stylebox_override("focus", STYLE.flat(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0, 0))
	button.add_theme_stylebox_override("pressed", STYLE.flat(Color(1, 1, 1, 0.16), Color(0, 0, 0, 0), 0, 0))
	button.focus_entered.connect(ui.tick)
	button.mouse_entered.connect(func(): button.grab_focus())
	button.pressed.connect(func():
		ui.confirm()
		on_pick.call())
	parent.add_child(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)
	for index in cells.size():
		STYLE.cell(row, cells[index][0], COLUMNS[index][1], 17, cells[index][1]).vertical_alignment = VERTICAL_ALIGNMENT_CENTER

# --- FICHA ------------------------------------------------------------------------

static func profile(ui, page: VBoxContainer) -> void:
	page.add_theme_constant_override("separation", 6)
	var records = ui.records
	var career: Dictionary = records.career
	# The name the boards and the rooms know this player by.
	ui.field(page, "Tu nombre", "player_name", "Ingresa tu nombre")
	ui.spacer(page, 4)
	var split := REPORT.row_in(page, 40)
	var left := VBoxContainer.new()
	var right := VBoxContainer.new()
	for side in [left, right]:
		side.add_theme_constant_override("separation", 3)
		split.add_child(side)
	var clock := func(seconds: float) -> String: return ui.tape_time(seconds) if seconds >= 0.0 else "—"
	var known := 0
	for floor_number in range(1, FLOORS.COUNT + 1): known += FLOORS.milestones(floor_number).size()
	var grade := String(career.get("best_grade", ""))
	stat(left, "PISOS SUPERADOS", str(int(career.get("floors", 0))), STYLE.AMBER)
	stat(left, "CINTAS PERDIDAS", str(int(career.get("lost", 0))))
	stat(left, "TIEMPO GRABADO", ui.tape_time(float(career.get("time", 0))))
	stat(left, "MEJOR TIEMPO A SOLAS", clock.call(records.best(1, RECORDS.SOLO, "time")))
	stat(left, "MEJOR TIEMPO EN EQUIPO", clock.call(records.best(1, RECORDS.COOP, "time")))
	stat(left, "MEJOR PUNTAJE", STYLE.grouped(int(career.get("best_score", 0))) if int(career.get("best_score", 0)) > 0 else "—")
	stat(left, "MEJOR NOTA", grade if not grade.is_empty() else "—", STYLE.AMBER)
	stat(left, "VECES MÁS VALIOSO", str(int(career.get("mvps", 0))))
	stat(left, "HITOS", "%d / %d" % [records.reached_count(), known])
	stat(right, "TELEVISORES ENCENDIDOS", str(int(career.get("tvs", 0))))
	stat(right, "NÚMEROS ENCONTRADOS", str(int(career.get("digits", 0))))
	stat(right, "CÓDIGOS MARCADOS", str(int(career.get("code", 0))))
	stat(right, "MUEBLES REGISTRADOS", str(int(career.get("searched", 0))))
	stat(right, "HUIDAS DE LA CRIATURA", str(int(career.get("escapes", 0))))
	stat(right, "CAÍDAS", str(int(career.get("deaths", 0))))
	stat(right, "VECES EN UN ARMARIO", str(int(career.get("hides", 0))))
	stat(right, "METROS ANDADOS", STYLE.grouped(int(career.get("metres", 0))))
	var usual: String = records.usual_part()
	stat(right, "PAPEL HABITUAL", usual if not usual.is_empty() else "—", STYLE.AMBER)
	if int(career.get("hunts", 0)) > 0:
		stat(right, "COMO THE LOCUST", "%d caza%s, %d captura%s" % [int(career.hunts), "" if int(career.hunts) == 1 else "s", int(career.get("catches", 0)), "" if int(career.get("catches", 0)) == 1 else "s"], STYLE.ALERT)

static func stat(parent: Node, caption: String, value: String, ink := STYLE.INK) -> void:
	var row := REPORT.row_in(parent, 10)
	STYLE.cell(row, caption, 270, 16, STYLE.SOFT)
	STYLE.cell(row, value, 200, 18, ink)

# --- HITOS ------------------------------------------------------------------------

static func milestones(ui, page: VBoxContainer) -> void:
	page.add_theme_constant_override("separation", 6)
	var records = ui.records
	for floor_number in range(1, FLOORS.COUNT + 1):
		var known: Array = FLOORS.milestones(floor_number)
		if known.is_empty():
			ui.label(page, "%s  ·  SIN GRABAR" % FLOORS.title(floor_number), 18).add_theme_color_override("font_color", STYLE.FAINT)
			continue
		var head := REPORT.row_in(page, 16)
		ui.label(head, FLOORS.title(floor_number), 20).add_theme_color_override("font_color", STYLE.AMBER)
		var reached: int = records.reached_count(floor_number)
		ui.label(head, "%d / %d" % [reached, known.size()], 20)
		var level := STYLE.meter(float(reached) / float(known.size()), 220, STYLE.AMBER, 8.0)
		head.add_child(level)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 26)
		grid.add_theme_constant_override("v_separation", 6)
		page.add_child(grid)
		for milestone in known:
			var day: String = records.reached(floor_number, String(milestone.id))
			var done := not day.is_empty()
			var row := REPORT.row_in(grid, 10)
			STYLE.cell(row, "■" if done else "□", 20, 18, STYLE.AMBER if done else STYLE.FAINT)
			var words := VBoxContainer.new()
			words.add_theme_constant_override("separation", 0)
			words.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(words)
			var top := REPORT.row_in(words, 10)
			STYLE.cell(top, String(milestone.title), 300, 17, STYLE.INK if done else STYLE.SOFT)
			STYLE.cell(top, day, 110, 13, STYLE.AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
			STYLE.cell(words, String(milestone.note), 440, 13, STYLE.SOFT if done else STYLE.FAINT)
		ui.spacer(page, 8)

# --- COMPARAR ---------------------------------------------------------------------

static func compare(ui, page: VBoxContainer, view: Dictionary) -> void:
	page.add_theme_constant_override("separation", 0)
	var records = ui.records
	var others: Array = records.rival_cards()
	if others.is_empty():
		ui.paragraph(page, "Aquí se ponen, al lado de la tuya, las fichas de la gente con la que juegas: cada uno dice la suya al empezar un piso en línea, y se queda guardada para leerla después, con o sin conexión.", 17, 900)
		ui.spacer(page, 6)
		ui.paragraph(page, "Todavía no has jugado con nadie desde que existen las fichas.", 17, 900, STYLE.AMBER)
		return
	var pages := int(ceil(float(others.size()) / RIVALS_SHOWN))
	var at := clampi(int(view.get("rivals", 0)), 0, pages - 1)
	var shown: Array = others.slice(at * RIVALS_SHOWN, (at + 1) * RIVALS_SHOWN)
	var own_name := String(ui.settings.values.player_name).strip_edges() if ui.settings != null else ""
	var cards: Array = [records.card(own_name if not own_name.is_empty() else "TÚ")] + shown
	const KEY := 250.0
	const WIDE := 172.0
	var head := REPORT.row_in(page, 10)
	STYLE.cell(head, "", KEY, 16)
	for index in cards.size():
		STYLE.cell(head, String(cards[index].get("name", "")).to_upper(), WIDE, 18, STYLE.AMBER if index == 0 else STYLE.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	var under := REPORT.row_in(page, 10)
	STYLE.cell(under, "", KEY, 13)
	for index in cards.size():
		STYLE.cell(under, "TÚ" if index == 0 else String(cards[index].get("part", "")), WIDE, 13, STYLE.SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	ui.spacer(page, 4)
	for entry in RECORDS.CARD_ROWS:
		var key := String(entry[0])
		var kind := String(entry[2])
		var more: bool = entry[3]
		# Who leads the row, if anybody does: the same for all is nobody's.
		var values: Array = cards.map(func(card): return rank(card.get(key, 0), kind, more))
		var top: float = values.max()
		var leads: bool = top > -INF and values.count(top) < values.size()
		var row := REPORT.row_in(page, 10)
		STYLE.cell(row, String(entry[1]), KEY, 15, STYLE.SOFT)
		for index in cards.size():
			var ahead: bool = leads and is_equal_approx(float(values[index]), top)
			STYLE.cell(row, written(ui, cards[index].get(key, 0), kind), WIDE, 17, STYLE.AMBER if ahead else STYLE.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	ui.spacer(page, 4)
	var together := REPORT.row_in(page, 10)
	STYLE.cell(together, "PISOS JUNTOS", KEY, 15, STYLE.SOFT)
	for index in cards.size(): STYLE.cell(together, "" if index == 0 else str(int(cards[index].get("together", 0))), WIDE, 17, STYLE.INK, HORIZONTAL_ALIGNMENT_RIGHT)
	if pages > 1:
		ui.spacer(page, 6)
		var turn := REPORT.row_in(page, 12)
		for step in [-1, 1]:
			var box := Button.new()
			box.theme_type_variation = "BoxButton"
			box.text = "◀ ANTERIORES" if step < 0 else "SIGUIENTES ▶"
			box.disabled = at + step < 0 or at + step >= pages
			box.focus_mode = Control.FOCUS_NONE if box.disabled else Control.FOCUS_ALL
			box.pressed.connect(func():
				ui.confirm()
				view["rivals"] = at + step
				ui.menu.call_deferred("records"))
			turn.add_child(box)
		ui.label(turn, "%d DE %d" % [at + 1, pages], 15).add_theme_color_override("font_color", STYLE.SOFT)

## How good a value of a card is, to find who leads its row: more is better,
## or less is; a time or a mark nobody has yet is the worst there is.
static func rank(value: Variant, kind: String, more: bool) -> float:
	if kind == "grade":
		var at := ["D", "C", "B", "A", "S"].find(String(value))
		return float(at) if at >= 0 else -INF
	var amount := float(value)
	if kind == "clock" and amount < 0.0: return -INF
	return amount if more else -amount

static func written(ui, value: Variant, kind: String) -> String:
	match kind:
		"grade": return String(value) if not String(value).is_empty() else "—"
		"clock": return ui.tape_time(float(value)) if float(value) >= 0.0 else "—"
		"time": return ui.tape_time(float(value))
	return STYLE.grouped(int(value))
