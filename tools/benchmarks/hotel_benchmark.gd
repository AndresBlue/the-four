extends SceneTree
## Frame cost of the hotel at 1080p, per quality: three still views and a walk
## along the route from the reception, which is what a real run looks like
## (moving casters re-render the shadows round them).
##   godot --path . --script res://tools/benchmarks/hotel_benchmark.gd -- --test-profile --automation --no-enemy --silent [--bench-label=name]
## Writes evidence/bench/<label>/report.json and, per quality and view, a
## capture without the tape filter (<view>_q<n>_raw.png, for
## tools/benchmarks/compare_captures.gd) and one with it (_vhs.png, as played).
## evidence/hotel_benchmark_<renderer>.json keeps the old summary.
## Each quality is a whole graphics preset, render scale included.
##   --qualities=0,3         only these presets (all four by default)
##   --set=key:value[,...]   force preset values (graphics_presets.gd keys) over
##                           every preset, to measure one effect at a time,
##                           e.g. --set=ssil:-1 or --set=msaa:0,taa:false
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const STILL_FRAMES := 120
const WALK_FRAMES := 240
## Walking pace in metres per frame (6 m/s at 60 fps), whatever the real rate,
## so every run walks the same route.
const WALK_STEP := 0.1
var label := "current"
var out_dir := ""

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var qualities := range(PRESETS.count())
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--bench-label="): label = argument.trim_prefix("--bench-label=")
		if argument.begins_with("--qualities="): qualities = Array(argument.trim_prefix("--qualities=").split(",")).map(func(q): return int(q))
		if argument.begins_with("--set="):
			for pair in argument.trim_prefix("--set=").split(","):
				var key := pair.get_slice(":", 0)
				var text := pair.get_slice(":", 1)
				# a/b is a pair (lamp_fade:36/12).
				if "/" in text: PRESETS.overrides[key] = Array(text.split("/")).map(func(v): return float(v))
				else: PRESETS.overrides[key] = (text == "true") if text in ["true", "false"] else (float(text) if "." in text else int(text))
	out_dir = "res://evidence/bench/%s_%s" % [label, RenderingServer.get_current_rendering_method()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var level = load("res://game/app/hotel.tscn").instantiate()
	root.add_child(level)
	var load_start := Time.get_ticks_msec()
	await level.start_floor(81)
	var load_ms := Time.get_ticks_msec() - load_start
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var viewport_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	# The walk: the navigation route from the reception towards the exit.
	var route := FLOOR.navigation_path(level.get_world_3d().navigation_map, Vector3(0, 0.04, 0), FLOOR.position_of(level.manifest.rooms[int(level.manifest.exit)]))
	var results: Array = []
	var legacy: Array = []
	var peak_memory := 0.0
	for quality in qualities:
		# Through the settings, as the menu does: the preset's render scale too.
		level.settings.set_value("quality", quality)
		# Presets with bounce light bake it now, on worker threads.
		await level.bounce_ready()
		# A forced scale wins over the preset's (--set=scale:0.5).
		if PRESETS.overrides.has("scale"): level.settings.set_value("scale", PRESETS.overrides.scale)
		# The settings put back their frame cap and vsync: unlimited again.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--atlas-quads="):
				var quads := argument.trim_prefix("--atlas-quads=").split(",")
				for q in 4: root.get_viewport().set_positional_shadow_atlas_quadrant_subdiv(q, int(quads[q]))
			# A/B of the soft shadow filter (RenderingServer.ShadowQuality, 0..5).
			if argument.begins_with("--shadow-filter="):
				RenderingServer.positional_soft_shadow_filter_set_quality(int(argument.trim_prefix("--shadow-filter=")))
		var all_frames: Array = []
		for id in [0, 36, int(level.manifest.exit)]:
			var room: Dictionary = level.manifest.rooms[id]
			level.player.position = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
			level.player.rotation.y = 0.65
			level.player.camera.rotation.x = -0.1
			level.hotel.update_visibility(level.player.position, true)
			await settle()
			await capture(level, "room%d_q%d" % [id, quality])
			var frames := await sample(level, viewport_rid, STILL_FRAMES, Callable())
			peak_memory = maxf(peak_memory, Performance.get_monitor(Performance.MEMORY_STATIC))
			results.append(summary("still_room%d" % id, quality, frames))
			all_frames.append_array(frames)
		# Walking: the body moves every frame, as in play.
		level.player.position = route[0] if route.size() > 0 else Vector3(0, 0.04, 0)
		await settle()
		var walked := [0.0]
		var step := func(_frame: int) -> void:
			walked[0] += WALK_STEP
			var point := along(route, walked[0])
			var ahead := along(route, walked[0] + 1.0)
			level.player.position = point + Vector3(0, 0.04, 0)
			var direction := Vector3(ahead.x - point.x, 0, ahead.z - point.z)
			if direction.length() > 0.01: level.player.rotation.y = atan2(-direction.x, -direction.z)
		var walk := await sample(level, viewport_rid, WALK_FRAMES, step)
		results.append(summary("walk", quality, walk))
		all_frames.append_array(walk)
		results.append({"view": "memory", "quality": quality, "video_mem_used": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED), "texture_mem_used": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED), "buffer_mem_used": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)})
		var times: Array = all_frames.map(func(f): return f.frame_ms)
		times.sort()
		legacy.append({"quality": quality, "mean_frame_ms": mean(times), "p95_frame_ms": times[int(times.size() * 0.95)], "sample_count": times.size()})
	var memory := {"video_mem_used": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED), "texture_mem_used": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED), "buffer_mem_used": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED), "peak_static_memory_bytes": peak_memory}
	var report := {"label": label, "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "viewport": str(root.size), "rooms": level.manifest.rooms.size(), "floor_load_ms": load_ms, "node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "memory": memory, "results": results}
	var file := FileAccess.open(out_dir + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	var old := FileAccess.open("res://evidence/hotel_benchmark_%s.json" % RenderingServer.get_current_rendering_method(), FileAccess.WRITE)
	old.store_string(JSON.stringify({"renderer": report.renderer, "viewport": report.viewport, "rooms": report.rooms, "results": legacy, "floor_load_ms": load_ms, "peak_static_memory_bytes": peak_memory, "node_count": report.node_count}, "\t"))
	old.close()
	for entry in results: print("BENCHMARK ", JSON.stringify(entry))
	print("BENCHMARK_MEMORY ", JSON.stringify(memory))
	paused = false
	level.queue_free()
	await process_frame
	quit()

## At least 1.5 s and 60 frames: the shadow atlas moves a light to a better
## slot only 0.5 s after placing it, so a shorter wait measures that shuffle.
func settle() -> void:
	var started := Time.get_ticks_msec()
	var frames := 0
	while frames < 60 or Time.get_ticks_msec() - started < 1500:
		await process_frame
		frames += 1

## Point at a distance along a polyline (its end past the last point).
static func along(line: PackedVector3Array, distance: float) -> Vector3:
	if line.is_empty(): return Vector3.ZERO
	var travelled := 0.0
	for i in range(1, line.size()):
		var segment := line[i].distance_to(line[i - 1])
		if travelled + segment >= distance: return line[i - 1].lerp(line[i], (distance - travelled) / maxf(segment, 0.0001))
		travelled += segment
	return line[line.size() - 1]

func sample(level: Node, viewport_rid: RID, count: int, step: Callable) -> Array:
	var frames: Array = []
	for frame in count:
		if step.is_valid(): step.call(frame)
		var started := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		await process_frame
		var viewport := root.get_viewport()
		frames.append({
			"frame_ms": (Time.get_ticks_usec() - started) / 1000.0,
			"gpu_ms": RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid),
			"render_cpu_ms": RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid) + RenderingServer.get_frame_setup_time_cpu(),
			"draws": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"objects": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
			"primitives": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
			"shadow_draws": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			"shadow_primitives": viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		})
	return frames

