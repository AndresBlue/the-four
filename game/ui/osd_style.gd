extends RefCounted
## Shared camcorder on-screen-display look: one monospace font, white ink with
## hard shadows, flat controls. Used by the in-world overlay, HUD and menus.
const FONT_PATH := "res://assets/fonts/vcr_osd_mono.ttf"
const INK := Color(0.94, 0.94, 0.9)
const SOFT := Color(0.94, 0.94, 0.9, 0.62)
const FAINT := Color(0.94, 0.94, 0.9, 0.22)
const ALERT := Color(0.93, 0.22, 0.14)
const AMBER := Color(0.96, 0.78, 0.4)
const SHADE := Color(0.0, 0.0, 0.0, 0.85)
## SOFT laid over black, but opaque: for marks drawn in overlapping pieces,
## where a translucent ink piles up where they meet.
const MUTED := Color(0.58, 0.58, 0.56)
const VCR_BLUE := Color(0.09, 0.16, 0.62)
static var cached_font: Font
static var cached_theme: Theme

static func font() -> Font:
	if cached_font != null: return cached_font
	if ResourceLoader.exists(FONT_PATH):
		cached_font = load(FONT_PATH)
	else:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["VCR OSD Mono", "Consolas", "Lucida Console", "Courier New", "monospace"])
		system.font_weight = 600
		system.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		cached_font = system
	return cached_font

static func pixel(width: int, height: int, fill: Callable) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width: image.set_pixel(x, y, fill.call(x, y))
	return ImageTexture.create_from_image(image)

