extends Node3D
## Opening scene of a new game. The player wakes in a dark hotel bedroom where
## only the television is on. Something peeks in from the static, then beats
## on the glass from inside, cracking it. Before the screen gives, the player
## runs out, slams the door and flees down the dark corridor while the door is
## battered behind them, into the next room, where the floor begins.
## Camera and events follow a fixed timeline; the view can drift a little with
## the mouse while in bed. Skippable (handled by hotel_main).
signal finished

const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const STEPS := preload("res://game/audio/footstep_segments.gd")
const GRUNTS := preload("res://game/audio/grunt_segments.gd")
## A picture of the creature for the television; a drawn stand-in otherwise.
const PICTURE := "res://assets/intro/locust_tv.png"
const HEIGHT := 2.9
const EYE := 1.62
## Room layout (local metres). Bedroom x -2.6..2.6, z -3.2..3.2; corridor to the
## east, x 2.6..5.0, z -14..4; the next room beyond the corridor's east wall.
const BED := Vector3(-1.1, 0.0, -2.13)
const TV := Vector3(-1.8, 0.62, 0.95)
const BEDROOM_DOOR := Vector3(2.6, 0.0, 2.0)
const NEXT_DOOR := Vector3(5.0, 0.0, -11.0)
const LENGTH := 39.5
## Seconds per unit of timeline; tests run it faster.
var speed := 1.0
var time := 0.0
var done := false
var builder: Node3D
var camera: Camera3D
var screen: ShaderMaterial
var tv_light: OmniLight3D
var tv_node: Node3D
var bedroom_leaf: Node3D
var next_leaf: Node3D
var lids: ColorRect
var fade := 1.0
var look_offset := Vector2.ZERO
var audible := true
var fired: Array[bool] = []
var events: Array = []
var shake := 0.0
var jolt := 0.0
var step_phase := 0.0
var last_position := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var voices := {}
var heartbeat_clock := -1.0
var heartbeat_beat := 0
var door_rattle := 0.0

## Camera keys: time, eye position, yaw, pitch, field of view, easing.
## Yaw 0 looks along -Z. "run" keys move at constant speed with a running gait.
var keys: Array = []

func _ready() -> void:
	rng.seed = 1987
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.03
	add_child(camera)
	build_set()
	build_camera_keys()
	build_events()
	build_audio()
	var layer := CanvasLayer.new()
	layer.layer = 3
	add_child(layer)
	lids = ColorRect.new()
	lids.color = Color.BLACK
	lids.set_anchors_preset(Control.PRESET_FULL_RECT)
	lids.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(lids)
	fired.resize(events.size())
	fired.fill(false)
	camera.current = true
	apply_camera()

## Direction to yaw/pitch as used by the camera keys.
static func aim(from: Vector3, to: Vector3) -> Vector2:
	var d := to - from
	return Vector2(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))

func key(t: float, pos: Vector3, target: Vector3, fov := 70.0, run := false) -> void:
	var angles := aim(pos, target)
	keys.append({"t": t, "pos": pos, "yaw": angles.x, "pitch": angles.y, "fov": fov, "run": run})

