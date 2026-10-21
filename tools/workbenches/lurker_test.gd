extends Node3D
## The Lurker coming down a narrow hotel corridor towards you, played: the
## player as in the game (hotel_player.gd: the torch, the zoom, the gait) seen
## through the camcorder (presentation.tscn), in a corridor built here instead
## of a generated floor, so it opens at once. Nothing of the player's profile is
## read or written: the settings are the defaults.
##   godot --path . res://tools/workbenches/lurker_test.tscn
## WASD and the mouse, F the torch, the wheel the zoom, Esc to leave.
##
## Only for looking at it (nothing of the game drives it yet, docs/LURKER.md):
## it comes along the floor, the walls and the ceiling towards you, keeping to
## the dark; caught in the torch it scurries back into the dark; once it is
## close it stares, and backs away fast when you come at it, and comes again.
const SETTINGS := preload("res://game/services/settings_service.gd")
const LOOK := preload("res://game/presentation/camcorder_look.gd")
const CAMERA_EFFECT := preload("res://game/presentation/camera/camcorder_effect.gd")
const BLUR_EFFECT := preload("res://game/presentation/camera/motion_blur_effect.gd")
const PLAYER := preload("res://game/player/player.tscn")
const PRESENTATION := preload("res://game/presentation/presentation.tscn")
const LURKER := preload("res://game/enemies/lurker/lurker.tscn")
const PLASTER := preload("res://game/presentation/materials/plaster.tres")
const PANEL := preload("res://game/presentation/materials/panel.tres")
const TRIM := preload("res://game/presentation/materials/trim.tres")
const CARPET := preload("res://game/presentation/materials/carpet.tres")
const CEILING := preload("res://game/presentation/materials/ceiling.tres")
const BULB := preload("res://game/presentation/materials/light.tres")

## The corridor, along -Z from where you stand: narrow, so it can hold on to
## both walls at once.
const WIDTH := 1.5
const HEIGHT := 2.5
const LENGTH := 22.0
## Ceiling lamps, with dark stretches between; the second one fails now and then.
const LAMPS := [-1.5, -8.0, -15.5]
const FLICKERING := 1
## The round of its corners as it goes from the floor to a wall or the ceiling.
const BEND := 0.35
## How fast it comes, how fast it gets away (the clips' own speeds,
## tools/art/lurker/animate.py SPEEDS) and how fast it moves round the corridor.
const CRAWL := 1.0
const SCURRY := 2.6
const ROUND := 0.7
## Where it stops to stare, and how near you can come before it goes.
const STARE_AT := 2.2
const TOO_NEAR := 1.4
## How long the torch must hold it before it runs.
const CAUGHT := 0.35
## The last metres it comes slower, down a wall to the height of your face.
const CLOSING := 3.5
const FACE_HEIGHT := 1.45

enum Mood { COMING, STARING, FLEEING, WAITING }

class Defaults:
	var values := SETTINGS.DEFAULTS.duplicate()
	var pad_bindings := SETTINGS.PAD_KEYS.duplicate()

var player
var presentation: Node3D
var lens: ShaderMaterial
var lens_zoom := -1.0
var lens_aspect := -1.0
var camcorder
var tape := 0.0
var lurker: Node3D
var flicker: OmniLight3D
var flicker_clock := 0.0
## Where it is: how far down the corridor (z) and where round it (u, metres
## along the outline of the corridor's section, 0 the middle of the floor).
var z := -LENGTH + 1.5
var u := 0.0
var u_goal := 0.0
var mood := Mood.WAITING
var mood_clock := 1.5
var lit_clock := 0.0
var flee_to := 0.0
var closing := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 2610
	bind_keys()
	build_corridor()
	presentation = PRESENTATION.instantiate()
	add_child(presentation)
	setup_camera()
	player = PLAYER.instantiate()
	player.settings = Defaults.new()
	add_child(player)
	player.position = Vector3(0.0, 0.04, -0.6)
	player.camera.current = true
	player.active = true
	camcorder = presentation.get_node("Camcorder")
	camcorder.start_tape(81)
	camcorder.show()
	lurker = LURKER.instantiate()
	add_child(lurker)
	u = perimeter() * 0.5
	u_goal = u
	place()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## The game's controls with their default keys, as the settings would bind them.
