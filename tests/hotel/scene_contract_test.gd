extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(label: String, result: bool) -> void:
	checks += 1
	print("PASS " if result else "FAIL ", label)
	if not result: failures.append(label)
func run() -> void:
	var packed := load("res://game/app/hotel.tscn") as PackedScene
	var a := packed.instantiate()
	var b := packed.instantiate()
	check("Composition contains named authoring nodes", a.has_node("Services/Settings") and a.has_node("Services/GameSession") and a.has_node("Player/Camera/Flashlight") and a.has_node("Interface/HUD/Subtitle"))
	var capsule_a: CapsuleShape3D = a.get_node("Player/BodyShape").shape
	var capsule_b: CapsuleShape3D = b.get_node("Player/BodyShape").shape
	capsule_a.height = 1.05
	check("Crouching does not mutate another player instance", is_equal_approx(capsule_b.height, 1.8))
	var env_a: Environment = a.get_node("Presentation/WorldEnvironment").environment
	var env_b: Environment = b.get_node("Presentation/WorldEnvironment").environment
	env_a.fog_density = 0.9
	check("Environment settings stay local to a scene", is_equal_approx(env_b.fog_density, (load("res://game/presentation/hotel_environment.tres") as Environment).fog_density))
	var fx_a: ShaderMaterial = a.get_node("Presentation/Analog/Screen").material
	var fx_b: ShaderMaterial = b.get_node("Presentation/Analog/Screen").material
	check("Postprocessing state is not shared", fx_a != fx_b)
	a.free()
	b.free()
	var scene := packed.instantiate()
	root.add_child(scene)
	check("Services are assigned before children are ready", scene.player.settings == scene.settings and scene.ui.settings == scene.settings)
	check("Presentation uses AgX tone mapping and colour ambient", scene.environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR and scene.environment.tonemap_mode == Environment.TONE_MAPPER_AGX)
	# The tape records what the camera saw and everything written over it:
	# the OSD first, the interface on top of that, and the analog filter
	# above both, so a menu is on the tape and not on the glass.
	check("The tape records the OSD and the interface alike", scene.get_node("Presentation/Camcorder").layer < scene.ui.layer and scene.ui.layer < scene.get_node("Presentation/Analog").layer)
	scene.queue_free()
	await process_frame
	var gallery: Node = load("res://tools/workbenches/module_gallery.tscn").instantiate()
	check("Gallery contains all twenty reference modules", gallery.get_node("Modules").get_child_count() == 20)
	check("Gallery contains no runtime generator", gallery.get_node("Modules").get_script() == null)
	var floors := gallery.find_children("Mesh_carpet_*", "MeshInstance3D", true, false)
	check("Saved gallery retains nondegenerate floor geometry", floors.size() > 0 and absf(floors[0].transform.basis.determinant()) > 1.0)
	gallery.free()
	var file := FileAccess.open("res://evidence/scene_contracts.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures}, "\t"))
	file.close()
	print("SCENE_CONTRACTS ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)
