extends Node3D
## Opening scene of a new game. The player wakes in a dark hotel bedroom where
## only a big old television is on. Leaning closer on the creaking bed, they see
## The Locust lean into the picture, lunge at the lens and beat the glass with
## its bladed arm, cracking it from inside. Before it gives, the player gets up,
## stamps to the door, slams it with a desperate turn (the screen shatters
## behind), runs down the dark corridor while the door is battered, crosses the
## lit room at the end and opens its far door onto the reception, under the red
## lamp that marks where the floor begins.
## The camera follows timeline keys through springs with head bob, sway and
## handheld tremor; events are listed with their times. Skippable (hotel_main).
signal finished

const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const STEPS := preload("res://game/audio/footstep_segments.gd")
const GRUNTS := preload("res://game/audio/grunt_segments.gd")
const TIMING := preload("res://game/audio/cue_timing.gd")
const BROADCAST := preload("res://game/intro/tv_broadcast.gd")
const CRACKS := preload("res://game/intro/crack_pattern.gd")
const NOISE := preload("res://game/ui/shaders/tape_noise.gdshader")
const HEIGHT := 2.9
const EYE := 1.62
## Room layout (local metres). Bedroom x -2.6..2.6, z -3.2..3.2; corridor to the
## east, x 2.6..5.0, z -14..4; the lit room x 5..9, z -13.5..-8.5; the reception
## glimpsed beyond it, x 9..13.
const BED := Vector3(-1.1, 0.0, -2.13)
## A large 1980s set: about 80 cm wide.
const TV_SCALE := 1.45
const TV := Vector3(-1.8, 0.55, 0.95)
const SCREEN := TV + Vector3(0.0, 0.505, -0.406)
const BEDROOM_DOOR := Vector3(2.6, 0.0, 2.0)
const NEXT_DOOR := Vector3(5.0, 0.0, -11.0)
const FAR_DOOR := Vector3(9.0, 0.0, -11.0)
const LENGTH := 39.6
## The four blows on the glass: time of impact, point on the tube, severity.
const BLOWS := [[26.4, Vector2(0.46, 0.44), 0.4], [27.9, Vector2(0.47, 0.45), 0.7], [29.1, Vector2(0.64, 0.34), 0.55], [30.0, Vector2(0.34, 0.6), 0.9]]
## Seconds per unit of timeline; tests run it faster.
var speed := 1.0
var time := 0.0
var done := false
var builder: Node3D
var camera: Camera3D
var screen: ShaderMaterial
var broadcast
var cracks
var tv_light: OmniLight3D
var tv_node: Node3D
var bedroom_leaf: Node3D
var next_leaf: Node3D
var far_leaf: Node3D
var beacon: OmniLight3D
var lids: ColorRect
var static_veil: ShaderMaterial
var look_offset := Vector2.ZERO
var audible := true
var fired: Array[bool] = []
var events: Array = []
var keys: Array = []
var shake := 0.0
var jolt := 0.0
var flash := 0.0
var flicker := 0.0
var blows_landed := 0
var rng := RandomNumberGenerator.new()
var voices := {}
var heartbeat_clock := -1.0
var heartbeat_beat := 0
var door_rattle := 0.0
# Camera rig state (springs, gait).
var cam_pos := Vector3.ZERO
var cam_vel := Vector3.ZERO
var cam_yaw := 0.0
var cam_yaw_vel := 0.0
var cam_pitch := 0.0
var cam_pitch_vel := 0.0
var cam_roll := 0.0
var gait_phase := 0.0

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
	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	static_veil = ShaderMaterial.new()
	static_veil.shader = NOISE
	veil.material = static_veil
	layer.add_child(veil)
	fired.resize(events.size())
	fired.fill(false)
	var first: Dictionary = keys[0]
	cam_pos = first.pos
	cam_yaw = first.yaw
	cam_pitch = first.pitch
	camera.current = true
	update_camera(0.0)

# --- Timeline -------------------------------------------------------------

## Direction to yaw/pitch as used by the camera keys (yaw 0 looks along -Z).
static func aim(from: Vector3, to: Vector3) -> Vector2:
	var d := to - from
	return Vector2(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()))

