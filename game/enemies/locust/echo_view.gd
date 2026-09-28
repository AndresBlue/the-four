extends Node
## The Locust's eyes, for the player who drives it. It does not see the hotel:
## it clicks, and rebuilds the hotel from what comes back, mixed with the
## sounds the survivors are making. Three readings, one image:
##
##   the dark    a screen pass that replaces the lit hotel with black. It draws
##               nothing with a shape: a picture computed from the live depth
##               buffer is the geometry with its textures off, and it moves
##               whenever anything moves
##   the grains  every shape there is. Points stamped in the world when a click
##               reaches them and frozen until the next one: walls, the surface
##               of a body, the puff a noise leaves hanging, what the shriek
##               found, and the doors it simply knows
##   the self    its own body, the one thing it knows without listening
##
## The reading refreshes on the click, twice a second, with an organic cadence.
## The picture itself is redrawn every frame from wherever the camera is, so
## moving is smooth and nothing warps: what pulses is the information, not the
## framerate, and nothing that has a shape is computed from the live frame.
##
## Presentation only. It never changes what the creature perceives: bodies are
## gated on creature.sees(), and noises on what the machine in charge already
## decided the creature can hear (hotel_locust.hear_route).
const FIELD_SHADER := preload("res://game/enemies/locust/shaders/echo_field.gdshader")
const POINT_SHADER := preload("res://game/enemies/locust/shaders/echo_points.gdshader")
const SELF_SHADER := preload("res://game/enemies/locust/shaders/echo_self.gdshader")
const BODY := preload("res://game/enemies/locust/echo_body.gd")
const KINDS := preload("res://game/audio/noise_kinds.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const HIDE := preload("res://game/world/interactables/hiding_place.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")

## Nominal clicks per second: the rate the reading refreshes at. Slow on
## purpose. A fast click makes a busy, almost psychedelic picture; at two per
## second each sweep is an event you wait for, and what fills the time between
## them is the memory of the last one going out.
const CLICK_RATE := 2.0
## Never a metronome: each interval is stretched or squeezed and breathes
## slowly underneath. It does NOT speed up while hunting, whatever the creature
## is doing with its legs: a reading that quickens when you run reads as your
## own footsteps coming back, which is not what this is.
const CLICK_JITTER := 0.22
const BREATH_RATE := 0.14
const BREATH_DEPTH := 0.25
## Slow enough to watch a front cross a room and back: a shell takes about two
## and a half seconds to reach the end of its hearing, so five or six of them
## are always in flight at different radii.
const WAVE_SPEED := 16.0
## Useful range. Under world_audio.ROUTE_LIMIT (42) and far under the 66 m at
## which update_visibility hides rooms, so no wall it should show is missing.
const REACH := 40.0
## Longest a remembered point lives; the real limit follows the ring buffer.
const MEMORY := 9.0
## Rays per click, points remembered, body points and every other count below
## come from the graphics preset (graphics_presets.gd "echo", in budget). The
## budget per click is large because there are thirty physics frames to spread
## it over: the cost per frame is the same as a fast click would be, and what
## you get for it is a scene made of points.
## Bodies are sampled on every click and fade just past the next one: a
## survivor is a live reading, never a memory to be followed.
const BODY_EVERY := 1
const BODY_FADE := 0.75
## Most of the rays go into a wide cone ahead and the rest over the whole
## sphere: what it looks at is what it describes, but a room it has walked
## through keeps its shape behind it too.
const FORWARD_BIAS := 0.62
const FORWARD_CONE := 1.0
## A heard noise hangs as a puff of grains where it was heard, blooming outward
## from the spot at this speed and out to this radius before it goes.
const PUFF_SPEED := 4.5
const PUFF_LIFE := 2.2
## Grains per surface sample when a close noise brings a body's shape with it.
const NOISE_SHAPE := 3
## How much each kind of noise shows, by noise_kinds.gd Kind: grains (times
## budget.puff_points) and size (times the spread). A step leaves a light trail and a
## run a heavy one; a door is a burst it cannot miss, and stays. A wardrobe is
## as loud as a door, but its cloud goes out sooner: the survivor gets that
## much of an edge for hiding. PUFF_LIVES is each kind's life in seconds,
## carried by every grain (write_life) so one cloud can hold all of them.
##                     step  run  jump door slam wardrobe peek hum
const PUFF_DENSITY := [1.5, 3.4, 2.0, 6.0, 7.0, 6.0, 2.0, 1.0]
const PUFF_SIZE := [1.15, 1.45, 1.2, 1.35, 1.5, 1.35, 1.0, 1.0]
const PUFF_LIVES := [2.2, 2.2, 2.2, 4.0, 4.0, 2.5, 2.2, 2.2]
## Doors and wardrobes gather round the spot the sound came from, a gaussian
## of this share of the radius (clipped at 1.6 radii), instead of filling an
## even ball: a bright core with a thin halo is what reads from rooms away.
const PUFF_BELLS := [KINDS.Kind.DOOR, KINDS.Kind.SLAM, KINDS.Kind.WARDROBE, KINDS.Kind.PEEK]
const PUFF_BELL := 0.22
## Sound grains outshine the room and the reflectors, and are a little coarser.
const PUFF_GAIN := 1.8
const PUFF_PIXELS := 3.2
const PUFF_WHITE := 2.2
const PUFF_TWINKLE := 0.7
## A far noise hangs in the opening it came through, which is also where a
## doorway's reflector grains are brightest. Stood this far out of it, towards
## the listener, it is a cloud in the air instead of a busier door frame.
const PUFF_STAND_OFF := 1.1
## The core of a bell shines brighter than its halo: energy times one plus
## this, falling off with the same gaussian.
const PUFF_CORE_GAIN := 2.5
## A far noise hangs vaguer and wider (blur), but only a little: spread over
## a room-sized ball, a run heard from afar hung a sparse cloud twelve metres
## across round the creature with nobody in it, which read as a phantom (or
## as leftovers from the last match). And no puff ever gets wider than
## PUFF_MAX_RADIUS, however loud: a sound is a place, not a room.
const PUFF_BLUR := 0.4
const BELL_BLUR := 0.35
const PUFF_MAX_RADIUS := 1.8
## Heard only by the way it came in, a step or a run is "something over
## there", not a thing: every stride renews the same cloud in the same
## opening, and a full-sized one read as a solid object standing there for
## as long as somebody kept running out of sight. So it shrinks to this
## radius and keeps this share of its grains at full blur. Doors and
## wardrobes keep their bright core: those have to read from afar.
const FAR_STEP_RADIUS := 0.9
const FAR_STEP_GRAINS := 0.45
## A wardrobe's cloud hangs in front of its doors at chest height: centred on
## the wardrobe itself, half of it would sit inside the cabinet or under the
## floor, hidden by the very thing that made the noise.
const WARDROBE_PUFF_OUT := 0.55
const WARDROBE_PUFF_UP := 1.15
## What the shriek found stays marked well after the cry has died away, so it
## is worth something beyond turning the picture red.
const FIND_LIFE := 3.2
## How long a contact is worth marking at all.
const CONTACT_LIFE := 1.6
## Its own shriek floods the reading red, then drains.
const SHRIEK_HOLD := 4.0
const SHRIEK_RISE := 6.0
const SHRIEK_FALL := 0.55
## Doors and wardrobes it simply knows are there, faded out by this distance.
const LANDMARK_NEAR := 14.0
const LANDMARK_REACH := 28.0
const LANDMARK_LEVEL := 0.16
## Grains up each jamb and across each lintel. A doorway is what it navigates
## by, so its frame is crowded on purpose.
const JAMB_GRAINS := 22
const LINTEL_GRAINS := 13
## Clear height of a hotel doorway (hotel_geometry builds the lintel at 2.65).
const DOORWAY_HIGH := 2.6
## A point's radius on screen, in pixels of the rendered image. Small: the
## picture should be made of grains, and grains that touch are a surface.
const POINT_PIXELS := 2.0
## Residual level between clicks. Low on purpose: raise it and the creature
## simply sees, and the whole thing stops being echolocation.
## The faintest hint that something solid is out there. Near nothing on
## purpose: raise it and the room starts being drawn instead of clicked at.
const PRESENCE := 0.006
const PRESENCE_CALM := 0.016
## Walls, doors and swinging leaves: what an echo comes back from.
const RAY_MASK := 1 | 8 | 64
## Strong reflectors. A door frame and a wardrobe are hard edges and big flat
## faces, which in real echolocation are what answers loudest, and they are
## what it needs to find while it hunts. So each click spends a budget of its
## own on rays aimed straight at them, on top of the general spray. A ray that
## lands within INTEREST_HIT of the spot it was aimed at found it in plain
## sight; anything else was in the way and the ray is dropped, so a frame
## behind a wall never answers.
const INTEREST_HIT := 0.25
## Grains laid for each reflector hit: two, so a frame reads crowded.
const INTEREST_GRAINS := 2
## Where the reflector grains live, how long, and how big they read.
const FRAME_MEMORY := 5.0
const FRAME_PIXELS := 2.6
## Aimed spots on a doorway per click: up the end of each wall, on the strip
## of wall round the frame (each side, each face), under the soffit and on the
## band above it (each face), and across the opening when a door shuts it.
## They are drawn at random over each surface every click, never from a fixed
## grid: a grid hit click after click piles its grains into neat clumps that
## read as a matrix of big dots instead of a lit surface.
const REVEAL_SPOTS := 24
const BAND_SPOTS := 12
const SOFFIT_SPOTS := 8
const HEADER_SPOTS := 8
const PANEL_SPOTS := 40
## Aimed spots on the front of a wardrobe, which is a block, not an outline.
const WARDROBE_SPOTS := 112
## Its own hearing already knows where the lamps are humming.
const HUM_LEVEL := 0.13

var creature
var driver
var level
var camera: Camera3D
## Seconds since this view opened. Its own clock, not TIME: it keeps float
## precision, freezes with the tree, and the tests can reproduce every value.
var clock := 0.0
var next_click := 0.0
var clicks := 0
## The interval the last click chose, for the regression's cadence check.
var last_interval := 0.0
var enabled := false
var quality := 1
## The preset's echo counts (graphics_presets.gd): rays, aimed, points,
## bodies, puff_points, puffs, find_points, finds, frames, grain.
var budget: Dictionary = PRESETS.PRESETS[PRESETS.MEDIUM].echo
var calm := false

var field: MeshInstance3D
var field_material: ShaderMaterial
var clouds: Node3D
var walls: MultiMeshInstance3D
var bodies: MultiMeshInstance3D
var puffs: MultiMeshInstance3D
var finds: MultiMeshInstance3D
var frames: MultiMeshInstance3D
var frame_material: ShaderMaterial
var marks: MultiMeshInstance3D
## The motes: a handful of red grains over everybody whose mind has gone out,
## laid again on every click so they never fade while it lasts. Their
## material is never told the time (push_uniforms), so a grain never ages:
## only the cloud's visible_instance_count, set by the last laying, ends it.
const MOTE_GRAINS := 10
const MOTE_BODIES := 5
const MOTE_SPREAD := 0.38
var motes: MultiMeshInstance3D
var mote_material: ShaderMaterial
var mote_at := 0
## Guides: what the floor lays out for it in coloured grains, through
## everything and at any distance (the cloud is fully "through", like the
## motes). Blue is the way to the lift while the survivors have gone on and it
## has not; yellow, the lit sets it can travel through, and the way to the
## nearest one when it asks for it (locust_player.trace). All of it is laid
## again on every click from where it stands, and it is the same on every
## preset: the quality of the picture never gives it more to go on.
const GUIDE_GRAINS := 2400
## Grains every this many metres of route, on the floor.
const GUIDE_STEP := 0.35
const GUIDE_PER_STEP := 3
const GUIDE_HEIGHT := 0.08
const GUIDE_SCATTER := 0.06
## Each laying sends a front down the route from the creature to its end, so
## the line runs the way to go, like the racing line of a driving game.
const GUIDE_FLOW := 9.0
## Where a route ends, a column of grains that reads from afar; while the car
## is away it beats, bright one click and dim the next, until it is back down.
const GUIDE_END_GRAINS := 24
## Strong but not blinding: past about one and a half the tonemapper takes a
## saturated grain to white (at three, the first version, blue read as white).
const GUIDE_BLUE := Color(0.02, 0.22, 1.6)
const GUIDE_YELLOW := Color(1.5, 1.05, 0.03)
## Grains over each lit set's screen, round it, and in a thin column over it,
## the way the end of a route stands up: a set has to read from anywhere on
## the floor, and a screen-sized patch alone was a speck from a room away.
const SCREEN_GRAINS := 48
const SCREEN_HALO := 16
const SCREEN_BEACON := 14
var guides: MultiMeshInstance3D
var guide_material: ShaderMaterial
## What the last laying put down: grains in all, and route points and screens,
## for the regression (instance data cannot be read back without a GPU).
var guide_count := 0
var guide_routes := {"lift": 0, "trace": 0, "screens": 0}
var wall_material: ShaderMaterial
var body_material: ShaderMaterial
var puff_material: ShaderMaterial
var find_material: ShaderMaterial
var mark_material: ShaderMaterial
var self_material: ShaderMaterial

## Ring buffer write positions and how many points each cloud has ever shown.
var wall_at := 0
var wall_shown := 0
var body_at := 0
var body_shown := 0
var puff_at := 0
var find_at := 0
## Grains the shriek has left on this view since it opened. find_at is a ring
## index and comes back round to 0, so it cannot say whether anything was.
var finds_written := 0
var frame_at := 0
## Noises already turned into a puff, so each one only blooms once.
var puffed := 0
## Writes in the last second, so the fade can be kept just short of the wrap.
var written := 0
var write_rate := 1.0
var rate_clock := 0.0

## The click in flight: its rays are worked out one by one as they are cast
## (spray_direction), from the last to the first; spray_left of them remain.
## Building the whole spray at once cost a hitch on every click. Where the
## click left from follows.
var spray_left := 0
var spray_count := 0
var spray_ahead := 0
var spray_turn := 0.0
var spray_frame := Basis()
var pending_from := Vector3.ZERO
var pending_at := 0.0
var pending_reach := REACH
## Spots on the doors and wardrobes in reach, aimed at directly this click,
## and which reflector each one belongs to.
var pending_targets := PackedVector3Array()
var pending_owner := PackedInt32Array()
## Each door and wardrobe of the floor: {node, centre, frame, panel}.
var reflectors: Array = []
## How many aimed rays each reflector has answered, since the floor began. The
## regression reads it: instance data cannot be read back without a GPU.
var reflector_hits := PackedInt32Array()
var per_tick := 1
## Rays cast since this view opened; the regression reads it to check the
## budget really is spread across the frames between two clicks.
var rays_cast := 0
var query: PhysicsRayQueryParameters3D

## The next click is its own cry, and answers three times as loudly.
var shriek_click := false
var shriek_hold := 0.0
var shriek := 0.0
var hum_clock := 0.0

## Its own randomness: the cadence and the ray rotation must never touch the
## map's generator (see the rule at the top of world_audio.gd).
var rng := RandomNumberGenerator.new()

func setup(owner_driver) -> void:
	name = "EchoView"
	driver = owner_driver
	creature = owner_driver.creature
	level = owner_driver.level
	camera = owner_driver.camera
	rng.seed = int(level.manifest.get("seed", 0)) + 90211
	query = PhysicsRayQueryParameters3D.new()
	query.collision_mask = RAY_MASK
	query.exclude = [creature.get_rid()]
	build_field()
	build_clouds()
	self_material = ShaderMaterial.new()
	self_material.shader = SELF_SHADER
	self_material.render_priority = 127
	# Its own body is a presence, not the picture: kept well under the reading
	# so it never blinds the middle of the frame.
	self_material.set_shader_parameter("gain", 0.08 * lift() * lift())
	build_landmarks()
	build_reflectors()
	apply_quality()
	enable()

# --- Building -----------------------------------------------------------------------

func build_field() -> void:
	field_material = ShaderMaterial.new()
	field_material.shader = FIELD_SHADER
	field_material.render_priority = 120
	field = MeshInstance3D.new()
	field.name = "EchoField"
	field.mesh = QuadMesh.new()
	field.material_override = field_material
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A 1x1 quad sitting on the camera would be frustum-culled; a huge custom
	# box never is. The shader writes POSITION itself to cover the frame.
	field.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	field.ignore_occlusion_culling = true
	camera.add_child(field)

## One shader, three clouds; they differ only in uniforms and draw priority.
## How much brighter every grain is drawn on Compatibility. Forward+ adds the
## grains up in HDR and tonemaps the sum; Compatibility tonemaps each grain as
## it is drawn and adds what is left, which is darker: the same reading came
## out about a third dimmer, and with reduced effects nearly black. Measured
## against Forward+ with tools/capture/echo_capture.gd in both renderers.
const COMPAT_LIFT := 1.6
static func lift() -> float:
	return COMPAT_LIFT if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0
## (Its own body is lifted twice over: it is drawn in faint strokes that each
## lose more to that per-grain tonemap than a grain does.)

func make_cloud(title: String, priority: int, through: float) -> MultiMeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = POINT_SHADER
	material.render_priority = priority
	material.set_shader_parameter("through", through)
	material.set_shader_parameter("wave_speed", WAVE_SPEED)
	var multi := MultiMesh.new()
	# Order matters: the format and the custom-data flag have to be set before
	# instance_count, which is what allocates the buffer.
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = QuadMesh.new()
	multi.instance_count = 0
	var instance := MultiMeshInstance3D.new()
	instance.name = title
	instance.multimesh = multi
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Points are stamped anywhere in the floor: never cull the cloud itself.
	instance.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)
	# Grains show through walls by design ("through"): walls must not cull them.
	instance.ignore_occlusion_culling = true
	clouds.add_child(instance)
	return instance