static func flat(color: Color, border := Color(0, 0, 0, 0), width := 0, margin := 6.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(width)
	box.set_content_margin_all(margin)
	return box

static func theme() -> Theme:
	if cached_theme != null: return cached_theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 20
	var empty := StyleBoxEmpty.new()
	for type in ["Label", "Button", "CheckButton", "OptionButton", "TabBar", "TabContainer", "PopupMenu"]:
		t.set_color("font_shadow_color", type, SHADE)
		t.set_constant("shadow_offset_x", type, 2)
		t.set_constant("shadow_offset_y", type, 2)
	t.set_color("font_color", "Label", INK)
	# Menu entries are bare text; focus is shown with a cursor and full ink.
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		t.set_stylebox(state, "Button", empty)
	t.set_color("font_color", "Button", SOFT)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", AMBER)
	t.set_color("font_hover_pressed_color", "Button", AMBER)
	t.set_color("font_disabled_color", "Button", FAINT)
	# Boxed variant for secondary actions inside panels.
	t.set_type_variation("BoxButton", "Button")
	t.set_stylebox("normal", "BoxButton", flat(Color(0, 0, 0, 0.35), FAINT, 1, 8))
	t.set_stylebox("hover", "BoxButton", flat(Color(1, 1, 1, 0.06), SOFT, 1, 8))
	t.set_stylebox("focus", "BoxButton", flat(Color(1, 1, 1, 0.06), INK, 1, 8))
	t.set_stylebox("pressed", "BoxButton", flat(Color(1, 1, 1, 0.12), AMBER, 1, 8))
	for type in ["CheckButton", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			t.set_stylebox(state, type, empty if type == "CheckButton" else flat(Color(0, 0, 0, 0.35), INK if state in ["hover", "focus"] else FAINT, 1, 8))
		t.set_color("font_color", type, SOFT)
		t.set_color("font_hover_color", type, INK)
		t.set_color("font_focus_color", type, INK)
		t.set_color("font_pressed_color", type, INK)
	var off := pixel(22, 22, func(x, y): return INK if x < 2 or y < 2 or x > 19 or y > 19 else Color(0, 0, 0, 0.4))
	var on := pixel(22, 22, func(x, y): return INK if x < 2 or y < 2 or x > 19 or y > 19 or (x > 5 and x < 16 and y > 5 and y < 16) else Color(0, 0, 0, 0.4))
	for icon in ["unchecked", "unchecked_disabled", "unchecked_mirrored", "unchecked_disabled_mirrored"]: t.set_icon(icon, "CheckButton", off)
	for icon in ["checked", "checked_disabled", "checked_mirrored", "checked_disabled_mirrored"]: t.set_icon(icon, "CheckButton", on)
	# Text fields (player name, address): a thin box like the option buttons.
	t.set_stylebox("normal", "LineEdit", flat(Color(0, 0, 0, 0.35), FAINT, 1, 8))
	t.set_stylebox("focus", "LineEdit", flat(Color(1, 1, 1, 0.06), INK, 1, 8))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", FAINT)
	t.set_color("caret_color", "LineEdit", AMBER)
	t.set_icon("arrow", "OptionButton", pixel(12, 8, func(x, y): return INK if absi(x * 2 - 11) <= (7 - y) * 2 - 2 else Color(0, 0, 0, 0)))
	t.set_stylebox("panel", "PopupMenu", flat(Color(0.02, 0.02, 0.02, 0.96), SOFT, 1, 8))
	t.set_stylebox("hover", "PopupMenu", flat(Color(1, 1, 1, 0.12)))
	t.set_color("font_color", "PopupMenu", SOFT)
	t.set_color("font_hover_color", "PopupMenu", INK)
	# Thin tape-deck slider with a solid block handle.
	var line := flat(FAINT, Color(0, 0, 0, 0), 0, 0)
	line.content_margin_top = 2
	line.content_margin_bottom = 2
	var filled := flat(INK, Color(0, 0, 0, 0), 0, 0)
	filled.content_margin_top = 2
	filled.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", line)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	var handle := pixel(10, 22, func(_x, _y): return INK)
	t.set_icon("grabber", "HSlider", handle)
	t.set_icon("grabber_highlight", "HSlider", pixel(10, 22, func(_x, _y): return AMBER))
	t.set_stylebox("background", "ProgressBar", flat(Color(0, 0, 0, 0.4), SOFT, 1, 0))
	t.set_stylebox("fill", "ProgressBar", flat(INK, Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("panel", "PanelContainer", flat(Color(0, 0, 0, 0.5), FAINT, 1, 18))
	t.set_stylebox("panel", "TabContainer", flat(Color(0, 0, 0, 0.45), FAINT, 1, 18))
	t.set_stylebox("tab_selected", "TabContainer", flat(Color(1, 1, 1, 0.08), INK, 0, 10))
	t.set_stylebox("tab_unselected", "TabContainer", flat(Color(0, 0, 0, 0), FAINT, 0, 10))
	t.set_stylebox("tab_hovered", "TabContainer", flat(Color(1, 1, 1, 0.04), FAINT, 0, 10))
	t.set_stylebox("tab_focus", "TabContainer", flat(Color(0, 0, 0, 0), INK, 1, 10))
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", SOFT)
	t.set_color("font_hovered_color", "TabContainer", INK)
	t.set_stylebox("tab_selected", "TabBar", flat(Color(1, 1, 1, 0.08), INK, 0, 10))
	t.set_stylebox("tab_unselected", "TabBar", flat(Color(0, 0, 0, 0), FAINT, 0, 10))
	t.set_stylebox("scroll", "VScrollBar", flat(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("grabber", "VScrollBar", flat(SOFT))
	t.set_stylebox("grabber_hover", "VScrollBar", flat(INK))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(AMBER))
	cached_theme = t
	return t

## A pair of headphones, drawn rather than imported: a band and two cups, in
## the weight of the menu's own type, so it belongs beside the words instead of
## looking like an icon borrowed from somewhere else. `size` is the width.
static func headphones(size: float, color := MUTED) -> Control:
	var mark := Control.new()
	mark.custom_minimum_size = Vector2(size, size * 0.62)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func() -> void:
		var stroke := maxf(2.0, size * 0.07)
		var middle := Vector2(size * 0.5, size * 0.38)
		var reach := size * 0.35
		# The band over the top, and a cup hanging at each end of it.
		mark.draw_arc(middle, reach, PI, TAU, 64, color, stroke, true)
		for side in [-1.0, 1.0]:
			var hinge := middle + Vector2(side * reach, 0.0)
			var bottom := hinge + Vector2(0.0, size * 0.2)
			mark.draw_line(hinge, bottom, color, stroke * 2.2, true)
			# Rounded off: draw_line has square ends and a cup does not.
			mark.draw_circle(bottom, stroke * 1.1, color))
	return mark

## A rubber stamp: words in a box, a little crooked, as a clerk would leave
## them on a tape's label. `delay` > 0 presses it on after that long.
static func stamp(words: String, size := 18, color := AMBER, tilt := -0.06, delay := 0.0) -> Control:
	var face := font()
	var extent := face.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var box := Vector2(extent.x + size * 1.1, size * 1.7)
	var mark := Control.new()
	# Room for the corners of a box that is turned.
	mark.custom_minimum_size = box + Vector2(absf(sin(tilt)) * box.y, absf(sin(tilt)) * box.x) + Vector2(6, 6)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func() -> void:
		mark.draw_set_transform(mark.size * 0.5, tilt, Vector2.ONE)
		var rect := Rect2(-box * 0.5, box)
		mark.draw_rect(rect, Color(color, 0.1), true)
		mark.draw_rect(rect, color, false, maxf(2.0, size * 0.09))
		mark.draw_string(face, Vector2(-extent.x * 0.5, (face.get_ascent(size) - face.get_descent(size)) * 0.5), words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color))
	if delay > 0.0:
		mark.modulate.a = 0.0
		var press := mark.create_tween()
		press.tween_interval(delay)
		press.tween_property(mark, "modulate:a", 1.0, 0.12)
	return mark

## A figure with what it is written small over it: the big numbers of a
## report. Returns the label of the figure, to count it up or recolour it.
static func figure(parent: Node, caption: String, words: String, size := 34, color := INK) -> Label:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(block)
	block.add_child(text(caption, 14, SOFT))
	var value := text(words, size, color)
	block.add_child(value)
	return value

## A thin level, filled from the left: how much of the longest this one is.
static func meter(fraction: float, width: float, color := INK, height := 8.0) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(width, height)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		bar.draw_rect(Rect2(Vector2.ZERO, bar.size), Color(1, 1, 1, 0.08), true)
		bar.draw_rect(Rect2(Vector2.ZERO, Vector2(bar.size.x * clampf(fraction, 0.0, 1.0), bar.size.y)), color, true))
	return bar

## A number with its thousands apart: 12 480.
static func grouped(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = " " + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

## One cell of a row laid out in columns: words in a fixed width, cut short
## with an ellipsis when they do not fit. Cut here and not by the label: one
## that clips its words clips the accent off every capital with them.
static func cell(row: Node, words: String, width: float, size := 17, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var face := font()
	if width > 0.0 and face.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		while words.length() > 1 and face.get_string_size(words + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width: words = words.left(words.length() - 1)
		words = words.strip_edges() + "…"
	var result := text(words, size, color)
	result.custom_minimum_size.x = width
	result.horizontal_alignment = align
	row.add_child(result)
	return result

static func text(words: String, size := 20, color := INK) -> Label:
	var result := Label.new()
	result.text = words
	result.add_theme_font_override("font", font())
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_shadow_color", SHADE)
	result.add_theme_constant_override("shadow_offset_x", 2)
	result.add_theme_constant_override("shadow_offset_y", 2)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

## Short synthetic camcorder beeps for menu feedback.
static func beep(frequency: float, seconds: float, level := 0.35) -> AudioStreamWAV:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 44100
	var count := int(44100 * seconds)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for i in count:
		var t := float(i) / 44100.0
		var envelope := minf(1.0, t * 800.0) * minf(1.0, (seconds - t) * 300.0)
		bytes.encode_s16(i * 2, int(sin(TAU * frequency * t) * envelope * level * 32767.0))
	audio.data = bytes
	return audio

## A few beeps in a row, each [frequency, seconds]; a frequency of zero is a
## gap. `edge` squares the wave off towards a buzz: the keypad saying no.
static func tones(steps: Array, level := 0.3, edge := 0.0) -> AudioStreamWAV:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 44100
	var total := 0
	for step in steps: total += int(44100 * float(step[1]))
	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	var at := 0
	for step in steps:
		var frequency: float = step[0]
		var seconds: float = step[1]
		var count := int(44100 * seconds)
		for i in count:
			var value := 0.0
			if frequency > 0.0:
				var t := float(i) / 44100.0
				var envelope := minf(1.0, t * 800.0) * minf(1.0, (seconds - t) * 300.0)
				var wave := sin(TAU * frequency * t)
				value = lerpf(wave, signf(wave), edge) * envelope * level
			bytes.encode_s16((at + i) * 2, int(value * 32767.0))
		at += count
	audio.data = bytes
	return audio
