extends SceneTree
## What the package weighs and why. It walks everything the game can reach --
## the main scene, every scene and resource under game/, and every path a
## script loads -- and follows the dependencies down to the files. Whatever is
## in assets/ and nobody reaches is dead weight in the export.
##
##   godot --headless --script tools/dev/asset_weight.gd
##
## The numbers it prints are the imported sizes (what actually ships), not the
## size of the originals.
const ROOTS := ["res://game", "res://tools/dev", "res://tests"]

func _initialize() -> void:
	var reached := {}
	var queue: Array[String] = []
	# Everything the project itself names: scenes, resources and the paths
	# written into scripts.
	for path in scan("res://game", [".tscn", ".tres", ".material", ".gd"]): queue.append(path)
	queue.append(ProjectSettings.get_setting("application/run/main_scene", ""))
	for path in scan("res://game", [".gd"]) + scan("res://tools", [".gd"]) + scan("res://tests", [".gd"]):
		for quoted in quoted_paths(path): queue.append(quoted)
	var cursor := 0
	while cursor < queue.size():
		var path: String = queue[cursor]
		cursor += 1
		if path.is_empty() or reached.has(path) or not ResourceLoader.exists(path): continue
		reached[path] = true
		for dependency in ResourceLoader.get_dependencies(path):
			# "uid::path" or plain path.
			var plain: String = dependency.get_slice("::", dependency.get_slice_count("::") - 1)
			if plain.begins_with("res://"): queue.append(plain)
	var orphan_bytes := 0
	var used_bytes := 0
	var orphans: Array = []
	var used: Array = []
	for path in scan("res://assets", []):
		var weight := imported_size(path)
		if reached.has(path):
			used_bytes += weight
			used.append([weight, path])
			continue
		orphan_bytes += weight
		orphans.append([weight, path])
	orphans.sort_custom(func(one, two): return one[0] > two[0])
	used.sort_custom(func(one, two): return one[0] > two[0])
	print("alcanzable ", size_text(used_bytes), " · huérfano ", size_text(orphan_bytes))
	print("lo más pesado que sí se usa:")
	for entry in used.slice(0, 20): print("  %8s  %s" % [size_text(int(entry[0])), entry[1]])
	print("lo más pesado que nadie usa:")
	for entry in orphans.slice(0, 25): print("  %8s  %s" % [size_text(int(entry[0])), entry[1]])
	var by_folder := {}
	for entry in orphans:
		var folder: String = String(entry[1]).get_base_dir()
		by_folder[folder] = int(by_folder.get(folder, 0)) + int(entry[0])
	var folders: Array = by_folder.keys()
	folders.sort_custom(func(one, two): return by_folder[one] > by_folder[two])
	print("por carpeta:")
	for folder in folders.slice(0, 15): print("  %8s  %s" % [size_text(int(by_folder[folder])), folder])
	quit()

## Every file under a folder, filtered by extension (empty: all of them).
func scan(root: String, kinds: Array) -> Array[String]:
	var found: Array[String] = []
	var directories: Array[String] = [root]
	while not directories.is_empty():
		var here: String = directories.pop_back()
		var directory := DirAccess.open(here)
		if directory == null: continue
		directory.list_dir_begin()
		var name := directory.get_next()
		while name != "":
			var path: String = here.path_join(name)
			if directory.current_is_dir(): directories.append(path)
			elif kinds.is_empty() or path.get_extension().insert(0, ".") in kinds:
				if not path.ends_with(".import") and not path.ends_with(".uid"): found.append(path)
			name = directory.get_next()
		directory.list_dir_end()
	return found

## The res:// paths written inside a script. A path a script builds while it
## runs ("res://assets/players/%s/model.fbx") names no one file, so everything
## under the folder above the hole counts as reachable -- that is exactly what
## it is: a folder the game picks from.
func quoted_paths(path: String) -> Array[String]:
	var found: Array[String] = []
	var text := FileAccess.get_file_as_string(path)
	var search := RegEx.create_from_string("res://[^\"']+")
	for hit in search.search_all(text):
		var quoted: String = hit.get_string()
		if not quoted.contains("%"):
			found.append(quoted)
			continue
		var root: String = quoted.get_slice("%", 0).get_base_dir()
		if root.begins_with("res://assets") or root.begins_with("res://game"): found.append_array(scan(root, []))
	return found

## What a file weighs once imported: the resource the export ships, or the
## file itself when it is not imported at all.
func imported_size(path: String) -> int:
	var settings := path + ".import"
	if FileAccess.file_exists(settings):
		var config := ConfigFile.new()
		if config.load(settings) == OK:
			var total := 0
			for destination in config.get_value("deps", "dest_files", []):
				total += FileAccess.get_file_as_bytes(String(destination)).size()
			if total > 0: return total
	return FileAccess.get_file_as_bytes(path).size()

func size_text(bytes: int) -> String:
	if bytes > 1048576: return "%.1f MB" % (float(bytes) / 1048576.0)
	return "%.0f kB" % (float(bytes) / 1024.0)
