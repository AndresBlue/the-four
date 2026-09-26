extends SceneTree
## The trailer's shots, filmed in the game itself (docs/TRAILER.md): each one is
## staged on a real floor -- the creature and the survivors placed and moved by
## hand, no AI -- and filmed one frame at a time at FPS, every frame written to
## evidence/trailer/shots/<shot>/f_NNNN.png, with what happened when (for the
## sound) in events.json beside them.
##
##   godot --path . --rendering-method forward_plus --fixed-fps 30 --windowed --resolution 1920x1080 --script res://tools/trailer/shots.gd -- --automation --test-profile --silent --shot=<name> [--preview]
##
## --fixed-fps keeps the game's clock at exactly 1/FPS a frame however long a
## frame takes to draw, so everything moves as it would in real time.
## --preview: a third of the size and every third frame, to judge framing.
## --shot=looks renders the stills listed in evidence/trailer/looks.json, to
## try framings without writing a shot. tools/trailer/render.ps1 runs them all.
##
## Two ways of filming. Through our own camera (cine), which looks through the
## game's camcorder all the same -- its lens, its sensor, its tape -- but moves
## as a dolly would. Or through the survivor's own eyes (pov): the player's
## camera, hand-held, with its torch and its zoom, walked by the game itself.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const LOOK := preload("res://game/presentation/camcorder_look.gd")
const AVATAR := preload("res://game/player/avatars/avatar_visual.tscn")
const NOISE := preload("res://game/audio/noise_kinds.gd")
const INTRO := preload("res://game/intro/intro_sequence.gd")
const FPS := 30.0
const SIZE := Vector2i(1920, 1080)
const EYE := 1.64
var level
var cam: Camera3D
var shot_name := ""
var out_dir := ""
var preview := false
var written := 0
## What happened when, for the sound: [frame, what, data].
var events: Array = []
var frame_index := 0
var pov := false
## Survivors standing in for teammates: {node, avatar, torch}.
var extras: Array = []

func _initialize() -> void: run.call_deferred()

func arg(name: String, fallback := "") -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name): return argument.trim_prefix("--%s=" % name)
	return fallback

func run() -> void:
	shot_name = arg("shot", "scout")
	preview = OS.get_cmdline_user_args().has("--preview")
	out_dir = ProjectSettings.globalize_path("res://evidence/trailer/shots/%s%s" % [arg("tag", shot_name), "_preview" if preview else "_check" if not arg("frames").is_empty() else ""])
	DirAccess.make_dir_recursive_absolute(out_dir)
	for old in DirAccess.get_files_at(out_dir): DirAccess.remove_absolute(out_dir.path_join(old))
	var method := "shot_" + shot_name
	if not has_method(method):
		push_error("No such shot: " + shot_name)
		quit(1)
		return
	await call(method)
	var log := FileAccess.open(out_dir.path_join("events.json"), FileAccess.WRITE)
	if log: log.store_string(JSON.stringify({"shot": shot_name, "frames": written, "fps": FPS, "events": events}, "\t"))
	print("SHOT %s: %d frames" % [shot_name, written])
	if is_instance_valid(level): level.queue_free()
	await process_frame
	quit()

# --- The floor -----------------------------------------------------------------

## A floor built and made still: nobody moves unless a shot moves them.
func build(seed_value: int) -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(seed_value)
	# The settings put the window back to the project's size when they take it
	# out of fullscreen: the size is asked for once they have.
	await size_window()
	level.settings.values.osd = false
	level.settings.set_value("quality", 3)
	level.apply_settings()
	await level.bounce_ready()
	if is_instance_valid(level.director):
		level.director.set_process(false)
		level.director.set_physics_process(false)
	level.locust.set_physics_process(false)
	level.locust.position = Vector3(0, -80, 0)
	level.locust.grace = 0.0
	level.player.set_physics_process(false)
	level.player.handheld_enabled = false
	level.player.avatar.visible = false
	level.player.torch.visible = false
	level.ui.get_node("HUD").visible = false
	level.ui.hide_brief()
	# The floor's own rules stop: what the player is looking at (the reticle
	# and its word), the mind, the lifts, the creature's gate. The player's own
	# body still walks when a shot asks it to.
	level.set_physics_process(false)
	level.camcorder.focus("")
	cam = Camera3D.new()
	cam.name = "TrailerCamera"
	level.add_child(cam)
	# The local body lives on layer 2, hidden from the eyes it belongs to.
	cam.cull_mask &= ~2
	cam.near = 0.03
	cam.far = 300.0
	use_pov(false)

func size_window() -> void:
	var wanted := SIZE / 3 if preview else SIZE
	for attempt in 10:
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(wanted)
		await process_frame
		await process_frame
		if root.size == wanted: return
	push_warning("Window is %s, not %s" % [root.size, wanted])

## Filming through our own camera, or through the survivor's eyes.
func use_pov(on: bool) -> void:
	pov = on
	level.player.handheld_enabled = on
	level.player.avatar.visible = on
	if on:
		level.player.camera.current = true
		level.player.reset_handheld()
		# hotel_main writes the player's lens whenever the zoom moves: forget
		# what was last written so it writes it now.
		level.lens_zoom = -1.0
	else:
		cam.current = true
		lens(1.0)

## The camcorder's lens at a zoom, for our camera: the barrel it bends with,
## the field of view its centre keeps and the wider one it has to render.
func lens(zoom: float) -> void:
	var size := Vector2(root.size)
	var aspect := size.x / maxf(size.y, 1.0)
	var barrel: float = LOOK.barrel_for(zoom)
	level.lens_material.set_shader_parameter("barrel", barrel)
	level.lens_material.set_shader_parameter("scale", LOOK.corner_scale(aspect, barrel))
	cam.fov = LOOK.render_fov(aspect, LOOK.zoom_fov(zoom), barrel)
	# hotel_main writes the lens only when the player's zoom moves; it stays at 1.
	level.lens_zoom = 1.0
	level.lens_aspect = aspect

## Everything the floor keeps doing on its own that a staged shot must not
## have: the mind going, the rooms drawn round the eye.
func hold_still() -> void:
	level.player.sanity = 100.0
	level.player.stamina = maxf(level.player.stamina, 60.0)
	var viewing: Camera3D = root.get_camera_3d()
	var eye: Vector3 = viewing.global_position if viewing != null else level.player.global_position
	if not pov and cam != null and cam.current: level.player.global_position = cam.global_position - Vector3(0, EYE, 0)
	if frame_index % 3 == 0 or frame_index < 0:
		level.hotel.update_visibility(eye, level.settings.values.shadows, 0.0, false, FLOOR.planta_of(eye.y))

func place_camera(from: Vector3, at: Vector3, roll := 0.0) -> void:
	cam.global_position = from
	cam.look_at(at, Vector3.UP)
	if roll != 0.0: cam.rotate_object_local(Vector3.FORWARD, roll)

