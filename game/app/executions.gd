extends Node
## The creature catching a survivor (docs/EXECUTION.md): the capture the host
## decides -- who, and how they were caught -- and the scene every machine
## plays out from it on one clock: the creature bent over its victim with the
## mask at their lens, the swipe that takes the camera, the body lifted, the
## blow, the body let fall, and the death registered at the end. Split out of
## hotel_main.gd, which owns it (`level.executions`); the level keeps
## delegates of what the network, the bots and the tests reach through it.
##
## This is the scene as it is in the world, the same for everybody. What the
## camcorder of whoever dies makes of it is death_tape.gd, on their machine
## only; every beat and curve of it is in capture_score.gd.
const SCORE := preload("res://game/app/capture_score.gd")
const CAMCORDER := preload("res://assets/props/camcorder/camcorder.res")
const AVATAR := preload("res://game/player/avatars/avatar_visual.gd")
const FALL := preload("res://game/app/camera_fall.gd")
var level

## A kill in progress. The floor only registers the death when it ends.
##   seat, time, point, yaw   who, the scene's clock, and where the creature
##                            stands and faces (its victim, always)
##   entry, side              how they were caught (capture_score.ENTRIES) and
##                            to which side things go: the swipe, the fall
##   far                      how far from it they are held while the face lasts
##   from, facing, crouched   where the victim was, where it looked and how
##   torch                    its torch was on
##   straight, slump, room    the fall where there is no room for it back
##                            and to a side: laid straight back, or folded up
##                            (slump) with `room` metres behind (fall_room)
##   hide                     the wardrobe it was taken from (its index), -1
##   glance                   the host would have it look at the lens
##   seed, id                 what is drawn from chance, and which capture
##   ending, lens             "leave" or "glance", and where the camera lies
##                            once its owner's machine has said (note_lens)
##   stabs, dropped, screamed beats already played
var execution := {}

const SCREAM := "res://assets/audio/events/execution_scream.wav"

const KILL_BLOW := "res://assets/audio/events/execution_hit.wav"

const DEAD_CHANNEL := "res://assets/audio/events/execution_static.ogg"

## A body on a floor: recordings the game already had, played low.
const BODY_FALL := ["res://assets/audio/intro/stomp_1.wav", "res://assets/audio/intro/stomp_2.wav", "res://assets/audio/intro/stomp_3.wav"]

## The beats of the scene others read by name (capture_score.gd has them all):
## the arm starts, the blow lands, the victim's picture goes, the body falls.
const ARM_TIME := SCORE.ARM_TIME

const KILL_TIME := SCORE.KILL_TIME

const SIGNAL_TIME := SCORE.CUT_TIME

const DROP_TIME := SCORE.DROP_TIME

## How long the arm takes from drawn back to through.
const ARM_SWING := KILL_TIME - ARM_TIME

## How long the victim's own screen stays lost before it starts watching a
## teammate. Alone, or with everyone else dead, the failure screen takes over
## instead and this never runs out.
const LOST_HOLD := 2.6

## The look at the lens before it leaves: one capture in this many, alone and
## in a team (alone there is nobody else for it to go after).
const GLANCE_ALONE := 3
const GLANCE_TEAM := 6
## And how late the victim's machine may still say where its camera lies for
## the look to happen.
const GLANCE_BY := 2.0

## How many captures this floor has had (the host's count: a capture's id).
var captures := 0
## Seat -> its last capture ended with the look: never twice running.
var glanced := {}
## What the next capture is made to be, whatever the place says: for the
## bench and the tests. {entry, side, glance}.
var forced := {}
var rng := RandomNumberGenerator.new()
## What captures have left lying on the floor (camcorders, torches still
## lit), until the stage is over.
var leavings: Array = []
## And the wardrobes they left open, a body in their mouth.
var held_open: Array = []
## The torch of whoever is being executed, out of their hand: {node, lamp,
## hand, rest, turn}. It is knocked aside at the grab, falls with the swipe,
## rolls and comes to rest alight, on every machine the same.
var torch := {}
## The camcorder of the capture in hand, between its owner's hands and the
## floor: {node, rest, fall}: for whoever watches, the same fall its owner's
## tape records from inside it (camera_fall.fall_to).
var camcorder := {}
## The camcorder this capture has put on the floor, while the capture lasts:
## let go alive, its owner has it in their hands again.
var dropped: MeshInstance3D
## How long it takes to reach the floor, how long it goes on rolling there,
## and how far round it turns as it does (radians).
const TORCH_FALL := 0.5
## The glow round its glass: strength and reach (metres).
const TORCH_SPILL := Vector2(0.3, 1.2)
const TORCH_ROLL := 1.15
const TORCH_TURN := 1.5

func _ready() -> void:
	rng.randomize()

## A new floor, or a stage given back: nothing of the captures before is left.
func reset() -> void:
	captures = 0
	glanced.clear()
	clear_leavings()

func clear_leavings() -> void:
	for left in leavings:
		if is_instance_valid(left): left.queue_free()
	leavings.clear()
	release_wardrobes()

