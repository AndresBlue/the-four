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
## The shared sheet is open over the picture: its marks step back from it.
var covered := false
## The creature's channels: the lit sets laid out by where they are, nothing
## else, on a compass lying on the floor. [{index, at (on the disk, radius 1:
## x to its right, y towards it), here}], how much of the disk it sees (0 level
## with the horizon, 1 looking straight down) and which one it would step out
## of.
var channels: Array = []
var channel_tilt := 0.0
var channel_target := -1
## The compass's radius, as a share of the picture's short side, and its sets.
const COMPASS_REACH := 0.46
const COMPASS_SET := 3.2
const COMPASS_HERE := 4.6
const COMPASS_RING := 8.0
const COMPASS_ARROW := 18.0

func show_channels(points: Array, tilt: float, target: int) -> void:
	channels = points
	channel_tilt = tilt
	channel_target = target
	canvas.queue_redraw()
var start_seconds := 0
var date_text := ""
## The recording lamp's blink, a second long: lit for LAMP_LIT of it. The dot
## beside REC and the red light on the camcorder's front (hotel_player.pilot)
## are the same lamp and read the same clock; a capture sets it to 0 as it
## starts (death_tape.gd), so the blow at 2.8 s falls between two blinks.
const LAMP_LIT := 0.7
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
## The hunter's two waits, as the share still to go (1 just used, 0 ready): the
## shriek and the trace to a set. Two short bars over the stamina meter, only
## while they recharge, like the stamina itself.
var waits := {"CHILLIDO": 0.0, "RASTRO": 0.0}
## And the lift it has to take: the share of the wait still to go (a dial
## that empties), and the seconds, while it may not ride it yet.
var lift_share := 0.0
var lift_seconds := 0.0
## The zoom rocker: where it stands (0 wide, 1 telephoto) and how long the
## bar stays up after it last moved, as on a camcorder.
var zoom := 0.0
var zoom_alpha := 0.0
var zoom_still := 9.0
const ZOOM_HOLD := 1.6
## The side of the runner's card over the stamina meter, in pixels.
const RUN_CARD := 28.0

## Line art in a unit square, drawn at `at` the size of `side`: the first entry
## is the stroke (a share of the side), then polylines with round joints and
## dots as Vector3 (x, y, radius). Drawn shapes, not a font's glyphs, so they
## look the same with any fallback font. `grow` thickens everything by that
## many pixels: drawn first in black, it is the edge of the same mark in white.
static func draw_icon(item: CanvasItem, icon: Array, at: Vector2, side: float, color: Color, grow := 0.0) -> void:
	var width: float = float(icon[0]) * side + grow
	for shape in icon.slice(1):
		if shape is Vector3:
			item.draw_circle(at + Vector2(shape.x, shape.y) * side, shape.z * side + grow * 0.5, color)
			continue
		var points := PackedVector2Array()
		for point: Vector2 in shape: points.append(at + point * side)
		item.draw_polyline(points, color, width, true)
		# draw_polyline has square ends and corners; a pen does not.
		for point in points: item.draw_circle(point, width * 0.5, color)

## Points along a circle in the unit square, from one angle to another
## (radians, clockwise on screen).
static func arc(centre: Vector2, radius: float, from: float, to: float, steps := 10) -> Array:
	var points: Array = []
	for k in steps + 1:
		var angle := lerpf(from, to, float(k) / steps)
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points

## A figure running to the right, mid stride: the stamina meter's mark.
static func runner_icon() -> Array:
	return [0.11, Vector3(0.64, 0.15, 0.1),
		[Vector2(0.57, 0.31), Vector2(0.44, 0.58)],
		[Vector2(0.56, 0.35), Vector2(0.71, 0.47), Vector2(0.85, 0.39)],
		[Vector2(0.55, 0.35), Vector2(0.38, 0.39), Vector2(0.26, 0.52)],
		[Vector2(0.44, 0.58), Vector2(0.64, 0.70), Vector2(0.61, 0.90), Vector2(0.71, 0.90)],
		[Vector2(0.44, 0.58), Vector2(0.35, 0.76), Vector2(0.15, 0.80)]]