## gait: "" still, "walk", "heavy" (stamping) or "run". stiff: how quickly the
## head gets there (a panicked whip turn is very stiff).
func key(t: float, pos: Vector3, target: Vector3, fov := 70.0, gait := "", stiff := 45.0) -> void:
	var angles := aim(pos, target)
	keys.append({"t": t, "pos": pos, "yaw": angles.x, "pitch": angles.y, "fov": fov, "gait": gait, "stiff": stiff})

func build_camera_keys() -> void:
	var lying := BED + Vector3(-0.7, 0.9, -0.62)
	var sitting := BED + Vector3(-0.7, 1.2, 0.05)
	var leaning := sitting + Vector3(0.0, -0.07, 0.36)
	var outside := Vector3(3.75, EYE, 2.0)
	key(0.0, lying, lying + Vector3(0.2, 3.0, 1.2), 72.0, "", 20.0)
	key(6.0, lying, lying + Vector3(-0.1, 2.0, 2.6), 72.0, "", 20.0)
	key(9.5, lying + Vector3(0, 0.05, 0.05), SCREEN + Vector3(0, 0.5, 0), 70.0, "", 25.0)
	key(12.5, sitting, SCREEN, 64.0, "", 30.0)
	key(15.8, leaning, SCREEN, 50.0, "", 30.0)
	key(19.0, leaning + Vector3(0, -0.02, 0.05), SCREEN, 45.0, "", 30.0)
	key(21.5, leaning + Vector3(0, -0.04, 0.2), SCREEN, 40.0, "", 30.0)
	key(25.0, leaning + Vector3(0, -0.04, 0.2), SCREEN, 37.0, "", 30.0)
	key(30.3, leaning + Vector3(0, -0.06, 0.22), SCREEN, 35.0, "", 60.0)
	# Panic: up off the bed and round towards the door.
	key(30.95, Vector3(-0.55, EYE, -1.55), Vector3(1.8, 1.45, 1.3), 70.0, "", 140.0)
	key(32.4, Vector3(1.7, EYE, 1.05), BEDROOM_DOOR + Vector3(0, 1.5, 0), 72.0, "heavy", 60.0)
	key(32.6, Vector3(1.8, EYE, 1.15), BEDROOM_DOOR + Vector3(0, 1.5, 0), 72.0, "heavy", 60.0)
	key(33.2, Vector3(3.5, EYE, 2.0), Vector3(6.0, 1.5, 2.0), 74.0, "run", 90.0)
	# A desperate whip round to pull the door shut.
	key(33.52, outside, BEDROOM_DOOR + Vector3(0, 1.3, 0), 76.0, "", 420.0)
	key(33.9, outside + Vector3(0.05, 0, 0), BEDROOM_DOOR + Vector3(0, 1.35, 0), 74.0, "", 300.0)
	key(34.3, Vector3(3.8, EYE, 1.65), Vector3(3.8, 1.5, -8.0), 76.0, "run", 260.0)
	key(37.0, Vector3(3.8, EYE, -10.3), Vector3(3.8, 1.5, -14.0), 76.0, "run", 90.0)
	key(37.5, Vector3(4.45, EYE, -11.0), Vector3(8.0, 1.5, -11.0), 74.0, "run", 140.0)
	key(38.4, Vector3(7.6, EYE, -11.0), FAR_DOOR + Vector3(0, 1.5, 0), 72.0, "walk", 90.0)
	key(38.7, Vector3(8.05, EYE, -11.0), FAR_DOOR + Vector3(0, 1.5, 0), 72.0, "walk", 90.0)
	key(39.3, Vector3(9.7, EYE, -11.0), Vector3(12.5, 1.6, -11.0), 72.0, "walk", 90.0)
	key(LENGTH, Vector3(10.2, EYE, -11.0), Vector3(12.5, 1.6, -11.0), 72.0, "walk", 90.0)