## The wardrobes somebody was taken out of shut again: the body is gone from
## their mouth, or was let go alive.
func release_wardrobes() -> void:
	for wardrobe in held_open:
		if is_instance_valid(wardrobe): wardrobe.release_open()
	held_open.clear()

## The creature reached this survivor: the execution starts and the death is
## registered when it ends (host, or offline).
func capture_survivor(body: Node3D) -> void:
	if body == null or level.net.is_client() or not execution.is_empty() or not is_instance_valid(level.locust): return
	if level.session.participants.get(body.slot, level.session.Life.DEAD) != level.session.Life.EXPLORING: return
	if level.lifts.riding.has(int(body.slot)) or level.point_protected(body.global_position): return
	if level.spare.is_valid() and bool(level.spare.call(body)): return
	# How it was caught is read off where everybody is now, before the victim
	# is taken out of whatever it was hiding in.
	var data := stage_capture(body)
	if level.match_net.in_match(): level.match_net.free_victim_hide(body.slot)
	var point: Vector3 = level.locust.global_position
	apply_execution(body.slot, point, float(data.yaw), data)
	if level.match_net.in_match(): level.match_net.execute_start.rpc(body.slot, point, float(data.yaw), data)
	# Alone, with no stage left to be given back, the floor is lost from this
	# moment: closing the game before the blow falls leaves nothing to go on
	# with (a floor that is lost is not played again).
	elif body == level.player and level.session.last_fall(): level.session.forget_checkpoint()

## What the host decides about a capture: everything the scene needs that is
## not the same on every machine by itself.
func stage_capture(body: Node3D) -> Dictionary:
	var creature = level.locust
	var away: Vector3 = body.global_position - creature.global_position
	away.y = 0.0
	var distance := away.length()
	# It is on them in the same instant it is in reach: the last of the way is
	# its own, as far as the place lets its body go, and its victim is drawn in
	# over what is left (place_victim). Too near, it is the one that gives way:
	# pushed back to arm's length, somebody against a wall went into it.
	var wanted := clampf(distance, SCORE.HOLD_FAR.x, SCORE.HOLD_FAR.y)
	if distance >= 0.05 and absf(distance - wanted) > 0.02 and creature.control != "puppet" and not bool(body.hidden):
		creature.move_and_collide(away / distance * (distance - wanted))
		away = body.global_position - creature.global_position
		away.y = 0.0
		distance = away.length()
	# It turns to its victim, wherever it was facing when it reached them.
	var yaw: float = creature.rotation.y if distance < 0.05 else atan2(-away.x, -away.z)
	var chosen := choose_entry(body, away)
	captures += 1
	var seat := int(body.slot)
	var alone: bool = level.session.roster_count <= 1
	var look: bool = not bool(glanced.get(seat, false)) and rng.randi_range(1, GLANCE_ALONE if alone else GLANCE_TEAM) == 1
	if forced.has("glance"): look = bool(forced.glance)
	glanced[seat] = look
	var side: float = float(forced.get("side", chosen[1]))
	var feet: Vector3 = creature.global_position - Basis(Vector3.UP, yaw).z * SCORE.HOLD_NEAR
	var room := fall_room(feet, yaw, side, [body.get_rid(), creature.get_rid()])
	var hide: int = level.hotel.hides.find(body.hiding_place) if bool(body.hidden) and is_instance_valid(body.hiding_place) else -1
	return {
		"entry": String(forced.get("entry", chosen[0])), "side": float(room[0]), "straight": bool(room[1]), "slump": bool(room[2]), "room": float(room[3]), "yaw": yaw, "hide": hide,
		"far": clampf(distance, SCORE.HOLD_FAR.x, SCORE.HOLD_FAR.y), "from": body.global_position, "facing": body.rotation.y,
		"crouched": bool(body.crouched), "torch": is_instance_valid(body.torch) and body.torch.visible,
		"glance": look, "seed": rng.randi() & 0x7fffffff, "id": captures,
	}

## How somebody is caught, from where they and the creature are: [entry, side].
## In a wardrobe it is the wardrobe's; crouching, it comes from above; and on
## their feet it is where they were looking -- at it, away from it or neither.
## The side is the hand it is on (1 their right), or chance when it is ahead
## or behind.
func choose_entry(body: Node3D, away: Vector3) -> Array:
	var creature = level.locust
	var chance := 1.0 if rng.randf() < 0.5 else -1.0
	if bool(body.hidden) and is_instance_valid(body.hiding_place): return ["ambush" if creature.get("pouncing") == true else "wardrobe", chance]
	if bool(body.crouched): return ["above", chance]
	if away.length() < 0.05: return ["front", chance]
	var look := -Basis(Vector3.UP, body.rotation.y).z
	var towards := -away.normalized()
	var angle := rad_to_deg(look.angle_to(towards))
	if angle <= 50.0: return ["front", chance]
	if angle >= 130.0: return ["back", chance]
	return ["side", 1.0 if towards.dot(Basis(Vector3.UP, body.rotation.y).x) > 0.0 else -1.0]

