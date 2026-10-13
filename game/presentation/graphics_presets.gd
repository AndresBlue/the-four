extends RefCounted
## Graphics presets: every value that changes with the quality setting lives
## here and nowhere else. hotel_main.apply_settings() applies the renderer and
## the screen effects, hotel_geometry.apply_quality() the lamps, rooms and
## props, echo_view.apply_quality() the creature's reading. The saved setting
## is an index into PRESETS; files saved with three qualities keep their
## meaning (0 Bajo, 1 Medio, 2 Alto), 3 is Ultra and 4 is Muy bajo, which was
## added last and is listed first (ORDER).
##
## The same in every preset, on purpose (docs/PERFORMANCE.md, "Presets"):
## - no lamp ever lights a room that is not its own. From Bajo up every lamp
##   in view keeps its shadow -- one without shines through walls and shut
##   doors, so shadows are cheapened, never dropped. Muy bajo has no lamp
##   shadows at all: there each lamp only lights what belongs to its room
##   (static_light), and the torch is the one light that casts;
## - no ambient light and near-black depth fog: dark rooms are black;
## - door numbers and signs, the red beacon, door seals and dark rooms;
## - the tape filter sliders, reduced effects and the Sombras switch, which
##   are the player's own settings.
const NAMES := ["Bajo", "Medio", "Alto", "Ultra", "Muy bajo"]
const LOW := 0
const MEDIUM := 1
const HIGH := 2
const ULTRA := 3
const VERY_LOW := 4
## The presets from the cheapest to the dearest, as the menu lists them.
const ORDER := [VERY_LOW, LOW, MEDIUM, HIGH, ULTRA]