func build_clouds() -> void:
	clouds = Node3D.new()
	clouds.name = "EchoClouds"
	level.add_child(clouds)
	# Remembered architecture whispers through a wall; a body never does, which
	# the soft depth test does for us by leaving it nothing to whisper with.
	# A noise is a sound, so its puff hangs there whatever is in the way.
	walls = make_cloud("EchoWalls", 122, 0.35)
	# A remembered frame only whispers through the wall in front of it.
	frames = make_cloud("EchoFrames", 123, 0.2)
	puffs = make_cloud("EchoPuffs", 124, 0.8)
	finds = make_cloud("EchoFinds", 125, 0.8)
	bodies = make_cloud("EchoBodies", 126, 0.0)
	marks = make_cloud("EchoLandmarks", 121, 0.55)
	# The motes of a burnt-out mind. They are not a reading: they arrive
	# whatever is in the way and however far off they are, which is the whole
	# point of them, so the cloud is fully "through" and its grains keep the
	# smallest size the shader allows instead of shrinking away with distance.
	motes = make_cloud("EchoMotes", 127, 1.0)
	wall_material = walls.material_override as ShaderMaterial
	body_material = bodies.material_override as ShaderMaterial
	puff_material = puffs.material_override as ShaderMaterial
	find_material = finds.material_override as ShaderMaterial
	mark_material = marks.material_override as ShaderMaterial
	mote_material = motes.material_override as ShaderMaterial
	motes.multimesh.instance_count = MOTE_GRAINS * MOTE_BODIES
	motes.multimesh.visible_instance_count = 0
	mote_material.set_shader_parameter("tone_cold", Color(1.5, 0.05, 0.03))
	mote_material.set_shader_parameter("tone_hot", Color(1.6, 0.22, 0.12))
	mote_material.set_shader_parameter("residue", 1.0)
	mote_material.set_shader_parameter("flare", 2.2)
	# Lifted well past the tone of the rest of the image, so a handful of
	# grains at the far end of a wing still reads as something red.
	mote_material.set_shader_parameter("gain", (2.6) * lift())
	guides = make_cloud("EchoGuides", 125, 1.0)
	guide_material = guides.material_override as ShaderMaterial
	guides.multimesh.instance_count = GUIDE_GRAINS
	guides.multimesh.visible_instance_count = 0
	guide_material.set_shader_parameter("wave_speed", GUIDE_FLOW)
	guide_material.set_shader_parameter("residue", 0.9)
	guide_material.set_shader_parameter("flare", 1.6)
	# Laid again every click: nothing of it is meant to fade in between.
	guide_material.set_shader_parameter("age_limit", 60.0)
	# The shriek turns every reading red, but not the way to go.
	for key in ["tone_cold", "shriek_cold"]: guide_material.set_shader_parameter(key, GUIDE_BLUE)
	for key in ["tone_hot", "shriek_hot"]: guide_material.set_shader_parameter(key, GUIDE_YELLOW)
	guide_material.set_shader_parameter("gain", 1.2 * lift())
	frame_material = frames.material_override as ShaderMaterial
	# Strong reflectors keep a body of light between fronts and come back warm
	# white, so a doorway or a wardrobe stands out from the room around it.
	frame_material.set_shader_parameter("residue", 0.5)
	frame_material.set_shader_parameter("flare", 2.0)
	frame_material.set_shader_parameter("tone_cold", Color(1.0, 0.97, 0.9))
	frame_material.set_shader_parameter("tone_hot", Color(1.0, 0.97, 0.9))
	# A puff is the same machinery with a slow wave and a body of its own: its
	# grains bloom outward from the noise and then hang in the air.
	for material in [puff_material, find_material]:
		material.set_shader_parameter("wave_speed", PUFF_SPEED)
		material.set_shader_parameter("residue", 0.85)
		material.set_shader_parameter("flare", 1.1)
		material.set_shader_parameter("tone_cold", Color(0.86, 0.90, 0.95))
		material.set_shader_parameter("tone_hot", Color(1.0, 0.97, 0.92))
	# Every grain's opacity tops out at one, so gain alone cannot lift a sound
	# above a door frame: its white is pushed past one instead (the image is
	# linear light, and the red of the shriek already goes past it too).
	puff_material.set_shader_parameter("tone_cold", Color(0.86, 0.90, 0.95) * PUFF_WHITE)
	puff_material.set_shader_parameter("tone_hot", Color(1.0, 0.97, 0.92) * PUFF_WHITE)
	find_material.set_shader_parameter("shriek_cold", Color(1.4, 0.18, 0.10))
	find_material.set_shader_parameter("shriek_hot", Color(1.5, 0.40, 0.24))
	# A living thing keeps answering a little between fronts: it has to stay
	# findable in the half second when the room has gone quiet.
	body_material.set_shader_parameter("residue", 0.32)
	body_material.set_shader_parameter("flare", 2.4)
	mark_material.set_shader_parameter("steady", 1.0)
	mark_material.set_shader_parameter("steady_fade_from", LANDMARK_NEAR)
	mark_material.set_shader_parameter("steady_fade_to", LANDMARK_REACH)

