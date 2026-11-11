extends RefCounted
## Dust out of a false ceiling as it really comes (the author: "el polvillo y
## las partículas se ven pésimas, cero realistas"): not a round cloud, not
## beads. Where a tile is stepped on or moved, dust runs down in THREADS from
## the joints of the grid, each a line of soft streaks drawn along their fall
## that thins, stops, and frays at the bottom as it slows; a VEIL of fine dust
## sinks under it and hangs for seconds, drawn by the volumetric fog where that
## is on (so the torch's beam and the tubes cut it, with their shadows) and by
## big faint sprites where it is not; a few FLAKES of plaster, flat and pale,
## come down turning and swaying. A tile pushed open gives a third thread and
## CRUMBS that drop like stones, bounce and lie on the floor a while. The
## particles scatter the light that reaches them (ceiling_dust.gdshader): they
## shine in a beam or under a tube and are not there in the dark. Everything
## frees itself; far less at the lowest quality (graphics_presets "dust" 0).
## Her voice calls fall() where she goes through or over a tile and seep() as
## she crawls the plenum; her lies call fall() too.
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")
const SHADER := preload("res://game/enemies/lurker/ceiling_dust.gdshader")
const VEIL_SHADER := preload("res://game/enemies/lurker/ceiling_dust_veil.gdshader")

## A thread's streaks (metres): width, and length along the fall.
const STREAK_WIDTH := Vector2(0.004, 0.007)
const STREAK_LENGTH := Vector2(0.07, 0.12)
## The veil's sprites where there is no volumetric fog, and the plaster.
const PUFF := Vector2(0.1, 0.3)
const FLAKE := Vector2(0.02, 0.04)
const CRUMB := Vector2(0.02, 0.04)
## The plaster and mineral fibre of the tiles: pale, a little warm.
const DUST_COLOUR := Color(0.86, 0.83, 0.76)
const FLAKE_COLOUR := Color(0.93, 0.91, 0.86)
const CRUMB_COLOUR := Color(0.88, 0.86, 0.8)
## Particles at full quality: the thickest thread's streaks (the others have
## less), the veil's sprites without fog, flakes and crumbs of an opened tile.
const THREAD_GRAINS := 600
const PUFFS := 40
const FLAKES := 8
const CRUMBS := 6
## The threads of a fall, thickest first: their share of the grains and width.
const HEFT := [1.0, 0.6, 0.35]
## Fog veils alive at once; a new one hurries the oldest away.
const MAX_VEILS := 3
## A veil at its thickest (fog density), full size (metres) and its life.
const VEIL_DENSITY := 3.0
const VEIL_SIZE := Vector3(1.4, 2.2, 1.4)
const VEIL_LIFE := 9.0
## How much more light the veil sends back than it stops: the torch lights the
## fog at 0.35 of its strength, and a veil only as bright as the wall behind it
## was not there. No emission, so out of the light it is still nothing.
const VEIL_GLOW := 16.0

static var soft_tex: ImageTexture
static var flake_tex: ImageTexture
static var veil_noise: NoiseTexture3D
static var veils: Array = []

## A tile moved or crossed at `point` (on the ceiling's plane): threads down
## its joints, a veil and flakes; `opened` (pushed open from above, or shut
## again), a third thread and crumbs.
static func fall(level, point: Vector3, opened := true) -> void:
	if level == null or not is_instance_valid(level): return
	var q := share(level)
	var half: float = OFFICE.TILE * 0.5
	var edges: Array = [Vector3(half, 0, 0), Vector3(-half, 0, 0), Vector3(0, 0, half), Vector3(0, 0, -half)]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(point.snapped(Vector3.ONE * 0.01))
	var threads: int = 3 if opened else 2
	for i in threads:
		var edge: Vector3 = edges[(i + rng.randi_range(0, 3)) % 4]
		var along := Vector3(edge.z, 0, edge.x).normalized() * rng.randf_range(-half, half) * 0.8
		var heft: float = HEFT[i]
		thread(level, point + edge + along, rng.randf_range(0.6, 1.4) * (0.5 + heft * 0.5), int(THREAD_GRAINS * heft * q), heft)
	haze(level, point, 1.0 if opened else 0.7, q)
	flakes(level, point, int(FLAKES * q * (1.0 if opened else 0.5)))
	if opened: crumbs(level, point, int(CRUMBS * q) + 1)

