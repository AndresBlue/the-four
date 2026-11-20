extends Control
## The security post's cameras, on the screen of whoever sits at its console
## (.claude/specs/cordura_y_edificio.md 3.11, air_objective.gd), as a
## surveillance set shows them (the author, 18 November 2026): the shown
## camera over the whole screen, in a tube's curve and lines, and over it its
## name, what the console does with the key of each thing, the cameras in a
## strip, the battery's lights running out and, on Tab, the plan of planta 3
## on a screen of its own, with a button on each camera's room.
## A dark room is seen by the camera's own lamp: a few metres of it, coarse and
## grainy (shaders/cctv_feed.gdshader). Everything on it is a button with its
## key, drawn here: no theme's. Every request goes to the host
## (match_net.use_office); what is drawn is the objective's state. A child of
## the interface's layer: the tape's filter over it, the menus above.
## The shown camera turns a little after the pointer.
## Keys: 1 to 8, A and D, the arrows or the wheel a camera, F the shown room's
## light, Space its lock, Tab the plan (a click on a camera there, that
## camera; on a room, its light),
## E or Escape up. A pad: the cross a camera, X the light, A the lock, Y the
## plan, B up.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const OSD := preload("res://game/ui/osd_style.gd")
const SCREEN := preload("res://game/ui/shaders/cctv_feed.gdshader")
## The feed drawn this many times smaller than the screen, as a CCTV's.
const SHRINK := 2
## The camera's own lamp in a dark room: how far it reaches and how strong.
const NIGHT_REACH := 4.0
const NIGHT_ENERGY := 0.6
## Seconds: each thing coming in, the static between two cameras, the plan
## coming up, a button warming under the pointer and cooling once pressed.
const OPEN_TIME := 0.35
const BURST_TIME := 0.32
const PLAN_TIME := 0.28
const WARM_TIME := 0.12
const HIT_TIME := 0.25
## Letters of a camera's name written a second.
const TYPE_RATE := 45.0
## How far the shown camera turns after the pointer: to each side, up or down.
const PAN := Vector2(0.24, 0.14)
## Laid out for a screen 720 high and scaled to the real one: what is written
## this far from its edges, its corner marks this far.
const EDGE := 56.0
const FRAME := 30.0
const OPEN := Color(0.42, 0.92, 0.5)
## The plan's screen: a VCR's blue, its corridors and its rooms on it.
const BLUE := Color(0.03, 0.045, 0.16)
const LANE := Color(0.5, 0.57, 0.92)
const MASS := Color(0.13, 0.17, 0.4)

var level
var air
var cams: Array = []
var selected := 0
var box: SubViewportContainer
var feed: SubViewport
var eye: Camera3D
var lamp: OmniLight3D
var screen: ShaderMaterial
var hud: Control
var font: Font
## The real screen's height over 720, and what multiplies every ink's alpha.
var u := 1.0
var fade := 1.0
## What can be pressed, as drawn last: {id, rect}. The one under the pointer,
## how warm each is (0 to 1) and how lately pressed.
var zones: Array = []
var hovered := ""
var heat := {}
var hit := {}
## Where the pointer is, for a capture to put it: INF, the mouse's own.
var pointer := Vector2.INF
var aim := 0.0
## The shown camera as it is mounted, and how far it has turned after the pointer.
var mount := Basis.IDENTITY
var pan := Vector2.ZERO
var age := 0.0
var burst := 1.0
var night := 0.0
var flash := 0.0
var typed := 0.0
## A light asked for with the battery spent, and a lock just opened: they blink.
var nope := 0.0
var stamp := 0.0
var was_dark := false
var was_open := false
var plan_open := false
var plan_t := 0.0
## Room id -> its rect on the plan, made for the plan's box.
var rects := {}
var plan_box := Rect2()

func setup(owner_level, objective) -> void:
	level = owner_level
	air = objective
	cams = level.manifest.air.get("cams", [])

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = OSD.font()
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	box = SubViewportContainer.new()
	box.stretch = true
	box.stretch_shrink = SHRINK
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen = ShaderMaterial.new()
	screen.shader = SCREEN
	box.material = screen
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
	# Its own lamp, lit only in a dark room: on this machine alone.
	lamp = OmniLight3D.new()
	lamp.omni_range = NIGHT_REACH
	lamp.light_energy = NIGHT_ENERGY
	lamp.omni_attenuation = 2.0
	lamp.visible = false
	eye.add_child(lamp)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.draw.connect(draw_hud)
	hud.gui_input.connect(hud_input)
	add_child(hud)
	# Its pointer is drawn here, under the tape as the rest.
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	show_cam(0)

