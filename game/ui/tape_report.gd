extends RefCounted
## The report of one tape, in tabs: what it came to (RESUMEN), who did what
## (EQUIPO), how each sector went (SECTORES), the moments of the floor in
## order (CRONOLOGÍA) and, on the floor just played, the milestones it reached
## for the first time (HITOS). Read out of the line the floor left
## (game/app/run_ledger.gd, game/services/run_score.gd), so the same screen
## shows the floor that has just ended and any tape kept on the boards.
##
## Built into the menus by hotel_ui.gd, which owns the helpers used here
## (label, paragraph, spacer, page, tape_time) and the walk between tabs.
const STYLE := preload("res://game/ui/osd_style.gd")
const SCORE := preload("res://game/services/run_score.gd")
const RECORDS := preload("res://game/services/records_service.gd")
const FLOORS := preload("res://game/floors/floor_index.gd")
## The tabs' box, in the 1280 x 720 the menus are laid out in.
const SIZE := Vector2(1040, 372)

## `outcome`: what filing it said (records_service.file()); empty for a tape
## read off the board.
static func build(ui, parent: Node, line: Dictionary, outcome := {}) -> TabContainer:
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = SIZE
	tabs.add_theme_font_size_override("font_size", 18)
	parent.add_child(tabs)
	summary(ui, sheet(ui, tabs, "RESUMEN"), line, outcome)
	team(ui, sheet(ui, tabs, "EQUIPO"), line)
	sectors(ui, sheet(ui, tabs, "SECTORES"), line, outcome)
	timeline(ui, sheet(ui, tabs, "CRONOLOGÍA"), line)
	# On the floor just played: what it reached. A tape that never got out
	# reaches nothing, unless it was the hunter's.
	if outcome.has("milestones") and (SCORE.won(line) or not outcome.milestones.is_empty()): milestones(ui, sheet(ui, tabs, "HITOS"), line, outcome)
	return tabs

## A page of the tabs, with a little air over its first line: the page rolls,
## and what rolls is cut at its edge -- the accent of a capital on the first
## line went with it.
static func sheet(ui, tabs: TabContainer, title: String) -> VBoxContainer:
	var page: VBoxContainer = ui.page(tabs, title)
	ui.spacer(page, 3)
	return page

## What tape this is, in one line: its number, its floor and who played it.
static func heading(line: Dictionary) -> String:
	var players := int(line.get("players", 1))
	var words := "CINTA Nº %d  ·  %s  ·  %s" % [int(line.get("seed", 0)), FLOORS.title(int(line.get("floor", 1))), String(RECORDS.COMPANY_NAMES.get(String(line.get("company", RECORDS.SOLO)), ""))]
	if players > 1: words += "  ·  %d SUPERVIVIENTES" % players
	var date := String(line.get("date", "")).left(10)
	return words + ("  ·  " + date if not date.is_empty() else "")

static func name_of(line: Dictionary, seat: int) -> String:
	var member := SCORE.member_of(line, seat)
	if not member.is_empty(): return String(member.get("name", "")).to_upper()
	if int(line.get("hunter", {}).get("seat", -1)) == seat: return String(line.hunter.get("name", "")).to_upper()
	return "ALGUIEN"