## Her weight on the tiles as she crawls the plenum over `point`: a thin
## thread from the nearest joint, a lesser veil and now and then a flake.
static func seep(level, point: Vector3, ceiling_y: float) -> void:
	if level == null or not is_instance_valid(level): return
	var q := share(level)
	var tile: float = OFFICE.TILE
	var jx: float = roundf(point.x / tile) * tile
	var jz: float = roundf(point.z / tile) * tile
	var at := Vector3(jx, ceiling_y, point.z) if absf(point.x - jx) < absf(point.z - jz) else Vector3(point.x, ceiling_y, jz)
	thread(level, at, randf_range(0.5, 0.9), int(THREAD_GRAINS * 0.5 * q), 0.5)
	haze(level, at, 0.35, q)
	if randf() < 0.4: flakes(level, at, 1 + int(q))

## The share of every amount at this quality.
static func share(level) -> float:
	var hotel = level.get("hotel")
	var preset = hotel.get("preset") if hotel != null else null
	if preset is Dictionary and int((preset as Dictionary).get("dust", 1)) <= 0: return 0.35
	return 1.0

## A run from one point of a joint, `seconds` long and `heft` thick (1 the
## thickest): streaks along their fall that slow, shorten and fray at the end.
static func thread(level, at: Vector3, seconds: float, amount: int, heft: float) -> void:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.004, 0.002, 0.004) * (0.5 + heft)
	p.direction = Vector3.DOWN
	p.spread = 1.5
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0, -1.8, 0)
	# Free fall, then braking hard: the air takes it and it frays.
	p.damping_min = 5.0
	p.damping_max = 7.0
	p.damping_curve = curve([Vector2(0.0, 0.0), Vector2(0.5, 0.0), Vector2(0.8, 1.0), Vector2(1.0, 1.0)])
	p.turbulence_enabled = true
	p.turbulence_noise_strength = 1.0
	p.turbulence_noise_scale = 1.6
	p.turbulence_influence_min = 0.06
	p.turbulence_influence_max = 0.12
	p.turbulence_influence_over_life = curve([Vector2(0.0, 0.03), Vector2(0.5, 0.08), Vector2(1.0, 1.0)])
	p.particle_flag_align_y = true
	p.use_scale_3d = true
	var wide: float = 0.7 + 0.6 * heft
	p.scale_3d_min = Vector3(STREAK_WIDTH.x * wide, STREAK_LENGTH.x, 1.0)
	p.scale_3d_max = Vector3(STREAK_WIDTH.y * wide, STREAK_LENGTH.y, 1.0)
	# Wider and shorter as it slows: a streak is how far it moved.
	var shape := CurveXYZTexture.new()
	shape.curve_x = curve([Vector2(0.0, 0.6), Vector2(0.6, 0.7), Vector2(1.0, 1.0)]).curve
	shape.curve_y = curve([Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(1.0, 0.15)]).curve
	shape.curve_z = curve([Vector2(0.0, 1.0), Vector2(1.0, 1.0)]).curve
	p.scale_curve = shape
	fade(p, DUST_COLOUR, 0.12, 0.03, 0.55)
	var life := 1.6
	var dust := emitter(level, at, p, soft_tex, false, maxi(amount, 12), life, false, 0.0, {"axial": true, "scatter": 7.0, "min_pixels": 2.5, "twinkle": 0.0})
	# Stepped every frame: at the default 30 a second the streaks came out in clumps.
	dust.fixed_fps = 0
	# It thins as it runs out, then stops.
	var tween: Tween = dust.create_tween()
	tween.tween_property(dust, "amount_ratio", 0.0, seconds).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): dust.emitting = false)
	free_after(dust, seconds + life + 0.5)

