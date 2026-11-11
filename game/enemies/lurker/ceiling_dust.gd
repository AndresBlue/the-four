extends RefCounted
## Dust out of a false ceiling as it really comes (the author: "el polvillo y
## las partículas se ven pésimas"): not a round cloud. Where a tile is stepped
## on or moved, fine dust runs down in THREADS from the joints of the grid for a
## second or two, thinning and breaking off; a few FLAKES of tile fibre, flat
## and ragged, come down slowly turning and swaying; and a HAZE so faint it is
## only seen in a beam drifts and takes its time to go. A tile pushed open
## gives a bigger fall from its four edges and CRUMBS that drop like stones,
## bounce and lie on the floor a while. All of it lit by the scene, so it is
## only there where a lamp or a torch is on it, soft against what it meets and
## faded near the lens. GPU particles; every emitter frees itself; fewer at
## the lowest quality (graphics_presets "dust" 0). Her voice calls fall()
## where she goes through or over a tile, and seep() as she crawls the plenum;
## her lies call fall() too.
const OFFICE := preload("res://game/floors/palettes/office_palette.gd")

## Sizes (metres): motes, flakes, crumbs; and the haze's patches. The motes
## twice real dust's: at 720p under the camcorder's filter real ones are lost.
const MOTE := Vector2(0.004, 0.008)
const FLAKE := Vector2(0.015, 0.035)
const CRUMB := Vector2(0.02, 0.05)
const HAZE := Vector2(0.3, 0.6)
## Their colours: the tiles' mineral fibre, a little warm.
const DUST_COLOUR := Color(0.78, 0.75, 0.68)
const FLAKE_COLOUR := Color(0.83, 0.8, 0.74)
const CRUMB_COLOUR := Color(0.62, 0.6, 0.55)

static var mote_tex: ImageTexture
static var flake_tex: ImageTexture
static var haze_tex: ImageTexture

## A tile moved or crossed at `point` (on the ceiling's plane): threads down
## its joints, flakes and haze; `opened` (pushed open from above, or shut
## again), the bigger fall from all four edges and crumbs.
static func fall(level, point: Vector3, opened := true) -> void:
	if level == null or not is_instance_valid(level): return
	textures()
	var q := share(level)
	var half: float = OFFICE.TILE * 0.5
	var edges: Array = [Vector3(half, 0, 0), Vector3(-half, 0, 0), Vector3(0, 0, half), Vector3(0, 0, -half)]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(point.snapped(Vector3.ONE * 0.01))
	var threads: int = 4 if opened else 2
	for i in threads:
		var edge: Vector3 = edges[(i + rng.randi_range(0, 3)) % 4]
		var along := Vector3(edge.z, 0, edge.x).normalized() * rng.randf_range(-half, half) * 0.8
		thread(level, point + edge + along, rng.randf_range(1.0, 1.8) * (1.3 if opened else 1.0), int(160 * q * (1.4 if opened else 1.0)))
	flakes(level, point, int((22 if opened else 8) * q))
	haze(level, point, 4 if opened else 3)
	if opened: crumbs(level, point, int(7 * q) + 1)

## Her weight on the tiles as she crawls the plenum over `point`: a thread
## from the nearest joint, and now and then a flake.
static func seep(level, point: Vector3, ceiling_y: float) -> void:
	if level == null or not is_instance_valid(level): return
	textures()
	var q := share(level)
	var tile: float = OFFICE.TILE
	# The nearest joint of the grid under her.
	var jx: float = roundf(point.x / tile) * tile
	var jz: float = roundf(point.z / tile) * tile
	var at := Vector3(jx, ceiling_y, point.z) if absf(point.x - jx) < absf(point.z - jz) else Vector3(point.x, ceiling_y, jz)
	thread(level, at, randf_range(0.6, 1.2), int(50 * q))
	if randf() < 0.4: flakes(level, at, 1 + int(2 * q))

