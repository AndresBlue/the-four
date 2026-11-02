extends SceneTree
## Area 5 of the floor 2 redesign (spec_rediseno 12): what the use of the
## equipment stands on, written before its look changes and after, to be
## compared. For each of the three handlers every usable (name, index, action,
## place, facing, stand, face, box, aim, and what the interaction's ray from
## its stand meets first); the lamps, handles, pilots, rotors and zones
## counted; the colliders under the floor by kind and layer, with their
## shapes; the lifts. Floor 2, seeds 7 and 33, without her.
##   godot --headless --path . --script res://tools/dev/office_equipment_dump.gd --log-file <log> -- --automation --test-profile --silent --tag=antes
##   ... -- --automation --test-profile --silent --compare=antes,despues
## Writes evidence/rediseno/equipos_<tag>.json; --compare builds nothing, prints
## each difference and EQUIPMENT_SAME, or EQUIPMENT_DIFFERENT and their count
## (exit 1).
const SEEDS := [7, 33]
const OUT := "res://evidence/rediseno/equipos_%s.json"
const HANDLERS := [&"files", &"power", &"air"]
var level

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in count: await physics_frame

func run() -> void:
	var tag := "antes"
	var compare := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tag="): tag = argument.trim_prefix("--tag=")
		if argument.begins_with("--compare="): compare = argument.trim_prefix("--compare=")
	if not compare.is_empty():
		quit(compare_files(compare.get_slice(",", 0), compare.get_slice(",", 1)))
		return
	var out := {}
	for seed_asked in SEEDS: out[str(seed_asked)] = await dump(int(seed_asked))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/rediseno"))
	var file := FileAccess.open(OUT % tag, FileAccess.WRITE)
	file.store_string(JSON.stringify(out, "\t", true))
	file.close()
	print("EQUIPMENT_DUMP ", OUT % tag)
	quit(0)

## One floor, in a level of its own (office_walk_test.gd's way).
func dump(seed_asked: int) -> Dictionary:
	if is_instance_valid(level):
		level.queue_free()
		await frames(2)
	level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	level.creature_scene = "none"
	await level.start_floor(seed_asked, false, [1], "", 2)
	level.player.set_physics_process(false)
	await frames(2)
	var data := {}
	for id in HANDLERS:
		var entries: Array = []
		for usable in level.objective(id).usables: entries.append(usable_entry(usable))
		data[String(id)] = entries
	var files = level.objective(&"files")
	var power = level.objective(&"power")
	var air = level.objective(&"air")
	data["counts"] = {"lamps": files.lamps.size(), "stations": files.station_exits.size(), "handles": power.handles.size(), "pilots": power.pilots.size(), "zones": power.zones.size(), "rotors": air.rotors.size(), "lifts": level.hotel.lifts.size(), "gates": level.hotel.gates.size()}
	print("EQUIPMENT_ZONES ", seed_asked, " ", power.zones.size())
	var lamps: Array = []
	for lamp in files.lamps: lamps.append(lamp.visible)
	data["lamps_on"] = lamps
	var hinges: Array = []
	for hinge in power.handles: hinges.append(text_of(hinge.global_position))
	data["handles"] = hinges
	var cars: Array = []
	for car in level.hotel.lifts: cars.append(text_of(car))
	data["lifts"] = cars
	data["colliders"] = colliders(level.hotel)
	return data

## A usable as the interaction, the bots and the tests read it.
func usable_entry(usable) -> Dictionary:
	var stand: Vector3 = usable.stand
	var face: float = usable.face_yaw
	return {"name": String(usable.name), "index": int(usable.index), "action": String(usable.action), "at": text_of(usable.global_position), "yaw": "%.3f" % usable.global_rotation.y, "stand": text_of(stand) if stand != Vector3.INF else "none", "face": "%.3f" % face if not is_nan(face) else "none", "box": text_of(usable.box), "aim": text_of(usable.aim_point()), "ray": reached(usable)}

## What the interaction's ray (interaction.gd focused_area(): 2 m, layers 1, 8
## and 16, areas too) meets first, from the stand's eye toward the aim; from
## 0.8 m in front of the usable when it has no stand. "itself" when it is the
## usable.
func reached(usable) -> String:
	var aim: Vector3 = usable.aim_point()
	var stand: Vector3 = usable.stand
	var eye: float = level.player.camera.position.y
	var from: Vector3 = stand + Vector3(0, eye, 0) if stand != Vector3.INF else aim + (usable.global_basis.z as Vector3) * 0.8
	var query := PhysicsRayQueryParameters3D.create(from, from + (aim - from).normalized() * 2.0, 1 | 8 | 16)
	query.collide_with_areas = true
	var space: PhysicsDirectSpaceState3D = level.hotel.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty(): return "nothing"
	return "itself" if hit.collider == usable else String(hit.collider.name)

## The colliders under the floor by kind and layer, and their shapes: the
## look adds none.
func colliders(node: Node) -> Dictionary:
	var found := {}
	for body in node.find_children("*", "CollisionObject3D", true, false):
		var key := "%s:%d" % [body.get_class(), int(body.collision_layer)]
		var have: Array = found.get(key, [0, 0])
		found[key] = [int(have[0]) + 1, int(have[1]) + body.get_shape_owners().size()]
	return found

func text_of(v: Vector3) -> String: return "%.3f,%.3f,%.3f" % [v.x, v.y, v.z]

## The two dumps compared: 0 when they are the same.
func compare_files(a: String, b: String) -> int:
	var before = JSON.parse_string(FileAccess.get_file_as_string(OUT % a))
	var after = JSON.parse_string(FileAccess.get_file_as_string(OUT % b))
	if before == null or after == null:
		print("EQUIPMENT_DIFFERENT no file")
		return 1
	var differences: Array = []
	diff(before, after, "", differences)
	for line in differences: print("DIFF ", line)
	print("EQUIPMENT_SAME" if differences.is_empty() else "EQUIPMENT_DIFFERENT %d" % differences.size())
	return 0 if differences.is_empty() else 1

## Every place where the two differ, by its path.
func diff(x, y, path: String, out: Array) -> void:
	if x is Dictionary and y is Dictionary:
		for key in x:
			if not y.has(key): out.append(path + "/" + str(key) + " gone")
			else: diff(x[key], y[key], path + "/" + str(key), out)
		for key in y:
			if not x.has(key): out.append(path + "/" + str(key) + " new")
	elif x is Array and y is Array:
		if x.size() != y.size(): out.append("%s: %d then %d" % [path, x.size(), y.size()])
		for i in mini(x.size(), y.size()): diff(x[i], y[i], "%s/%d" % [path, i], out)
	elif x != y: out.append("%s: %s then %s" % [path, str(x), str(y)])
