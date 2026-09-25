extends Node3D
## The observer: a camera that belongs to nobody, everything the floor is
## doing written down the side of the screen, and marks drawn over the world
## (observer_gizmos.gd). It is the game itself with `--observer`, so the hotel,
## the creature and the replication are the real ones; what is missing is a
## body. Two uses:
##
## - Watching a match from outside: it connects like a guest and takes no seat
##   (net_session.join_observer), so a hunter, three survivors and somebody
##   watching all see the same floor.
## - Watching a floor on its own, with nobody connected: it builds one, the
##   creature walks it, and R builds another. Time can be slowed or stopped
##   here, which online would only desync.
## - Comparing floors by eye: R and Shift+R go from one floor to another and
##   back with the view as it was (the plan, the planta), and the panel names
##   what the generator made of the planta on screen.
##
## Keys
##   movimiento   vuela (correr: más rápido; saltar/agacharse: subir y bajar)
##   TAB / F      seguir al siguiente cuerpo (la criatura incluida) / soltar
##   M            el piso desde arriba
##   1..6         capas de dibujo: camino, rastros, ruidos, puertas, objetivos, vista
##   L            su propia luz (el hotel está a oscuras y esto no es jugar)
##   C            quitar los techos, para mirar el piso desde arriba
##   V            su lectura acústica: lo que oye la criatura, desde su sitio
##   H            esconder los paneles
##   R            otro piso, con otra semilla (solo sin partida)
##   Mayús+R      el piso de antes; pulsada otra vez, el que se dejó
##   P  [  ]      parar el tiempo, más lento, más rápido (solo sin partida)
##   ESC          devuelve el ratón; pulsada otra vez, cierra la herramienta
##   F5           guarda lo que se ve en user://observer_<hora>.json
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GIZMOS := preload("res://game/app/observer_gizmos.gd")
const ECHO := preload("res://game/enemies/locust/echo_view.gd")

## What the creature's own view asks of whoever drives it (echo_view.setup):
## where its eyes are, what it has heard, and a camera to draw into. Driven by
## a player that is locust_player; watched from outside, it is this.
class Ears extends Node:
	const EYE := Vector3(0.0, 2.35, 0.0)
	## Where the hunter's own camera sits: over its shoulder, an arm behind.
	## Standing in its head instead, its body filled the depth buffer and the
	## reading's own soft depth test hid every grain behind it.
	const ARM := 2.8
	const SHOULDER := 1.0
	var creature
	var level
	var camera: Camera3D
	var heard: Array = []
	## The guides the reading draws (echo_view.bloom_guides), as the hunter's
	## locust_player gives them: without them every click was an error. There
	## is no Q from here, so no trace.
	func lit_screens() -> Array:
		var out: Array = []
		for index in level.lit_televisions():
			var set = level.televisions[index]
			if is_instance_valid(set): out.append([set.screen_point(), set.global_basis.x * (set.SCREEN_SIZE.x * 0.5), set.global_basis.y * (set.SCREEN_SIZE.y * 0.5)])
		return out
	func lift_route() -> PackedVector3Array:
		var car: int = level.lifts.creature_car(level.session.stage)
		if car < 0 or car >= level.hotel.lifts.size(): return PackedVector3Array()
		return FLOOR.navigation_path(creature.get_world_3d().navigation_map, creature.global_position, level.hotel.lifts[car])
	func lift_away_now() -> bool:
		var car: int = level.lifts.creature_car(level.session.stage)
		return car >= 0 and not level.lifts.creature_may_ride(car)
	func trace_route() -> PackedVector3Array:
		return PackedVector3Array()