func build_camera_keys() -> void:
	var screen_point := TV + Vector3(0, 0.35, -0.29)
	var lying := BED + Vector3(-0.7, 0.9, -0.62)
	var sitting := BED + Vector3(-0.7, 1.2, 0.05)
	var standing := Vector3(-0.2, EYE, -1.2)
	var outside := Vector3(3.8, EYE, 2.0)
	var corridor_end := Vector3(3.8, EYE, -10.3)
	key(0.0, lying, lying + Vector3(0.2, 3.0, 1.2), 72.0)
	key(6.0, lying, lying + Vector3(-0.1, 2.0, 2.6), 72.0)
	key(9.5, lying + Vector3(0, 0.05, 0.05), screen_point + Vector3(0, 0.5, 0), 70.0)
	key(12.5, sitting, screen_point, 66.0)
	key(19.0, sitting + Vector3(0, -0.03, 0.14), screen_point, 46.0)
	key(25.0, sitting + Vector3(0, -0.05, 0.2), screen_point, 36.0)
	key(30.4, sitting + Vector3(0, -0.05, 0.22), screen_point, 32.0)
	key(31.1, standing, Vector3(1.8, 1.5, 1.4), 70.0)
	key(32.5, Vector3(1.75, EYE, 1.15), BEDROOM_DOOR + Vector3(0, 1.5, 0), 72.0, true)
	key(33.3, Vector3(3.5, EYE, 2.0), Vector3(6.0, 1.5, 2.0), 72.0, true)
	key(33.9, outside, BEDROOM_DOOR + Vector3(0, 1.4, 0), 72.0)
	key(34.3, outside, BEDROOM_DOOR + Vector3(0, 1.4, 0), 72.0)
	key(34.9, outside + Vector3(0, 0, -0.4), Vector3(3.8, 1.5, -8.0), 74.0)
	key(37.6, corridor_end, Vector3(3.8, 1.5, -14.0), 74.0, true)
	key(38.2, Vector3(4.4, EYE, -11.0), Vector3(8.0, 1.5, -11.0), 72.0, true)
	key(39.1, Vector3(6.1, EYE, -11.0), Vector3(9.0, 1.4, -11.0), 72.0, true)
	key(LENGTH, Vector3(6.4, EYE, -11.0), Vector3(9.0, 1.4, -11.0), 72.0)

func build_events() -> void:
	# Time, method, arguments.
	events = [
		[0.3, "play", ["breath", -10.0]],
		[16.5, "tween_uniform", ["roll", 0.0, 1.0, 0.6]],
		[19.0, "start_drone", []],
		[21.0, "start_heartbeat", []],
		[25.2, "lunge", []],
		[26.4, "knock", [0, 0.25]],
		[27.9, "knock", [1, 0.5]],
		[29.1, "knock", [2, 0.75]],
		[30.0, "knock", [1, 0.92]],
		[32.5, "swing", ["bedroom", -1.45, 0.3, "open"]],
		[34.1, "swing", ["bedroom", 0.0, 0.22, "slam"]],
		[34.35, "play", ["shatter", -9.0]],
		[35.1, "bang", [0]],
		[35.6, "grunt", []],
		[35.9, "bang", [1]],
		[36.5, "bang", [2]],
		[37.1, "bang", [0]],
		[37.7, "swing", ["next", -1.4, 0.5, "open_soft"]],
		[37.9, "bang", [1]],
	]

func start_drone() -> void:
	play("drone", -30.0)
	fade_voice("drone", -20.0, 8.0)

func start_heartbeat() -> void:
	heartbeat_clock = 0.0

## The figure lurches at the glass.
func lunge() -> void:
	screen.set_shader_parameter("flash", 0.6)
	shake = 0.3
	play("sting", -10.0)

func _process(delta: float) -> void:
	if done: return
	var step := delta * speed
	time += step
	for i in events.size():
		if not fired[i] and time >= events[i][0]:
			fired[i] = true
			callv(events[i][1], events[i][2])
	update_screen(step)
	update_heartbeat(step)
	update_lids()
	shake = maxf(0.0, shake - step * 1.6)
	jolt = maxf(0.0, jolt - step * 4.0)
	# The mouse drifts the view a little while still in bed.
	var free := 1.0 - clampf((time - 30.0) / 0.6, 0.0, 1.0)
	look_offset = look_offset.lerp(Vector2.ZERO, 0.0 if free > 0.5 else minf(1.0, step * 4.0))
	apply_camera()
	if bedroom_leaf != null and door_rattle > 0.0:
		door_rattle = maxf(0.0, door_rattle - step * 3.0)
		bedroom_leaf.rotation.y = sin(time * 90.0) * 0.03 * door_rattle
	if time >= LENGTH:
		done = true
		finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and time < 30.0:
		look_offset.x = clampf(look_offset.x - event.relative.x * 0.0015, -0.45, 0.45)
		look_offset.y = clampf(look_offset.y - event.relative.y * 0.0015, -0.3, 0.3)