func open_at(i: int) -> bool:
	return i >= 0 and i < air.unlocked.size() and bool(air.unlocked[i])

func room_name(room_id: int) -> String:
	var rooms: Array = level.manifest.rooms
	return OFFICE.label(rooms[room_id]).to_upper() if room_id >= 0 and room_id < rooms.size() else ""

## A lit room's name on the battery: its camera's, or its own.
func tag_of(room_id: int) -> String:
	for i in cams.size():
		if int(air.lit_key(int(cams[i].room))) == room_id: return "CAM %02d" % (i + 1)
	return room_name(room_id)

## How much is left of a light the console keeps, 1 to 0 (1 with none kept).
func left_of(room_id: int) -> float:
	var key := int(air.lit_key(room_id))
	if not air.lights.has(key): return 1.0
	return clampf(1.0 - (float(level.session.elapsed) - float(air.lights[key])) / float(air.DECOY_TIME), 0.0, 1.0)

## Whether the console would give or take a room's light now.
func can_light(room_id: int) -> bool:
	var key := int(air.lit_key(room_id))
	return air.lightable(key) and (air.lights.has(key) or air.lights.size() < int(air.LIGHTS_MOST))

func mouse_at() -> Vector2:
	return pointer if pointer != Vector2.INF else hud.get_local_mouse_position()

static func ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)

## How far in a thing is that starts coming `delay` seconds after sitting.
func enter(delay: float) -> float:
	return ease_out((age - delay) / OPEN_TIME)

func _process(delta: float) -> void:
	u = get_viewport().get_visible_rect().size.y / 720.0
	age += delta
	# (hotel_main shows the mouse again whenever play resumes sat here.)
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE: Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	burst = maxf(0.0, burst - delta / BURST_TIME)
	flash = maxf(0.0, flash - delta / 0.3)
	nope = maxf(0.0, nope - delta / 0.6)
	stamp = maxf(0.0, stamp - delta / 0.9)
	typed += delta * TYPE_RATE
	plan_t = move_toward(plan_t, 1.0 if plan_open else 0.0, delta / PLAN_TIME)
	if not cams.is_empty():
		# A light coming on flashes; one going out, a breath of static.
		var dark: bool = not level.hotel.lit(int(cams[selected].room))
		if dark != was_dark:
			if was_dark: flash = 1.0
			else: burst = maxf(burst, 0.5)
			was_dark = dark
		night = move_toward(night, 1.0 if dark else 0.0, delta / 0.25)
		lamp.visible = dark
		if open_at(selected) and not was_open: stamp = 1.0
		was_open = open_at(selected)
	screen.set_shader_parameter("night", night)
	screen.set_shader_parameter("burst", burst)
	screen.set_shader_parameter("flash", flash)
	screen.set_shader_parameter("dim", ease_out(plan_t))
	# Under the plan's own screen nothing of the picture is seen.
	box.visible = plan_t < 1.0
	var point := mouse_at()
	hovered = ""
	for zone in zones:
		if (zone.rect as Rect2).has_point(point): hovered = String(zone.id)
	aim = move_toward(aim, 1.0 if hovered != "" else 0.0, delta / WARM_TIME)
	# The camera turns a little after the pointer; still under the plan and with a pad.
	var want := Vector2.ZERO
	if not plan_open and pointer == Vector2.INF and hud.size.x > 0.0 and not (bool(level.settings.using_pad) and level.settings.pad_present()):
		want = ((point / hud.size - Vector2(0.5, 0.5)) * 2.0).clamp(-Vector2.ONE, Vector2.ONE)
	pan = pan.lerp(want, 1.0 - exp(-delta * 5.0))
	eye.global_basis = Basis(Vector3.UP, -pan.x * PAN.x) * mount * Basis(Vector3.RIGHT, -pan.y * PAN.y)
	if hovered != "" and not heat.has(hovered): heat[hovered] = 0.0
	for id in heat.keys():
		heat[id] = move_toward(float(heat[id]), 1.0 if id == hovered else 0.0, delta / WARM_TIME)
		if float(heat[id]) <= 0.0 and id != hovered: heat.erase(id)
	for id in hit.keys():
		hit[id] = float(hit[id]) - delta / HIT_TIME
		if float(hit[id]) <= 0.0: hit.erase(id)
	hud.queue_redraw()

