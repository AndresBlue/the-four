extends SceneTree
## Looks for z-fighting in a built floor: two faces of the hotel's boxes lying
## in the same plane, facing the same way, overlapping, with different
## materials -- the depth test cannot tell which is in front and they flicker
## into each other. Boxes are every batched box of hotel_geometry (the
## walls, trims, panels, floors, ceilings, furniture carcasses) and every
## MeshInstance3D with a BoxMesh or QuadMesh (doors' plaques, the lift's
## casing...). Models are left out. Prints each material pair with how many
## places and how much area, and the worst places with where they are.
## Run with a window: headless, Godot reads every MultiMesh transform back as
## the identity.
##   godot --path . --script tools/dev/zfight_scan.gd -- [--seed=81] [--planta=0] [--shots]
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## Planes this close count as one (metres): the depth buffer cannot separate
## them at any distance worth looking from.
const PLANE := 0.0015
const MIN_AREA := 0.0004
var level
## Every box as the inverse of its transform, by metre cell: a face with a
## solid right in front of it is not seen, and what it fights with does not
## matter (the bottom of a wall on the floor, the top of the dado under the
## chair rail).
var solids := {}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var seed_value := 81
	var planta := -1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--planta="): planta = int(argument.trim_prefix("--planta="))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(seed_value)
	var faces: Array = []
	for node in level.hotel.find_children("*", "", true, false):
		if node is MultiMeshInstance3D and String(node.name).begins_with("Mesh_") and not String(node.name).contains("-") and not String(node.name).ends_with("_Shadow"):
			var material := String(node.name).trim_prefix("Mesh_")
			var multi: MultiMesh = node.multimesh
			for i in multi.instance_count:
				add_box(faces, node.global_transform * multi.get_instance_transform(i), material)
		elif node is MeshInstance3D and node.visible and (node.mesh is BoxMesh or node.mesh is QuadMesh):
			var mat: Material = node.material_override if node.material_override != null else node.mesh.surface_get_material(0)
			var material := mat.resource_name if mat != null and not mat.resource_name.is_empty() else ("%s#%d" % [node.name, mat.get_instance_id() if mat != null else 0])
			if node.mesh is BoxMesh: add_box(faces, node.global_transform * Transform3D(Basis.from_scale(node.mesh.size), Vector3.ZERO), material)
			else: add_quad(faces, node.global_transform, node.mesh.size, material)
	if planta >= 0: faces = faces.filter(func(face): return FLOOR.planta_of(face.centre.y) == planta)
	print("FACES ", faces.size())
	# Buckets by facing, plane and a metre cell of space, so only faces that
	# could meet are compared (a face goes in every cell it covers).
	var buckets := {}
	for index in faces.size():
		var face: Dictionary = faces[index]
		var facing := "%d,%d,%d" % [roundi(face.normal.x * 50), roundi(face.normal.y * 50), roundi(face.normal.z * 50)]
		var plane := roundi(face.offset / PLANE)
		var reach: Vector3 = (face.u as Vector3).abs() + (face.v as Vector3).abs()
		var low: Vector3 = (face.centre - reach).floor()
		var high: Vector3 = (face.centre + reach).floor()
		for x in range(int(low.x), int(high.x) + 1):
			for y in range(int(low.y), int(high.y) + 1):
				for z in range(int(low.z), int(high.z) + 1):
					for p in [plane, plane + 1]:
						var key := "%s|%d|%d,%d,%d" % [facing, p, x, y, z]
						if not buckets.has(key): buckets[key] = []
						buckets[key].append(index)
	var found := {}
	var places: Array = []
	var compared := {}
	for key in buckets:
		var group: Array = buckets[key]
		for a in group.size():
			for b in range(a + 1, group.size()):
				var i: int = mini(group[a], group[b])
				var j: int = maxi(group[a], group[b])
				if i == j: continue
				var fa: Dictionary = faces[i]
				var fb: Dictionary = faces[j]
				if fa.material == fb.material: continue
				var pair_key := i * 1000003 + j
				if compared.has(pair_key): continue
				compared[pair_key] = true
				if absf(fa.offset - fb.offset) > PLANE or fa.normal.dot(fb.normal) < 0.999: continue
				var area := overlap(fa, fb)
				if area < MIN_AREA: continue
				if hidden(fa, fb): continue
				var pair: String = " / ".join([fa.material, fb.material] if fa.material < fb.material else [fb.material, fa.material])
				if not found.has(pair): found[pair] = {"count": 0, "area": 0.0}
				found[pair].count += 1
				found[pair].area += area
				places.append({"pair": pair, "area": area, "at": (fa.centre + fb.centre) * 0.5, "normal": fa.normal})
	var pairs := found.keys()
	pairs.sort_custom(func(x, y): return found[x].area > found[y].area)
	print("PAIRS ", pairs.size(), " PLACES ", places.size())
	for pair in pairs: print("  %-45s %5d sitios  %8.2f m2" % [pair, found[pair].count, found[pair].area])
	places.sort_custom(func(x, y): return x.area > y.area)
	var shown := {}
	for place in places:
		if int(shown.get(place.pair, 0)) >= 3: continue
		shown[place.pair] = int(shown.get(place.pair, 0)) + 1
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, place.at)
		print("  AT %s room %d (%s) normal %s  %s  %.3f m2" % [place.at, int(room.get("id", -1)), FLOOR.TYPES[int(room.get("type", 20))] if not room.is_empty() else "-", place.normal.snappedf(0.01), place.pair, place.area])
	# --shots: the worst place of each pair, photographed from in front of it
	# (evidence/zfight_<n>.png), with the tape's filters off.
	if OS.get_cmdline_user_args().has("--shots"):
		level.locust.set_physics_process(false)
		level.locust.position = Vector3(0, -80, 0)
		for key in ["vhs", "grain", "chromatic", "scanlines"]: level.settings.values[key] = 0.0
		level.settings.values.reduced = true
		level.apply_settings()
		level.player.torch.visible = true
		level.player.set_physics_process(false)
		var taken := {}
		var n := 0
		for place in places:
			if taken.has(place.pair) or place.normal.y < -0.5: continue
			taken[place.pair] = true
			var eye: Vector3 = place.at + place.normal * 1.1 + Vector3(0, 0.25, 0) + (Vector3(0.3, 0, 0.3) if absf(place.normal.y) > 0.5 else Vector3.ZERO)
			level.player.position = eye - Vector3(0, level.player.eye_height, 0)
			var d: Vector3 = place.at - eye
			level.player.rotation = Vector3(0, atan2(-d.x, -d.z), 0)
			level.player.camera.rotation = Vector3(atan2(d.y, Vector2(d.x, d.z).length()), 0, 0)
			level.player.snap_torch()
			level.hotel.update_visibility(level.player.position, true)
			for i in 40: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://evidence/zfight_%d.png" % n)
			print("SHOT zfight_%d %s at %s" % [n, place.pair, place.at])
			n += 1
	quit()

