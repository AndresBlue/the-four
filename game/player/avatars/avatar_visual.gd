extends Node3D
## Presentation only. Never changes capsule, speed, or saved floor state.
const IDS := ["detective", "detective_woman", "realistic_female"]
const NAMES := ["Detective Masculino", "Detective Femenino", "Exploradora"]
## The capture's own measures (how a body folds up with no room to lie).
const SCORE := preload("res://game/app/capture_score.gd")
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
## How high the ankle sits above the sole, so a planted foot rests on the
## floor instead of sinking into it.
const ANKLE_HEIGHT := 0.09
const SURVIVOR_CLIPS := preload("res://game/player/avatars/survivor_clips.gd")
var model: Node3D
var rig: Skeleton3D
var bones := {}
var lengths := {}
## How the body moves: its clips (survivor_clips.gd, assets/players/<id>/clips.res).
var gait
## Smoothed 0..1 readings of what the body is doing, so nothing snaps.
var crouch_blend := 0.0
var air_blend := 0.0
var meshes: Array[MeshInstance3D] = []
var initialized := false
## Whether the body casts shadows. Only the local first-person body turns it
## off (graphics preset body_shadow): nobody sees it but its own shadow, and
## walking it re-renders every lamp shadow round the player.
var body_shadow := true

func _ready() -> void: configure(character, first_person)

func configure(index: int, local_view: bool) -> void:
	character = clampi(index, 0, IDS.size() - 1)
	first_person = local_view
	if model != null:
		drop_materials()
		remove_child(model)
		model.queue_free()
	rig = null
	bones.clear()
	locks.clear()
	meshes.clear()
	model = load("res://assets/players/%s/model.fbx" % IDS[character]).instantiate()
	if character == 0: dress_detective()
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
			forget_strays(animation)
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
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if not rigs.is_empty():
		# Some models carry a small accessory skeleton too; animate the body one.
		rigs.sort_custom(func(a, b): return a.get_bone_count() > b.get_bone_count())
		rig = rigs[0]
		var names := CHARACTER_CREATOR if character == 2 else MIXAMO
		for key in names: bones[key] = rig.find_bone(names[key])
		# The lengths of the limbs in the rest pose, which is what the IK
		# solves against.
		for side in ["l", "r"]:
			lengths[side + "leg"] = Vector2(bone_gap(side + "t", side + "k"), bone_gap(side + "k", side + "f"))
			lengths[side + "arm"] = Vector2(bone_gap(side + "a", side + "e"), bone_gap(side + "e", side + "h"))
		gait = SURVIVOR_CLIPS.new()
		gait.setup(load("res://assets/players/%s/clips.res" % IDS[character]), rig, absf(model.scale.x))
	initialized = true
	update_pose(Vector3.ZERO, false, 0)

## The detective's skeleton and skin are Mixamo's auto-rigger's, made from
## the OBJ it came as (assets/players/detective/model.obj): it kept the meshes
## and their UVs but not the materials, so each part wears its own from the OBJ.
const DETECTIVE_PARTS := {"Body": "Body", "Eyes": "Body", "Eyelashes": "Body", "Gloves": "Glove", "Tops": "Top", "Bottoms": "Bottom", "Shoes": "Shoes", "Hats": "Hat", "Eyewear": "Eyewear"}

func dress_detective() -> void:
	var source: Mesh = load("res://assets/players/detective/model.obj")
	var materials := {}
	for surface in source.get_surface_count():
		var material := source.surface_get_material(surface)
		if material != null: materials[material.resource_name] = material
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var wanted: String = DETECTIVE_PARTS.get(String(mesh.name), "")
		if mesh.mesh == null or not materials.has(wanted): continue
		for surface in mesh.mesh.get_surface_count(): mesh.set_surface_override_material(surface, materials[wanted])

## The clips of a model still move what was taken out of it (its camera):
## those tracks go too, or every body made of it warns that it cannot find
## them. On the clip as it is in memory, which every body shares.
func forget_strays(player: AnimationPlayer) -> void:
	var from := player.get_node_or_null(player.root_node)
	if from == null: return
	for clip_name in player.get_animation_list():
		var clip := player.get_animation(clip_name)
		for track in range(clip.get_track_count() - 1, -1, -1):
			if from.get_node_or_null(NodePath(clip.track_get_path(track).get_concatenated_names())) == null: clip.remove_track(track)