## A camera on the feed through a burst of static, and the floor drawn round it.
func show_cam(i: int) -> void:
	if cams.is_empty(): return
	selected = posmod(i, cams.size())
	var cam: Dictionary = cams[selected]
	var from := Vector3(float(cam.point[0]), float(cam.point[1]), float(cam.point[2]))
	var at := Vector3(float(cam.look[0]), float(cam.look[1]), float(cam.look[2]))
	mount = Basis.looking_at(at - from, Vector3.UP)
	eye.global_transform = Transform3D(mount, from)
	level.cams_eye = from
	if is_instance_valid(level.hotel):
		# One new reflection probe at most, as in a round: uncapped, a switch
		# of camera made up to 24 in one frame.
		level.hotel.probes_at_once = 1
		level.hotel.update_visibility(from, bool(level.settings.values.shadows))
		level.hotel.probes_at_once = 0
		was_dark = not level.hotel.lit(int(cam.room))
	night = 1.0 if was_dark else 0.0
	was_open = open_at(selected)
	burst = 1.0
	typed = 0.0
	say("cam_switch.wav", -10.0)

## The console's own sounds (tools/audio/prepare_office_sfx.py), heard here alone.
func say(file: String, gain: float) -> void:
	air.sound_at(file, level.world_audio.listener_position(), gain)

func ask(action: String, index: int) -> void:
	level.match_net.use_office(air.ID, action, index)

## What a button does, by its id: pressed, clicked or by its key.
func act(id: String) -> void:
	hit[id] = 1.0
	if not (id.begins_with("cam:") or id == "prev" or id == "next"): say("cam_click.wav", -12.0)
	if id.begins_with("cam:"):
		# A camera chosen puts the plan away.
		show_cam(int(id.trim_prefix("cam:")))
		plan_open = false
	elif id.begins_with("room:"): light(int(id.trim_prefix("room:")))
	elif id == "prev": show_cam(selected - 1)
	elif id == "next": show_cam(selected + 1)
	elif id == "light" and not cams.is_empty(): light(int(cams[selected].room))
	elif id == "lock": ask("lock", selected)
	elif id == "plan":
		plan_open = not plan_open
		typed = 0.0
	elif id == "stand": ask("stand", 4)

func light(room_id: int) -> void:
	if can_light(room_id): ask("light", room_id)
	else: nope = 1.0

func _input(event: InputEvent) -> void:
	var id := ""
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = (event as InputEventKey).physical_keycode
		if key >= KEY_1 and key <= KEY_8: id = "cam:%d" % (key - KEY_1)
		elif key == KEY_RIGHT or key == KEY_D: id = "next"
		elif key == KEY_LEFT or key == KEY_A: id = "prev"
		elif key == KEY_ESCAPE: id = "plan" if plan_open else "stand"
		elif event.is_action_pressed("interact"): id = "stand"
		elif key == KEY_F: id = "light"
		elif key == KEY_SPACE: id = "lock"
		elif key == KEY_TAB: id = "plan"
	elif event is InputEventJoypadButton and event.pressed:
		match (event as InputEventJoypadButton).button_index:
			JOY_BUTTON_DPAD_RIGHT: id = "next"
			JOY_BUTTON_DPAD_LEFT: id = "prev"
			JOY_BUTTON_A: id = "lock"
			JOY_BUTTON_X: id = "light"
			JOY_BUTTON_Y: id = "plan"
			JOY_BUTTON_B: id = "plan" if plan_open else "stand"
			JOY_BUTTON_START: id = "stand"
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		id = "next" if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else "prev"
	if id == "": return
	act(id)
	get_viewport().set_input_as_handled()

func hud_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and hovered != "": act(hovered)

# --- What is drawn ---------------------------------------------------------