func apply_camera() -> void:
	var index := 0
	while index < keys.size() - 2 and time >= keys[index + 1].t: index += 1
	var a: Dictionary = keys[index]
	var b: Dictionary = keys[index + 1]
	var raw := clampf((time - a.t) / maxf(b.t - a.t, 0.001), 0.0, 1.0)
	# Runs keep a constant pace; everything else eases in and out.
	var w := raw if b.run else raw * raw * (3.0 - 2.0 * raw)
	var pos: Vector3 = a.pos.lerp(b.pos, w)
	var yaw := lerp_angle(a.yaw, b.yaw, w)
	var pitch := lerpf(a.pitch, b.pitch, w)
	# Running gait: head bob and footsteps from the distance covered.
	if b.run:
		var travelled := pos.distance_to(last_position)
		var before := floori(step_phase / PI)
		step_phase += travelled / 2.4 * PI
		if floori(step_phase / PI) != before: footstep()
		last_position = pos
		pos.y += (absf(sin(step_phase)) - 0.6) * 0.06
		pos += Basis(Vector3.UP, yaw) * Vector3(sin(step_phase) * 0.03, 0, 0)
	else:
		last_position = pos
	# Breathing while in bed.
	if time < 30.4: pos.y += sin(time * 1.6) * 0.008
	var tremor := shake * shake
	yaw += look_offset.x + (rng.randf() - 0.5) * 0.05 * tremor
	pitch += look_offset.y + (rng.randf() - 0.5) * 0.05 * tremor
	camera.position = pos
	camera.rotation = Vector3(pitch, yaw, sin(time * 0.7) * 0.01 if time < 12.0 else 0.0)
	camera.fov = lerpf(a.fov, b.fov, w) - jolt * 6.0

## Eyelids opening on waking, and the fade into the next room at the end.
func update_lids() -> void:
	var open := 0.0
	if time < 2.0: open = 0.0
	elif time < 2.6: open = (time - 2.0) / 0.6 * 0.4
	elif time < 3.1: open = 0.4 - (time - 2.6) / 0.5 * 0.4
	elif time < 4.3: open = (time - 3.1) / 1.2 * 0.7
	elif time < 4.7: open = 0.7 - (time - 4.3) / 0.4 * 0.5
	elif time < 7.0: open = 0.2 + (time - 4.7) / 2.3 * 0.8
	else: open = 1.0
	var closing := clampf((time - 38.4) / 0.9, 0.0, 1.0)
	lids.modulate.a = clampf(maxf(1.0 - open, closing), 0.0, 1.0)

func update_screen(step: float) -> void:
	# Static fades as the figure comes through; the picture peeks in from the
	# right edge, holds, then lunges to fill the tube.
	var peek := clampf((time - 19.0) / 3.0, 0.0, 1.0)
	var lunge := clampf((time - 25.2) / 0.35, 0.0, 1.0)
	var closer := clampf((time - 26.4) / 4.0, 0.0, 1.0)
	screen.set_shader_parameter("image_amount", clampf((time - 18.2) / 1.5, 0.0, 1.0) * (0.75 + 0.25 * rng.randf()))
	screen.set_shader_parameter("static_amount", lerpf(1.0, 0.35, peek) + (0.4 if rng.randf() < 0.03 else 0.0))
	var base := 1.0 if screen.get_shader_parameter("has_image") else 1.5
	var scale := base * (lerpf(1.0, 1.7, lunge) + closer * 0.5 + jolt * 0.25)
	# Zoomed in, the picture slides down so the face (upper third) stays on the tube.
	var offset := Vector2(lerpf(0.75, 0.3, peek), lerpf(0.2, 0.08, peek)).lerp(Vector2(0.0, 0.2 * (scale - 1.0)), lunge)
	screen.set_shader_parameter("image_offset", offset + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * 0.01 * jolt)
	screen.set_shader_parameter("image_scale", scale)
	var flash: float = screen.get_shader_parameter("flash")
	screen.set_shader_parameter("flash", maxf(0.0, flash - step * 3.0))
	var level := 0.55 + rng.randf() * 0.25 - peek * 0.15 + flash * 2.5
	tv_light.light_energy = level * 0.9
	tv_node.position = TV + Vector3(rng.randf() - 0.5, 0, rng.randf() - 0.5) * 0.02 * jolt

