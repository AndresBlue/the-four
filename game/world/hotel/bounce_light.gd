extends RefCounted
## Bounce light (preset bounce, docs/REALISM.md trial 8): a VoxelGI per lit
## room. Light that hits the carpet, the walls and the ceiling lights the rest
## of the room with their colour; the lamps are injected live, so a failing
## tube or a lamp going out takes its bounce with it. A volume ends at its
## room's walls, so the bounce never reaches the next room, and a dark room has
## none.
##
## The baker is fed a stand-in: the room's own batched boxes, one surface per
## material in its mean colour (material_albedo.gd). VoxelGI reads colour only
## from standard materials and takes the hotel's shaders for white.
##
## A hall (cells merged into one open space) is one volume over all its
## cells, baked from all their boxes: a volume per cell saw nothing past its
## own edge, the next cell's bounce came out different, and where one volume
## gave way to the next the ceiling showed a straight line (Godot gives a
## surface at most two volumes and normalises them, so the change is abrupt).
## Only rectangular halls: an L-shaped hall's box would take in the room in
## its corner, so those have no bounce. A volume more than BIG_SIDE metres
## long bakes at subdivision 128, not to lose detail.
##
## A room takes some 55 ms to bake, about 5 s for a floor, so the rooms are
## baked on worker threads, detached from the scene tree (a node in the tree
## cannot be touched off the main thread), and handed to their rooms when all
## are done: about 1.3 s for a floor, while the game keeps running. The
## stand-in never reaches the GPU (stand_in_mesh.gd), so a worker never waits
## for the main thread and the main thread can always wait for the workers.
## Detached, the baker reads every global transform as the identity and
## complains about each one: the stand-in is given in the volume's own frame,
## and error printing is off while the bake runs.
const ALBEDO := preload("res://game/world/hotel/material_albedo.gd")
const STAND_IN := preload("res://game/world/hotel/stand_in_mesh.gd")
## Lamp glass, tubes and shades stay out of the stand-in: they enclose their
## own light, which the voxels round it would smother.
const SKIP := ["light", "shade", "tube"]
## Godot draws at most 8 volumes at once: the nearest rooms' are shown.
const SHOWN := 8
const BIG_SIDE := 20.0

## Boxes of each room, by the room node's instance id: [[group, transforms]].
var groups := {}
## The baked volumes, in their rooms (meta "room": the room's index).
var volumes: Array[VoxelGI] = []
var jobs: Array = []
var task := -1
## Unit shapes' triangles by group suffix, read on the main thread before
## the workers start: [vertices, normals].
var shapes := {}
## A plain material per hotel material, in its mean colour.
static var colours := {}

## Records a batched group of a room's boxes (hotel_geometry.flush()).
func add(room_key: int, group: String, transforms: Array) -> void:
	if material_of(group).get_slice("_", 0) in SKIP: return
	if not groups.has(room_key): groups[room_key] = []
	groups[room_key].append([group, transforms])

## A group's material (hotel_geometry: "material@shape").
static func material_of(group: String) -> String:
	return group.get_slice("@", 0)

func baking() -> bool:
	return task >= 0

## Starts baking the given volumes: [{"room": index, "node": Node3D (the
## volume goes under it), "centre": Vector3 (the volume's middle on the floor,
## in node's space), "size": Vector2, "height": float, "parts": [[room node,
## offset of that room from the centre]]}]; unit_mesh(group) gives a group's
## unit shape. Only once per floor.
func start(volumes_wanted: Array, unit_mesh: Callable) -> void:
	if baking() or not volumes.is_empty(): return
	for entry in volumes_wanted:
		var boxes := []
		for part in entry.parts:
			for box in groups.get(part[0].get_instance_id(), []):
				var key: String = box[0].get_slice("@", 1)
				if not shapes.has(key): shapes[key] = unindexed(unit_mesh.call(box[0]))
				boxes.append([box[0], box[1], part[1]])
		if boxes.is_empty(): continue
		entry["boxes"] = boxes
		jobs.append(entry)
	if jobs.is_empty(): return
	stand_in_colours()
	Engine.print_error_messages = false
	# Half the cores at most: the main thread keeps drawing meanwhile.
	task = WorkerThreadPool.add_group_task(bake, jobs.size(), clampi(OS.get_processor_count() / 2, 1, 8), false, "Bounce light")

