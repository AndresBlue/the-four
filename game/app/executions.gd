extends Node
## The creature catching a survivor: the execution every machine plays out
## (the grab, the scream, the arm coming for the lens, the picture going), the
## victim held on the blade, and the death registered at the end. Split out of
## hotel_main.gd, which owns it (`level.executions`); the level keeps
## delegates of what the network, the bots and the tests reach through it.
var level

## A kill in progress: {seat, time, point, yaw, stabs, dropped}. The floor only
## registers the death when the last blow lands.
var execution := {}

const SCREAM := "res://assets/audio/events/execution_scream.wav"

const KILL_BLOW := "res://assets/audio/events/execution_hit.wav"

const DEAD_CHANNEL := "res://assets/audio/events/execution_static.ogg"

## The beats of an execution, in seconds from the grab. The scream is at zero,
## because that is the point of it; then it holds you and looks at you; then
## the arm comes for the lens, covers it and lands; and the picture goes.
const ARM_TIME := 2.58

const KILL_TIME := 2.8

const SIGNAL_TIME := 2.92

const DROP_TIME := 3.1

## How long the arm takes to go from a point to the whole screen.
const ARM_SWING := KILL_TIME - ARM_TIME

## How long the victim's own screen stays lost before it starts watching a
## teammate. Alone, or with everyone else dead, the failure screen takes over
## instead and this never runs out.
const LOST_HOLD := 2.6

## The creature reached this survivor: the execution starts and the death is
## registered when it ends (host, or offline).
func capture_survivor(body: Node3D) -> void:
	if body == null or level.net.is_client() or not execution.is_empty() or not is_instance_valid(level.locust): return
	if level.session.participants.get(body.slot, level.session.Life.DEAD) != level.session.Life.EXPLORING: return
	if level.lifts.riding.has(int(body.slot)) or level.point_protected(body.global_position): return
	if level.spare.is_valid() and bool(level.spare.call(body)): return
	if level.match_net.in_match(): level.match_net.free_victim_hide(body.slot)
	var point: Vector3 = level.locust.global_position
	var yaw: float = level.locust.rotation.y
	apply_execution(body.slot, point, yaw)
	if level.match_net.in_match(): level.match_net.execute_start.rpc(body.slot, point, yaw)

## Everyone plays out the execution: the creature holds its victim up and
## stabs three times. The victim's own machine takes over its body.
func apply_execution(seat: int, point: Vector3, yaw: float) -> void:
	execution = {"seat": seat, "time": 0.0, "point": point, "yaw": yaw, "stabs": 0, "dropped": false}
	strike_uv = Vector2(0.35, 0.55)
	if is_instance_valid(level.locust) and level.locust.control != "puppet": level.locust.begin_execution()
	if seat == level.player.slot:
		# The grip: a long, deep shake, and each stab lands on top of it.
		level.rumble(0.5, 0.9, 0.7)
		level.player.active = false
		level.player.held = true
		level.player.velocity = Vector3.ZERO
		if level.player.hidden: level.player.force_leave_hide()
		if level.ui.sheet.visible: level.toggle_sheet()
		# Nothing it was reading stays up over its death.
		if level.lock_open: level.close_lock()
		if is_instance_valid(level.reading_document): level.close_document()
	# The scream is the moment it has you: flat and loud in the victim's own
	# ears, and out in the room for everybody else.
	if not level.world_audio.enabled: return
	if seat == level.player.slot:
		if is_instance_valid(level.scream_sound): level.scream_sound.play()
	# Everybody else hears it wherever they are on the floor: somebody has been
	# caught, and nobody should miss that it happened.
	else: level.world_audio.play_everywhere(SCREAM, point + Vector3(0, 2.0, 0), -4.0, 0.0)

## Sounds, screen jolts and, on the host, the death at the end.
func update_execution(delta: float) -> void:
	if execution.is_empty(): return
	execution.time += delta
	var point: Vector3 = level.locust.global_position if is_instance_valid(level.locust) else execution.point
	var held := point + Vector3(0, 1.7, 0)
	# The whoosh starts with the arm, so its impact lands as the lens goes.
	if int(execution.stabs) == 0 and execution.time >= ARM_TIME:
		if level.world_audio.enabled:
			if int(execution.seat) == level.player.slot and is_instance_valid(level.blow_sound): level.blow_sound.play()
			else: level.world_audio.play_everywhere(KILL_BLOW, held, -1.0, 0.0)
		execution.stabs = 1
	if int(execution.stabs) == 1 and execution.time >= KILL_TIME:
		level.glitch = 1.0
		if int(execution.seat) == level.player.slot: level.rumble(0.2, 1.0, 0.35)
		execution.stabs = 2
	# The dead channel starts with the snow, not before it: sound and picture
	# are the same event.
	if int(execution.stabs) == 2 and execution.time >= SIGNAL_TIME:
		execution.stabs = 3
		if int(execution.seat) == level.player.slot and level.world_audio.enabled and is_instance_valid(level.static_sound): level.static_sound.play()
	# The body going down is not heard: right after the blow it read as a
	# second stab, and nothing is lost by letting it fall in silence.
	if not execution.dropped and execution.time >= DROP_TIME: execution.dropped = true
	if execution.time >= level.locust.EXECUTION_TIME + 0.3:
		var seat := int(execution.seat)
		# Its own picture is gone: it keeps the lost signal a moment before it
		# ends up watching somebody else's camera.
		if seat == level.player.slot:
			level.lost_signal = LOST_HOLD
			level.ui.lost_signal(LOST_HOLD)
		execution = {}
		# Only the victim was held by it: somebody else's death let whoever
		# was mid-ride walk about in the dark.
		if seat == level.player.slot:
			level.player.held = not level.lifts.boarding.is_empty() or level.lifts.leaving >= 0.0
			if level.player.avatar != null:
				level.player.avatar.rotation.x = 0.0
				level.player.avatar.rotation.z = 0.0
		if not level.net.is_client():
			level.ledger.note_death(seat)
			level.session.capture(seat)