func knock(sound: int, level: float) -> void:
	screen.set_shader_parameter("crack_level", level)
	screen.set_shader_parameter("flash", 0.8)
	jolt = 1.0
	shake = maxf(shake, 0.35)
	play("knock_%d" % sound, -7.0)

func bang(sound: int) -> void:
	door_rattle = 1.0
	shake = maxf(shake, 0.2)
	play("bang_%d" % sound, -6.0)

func grunt() -> void:
	var voice: AudioStreamPlayer3D = voices.grunt
	if not audible: return
	var segment: Array = GRUNTS.SEGMENTS[3 % GRUNTS.SEGMENTS.size()]
	voice.play(segment[0])
	get_tree().create_timer(segment[1] / speed).timeout.connect(voice.stop)

func footstep() -> void:
	if not audible: return
	var clips: Array = STEPS.SETS.carpet_run
	var entry: Array = clips[rng.randi() % clips.size()]
	var voice: AudioStreamPlayer = voices.step
	voice.stream = load(entry[0])
	voice.pitch_scale = rng.randf_range(0.95, 1.05)
	voice.play(entry[1] * 0.5)

func update_heartbeat(step: float) -> void:
	if heartbeat_clock < 0.0 or time > LENGTH - 1.0: return
	heartbeat_clock -= step
	if heartbeat_clock > 0.0: return
	var bpm := lerpf(70.0, 140.0, clampf((time - 21.0) / 12.0, 0.0, 1.0))
	heartbeat_clock = 60.0 / bpm
	heartbeat_beat += 1
	play("heart_%d" % (heartbeat_beat % 2), lerpf(-22.0, -13.0, clampf((time - 21.0) / 10.0, 0.0, 1.0)))

func play(title: String, volume: float) -> void:
	if not audible or not voices.has(title): return
	var voice = voices[title]
	voice.volume_db = volume
	voice.play()

func fade_voice(title: String, volume: float, seconds: float) -> void:
	if not voices.has(title): return
	create_tween().tween_property(voices[title], "volume_db", volume, seconds / speed)

func tween_uniform(parameter: String, from: float, to: float, seconds: float) -> void:
	var motion := create_tween()
	motion.tween_method(func(v): screen.set_shader_parameter(parameter, v), from, to, seconds / speed)
	motion.tween_callback(func(): screen.set_shader_parameter(parameter, 0.0))

func swing(which: String, angle: float, seconds: float, sound: String) -> void:
	var leaf: Node3D = bedroom_leaf if which == "bedroom" else next_leaf
	if sound == "slam": shake = 0.5
	create_tween().tween_property(leaf, "rotation:y", angle, seconds / speed).set_trans(Tween.TRANS_QUAD)
	match sound:
		"open": play("door_open", -4.0)
		"slam": play("door_slam", -3.0)
		"open_soft": play("door_soft", -6.0)