## The survivor's eyes: where the body stands, which way it faces and how far
## it looks up, under whatever the hand-held motion adds.
func place_eyes(feet: Vector3, yaw: float, pitch: float) -> void:
	level.player.global_position = feet
	level.player.rotation.y = yaw
	level.player.camera.rotation.x = pitch + level.player.handheld.x
	level.player.camera.position.y = EYE

static func yaw_to(from: Vector3, to: Vector3) -> float:
	return atan2(-(to.x - from.x), -(to.z - from.z))

static func pitch_to(from: Vector3, to: Vector3) -> float:
	var d := to - from
	return atan2(d.y, Vector2(d.x, d.z).length())

## A smooth 0..1 between two times.
static func ramp(t: float, from: float, to: float) -> float:
	return smoothstep(from, to, t)

## Hand-held drift for our own camera: slow, small, 1/f.
static func drift(t: float, lane: int) -> float:
	var value := 0.0
	var amplitude := 0.57
	var frequency := 0.5
	for octave in 3:
		var x := t * frequency + lane * 17.3 + octave * 5.1
		value += (sin(x) * 0.6 + sin(x * 2.17 + 1.3) * 0.4) * amplitude
		amplitude *= 0.5
		frequency *= 2.1
	return value

# --- The creature --------------------------------------------------------------

func creature() -> Node3D: return level.locust

## Puts the creature somewhere facing a way (yaw as the game's own: forward -Z).
func creature_at(point: Vector3, yaw: float) -> void:
	level.locust.global_position = point
	level.locust.rotation = Vector3(0, yaw, 0)

## Walks it: its body along, its legs stepping at that speed.
func creature_step(velocity: Vector3, delta: float) -> void:
	level.locust.global_position += velocity * delta
	level.locust.visual.move_velocity = velocity

func creature_rest() -> void:
	level.locust.visual.move_velocity = Vector3.ZERO

# --- Stand-ins for the other survivors -----------------------------------------

## A survivor that is not the player: the game's own avatar, with a torch.
func add_extra(character: int, at: Vector3, yaw: float, torch := true) -> Dictionary:
	var body := Node3D.new()
	level.add_child(body)
	body.global_position = at
	body.rotation.y = yaw
	var avatar = AVATAR.instantiate()
	avatar.character = character
	avatar.first_person = false
	body.add_child(avatar)
	var lamp: SpotLight3D = null
	if torch:
		lamp = level.player.torch.duplicate() as SpotLight3D
		lamp.top_level = true
		lamp.visible = true
		body.add_child(lamp)
	var extra := {"node": body, "avatar": avatar, "torch": lamp, "velocity": Vector3.ZERO, "pitch": -0.15}
	extras.append(extra)
	return extra

## Moves a stand-in one frame: body along, legs at that speed, torch in hand.
func extra_step(extra: Dictionary, velocity: Vector3, delta: float, face := Vector3.INF) -> void:
	var body: Node3D = extra.node
	body.global_position += velocity * delta
	var flat := Vector3(velocity.x, 0, velocity.z)
	if face != Vector3.INF: body.rotation.y = lerp_angle(body.rotation.y, yaw_to(body.global_position, face), minf(1.0, delta * 6.0))
	elif flat.length() > 0.2: body.rotation.y = lerp_angle(body.rotation.y, atan2(-flat.x, -flat.z), minf(1.0, delta * 6.0))
	extra.avatar.update_pose(velocity, false, delta, true)
	if extra.torch != null:
		var hand: Vector3 = body.global_position + body.global_basis * Vector3(0.24, 1.3, -0.25)
		var aim: Vector3 = body.global_position + body.global_basis * Vector3(0.0, 1.3 + sin(float(extra.pitch)) * 7.0, -7.0)
		extra.torch.global_transform = Transform3D(Basis.looking_at(aim - hand, Vector3.UP), hand)

# --- Filming -------------------------------------------------------------------

## Films `count` frames after `preroll` unrecorded ones (the camera's iris,
## the temporal smoothing and the motion blur need a history). `step` is called
## with the shot's time in seconds (negative during the preroll) before each
## frame is drawn.
## --frames=a,b,c keeps only those frames (and stops after the last), to look
## at a moment at full size without writing the whole shot.
func film(count: int, step: Callable, preroll := 45) -> void:
	var only: Array = []
	if not arg("frames").is_empty(): only = Array(arg("frames").split(",")).map(func(n): return int(n))
	if not only.is_empty(): count = mini(count, int(only.max()) + 1)
	level.camera_cut()
	for i in preroll + count:
		frame_index = i - preroll
		var t := float(frame_index) / FPS
		step.call(t)
		hold_still()
		await process_frame
		await RenderingServer.frame_post_draw
		if frame_index < 0: continue
		if not only.is_empty() and not only.has(frame_index): continue
		if only.is_empty() and preview and frame_index % 3 != 0: continue
		var image := root.get_texture().get_image()
		image.save_png(out_dir.path_join("f_%04d.png" % frame_index))
		written += 1

func mark(what: String, data := {}) -> void:
	events.append([frame_index, what, data])

# --- Scouting ------------------------------------------------------------------

## The long straight runs of corridor on a planta: [start room, direction,
## cells], longest first.
func corridor_runs(planta: int) -> Array:
	var rooms: Array = level.manifest.rooms
	var runs: Array = []
	for room in rooms:
		if int(room.get("wing", -1)) != planta or int(room.type) != 11: continue
		for way in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var back := FLOOR.beside(room, -way)
			if back >= 0 and int(rooms[back].type) == 11: continue
			var length := 1
			var next := FLOOR.beside(room, way)
			while next >= 0 and int(rooms[next].type) == 11:
				length += 1
				next = FLOOR.beside(rooms[next], way)
			if length >= 2: runs.append([int(room.id), way, length])
	runs.sort_custom(func(a, b): return a[2] > b[2])
	return runs