## The copies refine_materials() hung on the meshes are taken off before the
## body goes. Left on, they died with their mesh a moment before the mesh was
## told, and with two bodies of one model about, the renderer went looking
## for a material that was no longer there ("Parameter material is null").
func drop_materials() -> void:
	staunch()
	for mesh in meshes:
		if not is_instance_valid(mesh) or mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			if mesh.get_surface_override_material(surface) != null: mesh.set_surface_override_material(surface, null)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE: drop_materials()

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
	"skin": 0.55, "eye": 0.12, "cornea": 0.05, "teeth": 0.35, "tongue": 0.4, "nails": 0.5,
	"hair": 0.74, "brow": 0.75, "lash": 0.75, "scalp": 0.75,
	"body": 0.8, "glove": 0.7, "shoe": 0.68, "heel": 0.62, "hat": 0.88, "eyewear": 0.15,
	"top": 0.92, "shirt": 0.92, "bottom": 0.9, "denim": 0.94, "underwear": 0.9,
}
## A survivor is somebody who has been walking this hotel, on this tape: as
## the models come -- skin with the sheen of a shop dummy, a shirt whiter
## than any lamp in the building, patent shoes -- they were a clean render
## pasted over it. So nothing they wear shines (SPECULAR, for whatever is
## not an eye or skin) and all of it is a shade down and a little towards
## the carpet (WORN). Skin is left nearly as it comes (LIVED, SKIN_SPECULAR):
## matt, a shade down and with light let into it, it was a wax figure's.
const SPECULAR := 0.22
const SKIN_SPECULAR := 0.36
const WORN := Color(0.74, 0.7, 0.64)
const LIVED := Color(0.96, 0.93, 0.9)
const WET := ["eye", "cornea", "teeth", "tongue", "eyewear"]
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
			var skin := name.contains("skin")
			if not WET.any(func(word): return name.contains(word)):
				material.metallic_specular = minf(material.metallic_specular, SKIN_SPECULAR if skin else SPECULAR)
				material.albedo_color = material.albedo_color * (LIVED if skin else WORN)
				material.clearcoat_enabled = false
				material.rim_enabled = false
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

## How the body moves while somebody is in it: the clips, mixed by where it
## is going and how fast, crouched or not, on the floor or off it
## (survivor_clips.gd). Crouching and leaving the floor come in over a
## fraction of a second, so nothing snaps.
##
## Presentation only: it never moves the body, and it is the same code for
## your own body and for a teammate's.
func update_pose(velocity: Vector3, crouching: bool, delta: float, grounded := true) -> void:
	if not initialized or fallen or rig == null or gait == null: return
	delta = clampf(delta, 0.0, 0.1)
	crouch_blend = move_toward(crouch_blend, 1.0 if crouching else 0.0, delta * 6.0)
	air_blend = move_toward(air_blend, 0.0 if grounded else 1.0, delta * (9.0 if grounded else 5.0))
	# Seen from the body: to its right, and ahead (it faces -Z).
	var basis := global_basis.orthonormalized()
	var local := Vector2(velocity.dot(basis.x), velocity.dot(-basis.z))
	gait.pose(local, velocity.y, crouch_blend, air_blend, grounded, delta)
	lock_feet(delta, local.length() > LOCK_SPEED and air_blend < 0.3)

## A foot on the floor stays where it was put. A clip's foot slides a little
## whenever the body goes at a speed the clip was not made for (a walk of the
## game is quicker than anybody's), so while a foot is down -- the ball of it
## within PLANTED of where it is standing still (in heels, as the Exploradora
## is, that is a hand off the floor) -- it is held where it came down
## and the knee bends to keep it there, and as it leaves the floor it is let
## go over a moment. Only across the floor: up and down, and how the foot
## rolls over onto its toes, are the clip's -- which is why it is the ball of
## the foot that stays and not the ankle, which goes forward over it. It is
## let go only once it is well up (LIFTED over PLANTED: a running foot brushes
## the line more than once on its way down), and held again from where it is
## seen, which may still be on its way out of the last hold: from where the
## clip has it, it jumped. One the clip takes further than LOCK_REACH from
## where it is held is dragged after it rather than let go with a snap; one
## that would have to cross more than LOCK_GONE (put somewhere else) is let
## go at once.
const PLANTED := 0.05
const LIFTED := 0.03
const LOCK_SPEED := 0.3
const LOCK_REACH := 0.3
const LOCK_GONE := 1.0
const LOCK_RELEASE := 0.08
var locks := {}