## A walkie-talkie: a teammate heard over the radio.
static func radio_icon() -> Array:
	return [0.09,
		[Vector2(0.31, 0.32), Vector2(0.69, 0.32), Vector2(0.69, 0.93), Vector2(0.31, 0.93), Vector2(0.31, 0.32)],
		[Vector2(0.40, 0.32), Vector2(0.40, 0.07)],
		[Vector2(0.42, 0.48), Vector2(0.58, 0.48)],
		[Vector2(0.42, 0.60), Vector2(0.58, 0.60)],
		Vector3(0.50, 0.78, 0.06)]

## A head in profile with the sound leaving its mouth: a teammate heard
## through the air, near enough.
static func voice_icon() -> Array:
	var head: Array = [Vector2(0.25, 0.93), Vector2(0.22, 0.68), Vector2(0.13, 0.52)]
	head += arc(Vector2(0.34, 0.38), 0.22, PI, TAU - PI / 6.0)
	head += [Vector2(0.56, 0.42), Vector2(0.62, 0.53), Vector2(0.56, 0.56), Vector2(0.57, 0.64), Vector2(0.52, 0.72), Vector2(0.44, 0.74), Vector2(0.44, 0.93)]
	return [0.08, head,
		arc(Vector2(0.62, 0.56), 0.14, -PI / 4.0, PI / 4.0, 6),
		arc(Vector2(0.62, 0.56), 0.27, -PI / 4.0, PI / 4.0, 8)]

## A hand microphone on its stand: the local player is sending.
static func microphone_icon() -> Array:
	var capsule: Array = arc(Vector2(0.5, 0.22), 0.13, PI, TAU, 8) + arc(Vector2(0.5, 0.46), 0.13, 0.0, PI, 8)
	capsule.append(capsule[0])
	return [0.09, capsule,
		arc(Vector2(0.5, 0.48), 0.24, 0.0, PI, 10),
		[Vector2(0.5, 0.72), Vector2(0.5, 0.88)],
		[Vector2(0.34, 0.88), Vector2(0.66, 0.88)]]

## The camcorder's lettering is softer than the picture it is burnt into: the
## blur of an old recording is right on these words and too much on the
## picture and the menus (the author, 19 November 2026). Each corner's
## lettering is drawn as a group and softened along the lines before the tape
## has it (mark_soft.gdshader). The groups are small: only what is written in
## them is read again. REC and the clock, which are there to be seen; not the
## word under the brackets nor the notice, which are there to be read at once
## (softened too, the author could not read "CERRAR").
const MARK_SOFT := preload("res://game/presentation/shaders/mark_soft.gdshader")
var soft_look := ShaderMaterial.new()
var corners: Array[Control] = []

## A piece of the picture to write in: a Control the size of the picture, so
## anchors mean in it what they mean on the layer itself.
func soft_corner() -> Control:
	var group := CanvasGroup.new()
	group.fit_margin = 12.0
	group.clear_margin = 12.0
	group.material = soft_look
	add_child(group)
	var corner := Control.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(corner)
	corners.append(corner)
	return corner

func fit_corners() -> void:
	for corner in corners: corner.size = get_viewport().get_visible_rect().size

## How soft, by the tape's wear (the player's VHS slider; 0 with reduced
## effects): the law the whole picture had at first.
func soften(wear: float) -> void:
	soft_look.set_shader_parameter("soft", 1.6 + wear * 5.0 if wear > 0.0 else 0.0)

func _ready() -> void:
	# Under the interface and under the tape: the OSD is burnt into the
	# recording, and so is anything the game writes over it.
	layer = 3
	soft_look.shader = MARK_SOFT
	get_viewport().size_changed.connect(fit_corners)
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(draw_overlay)
	add_child(canvas)
	rec = STYLE.mark("REC\nSP", true)
	rec.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rec.offset_left = -300 - STYLE.MARK_INSET
	rec.offset_top = 40
	rec.offset_right = -STYLE.MARK_INSET
	var top_right := soft_corner()
	top_right.add_child(rec)
	# Drawn shape rather than a glyph, so it works with any fallback font.
	dot = Panel.new()
	var round_style := StyleBoxFlat.new()
	round_style.bg_color = STYLE.ALERT
	round_style.set_corner_radius_all(9)
	dot.add_theme_stylebox_override("panel", round_style)
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Before the R of REC: three letters of the mark's size, narrowed as it is.
	dot.offset_right = -STYLE.MARK_INSET - 3.0 * 0.6 * STYLE.MARK_SIZE * STYLE.MARK_NARROW - 12.0
	dot.offset_left = dot.offset_right - 18.0
	dot.offset_top = 55
	dot.offset_bottom = 73
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_right.add_child(dot)
	clock = STYLE.mark("")
	clock.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	clock.offset_left = STYLE.MARK_INSET
	clock.offset_top = -164
	clock.offset_right = STYLE.MARK_INSET + 620
	clock.offset_bottom = -58
	soft_corner().add_child(clock)
	focus_label = STYLE.text("", 20)
	focus_label.set_anchors_preset(Control.PRESET_CENTER)
	focus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_label.offset_left = -200
	focus_label.offset_right = 200
	focus_label.offset_top = 44
	focus_label.offset_bottom = 74
	add_child(focus_label)
	# One of the lines at the foot of the picture: the interface gives it its
	# height, over or under the others that are up (hotel_ui.stack_foot).
	notice = STYLE.text("", 30)
	notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.offset_left = -260
	notice.offset_right = 260
	notice.offset_top = -150
	notice.offset_bottom = -110
	add_child(notice)
	fit_corners()
	hide()