func build_events() -> void:
	# Time, method, arguments.
	events = [
		[0.3, "play", ["breath", -10.0]],
		[8.2, "creak", [2, -14.0]],
		[9.6, "creak", [0, -4.0]],
		[11.3, "creak", [1, -8.0]],
		[13.2, "creak", [2, -6.0]],
		[15.0, "creak", [0, -7.0]],
		[16.5, "tween_uniform", ["roll", 0.0, 1.0, 0.6]],
		[19.0, "start_drone", []],
		[21.0, "start_heartbeat", []],
		[21.2, "creak", [1, -8.0]],
		[25.2, "lunge", []],
		[30.3, "creak", [2, -2.0]],
		[32.5, "swing", ["bedroom", -1.45, 0.22, "open"]],
		[33.62, "swing", ["bedroom", 0.0, 0.14, "slam"]],
		[33.85, "play", ["glass_break", -6.0]],
		[34.2, "grunt", []],
		[34.8, "bang", [0]],
		[35.5, "bang", [1]],
		[36.1, "bang", [2]],
		[36.8, "bang", [0]],
		[37.25, "swing", ["next", -1.4, 0.35, "push"]],
		[37.6, "bang", [1]],
		[38.45, "swing", ["far", -1.35, 0.5, "open_far"]],
		[38.9, "cut", []],
	]
	for i in BLOWS.size():
		events.append([BLOWS[i][0] - 0.5, "wind_up", [i]])
		events.append([BLOWS[i][0], "blow", [i]])
	events.sort_custom(func(a, b): return a[0] < b[0])

func start_drone() -> void:
	play("drone", -30.0)
	fade_voice("drone", -20.0, 8.0)

func start_heartbeat() -> void:
	heartbeat_clock = 0.0

## The creature lunges at the lens.
func lunge() -> void:
	flash = 0.5
	shake = 0.3
	play("sting", -10.0)

func wind_up(index: int) -> void:
	broadcast.blow = {"start": BLOWS[index][0] - 0.5, "hit": BLOWS[index][0], "uv": BLOWS[index][1]}

## A blow lands: the glass cracks where the blade struck, the tube flashes.
func blow(index: int) -> void:
	cracks.add_impact(BLOWS[index][1], index, BLOWS[index][2])
	blows_landed = index + 1
	screen.set_shader_parameter("crack_level", float(blows_landed))
	flash = 0.45
	jolt = 1.0
	shake = maxf(shake, 0.4)
	flicker = 0.35
	play("glass_hit_%d" % (index % 3), -2.0 + index)
	play("knock_%d" % (index % 3), -16.0)

func cut() -> void:
	create_tween().tween_method(func(v): static_veil.set_shader_parameter("amount", v), 0.0, 1.0, 0.5 / speed)

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
	if time > 30.0: look_offset = look_offset.lerp(Vector2.ZERO, minf(1.0, step * 4.0))
	update_camera(step)
	if door_rattle > 0.0:
		door_rattle = maxf(0.0, door_rattle - step * 3.0)
		bedroom_leaf.rotation.y = sin(time * 90.0) * 0.035 * door_rattle
	if beacon != null:
		beacon.light_energy = 2.4 * (1.0 if fposmod(time, 1.6) < 0.8 else 0.05)
	if time >= LENGTH:
		done = true
		finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and time < 30.0:
		look_offset.x = clampf(look_offset.x - event.relative.x * 0.0015, -0.45, 0.45)
		look_offset.y = clampf(look_offset.y - event.relative.y * 0.0015, -0.3, 0.3)

# --- Camera rig -----------------------------------------------------------

func sample_keys() -> Dictionary:
	var index := 0
	while index < keys.size() - 2 and time >= keys[index + 1].t: index += 1
	var a: Dictionary = keys[index]
	var b: Dictionary = keys[index + 1]
	var raw := clampf((time - a.t) / maxf(b.t - a.t, 0.001), 0.0, 1.0)
	var moving: bool = not String(b.gait).is_empty()
	var w := raw if moving else raw * raw * (3.0 - 2.0 * raw)
	return {"pos": a.pos.lerp(b.pos, w), "yaw": lerp_angle(a.yaw, b.yaw, w), "pitch": lerpf(a.pitch, b.pitch, w), "fov": lerpf(a.fov, b.fov, w), "gait": b.gait, "stiff": b.stiff}