## How the body goes down when it is let go, from the room there is where it
## hangs: laid out back and to one side, to the other side if that one is
## taken, straight back if neither is free, and with no room to lie at all,
## folded up against whatever is behind it. [side, straight, slump, room]:
## the last is how far back it is clear, in metres. (Folded up it used to
## lean back a fixed half of the way down whatever was there: through the
## side of a wardrobe, or a wall.)
func fall_room(feet: Vector3, yaw: float, side: float, exclude: Array) -> Array:
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for way in [side, -side]:
		if clear_along(space, feet, fall_way(yaw, float(way)), [0.35], exclude) >= SCORE.LIE_ROOM: return [float(way), false, false, SCORE.LIE_ROOM]
	var behind := clear_along(space, feet, fall_way(yaw, 0.0), [0.2, 0.6], exclude)
	if behind >= SCORE.LIE_ROOM: return [side, true, false, behind]
	return [side, false, true, behind]

## How far it is clear from a spot on the floor in a direction, at the
## nearest of some heights, up to the length of a body.
func clear_along(space: PhysicsDirectSpaceState3D, feet: Vector3, along: Vector3, heights: Array, exclude: Array) -> float:
	var least: float = SCORE.LIE_ROOM
	for height in heights:
		var from: Vector3 = feet + Vector3.UP * float(height)
		var query := PhysicsRayQueryParameters3D.create(from, from + along * SCORE.LIE_ROOM, 1 | 8)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if not hit.is_empty(): least = minf(least, from.distance_to(hit.position))
	return least

## The way a body falls, in the world: back from the creature and to a side
## (the avatar's own, avatar_visual.pose_capture); straight back with no side.
static func fall_way(yaw: float, side: float) -> Vector3:
	return (Basis(Vector3.UP, yaw + PI) * Vector3(side * 0.62, 0.0, 0.78)).normalized()

## Everyone plays out the execution, from what the host decided. The victim's
## own machine hands its picture to its tape.
func apply_execution(seat: int, point: Vector3, yaw: float, data := {}) -> void:
	var forward := -Basis(Vector3.UP, yaw).z
	var far := float(data.get("far", SCORE.HOLD_FAR.y))
	execution = {
		"seat": seat, "time": 0.0, "point": point, "yaw": yaw, "stabs": 0, "dropped": false, "screamed": false,
		"entry": String(data.get("entry", "front")), "side": float(data.get("side", 1.0)), "slump": bool(data.get("slump", false)),
		"straight": bool(data.get("straight", false)), "room": float(data.get("room", SCORE.LIE_ROOM)), "hide": int(data.get("hide", -1)),
		"far": far, "from": data.get("from", point + forward * far), "facing": float(data.get("facing", yaw + PI)),
		"crouched": bool(data.get("crouched", false)), "torch": bool(data.get("torch", false)),
		"glance": bool(data.get("glance", false)), "seed": int(data.get("seed", 0)), "id": int(data.get("id", 0)),
		"ending": "leave",
	}
	if is_instance_valid(level.locust):
		if level.locust.control != "puppet": level.locust.begin_execution()
		# Turned to its victim on every machine: the scene is laid out along it.
		level.locust.rotation.y = yaw
	if bool(execution.torch): drop_torch()
	# Taken out of a wardrobe, its doors stay as they are thrown: the body is
	# let fall in its mouth, and they shut through it.
	var taken_from := int(execution.hide)
	if taken_from >= 0 and is_instance_valid(level.hotel) and taken_from < level.hotel.hides.size():
		var wardrobe: Node3D = level.hotel.hides[taken_from]
		wardrobe.hold_open()
		if not held_open.has(wardrobe): held_open.append(wardrobe)
	if seat == level.player.slot and not level.bot_match:
		# The grip: a long, deep shake, and each beat lands on top of it.
		level.rumble(0.5, 0.9, 0.7)
		level.player.active = false
		level.player.held = true
		level.player.velocity = Vector3.ZERO
		if level.player.hidden: level.player.force_leave_hide()
		# Whatever was up over the picture goes -- torn out of it, not put
		# away (hotel_ui.tear_away) -- and the tape is told it was.
		var sheet_up: bool = level.ui.sheet.visible
		var covered: bool = sheet_up or level.lock_open or is_instance_valid(level.reading_document)
		level.ui.tear_away()
		if sheet_up: level.toggle_sheet()
		if level.lock_open: level.close_lock()
		if is_instance_valid(level.reading_document): level.close_document()
		if sheet_up: level.ui.tear_sheet()
		level.ui.hint.text = ""
		level.ui.progress.visible = false
		# Nor is what the sector asks for left written over it, caught in the
		# first seconds of one: the pause screen keeps it.
		level.ui.hide_brief()
		# The brackets round whatever it was about to use are gone at once: they
		# are not left fading over the face.
		level.camcorder.focus("")
		level.camcorder.focus_amount = 0.0
		level.tape.begin(execution, covered)
	scream()