## A figure that counts itself up, the way a counter does when a tape is rewound.
static func count_up(figure: Label, target: float, write: Callable, delay := 0.0) -> void:
	figure.text = write.call(0.0)
	var counting := figure.create_tween()
	if delay > 0.0: counting.tween_interval(delay)
	counting.tween_method(func(value: float): figure.text = write.call(value), 0.0, target, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func row_in(parent: Node, separation := 10) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	return row

# --- RESUMEN ----------------------------------------------------------------------

static func summary(ui, page: VBoxContainer, line: Dictionary, outcome: Dictionary) -> void:
	var won := SCORE.won(line)
	var split := row_in(page, 28)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 610
	left.add_theme_constant_override("separation", 8)
	split.add_child(left)
	var figures := row_in(left, 40)
	var time := float(line.get("time", 0.0))
	count_up(STYLE.figure(figures, "TIEMPO DE GRABACIÓN", "", 34, STYLE.AMBER if won else STYLE.ALERT), time, func(value: float): return ui.tape_time(value))
	if line.has("score"):
		count_up(STYLE.figure(figures, "PUNTAJE", "", 34), float(line.score), func(value: float): return STYLE.grouped(int(value)), 0.3)
	var grade := String(line.get("grade", ""))
	if won and not grade.is_empty():
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 0)
		figures.add_child(block)
		block.add_child(STYLE.text("NOTA", 14, STYLE.SOFT))
		block.add_child(STYLE.stamp(grade, 40, STYLE.AMBER if SCORE.grade_at_least(grade, "A") else STYLE.INK, -0.1, 1.5))
	elif not won:
		var kind: GDScript = FLOORS.kind(int(line.get("floor", 1)))
		STYLE.figure(figures, "SECTOR ALCANZADO", "%d / %d" % [int(line.get("stage", 1)), kind.count() if kind != null else 3], 34)
	# The floor in four counts, whoever they were.
	var members: Array = line.get("team", [])
	if not members.is_empty() and members[0].has("metres"):
		var sums := {"escapes": 0, "tvs": 0, "metres": 0}
		for member in members:
			for key in sums: sums[key] = int(sums[key]) + int(member.get(key, 0))
		var counts := row_in(left, 34)
		STYLE.figure(counts, "CAÍDAS", str(int(line.get("deaths", 0))), 22, STYLE.ALERT if int(line.get("deaths", 0)) > 0 else STYLE.INK)
		STYLE.figure(counts, "HUIDAS", str(int(sums.escapes)), 22)
		STYLE.figure(counts, "TELEVISORES", str(int(sums.tvs)), 22)
		STYLE.figure(counts, "VECES EN ARMARIOS", str(int(line.get("hides", 0))), 22)
		STYLE.figure(counts, "METROS ANDADOS", STYLE.grouped(int(sums.metres)), 22)
	# Against what the board held before it.
	var previous: Dictionary = outcome.get("previous", {})
	if won and not previous.is_empty():
		ui.spacer(left, 2)
		var best_time := float(previous.get("time", -1.0))
		if best_time < 0.0: ui.label(left, "PRIMERA CINTA DE ESTE TABLÓN", 17).add_theme_color_override("font_color", STYLE.AMBER)
		else:
			var beaten := time < best_time
			var words := ("MEJORA LA MEJOR MARCA EN %s" if beaten else "A %s DE LA MEJOR MARCA") % SCORE.clock(int(absf(time - best_time)))
			ui.label(left, "%s  (%s)" % [words, ui.tape_time(best_time)], 17).add_theme_color_override("font_color", STYLE.AMBER if beaten else STYLE.SOFT)
			var best_score := int(previous.get("score", -1.0))
			var score := int(line.get("score", 0))
			if best_score > 0:
				var more := score > best_score
				var said := ("SUPERA EL MEJOR PUNTAJE EN %s" if more else "A %s DEL MEJOR PUNTAJE") % STYLE.grouped(absi(score - best_score))
				ui.label(left, "%s  (%s)" % [said, STYLE.grouped(best_score)], 17).add_theme_color_override("font_color", STYLE.AMBER if more else STYLE.SOFT)
	# The places it took, in one line.
	var places: Dictionary = outcome.get("places", {})
	var taken: Array = []
	for table in RECORDS.TABLES:
		if places.has(table.id) and int(places[table.id]) <= RECORDS.KEPT: taken.append("Nº %d EN %s" % [int(places[table.id]), table.title])
	if not taken.is_empty(): ui.paragraph(left, "  ·  ".join(taken), 17, 600, STYLE.INK)
	# What it earned, stamped on one at a time.
	var marks: Array = RECORDS.badges(line)
	if not marks.is_empty():
		var stamps := row_in(left, 10)
		var delay := 0.9
		for mark in marks:
			stamps.add_child(STYLE.stamp(mark, 16, STYLE.AMBER, -0.03, delay))
			delay += 0.35
	if not won: ui.paragraph(left, "La cinta se quedó en el hotel. No entra en ningún tablón, pero lo que hizo cada uno queda en su ficha.", 16, 600)
	spotlight(ui, split, line, not outcome.is_empty())