func build_audio() -> void:
	audible = get_parent() == null or not ("world_audio" in get_parent()) or get_parent().world_audio.enabled
	var screen_point := TV + Vector3(0, 0.35, -0.3)
	var door_point := BEDROOM_DOOR + Vector3(0, 1.4, 0)
	voice3d("static", "res://assets/audio/intro/tv_static.wav", screen_point, "Effects", -3.0, true, 2.0)
	voice3d("whine", "res://assets/audio/intro/tv_whine.wav", screen_point, "Effects", -26.0, true, 2.0)
	for i in 3: voice3d("knock_%d" % i, "res://assets/audio/intro/glass_knock_%d.wav" % (i + 1), screen_point, "Threat", 0.0, false, 4.0)
	# Heard through the shut door: dull and far.
	voice3d("shatter", "res://assets/audio/intro/glass_shatter.wav", screen_point, "Threat", 0.0, false, 5.0)
	voices.shatter.attenuation_filter_cutoff_hz = 1400.0
	for i in 3:
		voice3d("bang_%d" % i, "res://assets/audio/intro/door_bang_%d.wav" % (i + 1), door_point, "Threat", 0.0, false, 6.0)
		voices["bang_%d" % i].attenuation_filter_cutoff_hz = 3000.0
	voice3d("grunt", "res://assets/audio/sfx/chase/grunts.ogg", door_point, "Threat", -2.0, false, 6.0)
	voices.grunt.attenuation_filter_cutoff_hz = 1800.0
	voice3d("door_open", "res://assets/audio/sfx/door/opening/close-hard-opening.ogg", door_point, "Effects", 0.0, false, 4.0)
	voice3d("door_slam", "res://assets/audio/sfx/door/closing/close-hard-closing.ogg", door_point, "Effects", 0.0, false, 4.0)
	voice3d("door_soft", "res://assets/audio/sfx/door/opening/opening2.ogg", NEXT_DOOR + Vector3(0, 1.4, 0), "Effects", 0.0, false, 4.0)
	voice2d("breath", "res://assets/audio/dread/dread_breath.wav", "Effects")
	voice2d("drone", "res://assets/audio/dread/dread_drone.wav", "Threat", true)
	voice2d("sting", "res://assets/audio/dread/presence_riser.wav", "Threat")
	voice2d("heart_0", "res://assets/audio/sfx/heartbeat/1.ogg", "Effects")
	voice2d("heart_1", "res://assets/audio/sfx/heartbeat/2.ogg", "Effects")
	voice2d("step", "", "Steps")
	voices.step.volume_db = -22.0
	if audible:
		voices.static.play()
		voices.whine.play()

func voice3d(title: String, path: String, point: Vector3, bus: String, volume: float, loop: bool, unit: float) -> void:
	var voice := AudioStreamPlayer3D.new()
	voice.name = title
	voice.stream = loop_stream(load(path)) if loop else load(path)
	voice.position = point
	voice.bus = bus
	voice.volume_db = volume
	voice.unit_size = unit
	voice.max_db = 0.0
	voice.max_distance = 40.0
	add_child(voice)
	voices[title] = voice

func voice2d(title: String, path: String, bus: String, loop := false) -> void:
	var voice := AudioStreamPlayer.new()
	voice.name = title
	if not path.is_empty(): voice.stream = loop_stream(load(path)) if loop else load(path)
	voice.bus = bus
	add_child(voice)
	voices[title] = voice

static func loop_stream(source: AudioStream) -> AudioStream:
	var copy: AudioStream = source.duplicate()
	if copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
		copy.loop_begin = 0
		copy.loop_end = int(copy.get_length() * copy.mix_rate)
	elif copy is AudioStreamOggVorbis: copy.loop = true
	return copy

# --- The set ---------------------------------------------------------------

