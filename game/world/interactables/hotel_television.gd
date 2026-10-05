extends Area3D
## A television of a stage: dead until somebody switches it on, and then it
## stays on. Each stage from the second on has its own sets, in its own wing,
## counted apart -- `stage` says which ones these are.
##
## The set itself is the room's own prop, built into the
## batched geometry: the trailer's CRT on a gothic commode, its glass dark
## (prop_factory's "tv" recipe). This node is the interaction target and the
## parts that have to change at runtime -- the channel on the glass and the
## light it throws into the room -- which cannot live in a MultiMesh.
##
## Switching one on is not free: the click carries, so the creature knows
## where somebody has just been.
signal switched(on: bool)
const NOISE := preload("res://game/audio/noise_kinds.gd")
const PROPS := preload("res://game/world/hotel/prop_factory.gd")
## The opening scene's CRT shader, showing its dead channel.
const CRT := preload("res://game/intro/tv_screen.gdshader")
## Where the screen sits inside the set: the front of the middle of the tube's
## face, on the commode, and how big that face is (prop_factory.tv_transform()
## and the model's screen; stages_test checks they agree).
const SCREEN := Vector3(-0.009, 1.672, 0.396)
const SCREEN_SIZE := Vector2(0.563, 0.422)
## The channel is drawn this far out from the glass (in the model's own
## units): over it, never into it.
const OVER_GLASS := 0.003
## Light of a channel with nothing on it: cold, thrown forward from the glass
## in a wide cone (not so wide that it floods the ceiling), and a fainter fill
## all round that shows the commode and the floor about it. Both cast
## shadows, so neither reaches through a wall: the cone in one pass, the fill
## in two (dual paraboloid) -- fewer than the six of the shadowed omni light
## the old set had.
const GLOW := Color(0.72, 0.82, 1.0)
const RANGE := 8.0
const CONE := 55.0
const TILT := -0.3
const ENERGY := 2.2
const FILL_RANGE := 4.5
const FILL := 0.5
## How bright the snow is, and how long the set takes to come on: the line
## across the middle opening out into the picture.
const BRIGHTNESS := 1.1
const OPEN_TIME := 0.4
var on := false
## The stage this set belongs to (2 or 3): the wing it stands in.
var stage := 2
var screen: MeshInstance3D
var channel: ShaderMaterial
var lamp: SpotLight3D
var fill: OmniLight3D
var flicker := 0.0
## 0 just switched on, 1 open.
var opening := 1.0
## What it sounds like (hotel_main.apply_television): the burst of dead
## channel it comes on with, while that lasts, and from this moment on (in
## Time.get_ticks_msec() seconds) the soft hiss world_audio gives lit sets.
var burst: AudioStreamPlayer3D
var hiss_after := 0.0

## Where the sound and the glow come from: the middle of the screen.
func screen_point() -> Vector3:
	return to_global(SCREEN)

func _ready() -> void:
	add_to_group("hotel_televisions")
	collision_layer = 16
	collision_mask = 0
	# The set and the top of the commode under it: aiming at either is aiming
	# at the television.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.25, 1.2, 0.95)
	shape.shape = box
	shape.position = Vector3(0, 1.45, 0)
	add_child(shape)
	channel = ShaderMaterial.new()
	channel.shader = CRT
	channel.set_shader_parameter("image_amount", 0.0)
	channel.set_shader_parameter("tint_blue", 0.35)
	channel.set_shader_parameter("brightness", BRIGHTNESS)
	screen = MeshInstance3D.new()
	screen.name = "Lit"
	screen.mesh = PROPS.TV_SCREEN
	screen.material_override = channel
	screen.transform = PROPS.tv_transform().translated_local(Vector3(0, 0, OVER_GLASS))
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.visible = false
	add_child(screen)
	lamp = SpotLight3D.new()
	lamp.name = "Glow"
	# A hand in front of the glass, looking out and down: a pool of light on
	# the floor in front of the set more than a wash over the ceiling.
	lamp.position = SCREEN + Vector3(0, 0, 0.3)
	lamp.rotation = Vector3(TILT, PI, 0)
	lamp.light_color = GLOW
	lamp.light_energy = ENERGY
	lamp.spot_range = RANGE
	lamp.spot_angle = CONE
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.04
	lamp.light_volumetric_fog_energy = 0.0
	lamp.visible = false
	add_child(lamp)
	fill = OmniLight3D.new()
	fill.name = "Fill"
	# Low and out in front of the set: from up against the glass, the set's
	# own overhang shaded the commode under it.
	fill.position = SCREEN + Vector3(0, -0.2, 0.35)
	fill.light_color = GLOW
	fill.light_energy = FILL
	fill.omni_range = FILL_RANGE
	fill.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	fill.shadow_enabled = true
	fill.shadow_bias = 0.04
	fill.light_volumetric_fog_energy = 0.0
	fill.light_specular = 0.2
	fill.visible = false
	add_child(fill)

## Turned on by a player, or by the state arriving from the host. Returns
## whether this changed anything, so the caller can make the noise once.
func set_on(value: bool) -> bool:
	if on == value: return false
	on = value
	opening = 0.0
	screen.visible = value
	lamp.visible = value
	fill.visible = value
	glow(0.0)
	switched.emit(value)
	return true

## The noise a set makes when it comes to life, for the creature: as far as a
## door opening slowly, enough to say somebody is in this wing. (What people
## hear is its static, which carries like any other sound.)
func click_radius() -> float: return NOISE.radius("door_slow")

func _process(delta: float) -> void:
	if not on: return
	opening = minf(1.0, opening + delta / OPEN_TIME)
	# A dead channel never sits still: the light breathes and stutters.
	flicker = fposmod(flicker + delta, 100.0)
	glow(0.86 + 0.14 * sin(flicker * 9.7) + (0.16 if fposmod(flicker, 1.7) < 0.06 else 0.0))

## The picture and the light at `wave` of their strength, as far as the set
## has come on.
func glow(wave: float) -> void:
	var up := smoothstep(0.0, 1.0, opening)
	channel.set_shader_parameter("open", opening)
	channel.set_shader_parameter("brightness", BRIGHTNESS * wave)
	lamp.light_energy = ENERGY * wave * up
	fill.light_energy = FILL * wave * up
