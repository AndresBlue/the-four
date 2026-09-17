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

## Nominal clicks per second: the rate the reading refreshes at.
const CLICK_RATE := 15.0
## Never a metronome. Each interval is stretched or squeezed, breathes slowly
## underneath, and tightens while it is hunting.
const CLICK_JITTER := 0.22
const BREATH_RATE := 0.14
const BREATH_DEPTH := 0.25
const HUNT_SCALE := 0.62
## One click in four comes back as a full sweep; the rest are weaker shells, so
## what you feel is a swell every few tenths over a constant shimmer.
const SWEEP_STRONG_EVERY := 4
## Not the speed of sound: slow enough to watch a front cross a room, fast
## enough that the shells sit about three metres apart.
const WAVE_SPEED := 42.0
## Useful range. Under world_audio.ROUTE_LIMIT (42) and far under the 66 m at
## which update_visibility hides rooms, so no wall it should show is missing.
const REACH := 40.0
## Depth contour spacing, about one band per stride of the hotel.
const BAND_STEP := 1.5
## Longest a remembered point lives; the real limit follows the ring buffer.
const MEMORY := 6.0
## Rays per click, points remembered, body points: off / medium / high.
const RAY_BUDGET := [0, 128, 224]
const POINT_BUDGET := [0, 8000, 16000]
const BODY_POINTS := [0, 256, 512]
## Bodies are sampled every third click and fade fast: a survivor is a live
## reading, never a memory to be followed.
const BODY_EVERY := 3
const BODY_FADE := 0.6
## Seven rays in ten go into a forward cone; the rest keep the room's shape.
const FORWARD_BIAS := 0.7
const FORWARD_CONE := 0.85
## Shells and sound contacts the shader carries at once. The per-pixel loops
## are the only superlinear cost in the whole view.
const SWEEPS := 6
const CONTACTS := 12
## A contact lasts as long as the old noise rings did.
const CONTACT_LIFE := 1.6
## Its own shriek floods the reading red, then drains.
const SHRIEK_HOLD := 4.0
const SHRIEK_RISE := 6.0
const SHRIEK_FALL := 0.55
## Doors and wardrobes it simply knows are there, faded out by this distance.
const LANDMARK_NEAR := 12.0
const LANDMARK_REACH := 20.0
const LANDMARK_LEVEL := 0.10
## A point's radius on screen, in pixels of the rendered image.
const POINT_PIXELS := 3.6
## Residual level between clicks. Low on purpose: raise it and the creature
## simply sees, and the whole thing stops being echolocation.
const BASE_LEVEL := 0.012
const BASE_CALM := 0.045
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
var marks: MultiMeshInstance3D
var wall_material: ShaderMaterial
var body_material: ShaderMaterial
var mark_material: ShaderMaterial
var self_material: ShaderMaterial

## Ring buffer write positions and how many points each cloud has ever shown.
var wall_at := 0
var wall_shown := 0
var body_at := 0
var body_shown := 0
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
	self_material.render_priority = 124
	# Its own body is a presence, not the picture: kept well under the reading
	# so it never blinds the middle of the frame.
	self_material.set_shader_parameter("gain", 0.12)
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
	walls = make_cloud("EchoWalls", 122, 0.35)
	bodies = make_cloud("EchoBodies", 123, 0.0)
	marks = make_cloud("EchoLandmarks", 121, 0.55)
	wall_material = walls.material_override as ShaderMaterial
	body_material = bodies.material_override as ShaderMaterial
	mark_material = marks.material_override as ShaderMaterial
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
	per_tick = maxi(1, int(ceil(float(RAY_BUDGET[quality]) / (60.0 / CLICK_RATE))))
	field_material.set_shader_parameter("base_level", BASE_CALM if calm else BASE_LEVEL)
	field_material.set_shader_parameter("front_level", 0.5 if calm else 1.0)
	field_material.set_shader_parameter("grain_amount", 0.0 if calm else 1.0)
	field_material.set_shader_parameter("jitter_amount", 0.0 if calm else 1.0)
	mark_material.set_shader_parameter("gain", 1.8 if calm else 1.0)
	wall_material.set_shader_parameter("gain", 0.55)
	body_material.set_shader_parameter("gain", 1.2)
	var height: float = maxf(1.0, level.get_viewport().get_visible_rect().size.y)
	var span := 2.0 * tan(deg_to_rad(camera.fov * 0.5)) * POINT_PIXELS / height
	for material in [wall_material, body_material, mark_material]:
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
	var interval := (1.0 / CLICK_RATE) * breath * jitter * (HUNT_SCALE if hunting else 1.0)
	last_interval = interval
	next_click = clock + interval
	var strong := clicks % SWEEP_STRONG_EVERY == 0
	var from: Vector3 = creature.global_position + Vector3(0, driver.EYE.y, 0)
	var reach: float = REACH if strong else REACH * 0.55
	shells.push_back([from, clock, 1.0 if strong else 0.42, reach])
	while shells.size() > SWEEPS: shells.pop_front()
	var budget: int = RAY_BUDGET[quality]
	if budget > 0:
		# Whatever is left of the previous click is dropped: the reading is
		# always the newest one, and the cost per tick stays bounded.
		pending = spray(budget)
		pending_from = from
		pending_at = clock
		pending_reach = reach
	if clicks % BODY_EVERY == 0: stamp_bodies(from)

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
		out.append(frame * Vector3(cos(angle) * radius, sin(angle) * radius, -z))
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
func stamp_bodies(from: Vector3) -> void:
	if BODY_POINTS[quality] == 0: return
	var shape := PackedVector3Array()
	for body in level.survivors():
		if not is_instance_valid(body) or not level.survivor_active(body): continue
		if body.global_position.distance_to(creature.global_position) > REACH: continue
		if not creature.sees(body): continue
		shape.clear()
		BODY.points(body, shape)
		var span := from.distance_to(body.global_position)
		for point in shape:
			write(bodies, point, span, 1.0, 1.0, clock)

