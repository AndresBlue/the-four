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
##   R            otro piso (solo sin partida)
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
const SPEED := 9.0
const SPEED_RANGE := Vector2(1.5, 60.0)
## How far above the floor the map view sits.
const MAP_HEIGHT := 150.0
## How many things that happened are kept on screen.
const LOG_KEPT := 16
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
	panel = write_panel(Vector2(18, 18), Vector2(600, 660))
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
			if alone(): level.observer_rebuild()
		KEY_P:
			if alone(): set_time(0.0 if Engine.time_scale > 0.0 else 1.0)
		KEY_BRACKETLEFT:
			if alone(): set_time(maxf(0.1, Engine.time_scale * 0.5))
		KEY_BRACKETRIGHT:
			if alone(): set_time(minf(4.0, maxf(Engine.time_scale, 0.1) * 2.0))
		KEY_F5: snapshot()
		KEY_ESCAPE: step_out()

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
	if is_instance_valid(level.locust): bodies.append(level.locust)
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
	if not is_instance_valid(level.locust):
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
		return
	following = null
	var middle := Vector3.ZERO
	var span := 40.0
	if not level.manifest.is_empty():
		for room in level.manifest.rooms: middle += FLOOR.position_of(room)
		middle /= float(level.manifest.rooms.size())
		for room in level.manifest.rooms: span = maxf(span, FLOOR.position_of(room).distance_to(middle))
	global_position = middle + Vector3(0, MAP_HEIGHT, 0.01)
	rotation = Vector3.ZERO
	pitch = -PI / 2
	camera.rotation.x = pitch
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = span * 2.3

func note(words: String) -> void:
	events.append("%s  %s" % [stamp(), words])
	while events.size() > LOG_KEPT * 4: events.pop_front()

func stamp() -> String:
	return "%d:%02d" % [int(clock) / 60, int(clock) % 60]

func _process(delta: float) -> void:
	clock += delta
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
	# The reading is clicked by whoever drives the creature; watching, nobody
	# does, so it is clicked here (echo_view.advance).
	if echoing and echo != null and is_instance_valid(level.locust): echo.advance(delta, level.locust.mode == level.locust.Mode.CHASE)
	fly(delta)
	watch_changes()
	panel.text = report()
	metrics.text = readings()

func fly(delta: float) -> void:
	# Its reading is drawn from its head: to see what it hears, you stand where
	# it stands and look where it looks, which is what the hunter does.
	if echoing and is_instance_valid(level.locust):
		global_position = level.locust.global_position + Ears.EYE
		rotation.y = level.locust.rotation.y
		camera.position = Vector3(Ears.SHOULDER, 0.0, Ears.ARM)
		camera.rotation.x = 0.0
		return
	camera.position = Vector3.ZERO
	if is_instance_valid(following):
		var behind: Vector3 = following.global_position + Vector3(0, 2.4, 0) + following.global_basis.z * 3.2
		global_position = global_position.lerp(behind, minf(1.0, delta * 6.0))
		look_at(following.global_position + Vector3(0, 1.6, 0))
		camera.rotation.x = 0.0
		return
	var axis := Input.get_vector("left", "right", "forward", "backward")
	var lift := (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("crouch") else 0.0)
	var quick: float = 3.0 if Input.is_action_pressed("sprint") else 1.0
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
	if is_instance_valid(level.locust):
		now["criatura"] = "%s en ala %d" % [modo(level.locust.mode), wing_of(level.locust.global_position)]
		now["mando"] = String(level.locust.control)
	for seat in session.participants: now["vida %d" % int(seat)] = ["explorando", "en refugio", "muerto"][int(session.participants[seat])]
	for index in level.hotel.lifts.size(): now["coche %d" % index] = level.lifts.lift_gone(index)
	for key in now:
		if before.has(key) and before[key] != now[key]: note("%s: %s" % [key, str(now[key])])
	before = now

