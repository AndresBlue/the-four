extends Node3D
## Presentation only. Never changes capsule, speed, or saved floor state.
const IDS := ["detective", "detective_woman", "realistic_female"]
const NAMES := ["Detective Masculino", "Detective Femenino", "Exploradora"]
@export_enum("Detective Masculino", "Detective Femenino", "Exploradora") var character := 0
@export var first_person := false
## The two skeletons the survivors come with. Keys: hip, spine, chest, head,
## and per side the shoulder (s), upper arm (a), forearm (e), hand (h), thigh
## (t), calf (k), foot (f) and toe (o).
const MIXAMO := {
	"hip": "mixamorig_Hips", "spine": "mixamorig_Spine1", "chest": "mixamorig_Spine2", "head": "mixamorig_Head",
	"ls": "mixamorig_LeftShoulder", "la": "mixamorig_LeftArm", "le": "mixamorig_LeftForeArm", "lh": "mixamorig_LeftHand",
	"rs": "mixamorig_RightShoulder", "ra": "mixamorig_RightArm", "re": "mixamorig_RightForeArm", "rh": "mixamorig_RightHand",
	"lt": "mixamorig_LeftUpLeg", "lk": "mixamorig_LeftLeg", "lf": "mixamorig_LeftFoot", "lo": "mixamorig_LeftToeBase",
	"rt": "mixamorig_RightUpLeg", "rk": "mixamorig_RightLeg", "rf": "mixamorig_RightFoot", "ro": "mixamorig_RightToeBase",
}
const CHARACTER_CREATOR := {
	"hip": "CC_Base_Hip", "spine": "CC_Base_Spine01", "chest": "CC_Base_Spine02", "head": "CC_Base_Head",
	"ls": "CC_Base_L_Clavicle", "la": "CC_Base_L_Upperarm", "le": "CC_Base_L_Forearm", "lh": "CC_Base_L_Hand",
	"rs": "CC_Base_R_Clavicle", "ra": "CC_Base_R_Upperarm", "re": "CC_Base_R_Forearm", "rh": "CC_Base_R_Hand",
	"lt": "CC_Base_L_Thigh", "lk": "CC_Base_L_Calf", "lf": "CC_Base_L_Foot", "lo": "CC_Base_L_ToeBase",
	"rt": "CC_Base_R_Thigh", "rk": "CC_Base_R_Calf", "rf": "CC_Base_R_Foot", "ro": "CC_Base_R_ToeBase",
}
## How far apart the feet stand. A stride grows with speed, the way a person's
## does -- about 0.75 m standing still and a third of a metre more for every
## metre per second -- and a step is in the air for a third of it, so a foot is
## planted the other two thirds. That ratio is what keeps somebody walking
## instead of gliding: too short a stride and both feet swing at once.
const STANCE := 0.11
const STRIDE_BASE := 0.75
const STRIDE_PER_SPEED := 0.34
const STRIDE_RANGE := Vector2(0.9, 2.7)
const STRIDE_CROUCH := 0.66
const SWING_SHARE := 0.5
const RUN_SPEED := 6.0
## How high the ankle sits above the sole, so a planted foot rests on the
## floor instead of sinking into it.
const ANKLE_HEIGHT := 0.09
## How high the propped hand rests: on the ground in front, near the knee.
const HAND_REST := 0.2
var model: Node3D
var rig: Skeleton3D
var bones := {}
var lengths := {}
## Each foot: where it is planted in the world, and the step it is taking.
var feet := {}
## Smoothed 0..1 readings of what the body is doing, so nothing snaps.
var crouch_blend := 0.0
var air_blend := 0.0
var lean := 0.0
var bob := 0.0
var hand_down := 0.0
var meshes: Array[MeshInstance3D] = []
var phase := 0.0
var initialized := false
# Fitted transform of the unrigged model, reused by its crouch/walk motion.
var base_scale := Vector3.ONE
var base_height := 0.0
## Whether the body casts shadows. Only the local first-person body turns it
## off (graphics preset body_shadow): nobody sees it but its own shadow, and
## walking it re-renders every lamp shadow round the player.
var body_shadow := true

func _ready() -> void: configure(character, first_person)