## Keys:
## scale                 the 3D render scale the preset was designed and
##                       measured at. Choosing a preset does not set it: the
##                       scale is the player's own setting. A first start on
##                       an integrated GPU begins with it, and the benchmark
##                       and the capture tools use it
##                       (settings_service.set_designed()).
## upscaler              how that picture is brought up to the window while
##                       the player's own choice is "auto", which is the
##                       default (UPSCALERS; always bilinear in Compatibility,
##                       and at native scale). A choice made by hand stays
##                       whatever the preset. FSR 2.2 is the dearest thing a
##                       modest GPU can be asked for: it and its history were
##                       half of Bajo's whole frame on the stand-in for an
##                       integrated one (PERFORMANCE.md, 10).
## msaa, fxaa, taa       anti-aliasing (TAA never for the creature's view).
## roughness_limiter     specular anti-aliasing on shiny surfaces.
## shadow_atlas          positional shadow atlas size. Never under 4096 while
##                       the lamps cast: a coarser cell grows the bias past a
##                       7 cm door leaf. With static_light only torches are in
##                       it, each with a big cell of its own.
## shadow_filter         soft shadow filter (RenderingServer.ShadowQuality);
##                       hard on Muy bajo: one read a pixel.
## static_light          the hotel's lamps cast no shadow and each lights only
##                       what belongs to its own room, by render layers
##                       (hotel_geometry.gd, "Light that stays in its room"):
##                       nothing of theirs is ever drawn again, and no light
##                       comes through a doorway either. The torch still casts.
## penumbra              lamp source size, times the size built (PCSS: a
##                       penumbra that widens away from the caster). 0: plain
##                       PCF, the cheapest. Ultra's 2.5 is about the size of a
##                       frosted dome. It was on Soft High for it; under TAA
##                       Soft Medium draws the same penumbrae, still or
##                       panning, for 2.3 ms less at 1080p (PERFORMANCE.md). The torch never grows past
##                       its own.
## lamp_fade             [begin, length] of the ceiling lamps' distance fade.
##                       Their shadow lasts exactly as long as their light.
## room_reach            rooms past this are hidden. A lamp only shines while
##                       every wall round it is drawn (hotel_geometry), so it
##                       has to cover the lamp fade plus a room's radius.
## furniture_lamps       distance at which table and floor lamps go out (0:
##                       never lit).
## body_shadow           the local player's own body casts shadows (it
##                       re-renders every lamp shadow round it while walking).
## ssao, ssil            screen-space occlusion and indirect light
##                       (RenderingServer.EnvironmentSSAOQuality /
##                       EnvironmentSSILQuality, -1 off), *_half at half size.
##                       SSIL is the only GI: SDFGI leaked light through the
##                       18 cm walls and a generated floor cannot be baked.
## ssr_steps             screen-space reflections (0 off); ssr_roughness is
##                       the blur quality on rough surfaces.
## fog_size, fog_depth   volumetric fog grid (0 off); fog_filter smooths it.
## floor_haze            the low haze in the halls (FogVolume).
## glow, glow_bicubic    bloom and its smoother upscale.
## debanding             dither against banding in dark gradients.
## probes                reflection probes: 0 none, 1 every third hall, 2 every
##                       lit room, rendered with shadows. Without bounce, a
##                       probes 2 capture is also its room's ambient light.
## decals                share of each room's decals (damp, stains,
##                       fingerprints; room_dressing.gd), 0 none. Forward+
##                       only: Compatibility draws none.
## small_maps            the scanned materials at 1024 px instead of 2048
##                       (assets/textures, hotel_geometry.apply_scan()): a
##                       quarter of their video memory.
## sconce_lights         wall lamps light their wall (lighting.gd profile,
##                       shadowed, and each kept in its room by the room's
##                       render layer all the same: hotel_geometry.gd,
##                       kept_in()); otherwise only their shades glow.
## lamps_cast            how many ceiling lamps cast a shadow at once, the
##                       nearest; the lit ones past them light without one,
##                       each kept in its room by layers as sconce_fill's are
##                       (hotel_geometry.gd, cast_or_fill()). 0: every lamp in
##                       reach casts. Ultra's reach lit more shadowed lamps
##                       than the shadow atlas has places for, and Alto's
##                       enough of them to redraw shadows in a room where
##                       nothing moved.
## ssao_shape            the occlusion's radius in metres, its intensity, and
##                       how much of it darkens what the lamps light and not
##                       only the ambient light (0 to 1). Nearly all the light
##                       of a room is its lamps', so with little of the last
##                       the creases of a room -- wall and ceiling, skirting,
##                       a chair's feet -- stay as bright as the open wall.
## glazed_art            the paintings are behind glass: a clear coat over the
##                       canvas, where the lamps and the torch are seen
##                       (hotel_geometry.gd, glaze()).
## detail_kit            the moulded kit (hotel_geometry.gd, "The moulded
##                       kit"): skirting, dado rail and cornice run to a
##                       section instead of plain boxes, the dado's panels
##                       raised, a plaster rose round each ceiling lamp, a
##                       switch by each door and a grille on a wall. Both are
##                       built with the floor; the preset shows one.
## sconce_fill           the wall lamps past the nearest twelve light their
##                       walls too, without a shadow, each kept in its room by
##                       the room's render layer (hotel_geometry.gd,
##                       SCONCES_LIT): a long corridor is lit to its end.
## lamp_fog              ceiling lamps light the volumetric fog, which is
##                       then 14 m long: short cells do not straddle walls.
## bounce                light bounced round each lit room (a VoxelGI per room,
##                       baked at load from a stand-in, the nearest 8 shown),
##                       in place of the probes' ambient light.
## bounce_half           the bounce drawn at half resolution.
## dust                  dust motes floating round the player (0 none).
## surface_detail        octaves of the procedural surface noise (the
##                       surface_detail shader global); under 2.5 the finest
##                       terms (carpet pile, paper fibre, wood pores) go too.
##                       At 0 every surface is drawn from one small picture
##                       of itself, baked from this same shader at full
##                       detail (surface.gdshaderinc, baked_surface();
##                       tools/textures/bake_lite_maps.gd): no scanned map --
##                       they are not loaded -- no noise, no relief. At 5
##                       what tells a real surface from a drawn plane
##                       (finest_surface()): the lacquer a clear coat over the
##                       wood, walls and ceilings that are not flat under a
##                       grazing lamp, tiles each at its own tilt, a carpet's
##                       pile lying one way or another.
## occlusion             occlusion culling: what is behind walls is not sent to
##                       the GPU, at the price of a small picture of the walls
##                       drawn on the processor every frame.
## chroma_taps           taps of the tape filter's chroma smear (same width).
## tape_lite             the tape filter reads the picture three times a
##                       pixel instead of nine or more (analog.gdshader): no
##                       luma softening or ringing, the rest as ever.
## lens                  the camcorder's lens and sensor pass (lens.gdshader):
##                       barrel, fringes, interlacing, sensor noise. Without
##                       it the picture is rendered straight, and the tape
##                       filter gives the grain and the vignette.
## lod_threshold         pixels of error allowed before a mesh LOD switches.
## anisotropy            anisotropic filtering of textured props.
## ccd_smear             strength of the CCD's vertical streak through saturated
##                       lights (camera/camcorder_effect.gd; 0 off). The rest of
##                       the camera (iris, video knee, lens, sensor noise) is the
##                       same on every preset: it is the camera, not a quality.
##                       Compatibility has no compositor and keeps AgX.
## glare                 the lamps' halo and lens ghosts (camcorder_effect.gd; 0
##                       off, 1 as designed).
## motion_blur           samples along the trail a turn leaves during the
##                       camcorder's 1/60 s shutter (camera/motion_blur_effect.gd;
##                       0 off).
## autofocus             the lens focuses on what is in the centre, late, and
##                       hunts; only something close blurs the background
##                       (hotel_player.update_focus, Godot's depth of field).
## echo                  the creature's acoustic reading (echo_view.gd): rays
##                       per click, rays aimed at doors and wardrobes, grains
##                       remembered, grain size. Low keeps half the grains of
##                       medium at twice the size, so the room still reads;
##                       doors and wardrobes keep medium's aimed rays and
##                       memory, because they are what it navigates by.
##                       Ultra is only a little finer than high: quality must
##                       not tell the creature more, it looks better instead
##                       (halo: a faint phosphor glow round every grain, drawn
##                       by echo_points.gdshader; the environment's glow works
##                       on downscaled images, where 2 px grains all but vanish).
const PRESETS := [
	{
		"scale": 0.67, "upscaler": "fsr1", "static_light": false, "tape_lite": false, "lens": true, "occlusion": true, "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "taa": false, "roughness_limiter": false,
		"shadow_atlas": 4096, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "penumbra": 0.0,
		"lamp_fade": [30.0, 12.0], "lamps_cast": 0, "room_reach": 56.0, "furniture_lamps": 0.0, "body_shadow": false,
		"ssao": -1, "ssao_half": true, "ssao_shape": [1.2, 2.6, 0.15], "ssil": -1, "ssil_half": true, "ssr_steps": 0, "ssr_roughness": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_DISABLED,
		"fog_size": 0, "fog_depth": 0, "fog_filter": false, "floor_haze": false,
		"glow": true, "glow_bicubic": false, "debanding": false, "probes": 0, "dust": 0,
		"surface_detail": 2.0, "chroma_taps": 4, "lod_threshold": 4.0, "anisotropy": Viewport.ANISOTROPY_2X, "ccd_smear": 0.0, "glare": 0.0, "motion_blur": 0, "autofocus": false, "sconce_lights": false, "sconce_fill": false, "glazed_art": false, "detail_kit": false, "lamp_fog": false, "bounce": false, "decals": 0.0, "small_maps": true, "bounce_half": true,
		"echo": {"rays": 950, "aimed": 600, "points": 12000, "bodies": 400, "puff_points": 13, "puffs": 2400, "find_points": 20, "finds": 300, "frames": 7000, "grain": 2.0, "halo": 0.0},
	},
	{
		"scale": 0.85, "upscaler": "fsr2", "static_light": false, "tape_lite": false, "lens": true, "occlusion": true, "msaa": Viewport.MSAA_DISABLED, "fxaa": false, "taa": true, "roughness_limiter": true,
		"shadow_atlas": 4096, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "penumbra": 1.0,
		"lamp_fade": [30.0, 12.0], "lamps_cast": 0, "room_reach": 66.0, "furniture_lamps": 28.0, "body_shadow": true,
		"ssao": RenderingServer.ENV_SSAO_QUALITY_LOW, "ssao_half": true, "ssao_shape": [1.2, 2.6, 0.15], "ssil": -1, "ssil_half": true, "ssr_steps": 0, "ssr_roughness": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_DISABLED,
		"fog_size": 48, "fog_depth": 48, "fog_filter": true, "floor_haze": false,
		"glow": true, "glow_bicubic": false, "debanding": false, "probes": 1, "dust": 60,
		"surface_detail": 3.0, "chroma_taps": 7, "lod_threshold": 2.0, "anisotropy": Viewport.ANISOTROPY_4X, "ccd_smear": 0.28, "glare": 1.0, "motion_blur": 6, "autofocus": false, "sconce_lights": false, "sconce_fill": false, "glazed_art": false, "detail_kit": false, "lamp_fog": true, "bounce": false, "decals": 0.5, "small_maps": false, "bounce_half": true,
		"echo": {"rays": 1900, "aimed": 600, "points": 24000, "bodies": 700, "puff_points": 26, "puffs": 4800, "find_points": 40, "finds": 600, "frames": 7000, "grain": 1.0, "halo": 0.0},
	},
	{
		"scale": 1.0, "upscaler": "fsr2", "static_light": false, "tape_lite": false, "lens": true, "occlusion": true, "msaa": Viewport.MSAA_2X, "fxaa": false, "taa": true, "roughness_limiter": true,
		"shadow_atlas": 8192, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "penumbra": 1.0,
		"lamp_fade": [36.0, 12.0], "lamps_cast": 20, "room_reach": 66.0, "furniture_lamps": 32.0, "body_shadow": true,
		"ssao": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "ssao_half": true, "ssao_shape": [1.2, 2.6, 0.15], "ssil": RenderingServer.ENV_SSIL_QUALITY_MEDIUM, "ssil_half": true, "ssr_steps": 32, "ssr_roughness": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_LOW,
		"fog_size": 64, "fog_depth": 64, "fog_filter": true, "floor_haze": true,
		"glow": true, "glow_bicubic": true, "debanding": true, "probes": 2, "dust": 90,
		"surface_detail": 4.0, "chroma_taps": 7, "lod_threshold": 1.0, "anisotropy": Viewport.ANISOTROPY_8X, "ccd_smear": 0.28, "glare": 1.0, "motion_blur": 8, "autofocus": true, "sconce_lights": true, "sconce_fill": false, "glazed_art": false, "detail_kit": false, "lamp_fog": true, "bounce": true, "decals": 1.0, "small_maps": false, "bounce_half": true,
		"echo": {"rays": 3600, "aimed": 1200, "points": 46000, "bodies": 1400, "puff_points": 44, "puffs": 9600, "find_points": 70, "finds": 1200, "frames": 14000, "grain": 1.0, "halo": 0.0},
	},
	{
		"scale": 1.0, "upscaler": "fsr2", "static_light": false, "tape_lite": false, "lens": true, "occlusion": true, "msaa": Viewport.MSAA_4X, "fxaa": false, "taa": true, "roughness_limiter": true,
		"shadow_atlas": 8192, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "penumbra": 2.5,
		"lamp_fade": [50.0, 14.0], "lamps_cast": 20, "room_reach": 82.0, "furniture_lamps": 40.0, "body_shadow": true,
		"ssao": RenderingServer.ENV_SSAO_QUALITY_HIGH, "ssao_half": false, "ssao_shape": [0.7, 4.0, 0.6], "ssil": RenderingServer.ENV_SSIL_QUALITY_HIGH, "ssil_half": true, "ssr_steps": 64, "ssr_roughness": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_HIGH,
		"fog_size": 96, "fog_depth": 96, "fog_filter": true, "floor_haze": true,
		"glow": true, "glow_bicubic": true, "debanding": true, "probes": 2, "dust": 140,
		"surface_detail": 5.0, "chroma_taps": 7, "lod_threshold": 1.0, "anisotropy": Viewport.ANISOTROPY_16X, "ccd_smear": 0.28, "glare": 1.0, "motion_blur": 12, "autofocus": true, "sconce_lights": true, "sconce_fill": true, "glazed_art": true, "detail_kit": true, "lamp_fog": true, "bounce": true, "decals": 1.0, "small_maps": false, "bounce_half": false,
		"echo": {"rays": 4800, "aimed": 1400, "points": 64000, "bodies": 1800, "puff_points": 56, "puffs": 12000, "find_points": 90, "finds": 1600, "frames": 18000, "grain": 0.8, "halo": 1.0},
	},
	# Muy bajo: for integrated graphics. The game is all there; the picture is
	# plainly a cheaper one (docs/PERFORMANCE.md, section 10).
	{
		"scale": 0.5, "upscaler": "bilinear", "static_light": true, "tape_lite": true, "lens": false, "occlusion": true, "msaa": Viewport.MSAA_DISABLED, "fxaa": false, "taa": false, "roughness_limiter": false,
		"shadow_atlas": 2048, "shadow_filter": RenderingServer.SHADOW_QUALITY_HARD, "penumbra": 0.0,
		"lamp_fade": [30.0, 12.0], "lamps_cast": 0, "room_reach": 56.0, "furniture_lamps": 0.0, "body_shadow": false,
		"ssao": -1, "ssao_half": true, "ssao_shape": [1.2, 2.6, 0.15], "ssil": -1, "ssil_half": true, "ssr_steps": 0, "ssr_roughness": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_DISABLED,
		"fog_size": 0, "fog_depth": 0, "fog_filter": false, "floor_haze": false,
		"glow": false, "glow_bicubic": false, "debanding": false, "probes": 0, "dust": 0,
		"surface_detail": 0.0, "chroma_taps": 2, "lod_threshold": 8.0, "anisotropy": Viewport.ANISOTROPY_DISABLED, "ccd_smear": 0.0, "glare": 0.0, "motion_blur": 0, "autofocus": false, "sconce_lights": false, "sconce_fill": false, "glazed_art": false, "detail_kit": false, "lamp_fog": false, "bounce": false, "decals": 0.0, "small_maps": true, "bounce_half": true,
		# The creature's reading is Bajo's: it is what it plays by.
		"echo": {"rays": 950, "aimed": 600, "points": 12000, "bodies": 400, "puff_points": 13, "puffs": 2400, "find_points": 20, "finds": 300, "frames": 7000, "grain": 2.0, "halo": 0.0},
	},
]

