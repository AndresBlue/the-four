extends "res://tools/bots/bot_threat_none.gd"
## The Lurker's model for the bots (docs/OFICINAS.md 11.6). For now what a
## recording keeps of her (spec_f3_integration 6.4) and how a replay puts her
## back; the bots do not mind her yet (step 3f, 7.1: this model learns her
## then). Her row: x, y, z, her turn as a quaternion (qx, qy, qz, qw: on a
## ceiling she hangs upside down, which no yaw says), her mind's state
## (lurker_brain.State), her prey's seat (-1 nobody), in a duct (0 or 1), the
## duct node nearest her and the seconds left of a warning (0 with none).
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")

func recorded_row() -> Array:
	var it = level.creature
	if not is_instance_valid(it) or it.get("brain") == null or it.get("motion") == null: return []
	var at: Vector3 = it.global_position
	var turn: Quaternion = it.global_basis.get_rotation_quaternion()
	var left: float = maxf(0.0, float(it.warning.active.due) - float(it.brain.clock)) if not it.warning.active.is_empty() else 0.0
	return [at.x, at.y, at.z, turn.x, turn.y, turn.z, turn.w, int(it.brain.state), int(it.brain.prey), 1 if it.motion.in_duct else 0, int(it.motion.near_node), left]

## Her way ahead, its first sixteen points; null with no creature.
func recorded_route() -> Variant:
	var it = level.creature
	if not is_instance_valid(it) or it.get("motion") == null: return null
	var ahead: PackedVector3Array = it.motion.ahead(30.0)
	return ahead.slice(0, 16)

## Her mind's state and the seat she is after (-1: nobody).
func recorded_watch() -> Dictionary:
	var it = level.creature
	if not is_instance_valid(it) or it.get("brain") == null: return {}
	return {"mode": int(it.brain.state), "focus": int(it.brain.prey)}

## Said with a change of her state: where she is, and its name.
func recorded_mode_change() -> Dictionary:
	var it = level.creature
	if not is_instance_valid(it) or it.get("brain") == null: return {}
	return {"where": RECORDER.vec(it.global_position), "state": it.brain.state_name()}

## A replay's frame of her: placed and turned as the recording has her,
## between its two frames, with no state of her own to pull her elsewhere.
func replay_row(a: PackedFloat32Array, b: PackedFloat32Array, c: int, w: float, span: float) -> void:
	if c + 7 > a.size() or c + 7 > b.size(): return
	var it = level.creature
	var from := Vector3(a[c], a[c + 1], a[c + 2])
	var to := Vector3(b[c], b[c + 1], b[c + 2])
	var turn := Quaternion(a[c + 3], a[c + 4], a[c + 5], a[c + 6]).normalized().slerp(Quaternion(b[c + 3], b[c + 4], b[c + 5], b[c + 6]).normalized(), w)
	it.global_transform = Transform3D(Basis(turn), from.lerp(to, w))
	it.velocity = (to - from) / span if from.distance_to(to) <= 3.0 else Vector3.ZERO
	it.net_states.clear()

## And doing what the recording says she was doing then (her word, for the
## observer's panel).
func replay_mode(value: int) -> void:
	var it = level.creature
	it.net_mind = value
	it.word = BRAIN.WORDS.get(value, &"roam")