## The scream is the face: a twentieth of a second after the mask is in
## front of its victim's lens (capture_score.scream_time), flat and loud in
## the victim's own ears, and out in the room for everybody else.
func scream() -> void:
	if execution.is_empty() or bool(execution.get("screamed", false)): return
	var mine: bool = int(execution.seat) == level.player.slot and not level.bot_match
	if float(execution.time) < SCORE.scream_time(String(execution.get("entry", "front")), mine and level.tape.running and level.tape.busy): return
	execution["screamed"] = true
	if not level.world_audio.enabled: return
	if mine:
		if is_instance_valid(level.scream_sound):
			level.scream_sound.pitch_scale = 1.0
			level.scream_sound.volume_db = level.tape.SOFT_DB if level.tape.soft else 0.0
			level.scream_sound.play()
	# Everybody else hears it wherever they are on the floor: somebody has been
	# caught, and nobody should miss that it happened.
	else: level.world_audio.play_everywhere(SCREAM, creature_point() + Vector3(0, 2.0, 0), -4.0, 0.0)

## The clock of the scene, what is heard at each beat, the bodies put where
## it says and, on the host, the death at the end.
func update_execution(delta: float) -> void:
	if execution.is_empty(): return
	execution.time += delta
	var time := float(execution.time)
	var mine: bool = int(execution.seat) == level.player.slot and not level.bot_match
	scream()
	# The whoosh starts with the arm and its impact lands as the arm does:
	# heard from where the creature is, by its victim too.
	if int(execution.stabs) == 0 and time >= ARM_TIME:
		if level.world_audio.enabled: level.world_audio.play_everywhere(KILL_BLOW, creature_point() + Vector3(0, 1.7, 0), -1.0, 0.0)
		execution.stabs = 1
	if int(execution.stabs) == 1 and time >= KILL_TIME:
		if mine: level.rumble(0.2, 1.0, 0.35)
		execution.stabs = 2
	if not execution.dropped and time >= DROP_TIME: execution.dropped = true
	# The body on the floor. It fell in silence while the picture was already
	# black, where it read as a second blow; seen falling, it has to be heard.
	if int(execution.stabs) == 2 and time >= DROP_TIME + SCORE.FALL_LENGTH * 0.85:
		execution.stabs = 3
		if level.world_audio.enabled: level.world_audio.play_at(BODY_FALL[int(execution.seed) % BODY_FALL.size()], body_rest() + Vector3.UP * 0.2, -7.0, RID(), -1.0, 0.74)
		if mine: level.rumble(0.3, 0.5, 0.2)
	place_victim(delta)
	move_torch(time)
	move_camcorder(time)
	if is_instance_valid(level.locust) and is_instance_valid(level.locust.visual) and "scene" in level.locust.visual: level.locust.visual.scene = scene_for()
	var ends: float = level.locust.EXECUTION_TIME + 0.3 if is_instance_valid(level.locust) else SCORE.END_TIME
	if time >= ends: finish_execution()

## The scene has run its length: the body is the floor's, and the death the
## host's to count.
func finish_execution() -> void:
	var seat := int(execution.seat)
	var mine: bool = seat == level.player.slot and not level.bot_match
	leave_scene()
	# Its own picture is gone: it keeps the lost signal a moment before it
	# ends up watching somebody else's camera.
	if mine:
		level.tape.stop(false)
		level.lost_signal = LOST_HOLD
		level.ui.lost_signal(LOST_HOLD)
		# Its camcorder is a thing on the floor now, for whoever it watches through.
		for left in leavings:
			if is_instance_valid(left) and left is MeshInstance3D and (left as MeshInstance3D).layers == 2:
				AVATAR.put_on_layers(left, 1)
				level.hotel.adopt(left)
	execution = {}
	# Only the victim was held by it: somebody else's death let whoever was
	# mid-ride walk about in the dark.
	if mine: level.player.held = not level.lifts.boarding.is_empty() or level.lifts.leaving >= 0.0
	if not level.net.is_client():
		level.ledger.note_death(seat)
		level.session.capture(seat)
	# Alone, and the floor giving the stage back: there is nobody to watch,
	# so the picture stays gone and the body still until it is up again at
	# the stage's door (revival.restore_local_player).
	if mine and not level.match_net.in_match() and level.session.restart_wait > 0.0:
		level.player.held = true
		level.player.active = false
		level.lost_signal = level.session.restart_wait + 0.6
		level.ui.lost_signal(level.session.restart_wait + 0.6)

## An execution cut short: the victim is let go alive, back on its feet with a
## clean picture, and the creature leaves the kill.
func release_execution() -> void:
	var seat := int(execution.seat)
	var mine: bool = seat == level.player.slot and not level.bot_match
	# Let go alive: the camcorder is in its hands again, and its torch, lit
	# as it was.
	if is_instance_valid(dropped):
		leavings.erase(dropped)
		dropped.queue_free()
	camcorder = {}
	if not torch.is_empty():
		var body := victim_body()
		if is_instance_valid(torch.node):
			leavings.erase(torch.node)
			torch.node.queue_free()
		if body != null and is_instance_valid(body.torch): body.torch.visible = true
	leave_scene(true)
	# Whoever it was being taken out of a wardrobe is not left in its mouth:
	# that wardrobe shuts again (any other, with a body still in it, stays).
	var taken_from := int(execution.get("hide", -1))
	if taken_from >= 0 and is_instance_valid(level.hotel) and taken_from < level.hotel.hides.size():
		var wardrobe: Node3D = level.hotel.hides[taken_from]
		wardrobe.release_open()
		held_open.erase(wardrobe)
	execution = {}
	if mine:
		level.tape.stop(true)
		level.player.held = not level.lifts.boarding.is_empty() or level.lifts.leaving >= 0.0
		if is_instance_valid(level.scream_sound): level.scream_sound.stop()
		level.clear_screen_cues()
	if is_instance_valid(level.locust) and level.locust.control != "puppet" and level.locust.mode == level.locust.Mode.EXECUTE:
		level.locust.set_mode(level.locust.Mode.SEARCH if level.locust.control == "ai" else level.locust.Mode.PATROL)