func lock_feet(delta: float, moving: bool) -> void:
	var floor_y := global_position.y
	for side in ["l", "r"]:
		var ankle: int = bones.get(side + "f", -1)
		var toe: int = bones.get(side + "o", -1)
		if ankle < 0 or toe < 0: continue
		var lock: Dictionary = locks.get(side, {"at": Vector3.ZERO, "weight": 0.0, "on": false})
		locks[side] = lock
		var foot := bone_point(ankle)
		var ball := bone_point(toe)
		if not lock.has("rest"): lock.rest = (global_transform.affine_inverse() * rig.global_transform * rig.get_bone_global_rest(toe).origin).y
		var height: float = ball.y - floor_y - float(lock.rest)
		if not moving or height > PLANTED + LIFTED: lock.on = false
		elif height < PLANTED and not lock.on:
			lock.on = true
			var weight := float(lock.weight)
			lock.at = Vector3(lerpf(ball.x, lock.at.x, weight), ball.y, lerpf(ball.z, lock.at.z, weight))
		if lock.on:
			var off := Vector2(lock.at.x - ball.x, lock.at.z - ball.z)
			if off.length() > LOCK_GONE:
				lock.on = false
				lock.weight = 0.0
			elif off.length() > LOCK_REACH:
				off = off.normalized() * LOCK_REACH
				lock.at = Vector3(ball.x + off.x, lock.at.y, ball.z + off.y)
		lock.weight = 1.0 if lock.on else move_toward(float(lock.weight), 0.0, delta / LOCK_RELEASE)
		# The ankle where it has to be for the ball of the foot, turned as the
		# clip turns it, to be where it came down.
		if lock.weight > 0.001: reach_foot(side, foot + Vector3(lock.at.x - ball.x, 0.0, lock.at.z - ball.z), float(lock.weight))

## The leg bent so that the ankle is `weight` of the way to `point` (in the
## world), the knee bending the way the clip already bends it and the foot
## kept turned as the clip has it.
func reach_foot(side: String, point: Vector3, weight: float) -> void:
	var thigh: int = bones.get(side + "t", -1)
	var calf: int = bones.get(side + "k", -1)
	var ankle: int = bones.get(side + "f", -1)
	if thigh < 0 or calf < 0 or ankle < 0: return
	var hip := rig.get_bone_global_pose(thigh).origin
	var knee_now := rig.get_bone_global_pose(calf).origin
	var foot_pose := rig.get_bone_global_pose(ankle)
	var target := foot_pose.origin.lerp(to_skeleton(point), weight)
	var span: Vector2 = lengths[side + "leg"]
	var reach := target - hip
	var distance := clampf(reach.length(), 0.05, span.x + span.y - 0.004)
	var along := reach.normalized()
	var pole := knee_now - hip
	var bend := pole - along * pole.dot(along)
	if bend.length() < 0.001: bend = skeleton_axis(Vector3.FORWARD) - along * skeleton_axis(Vector3.FORWARD).dot(along)
	bend = bend.normalized()
	var cos_hip := clampf((span.x * span.x + distance * distance - span.y * span.y) / (2.0 * span.x * distance), -1.0, 1.0)
	var knee := hip + along * span.x * cos_hip + bend * span.x * sqrt(maxf(0.0, 1.0 - cos_hip * cos_hip))
	aim_bone(thigh, calf, knee - hip)
	aim_bone(calf, ankle, hip + along * distance - rig.get_bone_global_pose(calf).origin)
	var placed := rig.get_bone_global_pose(ankle)
	placed.basis = foot_pose.basis
	rig.set_bone_global_pose(ankle, placed)

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

# --- A capture (docs/EXECUTION.md) ------------------------------------------------

## Whether the body is drawn for its owner's own camera. It never is while
## the camera is in its hands (layer 2, which that camera does not draw); once
## the camera has been knocked out of them, the tape sees its owner from
## outside like anybody else.
func show_to_owner(shown: bool) -> void:
	for mesh in meshes: put_on_layers(mesh, 1 if shown or not first_person else 2)

## A mesh's render layers changed without leaving it paired to a lamp by the
## old ones: hidden, changed, shown (the engine's quirk, room_layers.put_on).
static func put_on_layers(mesh: GeometryInstance3D, layers: int) -> void:
	if mesh.layers == layers: return
	if not mesh.is_inside_tree():
		mesh.layers = layers
		return
	RenderingServer.instance_set_visible(mesh.get_instance(), false)
	mesh.layers = layers
	RenderingServer.instance_set_visible(mesh.get_instance(), mesh.is_visible_in_tree())

# --- What soaks out of it (docs/EXECUTION.md, 8.7) ------------------------------------

const WORN_BLOOD := preload("res://game/presentation/shaders/blood_worn.gdshader")
## The stain on a body the creature has run through: one material, drawn as
## a second pass over everything of it that is not hair or an eye.
var stain: ShaderMaterial

