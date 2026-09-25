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
## A straight stretch of corridor is one volume too, for the same reason
## (hotel_geometry.corridor_runs()). Only rectangular halls: an L-shaped
## hall's box would take in the room in its corner, so those have no bounce.
## A volume more than BIG_SIDE metres long bakes at subdivision 128, not to
## lose detail.
##
## A room takes some 55 ms to bake, about 5 s for a floor of 121 rooms, so the
## rooms are baked on worker threads, detached from the scene tree (a node in
## the tree cannot be touched off the main thread), and handed to their rooms
## when all are done: about 1.3 s for that floor, while the game keeps
## running. A floor is three whole plantas now, and only the one looked from
## is baked (hotel_geometry.start_bounce(): release() lets the others go). The
## stand-in never reaches the GPU (stand_in_mesh.gd), so a worker never waits
## for the main thread and the main thread can always wait for the workers.
## Detached, the baker reads every global transform as the identity and
## complains about each one: the stand-in is given in the volume's own frame,
## and error printing is off while the bake runs.
const ALBEDO := preload("res://game/world/hotel/material_albedo.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const STAND_IN := preload("res://game/world/hotel/stand_in_mesh.gd")
## Lamp glass, tubes and shades stay out of the stand-in: they enclose their
## own light, which the voxels round it would smother.
const SKIP := ["light", "shade", "tube"]
## Godot draws at most 8 volumes at once: the nearest rooms' are shown.
const SHOWN := 8
const BIG_SIDE := 20.0
## How far in from a volume's side its walls reach (half core, panels, rails).
const EDGE := 0.3

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
## unit shape. One bake at a time (a planta's: hotel_geometry.start_bounce()).
func start(volumes_wanted: Array, unit_mesh: Callable) -> void:
	if baking(): return
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
	stand_in.mesh = stand_in_mesh(job.boxes, Vector3(0, -job.height * 0.5, 0), job.size * 0.5)
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
		# Held here, handed to the volume only while it is shown.
		volume.set_meta("baked", job.data)
		volume.set_meta("room", job.room)
		job.node.add_child(volume)
		volumes.append(volume)
	print_verbose("Bounce light: %d volumes baked" % volumes.size())
	jobs.clear()

## Lets go of every volume that is not on `planta`, and what it baked.
func release(planta: int) -> void:
	for volume in volumes.duplicate():
		if not is_instance_valid(volume):
			volumes.erase(volume)
			continue
		if FLOOR.planta_of(volume.global_position.y) == planta: continue
		volumes.erase(volume)
		volume.queue_free()

## Shows the nearest rooms' volumes, as many as Godot draws. Only a shown
## volume has its data: a volume with data keeps its textures in video
## memory, shown or not, some 56 MB each (the 51 of a floor took 2.9 GB).
func show_near(position: Vector3, on: bool, planta := -1) -> void:
	if volumes.is_empty(): return
	# Only the planta being looked from: one under the slab is never seen, and
	# its volumes would take the places (and the video memory) of this one's.
	var nearest := volumes.filter(func(volume: VoxelGI) -> bool: return planta < 0 or FLOOR.planta_of(volume.global_position.y) == planta)
	for volume in volumes:
		if nearest.has(volume) or not volume.visible: continue
		volume.data = null
		volume.visible = false
	nearest.sort_custom(func(a: VoxelGI, b: VoxelGI) -> bool: return reach(a, position) < reach(b, position))
	for k in nearest.size():
		var shown: bool = on and k < SHOWN
		if nearest[k].visible == shown: continue
		nearest[k].data = nearest[k].get_meta("baked") if shown else null
		nearest[k].visible = shown

## How far a point is from a volume's box, 0 inside it (the centre breaks
## ties). By the centre alone, a corridor volume 40 m long that the eye stood
## in came after the rooms round it and was left out of the eight.
static func reach(volume: VoxelGI, point: Vector3) -> float:
	var local := point - volume.global_position
	var half := volume.size * 0.5
	var outside := Vector3(maxf(absf(local.x) - half.x, 0.0), maxf(absf(local.y) - half.y, 0.0), maxf(absf(local.z) - half.z, 0.0))
	return outside.length() + local.length() * 0.001

## A volume's boxes, one surface per material, moved into the volume's frame:
## by their room's offset from the centre, then by offset.
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
		mesh.add(kept[0], kept[1], colours.get(material, colours[""]))
	return mesh

## Only faces that look into the volume, at its edges. A wall at the edge of
## a room's volume lies in its last voxels; with the face it turns to the next
## room, those voxels took in that room's lamps (the baker lights a voxel from
## any side) and gave their light to this one: a cold storeroom beside a
## bathroom came out 12 % brighter, and yellow round the wall lamps. The
## stand-in is never drawn: the faces that look out of the volume go.
static func outer_faces_removed(vertices: PackedVector3Array, normals: PackedVector3Array, half: Vector2) -> Array:
	var kept_vertices := PackedVector3Array()
	var kept_normals := PackedVector3Array()
	for t in range(0, vertices.size(), 3):
		var middle := (vertices[t] + vertices[t + 1] + vertices[t + 2]) / 3.0
		var normal := normals[t]
		var out_x := absf(middle.x) > half.x - EDGE and normal.x * signf(middle.x) > 0.5
		var out_z := absf(middle.z) > half.y - EDGE and normal.z * signf(middle.z) > 0.5
		if out_x or out_z: continue
		for k in 3:
			kept_vertices.append(vertices[t + k])
			kept_normals.append(normals[t + k])
	return [kept_vertices, kept_normals]

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
