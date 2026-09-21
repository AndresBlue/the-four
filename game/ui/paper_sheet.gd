extends Control
## The shared sheet: a blank page for the survivors of a floor, and beside it
## the slips this player has taken. Left button draws, right button erases
## under the cursor. It carries nothing automatic (no map, positions, north,
## exit or creatures): only what players draw, and what they found themselves.
## Opening it stops your character but not the world.
##
## It is drawn as the tape draws everything else -- light on dark, the OSD's
## own type, scanlines across it -- because it is the same camcorder looking at
## it. Each seat writes in its own colour, which is how a sheet with four hands
## on it stays readable.
##
## Strokes are operations in an order everyone agrees on: the host's. Your own
## strokes show at once (pending) and take their place in that order when the
## host confirms them. Strokes travel in small chunks (chunk_drawn) about ten
## times a second.
signal chunk_drawn(op_id: String, kind: int, points: PackedVector2Array)
enum Kind { DRAW, ERASE }
const STYLE := preload("res://game/ui/osd_style.gd")
const PAGE := Vector2(980, 640)
## The page itself, and the four hands that can write on it: white, amber,
## video blue and phosphor green, in seat order.
const PAPER := Color(0.055, 0.055, 0.05)
const INKS := [Color(0.94, 0.94, 0.9), Color(0.96, 0.78, 0.4), Color(0.52, 0.82, 0.96), Color(0.58, 0.92, 0.6)]
const PEN := 3.0
const ERASER := 30.0
## The strip of slips hanging off the page's right edge.
const STRIP := 300.0
## Seconds between chunks sent while a stroke is being drawn.
const FLUSH := 0.1
## Minimum distance (pixels) between recorded points.
const SPACING := 3.0
## Most points in one chunk.
const CHUNK := 96
## A floor's sheet stops taking strokes past this many.
const MAX_OPS := 3000
var page: Panel
var ink: Control
var caption: Label
## Which colour this seat writes in, and the slips taken by this player.
var hand: Label
var slips: VBoxContainer
var opening: Tween
## op_id -> Line2D
var lines := {}
## Confirmed operations in host order: [op_id, kind, points].
var log: Array = []
var log_index := {}
var confirmed_count := 0
## Operations drawn on this machine (their points are already on screen).
var drawn_here := {}
var seat := 1
var counter := 0
var editable := true
var drawing_op := ""
var drawing_kind := Kind.DRAW
var unsent := PackedVector2Array()
var last_point := Vector2.INF
var flush_clock := 0.0

func _ready() -> void:
	name = "PaperSheet"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	page = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = STYLE.FAINT
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 22
	page.add_theme_stylebox_override("panel", style)
	page.set_anchors_preset(Control.PRESET_CENTER)
	# The page sits left of centre: the slips hang off its right edge and the
	# pair of them is what is centred.
	page.offset_left = -PAGE.x * 0.5 - STRIP * 0.5
	page.offset_right = PAGE.x * 0.5 - STRIP * 0.5
	page.offset_top = -PAGE.y * 0.5 - 16
	page.offset_bottom = PAGE.y * 0.5 - 16
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	ink = Control.new()
	ink.clip_contents = true
	ink.size = PAGE
	ink.mouse_filter = Control.MOUSE_FILTER_STOP
	ink.gui_input.connect(_ink_input)
	page.add_child(ink)
	# Over the ink, so erasing never wipes the page itself: the scan of the
	# tape, a ruled line every so often, and the margin.
	var rules := Control.new()
	rules.size = PAGE
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rules.draw.connect(func():
		for y in range(0, int(PAGE.y), 4): rules.draw_line(Vector2(0, y), Vector2(PAGE.x, y), Color(0.6, 0.7, 0.85, 0.05), 1.0)
		for y in range(48, int(PAGE.y), 36): rules.draw_line(Vector2(24, y), Vector2(PAGE.x - 24, y), Color(0.55, 0.65, 0.85, 0.09), 1.0)
		rules.draw_line(Vector2(72, 12), Vector2(72, PAGE.y - 12), Color(0.96, 0.78, 0.4, 0.16), 1.0))
	page.add_child(rules)
	# What it is, in the corner, the way the tape labels everything.
	var heading := STYLE.text("HOJA COMPARTIDA", 18, STYLE.SOFT)
	heading.position = Vector2(20, -30)
	page.add_child(heading)
	hand = STYLE.text("", 18)
	hand.position = Vector2(PAGE.x - 200, -30)
	hand.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hand.size.x = 200
	page.add_child(hand)
	# The slips, hanging off the right edge.
	slips = VBoxContainer.new()
	slips.name = "Slips"
	slips.position = Vector2(PAGE.x + 26, -30)
	slips.custom_minimum_size = Vector2(STRIP - 44, 0)
	slips.add_theme_constant_override("separation", 12)
	slips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(slips)
	caption = Label.new()
	caption.add_theme_font_override("font", preload("res://game/ui/osd_style.gd").font())
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", Color(0.85, 0.83, 0.76))
	caption.set_anchors_preset(Control.PRESET_CENTER)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.offset_left = -PAGE.x * 0.5
	caption.offset_right = PAGE.x * 0.5
	caption.offset_top = PAGE.y * 0.5 - 4
	caption.offset_bottom = PAGE.y * 0.5 + 22
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)

