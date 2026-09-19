extends RefCounted
## Light as it is in a real hotel (docs/REALISM.md, phase 2): colour from the
## lamp's colour temperature, and the shape of its light from a photometric
## profile, the way an IES file describes a fixture. The profiles are
## projector textures on the lights (equirectangular, as Godot maps an omni
## light's projector), built here procedurally: a frosted dome that pools its
## light below and throws a soft glow on the ceiling round it, a fluorescent
## batten's wide "batwing" spread, and a cloth-shaded wall lamp that washes its
## wall in a cone upwards and one downwards and sends nothing behind it (so it
## cannot reach the next room). An omni light only uses a projector while it
## casts shadows; every lamp here does (a lamp without a shadow shines through
## walls).
##
## Orientation (measured, docs/REALISM.md trials 4 and phase 2): a
## direction's z in the texture is the opposite of the light's local z, and
## the texture's top row is the light's down. A wall lamp's light takes the
## lamp model's transform (+Z into the room), so its front is -z here.
## intensity() is written in the light's own terms (+y up); build_profile()
## turns it upside down into the texture.

## A profile dims a lamp everywhere but its brightest direction: this much
## more energy keeps a room about as bright as it was before the profiles.
const PROFILE_GAIN := 1.25

## Colour temperatures, in kelvin.
const INCANDESCENT := 2700.0
const FLUORESCENT := 4100.0
## An old tube's green cast, on top of its temperature.
const TUBE_TINT := Color(0.92, 1.0, 0.9)
## The camcorder's fixed indoor white balance (its "tungsten" preset): warm
## lamps come out a little warm, fluorescent ones cold and greenish, as on
## real tape shot indoors.
const CAMERA_WHITE := 3200.0

## An approximate black-body colour (Tanner Helland's fit), brightest
## channel 1, as an sRGB colour.
static func kelvin(k: float) -> Color:
	var t := k / 100.0
	var r := 1.0 if t <= 66.0 else clampf(329.698727446 * pow(t - 60.0, -0.1332047592) / 255.0, 0.0, 1.0)
	var g := 0.0
	if t <= 66.0: g = clampf((99.4708025861 * log(t) - 161.1195681661) / 255.0, 0.0, 1.0)
	else: g = clampf(288.1221695283 * pow(t - 60.0, -0.0755148492) / 255.0, 0.0, 1.0)
	var b := 1.0
	if t < 66.0: b = 0.0 if t <= 19.0 else clampf((138.5177312231 * log(t - 10.0) - 305.0447927307) / 255.0, 0.0, 1.0)
	return Color(r, g, b)

## A lamp's colour as the camcorder records it under its fixed CAMERA_WHITE
## balance: the black-body colour divided by the camera's white (in linear
## light), brightest channel 1. The balance is applied to each light here and
## not to the whole picture, so the torch, the glowing glass and the painted
## colours keep the look they were made with.
static func light_color(k: float, tint := Color.WHITE) -> Color:
	var lamp := (kelvin(k) * tint).srgb_to_linear()
	var white := kelvin(CAMERA_WHITE).srgb_to_linear()
	var balanced := Color(lamp.r / white.r, lamp.g / white.g, lamp.b / white.b)
	var peak := maxf(balanced.r, maxf(balanced.g, balanced.b))
	return Color(balanced.r / peak, balanced.g / peak, balanced.b / peak).linear_to_srgb()

static var profiles := {}

## A profile by name ("dome", "tube", "sconce"), built once.
static func profile(name: String) -> ImageTexture:
	if not profiles.has(name): profiles[name] = build_profile(name)
	return profiles[name]

static func build_profile(name: String) -> ImageTexture:
	var width := 256
	var height := 128
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	for y in height:
		var elevation := PI * (0.5 - (y + 0.5) / height)
		for x in width:
			var azimuth := TAU * ((x + 0.5) / width) - PI
			# Top row down: see the orientation note above.
			var dir := Vector3(sin(azimuth) * cos(elevation), -sin(elevation), cos(azimuth) * cos(elevation))
			var v := intensity(name, dir)
			image.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(image)

## Relative intensity towards a direction (-z front, +y up), 0..1.
static func intensity(name: String, dir: Vector3) -> float:
	var down := -dir.y
	match name:
		"dome":
			# Frosted glass spreads it wide: strongest downwards in a broad pool,
			# well over half sideways onto the walls, and a glow up on the
			# ceiling round the fitting.
			return clampf(0.6 + 0.4 * smoothstep(-0.2, 0.8, down) - 0.15 * smoothstep(0.3, 1.0, -down), 0.0, 1.0)
		"tube":
			# Bare tubes under a metal channel. Batwing: strongest some 40 degrees
			# off straight down across the tube, dimmer straight below and along
			# it; the channel shades straight up, but the tubes still throw a
			# good share onto the ceiling on either side.
			var across := absf(dir.x)
			var batwing := smoothstep(-0.2, 0.5, down) * (0.65 + 0.35 * smoothstep(0.2, 0.65, across))
			return clampf(0.3 + 0.7 * batwing - 0.2 * smoothstep(0.6, 1.0, -down), 0.0, 1.0)
		"sconce":
			# Nothing behind (the wall); a cone up and a cone down out of the
			# open ends of the shade, a dim glow through the cloth.
			var front := smoothstep(-0.05, 0.2, -dir.z)
			var cones := smoothstep(0.45, 0.85, absf(dir.y))
			return clampf(front * (0.22 + 0.78 * cones), 0.0, 1.0)
	return 1.0
