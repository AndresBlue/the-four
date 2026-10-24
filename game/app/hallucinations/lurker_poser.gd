extends RefCounted
## What poses The Lurker's model where a mind going sees her (phantom_sight,
## through lurker_hallucinations): a clip held still, the peek round a jamb or
## the stare, and where a bone of it is. Her hands do not crawl there: the
## clip moves the arms.
var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer

func _init(m: Node3D) -> void:
	model = m
	skeleton = m.find_children("*", "Skeleton3D", true, false)[0]
	animator = m.find_children("*", "AnimationPlayer", true, false)[0]

## Where a bone of hers is now, in the world.
func point(bone: String) -> Vector3:
	var index := skeleton.find_bone(bone)
	if index < 0: return model.global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(index).origin

## Leant out round a jamb by `lean` (0..0.6), the clip "peek" held there, a
## hair further on a twitch; mirrored for a lean to the other side.
func pose_peek(lean: float, twitch: float, side: float) -> void:
	hold("peek", lerpf(0.6, 1.6, clampf(lean / 0.6, 0.0, 1.0)) + 0.05 * twitch)
	var mirror := -1.0 if side < 0.0 else 1.0
	if signf(model.scale.x) != mirror: model.scale.x = -model.scale.x

## Still, looking: the clip "idle" held at 0.8 s.
func pose_stare(twitch: float) -> void:
	hold("idle", 0.8 + 0.05 * twitch)
	if model.scale.x < 0.0: model.scale.x = -model.scale.x

func hold(clip: String, at: float) -> void:
	if not animator.has_animation(clip): return
	animator.play(clip)
	animator.seek(minf(at, animator.get_animation(clip).length), true)
	animator.pause()
