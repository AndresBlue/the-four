extends Node3D
## Background of the main menu: an ordinary, lamp-lit hotel room seen from a
## slowly drifting handheld camera. At the back, off to the side of the
## picture, the door to the corridor stands ajar and The Locust leans into the
## gap from behind the frame, long arm hanging, head cocked, watching. It
## is dark and small in the shot, easy to miss until it is noticed.
## Built far from the hotel plan; runs while the tree is paused.
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const LOOK := preload("res://game/enemies/locust/locust_look.gd")
const POSER := preload("res://game/enemies/locust/locust_poser.gd")
## The camcorder lens remaps the picture: the camera renders a little wider.
const CAMCORDER := preload("res://game/presentation/camcorder_look.gd")

const MODEL := preload("res://assets/enemies/locust.glb")
const HEIGHT := 2.9
## Room x -3.2..3.2, z -3.6..3.6; the corridor runs behind the back wall,
## x -3.2..6.0, z -6.0..-3.6. The doorway is in the back wall, right of centre.
const DOORWAY := Vector3(1.7, 0.0, -3.6)
## Where it stands in the corridor, hidden by the wall left of the doorway.
## The door is hinged on the right and only ajar: from the camera the gap
## between its edge and the left jamb shows just the face.
const LOCUST_AT := Vector3(0.99, 0.0, -3.95)
## How far the door stands open, in radians.
const AJAR := 0.44
const CAMERA_AT := Vector3(-2.3, 1.5, 1.5)
const LOOK_AT := Vector3(-1.0, 1.35, -3.6)
var builder: Node3D
var camera: Camera3D
var locust: Node3D
var poser
var clock := 0.0
var twitch_clock := 7.0
var twitch := 0.0
var twitch_sign := 1.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.seed = 2204
	builder = GEOMETRY.new()
	builder.name = "Set"
	builder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(builder)
	build_room()
	build_lights()
	builder.flush()
	# Room numbers only show where light falls on them.
	for label in builder.find_children("*", "Label3D", true, false): label.shaded = true
	locust = MODEL.instantiate()
	locust.name = "Locust"
	locust.scale = Vector3.ONE * 1.95
	locust.position = LOCUST_AT
	add_child(locust)
	LOOK.apply(locust)
	poser = POSER.new(locust)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 58.0
	camera.near = 0.05
	add_child(camera)
	update_scene(0.0)

func build_room() -> void:
	for rect in [Rect2(-3.2, -3.6, 6.4, 7.2), Rect2(-3.2, -6.0, 9.2, 2.4)]:
		var centre := Vector3(rect.get_center().x, 0, rect.get_center().y)
		builder.box(builder, centre + Vector3(0, -0.15, 0), Vector3(rect.size.x + 0.2, 0.3, rect.size.y + 0.2), "carpet")
		builder.box(builder, centre + Vector3(0, HEIGHT + 0.1, 0), Vector3(rect.size.x + 0.2, 0.2, rect.size.y + 0.2), "ceiling")
	builder.set_wall(Vector2(-3.2, -3.6), Vector2(3.2, -3.6), [DOORWAY.x + 3.2])
	builder.set_wall(Vector2(3.2, -3.6), Vector2(6.0, -3.6), [])
	builder.set_wall(Vector2(-3.2, 3.6), Vector2(3.2, 3.6), [])
	builder.set_wall(Vector2(-3.2, -6.0), Vector2(-3.2, 3.6), [])
	builder.set_wall(Vector2(3.2, -3.6), Vector2(3.2, 3.6), [])
	builder.set_wall(Vector2(6.0, -6.0), Vector2(6.0, -3.6), [])
	builder.set_wall(Vector2(-3.2, -6.0), Vector2(6.0, -6.0), [4.2])
	# The door stands wide open into the room, hinged on the left and back
	# against the wall, so nothing hides the gap.
	var leaf: Node3D = builder.set_door(DOORWAY, "214", PI / 2)
	# Hinged like a real door, on the right jamb at the room face, and only
	# ajar into the room: just enough of a gap to be seen through.
	leaf.position = DOORWAY + Vector3(FLOOR.PORTAL * 0.5, 0.0, 0.225)
	leaf.rotation.y = PI / 2 + AJAR
	builder.set_door(Vector3(1.0, 0.0, -6.0), "", PI / 2)
	# A made bed against the back wall, with a nightstand and a floor lamp.
	var bed := MeshInstance3D.new()
	bed.mesh = load("res://assets/props/bedroom/bed.res")
	bed.position = Vector3(-1.0, 0.0, -2.45)
	builder.add_child(bed)
	place("nightstand", Vector3(-0.8, 0, -3.1), 0.0)
	place("lamp", Vector3(-2.75, 0, -3.15), 0.0)
	place("desk", Vector3(2.55, 0, 1.2), -PI / 2)
	place("curtain", Vector3(-3.05, 0, 1.2), PI / 2)
	place("luggage", Vector3(1.4, 0, -0.6), 0.4)
	# A print over the bed.
	builder.box(builder, Vector3(-1.7, 1.95, -3.47), Vector3(1.2, 0.85, 0.06), "gold")
	builder.box(builder, Vector3(-1.7, 1.95, -3.43), Vector3(1.06, 0.71, 0.02), "painting")