## --- The player's own picture and graphics settings -------------------------
##
## The preset says what a machine can afford; these say what the player wants
## over it. `of()` takes them in, so everything that reads a preset sees one
## picture of the settings and nowhere has to ask twice.

## How the 3D picture is scaled up to the window (settings "upscaler").
## - auto: native resolution is drawn straight (bilinear, nothing to rebuild);
##   under it, what the preset in force chooses (its "upscaler"): FSR 2.2,
##   the best the engine has, from Medio up; FSR 1 on Bajo, the preset for
##   machines with little room to spare; and on Muy bajo, for those with
##   none, the plain stretch -- the tape filter blurs the picture more than
##   any of them sharpens it.
## - fsr2: FidelityFX Super Resolution 2.2, temporal. It rebuilds the picture
##   from the frames before it with the motion of every pixel, so at 60% it
##   still reads sharper than a native 85% blown up. It does its own edge
##   smoothing, so it replaces TAA, FXAA and SMAA (and the engine switches TAA
##   off under it anyway). At scale 1 it is an antialiaser of its own.
## - fsr1: spatial, a single frame sharpened. Cheaper and with no history, so
##   nothing smears; it cannot invent the detail FSR 2.2 does.
## - bilinear: the plain stretch.
## Forward+ only: Compatibility has neither, and there everything is bilinear.
## There is no DLSS: it is not in the engine, and it cannot be added from
## outside one (it needs the renderer's own motion vectors and jitter), so it
## would mean shipping a fork of Godot.
const UPSCALERS := ["auto", "bilinear", "fsr1", "fsr2"]
const UPSCALER_NAMES := ["Automático", "Bilineal (sin reconstrucción)", "FSR 1.0 (espacial)", "FSR 2.2 (temporal)"]

