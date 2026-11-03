extends RefCounted
## Saves that cannot lose what was kept. Opening the real file to write empties
## it, so a full disk or a crash left it cut short, the next start took it for
## an empty one, and the first save after that wrote over it for good.

## The whole text into `temp`, read back to be sure: a full disk says nothing
## until then. False leaves no temp behind.
static func write_temp(temp: String, text: String) -> bool:
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if not file: return false
	file.store_string(text)
	file.close()
	if FileAccess.get_file_as_string(temp) == text: return true
	DirAccess.remove_absolute(temp)
	return false

## The file replaced only once the whole new one exists.
static func write(path: String, text: String) -> bool:
	var temp := path + ".tmp"
	return write_temp(temp, text) and DirAccess.rename_absolute(temp, path) == OK

## The table in a text, or {} if it holds none. Quiet: JSON.parse_string() logs an engine error.
static func parse(text: String) -> Dictionary:
	var json := JSON.new()
	return json.data if json.parse(text) == OK and json.data is Dictionary else {}

## What a save holds, or {}. One that cannot be read is set aside whole, where
## the next save will not write over it.
static func read(path: String) -> Dictionary:
	# A crash in the middle of replacing it: the temp is all there is, and whole.
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".tmp"): DirAccess.rename_absolute(path + ".tmp", path)
	if not FileAccess.file_exists(path): return {}
	var text := FileAccess.get_file_as_string(path)
	var data := parse(text)
	if data.is_empty() and text.strip_edges() != "{}": DirAccess.rename_absolute(path, path + ".corrupt")
	return data