## Everything a shot might be set in, written to evidence/trailer/scout/<seed>.json:
## the rooms, the corridor runs, the sets, the wardrobes, the doors and the lifts.
func shot_survey() -> void:
	var seed_value := int(arg("seed", "81"))
	await build(seed_value)
	var data := {"rooms": [], "runs": {}, "tvs": [], "hides": [], "doors": [], "lifts": [], "arrivals": [], "exit": int(level.manifest.exit), "refuges": level.manifest.get("refuges", [])}
	for room in level.manifest.rooms:
		if FLOOR.is_void(room): continue
		data.rooms.append({"id": int(room.id), "type": int(room.type), "name": FLOOR.NAMES[int(room.type)], "wing": int(room.wing), "x": int(room.x), "z": int(room.z), "p": [room.px, room.get("py", 0.0), room.pz], "span": [room.get("span_x", 12.0), room.get("span_z", 12.0)], "dark": level.hotel.dark_room(room), "open_sides": room.get("open_sides", []), "doors": room.get("doors", []), "height": room.get("height", 3.0), "hall": int(room.get("hall", -1))})
	for planta in FLOOR.PLANTAS: data.runs[str(planta)] = corridor_runs(planta).map(func(r): return [r[0], [r[1].x, r[1].y], r[2]])
	for index in level.televisions.size():
		var set: Node3D = level.televisions[index]
		data.tvs.append({"index": index, "p": [set.global_position.x, set.global_position.y, set.global_position.z], "yaw": set.global_rotation.y, "room": int(FLOOR.room_at(level.manifest.rooms, set.global_position).get("id", -1))})
	for hide in level.hotel.hides:
		data.hides.append({"p": [hide.global_position.x, hide.global_position.y, hide.global_position.z], "yaw": hide.global_rotation.y, "room": int(FLOOR.room_at(level.manifest.rooms, hide.global_position).get("id", -1))})
	for door in level.hotel.doors:
		data.doors.append({"p": [door.doorway.x, door.doorway.y, door.doorway.z], "opened": door.opened})
	for lift in level.hotel.lifts: data.lifts.append([lift.x, lift.y, lift.z])
	for arrival in level.hotel.arrivals: data.arrivals.append([arrival.x, arrival.y, arrival.z])
	var file := FileAccess.open(ProjectSettings.globalize_path("res://evidence/trailer/scout/%d.json" % seed_value), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))
	print("SURVEY rooms %d tvs %d hides %d doors %d lifts %d" % [data.rooms.size(), data.tvs.size(), data.hides.size(), data.doors.size(), data.lifts.size()])

## The longest clear lines of sight at eye height from the middle of every
## corridor, gallery and hall, each drawn from both ends: stills of the best
## into evidence/trailer/scout/<seed>_lines/, the list printed.
func shot_lines() -> void:
	var seed_value := int(arg("seed", "81"))
	await build(seed_value)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var lines: Array = []
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or not int(room.type) in [0, 5, 6, 10, 11, 12, 18]: continue
		var centre := FLOOR.position_of(room) + Vector3(0, 1.5, 0)
		for way in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var ends := []
			for sgn in [1.0, -1.0]:
				var query := PhysicsRayQueryParameters3D.create(centre, centre + way * sgn * 200.0, 1)
				var hit := space.intersect_ray(query)
				ends.append(hit.position if not hit.is_empty() else centre + way * sgn * 200.0)
			var length: float = ends[0].distance_to(ends[1])
			lines.append([length, ends[1], ends[0], int(room.id), int(room.type), int(room.wing)])
	lines.sort_custom(func(a, b): return a[0] > b[0])
	var unique: Array = []
	for line in lines:
		if unique.any(func(u): return u[1].distance_to(line[1]) < 4.0 and u[2].distance_to(line[2]) < 4.0): continue
		unique.append(line)
		if unique.size() >= 14: break
	var dir := ProjectSettings.globalize_path("res://evidence/trailer/scout/%d_lines" % seed_value)
	DirAccess.make_dir_recursive_absolute(dir)
	for n in unique.size():
		var line: Array = unique[n]
		print("LINE %d  %.1f m  from %s to %s  room %d type %d planta %d" % [n, line[0], line[1], line[2], line[3], line[4], line[5]])
		var way: Vector3 = (line[2] - line[1]).normalized()
		place_camera(line[1] + way * 1.0, line[2])
		lens(1.0)
		level.camera_cut()
		for i in 30:
			hold_still()
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("line_%02d_%dm.png" % [n, int(line[0])]))

static func vec(value) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

## Stills from evidence/trailer/looks.json, all on one floor: each is
## {name, cam: [x,y,z], at: [x,y,z], zoom, osd, torch, locust: [x,y,z,yaw],
## look: [x,y,z], aggression, attack, duck, open: radius (doors round the
## camera opened), dark: true (the power out)}.
func shot_looks() -> void:
	var looks: Array = JSON.parse_string(FileAccess.get_file_as_string("res://evidence/trailer/looks.json"))
	var seed_value := int(arg("seed", "81"))
	await build(seed_value)
	var dir := ProjectSettings.globalize_path("res://evidence/trailer/looks")
	DirAccess.make_dir_recursive_absolute(dir)
	for look in looks:
		if int(look.get("seed", seed_value)) != seed_value: continue
		var from := vec(look.cam)
		lens(float(look.get("zoom", 1.0)))
		place_camera(from, vec(look.at), float(look.get("roll", 0.0)))
		level.settings.values.osd = bool(look.get("osd", false))
		level.player.torch.visible = bool(look.get("torch", false))
		if look.has("locust"):
			var spot: Array = look.locust
			creature_at(Vector3(spot[0], spot[1], spot[2]), float(spot[3]))
		else: creature_at(Vector3(0, -80, 0), 0.0)
		level.locust.visual.look_point = vec(look.look) if look.has("look") else Vector3.INF
		level.locust.visual.aggression = float(look.get("aggression", 0.0))
		level.locust.visual.attack = float(look.get("attack", 0.0))
		level.locust.visual.duck = float(look.get("duck", 0.0))
		if look.has("open"):
			for door in level.hotel.doors:
				if door.doorway.distance_to(from) < float(look.open) and not door.opened: door.set_state(true)
		if bool(look.get("dark", false)) != level.hotel.dark: level.hotel.blackout(bool(look.get("dark", false)))
		level.camera_cut()
		for i in 40:
			hold_still()
			if level.player.torch.visible: level.player.torch.global_transform = Transform3D(cam.global_basis, cam.global_position + cam.global_basis * Vector3(0.2, -0.25, -0.2))
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dir.path_join("%s.png" % look.name))
		print("LOOK ", look.name)

# --- The shots -----------------------------------------------------------------

## The welcome: a long corridor of the third planta, drawn as a camcorder
## sees it, the dolly creeping in. Far down it, where another corridor
## crosses, something walks out from behind the corner, stops in the middle,
## turns to the lens, stands, and goes on.
func shot_hall() -> void:
	await build(81)
	level.settings.values.osd = true
	var start := Vector3(-99.5, -10.45, 90.5)
	var z := 110.8
	lens(float(arg("zoom", "2.6")))
	await film(250, func(t: float) -> void:
		var tt := maxf(t, 0.0)
		var at := start + Vector3(0, 0, tt * 0.38)
		var aim := Vector3(-99.5, -10.62, 126.0) + Vector3(drift(tt, 0) * 0.3, drift(tt, 1) * 0.16, 0)
		place_camera(at + Vector3(drift(tt, 2) * 0.02, drift(tt, 3) * 0.015, 0), aim, drift(tt, 4) * 0.004)
		# Out from behind the left-hand corner to the middle...
		var x := -99.3
		var yaw := -PI / 2
		var speed := 0.0
		if tt < 4.2:
			var walk := clampf((tt - 2.3) / 1.9, 0.0, 1.0)
			x = lerpf(-104.2, -99.3, walk)
			speed = 4.9 / 1.9 if walk > 0.0 and walk < 1.0 else 0.0
		# ...round to the lens, standing...
		var face := ramp(tt, 4.2, 4.75) * (1.0 - ramp(tt, 6.0, 6.5))
		yaw = lerp_angle(-PI / 2, yaw_to(Vector3(x, 0, z), at), face)
		# ...and on, out of sight on the right.
		if tt >= 6.35:
			var on := clampf((tt - 6.35) / 1.7, 0.0, 1.0)
			x = lerpf(-99.3, -94.9, on)
			speed = 4.4 / 1.7 if on < 1.0 else 0.0
		creature_at(Vector3(x, -12.0, z), yaw)
		level.locust.visual.move_velocity = Vector3(speed, 0, 0)
		level.locust.visual.look_point = Vector3(x + 6.0, -10.0, z).lerp(at, clampf(face * 1.3, 0.0, 1.0))
		if frame_index == int(2.3 * FPS): mark("cross")
		if frame_index == int(4.3 * FPS): mark("stare"))