## Springs make the head arrive with weight (and overshoot on fast turns);
## the gait adds bob, sway and a dip at each footfall; a slow tremor keeps
## the view handheld.
func update_camera(step: float) -> void:
	var target := sample_keys()
	var stiff: float = target.stiff
	var damping := 2.0 * sqrt(stiff) * 0.72
	var substeps := maxi(1, ceili(step / 0.006))
	var dt := step / substeps
	for i in substeps:
		cam_vel += ((target.pos - cam_pos) * stiff - cam_vel * damping) * dt
		cam_pos += cam_vel * dt
		cam_yaw_vel += (wrapf(target.yaw - cam_yaw, -PI, PI) * stiff - cam_yaw_vel * damping) * dt
		cam_yaw += cam_yaw_vel * dt
		cam_pitch_vel += ((target.pitch - cam_pitch) * stiff - cam_pitch_vel * damping) * dt
		cam_pitch += cam_pitch_vel * dt
	var ground := Vector2(cam_vel.x, cam_vel.z).length()
	var gait: String = target.gait
	var stride: float = {"walk": 1.4, "heavy": 1.2, "run": 2.3}.get(gait, 1.4)
	var amplitude: float = {"walk": 0.035, "heavy": 0.06, "run": 0.07}.get(gait, 0.0) * clampf(ground / 1.5, 0.0, 1.0)
	var before := floori(gait_phase / PI)
	if ground > 0.35 and not gait.is_empty():
		gait_phase += ground * step / stride * TAU
		if floori(gait_phase / PI) != before: footfall(gait)
	# Head drops at the footfall, rises mid-stride and sways over the planted foot.
	var dip := pow(1.0 - absf(sin(gait_phase)), 3.0)
	var offset := Vector3(sin(gait_phase) * amplitude * 0.6, -dip * amplitude + absf(sin(gait_phase)) * amplitude * 0.3, 0.0)
	# Handheld tremor, stronger on the move and after a fright.
	var clock := time * TAU
	var tremor := 0.0035 + ground * 0.004 + shake * 0.02
	var wobble := Vector3(sin(clock * 0.23) * 0.6 + sin(clock * 0.61 + 1.3) * 0.4, sin(clock * 0.31 + 0.7) * 0.6 + sin(clock * 0.83) * 0.4, 0.0) * tremor
	if time < 30.3: offset.y += sin(time * 1.6) * 0.008
	# Leaning into turns.
	var roll_target := clampf(-cam_yaw_vel * 0.05, -0.16, 0.16) + sin(gait_phase) * amplitude * 0.5
	cam_roll = lerpf(cam_roll, roll_target, minf(1.0, step * 8.0))
	var jitter := shake * shake
	var heading := Basis(Vector3.UP, cam_yaw)
	camera.position = cam_pos + heading * (offset + wobble) + Vector3(rng.randf() - 0.5, rng.randf() - 0.5, 0) * 0.02 * jitter
	camera.rotation = Vector3(
		cam_pitch + look_offset.y - dip * amplitude * 0.5 + wobble.y * 0.8 + (rng.randf() - 0.5) * 0.04 * jitter,
		cam_yaw + look_offset.x + wobble.x * 0.8 + (rng.randf() - 0.5) * 0.04 * jitter,
		cam_roll + sin(clock * 0.17) * 0.006)
	camera.fov = target.fov - jolt * 6.0

func footfall(gait: String) -> void:
	if not audible: return
	var set_name := "carpet_run" if gait == "run" else "carpet_walk"
	var clips: Array = STEPS.SETS[set_name]
	var entry: Array = clips[rng.randi() % clips.size()]
	var voice: AudioStreamPlayer = voices.step
	voice.stream = load(entry[0])
	voice.pitch_scale = rng.randf_range(0.9, 1.0) if gait == "heavy" else rng.randf_range(0.95, 1.05)
	voice.volume_db = {"heavy": -8.0, "run": -14.0}.get(gait, -18.0)
	voice.play(entry[1] * 0.5)
	if gait in ["heavy", "run"]:
		play("stomp_%d" % rng.randi_range(0, 2), -6.0 if gait == "heavy" else -14.0)
		shake = maxf(shake, 0.12 if gait == "heavy" else 0.05)

