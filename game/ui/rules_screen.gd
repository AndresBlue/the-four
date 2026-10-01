extends RefCounted
## The rules of the room, in tabs (game/floors/match_rules.gd says what they
## are): the host picks each one from a list, everybody else reads what was
## picked. What differs from the game's own is in amber, so a glance says what
## kind of floor is about to start.
##
## Built into the menus by hotel_ui.gd (menu("rules")), which owns the helpers
## used here and the walk between tabs. Every pick goes to the room at once
## (net_session.set_option) and from there to everybody.
const STYLE := preload("res://game/ui/osd_style.gd")
const RULES := preload("res://game/floors/match_rules.gd")
const REPORT := preload("res://game/ui/tape_report.gd")
const SIZE := Vector2(1040, 372)

static func build(ui, parent: Node, view: Dictionary) -> TabContainer:
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = SIZE
	tabs.add_theme_font_size_override("font_size", 18)
	parent.add_child(tabs)
	var hosting: bool = ui.net.is_host
	var now: Dictionary = RULES.settled(ui.net.options.get("rules", {}))
	for group in RULES.GROUPS.size():
		var page: VBoxContainer = REPORT.sheet(ui, tabs, RULES.GROUPS[group])
		page.add_theme_constant_override("separation", 2)
		for rule in RULES.RULES:
			if int(rule.group) != group: continue
			var id := String(rule.id)
			var values: Array = rule.values
			var differs: bool = int(now[id]) != int(rule.default)
			var row := REPORT.row_in(page, 14)
			var title := STYLE.cell(row, String(rule.title).to_upper(), 330, 18, STYLE.AMBER if differs else STYLE.INK)
			title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if hosting:
				var control := OptionButton.new()
				control.custom_minimum_size.x = 380
				control.add_theme_font_size_override("font_size", 17)
				for words in rule.labels: control.add_item(String(words).to_upper())
				control.select(maxi(values.find(int(now[id])), 0))
				control.item_selected.connect(func(index: int):
					ui.tick()
					# Over what the room already changed, and to everybody.
					var next: Dictionary = RULES.changed(ui.net.options.get("rules", {}))
					next[id] = int(values[index])
					ui.net.set_option("rules", next)
					title.add_theme_color_override("font_color", STYLE.AMBER if int(values[index]) != int(rule.default) else STYLE.INK))
				row.add_child(control)
			else:
				STYLE.cell(row, RULES.label(id, int(now[id])).to_upper(), 380, 18, STYLE.AMBER if differs else STYLE.SOFT)
			ui.paragraph(page, String(rule.note), 14, 940, STYLE.SOFT)
			ui.spacer(page, 8)
	tabs.current_tab = clampi(int(view.get("tab", 0)), 0, tabs.get_tab_count() - 1)
	tabs.tab_changed.connect(func(index: int): view["tab"] = index)
	return tabs
