extends Control
## The shared sheet: a blank page for the survivors of a floor, and beside it
## the slips this player has taken. Left button draws, right button erases
## under the cursor. It carries nothing automatic (no map, positions, north,
## exit or creatures): only what players draw, and what they found themselves.
## Opening it stops your character but not the world.
##
## It is a real sheet of paper, cream and worn from being carried about, filmed
## by the same camcorder as everything else (the interface is under the tape).
## Each seat writes with its own pencil -- the host in black, the others in
## navy, dark red and dark green -- which is how a sheet with four hands on it
## stays readable, and the pages the code was written on hang beside it.
##
## Strokes are operations in an order everyone agrees on: the host's. Your own
## strokes show at once (pending) and take their place in that order when the
## host confirms them. Strokes travel in small chunks (chunk_drawn) about ten
## times a second.
signal chunk_drawn(op_id: String, kind: int, points: PackedVector2Array)
enum Kind { DRAW, ERASE }
const STYLE := preload("res://game/ui/osd_style.gd")
const HAND := preload("res://game/ui/handwork.gd")
const PAGE := Vector2(980, 640)
## The page itself, and the four pencils that can write on it, in seat order:
## black for the host, then navy, dark red and dark green.
const PAPER := Color(0.86, 0.82, 0.71)
const INKS := [Color(0.1, 0.1, 0.11), Color(0.11, 0.16, 0.38), Color(0.44, 0.09, 0.09), Color(0.09, 0.29, 0.13)]
## Graphite, for the pages the numbers of the code are written on.
const GRAPHITE := Color(0.13, 0.12, 0.12)
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
var swatch: Control
var slips: VBoxContainer
var pages: GridContainer
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
	style.border_color = Color(0.62, 0.55, 0.42)
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
	# Over the pencil, so rubbing out never rubs out the page itself: the
	# ruled lines, the margin, and the wear of a sheet carried in a pocket.
	var rules := Control.new()
	rules.size = PAGE
	rules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rules.draw.connect(func():
		for y in range(48, int(PAGE.y), 36): rules.draw_line(Vector2(24, y), Vector2(PAGE.x - 24, y), Color(0.32, 0.42, 0.66, 0.2), 1.0)
		rules.draw_line(Vector2(72, 12), Vector2(72, PAGE.y - 12), Color(0.66, 0.18, 0.14, 0.32), 1.0))
	page.add_child(rules)
	var wear := TextureRect.new()
	wear.texture = HAND.wear(Vector2i(256, 168), 1187)
	wear.size = PAGE
	wear.stretch_mode = TextureRect.STRETCH_SCALE
	wear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(wear)
	# What it is, in the corner, the way the tape labels everything.
	var heading := STYLE.text("HOJA COMPARTIDA", 18, STYLE.SOFT)
	heading.position = Vector2(20, -30)
	page.add_child(heading)
	hand = STYLE.text("TU LÁPIZ", 18, STYLE.SOFT)
	hand.position = Vector2(PAGE.x - 250, -30)
	hand.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hand.size.x = 190
	page.add_child(hand)
	# A stroke of it beside the words: the pencils are dark and so is what the
	# words are written on, so the colour is shown on a scrap of the paper.
	swatch = Control.new()
	swatch.position = Vector2(PAGE.x - 52, -26)
	swatch.size = Vector2(52, 20)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.draw.connect(func():
		swatch.draw_rect(Rect2(Vector2.ZERO, swatch.size), PAPER)
		swatch.draw_line(Vector2(6, 13), Vector2(46, 7), ink_of(seat), PEN + 1.0, true))
	page.add_child(swatch)
	# The slips, hanging off the right edge.
	slips = VBoxContainer.new()
	slips.name = "Slips"
	slips.position = Vector2(PAGE.x + 26, -30)
	slips.custom_minimum_size = Vector2(STRIP - 44, 0)
	slips.add_theme_constant_override("separation", 14)
	slips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(slips)
	pages = GridContainer.new()
	pages.columns = 2
	pages.add_theme_constant_override("h_separation", 14)
	pages.add_theme_constant_override("v_separation", 16)
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	swatch.queue_redraw()
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
	for slip in slips.get_children() + pages.get_children():
		if slip == pages: continue
		slip.modulate.a = 0.0
		opening.parallel().tween_property(slip, "modulate:a", 1.0, 0.14).set_delay(wait)
		wait += 0.07

## The colour a seat writes in. Four hands, four channels.
func ink_of(who: int) -> Color:
	return INKS[maxi(0, who - 1) % INKS.size()]

## The pages this player took, pinned up beside the sheet as they are: the
## number written large in pencil, and under it, small, the page number --
## which is which place of the code it is, so the four can be put in order.
## Under each one, in the tape's own type, the room it came out of. Nobody
## else's pages: telling them is the other half of the game.
const LEAF := Vector2(118, 150)
func fill_slips(notes: Array) -> void:
	for old in slips.get_children():
		if old == pages: slips.remove_child(pages)
		else: old.queue_free()
	for old in pages.get_children(): old.queue_free()
	var title := STYLE.text("TUS NOTAS", 18, STYLE.SOFT)
	slips.add_child(title)
	if notes.is_empty():
		var empty := STYLE.text("NADA TODAVÍA", 16, STYLE.FAINT)
		slips.add_child(empty)
		return
	slips.add_child(pages)
	for note in notes:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pages.add_child(cell)
		cell.add_child(leaf(int(note.digit), int(note.slot)))
		var where := String(note.get("where", ""))
		var label := STYLE.text(where if not where.is_empty() else "¿DÓNDE?", 12, STYLE.SOFT)
		label.custom_minimum_size.x = LEAF.x
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cell.add_child(label)

## One of the pages: a scrap of the same worn paper, not quite square to the
## others, with its number and its page number in pencil.
func leaf(digit: int, place: int) -> Control:
	var scrap := Control.new()
	scrap.custom_minimum_size = LEAF
	scrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var worn := HAND.wear(Vector2i(48, 61), 311 + place * 97)
	var tilt := HAND.jitter(float(place), 4.2) * 0.09
	scrap.draw.connect(func() -> void:
		# Drawn turned a little about its middle: inside a grid a control's own
		# rotation is put back to nothing every time the grid lays it out.
		var middle := LEAF * 0.5
		scrap.draw_set_transform(middle, tilt, Vector2.ONE)
		var corner := -middle
		scrap.draw_rect(Rect2(corner + Vector2(3, 4), LEAF), Color(0, 0, 0, 0.35))
		scrap.draw_rect(Rect2(corner, LEAF), PAPER)
		scrap.draw_texture_rect(worn, Rect2(corner, LEAF), false)
		var figure := Rect2(corner + Vector2(LEAF.x * 0.2, LEAF.y * 0.1), Vector2(LEAF.x * 0.6, LEAF.y * 0.62))
		HAND.write_digit(scrap, digit, figure, GRAPHITE, LEAF.x * 0.075, place * 13 + digit)
		HAND.write_page(scrap, place, Vector2(0.0, LEAF.y * 0.39), 11.0, GRAPHITE, place * 7)
		scrap.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	return scrap

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