## Eyelids opening on waking, and the cut through static into the reception.
func update_lids() -> void:
	var open := 0.0
	if time < 2.0: open = 0.0
	elif time < 2.6: open = (time - 2.0) / 0.6 * 0.4
	elif time < 3.1: open = 0.4 - (time - 2.6) / 0.5 * 0.4
	elif time < 4.3: open = (time - 3.1) / 1.2 * 0.7
	elif time < 4.7: open = 0.7 - (time - 4.3) / 0.4 * 0.5
	elif time < 7.0: open = 0.2 + (time - 4.7) / 2.3 * 0.8
	else: open = 1.0
	var closing := clampf((time - 39.1) / 0.45, 0.0, 1.0)
	lids.modulate.a = clampf(maxf(1.0 - open, closing), 0.0, 1.0)

# --- The television --------------------------------------------------------

func update_screen(step: float) -> void:
	var peek := smoothstep(19.0, 22.0, time)
	broadcast.peek = peek
	broadcast.lunge = ease_out(clampf((time - 25.2) / 0.4, 0.0, 1.0))
	broadcast.twitch = clampf((time - 22.0) / 3.0, 0.0, 1.0)
	broadcast.clock = time - step
	broadcast.pose(step)
	screen.set_shader_parameter("image_amount", clampf((time - 18.2) / 1.5, 0.0, 1.0))
	var burst := 0.5 if rng.randf() < 0.04 else 0.0
	screen.set_shader_parameter("static_amount", clampf(lerpf(1.0, 0.3, peek) + burst + jolt * 0.25, 0.0, 1.0))
	screen.set_shader_parameter("unstable", clampf(jolt + (0.6 if rng.randf() < 0.02 else 0.0), 0.0, 1.0))
	# A failing set: small brightness dips, and short near-blackouts that get
	# more frequent as the thing inside gets closer.
	var dip_chance := 0.02 + clampf((time - 19.0) / 12.0, 0.0, 1.0) * 0.06
	if rng.randf() < dip_chance: flicker = maxf(flicker, rng.randf_range(0.25, 0.85))
	flicker = maxf(0.0, flicker - step * 6.0)
	screen.set_shader_parameter("flicker", flicker)
	flash = maxf(0.0, flash - step * 3.0)
	screen.set_shader_parameter("flash", flash)
	tv_light.light_energy = (0.55 + rng.randf() * 0.2 - peek * 0.12) * (1.0 - flicker) * 1.4 + flash * 3.0
	tv_node.position = TV + Vector3(rng.randf() - 0.5, rng.randf() * 0.3, rng.randf() - 0.5) * 0.03 * jolt

static func ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)

# --- Sound -----------------------------------------------------------------

func creak(index: int, volume: float) -> void:
	play("creak_%d" % index, volume)

func bang(sound: int) -> void:
	door_rattle = 1.0
	shake = maxf(shake, 0.2)
	play("bang_%d" % sound, -6.0)

func grunt() -> void:
	var voice: AudioStreamPlayer3D = voices.grunt
	if not audible: return
	var segment: Array = GRUNTS.SEGMENTS.filter(func(s): return s[1] >= 1.4)[0]
	voice.play(segment[0])
	get_tree().create_timer(segment[1] / speed).timeout.connect(voice.stop)

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
	var start := 0.0
	if voice.stream != null and TIMING.TIMING.has(voice.stream.resource_path): start = TIMING.onset(voice.stream.resource_path)
	voice.play(start)

func fade_voice(title: String, volume: float, seconds: float) -> void:
	if not voices.has(title): return
	create_tween().tween_property(voices[title], "volume_db", volume, seconds / speed)

func tween_uniform(parameter: String, from: float, to: float, seconds: float) -> void:
	var motion := create_tween()
	motion.tween_method(func(v): screen.set_shader_parameter(parameter, v), from, to, seconds / speed)
	motion.tween_callback(func(): screen.set_shader_parameter(parameter, 0.0))

