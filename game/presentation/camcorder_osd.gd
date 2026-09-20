extends CanvasLayer
## In-world camcorder overlay: REC, tape speed, date and time, autofocus
## brackets on interactive objects and a segmented stamina meter. It sits below
## the analog filter so it degrades with the footage. Subtitles and essential
## hints are drawn by the interface above the filter.
const STYLE := preload("res://game/ui/osd_style.gd")
const MONTHS := ["JAN.", "FEB.", "MAR.", "APR.", "MAY", "JUN.", "JUL.", "AUG.", "SEP.", "OCT.", "NOV.", "DEC."]
const SEGMENTS := 14
var rec: Label
var dot: Panel
var clock: Label
var focus_label: Label
var canvas: Control
var marks := true
## The picture is gone (an execution): the tape marks go with it.
var signal_lost := false
## The creature's channels: the lit sets laid out by where they are, nothing
## else. [{index, at (plane, in screen spans), here}], which way it is looking
## and which one it would step out of.
var channels: Array = []
var channel_look := Vector2.ZERO
var channel_target := -1

func show_channels(points: Array, look: Vector2, target: int) -> void:
	channels = points
	channel_look = look
	channel_target = target
	canvas.queue_redraw()
var start_seconds := 0
var date_text := ""
var blink := 0.0
var stamina := 1.0
var exhausted := false
var stamina_alpha := 0.0
var full_time := 99.0
var focus_word := ""
var focus_amount := 0.0
## The Locust's seat: the creature records nothing, so no REC, tape clock or
## focus brackets. What is left is drawn the same way, under the same filter:
## the stamina meter and a short notice (the countdown to the hunt).
var hunter := false
var notice: Label
## The zoom rocker: where it stands (0 wide, 1 telephoto) and how long the
## bar stays up after it last moved, as on a camcorder.
var zoom := 0.0
var zoom_alpha := 0.0
var zoom_still := 9.0
const ZOOM_HOLD := 1.6

func _ready() -> void:
	layer = 4
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(draw_overlay)
	add_child(canvas)
	rec = STYLE.text("REC\nSP", 30)
	rec.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rec.offset_left = -300
	rec.offset_top = 32
	rec.offset_right = -44
	add_child(rec)
	# Drawn shape rather than a glyph, so it works with any fallback font.
	dot = Panel.new()
	var round_style := StyleBoxFlat.new()
	round_style.bg_color = STYLE.ALERT
	round_style.set_corner_radius_all(9)
	dot.add_theme_stylebox_override("panel", round_style)
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -138
	dot.offset_top = 44
	dot.offset_right = -120
	dot.offset_bottom = 62
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)
	clock = STYLE.text("", 30)
	clock.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	clock.offset_left = 48
	clock.offset_top = -118
	clock.offset_right = 520
	clock.offset_bottom = -52
	add_child(clock)
	focus_label = STYLE.text("", 20)
	focus_label.set_anchors_preset(Control.PRESET_CENTER)
	focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_label.offset_left = -200
	focus_label.offset_right = 200
	focus_label.offset_top = 44
	focus_label.offset_bottom = 74
	add_child(focus_label)
	notice = STYLE.text("", 30)
	notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.offset_left = -420
	notice.offset_right = 420
	notice.offset_top = -150
	notice.offset_bottom = -110
	add_child(notice)
	hide()