## It lives here: the doors and wardrobes of its planta are drawn faintly and
## for good, so it can still find its way between clicks. Built for the planta
## it is on and again when it rides to another (advance), faded by distance in
## the shader: the ones of the planta under it would show through the floor.
var landmark_planta := -1
func build_landmarks() -> void:
	var places := PackedVector3Array()
	if not is_instance_valid(level.hotel): return
	landmark_planta = FLOOR.planta_of(creature.global_position.y)
	for door in level.hotel.doors:
		if FLOOR.planta_of(door.doorway.y) != landmark_planta: continue
		# The frame traced all the way round, on both faces of the reveal, so a
		# doorway is a shape and not four dots. A door is the thing it needs to
		# read at a glance while it hunts, so this is the one place where the
		# grains are deliberately crowded.
		var turn := Basis(Vector3.UP, door.closed_rotation)
		var across: Vector3 = turn.x * (FLOOR.PORTAL * 0.5 + 0.04)
		var through: Vector3 = turn.z
		for face in [-1.0, 1.0]:
			var depth: Vector3 = through * (0.165 * face)
			for side in [-1.0, 1.0]:
				var jamb: Vector3 = door.doorway + across * side + depth
				for i in JAMB_GRAINS:
					places.append(jamb + Vector3(0, lerpf(0.06, DOORWAY_HIGH, rng.randf()), 0))
			for i in LINTEL_GRAINS:
				var over := lerpf(-1.0, 1.0, rng.randf())
				places.append(door.doorway + across * over + depth + Vector3(0, DOORWAY_HIGH + 0.04, 0))
	for hide in level.hotel.hides:
		if FLOOR.planta_of(hide.global_position.y) != landmark_planta: continue
		# On the front of the wardrobe (hiding_place.gd: HINGE.z, WIDTH, HEIGHT),
		# not inside it.
		var frame: Basis = hide.global_basis
		var front: float = HIDE.HINGE.z + 0.02
		var half: float = HIDE.WIDTH * 0.5
		for side in [-1.0, 1.0]:
			for i in JAMB_GRAINS:
				places.append(hide.global_position + frame * Vector3(side * half, lerpf(0.08, HIDE.HEIGHT - 0.04, rng.randf()), front))
		for i in LINTEL_GRAINS:
			var over := lerpf(-half, half, rng.randf())
			for high in [0.08, HIDE.HEIGHT - 0.04]:
				places.append(hide.global_position + frame * Vector3(over, high, front))
	var multi: MultiMesh = marks.multimesh
	multi.instance_count = places.size()
	for i in places.size():
		# A hair of scatter, or the frame reads as a drawn line rather than
		# something the room gave back.
		var grain: Vector3 = places[i] + Vector3(rng.randfn(0.0, 0.016), rng.randfn(0.0, 0.016), rng.randfn(0.0, 0.016))
		multi.set_instance_transform(i, Transform3D(Basis(), grain))
		multi.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, LANDMARK_LEVEL))