## How fast it flies, and what the wheel can take it to. A hotel is a hundred
## metres across and this is not a walk.
const SPEED := 22.0
const SPEED_RANGE := Vector2(2.0, 200.0)
## What running multiplies it by.
const QUICK := 4.0
## How far above the floor the map view sits.
const MAP_HEIGHT := 150.0
## How many things that happened are kept on screen.
const LOG_KEPT := 16
## A planta's plan and outline as the generator names them (map_generator
## DECKS and SHAPES), in the words of the design document.
const PLAN_NAMES := {"spine": "espina", "twin": "doble", "ring": "anillo", "comb": "peine", "blocks": "manzanas", "arms": "brazos", "warren": "madriguera", "rot": "podrido"}
const SHAPE_NAMES := {"rect": "rectángulo", "notch": "con muesca", "ell": "en L", "you": "en U", "court": "con patio", "aitch": "en H"}
var level
var camera: Camera3D
var panel: Label
var metrics: Label
var layer: CanvasLayer
var gizmos
var speed := SPEED
var pitch := -0.15
## Whose shoulder it is riding, or null for the free camera.
var following: Node3D
var map_view := false
## How far the plan on screen reaches from its middle (frame_map()).
var map_span := 40.0
## The planta being looked at: the only one drawn (hotel_geometry
## update_visibility), chosen with RePág/AvPág, or the one the body followed
## is on. Never from the camera's height: flying up over a planta keeps it.
## A planta change takes the camera down (or up) with it.
var planta := 0
## Its own light. Without it there is nothing to see: the hotel is meant to be
## walked with a torch, and this camera has none.
var lit := true
## Ceilings hidden, so the floor can be looked at from above. The mesh batches
## carry their material in their name (hotel_geometry.flush), which is what
## makes this possible without touching the hotel.
var roofless := false
## The creature's acoustic reading, drawn from where it stands: what the hunter
## sees. Built the first time it is asked for.
var echo
var ears: Ears
var echoing := false
var lamp: DirectionalLight3D
var ambient_before := -1.0
var ambient_colour_before := Color.BLACK
var fog_before := true
var clock := 0.0
var events: Array = []
## The last value of everything the log watches, to tell a change.
var before := {}
## The floor on screen, to tell when another one is up (R, a match beginning);
## its seed and the seed of the one before it, which Shift+R goes back to; and
## what each of its plantas is, worked out once a floor.
var floor_seen := {}
var seed_shown := -1
var seed_before := -1
var planta_notes := PackedStringArray()

func setup(owner_level) -> void:
	name = "Observer"
	level = owner_level
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.name = "ObserverCamera"
	camera.far = 400.0
	camera.fov = 75.0
	add_child(camera)
	gizmos = GIZMOS.new()
	gizmos.setup(level)
	add_child(gizmos)
	layer = CanvasLayer.new()
	layer.name = "ObserverPanel"
	layer.layer = 7
	add_child(layer)
	panel = write_panel(Vector2(18, 18), Vector2(600, 700))
	metrics = write_panel(Vector2(-560, 18), Vector2(540, 460), Control.PRESET_TOP_RIGHT)
	lamp = DirectionalLight3D.new()
	lamp.name = "ObserverLamp"
	lamp.light_energy = 1.1
	lamp.shadow_enabled = false
	lamp.rotation_degrees = Vector3(-55, 35, 0)
	add_child(lamp)
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func write_panel(at: Vector2, size: Vector2, preset := Control.PRESET_TOP_LEFT) -> Label:
	var holder := Control.new()
	holder.set_anchors_preset(preset)
	holder.position = at
	holder.size = size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	var back := ColorRect.new()
	back.color = Color(0, 0, 0, 0.55)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(back)
	var words := Label.new()
	words.position = Vector2(12, 8)
	words.add_theme_font_size_override("font_size", 15)
	words.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(words)
	return words

func alone() -> bool:
	return not level.match_net.in_match()

## The creature, while it is in the floor. One going with its floor (R, the
## end of a match) is still there out of the tree until the frame ends, and
## asking it where it stood then only raised errors.
func live_locust():
	return level.locust if is_instance_valid(level.locust) and level.locust.is_inside_tree() else null

