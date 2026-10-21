extends Node3D
## The Lurker as it is seen (docs/LURKER.md): the model, its hands on whatever
## is near (lurker_limbs.gd), and the darkness it carries. Its body is black
## and takes no light at all (lurker_body.tres); round it a dense black fog
## with no edge (lurker_darkness.gdshader), and round that a wide, thin one
## that dims whatever is behind it for a couple of metres, so the walls near
## it go dark too and the body runs into the dark behind it. Only the face is
## left to be seen. (A negative light did the dimming at first: the camera's
## filters broke up on the negative values it left, in coloured specks.)
##
## Presentation only: whoever moves it sets its transform (its up is the
## surface it clings to, its +Z the way it faces) and `velocity`.
const LIMBS := preload("res://game/enemies/lurker/lurker_limbs.gd")
const DARKNESS := preload("res://game/enemies/lurker/lurker_darkness.gdshader")
## Render layer 3, its own. (Layer 2 is the player's own body; 5 to 20 are
## rooms at the lowest preset, room_layers.gd.)
const LAYER := 4
const CLOUD := 0.62
const GLOOM := 2.1
signal footfall(point: Vector3, strength: float)

## The hands plant themselves on what is near; off, the clip moves the arms.
@export var crawling := true: set = set_crawling
## How dark it makes its surroundings (the wide fog's density).
@export var gloom := 0.5
var velocity := Vector3.ZERO
var skeleton: Skeleton3D
var animator: AnimationPlayer
var limbs: SkeletonModifier3D
var darkness: MeshInstance3D
var shroud: MeshInstance3D
var body_bone := -1
var head_bone := -1
var last_position := Vector3.INF


func _ready() -> void:
	var model := get_node("Model")
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	animator = model.find_children("*", "AnimationPlayer", true, false)[0]
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = LAYER
	body_bone = skeleton.find_bone("body")
	head_bone = skeleton.find_bone("head")
	limbs = LIMBS.new()
	limbs.name = "Limbs"
	limbs.footfall.connect(func(point, strength): footfall.emit(point, strength))
	skeleton.add_child(limbs)
	limbs.active = crawling
	darkness = fog("Darkness", CLOUD, 7.0, 0.17, 1.0)
	shroud = fog("Gloom", GLOOM, gloom, 0.0, 0.0)
	animator.play("idle")


func fog(name_: String, radius: float, density: float, face_clear: float, churn: float) -> MeshInstance3D:
	var cloud := MeshInstance3D.new()
	cloud.name = name_
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	cloud.mesh = sphere
	var material := ShaderMaterial.new()
	material.shader = DARKNESS
	material.set_shader_parameter("radius", radius)
	material.set_shader_parameter("density", density)
	material.set_shader_parameter("face_clear", face_clear)
	material.set_shader_parameter("churn", churn)
	cloud.material_override = material
	cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud.layers = LAYER
	add_child(cloud)
	return cloud


func set_crawling(value: bool) -> void:
	crawling = value
	if limbs: limbs.active = value


## Plays one of the model's clips (idle, loom, scare, peek...).
func play(clip: String, blend := 0.2) -> void:
	animator.play(clip, blend)


func _process(delta: float) -> void:
	if delta > 0.0 and last_position != Vector3.INF and velocity == Vector3.ZERO:
		limbs.velocity = (global_position - last_position) / delta
	else:
		limbs.velocity = velocity
	last_position = global_position
	var xf := skeleton.global_transform
	var body := skeleton.get_bone_global_pose(body_bone)
	var centre := xf * (body * Vector3(0.0, 0.14, 0.0))
	var head := xf * (skeleton.get_bone_global_pose(head_bone) * Vector3(0.0, 0.06, 0.1))
	darkness.global_position = centre
	shroud.global_position = centre
	(darkness.material_override as ShaderMaterial).set_shader_parameter("face", head)
	(shroud.material_override as ShaderMaterial).set_shader_parameter("density", gloom)