## The spots each door and wardrobe is aimed at, laid once per floor. Every one
## sits a centimetre or two in front of a solid face, because a ray has to land
## on something to count: the decorative trim round a doorway has no collision,
## but the end of the wall and the header above the opening do.
func build_reflectors() -> void:
	reflectors.clear()
	if not is_instance_valid(level.hotel): return
	var up := Vector3(0, 1, 0)
	for door in level.hotel.doors:
		var turn := Basis(Vector3.UP, door.closed_rotation)
		var across: Vector3 = turn.x
		var through: Vector3 = turn.z
		var edge: float = FLOOR.PORTAL * 0.5
		var base: Vector3 = door.doorway
		var tall: float = DOORWAY_HIGH - 0.2
		# Each surface is [corner, one side, the other side, spots per click].
		var frame: Array = []
		for side in [-1.0, 1.0]:
			# The end of the wall, facing into the opening.
			frame.append([base + across * side * (edge + 0.01) - through * 0.06 + up * 0.12, through * 0.12, up * tall, REVEAL_SPOTS])
			# The strip of wall round the opening, on both faces.
			for face in [-1.0, 1.0]:
				frame.append([base + across * side * (edge + 0.02) + through * (0.1 * face) + up * 0.12, across * side * 0.22, up * tall, BAND_SPOTS])
		# Under the header, and the band above the opening on both faces.
		frame.append([base - across * edge - through * 0.06 + up * (DOORWAY_HIGH + 0.04), across * (2.0 * edge), through * 0.12, SOFFIT_SPOTS])
		for face in [-1.0, 1.0]:
			frame.append([base - across * (edge + 0.1) + through * (0.1 * face) + up * (DOORWAY_HIGH + 0.06), across * (2.0 * edge + 0.2), up * 0.24, HEADER_SPOTS])
		# Across the opening, where a shut door stands.
		var panel: Array = [[base - across * (edge - 0.08) + up * 0.12, across * (2.0 * edge - 0.16), up * tall, PANEL_SPOTS]]
		reflectors.append({"node": door, "centre": base + Vector3(0, 1.3, 0), "frame": frame, "panel": panel})
	for hide in level.hotel.hides:
		var turn: Basis = hide.global_basis
		var front: float = HIDE.HINGE.z + 0.03
		var half: float = HIDE.WIDTH * 0.5 - 0.04
		var frame: Array = [[hide.global_position + turn * Vector3(-half, 0.1, front), turn * Vector3(2.0 * half, 0, 0), turn * Vector3(0, HIDE.HEIGHT - 0.18, 0), WARDROBE_SPOTS]]
		reflectors.append({"node": hide, "centre": hide.global_position + turn * Vector3(0, 1.1, front), "frame": frame, "panel": []})
	reflector_hits.resize(reflectors.size())
	reflector_hits.fill(0)