func swing(which: String, angle: float, seconds: float, sound: String) -> void:
	var leaf: Node3D = {"bedroom": bedroom_leaf, "next": next_leaf, "far": far_leaf}[which]
	var motion := create_tween().tween_property(leaf, "rotation:y", angle, seconds / speed)
	motion.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if sound == "slam" else Tween.EASE_OUT)
	match sound:
		"open": play("door_open", -4.0)
		"slam":
			play("door_slam", -2.0)
			shake = 0.7
			jolt = 0.6
		"push": play("door_push", -8.0)
		"open_far": play("door_far", -5.0)

func build_audio() -> void:
	audible = get_parent() == null or not ("world_audio" in get_parent()) or get_parent().world_audio.enabled
	var door_point := BEDROOM_DOOR + Vector3(0, 1.4, 0)
	voice3d("static", "res://assets/audio/intro/tv_static.wav", SCREEN, "Effects", -1.5, true, 2.5)
	voice3d("whine", "res://assets/audio/intro/tv_whine.wav", SCREEN, "Effects", -24.0, true, 2.0)
	for i in 3:
		voice3d("glass_hit_%d" % i, "res://assets/audio/glass/glass-hit-%d.ogg" % (i + 1), SCREEN, "Threat", 0.0, false, 4.0)
		voice3d("knock_%d" % i, "res://assets/audio/intro/glass_knock_%d.wav" % (i + 1), SCREEN, "Threat", 0.0, false, 4.0)
		voice3d("creak_%d" % i, "res://assets/audio/intro/bed_creak_%d.wav" % (i + 1), BED + Vector3(-0.7, 0.5, -0.4), "Effects", 0.0, false, 3.0)
		voice2d("stomp_%d" % i, "res://assets/audio/intro/stomp_%d.wav" % (i + 1), "Steps")
		voice3d("bang_%d" % i, "res://assets/audio/intro/door_bang_%d.wav" % (i + 1), door_point, "Threat", 0.0, false, 6.0)
		voices["bang_%d" % i].attenuation_filter_cutoff_hz = 3000.0
	# Heard through the shut door: dull.
	voice3d("glass_break", "res://assets/audio/glass/glass-break.ogg", SCREEN, "Threat", 0.0, false, 6.0)
	voices.glass_break.attenuation_filter_cutoff_hz = 1500.0
	voice3d("grunt", "res://assets/audio/sfx/chase/grunts.ogg", door_point, "Threat", -2.0, false, 6.0)
	voices.grunt.attenuation_filter_cutoff_hz = 1800.0
	voice3d("door_open", "res://assets/audio/sfx/door/opening/close-hard-opening.ogg", door_point, "Effects", 0.0, false, 4.0)
	voice3d("door_slam", "res://assets/audio/sfx/door/closing/close-hard-closing.ogg", door_point, "Effects", 0.0, false, 4.0)
	voice3d("door_push", "res://assets/audio/sfx/door/opening/opening2.ogg", NEXT_DOOR + Vector3(0, 1.4, 0), "Effects", 0.0, false, 4.0)
	voice3d("door_far", "res://assets/audio/sfx/door/opening/wooden-opening.ogg", FAR_DOOR + Vector3(0, 1.4, 0), "Effects", 0.0, false, 4.0)
	voice2d("breath", "res://assets/audio/dread/dread_breath.wav", "Effects")
	voice2d("drone", "res://assets/audio/dread/dread_drone.wav", "Threat", true)
	voice2d("sting", "res://assets/audio/dread/presence_riser.wav", "Threat")
	voice2d("heart_0", "res://assets/audio/sfx/heartbeat/1.ogg", "Effects")
	voice2d("heart_1", "res://assets/audio/sfx/heartbeat/2.ogg", "Effects")
	voice2d("step", "", "Steps")
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
	voice.max_db = 3.0 if loop else 0.0
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
	# Floors and ceilings: bedroom, corridor, lit room, reception glimpse.
	for rect in [Rect2(-2.6, -3.2, 5.2, 6.4), Rect2(2.6, -14.0, 2.4, 18.0), Rect2(5.0, -13.5, 4.0, 5.0), Rect2(9.0, -13.5, 4.5, 5.0)]:
		var centre := Vector3(rect.get_center().x, 0, rect.get_center().y)
		builder.box(builder, centre + Vector3(0, -0.15, 0), Vector3(rect.size.x + 0.2, 0.3, rect.size.y + 0.2), "carpet", true)
		builder.box(builder, centre + Vector3(0, HEIGHT + 0.1, 0), Vector3(rect.size.x + 0.2, 0.2, rect.size.y + 0.2), "ceiling", true)
	# Bedroom walls; the east one is shared with the corridor.
	wall(Vector2(-2.6, -3.2), Vector2(2.6, -3.2), [])
	wall(Vector2(-2.6, 3.2), Vector2(2.6, 3.2), [])
	wall(Vector2(-2.6, -3.2), Vector2(-2.6, 3.2), [])
	wall(Vector2(2.6, -14.0), Vector2(2.6, 4.0), [16.0, 6.8])
	# Corridor: east wall with the lit room's door and two shut ones, end walls.
	wall(Vector2(5.0, -14.0), Vector2(5.0, 4.0), [3.0, 9.5, 15.0])
	wall(Vector2(2.6, 4.0), Vector2(5.0, 4.0), [])
	wall(Vector2(2.6, -14.0), Vector2(5.0, -14.0), [])
	# Lit room, with a far door into the reception.
	wall(Vector2(5.0, -13.5), Vector2(9.0, -13.5), [])
	wall(Vector2(5.0, -8.5), Vector2(9.0, -8.5), [])
	wall(Vector2(9.0, -13.5), Vector2(9.0, -8.5), [2.5])
	wall(Vector2(9.0, -13.5), Vector2(13.5, -13.5), [])
	wall(Vector2(9.0, -8.5), Vector2(13.5, -8.5), [])
	wall(Vector2(13.5, -13.5), Vector2(13.5, -8.5), [])
	build_furniture()
	bedroom_leaf = door_leaf(BEDROOM_DOOR, "107")
	next_leaf = door_leaf(NEXT_DOOR, "112")
	next_leaf.rotation.y = -0.6
	far_leaf = door_leaf(FAR_DOOR, "")
	door_leaf(Vector3(2.6, 0, -7.2), "109")
	door_leaf(Vector3(5.0, 0, 1.0), "108")
	door_leaf(Vector3(5.0, 0, -4.5), "110")
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