func place(kind: String, point: Vector3, yaw: float) -> void:
	var prop := Node3D.new()
	prop.position = point
	prop.rotation.y = yaw
	builder.add_child(prop)
	builder.build_prop(prop, kind)

func build_lights() -> void:
	# Warm ceiling dome over the room.
	var dome := OmniLight3D.new()
	dome.position = Vector3(-0.4, HEIGHT - 0.45, -0.2)
	dome.light_color = Color("ffcf94")
	dome.light_energy = 2.3
	dome.omni_range = 7.5
	dome.omni_attenuation = 1.25
	dome.shadow_enabled = true
	add_child(dome)
	builder.cylinder(builder, Vector3(-0.4, HEIGHT - 0.03, -0.2), 0.26, 0.06, "gold")
	builder.box(builder, Vector3(-0.4, HEIGHT - 0.13, -0.2), Vector3(0.46, 0.16, 0.46), "light", false, "cone", Vector3(PI, 0, 0))
	# The corridor is dark but for a faint cold night light far down it.
	var night := OmniLight3D.new()
	night.position = Vector3(-2.4, 2.5, -4.8)
	night.light_color = Color(0.55, 0.62, 0.75)
	night.light_energy = 0.12
	night.omni_range = 4.5
	add_child(night)
	# Spill from the room just catching the pale face in the gap.
	var spill := OmniLight3D.new()
	spill.name = "Spill"
	spill.position = Vector3(0.9, 1.9, -2.3)
	spill.light_color = Color("ffc58a")
	spill.light_energy = 0.55
	spill.omni_range = 2.8
	spill.omni_attenuation = 1.6
	add_child(spill)

func _process(delta: float) -> void:
	if visible: update_scene(delta)

func update_scene(delta: float) -> void:
	clock += delta
	# Handheld drift, slow enough to read as someone breathing behind the camera.
	camera.fov = CAMCORDER.fov_for(get_viewport(), 58.0)
	camera.position = CAMERA_AT + Vector3(sin(clock * 0.11) * 0.05, sin(clock * 0.23) * 0.015, sin(clock * 0.07) * 0.04)
	camera.look_at(global_transform * (LOOK_AT + Vector3(sin(clock * 0.05) * 0.35, sin(clock * 0.09) * 0.08, 0.0)))
	camera.rotation.z += sin(clock * 0.13) * 0.006
	pose_locust(delta)

## Leaning into the gap and back a little, with the odd sudden tilt of the head.
func pose_locust(delta: float) -> void:
	twitch_clock -= delta
	if twitch_clock <= 0.0:
		twitch_clock = rng.randf_range(6.0, 14.0)
		twitch = 1.0
		twitch_sign = 1.0 if rng.randf() < 0.5 else -1.0
	twitch = maxf(0.0, twitch - delta * 5.0)
	var lean := 0.36 + sin(clock * 0.21) * 0.04 + sin(clock * 0.077) * 0.03
	poser.reset()
	# Leans right (+X) from behind the left jamb into the gap.
	poser.turn("Spine", Vector3(0, 0, 1), -lean)
	poser.turn("Spine2", Vector3(0, 0, 1), -lean)
	poser.turn("Spine2", Vector3(1, 0, 0), 0.15)
	poser.turn("Spine4", Vector3(0, 0, 1), -lean * 0.5)
	# Looks out of the gap towards the camera, head cocked hard.
	poser.turn("Neck1", Vector3(0, 1, 0), -0.35)
	poser.turn("Neck1", Vector3(0, 0, 1), lean * 0.4)
	poser.turn("Head1", Vector3(0, 0, 1), 0.5 + twitch * twitch_sign * 0.14 + sin(clock * 0.6) * 0.02)
	poser.turn("Head1", Vector3(1, 0, 0), 0.15)
	# The long arms hang straight down, the near one showing in the gap.
	poser.aim("L_UpperArm", "L_Forearm", Vector3(0.08, -1.0, 0.12))
	poser.aim("L_Forearm", "L_Hand", Vector3(-0.02, -1.0, 0.2))
	poser.aim("R_UpperArm", "R_Forearm", Vector3(-0.15, -1.0, 0.0))
	poser.aim("R_Forearm", "R_Hand", Vector3(-0.05, -1.0, 0.1))

## Menu on: this camera takes over. Off: hidden and idle.
func set_active(active: bool) -> void:
	visible = active
	if active: camera.current = true
	elif camera.current: camera.current = false