## The six faces of a box (a unit cube under `xform`).
func add_box(faces: Array, xform: Transform3D, material: String) -> void:
	if absf(xform.basis.determinant()) > 1e-9:
		var reach: Vector3 = (xform.basis.x.abs() + xform.basis.y.abs() + xform.basis.z.abs()) * 0.5
		var low: Vector3 = (xform.origin - reach).floor()
		var high: Vector3 = (xform.origin + reach).floor()
		var inverse := xform.affine_inverse()
		for x in range(int(low.x), int(high.x) + 1):
			for y in range(int(low.y), int(high.y) + 1):
				for z in range(int(low.z), int(high.z) + 1):
					var key := Vector3i(x, y, z)
					if not solids.has(key): solids[key] = []
					solids[key].append(inverse)
	var axes := [xform.basis.x, xform.basis.y, xform.basis.z]
	for k in 3:
		var along: Vector3 = axes[k]
		if along.length() < 0.0001: continue
		var u: Vector3 = axes[(k + 1) % 3]
		var v: Vector3 = axes[(k + 2) % 3]
		for side in [-1.0, 1.0]:
			var normal: Vector3 = along.normalized() * side
			var centre: Vector3 = xform.origin + along * 0.5 * side
			faces.append({"normal": normal, "offset": normal.dot(centre), "centre": centre, "u": u * 0.5, "v": v * 0.5, "material": material})

## A quad (QuadMesh faces +Z), one face.
func add_quad(faces: Array, xform: Transform3D, size: Vector2, material: String) -> void:
	var normal: Vector3 = xform.basis.z.normalized()
	var centre: Vector3 = xform.origin
	faces.append({"normal": normal, "offset": normal.dot(centre), "centre": centre, "u": xform.basis.x * size.x * 0.5, "v": xform.basis.y * size.y * 0.5, "material": material})

## Roughly how much of two coplanar rectangles overlaps: a grid of points on
## the smaller one, counted inside the other.
func overlap(a: Dictionary, b: Dictionary) -> float:
	var area_a: float = 4.0 * (a.u as Vector3).length() * (a.v as Vector3).length()
	var area_b: float = 4.0 * (b.u as Vector3).length() * (b.v as Vector3).length()
	var small: Dictionary = a if area_a <= area_b else b
	var large: Dictionary = b if area_a <= area_b else a
	var inside := 0
	var steps := 6
	for s in steps:
		for t in steps:
			var p: Vector3 = small.centre + small.u * ((s + 0.5) / steps * 2.0 - 1.0) + small.v * ((t + 0.5) / steps * 2.0 - 1.0)
			if contains(large, p): inside += 1
	return minf(area_a, area_b) * float(inside) / float(steps * steps)

## Whether, where the two overlap, something solid sits right in front of
## them: then neither is seen.
func hidden(a: Dictionary, b: Dictionary) -> bool:
	var small: Dictionary = a if (a.u as Vector3).length() * (a.v as Vector3).length() <= (b.u as Vector3).length() * (b.v as Vector3).length() else b
	var large: Dictionary = b if small == a else a
	var seen := 0
	var inside := 0
	for s in 4:
		for t in 4:
			var p: Vector3 = small.centre + small.u * ((s + 0.5) / 4.0 * 2.0 - 1.0) + small.v * ((t + 0.5) / 4.0 * 2.0 - 1.0)
			if not contains(large, p): continue
			inside += 1
			if not solid_at(p + (small.normal as Vector3) * 0.004): seen += 1
	return inside > 0 and seen == 0

func solid_at(p: Vector3) -> bool:
	for inverse in solids.get(Vector3i(p.floor()), []):
		var local: Vector3 = inverse * p
		if absf(local.x) < 0.5 and absf(local.y) < 0.5 and absf(local.z) < 0.5: return true
	return false

func contains(face: Dictionary, p: Vector3) -> bool:
	var d: Vector3 = p - face.centre
	var u: Vector3 = face.u
	var v: Vector3 = face.v
	return absf(d.dot(u)) <= u.length_squared() + 0.0005 and absf(d.dot(v)) <= v.length_squared() + 0.0005