func configure(index: int, local_view: bool) -> void:
	character = clampi(index, 0, IDS.size() - 1)
	first_person = local_view
	if model != null:
		remove_child(model)
		model.queue_free()
	rig = null
	bones.clear()
	meshes.clear()
	if character == 0:
		model = MeshInstance3D.new()
		model.mesh = load("res://game/player/avatars/detective_relaxed.res")
	else: model = load("res://assets/players/%s/model.fbx" % IDS[character]).instantiate()
	model.name = "Model"
	# The Exploradora's FBX brings the camera it was shown with ("Preview_Camera").
	# First into a viewport, it became that viewport's camera: the character
	# screen, opened with her already chosen, framed her from there, too close
	# and off to one side. Whatever a model brings to look or light with is
	# not the body.
	for stray in model.find_children("*", "Camera3D", true, false) + model.find_children("*", "Light3D", true, false):
		stray.get_parent().remove_child(stray)
		stray.free()
	add_child(model)
	# Imported demonstration clips are preserved but never drive game root motion.
	for animation in model.find_children("*", "AnimationPlayer", true, false):
		if character == 2:
			animation.play(animation.get_animation_list()[0])
			animation.advance(0.0)
			animation.pause()
		else: animation.stop()
	if model is MeshInstance3D: meshes.append(model)
	for mesh in model.find_children("*", "MeshInstance3D", true, false): meshes.append(mesh)
	refine_materials()
	var bounds := AABB()
	var first := true
	for mesh in meshes:
		var box: AABB = global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		mesh.layers = 2 if first_person else 1
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if body_shadow or not first_person else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var size_factor := 1.78 / maxf(bounds.size.y, 0.01)
	model.scale *= size_factor
	model.position.y -= bounds.position.y * size_factor
	model.rotation.y += PI
	base_scale = model.scale
	base_height = model.position.y
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if not rigs.is_empty():
		# Some models carry a small accessory skeleton too; animate the body one.
		rigs.sort_custom(func(a, b): return a.get_bone_count() > b.get_bone_count())
		rig = rigs[0]
		var names := MIXAMO if character == 1 else CHARACTER_CREATOR
		for key in names: bones[key] = rig.find_bone(names[key])
		# The lengths of the limbs in the rest pose, which is what the IK
		# solves against.
		for side in ["l", "r"]:
			lengths[side + "leg"] = Vector2(bone_gap(side + "t", side + "k"), bone_gap(side + "k", side + "f"))
			lengths[side + "arm"] = Vector2(bone_gap(side + "a", side + "e"), bone_gap(side + "e", side + "h"))
	initialized = true
	update_pose(Vector3.ZERO, false, 0)

## The bought models come out of the importer a little wrong, and these are
## the fixes, made on a copy of each material as the body is put together.
##
## - Character Creator's eye occlusion is a shell over each eye meant to be a
##   soft transparent shadow in the corners; it imports opaque and white, and
##   the Exploradora looked out through two white balls. It is not drawn.
## - Hair, brows and lashes are cut out with a hard alpha threshold, which
##   leaves every strand a staircase of pixels. They are blended instead,
##   with a depth pre-pass so the layers still sort, and softened on the
##   cut when the screen has MSAA.
## - Every surface came in at roughness 1 with no roughness map: skin, eyes
##   and teeth like chalk. They get a plausible roughness of their own.
## - The detective's own maps -- the relief of the coat, the face, the hat
##   band -- came with it and were never hooked up: only its colour was
##   drawn, flat as a cardboard cut-out. Each part finds its normal map by
##   name beside its colour.
## - Up close a survivor is never drawn with a reduced mesh: the level of
##   detail that is fine for a chair turns a face into facets.
const HAIRLIKE := ["hair", "brow", "lash", "scalp", "tearline"]
## By the name of the material, first match wins: skin before body, so the
## Exploradora's "Skin_Body" is skin and not clothes.
const ROUGHNESS := {
	"skin": 0.52, "eye": 0.12, "cornea": 0.05, "teeth": 0.35, "tongue": 0.4, "nails": 0.4,
	"hair": 0.62, "brow": 0.7, "lash": 0.7, "scalp": 0.7,
	"body": 0.74, "glove": 0.5, "shoe": 0.42, "heel": 0.3, "hat": 0.85, "eyewear": 0.15,
	"top": 0.82, "shirt": 0.85, "bottom": 0.8, "denim": 0.88, "underwear": 0.8,
}
const AVATAR_LOD_BIAS := 6.0

