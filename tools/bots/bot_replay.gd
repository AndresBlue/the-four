extends Node
## A recorded bot match (bot_recorder.gd) watched again in the observer:
##   ./tools/godot.ps1 bots-replay -Run <folder> [-At <second>]
## The same floor is put up from its seed and checked against the hash the
## recording kept; nothing on it runs of itself (hotel_main.replaying): the
## bots are puppets put where the recording has them, the creature too, and
## the doors, sets, drawers, the code, the power, the stage and the lives go
## the way they went. Time is the recording's own, and can be stopped, sped
## up and jumped about -- backwards too: a jump starts from the nearest whole
## picture of the floor before it (a keyframe) and plays what came after.
##
## Keys, on top of the observer's:
##   P pause · [ ] slower/faster · Left/Right 10 s · Shift+Left/Right 60 s
##   N/B next/previous incident · Home/End · 7 whole trails · 8 what there was
##   to find · 9 where each meant to go
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PUPPET := preload("res://tools/bots/bot_replay_puppet.gd")
const RECORDER := preload("res://tools/bots/bot_recorder.gd")
const THREATS := preload("res://tools/bots/bot_threats.gd")
const COLOURS := [Color(0.2, 0.9, 1.0), Color(0.4, 1.0, 0.35), Color(1.0, 0.9, 0.2), Color(1.0, 0.35, 0.9), Color(1.0, 1.0, 1.0)]
const CREATURE := Color(1.0, 0.2, 0.15)
const SEVERITY := {"leve": Color(0.7, 0.7, 0.7), "media": Color(1.0, 0.6, 0.1), "grave": Color(1.0, 0.1, 0.1)}
const TRAIL_EVERY := 1.0
var level
var folder := ""
var header := {}
var events: Array = []
var incidents: Array = []
var times := PackedFloat32Array()
var frames: Array = []
var routes: Array = []
var keys: Array = []
var duration := 0.0
var t := 0.0
var speed := 1.0
var paused := false
var next_event := 0
var puppets := {}
var seats: Array = []
## Per seat (0 the creature): [[time, point], ...] one a second.
var trails := {}
var mesh: ImmediateMesh
var drawing: MeshInstance3D
var labels: Array = []
var bar: Control
var caption: Label
var listing: Label
var show_trails := true
var show_goals := true
var show_routes := true
var current_incident := -1
var problem := ""
## The threat model of the creature recorded (bot_threats.gd): it puts the
## creature back the way the recording keeps it.
var model

func setup(owner_level, path: String) -> void:
	level = owner_level
	folder = path
	name = "BotReplay"
	process_mode = Node.PROCESS_MODE_ALWAYS

# --- Reading the recording ------------------------------------------------------------

