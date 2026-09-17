extends SceneTree
## Loads every script under game/ and tests/ so parse and type errors show up
## at once, without starting the game.
##
## tools/dev is deliberately not in the list: loading a script from here with
## CACHE_MODE_IGNORE would reload this very file while it is running, which
## breaks the running function and then hangs the process.
func _initialize() -> void:
	var failed := 0
	for root_path in ["res://game", "res://tests", "res://tools/capture", "res://tools/audio"]:
		for path in collect(root_path):
			var script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if script == null or not script.can_instantiate():
				failed += 1
				print("BROKEN ", path)
	print("SCRIPTS_BROKEN ", failed)
	quit(1 if failed > 0 else 0)

func collect(path: String) -> Array:
	var result: Array = []
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".gd"): result.append(path.path_join(file))
	for folder in DirAccess.get_directories_at(path): result.append_array(collect(path.path_join(folder)))
	return result