func refine_materials() -> void:
	for mesh in meshes:
		if String(mesh.name).to_lower().contains("eyeocclusion"):
			mesh.visible = false
			continue
		mesh.lod_bias = AVATAR_LOD_BIAS
		if mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null: continue
			var material := original.duplicate() as StandardMaterial3D
			var name := original.resource_name.to_lower()
			material.emission_enabled = false
			if material.normal_texture == null and material.albedo_texture != null:
				var relief := material.albedo_texture.resource_path.replace("_diffuse", "_normal")
				if relief != material.albedo_texture.resource_path and ResourceLoader.exists(relief):
					material.normal_enabled = true
					material.normal_texture = load(relief)
			for key in ROUGHNESS:
				if name.contains(key):
					material.roughness = ROUGHNESS[key]
					break
			# Skin is not a mirror: the default specular turned the detective's
			# face to bronze once its relief was drawn.
			if name.contains("skin") or name.contains("body"): material.metallic_specular = 0.3
			if HAIRLIKE.any(func(word): return name.contains(word)) and original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				material.alpha_antialiasing_edge = 0.3
			mesh.set_surface_override_material(surface, material)

func set_body_shadow(on: bool) -> void:
	body_shadow = on
	var setting := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on or not first_person else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for mesh in meshes:
		if mesh.cast_shadow != setting: mesh.cast_shadow = setting

## Procedural animation, the same idea as the creature's (locust_visual.gd):
## the feet are planted in the world and only move while they are taking a
## step, so nobody slides, and two-bone IK bends the knees to reach them.
## Everything else hangs off that -- the body rises and falls with the step,
## the chest leans into the speed, the arms swing against the legs and the
## head stays level.
##
## Crouching is its own pose: hips down, back rounded, knees deep, and while
## they are still, one hand down on the floor, which comes up as soon as they
## move. In the air the legs tuck and the feet let go of the ground.
##
## Presentation only: it never moves the body, and it is the same code for
## your own body and for a teammate's.
func update_pose(velocity: Vector3, crouching: bool, delta: float, grounded := true) -> void:
	if not initialized: return
	var planar := Vector3(velocity.x, 0, velocity.z)
	var speed := planar.length()
	phase += delta * speed * 2.5
	if rig == null:
		# The OBJ has no bones: only a restrained whole-body walking motion.
		model.position.y = base_height + (absf(sin(phase)) * 0.015 if speed > 0.1 else 0.0)
		model.scale.y = base_scale.y * (0.59 if crouching else 1.0)
		return
	delta = clampf(delta, 0.0, 0.1)
	crouch_blend = move_toward(crouch_blend, 1.0 if crouching else 0.0, delta * 6.0)
	air_blend = move_toward(air_blend, 0.0 if grounded else 1.0, delta * (9.0 if grounded else 5.0))
	var ratio := clampf(speed / RUN_SPEED, 0.0, 1.0)
	var moving := clampf(speed / 0.6, 0.0, 1.0)
	hand_down = move_toward(hand_down, crouch_blend * (1.0 - moving), delta * 4.0)
	if feet.is_empty(): plant_feet()
	if grounded: step_feet(delta, planar, speed, ratio)
	rig.reset_bone_poses()
	pose_body(delta, ratio)
	for side in ["l", "r"]:
		if air_blend > 0.85: tuck_leg(side)
		else: solve_leg(side, feet[side])
	pose_arms(ratio)
	pose_head()

## Both feet under the hips, where they stand at rest.
func plant_feet() -> void:
	for pair in [["l", -1.0], ["r", 1.0]]:
		feet[pair[0]] = {"planted": rest_foot(pair[1]), "from": Vector3.ZERO, "to": Vector3.ZERO, "t": 1.0, "swing": false, "duration": 0.3, "side": pair[1]}

## Where a foot belongs when nothing is happening: under its own hip, on the
## floor the body is standing on.
func rest_foot(side: float) -> Vector3:
	var basis := global_basis.orthonormalized()
	var point: Vector3 = global_position + basis.x * side * STANCE
	point.y = global_position.y
	return point

