extends SceneTree
func count(level) -> String:
	var n := 0
	var names := []
	for child in level.get_children():
		if child is Node3D and child.get_child_count() > 0 and child.get_child(0) is MultiMeshInstance3D:
			n += 1
			names.append(child.name)
	return "%d %s" % [n, names]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	await level.take_locust(81)
	print("after first: ", count(level))
	for i in 120: await physics_frame
	await level.take_locust(82)
	await process_frame
	await process_frame
	print("after second: ", count(level))
	level.on_action("retry")
	for i in 200: await process_frame
	print("after retry: ", count(level), " state=", level.session.state)
	quit()
