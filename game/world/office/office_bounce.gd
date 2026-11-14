extends "res://game/world/hotel/bounce_light.gd"
## The bounce light of an office floor (spec_rediseno 4): the hotel's, but its
## stand-in takes the office's own materials in their own mean colour, which
## material_albedo.gd (measured from the hotel's) does not know: they baked
## grey, and the carpet and the ceiling tile in the hotel's colours.
## Material key -> a plain material in its colour, made on the main thread.
var own := {}
## Whether a room has its light (office_geometry.lit()); and each volume's
## cells, by its first cell (its meta "room").
var lit_test := Callable()
var cells := {}
## The floor's rooms (office_geometry: the manifest's), for the open sides.
var rooms_of := Callable()
## How far a volume runs on past an open side of its cells into the next
## space: two volumes meeting there overlap and Godot blends them across it.
## Meeting edge to edge, a surface took one or the other, and where a
## stretch of corridor met the next at a turn or a T, or a cell met a hall,
## floor and walls changed brightness at a ruled line.
const OVERLAP := 1.2
## How far inside its walls' middle a volume ends on a walled side: past the
## wall's own face (half its 18 cm) and the door leaves hung on it. Godot
## gives a volume to whatever it touches and lights it from the volume's edge
## even outside it: ending on the walls' middle, it touched the floor, the
## walls and the doors of the dark room next door, which glowed in its light
## (a store's brick wall in a flat rectangle, an orange door in the dark).
## The room's own walls, just outside it, still take their light that way.
const INSET := 0.13
const SIDES := {"west": Vector2(-1, 0), "east": Vector2(1, 0), "north": Vector2(0, -1), "south": Vector2(0, 1)}

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

## The hotel's, each volume's cells noted (by the room nodes' names,
## Room_<id>_...), its open sides run on by OVERLAP and its walled ones drawn
## in by INSET.
func start(volumes_wanted: Array, unit_mesh: Callable) -> void:
	var rooms: Array = rooms_of.call() if rooms_of.is_valid() else []
	for entry: Dictionary in volumes_wanted:
		var ids: Array = entry.parts.map(func(part: Array) -> int: return int(String(part[0].name).get_slice("_", 1)))
		cells[int(entry.room)] = ids
		if rooms.is_empty(): continue
		var middle: Vector3 = (entry.node as Node3D).position + (entry.centre as Vector3)
		var half: Vector2 = (entry.size as Vector2) * 0.5
		# A side runs on only where every cell along it is open there: a box
		# grown along a whole stretch for the one cell open at a T reached
		# through the walls into the rooms beside the stretch.
		var grow := {}
		for side: String in SIDES:
			var way: Vector2 = SIDES[side]
			var on_edge := 0
			var open := 0
			for id: int in ids:
				var room: Dictionary = rooms[id]
				var at := FLOOR.position_of(room)
				var edge := Vector2(at.x - middle.x, at.z - middle.z) + way * FLOOR.size_of(room) * 0.5
				if absf(edge.dot(way) - (half * way.abs()).length()) > 0.05: continue
				on_edge += 1
				if room.get("open_sides", []).has(side): open += 1
			if on_edge > 0 and open == on_edge: grow[side] = true
		var low := -half
		var high := half
		for side: String in SIDES:
			var way: Vector2 = SIDES[side]
			var by: float = OVERLAP if grow.has(side) else -INSET
			if way.x < 0.0 or way.y < 0.0: low += way * by
			else: high += way * by
		var shift := (low + high) * 0.5
		entry.size = high - low
		entry.centre = (entry.centre as Vector3) + Vector3(shift.x, 0, shift.y)
		for part: Array in entry.parts: part[1] = (part[1] as Vector3) - Vector3(shift.x, 0, shift.y)
	super(volumes_wanted, unit_mesh)

## A volume shines while one of its cells has its light. Baked once for the
## rooms lit as the planta opened, a room darkened after (her snuff, her
## drinking it, the board) kept its volume, and the lamps next door, which a
## volume injects shadowed only by its own voxels, lit its walls through the
## doorways' gaps: a wall of a dark room glowing in a flat rectangle.
func shines(volume: VoxelGI) -> bool:
	return cells.get(int(volume.get_meta("room", -1)), []).any(func(id: int) -> bool: return lit_test.call(id))

func show_near(position: Vector3, on: bool, planta := -1) -> void:
	if not lit_test.is_valid():
		super(position, on, planta)
		return
	for volume in volumes:
		if is_instance_valid(volume) and volume.visible and not shines(volume): show(volume, false)
	var every := volumes.duplicate()
	volumes.assign(every.filter(func(volume: VoxelGI) -> bool: return is_instance_valid(volume) and shines(volume)))
	super(position, on, planta)
	volumes.assign(every)

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