## Rule one's answer: the creature in the corridor, side-on, listening to the
## wall; the head snaps round -- it has heard -- the body follows, and it comes.
func shot_listen() -> void:
	await build(81)
	var feet := Vector3(-99.3, -12.0, 96.5)
	var eye := Vector3(-100.1, -10.95, 92.6)
	lens(float(arg("zoom", "3.0")))
	await film(110, func(t: float) -> void:
		var tt := maxf(t, 0.0)
		var come := ramp(tt, 2.2, 3.6)
		var at := feet + (eye - feet) * Vector3(1, 0, 1) * come * 0.22
		place_camera(eye + Vector3(drift(tt, 0) * 0.012, drift(tt, 1) * 0.01, 0), at + Vector3(0.05, 1.95 - come * 0.1, 0) + Vector3(drift(tt, 2) * 0.04, drift(tt, 3) * 0.03, 0))
		var turn := ramp(tt, 1.3, 2.1)
		creature_at(at, lerp_angle(PI / 2 + 0.3, yaw_to(feet, eye), turn))
		level.locust.visual.move_velocity = (eye - feet).normalized() * Vector3(1, 0, 1) * 1.3 * (1.0 if come > 0.0 and come < 1.0 else 0.0)
		level.locust.visual.aggression = ramp(tt, 1.9, 3.0) * 0.7
		var snap := ramp(tt, 0.9, 1.05)
		var wall := at + Vector3(-3.0, 1.7 + sin(tt * 2.3) * 0.12, 0.8)
		level.locust.visual.look_point = wall.lerp(eye, snap)
		if frame_index == int(0.9 * FPS): mark("snap"))

## The montage's charge: down a corridor at the lens, blades up, too close.
func shot_charge() -> void:
	await build(81)
	var eye := Vector3(-58.0, -11.2, 41.0)
	lens(float(arg("zoom", "1.35")))
	await film(54, func(t: float) -> void:
		var tt := maxf(t, 0.0)
		var z := 53.5 - tt * 7.0
		var near := 1.0 - clampf((z - 43.4) / 10.0, 0.0, 1.0)
		var shake := near * near * 0.05
		place_camera(eye + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.4, Vector3(-58.0, -10.6 + near * 0.5, 60.0) + Vector3(drift(tt * 3.0, 0), drift(tt * 3.0, 1), 0) * 0.06)
		creature_at(Vector3(-58.0, -12.0, maxf(z, 43.4)), 0.0)
		level.locust.visual.move_velocity = Vector3(0, 0, -7.0) if z > 43.4 else Vector3.ZERO
		level.locust.visual.aggression = 1.0
		level.locust.visual.attack = ramp(tt, 1.35, 1.6)
		level.locust.visual.look_point = eye
		if frame_index == 0: mark("charge"), 20)

## Rule one: running down a corridor through the survivor's own eyes, the
## camcorder bouncing with every stride.
func shot_run() -> void:
	await build(81)
	level.settings.values.osd = true
	use_pov(true)
	var from := Vector3(-58.0, -12.0 + 0.04, 79.0)
	level.player.global_position = from
	level.player.rotation.y = 0.0
	level.player.torch.visible = true
	level.player.active = true
	level.player.set_physics_process(true)
	var started := false
	var last_step := -1
	await film(100, func(t: float) -> void:
		var step := floori(level.player.step_phase / PI)
		if step != last_step:
			if last_step >= 0 and frame_index >= 0: mark("step")
			last_step = step
		if t >= -1.0 and not started:
			started = true
			Input.action_press("forward")
			Input.action_press("sprint")
		var here: Vector3 = level.player.global_position
		# Held to the middle of the corridor, looking a little down its length.
		var wanted := yaw_to(here, Vector3(-58.0, here.y, here.z - 10.0))
		level.player.rotation.y = lerp_angle(level.player.rotation.y, wanted, 0.1)
		level.player.camera.rotation.x = -0.06 + level.player.handheld.x, 30)
	Input.action_release("forward")
	Input.action_release("sprint")

## Rule two: a dark television room, the torch finding the set, and the set
## coming to life -- the dead channel lighting the room.
func shot_tv_on() -> void:
	await build(81)
	level.settings.values.osd = true
	var index := int(arg("tv", "5"))
	var set: Node3D = level.televisions[index]
	var screen: Vector3 = set.screen_point()
	var yaw: float = set.global_rotation.y
	var front := Vector3(sin(yaw), 0, cos(yaw))
	level.hotel.blackout(true)
	use_pov(true)
	level.player.torch.visible = true
	var start := set.global_position + front * 3.1
	start.y = FLOOR.planta_y(FLOOR.planta_of(set.global_position.y)) + 0.04
	var switched := false
	await film(100, func(t: float) -> void:
		var tt := maxf(t, 0.0)
		var feet := start - front * ramp(tt, -1.0, 2.2) * 0.9
		var look := screen + Vector3(0.25 * (1.0 - ramp(tt, 0.0, 0.9)), -0.15, 0)
		place_eyes(feet, yaw_to(feet, look), pitch_to(feet + Vector3(0, EYE, 0), look))
		if tt >= 1.0 and not switched:
			switched = true
			level.apply_television(index, true)
			mark("tv_on"))

## Our camera, close on the opening scene's set.
func intro_camera(distance: float, zoom: float) -> void:
	cam = Camera3D.new()
	cam.name = "TrailerCamera"
	level.add_child(cam)
	cam.near = 0.02
	cam.current = true
	lens(zoom)
	var screen: Vector3 = level.intro.to_global(INTRO.SCREEN)
	place_camera(level.intro.to_global(INTRO.SCREEN + Vector3(0.06, 0.02, -distance)), screen)