## Beside the figures: who was worth most, or the part the only one played
## (`fresh`: on the floor just played, where the only one is whoever reads it).
static func spotlight(ui, parent: Node, line: Dictionary, fresh: bool) -> void:
	var members: Array = line.get("team", [])
	if members.is_empty(): return
	var star := SCORE.member_of(line, int(line.get("mvp", 0)))
	var caption := "MÁS VALIOSO"
	if star.is_empty():
		# Alone, or a floor that was lost: whoever did most of it.
		for member in members:
			if star.is_empty() or SCORE.better(member, star): star = member
		caption = ("TU PAPEL" if fresh else "SU PAPEL") if members.size() == 1 else "QUIEN MÁS HIZO"
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", STYLE.flat(Color(0, 0, 0, 0.45), Color(STYLE.AMBER, 0.5), 1, 16))
	parent.add_child(panel)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	panel.add_child(card)
	ui.label(card, caption, 15).add_theme_color_override("font_color", STYLE.AMBER)
	var name_label := STYLE.cell(card, String(star.get("name", "")).to_upper(), 300, 30)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var part := String(star.get("title", ""))
	if not part.is_empty():
		ui.label(card, part, 19).add_theme_color_override("font_color", STYLE.AMBER)
		ui.paragraph(card, String(star.get("why", "")), 15, 300)
	if star.has("score"):
		ui.spacer(card, 4)
		ui.label(card, "%s PUNTOS" % STYLE.grouped(int(star.score)), 20)
	var deeds: Array = []
	for pair in [["tvs", "tele", "teles"], ["digits", "número", "números"], ["escapes", "huida", "huidas"], ["deaths", "caída", "caídas"]]:
		var many := int(star.get(pair[0], 0))
		if many > 0: deeds.append("%d %s" % [many, pair[1] if many == 1 else pair[2]])
	if not deeds.is_empty(): ui.paragraph(card, " · ".join(deeds), 15, 300)

# --- EQUIPO -----------------------------------------------------------------------

## The columns of the team's table: [heading, width, the member's key].
const COLUMNS := [["JUGADOR", 196, "name"], ["PAPEL", 176, "title"], ["PUNTOS", 86, "score"], ["TV", 40, "tvs"], ["Nº", 40, "digits"], ["HUIDAS", 72, "escapes"], ["CAÍDAS", 72, "deaths"], ["METROS", 76, "metres"], ["", 96, "escaped"]]
const MARK := 22

