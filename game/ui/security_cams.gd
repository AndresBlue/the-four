extends Control
## The security post's cameras, on the screen of whoever sits at its console
## (.claude/specs/cordura_y_edificio.md 3.11, air_objective.gd): the plan of
## planta 3 with each room's light and the eight rooms behind electric locks
## (CAM 1 to CAM 8); one camera at a time live, small and coarse; and what the
## console does: the shown room's lock opened, any room's light given or taken
## (the battery's LIGHTS_MOST at once). Every request goes to the host
## (match_net.use_office); what is drawn is the objective's state. A child of
## the interface's layer: the tape's filter over it, the menus above.
## Keys: 1 to 8 or the arrows a camera, Space the lock, a click on the plan a
## room's light, E or Escape up. A pad: the cross a camera, A the lock, X the
## shown room's light, B up.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## The feed drawn this many times smaller than its box, as an old CCTV's.
const SHRINK := 3
const MARGIN := 24.0
const BACK := Color(0.02, 0.03, 0.03)
const INK := Color(0.82, 0.9, 0.82)
const ROOM := Color(0.15, 0.17, 0.16)
const LANE := Color(0.23, 0.26, 0.24)
const LIT := Color(0.78, 0.6, 0.2)
const SHUT := Color(0.92, 0.22, 0.16)
const OPEN := Color(0.32, 0.9, 0.42)
const POST := Color(0.9, 0.9, 0.86)

var level
var air
var cams: Array = []
var selected := 0
var plan: Control
var box: SubViewportContainer
var feed: SubViewport
var eye: Camera3D
var title: Label
var state: Label
var help: Label
## Room id -> its rect on the plan, made with the plan's size.
var rects := {}
var plan_size := Vector2.ZERO

func setup(owner_level, objective) -> void:
	level = owner_level
	air = objective
	cams = level.manifest.air.get("cams", [])

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := ColorRect.new()
	back.color = BACK
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	plan = Control.new()
	plan.draw.connect(draw_plan)
	plan.gui_input.connect(plan_input)
	add_child(plan)
	box = SubViewportContainer.new()
	box.stretch = true
	box.stretch_shrink = SHRINK
	box.gui_input.connect(feed_input)
	add_child(box)
	feed = SubViewport.new()
	feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(feed)
	eye = Camera3D.new()
	# The player's camera's layers and planes (as revival.gd's watch camera):
	# the rooms are drawn on layers of their own.
	var own: Camera3D = level.player.camera
	eye.cull_mask = own.cull_mask
	eye.near = own.near
	eye.far = own.far
	eye.fov = 78.0
	eye.current = true
	feed.add_child(eye)
	title = label(26)
	state = label(22)
	help = label(16)
	show_cam(0)

func label(size: int) -> Label:
	var words := Label.new()
	words.add_theme_font_size_override("font_size", size)
	words.add_theme_color_override("font_color", INK)
	add_child(words)
	return words

## The plan on the left, the feed on the right, its words over it.
func lay_out() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var feed_w := screen.x * 0.42
	var feed_h := feed_w * 0.75
	plan.position = Vector2(MARGIN, MARGIN)
	plan.size = Vector2(screen.x - feed_w - MARGIN * 3.0, screen.y - MARGIN * 3.0 - 20.0)
	box.position = Vector2(screen.x - feed_w - MARGIN, MARGIN + 40.0)
	box.size = Vector2(feed_w, feed_h)
	title.position = box.position + Vector2(0, -36)
	state.position = box.position + Vector2(0, feed_h + 10)
	help.position = Vector2(MARGIN, screen.y - MARGIN - 20.0)

func _process(_delta: float) -> void:
	lay_out()
	if plan.size != plan_size: rects.clear()
	plan_size = plan.size
	plan.queue_redraw()
	var shown: bool = selected < air.unlocked.size() and bool(air.unlocked[selected])
	title.text = "CAM %d" % (selected + 1)
	state.text = "%s        LUCES %d / %d" % ["ABIERTA" if shown else "CERRADA", air.lights.size(), air.LIGHTS_MOST]
	state.add_theme_color_override("font_color", OPEN if shown else SHUT)
	help.text = "1 A 8  CÁMARA        ESPACIO  ABRIR CIERRE        CLIC EN EL PLANO  LUZ        %s  LEVANTARSE" % String(level.settings.prompt_name("interact"))