## Fresh spots scattered over a reflector's surfaces, uniformly and anew each
## time, so click after click the grains cover the whole face.
func reflector_spots(surfaces: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for surface in surfaces:
		for i in int(surface[3]):
			out.append(surface[0] + surface[1] * rng.randf() + surface[2] * rng.randf())
	return out

## This click's aimed spots: the reflectors within reach and not behind it,
## nearest first, until the budget runs out. A doorway's panel only while the
## door is shut. The spots are new every click (reflector_spots).
func aim_reflectors(from: Vector3) -> void:
	pending_targets = PackedVector3Array()
	pending_owner = PackedInt32Array()
	var aimed: int = budget.aimed
	if aimed == 0: return
	var forward: Vector3 = -camera.global_basis.z
	var near: Array = []
	var planta := FLOOR.planta_of(from.y - driver.EYE.y)
	for index in reflectors.size():
		var one: Dictionary = reflectors[index]
		if not is_instance_valid(one.node): continue
		# Only its own planta's: a frame under the floor would spend a ray on a
		# slab for nothing.
		if FLOOR.planta_of(one.centre.y - 1.0) != planta: continue
		var offset: Vector3 = one.centre - from
		var span := offset.length()
		if span > REACH: continue
		# Behind it counts only when it is right on top of it.
		if span > 3.0 and offset.normalized().dot(forward) < -0.2: continue
		near.append([span, index])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for entry in near:
		var one: Dictionary = reflectors[entry[1]]
		var spots := reflector_spots(one.frame)
		if "opened" in one.node and not one.node.opened: spots.append_array(reflector_spots(one.panel))
		for spot in spots:
			if pending_targets.size() >= aimed: return
			pending_targets.append(spot)
			pending_owner.append(entry[1])

## One aimed ray. The hit if it landed on the spot it was aimed at, which means
## the spot is in plain sight from `from`; empty if anything was in the way.
func reflect(space: PhysicsDirectSpaceState3D, from: Vector3, target: Vector3) -> Dictionary:
	var way := target - from
	var span := way.length()
	if span < 0.05 or span > REACH: return {}
	query.from = from
	query.to = from + way / span * (span + 0.3)
	rays_cast += 1
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty() or hit.position.distance_to(target) > INTEREST_HIT: return {}
	return hit

# --- Turning the view on and off ----------------------------------------------------

func enable() -> void:
	if enabled: return
	enabled = true
	field.visible = true
	clouds.visible = true
	# Its own body, drawn above the reading. material_override outranks the
	# surface overrides locust_look.apply() installed, so those are untouched
	# and come back on their own.
	if is_instance_valid(creature.visual):
		for mesh in creature.visual.find_children("*", "MeshInstance3D", true, false):
			mesh.set_meta("echo_kept", mesh.material_override)
			mesh.material_override = self_material

func disable() -> void:
	if not enabled: return
	enabled = false
	if is_instance_valid(field): field.visible = false
	if is_instance_valid(clouds): clouds.visible = false
	if is_instance_valid(creature) and is_instance_valid(creature.visual):
		for mesh in creature.visual.find_children("*", "MeshInstance3D", true, false):
			if not mesh.has_meta("echo_kept"): continue
			mesh.material_override = mesh.get_meta("echo_kept")
			mesh.remove_meta("echo_kept")

func _exit_tree() -> void:
	disable()
	if is_instance_valid(clouds): clouds.queue_free()

## Point budgets and how much of the reading trembles, from the user's setting.
func apply_quality() -> void:
	quality = clampi(int(level.settings.values.quality), 0, PRESETS.count() - 1)
	budget = PRESETS.of(quality).echo
	calm = level.settings.values.reduced == true
	var points: int = budget.points
	if walls.multimesh.instance_count != points:
		walls.multimesh.instance_count = points
		wall_at = 0
		wall_shown = 0
	var flesh: int = budget.bodies
	if bodies.multimesh.instance_count != flesh:
		bodies.multimesh.instance_count = flesh
		body_at = 0
		body_shown = 0
	if puffs.multimesh.instance_count != budget.puffs:
		puffs.multimesh.instance_count = budget.puffs
		puff_at = 0
	if finds.multimesh.instance_count != budget.finds:
		finds.multimesh.instance_count = budget.finds
		find_at = 0
	if frames.multimesh.instance_count != budget.frames:
		frames.multimesh.instance_count = budget.frames
		frame_at = 0
	per_tick = maxi(1, int(ceil(float(budget.rays + budget.aimed) / (60.0 / CLICK_RATE))))
	field_material.set_shader_parameter("presence", (PRESENCE_CALM if calm else PRESENCE) * lift())
	# With nothing drawn from the depth buffer, the grains have to carry the
	# room between clicks, so they keep more of themselves alight than a
	# wavefront-lit stipple needed to.
	# The general room sits a little back now that doors and wardrobes answer
	# on their own: they are what matters, the rest is only somewhere to be.
	wall_material.set_shader_parameter("residue", 0.32 if calm else 0.24)
	wall_material.set_shader_parameter("flare", 1.2 if calm else 1.9)
	field_material.set_shader_parameter("grain_amount", 0.0 if calm else 1.0)
	field_material.set_shader_parameter("jitter_amount", 0.0 if calm else 1.0)
	mark_material.set_shader_parameter("gain", (1.8 if calm else 1.0) * lift())
	# The cloud carries most of the picture now that the clicks are slow.
	wall_material.set_shader_parameter("gain", (0.95) * lift())
	frame_material.set_shader_parameter("gain", (1.5) * lift())
	body_material.set_shader_parameter("gain", (1.6) * lift())
	# A heard noise has to stand out from the architecture round it, which a
	# door's own reflector grains made hard: brighter and coarser than both.
	puff_material.set_shader_parameter("gain", (PUFF_GAIN) * lift())
	puff_material.set_shader_parameter("twinkle", PUFF_TWINKLE)
	find_material.set_shader_parameter("gain", (1.35) * lift())
	var height: float = maxf(1.0, level.get_viewport().get_visible_rect().size.y)
	# Fewer grains read as a room when each is bigger, and the other way round
	# (budget.grain, per preset): the same share of the screen is covered.
	var grain: float = budget.grain
	var span := 2.0 * tan(deg_to_rad(camera.fov * 0.5)) * POINT_PIXELS * grain / height
	for material in [wall_material, body_material, puff_material, find_material, mark_material, frame_material]:
		material.set_shader_parameter("point_scale", span)
		material.set_shader_parameter("point_min", 0.010 * grain)
		material.set_shader_parameter("point_max", 0.085 * grain)
		material.set_shader_parameter("halo", budget.halo)
	# Reflector grains a touch bigger than the room's.
	frame_material.set_shader_parameter("point_scale", span * FRAME_PIXELS / POINT_PIXELS)
	# The guides one size on every preset, a little coarser than a room grain,
	# and that size on screen however far off: with the room's cap they shrank
	# to nothing past a dozen metres, and a lit set has to read from anywhere.
	guide_material.set_shader_parameter("point_scale", 2.0 * tan(deg_to_rad(camera.fov * 0.5)) * POINT_PIXELS * 1.6 / height)
	guide_material.set_shader_parameter("point_min", 0.012)
	guide_material.set_shader_parameter("point_max", 1.0)
	puff_material.set_shader_parameter("point_scale", span * PUFF_PIXELS / POINT_PIXELS)

# --- The clicks ---------------------------------------------------------------------

## Called from the driver's physics step.
func advance(delta: float, hunting: bool) -> void:
	if not enabled: return
	# Ridden to another planta: the doors it simply knows are the ones there.
	if FLOOR.planta_of(creature.global_position.y) != landmark_planta: build_landmarks()
	clock += delta
	rate_clock += delta
	if rate_clock >= 1.0:
		write_rate = maxf(1.0, float(written) / rate_clock)
		written = 0
		rate_clock = 0.0
	hum_clock -= delta
	if hum_clock <= 0.0:
		hum_clock = 1.4
		bloom_hums()
	shriek_hold = maxf(0.0, shriek_hold - delta)
	var wanted := 1.0 if shriek_hold > 0.0 else 0.0
	shriek = move_toward(shriek, wanted, delta * ((SHRIEK_RISE if not calm else 2.5) if wanted > shriek else SHRIEK_FALL))
	if clock >= next_click: click(hunting)
	cast_pending()
	push_uniforms()

## One click: a front leaves its head and a budget of rays goes with it, and
## every ray that comes back becomes a grain stamped with that front's time.
func click(hunting: bool) -> void:
	clicks += 1
	var breath := 1.0 if calm else 1.0 + sin(clock * TAU * BREATH_RATE) * BREATH_DEPTH
	var jitter := 1.0 if calm else 1.0 + rng.randf_range(-CLICK_JITTER, CLICK_JITTER)
	var interval := (1.0 / CLICK_RATE) * breath * jitter
	last_interval = interval
	next_click = clock + interval
	var from: Vector3 = creature.global_position + Vector3(0, driver.EYE.y, 0)
	var reach: float = REACH
	# Its own cry is one enormous click: everything answers at once.
	var rays: int = budget.rays * (3 if shriek_click else 1)
	shriek_click = false
	if rays > 0:
		# Whatever is left of the previous click is dropped: the reading is
		# always the newest one, and the cost per tick stays bounded.
		start_spray(rays)
		pending_from = from
		pending_at = clock
		pending_reach = reach
	# Doors and wardrobes in reach get rays of their own, cast first.
	aim_reflectors(from)
	if not pending_targets.is_empty() and rays == 0:
		pending_from = from
		pending_at = clock
	if clicks % BODY_EVERY == 0: stamp_bodies(from, reach)
	bloom_contacts()
	bloom_motes()
	bloom_guides()

## Directions for one click: a Fibonacci sphere, turned by a fresh angle every
## time so successive clicks fill in each other's gaps, with most of the rays
## pushed into a cone ahead of where it is looking. start_spray() fixes the
## frame and the turn; spray_direction() gives ray i when it is cast.
const GOLDEN := PI * (3.0 - 2.2360679775)
func start_spray(count: int) -> void:
	var forward: Vector3 = -camera.global_basis.z
	spray_frame = Basis()
	if absf(forward.dot(Vector3.UP)) < 0.98:
		spray_frame = Basis.looking_at(forward, Vector3.UP)
	spray_turn = rng.randf() * TAU
	spray_count = count
	spray_ahead = int(count * FORWARD_BIAS)
	spray_left = count

func spray_direction(i: int) -> Vector3:
	var into_cone := i < spray_ahead
	var span: float = cos(FORWARD_CONE) if into_cone else -1.0
	var reach_i: int = spray_ahead if into_cone else spray_count - spray_ahead
	var index: int = i if into_cone else i - spray_ahead
	var z := 1.0 - (1.0 - span) * (float(index) + 0.5) / float(maxi(reach_i, 1))
	var radius := sqrt(maxf(0.0, 1.0 - z * z))
	var angle := GOLDEN * float(i) + spray_turn
	var direction := Vector3(cos(angle) * radius, sin(angle) * radius, -z)
	# A touch of scatter on every ray: the bare spiral lands on a floor in
	# visible rings, and the point of this is stipple, not moire.
	direction += Vector3(rng.randfn(0.0, 0.012), rng.randfn(0.0, 0.012), rng.randfn(0.0, 0.012))
	return spray_frame * direction.normalized()

## The rays of the click in flight, spread over the frames until the next one
## so the cost never lands in a single tick. The origin is frozen at emission:
## the shell left from there, wherever the body has walked to since.
func cast_pending() -> void:
	if (spray_left == 0 and pending_targets.is_empty()) or not is_instance_valid(level.hotel): return
	var space: PhysicsDirectSpaceState3D = creature.get_world_3d().direct_space_state
	var left := per_tick
	# The reflectors first: if a short interval cuts the click off, what gets
	# dropped is general room, never a doorway.
	while left > 0 and not pending_targets.is_empty():
		left -= 1
		var target: Vector3 = pending_targets[pending_targets.size() - 1]
		var owner: int = pending_owner[pending_owner.size() - 1]
		pending_targets.remove_at(pending_targets.size() - 1)
		pending_owner.remove_at(pending_owner.size() - 1)
		var hit: Dictionary = reflect(space, pending_from, target)
		if hit.is_empty(): continue
		reflector_hits[owner] += 1
		var landed: Vector3 = hit.position
		for grain in INTEREST_GRAINS:
			var spot: Vector3 = landed if grain == 0 else landed + Vector3(rng.randfn(0.0, 0.02), rng.randfn(0.0, 0.02), rng.randfn(0.0, 0.02))
			write(frames, spot, pending_from.distance_to(spot), 0.0, 1.0, pending_at)
	var count := mini(left, spray_left)
	for i in count:
		spray_left -= 1
		var direction := spray_direction(spray_left)
		query.from = pending_from
		query.to = pending_from + direction * pending_reach
		rays_cast += 1
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty(): continue
		var point: Vector3 = hit.position
		var facing: float = absf(hit.normal.dot(direction))
		write(walls, point, pending_from.distance_to(point), 0.0, 0.30 + 0.70 * facing, pending_at)

## A survivor as the echo returns it, only while the creature can actually see
## it: sees() already applies its cone, its line of sight and the wardrobe
## rule, so the image can never show more than its own perception allows.
func stamp_bodies(from: Vector3, reach: float) -> void:
	if budget.bodies == 0: return
	var shape := PackedVector3Array()
	for body in level.survivors():
		if not is_instance_valid(body) or not level.survivor_active(body): continue
		if body.global_position.distance_to(creature.global_position) > REACH: continue
		if not creature.sees(body): continue
		shape.clear()
		BODY.points(body, from, shape, rng)
		for point in shape:
			# Stamped with this click's own time and each grain's own distance
			# from where it left, so the front sweeps across the body exactly as
			# it sweeps the walls, instead of the whole figure lighting at once.
			write(bodies, point, from.distance_to(point), 1.0, 1.0, clock, reach)

## One grain into a cloud's ring buffer. `span` is how far it is from whatever
## front will light it: the click's origin for the world, the centre of the
## noise for a puff. `reach` beyond zero drops grains past the click's range.
func write(cloud: MultiMeshInstance3D, point: Vector3, span: float, kind: float, energy: float, at: float, reach := 0.0) -> void:
	var multi: MultiMesh = cloud.multimesh
	if multi.instance_count == 0: return
	if reach > 0.0 and span > reach: return
	var index: int
	if cloud == walls:
		index = wall_at
		wall_at = (wall_at + 1) % multi.instance_count
		wall_shown = mini(wall_shown + 1, multi.instance_count)
	elif cloud == puffs:
		index = puff_at
		puff_at = (puff_at + 1) % multi.instance_count
	elif cloud == finds:
		index = find_at
		find_at = (find_at + 1) % multi.instance_count
		finds_written += 1
	elif cloud == motes:
		index = mote_at
		mote_at = (mote_at + 1) % multi.instance_count
	elif cloud == frames:
		index = frame_at
		frame_at = (frame_at + 1) % multi.instance_count
	else:
		index = body_at
		body_at = (body_at + 1) % multi.instance_count
		body_shown = mini(body_shown + 1, multi.instance_count)
	multi.set_instance_transform(index, Transform3D(Basis(), point))
	multi.set_instance_custom_data(index, Color(at, span, kind, energy))
	written += 1

## A ball of grains scattered around a point, each one carrying its distance
## from the centre so the shader blooms them outward from it.
func scatter(cloud: MultiMeshInstance3D, centre: Vector3, radius: float, count: int, kind: float, energy: float, at: float, bell := false) -> void:
	for i in count:
		if bell:
			# A bell instead of a ball: dense at the source and thinning out,
			# so the source itself stays a bright knot that reads from afar.
			var offset := bell_offset(radius)
			var near: float = offset.length() / maxf(radius * PUFF_BELL, 0.01)
			write(cloud, centre + offset, offset.length(), kind, energy * (1.0 + PUFF_CORE_GAIN * exp(-near * near)), at)
			continue
		var direction := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0))
		if direction.length() < 0.001: direction = Vector3.UP
		# Cube root of a uniform draw fills the ball evenly instead of clumping
		# everything at the middle.
		var span: float = radius * pow(rng.randf(), 0.34)
		var point: Vector3 = centre + direction.normalized() * span
		write(cloud, point, span, kind, energy, at)

