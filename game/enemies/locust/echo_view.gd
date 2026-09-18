extends Node
## The Locust's eyes, for the player who drives it. It does not see the hotel:
## it clicks, and rebuilds the hotel from what comes back, mixed with the
## sounds the survivors are making. Three readings, one image:
##
##   the field   a screen pass over the real depth buffer: the wavefront of
##               each click sweeping the surfaces in front of it, depth bands,
##               edges, and the sounds painted as rings on those same surfaces
##   the clouds  world-space points stamped by rays on every click, so the
##               shape of a room stays where it really is; architecture is
##               remembered for seconds, a body only for a breath
##   the self    its own body, the one thing it knows without listening
##
## The reading refreshes on the click, about fifteen times a second, with an
## organic cadence and several shells in flight at once. The picture itself is
## redrawn every frame from wherever the camera is, so moving is smooth and
## nothing warps: what pulses is the information, not the framerate.
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
## Every click is a full sweep at this rate, with only a little variation in
## how hard it comes back.
const SWEEP_MIN := 0.78
## Slow enough to watch a front cross a room and back: a shell takes about two
## and a half seconds to reach the end of its hearing, so five or six of them
## are always in flight at different radii.
const WAVE_SPEED := 16.0
## Useful range. Under world_audio.ROUTE_LIMIT (42) and far under the 66 m at
## which update_visibility hides rooms, so no wall it should show is missing.
const REACH := 40.0
## Depth contour spacing, about one band per stride of the hotel.
const BAND_STEP := 1.5
## Longest a remembered point lives; the real limit follows the ring buffer.
const MEMORY := 5.0
## Rays per click, points remembered, body points: off / medium / high. The
## budget per click is large because there are thirty physics frames to spread
## it over: the cost per frame is the same as a fast click would be, and what
## you get for it is a scene made of points.
const RAY_BUDGET := [0, 900, 1800]
const POINT_BUDGET := [0, 7000, 11000]
const BODY_POINTS := [0, 700, 1400]
## Bodies are sampled on every click and fade just past the next one: a
## survivor is a live reading, never a memory to be followed.
const BODY_EVERY := 1
const BODY_FADE := 0.75
## Half the rays go into a wide cone ahead and the rest over the whole sphere.
## Any narrower and the wall it happens to be facing collects so many points
## that they merge into a solid sheet instead of reading as stipple.
const FORWARD_BIAS := 0.5
const FORWARD_CONE := 1.15
## Shells the field shader carries at once: its per-pixel loop is the only
## superlinear cost in the whole view.
const SWEEPS := 6
## A heard noise hangs as a puff of grains where it was heard, blooming outward
## from the spot at this speed and out to this radius before it goes.
const PUFF_SPEED := 4.5
const PUFF_LIFE := 2.2
const PUFF_POINTS := [0, 26, 44]
const PUFF_BUDGET := [0, 900, 1800]
## What the shriek found stays marked well after the cry has died away, so it
## is worth something beyond turning the picture red.
const FIND_LIFE := 3.2
const FIND_POINTS := [0, 40, 70]
const FIND_BUDGET := [0, 600, 1200]
## How long a contact is worth marking at all.
const CONTACT_LIFE := 1.6
## Its own shriek floods the reading red, then drains.
const SHRIEK_HOLD := 4.0
const SHRIEK_RISE := 6.0
const SHRIEK_FALL := 0.55
## Doors and wardrobes it simply knows are there, faded out by this distance.
const LANDMARK_NEAR := 12.0
const LANDMARK_REACH := 20.0
const LANDMARK_LEVEL := 0.12
## A point's radius on screen, in pixels of the rendered image. Small: the
## picture should be made of grains, and grains that touch are a surface.
const POINT_PIXELS := 2.0
## Residual level between clicks. Low on purpose: raise it and the creature
## simply sees, and the whole thing stops being echolocation.
const BASE_LEVEL := 0.008
const BASE_CALM := 0.03
## Walls, doors and swinging leaves: what an echo comes back from.
const RAY_MASK := 1 | 8 | 64
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
var calm := false