func read() -> bool:
	var header_file := FileAccess.open(folder.path_join("header.json"), FileAccess.READ)
	if header_file == null:
		problem = "No hay grabación en %s" % folder
		return false
	header = JSON.parse_string(header_file.get_as_text())
	if int(header.get("generator", -1)) != FLOOR.VERSION:
		problem = "La grabación es del generador %d y el juego va por el %d: su piso ya no es el mismo." % [int(header.get("generator", -1)), FLOOR.VERSION]
		return false
	var events_file := FileAccess.open(folder.path_join("events.jsonl"), FileAccess.READ)
	while events_file != null and not events_file.eof_reached():
		var line := events_file.get_line()
		if line.strip_edges().is_empty(): continue
		var entry = JSON.parse_string(line)
		if entry is Dictionary: events.append(entry)
	events.sort_custom(func(a, b): return float(a.t) < float(b.t))
	for entry in events:
		if String(entry.kind) == "incidencia": incidents.append(entry.entry)
	var pieces: Array = []
	for file in DirAccess.get_files_at(folder):
		if file.begins_with("track_") and file.ends_with(".bin"): pieces.append(file)
	pieces.sort()
	var frame_times: Array = []
	for piece in pieces:
		var stream := FileAccess.open_compressed(folder.path_join(piece), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		if stream == null: continue
		# A piece cut short by a crash reads up to where it was cut.
		while stream.get_position() < stream.get_length():
			var record = stream.get_var()
			if not record is Array or record.size() < 3: break
			match String(record[0]):
				"f":
					frame_times.append(float(record[1]))
					frames.append(record[2])
				"r": routes.append([float(record[1]), record[2]])
				"k": keys.append([float(record[1]), record[2]])
	times = PackedFloat32Array(frame_times)
	if times.is_empty() or keys.is_empty():
		problem = "La grabación de %s no tiene recorrido." % folder
		return false
	duration = times[times.size() - 1]
	seats = header.get("seats", [])
	return true

# --- Putting it up -----------------------------------------------------------------

func begin(at: float) -> void:
	if not read():
		fail(problem)
		return
	level.replaying = true
	level.bot_match = true
	level.observer = true
	level.session.keeps_checkpoint = false
	level.settings.force_window = true
	level.settings.apply_display()
	await level.start_floor(int(header.seed), false, seats, String(header.get("difficulty", "desafiante")))
	if level.session.state != level.session.State.PLAYING:
		fail("No se pudo levantar el piso de la semilla %d." % int(header.seed))
		return
	if hash(JSON.stringify(level.manifest)) != int(header.floor_hash):
		fail("El piso de la semilla %d ya no es el que se grabó (el generador o su contenido cambiaron desde entonces)." % int(header.seed))
		return
	level.session.authority = false
	if is_instance_valid(level.director): level.director.process_mode = Node.PROCESS_MODE_DISABLED
	level.creature.set_control("puppet")
	level.creature.grace = 0.0
	model = THREATS.make(level)
	var names: Array = header.get("names", [])
	var characters: Array = header.get("characters", [])
	for i in seats.size():
		var seat := int(seats[i])
		var puppet := PUPPET.new()
		puppet.setup(level, seat, String(names[i]) if i < names.size() else "Bot %d" % (i + 1), int(characters[i]) if i < characters.size() else i % 3)
		level.add_child(puppet)
		level.match_net.bodies[seat] = puppet
		puppets[seat] = puppet
	level.enter_observer_mode()
	build_trails()
	build_view()
	build_labels()
	seek(clampf(at, 0.0, duration))
	level.observer_view.note("REPASO · %s · semilla %d · %d bots · %s" % [folder.get_file(), int(header.seed), seats.size(), clock_text(duration)])

func fail(words: String) -> void:
	push_warning(words)
	problem = words
	level.ui.menu("main", false, words)

# --- Time ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if times.is_empty() or not level.replaying or level.observer_view == null: return
	if not paused:
		var was := t
		t = minf(t + delta * speed, duration)
		play_events(was, t, false)
	pose_everyone()
	draw()
	update_caption()

## What happened between two moments, done on the floor. Quiet when jumping:
## a door that was already open is put open, not heard swinging.
func play_events(from: float, to: float, quiet: bool) -> void:
	while next_event < events.size() and float(events[next_event].t) <= to:
		var entry: Dictionary = events[next_event]
		if float(entry.t) > from or quiet: apply(entry, quiet)
		next_event += 1

func apply(entry: Dictionary, quiet: bool) -> void:
	var hotel = level.hotel
	match String(entry.kind):
		"puerta":
			var door = hotel.doors[int(entry.door)]
			if quiet: door.set_state(bool(entry.open))
			else: door.swing_to(bool(entry.open), bool(entry.get("slow", false)), bool(entry.get("forceful", false)))
		"tele": level.apply_television(int(entry.index), bool(entry.on), quiet)
		"cerrojo": hotel.doors[int(entry.door)].locked = bool(entry.locked)
		"mueble": search(int(entry.index), bool(entry.searched), int(entry.get("by", -1)), quiet)
		"blackout": if bool(hotel.dark) != bool(entry.value): hotel.blackout(bool(entry.value))
		"code": set_code(bool(entry.value))
		"stage": level.session.stage = int(entry.value)
		"lives": set_lives(entry.value)
		"armario": set_hide(int(entry.hide), int(entry.seat))
		"mode":
			if model != null: model.replay_mode(int(entry.value))
	if quiet: return
	# What is worth a line in the observer's log.
	var words := ""
	match String(entry.kind):
		"incidencia":
			var incident: Dictionary = entry.entry
			words = "%s %s · %s%s" % [String(incident.severity).to_upper(), incident.kind, (String(incident.bot) + " · ") if not String(incident.bot).is_empty() else "", incident.words]
		"descubre": words = "%s ve %s" % [seat_name(entry), entry.target]
		"huye": words = "%s huye" % seat_name(entry)
		"se_esconde": words = "%s se esconde" % seat_name(entry)
		"ascensor": words = "%s pulsa el ascensor %d" % [seat_name(entry), int(entry.car) + 1]
		"sector": words = "sector %d" % int(entry.stage)
		"ruido": if level.observer_view != null: level.observer_view.gizmos.note_noise(Vector3(entry.at[0], entry.at[1], entry.at[2]), float(entry.radius))
	if not words.is_empty(): level.observer_view.note("%s %s" % [clock_text(float(entry.t)), words])

func seat_name(entry: Dictionary) -> String:
	var puppet = puppets.get(int(entry.get("seat", -1)))
	return puppet.player_name if puppet != null else "alguien"

func search(index: int, searched: bool, by: int, quiet: bool) -> void:
	var piece = level.containers[index]
	if searched:
		if not piece.searched: level.apply_search(index, true, quiet, by)
		return
	if not piece.searched: return
	piece.set_searched(false)
	if int(piece.digit) >= 0:
		piece.plant_note()
		level.found_digits.erase(int(piece.slot))
		level.found_by.erase(int(piece.slot))

func set_code(value: bool) -> void:
	level.code_entered = value
	if is_instance_valid(level.lock): level.lock.set_open(value)

func set_lives(lives: Dictionary) -> void:
	for seat_key in lives:
		var seat := int(seat_key)
		level.session.participants[seat] = int(lives[seat_key])
		if puppets.has(seat): puppets[seat].set_dead(int(lives[seat_key]) == level.session.Life.DEAD)

func set_hide(index: int, seat: int) -> void:
	var hide = level.hotel.hides[index]
	var inside = hide.occupant
	if seat >= 0 and puppets.has(seat):
		if inside == puppets[seat]: return
		if is_instance_valid(inside): level.match_net.remote_leaves(hide, inside)
		level.match_net.remote_enters(hide, puppets[seat])
	elif is_instance_valid(inside): level.match_net.remote_leaves(hide, inside)

## The floor at a moment as data -- what seek() puts on the floor: the last
## whole picture before it and what happened after. The test that a
## recording says what went on compares this with the floor itself.
func state_at(to: float) -> Dictionary:
	var key: Array = keys[0]
	for candidate in keys:
		if float(candidate[0]) <= to: key = candidate
	var state: Dictionary = key[1].duplicate(true)
	var doors: PackedByteArray = state.get("doors", PackedByteArray()).duplicate()
	var sets: Array = state.get("tvs", []).duplicate()
	var searched: Array = state.get("searched", []).duplicate()
	var hides: Dictionary = state.get("hides", {}).duplicate()
	var lives := {}
	for seat in state.get("lives", {}): lives[int(seat)] = int(state.lives[seat])
	for entry in events:
		if float(entry.t) <= float(key[0]) or float(entry.t) > to: continue
		match String(entry.kind):
			"puerta": if int(entry.door) < doors.size(): doors[int(entry.door)] = 1 if bool(entry.open) else 0
			"tele":
				sets.erase(int(entry.index))
				if bool(entry.on): sets.append(int(entry.index))
			"mueble":
				searched.erase(int(entry.index))
				if bool(entry.searched): searched.append(int(entry.index))
			"code": state["code"] = bool(entry.value)
			"stage": state["stage"] = int(entry.value)
			"blackout": state["blackout"] = bool(entry.value)
			"lives": for seat in entry.value: lives[int(seat)] = int(entry.value[seat])
			"armario":
				if int(entry.seat) >= 0: hides[int(entry.hide)] = int(entry.seat)
				else: hides.erase(int(entry.hide))
	sets.sort()
	searched.sort()
	state["doors"] = doors
	state["tvs"] = sets
	state["searched"] = searched
	state["hides"] = hides
	state["lives"] = lives
	return state

## Straight to a moment: the last whole picture of the floor before it, and
## what happened from there on, quietly.
func seek(to: float) -> void:
	t = clampf(to, 0.0, duration)
	var key: Array = keys[0]
	for candidate in keys:
		if float(candidate[0]) <= t: key = candidate
	apply_keyframe(key[1])
	next_event = 0
	while next_event < events.size() and float(events[next_event].t) <= float(key[0]): next_event += 1
	play_events(float(key[0]), t, true)
	pose_everyone()

func apply_keyframe(state: Dictionary) -> void:
	var doors: PackedByteArray = state.get("doors", PackedByteArray())
	for index in mini(doors.size(), level.hotel.doors.size()):
		var door = level.hotel.doors[index]
		if door.opened != (doors[index] == 1) or door.moving: door.set_state(doors[index] == 1)
	var locked: Array = state.get("locked", [])
	for index in level.hotel.doors.size():
		var door = level.hotel.doors[index]
		if int(door.gate_stage) > 0 or door.locked: door.locked = locked.has(index)
	var lit: Array = state.get("tvs", [])
	for index in level.televisions.size(): level.apply_television(index, lit.has(index), true)
	var searched: Array = state.get("searched", [])
	for index in level.containers.size(): search(index, searched.has(index), int(state.get("found_by", {}).get(int(level.containers[index].slot), -1)), true)
	set_code(bool(state.get("code", false)))
	if bool(level.hotel.dark) != bool(state.get("blackout", false)): level.hotel.blackout(bool(state.get("blackout", false)))
	level.session.stage = int(state.get("stage", 1))
	set_lives(state.get("lives", {}))
	var hides: Dictionary = state.get("hides", {})
	for index in level.hotel.hides.size(): set_hide(index, int(hides.get(index, -1)))

## Everybody where the recording has them now, between its two nearest frames.
func pose_everyone() -> void:
	var i := times.bsearch(t, false) - 1
	i = clampi(i, 0, times.size() - 1)
	var j := mini(i + 1, times.size() - 1)
	var span: float = maxf(times[j] - times[i], 0.001)
	var w: float = clampf((t - times[i]) / span, 0.0, 1.0) if j != i else 0.0
	var a: PackedFloat32Array = frames[i]
	var b: PackedFloat32Array = frames[j]
	var fields := int(header.get("bot_fields", RECORDER.BOT_FIELDS))
	for k in seats.size():
		var puppet = puppets[int(seats[k])]
		var o := k * fields
		if o + fields > a.size(): continue
		var at := Vector3(a[o], a[o + 1], a[o + 2]).lerp(Vector3(b[o], b[o + 1], b[o + 2]), w)
		var flags := int(a[o + 5])
		var moving := (Vector3(b[o], b[o + 1], b[o + 2]) - Vector3(a[o], a[o + 1], a[o + 2])) / span
		if Vector3(b[o], b[o + 1], b[o + 2]).distance_to(Vector3(a[o], a[o + 1], a[o + 2])) > 3.0: moving = Vector3.ZERO
		puppet.pose(at, lerp_angle(a[o + 3], b[o + 3], w), lerpf(a[o + 4], b[o + 4], w), moving, flags & RECORDER.Flag.CROUCHED != 0, flags & RECORDER.Flag.TORCH != 0)
	var c := seats.size() * fields
	if c + 4 <= a.size() and is_instance_valid(level.creature) and model != null:
		model.replay_pose(Vector3(a[c], a[c + 1], a[c + 2]).lerp(Vector3(b[c], b[c + 1], b[c + 2]), w), lerp_angle(a[c + 3], b[c + 3], w), (Vector3(b[c], b[c + 1], b[c + 2]) - Vector3(a[c], a[c + 1], a[c + 2])) / span)

# --- Keys ---------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if times.is_empty() or not event is InputEventKey or not event.pressed or event.echo: return
	var handled := true
	match event.physical_keycode:
		KEY_P: paused = not paused
		KEY_BRACKETLEFT: speed = maxf(0.25, speed * 0.5)
		KEY_BRACKETRIGHT: speed = minf(16.0, speed * 2.0)
		KEY_LEFT: seek(t - (60.0 if event.shift_pressed else 10.0))
		KEY_RIGHT: seek(t + (60.0 if event.shift_pressed else 10.0))
		KEY_HOME: seek(0.0)
		KEY_END: seek(duration)
		KEY_N: jump_incident(1)
		KEY_B: jump_incident(-1)
		KEY_7: show_trails = not show_trails
		KEY_8: show_goals = not show_goals
		KEY_9: show_routes = not show_routes
		KEY_R: level.observer_view.note("R: no en un repaso (es la semilla %d, grabada)" % int(header.seed))
		_: handled = false
	if handled: get_viewport().set_input_as_handled()

## To the next (or previous) incident, a few seconds before it.
func jump_incident(way: int) -> void:
	if incidents.is_empty(): return
	var chosen := -1
	if way > 0:
		for i in incidents.size():
			if float(incidents[i].t) > t + 5.5:
				chosen = i
				break
		if chosen < 0: chosen = incidents.size() - 1
	else:
		for i in range(incidents.size() - 1, -1, -1):
			if float(incidents[i].t) < t + 4.5:
				chosen = i
				break
		if chosen < 0: chosen = 0
	current_incident = chosen
	seek(maxf(0.0, float(incidents[chosen].t) - 5.0))
	# Looking at it: from above, on its planta.
	var incident: Dictionary = incidents[chosen]
	level.observer_view.note("→ incidencia %d/%d: %s" % [chosen + 1, incidents.size(), incident.words])

# --- Drawing ----------------------------------------------------------------------

func build_trails() -> void:
	var fields := int(header.get("bot_fields", RECORDER.BOT_FIELDS))
	var last := -INF
	for i in times.size():
		if times[i] - last < TRAIL_EVERY and i != times.size() - 1: continue
		last = times[i]
		var values: PackedFloat32Array = frames[i]
		for k in seats.size():
			var o := k * fields
			if o + 3 > values.size(): continue
			var list: Array = trails.get(int(seats[k]), [])
			list.append([times[i], Vector3(values[o], values[o + 1], values[o + 2])])
			trails[int(seats[k])] = list
		var c := seats.size() * fields
		if c + 3 <= values.size():
			var list: Array = trails.get(0, [])
			list.append([times[i], Vector3(values[c], values[c + 1], values[c + 2])])
			trails[0] = list

func build_view() -> void:
	mesh = ImmediateMesh.new()
	drawing = MeshInstance3D.new()
	drawing.name = "ReplayLines"
	drawing.mesh = mesh
	drawing.top_level = true
	drawing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drawing.material_override = material
	add_child(drawing)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	bar = Control.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -64
	bar.offset_bottom = -8
	bar.offset_left = 16
	bar.offset_right = -16
	bar.draw.connect(draw_bar)
	layer.add_child(bar)
	caption = Label.new()
	caption.anchor_left = 0.0
	caption.anchor_right = 1.0
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.offset_top = -64
	caption.offset_left = 22
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 6)
	layer.add_child(caption)
	listing = Label.new()
	listing.anchor_left = 1.0
	listing.anchor_right = 1.0
	listing.offset_left = -560
	listing.offset_right = -16
	listing.offset_top = 16
	listing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	listing.add_theme_font_size_override("font_size", 13)
	listing.add_theme_color_override("font_outline_color", Color.BLACK)
	listing.add_theme_constant_override("outline_size", 5)
	layer.add_child(listing)

