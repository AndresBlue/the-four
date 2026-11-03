extends Node
## Persistent record of the documents the player has read, kept apart from
## settings and checkpoints. Reading order is kept for the archive screen.
signal changed
const SAVE_FILE := preload("res://game/services/save_file.gd")
var save_path := "user://discoveries.json"
var found: Array[String] = []

func _ready() -> void:
	load_record()

func load_record() -> void:
	found.clear()
	var data := SAVE_FILE.read(save_path)
	if data.get("found") is Array:
		for id in data.found:
			if id is String and not found.has(id): found.append(id)

## Returns true the first time an entry is recorded.
func record(id: String) -> bool:
	if found.has(id): return false
	found.append(id)
	SAVE_FILE.write(save_path, JSON.stringify({"version": 1, "found": found}, "\t"))
	changed.emit()
	return true

func has(id: String) -> bool:
	return found.has(id)