## A camera on the feed, and the floor drawn round it.
func show_cam(i: int) -> void:
	if cams.is_empty(): return
	selected = posmod(i, cams.size())
	var cam: Dictionary = cams[selected]
	var from := Vector3(float(cam.point[0]), float(cam.point[1]), float(cam.point[2]))
	var at := Vector3(float(cam.look[0]), float(cam.look[1]), float(cam.look[2]))
	eye.global_transform = Transform3D(Basis.looking_at(at - from, Vector3.UP), from)
	level.cams_eye = from
	if is_instance_valid(level.hotel): level.hotel.update_visibility(from, bool(level.settings.values.shadows))

func ask(action: String, index: int) -> void:
	level.match_net.use_office(air.ID, action, index)

func _input(event: InputEvent) -> void:
	var used := true
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = (event as InputEventKey).physical_keycode
		if key >= KEY_1 and key <= KEY_8: show_cam(key - KEY_1)
		elif key == KEY_RIGHT or key == KEY_D: show_cam(selected + 1)
		elif key == KEY_LEFT or key == KEY_A: show_cam(selected - 1)
		elif key == KEY_SPACE: ask("lock", selected)
		elif key == KEY_ESCAPE or event.is_action_pressed("interact"): ask("stand", 4)
		else: used = false
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_RIGHT: show_cam(selected + 1)
			JOY_BUTTON_DPAD_LEFT: show_cam(selected - 1)
			JOY_BUTTON_A: ask("lock", selected)
			JOY_BUTTON_X: ask("light", int(cams[selected].room))
			JOY_BUTTON_B, JOY_BUTTON_START: ask("stand", 4)
			_: used = false
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		show_cam(selected + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
	else: used = false
	if used: get_viewport().set_input_as_handled()

func plan_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT): return
	var point: Vector2 = event.position
	for id in rects:
		if (rects[id] as Rect2).has_point(point):
			ask("light", int(id))
			return

func feed_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: ask("lock", selected)

## Each room of planta 3 at its place, fitted to the plan's box.
func make_rects() -> void:
	var low := Vector2.INF
	var high := -Vector2.INF
	var kept: Array = []
	for room in level.manifest.rooms:
		if int(room.get("wing", -1)) != 2 or FLOOR.is_void(room): continue
		var middle := Vector2(float(room.px), float(room.pz))
		var half := FLOOR.size_of(room) * 0.5
		low = low.min(middle - half)
		high = high.max(middle + half)
		kept.append(room)
	var span := high - low
	if span.x <= 0.0 or span.y <= 0.0: return
	var scale := minf(plan.size.x / span.x, plan.size.y / span.y)
	var offset := (plan.size - span * scale) * 0.5
	for room in kept:
		var half := FLOOR.size_of(room) * 0.5
		var corner := (Vector2(float(room.px), float(room.pz)) - half - low) * scale + offset
		rects[int(room.id)] = Rect2(corner, half * 2.0 * scale).grow(-0.5)

func draw_plan() -> void:
	if rects.is_empty(): make_rects()
	var rooms: Array = level.manifest.rooms
	var post := int(level.manifest.air.security.room)
	for id in rects:
		var room: Dictionary = rooms[int(id)]
		var fill: Color = LANE if bool(room.get("corridor", false)) else ROOM
		if level.hotel.lit(int(id)): fill = LIT if air.lights.has(air.lit_key(int(id))) else LIT.darkened(0.5)
		if int(id) == post: fill = POST
		plan.draw_rect(rects[id], fill)
	var font := ThemeDB.fallback_font
	for i in cams.size():
		var id := int(cams[i].room)
		if not rects.has(id): continue
		var area: Rect2 = rects[id]
		var ink: Color = OPEN if bool(air.unlocked[i]) else SHUT
		plan.draw_rect(area, ink, false, 2.0)
		if i == selected: plan.draw_rect(area.grow(3.0), INK, false, 2.0)
		plan.draw_string(font, area.get_center() + Vector2(-4, 6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink)