func draw_bar() -> void:
	var width := bar.size.x
	var y := bar.size.y - 10.0
	bar.draw_rect(Rect2(0, y - 3, width, 6), Color(0, 0, 0, 0.55))
	bar.draw_rect(Rect2(0, y - 3, width * t / maxf(duration, 0.001), 6), Color(0.85, 0.85, 0.85, 0.8))
	for entry in events:
		if String(entry.kind) == "sector": bar.draw_line(Vector2(width * float(entry.t) / duration, y - 12), Vector2(width * float(entry.t) / duration, y + 6), Color.WHITE, 2.0)
	for incident in incidents:
		var x: float = width * float(incident.t) / duration
		bar.draw_line(Vector2(x, y - 8), Vector2(x, y + 3), SEVERITY.get(String(incident.severity), Color.GRAY), 2.0)
	bar.draw_circle(Vector2(width * t / maxf(duration, 0.001), y), 6.0, Color.WHITE)

func update_caption() -> void:
	var stage := int(level.session.stage)
	caption.text = "REPASO %s / %s · x%s%s · sector %d · incidencias %d%s" % [clock_text(t), clock_text(duration), str(speed), " · EN PAUSA" if paused else "", stage, incidents.size(), "" if current_incident < 0 else " (%d)" % (current_incident + 1)]
	bar.queue_redraw()
	# The incidents near this moment, the current one marked.
	var lines: Array = []
	for i in incidents.size():
		var incident: Dictionary = incidents[i]
		if absf(float(incident.t) - t) > 90.0 and i != current_incident: continue
		lines.append("%s%s %s %s · %s%s" % ["» " if i == current_incident else "", clock_text(float(incident.t)), String(incident.severity).to_upper(), incident.kind, (String(incident.bot) + " · ") if not String(incident.bot).is_empty() else "", incident.words])
		if lines.size() >= 8: break
	listing.text = "\n".join(lines)

