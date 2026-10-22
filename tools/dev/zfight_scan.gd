extends SceneTree
## Looks for z-fighting in a built floor: two surfaces lying in the same plane,
## facing the same way and overlapping -- the depth test cannot tell which is
## in front and they flicker into each other. It looks at:
##  - every batched box of hotel_geometry (walls, trims, panels, floors,
##    ceilings, carcasses) and every MeshInstance3D with a BoxMesh or QuadMesh;
##  - every model (the furniture, the wardrobes, the doors, what lies on the
##    tables), as its flat patches: its triangles gathered by plane.
## Two surfaces fight when their materials differ, or when they are the same
## material drawn by two rooms (each room shades its own walls: where two
## rooms of a salon both draw the same stretch, it flickers too). A pair with
## something solid right in front of it is not seen and is left out. Prints
## each pair of materials with how many places and how much area, and the
## worst places of each; --shots photographs them (evidence/zfight_<n>.png).
## Run with a window: headless, Godot reads every MultiMesh transform back as
## the identity.
##   godot --path . --script tools/dev/zfight_scan.gd -- [--seed=81] [--planta=0] [--walls] [--shots] [--detail] [--per=3] [--quality=3]
## --quality puts a graphics preset (Medio if not given): Ultra has pieces the
## others do not, and draws rooms further off.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## Planes this close count as one (metres): the depth buffer cannot separate
## them at any distance worth looking from.
const PLANE := 0.0015
const MIN_AREA := 0.002
## A model's flat patch counts from this much area (m2, in the model).
const PATCH_AREA := 0.004
var level
## Every box as the inverse of its transform, by metre cell: a face with a
## solid right in front of it is not seen (the bottom of a wall on the floor).
var solids := {}
var patches := {}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var seed_value := 81
	var planta := -1
	var per := 3
	var quality := 1
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--planta="): planta = int(argument.trim_prefix("--planta="))
		if argument.begins_with("--per="): per = int(argument.trim_prefix("--per="))
		if argument.begins_with("--quality="): quality = int(argument.trim_prefix("--quality="))
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.ui.finish_intro()
	await level.start_floor(seed_value)
	# What is hidden is not looked at, and a preset hides or shows pieces (the
	# moulded kit, graphics_presets.gd detail_kit): always a preset of this
	# run's own, Medio unless told, and not whatever the last run left saved.
	level.settings.set_designed(quality)
	await process_frame
	var faces: Array = []
	for node in level.hotel.find_children("*", "", true, false):
		if node is MultiMeshInstance3D and String(node.name).ends_with("_Shadow"): continue
		if node is GeometryInstance3D and (not node.is_visible_in_tree() or node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY): continue
		# What only stands in from far (the kit's plain pieces while the kit is
		# on) is not drawn with what it stands in for, but for a metre.
		if node is GeometryInstance3D and node.visibility_range_begin > 0.0: continue
		# Whose it is: the room it is drawn with (a room shades its own boxes).
		var owner_id: int = node.get_parent().get_instance_id()
		if node is MultiMeshInstance3D and String(node.name).begins_with("Mesh_"):
			# Cylinders and cones are not boxes; the moulded kit's two kinds of
			# box are (hotel_geometry.SHAPES: "plain", "detail").
			var material := String(node.name).trim_prefix("Mesh_").trim_suffix("-plain").trim_suffix("-detail")
			if material.contains("-"): continue
			var multi: MultiMesh = node.multimesh
			for i in multi.instance_count:
				add_box(faces, node.global_transform * multi.get_instance_transform(i), material, owner_id)
		elif node is MultiMeshInstance3D and node.multimesh != null and node.multimesh.mesh is ArrayMesh:
			var multi: MultiMesh = node.multimesh
			for i in multi.instance_count:
				add_model(faces, node.global_transform * multi.get_instance_transform(i), multi.mesh, String(node.name).trim_prefix("Model_"))
		elif node is MeshInstance3D and node.mesh != null:
			if node.mesh is BoxMesh or node.mesh is QuadMesh:
				var mat: Material = node.material_override if node.material_override != null else node.mesh.surface_get_material(0)
				var material := mat.resource_name if mat != null and not mat.resource_name.is_empty() else title_of(node)
				if node.mesh is BoxMesh: add_box(faces, node.global_transform * Transform3D(Basis.from_scale(node.mesh.size), Vector3.ZERO), material, node.get_instance_id())
				else: add_quad(faces, node.global_transform, node.mesh.size, material, node.get_instance_id())
			elif node.mesh is ArrayMesh:
				add_model(faces, node.global_transform, node.mesh, title_of(node))
	if planta >= 0: faces = faces.filter(func(face): return FLOOR.planta_of(face.centre.y) == planta)
	# --walls: only what stands upright (the undersides and tops of walls meet
	# the floor and the ceiling in hundreds of places nobody sees).
	if OS.get_cmdline_user_args().has("--walls"): faces = faces.filter(func(face): return absf(face.normal.y) < 0.5)
	print("FACES ", faces.size())
	# Buckets by facing, plane and a metre cell of space, so only faces that
	# could meet are compared (a face goes in every cell it covers).
	var buckets := {}
	for index in faces.size():
		var face: Dictionary = faces[index]
		# Opposite facings share a bucket (a face drawn from both sides fights
		# with either): the normal with its first axis that is not zero made
		# positive, and the plane measured along that.
		var folded: Vector3 = face.normal
		var q := Vector3i(roundi(folded.x * 40), roundi(folded.y * 40), roundi(folded.z * 40))
		var flip := -1.0 if (q.x < 0 or (q.x == 0 and (q.y < 0 or (q.y == 0 and q.z < 0)))) else 1.0
		var facing := "%d,%d,%d" % [int(q.x * flip), int(q.y * flip), int(q.z * flip)]
		var plane := roundi(face.offset * flip / PLANE)
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
				# The same thing twice over (a model's own patches, a room's own
				# boxes of one material) looks the same whichever wins.
				if fa.material == fb.material and fa.owner == fb.owner: continue
				var pair_key := i * 1000003 + j
				if compared.has(pair_key): continue
				compared[pair_key] = true
				var facing_same: float = (fa.normal as Vector3).dot(fb.normal)
				# The same way, or back to back when one of them is drawn from
				# both sides; and truly parallel -- a clock hung a degree off the
				# wall crosses its plane, it does not lie in it.
				if absf(facing_same) < 0.99995 or (facing_same < 0.0 and not (fa.double or fb.double)): continue
				if absf((fa.normal as Vector3).dot(fb.centre) - fa.offset) > PLANE or absf((fb.normal as Vector3).dot(fa.centre) - fb.offset) > PLANE: continue
				var area := overlap(fa, fb)
				if area < MIN_AREA: continue
				if hidden(fa, fb): continue
				var names: Array = [fa.material, fb.material]
				names.sort()
				var pair: String = "%s / %s" % names if names[0] != names[1] else "%s (dos salas)" % names[0]
				if not found.has(pair): found[pair] = {"count": 0, "area": 0.0}
				found[pair].count += 1
				found[pair].area += area
				# --detail: the two faces of the first few places of each pair.
				if OS.get_cmdline_user_args().has("--detail") and int(found[pair].count) <= 3:
					for f in [fa, fb]: print("    DETAIL %s  %s centre %s n %s u %s v %s" % [pair, f.material, (f.centre as Vector3).snappedf(0.001), (f.normal as Vector3).snappedf(0.01), (f.u as Vector3).snappedf(0.001), (f.v as Vector3).snappedf(0.001)])
				places.append({"pair": pair, "area": area, "at": (fa.centre + fb.centre) * 0.5 if area > 0.5 * minf(size_of(fa), size_of(fb)) else (fa.centre if size_of(fa) < size_of(fb) else fb.centre), "normal": fa.normal})
	var pairs := found.keys()
	pairs.sort_custom(func(x, y): return found[x].area > found[y].area)
	print("PAIRS ", pairs.size(), " PLACES ", places.size())
	for pair in pairs: print("  %-60s %5d sitios  %8.2f m2" % [pair, found[pair].count, found[pair].area])
	places.sort_custom(func(x, y): return x.area > y.area)
	var shown := {}
	var worst: Array = []
	for place in places:
		if int(shown.get(place.pair, 0)) >= per: continue
		shown[place.pair] = int(shown.get(place.pair, 0)) + 1
		var room: Dictionary = FLOOR.room_at(level.manifest.rooms, place.at)
		print("  AT %s room %d (%s) normal %s  %s  %.3f m2" % [place.at, int(room.get("id", -1)), FLOOR.palette(level.manifest).TYPES[int(room.get("type", FLOOR.VOID))] if not room.is_empty() else "-", place.normal.snappedf(0.01), place.pair, place.area])
		if int(shown[place.pair]) == 1: worst.append(place)
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
		var n := 0
		for place in worst:
			var normal: Vector3 = place.normal
			# A floor or a shelf is looked down at from one side; a wall, from
			# in front and a little above.
			var eye: Vector3 = place.at + (Vector3(0.45, 0.7, 0.45) if normal.y > 0.5 else Vector3(0.4, -0.5, 0.4) if normal.y < -0.5 else normal * 0.9 + Vector3(0, 0.3, 0) + normal.cross(Vector3.UP) * 0.3)
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