## Rule two's answer: that set, close, the creature leaning in out of the
## picture and lunging at the glass.
func shot_tv_locust() -> void:
	var distance := 0.86
	await intro_from(22.5, 100, func(t: float) -> void:
		var screen: Vector3 = level.intro.to_global(INTRO.SCREEN)
		place_camera(level.intro.to_global(INTRO.SCREEN + Vector3(0.06 - t * 0.01, 0.02, -distance + t * 0.07)), screen + Vector3(drift(t, 0), drift(t, 1), 0) * 0.01)
		if frame_index == int((25.2 - 22.5) * FPS): mark("lunge"),
		func() -> void: intro_camera(distance, 1.6))

## The montage: a blow on that glass, close.
func shot_intro_glass() -> void:
	await intro_from(29.6, 36, func(t: float) -> void:
		if frame_index == int((30.0 - 29.6) * FPS): mark("blow"),
		func() -> void: intro_camera(0.8, 1.5))

## The montage: the door slammed on it, through the scene's own eyes.
func shot_intro_slam() -> void:
	await intro_from(33.1, 45, func(t: float) -> void:
		if frame_index == int((33.62 - 33.1) * FPS): mark("slam")
		if frame_index == int((33.85 - 33.1) * FPS): mark("glass"))

## What the opening scene has to offer, one frame every tenth of a second.
func shot_intro_scan() -> void:
	preview = true
	await intro_from(16.0, 540)

