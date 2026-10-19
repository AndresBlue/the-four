extends SceneTree
## Bakes the survivors' movement clips onto each survivor's own skeleton.
##
##   godot --headless --path . --script res://tools/avatars/bake_survivor_clips.gd
##
## The clips are Mixamo's, made for the detective's skeleton (Mixamo's
## auto-rig of assets/players/detective/model.obj), in place and at 30 frames
## a second. They are kept outside the project, in models/mixamo/ with the rest
## of the downloads (docs/ASSETS.md), and read from there with FBXDocument.
##
## A clip is put on a skeleton by how much each bone turns from its rest, in
## the model's own space: never by its local axes, which are different on
## every rig (the Exploradora's skeleton is Z-up and the detectives' Y-up). The
## target's rest is first turned onto the clip's, bone by bone, so that both
## start from the same pose: the Exploradora stands in an A and the clips'
## skeleton in a T. The hips move as much as the clip's do, scaled by how high
## each pair of hips stands.
##
## Writes assets/players/<id>/clips.res, an AnimationLibrary. Every clip loops
## and carries what the game needs to put it under a body that walks at any
## speed (survivor_clips.gd): `speed`, how fast the body goes in it (metres a
## second, in the model's units), read from the foot on the floor sliding
## back under the hips; `travel`, which way (model space, the body facing +Z);
## and `phase0`, the moment the left foot is furthest ahead (for a clip that
## goes ahead or back) or furthest to the body's left (one that goes to a
## side), where every clip of a gait starts its cycle so that two of them can
## be mixed without the feet coming apart -- and so that two that go opposite
## ways have the same leg ahead at the same moment, and turning round from one
## to the other crosses no legs.
##
## The jump is not a loop: it is played as the body goes up and comes down
## (survivor_clips.gd), and carries `takeoff`, `landing` and `settled`, the
## moments its feet leave the floor, meet it again and the knees have taken
## the landing. Its hips go no higher than the feet under them let them: the
## body is lifted by the game, not by the clip.
const SOURCE := "models/mixamo/"
## Name in the game: file in models/mixamo/, or [file, mirrored]. Mixamo's
## "Crouched Cover Sneaking Left" goes along with its back to the cover, the
## other way round from its right one: the left one is the right one, mirrored.
const CLIPS := {
	"idle": "breathing_idle",
	"walk": "male_standard_walk",
	"hurry": "male_hurried_walk",
	"run": "running_forward_quickly",
	"walk_back": "male_walk_backwards",
	"run_back": "backwards_running",
	"walk_left": "strafe_walking_left",
	"walk_right": "strafe_walking_right",
	"run_left": "running_strafe_left",
	"run_right": "running_strafe_right",
	"crouch_idle": "low_crouching_idle",
	"crouch_walk": "crouched_walk",
	"crouch_back": "crouch_walk_back",
	"crouch_left": ["crouched_sneaking_right", true],
	"crouch_right": "crouched_sneaking_right",
	"jump": "jumping_forward",
}
## The clips that leave the floor (above).
const LEAPS := ["jump"]
const TARGETS := ["detective", "detective_woman", "realistic_female"]
## The clips' bones by their Mixamo name (without "mixamorig_") and, on the
## Exploradora, the Character Creator bone that does the same work. Her twist,
## share and breast bones keep their rest and follow.
const CHARACTER_CREATOR := {
	"Hips": "CC_Base_Hip", "Spine": "CC_Base_Waist", "Spine1": "CC_Base_Spine01", "Spine2": "CC_Base_Spine02",
	"Neck": "CC_Base_NeckTwist01", "Head": "CC_Base_Head",
	"LeftShoulder": "CC_Base_L_Clavicle", "LeftArm": "CC_Base_L_Upperarm", "LeftForeArm": "CC_Base_L_Forearm", "LeftHand": "CC_Base_L_Hand",
	"RightShoulder": "CC_Base_R_Clavicle", "RightArm": "CC_Base_R_Upperarm", "RightForeArm": "CC_Base_R_Forearm", "RightHand": "CC_Base_R_Hand",
	"LeftUpLeg": "CC_Base_L_Thigh", "LeftLeg": "CC_Base_L_Calf", "LeftFoot": "CC_Base_L_Foot", "LeftToeBase": "CC_Base_L_ToeBase",
	"RightUpLeg": "CC_Base_R_Thigh", "RightLeg": "CC_Base_R_Calf", "RightFoot": "CC_Base_R_Foot", "RightToeBase": "CC_Base_R_ToeBase",
}
const FINGERS := {"Thumb": "Thumb", "Index": "Index", "Middle": "Mid", "Ring": "Ring", "Pinky": "Pinky"}
## Which bone each one points at, for turning the target's rest onto the
## clip's. One that points at nothing in particular (the hips, the head, the
## toes, the finger tips) keeps its rest as it is.
const POINTS_AT := {
	"Spine": "Spine1", "Spine1": "Spine2", "Spine2": "Neck", "Neck": "Head",
	"Shoulder": "Arm", "Arm": "ForeArm", "ForeArm": "Hand", "Hand": "HandMiddle1",
	"UpLeg": "Leg", "Leg": "Foot", "Foot": "ToeBase",
}
const FPS := 30.0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var failed := false
	var sources := {}
	for name in CLIPS:
		var file: String = CLIPS[name] if CLIPS[name] is String else CLIPS[name][0]
		var source := read_clip(ProjectSettings.globalize_path("res://") + SOURCE + file + ".fbx")
		if source.is_empty():
			push_error("No se pudo leer %s" % file)
			failed = true
			continue
		source.mirrored = CLIPS[name] is Array and bool(CLIPS[name][1])
		source.leap = name in LEAPS
		sources[name] = source
	for id in TARGETS:
		var scene: Node3D = load("res://assets/players/%s/model.fbx" % id).instantiate()
		root.add_child(scene)
		var skeleton := body_skeleton(scene)
		var mapping := bone_mapping(skeleton, id == "realistic_female")
		var library := AnimationLibrary.new()
		for name in sources:
			var animation := retarget(sources[name], scene, skeleton, mapping)
			library.add_animation(name, animation)
			print("BAKE %-17s %-12s %5.2f s, %4.2f m/s towards %s, left foot out at %.2f s%s" % [id, name, animation.length, float(animation.get_meta("speed")), (animation.get_meta("travel") as Vector3).snapped(Vector3.ONE * 0.01), float(animation.get_meta("phase0")), ", off the floor %.2f to %.2f s, settled at %.2f s" % [float(animation.get_meta("takeoff")), float(animation.get_meta("landing")), float(animation.get_meta("settled"))] if animation.has_meta("takeoff") else ""])
		var error := ResourceSaver.save(library, "res://assets/players/%s/clips.res" % id)
		if error != OK: failed = true
		scene.queue_free()
	for source in sources.values(): source.scene.queue_free()
	await process_frame
	print("BAKE_CLIPS ", "FAILED" if failed else "OK")
	quit(1 if failed else 0)