## Which foot is where. A planted foot stays put until it has fallen far
## enough behind the hips, and then swings to where the body is going to be:
## that is what a walk cycle on a timer can never do, and why nobody slides.
func step_feet(delta: float, planar: Vector3, speed: float, ratio: float) -> void:
	var stride := clampf(STRIDE_BASE + STRIDE_PER_SPEED * speed, STRIDE_RANGE.x, STRIDE_RANGE.y)
	if crouch_blend > 0.5: stride *= STRIDE_CROUCH
	var direction := planar.normalized() if speed > 0.05 else Vector3.ZERO
	var duration := 0.3
	var lift: float = (0.07 + ratio * 0.11) * (1.0 - crouch_blend * 0.45)
	# A foot never lands where the leg cannot follow it: with the hips at
	# nine tenths of a metre a leg only reaches a third of a metre ahead
	# before it has to straighten into a stilt, and that is what drags a
	# planted foot along the floor.
	var span: Vector2 = lengths.get("lleg", Vector2(0.42, 0.42))
	var reach: float = minf(stride * 0.45, (span.x + span.y) * 0.5) * minf(1.0, speed / 0.7)
	# The step itself is twice that reach, and a foot spends about a third of
	# it in the air: any longer and both feet are off the floor at once, which
	# is a run however slowly the body is going.
	duration = clampf(2.0 * reach / maxf(speed, 0.1) * SWING_SHARE, 0.1, 0.4)
	for side in ["l", "r"]:
		var foot: Dictionary = feet[side]
		var other: Dictionary = feet["r" if side == "l" else "l"]
		var rest := rest_foot(foot.side)
		# Teleported, fell, or came out of a wardrobe: start from under the hips.
		if foot.planted.distance_to(rest) > 2.2:
			plant_feet()
			return
		if foot.swing:
			foot.t = minf(1.0, foot.t + delta / foot.duration)
			var eased: float = foot.t * foot.t * (3.0 - 2.0 * foot.t)
			foot.planted = foot.from.lerp(foot.to, eased) + Vector3.UP * sin(PI * foot.t) * lift
			if foot.t >= 1.0:
				foot.swing = false
				foot.planted = foot.to
			continue
		var offset: Vector3 = foot.planted - rest
		var behind: float = -offset.dot(direction) if speed > 0.05 else 0.0
		var sideways: float = (offset - direction * offset.dot(direction)).length() if speed > 0.05 else offset.length()
		var due: bool = behind > reach or sideways > 0.24 or (speed <= 0.2 and offset.length() > 0.12)
		# One foot at a time, except at a run, where the next one starts as
		# the other lands.
		var other_ready: bool = not other.swing or (ratio > 0.55 and other.t > 0.8)
		if due and other_ready:
			foot.swing = true
			foot.t = 0.0
			foot.from = foot.planted
			foot.to = rest + direction * (speed * duration + reach)
			foot.duration = duration
	var lifting: float = maxf(sin(PI * feet.l.t) if feet.l.swing else 0.0, sin(PI * feet.r.t) if feet.r.swing else 0.0)
	bob = lerpf(bob, lifting, minf(1.0, delta * 14.0))

## The hips, the back and the chest: how low the body is, how far it leans
## into where it is going, and the roll that comes with each step.
func pose_body(delta: float, ratio: float) -> void:
	var right := skeleton_axis(Vector3.RIGHT)
	var forward := skeleton_axis(Vector3.FORWARD)
	# Hips low enough that the knees keep slack to reach with: a leg that has
	# to stretch straight to touch the floor reads as stilts.
	# Crouched and still it goes down further and folds over: that is what
	# brings the shoulder near enough for a hand to reach the floor at all.
	var drop: float = crouch_blend * 0.36 + hand_down * 0.16 + 0.04 + ratio * 0.13 - bob * 0.035 + air_blend * 0.06
	var hip := rig.get_bone_global_pose(bones.hip)
	hip.origin += skeleton_axis(Vector3.DOWN) * drop
	rig.set_bone_global_pose(bones.hip, hip)
	lean = lerpf(lean, ratio * 0.34 + crouch_blend * 0.5 + hand_down * 0.28, minf(1.0, delta * 6.0))
	turn_bone("spine", right, lean * 0.55)
	turn_bone("chest", right, lean * 0.45)
	# A step rolls the shoulders a little the other way, which is most of what
	# reads as walking when it is seen from behind.
	var sway := 0.0
	if feet.l.swing: sway -= sin(PI * float(feet.l.t))
	if feet.r.swing: sway += sin(PI * float(feet.r.t))
	turn_bone("spine", forward, sway * 0.045 * (0.5 + ratio))
	turn_bone("chest", forward, sway * 0.03)