func build_set() -> void:
	builder = GEOMETRY.new()
	builder.name = "Set"
	add_child(builder)
	# Floors and ceilings: bedroom, corridor, next room.
	for area in [[Rect2(-2.6, -3.2, 5.2, 6.4), "carpet"], [Rect2(2.6, -14.0, 2.4, 18.0), "carpet"], [Rect2(5.0, -13.5, 4.0, 5.0), "carpet"]]:
		var rect: Rect2 = area[0]
		var centre := Vector3(rect.get_center().x, 0, rect.get_center().y)
		builder.box(builder, centre + Vector3(0, -0.15, 0), Vector3(rect.size.x + 0.2, 0.3, rect.size.y + 0.2), area[1], true)
		builder.box(builder, centre + Vector3(0, HEIGHT + 0.1, 0), Vector3(rect.size.x + 0.2, 0.2, rect.size.y + 0.2), "ceiling", true)
	# Bedroom walls; the east one is shared with the corridor.
	wall(Vector2(-2.6, -3.2), Vector2(2.6, -3.2), [])
	wall(Vector2(-2.6, 3.2), Vector2(2.6, 3.2), [])
	wall(Vector2(-2.6, -3.2), Vector2(-2.6, 3.2), [])
	wall(Vector2(2.6, -14.0), Vector2(2.6, 4.0), [16.0, 6.8])
	# Corridor: east wall with the next room's door and two shut ones, end walls.
	wall(Vector2(5.0, -14.0), Vector2(5.0, 4.0), [3.0, 9.5, 15.0])
	wall(Vector2(2.6, 4.0), Vector2(5.0, 4.0), [])
	wall(Vector2(2.6, -14.0), Vector2(5.0, -14.0), [])
	# Next room.
	wall(Vector2(5.0, -13.5), Vector2(9.0, -13.5), [])
	wall(Vector2(5.0, -8.5), Vector2(9.0, -8.5), [])
	wall(Vector2(9.0, -13.5), Vector2(9.0, -8.5), [])
	build_furniture()
	# Doors: the bedroom's, the next room's (ajar, lit) and shut neighbours.
	bedroom_leaf = door_leaf(BEDROOM_DOOR, true, "107")
	next_leaf = door_leaf(NEXT_DOOR, true, "112")
	next_leaf.rotation.y = -0.6
	door_leaf(Vector3(2.6, 0, -7.2), true, "109")
	door_leaf(Vector3(5.0, 0, 1.0), true, "108")
	door_leaf(Vector3(5.0, 0, -4.5), true, "110")
	builder.flush()
	build_lights()
	# Room numbers only show where light falls on them.
	for label in builder.find_children("*", "Label3D", true, false): label.shaded = true

## A papered wall between two floor points, with doorway gaps centred at the
## given distances from its start.
func wall(from: Vector2, to: Vector2, gaps: Array) -> void:
	var direction := to - from
	var length := direction.length()
	var boundary := Node3D.new()
	var middle := (from + to) * 0.5
	boundary.position = Vector3(middle.x, 0, middle.y)
	boundary.rotation.y = atan2(-direction.y, direction.x)
	builder.add_child(boundary)
	var cuts: Array = gaps.duplicate()
	cuts.sort()
	var start := 0.0
	var portal: float = FLOOR.PORTAL
	for centre in cuts + [length + portal * 0.5]:
		var stop: float = minf(centre - portal * 0.5, length)
		if stop - start > 0.01:
			var x := (start + stop) * 0.5 - length * 0.5
			builder.box(boundary, Vector3(x, HEIGHT / 2, 0), Vector3(stop - start, HEIGHT, 0.18), "plaster", true)
			for face in [-1, 1]:
				builder.box(boundary, Vector3(x, 0.48, face * 0.11), Vector3(stop - start, 0.96, 0.07), "panel")
				builder.box(boundary, Vector3(x, 0.98, face * 0.15), Vector3(stop - start, 0.05, 0.035), "trim")
				builder.box(boundary, Vector3(x, 0.07, face * 0.155), Vector3(stop - start, 0.14, 0.03), "trim")
				builder.box(boundary, Vector3(x, HEIGHT - 0.05, face * 0.12), Vector3(stop - start, 0.1, 0.06), "trim")
		if centre < length:
			var x: float = centre - length * 0.5
			builder.box(boundary, Vector3(x, (HEIGHT + 2.65) / 2, 0), Vector3(portal, HEIGHT - 2.65, 0.18), "plaster", true)
			for face in [-1, 1]:
				builder.box(boundary, Vector3(x, 2.74, face * 0.165), Vector3(portal + 0.26, 0.14, 0.035), "trim")
				for side in [-1, 1]: builder.box(boundary, Vector3(x + side * (portal * 0.5 + 0.06), 1.36, face * 0.165), Vector3(0.14, 2.72, 0.035), "trim")
		start = centre + portal * 0.5