## The share of every amount at this quality: the lowest has no floating dust
## (graphics_presets "dust" 0), so a little less of hers too.
static func share(level) -> float:
	var hotel = level.get("hotel")
	var preset = hotel.get("preset") if hotel != null else null
	if preset is Dictionary and int((preset as Dictionary).get("dust", 1)) <= 0: return 0.45
	return 1.0

## A thin run of dust from one point of a joint, `seconds` long, thinning out.
static func thread(level, at: Vector3, seconds: float, amount: int) -> void:
	textures()
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.006, 0.002, 0.006)
	p.direction = Vector3.DOWN
	p.spread = 4.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.2
	p.gravity = Vector3(0, -1.6, 0)
	p.damping_min = 0.6
	p.damping_max = 1.2
	p.turbulence_enabled = true
	p.turbulence_noise_strength = 0.4
	p.turbulence_noise_scale = 2.0
	p.turbulence_influence_min = 0.01
	p.turbulence_influence_max = 0.05
	p.scale_min = MOTE.x
	p.scale_max = MOTE.y
	fade(p, DUST_COLOUR, 0.9, 0.05, 0.75)
	var life := 2.2
	var dust := emitter(level, at, p, mote_tex, true, maxi(amount, 8), life, false)
	# The run thins out and breaks off.
	var tween: Tween = dust.create_tween()
	tween.tween_property(dust, "amount_ratio", 0.0, seconds).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): dust.emitting = false)
	free_after(dust, seconds + life + 0.5)

## Ragged flakes of fibre, flat, tumbling and swaying down.
static func flakes(level, at: Vector3, amount: int) -> void:
	textures()
	if amount <= 0: return
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(OFFICE.TILE * 0.5, 0.005, OFFICE.TILE * 0.5)
	p.direction = Vector3.DOWN
	p.spread = 30.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.15
	p.gravity = Vector3(0, -0.7, 0)
	p.damping_min = 0.9
	p.damping_max = 1.4
	p.turbulence_enabled = true
	p.turbulence_noise_strength = 1.2
	p.turbulence_noise_scale = 1.2
	p.turbulence_influence_min = 0.08
	p.turbulence_influence_max = 0.2
	p.use_rotation_3d = true
	p.rotation_3d_min = Vector3(-180, -180, -180)
	p.rotation_3d_max = Vector3(180, 180, 180)
	p.use_rotation_velocity_3d = true
	p.rotation_velocity_3d_min = Vector3(-220, -120, -220)
	p.rotation_velocity_3d_max = Vector3(220, 120, 220)
	p.scale_min = FLAKE.x
	p.scale_max = FLAKE.y
	fade(p, FLAKE_COLOUR, 1.0, 0.02, 0.85)
	var life := 4.0
	var bits := emitter(level, at, p, flake_tex, false, amount, life, true, 0.6)
	free_after(bits, life + 0.5)

## A haze so faint it only shows in a beam, drifting and slow to go.
static func haze(level, at: Vector3, amount: int) -> void:
	textures()
	var p := ParticleProcessMaterial.new()
	p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(OFFICE.TILE * 0.4, 0.05, OFFICE.TILE * 0.4)
	p.direction = Vector3.DOWN
	p.spread = 60.0
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.08
	p.gravity = Vector3(0, -0.04, 0)
	p.turbulence_enabled = true
	p.turbulence_noise_strength = 0.6
	p.turbulence_noise_scale = 3.0
	p.turbulence_influence_min = 0.02
	p.turbulence_influence_max = 0.06
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_min = HAZE.x
	p.scale_max = HAZE.y
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	p.scale_curve = grow_tex
	fade(p, DUST_COLOUR, 0.09, 0.3, 0.5)
	var life := 5.0
	var cloud := emitter(level, at + Vector3.DOWN * 0.15, p, haze_tex, true, amount, life, true, 0.5)
	free_after(cloud, life + 0.5)