static func team(ui, page: VBoxContainer, line: Dictionary) -> void:
	page.add_theme_constant_override("separation", 4)
	var members: Array = line.get("team", []).duplicate()
	members.sort_custom(func(a, b): return SCORE.better(a, b))
	var won := SCORE.won(line)
	var star := int(line.get("mvp", 0))
	var head := row_in(page)
	STYLE.cell(head, "", MARK, 14)
	for column in COLUMNS:
		STYLE.cell(head, column[0], column[1], 14, STYLE.SOFT, HORIZONTAL_ALIGNMENT_LEFT if column[2] in ["name", "title", "escaped"] else HORIZONTAL_ALIGNMENT_RIGHT)
	var top := 1
	for member in members: top = maxi(top, int(member.get("score", 0)))
	for member in members:
		var best: bool = int(member.get("seat", -1)) == star and star != 0
		var out := bool(member.get("escaped", false))
		var ink := STYLE.AMBER if best else (STYLE.INK if out or not won else STYLE.SOFT)
		var row := row_in(page)
		STYLE.cell(row, "★" if best else "", MARK, 17, STYLE.AMBER)
		for column in COLUMNS:
			var key := String(column[2])
			match key:
				"name": STYLE.cell(row, String(member.get("name", "")).to_upper(), column[1], 18, ink)
				"title": STYLE.cell(row, String(member.get("title", "—")), column[1], 16, STYLE.AMBER if best else STYLE.SOFT)
				"escaped": STYLE.cell(row, ("SALIÓ" if out else "SE QUEDÓ") if won else "", column[1], 16, STYLE.SOFT if out else STYLE.ALERT)
				"score": STYLE.cell(row, STYLE.grouped(int(member.score)) if member.has("score") else "—", column[1], 18, ink, HORIZONTAL_ALIGNMENT_RIGHT)
				_: STYLE.cell(row, str(int(member[key])) if member.has(key) else "—", column[1], 17, STYLE.ALERT if key == "deaths" and int(member.get(key, 0)) > 0 else STYLE.INK, HORIZONTAL_ALIGNMENT_RIGHT)
		# Under the name: how much of the best one's points this one made, and why
		# the part is theirs.
		var under := row_in(page)
		STYLE.cell(under, "", MARK, 12)
		under.add_child(STYLE.meter(float(member.get("score", 0)) / float(top), 196, STYLE.AMBER if best else STYLE.MUTED, 5.0))
		STYLE.cell(under, String(member.get("why", "")), 560, 14, STYLE.SOFT)
		ui.spacer(page, 3)
	var hunter: Dictionary = line.get("hunter", {})
	if not hunter.is_empty():
		var row := row_in(page)
		STYLE.cell(row, "", MARK, 17)
		STYLE.cell(row, String(hunter.get("name", "")).to_upper(), 196, 18, STYLE.ALERT)
		STYLE.cell(row, "THE LOCUST · %d captura%s" % [int(line.get("deaths", 0)), "" if int(line.get("deaths", 0)) == 1 else "s"], 420, 16, STYLE.ALERT)
		ui.spacer(page, 3)
	# Alone, where its points came from, line by line.
	if members.size() == 1 and members[0].has("score"):
		ui.spacer(page, 4)
		ui.label(page, "DE DÓNDE SALEN SUS PUNTOS", 14).add_theme_color_override("font_color", STYLE.AMBER)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 48)
		grid.add_theme_constant_override("v_separation", 2)
		page.add_child(grid)
		for item in SCORE.breakdown(members[0]):
			var entry := row_in(grid, 8)
			STYLE.cell(entry, "%s%s" % [item[0], (" × %d" % int(item[1])) if int(item[1]) > 1 else ""], 300, 15, STYLE.SOFT)
			STYLE.cell(entry, signed(int(item[2])), 70, 15, STYLE.INK if int(item[2]) >= 0 else STYLE.ALERT, HORIZONTAL_ALIGNMENT_RIGHT)
	var earned: Array = SCORE.bonuses(line)
	if not earned.is_empty():
		ui.spacer(page, 4)
		ui.label(page, "LO QUE GANÓ EL EQUIPO JUNTO" if members.size() > 1 else "Y POR LA CINTA ENTERA", 14).add_theme_color_override("font_color", STYLE.AMBER)
		ui.paragraph(page, "   ·   ".join(earned.map(func(item): return "%s %s" % [item[0], signed(int(item[1]))])), 15, 960, STYLE.INK)
	var facts: Array = highlights(line, members)
	if not facts.is_empty():
		ui.spacer(page, 4)
		ui.label(page, "DESTACADO", 14).add_theme_color_override("font_color", STYLE.AMBER)
		ui.paragraph(page, "   ·   ".join(facts), 15, 960, STYLE.SOFT)

static func signed(value: int) -> String:
	return ("+" if value >= 0 else "−") + STYLE.grouped(absi(value))

## What stands out among the things that earn nothing: who walked furthest,
## who spent longest in a wardrobe, who had the creature closest, whose mind
## went lowest. Alone, the same things said of the only one.
static func highlights(line: Dictionary, members: Array) -> Array:
	var facts: Array = []
	var alone := members.size() == 1
	var lead := func(key: String, least: float, lowest: bool) -> Dictionary:
		var found: Dictionary = {}
		for member in members:
			if not member.has(key) or float(member[key]) < 0.0: continue
			if (lowest and float(member[key]) > least) or (not lowest and float(member[key]) < least): continue
			if found.is_empty() or (float(member[key]) < float(found[key]) if lowest else float(member[key]) > float(found[key])): found = member
		return found
	var who := func(member: Dictionary) -> String: return "" if alone else " (%s)" % String(member.get("name", "")).to_upper()
	var walker: Dictionary = lead.call("metres", 1.0, false)
	if not walker.is_empty(): facts.append("%d m andados%s%s" % [int(walker.metres), (", %d corriendo" % int(walker.get("run", 0))) if int(walker.get("run", 0)) > 0 else "", who.call(walker)])
	var hider: Dictionary = lead.call("hidden", 5.0, false)
	if not hider.is_empty(): facts.append("%s en armarios%s" % [SCORE.clock(int(hider.hidden)), who.call(hider)])
	var chased: Dictionary = lead.call("chased", 5.0, false)
	if not chased.is_empty(): facts.append("%s con la criatura detrás%s" % [SCORE.clock(int(chased.chased)), who.call(chased)])
	var close: Dictionary = lead.call("closest", 6.0, true)
	if not close.is_empty(): facts.append("la criatura a %s m%s" % [("%.1f" % float(close.closest)).replace(".", ","), who.call(close)])
	var frayed: Dictionary = lead.call("low", 40.0, true)
	if not frayed.is_empty(): facts.append("cordura hasta %d%s" % [int(frayed.low), who.call(frayed)])
	return facts