## The wounds as they are this frame: the blade that holds it, through the
## chest from the grab; and the blow, through the face at KILL_TIME. `since`
## is the scene's clock.
func bleed(since: float) -> void:
	if stain == null:
		stain = ShaderMaterial.new()
		stain.shader = WORN_BLOOD
		stain.render_priority = 3
		for mesh in meshes:
			if not is_instance_valid(mesh) or mesh.mesh == null: continue
			for surface in mesh.mesh.get_surface_count():
				var worn := mesh.get_surface_override_material(surface) as StandardMaterial3D
				if worn == null or worn.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
				var name := worn.resource_name.to_lower()
				if WET.any(func(word): return name.contains(word)) or HAIRLIKE.any(func(word): return name.contains(word)): continue
				worn.next_pass = stain
	var places: Array = []
	var frames: Array = []
	for pair in [["chest", Vector3(0.0, 1.28, 0.0)], ["head", Vector3(0.0, 1.62, 0.0)]]:
		var bone: int = bones.get(pair[0], -1) if rig != null else -1
		if bone >= 0:
			var pose: Transform3D = rig.global_transform * rig.get_bone_global_pose(bone)
			# A hand above the bone: the middle of the chest, the middle of the face.
			places.append(pose.origin + pose.basis.y.normalized() * 0.07)
			frames.append(pose.basis.orthonormalized().inverse())
		else:
			places.append(global_transform * (pair[1] as Vector3))
			frames.append(global_basis.orthonormalized().inverse())
	stain.set_shader_parameter("wound_at", PackedVector3Array(places))
	stain.set_shader_parameter("wound_frame", frames)
	stain.set_shader_parameter("wound_age", PackedFloat32Array([since - 0.03, since - SCORE.KILL_TIME]))

## Nobody is bleeding: the stain is off whatever wore it.
func staunch() -> void:
	if stain == null: return
	for mesh in meshes:
		if not is_instance_valid(mesh) or mesh.mesh == null: continue
		for surface in mesh.mesh.get_surface_count():
			var worn := mesh.get_surface_override_material(surface) as StandardMaterial3D
			if worn != null and worn.next_pass == stain: worn.next_pass = null
	stain = null

## A body the creature let fall lies as it fell: nothing stands it up, walks
## it or breathes for it until it is given back to somebody (end_capture).
var fallen := false

## Back as it stands, after a capture that ended or was let go.
func end_capture() -> void:
	fallen = false
	staunch()
	transform = Transform3D.IDENTITY
	show_to_owner(false)

## Where the hips are in the body's own space, standing.
func hip_rest() -> Vector3:
	var id: int = bones.get("hip", -1)
	if rig == null or id < 0: return Vector3(0.0, 0.95, 0.0)
	return (global_transform.affine_inverse() * rig.global_transform) * rig.get_bone_global_rest(id).origin

## A leg of somebody sitting on the floor: the foot brought to where it is
## put (`weight` of the way there from where it hangs) and the knee up.
func seat_leg(side: String, spot: Vector3, weight: float) -> void:
	var thigh: int = bones.get(side + "t", -1)
	var calf: int = bones.get(side + "k", -1)
	var ankle: int = bones.get(side + "f", -1)
	if thigh < 0 or calf < 0 or ankle < 0: return
	var hip := rig.get_bone_global_pose(thigh).origin
	var target := rig.get_bone_global_pose(ankle).origin.lerp(to_skeleton(spot), weight)
	var span: Vector2 = lengths[side + "leg"]
	var reach := target - hip
	var distance := clampf(reach.length(), 0.05, span.x + span.y - 0.004)
	var along := reach.normalized()
	# Up, whichever way the trunk leans; forwards while the leg still hangs.
	var pole := (rig.global_basis.inverse() * Vector3.UP).normalized() + skeleton_axis(Vector3.FORWARD) * 0.8 + skeleton_axis(Vector3.RIGHT) * (0.12 if side == "r" else -0.12)
	var bend := (pole - along * pole.dot(along)).normalized()
	var cos_hip := clampf((span.x * span.x + distance * distance - span.y * span.y) / (2.0 * span.x * distance), -1.0, 1.0)
	var knee := hip + along * span.x * cos_hip + bend * span.x * sqrt(maxf(0.0, 1.0 - cos_hip * cos_hip))
	aim_bone(thigh, calf, knee - hip)
	aim_bone(calf, ankle, hip + along * distance - rig.get_bone_global_pose(calf).origin)

# --- Kept out of the walls ----------------------------------------------------------
#
# A body the scene carries about is not moved by the physics that keeps a
# walking one out of things: held against a wall its arms were flung through
# it, laid on the floor its elbows and heels lay under the carpet, and sat
# against a wall its head was in it. So what the scene poses is put right
# against the place itself, joint by joint, every frame it is posed.

## What no part of a body may be in: walls, floors and furniture (1), doors
## and wardrobe leaves shut (8) or standing open (64).
const SOLID := 1 | 8 | 64
## Half the thickness of what hangs from each joint (metres): the limbs, by
## the joint they end at, and the trunk, which the floor has to be under.
const LIMB := {"e": 0.055, "h": 0.07, "k": 0.075, "f": 0.065, "o": 0.045}
const TRUNK := {"hip": 0.1, "chest": 0.11, "head": 0.1, "la": 0.06, "ra": 0.06, "lt": 0.085, "rt": 0.085}
## From the base of the skull to past its top, along the neck.
const SKULL := 0.22