## Crumbs of tile that drop like stones, bounce and lie on the floor a while.
static func crumbs(level, at: Vector3, amount: int) -> void:
	textures()
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
	p.scale_min = CRUMB.x
	p.scale_max = CRUMB.y
	p.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	p.collision_bounce = 0.25
	p.collision_friction = 0.8
	fade(p, CRUMB_COLOUR, 1.0, 0.0, 0.85)
	var life := 6.0
	var bits := emitter(level, at, p, flake_tex, false, amount, life, true, 1.0)
	bits.collision_base_size = 0.02
	# The floor under the tile, for them to land on.
	var space: PhysicsDirectSpaceState3D = (level as Node3D).get_world_3d().direct_space_state if level is Node3D else null
	var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.DOWN * 0.1, at + Vector3.DOWN * 5.0, 1)) if space != null else {}
	if not hit.is_empty():
		var ground := GPUParticlesCollisionBox3D.new()
		ground.size = Vector3(4.0, 0.2, 4.0)
		bits.add_child(ground)
		ground.global_position = (hit.position as Vector3) + Vector3.DOWN * 0.1
	free_after(bits, life + 0.5)

## Its colour at `peak` alpha, faded in over `rise` of its life and out from
## `out` (the alpha curve; a colour ramp left the haze opaque and the motes
## unseen).
static func fade(p: ParticleProcessMaterial, colour: Color, peak: float, rise: float, out: float) -> void:
	p.color = Color(colour.r, colour.g, colour.b, peak)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0 if rise > 0.0 else 1.0))
	if rise > 0.0: curve.add_point(Vector2(rise, 1.0))
	curve.add_point(Vector2(out, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	p.alpha_curve = tex

## One emitter at `at`: its quads `tex`-shaped, lit, soft where they meet a
## surface and faded near the lens; facing the camera (`facing`) or flat and
## tumbling.
static func emitter(level, at: Vector3, process: ParticleProcessMaterial, tex: Texture2D, facing: bool, amount: int, life: float, one_shot: bool, burst := 0.0) -> GPUParticles3D:
	var parts := GPUParticles3D.new()
	parts.amount = maxi(amount, 1)
	parts.lifetime = life
	parts.one_shot = one_shot
	parts.explosiveness = burst
	parts.randomness = 0.5
	parts.process_material = process
	parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parts.visibility_aabb = AABB(Vector3(-3, -5, -3), Vector3(6, 6, 6))
	# The quad made the size the dust is, the process only varying it about
	# that: with a unit quad and the size left to the process's scale every
	# speck was drawn a metre wide.
	var middle: float = (process.scale_min + process.scale_max) * 0.5
	process.scale_min /= middle
	process.scale_max /= middle
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * middle
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.roughness = 1.0
	m.metallic_specular = 0.1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if facing else BaseMaterial3D.BILLBOARD_DISABLED
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.12
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	m.distance_fade_min_distance = 0.15
	m.distance_fade_max_distance = 0.45
	mesh.material = m
	parts.draw_pass_1 = mesh
	level.add_child(parts)
	parts.global_position = at
	var hotel = level.get("hotel")
	if hotel != null and hotel.has_method("adopt"): hotel.adopt(parts)
	parts.emitting = true
	return parts

static func free_after(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds).timeout.connect(func(): if is_instance_valid(node): node.queue_free())

## The shapes, made once in code: a mote a little out of round, a ragged
## flake with a hard edge, and the haze a soft uneven patch.
static func textures() -> void:
	if mote_tex != null: return
	mote_tex = blot(16, 0.45, 0.15, 11)
	flake_tex = blot(32, 0.08, 0.35, 23)
	haze_tex = blot(64, 0.9, 0.3, 37)

## A white shape on clear: round but for `wobble` of its radius, its edge
## `edge` of its radius soft.
static func blot(size: int, edge: float, wobble: float, seed_value: int) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var waves: Array = []
	for k in range(2, 7): waves.append([k, rng.randf_range(0.2, 1.0) / float(k - 1), rng.randf_range(0.0, TAU)])
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
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
	return ImageTexture.create_from_image(image)
