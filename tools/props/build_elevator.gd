extends SceneTree
## Bakes "Elevator with Animation LOWPOLY" (EFX, CC BY; assets/props/elevator/
## elevator.fbx, docs/ASSETS.md) into the pieces hotel_geometry.build_car()
## puts together, at LIFT_SCALE of the model's size, in the car's space: the
## middle of the doorway at x = 0, the car's floor at y = 0, the outer face of
## its front at z = 0 and the car behind it, towards -Z.
##   lift_car.res     the car: shell, wood, floor, light strips, the panel of
##                    buttons inside (every row of the model's)
##   lift_door_a.res  the leaf nearer the side the doors open to, shut
##   lift_door_b.res  the other one, shut
##   lift_call.res    the call buttons outside, centred, back at z = 0
##   lift_screen.res  the display over the doors outside, centred, back at z = 0
## The model's wall round the car (its wallpaper) is left out: the car goes
## into a wall of the hotel's own (hotel_geometry.lift_wall()). It prints the
## numbers build_car() is written against.
##   godot --headless --path . --script res://tools/props/build_elevator.gd
const SOURCE := "res://assets/props/elevator/elevator.fbx"
const OUTPUT := "res://assets/props/elevator/"
const MATERIALS := "res://game/presentation/materials/"
## The model is a third bigger than a lift: doors 2.8 m high and a car four
## metres across. At 0.8 the doors are 2.2 m and the car 3.5 by 2.1.
const LIFT_SCALE := 0.8
## The middle of the doorway on the car's floor, at the outer face of its
## front, in the model's metres.
const ORIGIN := Vector3(0.023, -0.02, 1.17)
const SLOTS := {"ElevatorMetal": "lift_metal.tres", "ElevatorFloor": "lift_floor.tres", "WallsWood": "lift_wood.tres", "LightEmis": "lift_light.tres", "MetalDark": "lift_metal_dark.tres", "Buttons": "lift_buttons.tres", "ElevatorScreen": "lift_screen.tres", "ButtonsExtra": "lift_call.tres"}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene: Node3D = load(SOURCE).instantiate()
	root.add_child(scene)
	var fit := Transform3D(Basis.from_scale(Vector3.ONE * LIFT_SCALE), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -ORIGIN)
	bake(scene, ["Elevator", "ButtonsPanel"], fit, "lift_car.res")
	bake(scene, ["Door1"], fit, "lift_door_a.res")
	bake(scene, ["Door2"], fit, "lift_door_b.res")
	for pair in [["OutsideButtons", "lift_call.res"], ["ScreenOutside", "lift_screen.res"]]:
		var box := bounds(scene.get_node(pair[0]), fit)
		bake(scene, [pair[0]], Transform3D(Basis.IDENTITY, -Vector3(box.get_center().x, box.get_center().y, box.position.z)) * fit, pair[1])
		print("  %s sits at %s in the model's layout" % [pair[0], Vector3(box.get_center().x, box.get_center().y, box.position.z)])
	# Where the leaves go: the animation's open keys, in the car's space.
	var player: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var anim: Animation = player.get_animation("Scene")
	for t in anim.get_track_count():
		var xs: Array = []
		for k in anim.track_get_key_count(t): xs.append((anim.track_get_key_value(t, k) as Vector3).x)
		print("  %s: shut %.3f, open %.3f (model x)" % [anim.track_get_path(t), xs[0], xs.min()])
	# The inside of the car and the screen of the panel, for build_car().
	var floor_box := surface_bounds(scene.get_node("Elevator"), "ElevatorFloor", fit)
	var wood_box := surface_bounds(scene.get_node("Elevator"), "WallsWood", fit)
	print("  floor ", floor_box, " wood ", wood_box)
	print("  shell ", bounds(scene.get_node("Elevator"), fit))
	print("  panel screen ", surface_bounds(scene.get_node("ButtonsPanel"), "ElevatorScreen", fit))
	print("  leaves ", bounds(scene.get_node("Door1"), fit), " ", bounds(scene.get_node("Door2"), fit))
	scene.queue_free()
	quit()

func bounds(mesh: MeshInstance3D, fit: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	for surface in mesh.mesh.get_surface_count():
		for v in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var p: Vector3 = fit * (mesh.global_transform * v)
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
	return box

func surface_bounds(mesh: MeshInstance3D, slot: String, fit: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	for surface in mesh.mesh.get_surface_count():
		if mesh.mesh.surface_get_material(surface).resource_name != slot: continue
		for v in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var p: Vector3 = fit * (mesh.global_transform * v)
			box = AABB(p, Vector3.ZERO) if first else box.expand(p)
			first = false
	return box

## The named meshes as one, a surface per material.
func bake(scene: Node3D, names: Array, fit: Transform3D, output: String) -> void:
	var groups := {}
	for name in names:
		var mesh: MeshInstance3D = scene.get_node(name)
		for surface in mesh.mesh.get_surface_count():
			var slot: String = mesh.mesh.surface_get_material(surface).resource_name
			if not groups.has(slot):
				groups[slot] = SurfaceTool.new()
				groups[slot].begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[slot].append_from(mesh.mesh, surface, fit * mesh.global_transform)
	var combined := ArrayMesh.new()
	for slot in groups:
		var tool: SurfaceTool = groups[slot]
		tool.generate_tangents()
		tool.commit(combined)
		combined.surface_set_material(combined.get_surface_count() - 1, load(MATERIALS + SLOTS[slot]))
	ResourceSaver.save(combined, OUTPUT + output)
	print("BAKED ", output, " surfaces=", combined.get_surface_count(), " aabb=", combined.get_aabb())