## The fine dust that hangs under a fall: a veil of volumetric fog where that
## is drawn (forward_plus, fog on and not reduced), big faint sprites where not.
static func haze(level, at: Vector3, strength: float, q: float) -> void:
	var environment = level.get("environment")
	if environment is Environment and (environment as Environment).volumetric_fog_enabled:
		veil(level, at, strength)
	else:
		puffs(level, at, int(PUFFS * strength * q))

## A fog volume under `at` that drops out of the ceiling in half a second,
## sinks slowly toward the floor, spreads and is gone in about nine; its
## wisps are drawn by ceiling_dust_veil.gdshader.
static func veil(level, at: Vector3, strength: float) -> void:
	veils = veils.filter(func(v): return is_instance_valid(v))
	while veils.size() >= MAX_VEILS:
		var old: FogVolume = veils.pop_front()
		(old.get_meta("tween") as Tween).kill()
		var hurry := old.create_tween()
		hurry.tween_property(old.material, "shader_parameter/density", 0.0, 0.6)
		hurry.tween_callback(old.queue_free)
	if veil_noise == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.15
		noise.fractal_octaves = 3
		veil_noise = NoiseTexture3D.new()
		veil_noise.width = 32
		veil_noise.height = 32
		veil_noise.depth = 32
		veil_noise.seamless = true
		veil_noise.noise = noise
	var m := ShaderMaterial.new()
	m.shader = VEIL_SHADER
	m.set_shader_parameter("noise_tex", veil_noise)
	m.set_shader_parameter("density", 0.0)
	m.set_shader_parameter("albedo", Vector3(DUST_COLOUR.r, DUST_COLOUR.g, DUST_COLOUR.b) * VEIL_GLOW)
	var fog := FogVolume.new()
	fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	fog.material = m
	var full: Vector3 = VEIL_SIZE * Vector3(sqrt(strength), strength, sqrt(strength))
	fog.size = full * 0.3
	level.add_child(fog)
	fog.global_position = at + Vector3.DOWN * full.y * 0.15
	adopt(level, fog)
	veils.append(fog)
	var tween := fog.create_tween()
	fog.set_meta("tween", tween)
	# Out of the ceiling: thick in half a second, its full height in one and a half.
	tween.set_parallel(true)
	tween.tween_property(m, "shader_parameter/density", VEIL_DENSITY * sqrt(strength), 0.5)
	tween.tween_property(fog, "size", full, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(fog, "position:y", fog.position.y - full.y * 0.4, 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Where the eye is, every frame, for the veil to clear round it.
	var follow := func(_t: float) -> void:
		var camera := fog.get_viewport().get_camera_3d()
		if camera != null: m.set_shader_parameter("eye", camera.global_position)
	tween.tween_method(follow, 0.0, 1.0, 1.5)
	# Then it sinks, spreads and thins away.
	tween.chain().tween_method(follow, 0.0, 1.0, VEIL_LIFE - 1.5)
	tween.tween_property(fog, "position:y", fog.position.y - full.y * 0.4 - 0.6, VEIL_LIFE - 1.5)
	tween.tween_property(fog, "size", full * Vector3(1.4, 1.0, 1.4), VEIL_LIFE - 1.5)
	tween.tween_property(m, "shader_parameter/density", 0.0, VEIL_LIFE - 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(fog.queue_free)

## The veil without fog: a few big, faint, soft sprites that sink and spread.
static func puffs(level, at: Vector3, amount: int) -> void:
	if amount <= 0: return
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.25, 0.2, 0.25)
	p.direction = Vector3.DOWN
	p.spread = 40.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.gravity = Vector3(0, -0.03, 0)
	p.damping_min = 0.02
	p.damping_max = 0.05
	p.turbulence_enabled = true
	p.turbulence_noise_strength = 0.5
	p.turbulence_noise_scale = 3.0
	p.turbulence_influence_min = 0.01
	p.turbulence_influence_max = 0.04
	p.scale_min = PUFF.x
	p.scale_max = PUFF.y
	p.scale_curve = curve([Vector2(0.0, 0.5), Vector2(1.0, 1.0)])
	fade(p, DUST_COLOUR, 0.045, 0.1, 0.45)
	var life := VEIL_LIFE
	var cloud := emitter(level, at + Vector3.DOWN * 0.5, p, soft_tex, true, amount, life, true, 0.85, {"scatter": 2.0, "min_pixels": 0.0, "twinkle": 0.0})
	free_after(cloud, life + 0.5)

## Pale flakes of plaster, flat and ragged, turning and swaying down.
static func flakes(level, at: Vector3, amount: int) -> void:
	if amount <= 0: return
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(OFFICE.TILE * 0.5, 0.005, OFFICE.TILE * 0.5)
	p.direction = Vector3.DOWN
	p.spread = 30.0
	# Held to a flutter of under half a metre a second: braking against their
	# weight left them hanging under the ceiling like stars.
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0, -1.5, 0)
	p.velocity_limit_curve = curve([Vector2(0.0, 0.45), Vector2(1.0, 0.45)])
	p.turbulence_enabled = true
	p.turbulence_noise_strength = 1.0
	p.turbulence_noise_scale = 1.2
	p.turbulence_influence_min = 0.04
	p.turbulence_influence_max = 0.1
	p.use_rotation_3d = true
	p.rotation_3d_min = Vector3(-180, -180, -180)
	p.rotation_3d_max = Vector3(180, 180, 180)
	p.use_rotation_velocity_3d = true
	p.rotation_velocity_3d_min = Vector3(-200, -120, -200)
	p.rotation_velocity_3d_max = Vector3(200, 120, 200)
	# Chips longer than wide, so they do not read as round sparks.
	p.use_scale_3d = true
	p.scale_3d_min = Vector3(FLAKE.x, FLAKE.x * 0.55, 1.0)
	p.scale_3d_max = Vector3(FLAKE.y, FLAKE.y * 0.7, 1.0)
	fade(p, FLAKE_COLOUR, 1.0, 0.02, 0.85)
	var life := 4.5
	var bits := emitter(level, at, p, flake_tex, false, amount, life, true, 0.6, {"scatter": 2.5, "min_pixels": 0.0, "twinkle": 0.0})
	free_after(bits, life + 0.5)

## Crumbs of tile that drop like stones, bounce and lie on the floor a while:
## little lit blocks, not sprites.
static func crumbs(level, at: Vector3, amount: int) -> void:
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(OFFICE.TILE * 0.5, 0.005, OFFICE.TILE * 0.5)
	p.direction = Vector3.DOWN
	p.spread = 20.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0, -9.8, 0)
	p.use_rotation_3d = true
	p.rotation_3d_min = Vector3(-180, -180, -180)
	p.rotation_3d_max = Vector3(180, 180, 180)
	p.use_rotation_velocity_3d = true
	p.rotation_velocity_3d_min = Vector3(-300, -300, -300)
	p.rotation_velocity_3d_max = Vector3(300, 300, 300)
	p.use_scale_3d = true
	p.scale_3d_min = Vector3(CRUMB.x, CRUMB.x * 0.3, CRUMB.x * 0.8)
	p.scale_3d_max = Vector3(CRUMB.y, CRUMB.y * 0.4, CRUMB.y * 0.9)
	p.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	p.collision_bounce = 0.3
	p.collision_friction = 0.8
	p.color = CRUMB_COLOUR
	var life := 10.0
	var bits := GPUParticles3D.new()
	bits.amount = maxi(amount, 1)
	bits.lifetime = life
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.randomness = 0.5
	bits.process_material = p
	bits.collision_base_size = 0.02
	bits.visibility_aabb = AABB(Vector3(-3, -5, -3), Vector3(6, 6, 6))
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mesh.material = m
	bits.draw_pass_1 = mesh
	level.add_child(bits)
	bits.global_position = at
	adopt(level, bits)
	# The floor under the tile, for them to land on.
	var space: PhysicsDirectSpaceState3D = (level as Node3D).get_world_3d().direct_space_state if level is Node3D else null
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.DOWN * 0.1, at + Vector3.DOWN * 5.0, 1)) if space != null else {}
	if not hit.is_empty():
		var ground := GPUParticlesCollisionBox3D.new()
		ground.size = Vector3(4.0, 0.2, 4.0)
		bits.add_child(ground)
		ground.global_position = (hit.position as Vector3) + Vector3.DOWN * 0.1
	bits.emitting = true
	free_after(bits, life + 0.5)

