extends Area3D
## A television of a stage: dead until somebody switches it on, and then it
## stays on. Each stage from the second on has its own sets, in its own wing,
## counted apart -- `stage` says which ones these are.
##
## The set itself is the room's own prop, built into the
## batched geometry; this node is the interaction target and the parts that
## have to change at runtime -- the lit screen and the light it throws into the
## room -- which cannot live in a MultiMesh.
##
## Switching one on is not free: the click carries, so the creature knows
## where somebody has just been.
signal switched(on: bool)
const NOISE := preload("res://game/audio/noise_kinds.gd")
## Where the screen sits inside the set (prop_factory's "tv" recipe).
const SCREEN := Vector3(-0.1, 1.44, 0.24)
const SCREEN_SIZE := Vector2(0.78, 0.6)
## Light of a channel with nothing on it: cold, close, and it does not reach
## through the walls.
const GLOW := Color(0.72, 0.82, 1.0)
const RANGE := 7.0
var on := false
## The stage this set belongs to (2 or 3): the wing it stands in.
var stage := 2
var screen: MeshInstance3D
var lamp: OmniLight3D
var flicker := 0.0
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
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 1.1, 0.9)
	shape.shape = box
	shape.position = Vector3(0, 1.3, 0)
	add_child(shape)
	var quad := QuadMesh.new()
	quad.size = SCREEN_SIZE
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(0.55, 0.62, 0.72)
	lit.emission_enabled = true
	lit.emission = GLOW
	lit.emission_energy_multiplier = 2.4
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen = MeshInstance3D.new()
	screen.name = "Lit"
	screen.mesh = quad
	screen.material_override = lit
	screen.position = SCREEN
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	screen.visible = false
	add_child(screen)
	lamp = OmniLight3D.new()
	lamp.name = "Glow"
	lamp.position = SCREEN + Vector3(0, 0, 0.35)
	lamp.light_color = GLOW
	lamp.light_energy = 1.6
	lamp.omni_range = RANGE
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.04
	lamp.light_volumetric_fog_energy = 0.0
	lamp.visible = false
	add_child(lamp)

## Turned on by a player, or by the state arriving from the host. Returns
## whether this changed anything, so the caller can make the noise once.
func set_on(value: bool) -> bool:
	if on == value: return false
	on = value
	screen.visible = value
	lamp.visible = value
	switched.emit(value)
	return true

## The noise a set makes when it comes to life, for the creature: as far as a
## door opening slowly, enough to say somebody is in this wing. (What people
## hear is its static, which carries like any other sound.)
func click_radius() -> float: return NOISE.radius("door_slow")

func _process(delta: float) -> void:
	if not on: return
	# A dead channel never sits still: the light breathes and stutters.
	flicker = fposmod(flicker + delta, 100.0)
	var wave := 0.86 + 0.14 * sin(flicker * 9.7) + (0.16 if fposmod(flicker, 1.7) < 0.06 else 0.0)
	lamp.light_energy = 1.6 * wave
	screen.material_override.emission_energy_multiplier = 2.4 * wave