## The floor, in the words that answer what this was made for.
func report() -> String:
	if level == null or level.manifest.is_empty() or not is_instance_valid(level.hotel): return "Sin piso todavía."
	var session = level.session
	var lines: PackedStringArray = []
	var where: String = "libre" if not is_instance_valid(following) else "siguiendo a %s" % following.name
	lines.append("OBSERVADOR · %s%s%s · %0.0f m/s%s" % [where, " · mapa" if map_view else "", " · lectura" if echoing else "", speed, "" if is_equal_approx(Engine.time_scale, 1.0) else " · tiempo ×%0.2f" % Engine.time_scale])
	lines.append("TAB seguir · F soltar · M mapa · V lectura · C techos · L luz · 1-6 capas · H panel · R piso · P/[/] tiempo")
	lines.append("F5 volcar · ESC ratón, y otra vez cerrar")
	lines.append("")
	lines.append("Piso 1 · semilla %d · %s · %s" % [int(session.run_seed), "en red" if level.match_net.in_match() else "local", "versus" if level.match_net.versus() else "cooperativo"])
	lines.append("Sector %d/%d · %s · %s" % [session.stage, session.STAGES, estado(session.state), String(session.goal.get("kind", "?"))])
	lines.append("Meta %s %d/%d%s · código %s · teles %d" % ["lista" if session.goal.get("ready", false) else "pendiente", int(session.goal.get("done", 0)), int(session.goal.get("needed", 0)), " · apagón" if session.goal.get("blackout", false) else "", "puesto" if level.code_entered else "no", level.televisions_on()])
	lines.append("")
	lines.append("SUPERVIVIENTES")
	if not level.match_net.in_match() and not level.player.visible:
		lines.append("  ninguno · piso de prueba, solo la criatura")
	for seat in session.participants:
		if not level.match_net.in_match() and not level.player.visible: break
		var body: Node3D = level.match_net.body_of(int(seat)) if level.match_net.in_match() else level.player
		var life: String = ["explorando", "en refugio", "muerto"][int(session.participants[seat])]
		var spot := "?"
		var mind := ""
		if is_instance_valid(body):
			spot = "ala %d · %0.0f, %0.0f" % [wing_of(body.global_position), body.global_position.x, body.global_position.z]
			if is_instance_valid(level.locust): spot += " · a %0.0f m" % body.global_position.distance_to(level.locust.global_position)
			if body.get("hidden"): spot += " · escondido"
		var minds: Dictionary = level.sanity.minds if level.sanity != null else {}
		if minds.has(int(seat)): mind = " · cordura %0.0f" % float(minds[int(seat)].get("sanity", 100.0))
		elif int(seat) == level.player.slot: mind = " · cordura %0.0f" % level.player.sanity
		var riding: String = " · en ascensor" if level.lifts.riding.has(int(seat)) else ""
		lines.append("  %d %s · %s · %s%s%s" % [int(seat), level.seat_name(int(seat)), life, spot, mind, riding])
	lines.append("")
	var creature = level.locust
	if is_instance_valid(creature):
		lines.append("THE LOCUST (%s)" % creature.control)
		lines.append("  %s · gracia %0.1f · velocidad %0.1f · detección %0.2f" % [modo(creature.mode), creature.grace, creature.speed, creature.detection])
		lines.append("  ala %d · %0.0f, %0.0f · sin ver %0.1f s" % [wing_of(creature.global_position), creature.global_position.x, creature.global_position.z, creature.lost_time])
		lines.append("  destino a %0.1f m · camino %d puntos · repath %0.2f" % [creature.global_position.distance_to(creature.destination), creature.path.size(), creature.repath])
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
	lines.append("")
	lines.append("ASCENSORES")
	for index in level.hotel.lifts.size():
		var away: float = float(level.lifts.lift_away.get(index, 0.0))
		var gate = level.hotel.gates[index] if level.hotel.gates.size() > index else null
		lines.append("  %d · %s · puerta %s%s" % [index, ("arriba %0.1f s" % away) if away > 0.0 else "abajo", "con llave" if is_instance_valid(gate) and gate.locked else "abierta", " · llamado" if level.lifts.called.has(index) else ""])
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
		if peer != null and peer.get_peer(1) != null: round_trip = float(peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
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
		"sector": level.session.stage,
		"estado": estado(level.session.state),
		"meta": level.session.goal,
		"registro": events,
		"cuerpos": {},
	}
	for seat in level.session.participants:
		var body: Node3D = level.match_net.body_of(int(seat)) if level.match_net.in_match() else level.player
		if is_instance_valid(body): data.cuerpos[str(seat)] = {"vida": int(level.session.participants[seat]), "donde": [body.global_position.x, body.global_position.y, body.global_position.z], "ala": wing_of(body.global_position)}
	if is_instance_valid(level.locust):
		data["criatura"] = {"modo": modo(level.locust.mode), "mando": level.locust.control, "donde": [level.locust.global_position.x, level.locust.global_position.y, level.locust.global_position.z], "ala": wing_of(level.locust.global_position), "destino": [level.locust.destination.x, level.locust.destination.z], "camino": level.locust.path.size()}
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

func modo(mode: int) -> String:
	return ["patrulla", "investiga", "busca", "alerta", "persigue", "prepara", "se repone", "ejecuta", "armario"][clampi(mode, 0, 8)]