## One grain's place in a bell-shaped puff, from its centre.
func bell_offset(radius: float) -> Vector3:
	var offset := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0)) * radius * PUFF_BELL
	return offset.limit_length(radius * 1.6)

## Every noise heard since the last click becomes a puff hanging where it was
## heard. A survivor walking leaves one every stride, which is the trail.
func bloom_contacts() -> void:
	if budget.puffs == 0: return
	var seconds := Time.get_ticks_msec() / 1000.0
	for mark in driver.heard:
		if int(mark.get("id", 0)) <= puffed: continue
		puffed = int(mark.id)
		if seconds - mark.time > CONTACT_LIFE: continue
		# Loud and blunt noises make a wider, denser cloud than a crouched step.
		var loud: float = mark.strength
		var kind := int(mark.kind)
		var bell: bool = kind in PUFF_BELLS
		var radius := puff_radius(loud, kind, mark.get("blur", 0.0))
		var count: int = int(budget.puff_points * (0.45 + 0.55 * loud) * PUFF_DENSITY[kind])
		if not kind in PUFF_BELLS: count = int(count * lerpf(1.0, FAR_STEP_GRAINS, float(mark.get("blur", 0.0))))
		# The further the sound travelled, the vaguer the place it hangs in.
		var when: float = clock - (seconds - mark.time)
		var centre: Vector3 = mark.at
		if kind == KINDS.Kind.WARDROBE: centre = before_wardrobe(centre)
		var blur: float = mark.get("blur", 0.0)
		if blur > 0.0:
			var towards: Vector3 = creature.global_position + Vector3(0, centre.y - creature.global_position.y, 0) - centre
			if towards.length() > PUFF_STAND_OFF * 2.0: centre += towards.normalized() * PUFF_STAND_OFF * blur
		# Two above the tone marks a grain that fades early (echo_points.gdshader).
		var life := write_life(PUFF_LIVES[kind])
		scatter(puffs, centre, radius, count, life, 0.35 + 0.65 * loud, when, bell)
		shape_of_noise(mark, when, life)