func draw() -> void:
	mesh.clear_surfaces()
	var planta: int = level.observer_view.planta
	var big: float = 6.0 if level.observer_view.map_view else 1.0
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var drawn := 0
	if show_trails:
		for seat in trails:
			var colour: Color = CREATURE if int(seat) == 0 else COLOURS[seats.find(int(seat)) % COLOURS.size()]
			var list: Array = trails[seat]
			for i in range(1, list.size()):
				if float(list[i][0]) > t: break
				var a: Vector3 = list[i - 1][1]
				var b: Vector3 = list[i][1]
				if FLOOR.planta_of(a.y) != planta or FLOOR.planta_of(b.y) != planta or a.distance_to(b) > 12.0: continue
				mesh.surface_set_color(Color(colour, 0.75))
				mesh.surface_add_vertex(a + Vector3(0, 0.15, 0))
				mesh.surface_set_color(Color(colour, 0.75))
				mesh.surface_add_vertex(b + Vector3(0, 0.15, 0))
				drawn += 1
	if show_routes: drawn += draw_routes(planta)
	if show_goals: drawn += draw_goals(planta, big)
	drawn += draw_incidents(planta, big)
	drawn += draw_sight(planta)
	if drawn == 0:
		mesh.surface_set_color(Color.TRANSPARENT)
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_end()