## What a mesh instance is called in the report: its mesh's file, or its
## node's name without the numbers that tell one from another.
func title_of(node: MeshInstance3D) -> String:
	var path := node.mesh.resource_path
	if not path.is_empty() and not path.contains("::"): return path.get_file().get_basename()
	var digits := RegEx.create_from_string("[@_]?[0-9]+")
	var title := digits.sub(String(node.name), "", true).replace("@", "")
	if title in ["MeshInstanceD", "MeshInstance3D", ""]: title = digits.sub(String(node.get_parent().name), "", true).replace("@", "") + ">malla"
	return title

func size_of(face: Dictionary) -> float:
	return 4.0 * (face.u as Vector3).length() * (face.v as Vector3).length()

## The six faces of a box (a unit cube under `xform`).
func add_box(faces: Array, xform: Transform3D, material: String, owner_id: int) -> void:
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
			faces.append({"normal": normal, "offset": normal.dot(centre), "centre": centre, "u": u * 0.5, "v": v * 0.5, "material": material, "owner": owner_id, "double": false})

## A quad (QuadMesh faces +Z), one face.
func add_quad(faces: Array, xform: Transform3D, size: Vector2, material: String, owner_id: int) -> void:
	var normal: Vector3 = xform.basis.z.normalized()
	var centre: Vector3 = xform.origin
	faces.append({"normal": normal, "offset": normal.dot(centre), "centre": centre, "u": xform.basis.x * size.x * 0.5, "v": xform.basis.y * size.y * 0.5, "material": material, "owner": owner_id, "double": false})