## Where a bone is, in the world.
func bone_point(bone: int) -> Vector3:
	return rig.global_transform * rig.get_bone_global_pose(bone).origin

## Where the end of a limb can be: where it was put, or as near that as the
## place lets something `thick` be, the same length from its joint. `clear`:
## {space, exclude, floor} (clearance).
func kept_out(from: Vector3, tip: Vector3, thick: float, clear: Dictionary) -> Vector3:
	var space: PhysicsDirectSpaceState3D = clear.space
	var length := from.distance_to(tip)
	if length < 0.01: return tip
	var wanted := tip
	for attempt in 4:
		var moved := false
		var along := (wanted - from).normalized()
		var query := PhysicsRayQueryParameters3D.create(from, from + along * (length + thick), SOLID)
		query.exclude = clear.exclude
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			# Through something, or nearer it than it is thick: round, out of it.
			wanted = swung(from, wanted, length, hit.normal, hit.position, thick)
			moved = true
		else:
			# Alongside something: off it.
			for turn in 6:
				var aside := Vector3(cos(TAU * float(turn) / 6.0), 0.0, sin(TAU * float(turn) / 6.0))
				var graze := PhysicsRayQueryParameters3D.create(wanted, wanted + aside * thick, SOLID)
				graze.exclude = clear.exclude
				var near := space.intersect_ray(graze)
				if near.is_empty(): continue
				wanted = swung(from, wanted, length, near.normal, near.position, thick)
				moved = true
		# And never under the floor.
		if wanted.y < float(clear.floor) + thick - 0.002:
			wanted = swung(from, wanted, length, Vector3.UP, Vector3(wanted.x, float(clear.floor), wanted.z), thick)
			moved = true
		if not moved: break
	return wanted

## The end of a limb swung about its joint until it is `thick` off a face of
## something (a point of it and the way it faces): as far towards it as that
## leaves, and the rest of its length along it, the way it was already going.
func swung(from: Vector3, tip: Vector3, length: float, normal: Vector3, on: Vector3, thick: float) -> Vector3:
	var reach := tip - from
	# How far off the face its end has to be, as seen from the joint.
	var least := clampf(thick + 0.005 - (from - on).dot(normal), -length, length * 0.98)
	if reach.dot(normal) >= least: return tip
	var beside := reach - normal * reach.dot(normal)
	if beside.length() < 0.001: beside = Vector3.DOWN - normal * Vector3.DOWN.dot(normal)
	if beside.length() < 0.001: beside = Vector3.FORWARD
	return from + normal * least + beside.normalized() * sqrt(maxf(0.0, length * length - least * least))

## A bone turned so that the one hanging from it is clear of the place.
func clear_bone(bone: int, child: int, thick: float, clear: Dictionary) -> void:
	if bone < 0 or child < 0 or clear.is_empty(): return
	var from := bone_point(bone)
	var tip := bone_point(child)
	var wanted := kept_out(from, tip, thick, clear)
	if wanted.distance_to(tip) > 0.002: aim_bone(bone, child, rig.global_basis.inverse() * (wanted - from))

## The head, which has no bone beyond it: its top is along the neck.
func clear_head(clear: Dictionary) -> void:
	var chest: int = bones.get("chest", -1)
	var head: int = bones.get("head", -1)
	if chest < 0 or head < 0 or clear.is_empty(): return
	var from := bone_point(chest)
	var neck := bone_point(head) - from
	if neck.length() < 0.01: return
	var top := from + neck.normalized() * (neck.length() + SKULL)
	var wanted := kept_out(from, top, 0.1, clear)
	if wanted.distance_to(top) > 0.002: aim_bone(chest, head, rig.global_basis.inverse() * (wanted - from))

## The head of somebody lying, laid on the floor: the skull is HEAD_REST
## thick behind the bone that carries it.
const HEAD_REST := 0.095
## A body's own origin is this far over the floor it stands on (so is the
## creature's, from which the scene measures): the floor is that much lower
## than either, and a body laid on "the floor" without it lay a finger over it.
const STANDS_OVER := 0.035
## How high the hips of somebody lying flat are, over that origin.
const LAID_HIPS := 0.075
func rest_head(floor_y: float, weight: float) -> void:
	var chest: int = bones.get("chest", -1)
	var head: int = bones.get("head", -1)
	if chest < 0 or head < 0 or weight <= 0.0: return
	var from := bone_point(chest)
	var neck := bone_point(head) - from
	var length := neck.length()
	var over := (from.y + neck.y) - (floor_y + HEAD_REST)
	if length < 0.01 or over <= 0.002: return
	var down := clampf(neck.y - over * clampf(weight, 0.0, 1.0), -length, length)
	var flat := Vector3(neck.x, 0.0, neck.z)
	if flat.length() < 0.001: return
	aim_bone(chest, head, rig.global_basis.inverse() * (flat.normalized() * sqrt(maxf(0.0, length * length - down * down)) + Vector3.UP * down))