func bind_keys() -> void:
	for action in SETTINGS.KEYS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = SETTINGS.KEYS[action]
		InputMap.action_add_event(action, key)
	# looking with a pad's right stick, read every frame (hotel_player.pad_look)
	for action in SETTINGS.LOOK_ACTIONS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action, SETTINGS.STICK_DEADZONE)
		InputMap.action_add_event(action, SETTINGS.stick(SETTINGS.LOOK_ACTIONS[action]))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_tree().quit()


# ---------------------------------------------------------------- the place

func build_corridor() -> void:
	var half := WIDTH * 0.5
	var mid := -LENGTH * 0.5 + 0.25
	var long := LENGTH + 0.5
	slab(Vector3(WIDTH + 0.4, 0.1, long), Vector3(0, -0.05, mid), CARPET)
	slab(Vector3(WIDTH + 0.4, 0.1, long), Vector3(0, HEIGHT + 0.05, mid), CEILING)
	for side in [-1.0, 1.0]:
		slab(Vector3(0.12, HEIGHT, long), Vector3(side * (half + 0.06), HEIGHT * 0.5, mid), PLASTER)
		# wainscot to the waist and its rail, as in the hotel
		slab(Vector3(0.02, 0.9, long), Vector3(side * (half - 0.01), 0.45, mid), PANEL, false)
		slab(Vector3(0.04, 0.05, long), Vector3(side * (half - 0.02), 0.92, mid), TRIM, false)
	slab(Vector3(WIDTH, HEIGHT, 0.12), Vector3(0, HEIGHT * 0.5, 0.31), PLASTER)
	slab(Vector3(WIDTH, HEIGHT, 0.12), Vector3(0, HEIGHT * 0.5, -LENGTH - 0.06), PLASTER)
	for i in LAMPS.size():
		var at := Vector3(0.0, HEIGHT - 0.02, float(LAMPS[i]))
		var bulb := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.16
		disc.bottom_radius = 0.18
		disc.height = 0.04
		bulb.mesh = disc
		bulb.material_override = BULB
		bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bulb.position = at
		add_child(bulb)
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.84, 0.62)
		lamp.light_energy = 1.4
		lamp.omni_range = 5.0
		lamp.omni_attenuation = 1.6
		lamp.shadow_enabled = true
		lamp.position = at + Vector3(0, -0.12, 0)
		add_child(lamp)
		if i == FLICKERING: flicker = lamp


func slab(size: Vector3, at: Vector3, material: Material, solid := true) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	if not solid:
		mesh.position = at
		add_child(mesh)
		return
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var form := BoxShape3D.new()
	form.size = size
	shape.shape = form
	body.add_child(shape)
	body.add_child(mesh)
	body.position = at
	add_child(body)


## The camcorder as the game sets it up (presentation_rig.gd): its HDR stage
## after a little motion blur, the tonemapping that goes with it, and the lens.
func setup_camera() -> void:
	var environment: Environment = presentation.get_node("WorldEnvironment").environment
	if RenderingServer.get_rendering_device() != null:
		var camera_effect := CAMERA_EFFECT.new()
		var blur := BLUR_EFFECT.new()
		var compositor := Compositor.new()
		compositor.compositor_effects = [blur, camera_effect]
		presentation.get_node("WorldEnvironment").compositor = compositor
		environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		environment.tonemap_exposure = 1.0
		environment.glow_hdr_threshold = 0.9
	var defaults: Dictionary = SETTINGS.DEFAULTS
	var analog: ShaderMaterial = presentation.get_node("Analog/Screen").material
	for key in ["vhs", "scanlines", "grain"]: analog.set_shader_parameter(key, defaults[key])
	lens = presentation.get_node("Lens/Screen").material
	lens.set_shader_parameter("noise", defaults.grain)
	lens.set_shader_parameter("chromatic", defaults.chromatic)