func open(can_edit: bool, key_name: String, notes := []) -> void:
	editable = can_edit
	visible = true
	# Smaller windows get a smaller page (pointer positions stay in page space).
	var fit := minf(1.0, minf((size.x - 60.0) / (PAGE.x + STRIP), (size.y - 110.0) / PAGE.y))
	page.pivot_offset = PAGE * 0.5
	var shown := maxf(fit, 0.4)
	page.scale = Vector2.ONE * shown
	hand.text = "TU TRAZO"
	hand.add_theme_color_override("font_color", ink_of(seat))
	caption.text = ("IZQUIERDO DIBUJA · DERECHO BORRA · %s CIERRA" % key_name) if editable else ("SOLO PUEDES MIRAR · %s CIERRA" % key_name)
	fill_slips(notes)
	# It comes up the way the tape cuts to anything: quick, and from nothing.
	if is_instance_valid(opening): opening.kill()
	page.modulate.a = 0.0
	page.scale = Vector2.ONE * shown * 0.965
	opening = create_tween()
	opening.tween_property(page, "modulate:a", 1.0, 0.12)
	opening.parallel().tween_property(page, "scale", Vector2.ONE * shown, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var wait := 0.1
	for slip in slips.get_children():
		slip.modulate.a = 0.0
		opening.parallel().tween_property(slip, "modulate:a", 1.0, 0.14).set_delay(wait)
		wait += 0.07

## The colour a seat writes in. Four hands, four channels.
func ink_of(who: int) -> Color:
	return INKS[maxi(0, who - 1) % INKS.size()]

## The slips taken by this player, as they would be if they were pinned up
## beside the sheet: the place of the code, the number, and the room it came
## out of. Nobody else's, because telling them is the other half of the game.
func fill_slips(notes: Array) -> void:
	for old in slips.get_children(): old.queue_free()
	var title := STYLE.text("TUS NOTAS", 18, STYLE.SOFT)
	slips.add_child(title)
	if notes.is_empty():
		var empty := STYLE.text("NADA TODAVÍA", 16, STYLE.FAINT)
		slips.add_child(empty)
		return
	for note in notes:
		var slip := PanelContainer.new()
		slip.add_theme_stylebox_override("panel", STYLE.flat(Color(0.1, 0.1, 0.09, 0.9), STYLE.FAINT, 1, 12.0))
		slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 2)
		slip.add_child(column)
		column.add_child(STYLE.text("NÚMERO %d DEL CÓDIGO" % int(note.slot), 14, STYLE.SOFT))
		var figure := STYLE.text(str(int(note.digit)), 44, STYLE.AMBER)
		column.add_child(figure)
		var where := String(note.get("where", ""))
		column.add_child(STYLE.text(where if not where.is_empty() else "NO APUNTASTE DÓNDE", 14, STYLE.FAINT))
		slips.add_child(slip)