## The recording date derives from the floor seed, so a retry shows the same tape.
func start_tape(run_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + 1989
	var year := rng.randi_range(1986, 1997)
	var month := rng.randi_range(0, 11)
	var day := rng.randi_range(1, 28)
	start_seconds = 2 * 3600 + rng.randi_range(0, 3599)
	date_text = "%s %d %d" % [MONTHS[month], day, year]
	stamina = 1.0
	stamina_alpha = 0.0
	full_time = 99.0
	focus_word = ""

func set_stamina(value: float, is_exhausted: bool) -> void:
	stamina = clampf(value, 0.0, 1.0)
	exhausted = is_exhausted

## The zoom's place along its travel; the bar shows while it moves and for a
## moment after.
func set_zoom(fraction: float, delta: float) -> void:
	if absf(fraction - zoom) > 0.0005: zoom_still = 0.0
	else: zoom_still += delta
	zoom = fraction
	var wanted := 0.0 if zoom_still > ZOOM_HOLD or hunter or not marks else 1.0
	zoom_alpha = move_toward(zoom_alpha, wanted, delta * (3.0 if wanted > 0.0 else 1.6))

## A line of text in the tape's own lettering; empty hides it.
func announce(words: String) -> void:
	notice.text = words

## Autofocus brackets with a one-word action; empty hides them.
func focus(word: String) -> void:
	focus_word = word

func show_tape(elapsed: float, delta: float) -> void:
	blink = fposmod(blink + delta, 1.0)
	var tape := marks and not hunter and not signal_lost
	rec.visible = tape
	dot.visible = tape and blink < 0.6
	clock.visible = tape
	notice.visible = not notice.text.is_empty()
	if hunter or signal_lost: focus_word = ""
	var total := start_seconds + int(elapsed)
	var hours := total / 3600
	clock.text = "AM %d:%02d:%02d\n%s" % [hours % 12 if hours % 12 != 0 else 12, (total / 60) % 60, total % 60, date_text]
	# The meter appears while stamina is spent and fades out once full.
	full_time = full_time + delta if stamina >= 0.999 else 0.0
	stamina_alpha = move_toward(stamina_alpha, 0.0 if full_time > 1.5 else 1.0, delta * 2.5)
	focus_amount = move_toward(focus_amount, 1.0 if not focus_word.is_empty() else 0.0, delta * 7.0)
	if not focus_word.is_empty(): focus_label.text = focus_word
	focus_label.modulate.a = focus_amount
	canvas.queue_redraw()

func draw_overlay() -> void:
	var size := canvas.size
	if zoom_alpha > 0.01:
		# W [---|----] T, the rocker's own scale, centred across the top of the
		# picture under the tape marks: short and heavy, and its frame close
		# round the lettering, the way a camcorder stamps it.
		var track := 170.0
		var letters := 16
		var font := STYLE.font()
		var w_wide := font.get_string_size("W", HORIZONTAL_ALIGNMENT_LEFT, -1, letters).x
		var t_wide := font.get_string_size("T", HORIZONTAL_ALIGNMENT_LEFT, -1, letters).x
		var gap := 9.0
		var pad := Vector2(9.0, 5.0)
		var inside := Vector2(w_wide + gap + track + gap + t_wide, 14.0)
		var frame := Rect2(Vector2((size.x - inside.x) * 0.5 - pad.x, 56.0), inside + pad * 2.0)
		var middle := frame.position.y + frame.size.y * 0.5
		var left := frame.position.x + pad.x
		var ink := Color(STYLE.INK, zoom_alpha * 0.9)
		var faint := Color(STYLE.INK, zoom_alpha * 0.45)
		var shadow := Color(0, 0, 0, zoom_alpha * 0.6)
		for pass_index in 2:
			var shift := Vector2(2, 2) if pass_index == 0 else Vector2.ZERO
			var color := shadow if pass_index == 0 else ink
			var soft := shadow if pass_index == 0 else faint
			canvas.draw_rect(Rect2(frame.position + shift, frame.size), soft, false, 4.0)
			var base := Vector2(left, middle + letters * 0.36) + shift
			canvas.draw_string(font, base, "W", HORIZONTAL_ALIGNMENT_LEFT, -1, letters, color)
			canvas.draw_string(font, base + Vector2(inside.x - t_wide, 0), "T", HORIZONTAL_ALIGNMENT_LEFT, -1, letters, color)
			var start := left + w_wide + gap
			canvas.draw_line(Vector2(start, middle) + shift, Vector2(start + track, middle) + shift, soft, 5.0)
			for end in [0.0, track]:
				canvas.draw_line(Vector2(start + end, middle - 5) + shift, Vector2(start + end, middle + 5) + shift, soft, 5.0)
			var marker := Vector2(start + track * clampf(zoom, 0.0, 1.0), middle) + shift
			canvas.draw_rect(Rect2(marker - Vector2(6, 7), Vector2(12, 14)), color)
	if stamina_alpha > 0.01:
		var right := size.x - 48.0
		var bottom := size.y - 60.0
		var cell := Vector2(14, 22)
		var gap := 5.0
		var width := SEGMENTS * (cell.x + gap) - gap
		var lit := int(ceil(stamina * SEGMENTS))
		var flash := exhausted and blink > 0.5
		for i in SEGMENTS:
			var rect := Rect2(Vector2(right - width + i * (cell.x + gap), bottom - cell.y), cell)
			var ink := STYLE.ALERT if exhausted else STYLE.INK
			ink.a = stamina_alpha * (0.9 if i < lit and not flash else 0.18)
			canvas.draw_rect(Rect2(rect.position + Vector2(2, 2), rect.size), Color(0, 0, 0, stamina_alpha * 0.6))
			canvas.draw_rect(rect, ink)
	if focus_amount > 0.01:
		# Four corner brackets that settle in as focus is acquired.
		var center := size * 0.5
		var half := Vector2(46, 32) * (1.0 + (1.0 - focus_amount) * 0.35)
		var arm := 14.0
		var ink := Color(STYLE.INK, focus_amount * 0.9)
		var shadow := Color(0, 0, 0, focus_amount * 0.6)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := center + Vector2(sx * half.x, sy * half.y)
				for pass_index in 2:
					var shift := Vector2(2, 2) if pass_index == 0 else Vector2.ZERO
					var color := shadow if pass_index == 0 else ink
					canvas.draw_line(corner + shift, corner + shift + Vector2(-sx * arm, 0), color, 3.0)
					canvas.draw_line(corner + shift, corner + shift + Vector2(0, -sy * arm), color, 3.0)
	if not channels.is_empty():
		# No rooms, no walls, no numbers: only how far and which way one set is
		# from another, which is all it knows about a place it has never seen.
		var center := size * 0.5
		var reach: float = minf(size.x, size.y) * 0.34
		canvas.draw_circle(center, reach + 26.0, Color(0, 0, 0, 0.45))
		# Which way it is facing, so turning its head reads as aiming.
		if channel_look.length() > 0.01:
			var heading := Vector2(channel_look.x, channel_look.y).normalized() * (reach + 18.0)
			canvas.draw_line(center, center + heading, Color(STYLE.INK, 0.25), 2.0)
		for point in channels:
			var at: Vector2 = point.at
			var spot := center + Vector2(at.x, at.y) * reach * 2.0
			var here: bool = point.here
			var chosen: bool = int(point.index) == channel_target
			var ink := Color(STYLE.INK, 0.9 if here or chosen else 0.5)
			canvas.draw_circle(spot + Vector2(2, 2), 7.0 if here else 5.0, Color(0, 0, 0, 0.6))
			if here: canvas.draw_circle(spot, 7.0, ink)
			else: canvas.draw_circle(spot, 5.0, ink)
			if chosen:
				canvas.draw_arc(spot, 13.0, 0.0, TAU, 24, Color(STYLE.INK, 0.85), 2.0)
				canvas.draw_line(center, spot, Color(STYLE.INK, 0.4), 2.0)