## A door leaf hinged at one edge of a doorway; returns its hinge so it can swing.
## along_z: the doorway lies in a wall running along Z.
func door_leaf(centre: Vector3, along_z: bool, number: String) -> Node3D:
	var width: float = FLOOR.LEAF_WIDTH
	var hinge := Node3D.new()
	hinge.position = centre + (Vector3(0, 0, width * 0.5) if along_z else Vector3(width * 0.5, 0, 0))
	builder.add_child(hinge)
	var holder := Node3D.new()
	holder.rotation.y = PI / 2 if along_z else PI
	hinge.add_child(holder)
	var leaf := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 2.58, 0.07)
	mesh.material = builder.materials.door
	leaf.mesh = mesh
	leaf.position = Vector3(width * 0.5, 1.29, 0)
	holder.add_child(leaf)
	for face in [-1, 1]: builder.box(holder, Vector3(width - 0.14, 1.08, face * 0.07), Vector3(0.14, 0.04, 0.05), "gold")
	builder.text(holder, number, Vector3(width * 0.5, 1.94, 0.045), 0, 24)
	builder.text(holder, number, Vector3(width * 0.5, 1.94, -0.045), PI, 24)
	return hinge

func build_furniture() -> void:
	var bed := MeshInstance3D.new()
	bed.name = "Bed"
	bed.mesh = load("res://assets/props/bedroom/bed.res")
	bed.position = BED
	builder.add_child(bed)
	builder.box(builder, BED + Vector3(-0.7, 0.4, 0.0), Vector3(1.4, 0.8, 2.1), "", true)
	# Low dresser at the foot of the bed with the television on it.
	var dresser := Vector3(TV.x, 0.0, TV.z + 0.05)
	builder.box(builder, dresser + Vector3(0, 0.31, 0), Vector3(1.3, 0.62, 0.55), "wood", true)
	for x in [-0.33, 0.33]: builder.box(builder, dresser + Vector3(x, 0.4, -0.28), Vector3(0.56, 0.22, 0.02), "trim")
	tv_node = Node3D.new()
	tv_node.name = "Television"
	tv_node.position = TV
	tv_node.rotation.y = PI
	builder.add_child(tv_node)
	var body := MeshInstance3D.new()
	body.mesh = load("res://assets/props/tv/tv_body.res")
	# Its own screen does not light the set's casing (see build_lights).
	body.layers = 2
	tv_node.add_child(body)
	var glass := MeshInstance3D.new()
	glass.name = "Screen"
	glass.mesh = load("res://assets/props/tv/tv_screen.res")
	screen = ShaderMaterial.new()
	screen.shader = load("res://game/intro/tv_screen.gdshader")
	screen.set_shader_parameter("cracks", crack_texture())
	if ResourceLoader.exists(PICTURE):
		screen.set_shader_parameter("image", load(PICTURE))
		screen.set_shader_parameter("has_image", true)
	for parameter in ["flash", "crack_level", "image_amount", "roll"]: screen.set_shader_parameter(parameter, 0.0)
	glass.material_override = screen
	tv_node.add_child(glass)
	for spot in [[Vector3(2.0, 0, -2.7), "luggage", 3], [Vector3(-2.35, 0, 1.2), "curtain", 1]]:
		var prop := Node3D.new()
		prop.position = spot[0]
		prop.rotation.y = spot[2] * PI / 2
		builder.add_child(prop)
		builder.build_prop(prop, spot[1])
	# Framed prints in the corridor.
	for z in [-2.0, -9.0]:
		builder.box(builder, Vector3(2.75, 1.9, z), Vector3(0.06, 0.8, 1.1), "gold")
		builder.box(builder, Vector3(2.79, 1.9, z), Vector3(0.02, 0.66, 0.96), "painting")
	var lamp := Node3D.new()
	lamp.position = Vector3(8.3, 0, -9.2)
	builder.add_child(lamp)
	builder.build_prop(lamp, "lamp")

