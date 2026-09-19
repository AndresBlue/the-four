extends SceneTree
## Measures the mean colour of every hotel material and writes it to
## game/world/hotel/material_albedo.gd, for the bounce light's proxy (docs/
## REALISM.md, trial 8): VoxelGI's baker only reads the colour of standard
## materials, and the hotel's are shaders, which it takes for white. Each
## material is drawn on a 3 m patch under plain white ambient light, with no
## lamp, reflection or tonemapping, so a pixel is its albedo. Run it again
## whenever a material changes:
##   godot --path . --rendering-method forward_plus --script res://tools/lighting/measure_albedo.gd
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const OUT := "res://game/world/hotel/material_albedo.gd"
## Metres of surface in view: several repeats of the largest pattern.
const PATCH := 3.0
const PIXELS := 128

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(PIXELS, PIXELS)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = PATCH
	camera.position = Vector3(0, 0, 2)
	viewport.add_child(camera)
	var patch := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	patch.mesh = cube
	# Scaled like the hotel's batched boxes, whose shaders measure in metres.
	patch.scale = Vector3(PATCH * 1.2, PATCH * 1.2, 0.2)
	viewport.add_child(patch)
	var geometry = GEOMETRY.new()
	var lines := PackedStringArray()
	for key in GEOMETRY.MATERIALS:
		var material: Material = geometry.materials[key]
		var colour: Color
		if material is BaseMaterial3D:
			colour = (material as BaseMaterial3D).albedo_color
		else:
			patch.material_override = material
			for frame in 4: await process_frame
			await RenderingServer.frame_post_draw
			colour = mean(viewport.get_texture().get_image())
		lines.append('\t"%s": Color(%.3f, %.3f, %.3f),' % [key, colour.r, colour.g, colour.b])
		print("ALBEDO ", key, " ", colour)
	geometry.free()
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("extends RefCounted\n## The mean colour of each hotel material (sRGB), measured by\n## tools/lighting/measure_albedo.gd: do not edit by hand, run it again.\nconst ALBEDO := {\n%s\n}\n" % "\n".join(lines))
	file.close()
	quit()

## The mean in linear light, back in sRGB.
func mean(image: Image) -> Color:
	var total := Color(0, 0, 0)
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y).srgb_to_linear()
			total += Color(pixel.r, pixel.g, pixel.b)
			count += 1
	return Color(total.r / count, total.g / count, total.b / count).linear_to_srgb()
