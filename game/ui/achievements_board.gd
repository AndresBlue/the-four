extends RefCounted
## LOGROS: every milestone of every floor (game/floors/*.gd, MILESTONES) down
## one strip, each with its icon (assets/ui/achievements, drawn by
## tools/art/make_achievement_icons.py), what it asks for and the day it was
## reached; over them, how much of it is done. They are kept by
## records_service (reach) and are Steam achievements too (steam_link.unlock),
## so with Steam a friend can be picked to compare: the day each one got it
## beside one's own.
##
## Built into the menus by hotel_ui.gd (menu("achievements")), which owns the
## helpers used here and remembers who is being compared (`view`).
const STYLE := preload("res://game/ui/osd_style.gd")
const FLOORS := preload("res://game/floors/floor_index.gd")
const REPORT := preload("res://game/ui/tape_report.gd")
const SIZE := Vector2(1040, 430)
const ICON := 52
const ICONS := "res://assets/ui/achievements/%d_%s.png"

## Every milestone there is, in order: [floor, milestone].
static func all() -> Array:
	var list: Array = []
	for floor_number in range(1, FLOORS.COUNT + 1):
		for milestone in FLOORS.milestones(floor_number): list.append([floor_number, milestone])
	return list

## Their keys, as records_service and Steam know them ("floor:id").
static func keys() -> Array:
	return all().map(func(pair): return "%d:%s" % [pair[0], String(pair[1].id)])

static func build(ui, parent: Node, view: Dictionary) -> void:
	var records = ui.records
	var every := all()
	var done := every.filter(func(pair): return not String(records.reached(int(pair[0]), String(pair[1].id))).is_empty()).size()
	var share := float(done) / maxf(1.0, float(every.size()))
	var head := REPORT.row_in(parent, 16)
	ui.label(head, "%d / %d" % [done, every.size()], 22).add_theme_color_override("font_color", STYLE.AMBER)
	var level := STYLE.meter(share, 260, STYLE.AMBER, 8.0)
	level.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(level)
	ui.label(head, "%d %%" % roundi(share * 100.0), 22)
	var steam = ui.net.steam if ui.net != null else null
	var comparing := int(view.get("friend", 0)) != 0
	if steam != null and steam.ready_to_play():
		var friends: Array = steam.friends()
		if not friends.is_empty():
			var spacer := Control.new()
			spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			head.add_child(spacer)
			var names: Array = ["Nadie"] + friends.map(func(friend): return String(friend.name))
			var ids: Array = [0] + friends.map(func(friend): return int(friend.id))
			ui.label(head, "COMPARAR CON", 16).add_theme_color_override("font_color", STYLE.SOFT)
			var control := OptionButton.new()
			control.custom_minimum_size.x = 240
			control.add_theme_font_size_override("font_size", 17)
			for words in names: control.add_item(String(words))
			control.select(maxi(0, ids.find(int(view.get("friend", 0)))))
			control.item_selected.connect(func(index: int):
				ui.tick()
				ui.compare_achievements(int(ids[index]), String(names[index])))
			head.add_child(control)
	ui.spacer(parent, 6)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = SIZE
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var strip := VBoxContainer.new()
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_theme_constant_override("separation", 8)
	scroll.add_child(strip)
	if comparing:
		var columns := REPORT.row_in(strip, 14)
		STYLE.cell(columns, "", ICON + 14 + 640, 13)
		STYLE.cell(columns, "TÚ", 120, 13, STYLE.SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
		STYLE.cell(columns, String(view.get("name", "")).to_upper().left(14), 150, 13, STYLE.SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
	var theirs: Dictionary = view.get("unlocked", {})
	for pair in every:
		var floor_number := int(pair[0])
		var milestone: Dictionary = pair[1]
		var day := String(records.reached(floor_number, String(milestone.id)))
		var got := not day.is_empty()
		var row := REPORT.row_in(strip, 14)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(ICON, ICON)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path := ICONS % [floor_number, String(milestone.id)]
		if ResourceLoader.exists(path): icon.texture = load(path)
		# Not reached yet: there, but dark.
		if not got: icon.modulate = Color(0.55, 0.55, 0.55, 0.4)
		row.add_child(icon)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 0)
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(words)
		STYLE.cell(words, String(milestone.title), 640, 19, STYLE.INK if got else STYLE.SOFT)
		STYLE.cell(words, String(milestone.note), 640, 14, STYLE.SOFT if got else STYLE.FAINT)
		var mine := STYLE.cell(row, day, 120, 15, STYLE.AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
		mine.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if comparing:
			var key := "%d:%s" % [floor_number, String(milestone.id)]
			var when := int(theirs.get(key, 0))
			var said := Time.get_date_string_from_unix_time(when) if when > 0 else ""
			var other := STYLE.cell(row, said, 150, 15, STYLE.INK, HORIZONTAL_ALIGNMENT_RIGHT)
			other.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if comparing and not bool(view.get("known", true)):
		ui.spacer(parent, 4)
		ui.label(parent, "STEAM NO TIENE LOGROS DE %s EN ESTE JUEGO" % String(view.get("name", "")).to_upper(), 14).add_theme_color_override("font_color", STYLE.FAINT)