func c(color: Color) -> Color:
	return Color(color.r, color.g, color.b, color.a * fade)

func wide(words: String, text_size: float) -> float:
	return font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(text_size * u))).x

## Words with the OSD's hard shadow, `at` their baseline's start.
func ink(at: Vector2, words: String, text_size: float, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, shade := true) -> void:
	var px := int(round(text_size * u))
	if shade: hud.draw_string(font, at + Vector2(2, 2) * u, words, align, width, px, c(Color(0, 0, 0, 0.85 * color.a)))
	hud.draw_string(font, at, words, align, width, px, c(color))

## The baseline that puts words of a size in the middle of a box's height.
func line_of(area: Rect2, text_size: float) -> float:
	var px := int(round(text_size * u))
	return area.position.y + (area.size.y + font.get_ascent(px) - font.get_descent(px)) * 0.5

func centred(area: Rect2, words: String, text_size: float, color: Color, shade := true) -> void:
	ink(Vector2(area.position.x, line_of(area, text_size)), words, text_size, color, HORIZONTAL_ALIGNMENT_CENTER, area.size.x, shade)

## A corner mark: two strokes from `at`, toward `way`.
func corner(at: Vector2, way: Vector2, length: float, color: Color) -> void:
	var w := 3.0 * u
	hud.draw_rect(Rect2(at, Vector2(way.x * length, way.y * w)).abs(), c(color))
	hud.draw_rect(Rect2(at, Vector2(way.x * w, way.y * length)).abs(), c(color))

## A key's cap: outlined, filling with its ink as it warms.
func cap(area: Rect2, key: String, tone: Color, fill: float) -> void:
	if fill > 0.0: hud.draw_rect(area, c(Color(tone, tone.a * fill)))
	hud.draw_rect(area, c(tone), false, 2.0 * u)
	centred(area, key, 17.0, tone.lerp(Color(0, 0, 0, tone.a), fill), fill < 0.5)

func draw_hud() -> void:
	zones.clear()
	if cams.is_empty(): return
	var view: Vector2 = hud.size
	var pad: bool = bool(level.settings.using_pad) and level.settings.pad_present()
	if plan_t > 0.0: draw_screen(view)
	fade = enter(0.0)
	for way: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		corner(Vector2(FRAME * u if way.x > 0.0 else view.x - FRAME * u, FRAME * u if way.y > 0.0 else view.y - FRAME * u), way, 26.0 * u, Color(OSD.INK, 0.6))
	draw_title()
	draw_actions(view, pad)
	draw_strip(view, pad)
	draw_battery(view)
	if plan_t > 0.0: draw_plan(view)
	if not pad: draw_pointer()

## The plan's own screen over the picture: a VCR's blue, ruled faintly, a
## paler band rolling down it.
func draw_screen(view: Vector2) -> void:
	var t := ease_out(plan_t)
	hud.draw_rect(Rect2(Vector2.ZERO, view), Color(BLUE, t))
	var step := 40.0 * u
	var x := fmod(view.x * 0.5, step)
	while x < view.x:
		hud.draw_rect(Rect2(x, 0.0, 1.0, view.y), Color(LANE, 0.05 * t))
		x += step
	var y := fmod(view.y * 0.5, step)
	while y < view.y:
		hud.draw_rect(Rect2(0.0, y, view.x, 1.0), Color(LANE, 0.05 * t))
		y += step
	var band := 120.0 * u
	hud.draw_rect(Rect2(0.0, fmod(age * 90.0 * u, view.y + band) - band, view.x, band), Color(LANE, 0.035 * t))

