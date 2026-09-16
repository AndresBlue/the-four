extends SceneTree
func _initialize() -> void:
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://docs/assets/sfx_inventory.json"))
	var decoded := []
	for item in catalog:
		if item.working_copy == null: continue
		var stream: AudioStream = load("res://" + item.working_copy)
		if stream == null or stream.get_length() <= 0:
			push_error("Audio could not be decoded: " + item.working_copy)
			quit(1)
			return
		decoded.append({"source": item.source, "working_copy": item.working_copy, "seconds": stream.get_length(), "status": item.status})
	var file := FileAccess.open("res://docs/assets/sfx_runtime_inventory.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(decoded, "\t"))
	file.close()
	print("SFX_DECODED ", decoded.size())
	quit()
