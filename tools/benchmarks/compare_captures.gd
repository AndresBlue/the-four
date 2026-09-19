extends SceneTree
## Compares two benchmark capture folders image by image (same file names).
##   godot --headless --path . --script res://tools/benchmarks/compare_captures.gd -- --before=res://evidence/bench/base_forward_plus --after=res://evidence/bench/x_forward_plus [--only=_raw]
## Per image: mean absolute difference (0..255), largest difference, and the
## share of pixels differing by more than THRESHOLD in any channel. Writes an
## amplified difference image next to the "after" captures (diff_<name>).
const THRESHOLD := 12

func _initialize() -> void:
	var before := ""
	var after := ""
	var only := "_raw"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--before="): before = argument.trim_prefix("--before=")
		if argument.begins_with("--after="): after = argument.trim_prefix("--after=")
		if argument.begins_with("--only="): only = argument.trim_prefix("--only=")
	var rows: Array = []
	for file in DirAccess.get_files_at(before):
		if not file.ends_with(".png") or not file.contains(only) or file.begins_with("diff_"): continue
		if not FileAccess.file_exists(after + "/" + file):
			print("COMPARE missing ", file)
			continue
		rows.append(compare(before + "/" + file, after + "/" + file, after + "/diff_" + file))
		print("COMPARE ", JSON.stringify(rows[-1]))
	var report := FileAccess.open(after + "/compare.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"before": before, "after": after, "threshold": THRESHOLD, "images": rows}, "\t"))
	report.close()
	quit()

func compare(a_path: String, b_path: String, diff_path: String) -> Dictionary:
	var a := Image.load_from_file(ProjectSettings.globalize_path(a_path))
	var b := Image.load_from_file(ProjectSettings.globalize_path(b_path))
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	if a.get_size() != b.get_size(): return {"image": a_path.get_file(), "error": "size"}
	var da := a.get_data()
	var db := b.get_data()
	var out := PackedByteArray()
	out.resize(da.size())
	var total := 0
	var largest := 0
	var over := 0
	for i in range(0, da.size(), 3):
		var worst := 0
		for c in 3:
			var d := absi(da[i + c] - db[i + c])
			total += d
			worst = maxi(worst, d)
			out[i + c] = mini(255, d * 8)
		largest = maxi(largest, worst)
		if worst > THRESHOLD: over += 1
	Image.create_from_data(a.get_width(), a.get_height(), false, Image.FORMAT_RGB8, out).save_png(ProjectSettings.globalize_path(diff_path))
	var pixels := da.size() / 3
	return {"image": a_path.get_file(), "mean_abs": snappedf(float(total) / da.size(), 0.001), "max": largest, "over_threshold_pct": snappedf(100.0 * over / pixels, 0.001)}