## How far the trunk has to come up for none of it to be under the floor.
func under_floor(floor_y: float) -> float:
	var deepest := 0.0
	for key in TRUNK:
		var bone: int = bones.get(key, -1)
		if bone >= 0: deepest = maxf(deepest, floor_y + float(TRUNK[key]) - bone_point(bone).y)
	return deepest

## Somebody the creature has: run through on its arm, held up, hanging from
## it once the blow has landed, and let go. What is let go is a body with
## nobody in it, and it goes down as one does (capture_score: dropped, sunk,
## toppled, jolt): it falls the metre it was held up, its legs give under it
## at the speed it arrives with and it comes down on its seat, folded
## forward; from there the trunk goes over backwards, faster and faster, the
## head and the arms a moment behind it; it meets the floor, gives once, and
## the arms and a leg slide out. How far back it goes is the room there is
## behind it: flat on its back with a knee up where there is the length of
## a body, propped against whatever is there where there is not. (It used to
## be turned to the floor all of a piece, about its feet, and set down
## gently: a shop dummy tipped over.) The scene writes this every frame
## instead of update_pose (executions.gd), the same on every machine. state:
## lift, limp and fall (0 to 1, capture_score), time (the scene's clock),
## side (-1 or 1, which way it goes over), straight (straight back, to no
## side), slump (no room to lie: straight back too) with room (metres clear
## behind it) and sill (how far above the floor it comes to sit: a
## wardrobe's bottom board), and height (how far above the floor the body is
## held), away (to which side its head turns once it is dead: 1 its
## left) and bleed (whether this machine shows what soaks out of it). And, for none of it to end up in a wall or under the floor,
## `clear`: the bodies the scene's own rays go through (kept_out).
func pose_capture(state: Dictionary) -> void:
	if not initialized: return
	var lift := float(state.get("lift", 0.0))
	var limp := float(state.get("limp", 0.0))
	var fall := float(state.get("fall", 0.0))
	var time := float(state.get("time", 0.0))
	var side := float(state.get("side", 1.0))
	var slump := bool(state.get("slump", false))
	var room := float(state.get("room", SCORE.LIE_ROOM))
	fallen = fall > 0.0
	if bool(state.get("bleed", false)): bleed(time)
	elif stain != null: staunch()
	var sat := SCORE.sunk(fall)
	var gone := SCORE.toppled(fall)
	var jolt := SCORE.jolt(fall)
	# Half way over is where what trails it trails most.
	var trail := sin(PI * sqrt(gone)) * (1.0 - jolt)
	var clear := {}
	if rig != null and state.has("clear") and is_inside_tree() and get_parent_node_3d() != null:
		clear = {"space": get_world_3d().direct_space_state, "exclude": state.clear, "floor": get_parent_node_3d().global_position.y - float(state.get("height", 0.0)) - STANDS_OVER + float(state.get("sill", 0.0)) * sat}
	var seat := SCORE.seat_back(room)
	var recline := SCORE.seat_lean(room)
	# Which way it goes over: back, and to a side where there is one to go to.
	var way := Vector3(0.0 if slump or bool(state.get("straight", false)) else side * 0.62, 0.0, 0.78).normalized()
	var over := Basis(Vector3.RIGHT, -(0.06 + 0.1 * lift + 0.12 * limp) * (1.0 - sat))
	var leant := recline * (gone - 0.07 * jolt)
	var turned := Basis(Vector3.UP, atan2(way.x, way.z) * gone) * Basis(Vector3.RIGHT, leant) * over
	if rig == null: return
	# Its hips come down where its legs give, a little behind its feet.
	var hips := hip_rest()
	var low := lerpf(SCORE.SEAT_HEIGHT, LAID_HIPS, gone * clampf(recline / 1.45, 0.0, 1.0))
	var sitting := Vector3(hips.x + way.x * seat * sat, lerpf(hips.y, low + float(state.get("sill", 0.0)), sat), hips.z + way.z * seat * sat)
	# Held, it is bent about its feet, as it always was; down, about its hips.
	transform = Transform3D(turned, (sitting - turned * hips) * minf(1.0, sat * 4.0))
	rig.reset_bone_poses()
	var right := skeleton_axis(Vector3.RIGHT)
	var forward := skeleton_axis(Vector3.FORWARD)
	var below := skeleton_axis(Vector3.DOWN)
	var alive := 1.0 - limp
	# How near upright it ends (flat on its back, nothing of what follows
	# hangs forward).
	var upright := 1.0 - clampf(recline / 1.45, 0.0, 1.0)
	# The back (turned about its right, a bone goes back with a positive
	# angle and forward with a negative one): hunched on the blade while
	# there is life in it and arched over it once there is not; folded
	# forward over its knees as it comes down on its seat; and from there
	# straight, or rounded against what props it.
	var hung := limp * (1.0 - sat)
	var folded := sat * (1.0 - gone)
	turn_bone("spine", right, -0.16 * alive + 0.3 * hung - 0.45 * folded + 0.2 * sat * gone * upright)
	turn_bone("chest", right, -0.2 * alive + 0.22 * hung - 0.35 * folded + 0.16 * sat * gone * upright)
	# The head: thrown back while it hangs; on its chest as the legs give and
	# as the trunk goes over, behind it; back with a jolt when the floor stops
	# the shoulders; and where it comes to rest -- on its chest still, sat up,
	# and rolled to a side, lying.
	turn_bone("head", right, -0.42 * alive * (0.4 + 0.6 * lift) + 0.55 * hung - 0.55 * folded - 0.5 * trail + 0.35 * jolt - 0.5 * gone * upright + 0.06 * gone * (1.0 - upright))
	# And once there is nobody in it, it turns away: to the side the camera on
	# the floor is not on (`away`, which the scene says: 1 its left), slowly,
	# as somebody's does who has gone, and it stays turned -- nobody's face
	# is left looking into the lens.
	var away := float(state.get("away", side))
	var faded := SCORE.smooth(SCORE.ramp(time, SCORE.KILL_TIME + 0.05, SCORE.KILL_TIME + 0.75))
	turn_bone("head", -below, away * 0.95 * faded)
	turn_bone("head", forward, -away * (0.12 * limp + 0.1 * faded))
	if not clear.is_empty():
		# Down on the floor, the whole of it comes up until its back is on the
		# carpet and not under it; and its head is kept out of what is behind it.
		if sat > 0.0: position.y += under_floor(float(clear.floor))
		clear_head(clear)
		# And lying, the back of its head is on the floor: let down to it from
		# wherever the neck was holding it.
		if gone > 0.0 and upright < 0.2: rest_head(float(clear.floor), gone * (1.0 - upright * 5.0))
	# The arms: flung out at the grab, up to the arm that holds as the feet
	# leave the floor, and down for good after the blow.
	var sag := (rig.global_basis.inverse() * Vector3.DOWN).normalized()
	for pair in [["l", -1.0], ["r", 1.0]]:
		var key: String = pair[0]
		var hand_side: float = pair[1]
		var arm: int = bones.get(key + "a", -1)
		var elbow: int = bones.get(key + "e", -1)
		var hand: int = bones.get(key + "h", -1)
		if arm < 0 or elbow < 0 or hand < 0: continue
		var flung := (right * hand_side * 0.85 + below * 0.45 - forward * 0.25).normalized()
		var flung_fore := (right * hand_side * 0.5 + below * 0.7 + forward * 0.5).normalized()
		var clutch := (right * hand_side * 0.35 + below * 0.2 + forward * 0.9).normalized()
		var clutch_fore := (-right * hand_side * 0.75 - below * 0.35 + forward * 0.55).normalized()
		var dead := (right * hand_side * 0.14 + below - forward * 0.08).normalized()
		var dead_fore := (right * hand_side * 0.05 + below + forward * 0.12).normalized()
		# Down: they hang to the floor beside it, the hands in its lap, sat up;
		# and lying, they lie where they dropped -- the one on the side it went
		# over to further out than the other, its hand turned up.
		var outer := hand_side * side > 0.0
		var spread := lerpf(0.32, 0.85 if outer else 0.5, 1.0 - upright)
		var thrown := (below * 0.75 + sag * 0.35 * (0.25 + 0.75 * upright) + right * hand_side * spread).normalized()
		var thrown_fore := (below * 0.45 + (forward * 0.7 + sag * 0.2) * upright + right * hand_side * (0.12 if upright > 0.5 or not outer else 0.5) - below * (0.0 if upright > 0.5 or not outer else 0.6)).normalized()
		# On the way down they are the last of it to go: left in the air in
		# front of it while the trunk goes over, and down a moment after it.
		var left_behind := (forward * 0.85 + below * 0.35 + right * hand_side * 0.3).normalized()
		var late := clampf(gone * 1.0 - 0.25 * trail, 0.0, 1.0)
		var struggle := clampf(lift * 1.6, 0.0, 1.0)
		var upper := flung.lerp(clutch, struggle).lerp(dead, limp).lerp(thrown, sat * late).lerp(left_behind, 0.55 * trail).normalized()
		var fore := flung_fore.lerp(clutch_fore, struggle).lerp(dead_fore, limp).lerp(thrown_fore, sat * late).lerp(left_behind, 0.75 * trail).normalized()
		# And they give once more when it lands.
		upper = (upper - sag * 0.25 * jolt).normalized()
		fore = (fore - sag * 0.45 * jolt).normalized()
		aim_bone(arm, elbow, upper)
		clear_bone(arm, elbow, LIMB.e, clear)
		aim_bone(elbow, hand, fore)
		clear_bone(elbow, hand, LIMB.h, clear)
	# The legs: standing while it still has the floor, kicking once it has not,
	# hanging after the blow, and under it when it comes down.
	for pair in [["l", -1.0], ["r", 1.0]]:
		var key: String = pair[0]
		var leg_side: float = pair[1]
		var thigh: int = bones.get(key + "t", -1)
		var calf: int = bones.get(key + "k", -1)
		var ankle: int = bones.get(key + "f", -1)
		var toe: int = bones.get(key + "o", -1)
		if thigh < 0 or calf < 0 or ankle < 0: continue
		# As its feet leave the floor it fights what has it -- a few uneven
		# kicks, no more than a body held by the chest can give -- and that is
		# soon spent: what
		# is left is a slow treading of the air, less and less, until the blow;
		# after it they only swing. The knees are never straight and never go
		# back: the thighs hang a little forward of the hips and the shins a
		# little behind the knees, as legs with nothing under them do. (Turned
		# the other way, as they were, the knees were pushed in backwards.)
		var since := time - SCORE.LIFT_FROM
		var fight := alive * SCORE.smooth(since / 0.2) * (1.0 - SCORE.smooth((since - 0.45) / 0.55))
		var tread := alive * SCORE.smooth((since - 0.55) / 0.6) * (1.0 - 0.6 * SCORE.ramp(time, SCORE.LIFT_TO, SCORE.KILL_TIME))
		# No two legs alike: one leads, harder and quicker; the other follows
		# late, less, at a pace of its own, and hangs a little further forward.
		var lead := leg_side * side > 0.0
		var own := 0.0 if lead else 2.3
		var pace := 1.0 if lead else 0.78
		var reach := 1.0 if lead else 0.6
		var kicking := 0.65 * sin(time * 11.5 * pace + own) + 0.35 * sin(time * 18.0 * pace + own * 1.7)
		var treading := sin(time * 4.2 * pace + own)
		var swinging := limp * sin((time - SCORE.KILL_TIME) * 5.5 * pace + own * 0.5) * exp(-maxf(0.0, time - SCORE.KILL_TIME) * 2.2)
		var hip := (0.04 if lead else 0.1) + 0.12 * lift + 0.22 * reach * fight * kicking + 0.12 * reach * tread * treading + 0.07 * swinging
		var knee := (0.12 if lead else 0.2) + 0.14 * lift + 0.3 * reach * fight * (0.5 - 0.5 * kicking) + 0.2 * reach * tread * (0.5 + 0.5 * sin(time * 4.2 * pace + own + 1.2)) + 0.12 * limp + 0.05 * swinging
		turn_bone(key + "t", right, hip)
		turn_bone(key + "t", forward, leg_side * (0.05 + 0.2 * sat))
		turn_bone(key + "k", right, -knee)
		# Its feet meet the floor and stay where they met it while the hips come
		# down behind them: the knees go up. Lying, the leg on the side it went
		# over to slides out until it is all but straight; the other knee stays.
		if sat > 0.0 and get_parent_node_3d() != null:
			var outer := leg_side * side > 0.0
			var ahead := (0.64 + 0.3 * gone * (1.0 - upright)) if outer else 0.5
			var spot := get_parent_node_3d().global_transform * Vector3(leg_side * (0.15 + (0.1 * gone * (1.0 - upright) if outer else 0.0)) - way.x * (ahead - seat), ANKLE_HEIGHT - float(state.get("height", 0.0)), way.z * (seat - ahead))
			seat_leg(key, spot, clampf(sat * 2.5, 0.0, 1.0))
		# Feet that carry nothing point down; those of somebody sitting, ahead.
		if toe >= 0 and (lift > 0.05 or sat > 0.0): aim_bone(ankle, toe, (below * (0.75 + 0.25 * limp) * (1.0 - sat) + forward * (0.5 + sat)).normalized())
		clear_bone(thigh, calf, LIMB.k, clear)
		clear_bone(calf, ankle, LIMB.f, clear)
		if toe >= 0: clear_bone(ankle, toe, LIMB.o, clear)
