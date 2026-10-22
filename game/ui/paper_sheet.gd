extends Control
## The shared sheet: a page for the survivors of a floor, taking most of the
## screen, and beside it, in a narrow column, the slips this player has taken,
## hanging one from the next in a zigzag chain. Left button draws, right button
## erases under the cursor. The one thing on it nobody drew is the plan
## (sheet_map.gd): the walls the survivors have had in front of them lately,
## drawn by the page itself and fading. No positions of anybody else, no north,
## no exit, no creature. Opening it stops your character but not the world.
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
## A stroke begun on the plan belongs to the building, not to the page: its
## points are kept in the plan (world x, z) and its kind says so, and which
## planta: MAP_KIND + planta * 2, plus one for rubbing out. Drawn again from
## those wherever the plan is framed now, it stays on the walls it was drawn
## on as the plan grows, on every machine, whatever each one frames.
const MAP_KIND := 10
static func map_kind(kind: int) -> bool: return kind >= MAP_KIND
static func erasing(kind: int) -> bool: return (kind - MAP_KIND) % 2 == 1 if map_kind(kind) else kind == Kind.ERASE
const STYLE := preload("res://game/ui/osd_style.gd")
const HAND := preload("res://game/ui/handwork.gd")
const PAGE := Vector2(1600, 1000)
## Where the plan is drawn on the page, as shares of it: the right-hand three
## fifths, below the top quarter; the rest is for the players' own hands.
const MAP_AREA := Rect2(0.335, 0.22, 0.59, 0.735)
const MAP := preload("res://game/ui/sheet_map.gd")
const HINT_VIEW := preload("res://game/ui/hint_view.gd")
## The page itself, and the four pencils that can write on it, in seat order:
## black for the host, then navy, dark red and dark green.
const PAPER := Color(0.86, 0.82, 0.71)
const INKS := [Color(0.1, 0.1, 0.11), Color(0.11, 0.16, 0.38), Color(0.44, 0.09, 0.09), Color(0.09, 0.29, 0.13), Color(0.36, 0.2, 0.06), Color(0.29, 0.1, 0.33)]
const PEN := 3.0
const ERASER := 30.0
## The column of slips beside the page's right edge.
const STRIP := 250.0
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
## The slips taken by this player: the column, and the chain in it.
var slips: Control
var pages: Control
## The plan, and what it is drawn from (floor_map.gd, given by hotel_main).
var map: Control
var map_source:
	set(value):
		map_source = value
		if map != null: map.source = value
var opening: Tween
## op_id -> Line2D
var lines := {}
## Confirmed operations in host order: [op_id, kind, points].
var log: Array = []
var log_index := {}
var confirmed_count := 0
var map_confirmed := 0
## Operations drawn on this machine (their points are already on screen).
var drawn_here := {}
var seat := 1
var counter := 0
var editable := true
var drawing_op := ""
var drawing_kind: int = Kind.DRAW
## The pencil on the plan: under it, over the page's own pencil.
var map_pencil: Control
var unsent := PackedVector2Array()
var last_point := Vector2.INF
var flush_clock := 0.0
## A pad's pencil. A pad has no pointer, and Godot does not pass on where a
## finger is on a PlayStation's touchpad (only its click), so the pencil is
## steered: the left stick moves its tip over the page, quick pushed all the
## way and slow barely pushed, and slower still while it draws; the right
## trigger draws and the left one rubs out. It shows once the pad moves it and
## goes when the mouse does.
const TIP_SPEED := 820.0
const TIP_DRAWING := 0.55
const TRIGGER := 0.35
var tip: Control
var tip_at := PAGE * 0.5
var tip_shown := false
var tip_rubbing := false
var pad_stroke := false

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
	page.offset_top = -PAGE.y * 0.5
	page.offset_bottom = PAGE.y * 0.5
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	ink = Control.new()
	ink.clip_contents = true
	ink.size = PAGE
	ink.mouse_filter = Control.MOUSE_FILTER_STOP
	ink.gui_input.connect(_ink_input)
	page.add_child(ink)
	map_pencil = Control.new()
	map_pencil.name = "PlanPencil"
	map_pencil.position = PAGE * MAP_AREA.position
	map_pencil.size = PAGE * MAP_AREA.size
	map_pencil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(map_pencil)
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
	wear.texture = HAND.wear(Vector2i(256, 160), 1187, false)
	wear.size = PAGE
	wear.stretch_mode = TextureRect.STRETCH_SCALE
	wear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(wear)
	# The plan, over the pencil: rubbing out what somebody wrote never rubs
	# out a wall the page put down.
	map = MAP.new()
	map.name = "Plan"
	map.position = PAGE * MAP_AREA.position
	map.size = PAGE * MAP_AREA.size
	map.source = map_source
	map.pencil = map_pencil
	page.add_child(map)
	# The slips, in their column off the right edge.
	slips = Control.new()
	slips.name = "Slips"
	slips.position = Vector2(PAGE.x + 26, 0)
	slips.size = Vector2(STRIP - 36, PAGE.y)
	slips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(slips)
	pages = Control.new()
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
	tip = Control.new()
	tip.name = "PadPencil"
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip.visible = false
	tip.draw.connect(func() -> void:
		var ink_colour: Color = PAPER.darkened(0.45) if tip_rubbing else ink_of(seat)
		var reach := ERASER * 0.5 if tip_rubbing else 7.0
		tip.draw_arc(Vector2.ZERO, reach, 0.0, TAU, 28, Color(ink_colour, 0.85), 1.6, true)
		tip.draw_circle(Vector2.ZERO, 1.8, ink_colour, true, -1.0, true))
	page.add_child(tip)