## Another floor to look at, the view left as it is (arrived()).
func rebuild(seed_value: int) -> void:
	if level.session.state == level.session.State.LOADING: return
	note("construyendo el piso %d" % seed_value)
	level.observer_rebuild(seed_value)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not map_view:
		rotate_y(-event.relative.x * 0.0022)
		pitch = clampf(pitch - event.relative.y * 0.0022, -1.5, 1.5)
		camera.rotation.x = pitch
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: speed = clampf(speed * 1.25, SPEED_RANGE.x, SPEED_RANGE.y)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: speed = clampf(speed / 1.25, SPEED_RANGE.x, SPEED_RANGE.y)
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = (event as InputEventKey).physical_keycode
	var layers := ["path", "trails", "noises", "doors", "errand", "sight"]
	if key >= KEY_1 and key <= KEY_6:
		var name: String = layers[key - KEY_1]
		gizmos.shown[name] = not gizmos.shown[name]
		note("capa %s %s" % [name, "sí" if gizmos.shown[name] else "no"])
		return
	match key:
		KEY_PAGEUP: change_planta(-1)
		KEY_PAGEDOWN: change_planta(1)
		KEY_TAB: follow_next()
		KEY_F: following = null
		KEY_M: toggle_map()
		KEY_H: layer.visible = not layer.visible
		KEY_L:
			lit = not lit
			note("luz %s" % ("sí" if lit else "no"))
		KEY_C:
			roofless = not roofless
			apply_roof()
			note("techos %s" % ("no" if roofless else "sí"))
		KEY_V: toggle_echo()
		KEY_R:
			if level.bot_match or is_instance_valid(level.bot_watch): level.skip_bot_floor()
			elif not alone(): note("R: solo sin partida")
			elif not (event as InputEventKey).shift_pressed: rebuild(randi_range(0, 2147483647))
			elif seed_before >= 0: rebuild(seed_before)
			else: note("no hay piso anterior")
		KEY_P:
			if alone(): set_time(0.0 if Engine.time_scale > 0.0 else 1.0)
		KEY_BRACKETLEFT:
			if alone(): set_time(maxf(0.1, Engine.time_scale * 0.5))
		KEY_BRACKETRIGHT:
			if alone(): set_time(minf(4.0, maxf(Engine.time_scale, 0.1) * 2.0))
		KEY_F5: snapshot()
		KEY_ESCAPE: step_out()

## Up or down a planta: the plan is redrawn over it, and the free camera is
## taken down (or up) with it, at the same height over its floor.
func change_planta(step: int) -> void:
	var next := clampi(planta + step, 0, FLOOR.PLANTAS - 1)
	if next == planta: return
	following = null
	global_position.y += FLOOR.planta_y(next) - FLOOR.planta_y(planta)
	planta = next
	if map_view: frame_map()
	note("planta %d" % (planta + 1))

## Escape: the mouse back, so the window can be left; and again, out. A tool
## that swallowed Escape was a tool you had to kill from the task bar.
func step_out() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		note("ratón libre · ESC otra vez para cerrar")
		return
	get_tree().quit()

func set_time(scale: float) -> void:
	Engine.time_scale = scale
	note("tiempo ×%0.2f" % scale)

## Everyone there is to watch, in seat order, with the creature last.
func watchable() -> Array:
	var bodies: Array = []
	for seat in level.match_net.bodies:
		if is_instance_valid(level.match_net.bodies[seat]): bodies.append(level.match_net.bodies[seat])
	if is_instance_valid(level.player) and level.player.visible: bodies.append(level.player)
	if live_locust() != null: bodies.append(live_locust())
	return bodies

func follow_next() -> void:
	var bodies := watchable()
	if bodies.is_empty(): return
	following = bodies[(bodies.find(following) + 1) % bodies.size()]
	map_view = false
	note("siguiendo a %s" % following.name)

## What the creature hears, drawn where it stands. The reading is built for
## whoever drives the creature; here nobody does, so it is given the same three
## things a driver gives it (Ears) and this camera to draw into.
func toggle_echo() -> void:
	if live_locust() == null:
		note("no hay criatura que oír")
		return
	echoing = not echoing
	if echoing and echo == null:
		ears = Ears.new()
		ears.creature = level.locust
		ears.level = level
		ears.camera = camera
		add_child(ears)
		echo = ECHO.new()
		ears.add_child(echo)
		echo.setup(ears)
	if echo == null: return
	if echoing:
		# From its own head: the reading is drawn round where it is standing.
		following = level.locust
		map_view = false
		echo.enable()
	else: echo.disable()
	# The reading replaces the lit hotel, as it does for the hunter: no ambient
	# light, no glow, no lens, and the hotel drawn as the creature's own.
	level.apply_settings()
	echo.apply_quality()
	note("lectura de la criatura %s" % ("sí" if echoing else "no"))

## Ceilings on or off, over the whole hotel as it stands now.
func apply_roof() -> void:
	if not is_instance_valid(level.hotel): return
	for node in level.hotel.find_children("*ceiling*", "MultiMeshInstance3D", true, false): node.visible = not roofless
	for node in level.hotel.find_children("*Ceiling*", "MeshInstance3D", true, false): node.visible = not roofless