# --- SECTORES ---------------------------------------------------------------------

static func sectors(ui, page: VBoxContainer, line: Dictionary, outcome: Dictionary) -> void:
	page.add_theme_constant_override("separation", 4)
	var kind: GDScript = FLOORS.kind(int(line.get("floor", 1)))
	var marks: Array = line.get("sectors", [])
	var won := SCORE.won(line)
	var took: Array = []
	var before := 0.0
	for mark in marks:
		took.append(float(mark) - before)
		before = float(mark)
	# The sector a lost floor ended in: what it had been going for.
	var unfinished := -1.0 if won else float(line.get("time", 0.0)) - before
	var longest := 1.0
	for value in took: longest = maxf(longest, float(value))
	longest = maxf(longest, unfinished)
	var best: Array = outcome.get("previous", {}).get("splits", [])
	var count := took.size() + (1 if unfinished >= 0.0 else 0)
	for index in count:
		var closed := index < took.size()
		var seconds: float = float(took[index]) if closed else unfinished
		var row := row_in(page, 14)
		STYLE.cell(row, "SECTOR %d" % (index + 1), 120, 20, STYLE.INK if closed else STYLE.ALERT)
		STYLE.cell(row, String(kind.stage(index + 1).errand) if kind != null and index < kind.count() else "", 290, 15, STYLE.SOFT)
		row.add_child(STYLE.meter(seconds / longest, 250, STYLE.AMBER if closed else STYLE.ALERT, 10.0))
		STYLE.cell(row, ui.tape_time(seconds), 100, 20, STYLE.AMBER if closed else STYLE.ALERT, HORIZONTAL_ALIGNMENT_RIGHT)
		var against := ""
		var ahead := false
		if not closed: against = "NO SE CERRÓ"
		elif index < best.size():
			var gap := seconds - float(best[index])
			ahead = gap < 0.0
			against = ("−" if ahead else "+") + SCORE.clock(int(absf(gap)))
		STYLE.cell(row, against, 130, 16, STYLE.ALERT if not closed else (STYLE.AMBER if ahead else STYLE.SOFT), HORIZONTAL_ALIGNMENT_RIGHT)
		var said := sector_facts(line, index + 1)
		if not said.is_empty():
			var under := row_in(page, 14)
			STYLE.cell(under, "", 120, 14)
			STYLE.cell(under, said, 800, 14, STYLE.SOFT)
		ui.spacer(page, 6)
	if not best.is_empty(): ui.label(page, "A LA DERECHA, CADA SECTOR CONTRA EL MÁS RÁPIDO QUE HA TENIDO ESTE TABLÓN.", 13).add_theme_color_override("font_color", STYLE.FAINT)

## What happened in a sector, counted out of the floor's moments.
static func sector_facts(line: Dictionary, stage: int) -> String:
	var counts := {}
	for event in line.get("events", []):
		if int(event.get("st", 0)) == stage: counts[String(event.get("k", ""))] = int(counts.get(String(event.get("k", "")), 0)) + 1
	var parts: Array = []
	var plural := func(many: int, one: String, more: String) -> String: return "%d %s" % [many, one if many == 1 else more]
	if counts.has("tv"): parts.append(plural.call(int(counts.tv), "televisor encendido", "televisores encendidos"))
	if counts.has("dark"): parts.append("se fue la luz")
	if counts.has("digit"): parts.append(plural.call(int(counts.digit), "número encontrado", "números encontrados"))
	if counts.has("code"): parts.append("código marcado")
	if counts.has("escape"): parts.append(plural.call(int(counts.escape), "huida", "huidas"))
	if counts.has("death"): parts.append(plural.call(int(counts.death), "caída", "caídas"))
	if counts.has("collapse"): parts.append("el sector se derrumbó y volvió a empezar")
	return "  ·  ".join(parts)

# --- CRONOLOGÍA -------------------------------------------------------------------