func line(a: Vector3, b: Vector3, colour: Color) -> void:
	mesh.surface_set_color(colour)
	mesh.surface_add_vertex(a)
	mesh.surface_set_color(colour)
	mesh.surface_add_vertex(b)

## Where each meant to go, from the last second's record.
func draw_routes(planta: int) -> int:
	var chosen = null
	for entry in routes:
		if float(entry[0]) <= t: chosen = entry[1]
		else: break
	if chosen == null: return 0
	var count := 0
	for seat in chosen:
		var colour: Color = CREATURE if int(seat) == 0 else COLOURS[seats.find(int(seat)) % COLOURS.size()]
		var points: PackedVector3Array = chosen[seat].path
		var from: Vector3 = level.creature.global_position if int(seat) == 0 else (puppets[int(seat)].global_position if puppets.has(int(seat)) else Vector3.INF)
		for point in points:
			if from != Vector3.INF and FLOOR.planta_of(point.y) == planta:
				line(from + Vector3(0, 0.3, 0), point + Vector3(0, 0.3, 0), Color(colour, 0.45))
				count += 1
			from = point
	return count

## What there was to find: sets (lit or not), notes (taken or not), and the
## refuge of each stage; what the bots never saw, in magenta.
func draw_goals(planta: int, big: float) -> int:
	var missed := {}
	for incident in incidents:
		if String(incident.kind) == "no_encontrado": missed[String(incident.get("target", ""))] = true
	var count := 0
	for index in level.televisions.size():
		var set = level.televisions[index]
		if FLOOR.planta_of(set.global_position.y) != planta: continue
		var colour := Color(1, 0, 1) if missed.has("tv:%d" % index) else Color(0.3, 1.0, 0.3) if set.on else Color(1.0, 0.9, 0.2)
		mark(set.global_position, colour, 2.4 * big)
		count += 1
	for index in level.containers.size():
		var piece = level.containers[index]
		if int(piece.digit) < 0 or FLOOR.planta_of(piece.global_position.y) != planta: continue
		var colour := Color(1, 0, 1) if missed.has("note:%d" % index) else Color(0.3, 1.0, 0.3) if piece.searched else Color(1, 1, 1)
		mark(piece.global_position, colour, 2.0 * big)
		count += 1
	var refuges: Array = level.manifest.get("refuges", [])
	if planta < refuges.size():
		var room: Dictionary = level.manifest.rooms[int(refuges[planta])]
		var centre := FLOOR.position_of(room)
		var half := FLOOR.size_of(room) * 0.5
		var corners := [Vector3(-half.x, 0.2, -half.y), Vector3(half.x, 0.2, -half.y), Vector3(half.x, 0.2, half.y), Vector3(-half.x, 0.2, half.y)]
		for i in 4: line(centre + corners[i], centre + corners[(i + 1) % 4], Color(0.3, 0.8, 1.0))
		count += 4
	return count