static func mean(values: Array) -> float:
	var total := 0.0
	for value in values: total += float(value)
	return total / maxf(1.0, values.size())

static func percentile(sorted: Array, share: float) -> float:
	return float(sorted[mini(sorted.size() - 1, int(sorted.size() * share))])

func summary(view: String, quality: int, frames: Array) -> Dictionary:
	var entry := {"view": view, "quality": quality, "samples": frames.size()}
	for key in ["frame_ms", "gpu_ms", "render_cpu_ms"]:
		var values: Array = frames.map(func(f): return f[key])
		values.sort()
		entry[key] = {"mean": snappedf(mean(values), 0.001), "p95": snappedf(percentile(values, 0.95), 0.001), "p99": snappedf(percentile(values, 0.99), 0.001), "max": snappedf(values[-1], 0.001)}
	for key in ["draws", "objects", "primitives", "shadow_draws", "shadow_primitives"]:
		var values: Array = frames.map(func(f): return f[key])
		values.sort()
		entry[key] = {"mean": int(mean(values)), "max": int(values[-1])}
	return entry

## The same view without the camera's lens, sensor and tape (stable, for pixel
## comparison) and with them (as played).
func capture(level: Node, name: String) -> void:
	var screen: CanvasItem = level.get_node("Presentation/Analog/Screen")
	var lens: CanvasLayer = level.get_node("Presentation/Lens")
	var camcorder: CanvasLayer = level.get_node("Presentation/Camcorder")
	# The reception beacon and the failing tubes blink with time: freeze them lit.
	level.hotel.flicker_clock = 0.4
	level.hotel._process(0.0)
	level.hotel.set_process(false)
	screen.visible = false
	lens.visible = false
	var marks = level.settings.values.osd
	level.settings.values.osd = false
	camcorder.visible = false
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/%s_raw.png" % name)
	screen.visible = true
	lens.visible = true
	level.settings.values.osd = marks
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir + "/%s_vhs.png" % name)
	level.hotel.set_process(true)