static func scaling_mode(values: Dictionary) -> int:
	if RenderingServer.get_current_rendering_method() != "forward_plus": return Viewport.SCALING_3D_MODE_BILINEAR
	var choice := String(values.get("upscaler", "auto"))
	if choice == "auto":
		if float(values.get("scale", 1.0)) >= 0.999: choice = "bilinear"
		else: choice = PRESETS[clampi(int(values.get("quality", MEDIUM)), 0, PRESETS.size() - 1)].upscaler
	match choice:
		"fsr1": return Viewport.SCALING_3D_MODE_FSR
		"fsr2": return Viewport.SCALING_3D_MODE_FSR2
	return Viewport.SCALING_3D_MODE_BILINEAR

## What a reconstruction is given to work with, in the proportions AMD names
## its own modes by: how much of each side is drawn before it is rebuilt up to
## the window. Quality 67% draws about half the pixels; Performance 50% draws
## a quarter. Anything else the slider is left at reads as "Personalizada".
const SCALING_MODES := [1.0, 0.77, 0.67, 0.59, 0.5, 0.33]
const SCALING_NAMES := ["Nativa (sin reescalado)", "Ultra calidad (77%)", "Calidad (67%)", "Equilibrado (59%)", "Rendimiento (50%)", "Ultra rendimiento (33%)"]

