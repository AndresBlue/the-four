extends RefCounted
## Graphics presets: every value that changes with the quality setting lives
## here and nowhere else. hotel_main.apply_settings() applies the renderer and
## the screen effects, hotel_geometry.apply_quality() the lamps, rooms and
## props, echo_view.apply_quality() the creature's reading. The saved setting
## is an index into PRESETS; files saved with three qualities keep their
## meaning (0 Bajo, 1 Medio, 2 Alto) and 3 is Ultra.
##
## The same in every preset, on purpose (docs/PERFORMANCE.md, "Presets"):
## - every lamp in view keeps its shadow: a lamp without one shines through
##   walls and shut doors, so shadows are cheapened, never dropped;
## - no ambient light and near-black depth fog: dark rooms are black;
## - door numbers and signs, the red beacon, door seals and dark rooms;
## - the tape filter sliders, reduced effects and the Sombras switch, which
##   are the player's own settings.
const NAMES := ["Bajo", "Medio", "Alto", "Ultra"]
const LOW := 0
const MEDIUM := 1
const HIGH := 2
const ULTRA := 3

## Keys:
## scale                 3D render scale the preset sets when chosen (the
##                       slider stays free afterwards); below 1 it is
##                       upscaled with FSR 1 (bilinear in Compatibility).
## msaa, fxaa, taa       anti-aliasing (TAA never for the creature's view).
## roughness_limiter     specular anti-aliasing on shiny surfaces.
## shadow_atlas          positional shadow atlas size. Never under 4096: a
##                       coarser cell grows the bias past a 7 cm door leaf.
## shadow_filter         soft shadow filter (RenderingServer.ShadowQuality).
## penumbra              lamp source size, times the size built (PCSS: a
##                       penumbra that widens away from the caster). 0: plain
##                       PCF, the cheapest. Ultra's 2.5 is about the size of a
##                       frosted dome and needs Soft High, or its wide
##                       penumbrae come out grainy. The torch never grows past
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
## probes                reflection probes: 0 none, 1 every third hall
##                       (reflections), 2 every lit room, rendered with
##                       shadows, its capture also the room's ambient light: the
##                       bounce, confined to the room's box.
## sconce_lights         wall lamps light their wall (lighting.gd profile,
##                       shadowed); otherwise only their shades glow.
## lamp_fog              ceiling lamps light the volumetric fog, which is
##                       then 14 m long: short cells do not straddle walls.
## dust                  dust motes floating round the player (0 none).
## surface_detail        octaves of the procedural surface noise (the
##                       surface_detail shader global); under 2.5 the finest
##                       terms (carpet pile, paper fibre, wood pores) go too.
## chroma_taps           taps of the tape filter's chroma smear (same width).
## lod_threshold         pixels of error allowed before a mesh LOD switches.
## anisotropy            anisotropic filtering of textured props.
## ccd_smear             strength of the CCD's vertical streak through saturated
##                       lights (camera/camcorder_effect.gd; 0 off). The rest of
##                       the camera (iris, video knee, lens, sensor noise) is the
##                       same on every preset: it is the camera, not a quality.
##                       Compatibility has no compositor and keeps AgX.
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
		"scale": 0.67, "msaa": Viewport.MSAA_DISABLED, "fxaa": true, "taa": false, "roughness_limiter": false,
		"shadow_atlas": 4096, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "penumbra": 0.0,
		"lamp_fade": [30.0, 12.0], "room_reach": 56.0, "furniture_lamps": 0.0, "body_shadow": false,
		"ssao": -1, "ssao_half": true, "ssil": -1, "ssil_half": true, "ssr_steps": 0, "ssr_roughness": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_DISABLED,
		"fog_size": 0, "fog_depth": 0, "fog_filter": false, "floor_haze": false,
		"glow": true, "glow_bicubic": false, "debanding": false, "probes": 0, "dust": 0,
		"surface_detail": 2.0, "chroma_taps": 4, "lod_threshold": 4.0, "anisotropy": Viewport.ANISOTROPY_2X, "ccd_smear": 0.0, "motion_blur": 0, "autofocus": false, "sconce_lights": false, "lamp_fog": false,
		"echo": {"rays": 950, "aimed": 600, "points": 12000, "bodies": 400, "puff_points": 13, "puffs": 2400, "find_points": 20, "finds": 300, "frames": 7000, "grain": 2.0, "halo": 0.0},
	},
	{
		"scale": 0.85, "msaa": Viewport.MSAA_DISABLED, "fxaa": false, "taa": true, "roughness_limiter": true,
		"shadow_atlas": 4096, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "penumbra": 1.0,
		"lamp_fade": [30.0, 12.0], "room_reach": 66.0, "furniture_lamps": 28.0, "body_shadow": true,
		"ssao": RenderingServer.ENV_SSAO_QUALITY_LOW, "ssao_half": true, "ssil": -1, "ssil_half": true, "ssr_steps": 0, "ssr_roughness": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_DISABLED,
		"fog_size": 48, "fog_depth": 48, "fog_filter": true, "floor_haze": false,
		"glow": true, "glow_bicubic": false, "debanding": false, "probes": 1, "dust": 60,
		"surface_detail": 3.0, "chroma_taps": 7, "lod_threshold": 2.0, "anisotropy": Viewport.ANISOTROPY_4X, "ccd_smear": 0.04, "motion_blur": 6, "autofocus": false, "sconce_lights": false, "lamp_fog": true,
		"echo": {"rays": 1900, "aimed": 600, "points": 24000, "bodies": 700, "puff_points": 26, "puffs": 4800, "find_points": 40, "finds": 600, "frames": 7000, "grain": 1.0, "halo": 0.0},
	},
	{
		"scale": 1.0, "msaa": Viewport.MSAA_2X, "fxaa": false, "taa": true, "roughness_limiter": true,
		"shadow_atlas": 8192, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, "penumbra": 1.0,
		"lamp_fade": [36.0, 12.0], "room_reach": 66.0, "furniture_lamps": 32.0, "body_shadow": true,
		"ssao": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "ssao_half": true, "ssil": RenderingServer.ENV_SSIL_QUALITY_MEDIUM, "ssil_half": true, "ssr_steps": 32, "ssr_roughness": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_LOW,
		"fog_size": 64, "fog_depth": 64, "fog_filter": true, "floor_haze": true,
		"glow": true, "glow_bicubic": true, "debanding": true, "probes": 2, "dust": 90,
		"surface_detail": 4.0, "chroma_taps": 7, "lod_threshold": 1.0, "anisotropy": Viewport.ANISOTROPY_8X, "ccd_smear": 0.04, "motion_blur": 8, "autofocus": true, "sconce_lights": true, "lamp_fog": true,
		"echo": {"rays": 3600, "aimed": 1200, "points": 46000, "bodies": 1400, "puff_points": 44, "puffs": 9600, "find_points": 70, "finds": 1200, "frames": 14000, "grain": 1.0, "halo": 0.0},
	},
	{
		"scale": 1.0, "msaa": Viewport.MSAA_4X, "fxaa": false, "taa": true, "roughness_limiter": true,
		"shadow_atlas": 8192, "shadow_filter": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "penumbra": 2.5,
		"lamp_fade": [50.0, 14.0], "room_reach": 82.0, "furniture_lamps": 40.0, "body_shadow": true,
		"ssao": RenderingServer.ENV_SSAO_QUALITY_HIGH, "ssao_half": false, "ssil": RenderingServer.ENV_SSIL_QUALITY_HIGH, "ssil_half": true, "ssr_steps": 64, "ssr_roughness": RenderingServer.ENV_SSR_ROUGHNESS_QUALITY_HIGH,
		"fog_size": 96, "fog_depth": 96, "fog_filter": true, "floor_haze": true,
		"glow": true, "glow_bicubic": true, "debanding": true, "probes": 2, "dust": 140,
		"surface_detail": 4.0, "chroma_taps": 7, "lod_threshold": 1.0, "anisotropy": Viewport.ANISOTROPY_16X, "ccd_smear": 0.04, "motion_blur": 12, "autofocus": true, "sconce_lights": true, "lamp_fog": true,
		"echo": {"rays": 4800, "aimed": 1400, "points": 64000, "bodies": 1800, "puff_points": 56, "puffs": 12000, "find_points": 90, "finds": 1600, "frames": 18000, "grain": 0.8, "halo": 1.0},
	},
]

## Values forced over every preset, for A/B measurements only
## (tools/benchmarks/hotel_benchmark.gd --set=key:value). Empty in play.
static var overrides := {}

## The preset for a quality, with what the running renderer cannot do taken
## out: Compatibility has no screen-space effects, volumetric fog, TAA or FSR.
static func of(quality: int) -> Dictionary:
	var preset: Dictionary = PRESETS[clampi(quality, 0, PRESETS.size() - 1)].duplicate(true)
	for key in overrides: preset[key] = overrides[key]
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
		# Without TAA, the plain edge smoothing.
		if preset.msaa == Viewport.MSAA_DISABLED: preset.fxaa = true
	return preset

## How many presets there are (the saved setting is clamped to them).
static func count() -> int:
	return PRESETS.size()