## The hints this player took or read (hint_placement.gd), hanging under the
## pages in miniature, each the paper it is; a click (or the pad's pencil and
## its trigger) holds one up over the sheet, and another puts it down. The
## walls of their planta are what their plans are drawn from.
const THUMB := 112.0
var hint_walls: Array = []
var held: Control
var thumbs: Array = []
var trigger_was := false

func open(can_edit: bool, key_name: String, notes := [], hints := [], walls := []) -> void:
	hint_walls = walls
	editable = can_edit
	visible = true
	# Smaller windows get a smaller page (pointer positions stay in page space).
	var fit := minf((size.x - 48.0) / (PAGE.x + STRIP), (size.y - 56.0) / PAGE.y)
	page.pivot_offset = PAGE * 0.5
	var shown := clampf(fit, 0.3, 1.6)
	page.scale = Vector2.ONE * shown
	# Nothing said while it can be written on; only that it cannot.
	caption.text = "" if editable else ("SOLO PUEDES MIRAR, %s CIERRA" % key_name)
	fill_slips(notes, hints)
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

## The pages this player took, beside the sheet: the pieces of the torn
## letter (torn_letter.gd), each put back where it was torn from, so the
## letter comes together as they are found and where each one sits says which
## place of the code its number is. On each, the number written large in
## pencil and, under it, the room it came out of. Where a piece is still
## missing, only the faint shape of the hole. Nobody else's pages: telling
## them is the other half of the game.
const LETTER := preload("res://game/ui/torn_letter.gd")
func fill_slips(notes: Array, hints := []) -> void:
	for old in slips.get_children():
		if old == pages: slips.remove_child(pages)
		else: old.queue_free()
	for old in pages.get_children(): old.queue_free()
	thumbs.clear()
	var title := STYLE.text("TUS NOTAS", 18, STYLE.SOFT)
	slips.add_child(title)
	if notes.is_empty() and hints.is_empty():
		var empty := STYLE.text("NADA TODAVÍA", 16, STYLE.FAINT)
		empty.position = Vector2(0, 28)
		slips.add_child(empty)
		return
	slips.add_child(pages)
	pages.position = Vector2(0, 40)
	var letter_size := Vector2(slips.size.x - 6.0, (slips.size.x - 6.0) * 1.5)
	if not notes.is_empty():
		var letter := Control.new()
		letter.name = "Letter"
		letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		letter.size = letter_size
		pages.add_child(letter)
		var found := {}
		for note in notes: found[int(note.slot)] = note
		letter.draw.connect(func() -> void:
			var full := LETTER.CARTA.get_size()
			var scale := letter_size / full
			for place in range(1, 5):
				var box: Rect2 = LETTER.quarter(place)
				var rect := Rect2(box.position * scale, box.size * scale)
				if not found.has(place):
					letter.draw_rect(rect.grow(-3.0), Color(PAPER, 0.08), false, 1.0)
					continue
				# Put back nearly where it was torn from: a hair apart, a hair
				# askew.
				var nudge := Vector2(HAND.jitter(float(place), 2.0), HAND.jitter(float(place), 4.0)) * 4.0
				LETTER.draw_piece(letter, place, Rect2(rect.position + nudge, rect.size), int(found[place].digit), String(found[place].get("where", "")), HAND.jitter(float(place), 6.0) * 0.05))
	# The hints under the letter, smaller, in a chain of their own.
	var y := 0.0 if notes.is_empty() else letter_size.y + 16.0
	var room_left := slips.size.y - 40.0 - y
	var step := minf(84.0, room_left / maxf(1.0, float(hints.size()) + 0.6))
	for i in hints.size():
		var hint: Dictionary = hints[i]
		var view := HINT_VIEW.new()
		view.setup(hint, hint_walls)
		var shrink := THUMB / view.card.x
		var cell := Control.new()
		cell.name = "Hint_%d" % int(hint.id)
		cell.size = view.card * shrink
		cell.position = Vector2((slips.size.x - THUMB) * float(i % 2), y)
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		cell.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: hold_up(hint))
		view.scale = Vector2.ONE * shrink
		view.rotation = HAND.jitter(float(i), 9.0) * 0.06
		cell.add_child(view)
		pages.add_child(cell)
		thumbs.append({"cell": cell, "hint": hint})
		y += step

