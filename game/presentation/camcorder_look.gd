extends RefCounted
## The camcorder's fixed character: its lens. Not a quality setting, the same
## camera on every preset (the hunter's acoustic view has none) -- but for
## Muy bajo, which leaves the whole lens pass out (`lens`).
##
## A real wide-angle camcorder lens is not rectilinear: straight lines bow
## outward towards the edges and the corners are squeezed in, where a
## rectilinear 78 degrees stretches them (the look of a game camera). The
## picture is rendered wider and remapped in lens.gdshader so that the centre
## keeps exactly the field of view the game was designed around.

## Barrel distortion: source radius = r * scale * (1 + BARREL * r^2), with r
## in half-heights.
const BARREL := 0.05
## Whether the lens pass is drawn at all (graphics preset "lens", set by
## presentation_rig.apply_settings()). Without it nothing is remapped, so
## nothing is rendered wider either: every camera gets the field of view it
## was designed with.
static var lens := true
## Vertical field of view at the centre of the picture, as before the lens,
## with the zoom fully wide.
const VIEW_FOV := 78.0
## The zoom motor's range, wide (1) to telephoto: a 6x lens, like the home
## camcorders of the day.
const ZOOM_MAX := 6.0

## The field of view the picture's centre keeps at a zoom of 1 to ZOOM_MAX.
static func zoom_fov(zoom: float, design := VIEW_FOV) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(design) * 0.5) / clampf(zoom, 1.0, ZOOM_MAX)))

## A long lens bends straight lines far less than a wide one: the barrel
## fades out as the zoom goes in.
static func barrel_for(zoom: float) -> float:
	return BARREL / clampf(zoom, 1.0, ZOOM_MAX)

## Scale that puts the corners of the output exactly on the corners of the
## rendered picture, for an aspect ratio (width / height).
static func corner_scale(aspect: float, barrel := BARREL) -> float:
	return 1.0 / (1.0 + barrel * (aspect * aspect + 1.0))

## Vertical field of view to render with, so that after the remap the centre
## sees `design` (VIEW_FOV for the player). Every camera the lens films
## through asks for its field of view here: the player's, the watch camera,
## the opening scene and the title set.
static func render_fov(aspect: float, design := VIEW_FOV, barrel := BARREL) -> float:
	if not lens: return design
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(design) * 0.5) / corner_scale(aspect, barrel)))

## The same for whatever viewport a camera renders into.
static func fov_for(viewport: Viewport, design: float) -> float:
	var size := viewport.get_visible_rect().size
	return render_fov(size.x / maxf(size.y, 1.0), design)
