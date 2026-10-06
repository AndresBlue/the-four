extends SceneTree
## The small pictures the lowest graphics preset draws the hotel's surfaces
## from (surface.gdshaderinc, baked_surface()): each material of
## hotel_geometry.MATERIALS that has a surface shader is photographed flat,
## unlit and at full detail -- its scanned maps, its print, its stains, exactly
## what its own shader draws on the other presets -- and the photograph is
## made to repeat. One read of that stands, on Muy bajo, for three scanned
## maps, the noise and the relief.
##
##   godot --path . --script res://tools/textures/bake_lite_maps.gd
##   godot --headless --path . --import
## Needs a window (it renders). Writes assets/textures/lite/<material>.png
## with its .import (VRAM compressed, mipmaps) and lite.json, the metres each
## picture covers. Run it again whenever a material or its shader changes.
##
## How a picture repeats without a seam: twice the stretch it will cover is
## photographed, and its first BAND is cross-faded into the same place one
## repetition on. Where the stretch is a whole number of the pattern's own
## periods (the wallpaper's rolls, the carpet's medallions, a scan that is
## laid as tiles or boards) the pattern lands on itself and only what is
## random -- stains, mottling -- is blended.
##
## Wallpaper is a strip the height of the tallest room, repeated only along
## the wall: its stains gather under the ceiling and its grime over the
## skirting, and a square of it repeated up the wall would say neither.
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const OUT := "res://assets/textures/lite/"
## Drawn this many times bigger and brought down, so a thin printed line is
## averaged and not sampled.
const SUPER := 2
## The share of a picture, from its edge, that is blended into the next
## repetition.
const BAND := 0.25
## The tallest room (map_generator: a hall is 4.8 m).
const TALLEST := 4.8

const IMPORT := """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/textures/lite/%s.png"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map=2
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
process/fix_alpha_border=false
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/size_limit=0
detect_3d/compress_to=0
"""

func _initialize() -> void: run.call_deferred()

## A material's parameter, or its shader's default where the material leaves
## it alone.
static func value(material: ShaderMaterial, title: String, fallback: Variant) -> Variant:
	var own = material.get_shader_parameter(title)
	if own != null: return own
	var standard = RenderingServer.shader_get_parameter_default(material.shader.get_rid(), title)
	return standard if standard != null else fallback

## What to photograph: {face, size (metres one repetition covers), pixels
## (across), strip (repeats only across), with (parameters put aside for the
## photograph)}. {} for a shader that keeps its own drawing (a curtain, a
## painting: small things).
static func plan(material: ShaderMaterial) -> Dictionary:
	var shader := material.shader.resource_path.get_file().get_basename()
	var metres := float(value(material, "map_metres", 1.0))
	# A scan laid as tiles or boards repeats every map_metres; one that is
	# shuffled (map_no_tile) repeats nowhere.
	var laid: bool = material.has_meta("scan") and not bool(value(material, "map_no_tile", false))
	match shader:
		"wallpaper":
			var roll := float(value(material, "roll_width", 0.53))
			var motif := float(value(material, "motif_height", 0.46))
			return {"face": "wall", "strip": true, "size": Vector2(8.0 * roll, ceilf(TALLEST / motif) * motif), "pixels": 1024, "with": {}}
		"carpet":
			# No wear: a stain every other medallion, the same one, is worse
			# than none.
			return {"face": "floor", "strip": false, "size": Vector2.ONE * 2.0 * float(value(material, "tile_size", 0.62)), "pixels": 512, "with": {"wear": 0.0}}
		"tile":
			return {"face": "floor", "strip": false, "size": Vector2.ONE * (metres if laid else 2.0 * float(value(material, "tile_size", 0.3))), "pixels": 512, "with": {"grime": float(value(material, "grime", 0.6)) * 0.5}}
		"ceiling":
			return {"face": "ceiling", "strip": false, "size": Vector2.ONE * (metres * ceilf(3.0 / metres) if laid else 4.0), "pixels": 512, "with": {}}
		"wood":
			# The grooves of a panelled dado and of a door's leaf are cut over
			# the picture by the shader itself: here, only the wood.
			return {"face": "wall", "strip": false, "size": Vector2.ONE * metres * ceilf(1.0 / metres), "pixels": 512, "with": {"panel_spacing": 0.0, "door_panels": false, "object_space": false}}
		"finish":
			# As paint, not as metal: unlit, a metal has no colour of its own to
			# show (brass came out black), and on this preset there is nothing
			# for it to reflect either.
			return {"face": "wall", "strip": false, "size": Vector2.ONE * (metres * ceilf(0.8 / metres) if laid else 1.0), "pixels": 128, "with": {"metallic": 0.0, "map_metallic": 0.0}}
	return {}

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	RenderingServer.global_shader_parameter_set("surface_detail", 4.0)
	GEOMETRY.small_maps = false
	GEOMETRY.no_maps = false
	var builder = GEOMETRY.new()
	var sizes := {}
	for key in GEOMETRY.MATERIALS:
		var material := builder.materials[key] as ShaderMaterial
		if material == null: continue
		var spec := plan(material)
		if spec.is_empty(): continue
		var size: Vector2 = spec.size
		var pixels := Vector2i(int(spec.pixels), int(roundf(float(spec.pixels) * size.y / size.x / 4.0)) * 4)
		var sheet := await photograph(material, spec, pixels)
		var picture := repeating(sheet, pixels, bool(spec.strip))
		picture.save_png(OUT + key + ".png")
		var file := FileAccess.open(OUT + key + ".png.import", FileAccess.WRITE)
		file.store_string(IMPORT % key)
		file.close()
		sizes[key] = [snappedf(size.x, 0.0001), snappedf(size.y, 0.0001)]
		print("LITE %-18s %4.2f x %4.2f m  %d x %d px" % [key, size.x, size.y, pixels.x, pixels.y])
	var listing := FileAccess.open(OUT + "lite.json", FileAccess.WRITE)
	listing.store_string(JSON.stringify(sizes, "\t", true))
	listing.close()
	builder.free()
	quit()