## A hint held up over the sheet, as large as the page allows; a click
## anywhere, or the pad's trigger again, puts it down.
func hold_up(hint: Dictionary) -> void:
	put_down()
	held = Control.new()
	held.name = "HeldHint"
	held.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	held.mouse_filter = Control.MOUSE_FILTER_STOP
	held.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: put_down())
	add_child(held)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	held.add_child(shade)
	var view := HINT_VIEW.new()
	view.setup(hint, hint_walls)
	# A whole sheet (the hotel's form, a notebook's page, the folded map) to
	# nearly the height of the page, or nearly its width.
	var whole: bool = view.card.y >= 1000.0 or view.card.x >= 1000.0
	var fit := minf(minf(size.x * (0.8 if whole else 0.62) / view.card.x, size.y * (0.93 if whole else 0.78) / view.card.y), 1.5)
	view.scale = Vector2.ONE * fit
	view.position = (size - view.card * fit) * 0.5
	held.add_child(view)

func put_down() -> void:
	if is_instance_valid(held): held.queue_free()
	held = null

## The hint under a point of the page (the pad's pencil), or {}.
func thumb_at(point: Vector2) -> Dictionary:
	for entry in thumbs:
		var cell: Control = entry.cell
		if not is_instance_valid(cell): continue
		var origin: Vector2 = slips.position + pages.position + cell.position
		if Rect2(origin, cell.size).has_point(point): return entry.hint
	return {}

func close() -> void:
	put_down()
	finish_stroke()
	pad_stroke = false
	tip_shown = false
	tip.visible = false
	if is_instance_valid(opening): opening.kill()
	page.modulate.a = 1.0
	visible = false

## A new, empty sheet (new floor or retry).
func clear() -> void:
	finish_stroke()
	for line in lines.values(): line.queue_free()
	lines.clear()
	if map != null: map.pencil_lines.clear()
	drawn_here.clear()
	log.clear()
	log_index.clear()
	confirmed_count = 0
	map_confirmed = 0
	counter = 0

func _ink_input(event: InputEvent) -> void:
	if not editable: return
	# The mouse takes the page back from the pad's pencil.
	if event is InputEventMouseMotion and not pad_stroke and tip_shown:
		tip_shown = false
		tip.visible = false
	if pad_stroke: return
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.pressed and drawing_op.is_empty():
			begin_stroke(event.position, event.button_index == MOUSE_BUTTON_RIGHT)
		elif not event.pressed:
			add_point(event.position)
			finish_stroke()
		accept_event()
	elif event is InputEventMouseMotion and not drawing_op.is_empty():
		add_point(event.position)
		accept_event()

## A new stroke from a point of the page, by whatever hand: pencil or rubber.
func begin_stroke(at: Vector2, erase: bool) -> void:
	if log.size() >= MAX_OPS: return
	drawing_kind = Kind.ERASE if erase else Kind.DRAW
	# Begun on the plan, it is drawn on the building.
	var on_plan: bool = map != null and map.framed_planta >= 0 and Rect2(map.position, map.size).has_point(at)
	if on_plan: drawing_kind = MAP_KIND + map.framed_planta * 2 + (1 if erase else 0)
	counter += 1
	drawing_op = "%d:%d" % [seat, counter]
	drawn_here[drawing_op] = true
	line_for(drawing_op, drawing_kind)
	last_point = Vector2.INF
	add_point(at)

## How far a trigger is pulled, on whichever pad pulls it most.
static func trigger(axis: JoyAxis) -> float:
	var most := 0.0
	for pad in Input.get_connected_joypads(): most = maxf(most, Input.get_joy_axis(pad, axis))
	return most