## Knee bent to reach the foot where it is planted, and the foot laid flat on
## the floor instead of hanging off the shin.
func solve_leg(side: String, foot: Dictionary) -> void:
	var thigh: int = bones.get(side + "t", -1)
	var calf: int = bones.get(side + "k", -1)
	var ankle: int = bones.get(side + "f", -1)
	if thigh < 0 or calf < 0 or ankle < 0: return
	var hip := rig.get_bone_global_pose(thigh).origin
	var target := to_skeleton(foot.planted) + skeleton_axis(Vector3.UP) * ANKLE_HEIGHT
	var span: Vector2 = lengths[side + "leg"]
	var reach := target - hip
	# Mid-swing the foot is drawn in under the hip, which is what folds the
	# knee: reaching for the ground the whole way keeps the leg straight and
	# the walk looks like a pair of compasses.
	var fold: float = (sin(PI * foot.t) if foot.swing else 0.0) * 0.16
	var distance := clampf(reach.length() - fold, 0.05, span.x + span.y - 0.004)
	var along := reach.normalized()
	# Knees forward and a touch outward, never sideways and never backwards.
	var pole := skeleton_axis(Vector3.FORWARD) + skeleton_axis(Vector3.RIGHT) * (0.18 if side == "r" else -0.18)
	var bend := (pole - along * pole.dot(along)).normalized()
	var cos_hip := clampf((span.x * span.x + distance * distance - span.y * span.y) / (2.0 * span.x * distance), -1.0, 1.0)
	var knee := hip + along * span.x * cos_hip + bend * span.x * sqrt(maxf(0.0, 1.0 - cos_hip * cos_hip))
	aim_bone(thigh, calf, knee - hip)
	aim_bone(calf, ankle, hip + along * distance - rig.get_bone_global_pose(calf).origin)
	var toe: int = bones.get(side + "o", -1)
	if toe < 0: return
	# Flat while it carries the weight, pointed as it leaves the ground.
	var roll: float = sin(PI * foot.t) if foot.swing else 0.0
	aim_bone(ankle, toe, skeleton_axis(Vector3.FORWARD) - skeleton_axis(Vector3.UP) * (0.12 - roll * 0.5))

## In the air there is nothing to reach for: the leg folds under the body.
func tuck_leg(side: String) -> void:
	var right := skeleton_axis(Vector3.RIGHT)
	turn_bone(side + "t", right, 0.9)
	turn_bone(side + "k", right, -1.5)

## Arms swing against the legs, with the elbow carried higher the faster it
## goes. Crouched they come in close, and crouched and still one hand goes
## down to the floor for balance and the other rests on the knee.
func pose_arms(ratio: float) -> void:
	# Which leg is ahead, as a number that runs smoothly from -1 to 1 across
	# the whole stride: taken only from the swinging foot the arms would hang
	# still for the two thirds of the time both feet are on the floor.
	var swing := 0.0
	var across: Vector3 = feet.r.planted - feet.l.planted
	var forward_world: Vector3 = -global_basis.z
	swing = clampf(across.dot(forward_world) / maxf(STRIDE_BASE, 0.1), -1.0, 1.0)
	var down := skeleton_axis(Vector3.DOWN)
	var forward := skeleton_axis(Vector3.FORWARD)
	var right := skeleton_axis(Vector3.RIGHT)
	for pair in [["l", -1.0], ["r", 1.0]]:
		var side: String = pair[0]
		var hand_side: float = pair[1]
		var arm: int = bones.get(side + "a", -1)
		var elbow: int = bones.get(side + "e", -1)
		var hand: int = bones.get(side + "h", -1)
		if arm < 0 or elbow < 0 or hand < 0: continue
		var reach: float = swing * hand_side * (0.75 + ratio * 0.85)
		var upper := (down + right * hand_side * (0.16 + crouch_blend * 0.12) + forward * reach).normalized()
		var fore := (down * (1.0 - 0.45 * ratio - crouch_blend * 0.35) + forward * (0.4 + ratio * 0.6 + crouch_blend * 0.5) - forward * reach * 0.35 + right * hand_side * 0.05).normalized()
		upper = upper.lerp((down + forward * 0.55 + right * hand_side * 0.25).normalized(), air_blend * 0.7)
		aim_bone(arm, elbow, upper)
		aim_bone(elbow, hand, fore)
	# Crouched and still, the right hand goes down to the floor in front and
	# takes some of the weight. It is solved to a point on the ground, like a
	# foot, so it lands on the floor instead of hanging over it.
	if hand_down > 0.01:
		# Low and in front, within what an arm can actually reach from a
		# crouch: any lower and the arm only points at the floor instead of
		# resting on it.
		var ahead: Vector3 = global_position + global_basis.z * -0.32 + global_basis.x * 0.22
		ahead.y = global_position.y + HAND_REST
		reach_hand("r", ahead, hand_down)

