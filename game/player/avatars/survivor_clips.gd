extends RefCounted
## A survivor's movement, from clips: Mixamo's motion capture, baked onto each
## survivor's own skeleton (tools/avatars/bake_survivor_clips.gd writes
## assets/players/<id>/clips.res). It replaced a walk made in code -- feet
## planted by IK and arms swung by formula -- that read as a puppet's.
##
## Which clips play, and how much, comes from where the body is going, seen
## from where it faces: ahead, back, to its left or to its right, and in
## between two of those, both of them; at a speed between two clips of a way,
## both of those (a walk, a hurried walk and a run ahead). Crouched, the
## crouched ones; in the air, a fall; and nearly still, standing breathing or
## crouched with a hand on the floor.
##
## Every clip of a gait starts its cycle at the same moment of the step (the
## left foot furthest out, `phase0`) and they all play at one shared phase,
## which goes round at the body's speed over the blended stride: so two clips
## mixed keep their feet together, and a foot on the floor stays where it is
## at any speed instead of sliding. Faster than a clip was made for, it is
## played faster.
const STANDING := {
	"forward": ["walk", "hurry", "run"],
	"back": ["walk_back", "run_back"],
	"left": ["walk_left"],
	"right": ["walk_right"],
}
const CROUCHED := {
	"forward": ["crouch_walk"],
	"back": ["crouch_back"],
	"left": ["crouch_left"],
	"right": ["crouch_right"],
}
## Each way, as its angle from straight ahead (to the right, positive).
const HEADINGS := {"forward": 0.0, "right": PI / 2.0, "back": PI, "left": -PI / 2.0}
## Slower than this (metres a second) the body is standing; the gait comes
## in fully by four fifths of its slowest clip's speed.
const STILL := 0.15

var rig: Skeleton3D
## name -> {animation, tracks [[bone, track, position?]], speed and stride
## (world metres), phase0}
var clips := {}
## Where the gait is in its cycle, 0 to 1.
var phase := 0.0
## For what has no cycle of steps: breathing, crouching, falling.
var clock := 0.0

## `scale`: how much the model was scaled to its height (its clips are
## measured in the model's own units).
func setup(library: AnimationLibrary, skeleton: Skeleton3D, scale: float) -> void:
	rig = skeleton
	clips.clear()
	for name in library.get_animation_list():
		var animation: Animation = library.get_animation(name)
		var tracks := []
		for track in animation.get_track_count():
			var bone := rig.find_bone(String(animation.track_get_path(track).get_concatenated_subnames()))
			if bone >= 0: tracks.append([bone, track, animation.track_get_type(track) == Animation.TYPE_POSITION_3D])
		var speed := float(animation.get_meta("speed", 0.0)) * scale
		clips[name] = {"animation": animation, "tracks": tracks, "speed": speed, "stride": speed * animation.length, "phase0": float(animation.get_meta("phase0", 0.0))}

## Poses the skeleton for a body going `local` (metres a second: x to its
## right, y ahead of it), crouched `crouch` and off the floor `air` (0 to 1).
func pose(local: Vector2, crouch: float, air: float, delta: float) -> void:
	if rig == null or clips.is_empty(): return
	var weights := weigh(local, crouch, air)
	advance(weights, local.length(), delta)
	apply(weights)

func weigh(local: Vector2, crouch: float, air: float) -> Dictionary:
	var weights := {}
	var speed := local.length()
	var heading := atan2(local.x, local.y)
	var ground := 1.0 - air
	for group in [[STANDING, "idle", 1.0 - crouch], [CROUCHED, "crouch_idle", crouch]]:
		var amount: float = float(group[2]) * ground
		if amount <= 0.0: continue
		var gaits: Dictionary = group[0]
		var slowest := INF
		for way in gaits: slowest = minf(slowest, float(clips[gaits[way][0]].speed))
		var moving := smoothstep(STILL, maxf(slowest * 0.8, STILL + 0.1), speed)
		add(weights, group[1], amount * (1.0 - moving))
		if moving <= 0.0: continue
		for way in gaits:
			var toward := 1.0 - absf(angle_difference(heading, float(HEADINGS[way]))) / (PI / 2.0)
			if toward <= 0.0: continue
			var paced := by_speed(gaits[way], speed)
			for name in paced: add(weights, name, amount * moving * toward * float(paced[name]))
	if air > 0.0: add(weights, "fall", air)
	return weights

static func add(weights: Dictionary, name: String, weight: float) -> void:
	if weight > 0.0: weights[name] = float(weights.get(name, 0.0)) + weight

## Between the two clips of a way either side of `speed` (they go slowest
## first); below the slowest or above the fastest, that one alone.
func by_speed(names: Array, speed: float) -> Dictionary:
	if names.size() == 1 or speed <= float(clips[names[0]].speed): return {names[0]: 1.0}
	if speed >= float(clips[names[-1]].speed): return {names[-1]: 1.0}
	for i in names.size() - 1:
		var low: float = clips[names[i]].speed
		var high: float = clips[names[i + 1]].speed
		if speed <= high:
			var t := (speed - low) / maxf(high - low, 0.001)
			return {names[i]: 1.0 - t, names[i + 1]: t}
	return {names[-1]: 1.0}

## The phase goes round once for every blended stride the body covers.
func advance(weights: Dictionary, speed: float, delta: float) -> void:
	clock += delta
	var stride := 0.0
	var total := 0.0
	for name in weights:
		if float(clips[name].speed) <= 0.0: continue
		stride += float(weights[name]) * float(clips[name].stride)
		total += float(weights[name])
	if total > 0.001 and stride > 0.001: phase = fposmod(phase + delta * speed * total / stride, 1.0)

func apply(weights: Dictionary) -> void:
	rig.reset_bone_poses()
	var turns := {}
	var places := {}
	var placed := {}
	for name in weights:
		var weight: float = weights[name]
		if weight < 0.001: continue
		var clip: Dictionary = clips[name]
		var animation: Animation = clip.animation
		var time := fposmod(float(clip.phase0) + phase * animation.length, animation.length) if float(clip.speed) > 0.0 else fposmod(clock, animation.length)
		for entry in clip.tracks:
			var bone: int = entry[0]
			if entry[2]:
				places[bone] = places.get(bone, Vector3.ZERO) + animation.position_track_interpolate(entry[1], time) * weight
				placed[bone] = float(placed.get(bone, 0.0)) + weight
				continue
			var turn := animation.rotation_track_interpolate(entry[1], time)
			if turns.has(bone):
				var sum: Quaternion = turns[bone]
				# The same turn either way round: added the short way.
				if sum.dot(turn) < 0.0: turn = -turn
				turns[bone] = sum + turn * weight
			else: turns[bone] = turn * weight
	for bone in turns: rig.set_bone_pose_rotation(bone, (turns[bone] as Quaternion).normalized())
	for bone in places: rig.set_bone_pose_position(bone, places[bone] / maxf(float(placed[bone]), 0.001))