## The floor as a plan: straight down, without perspective, with the ceilings
## off and the marks drawn big enough to read from up there.
func toggle_map() -> void:
	map_view = not map_view
	roofless = map_view
	apply_roof()
	gizmos.scale_hint = 6.0 if map_view else 1.0
	if not map_view:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		# Down to the planta it was showing, at eye height: from the height of
		# the plan the free camera would count as on the top planta.
		global_position.y = FLOOR.planta_y(planta) + 1.7
		return
	following = null
	frame_map()

## The plan of the planta being looked at, and only that one, framed on the
## floor that is up now.
func frame_map() -> void:
	var middle := Vector3(0, FLOOR.planta_y(planta), 0)
	var span := 40.0
	if not level.manifest.is_empty():
		var here: Array = level.manifest.rooms.filter(func(room): return FLOOR.planta_of(FLOOR.position_of(room).y) == planta)
		if not here.is_empty():
			middle = Vector3.ZERO
			for room in here: middle += FLOOR.position_of(room)
			middle /= float(here.size())
			for room in here: span = maxf(span, FLOOR.position_of(room).distance_to(middle))
	global_position = middle + Vector3(0, MAP_HEIGHT, 0.01)
	rotation = Vector3.ZERO
	pitch = -PI / 2
	camera.rotation.x = pitch
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	map_span = span
	fit_map()

## The plan in the part of the window the panel leaves free, every frame (the
## window can change, and H takes the panel away). The other panel is about
## the machine and goes while the plan is up: between the two there was a
## strip of the plan to see.
func fit_map() -> void:
	var window := get_viewport().get_visible_rect().size
	var left: float = panel.get_parent().get_rect().end.x if layer.visible else 0.0
	var free := maxf(window.x - left, window.x * 0.3)
	camera.size = map_span * 2.3 * maxf(1.0, window.y / free)
	# Moved over so its middle is the middle of what is free.
	camera.h_offset = -0.5 * (window.x - free) * camera.size / window.y

## A floor has just been put up (R, Shift+R, a match beginning): the view is
## kept and turned on it. The plan is framed on this floor's planta, and the
## free camera goes to where that planta is walked into -- its old spot could
## be inside a wall of this floor, or outside it.
func arrived() -> void:
	var seed_now := int(level.session.run_seed)
	if seed_shown >= 0 and seed_now != seed_shown: seed_before = seed_shown
	seed_shown = seed_now
	floor_seen = level.manifest
	following = null
	# What was drawn over the last floor is not this one's.
	gizmos.trails.clear()
	gizmos.noises.clear()
	gizmos.lift_route = PackedVector3Array()
	# The reading was built round the creature and the hotel that went.
	if echo != null:
		if echoing:
			echoing = false
			echo.disable()
			level.apply_settings()
		ears.queue_free()
		ears = null
		echo = null
	planta_notes = PackedStringArray()
	var plans: Array = level.manifest.get("plans", [])
	for index in plans.size():
		var plan: Dictionary = plans[index]
		# Its size as it stands, from the cells it uses.
		var low := Vector2(INF, INF)
		var high := -low
		for room in level.manifest.rooms:
			if FLOOR.is_void(room) or FLOOR.planta_of(FLOOR.position_of(room).y) != index: continue
			var at := Vector2(FLOOR.position_of(room).x, FLOOR.position_of(room).z)
			low = low.min(at - FLOOR.size_of(room) * 0.5)
			high = high.max(at + FLOOR.size_of(room) * 0.5)
		planta_notes.append("%s · %s · %d habitaciones · %0.0f × %0.0f m" % [PLAN_NAMES.get(plan.plan, plan.plan), SHAPE_NAMES.get(plan.shape, plan.shape), int(plan.rooms), high.x - low.x, high.y - low.y])
	if map_view: frame_map()
	else: global_position = FLOOR.position_of(level.manifest.rooms[int(level.manifest.entries[planta])]) + Vector3(0, 1.7, 0)
	var names: PackedStringArray = []
	for plan in plans: names.append(PLAN_NAMES.get(plan.plan, plan.plan))
	note("piso %d · %s%s" % [seed_now, ", ".join(names), " · de respaldo" if level.manifest.get("fallback", false) else ""])