func body_skeleton(scene: Node) -> Skeleton3D:
	var rigs := scene.find_children("*", "Skeleton3D", true, false)
	rigs.sort_custom(func(a, b): return a.get_bone_count() > b.get_bone_count())
	return rigs[0]

## A clip as FBXDocument reads it: its scene (kept in the tree, so that its
## transforms are known), skeleton and animation, and which tracks move which
## bone.
func read_clip(path: String) -> Dictionary:
	var document := FBXDocument.new()
	var state := FBXState.new()
	if document.append_from_file(path, state) != OK: return {}
	var scene: Node3D = document.generate_scene(state)
	if scene == null: return {}
	root.add_child(scene)
	var skeleton := body_skeleton(scene)
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var animation: Animation = player.get_animation(player.get_animation_list()[0])
	var tracks := {}
	for track in animation.get_track_count():
		var bone := skeleton.find_bone(String(animation.track_get_path(track).get_concatenated_subnames()))
		if bone < 0: continue
		match animation.track_get_type(track):
			Animation.TYPE_POSITION_3D: tracks[Vector2i(bone, 0)] = track
			Animation.TYPE_ROTATION_3D: tracks[Vector2i(bone, 1)] = track
			Animation.TYPE_SCALE_3D: tracks[Vector2i(bone, 2)] = track
	return {"scene": scene, "skeleton": skeleton, "animation": animation, "tracks": tracks, "order": parents_first(skeleton)}

## The bones, each after its parent.
func parents_first(skeleton: Skeleton3D) -> PackedInt32Array:
	var order := PackedInt32Array()
	var placed := {}
	while order.size() < skeleton.get_bone_count():
		for bone in skeleton.get_bone_count():
			if placed.has(bone): continue
			var parent := skeleton.get_bone_parent(bone)
			if parent < 0 or placed.has(parent):
				order.append(bone)
				placed[bone] = true
	return order

## Where a skeleton is in its model's own space.
func model_space(skeleton: Skeleton3D, scene: Node3D) -> Transform3D:
	return scene.global_transform.affine_inverse() * skeleton.global_transform