## One point into a cloud's ring buffer.
func write(cloud: MultiMeshInstance3D, point: Vector3, span: float, kind: float, energy: float, at: float) -> void:
	var multi: MultiMesh = cloud.multimesh
	if multi.instance_count == 0: return
	var index: int
	if cloud == walls:
		index = wall_at
		wall_at = (wall_at + 1) % multi.instance_count
		wall_shown = mini(wall_shown + 1, multi.instance_count)
	else:
		index = body_at
		body_at = (body_at + 1) % multi.instance_count
		body_shown = mini(body_shown + 1, multi.instance_count)
	multi.set_instance_transform(index, Transform3D(Basis(), point))
	multi.set_instance_custom_data(index, Color(at, span, kind, energy))
	written += 1

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
	var heard := gather_contacts()
	var contact_points := PackedVector4Array()
	var contact_power := PackedVector4Array()
	for i in CONTACTS:
		if i < heard.size():
			var one: Dictionary = heard[i]
			var at: Vector3 = one.at
			contact_points.append(Vector4(at.x, at.y, at.z, one.emit))
			contact_power.append(Vector4(one.strength, float(one.kind), one.muffle, one.spread))
		else:
			contact_points.append(Vector4.ZERO)
			contact_power.append(Vector4.ZERO)
	field_material.set_shader_parameter("contact_count", mini(heard.size(), CONTACTS))
	field_material.set_shader_parameter("contacts", contact_points)
	field_material.set_shader_parameter("contact_power", contact_power)
	field_material.set_shader_parameter("glare", torch_glare())
	for material in [field_material, wall_material, body_material, mark_material, self_material]:
		material.set_shader_parameter("now", clock)
		material.set_shader_parameter("shriek", shriek)

## Everything it is hearing right now, loudest first: the noises the machine in
## charge confirmed, what its shriek came back with, and the lamps it can hear
## buzzing. Culled here so the shader's per-pixel loop stays short.
func gather_contacts() -> Array:
	var out: Array = []
	var seconds := Time.get_ticks_msec() / 1000.0
	for mark in driver.heard:
		var age: float = seconds - mark.time
		if age > CONTACT_LIFE: continue
		out.append({
			"at": mark.at, "emit": clock - age, "strength": mark.strength,
			"kind": mark.kind, "muffle": mark.muffle,
			"spread": KINDS.SPREAD[mark.kind] * (0.6 + mark.get("blur", 0.0) * 1.4),
		})
	for mark in driver.revealed:
		var age: float = seconds - mark.time
		out.append({"at": mark.point, "emit": clock - age, "strength": 1.4, "kind": 0, "muffle": 0.0, "spread": 1.0})
	if is_instance_valid(level.world_audio):
		for hum in level.world_audio.hums:
			if not is_instance_valid(hum) or not hum.playing: continue
			out.append({"at": hum.global_position, "emit": clock - fposmod(clock, 1.6), "strength": HUM_LEVEL, "kind": KINDS.Kind.HUM, "muffle": 0.4, "spread": 0.5})
	out.sort_custom(func(a, b): return a.strength > b.strength)
	if out.size() > CONTACTS: out.resize(CONTACTS)
	return out

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