## Edge smoothing the player asks for over the preset's own (settings "aa").
const ANTIALIASING := ["preset", "off", "fxaa", "smaa", "taa", "msaa2", "msaa4"]
const ANTIALIASING_NAMES := ["Del preset", "Sin suavizado", "FXAA (rápido)", "SMAA (mejor)", "TAA (temporal)", "MSAA 2×", "MSAA 4×"]

## The heavy effects, each one "del preset" (-1), off (0) or on (1).
const SWITCHES := {
	"ao": "Oclusión ambiental (SSAO/SSIL)",
	"fog": "Niebla volumétrica",
	"reflections": "Reflejos en superficies",
	"blur": "Desenfoque de movimiento",
}

## Values forced over every preset, for A/B measurements only
## (tools/benchmarks/hotel_benchmark.gd --set=key:value). Empty in play.
static var overrides := {}

## The preset for a quality, with what the running renderer cannot do taken
## out: Compatibility has no screen-space effects, volumetric fog, TAA or FSR.
static func of(quality: int, values := {}) -> Dictionary:
	var preset: Dictionary = PRESETS[clampi(quality, 0, PRESETS.size() - 1)].duplicate(true)
	preset["smaa"] = false
	for key in overrides: preset[key] = overrides[key]
	apply_choices(preset, values)
	if RenderingServer.get_current_rendering_method() != "forward_plus":
		preset.ssao = -1
		preset.ssil = -1
		preset.ssr_steps = 0
		preset.fog_size = 0
		preset.floor_haze = false
		preset.taa = false
		preset.autofocus = false
		preset.lamp_fog = false
		preset.sconce_lights = false
		preset.bounce = false
		# Without TAA, the plain edge smoothing.
		if preset.msaa == Viewport.MSAA_DISABLED and not preset.smaa: preset.fxaa = true
	# FSR 2.2 rebuilds the picture from its own history: it is the smoothing,
	# and anything else on top of it only softens what it just resolved.
	if scaling_mode(values) == Viewport.SCALING_3D_MODE_FSR2:
		preset.taa = false
		preset.fxaa = false
		preset.smaa = false
		preset.msaa = Viewport.MSAA_DISABLED
	return preset