var field: MeshInstance3D
var field_material: ShaderMaterial
var clouds: Node3D
var walls: MultiMeshInstance3D
var bodies: MultiMeshInstance3D
var puffs: MultiMeshInstance3D
var finds: MultiMeshInstance3D
var marks: MultiMeshInstance3D
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
## Noises already turned into a puff, so each one only blooms once.
var puffed := 0
## Writes in the last second, so the fade can be kept just short of the wrap.
var written := 0
var write_rate := 1.0
var rate_clock := 0.0

## Rays still to cast for the click in flight, and where that click left from.
var pending := PackedVector3Array()
var pending_from := Vector3.ZERO
var pending_at := 0.0
var pending_reach := REACH
var per_tick := 1
## Rays cast since this view opened; the regression reads it to check the
## budget really is spread across the frames between two clicks.
var rays_cast := 0
var query: PhysicsRayQueryParameters3D

## Shells in flight: [origin, emit time, amplitude, reach].
var shells: Array = []
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
	self_material.render_priority = 126
	# Its own body is a presence, not the picture: kept well under the reading
	# so it never blinds the middle of the frame.
	self_material.set_shader_parameter("gain", 0.08)
	build_landmarks()
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
	camera.add_child(field)
	field_material.set_shader_parameter("reach", REACH)
	field_material.set_shader_parameter("wave_speed", WAVE_SPEED)
	field_material.set_shader_parameter("band_step", BAND_STEP)

## One shader, three clouds; they differ only in uniforms and draw priority.
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
	puffs = make_cloud("EchoPuffs", 123, 0.8)
	finds = make_cloud("EchoFinds", 124, 0.8)
	bodies = make_cloud("EchoBodies", 125, 0.0)
	marks = make_cloud("EchoLandmarks", 121, 0.55)
	wall_material = walls.material_override as ShaderMaterial
	body_material = bodies.material_override as ShaderMaterial
	puff_material = puffs.material_override as ShaderMaterial
	find_material = finds.material_override as ShaderMaterial
	mark_material = marks.material_override as ShaderMaterial
	# A puff is the same machinery with a slow wave and a body of its own: its
	# grains bloom outward from the noise and then hang in the air.
	for material in [puff_material, find_material]:
		material.set_shader_parameter("wave_speed", PUFF_SPEED)
		material.set_shader_parameter("residue", 0.85)
		material.set_shader_parameter("flare", 1.1)
		material.set_shader_parameter("tone_cold", Color(0.86, 0.90, 0.95))
		material.set_shader_parameter("tone_hot", Color(1.0, 0.97, 0.92))
	find_material.set_shader_parameter("shriek_cold", Color(1.4, 0.18, 0.10))
	find_material.set_shader_parameter("shriek_hot", Color(1.5, 0.40, 0.24))
	# A living thing keeps answering a little between fronts: it has to stay
	# findable in the half second when the room has gone quiet.
	body_material.set_shader_parameter("residue", 0.32)
	body_material.set_shader_parameter("flare", 2.4)
	mark_material.set_shader_parameter("steady", 1.0)
	mark_material.set_shader_parameter("steady_fade_from", LANDMARK_NEAR)
	mark_material.set_shader_parameter("steady_fade_to", LANDMARK_REACH)