## Target bone -> clip bone name ("mixamorig_..."), for every bone of the
## target that a bone of the clip drives.
func bone_mapping(skeleton: Skeleton3D, character_creator: bool) -> Dictionary:
	var mapping := {}
	var wanted := {}
	if character_creator:
		wanted = CHARACTER_CREATOR.duplicate()
		for side in ["Left", "Right"]:
			for finger in FINGERS:
				for joint in [1, 2, 3]:
					wanted["%sHand%s%d" % [side, finger, joint]] = "CC_Base_%s_%s%d" % [side[0], FINGERS[finger], joint]
	else:
		for bone in skeleton.get_bone_count():
			var name := skeleton.get_bone_name(bone)
			if name.begins_with("mixamorig_"): wanted[name.trim_prefix("mixamorig_")] = name
	for short in wanted:
		var bone := skeleton.find_bone(wanted[short])
		if bone >= 0: mapping[bone] = "mixamorig_" + short
	return mapping

## A clip bone's pose at `time`, in its parent's space.
func clip_local(source: Dictionary, bone: int, time: float) -> Transform3D:
	var skeleton: Skeleton3D = source.skeleton
	var animation: Animation = source.animation
	var tracks: Dictionary = source.tracks
	var rest := skeleton.get_bone_rest(bone)
	var position := rest.origin
	var rotation := rest.basis.get_rotation_quaternion()
	var scale := rest.basis.get_scale()
	if tracks.has(Vector2i(bone, 0)): position = animation.position_track_interpolate(tracks[Vector2i(bone, 0)], time)
	if tracks.has(Vector2i(bone, 1)): rotation = animation.rotation_track_interpolate(tracks[Vector2i(bone, 1)], time)
	if tracks.has(Vector2i(bone, 2)): scale = animation.scale_track_interpolate(tracks[Vector2i(bone, 2)], time)
	return Transform3D(Basis(rotation) * Basis.from_scale(scale), position)

## Every clip bone at `time`, in the model's space.
func clip_pose(source: Dictionary, time: float) -> Array:
	var skeleton: Skeleton3D = source.skeleton
	var space := model_space(skeleton, source.scene)
	var pose := []
	pose.resize(skeleton.get_bone_count())
	for bone in source.order:
		var parent := skeleton.get_bone_parent(bone)
		var local := clip_local(source, bone, time)
		pose[bone] = space * local if parent < 0 else (pose[parent] as Transform3D) * local
	return pose

func rest_pose(skeleton: Skeleton3D, space: Transform3D) -> Array:
	var pose := []
	for bone in skeleton.get_bone_count(): pose.append(space * skeleton.get_bone_global_rest(bone))
	return pose

static func turning(transform: Transform3D) -> Quaternion:
	return transform.basis.orthonormalized().get_rotation_quaternion()

## A turn seen in a mirror that swaps left and right (x for -x, the model
## space's left being +X): about the reflected axis, the other way round.
static func reflected(turn: Quaternion) -> Quaternion:
	return Quaternion(turn.x, -turn.y, -turn.z, turn.w)

## The bone on the other side ("Left..." for "Right..."), or the same one.
static func partner(name: String) -> String:
	if name.contains("Left"): return name.replace("Left", "Right")
	if name.contains("Right"): return name.replace("Right", "Left")
	return name

## The clip bone a target bone's rest is turned towards: the next joint along.
static func points_at(short: String) -> String:
	var side := "Left" if short.begins_with("Left") else ("Right" if short.begins_with("Right") else "")
	var part := short.trim_prefix(side)
	if POINTS_AT.has(part): return side + POINTS_AT[part]
	# A finger's first and second joints point at the one after.
	if part.begins_with("Hand") and (part.ends_with("1") or part.ends_with("2")):
		return side + part.substr(0, part.length() - 1) + str(int(part[-1]) + 1)
	return ""

