extends "res://game/world/hotel/bounce_light.gd"
## The bounce light of an office floor (spec_rediseno 4): the hotel's, but its
## stand-in takes the office's own materials in their own mean colour, which
## material_albedo.gd (measured from the hotel's) does not know: they baked
## grey, and the carpet and the ceiling tile in the hotel's colours.
## Material key -> a plain material in its colour, made on the main thread.
var own := {}

## Each material not measured for the hotel, or measured but the office's own
## (`over`), in its mean colour: a shader's flat_color or a standard
## material's albedo.
func own_colours(materials: Dictionary, over: Array) -> void:
	own.clear()
	for key: String in materials:
		if ALBEDO.ALBEDO.has(key) and not over.has(key): continue
		var material: Material = materials[key]
		var colour: Variant = null
		if material is ShaderMaterial: colour = (material as ShaderMaterial).get_shader_parameter("flat_color")
		elif material is BaseMaterial3D: colour = (material as BaseMaterial3D).albedo_color
		if not colour is Color: continue
		var plain := StandardMaterial3D.new()
		plain.albedo_color = colour
		own[key] = plain

## The hotel's stand-in (bounce_light.gd), with the office's colours first.
func stand_in_mesh(boxes: Array, offset: Vector3, half := Vector2(INF, INF)) -> Mesh:
	var by_material := {}
	for box in boxes:
		var shift := Transform3D(Basis.IDENTITY, box[2] + offset)
		var material := material_of(box[0])
		if not by_material.has(material): by_material[material] = [PackedVector3Array(), PackedVector3Array()]
		var shape: Array = shapes[box[0].get_slice("@", 1)]
		for frame: Transform3D in box[1]:
			by_material[material][0].append_array((shift * frame) * shape[0])
			by_material[material][1].append_array(Transform3D(frame.basis.inverse().transposed(), Vector3.ZERO) * shape[1])
	var mesh := STAND_IN.new()
	for material in by_material:
		var kept := outer_faces_removed(by_material[material][0], by_material[material][1], half)
		mesh.add(kept[0], kept[1], own.get(material, colours.get(material, colours[""])))
	return mesh