func note(words: String) -> void:
	# The same thing twice running is said once: a knock nobody answers comes
	# back every half minute while a floor is looked at alone.
	if not events.is_empty() and events[-1].ends_with("  " + words): return
	events.append("%s  %s" % [stamp(), words])
	while events.size() > LOG_KEPT * 4: events.pop_front()

func stamp() -> String:
	return "%d:%02d" % [int(clock) / 60, int(clock) % 60]

func _process(delta: float) -> void:
	clock += delta
	# A floor arriving from a room sets the player's own camera up again: this
	# one takes it back, every frame, because there is no player here.
	if not camera.current: camera.current = true
	if is_instance_valid(level.player) and level.player.visible:
		level.player.visible = false
		level.player.active = false
	# Its own light, over whatever the floor is doing with its lamps.
	lamp.visible = lit
	if is_instance_valid(level.environment):
		if ambient_before < 0.0:
			ambient_before = level.environment.ambient_light_energy
			ambient_colour_before = level.environment.ambient_light_color
			fog_before = level.environment.fog_enabled
		# The hotel is lit by its own lamps and most of it is meant to be dark;
		# for looking at it, a light of our own over all of it. The plan is read,
		# not explored, so from above there is more of it.
		level.environment.ambient_light_energy = (1.4 if map_view else 0.4) if lit else ambient_before
		level.environment.ambient_light_color = Color(0.78, 0.8, 0.85) if lit else ambient_colour_before
		# The depth fog is what makes a dark hotel dark: looking at it, it goes.
		level.environment.fog_enabled = fog_before and not lit
		level.environment.volumetric_fog_enabled = level.environment.volumetric_fog_enabled and not lit
		lamp.light_energy = 2.2 if map_view else 1.1
		lamp.rotation_degrees = Vector3(-90, 0, 0) if map_view else Vector3(-55, 35, 0)
	if not level.manifest.is_empty() and not is_same(level.manifest, floor_seen) and level.session.state != level.session.State.LOADING and is_instance_valid(level.hotel) and not level.hotel.building: arrived()
	# The reading is clicked by whoever drives the creature; watching, nobody
	# does, so it is clicked here (echo_view.advance).
	var creature = live_locust()
	if echoing and echo != null and creature != null: echo.advance(delta, creature.mode == creature.Mode.CHASE)
	fly(delta)
	# Whatever took the view off the plan (M, TAB, V), what the plan changed
	# goes with it: TAB used to follow a body with the plan's flat camera.
	metrics.get_parent().visible = not map_view
	gizmos.scale_hint = 6.0 if map_view else 1.0
	if map_view: fit_map()
	else:
		camera.h_offset = 0.0
		if camera.projection != Camera3D.PROJECTION_PERSPECTIVE: camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	watch_changes()
	panel.text = report()
	metrics.text = readings()

func fly(delta: float) -> void:
	# Its reading is drawn from its head: to see what it hears, you stand where
	# it stands and look where it looks, which is what the hunter does.
	var creature = live_locust()
	if echoing and creature != null:
		planta = FLOOR.planta_of(creature.global_position.y)
		global_position = creature.global_position + Ears.EYE
		rotation.y = creature.rotation.y
		camera.position = Vector3(Ears.SHOULDER, 0.0, Ears.ARM)
		camera.rotation.x = 0.0
		return
	camera.position = Vector3.ZERO
	if is_instance_valid(following) and following.is_inside_tree():
		planta = FLOOR.planta_of(following.global_position.y)
		var behind: Vector3 = following.global_position + Vector3(0, 2.4, 0) + following.global_basis.z * 3.2
		global_position = global_position.lerp(behind, minf(1.0, delta * 6.0))
		look_at(following.global_position + Vector3(0, 1.6, 0))
		camera.rotation.x = 0.0
		return
	# Free, it stays on the planta chosen, however high it flies: taken from its
	# height, going up to look at a planta from above brought back the top one.
	var axis := Input.get_vector("left", "right", "forward", "backward")
	var lift := (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("crouch") else 0.0)
	var quick: float = QUICK if Input.is_action_pressed("sprint") else 1.0
	var wanted: Vector3 = Vector3(axis.x, lift, axis.y).rotated(Vector3.UP, rotation.y) if map_view else (camera.global_basis * Vector3(axis.x, 0, axis.y)) + Vector3(0, lift, 0)
	global_position += wanted * speed * quick * delta

