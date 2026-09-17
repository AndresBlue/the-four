extends Node
## Persistent record of the documents the player has read, kept apart from
## settings and checkpoints. Reading order is kept for the archive screen.
signal changed
var save_path := "user://discoveries.json"
var found: Array[String] = []

func _ready() -> void:
	load_record()

func load_record() -> void:
	found.clear()
	if not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if data is Dictionary and data.get("found") is Array:
		for id in data.found:
			if id is String and not found.has(id): found.append(id)

## Returns true the first time an entry is recorded.
func record(id: String) -> bool:
	if found.has(id): return false
	found.append(id)
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"version": 1, "found": found}, "\t"))
		file.close()
	changed.emit()
	return true

func has(id: String) -> bool:
	return found.has(id)