static func curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for point in points: c.add_point(point)
	var tex := CurveTexture.new()
	tex.curve = c
	return tex

## Its colour at `peak` alpha, faded in over `rise` of its life and out from
## `out` (an alpha curve: a colour ramp left the alpha out).
static func fade(p: ParticleProcessMaterial, colour: Color, peak: float, rise: float, out: float) -> void:
	p.color = Color(colour.r, colour.g, colour.b, peak)
	var points: Array = [Vector2(0.0, 0.0 if rise > 0.0 else 1.0)]
	if rise > 0.0: points.append(Vector2(rise, 1.0))
	points.append(Vector2(out, 1.0))
	points.append(Vector2(1.0, 0.0))
	p.alpha_curve = curve(points)

## One emitter of dust at `at`: unit quads scaled by the process to the size
## the dust is, in the scattering shader, facing the camera, flat and turning,
## or (look "axial") streaked along their fall.
static func emitter(level, at: Vector3, process: ParticleProcessMaterial, tex: Texture2D, facing: bool, amount: int, life: float, one_shot: bool, burst: float, look: Dictionary) -> GPUParticles3D:
	textures()
	var parts := GPUParticles3D.new()
	parts.amount = maxi(amount, 1)
	parts.lifetime = life
	parts.one_shot = one_shot
	parts.explosiveness = burst
	parts.randomness = 0.5
	parts.process_material = process
	parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parts.visibility_aabb = AABB(Vector3(-3, -5, -3), Vector3(6, 6, 6))
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("shape", tex if tex != null else soft_tex)
	m.set_shader_parameter("billboard", facing)
	for key in look: m.set_shader_parameter(key, look[key])
	mesh.material = m
	parts.draw_pass_1 = mesh
	level.add_child(parts)
	parts.global_position = at
	adopt(level, parts)
	parts.emitting = true
	return parts