## A door leaf hinged at the south edge of a doorway in a wall running along Z;
## returns its hinge. A negative turn swings it towards +X.
func door_leaf(centre: Vector3, number: String) -> Node3D:
	var width: float = FLOOR.LEAF_WIDTH
	var hinge := Node3D.new()
	hinge.position = centre + Vector3(0, 0, width * 0.5)
	builder.add_child(hinge)
	var holder := Node3D.new()
	holder.rotation.y = PI / 2
	hinge.add_child(holder)
	var leaf := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 2.58, 0.07)
	mesh.material = builder.materials.door
	leaf.mesh = mesh
	leaf.position = Vector3(width * 0.5, 1.29, 0)
	holder.add_child(leaf)
	for face in [-1, 1]: builder.box(holder, Vector3(width - 0.14, 1.08, face * 0.07), Vector3(0.14, 0.04, 0.05), "gold")
	if not number.is_empty():
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
	# Low dresser at the foot of the bed carrying the big set.
	var dresser := Vector3(TV.x, 0.0, TV.z + 0.08)
	builder.box(builder, dresser + Vector3(0, TV.y * 0.5, 0), Vector3(1.6, TV.y, 0.8), "wood", true)
	for x in [-0.4, 0.4]: builder.box(builder, dresser + Vector3(x, 0.32, -0.41), Vector3(0.7, 0.2, 0.02), "trim")
	tv_node = Node3D.new()
	tv_node.name = "Television"
	tv_node.position = TV
	tv_node.rotation.y = PI
	tv_node.scale = Vector3.ONE * TV_SCALE
	builder.add_child(tv_node)
	var body := MeshInstance3D.new()
	body.mesh = load("res://assets/props/tv/tv_body.res")
	# Its own screen does not light the set's casing (see build_lights).
	body.layers = 2
	tv_node.add_child(body)
	broadcast = BROADCAST.new()
	broadcast.name = "Broadcast"
	add_child(broadcast)
	broadcast.build(builder.materials)
	cracks = CRACKS.new()
	var glass := MeshInstance3D.new()
	glass.name = "Screen"
	glass.mesh = load("res://assets/props/tv/tv_screen.res")
	screen = ShaderMaterial.new()
	screen.shader = load("res://game/intro/tv_screen.gdshader")
	screen.set_shader_parameter("cracks", cracks.texture)
	screen.set_shader_parameter("image", broadcast.get_texture())
	for parameter in ["flash", "crack_level", "image_amount", "roll", "flicker", "unstable"]: screen.set_shader_parameter(parameter, 0.0)
	glass.material_override = screen
	tv_node.add_child(glass)
	for spot in [[Vector3(2.0, 0, -2.7), "luggage", 3], [Vector3(-2.35, 0, 1.6), "curtain", 1]]:
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
	var desk := Node3D.new()
	desk.position = Vector3(11.8, 0, -12.6)
	builder.add_child(desk)
	builder.build_prop(desk, "reception")