## Top left: the camera's number, its room's name written out, and its lock;
## over the plan, the planta's name and how many locks are open.
func draw_title() -> void:
	fade = enter(0.05)
	var x := EDGE * u - (1.0 - fade) * 40.0 * u
	var top := EDGE * u
	var on_plan := plan_t > 0.5
	ink(Vector2(x, top + 18.0 * u), "PLANO" if on_plan else "CAM %02d" % (selected + 1), 20.0, OSD.AMBER)
	var words := String(OFFICE.PLANTA_NAMES[2]) if on_plan else room_name(int(cams[selected].room))
	var count := mini(words.length(), int(typed))
	var writing := count < words.length() and fmod(age, 0.12) < 0.06
	ink(Vector2(x, top + 62.0 * u), words.left(count) + ("_" if writing else ""), 44.0, OSD.INK)
	if on_plan:
		var opened := 0
		for i in cams.size(): opened += int(open_at(i))
		ink(Vector2(x, top + 92.0 * u), "CIERRES ABIERTOS  %d / %d" % [opened, cams.size()], 18.0, OSD.SOFT)
		return
	if stamp > 0.0 and fmod(stamp * 6.0, 2.0) >= 1.0: return
	var tone: Color = OPEN if open_at(selected) else OSD.ALERT
	hud.draw_rect(Rect2(x, top + 80.0 * u, 12.0 * u, 12.0 * u), c(tone))
	ink(Vector2(x + 20.0 * u, top + 92.0 * u), "CIERRE ABIERTO" if open_at(selected) else "CIERRE CERRADO", 18.0, tone)

## Top right: what the console does, each with its key.
func draw_actions(view: Vector2, pad: bool) -> void:
	var room := int(cams[selected].room)
	var kept: bool = air.lights.has(int(air.lit_key(room)))
	var rows: Array = [
		["light", "APAGAR LUZ" if kept else "ENCENDER LUZ", "X" if pad else "F", OSD.AMBER if kept else OSD.INK, can_light(room)],
		["lock", "ABRIR CIERRE", "A" if pad else "ESPACIO", OSD.INK, not open_at(selected)],
		["plan", "CERRAR PLANO" if plan_open else "PLANO", "Y" if pad else "TAB", OSD.INK, true],
		["stand", "LEVANTARSE", "B" if pad else String(level.settings.prompt_name("interact")), OSD.INK, true],
	]
	# Over the plan, only what the plan needs.
	if plan_t > 0.5: rows = rows.slice(2)
	for i in rows.size():
		fade = enter(0.1 + i * 0.06)
		row(view, String(rows[i][0]), EDGE * u + i * 42.0 * u, String(rows[i][1]), String(rows[i][2]), rows[i][3], bool(rows[i][4]))

## One of them: its words and its key's cap, its right end at the edge. Under
## the pointer a wash grows out of its cap and a tick stands at its far end.
func row(view: Vector2, id: String, top: float, words: String, key: String, color: Color, enabled: bool) -> void:
	var high := 34.0 * u
	var cap_w := maxf(36.0 * u, wide(key, 17.0) + 18.0 * u)
	var words_w := wide(words, 22.0)
	var right := view.x - EDGE * u + (1.0 - fade) * 60.0 * u
	var area := Rect2(right - cap_w - words_w - 34.0 * u, top, cap_w + words_w + 34.0 * u, high)
	var warm := 0.0
	if enabled:
		zones.append({"id": id, "rect": area})
		warm = ease_out(float(heat.get(id, 0.0)))
	var tone := color if enabled else Color(color, 0.28)
	if warm > 0.0:
		hud.draw_rect(Rect2(area.end.x - area.size.x * warm, top, area.size.x * warm, high), c(Color(tone, 0.14)))
		hud.draw_rect(Rect2(area.position.x - 6.0 * u, top + high * (1.0 - warm) * 0.5, 3.0 * u, high * warm), c(tone))
	var cap_area := Rect2(right - cap_w, top + 3.0 * u, cap_w, high - 6.0 * u)
	cap(cap_area, key, tone, maxf(warm, float(hit.get(id, 0.0))) if enabled else 0.0)
	ink(Vector2(cap_area.position.x - 14.0 * u - words_w - 4.0 * u * warm, line_of(area, 22.0)), words, 22.0, tone)