static func adopt(level, node: Node3D) -> void:
	var hotel = level.get("hotel")
	if hotel != null and hotel.has_method("adopt"): hotel.adopt(node)

static func free_after(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds).timeout.connect(func(): if is_instance_valid(node): node.queue_free())

## The shapes, made once in code: a soft speck and a ragged flake.
static func textures() -> void:
	if soft_tex != null: return
	soft_tex = blot(32, 0.9, 0.2, 11)
	flake_tex = blot(32, 0.08, 0.35, 23)

## A white shape on clear: round but for `wobble` of its radius, its edge
## `edge` of its radius soft.
static func blot(size: int, edge: float, wobble: float, seed_value: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var waves: Array = []
	for k in range(2, 7): waves.append([k, rng.randf_range(0.2, 1.0) / float(k - 1), rng.randf_range(0.0, TAU)])
	var image := Image.create_empty(size, size, true, Image.FORMAT_RGBA8)
	var c := (float(size) - 1.0) * 0.5
	for y in size:
		for x in size:
			var dx := (float(x) - c) / c
			var dy := (float(y) - c) / c
			var d := Vector2(dx, dy).length()
			var a := atan2(dy, dx)
			var bump := 0.0
			for w in waves: bump += float(w[1]) * sin(float(w[0]) * a + float(w[2]))
			var rim := 1.0 - wobble * (0.5 + 0.5 * clampf(bump, -1.0, 1.0))
			var alpha := clampf((rim - d) / maxf(edge * rim, 1e-3), 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha * alpha * (3.0 - 2.0 * alpha)))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
