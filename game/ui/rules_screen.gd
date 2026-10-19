extends RefCounted
## The rules of the room on one screen (game/floors/match_rules.gd says what
## they are): a line each, its name and what it is set to -- a list to pick
## from for the host, the word for everybody else -- in amber where it differs
## from the game's own. Nothing else is written there (the author's word, 19
## October 2026): what a rule does comes up under the list, out of the static
## of a weak signal, while the pointer rests on its line or the line is marked.
##
## Built into the menus by hotel_ui.gd (menu("rules")), which owns the helpers
## used here and keeps what is shown (`rule_pickers`, `rule_rows`,
## `rule_detail`). Every pick goes to the room at once (net_session.set_option)
## and from there to everybody.
const STYLE := preload("res://game/ui/osd_style.gd")
const RULES := preload("res://game/floors/match_rules.gd")
const REPORT := preload("res://game/ui/tape_report.gd")
const WASH := preload("res://game/ui/shaders/signal_wash.gdshader")
const SIZE := Vector2(1040, 0)
## The width of a rule's name, and of its list or its word.
const NAME_WIDTH := 360.0
const VALUE_WIDTH := 380.0
## Where what a rule does is shown, and how long it takes to come through.
const DETAIL_SIZE := Vector2i(1000, 76)
const DETAIL_IN := 0.9

static func build(ui, parent: Node) -> void:
	var hosting: bool = ui.net.is_host
	var now: Dictionary = RULES.settled(ui.net.options.get("rules", {}))
	ui.rule_pickers = {}
	ui.rule_rows = {}
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	parent.add_child(list)
	for rule in RULES.RULES:
		var id := String(rule.id)
		var values: Array = rule.values
		var differs: bool = int(now[id]) != int(rule.default)
		var note := String(rule.note)
		var row := REPORT.row_in(list, 14)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.custom_minimum_size.y = 32
		row.mouse_entered.connect(func(): tell(ui, note))
		ui.rule_rows[id] = row
		var title := STYLE.cell(row, String(rule.title).to_upper(), NAME_WIDTH, 18, STYLE.AMBER if differs else STYLE.INK)
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if hosting:
			var control := OptionButton.new()
			control.custom_minimum_size.x = VALUE_WIDTH
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
			control.focus_entered.connect(func(): tell(ui, note))
			control.mouse_entered.connect(func(): tell(ui, note))
			row.add_child(control)
			ui.rule_pickers[id] = control
		else:
			var word := STYLE.cell(row, RULES.label(id, int(now[id])).to_upper(), VALUE_WIDTH, 18, STYLE.AMBER if differs else STYLE.SOFT)
			word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ui.spacer(parent, 6)
	detail(ui, parent)

## The place under the list where what a rule does comes up: its words drawn
## into a picture of their own, shown through the weak signal's wash
## (signal_wash.gdshader, the notices' own).
static func detail(ui, parent: Node) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(DETAIL_SIZE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var picture := SubViewport.new()
	picture.size = DETAIL_SIZE
	picture.transparent_bg = true
	picture.disable_3d = true
	picture.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(picture)
	var words := STYLE.text("", 18, STYLE.SOFT)
	words.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.position = Vector2(6, 6)
	words.size = Vector2(DETAIL_SIZE.x - 12, DETAIL_SIZE.y - 12)
	picture.add_child(words)
	var screen := TextureRect.new()
	screen.texture = picture.get_texture()
	screen.size = Vector2(DETAIL_SIZE)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var look := ShaderMaterial.new()
	look.shader = WASH
	look.set_shader_parameter("wash", 1.0)
	screen.material = look
	holder.add_child(screen)
	ui.rule_detail = {"words": words, "look": look, "tween": null}

## What a rule does, come up through the static (once per rule: resting on
## the same one again does not start it over).
static func tell(ui, note: String) -> void:
	var shown: Dictionary = ui.rule_detail
	if shown.is_empty() or not is_instance_valid(shown.words): return
	var words: Label = shown.words
	if words.text == note: return
	words.text = note
	var look: ShaderMaterial = shown.look
	if shown.tween is Tween and (shown.tween as Tween).is_valid(): (shown.tween as Tween).kill()
	var tween := words.create_tween()
	tween.tween_method(func(amount: float): look.set_shader_parameter("wash", amount), 1.0, 0.0, DETAIL_IN).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	shown["tween"] = tween