## The opening scene, as the game plays it, from `from` for `count` frames:
## fast-forwarded there first (its own events fire on the way, as they would).
func intro_from(from: float, count: int, step := Callable(), setup := Callable()) -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await size_window()
	level.settings.set_value("quality", 3)
	level.apply_settings()
	level.start_intro(81)
	var intro = level.intro
	intro.speed = 4.0
	while intro.time < from - 1.5: await process_frame
	intro.speed = 1.0
	while intro.time < from - 0.02: await process_frame
	level.ui.get_node("HUD").visible = false
	if setup.is_valid(): setup.call()
	for i in count:
		frame_index = i
		if step.is_valid(): step.call(float(i) / FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		if preview and i % 3 != 0: continue
		root.get_texture().get_image().save_png(out_dir.path_join("f_%04d.png" % i))
		written += 1

## Rule three: from inside a wardrobe -- the doors pulled shut on a lit
## bedroom, the dark with its slits of light; then eased open a crack, and the
## creature walks in, crosses the room and stops, and turns its head to the
## wardrobe.
func shot_hide() -> void:
	await build(81)
	level.settings.values.osd = true
	var hide = get_nodes_in_group("hotel_hides")[int(arg("hide", "2"))]
	var front: Vector3 = (hide.to_global(Vector3(0, 0, 1)) - hide.global_position).normalized()
	var floor_y := FLOOR.planta_y(FLOOR.planta_of(hide.global_position.y))
	# The room's way in: the nearest door to the wardrobe.
	var door = null
	for candidate in level.hotel.doors:
		if absf(candidate.doorway.y - floor_y) > 1.0: continue
		if door == null or candidate.doorway.distance_to(hide.global_position) < door.doorway.distance_to(hide.global_position): door = candidate
	door.set_state(true)
	var inside_room: Vector3 = hide.global_position + front * 2.2
	var through: Vector3 = (inside_room - door.doorway) * Vector3(1, 0, 1)
	var entry: Vector3 = door.doorway - through.normalized() * 1.2
	entry.y = floor_y
	var stop: Vector3 = hide.global_position + front * 2.0
	stop.y = floor_y
	print("HIDE door %s entry %s stop %s" % [door.doorway, entry, stop])
	use_pov(true)
	level.player.active = true
	level.player.set_physics_process(true)
	level.player.enter_hide(hide)
	level.player.peek = 1.0
	Input.action_press("forward")
	var yaw0: float = level.player.hide_yaw
	var path_len := entry.distance_to(stop)
	await film(170, func(t: float) -> void:
		var tt := maxf(t, 0.0)
		# Shut at 0.3 s, a crack open again from 1.25 s.
		if tt >= 0.3 and tt < 1.25: Input.action_release("forward")
		elif tt >= 1.25: Input.action_press("forward")
		# The head turns towards where it comes in, then follows it.
		var watch: float = lerp_angle(yaw0, yaw_to(level.player.global_position, entry), 0.35 * ramp(tt, 1.5, 2.3))
		level.player.rotation.y = watch
		level.player.camera.rotation.x = -0.05 + level.player.handheld.x
		var walk := clampf((tt - 1.6) / (path_len / 1.35), 0.0, 1.0)
		var at: Vector3 = entry.lerp(stop, walk)
		var facing := yaw_to(entry, stop)
		var turn := ramp(tt, 3.6, 4.1)
		creature_at(at if tt >= 1.6 else Vector3(0, -80, 0), lerp_angle(facing, yaw_to(stop, hide.global_position), turn * 0.6))
		level.locust.visual.move_velocity = (stop - entry).normalized() * 1.35 if walk > 0.0 and walk < 1.0 else Vector3.ZERO
		level.locust.visual.look_point = at + (stop - entry).normalized() * 4.0 + Vector3(0, 1.6, 0) if turn <= 0.0 else (at + (stop - entry).normalized() * 4.0 + Vector3(0, 1.6, 0)).lerp(hide.global_position + Vector3(0, 1.4, 0), turn)
		level.locust.visual.hunch = 0.0
		if frame_index == int(0.3 * FPS): mark("shut")
		if frame_index == int(1.25 * FPS): mark("crack")
		if frame_index == int(3.7 * FPS): mark("look"))
	Input.action_release("forward")

## Candidate doorways for the head round a jamb (game/app/phantom_sight.gd):
## stills of every one the game itself would accept, from 11 to 18 m.
func shot_phantom_scout() -> void:
	await build(81)
	use_pov(true)
	var sight = level.sanity.ensure_sight()
	sight.set_physics_process(false)
	sight.ensure_model()
	var dir := ProjectSettings.globalize_path("res://evidence/trailer/scout/phantom")
	DirAccess.make_dir_recursive_absolute(dir)
	var camera: Camera3D = level.player.camera
	var found := 0
	for door in level.hotel.doors:
		if found >= 10: break
		for room in level.manifest.rooms:
			if FLOOR.is_void(room) or not bool(room.get("corridor", false)) and not int(room.type) in [5, 10, 12, 18]: continue
			var centre := FLOOR.position_of(room)
			if absf(centre.y - door.doorway.y) > 1.0: continue
			var gap := centre.distance_to(door.doorway)
			if gap < 11.0 or gap > 18.0: continue
			door.set_state(true)
			var feet: Vector3 = FLOOR.closest(level.get_world_3d().navigation_map, centre) + Vector3(0, 0.04, 0)
			place_eyes(feet, yaw_to(feet, door.doorway), pitch_to(feet + Vector3(0, EYE, 0), door.doorway + Vector3(0, 1.9, 0)))
			await process_frame
			if not sight.place_peek(door, camera): continue
			sight.model.visible = true
			sight.pose(1.0)
			found += 1
			level.camera_cut()
			for i in 30:
				hold_still()
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(dir.path_join("peek_%02d.png" % found))
			print("PEEK %d door %s feet %s" % [found, door.doorway, feet])
			sight.model.visible = false
			sight.kind = ""
			break

## Rule four: something round the jamb of a far doorway, the head and the neck
## only, leaning out slowly while the camcorder holds on it -- and the tape
## tears, and nothing is there.
func shot_phantom() -> void:
	await build(81)
	level.settings.values.osd = true
	use_pov(true)
	var sight = level.sanity.ensure_sight()
	sight.set_physics_process(false)
	sight.ensure_model()
	var door_at := vec(arg("door", "11.0,0,-30.5").split(","))
	var feet := vec(arg("feet", "9.25,0.24,-37.5").split(","))
	var door = null
	for candidate in level.hotel.doors:
		if door == null or candidate.doorway.distance_to(door_at) < door.doorway.distance_to(door_at): door = candidate
	door.set_state(true)
	var camera: Camera3D = level.player.camera
	place_eyes(feet, yaw_to(feet, door.doorway), pitch_to(feet + Vector3(0, EYE, 0), door.doorway + Vector3(0, 1.9, 0)))
	await process_frame
	var placed: bool = sight.place_peek(door, camera)
	var head: Vector3 = sight.face_point
	print("PHANTOM placed %s head %s" % [placed, head])
	var gone := false
	level.player.zoom = 1.3
	level.player.zoom_wanted = 1.3
	await film(165, func(t: float) -> void:
		var tt := maxf(t, 0.0)
		# The camcorder finds the doorway and the zoom goes in on it.
		var look: Vector3 = head.lerp(door.doorway + Vector3(0, 1.6, 0), 1.0 - ramp(tt, 0.2, 1.4)) + Vector3(0, -0.22, 0)
		place_eyes(feet, yaw_to(feet, look), pitch_to(feet + Vector3(0, EYE, 0), look))
		if frame_index == int(0.5 * FPS): level.player.zoom_wanted = float(arg("zoom", "3.4"))
		if tt < 4.4:
			sight.model.visible = true
			sight.seen_for = tt
			sight.pose(ramp(tt, 1.3, 2.8))
		elif not gone:
			gone = true
			sight.model.visible = false
			mark("vanish")
		if frame_index == int(1.3 * FPS): mark("peek"))
## Together: close behind two teammates walking down a corridor, torches up,
## what playing it together looks like.
func shot_together() -> void:
	await build(81)
	var z := 39.5
	var y := -12.0
	var walkers := [add_extra(1, Vector3(-60.2, y, z - 0.5), PI / 2), add_extra(2, Vector3(-61.3, y, z + 0.55), PI / 2)]
	var eye := Vector3(-58.4, y + 1.42, z + 0.05)
	lens(1.55)
	await film(110, func(t: float) -> void:
		var tt := maxf(t, -1.5)
		var dt := 1.0 / FPS
		for n in walkers.size():
			var w: Dictionary = walkers[n]
			w.pitch = -0.12 + sin(tt * 0.9 + n * 1.7) * 0.06
			var sway := Vector3(0, 0, sin(tt * 0.6 + n * 2.0) * 0.12)
			var looking: Vector3 = w.node.global_position + Vector3(-7.0, 0, sin(tt * 0.7 + n * 2.3) * 2.6)
			extra_step(w, Vector3(-1.2, 0, 0) + sway, dt, looking)
		eye += Vector3(-1.2, 0, 0) * dt
		var at := eye + Vector3(drift(tt, 0) * 0.03, drift(tt, 1) * 0.02 + sin(tt * 3.6) * 0.01, drift(tt, 2) * 0.03)
		place_camera(at, Vector3(eye.x - 8.0, y + 1.3, z + drift(tt, 3) * 0.3), drift(tt, 4) * 0.01), 60)
## The shared sheet: the plan drawing itself as the survivors see, their
## pencils on it in four colours, the pages of the code hanging beside.
func shot_sheet() -> void:
	await build(81)
	level.player.set_physics_process(false)
	var refuge := int(level.manifest.refuges[0])
	var metres := FLOOR.route_metres(level.manifest, refuge)
	var at := FLOOR.entry_of(level.manifest, 0)
	var route: Array = []
	var walked := 0
	while at != refuge and walked < 60:
		walked += 1
		route.append(at)
		var best := at
		for other in level.manifest.adjacency[at]:
			if float(metres.get(int(other), INF)) < float(metres.get(best, INF)): best = int(other)
		if best == at: break
		at = best
	# The first part of the way already seen, some of it a while ago.
	var seen_before := int(route.size() * 0.55)
	for n in seen_before:
		level.player.global_position = FLOOR.position_of(level.manifest.rooms[route[n]]) + Vector3(0, 0.04, 0)
		for turn in 8:
			level.player.rotation.y = TAU * turn / 8.0
			await physics_frame
			level.floor_map.look_now()
		level.floor_map.clock += 6.0
	for slot in range(1, 5):
		level.found_digits[slot] = [4, 7, 1, 9][slot - 1]
		level.found_by[slot] = level.player.slot
		level.found_where[slot] = ["HABITACIÓN 214", "LAVANDERÍA", "SUITE 301", "OFICINA"][slot - 1]
	level.toggle_sheet()
	var sheet = level.ui.sheet
	# Other hands, already on the plan: a ring round the refuge, a cross on a
	# room, an arrow; and the code being worked out at the side.
	var refuge_at := FLOOR.position_of(level.manifest.rooms[refuge])
	var ring := PackedVector2Array()
	for k in 40: ring.append(Vector2(refuge_at.x, refuge_at.z) + Vector2(cos(k * TAU / 38.0), sin(k * TAU / 38.0)) * Vector2(9.0, 7.5))
	var planta_kind: int = sheet.MAP_KIND + 0 * 2
	sheet.apply_confirmed("3:1", planta_kind, ring)
	var cross_at := FLOOR.position_of(level.manifest.rooms[route[int(route.size() * 0.3)]])
	sheet.apply_confirmed("4:1", planta_kind, PackedVector2Array([Vector2(cross_at.x - 4, cross_at.z - 4), Vector2(cross_at.x + 4, cross_at.z + 4)]))
	sheet.apply_confirmed("4:2", planta_kind, PackedVector2Array([Vector2(cross_at.x + 4, cross_at.z - 4), Vector2(cross_at.x - 4, cross_at.z + 4)]))
	var remaining: Array = route.slice(seen_before)
	var step_room := 0
	var pen := PackedVector2Array()
	var entry_at := FLOOR.position_of(level.manifest.rooms[route[0]])
	await film(100, func(t: float) -> void:
		# Walking on, still looking: the walls come onto the page as they do in play.
		if frame_index >= 0 and frame_index % 6 == 0 and step_room < remaining.size():
			level.player.global_position = FLOOR.position_of(level.manifest.rooms[remaining[step_room]]) + Vector3(0, 0.04, 0)
			step_room += 1
		level.player.rotation.y += 0.9
		level.floor_map.tick(1.0 / FPS)
		level.floor_map.look_now()
		# And a hand drawing the way: a line from the way in towards the refuge.
		if frame_index >= 6 and frame_index % 2 == 0 and frame_index < 76:
			var k := float(frame_index - 6) / 70.0 * float(route.size() - 1)
			var n := mini(int(k), route.size() - 2)
			var a := FLOOR.position_of(level.manifest.rooms[route[n]])
			var b := FLOOR.position_of(level.manifest.rooms[route[n + 1]])
			var spot := a.lerp(b, k - n)
			var p := Vector2(spot.x, spot.z)
			pen.append(p + Vector2(sin(k * 7.0) * 0.6, cos(k * 5.0) * 0.6))
			if pen.size() >= 2: sheet.apply_confirmed("2:1", planta_kind, PackedVector2Array([pen[pen.size() - 2], pen[pen.size() - 1]]))
		if frame_index == 6: mark("pencil"))

## Versus: through the creature's ears. Its acoustic reading of a corridor, a
## survivor running away in it as a cloud of echoes, each step a burst; it
## shrieks, the reading floods red, and it goes.
func shot_versus() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.take_locust(81)
	await size_window()
	level.settings.set_value("quality", 3)
	level.apply_settings()
	level.locust.driver.set_process_unhandled_input(false)
	if is_instance_valid(level.director): level.director.set_process(false)
	level.ui.get_node("HUD").visible = false
	level.player.set_physics_process(false)
	pov = true
	var echo = level.locust.driver.echo
	# A chase down a corridor: the survivor ahead, running; the creature
	# behind, keeping its distance, clicking; it shrieks and closes.
	var start := Vector3(-58.0, -12.0 + 0.04, 39.0)
	var lead := 9.0
	var last_step := -1
	var creature_z := start.z
	var runner_z := start.z + lead
	await film(170, func(t: float) -> void:
		var dt := 1.0 / FPS
		var running := t > 0.0
		var runner_speed := 4.3 if running else 0.0
		var hunt_speed := 4.0 if t < 2.6 else 6.6
		if not running: hunt_speed = 0.0
		runner_z += runner_speed * dt
		creature_z = minf(creature_z + hunt_speed * dt, runner_z - 4.5)
		level.locust.global_position = Vector3(start.x, start.y, creature_z)
		level.locust.rotation = Vector3(0, PI, 0)
		level.locust.driver.pitch = -0.1
		var body_at := Vector3(start.x + sin(t * 1.3) * 0.25, start.y, runner_z)
		level.player.global_position = body_at
		level.player.rotation.y = PI
		level.player.avatar.update_pose(Vector3(0, 0, runner_speed), false, dt, true)
		# Its steps, heard: small bursts at its feet, every other stride (a run's
		# full noise is a burst the size of the corridor, and hid the body).
		var step := int(runner_z / 3.0)
		if running and step != last_step:
			last_step = step
			level.on_noise(body_at, NOISE.radius("walk") * 0.5, NOISE.Kind.FOOTSTEP)
		if frame_index == int(2.6 * FPS):
			echo.flash_shriek()
			mark("shriek"), 100)
## The montage: the power goes, all at once, down a lit corridor.
func shot_blackout() -> void:
	await build(81)
	level.settings.values.osd = true
	use_pov(true)
	level.player.torch.visible = true
	var feet := Vector3(-59.5, -12.0 + 0.04, 39.5)
	var ahead := Vector3(-100.0, -10.5, 39.5)
	await film(50, func(t: float) -> void:
		place_eyes(feet, yaw_to(feet, ahead) + drift(t, 0) * 0.01, pitch_to(feet + Vector3(0, EYE, 0), ahead))
		if frame_index == 14:
			level.apply_blackout()
			mark("blackout"))

## The montage's end: caught. Through the victim's eyes: lifted, the mask
## coming in, the arm, and the picture gone.
func shot_kill() -> void:
	await build(81)
	level.set_physics_process(true)
	use_pov(true)
	level.player.active = true
	var spot := Vector3(-112.0, -6.0 + 0.04, -29.5)
	level.player.global_position = spot
	level.player.rotation.y = yaw_to(spot, spot + Vector3(-1, 0, 0))
	creature_at(spot + Vector3(-1.6, 0.04, 0), yaw_to(spot + Vector3(-1.6, 0, 0), spot))
	await film(115, func(t: float) -> void:
		level.camcorder.focus("")
		if frame_index == 0:
			level.locust.set_physics_process(true)
			level.locust.face_toward(spot, 1.0, 100.0)
			level.capture_survivor(level.player)
			mark("grab"), 20)

## Piso 1 of 4: the floor indicator over a lift, brass and four lamps; the
## first one burning, and -- "quedan tres" -- the other three coming on, each
## wrong in its own way, and all of them going out.
func shot_floors() -> void:
	await build(81)
	var car: Vector3 = level.hotel.lifts[0]
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var out := Vector3.ZERO
	var reach := 0.0
	for way in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(car + Vector3(0, 1.2, 0), car + Vector3(0, 1.2, 0) + way * 30.0, 1))
		var d: float = car.distance_to(hit.position) if not hit.is_empty() else 30.0
		if d > reach:
			reach = d
			out = way
	# The car is a box standing free in its lobby (hotel_geometry.build_car,
	# CAR 2.6 x 2.45 x 2.3), open to the front: the indicator stands on the
	# front edge of its roof, facing the lobby.
	var top: Vector3 = car + out * (2.3 * 0.5 + 0.02) + Vector3(0, 2.45 + 0.26, 0)
	print("FLOORS car %s out %s panel %s" % [car, out, top])
	var panel := Node3D.new()
	level.add_child(panel)
	panel.global_position = top
	panel.look_at(panel.global_position - out, Vector3.UP)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.52, 0.38, 0.17)
	brass.metallic = 1.0
	brass.roughness = 0.32
	var plate := StandardMaterial3D.new()
	plate.albedo_color = Color(0.05, 0.045, 0.04)
	plate.metallic = 0.6
	plate.roughness = 0.25
	var frame_mesh := MeshInstance3D.new()
	var frame_box := BoxMesh.new()
	frame_box.size = Vector3(1.34, 0.38, 0.03)
	frame_mesh.mesh = frame_box
	frame_mesh.material_override = brass
	panel.add_child(frame_mesh)
	var face := MeshInstance3D.new()
	var face_box := BoxMesh.new()
	face_box.size = Vector3(1.26, 0.3, 0.02)
	face.mesh = face_box
	face.material_override = plate
	face.position = Vector3(0, 0, 0.018)
	panel.add_child(face)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Perpetua Titling MT", "Perpetua", "Georgia"])
	var lamps: Array = []
	for n in 4:
		var x := -0.45 + n * 0.3
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.085
		torus.outer_radius = 0.105
		ring.mesh = torus
		ring.material_override = brass
		ring.rotation = Vector3(PI / 2, 0, 0)
		ring.position = Vector3(x, 0, 0.03)
		panel.add_child(ring)
		var glass := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.086
		disc.bottom_radius = 0.086
		disc.height = 0.01
		glass.mesh = disc
		var lit := StandardMaterial3D.new()
		lit.albedo_color = Color(0.1, 0.08, 0.06)
		lit.emission_enabled = true
		lit.emission = Color(0, 0, 0)
		lit.roughness = 0.2
		glass.material_override = lit
		glass.rotation = Vector3(PI / 2, 0, 0)
		glass.position = Vector3(x, 0, 0.03)
		panel.add_child(glass)
		var digit := Label3D.new()
		digit.text = str(n + 1)
		digit.font = font
		digit.font_size = 128
		digit.pixel_size = 0.0011
		digit.position = Vector3(x, -0.004, 0.038)
		digit.modulate = Color(0.08, 0.07, 0.06)
		digit.outline_size = 0
		digit.shaded = false
		panel.add_child(digit)
		var bulb := OmniLight3D.new()
		bulb.position = Vector3(x, 0, 0.25)
		bulb.omni_range = 1.6
		bulb.light_energy = 0.0
		bulb.shadow_enabled = false
		panel.add_child(bulb)
		lamps.append({"glass": lit, "digit": digit, "bulb": bulb})
	# The lamps: the first warm; the others cold, sick and red.
	var colours := [Color(1.0, 0.62, 0.26), Color(0.55, 0.75, 1.0), Color(0.55, 1.0, 0.45), Color(1.0, 0.15, 0.1)]
	var eye: Vector3 = panel.global_position + out * 1.9 - Vector3(0, 0.95, 0) + out.cross(Vector3.UP) * 0.2
	lens(float(arg("zoom", "2.3")))
	await film(170, func(t: float) -> void:
		var tt := maxf(t, 0.0)
		place_camera(eye - out * tt * 0.055 + Vector3(drift(tt, 0) * 0.01, drift(tt, 1) * 0.008, 0), panel.global_position + Vector3(drift(tt, 2) * 0.02, -0.02 + drift(tt, 3) * 0.015, 0))
		for n in 4:
			var level_n := 0.0
			if n == 0: level_n = 1.0
			else:
				var on_at: float = [0.0, 3.35, 3.62, 3.9][n]
				if tt >= on_at:
					level_n = 0.55 + 0.45 * (1.0 if fmod(tt * (7.0 + n * 3.3), 1.0) > 0.18 else 0.2)
					if tt < on_at + 0.12 and fmod(tt * 60.0, 2.0) <= 1.0: level_n = 0.0
			if tt >= 4.75: level_n *= 0.0 if fmod(tt * 23.0, 1.0) < 0.5 or tt > 4.95 else 0.6
			var c: Color = colours[n]
			lamps[n].glass.emission = c * level_n * 2.6
			lamps[n].glass.emission_energy_multiplier = 1.0
			lamps[n].digit.modulate = Color(0.3, 0.24, 0.13).lerp(Color(0.1, 0.06, 0.04), clampf(level_n * 1.6, 0.0, 1.0))
			lamps[n].bulb.light_color = c
			lamps[n].bulb.light_energy = level_n * 0.6
		for n in 3:
			if frame_index == int([3.35, 3.62, 3.9][n] * FPS): mark("lamp", {"n": n + 2})
		if frame_index == int(4.75 * FPS): mark("out"))