## The recording date derives from the floor seed, so a retry shows the same tape.
## The tape's date as [day, month, year in two figures] (the offices' card).
var date_parts: Array = [1, 1, 92]

func start_tape(run_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + 1989
	var year := rng.randi_range(1986, 1997)
	var month := rng.randi_range(0, 11)
	var day := rng.randi_range(1, 28)
	start_seconds = 2 * 3600 + rng.randi_range(0, 3599)
	date_text = "%s %d %d" % [MONTHS[month], day, year]
	date_parts = [day, month + 1, year % 100]
	stamina = 1.0
	stamina_alpha = 0.0
	full_time = 99.0
	for title in waits: waits[title] = 0.0
	lift_share = 0.0
	focus_word = ""

func set_cooldowns(shriek: float, trace: float) -> void:
	waits["CHILLIDO"] = clampf(shriek, 0.0, 1.0)
	waits["RASTRO"] = clampf(trace, 0.0, 1.0)

func set_lift_wait(share: float, seconds: float) -> void:
	lift_share = clampf(share, 0.0, 1.0)
	lift_seconds = maxf(0.0, seconds)

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

## Whether the recording lamp is lit at this moment of its blink.
func lamp_lit() -> bool:
	return blink < LAMP_LIT

func show_tape(elapsed: float, delta: float) -> void:
	blink = fposmod(blink + delta, 1.0)
	var tape := marks and not hunter and not signal_lost and not covered
	rec.visible = tape
	dot.visible = tape and lamp_lit()
	clock.visible = tape
	notice.visible = not notice.text.is_empty()
	if hunter or signal_lost: focus_word = ""
	clock.text = clock_text(elapsed)
	# The meter appears while stamina is spent and fades out once full.
	full_time = full_time + delta if stamina >= 0.999 else 0.0
	stamina_alpha = move_toward(stamina_alpha, 0.0 if full_time > 1.5 else 1.0, delta * 2.5)
	focus_amount = move_toward(focus_amount, 1.0 if not focus_word.is_empty() else 0.0, delta * 7.0)
	if not focus_word.is_empty(): focus_label.text = focus_word
	focus_label.modulate.a = focus_amount
	canvas.queue_redraw()

## What the camcorder's clock reads `elapsed` seconds into its tape.
func clock_text(elapsed: float) -> String:
	var total := start_seconds + int(elapsed)
	var hours := total / 3600
	return "AM %d:%02d:%02d\n%s" % [hours % 12 if hours % 12 != 0 else 12, (total / 60) % 60, total % 60, date_text]

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
		var right := size.x - STYLE.MARK_INSET
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
		if not hunter:
			# What the meter is: a figure running, black on a white card, over
			# its left end. The creature's meter has its waits stacked there.
			var card := Rect2(Vector2(right - width, bottom - cell.y - 8.0 - RUN_CARD), Vector2(RUN_CARD, RUN_CARD))
			canvas.draw_rect(Rect2(card.position + Vector2(2, 2), card.size), Color(0, 0, 0, stamina_alpha * 0.6))
			canvas.draw_rect(card, Color(STYLE.INK, stamina_alpha * 0.9))
			canvas.draw_rect(card, Color(0, 0, 0, stamina_alpha * 0.9), false, 2.0)
			draw_icon(canvas, runner_icon(), card.position + Vector2(3, 3), RUN_CARD - 6.0, Color(0, 0, 0, stamina_alpha * 0.9))
	if hunter:
		# Its waits: a word and a bar that fills as it comes back.
		var font := STYLE.font()
		var right := size.x - STYLE.MARK_INSET
		var row := size.y - 60.0 - 22.0 - 22.0
		for title in waits:
			var left: float = waits[title]
			if left <= 0.001: continue
			var bar := Rect2(Vector2(right - 150.0, row - 6.0), Vector2(150.0, 6.0))
			var word_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			for pass_index in 2:
				var shift := Vector2(2, 2) if pass_index == 0 else Vector2.ZERO
				var ink := Color(0, 0, 0, 0.6) if pass_index == 0 else Color(STYLE.INK, 0.9)
				canvas.draw_string(font, Vector2(bar.position.x - 12.0 - word_width, row) + shift, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
				canvas.draw_rect(Rect2(bar.position + shift, bar.size), Color(ink, ink.a * 0.25))
				canvas.draw_rect(Rect2(bar.position + shift, Vector2(bar.size.x * (1.0 - left), bar.size.y)), ink)
			row -= 26.0
		# The lift: a small pie that empties as its wait runs out, and the word.
		if lift_share > 0.001:
			var radius := 16.0
			var centre := Vector2(right - radius, row - 6.0 - radius)
			var title := "ASCENSOR %d" % int(ceil(lift_seconds))
			var word_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			for pass_index in 2:
				var shift := Vector2(2, 2) if pass_index == 0 else Vector2.ZERO
				var ink := Color(0, 0, 0, 0.6) if pass_index == 0 else Color(STYLE.INK, 0.9)
				canvas.draw_string(font, Vector2(centre.x - radius - 12.0 - word_width, centre.y + 6.0) + shift, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
				canvas.draw_circle(centre + shift, radius, Color(ink, ink.a * 0.25))
				# From twelve o'clock, clockwise, what is still to wait.
				var wedge := PackedVector2Array([centre + shift])
				var steps := maxi(2, int(48 * lift_share))
				for k in steps + 1:
					var angle := -PI * 0.5 + TAU * lift_share * float(k) / float(steps)
					wedge.append(centre + shift + Vector2(cos(angle), sin(angle)) * radius)
				canvas.draw_colored_polygon(wedge, ink)
				canvas.draw_arc(centre + shift, radius, 0.0, TAU, 40, ink, 1.5, true)
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
		# A compass lying on the floor, seen from where it looks: squashed to a
		# line level with the horizon, a circle looking down at its feet.
		var center := size * 0.5
		var radius: float = minf(size.x, size.y) * COMPASS_REACH
		var squash: float = channel_tilt
		var rim := PackedVector2Array()
		for k in 72: rim.append(center + Vector2(cos(TAU * k / 72.0), sin(TAU * k / 72.0) * squash) * radius)
		if squash > 0.03: canvas.draw_colored_polygon(rim, Color(0, 0, 0, 0.45))
		rim.append(rim[0])
		canvas.draw_polyline(rim, Color(STYLE.INK, 0.4), 2.0, true)
		for point in channels:
			var at: Vector2 = point.at
			var spot := center + Vector2(at.x, at.y * squash) * radius
			var here: bool = point.here
			var chosen: bool = int(point.index) == channel_target
			var ink := Color(STYLE.INK, 0.9 if here or chosen else 0.55)
			var dot: float = COMPASS_HERE if here else COMPASS_SET
			canvas.draw_circle(spot + Vector2(1.5, 1.5), dot, Color(0, 0, 0, 0.6))
			canvas.draw_circle(spot, dot, ink)
			if chosen:
				canvas.draw_arc(spot, COMPASS_RING, 0.0, TAU, 24, Color(STYLE.INK, 0.85), 1.5)
				# From here to there: an arrowhead halfway along says which way.
				var ink_line := Color(STYLE.INK, 0.6)
				canvas.draw_line(center, spot, ink_line, 1.5)
				var way := spot - center
				if way.length() > COMPASS_ARROW * 3.0:
					var dir := way.normalized()
					var tip := center + way * 0.5 + dir * COMPASS_ARROW * 0.5
					var back := tip - dir * COMPASS_ARROW
					var side := Vector2(-dir.y, dir.x) * COMPASS_ARROW * 0.5
					canvas.draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), ink_line)