## The lens as the zoom stands (presentation_rig.update_zoom_lens).
func update_lens() -> void:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var zoom: float = player.zoom
	if is_equal_approx(zoom, lens_zoom) and is_equal_approx(aspect, lens_aspect): return
	lens_zoom = zoom
	lens_aspect = aspect
	var barrel: float = LOOK.barrel_for(zoom) if LOOK.lens else 0.0
	lens.set_shader_parameter("barrel", barrel)
	lens.set_shader_parameter("scale", LOOK.corner_scale(aspect, barrel))
	player.camera.fov = LOOK.render_fov(aspect, LOOK.zoom_fov(zoom), barrel)


# ---------------------------------------------------------------- round the corridor

## The outline of the corridor's section that its feet follow: the floor, the
## walls and the ceiling, with the corners rounded off.
func perimeter() -> float:
	return 2.0 * (WIDTH - 2.0 * BEND) + 2.0 * (HEIGHT - 2.0 * BEND) + TAU * BEND


## A point of that outline (x, y) and the way it faces into the corridor.
func outline(at: float) -> Array:
	var half := WIDTH * 0.5
	var flat := WIDTH - 2.0 * BEND
	var tall := HEIGHT - 2.0 * BEND
	var arc := PI * 0.5 * BEND
	var s := fposmod(at + flat * 0.5, perimeter())
	# floor (left to right), corner, right wall (up), corner, ceiling (right to
	# left), corner, left wall (down), corner
	var pieces := [
		[flat, Vector2(-half + BEND, 0.0), Vector2(1, 0), Vector2(0, 1)],
		[arc, Vector2(half - BEND, BEND), -PI * 0.5],
		[tall, Vector2(half, BEND), Vector2(0, 1), Vector2(-1, 0)],
		[arc, Vector2(half - BEND, HEIGHT - BEND), 0.0],
		[flat, Vector2(half - BEND, HEIGHT), Vector2(-1, 0), Vector2(0, -1)],
		[arc, Vector2(-half + BEND, HEIGHT - BEND), PI * 0.5],
		[tall, Vector2(-half, HEIGHT - BEND), Vector2(0, -1), Vector2(1, 0)],
		[arc, Vector2(-half + BEND, BEND), PI],
	]
	for piece in pieces:
		var length: float = piece[0]
		if s <= length or piece == pieces[-1]:
			if piece.size() == 4:
				return [piece[1] + piece[2] * s, piece[3]]
			var angle: float = piece[2] + s / BEND
			var out := Vector2(cos(angle), sin(angle))
			return [piece[1] + out * BEND, -out]
		s -= length
	return [Vector2.ZERO, Vector2.UP]


## Where round the corridor it would rather be: the walls high up and the
## ceiling, in the dark, more than the floor.
func pick_spot() -> float:
	var p := perimeter()
	var spots := [0.0, p * 0.3, p * 0.42, p * 0.5, p * 0.58, p * 0.7]
	return spots[rng.randi_range(0, spots.size() - 1)]


## A point on one of the walls (side -1 left, 1 right) at a height.
func on_wall(side: float, height: float) -> float:
	var along := (WIDTH - 2.0 * BEND) * 0.5 + PI * 0.5 * BEND + clampf(height, BEND, HEIGHT - BEND) - BEND
	return along if side > 0.0 else perimeter() - along


func place() -> void:
	var at: Array = outline(u)
	var point: Vector2 = at[0]
	var normal: Vector2 = at[1]
	var up := Vector3(normal.x, normal.y, 0.0)
	# its face to you, always, down the corridor
	var toward := Vector3(0, 0, signf(player.global_position.z - z) if player.global_position.z != z else 1.0)
	var y := up
	var forward := (toward - y * toward.dot(y)).normalized()
	lurker.global_transform = Transform3D(Basis(y.cross(forward), y, forward), Vector3(point.x, point.y, z))
	# on a wall or the ceiling it would rather hold walls and ceiling
	lurker.cling = clampf(1.0 - normal.y, 0.25, 1.0)