## Everything worth a line in the log, looked at once a frame: what changed is
## what a floor did, and it is what this tool is for.
func watch_changes() -> void:
	if level.manifest.is_empty(): return
	var session = level.session
	var now := {
		"estado": estado(session.state),
		"sector": session.stage,
		"meta": bool(session.goal.get("ready", false)),
		"apagón": bool(session.goal.get("blackout", false)),
		"código": bool(level.code_entered),
		"teles": level.televisions_on(),
		"números": level.found_digits.size(),
		"ejecución": int(level.execution.get("seat", -1)) if not level.execution.is_empty() else -1,
		"saliendo": level.lifts.leaving >= 0.0,
	}
	var creature = live_locust()
	if creature != null:
		now["criatura"] = "%s en ala %d" % [modo(creature.mode), wing_of(creature.global_position)]
		now["mando"] = String(creature.control)
	for seat in session.participants: now["vida %d" % int(seat)] = ["explorando", "en refugio", "muerto"][int(session.participants[seat])]
	for index in level.hotel.lifts.size(): now["coche %d" % index] = level.lifts.lift_gone(index)
	for key in now:
		if before.has(key) and before[key] != now[key]: note("%s: %s" % [key, str(now[key])])
	before = now

## The floor, in the words that answer what this was made for.
func report() -> String:
	if level == null or level.manifest.is_empty() or not is_instance_valid(level.hotel): return "Sin piso todavía."
	# While a floor is being put up there is nothing on it to read yet.
	if level.session.state == level.session.State.LOADING: return "OBSERVADOR · construyendo un piso…"
	var session = level.session
	var lines: PackedStringArray = []
	var where: String = "libre" if not is_instance_valid(following) else "siguiendo a %s" % following.name
	lines.append("OBSERVADOR · %s%s%s · %0.0f m/s%s" % [where, " · mapa" if map_view else "", " · lectura" if echoing else "", speed, "" if is_equal_approx(Engine.time_scale, 1.0) else " · tiempo ×%0.2f" % Engine.time_scale])
	lines.append("TAB seguir · F soltar · M mapa · RePág/AvPág planta · C techos · L luz · H panel")
	lines.append("R otro piso%s · V lectura · 1-6 capas" % ((" · Mayús+R vuelve al %d" % seed_before) if seed_before >= 0 else ""))
	lines.append("P [ ] tiempo · F5 volcar · ESC ratón, y otra vez cerrar")
	lines.append("")
	# Which floor this is and where it came from, which is the first thing to
	# know when a tool shows you a hotel.
	var source := "piso propio · buscando partida en %s" % level.observer_address
	if level.net.observing and level.match_net.in_match(): source = "la partida · %s" % ("versus" if level.match_net.versus() else "cooperativo")
	elif level.net.observing: source = "piso propio · en la sala, esperando a que empiecen"
	lines.append("Piso 1 · semilla %d · %s" % [int(session.run_seed), source])
	# What the generator made of the planta on screen, to put a name to what
	# the plan shows when floors are compared.
	lines.append("Planta %d de %d%s" % [planta + 1, FLOOR.PLANTAS, (" · " + planta_notes[planta]) if planta < planta_notes.size() else ""])
	lines.append("Sector %d/%d · %s · %s" % [session.stage, session.STAGES, estado(session.state), String(session.goal.get("kind", "?"))])
	lines.append("Meta %s %d/%d%s · código %s · teles %d" % ["lista" if session.goal.get("ready", false) else "pendiente", int(session.goal.get("done", 0)), int(session.goal.get("needed", 0)), " · apagón" if session.goal.get("blackout", false) else "", "puesto" if level.code_entered else "no", level.televisions_on()])
	lines.append("")
	lines.append("SUPERVIVIENTES")
	# Offline the bodies are the level's: this machine's player on a floor it
	# plays, or bots (tools/bots) on one they play or one watched again.
	var anybody := false
	for seat in session.participants:
		var body: Node3D = level.match_net.body_of(int(seat)) if level.match_net.in_match() else level.body_of_seat(int(seat))
		if not level.match_net.in_match() and (body == null or (body == level.player and not level.player.visible)): continue
		anybody = true
		var life: String = ["explorando", "en refugio", "muerto"][int(session.participants[seat])]
		var spot := "?"
		var mind := ""
		if is_instance_valid(body):
			spot = "ala %d · %0.0f, %0.0f" % [wing_of(body.global_position), body.global_position.x, body.global_position.z]
			if live_locust() != null: spot += " · a %0.0f m" % body.global_position.distance_to(live_locust().global_position)
			if body.get("hidden"): spot += " · escondido"
		var minds: Dictionary = level.sanity.minds if level.sanity != null else {}
		if minds.has(int(seat)): mind = " · cordura %0.0f" % float(minds[int(seat)].get("sanity", 100.0))
		elif int(seat) == level.player.slot: mind = " · cordura %0.0f" % level.player.sanity
		var riding: String = " · en ascensor" if level.lifts.riding.has(int(seat)) else ""
		lines.append("  %d %s · %s · %s%s%s" % [int(seat), level.seat_name(int(seat)), life, spot, mind, riding])
	if not anybody: lines.append("  ninguno · piso de prueba, solo la criatura")
	lines.append("")
	var creature = live_locust()
	if creature != null:
		lines.append("THE LOCUST (%s)" % creature.control)
		lines.append("  %s · gracia %0.1f · velocidad %0.1f · detección %0.2f" % [modo(creature.mode), creature.grace, creature.speed, creature.detection])
		lines.append("  ala %d · %0.0f, %0.0f · sin ver %0.1f s" % [wing_of(creature.global_position), creature.global_position.x, creature.global_position.z, creature.lost_time])
		lines.append("  destino a %0.1f m · camino %d puntos · repath %0.2f · %d puertas en la ruta" % [creature.global_position.distance_to(creature.destination), creature.path.size(), creature.repath, creature.crossings.size()])
		# Its protocol for getting unstuck (hotel_locust.escalate): the step it
		# is on and how many times each has been reached this floor.
		var counts: Array = creature.stuck_counts
		lines.append("  atascos · paso %d ahora · %d/%d/%d/%d/%d (pasos 1 a 5)" % [creature.stuck_level, counts[1], counts[2], counts[3], counts[4], counts[5]])
		var nearest := -1
		var gap := INF
		for index in level.hotel.lifts.size():
			var to_car: float = creature.global_position.distance_to(level.hotel.lifts[index])
			if to_car < gap:
				gap = to_car
				nearest = index
		if nearest >= 0: lines.append("  ascensor más cerca: %d a %0.1f m%s" % [nearest, gap, " (arriba)" if level.lifts.lift_gone(nearest) else ""])
		lines.append("  el coche que le toca: %s" % ("ninguno · ya está en el ala en juego" if level.lifts.creature_car(session.stage) < 0 else str(level.lifts.creature_car(session.stage))))
		if is_instance_valid(creature.focus): lines.append("  va a por %s" % creature.focus.name)
		if creature.leaving: lines.append("  se va: dejó una zona sin encontrar nada")
		if creature.mode == creature.Mode.SEARCH: lines.append("  busca · %d sitios por mirar · %0.1f s sin pistas" % [creature.search_plan.size(), creature.clue_idle])
	lines.append("")
	if is_instance_valid(level.director) and level.director.has_method("status_lines"):
		lines.append_array(level.director.status_lines())
		lines.append("")
	lines.append("ASCENSORES")
	for index in level.hotel.lifts.size():
		var away: float = float(level.lifts.lift_away.get(index, 0.0))
		var gate = level.hotel.gates[index] if level.hotel.gates.size() > index else null
		lines.append("  %d · %s · puerta %s%s" % [index, ("arriba %0.1f s" % away) if away > 0.0 else "abajo", "con llave" if is_instance_valid(gate) and gate.locked else "abierta", " · llamado" if level.lifts.called.has(index) else ""])
		# The creature's own wait for it: after the survivors, and at its doors.
		var hold: float = float(level.lifts.creature_hold.get(index, 0.0))
		var waited: float = float(level.lifts.lobby_time.get(index, 0.0))
		if hold > 0.0 or waited > 0.0: lines.append("    criatura: %s · en el vestíbulo %0.1f / %0.0f s" % [("no antes de %0.1f s" % hold) if hold > 0.0 else "ya puede", waited, level.lifts.CREATURE_WAIT])
	if level.lifts.leaving >= 0.0: lines.append("  último coche saliendo · %0.1f s" % level.lifts.leaving)
	if not level.execution.is_empty(): lines.append("\nEJECUCIÓN en curso · asiento %d · %0.1f s" % [int(level.execution.seat), float(level.execution.time)])
	return "\n".join(lines)