func build_lights() -> void:
	# The television is the only light in the bedroom.
	tv_light = OmniLight3D.new()
	# Just off the glass: the room is lit, the set's own bezel barely.
	tv_light.position = TV + Vector3(0, 0.36, -0.42)
	tv_light.light_color = Color(0.72, 0.82, 1.0)
	tv_light.omni_range = 7.0
	tv_light.omni_attenuation = 1.4
	tv_light.shadow_enabled = true
	tv_light.light_size = 0.3
	tv_light.light_cull_mask = ~2
	add_child(tv_light)
	# Warm spill from the next room through its ajar door.
	var warm := OmniLight3D.new()
	warm.position = Vector3(7.5, 2.0, -11.0)
	warm.light_color = Color("ffb877")
	warm.light_energy = 3.0
	warm.omni_range = 7.5
	warm.shadow_enabled = true
	add_child(warm)
	# A barely lit corridor: an exit sign glowing at the far end.
	var sign := OmniLight3D.new()
	sign.position = Vector3(3.8, 2.4, -13.7)
	sign.light_color = Color(0.5, 0.78, 0.55)
	sign.light_energy = 0.07
	sign.omni_range = 4.0
	# Faint grey night light along the corridor, just enough to read its shape.
	for z in [0.5, -6.0]:
		var night := OmniLight3D.new()
		night.position = Vector3(3.8, 2.6, z)
		night.light_color = Color(0.55, 0.62, 0.75)
		night.light_energy = 0.18
		night.omni_range = 6.5
		add_child(night)
	add_child(sign)
	builder.box(builder, Vector3(3.8, 2.45, -13.88), Vector3(0.5, 0.18, 0.05), "green")
	builder.flush()

## Cracks spreading from a point low on the tube: each pixel stores the stage
## (0.22, 0.44, 0.66, 0.88) at which it breaks, so one texture grows with the knocks.
func crack_texture() -> ImageTexture:
	var size := 512
	var image := Image.create(size, size, false, Image.FORMAT_R8)
	var noise := RandomNumberGenerator.new()
	noise.seed = 4411
	var origin := Vector2(0.46, 0.45) * size
	var tips: Array = [origin]
	for stage in range(1, 5):
		var value := stage * 0.22
		var branches: Array = []
		for ray in 4 + stage * 2:
			var point: Vector2 = tips[noise.randi() % tips.size()]
			var angle := noise.randf() * TAU
			var steps := 5 + stage * 4
			for i in steps:
				angle += noise.randf_range(-0.45, 0.45)
				var next := point + Vector2(cos(angle), sin(angle)) * noise.randf_range(6.0, 14.0)
				line(image, point, next, value)
				point = next
			branches.append(point)
		tips += branches
	return ImageTexture.create_from_image(image)

static func line(image: Image, a: Vector2, b: Vector2, value: float) -> void:
	var count := int(a.distance_to(b)) + 1
	for i in count:
		var p := a.lerp(b, float(i) / count)
		for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var x := int(p.x) + o.x
			var y := int(p.y) + o.y
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height(): continue
			if image.get_pixel(x, y).r <= 0.0: image.set_pixel(x, y, Color(value, 0, 0))