# ---------------------------------------------------------------- what it does

func _process(delta: float) -> void:
	update_lens()
	tape += delta
	camcorder.show_tape(tape, delta)
	if flicker:
		flicker_clock -= delta
		if flicker_clock <= 0.0:
			flicker.visible = not flicker.visible or rng.randf() < 0.6
			flicker_clock = rng.randf_range(0.03, 0.14) if not flicker.visible or rng.randf() < 0.3 else rng.randf_range(1.0, 5.0)
	behave(delta)
	place()


func behave(delta: float) -> void:
	var you: float = player.global_position.z
	var gap := absf(you - z)
	var away := -signf(you - z) if you != z else -1.0
	lit_clock = lit_clock + delta if in_torch() else 0.0
	mood_clock -= delta
	match mood:
		Mood.WAITING:
			if mood_clock <= 0.0:
				go(Mood.COMING)
		Mood.COMING:
			if lit_clock > CAUGHT or gap < TOO_NEAR:
				flee(away)
			elif gap <= STARE_AT:
				go(Mood.STARING)
			elif gap <= STARE_AT + CLOSING:
				if not closing:
					closing = true
					u_goal = on_wall(-1.0 if rng.randf() < 0.5 else 1.0, FACE_HEIGHT)
				z += -away * CRAWL * 0.55 * delta
			else:
				z += -away * CRAWL * delta
				if mood_clock <= 0.0:
					u_goal = pick_spot()
					mood_clock = rng.randf_range(2.5, 5.0)
		Mood.STARING:
			if lit_clock > CAUGHT * 3.0 or gap < TOO_NEAR or mood_clock <= 0.0:
				flee(away)
		Mood.FLEEING:
			z += away * SCURRY * delta
			if (z - flee_to) * away >= 0.0 or absf(z) < 0.5 or absf(z + LENGTH) < 0.6:
				z = clampf(z, -LENGTH + 0.6, -0.5)
				go(Mood.WAITING)
	z = clampf(z, -LENGTH + 0.6, -0.5)
	# round the corridor to where it wants to be, the short way
	var p := perimeter()
	var turn := wrapf(u_goal - u, -p * 0.5, p * 0.5)
	u = fposmod(u + clampf(turn, -ROUND * delta, ROUND * delta), p)


func go(next: Mood) -> void:
	mood = next
	match next:
		Mood.WAITING:
			mood_clock = rng.randf_range(1.5, 3.5)
			lurker.play("idle", 0.3)
		Mood.COMING:
			mood_clock = 0.0
			closing = false
			lurker.play("crawl", 0.3)
		Mood.STARING:
			mood_clock = rng.randf_range(2.5, 4.5)
			lurker.play("idle", 0.4)


## Back into the dark: some metres away, or the far end of the corridor. With
## its back to the end wall it goes the other way instead, over your head
## along the ceiling.
func flee(away: float) -> void:
	mood = Mood.FLEEING
	flee_to = clampf(z + away * rng.randf_range(5.0, 9.0), -LENGTH + 0.6, -0.5)
	u_goal = pick_spot()
	if absf(flee_to - z) < 1.0:
		flee_to = -0.5 if away < 0.0 else -LENGTH + 0.6
		u_goal = perimeter() * 0.5
	lurker.play("crawl_fast", 0.15)


## Whether the torch is on it and reaches it.
func in_torch() -> bool:
	var torch: SpotLight3D = player.torch
	if not torch.visible: return false
	var body: Vector3 = lurker.global_transform * Vector3(0, 0.3, 0)
	var to := body - torch.global_position
	if to.length() > torch.spot_range: return false
	if rad_to_deg((-torch.global_basis.z).angle_to(to)) > torch.spot_angle: return false
	var query := PhysicsRayQueryParameters3D.create(torch.global_position, body)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