## It lives here: the doors and wardrobes of the floor are drawn faintly and
## for good, so it can still find its way between clicks. Built once, never
## touched again, faded by distance in the shader.
func build_landmarks() -> void:
	var places := PackedVector3Array()
	if not is_instance_valid(level.hotel): return
	for door in level.hotel.doors:
		var across: Vector3 = Basis(Vector3.UP, door.closed_rotation).x * (FLOOR.PORTAL * 0.5)
		for side in [-1.0, 1.0]:
			places.append(door.doorway + across * side + Vector3(0, 0.12, 0))
			places.append(door.doorway + across * side + Vector3(0, 2.05, 0))
	for hide in level.hotel.hides:
		var frame: Basis = hide.global_basis
		for corner in [Vector3(-0.55, 0.1, 0), Vector3(0.55, 0.1, 0), Vector3(-0.55, 2.05, 0), Vector3(0.55, 2.05, 0), Vector3(0, 1.1, 0), Vector3(0, 2.05, 0)]:
			places.append(hide.global_position + frame * corner)
	var multi: MultiMesh = marks.multimesh
	multi.instance_count = places.size()
	for i in places.size():
		multi.set_instance_transform(i, Transform3D(Basis(), places[i]))
		multi.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, LANDMARK_LEVEL))

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
	quality = clampi(int(level.settings.values.quality), 0, 2)
	calm = level.settings.values.reduced == true
	var points: int = POINT_BUDGET[quality]
	if walls.multimesh.instance_count != points:
		walls.multimesh.instance_count = points
		wall_at = 0
		wall_shown = 0
	var flesh: int = BODY_POINTS[quality]
	if bodies.multimesh.instance_count != flesh:
		bodies.multimesh.instance_count = flesh
		body_at = 0
		body_shown = 0
	if puffs.multimesh.instance_count != PUFF_BUDGET[quality]:
		puffs.multimesh.instance_count = PUFF_BUDGET[quality]
		puff_at = 0
	if finds.multimesh.instance_count != FIND_BUDGET[quality]:
		finds.multimesh.instance_count = FIND_BUDGET[quality]
		find_at = 0
	per_tick = maxi(1, int(ceil(float(RAY_BUDGET[quality]) / (60.0 / CLICK_RATE))))
	field_material.set_shader_parameter("base_level", BASE_CALM if calm else BASE_LEVEL)
	field_material.set_shader_parameter("front_level", 0.5 if calm else 1.0)
	field_material.set_shader_parameter("grain_amount", 0.0 if calm else 1.0)
	field_material.set_shader_parameter("jitter_amount", 0.0 if calm else 1.0)
	mark_material.set_shader_parameter("gain", 1.8 if calm else 1.0)
	# The cloud carries most of the picture now that the clicks are slow.
	wall_material.set_shader_parameter("gain", 0.95)
	body_material.set_shader_parameter("gain", 1.6)
	puff_material.set_shader_parameter("gain", 1.0)
	find_material.set_shader_parameter("gain", 1.35)
	var height: float = maxf(1.0, level.get_viewport().get_visible_rect().size.y)
	var span := 2.0 * tan(deg_to_rad(camera.fov * 0.5)) * POINT_PIXELS / height
	for material in [wall_material, body_material, puff_material, find_material, mark_material]:
		material.set_shader_parameter("point_scale", span)
		material.set_shader_parameter("point_min", 0.010)
		material.set_shader_parameter("point_max", 0.085)

# --- The clicks ---------------------------------------------------------------------

## Called from the driver's physics step.
func advance(delta: float, hunting: bool) -> void:
	if not enabled: return
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

## One click: a shell leaves its head and a budget of rays goes with it.
func click(hunting: bool) -> void:
	clicks += 1
	var breath := 1.0 if calm else 1.0 + sin(clock * TAU * BREATH_RATE) * BREATH_DEPTH
	var jitter := 1.0 if calm else 1.0 + rng.randf_range(-CLICK_JITTER, CLICK_JITTER)
	var interval := (1.0 / CLICK_RATE) * breath * jitter
	last_interval = interval
	next_click = clock + interval
	var from: Vector3 = creature.global_position + Vector3(0, driver.EYE.y, 0)
	var reach: float = REACH
	shells.push_back([from, clock, rng.randf_range(SWEEP_MIN, 1.0), reach])
	while shells.size() > SWEEPS: shells.pop_front()
	var budget: int = RAY_BUDGET[quality]
	if budget > 0:
		# Whatever is left of the previous click is dropped: the reading is
		# always the newest one, and the cost per tick stays bounded.
		pending = spray(budget)
		pending_from = from
		pending_at = clock
		pending_reach = reach
	if clicks % BODY_EVERY == 0: stamp_bodies(from, reach)
	bloom_contacts()