## Bottom left: the cameras, each with its number as its key, its lock a pip
## in its corner and its room's light a bar along its foot; the shown one up.
func draw_strip(view: Vector2, pad: bool) -> void:
	fade = enter(0.2)
	var cell := 44.0 * u
	var gap := 6.0 * u
	var top := view.y - EDGE * u - cell + (1.0 - fade) * 40.0 * u
	var x := EDGE * u
	var side := Vector2(30.0 * u, cell)
	arrow("prev", Rect2(Vector2(x, top), side), "<" if pad else "A")
	x += side.x + gap
	for i in cams.size():
		var id := "cam:%d" % i
		var on := i == selected
		var area := Rect2(x, top - (5.0 * u if on else 0.0), cell, cell)
		zones.append({"id": id, "rect": area})
		var warm := ease_out(float(heat.get(id, 0.0)))
		hud.draw_rect(area, c(Color(OSD.INK, 0.92) if on else Color(0, 0, 0, 0.45 + 0.25 * warm)))
		hud.draw_rect(area, c(Color(OSD.INK, 0.35 + 0.65 * warm)), false, 2.0 * u)
		centred(area, str(i + 1), 22.0, Color.BLACK if on else Color(OSD.INK, 0.7 + 0.3 * warm), not on)
		hud.draw_rect(Rect2(area.end.x - 12.0 * u, area.position.y + 6.0 * u, 6.0 * u, 6.0 * u), c(OPEN if open_at(i) else OSD.ALERT))
		var room := int(cams[i].room)
		if level.hotel.lit(room): hud.draw_rect(Rect2(area.position.x + 6.0 * u, area.end.y - 9.0 * u, (cell - 12.0 * u) * left_of(room), 3.0 * u), c(OSD.AMBER.darkened(0.25) if on else OSD.AMBER))
		x += cell + gap
	arrow("next", Rect2(Vector2(x, top), side), ">" if pad else "D")

func arrow(id: String, area: Rect2, key: String) -> void:
	zones.append({"id": id, "rect": area})
	cap(area, key, Color(OSD.INK, 0.8), maxf(ease_out(float(heat.get(id, 0.0))), float(hit.get(id, 0.0))))

## Bottom right: the battery's lights, a bar each running out, the oldest on top.
func draw_battery(view: Vector2) -> void:
	fade = enter(0.3)
	var slot := Vector2(200.0 * u, 12.0 * u)
	var gap := 8.0 * u
	var most := int(air.LIGHTS_MOST)
	var left := view.x - EDGE * u - slot.x + (1.0 - fade) * 60.0 * u
	var top := view.y - EDGE * u - most * slot.y - (most - 1) * gap
	var kept: Array = air.lights.keys()
	kept.sort_custom(func(a, b): return float(air.lights[a]) < float(air.lights[b]))
	var alarm := nope > 0.0 and fmod(nope * 8.0, 2.0) < 1.0
	ink(Vector2(left, top - 12.0 * u), "LUCES", 18.0, OSD.ALERT if alarm else OSD.SOFT)
	ink(Vector2(left, top - 12.0 * u), "%d / %d" % [kept.size(), most], 18.0, OSD.ALERT if alarm else OSD.INK, HORIZONTAL_ALIGNMENT_RIGHT, slot.x)
	for s in most:
		var area := Rect2(Vector2(left, top + s * (slot.y + gap)), slot)
		if s >= kept.size():
			hud.draw_rect(area, c(OSD.FAINT), false, 2.0 * u)
			continue
		var share := left_of(int(kept[s]))
		var low: bool = share * float(air.DECOY_TIME) < 10.0 and fmod(age, 0.5) < 0.25
		hud.draw_rect(Rect2(area.position, Vector2(slot.x * share, slot.y)), c(Color(OSD.AMBER, 0.35 if low else 0.95)))
		hud.draw_rect(area, c(OSD.AMBER), false, 2.0 * u)
		var tag := tag_of(int(kept[s]))
		ink(Vector2(left - 12.0 * u - wide(tag, 14.0), line_of(area, 14.0)), tag, 14.0, OSD.SOFT)

## Each room of planta 3 at its place, fitted to the plan's box.
func make_rects() -> void:
	rects.clear()
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
	var scale_now := minf(plan_box.size.x / span.x, plan_box.size.y / span.y)
	var offset := plan_box.position + (plan_box.size - span * scale_now) * 0.5
	for room in kept:
		var half := FLOOR.size_of(room) * 0.5
		rects[int(room.id)] = Rect2((Vector2(float(room.px), float(room.pz)) - half - low) * scale_now + offset, half * 2.0 * scale_now).grow(-0.5)