## An execution cut short: the victim is let go alive, back on its feet with a
## clean picture, and the creature leaves the kill.
func release_execution() -> void:
	var seat := int(execution.seat)
	execution = {}
	if seat == level.player.slot:
		level.player.held = not level.lifts.boarding.is_empty() or level.lifts.leaving >= 0.0
		if level.player.avatar != null:
			level.player.avatar.rotation.x = 0.0
			level.player.avatar.rotation.z = 0.0
		if is_instance_valid(level.scream_sound): level.scream_sound.stop()
		if is_instance_valid(level.blow_sound): level.blow_sound.stop()
		level.clear_screen_cues()
	if is_instance_valid(level.locust) and level.locust.control != "puppet" and level.locust.mode == level.locust.Mode.EXECUTE:
		level.locust.set_mode(level.locust.Mode.SEARCH if level.locust.control == "ai" else level.locust.Mode.PATROL)

## Where the striking arm is on the victim's screen, as a UV: the black
## spreads from there, so it reads as an arm arriving and not as a fade.
var strike_uv := Vector2(0.35, 0.55)

func strike_on_screen() -> Vector2:
	if not is_instance_valid(level.locust) or not is_instance_valid(level.player.camera): return strike_uv
	# The hand that is actually coming: the creature holds with its left and
	# strikes with its right (locust_visual), and facing you its right is on
	# your left, which is where the black has to start.
	var hand: Vector3 = level.locust.global_position + Vector3(0, 2.0, 0) + level.locust.global_basis.x * 0.45
	var visual = level.locust.visual
	if is_instance_valid(visual) and "skeleton" in visual and "bones" in visual and visual.bones.has("R_Hand"):
		hand = visual.skeleton.global_transform * visual.skeleton.get_bone_global_pose(int(visual.bones["R_Hand"])).origin
	var size: Vector2 = level.player.camera.get_viewport().get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0: return strike_uv
	# Once the hand is past the lens it would project inverted, so the last
	# place it was seen is kept: the black goes on spreading from there instead
	# of jumping to the middle of the screen.
	if level.player.camera.is_position_behind(hand): return strike_uv
	var point: Vector2 = level.player.camera.unproject_position(hand)
	# Kept inside the frame and on the left half: the arm that strikes is the
	# creature's right, which facing you is on your left, and a black growing
	# from a corner reads as a shadow instead of as something arriving.
	strike_uv = Vector2(clampf(point.x / size.x, 0.08, 0.5), clampf(point.y / size.y, 0.18, 0.82))
	return strike_uv

## The victim: held in the air in front of the creature, looking at it.
func hold_victim(delta: float) -> void:
	var point: Vector3 = level.locust.global_position if is_instance_valid(level.locust) else execution.point
	var time: float = execution.time
	var lift := victim_lift(time)
	var wanted := victim_hold_point()
	level.player.velocity = Vector3.ZERO
	level.player.global_position = level.player.global_position.lerp(wanted, minf(1.0, delta * 10.0))
	# Run through on the blade: the body hangs back and sags, and goes limp
	# once the arm is through its face.
	var limp := clampf((time - KILL_TIME) / 0.35, 0.0, 1.0)
	if level.player.avatar != null:
		level.player.avatar.rotation.x = -(0.5 + 0.5 * limp) * lift
		level.player.avatar.rotation.z = (0.12 + 0.25 * limp) * lift
	# It is the last thing you see.
	var head := point + Vector3(0, 2.3, 0)
	var offset: Vector3 = head - level.player.camera.global_position
	level.player.rotation.y = lerp_angle(level.player.rotation.y, atan2(-offset.x, -offset.z), minf(1.0, delta * 8.0))
	level.player.camera.rotation.x = lerpf(level.player.camera.rotation.x, atan2(offset.y, Vector2(offset.x, offset.z).length()), minf(1.0, delta * 8.0))
	level.camcorder.focus("")
	level.ui.hint.text = ""
	level.ui.progress.visible = false

## How high the victim is held at this moment of it: up, and let fall.
func victim_lift(time: float) -> float:
	return clampf(time / 0.5, 0.0, 1.0) - clampf((time - DROP_TIME) / 0.4, 0.0, 1.0)

## Where the victim of the execution in hand is held: on the blade at the
## creature's chest height, and drawn slowly in -- the mask arriving is the
## whole point of the wait before the blow. The local player is put there,
## and so is a test bot's body.
func victim_hold_point() -> Vector3:
	var point: Vector3 = level.locust.global_position if is_instance_valid(level.locust) else execution.point
	var yaw: float = level.locust.rotation.y if is_instance_valid(level.locust) else execution.yaw
	var forward := -Basis(Vector3.UP, yaw).z
	var time: float = execution.time
	var closing := ease(clampf((time - 0.5) / maxf(KILL_TIME - 0.5, 0.01), 0.0, 1.0), 0.45)
	return point + forward * lerpf(1.15, 0.6, closing) + Vector3(0, 0.1 + victim_lift(time) * 1.0, 0)