## The scene lets go of the creature, and of the body if it is still alive:
## a body that was killed stays as it fell until it is taken away or stood up
## again (remote_player.set_dead, revival.restore_local_player).
func leave_scene(alive := false) -> void:
	var body := victim_body()
	if alive and body != null and "avatar" in body and body.avatar != null: body.avatar.end_capture()
	if is_instance_valid(level.locust) and is_instance_valid(level.locust.visual) and "scene" in level.locust.visual: level.locust.visual.scene = {}
	torch = {}
	# Wherever the scene stopped, the camcorder is on the floor.
	if not camcorder.is_empty() and is_instance_valid(camcorder.node):
		camcorder.node.visible = true
		camcorder.node.transform = camcorder.rest
	camcorder = {}
	dropped = null

# --- Where everything is ------------------------------------------------------------

func creature_point() -> Vector3:
	return level.locust.global_position if is_instance_valid(level.locust) else execution.point

func creature_forward() -> Vector3:
	return -Basis(Vector3.UP, float(execution.yaw)).z

## Whoever is being executed, as a body on this machine: its own player, a
## teammate's or a bot's.
func victim_body() -> Node3D:
	if execution.is_empty(): return null
	var seat := int(execution.seat)
	var other = level.match_net.bodies.get(seat)
	if is_instance_valid(other): return other
	return level.player if seat == level.player.slot else null

## Where the victim of the execution in hand is: on the arm in front of the
## creature, at arm's length while the face lasts, then lifted and drawn in
## as it straightens, and on the floor once it lets go.
func victim_hold_point() -> Vector3:
	var time := float(execution.time)
	var far := float(execution.get("far", SCORE.HOLD_FAR.y))
	var reach := lerpf(far, SCORE.HOLD_NEAR, SCORE.closing(time))
	return creature_point() + creature_forward() * reach + Vector3(0, SCORE.HOLD_STAND * (1.0 - SCORE.fall(time)) + SCORE.lift(time) * SCORE.LIFT_HEIGHT, 0)

## How high the victim is held at a second of it.
func victim_lift(time: float) -> float:
	return SCORE.lift(time)

## Where the victim's camera is while the face lasts: at its own eyes, where
## it was pulled to.
func lens_point() -> Vector3:
	var far := float(execution.get("far", SCORE.HOLD_FAR.y))
	var eyes := 0.9 if bool(execution.get("crouched", false)) else 1.64
	return creature_point() + creature_forward() * far + Vector3(0, SCORE.HOLD_STAND + eyes, 0)

## From the lens, which way the mask is: ahead and a little over it; and
## straight above somebody caught crouching.
func mask_from() -> Vector3:
	if bool(execution.get("crouched", false)): return (Vector3.UP * 0.9 - creature_forward() * 0.35).normalized()
	return (-creature_forward() + Vector3.UP * 0.2).normalized()

## The floor where the body is let go, and where it lies: along the way it
## falls, or in a heap where it dropped.
func drop_point() -> Vector3:
	return creature_point() + creature_forward() * SCORE.HOLD_NEAR

## The way the body goes down: back and to its side, or straight back when
## that is all the room there is (laid out so, or folded up).
func fall_dir() -> Vector3:
	var straight: bool = bool(execution.get("straight", false)) or bool(execution.get("slump", false))
	return fall_way(float(execution.yaw), 0.0 if straight else float(execution.get("side", 1.0)))

func body_rest() -> Vector3:
	if bool(execution.get("slump", false)): return drop_point() + fall_dir() * SCORE.seat_back(float(execution.get("room", 0.0)))
	return drop_point() + fall_dir() * 0.85

## Where its head comes to lie (or to hang, sitting).
func head_rest() -> Vector3:
	if not bool(execution.get("slump", false)): return drop_point() + fall_dir() * 1.7
	var room := float(execution.get("room", 0.0))
	return drop_point() + fall_dir() * (SCORE.seat_back(room) + 0.1 + 0.45 * sin(SCORE.seat_lean(room)))

## What the tape of whoever dies needs to know of the place (death_tape.plan).
func staging() -> Dictionary:
	var far := float(execution.get("far", SCORE.HOLD_FAR.y))
	return {
		"lens": lens_point(), "middle": creature_point() + creature_forward() * far * 0.5, "hold": drop_point(), "body": body_rest(),
		"head": head_rest(), "creature": creature_point(),
	}