## The plan (Tab), on its own screen as a surveillance set's: the corridors
## bright, the rooms dim blocks between them with their name where it fits, a
## lit room amber and darker as its light runs out, the post in white, and a
## button on each camera's room. They come in from the left behind a line. A
## click on a camera, that camera; on any room, its light.
func draw_plan(view: Vector2) -> void:
	var t := ease_out(plan_t)
	var area := Rect2(EDGE * u, 165.0 * u, view.x - EDGE * 2.0 * u, view.y - 325.0 * u)
	if area != plan_box:
		plan_box = area
		make_rects()
	var rooms: Array = level.manifest.rooms
	var post := int(level.manifest.air.security.room)
	var cam_rooms := {}
	for i in cams.size(): cam_rooms[int(cams[i].room)] = i
	var seen := {}
	var over := -1
	for id in rects:
		var spot: Rect2 = rects[id]
		seen[id] = clampf(t * 1.8 - (spot.get_center().x - area.position.x) / area.size.x * 0.8, 0.0, 1.0)
		fade = float(seen[id])
		if fade <= 0.0: continue
		var room: Dictionary = rooms[int(id)]
		var lane := bool(room.get("corridor", false))
		var fill: Color = LANE if lane else MASS
		if level.hotel.lit(int(id)): fill = OSD.AMBER.darkened(0.55 - 0.45 * left_of(int(id)) if air.lights.has(int(air.lit_key(int(id)))) else 0.6)
		if int(id) == post: fill = OSD.INK
		# A corridor runs on into the next; rooms stand a hair apart.
		var block := spot.grow(0.5) if lane else spot.grow(-1.0 * u)
		hud.draw_rect(block, c(fill))
		if not lane and not cam_rooms.has(int(id)) and int(id) != post:
			var words := room_name(int(id))
			if wide(words, 10.0) + 8.0 * u < block.size.x and block.size.y > 16.0 * u: centred(block, words, 10.0, Color(LANE, 0.8), false)
		if plan_open and air.lightable(int(air.lit_key(int(id)))):
			zones.append({"id": "room:%d" % int(id), "rect": spot})
			if hovered == "room:%d" % int(id): over = int(id)
	# Whoever sits at the post.
	if rects.has(post):
		fade = float(seen.get(post, 0.0))
		centred(rects[post], "TÚ", 16.0, Color.BLACK, false)
	var aimed := draw_cam_buttons(area, seen)
	fade = 1.0
	if plan_open and plan_t < 1.0:
		hud.draw_rect(Rect2(area.position.x + area.size.x * t, area.position.y, 2.0 * u, area.size.y), Color(OSD.INK, 0.6 * (1.0 - t)))
	# Under the pointer: what it is and what a click does.
	if aimed >= 0:
		card(view, room_name(int(cams[aimed].room)), "VER CÁMARA", OSD.INK, OSD.INK)
	elif over >= 0:
		hud.draw_rect(rects[over], OSD.INK, false, 2.0 * u)
		var kept: bool = air.lights.has(int(air.lit_key(over)))
		card(view, room_name(over), "APAGAR LUZ" if kept else ("ENCENDER LUZ" if can_light(over) else "SIN BATERÍA"), OSD.AMBER if can_light(over) else OSD.ALERT, OSD.AMBER if kept else OSD.INK)