## The tape starting: the game's own first seconds -- the headphones notice
## on black, the VCR blue with PLAY and the picture breaking up -- as it plays
## them (hotel_ui.play_intro), every frame.
func shot_boot() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await size_window()
	level.ui.play_intro()
	for i in 250:
		frame_index = i
		await process_frame
		await RenderingServer.frame_post_draw
		if preview and i % 3 != 0: continue
		root.get_texture().get_image().save_png(out_dir.path_join("f_%04d.png" % i))
		written += 1
## The title: the menu's own room (game/title/title_scene.gd), the camera
## creeping towards the door left ajar at the back, where it leans into the
## gap and watches; its head tilts once, suddenly.
func shot_title() -> void:
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await process_frame
	await size_window()
	level.settings.set_value("quality", 3)
	level.apply_settings()
	level.ui.finish_intro()
	level.ui.overlay.hide()
	var title = level.title_scene
	title.set_process(false)
	var room_cam: Camera3D = title.camera
	var from: Vector3 = title.CAMERA_AT + Vector3(0.3, 0.0, 0.2)
	var to: Vector3 = title.CAMERA_AT + Vector3(1.55, 0.05, -1.9)
	var aim: Vector3 = title.DOORWAY + Vector3(-0.35, 1.72, -0.2)
	var twitched := false
	for i in 45 + 150:
		frame_index = i - 45
		var t := maxf(float(frame_index) / FPS, 0.0)
		var k := ease(clampf(t / 5.0, 0.0, 1.0), 0.6)
		room_cam.position = from.lerp(to, k) + Vector3(sin(t * 0.7) * 0.01, sin(t * 1.1) * 0.006, 0)
		room_cam.fov = LOOK.fov_for(root, lerpf(50.0, 30.0, k))
		room_cam.look_at(title.global_transform * (aim + Vector3(sin(t * 0.4) * 0.03, sin(t * 0.6) * 0.015, 0)))
		# The head: still, then the sudden tilt at 3.95 s, eased back.
		title.twitch = 0.0
		if t >= 3.95:
			if not twitched:
				twitched = true
				mark("twitch")
			title.twitch = maxf(0.0, 1.0 - (t - 3.95) * 1.2)
		title.twitch_sign = 1.0
		title.clock = 8.0 + t
		title.pose_locust(0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame_index < 0: continue
		if preview and frame_index % 3 != 0: continue
		root.get_texture().get_image().save_png(out_dir.path_join("f_%04d.png" % frame_index))
		written += 1
## The montage: in the dark, in the torch, the blades going up -- too close.
func shot_strike() -> void:
	await build(81)
	level.hotel.blackout(true)
	level.settings.values.osd = true
	use_pov(true)
	level.player.torch.visible = true
	var feet := Vector3(-58.0, -12.0 + 0.04, 44.0)
	var monster := Vector3(-58.0, -12.0, 46.5)
	creature_at(monster, yaw_to(monster, feet))
	await film(40, func(t: float) -> void:
		var tt := maxf(t, 0.0)
		var aim: Vector3 = monster + Vector3(0, 2.0, 0)
		place_eyes(feet, yaw_to(feet, aim) + drift(tt * 5.0, 0) * 0.025, pitch_to(feet + Vector3(0, EYE, 0), aim) + drift(tt * 5.0, 1) * 0.02)
		level.locust.visual.aggression = 1.0
		level.locust.visual.attack = ramp(tt, 0.0, 0.35)
		level.locust.visual.look_point = feet + Vector3(0, EYE, 0)
		if frame_index == 0: mark("strike"), 30)