func build_lights() -> void:
	# The television is the only light in the bedroom.
	tv_light = OmniLight3D.new()
	# Just off the glass: the room is lit, the set's own casing barely.
	tv_light.position = SCREEN + Vector3(0, 0, -0.3)
	tv_light.light_color = Color(0.72, 0.82, 1.0)
	tv_light.omni_range = 8.0
	tv_light.omni_attenuation = 1.4
	tv_light.shadow_enabled = true
	tv_light.light_size = 0.4
	tv_light.light_cull_mask = ~2
	add_child(tv_light)
	# Warm light in the room at the end of the corridor, spilling through its ajar door.
	var warm := OmniLight3D.new()
	warm.position = Vector3(7.5, 2.0, -11.0)
	warm.light_color = Color("ffb877")
	warm.light_energy = 3.0
	warm.omni_range = 7.5
	warm.shadow_enabled = true
	add_child(warm)
	# The reception beyond: the red lamp that marks the start of the floor.
	beacon = OmniLight3D.new()
	beacon.position = Vector3(11.2, 2.45, -11.0)
	beacon.light_color = Color(1.0, 0.1, 0.06)
	beacon.light_energy = 2.4
	beacon.omni_range = 8.0
	beacon.shadow_enabled = true
	add_child(beacon)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.5, 0.02, 0.02)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.08, 0.04)
	glow.emission_energy_multiplier = 4.0
	var lens := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.11
	dome.height = 0.14
	dome.material = glow
	lens.mesh = dome
	lens.position = Vector3(11.2, HEIGHT - 0.22, -11.0)
	add_child(lens)
	# A barely lit corridor: an exit sign glowing at the far end.
	var sign := OmniLight3D.new()
	sign.position = Vector3(3.8, 2.4, -13.7)
	sign.light_color = Color(0.5, 0.78, 0.55)
	sign.light_energy = 0.07
	sign.omni_range = 4.0
	add_child(sign)
	# Streetlight through the curtain: just enough to find the door in the dark.
	var window := OmniLight3D.new()
	window.position = Vector3(-2.2, 1.9, 1.6)
	window.light_color = Color(0.5, 0.58, 0.75)
	window.light_energy = 0.6
	window.omni_range = 6.0
	add_child(window)
	# Faint grey night light along the corridor, just enough to read its shape.
	for z in [0.5, -6.0]:
		var night := OmniLight3D.new()
		night.position = Vector3(3.8, 2.6, z)
		night.light_color = Color(0.55, 0.62, 0.75)
		night.light_energy = 0.24
		night.omni_range = 6.5
		add_child(night)
	builder.box(builder, Vector3(3.8, 2.45, -13.88), Vector3(0.5, 0.18, 0.05), "green")
	builder.flush()