## The pad's pencil, each frame the sheet is up.
func steer_pencil(delta: float) -> void:
	if not visible or not editable or Input.get_connected_joypads().is_empty():
		if pad_stroke:
			finish_stroke()
			pad_stroke = false
		tip.visible = false
		return
	var stick := Input.get_vector("left", "right", "forward", "backward")
	var drawing := trigger(JOY_AXIS_TRIGGER_RIGHT) > TRIGGER
	var rubbing := not drawing and trigger(JOY_AXIS_TRIGGER_LEFT) > TRIGGER
	if stick.length() > 0.0 or drawing or rubbing: tip_shown = true
	tip.visible = tip_shown
	if not tip_shown: return
	var push := minf(stick.length(), 1.0)
	if push > 0.0:
		var speed := TIP_SPEED * (TIP_DRAWING if pad_stroke else 1.0) * push * (0.25 + 0.75 * push)
		# Out over the column of slips too, to pick up a hint.
		tip_at = (tip_at + stick.normalized() * speed * delta).clamp(Vector2.ZERO, Vector2(PAGE.x + STRIP, PAGE.y))
	tip.position = tip_at
	# The trigger on a hint holds it up, and again puts it down.
	var pulled := drawing and not trigger_was
	trigger_was = drawing
	if is_instance_valid(held):
		if pulled: put_down()
		return
	if pulled and not pad_stroke and drawing_op.is_empty():
		var hint := thumb_at(tip_at)
		if not hint.is_empty():
			hold_up(hint)
			return
	if tip_at.x > PAGE.x:
		if pad_stroke:
			finish_stroke()
			pad_stroke = false
		tip.queue_redraw()
		return
	if pad_stroke:
		add_point(tip_at)
		if not (drawing or rubbing) or drawing_op.is_empty():
			finish_stroke()
			pad_stroke = false
	elif (drawing or rubbing) and drawing_op.is_empty():
		begin_stroke(tip_at, rubbing)
		pad_stroke = not drawing_op.is_empty()
	if tip_rubbing != (rubbing or (pad_stroke and erasing(drawing_kind))):
		tip_rubbing = not tip_rubbing
	tip.queue_redraw()

func add_point(position: Vector2) -> void:
	position = position.clamp(Vector2.ZERO, PAGE)
	if last_point != Vector2.INF and position.distance_to(last_point) < SPACING: return
	last_point = position
	if map_kind(drawing_kind):
		var at: Vector2 = map.to_plan(position - map.position)
		map.add_pencil_point(drawing_op, at)
		unsent.append(at)
	else:
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
	steer_pencil(delta)
	if drawing_op.is_empty(): return
	flush_clock -= delta
	if flush_clock <= 0.0: flush()

## A Line2D for an operation; new ones go after everything drawn so far.
func line_for(op_id: String, kind: int) -> Line2D:
	if lines.has(op_id): return lines[op_id]
	var line := Line2D.new()
	line.width = ERASER if erasing(kind) else PEN
	# Whose stroke it is is in the operation's name, and that is what gives it
	# its colour: a sheet with four hands on it is only readable if they can be
	# told apart.
	line.default_color = PAPER if erasing(kind) else ink_of(int(op_id.get_slice(":", 0)))
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	lines[op_id] = line
	if map_kind(kind):
		map_pencil.add_child(line)
		map.pencil_lines[op_id] = {"line": line, "planta": (kind - MAP_KIND) / 2, "points": PackedVector2Array()}
	else: ink.add_child(line)
	return line

## The host's order for a chunk. A stroke takes its place in the order with its
## first confirmed chunk; its own author already sees the points.
func apply_confirmed(op_id: String, kind: int, points: PackedVector2Array) -> void:
	var line := line_for(op_id, kind)
	var own := drawn_here.has(op_id)
	if not log_index.has(op_id):
		log_index[op_id] = log.size()
		log.append([op_id, kind, PackedVector2Array()])
		# In the host's order, ahead of whatever is still waiting for it: on the
		# page's pencil, or the plan's.
		if map_kind(kind):
			map_pencil.move_child(line, map_confirmed)
			map_confirmed += 1
		else:
			ink.move_child(line, confirmed_count)
			confirmed_count += 1
	var entry: Array = log[log_index[op_id]]
	var merged: PackedVector2Array = entry[2]
	merged.append_array(points)
	entry[2] = merged
	if not own:
		for point in points:
			if map_kind(kind): map.add_pencil_point(op_id, point)
			else: line.add_point(point * PAGE)

func snapshot() -> Array:
	return log.duplicate(true)

func restore(ops: Array) -> void:
	clear()
	for op in ops:
		if op is Array and op.size() == 3:
			var line := line_for(op[0], int(op[1]))
			for point in op[2]:
				if map_kind(int(op[1])): map.add_pencil_point(op[0], point)
				else: line.add_point(point * PAGE)
			log_index[op[0]] = log.size()
			log.append([op[0], int(op[1]), op[2]])
			if map_kind(int(op[1])): map_confirmed += 1
			else: confirmed_count += 1
			# New strokes from this seat must not reuse an earlier number.
			if String(op[0]).begins_with("%d:" % seat): counter = maxi(counter, int(String(op[0]).get_slice(":", 1)))
