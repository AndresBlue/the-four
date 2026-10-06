extends Node
## How the floor is seen and heard through the camcorder: the environment
## and its HDR stage, the lens and the zoom, the interlaced fields, the
## graphics settings applied to all of it, the screen cues (the lost signal,
## the static, the glitch), the level's own sound players and the menu music.
## Split out of hotel_main.gd, which owns it (`level.rig`); the level keeps
## delegates of what the network, the bots and the tests reach through it.
const LOOK := preload("res://game/presentation/camcorder_look.gd")
const WARMUP := preload("res://game/presentation/shader_warmup.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var level

var ambient_energy := 0.16

const CAMERA_EFFECT := preload("res://game/presentation/camera/camcorder_effect.gd")

const BLUR_EFFECT := preload("res://game/presentation/camera/motion_blur_effect.gd")

## How deep the volumetric fog reaches when lamps light it.
const LIT_FOG_LENGTH := 14.0

var blur_effect: CompositorEffect

## The camcorder's lens and sensor layer (lens.gdshader), under the OSD.
var lens_material: ShaderMaterial

var lens_layer: CanvasLayer

## The camcorder's HDR stage (iris, video knee, CCD smear) as a compositor
## effect on the world environment, and the tonemapper it replaces.
var camera_effect: CompositorEffect

var authored_tone := {}

func build_environment() -> void:
	level.environment = level.get_node("Presentation/WorldEnvironment").environment
	ambient_energy = level.environment.ambient_light_energy
	level.post_material = level.get_node("Presentation/Analog/Screen").material
	lens_material = level.get_node("Presentation/Lens/Screen").material
	lens_layer = level.get_node("Presentation/Lens")
	level.camcorder = level.get_node("Presentation/Camcorder")
	get_viewport().size_changed.connect(func(): apply_lens(hunter_seat(), level.settings.values.reduced))
	authored_tone = {"mode": level.environment.tonemap_mode, "exposure": level.environment.tonemap_exposure, "glow": level.environment.glow_hdr_threshold, "fog_length": level.environment.volumetric_fog_length}
	# Only where there is a RenderingDevice to run it (not headless, not
	# Compatibility): elsewhere the game keeps AgX.
	if RenderingServer.get_rendering_device() != null:
		camera_effect = CAMERA_EFFECT.new()
		# The light smears while it is being exposed: blur first, then the camera.
		blur_effect = BLUR_EFFECT.new()
		var compositor := Compositor.new()
		compositor.compositor_effects = [blur_effect, camera_effect]
		level.get_node("Presentation/WorldEnvironment").compositor = compositor

## The camera's HDR stage on or off, with the tonemapper that goes with it.
func apply_camera(preset: Dictionary, hunter: bool) -> void:
	var on := is_instance_valid(camera_effect) and not hunter
	if is_instance_valid(camera_effect):
		camera_effect.enabled = on
		camera_effect.smear = preset.ccd_smear
		camera_effect.glare = preset.glare
		# Reduced effects: no smearing of the picture while turning.
		blur_effect.samples = 0 if level.settings.values.reduced else preset.motion_blur
		blur_effect.enabled = on and blur_effect.samples > 0
	# The camera's own video knee does the tonemapping; Godot's stays linear.
	# Its highlights end just under 1, so the bloom starts lower.
	level.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR if on else authored_tone.mode
	level.environment.tonemap_exposure = 1.0 if on else authored_tone.exposure
	level.environment.glow_hdr_threshold = 0.9 if on else authored_tone.glow
	# The sensor's noise grows with the gain the iris had to add, which the
	# lens reads straight from the camera stage on the GPU.
	if is_instance_valid(lens_material): lens_material.set_shader_parameter("gain_map", camera_effect.exposure_texture if on else null)

func camera_cut() -> void:
	if is_instance_valid(camera_effect): camera_effect.reset = true
	if is_instance_valid(blur_effect): blur_effect.has_previous = false
	field_camera = null

## Interlaced fields (lens.gdshader, field_shift): how far the picture moved in
## the 1/60 s between a frame's two fields, from the camera's turn since the
## last frame. Only fast turns comb: under FIELD_FROM pixels (of a 1080-line
## picture) nothing shows, from FIELD_TO the full offset, never past
## FIELD_MAX. Reduced effects: none.
const FIELD_TIME := 1.0 / 60.0

const FIELD_FROM := 12.0

const FIELD_TO := 30.0

const FIELD_MAX := 48.0

var field_camera: Camera3D

var field_basis := Basis.IDENTITY

func update_fields(delta: float) -> void:
	if not is_instance_valid(lens_material): return
	var camera := get_viewport().get_camera_3d()
	var shift := Vector2.ZERO
	if camera != null and camera == field_camera and delta > 0.0 and not level.settings.values.reduced:
		# Last frame's view centre, seen from this frame's view.
		var before: Vector3 = camera.global_basis.orthonormalized().inverse() * -field_basis.z
		if before.z < -0.01:
			var projection := camera.get_camera_projection()
			var moved := Vector2(projection.x.x * before.x, -projection.y.y * before.y) / -before.z * 0.5 * FIELD_TIME / delta
			var size := get_viewport().get_visible_rect().size
			var pixels := Vector2(moved.x * size.x / maxf(size.y, 1.0), moved.y).length() * 1080.0
			shift = moved * smoothstep(FIELD_FROM, FIELD_TO, pixels) * minf(1.0, FIELD_MAX / maxf(pixels, 0.001))
	field_camera = camera
	if camera != null: field_basis = camera.global_basis.orthonormalized()
	lens_material.set_shader_parameter("field_shift", shift)

## The lens remaps a picture rendered wider than the view (camcorder_look.gd):
## the cameras that film the hotel render at the lens's field of view.
func apply_lens(hunter: bool, reduced: bool) -> void:
	if not is_instance_valid(lens_material): return
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	# The observer looks through no lens either: the barrel bent the plan.
	# Nor does the lowest preset (graphics_presets.gd "lens").
	lens_layer.visible = LOOK.lens and not hunter and not level.observer
	update_zoom_lens()
	lens_material.set_shader_parameter("noise", 0.0 if reduced else level.settings.values.grain)
	lens_material.set_shader_parameter("chromatic", 0.0 if reduced else level.settings.values.chromatic)
	lens_material.set_shader_parameter("vignette", 0.0 if reduced else 0.45)
	lens_material.set_shader_parameter("detail", 0.0 if reduced else 0.35)
	if hunter:
		# The creature's view has no lens and no zoom; leaving that seat the
		# lens is written again.
		level.player.camera.fov = LOOK.VIEW_FOV
		if is_instance_valid(level.watch_camera): level.watch_camera.fov = LOOK.VIEW_FOV
		lens_zoom = -1.0

## The lens as the zoom stands (hotel_player.zoom): the field of view it sees,
## how wide the picture is rendered and how much the barrel bends it. A long
## lens bends far less, so the remap follows the zoom (camcorder_look.gd).
var lens_zoom := -1.0

var lens_aspect := -1.0

func update_zoom_lens() -> void:
	if hunter_seat() or not is_instance_valid(level.player) or not is_instance_valid(lens_material): return
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	# Written only when it moves: setting a camera's field of view rebuilds
	# its projection, every frame, for nothing.
	# The zoom is the living player's own: over the menu, the opening scene or
	# a teammate's shoulder the lens is wide, whatever it was left at.
	var zoom: float = level.player.zoom if level.session.state in [level.session.State.PLAYING, level.session.State.PAUSED] and level.local_alive() else 1.0
	if is_equal_approx(zoom, lens_zoom) and is_equal_approx(aspect, lens_aspect): return
	lens_zoom = zoom
	lens_aspect = aspect
	var barrel: float = LOOK.barrel_for(zoom) if LOOK.lens else 0.0
	var design: float = LOOK.zoom_fov(zoom)
	lens_material.set_shader_parameter("barrel", barrel)
	lens_material.set_shader_parameter("scale", LOOK.corner_scale(aspect, barrel))
	var fov: float = LOOK.render_fov(aspect, design, barrel)
	level.player.camera.fov = fov
	if is_instance_valid(level.watch_camera): level.watch_camera.fov = fov

## This machine drives The Locust: the hunter's seat online, or the local
## preview. Its screen is the acoustic image, not the lit hotel.
## This machine is drawing the creature's acoustic reading instead of the lit
## hotel: the hunter, or the observer while it is looking through its ears.
func hunter_seat() -> bool:
	if level.observer and level.observer_view != null and level.observer_view.echoing: return true
	return is_instance_valid(level.net) and level.match_net.local_is_locust()

## Whether what this machine draws is that reading. A hunter the room lets see
## like a person (the rule "plain_sight") sits in the creature's seat and
## looks at the lit hotel.
func echo_seat() -> bool:
	if not hunter_seat(): return false
	return level.observer or level.rule("plain_sight") == 0

## Every value that changes with the quality setting (graphics_presets.gd).
const PRESETS := preload("res://game/presentation/graphics_presets.gd")

const COMPAT_SHADOW_ATLAS := 4096

## The torch's source size as built (player.tscn), for presets without penumbra.
var torch_size := -1.0

## Whether the preset in force culls by occlusion (graphics_presets.gd).
var occlusion := true

## How many shadows the atlas's first quarter is cut into, as the project has
## it. With static_light the torch is the only light that casts, and it gets
## that quarter to itself.
var atlas_first := -1

func apply_settings() -> void:
	if not is_instance_valid(level.environment): return
	var preset: Dictionary = PRESETS.of(level.settings.values.quality, level.settings.values)
	# Before any set is built (title, intro, floor): the size of the scans.
	level.GEOMETRY.small_maps = preset.small_maps
	level.GEOMETRY.no_maps = preset.surface_detail < 0.5
	# The acoustic view replaces the lit image entirely, so none of this would
	# ever be seen; switching it off is what pays for its own screen pass.
	var hunter := echo_seat()
	level.environment.ssao_enabled = preset.ssao >= 0 and not hunter
	if preset.ssao >= 0: RenderingServer.environment_set_ssao_quality(preset.ssao, preset.ssao_half, ProjectSettings.get_setting("rendering/environment/ssao/adaptive_target"), ProjectSettings.get_setting("rendering/environment/ssao/blur_passes"), ProjectSettings.get_setting("rendering/environment/ssao/fadeout_from"), ProjectSettings.get_setting("rendering/environment/ssao/fadeout_to"))
	level.environment.ssil_enabled = preset.ssil >= 0 and not hunter
	if preset.ssil >= 0: RenderingServer.environment_set_ssil_quality(preset.ssil, preset.ssil_half, ProjectSettings.get_setting("rendering/environment/ssil/adaptive_target"), ProjectSettings.get_setting("rendering/environment/ssil/blur_passes"), ProjectSettings.get_setting("rendering/environment/ssil/fadeout_from"), ProjectSettings.get_setting("rendering/environment/ssil/fadeout_to"))
	level.environment.ssr_enabled = preset.ssr_steps > 0 and not hunter
	if preset.ssr_steps > 0:
		level.environment.ssr_max_steps = preset.ssr_steps
		RenderingServer.environment_set_ssr_roughness_quality(preset.ssr_roughness)
	# SDFGI leaks light through the 18 cm hotel walls; bounce light is screen-space only.
	level.environment.sdfgi_enabled = false
	level.environment.glow_enabled = preset.glow and not hunter
	RenderingServer.environment_glow_set_use_bicubic_upscale(preset.glow_bicubic)
	RenderingServer.gi_set_use_half_resolution(preset.bounce_half)
	# Ambient light reaches every surface whether or not a lamp does, so for the
	# creature it has to go too: anything still lit leaks the seen hotel into a
	# reading that is supposed to be made of echoes.
	level.environment.ambient_light_energy = 0.0 if hunter else ambient_energy
	level.environment.fog_enabled = not hunter
	level.environment.volumetric_fog_enabled = preset.fog_size > 0 and not level.settings.values.reduced and not hunter
	# Lamps that light the fog (preset lamp_fog) need short cells, or a room's
	# glow would spread into the next one through the wall (docs/REALISM.md,
	# trial 7).
	level.environment.volumetric_fog_length = LIT_FOG_LENGTH if preset.lamp_fog else authored_tone.fog_length
	if preset.fog_size > 0:
		RenderingServer.environment_set_volumetric_fog_volume_size(preset.fog_size, preset.fog_depth)
		RenderingServer.environment_set_volumetric_fog_filter_active(preset.fog_filter)
	var viewport := get_viewport()
	# Every lamp shares one shadow atlas. At 4096 the rooms further off got
	# cells so coarse that shadows came out as saw-teeth along door frames and
	# a lamp's shadow bias grew past a 7 cm leaf: light through shut doors.
	# No preset goes under 4096. And none goes over it on Compatibility: there
	# an 8192 atlas broke the torch's shadow into wide dark diagonal bands on
	# every wall ten metres off and more (Alto and Ultra; Bajo and Medio, at
	# 4096, were clean). Seen with tools/capture/torch_capture.gd, long_* shots.
	var compatibility: bool = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	viewport.positional_shadow_atlas_size = mini(preset.shadow_atlas, COMPAT_SHADOW_ATLAS) if compatibility else preset.shadow_atlas
	# And its depth in 32 bits there. The bands are the torch shadowing the wall
	# it lights, where 16 bits cannot tell the wall's depth from its own: at 9
	# and 12 m with the bias low they come back on a 16-bit atlas and not on a
	# 32-bit one, and 0.3/4.0 only just cleared them here -- on another card
	# they were seen at those very distances. Some 32 MB more at 4096.
	viewport.positional_shadow_atlas_16_bits = not compatibility
	if atlas_first < 0: atlas_first = viewport.get_positional_shadow_atlas_quadrant_subdiv(0)
	viewport.set_positional_shadow_atlas_quadrant_subdiv(0, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1 if preset.static_light else atlas_first)
	# Soft shadow filtering is paid per pixel for every shadowed lamp on it.
	RenderingServer.positional_soft_shadow_filter_set_quality(preset.shadow_filter)
	viewport.msaa_3d = preset.msaa
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if preset.get("smaa", false) and not hunter else Viewport.SCREEN_SPACE_AA_FXAA if preset.fxaa and not hunter else Viewport.SCREEN_SPACE_AA_DISABLED
	# Temporal accumulation has nothing to work with here: the echo field writes
	# POSITION itself (no motion vectors) and the point cloud is restamped
	# fifteen times a second, so TAA smears it into paste.
	viewport.use_taa = preset.taa and not hunter
	viewport.mesh_lod_threshold = preset.lod_threshold
	occlusion = preset.occlusion
	viewport.anisotropic_filtering_level = preset.anisotropy
	viewport.use_debanding = preset.debanding
	RenderingServer.screen_space_roughness_limiter_set_active(preset.roughness_limiter, ProjectSettings.get_setting("rendering/anti_aliasing/screen_space_roughness_limiter/amount"), ProjectSettings.get_setting("rendering/anti_aliasing/screen_space_roughness_limiter/limit"))
	# Octaves of every procedural surface (surface.gdshaderinc) and the tape
	# filter's chroma reads.
	RenderingServer.global_shader_parameter_set("surface_detail", preset.surface_detail)
	level.post_material.set_shader_parameter("chroma_taps", preset.chroma_taps)
	level.post_material.set_shader_parameter("lite", preset.tape_lite)
	LOOK.lens = preset.lens
	var reduced: bool = level.settings.values.reduced
	# The camcorder's lens and sensor (lens.gdshader) take the grain, the colour
	# fringes and the vignette; the tape filter keeps the tape. The creature's
	# acoustic view has no lens, and neither has a preset without the lens
	# pass: there the tape filter's own versions are used.
	var lensless: bool = hunter or not preset.lens
	for key in ["vhs", "scanlines"]: level.post_material.set_shader_parameter(key, 0.0 if reduced else level.settings.values[key])
	level.post_material.set_shader_parameter("grain", 0.0 if reduced or not lensless else level.settings.values.grain)
	level.post_material.set_shader_parameter("chromatic", 0.0 if reduced or not hunter else level.settings.values.chromatic * 0.5)
	level.post_material.set_shader_parameter("vignette", 0.0 if reduced or not lensless else 0.45)
	apply_lens(hunter, reduced)
	apply_camera(preset, hunter)
	# The warm tape cast would break the monochrome reading.
	level.post_material.set_shader_parameter("tint", Vector3.ONE if hunter else Vector3(1.02, 1.0, 0.9))
	if level.settings.values.reduced:
		level.post_material.set_shader_parameter("enclosure", 0.0)
		level.post_material.set_shader_parameter("threat_glitch", 0.0)
	level.player.torch.shadow_enabled = level.settings.values.shadows
	if torch_size < 0.0: torch_size = level.player.torch.light_size
	level.player.torch.light_size = torch_size * minf(preset.penumbra, 1.0)
	level.player.set_character(level.settings.values.character)
	# Your own body, walking, re-renders the shadow of every lamp round it.
	level.player.avatar.set_body_shadow(preset.body_shadow)
	level.player.autofocus = preset.autofocus and not hunter
	configure_hotel()
	if is_instance_valid(level.locust) and level.locust.driver != null and is_instance_valid(level.locust.driver.echo): level.locust.driver.echo.apply_quality()

## The floor's share of the settings: preset, reduced effects, creature's view.
func configure_hotel() -> void:
	if not is_instance_valid(level.hotel): return
	level.hotel.reduced = level.settings.values.reduced
	level.hotel.echo_view = echo_seat()
	level.hotel.apply_quality(PRESETS.of(level.settings.values.quality, level.settings.values))

## Wardrobe enclosure, strike glitch and lost signal on the analog filter.
## The first two are off with reduced effects; the picture going is not an
## effect, it is how a victim is told it died, so it stays (milder).
var enclosure := 0.0

var glitch := 0.0

## Seconds of lost picture left for the local victim, and how far gone it is.
var lost_signal := 0.0

var static_level := 0.0

func update_screen_cues(delta: float) -> void:
	var wanted_enclosure: float = (1.0 - level.player.peek * 0.8) if level.player.hidden and level.session.state == level.session.State.PLAYING else 0.0
	enclosure = move_toward(enclosure, wanted_enclosure, delta * 2.0)
	var striking: bool = level.winding_up_near()
	glitch = 1.0 if striking else move_toward(glitch, 0.0, delta * 4.0)
	lost_signal = maxf(0.0, lost_signal - delta)
	var mine: bool = not level.execution.is_empty() and int(level.execution.seat) == level.player.slot
	var dying: bool = mine and float(level.execution.time) >= level.SIGNAL_TIME
	var riding_now: float = level.lifts.ride_static()
	update_ride_hiss(riding_now)
	var wanted_static: float = 1.0 if dying or lost_signal > 0.0 else riding_now
	# Straight to static once the arm has landed: the picture does not fade,
	# it goes. Coming back (a new floor) it clears gently.
	# Gone at once when the view is already somebody else's camera; otherwise
	# it comes in hard and clears gently.
	if wanted_static <= 0.0 and not level.local_alive() and level.execution.is_empty(): static_level = 0.0
	elif riding_now > 0.0 or not level.lifts.boarding.is_empty(): static_level = wanted_static
	else: static_level = move_toward(static_level, wanted_static, delta * (14.0 if wanted_static > static_level else 1.6))
	level.post_material.set_shader_parameter("signal_loss", static_level * (0.75 if level.settings.values.reduced else 1.0))
	# The arm arriving: black spreading from where its hand is on screen.
	var arm := 0.0
	if mine and float(level.execution.time) >= level.ARM_TIME and static_level < 0.9:
		arm = clampf((float(level.execution.time) - level.ARM_TIME) / level.ARM_SWING, 0.0, 1.0)
		level.post_material.set_shader_parameter("strike_point", level.strike_on_screen())
	level.post_material.set_shader_parameter("strike_fill", arm)
	level.camcorder.signal_lost = static_level > 0.35 or arm > 0.25
	# The dead channel stops with the snow, not a moment later.
	if is_instance_valid(level.static_sound) and level.static_sound.playing and static_level < 0.05: level.static_sound.stop()
	if level.settings.values.reduced: return
	level.post_material.set_shader_parameter("enclosure", enclosure)
	level.post_material.set_shader_parameter("threat_glitch", glitch)
	# The tape frays with the mind: the picture drags and the colours start to
	# run. With no bar anywhere, this is what says the meter is there at all.
	if not hunter_seat():
		# Only over the floor being played: the last floor's mind frayed the
		# tape of the opening scene of the next.
		var frayed: float = clampf(1.0 - level.player.sanity / level.sanity.SANITY_UNEASY + level.sanity.glitch, 0.0, 1.0) if level.session.state in [level.session.State.PLAYING, level.session.State.PAUSED, level.session.State.FAILED] else 0.0
		level.post_material.set_shader_parameter("vhs", level.settings.values.vhs * (1.0 + frayed * 1.6))
		level.post_material.set_shader_parameter("chromatic", level.settings.values.chromatic * frayed * 0.7)

## A lift ride has no sound of its own yet (the recording is still to come):
## until then its snow is heard softly, following the picture -- full as the
## doors shut and open, low under the card -- instead of a silence that read
## as the game hanging.
const RIDE_HISS_DB := -20.0

func update_ride_hiss(amount: float) -> void:
	if not is_instance_valid(level.ride_hiss): return
	if amount <= 0.02 or not level.world_audio.enabled:
		if level.ride_hiss.playing: level.ride_hiss.stop()
		return
	level.ride_hiss.volume_db = RIDE_HISS_DB + linear_to_db(amount)
	if not level.ride_hiss.playing: level.ride_hiss.play()

func build_audio() -> void:
	# Handling a document: a local sound, not a noise the creature can hear.
	level.paper_sound = AudioStreamPlayer.new()
	level.paper_sound.name = "Paper"
	level.paper_sound.bus = "Effects"
	level.paper_sound.volume_db = -8.0
	level.paper_sound.stream = load("res://assets/audio/sfx/paper/paper.ogg")
	level.add_child(level.paper_sound)
	# The scream of being caught: not a sound in the room, a sound in your head.
	level.scream_sound = AudioStreamPlayer.new()
	level.scream_sound.name = "Scream"
	level.scream_sound.bus = "Threat"
	level.scream_sound.volume_db = 0.0
	level.scream_sound.stream = load(level.SCREAM)
	level.add_child(level.scream_sound)
	# The blow and the dead channel that follows it, in the victim's own ears.
	level.blow_sound = AudioStreamPlayer.new()
	level.blow_sound.name = "Blow"
	level.blow_sound.bus = "Threat"
	level.blow_sound.volume_db = -1.0
	level.blow_sound.stream = load(level.KILL_BLOW)
	level.add_child(level.blow_sound)
	level.static_sound = AudioStreamPlayer.new()
	level.static_sound.name = "DeadChannel"
	level.static_sound.bus = "Effects"
	level.static_sound.volume_db = -2.0
	level.static_sound.stream = load(level.DEAD_CHANNEL)
	level.add_child(level.static_sound)
	level.ride_hiss = AudioStreamPlayer.new()
	level.ride_hiss.name = "RideHiss"
	level.ride_hiss.bus = "Effects"
	level.ride_hiss.volume_db = -80.0
	level.ride_hiss.stream = preload("res://game/audio/world_audio.gd").loop_stream(load("res://assets/audio/intro/tv_static.wav"))
	level.add_child(level.ride_hiss)
	level.ambience = AudioStreamPlayer.new()
	level.ambience.name = "AmbientLoop"
	level.ambience.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.ambience.bus = "Ambience"
	level.ambience.volume_db = -17
	var ambient_stream := load("res://assets/audio/sfx/ambience/dark_hotel.wav").duplicate() as AudioStreamWAV
	ambient_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	ambient_stream.loop_begin = 0
	ambient_stream.loop_end = int(ambient_stream.get_length() * ambient_stream.mix_rate)
	level.ambience.stream = ambient_stream
	level.add_child(level.ambience)
	level.theme = AudioStreamPlayer.new()
	level.theme.name = "Music"
	level.theme.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.theme.bus = "Music"
	level.theme.volume_db = -24
	level.theme.stream = load("res://assets/audio/the_four_theme.mp3").duplicate()
	level.theme.stream.loop = true
	level.add_child(level.theme)
	level.ventilation = AudioStreamPlayer3D.new()
	level.ventilation.name = "Ventilation"
	level.ventilation.process_mode = Node.PROCESS_MODE_PAUSABLE
	level.ventilation.bus = "Ambience"
	level.ventilation.volume_db = -19
	level.ventilation.max_distance = 16
	level.ventilation.area_mask = level.world_audio.ACOUSTIC_MASK
	level.ventilation.stream = preload("res://game/audio/world_audio.gd").loop_stream(load("res://assets/audio/hotel/ambience.wav"))
	level.add_child(level.ventilation)
	level.menu_music = AudioStreamPlayer.new()
	level.menu_music.name = "MenuMusic"
	level.menu_music.process_mode = Node.PROCESS_MODE_ALWAYS
	level.menu_music.bus = "Music"
	level.menu_music.volume_db = -12
	level.menu_music.stream = load("res://assets/audio/the_four_theme.mp3").duplicate()
	level.menu_music.stream.loop = true
	level.add_child(level.menu_music)

## How much of the music is left with the power (1 on, 0 cut), and how fast it
## goes and comes back.
var music_power := 1.0

const MUSIC_CUT := 0.12

const MUSIC_RETURN := 2.0

func update_menu_scene(_delta: float) -> void:
	var in_menu: bool = level.session.state == level.session.State.MENU
	var audible: bool = in_menu and level.world_audio.enabled
	if audible and not level.menu_music.playing: level.menu_music.play()
	elif not audible and level.menu_music.playing: level.menu_music.stop()