static func timeline(ui, page: VBoxContainer, line: Dictionary) -> void:
	page.add_theme_constant_override("separation", 3)
	var events: Array = line.get("events", [])
	if events.is_empty():
		ui.paragraph(page, "Esta cinta se grabó antes de que el hotel anotara sus momentos.", 17, 900)
		return
	for event in events:
		var told := moment(line, event)
		if told.is_empty(): continue
		var row := row_in(page, 14)
		STYLE.cell(row, ui.tape_time(float(event.get("t", 0.0))), 96, 16, STYLE.SOFT)
		STYLE.cell(row, "S%d" % int(event.get("st", 1)), 36, 16, STYLE.FAINT)
		STYLE.cell(row, told[0], 820, 16, told[1])

## A moment of the floor as it is told: [the words, their ink].
static func moment(line: Dictionary, event: Dictionary) -> Array:
	var who := name_of(line, int(event.get("s", 0)))
	var many := int(event.get("n", 0))
	match String(event.get("k", "")):
		"tv": return ["%s encendió un televisor%s" % [who, (" (%d de %d)" % [many, int(event.get("of", 0))]) if many > 0 and int(event.get("of", 0)) > 0 else ""], STYLE.INK]
		"dark": return ["Se fue la luz del ala", STYLE.SOFT]
		"digit": return ["%s encontró un número del código%s" % [who, (" en %s" % String(event.get("w", ""))) if not String(event.get("w", "")).is_empty() else ""], STYLE.INK]
		"code": return ["%s marcó el código: la última puerta se abrió" % who, STYLE.INK]
		"lift": return ["%s llamó al ascensor" % who, STYLE.SOFT]
		"escape": return ["%s se le escapó a la criatura tras %d s de persecución" % [who, many], STYLE.INK]
		"burnt": return ["%s se quedó sin cordura" % who, STYLE.SOFT]
		"death": return ["The Locust atrapó a %s" % who, STYLE.ALERT]
		"collapse": return ["El sector se derrumbó: todos en pie y a empezarlo otra vez", STYLE.ALERT]
		"sector": return ["SECTOR %d CERRADO" % many, STYLE.AMBER]
		"out": return ["LA CINTA SALIÓ DEL HOTEL", STYLE.AMBER]
	return []

# --- HITOS ------------------------------------------------------------------------

static func milestones(ui, page: VBoxContainer, line: Dictionary, outcome: Dictionary) -> void:
	page.add_theme_constant_override("separation", 6)
	var floor_number := int(line.get("floor", 1))
	var fresh: Array = outcome.get("milestones", [])
	var known: Array = FLOORS.milestones(floor_number)
	if fresh.is_empty(): ui.paragraph(page, "Esta cinta no trae ningún hito nuevo.", 17, 900)
	else: ui.label(page, "HITOS NUEVOS", 15).add_theme_color_override("font_color", STYLE.AMBER)
	var delay := 0.5
	for milestone in known:
		if not fresh.has(String(milestone.id)): continue
		var row := row_in(page, 16)
		var holder := CenterContainer.new()
		holder.custom_minimum_size.x = 300
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(holder)
		holder.add_child(STYLE.stamp(String(milestone.title), 17, STYLE.AMBER, -0.03, delay))
		delay += 0.3
		var note := STYLE.cell(row, String(milestone.note), 620, 16, STYLE.SOFT)
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ui.records == null or known.is_empty(): return
	ui.spacer(page, 6)
	ui.label(page, "%s:  %d DE %d HITOS" % [FLOORS.title(floor_number), ui.records.reached_count(floor_number), known.size()], 17)
	# And a few of the ones still to do, to have something to go back for.
	var pending: Array = known.filter(func(milestone): return String(ui.records.reached(floor_number, String(milestone.id))).is_empty())
	if pending.is_empty(): return
	ui.spacer(page, 2)
	ui.label(page, "QUEDAN POR HACER", 14).add_theme_color_override("font_color", STYLE.AMBER)
	for milestone in pending.slice(0, 4):
		var row := row_in(page, 16)
		STYLE.cell(row, String(milestone.title), 300, 16, STYLE.SOFT)
		STYLE.cell(row, String(milestone.note), 620, 15, STYLE.FAINT)
	ui.label(page, "TODOS, EN MARCAS ▸ HITOS.", 13).add_theme_color_override("font_color", STYLE.FAINT)