## The other side: what the machine is doing, and what just happened.
func readings() -> String:
	var lines: PackedStringArray = []
	lines.append("MÁQUINA")
	lines.append("  %d FPS · proceso %0.1f ms · física %0.1f ms" % [Performance.get_monitor(Performance.TIME_FPS), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	lines.append("  %d objetos · %d llamadas de dibujo · %d nodos" % [Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	lines.append("  memoria %0.0f MB · vídeo %0.0f MB" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	var viewport := get_viewport()
	lines.append("  render %0.0f%% · %s" % [viewport.scaling_3d_scale * 100.0, RenderingServer.get_current_rendering_method()])
	lines.append("")
	lines.append("RED")
	if level.net.active():
		var peer = level.net.peer
		var round_trip := 0.0
		if peer is ENetMultiplayerPeer and peer.get_peer(1) != null: round_trip = float(peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
		lines.append("  observando · ida y vuelta %0.0f ms · %d jugadores" % [round_trip, level.net.players.size()])
	else: lines.append("  sin conexión · piso local")
	lines.append("")
	if is_instance_valid(level.world_audio):
		lines.append("SONIDO")
		lines.append("  %d voces · agachado %0.1f dB · música %0.2f" % [level.world_audio.voices.size(), level.world_audio.duck_db(), level.music_power])
		lines.append("")
	lines.append("LO QUE HA PASADO")
	for index in range(maxi(0, events.size() - LOG_KEPT), events.size()): lines.append("  " + events[index])
	return "\n".join(lines)

## Everything on screen, written to a file: the state, the log and where
## everybody is, to send with a report of what went wrong.
func snapshot() -> void:
	if level.manifest.is_empty() or not is_instance_valid(level.hotel):
		note("nada que volcar todavía")
		return
	var data := {
		"cuando": Time.get_datetime_string_from_system(false, true),
		"semilla": int(level.session.run_seed),
		"semilla_anterior": seed_before,
		"plantas": Array(planta_notes),
		"sector": level.session.stage,
		"estado": estado(level.session.state),
		"meta": level.session.goal,
		"registro": events,
		"cuerpos": {},
	}
	for seat in level.session.participants:
		var body: Node3D = level.match_net.body_of(int(seat)) if level.match_net.in_match() else level.player
		if is_instance_valid(body): data.cuerpos[str(seat)] = {"vida": int(level.session.participants[seat]), "donde": [body.global_position.x, body.global_position.y, body.global_position.z], "ala": wing_of(body.global_position)}
	var creature = live_locust()
	if creature != null:
		data["criatura"] = {"modo": modo(creature.mode), "mando": creature.control, "donde": [creature.global_position.x, creature.global_position.y, creature.global_position.z], "ala": wing_of(creature.global_position), "destino": [creature.destination.x, creature.destination.z], "camino": creature.path.size(), "atascos": creature.stuck_counts, "paso": creature.stuck_level}
	data["ascensores"] = {}
	for index in level.hotel.lifts.size(): data.ascensores[str(index)] = {"arriba": level.lifts.lift_gone(index), "llave": level.hotel.gates[index].locked if level.hotel.gates.size() > index else null}
	var path := "user://observer_%d.json" % int(Time.get_unix_time_from_system())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		note("no se pudo guardar el volcado")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	note("volcado en %s" % ProjectSettings.globalize_path(path))

func wing_of(point: Vector3) -> int:
	return int(FLOOR.room_at(level.manifest.rooms, point).get("wing", -1))

func estado(state: int) -> String:
	return ["menú", "cargando", "jugando", "en pausa", "cambio de sector", "ganado", "perdido", "escena"][clampi(state, 0, 7)]

## In the order of hotel_locust.Mode. It was once in another, and the panel
## said "busca" of a creature running somebody down.
func modo(mode: int) -> String:
	return ["patrulla", "investiga", "persigue", "busca", "prepara", "se repone", "alerta", "armario", "ejecuta"][clampi(mode, 0, 8)]
