extends "res://game/net/remote_player.gd"
## A bot of a recorded match, watched again (bot_replay.gd): a teammate's body
## that is put where the recording says, frame by frame, and only animates.
## Registered where the level keeps other survivors, so the observer's TAB,
## panel and gizmos take it like anybody's.

func setup(owner_level, seat: int, words: String, character: int) -> void:
	super.setup(owner_level, seat, words, character)
	name = "Replay_%d" % seat
	# Nothing bumps into a recording.
	collision_layer = 0

func push_state(_data: Array) -> void: pass

## Where the recording has it at this moment.
func pose(at: Vector3, yaw: float, pitch_value: float, speed: Vector3, crouching: bool, torch_on: bool) -> void:
	global_position = at
	rotation.y = yaw
	pitch = pitch_value
	velocity = speed
	crouched = crouching
	camera.position.y = 0.9 if crouched else 1.64
	camera.rotation.x = pitch
	torch.visible = torch_on and not hidden and not dead

func set_dead(value: bool) -> void:
	super.set_dead(value)
	collision_layer = 0

func _physics_process(delta: float) -> void:
	if dead: return
	avatar.visible = not hidden
	avatar.update_pose(velocity if not hidden else Vector3.ZERO, crouched, delta, true)