## How wide a noise's cloud is: louder and blunter is wider, heard from afar
## a little vaguer, and never wider than PUFF_MAX_RADIUS.
func puff_radius(loud: float, kind: int, blur: float) -> float:
	var radius: float = (0.30 + 1.25 * loud) * KINDS.SPREAD[kind] * PUFF_SIZE[kind]
	radius *= 1.0 + blur * (BELL_BLUR if kind in PUFF_BELLS else PUFF_BLUR)
	if kind in PUFF_BELLS: return minf(radius, PUFF_MAX_RADIUS)
	return minf(radius, lerpf(PUFF_MAX_RADIUS, FAR_STEP_RADIUS, blur))

## A grain's own life, added to its tone (0 or 1) in the kind channel: two
## per tenth of a second, so the tone stays readable as what is left over.
## Zero means the cloud's age_limit (echo_points.gdshader decodes it).
func write_life(seconds: float) -> float:
	return 2.0 * roundf(seconds * 10.0)

## In front of the wardrobe a noise came from, if it hangs on one; a noise
## heard from afar hangs in a doorway instead and stays there.
func before_wardrobe(point: Vector3) -> Vector3:
	for hide in level.hotel.hides:
		if hide.global_position.distance_to(point) > 1.2: continue
		return hide.global_position + hide.global_basis * Vector3(0, WARDROBE_PUFF_UP, HIDE.HINGE.z + WARDROBE_PUFF_OUT)
	return point

## A noise made close by does not just say "over there": it comes off a body,
## and the body's shape comes back with it. Inside the puff, whoever made the
## sound is drawn densely in grains. Only for a noise heard from close, where
## the exact spot is already part of what the machine in charge sent, so this
## reveals a shape and never a position the creature had not earned.
func shape_of_noise(mark: Dictionary, when: float, life := 0.0) -> void:
	if float(mark.get("blur", 1.0)) > 0.01: return
	var point: Vector3 = mark.point
	var maker: Node3D = null
	for body in level.survivors():
		if not is_instance_valid(body) or not level.survivor_active(body): continue
		if body.global_position.distance_to(point) > 1.4: continue
		maker = body
		break
	if maker == null: return
	var from: Vector3 = creature.global_position + Vector3(0, driver.EYE.y, 0)
	var shape := PackedVector3Array()
	BODY.points(maker, from, shape, rng)
	# Two or three grains per sample, jittered, so the figure reads as a dense
	# cloud of its own rather than a row of dots.
	for i in shape.size():
		var surface: Vector3 = shape[i]
		for extra in NOISE_SHAPE:
			var grain := surface + Vector3(rng.randfn(0.0, 0.022), rng.randfn(0.0, 0.022), rng.randfn(0.0, 0.022))
			write(puffs, grain, grain.distance_to(point), 1.0 + life, 1.0, when)

# --- Uniforms -----------------------------------------------------------------------

func push_uniforms() -> void:
	# The fade is never fixed by hand: it follows the measured write rate, so a
	# point always finishes going out before the ring buffer reaches it again.
	var span: float = minf(MEMORY, float(maxi(wall_shown, 1)) / maxf(write_rate, 1.0))
	wall_material.set_shader_parameter("age_limit", span)
	body_material.set_shader_parameter("age_limit", BODY_FADE)
	puff_material.set_shader_parameter("age_limit", PUFF_LIFE)
	frame_material.set_shader_parameter("age_limit", FRAME_MEMORY)
	find_material.set_shader_parameter("age_limit", FIND_LIFE)
	push_beam()
	for material in [field_material, wall_material, frame_material, body_material, puff_material, find_material, mark_material, self_material, guide_material]:
		material.set_shader_parameter("now", clock)
		material.set_shader_parameter("shriek", shriek)

## The fluorescent battens it can hear buzzing, as a faint puff under each one,
## refreshed slowly. Free texture: world_audio already routes them from its own
## camera, so this costs no network and no extra listening.
func bloom_hums() -> void:
	if budget.puffs == 0 or not is_instance_valid(level.world_audio): return
	for hum in level.world_audio.hums:
		if not is_instance_valid(hum) or not hum.playing: continue
		scatter(puffs, hum.global_position, 0.5, maxi(4, int(budget.puff_points) / 5), 0.0, HUM_LEVEL, clock)

## Whoever has burnt out, wherever they are: a few grains over each of them,
## with no sight check and no distance to it. This is the one thing the
## creature is given for free, and it is given because somebody stopped being
## able to think -- which is what standing in the dark long enough does.
## Laid whole on every click, like the guides: when a mark goes out (killed,
## back in the light, in the refuge or riding a car) its grains go with it.
## Left in the ring, the last ones hung where it ended for the rest of the
## match, on every planta after it too, since nothing ever aged them.
func bloom_motes() -> void:
	if motes.multimesh.instance_count == 0 or not is_instance_valid(level): return
	var marked: Array = level.sanity.burnt_survivors().slice(0, MOTE_BODIES)
	mote_at = 0
	for point in marked:
		scatter(motes, point + Vector3(0, 1.15, 0), MOTE_SPREAD, MOTE_GRAINS, 1.0, 1.0, clock)
	motes.multimesh.visible_instance_count = marked.size() * MOTE_GRAINS