## What the creature needs to pose itself (locust_visual.pose_capture):
## places in the world, at this second.
func scene_for() -> Dictionary:
	var time := float(execution.time)
	var hold := victim_hold_point()
	# Somebody caught crouching is on their feet by the time they are lifted.
	var low := (1.0 - SCORE.lift(time)) if bool(execution.get("crouched", false)) else 0.0
	var lens = execution.get("lens")
	return {
		"time": time, "entry": String(execution.get("entry", "front")), "side": float(execution.get("side", 1.0)),
		"ending": String(execution.get("ending", "leave")), "lens": lens_point(), "mask_from": mask_from(),
		"chest": hold + Vector3.UP * lerpf(1.2, 0.68, low), "face": hold + Vector3.UP * lerpf(1.58, 0.88, low),
		"body": body_rest() + Vector3.UP * 0.12, "glance": (lens as Transform3D).origin if lens is Transform3D else Vector3.INF,
	}

## The victim's body put where the scene has it, on whichever machine this
## is, and posed: turned to the creature (round on its arm, caught from
## behind), held, hanging, and laid out when it falls.
func place_victim(delta: float) -> void:
	var body := victim_body()
	if body == null: return
	var time := float(execution.time)
	var entry := String(execution.get("entry", "front"))
	if "velocity" in body: body.velocity = Vector3.ZERO
	var wanted := victim_hold_point()
	# Pulled on to the arm over the first frames; from there it is the scene's.
	body.global_position = wanted if time > 0.3 else body.global_position.lerp(wanted, minf(1.0, delta * 18.0))
	var towards := float(execution.yaw) + PI
	if entry == "back": body.rotation.y = lerp_angle(float(execution.get("facing", towards)), towards, SCORE.turned(entry, time))
	else: body.rotation.y = lerp_angle(body.rotation.y, towards, minf(1.0, delta * 16.0))
	if "avatar" in body and body.avatar != null:
		body.avatar.pose_capture({
			"lift": SCORE.lift(time), "limp": SCORE.limp(time), "fall": SCORE.fall(time), "time": time, "side": float(execution.get("side", 1.0)),
			"slump": bool(execution.get("slump", false)), "straight": bool(execution.get("straight", false)), "room": float(execution.get("room", SCORE.LIE_ROOM)),
			"height": body.global_position.y - creature_point().y, "sill": seat_floor(), "clear": scene_bodies(),
		})

## The bodies of the scene, which what looks for walls looks through.
func scene_bodies() -> Array:
	var said: Array = []
	if is_instance_valid(level.locust): said.append(level.locust.get_rid())
	if level.player is CollisionObject3D: said.append(level.player.get_rid())
	for other in level.match_net.bodies.values():
		if is_instance_valid(other) and other is CollisionObject3D: said.append(other.get_rid())
	return said

## How far above the room's floor whoever folds up comes to sit: on the
## bottom board of the wardrobe they were taken from, if it has one.
func seat_floor() -> float:
	var index := int(execution.get("hide", -1))
	if index < 0 or not is_instance_valid(level.hotel) or index >= level.hotel.hides.size(): return 0.0
	return maxf(0.0, float(level.hotel.hides[index].inside_offset.y) - 0.04)

## The victim, on its own machine: nothing of the body is its own to move
## while it lasts (place_victim puts it, death_tape films it).
func hold_victim(_delta: float) -> void:
	level.player.velocity = Vector3.ZERO
	level.camcorder.focus("")
	level.ui.hint.text = ""
	level.ui.progress.visible = false

# --- The camera on the floor ---------------------------------------------------------

## The victim's machine says where its camera came to lie (death_tape), and
## whether what the creature does over it could be seen from there. The host
## makes the look of it, if it wanted one, and everybody is told.
func report_lens(id: int, rest: Transform3D, seen: bool) -> void:
	if level.match_net.in_match() and level.net.is_client(): level.match_net.tell_lens.rpc_id(1, id, rest, seen)
	else: settle_lens(id, rest, seen)

## The host's word on it (or the only machine's).
func settle_lens(id: int, rest: Transform3D, seen: bool) -> void:
	if execution.is_empty() or int(execution.get("id", -1)) != id: return
	var look: bool = seen and bool(execution.get("glance", false)) and float(execution.time) < GLANCE_BY
	note_lens(id, rest, look)
	if level.match_net.in_match() and not level.net.is_client(): level.match_net.lens_settled.rpc(id, rest, look)

## On every machine: the camcorder is on the floor there, and the scene ends
## with the look at it or without.
func note_lens(id: int, rest: Transform3D, look: bool) -> void:
	if execution.is_empty() or int(execution.get("id", -1)) != id: return
	execution["lens"] = rest
	execution["ending"] = "glance" if look else "leave"
	leave_camcorder(rest, int(execution.seat) == level.player.slot and not level.bot_match)