func retarget(source: Dictionary, scene: Node3D, skeleton: Skeleton3D, wanted: Dictionary) -> Animation:
	var clip_skeleton: Skeleton3D = source.skeleton
	var clip_rest := rest_pose(clip_skeleton, model_space(clip_skeleton, source.scene))
	var space := model_space(skeleton, scene)
	var rest := rest_pose(skeleton, space)
	var order := parents_first(skeleton)
	# Only what the clip's skeleton has too.
	var mapping := {}
	var clip_bone := {}
	var target_of := {}
	for bone in wanted:
		var clip_id := clip_skeleton.find_bone(wanted[bone])
		if clip_id < 0: continue
		mapping[bone] = wanted[bone]
		clip_bone[bone] = clip_id
		target_of[String(wanted[bone]).trim_prefix("mixamorig_")] = bone
	# Each target bone's rest turned onto the clip's: the way it points made
	# the way the clip's bone points at rest.
	var align := {}
	for bone in mapping:
		align[bone] = Quaternion.IDENTITY
		var points := points_at(String(mapping[bone]).trim_prefix("mixamorig_"))
		if points == "" or not target_of.has(points): continue
		var clip_child := clip_skeleton.find_bone("mixamorig_" + points)
		var from: Vector3 = (rest[target_of[points]] as Transform3D).origin - (rest[bone] as Transform3D).origin
		var to: Vector3 = (clip_rest[clip_child] as Transform3D).origin - (clip_rest[clip_bone[bone]] as Transform3D).origin
		if from.length() > 0.001 and to.length() > 0.001: align[bone] = Quaternion(from.normalized(), to.normalized())
	var hips := int(target_of.get("Hips", -1))
	# Mirrored, each bone takes its partner's turn.
	var mirror_of := {}
	for bone in mapping: mirror_of[bone] = clip_skeleton.find_bone(partner(mapping[bone]))
	var clip_hips := clip_skeleton.find_bone("mixamorig_Hips")
	var hip_ratio: float = (rest[hips] as Transform3D).origin.y / maxf((clip_rest[clip_hips] as Transform3D).origin.y, 0.01)
	var animation_in: Animation = source.animation
	var frames := int(round(animation_in.length * FPS))
	# Mixamo's loops end on the frame they start with: that one is not played twice.
	var first := clip_pose(source, 0.0)
	var last := clip_pose(source, float(frames - 1) / FPS)
	var repeats := true
	for name in ["mixamorig_LeftToeBase", "mixamorig_RightToeBase", "mixamorig_LeftHand", "mixamorig_Head"]:
		var id := clip_skeleton.find_bone(name)
		if (first[id] as Transform3D).origin.distance_to((last[id] as Transform3D).origin) > 0.02: repeats = false
	var played := frames - 1 if repeats and frames > 2 and not source.leap else frames
	var animation := Animation.new()
	animation.length = float(played) / FPS
	animation.loop_mode = Animation.LOOP_NONE if source.leap else Animation.LOOP_LINEAR
	var clip_toes := [clip_skeleton.find_bone("mixamorig_LeftToeBase"), clip_skeleton.find_bone("mixamorig_RightToeBase")]
	var rest_feet := minf((clip_rest[clip_toes[0]] as Transform3D).origin.y, (clip_rest[clip_toes[1]] as Transform3D).origin.y)
	var prefix := String(scene.get_path_to(skeleton))
	var rotation_track := {}
	for bone in order:
		if not mapping.has(bone): continue
		var track := animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track, NodePath("%s:%s" % [prefix, skeleton.get_bone_name(bone)]))
		rotation_track[bone] = track
	var hip_track := animation.add_track(Animation.TYPE_POSITION_3D)
	animation.track_set_path(hip_track, NodePath("%s:%s" % [prefix, skeleton.get_bone_name(hips)]))
	# Where the toes are, frame by frame, to read the clip's speed from.
	var toes := [int(target_of.get("LeftToeBase", -1)), int(target_of.get("RightToeBase", -1))]
	var toe_track := [PackedVector3Array(), PackedVector3Array()]
	var hip_track_points := PackedVector3Array()
	# How high the clip's own feet are (a jump leaves the floor in the clip; on
	# the target it is the game that lifts the body).
	var clip_feet := PackedFloat32Array()
	for frame in played:
		var time := float(frame) / FPS
		var clip := clip_pose(source, time)
		clip_feet.append(minf((clip[clip_toes[0]] as Transform3D).origin.y, (clip[clip_toes[1]] as Transform3D).origin.y))
		var posed := []
		posed.resize(skeleton.get_bone_count())
		for bone in order:
			var parent := skeleton.get_bone_parent(bone)
			var above: Transform3D = space if parent < 0 else posed[parent]
			var local_rest := skeleton.get_bone_rest(bone)
			var placed: Transform3D = above * local_rest
			if mapping.has(bone):
				var moved: int = mirror_of[bone] if source.mirrored else clip_bone[bone]
				var from_rest: Quaternion = turning(clip[moved]) * turning(clip_rest[moved]).inverse()
				if source.mirrored: from_rest = reflected(from_rest)
				var turned: Quaternion = from_rest * align[bone] * turning(rest[bone])
				var origin := placed.origin
				if bone == hips:
					var sway: Vector3 = ((clip[clip_hips] as Transform3D).origin - (clip_rest[clip_hips] as Transform3D).origin) * hip_ratio
					if source.mirrored: sway.x = -sway.x
					# Off the floor, only as low as the knees take them over the feet.
					if source.leap:
						var feet := minf((clip[clip_toes[0]] as Transform3D).origin.y, (clip[clip_toes[1]] as Transform3D).origin.y)
						var over: float = (clip[clip_hips] as Transform3D).origin.y - feet
						sway = Vector3(0.0, (over - ((clip_rest[clip_hips] as Transform3D).origin.y - rest_feet)) * hip_ratio, 0.0)
					origin = (rest[bone] as Transform3D).origin + sway
				placed = Transform3D(Basis(turned) * Basis.from_scale((rest[bone] as Transform3D).basis.get_scale()), origin)
			posed[bone] = placed
			if mapping.has(bone):
				var local := above.affine_inverse() * placed
				animation.rotation_track_insert_key(rotation_track[bone], time, turning(local))
				if bone == hips: animation.position_track_insert_key(hip_track, time, local.origin)
		for side in 2:
			if toes[side] >= 0: toe_track[side].append((posed[toes[side]] as Transform3D).origin)
		hip_track_points.append((posed[hips] as Transform3D).origin)
	if source.leap: measure_leap(animation, clip_feet, hip_track_points, played)
	else: measure(animation, toe_track, hip_track_points, played)
	return animation