## The guides of this click, laid whole: every lit set of the stage first (a
## handful of grains each), then the way to the lift and the way to the set it
## asked for, with what is left.
func bloom_guides() -> void:
	var count := 0
	var screens: Array = driver.lit_screens()
	guide_routes.screens = screens.size()
	for screen in screens: count = lay_screen(screen, count)
	var lift: PackedVector3Array = driver.lift_route()
	guide_routes.lift = lift.size()
	if lift.size() >= 2: count = lay_route(lift, 0.0, count, driver.lift_away_now())
	var trace: PackedVector3Array = driver.trace_route()
	guide_routes.trace = trace.size()
	if trace.size() >= 2: count = lay_route(trace, 1.0, count, false)
	guide_count = count
	guides.multimesh.visible_instance_count = count

## A route as a line of grains on the floor, each carrying how far along the
## route it lies, so this click's front runs from the creature to the end.
## Coarser when the route is too long for the grains left. Returns where the
## next grains go.
func lay_route(route: PackedVector3Array, kind: float, at: int, waiting: bool) -> int:
	route = rounded(route)
	var multi: MultiMesh = guides.multimesh
	var length := 0.0
	for i in range(1, route.size()): length += route[i].distance_to(route[i - 1])
	var room: int = multi.instance_count - at - GUIDE_END_GRAINS
	if room <= GUIDE_PER_STEP: return at
	var step: float = maxf(GUIDE_STEP, length * GUIDE_PER_STEP / float(room))
	var along := 0.0
	var next := 0.0
	for i in range(1, route.size()):
		var a: Vector3 = route[i - 1]
		var b: Vector3 = route[i]
		var span: float = a.distance_to(b)
		while next <= along + span and at + GUIDE_PER_STEP <= multi.instance_count - GUIDE_END_GRAINS:
			var point: Vector3 = a.lerp(b, clampf((next - along) / maxf(span, 0.001), 0.0, 1.0))
			for k in GUIDE_PER_STEP:
				var grain := point + Vector3(rng.randfn(0.0, GUIDE_SCATTER), GUIDE_HEIGHT + absf(rng.randfn(0.0, 0.02)), rng.randfn(0.0, GUIDE_SCATTER))
				multi.set_instance_transform(at, Transform3D(Basis(), grain))
				multi.set_instance_custom_data(at, Color(clock, next, kind, 1.0))
				at += 1
			next += step
		along += span
	var end: Vector3 = route[route.size() - 1]
	var beat: float = 0.35 if waiting and clicks % 2 == 1 else 1.6
	for k in GUIDE_END_GRAINS:
		if at >= multi.instance_count: break
		var grain := end + Vector3(rng.randfn(0.0, 0.22), GUIDE_HEIGHT + rng.randf() * 1.6, rng.randfn(0.0, 0.22))
		multi.set_instance_transform(at, Transform3D(Basis(), grain))
		multi.set_instance_custom_data(at, Color(clock, length, kind, beat))
		at += 1
	return at

## The guides' corners rounded off: each turn of the route becomes a curve
## that starts and ends up to ROUND_CORNER metres either side of it (never
## past half a leg), so the blue and yellow ways bend instead of snapping at
## every corner of the navigation mesh. Only a look: the route is the same.
const ROUND_CORNER := 1.2
const ROUND_STEPS := 6
static func rounded(route: PackedVector3Array) -> PackedVector3Array:
	if route.size() < 3: return route
	var out := PackedVector3Array([route[0]])
	for i in range(1, route.size() - 1):
		var a: Vector3 = route[i - 1]
		var b: Vector3 = route[i]
		var c: Vector3 = route[i + 1]
		var cut: float = minf(ROUND_CORNER, minf(a.distance_to(b), b.distance_to(c)) * 0.5)
		if cut < 0.05:
			out.append(b)
			continue
		var from: Vector3 = b + (a - b).normalized() * cut
		var to: Vector3 = b + (c - b).normalized() * cut
		for k in ROUND_STEPS + 1:
			var t := float(k) / float(ROUND_STEPS)
			out.append(from.lerp(b, t).lerp(b.lerp(to, t), t))
	out.append(route[route.size() - 1])
	return out

## A lit set as it has it: its screen full of yellow grains and a few round it,
## lit afresh on every click.
func lay_screen(screen: Array, at: int) -> int:
	var multi: MultiMesh = guides.multimesh
	var centre: Vector3 = screen[0]
	var right: Vector3 = screen[1]
	var up: Vector3 = screen[2]
	for k in SCREEN_GRAINS + SCREEN_HALO + SCREEN_BEACON:
		if at >= multi.instance_count: break
		var grain: Vector3 = centre + right * rng.randf_range(-1.0, 1.0) + up * rng.randf_range(-1.0, 1.0)
		var energy := 1.6
		if k >= SCREEN_GRAINS + SCREEN_HALO:
			grain = centre + Vector3(rng.randfn(0.0, 0.05), up.length() + rng.randf() * 1.4, rng.randfn(0.0, 0.05))
			energy = 1.2
		elif k >= SCREEN_GRAINS:
			grain = centre + Vector3(rng.randfn(0.0, 0.45), rng.randfn(0.0, 0.35), rng.randfn(0.0, 0.45))
			energy = 0.8
		multi.set_instance_transform(at, Transform3D(Basis(), grain))
		multi.set_instance_custom_data(at, Color(clock, 0.0, 1.0, energy))
		at += 1
	return at

## What the shriek came back with: a dense cloud over each survivor it found,
## which stays for seconds after the cry itself has died away. This is what the
## shriek is worth, not the red.
func mark_found(points: PackedVector3Array) -> void:
	if budget.finds == 0: return
	for point in points:
		scatter(finds, point, 0.55, budget.find_points, 1.0, 1.0, clock)

## A survivor's lit torch pointed this way. It cannot see light, but the beam
## disturbs the reading from that direction: turning it off still matters.
## The beam of a torch pointed at it, handed to the field in the camera's own
## space: where the lamp is, which way it points, how wide and how far. The
## field draws the cone from that, so it is where the light really is.
func push_beam() -> void:
	var lit = creature.lit_by_torch()
	if lit == null or not is_instance_valid(camera) or not is_instance_valid(lit.torch):
		field_material.set_shader_parameter("beam_origin", Vector4.ZERO)
		return
	var torch: SpotLight3D = lit.torch
	var to_view := camera.global_transform.affine_inverse()
	var origin: Vector3 = to_view * torch.global_position
	var axis: Vector3 = (to_view.basis * -torch.global_basis.z).normalized()
	var strength := clampf(1.0 - origin.length() / 45.0, 0.0, 1.0)
	field_material.set_shader_parameter("beam_origin", Vector4(origin.x, origin.y, origin.z, strength))
	field_material.set_shader_parameter("beam_axis", Vector4(axis.x, axis.y, axis.z, cos(deg_to_rad(torch.spot_angle))))
	field_material.set_shader_parameter("beam_range", torch.spot_range)

## It shrieked: the reading floods red and it clicks at once, hard.
func flash_shriek() -> void:
	shriek_hold = SHRIEK_HOLD
	shriek_click = true
	next_click = clock