## The same two-bone solve as a leg, for an arm that has to touch something:
## the hand on the floor while crouched still.
func reach_hand(side: String, point: Vector3, weight: float) -> void:
	var arm: int = bones.get(side + "a", -1)
	var elbow: int = bones.get(side + "e", -1)
	var hand: int = bones.get(side + "h", -1)
	if arm < 0 or elbow < 0 or hand < 0: return
	var shoulder := rig.get_bone_global_pose(arm).origin
	var target: Vector3 = to_skeleton(point)
	var span: Vector2 = lengths[side + "arm"]
	var reach := target - shoulder
	var distance := clampf(reach.length(), 0.05, span.x + span.y - 0.004)
	var along := reach.normalized()
	# The elbow bends backwards and a little out, the way an arm does when
	# somebody props themselves up.
	var pole := -skeleton_axis(Vector3.FORWARD) + skeleton_axis(Vector3.RIGHT) * (0.3 if side == "r" else -0.3)
	var bend := (pole - along * pole.dot(along)).normalized()
	var cos_shoulder := clampf((span.x * span.x + distance * distance - span.y * span.y) / (2.0 * span.x * distance), -1.0, 1.0)
	var joint := shoulder + along * span.x * cos_shoulder + bend * span.x * sqrt(maxf(0.0, 1.0 - cos_shoulder * cos_shoulder))
	var wanted_upper: Vector3 = (joint - shoulder).normalized()
	var wanted_fore: Vector3 = (shoulder + along * distance - joint).normalized()
	var current_upper: Vector3 = (rig.get_bone_global_pose(elbow).origin - shoulder).normalized()
	aim_bone(arm, elbow, current_upper.lerp(wanted_upper, weight).normalized())
	var forearm_from := rig.get_bone_global_pose(elbow).origin
	var current_fore: Vector3 = (rig.get_bone_global_pose(hand).origin - forearm_from).normalized()
	aim_bone(elbow, hand, current_fore.lerp(wanted_fore, weight).normalized())

## The head stays level with the world instead of riding the lean, which is
## most of what makes a walk read as a person and not as a puppet.
func pose_head() -> void:
	turn_bone("head", skeleton_axis(Vector3.RIGHT), -lean * 0.75)

## A direction of the body, in the skeleton's own space.
func skeleton_axis(direction: Vector3) -> Vector3:
	return (rig.global_basis.inverse() * global_basis * direction).normalized()

func to_skeleton(point: Vector3) -> Vector3:
	return rig.global_transform.affine_inverse() * point

## The rest-pose distance between two bones of the map.
func bone_gap(one: String, two: String) -> float:
	var first: int = bones.get(one, -1)
	var second: int = bones.get(two, -1)
	if first < 0 or second < 0: return 0.4
	return rig.get_bone_global_rest(first).origin.distance_to(rig.get_bone_global_rest(second).origin)

## Rotates a bone in skeleton space so that its child lies along `direction`.
func aim_bone(bone: int, child: int, direction: Vector3) -> void:
	var pose := rig.get_bone_global_pose(bone)
	var current := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	var wanted := direction.normalized()
	if current.dot(wanted) > 0.9999 or current.dot(wanted) < -0.9999: return
	pose.basis = Basis(Quaternion(current, wanted)) * pose.basis
	rig.set_bone_global_pose(bone, pose)

## Turns a bone of the map about an axis given in skeleton space.
func turn_bone(key: String, axis: Vector3, angle: float) -> void:
	var id: int = bones.get(key, -1)
	if id < 0 or is_zero_approx(angle): return
	var pose := rig.get_bone_global_pose(id)
	pose.basis = Basis(axis.normalized(), angle) * pose.basis
	rig.set_bone_global_pose(id, pose)