## A model where it stands: each of its flat patches as a face.
func add_model(faces: Array, xform: Transform3D, mesh: ArrayMesh, title: String) -> void:
	var id := mesh.get_instance_id()
	if not patches.has(id): patches[id] = patches_of(mesh)
	for patch in patches[id]:
		var normal: Vector3 = (xform.basis * (patch.normal as Vector3)).normalized()
		var centre: Vector3 = xform * (patch.centre as Vector3)
		faces.append({"normal": normal, "offset": normal.dot(centre), "centre": centre, "u": xform.basis * (patch.u as Vector3), "v": xform.basis * (patch.v as Vector3), "material": title, "owner": id, "double": patch.double})

## A mesh's flat patches: its triangles gathered by plane (a millimetre and a
## degree or so apart at most), each as the rectangle round it. A patch that
## is not a rectangle is taken for the one that holds it.
func patches_of(mesh: ArrayMesh) -> Array:
	var planes := {}
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		# Drawn from both sides (the wardrobe, so the inside of its doors shows):
		# it fights with what lies in its plane whichever way that faces.
		var material: Material = mesh.surface_get_material(surface)
		var double: bool = material is BaseMaterial3D and (material as BaseMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices = arrays[Mesh.ARRAY_INDEX]
		var count: int = indices.size() if indices != null and indices.size() > 0 else vertices.size()
		for t in range(0, count - 2, 3):
			var a: Vector3 = vertices[indices[t]] if indices != null and indices.size() > 0 else vertices[t]
			var b: Vector3 = vertices[indices[t + 1]] if indices != null and indices.size() > 0 else vertices[t + 1]
			var c: Vector3 = vertices[indices[t + 2]] if indices != null and indices.size() > 0 else vertices[t + 2]
			var cross := (c - a).cross(b - a)
			var area := cross.length() * 0.5
			if area < 0.000002: continue
			var normal := cross.normalized()
			var key := "%d,%d,%d|%d" % [roundi(normal.x * 60), roundi(normal.y * 60), roundi(normal.z * 60), roundi(normal.dot(a) / 0.001)]
			if not planes.has(key): planes[key] = {"normal": normal, "area": 0.0, "points": PackedVector3Array(), "double": double}
			planes[key].area += area
			planes[key].points.append_array([a, b, c])
	var result: Array = []
	for key in planes:
		var plane: Dictionary = planes[key]
		if plane.area < PATCH_AREA: continue
		var normal: Vector3 = plane.normal
		var along: Vector3 = (Vector3.UP if absf(normal.y) < 0.9 else Vector3.RIGHT).cross(normal).normalized()
		var across: Vector3 = normal.cross(along).normalized()
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for p in plane.points:
			var q := Vector2(p.dot(along), p.dot(across))
			low = low.min(q)
			high = high.max(q)
		var middle := (low + high) * 0.5
		var depth: float = normal.dot(plane.points[0])
		result.append({"normal": normal, "centre": along * middle.x + across * middle.y + normal * depth, "u": along * (high.x - low.x) * 0.5, "v": across * (high.y - low.y) * 0.5, "double": plane.double})
	return result

## Roughly how much of two coplanar rectangles overlaps: a grid of points on
## the smaller one, counted inside the other.
func overlap(a: Dictionary, b: Dictionary) -> float:
	var area_a := size_of(a)
	var area_b := size_of(b)
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
	var small: Dictionary = a if size_of(a) <= size_of(b) else b
	var large: Dictionary = b if small == a else a
	var seen := 0
	var inside := 0
	for s in 4:
		for t in 4:
			var p: Vector3 = small.centre + small.u * ((s + 0.5) / 4.0 * 2.0 - 1.0) + small.v * ((t + 0.5) / 4.0 * 2.0 - 1.0)
			if not contains(large, p): continue
			inside += 1
			# From the side a face shows; from either, if it is drawn from both.
			var open_front := not solid_at(p + (small.normal as Vector3) * 0.004)
			var open_back := not solid_at(p - (small.normal as Vector3) * 0.004)
			if open_front or ((small.double or large.double) and open_back): seen += 1
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
	# Half a millimetre of slack, in metres whatever the face's size: scaled
	# by the face, the two halves of a wall were taken to overlap.
	return absf(d.dot(u.normalized())) <= u.length() + 0.0005 and absf(d.dot(v.normalized())) <= v.length() + 0.0005
