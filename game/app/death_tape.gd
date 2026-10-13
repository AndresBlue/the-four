extends Node
## What the camcorder of whoever is caught records (docs/EXECUTION.md): the
## mask filling the lens, the swipe that knocks the camera out of its owner's
## hands, the floor it lands on, and from there, lying on its side and half
## hidden by whatever is next to it, what is done to them -- until the body
## falls beside it and the tape gives out.
##
## Only the victim's own machine runs this, and nothing it does is told to
## anybody or changes anything that can be done: the scene everybody plays
## out is executions.gd's, and this is one camera's recording of it. If it is
## never run, or stops half way, the capture goes on and the death is
## registered all the same. Split out of hotel_main.gd, which owns it
## (`level.tape`).
##
## The camera is the player's own throughout -- its iris, its focus and its
## motion blur carry on -- taken off the body (top_level) and written here
## every drawn frame from the scene's clock, after everything else has had
## its say (process_priority).
const SCORE := preload("res://game/app/capture_score.gd")
const FALL := preload("res://game/app/camera_fall.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

## The face in the lens: how far the lens is from the mask as it arrives, once
## it is there, and after the last jerk (metres; the pale of the mask is 14 cm
## high, so 51 and 63 % of the picture's height). Never nearer than MASK_NEAR.
const MASK_FAR := 0.26
const MASK_HELD := 0.165
const MASK_CLOSE := 0.135
const MASK_NEAR := 0.11
## And at the last it comes at the lens: in the LUNGE seconds before the
## swipe, from where it was held to MASK_LUNGE, faster the nearer it gets --
## the pale of it taller than the picture -- and it is there still when the
## arm takes the camera. Without it the face was a picture laid over the
## picture; with it, it is something coming. The lens sees that near
## (LENS_NEAR, metres) while a capture lasts.
const MASK_LUNGE := 0.082
const LUNGE := 0.07
const LENS_NEAR := 0.02
## It comes down into the picture: how far under the mask the lens is aimed on
## the first frame, and how far to one side when it comes in from the side.
const ARRIVE_DROP := 0.05
const ARRIVE_SIDE := 0.2
## The hand that holds the camera while the face is in it: a tremor of this
## many degrees at this rate, gone in SHAKE_FADE seconds.
const SHAKE := 0.4
const SHAKE_RATE := 13.0
const SHAKE_FADE := 0.3
## Caught from behind: how far the camera tips forward as its owner is
## stopped dead (radians).
const BACK_DIP := 0.3
## What a blow does to the picture: how hard and for how long, at the grab, as
## the camera hits the floor and as the body does beside it.
const HIT_GRAB := Vector2(0.4, 0.05)
const HIT_FLOOR := Vector2(1.0, 0.27)
## Each time it comes down again after that -- the hop, and every edge it
## goes over -- is that blow again, as much weaker as it was (camera_fall.blows)
## and this much shorter.
const HIT_AGAIN := 0.5
const HIT_BODY := Vector2(0.9, 0.32)
## The camcorder's microphone: what it passes, how far its automatic gain
## falls at a bang, how fast it comes back and how far over.
const MIC_LOW := 120.0
const MIC_HIGH := 6500.0
const AGC_FLOOR := -14.0
const AGC_BLOW := -9.0
const AGC_RISE := 7.0
const AGC_OVER := 6.0
## From the body's fall the tape does not run true again, and its sound goes
## with its picture: pieces of it missing, more of them as it frays. How many
## pieces a second, how long each is gone, how many go at the end and how far
## down one is.
const DROPOUT_RATE := 14.0
const DROPOUT_SHARE := 0.6
const DROPOUT_MOST := 0.55
const DROPOUT_DB := -22.0
## The camcorder's own lamp through a capture: strength, reach (metres) and
## how fast it falls off with distance (hotel_player.pilot_as). On a face a
## hand from the lens it falls off fast, which is what gives the mask its
## shape; with a torch about it is turned down, so the torch does the work.
## From the floor in the dark it has to reach a body a metre off without the
## carpet under the lens being all there is, so it falls off slowly; and with
## any other light it is only a stain on the carpet.
const LAMP_FACE := Vector3(0.5, 1.15, 1.4)
const LAMP_FACE_LIT := Vector3(0.22, 1.15, 1.4)
const LAMP_FLOOR_DARK := Vector3(1.3, 1.15, 0.5)
const LAMP_FLOOR_LIT := Vector3(0.2, 0.9, 1.2)
## How long before the blow the lamp's blink starts over: eight tenths, of
## which it is lit seven (camcorder_osd.LAMP_LIT).
const LAMP_BEFORE := 1.8
const HISS := "res://assets/audio/intro/tv_static.wav"
const HISS_DB := -33.0
const CASE_FALL := ["res://assets/audio/events/object_fall_1.wav", "res://assets/audio/events/object_fall_2.wav"]
const RUSTLES := ["res://assets/audio/intro/bed_shift.wav", "res://assets/audio/intro/bed_stir.wav"]
## The scream, soft: this much quieter (executions.scream).
const SOFT_DB := -8.0

var running := false
## The capture being recorded (executions' id), how it began and how it is
## shown: `busy`, something was up over the picture; `brief`, this way in has
## been seen on this floor already; `soft`, no face; `plain`, reduced effects.
var id := -1
var entry := "front"
var busy := false
var brief := false
var soft := false
var plain := false
## Where the camera falls (camera_fall.solve) and how it is doing: the camera
## in the hand at the grab, as the swipe took it, when that was, when it
## first touched the floor and when it lay still.
var take := {}
var hand := Transform3D.IDENTITY
var thrown := Transform3D.IDENTITY
var thrown_at := -1.0
var landed_at := -1.0
var rested_at := -1.0
## The picture is gone: snow, whatever the scene's clock says.
var gone := false
## Nothing lights the place but the camcorder's own lamp.
var dark := false
## The ways in already seen on this floor.
var seen := {}
var saved := {}
var mic: Array = []
var gain := 0.0
var hiss: AudioStreamPlayer
var done := {}

func _ready() -> void:
	# After the player, whose own _process trails the look and the focus.
	process_priority = 100
	hiss = AudioStreamPlayer.new()
	hiss.name = "TapeHiss"
	hiss.bus = "Effects"
	hiss.volume_db = HISS_DB
	hiss.stream = preload("res://game/audio/world_audio.gd").loop_stream(load(HISS))
	add_child(hiss)

## A new floor: nothing of it has been seen yet.
func reset() -> void:
	if running: stop(false)
	seen.clear()

## Whether the victim's picture is snow at this second of its capture: from
## the cut on, or -- the short version -- from when the camera came to rest.
func lost(time: float) -> bool:
	return time >= SCORE.CUT_TIME or gone

func recording() -> bool:
	return running

## The capture of this machine's own player starts. `covered`: a document,
## the sheet or the keypad was up over the picture when it was caught.
func begin(execution: Dictionary, covered := false) -> void:
	if running: stop(false)
	var player = level.player
	var camera: Camera3D = player.camera
	running = true
	gone = false
	done = {}
	id = int(execution.get("id", -1))
	entry = String(execution.get("entry", "front"))
	busy = covered
	soft = bool(level.settings.values.get("startle_soft", false))
	plain = bool(level.settings.values.reduced)
	brief = seen.has(entry)
	seen[entry] = true
	hand = camera.global_transform
	thrown = hand
	thrown_at = -1.0
	landed_at = -1.0
	rested_at = -1.0
	gain = 0.0
	saved = {"handheld": player.handheld_enabled, "zoom": player.zoom_wanted, "torch": player.torch.visible, "near": camera.near}
	camera.near = LENS_NEAR
	player.handheld_enabled = false
	player.reset_handheld()
	camera.top_level = true
	camera.global_transform = hand
	# The lamp's blink starts again with the capture, lit, and it is brought up.
	level.camcorder.blink = 0.0
	dark = is_dark(execution)
	# In a lit room it stays what it is carried as: a red cast on a mask the
	# room already lights would be a light from nowhere. In a wardrobe the mask
	# that comes in has the room behind it: the lamp is all that shows its face.
	if dark or entry in ["wardrobe", "ambush"]: player.pilot_as = LAMP_FACE
	elif bool(execution.get("torch", false)): player.pilot_as = LAMP_FACE_LIT
	# The face is there on the next frame: a jump, not a move to smear.
	if SCORE.face_start(entry) <= 0.0 or busy: level.rig.motion_cut()
	take = plan(execution)
	level.executions.report_lens(id, take.rest, int(take.kind) == FALL.VIEW and not brief and not dark)
	if soft:
		# No face: the picture is the camera already on the floor.
		thrown_at = 0.0
		landed_at = 0.0
		rested_at = 0.0
		level.camera_cut()
	update(execution)

## Nothing lights the place but what the victim carries.
func is_dark(execution: Dictionary) -> bool:
	if bool(execution.get("torch", false)): return false
	if not is_instance_valid(level.hotel): return false
	if level.hotel.dark: return true
	var room := FLOOR.room_at(level.manifest.rooms, execution.get("from", level.player.global_position))
	return not room.is_empty() and level.hotel.dark_ids.has(int(room.id))

## Where the camera is going to land, for this capture.
func plan(execution: Dictionary) -> Dictionary:
	var stage: Dictionary = level.executions.staging()
	var exclude: Array = [level.player.get_rid()]
	if is_instance_valid(level.locust): exclude.append(level.locust.get_rid())
	for body in level.match_net.bodies.values():
		if is_instance_valid(body): exclude.append(body.get_rid())
	var scene := {
		"from": stage.lens, "middle": stage.middle, "hold": stage.hold, "body": stage.body, "head": stage.head, "creature": stage.creature,
		"torch": (level.executions.torch.rest as Transform3D).origin if not level.executions.torch.is_empty() else Vector3.INF, "dark": dark, "exclude": exclude,
		"allowed": func(point: Vector3) -> bool: return not level.point_protected(point) and not door_sweeps(point),
	}
	return FALL.solve(level.get_world_3d().direct_space_state, scene, int(execution.get("seed", 0)))

## Whether a place on the floor is where a door on the move is about to be.
func door_sweeps(point: Vector3) -> bool:
	if not is_instance_valid(level.hotel): return false
	for door in level.hotel.doors_near(point, 1.6):
		if door.moving and Vector2(door.doorway.x - point.x, door.doorway.z - point.z).length() < 1.25: return true
	return false

func _process(_delta: float) -> void:
	if not running: return
	var execution: Dictionary = level.execution
	if execution.is_empty() or int(execution.get("seat", -1)) != level.player.slot or int(execution.get("id", -1)) != id:
		# The scene went away without a word (a floor torn down): hands back.
		stop(false)
		return
	update(execution)

func update(execution: Dictionary) -> void:
	var time := float(execution.time)
	var delta := get_process_delta_time()
	frame_camera(execution, time, delta)
	frame_picture(time)
	frame_sound(execution, time, delta)

# --- The camera -------------------------------------------------------------------

func fly_at() -> float:
	return SCORE.face_end(entry) + SCORE.SWIPE_REACH

func frame_camera(execution: Dictionary, time: float, delta: float) -> void:
	var player = level.player
	var camera: Camera3D = player.camera
	# Whatever the lens was zoomed to, it is wide again within a few frames.
	if player.zoom > 1.0:
		player.zoom_wanted = 1.0
		player.zoom = pow(2.0, move_toward(log(player.zoom) / log(2.0), 0.0, delta * 2.6 / 0.08))
	var face_from := 0.0 if busy else SCORE.face_start(entry)
	var wanted := camera.global_transform
	# The lamp's blink is set again from the floor, so that the blow falls in
	# the three tenths it is dark and the body comes down in its light
	# (docs/EXECUTION.md, 10).
	if once("lamp", time, SCORE.KILL_TIME - LAMP_BEFORE): level.camcorder.blink = 0.0
	if thrown_at < 0.0 and time >= fly_at():
		thrown_at = fly_at()
		landed_at = thrown_at + (0.0 if plain else float(take.landed))
		rested_at = thrown_at + (0.0 if plain else float(take.duration))
		if plain: level.camera_cut()
		# From here the tape sees its owner from outside.
		player.avatar.show_to_owner(true)
	if thrown_at >= 0.0:
		if plain or soft or rested_at <= thrown_at: wanted = take.rest
		else: wanted = FALL.pose(take, thrown, time - thrown_at)
		if time >= rested_at:
			# The body coming down beside it rocks it once more.
			var thud := time - body_at()
			if thud >= 0.0 and thud < 0.2 and not plain: wanted = wanted * Transform3D(Basis(Vector3.BACK, sin(thud * 60.0) * 0.012 * exp(-thud * 20.0)), Vector3.UP * 0.006 * sin(PI * thud / 0.2))
	elif time < face_from:
		wanted = turning(execution, time)
		thrown = wanted
	else:
		wanted = facing(execution, time - face_from, time)
		thrown = wanted
	if not wanted.origin.is_finite() or not wanted.basis.x.is_finite() or not wanted.basis.y.is_finite() or not wanted.basis.z.is_finite(): wanted = take.rest
	camera.global_transform = wanted.orthonormalized()
	# On the floor the lamp is a hand from the carpet: all there is to see by
	# in the dark, and with any other light only a red stain under the lens.
	if landed_at >= 0.0 and time >= landed_at and player.pilot_as.x >= 0.0: player.pilot_as = LAMP_FLOOR_DARK if dark else LAMP_FLOOR_LIT
	focus(time)

## The mask in the lens, `since` seconds after it got there: framed in the
## mask's own space, so the picture is the same against a wall as in the
## middle of a room.
func facing(execution: Dictionary, since: float, time: float) -> Transform3D:
	if not is_instance_valid(level.locust) or not is_instance_valid(level.locust.visual) or not "scene" in level.locust.visual: return thrown
	var mask: Transform3D = level.locust.visual.mask_transform()
	var side := float(execution.get("side", 1.0))
	var arrived := 1.0 if busy else SCORE.smooth(since / SCORE.ARRIVE)
	var jerk := SCORE.smooth(SCORE.ramp(since, SCORE.JERK_TIME, SCORE.JERK_TIME + SCORE.JERK_LENGTH))
	var distance := maxf(MASK_NEAR, lerpf(MASK_FAR, MASK_HELD, arrived) - (MASK_HELD - MASK_CLOSE) * jerk)
	var coming := 0.0 if soft else SCORE.ramp(time, SCORE.face_end(entry) - LUNGE, SCORE.face_end(entry))
	coming *= coming
	distance = lerpf(distance, MASK_LUNGE, coming)
	var eye := mask.origin + mask.basis.z * distance
	# Where the lens points: under the mask at first, so it comes down into
	# the picture; from the side, off to that side.
	var aim := mask.origin - Vector3.UP * ARRIVE_DROP * (1.0 - arrived)
	if entry == "side": aim += mask.basis.x * side * ARRIVE_SIDE * (1.0 - arrived)
	var ahead := aim - eye
	var up := Vector3.UP
	# Looking nearly straight up at it. Caught crouching, that is the picture:
	# its body is above it and the mask hangs in it the wrong way up. Any
	# other way it is the first frame or two of a lunge that ended with its
	# head over its victim, before it has bent down to the lens: the mask's
	# own top is the picture's, or it was upside down for a frame.
	if absf(ahead.normalized().y) > 0.85: up = Basis(Vector3.UP, float(execution.yaw)).z if entry == "above" else mask.basis.y
	var basis := Basis.looking_at(ahead, up)
	if not plain:
		var fade := exp(-since / SHAKE_FADE) + 0.25 + 2.0 * coming
		var tremble := deg_to_rad(SHAKE) * fade
		basis = basis * Basis.from_euler(Vector3(sin(time * TAU * SHAKE_RATE) * tremble, sin(time * TAU * SHAKE_RATE * 0.83 + 1.1) * tremble, sin(time * TAU * SHAKE_RATE * 1.21 + 2.3) * tremble * 0.7))
	return Transform3D(basis, eye)

## Caught from behind: the camera is pulled up short with its owner -- back
## on to the arm, tipping forward, far enough to see what has come through
## their chest -- and then swung round on that arm to the face that was there
## all along.
func turning(execution: Dictionary, time: float) -> Transform3D:
	var side := float(execution.get("side", 1.0))
	var face := facing(execution, 0.0, time)
	var turned := SCORE.turned(entry, time)
	var pulled := SCORE.smooth(minf(time / (SCORE.BACK_TURN_FROM * 0.45), 1.0))
	# The long way round or the short one, it goes the way the arm takes it.
	var from_yaw := hand.basis.get_euler().y
	var to_yaw := face.basis.get_euler().y
	var sweep := fposmod((to_yaw - from_yaw) * side, TAU)
	if sweep < 0.6: sweep += TAU
	var yaw := from_yaw + side * sweep * turned
	var pitch := lerpf(hand.basis.get_euler().x - BACK_DIP * pulled, face.basis.get_euler().x, turned)
	var roll := side * 0.5 * sin(PI * turned)
	var held: Vector3 = hand.origin.lerp(level.executions.lens_point(), pulled)
	return Transform3D(Basis.from_euler(Vector3(pitch, yaw, roll)), held.lerp(face.origin, turned))

## When the body is on the floor beside the camera.
func body_at() -> float:
	return SCORE.DROP_TIME + SCORE.FALL_LENGTH * 0.85

## The lens's focus: on the mask while the face lasts, and left wherever it
## was when the camera hit the floor -- the carpet in front of it.
func focus(time: float) -> void:
	var attributes: CameraAttributesPractical = level.player.focus_attributes
	if not level.player.autofocus or attributes == null: return
	if thrown_at < 0.0:
		attributes.dof_blur_near_enabled = false
		attributes.dof_blur_far_enabled = true
		attributes.dof_blur_far_distance = 0.45
		attributes.dof_blur_far_transition = 1.4
	else:
		attributes.dof_blur_near_enabled = false
		attributes.dof_blur_far_enabled = time >= landed_at
		attributes.dof_blur_far_distance = 0.9
		attributes.dof_blur_far_transition = 3.5

# --- The picture ------------------------------------------------------------------

func bump(time: float, at: float, shape: Vector2) -> float:
	var since := time - at
	if at < 0.0 or since < 0.0 or since > shape.y: return 0.0
	return shape.x * (1.0 - since / shape.y)

func frame_picture(time: float) -> void:
	if level.post_material == null: return
	# The short version: once the camera is still, the picture goes, and the
	# words that say so with it; the rest is heard.
	if brief and not gone and rested_at >= 0.0 and time >= rested_at + 0.15:
		gone = true
		level.ui.lost_signal(SCORE.END_TIME - time + level.executions.LOST_HOLD)
	var hit := 0.0
	var band := -1.0
	var fray := 0.0
	if not plain and not gone:
		# The grab bends the top of the picture and no more: the mask is under it.
		if not soft and not busy: hit = maxf(hit, bump(time, 0.0, HIT_GRAB))
		# The floor, each time it meets it, and the body beside it, send a band
		# of noise up it as well.
		var struck: Array = [[body_at(), HIT_BODY]]
		if landed_at >= 0.0 and rested_at > landed_at:
			for blow in FALL.blows(take): struck.append([thrown_at + float(blow[0]), Vector2(HIT_FLOOR.x * float(blow[1]), HIT_FLOOR.y * (1.0 if float(blow[1]) >= 1.0 else HIT_AGAIN))])
		else: struck.append([landed_at, HIT_FLOOR])
		for blow in struck:
			var strength := bump(time, float(blow[0]), blow[1])
			if strength <= 0.0: continue
			hit = maxf(hit, strength)
			band = 1.0 - (time - float(blow[0])) / (blow[1] as Vector2).y
		# From the body's fall the mechanism does not settle again.
		fray = pow(SCORE.ramp(time, body_at(), SCORE.CUT_TIME), 2.2)
	level.post_material.set_shader_parameter("tape_hit", hit)
	level.post_material.set_shader_parameter("tape_band", band)
	level.post_material.set_shader_parameter("tape_fray", fray)
	# Lying within reach of what the blow throws, the lens has some of it on
	# its glass from a tenth of a second after (blood.gd): to the end.
	var spattered := 0.0
	if not plain and not gone and rested_at >= 0.0 and rested_at <= SCORE.KILL_TIME and level.executions.blood.on_lens(id, (take.rest as Transform3D).origin): spattered = maxf(0.0, time - SCORE.KILL_TIME - 0.1)
	level.post_material.set_shader_parameter("lens_blood", spattered)
	level.post_material.set_shader_parameter("lens_seed", float(id % 89) + 0.37)

# --- The sound --------------------------------------------------------------------

func once(what: String, time: float, at: float) -> bool:
	if at < 0.0 or time < at or done.has(what): return false
	done[what] = true
	return true

func frame_sound(execution: Dictionary, time: float, delta: float) -> void:
	if not level.world_audio.enabled: return
	var scream: AudioStreamPlayer = level.scream_sound
	if is_instance_valid(scream):
		# It does not last the scene: once the camera is out of the hands it is
		# a sound left behind in the room, and it is over before the floor.
		var leaving := SCORE.ramp(time, SCORE.face_end(entry), 1.1)
		if leaving > 0.0 and scream.playing:
			scream.pitch_scale = lerpf(1.0, 0.9, leaving)
			scream.volume_db = (SOFT_DB if soft else 0.0) + lerpf(0.0, -42.0, leaving * leaving)
			if leaving >= 1.0: scream.stop()
	# From the swipe on, what is heard is what the camcorder's microphone
	# picks up from where it lies.
	if thrown_at >= 0.0 and mic.is_empty() and time < SCORE.CUT_TIME:
		mic_on()
		hiss.volume_db = HISS_DB
		hiss.play()
	if not mic.is_empty():
		gain = minf(AGC_OVER, gain + AGC_RISE * delta)
		if once("floor", time, landed_at):
			gain = AGC_FLOOR
			play_case(-3.0, 0.72)
		# And each time it comes down again: the same case, lighter and higher.
		if rested_at > landed_at:
			var again: Array = FALL.blows(take)
			for index in range(1, again.size()):
				if once("knock%d" % index, time, thrown_at + float(again[index][0])):
					gain = minf(gain, AGC_FLOOR * float(again[index][1]))
					play_case(-3.0 + linear_to_db(float(again[index][1])) - 3.0, 0.82 + 0.06 * float(index), index)
		if once("blow", time, SCORE.KILL_TIME): gain = minf(gain, AGC_BLOW)
		if once("body", time, body_at()): gain = minf(gain, AGC_FLOOR + 2.0)
		(mic[2] as AudioEffectAmplify).volume_db = gain + dropout(time)
	if once("rustle", time, SCORE.LIFT_FROM + 0.2): rustle(execution, 0)
	if once("rustle_again", time, SCORE.LIFT_FROM + 0.8): rustle(execution, 1)
	# The picture going is the channel dying: the same instant, not a beat
	# late. The short version loses its picture early and goes on hearing
	# through the snow, which is quieter until the tape really ends.
	var ended := time >= SCORE.CUT_TIME
	if lost(time) and once("snow", time, 0.0) and is_instance_valid(level.static_sound):
		level.static_sound.volume_db = -2.0 if ended else -15.0
		level.static_sound.play()
	if ended and once("cut", time, SCORE.CUT_TIME):
		mic_off()
		hiss.stop()
		if is_instance_valid(level.static_sound): level.static_sound.volume_db = -2.0

## What the sound loses at this second of a tape that is giving out: nothing,
## or a piece of it. Which pieces go is the capture's own draw, so a second
## of it is the same however often it is asked.
func dropout(time: float) -> float:
	if plain or gone: return 0.0
	var fray := pow(SCORE.ramp(time, body_at(), SCORE.CUT_TIME), 2.2)
	if fray <= 0.02: return 0.0
	var piece := floorf(time * DROPOUT_RATE)
	var draw := fposmod(sin(piece * 12.9898 + float(id) * 78.233) * 43758.5453, 1.0)
	return DROPOUT_DB if draw < fray * DROPOUT_MOST and fposmod(time * DROPOUT_RATE, 1.0) < DROPOUT_SHARE else 0.0

func play_case(db: float, pitch: float, which := 0) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = "Effects"
	player.stream = load(CASE_FALL[(int(take.get("side", 1.0) > 0.0) + which) % CASE_FALL.size()])
	player.pitch_scale = pitch
	player.volume_db = db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func rustle(execution: Dictionary, which: int) -> void:
	var at: Vector3 = level.executions.victim_hold_point() + Vector3.UP * 1.0
	level.world_audio.play_at(RUSTLES[which % RUSTLES.size()], at, -13.0)

## The microphone: a band of the sound and a gain that this node rides,
## ahead of everything on the master bus.
func mic_on() -> void:
	if not mic.is_empty(): return
	var low := AudioEffectHighPassFilter.new()
	low.cutoff_hz = MIC_LOW
	var high := AudioEffectLowPassFilter.new()
	high.cutoff_hz = MIC_HIGH
	var amplify := AudioEffectAmplify.new()
	amplify.volume_db = 0.0
	mic = [low, high, amplify]
	for index in mic.size(): AudioServer.add_bus_effect(0, mic[index], index)

func mic_off() -> void:
	for effect in mic:
		for index in AudioServer.get_bus_effect_count(0):
			if AudioServer.get_bus_effect(0, index) == effect:
				AudioServer.remove_bus_effect(0, index)
				break
	mic.clear()

# --- The end ----------------------------------------------------------------------

## The capture is over, or was let go (`alive`): the camera back in its
## owner's hands and everything this put on the picture and the sound off.
func stop(alive: bool) -> void:
	if not running: return
	running = false
	var player = level.player
	var camera: Camera3D = player.camera
	mic_off()
	hiss.stop()
	if level.post_material != null:
		level.post_material.set_shader_parameter("tape_hit", 0.0)
		level.post_material.set_shader_parameter("tape_band", -1.0)
		level.post_material.set_shader_parameter("tape_fray", 0.0)
		level.post_material.set_shader_parameter("lens_blood", 0.0)
	camera.top_level = false
	camera.near = float(saved.get("near", camera.near))
	camera.position = Vector3(0.0, player.eye_height, 0.0)
	camera.rotation = Vector3.ZERO
	player.handheld_enabled = bool(saved.get("handheld", true))
	player.reset_handheld()
	player.pilot_as = Vector3(-1.0, 0.0, 0.0)
	player.avatar.show_to_owner(false)
	var scream: AudioStreamPlayer = level.scream_sound
	if is_instance_valid(scream):
		scream.pitch_scale = 1.0
		scream.volume_db = 0.0
	if is_instance_valid(level.static_sound): level.static_sound.volume_db = -2.0
	if alive:
		# Let go: back behind its own eyes, as it was.
		player.zoom_wanted = float(saved.get("zoom", 1.0))
		gone = false
	level.camera_cut()