## When a jump's feet leave the floor and meet it again, and when the knees
## have taken the landing (the hips back up to where they end).
func measure_leap(animation: Animation, feet: PackedFloat32Array, hips: PackedVector3Array, frames: int) -> void:
	var lowest := INF
	for height in feet: lowest = minf(lowest, height)
	var takeoff := -1
	var landing := -1
	for frame in frames:
		var off: bool = feet[frame] > lowest + 0.04
		if off and takeoff < 0: takeoff = frame
		elif not off and takeoff >= 0 and landing < 0: landing = frame
	var settled := frames - 1
	if landing >= 0:
		var deepest := landing
		for frame in range(landing, frames):
			if hips[frame].y < hips[deepest].y: deepest = frame
		for frame in range(deepest, frames):
			if hips[frame].y >= hips[frames - 1].y - 0.01:
				settled = frame
				break
	animation.set_meta("speed", 0.0)
	animation.set_meta("travel", Vector3.ZERO)
	animation.set_meta("phase0", 0.0)
	animation.set_meta("takeoff", float(maxi(takeoff, 0)) / FPS)
	animation.set_meta("landing", float(maxi(landing, takeoff + 1)) / FPS)
	animation.set_meta("settled", float(settled) / FPS)

## The clip's speed and direction, from the foot on the floor sliding back
## under the hips, and the moment its left foot is furthest out that way.
func measure(animation: Animation, toes: Array, hips: PackedVector3Array, frames: int) -> void:
	var lowest := INF
	for side in 2:
		for point in toes[side]: lowest = minf(lowest, point.y)
	var sum := Vector3.ZERO
	var speeds := PackedFloat32Array()
	for frame in frames:
		var next := (frame + 1) % frames
		var side := 0 if (toes[0][frame] as Vector3).y <= (toes[1][frame] as Vector3).y else 1
		var here: Vector3 = toes[side][frame]
		var there: Vector3 = toes[side][next]
		if here.y > lowest + 0.025 or there.y > lowest + 0.025: continue
		var slide := Vector3(there.x - here.x, 0.0, there.z - here.z) * FPS
		# The step from the last frame back to the first can be a jump.
		if slide.length() > 12.0: continue
		sum += slide
		speeds.append(slide.length())
	var speed := 0.0
	var travel := Vector3.ZERO
	if not speeds.is_empty():
		speeds.sort()
		speed = speeds[speeds.size() / 2]
		travel = -sum.normalized() if sum.length() > 0.001 else Vector3.ZERO
	# Standing still, nothing slides; the little a foot shifts is not a speed.
	if speed < 0.25:
		speed = 0.0
		travel = Vector3.ZERO
	var phase0 := 0.0
	if speed > 0.0:
		# Ahead, for one that goes ahead or back; to the body's left, for one
		# that goes to a side: the same for two clips going opposite ways.
		var axis := Vector3.BACK if absf(travel.z) >= absf(travel.x) else Vector3.RIGHT
		var furthest := -INF
		for frame in frames:
			var out: float = ((toes[0][frame] as Vector3) - hips[frame]).dot(axis)
			if out > furthest:
				furthest = out
				phase0 = float(frame) / FPS
	animation.set_meta("speed", speed)
	animation.set_meta("travel", travel)
	animation.set_meta("phase0", phase0)
