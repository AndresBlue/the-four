extends SceneTree
## Whether The Lurker's arms go through things (lurker_limbs.gd): lurker.tscn
## upside down under a 2.95 m ceiling, going along it beside a column of a
## nave, over tall cabinets, a locker and survivors standing under her way,
## then still over a survivor; every frame each arm sampled from shoulder to
## elbow to wrist, and a frame counts when any sample is inside something
## solid (the world, a survivor, a shut door or a locker's leaf, an open
## leaf). The arms are read when the hands' modifier has run (afterwards the
## skeleton is back at the clip's pose). --strict exits 1 when any arm goes
## through anything: verify.ps1 runs it so.
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev/lurker_elbow_probe.gd -- --test-profile --strict
const BODY := preload("res://game/enemies/lurker/lurker.tscn")
const CEILING := 2.95
const HANG := 0.35
const CLING := 0.3
const HALF_WIDTH := 6.0
## What an arm must not go through: the world, survivors, shut leaves, open leaves.
const SOLID := 1 | 4 | 8 | 128
const SAMPLES := 8
## The runs: clip, pace (m/s), seconds.
const RUNS := [["crawl", 1.35, 30.0], ["crawl_fast", 3.5, 12.0], ["idle", 0.0, 6.0]]

var body: Node3D
var probe_point := PhysicsPointQueryParameters3D.new()
## Where the arms go through: {"upper"|"fore" + layer + share of the half: count}.
var where := {}
var stuck := 0
## Hands on a hold, against all hands, sampled with the arms.
var holding := 0
var hands := 0
## Each arm's shoulder, elbow and wrist as the hands left them (read when
## the modifier has run: afterwards the skeleton is back at the clip's pose).
var arms: Array = []

func _initialize() -> void: run.call_deferred()

func solid(at: Vector3, size: Vector3, layer: int) -> void:
	var block := StaticBody3D.new()
	block.collision_layer = layer
	block.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	block.add_child(shape)
	block.position = at
	root.add_child(block)

## A survivor's capsule standing on the floor (player.tscn: radius 0.3, 1.8 tall).
func survivor(x: float, z: float) -> void:
	var standing := StaticBody3D.new()
	standing.collision_layer = 4
	standing.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	shape.shape = capsule
	standing.add_child(shape)
	standing.position = Vector3(x, 0.9, z)
	root.add_child(standing)

func run() -> void:
	solid(Vector3(0, CEILING + 0.1, 0), Vector3(80, 0.2, HALF_WIDTH * 2.0), 1)
	solid(Vector3(0, -0.1, 0), Vector3(80, 0.2, HALF_WIDTH * 2.0), 1)
	for x in range(-24, 25, 4):
		# tall cabinets either side of her way (2.2 m, office_palette FURNITURE_TOP)
		solid(Vector3(x, 1.1, 1.3), Vector3(1.0, 2.2, 0.6), 1)
		solid(Vector3(x + 2, 1.1, -1.3), Vector3(1.0, 2.2, 0.6), 1)
	# a locker's leaf (2.3 m) and an open door's leaf
	solid(Vector3(-6, 1.15, -0.9), Vector3(1.25, 2.3, 0.05), 8)
	solid(Vector3(6, 1.2, 0.9), Vector3(0.9, 2.1, 0.05), 128)
	# a column of a nave beside her way, its face 0.45 m (lurker_shell RADIUS)
	# from her line (spec_rediseno 9)
	solid(Vector3(10, CEILING * 0.5, 0.75), Vector3(0.6, CEILING, 0.6), 1)
	for x in [-16.0, -8.0, 0.0, 8.0, 16.0]: survivor(x, 0.0)
	body = BODY.instantiate()
	root.add_child(body)
	body.cling = CLING
	body.limbs.modification_processed.connect(keep_arms)
	probe_point.collision_mask = SOLID
	await physics_frame
	var report := {}
	var all_through := 0
	for entry in RUNS:
		var clip: String = entry[0]
		var pace: float = entry[1]
		var seconds: float = entry[2]
		var x := -20.0 if pace > 0.0 else 0.0
		place(x)
		body.play(clip, 0.0)
		var frames := int(seconds * 60.0)
		var through := 0
		var arm_frames := 0
		for i in frames:
			x += pace / 60.0
			if x > 24.0: x = -24.0
			place(x)
			body.velocity = Vector3(pace, 0, 0)
			await physics_frame
			if i < 30: continue
			var bad := arms_through()
			arm_frames += arms.size()
			through += bad
		all_through += through
		report[clip] = {"arm_frames": arm_frames, "through": through, "share": snappedf(float(through) / float(maxi(arm_frames, 1)), 0.0001)}
		print("%s  %d de %d brazos por fotograma atraviesan algo (%.2f %%)" % [clip, through, arm_frames, 100.0 * float(through) / float(maxi(arm_frames, 1))])
	var keys := where.keys()
	keys.sort_custom(func(a, b): return int(where[a]) > int(where[b]))
	for key in keys.slice(0, 12): print("  ", key, ": ", where[key])
	print("  codos sin salida: ", stuck)
	print("  manos agarradas: %.1f %%" % (100.0 * float(holding) / float(maxi(hands, 1))))
	report["holding"] = snappedf(float(holding) / float(maxi(hands, 1)), 0.001)
	var file := FileAccess.open("res://evidence/lurker_elbow_probe.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report, "\t"))
	print("LURKER_ELBOW_PROBE %s %d" % ["PASS" if all_through == 0 else "FAIL", all_through])
	quit(1 if OS.get_cmdline_user_args().has("--strict") and all_through > 0 else 0)

func place(x: float) -> void:
	var y := Vector3.DOWN
	var z := Vector3.RIGHT
	body.global_transform = Transform3D(Basis(y.cross(z), y, z), Vector3(x, CEILING - HANG, 0))

func keep_arms() -> void:
	var skeleton: Skeleton3D = body.skeleton
	var xf := skeleton.global_transform
	arms = []
	for limb in body.limbs.limbs:
		arms.append([xf * skeleton.get_bone_global_pose(limb.upper).origin, xf * skeleton.get_bone_global_pose(limb.fore).origin, xf * skeleton.get_bone_global_pose(limb.hand).origin, bool(limb.elbow_stuck), not bool(limb.free)])

## How many arms have a point, shoulder to elbow to wrist, inside something solid.
func arms_through() -> int:
	var space := body.get_world_3d().direct_space_state
	var count := 0
	for arm in arms:
		var shoulder: Vector3 = arm[0]
		var elbow: Vector3 = arm[1]
		var wrist: Vector3 = arm[2]
		var hit := false
		if bool(arm[3]): stuck += 1
		hands += 1
		if bool(arm[4]): holding += 1
		for k in range(1, SAMPLES + 1):
			var t := float(k) / float(SAMPLES)
			var parts := [["upper", shoulder.lerp(elbow, t)], ["fore", elbow.lerp(wrist, minf(t, 0.85))]]
			for part in parts:
				probe_point.position = part[1]
				var found := space.intersect_point(probe_point, 1)
				if not found.is_empty():
					hit = true
					var layer: int = (found[0].collider as CollisionObject3D).collision_layer
					var key := "%s capa %d a %.2f" % [part[0], layer, t]
					where[key] = int(where.get(key, 0)) + 1
					break
			if hit: break
		if hit: count += 1
	return count