## The cameras on the plan: a button on each one's room, with its lock a pip
## and its light a bar as in the strip, pushed apart where two would overlap
## (a hair's line back to its room then). The camera under the pointer, or -1.
func draw_cam_buttons(area: Rect2, seen: Dictionary) -> int:
	var button := Vector2(46.0, 40.0) * u
	var spots: Array = []
	for i in cams.size():
		var id := int(cams[i].room)
		spots.append((rects[id] as Rect2).get_center() if rects.has(id) else Vector2.INF)
	for round_n in 12:
		for a in spots.size():
			for b in range(a + 1, spots.size()):
				if spots[a] == Vector2.INF or spots[b] == Vector2.INF: continue
				var gap: Vector2 = spots[b] - spots[a]
				if absf(gap.x) >= button.x + 4.0 * u or absf(gap.y) >= button.y + 4.0 * u: continue
				var push := (button.x + 4.0 * u - absf(gap.x)) * 0.5 * (1.0 if gap.x >= 0.0 else -1.0)
				spots[a] = Vector2(float(spots[a].x) - push, float(spots[a].y))
				spots[b] = Vector2(float(spots[b].x) + push, float(spots[b].y))
	var aimed := -1
	for i in cams.size():
		if spots[i] == Vector2.INF: continue
		var id := int(cams[i].room)
		fade = float(seen.get(id, 0.0))
		if fade <= 0.0: continue
		var home: Vector2 = (rects[id] as Rect2).get_center()
		var at: Vector2 = (spots[i] as Vector2).clamp(area.position + button * 0.5, area.end - button * 0.5)
		var key := "cam:%d" % i
		var face := Rect2(at - button * 0.5 - Vector2(0, (1.0 - fade) * 8.0 * u), button)
		if plan_open:
			zones.append({"id": key, "rect": face})
			if hovered == key and face.has_point(mouse_at()): aimed = i
		var warm := ease_out(float(heat.get(key, 0.0)))
		var on := i == selected
		if at.distance_to(home) > 2.0: hud.draw_line(home, at, c(Color(OSD.INK, 0.5)), 1.0)
		hud.draw_rect(face, c(Color(OSD.INK, 0.95) if on else Color(0.02, 0.03, 0.1, 0.92).lerp(Color(LANE, 0.9), 0.35 * warm)))
		hud.draw_rect(face, c(Color(OSD.INK, 0.55 + 0.45 * warm)), false, 2.0 * u)
		var tone := Color.BLACK if on else Color(OSD.INK, 0.75 + 0.25 * warm)
		centred(Rect2(face.position + Vector2(0, 3.0 * u), Vector2(button.x, 13.0 * u)), "CAM", 11.0, tone, false)
		centred(Rect2(face.position + Vector2(0, 14.0 * u), Vector2(button.x, 24.0 * u)), "%02d" % (i + 1), 20.0, tone, not on)
		hud.draw_rect(Rect2(face.end.x - 11.0 * u, face.position.y + 5.0 * u, 6.0 * u, 6.0 * u), c(OPEN if open_at(i) else OSD.ALERT))
		if level.hotel.lit(id): hud.draw_rect(Rect2(face.position.x + 5.0 * u, face.end.y - 7.0 * u, (button.x - 10.0 * u) * left_of(id), 3.0 * u), c(OSD.AMBER.darkened(0.25) if on else OSD.AMBER))
		if not on: continue
		var grown := face.grow((4.0 + 2.0 * sin(age * 5.0)) * u)
		for way: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			corner(Vector2(grown.position.x if way.x > 0.0 else grown.end.x, grown.position.y if way.y > 0.0 else grown.end.y), way, 8.0 * u, OSD.INK)
	return aimed

## A card by the pointer: a name and what a click does, a bar down its side.
func card(view: Vector2, title: String, does: String, tone: Color, bar: Color) -> void:
	var size_now := Vector2(maxf(wide(title, 18.0), wide(does, 15.0)) + 20.0 * u, 52.0 * u)
	var at := mouse_at() + Vector2(18.0, -size_now.y - 6.0) * u
	at = at.clamp(Vector2(EDGE * u, EDGE * u), view - size_now - Vector2(EDGE * u, EDGE * u))
	hud.draw_rect(Rect2(at, size_now), Color(0, 0, 0, 0.85))
	hud.draw_rect(Rect2(at, Vector2(3.0 * u, size_now.y)), bar)
	ink(at + Vector2(12.0, 21.0) * u, title, 18.0, OSD.INK)
	ink(at + Vector2(12.0, 42.0) * u, does, 15.0, tone)

## The pointer: four ticks round a dot, opening and turning amber over a button.
func draw_pointer() -> void:
	fade = 1.0
	var at := mouse_at()
	var tone := OSD.INK.lerp(OSD.AMBER, aim)
	var from := (5.0 + 3.0 * aim) * u
	for way: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		hud.draw_line(at + way * (from - u), at + way * (from + 8.0 * u), Color(0, 0, 0, 0.8), 4.0 * u)
		hud.draw_line(at + way * from, at + way * (from + 7.0 * u), tone, 2.0 * u)
	hud.draw_rect(Rect2(at - Vector2(1.5, 1.5) * u, Vector2(3, 3) * u), tone)
