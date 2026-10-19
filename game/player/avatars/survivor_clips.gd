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
## crouched ones; nearly still, standing breathing or crouched with a hand on
## the floor. Nothing changes from one clip to another at once: what plays
## moves towards what should over a moment (BLEND, longer the faster the body
## goes), so turning round from a run ahead to a run back goes through the
## steps in between instead of cutting from one to the other.
##
## Off the floor it is a jump, a short one with both feet: where it is in the
## jump is where the body is in its own -- going up at JUMP_SPEED, the feet
## just left the floor; at the top, the middle; coming down as fast, about to
## land -- and once it is down again after a real jump (longer than
## LANDS_AFTER off the floor), the knees take the landing as the clip's do,
## less the faster the body is already going on.
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
	"left": ["walk_left", "run_left"],
	"right": ["walk_right", "run_right"],
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
## How long a change of clips takes to come in, about (seconds): walking, and
## running at 6 m/s.
const BLEND := 0.12
const BLEND_RUNNING := 0.22
## How fast the game's jump leaves the floor (survivor_gait / hotel_player).
const JUMP_SPEED := 5.4
const LANDS_AFTER := 0.25

var rig: Skeleton3D
## name -> {animation, tracks [[bone, track, position?]], speed and stride
## (world metres), phase0}
var clips := {}
## Where the gait is in its cycle, 0 to 1.
var phase := 0.0
## For what has no cycle of steps: breathing, crouching.
var clock := 0.0
## The clips playing now and how much, which move towards what is wanted.
var mixed := {}
## How fast the body is going up (metres a second), how long it has been off
## the floor, and how long since it came down after a jump (-1: not landing).
var rising := 0.0
var flight := 0.0
var landed := -1.0

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
## right, y ahead of it) and `up`, crouched `crouch` and off the floor `air`
## (0 to 1), on the floor or not.
func pose(local: Vector2, up: float, crouch: float, air: float, grounded: bool, delta: float) -> void:
	if rig == null or clips.is_empty(): return
	rising = up
	if not grounded:
		flight += delta
		landed = -1.0
	else:
		if flight > LANDS_AFTER and clips.has("jump"): landed = 0.0
		elif landed >= 0.0: landed += delta
		flight = 0.0
	var speed := local.length()
	blend(weigh(local, crouch, air), speed, delta)
	advance(mixed, speed, delta)
	apply(mixed)

## What plays moves towards what is wanted.
func blend(wanted: Dictionary, speed: float, delta: float) -> void:
	var toward := 1.0 - exp(-delta / lerpf(BLEND, BLEND_RUNNING, clampf(speed / 6.0, 0.0, 1.0)))
	for name in wanted:
		if not mixed.has(name): mixed[name] = 0.0
	for name in mixed.keys():
		mixed[name] = lerpf(float(mixed[name]), float(wanted.get(name, 0.0)), toward)
		if float(mixed[name]) < 0.002 and not wanted.has(name): mixed.erase(name)

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
	if air > 0.0: add(weights, "jump", air)
	# Down after a jump: the knees take it, as the clip's do.
	if landed >= 0.0 and clips.has("jump"):
		var animation: Animation = clips.jump.animation
		var lasts := float(animation.get_meta("settled")) - float(animation.get_meta("landing"))
		if landed >= lasts: landed = -1.0
		else:
			var land := (1.0 - smoothstep(0.0, lasts, landed)) * (1.0 - 0.6 * smoothstep(STILL, 2.0, speed))
			for name in weights: weights[name] = float(weights[name]) * (1.0 - land)
			add(weights, "land", land)
	return weights

## The clip a name plays: the landing is the end of the jump.
func clip_of(name: String) -> Dictionary:
	return clips.jump if name == "land" else clips[name]

## Where in its clip a name is now.
func time_of(name: String, clip: Dictionary) -> float:
	var animation: Animation = clip.animation
	if name == "jump":
		var off := float(animation.get_meta("takeoff"))
		var down := float(animation.get_meta("landing"))
		return lerpf(off, down, clampf(0.5 - rising / (2.0 * JUMP_SPEED), 0.0, 1.0))
	if name == "land": return minf(float(animation.get_meta("landing")) + landed, animation.length)
	if float(clip.speed) > 0.0: return fposmod(float(clip.phase0) + phase * animation.length, animation.length)
	return fposmod(clock, animation.length)

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
		var clip := clip_of(name)
		if float(clip.speed) <= 0.0: continue
		stride += float(weights[name]) * float(clip.stride)
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
		var clip := clip_of(name)
		var animation: Animation = clip.animation
		var time := time_of(name, clip)
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