## What the player asked for over the preset (see ANTIALIASING and SWITCHES).
static func apply_choices(preset: Dictionary, values: Dictionary) -> void:
	match String(values.get("aa", "preset")):
		"off": preset.merge({"msaa": Viewport.MSAA_DISABLED, "fxaa": false, "smaa": false, "taa": false}, true)
		"fxaa": preset.merge({"msaa": Viewport.MSAA_DISABLED, "fxaa": true, "smaa": false, "taa": false}, true)
		"smaa": preset.merge({"msaa": Viewport.MSAA_DISABLED, "fxaa": false, "smaa": true, "taa": false}, true)
		"taa": preset.merge({"msaa": Viewport.MSAA_DISABLED, "fxaa": false, "smaa": false, "taa": true}, true)
		"msaa2": preset.merge({"msaa": Viewport.MSAA_2X, "fxaa": false, "smaa": false, "taa": false}, true)
		"msaa4": preset.merge({"msaa": Viewport.MSAA_4X, "fxaa": false, "smaa": false, "taa": false}, true)
	# Switched off, an effect goes; switched on, it comes in at the quality the
	# preset above it would have given, so a modest machine asking for fog gets
	# the cheap grid and not Ultra's.
	match int(values.get("ao", -1)):
		0:
			preset.ssao = -1
			preset.ssil = -1
		1:
			if preset.ssao < 0: preset.merge({"ssao": RenderingServer.ENV_SSAO_QUALITY_LOW, "ssao_half": true}, true)
			if preset.ssil < 0: preset.merge({"ssil": RenderingServer.ENV_SSIL_QUALITY_LOW, "ssil_half": true}, true)
	match int(values.get("fog", -1)):
		0:
			preset.merge({"fog_size": 0, "fog_depth": 0, "floor_haze": false, "lamp_fog": false}, true)
		1:
			if preset.fog_size <= 0: preset.merge({"fog_size": 48, "fog_depth": 48, "fog_filter": true, "lamp_fog": true}, true)
	match int(values.get("reflections", -1)):
		0: preset.ssr_steps = 0
		1:
			if preset.ssr_steps <= 0: preset.merge({"ssr_steps": 32, "ssr_roughness": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_LOW}, true)
	match int(values.get("blur", -1)):
		0: preset.motion_blur = 0
		1:
			if preset.motion_blur <= 0: preset.motion_blur = 6

## How many presets there are (the saved setting is clamped to them).
static func count() -> int:
	return PRESETS.size()