## Directions for one click: a Fibonacci sphere, turned by a fresh angle every
## time so successive clicks fill in each other's gaps, with most of the rays
## pushed into a cone ahead of where it is looking.
func spray(count: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	var forward: Vector3 = -camera.global_basis.z
	var frame := Basis()
	if absf(forward.dot(Vector3.UP)) < 0.98:
		frame = Basis.looking_at(forward, Vector3.UP)
	var turn := rng.randf() * TAU
	var golden := PI * (3.0 - sqrt(5.0))
	var ahead := int(count * FORWARD_BIAS)
	for i in count:
		var into_cone := i < ahead
		var span: float = cos(FORWARD_CONE) if into_cone else -1.0
		var reach_i: int = ahead if into_cone else count - ahead
		var index: int = i if into_cone else i - ahead
		var z := 1.0 - (1.0 - span) * (float(index) + 0.5) / float(maxi(reach_i, 1))
		var radius := sqrt(maxf(0.0, 1.0 - z * z))
		var angle := golden * float(i) + turn
		var direction := Vector3(cos(angle) * radius, sin(angle) * radius, -z)
		# A touch of scatter on every ray: the bare spiral lands on a floor in
		# visible rings, and the point of this is stipple, not moire.
		direction += Vector3(rng.randfn(0.0, 0.012), rng.randfn(0.0, 0.012), rng.randfn(0.0, 0.012))
		out.append(frame * direction.normalized())
	return out

## The rays of the click in flight, spread over the frames until the next one
## so the cost never lands in a single tick. The origin is frozen at emission:
## the shell left from there, wherever the body has walked to since.
func cast_pending() -> void:
	if pending.is_empty() or not is_instance_valid(level.hotel): return
	var space: PhysicsDirectSpaceState3D = creature.get_world_3d().direct_space_state
	var count := mini(per_tick, pending.size())
	for i in count:
		var direction: Vector3 = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
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
	if BODY_POINTS[quality] == 0: return
	var shape := PackedVector3Array()
	for body in level.survivors():
		if not is_instance_valid(body) or not level.survivor_active(body): continue
		if body.global_position.distance_to(creature.global_position) > REACH: continue
		if not creature.sees(body): continue
		shape.clear()
		BODY.points(body, from, shape)
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
	else:
		index = body_at
		body_at = (body_at + 1) % multi.instance_count
		body_shown = mini(body_shown + 1, multi.instance_count)
	multi.set_instance_transform(index, Transform3D(Basis(), point))
	multi.set_instance_custom_data(index, Color(at, span, kind, energy))
	written += 1

## A ball of grains scattered around a point, each one carrying its distance
## from the centre so the shader blooms them outward from it.
func scatter(cloud: MultiMeshInstance3D, centre: Vector3, radius: float, count: int, kind: float, energy: float, at: float) -> void:
	for i in count:
		var direction := Vector3(rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0), rng.randfn(0.0, 1.0))
		if direction.length() < 0.001: direction = Vector3.UP
		# Cube root of a uniform draw fills the ball evenly instead of clumping
		# everything at the middle.
		var span: float = radius * pow(rng.randf(), 0.34)
		var point: Vector3 = centre + direction.normalized() * span
		write(cloud, point, span, kind, energy, at)

## Every noise heard since the last click becomes a puff hanging where it was
## heard. A survivor walking leaves one every stride, which is the trail.
func bloom_contacts() -> void:
	if PUFF_BUDGET[quality] == 0: return
	var seconds := Time.get_ticks_msec() / 1000.0
	for mark in driver.heard:
		if int(mark.get("id", 0)) <= puffed: continue
		puffed = int(mark.id)
		if seconds - mark.time > CONTACT_LIFE: continue
		# Loud and blunt noises make a wider, denser cloud than a crouched step.
		var loud: float = mark.strength
		var radius: float = (0.30 + 1.25 * loud) * KINDS.SPREAD[int(mark.kind)]
		var count: int = int(PUFF_POINTS[quality] * (0.45 + 0.55 * loud))
		# The further the sound travelled, the vaguer the place it hangs in.
		radius *= 1.0 + mark.get("blur", 0.0) * 1.6
		scatter(puffs, mark.at, radius, count, 0.0, 0.35 + 0.65 * loud, clock - (seconds - mark.time))

