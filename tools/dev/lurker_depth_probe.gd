extends SceneTree
## How far below the ceiling The Lurker's body hangs (spec_f2_movement 12,
## step 1): lurker.tscn upside down under a 2.95 m ceiling, its anchor at the
## shell's default hang (0.35), going along it at each clip's pace for five
## seconds per clip while its hands hold on (lurker_limbs.gd), and the
## farthest any bone gets from the anchor along its +Y (away from the
## ceiling), plus 0.05 for the skin. Not in verify.ps1.
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev/lurker_depth_probe.gd -- --test-profile
const BODY := preload("res://game/enemies/lurker/lurker.tscn")
const CEILING := 2.95
const HANG := 0.35
const SKIN := 0.05
const SECONDS := 5.0
## Each clip and the pace it is shown at (lurker_motion.gd's speeds).
const CLIPS := [["idle", 0.0], ["crawl", 1.35], ["crawl_fast", 3.5], ["peek", 0.0]]
## Her hands on a ceiling, as lurker.gd sets it on a tray.
const CLING := 0.3
## Half the room's width: an office, not the bench's corridor.
const HALF_WIDTH := 6.0
## The body itself, apart from its arms.
const TRUNK := ["body", "abdomen", "head"]

var body: Node3D
var results := {}
## Every bone's depth as the hands left it (read when the modifier has run:
## afterwards the skeleton is back at the clip's pose), [depth, name].
var sampled: Array = []

func _initialize() -> void: run.call_deferred()

func slab(at: Vector3, size: Vector3) -> void:
	var solid := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	solid.add_child(shape)
	solid.position = at
	root.add_child(solid)

func run() -> void:
	slab(Vector3(0, CEILING + 0.1, 0), Vector3(80, 0.2, HALF_WIDTH * 2.0))
	slab(Vector3(0, -0.1, 0), Vector3(80, 0.2, HALF_WIDTH * 2.0))
	slab(Vector3(0, CEILING / 2.0, -HALF_WIDTH), Vector3(80, CEILING, 0.2))
	slab(Vector3(0, CEILING / 2.0, HALF_WIDTH), Vector3(80, CEILING, 0.2))
	body = BODY.instantiate()
	root.add_child(body)
	body.cling = CLING
	body.limbs.modification_processed.connect(func(): sampled = bone_depths())
	await physics_frame
	var worst := 0.0
	var worst_clip := ""
	for entry in CLIPS:
		var clip: String = entry[0]
		var pace: float = entry[1]
		var x := -30.0
		place(x)
		body.play(clip, 0.0)
		var deepest := 0.0
		var bones := {}
		var frames := int(SECONDS * 60.0)
		for i in frames:
			x += pace / 60.0
			place(x)
			body.velocity = Vector3(pace, 0, 0)
			await physics_frame
			if i < 30: continue
			for b in sampled:
				deepest = maxf(deepest, float(b[0]))
				bones[b[1]] = maxf(float(bones.get(b[1], -INF)), float(b[0]))
		var names: Array = bones.keys()
		names.sort_custom(func(a, b): return float(bones[a]) > float(bones[b]))
		results[clip] = snappedf(deepest + SKIN, 0.001)
		var trunk := 0.0
		for n in TRUNK: trunk = maxf(trunk, float(bones.get(n, 0.0)))
		results[clip + "_trunk"] = snappedf(trunk + SKIN, 0.001)
		print("%s  %.3f m, trunk %.3f m  %s" % [clip, deepest + SKIN, trunk + SKIN, str(names.slice(0, 4).map(func(n): return "%s %.2f" % [n, float(bones[n])]))])
		if deepest + SKIN > worst:
			worst = deepest + SKIN
			worst_clip = clip
	print("LURKER_BODY_DEPTH %.3f (%s)" % [worst, worst_clip])
	var file := FileAccess.open("res://evidence/lurker_depth_probe.json", FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"clips": results, "body_depth": snappedf(worst, 0.001), "clip": worst_clip}, "\t"))
	quit()

## Upside down under the ceiling, facing +X, at the default hang.
func place(x: float) -> void:
	var y := Vector3.DOWN
	var z := Vector3.RIGHT
	body.global_transform = Transform3D(Basis(y.cross(z), y, z), Vector3(x, CEILING - HANG, 0))

## Every bone's distance from the anchor along the body's +Y, [depth, name].
func bone_depths() -> Array:
	var skeleton: Skeleton3D = body.skeleton
	var anchor: Vector3 = body.global_position
	var up: Vector3 = body.global_basis.y
	var out: Array = []
	for bone in skeleton.get_bone_count():
		var at := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
		out.append([(at - anchor).dot(up), skeleton.get_bone_name(bone)])
	return out