## One room, on a worker thread.
func bake(k: int) -> void:
	var job: Dictionary = jobs[k]
	var holder := Node3D.new()
	var stand_in := MeshInstance3D.new()
	stand_in.mesh = stand_in_mesh(job.boxes, Vector3(0, -job.height * 0.5, 0))
	holder.add_child(stand_in)
	var volume := VoxelGI.new()
	volume.subdiv = subdivision(job)
	volume.size = volume_size(job)
	holder.add_child(volume)
	volume.bake(stand_in)
	job["data"] = volume.data
	holder.free()

## Floor and ceiling faces just inside the volume.
static func volume_size(job: Dictionary) -> Vector3:
	return Vector3(job.size.x, job.height + 0.3, job.size.y)

static func subdivision(job: Dictionary) -> VoxelGI.Subdiv:
	return VoxelGI.SUBDIV_128 if maxf(job.size.x, job.size.y) > BIG_SIDE else VoxelGI.SUBDIV_64

## Every frame: once the bake is done, each room gets its volume.
func poll() -> void:
	if not baking() or not WorkerThreadPool.is_group_task_completed(task): return
	finish()

## Waits for the bake and hands the volumes over (also when the floor goes
## before it is done).
func finish() -> void:
	if not baking(): return
	WorkerThreadPool.wait_for_group_task_completion(task)
	task = -1
	Engine.print_error_messages = true
	for job in jobs:
		if job.get("data") == null or not is_instance_valid(job.node): continue
		var volume := VoxelGI.new()
		volume.subdiv = subdivision(job)
		volume.size = volume_size(job)
		volume.position = Vector3(job.centre.x, job.height * 0.5, job.centre.z)
		volume.visible = false
		# Walled in: no sky, no environment light.
		job.data.interior = true
		volume.data = job.data
		volume.set_meta("room", job.room)
		job.node.add_child(volume)
		volumes.append(volume)
	print_verbose("Bounce light: %d rooms baked" % volumes.size())
	jobs.clear()

## Shows the nearest rooms' volumes, as many as Godot draws.
func show_near(position: Vector3, on: bool) -> void:
	if volumes.is_empty(): return
	var nearest := volumes.duplicate()
	nearest.sort_custom(func(a: VoxelGI, b: VoxelGI) -> bool: return a.global_position.distance_squared_to(position) < b.global_position.distance_squared_to(position))
	for k in nearest.size():
		var shown: bool = on and k < SHOWN
		if nearest[k].visible != shown: nearest[k].visible = shown

## A volume's boxes, one surface per material, moved into the volume's frame:
## by their room's offset from the centre, then by offset.
func stand_in_mesh(boxes: Array, offset: Vector3) -> Mesh:
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
	for material in by_material: mesh.add(by_material[material][0], by_material[material][1], colours.get(material, colours[""]))
	return mesh

## A unit shape's triangles, unindexed: [vertices, normals].
static func unindexed(mesh: Mesh) -> Array:
	var arrays := mesh.surface_get_arrays(0)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		vertices.append(arrays[Mesh.ARRAY_VERTEX][index])
		normals.append(arrays[Mesh.ARRAY_NORMAL][index])
	return [vertices, normals]

## Made on the main thread, before the workers start.
static func stand_in_colours() -> void:
	if not colours.is_empty(): return
	for material in ALBEDO.ALBEDO:
		var colour := StandardMaterial3D.new()
		colour.albedo_color = ALBEDO.ALBEDO[material]
		colours[material] = colour
	# Anything not measured.
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.3, 0.3, 0.3)
	colours[""] = grey