## The material on a flat face, twice the stretch across (and twice up, unless
## it is a strip), with no light on it: what its shader gives as ALBEDO.
func photograph(material: ShaderMaterial, spec: Dictionary, pixels: Vector2i) -> Image:
	var size: Vector2 = spec.size
	var shown := Vector2(size.x * 2.0, size.y if spec.strip else size.y * 2.0)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.size = Vector2i(pixels.x * 2, pixels.y if spec.strip else pixels.y * 2) * SUPER
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	root.add_child(view)
	var stage := WorldEnvironment.new()
	stage.environment = Environment.new()
	stage.environment.background_mode = Environment.BG_COLOR
	stage.environment.background_color = Color.BLACK
	stage.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	view.add_child(stage)
	var taken := material.duplicate() as ShaderMaterial
	for title in spec.with: taken.set_shader_parameter(title, spec.with[title])
	var slab := MeshInstance3D.new()
	slab.mesh = BoxMesh.new()
	slab.material_override = taken
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = shown.y
	camera.near = 0.1
	camera.far = 20.0
	view.add_child(slab)
	view.add_child(camera)
	# The face lies where the shader's own coordinates start at the picture's
	# corner: face_uv() runs right and down from it (surface.gdshaderinc).
	# Wider than tall, so wood runs its grain across.
	match String(spec.face):
		"wall":
			# A strip stands on the floor (y = 0 at its foot); a tile hangs
			# from y = 0.
			var middle := Vector3(shown.x * 0.5, shown.y * 0.5 if spec.strip else -shown.y * 0.5, 0.0)
			slab.scale = Vector3(shown.x + 6.0, shown.y + 4.0, 0.2)
			slab.position = middle - Vector3(0, 0, 0.1)
			camera.look_at_from_position(middle + Vector3(0, 0, 5), middle, Vector3.UP)
		"floor":
			var middle := Vector3(shown.x * 0.5, 0.0, shown.y * 0.5)
			slab.scale = Vector3(shown.x + 6.0, 0.2, shown.y + 4.0)
			slab.position = middle - Vector3(0, 0.1, 0)
			camera.look_at_from_position(middle + Vector3(0, 5, 0), middle, Vector3(0, 0, -1))
		"ceiling":
			var middle := Vector3(shown.x * 0.5, 0.0, -shown.y * 0.5)
			slab.scale = Vector3(shown.x + 6.0, 0.2, shown.y + 4.0)
			slab.position = middle + Vector3(0, 0.1, 0)
			camera.look_at_from_position(middle - Vector3(0, 5, 0), middle, Vector3(0, 0, 1))
	camera.current = true
	for frame in 6: await process_frame
	await RenderingServer.frame_post_draw
	var sheet := view.get_texture().get_image()
	sheet.convert(Image.FORMAT_RGB8)
	sheet.resize(sheet.get_width() / SUPER, sheet.get_height() / SUPER, Image.INTERPOLATE_LANCZOS)
	view.queue_free()
	return sheet

## One repetition out of a sheet of two across (and two down): what is within
## BAND of its left (and top) edge is faded into the same place a repetition
## on, so its two edges meet.
static func repeating(sheet: Image, pixels: Vector2i, strip: bool) -> Image:
	var picture := Image.create(pixels.x, pixels.y, false, Image.FORMAT_RGB8)
	for y in pixels.y:
		var down := 1.0 if strip else smoothstep(0.0, BAND, float(y) / float(pixels.y))
		for x in pixels.x:
			var across := smoothstep(0.0, BAND, float(x) / float(pixels.x))
			var here := sheet.get_pixel(x, y).lerp(sheet.get_pixel(x + pixels.x, y), 1.0 - across)
			if down < 1.0:
				var below := sheet.get_pixel(x, y + pixels.y).lerp(sheet.get_pixel(x + pixels.x, y + pixels.y), 1.0 - across)
				here = here.lerp(below, 1.0 - down)
			picture.set_pixel(x, y, here)
	return picture
