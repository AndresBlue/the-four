extends RefCounted
## The Locust as the first commit had it (ec1cc07e, tools/build_scene.gd: a
## stand-in of spheres and cylinders), worn over the real one's skeleton so it
## walks, crouches and strikes with the same clips: each piece hangs from its
## bone, placed in the rest pose the way the stand-in stood. An extra unlocked
## by a code (hotel_ui CODES, "Legacy Locust" in Ajustes, Extras); this
## machine's picture only.
const BONE := "ValveBiped.Bip01_"
const SKIN := Color(0.055, 0.041, 0.031)
const FACE := Color(0.51, 0.43, 0.29)
const EYE := Color(0.86, 0.85, 0.63)
const DARK := Color(0.008, 0.007, 0.006)
## The stand-in's head stood this high; everything is scaled from there.
const HEAD_HEIGHT := 2.61

## On or off: the stand-in hung on the visual's skeleton, the real body made
## invisible (not hidden: other parts of the game show and hide its meshes).
static func wear(visual: Node3D, on: bool) -> void:
	var rigs := visual.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty(): return
	var skeleton: Skeleton3D = rigs[0]
	# The Locust's skeleton only (not the Lurker's, on floor 2).
	if skeleton.find_bone(BONE + "Head1") < 0: return
	if bool(visual.get_meta("legacy", false)) == on: return
	visual.set_meta("legacy", on)
	for old in skeleton.get_children():
		if old.has_meta("legacy"):
			skeleton.remove_child(old)
			old.queue_free()
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		mesh.transparency = 1.0 if on else 0.0
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if on: build(skeleton)

static func rest(skeleton: Skeleton3D, name: String) -> Transform3D:
	return skeleton.get_bone_global_rest(skeleton.find_bone(BONE + name))

## The creature's own space (metres, Y up) from the skeleton's: the model
## comes Z-up, turned and scaled inside the visual.
static var to_body := Transform3D.IDENTITY
static func at(skeleton: Skeleton3D, name: String) -> Vector3:
	return to_body * rest(skeleton, name).origin

static func build(skeleton: Skeleton3D) -> void:
	var body := skeleton.get_parent()
	while body != null and not body is CharacterBody3D: body = body.get_parent()
	if body == null: return
	to_body = (body as Node3D).global_transform.affine_inverse() * skeleton.global_transform
	# The pieces hang straight from the skeleton: an attachment follows its
	# bone only as the skeleton's own child.
	var root := skeleton
	var head := at(skeleton, "Head1")
	var k: float = head.y / HEAD_HEIGHT
	var skin := material(SKIN)
	var face := material(FACE)
	var dark := material(DARK)
	var eye := material(EYE, 0.5)
	# The front of the body at rest: from the heel towards the toes.
	var front := Vector3(0, 0, 1)
	if skeleton.find_bone(BONE + "L_Toe0") >= 0:
		var toe := at(skeleton, "L_Toe0") - at(skeleton, "L_Foot")
		toe.y = 0.0
		if toe.length() > 0.001: front = toe.normalized()
	var right := Vector3.UP.cross(front).normalized()
	var spine := at(skeleton, "Spine")
	var neck := at(skeleton, "Neck1")
	ellipsoid(root, skeleton, "Spine2", (spine + neck) * 0.5, Vector3(0.55, 0.75, 0.3) * k, front, skin)
	limb(root, skeleton, "Neck1", neck, head, 0.06 * k, skin)
	var middle := head + front * 0.02 * k
	ellipsoid(root, skeleton, "Head1", middle, Vector3(0.52, 0.52, 0.30) * k, front, face)
	ellipsoid(root, skeleton, "Head1", middle + (Vector3(0, -0.16, 0) + front * 0.23) * k, Vector3(0.30, 0.31, 0.08) * k, front, dark)
	for side in [-1.0, 1.0]:
		var s: String = "L" if side < 0.0 else "R"
		# Each eye on its own side of the face, whichever way the bones name it.
		var across: Vector3 = right * side * 0.135
		ellipsoid(root, skeleton, "Head1", middle + (across + Vector3(0, 0.07, 0) + front * 0.245) * k, Vector3(0.13, 0.115, 0.065) * k, front, dark)
		ellipsoid(root, skeleton, "Head1", middle + (across + Vector3(0, 0.08, 0) + front * 0.277) * k, Vector3(0.037, 0.044, 0.025) * k, front, eye)
		var shoulder := at(skeleton, s + "_UpperArm")
		var elbow := at(skeleton, s + "_Forearm")
		var wrist := at(skeleton, s + "_Hand")
		limb(root, skeleton, s + "_UpperArm", shoulder, elbow, 0.065 * k, skin)
		limb(root, skeleton, s + "_Forearm", elbow, wrist, 0.047 * k, skin)
		# Three long fingers, on down and forward from the wrist.
		var reach := (wrist - elbow).normalized()
		var out: Vector3 = (wrist - Vector3(0, wrist.y, 0)).normalized() if absf(wrist.x) + absf(wrist.z) > 0.001 else right
		for finger in 3:
			var start: Vector3 = wrist + out * (finger - 1) * 0.04 * k
			limb(root, skeleton, s + "_Hand", start, start + (reach * 0.22 + front * 0.08 + out * (finger - 1) * 0.03 + Vector3(0, -0.06, 0)) * k, 0.014 * k, skin)
		var hip := at(skeleton, s + "_Thigh")
		var knee := at(skeleton, s + "_Calf")
		var ankle := at(skeleton, s + "_Foot")
		limb(root, skeleton, s + "_Thigh", hip, knee, 0.08 * k, skin)
		limb(root, skeleton, s + "_Calf", knee, ankle, 0.05 * k, skin)
		ellipsoid(root, skeleton, s + "_Foot", ankle + (front * 0.06 + Vector3(0, -0.02, 0)) * k, Vector3(0.16, 0.10, 0.38) * k, front, skin)

static func material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

## A piece hung from `bone`, placed at `where` (the creature's space) as the
## body stands at rest.
static func attach(root: Node3D, skeleton: Skeleton3D, bone: String, piece: Node3D, where: Transform3D) -> void:
	var holder := BoneAttachment3D.new()
	holder.name = "Legacy_%d" % root.get_child_count()
	holder.set_meta("legacy", true)
	root.add_child(holder)
	holder.bone_name = BONE + bone
	# The attachment follows the bone's pose; the piece sits where it did at rest.
	piece.transform = (to_body * rest(skeleton, bone)).affine_inverse() * where
	holder.add_child(piece)

static func ellipsoid(root: Node3D, skeleton: Skeleton3D, bone: String, centre: Vector3, size: Vector3, front: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 20
	sphere.rings = 12
	mesh.mesh = sphere
	mesh.material_override = mat
	# Its depth (z) along the body's front.
	var facing := Basis.looking_at(-front, Vector3.UP)
	attach(root, skeleton, bone, mesh, Transform3D(facing * Basis.from_scale(size), centre))

static func limb(root: Node3D, skeleton: Skeleton3D, bone: String, from: Vector3, to: Vector3, radius: float, mat: Material) -> void:
	if from.distance_to(to) < 0.001: return
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.7
	cylinder.bottom_radius = radius
	cylinder.height = from.distance_to(to)
	cylinder.radial_segments = 12
	mesh.mesh = cylinder
	mesh.material_override = mat
	attach(root, skeleton, bone, mesh, Transform3D(Basis(Quaternion(Vector3.UP, (to - from).normalized())), (from + to) * 0.5))