## The camcorder left where it fell, for whoever comes by: the model, lying as
## the camera lay. Its owner's own machine does not draw it while its picture
## is being taken from inside it.
func leave_camcorder(rest: Transform3D, own: bool) -> void:
	if not is_instance_valid(level.hotel): return
	var prop := MeshInstance3D.new()
	prop.name = "FallenCamcorder"
	prop.mesh = CAMCORDER
	prop.transform = rest
	# Not the layer the owner's own camera draws (the same one its body is on).
	if own: prop.layers = 2
	# Still in its owner's hands until the swipe (move_camcorder).
	prop.visible = false
	level.hotel.add_child(prop)
	leavings.append(prop)
	camcorder = {"node": prop, "rest": rest}
	dropped = prop

## The camcorder as everybody else sees it go: nothing until the swipe, then
## from where it was held to where it lies, turning over, and there to stay.
func move_camcorder(time: float) -> void:
	if camcorder.is_empty() or not is_instance_valid(camcorder.node): return
	var node: MeshInstance3D = camcorder.node
	var rest: Transform3D = camcorder.rest
	var since := time - (SCORE.face_end(String(execution.get("entry", "front"))) + SCORE.SWIPE_REACH)
	if since < 0.0: return
	node.visible = true
	if not camcorder.has("fall"):
		var exclude: Array = []
		if is_instance_valid(level.locust): exclude.append(level.locust.get_rid())
		var body := victim_body()
		if body != null: exclude.append(body.get_rid())
		camcorder["from"] = Transform3D(Basis(Vector3.UP, float(execution.yaw) + PI), lens_point())
		camcorder["fall"] = FALL.fall_to(level.get_world_3d().direct_space_state, rest, lens_point(), int(execution.get("seed", 0)), exclude)
	var fall: Dictionary = camcorder.fall
	if since >= float(fall.duration) + FALL.ROCK:
		node.transform = rest
		camcorder = {}
		return
	node.transform = FALL.pose(fall, camcorder.from, since)

# --- The torch on the floor ------------------------------------------------------------

## Where the victim's torch ends up, and pointing where: to the side the swipe
## sends things, a step or two from where the body hangs, lying on the floor
## and turned back towards the creature -- so that its beam runs along the
## carpet, up the creature and on to the wall behind it. Drawn from the
## capture's seed and stopped by the walls, which are the same on every
## machine: everybody sees it come to rest in the same place.
func torch_rest() -> Transform3D:
	var draw := RandomNumberGenerator.new()
	draw.seed = int(execution.get("seed", 0)) ^ 0x51ed
	var forward := creature_forward()
	var right := forward.cross(Vector3.UP)
	var side := float(execution.get("side", 1.0))
	var out := (forward * draw.randf_range(0.5, 0.9) - right * side * draw.randf_range(0.6, 1.0)).normalized()
	var from := lens_point() - Vector3.UP * 0.3
	# Far enough for its beam, level with the floor, to have opened up to the
	# height of legs by the time it reaches them.
	var spot := drop_point() + out * draw.randf_range(2.1, 2.9)
	var query := PhysicsRayQueryParameters3D.create(from, spot + Vector3.UP * 0.2, 1)
	var hit: Dictionary = level.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var back := from - (hit.position as Vector3)
		back.y = 0.0
		spot = (hit.position as Vector3) + back.normalized() * 0.25
	spot.y = creature_point().y + 0.035
	var aim := drop_point().lerp(creature_point(), 0.5) + Vector3.UP * 0.9 - spot
	return Transform3D(Basis(Vector3.UP, atan2(-aim.x, -aim.z) + draw.randf_range(-0.22, 0.22)) * Basis(Vector3.RIGHT, deg_to_rad(4.0)), spot)

## The victim's torch leaves its hand: the lamp it carried goes dark and one
## like it, with a body to it, takes its place in the world.
func drop_torch() -> void:
	var body := victim_body()
	if body == null or not is_instance_valid(body.torch) or not is_instance_valid(level.hotel): return
	var carried: SpotLight3D = body.torch
	var hand := carried.global_transform
	carried.visible = false
	var made := torch_prop(carried)
	var node: Node3D = made.node
	level.hotel.add_child(node)
	node.global_transform = hand
	leavings.append(node)
	torch = {"node": node, "lamp": made.lamp, "hand": hand, "rest": torch_rest(), "turn": float(execution.get("side", 1.0)) * TORCH_TURN}