func mark(point: Vector3, colour: Color, height: float) -> void:
	line(point, point + Vector3(0, height, 0), colour)
	line(point + Vector3(-0.3, 0.05, 0), point + Vector3(0.3, 0.05, 0), colour)
	line(point + Vector3(0, 0.05, -0.3), point + Vector3(0, 0.05, 0.3), colour)

## Every incident of this planta that has happened by now: a mast, and its
## words on top.
func draw_incidents(planta: int, big: float) -> int:
	for label in labels: label.visible = false
	var count := 0
	for i in incidents.size():
		var incident: Dictionary = incidents[i]
		if float(incident.t) > t: break
		var at := Vector3(incident.where[0], incident.where[1], incident.where[2])
		if FLOOR.planta_of(at.y) != planta: continue
		var colour: Color = SEVERITY.get(String(incident.severity), Color.GRAY)
		line(at, at + Vector3(0, 3.0 * big, 0), colour)
		count += 1
		if String(incident.severity) == "leve" and i != current_incident: continue
		labels[i].visible = true
		labels[i].global_position = at + Vector3(0, 3.2 * big, 0)
	return count

## One label per incident, made once; drawing only shows the ones of now.
func build_labels() -> void:
	for incident in incidents:
		var label := Label3D.new()
		label.text = "%s %s" % [clock_text(float(incident.t)), incident.kind]
		label.fixed_size = true
		label.pixel_size = 0.0012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.modulate = SEVERITY.get(String(incident.severity), Color.GRAY)
		label.outline_size = 8
		label.top_level = true
		label.visible = false
		add_child(label)
		labels.append(label)

## What the creature had its eye on, from the recording and not worked out
## again: a line to whoever it was hunting.
func draw_sight(planta: int) -> int:
	var i := clampi(times.bsearch(t, false) - 1, 0, times.size() - 1)
	var values: PackedFloat32Array = frames[i]
	var c := seats.size() * int(header.get("bot_fields", RECORDER.BOT_FIELDS))
	if c + 6 > values.size() or not is_instance_valid(level.creature): return 0
	var focus := int(values[c + 5])
	if focus < 0 or not puppets.has(focus): return 0
	var from: Vector3 = level.creature.eye_point()
	if FLOOR.planta_of(from.y) != planta: return 0
	line(from, puppets[focus].camera.global_position, Color(1, 0.1, 0.1, 0.9))
	return 1

static func clock_text(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]