func close() -> void:
	finish_stroke()
	if is_instance_valid(opening): opening.kill()
	page.modulate.a = 1.0
	visible = false

## A new, empty sheet (new floor or retry).
func clear() -> void:
	finish_stroke()
	for line in lines.values(): line.queue_free()
	lines.clear()
	drawn_here.clear()
	log.clear()
	log_index.clear()
	confirmed_count = 0
	counter = 0

func _ink_input(event: InputEvent) -> void:
	if not editable: return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.pressed and drawing_op.is_empty():
			if log.size() >= MAX_OPS: return
			drawing_kind = Kind.DRAW if event.button_index == MOUSE_BUTTON_LEFT else Kind.ERASE
			counter += 1
			drawing_op = "%d:%d" % [seat, counter]
			drawn_here[drawing_op] = true
			line_for(drawing_op, drawing_kind)
			last_point = Vector2.INF
			add_point(event.position)
		elif not event.pressed:
			add_point(event.position)
			finish_stroke()
		accept_event()
	elif event is InputEventMouseMotion and not drawing_op.is_empty():
		add_point(event.position)
		accept_event()

func add_point(position: Vector2) -> void:
	position = position.clamp(Vector2.ZERO, PAGE)
	if last_point != Vector2.INF and position.distance_to(last_point) < SPACING: return
	last_point = position
	lines[drawing_op].add_point(position)
	unsent.append(position / PAGE)
	if unsent.size() >= CHUNK: flush()

func finish_stroke() -> void:
	if drawing_op.is_empty(): return
	flush()
	drawing_op = ""

func flush() -> void:
	flush_clock = FLUSH
	if unsent.is_empty() or drawing_op.is_empty(): return
	var points := unsent
	unsent = PackedVector2Array()
	chunk_drawn.emit(drawing_op, drawing_kind, points)

func _process(delta: float) -> void:
	if drawing_op.is_empty(): return
	flush_clock -= delta
	if flush_clock <= 0.0: flush()

## A Line2D for an operation; new ones go after everything drawn so far.
func line_for(op_id: String, kind: int) -> Line2D:
	if lines.has(op_id): return lines[op_id]
	var line := Line2D.new()
	line.width = PEN if kind == Kind.DRAW else ERASER
	# Whose stroke it is is in the operation's name, and that is what gives it
	# its colour: a sheet with four hands on it is only readable if they can be
	# told apart.
	line.default_color = ink_of(int(op_id.get_slice(":", 0))) if kind == Kind.DRAW else PAPER
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	ink.add_child(line)
	lines[op_id] = line
	return line

## The host's order for a chunk. A stroke takes its place in the order with its
## first confirmed chunk; its own author already sees the points.
func apply_confirmed(op_id: String, kind: int, points: PackedVector2Array) -> void:
	var line := line_for(op_id, kind)
	var own := drawn_here.has(op_id)
	if not log_index.has(op_id):
		log_index[op_id] = log.size()
		log.append([op_id, kind, PackedVector2Array()])
		ink.move_child(line, confirmed_count)
		confirmed_count += 1
	var entry: Array = log[log_index[op_id]]
	var merged: PackedVector2Array = entry[2]
	merged.append_array(points)
	entry[2] = merged
	if not own:
		for point in points: line.add_point(point * PAGE)

func snapshot() -> Array:
	return log.duplicate(true)

func restore(ops: Array) -> void:
	clear()
	for op in ops:
		if op is Array and op.size() == 3:
			var line := line_for(op[0], int(op[1]))
			for point in op[2]: line.add_point(point * PAGE)
			log_index[op[0]] = log.size()
			log.append([op[0], int(op[1]), op[2]])
			confirmed_count += 1
			# New strokes from this seat must not reuse an earlier number.
			if String(op[0]).begins_with("%d:" % seat): counter = maxi(counter, int(String(op[0]).get_slice(":", 1)))