## A torch out of somebody's hand: the thing itself and the light it had
## there. {node, lamp}.
func torch_prop(carried: SpotLight3D) -> Dictionary:
	var node := Node3D.new()
	node.name = "FallenTorch"
	var lamp := SpotLight3D.new()
	lamp.light_color = carried.light_color
	lamp.light_energy = carried.light_energy
	lamp.light_size = carried.light_size
	lamp.light_projector = carried.light_projector
	lamp.light_volumetric_fog_energy = 0.0
	lamp.light_bake_mode = Light3D.BAKE_DISABLED
	lamp.spot_range = carried.spot_range
	lamp.spot_angle = carried.spot_angle
	lamp.spot_attenuation = carried.spot_attenuation
	lamp.spot_angle_attenuation = carried.spot_angle_attenuation
	lamp.shadow_enabled = carried.shadow_enabled
	lamp.shadow_bias = carried.shadow_bias
	lamp.shadow_normal_bias = carried.shadow_normal_bias
	# Left lit on the floor, it is not somebody's across the hotel.
	lamp.distance_fade_enabled = true
	lamp.distance_fade_begin = 20.0
	lamp.distance_fade_length = 6.0
	lamp.position = Vector3(0, 0, -0.1)
	node.add_child(lamp)
	# What a torch's glass throws to its sides: next to nothing, and all that
	# reaches a mask the beam has been turned away from, or the carpet round a
	# torch lying on it.
	var spill := OmniLight3D.new()
	spill.light_color = carried.light_color
	spill.light_energy = TORCH_SPILL.x
	spill.omni_range = TORCH_SPILL.y
	spill.omni_attenuation = 1.6
	spill.shadow_enabled = false
	spill.light_volumetric_fog_energy = 0.0
	spill.light_bake_mode = Light3D.BAKE_DISABLED
	spill.position = Vector3(0, 0, -0.1)
	node.add_child(spill)
	var barrel := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.028
	tube.bottom_radius = 0.02
	tube.height = 0.17
	tube.radial_segments = 12
	tube.rings = 1
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.08, 0.08, 0.09)
	metal.metallic = 0.6
	metal.roughness = 0.45
	tube.material = metal
	barrel.mesh = tube
	# The tube lies along the beam, its wide end at the lamp.
	barrel.rotation.x = -PI * 0.5
	barrel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(barrel)
	var glass := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.025
	disc.bottom_radius = 0.025
	disc.height = 0.004
	disc.radial_segments = 12
	disc.rings = 1
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.93, 0.78)
	disc.material = glow
	glass.mesh = disc
	glass.rotation.x = -PI * 0.5
	glass.position = Vector3(0, 0, -0.087)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(glass)
	return {"node": node, "lamp": lamp}

## What a capture puts in the picture that nothing has drawn before it: the
## camcorder and the torch, as they lie on a floor. For the loading screen
## to draw once (presentation/shader_warmup.gd), which is where the first of
## each is paid for instead of in the middle of the scene.
func warmup_props() -> Array:
	var props: Array = []
	var prop := MeshInstance3D.new()
	prop.mesh = CAMCORDER
	props.append(prop)
	if is_instance_valid(level.player) and is_instance_valid(level.player.torch): props.append(torch_prop(level.player.torch).node)
	return props

## The torch through the scene: in a hand that has been knocked aside while
## the face lasts -- its beam crosses the mask for a frame or two and stays
## off it, on the floor to one side -- then down with the swipe, a bounce, a
## roll, and still.
func move_torch(time: float) -> void:
	if torch.is_empty() or not is_instance_valid(torch.node): return
	var node: Node3D = torch.node
	var rest: Transform3D = torch.rest
	var entry := String(execution.get("entry", "front"))
	var falls := SCORE.face_end(entry) + SCORE.SWIPE_REACH
	var forward := creature_forward()
	var right := forward.cross(Vector3.UP)
	var side := float(execution.get("side", 1.0))
	if time < falls:
		# Held still, but not at the mask: a white mask a hand away under the
		# beam is a blank, so the grip turns the hand and the mask is left with
		# the edge of the light.
		# In the hand, out to one side of the body and just ahead of it: level
		# with the mask, so what reaches the mask comes across it, not at it.
		var at: Vector3 = victim_hold_point() + Vector3.UP * (0.8 if bool(execution.get("crouched", false)) else 1.34) - forward * 0.2 - right * side * 0.32
		var mask := lens_point() + mask_from() * 0.17
		var aside := at + (-forward * 0.5 - right * side * 0.75 - Vector3.UP * 0.45).normalized()
		var struck := SCORE.smooth(SCORE.ramp(time, 0.0, 0.05))
		var aim := mask.lerp(aside, struck)
		node.global_transform = Transform3D(Basis.looking_at(aim - at, Vector3.UP), at)
		torch["thrown"] = node.global_transform
		return
	var thrown: Transform3D = torch.get("thrown", torch.hand)
	var since := time - falls
	if since < TORCH_FALL:
		var s := since / TORCH_FALL
		# Nothing pushes it on its way down but its weight.
		var point := thrown.origin.lerp(rest.origin, s)
		point.y = lerpf(thrown.origin.y, rest.origin.y, s * s) + 0.12 * 4.0 * s * (1.0 - s)
		var spin := Basis(Vector3(0.3, 1.0, 0.2).normalized(), TAU * 1.5 * s * side)
		node.global_transform = Transform3D(spin * Basis(thrown.basis.get_rotation_quaternion().slerp(rest.basis.get_rotation_quaternion(), s)), point)
		return
	# On the floor: one bounce, and rolling round to where it stops.
	var rolled := clampf((since - TORCH_FALL) / TORCH_ROLL, 0.0, 1.0)
	var left := pow(1.0 - rolled, 2.2)
	var hop := maxf(0.0, sin(PI * clampf((since - TORCH_FALL) / 0.12, 0.0, 1.0))) * 0.04
	var drift := (rest.basis * Vector3.RIGHT) * float(torch.turn) * 0.16 * left
	node.global_transform = Transform3D(Basis(Vector3.UP, float(torch.turn) * left) * rest.basis, rest.origin + drift + Vector3.UP * hop)