# --- Uniforms -----------------------------------------------------------------------

func push_uniforms() -> void:
	# The fade is never fixed by hand: it follows the measured write rate, so a
	# point always finishes going out before the ring buffer reaches it again.
	var span: float = minf(MEMORY, float(maxi(wall_shown, 1)) / maxf(write_rate, 1.0))
	wall_material.set_shader_parameter("age_limit", span)
	body_material.set_shader_parameter("age_limit", BODY_FADE)
	var shell_points := PackedVector4Array()
	var shell_power := PackedVector4Array()
	for i in SWEEPS:
		if i < shells.size():
			var shell: Array = shells[shells.size() - 1 - i]
			shell_points.append(Vector4(shell[0].x, shell[0].y, shell[0].z, shell[1]))
			shell_power.append(Vector4(shell[2], shell[3], 0.0, 0.0))
		else:
			shell_points.append(Vector4.ZERO)
			shell_power.append(Vector4.ZERO)
	field_material.set_shader_parameter("sweep_count", mini(shells.size(), SWEEPS))
	field_material.set_shader_parameter("sweeps", shell_points)
	field_material.set_shader_parameter("sweep_power", shell_power)
	puff_material.set_shader_parameter("age_limit", PUFF_LIFE)
	find_material.set_shader_parameter("age_limit", FIND_LIFE)
	field_material.set_shader_parameter("glare", torch_glare())
	for material in [field_material, wall_material, body_material, puff_material, find_material, mark_material, self_material]:
		material.set_shader_parameter("now", clock)
		material.set_shader_parameter("shriek", shriek)

## The fluorescent battens it can hear buzzing, as a faint puff under each one,
## refreshed slowly. Free texture: world_audio already routes them from its own
## camera, so this costs no network and no extra listening.
func bloom_hums() -> void:
	if PUFF_BUDGET[quality] == 0 or not is_instance_valid(level.world_audio): return
	for hum in level.world_audio.hums:
		if not is_instance_valid(hum) or not hum.playing: continue
		scatter(puffs, hum.global_position, 0.5, maxi(4, PUFF_POINTS[quality] / 5), 0.0, HUM_LEVEL, clock)

## What the shriek came back with: a dense cloud over each survivor it found,
## which stays for seconds after the cry itself has died away. This is what the
## shriek is worth, not the red.
func mark_found(points: PackedVector3Array) -> void:
	if FIND_BUDGET[quality] == 0: return
	for point in points:
		scatter(finds, point, 0.55, FIND_POINTS[quality], 1.0, 1.0, clock)

## A survivor's lit torch pointed this way. It cannot see light, but the beam
## disturbs the reading from that direction: turning it off still matters.
func torch_glare() -> Vector3:
	var lit = creature.lit_by_torch()
	if lit == null or not is_instance_valid(camera): return Vector3.ZERO
	var local: Vector3 = camera.global_basis.inverse() * (lit.global_position - camera.global_position)
	var aim := Vector2(local.x, -local.y)
	if aim.length() < 0.001: aim = Vector2(0.0, -1.0)
	aim = aim.normalized()
	var near := clampf(1.0 - local.length() / 45.0, 0.0, 1.0)
	return Vector3(aim.x, aim.y, near)

## It shrieked: the reading floods red, and one enormous shell goes out with it.
func flash_shriek() -> void:
	shriek_hold = SHRIEK_HOLD
	var from: Vector3 = creature.global_position + Vector3(0, driver.EYE.y, 0)
	shells.push_back([from, clock, 2.0, REACH])
	while shells.size() > SWEEPS: shells.pop_front()
