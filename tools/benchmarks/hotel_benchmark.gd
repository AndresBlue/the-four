extends SceneTree
## Frame cost of the hotel at 1080p, per quality: three still views and a walk
## along the route from the reception, which is what a real run looks like
## (moving casters re-render the shadows round them).
##   godot --path . --script res://tools/benchmarks/hotel_benchmark.gd -- --test-profile --automation --no-enemy --silent [--bench-label=name] [--floor=2] [--seed=N] [--difficulty=apacible]
## --floor=2 measures the offices (hotel_main.floor_asked() picks the floor); --seed= replaces the hotel's 81; --difficulty= the settings' difficulty.
## Writes evidence/bench/<label>/report.json and, per quality and view, a
## capture without the tape filter (<view>_q<n>_raw.png, for
## tools/benchmarks/compare_captures.gd) and one with it (_vhs.png, as played).
## evidence/hotel_benchmark_<renderer>.json keeps the old summary.
## Each quality is a whole graphics preset, render scale included.
## Every view also says where the main thread's time went (`cpu`): a physics
## tick (the scripts' _physics_process, the physics and the navigation), a
## frame's _process, and drawing it. Unlimited, a frame only has a physics
## tick in it now and then, and its mean hides them; at 60 FPS every frame
## has one, so what a frame costs there is `at_60`: one of each.
##   --qualities=0,3         only these presets (all four by default)
##   --set=key:value[,...]   force preset values (graphics_presets.gd keys) over
##                           every preset, to measure one effect at a time,
##                           e.g. --set=ssil:-1 or --set=msaa:0,taa:false
##   --setting=key:value[,.] the player's own settings (settings_service.gd), set
##                           after each preset: --setting=upscaler:bilinear
##   --passes                where the frame goes: every view also gets the
##                           stages of the 3D render with their mean GPU and
##                           CPU time (see Mark below); Forward+ only
##   --hide=Analog,Lens      canvas layers of Presentation left out, to measure
##                           what the tape filter, the lens or the OSD cost
##   --size=1280x720         the window, 1920x1080 by default
##   --pixels=9              everything is drawn with this many times the
##                           window's pixels (the root viewport, stretched
##                           back): on this card that stands for a GPU that
##                           many times slower at filling them, which is what
##                           an integrated one is short of (docs/PERFORMANCE.md,
##                           "Equipo modesto"). No captures, and the video
##                           memory it reports is not the game's.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const STILL_FRAMES := 120
const WALK_FRAMES := 240
## Arriving in a room for the first time: how many rooms, and how many frames
## are watched from the moment the camera lands (no settling, on purpose).
const ARRIVALS := 8
const ARRIVAL_FRAMES := 20
## Walking pace in metres per frame (6 m/s at 60 fps), whatever the real rate,
## so every run walks the same route.
const WALK_STEP := 0.1
var label := "current"
var out_dir := ""
var passes := false
var window := Vector2i(1920, 1080)
var pixels := 1.0
## When the last physics tick and the last _process started, and what the
## ticks since the last frame added up to (microseconds).
var tick_started := 0
var process_started := 0
var ticks_spent := 0
var ticks_count := 0
var process_spent := 0

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var qualities := range(PRESETS.count())
	var seed_value := 81
	var difficulty := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--bench-label="): label = argument.trim_prefix("--bench-label=")
		if argument.begins_with("--seed="): seed_value = int(argument.trim_prefix("--seed="))
		if argument.begins_with("--difficulty="): difficulty = argument.trim_prefix("--difficulty=")
		if argument == "--passes": passes = true
		if argument.begins_with("--size="): window = Vector2i(int(argument.trim_prefix("--size=").get_slice("x", 0)), int(argument.trim_prefix("--size=").get_slice("x", 1)))
		if argument.begins_with("--pixels="): pixels = float(argument.trim_prefix("--pixels="))
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
	# Every run starts from the game's own defaults: the settings of the run
	# before are saved (--setting), and would be measured again here. And the
	# floor is put up on the first preset measured, so a run of one preset
	# says what a game started on it loads and keeps in memory (one that goes
	# through several keeps some of what the ones before it loaded).
	level.settings.values = level.settings.DEFAULTS.duplicate()
	level.settings.set_designed(int(qualities[0]))
	# --difficulty=: the floor's difficulty instead of the settings' default (desafiante).
	if not difficulty.is_empty(): level.settings.values.difficulty = difficulty
	var load_start := Time.get_ticks_msec()
	await level.start_floor(seed_value)
	var load_ms := Time.get_ticks_msec() - load_start
	# Floor 2: the walk and the third view end in the room of its first planta
	# furthest from the start by doors (farthest_on_first()), not at manifest.exit.
	var far: int = int(level.manifest.exit) if level.session.floor_number == 1 else farthest_on_first(level.manifest)
	var from: Vector3 = Vector3(0, 0.04, 0) if level.session.floor_number == 1 else FLOOR.position_of(level.manifest.rooms[int(level.manifest.start)]) + Vector3(0, 0.04, 0)
	DisplayServer.window_set_size(window)
	if pixels > 1.0:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
		root.content_scale_size = Vector2i(Vector2(window) * sqrt(pixels))
	if passes: add_marks(level)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hide="):
			for layer in argument.trim_prefix("--hide=").split(","):
				# The level shows and hides the layers themselves as it goes:
				# what is hidden is what each one draws.
				for child in level.get_node("Presentation/" + layer).get_children():
					if child is CanvasItem: child.visible = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var viewport_rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid, true)
	# A tick lasts from its signal to the next one's, or to the frame's.
	physics_frame.connect(func() -> void:
		var now := Time.get_ticks_usec()
		if tick_started > 0: ticks_spent += now - tick_started
		tick_started = now
		ticks_count += 1)
	process_frame.connect(func() -> void:
		var now := Time.get_ticks_usec()
		if tick_started > 0: ticks_spent += now - tick_started
		tick_started = 0
		process_started = now)
	RenderingServer.frame_pre_draw.connect(func() -> void: process_spent = Time.get_ticks_usec() - process_started)
	# The walk: the navigation route from the reception towards the exit.
	var route := FLOOR.navigation_path(level.get_world_3d().navigation_map, from, FLOOR.position_of(level.manifest.rooms[far]))
	var results: Array = []
	var legacy: Array = []
	var peak_memory := 0.0
	for quality in qualities:
		# Through the settings, as the menu does: the preset's render scale too.
		level.settings.set_designed(quality)
		# Presets with bounce light bake it now, on worker threads.
		await level.bounce_ready()
		# A forced scale wins over the preset's (--set=scale:0.5).
		if PRESETS.overrides.has("scale"): level.settings.set_value("scale", PRESETS.overrides.scale)
		for argument in OS.get_cmdline_user_args():
			if not argument.begins_with("--setting="): continue
			for pair in argument.trim_prefix("--setting=").split(","):
				var text := pair.get_slice(":", 1)
				var current = level.settings.values.get(pair.get_slice(":", 0))
				level.settings.set_value(pair.get_slice(":", 0), text if current is String else (text == "true") if current is bool else float(text) if current is float else int(text))
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
		# The reception, a room halfway to the first refuge, and the refuge.
		var hops: Array = preload("res://game/world/generation/map_generator.gd").distance_map(level.manifest.adjacency, int(level.manifest.start))
		var halfway := int(level.manifest.start)
		for room in level.manifest.rooms:
			if int(room.wing) == 0 and hops[int(room.id)] == hops[far] / 2:
				halfway = int(room.id)
				break
		for id in [int(level.manifest.start), halfway, far]:
			drawn["%d:%d" % [quality, id]] = true
			var room: Dictionary = level.manifest.rooms[id]
			level.player.position = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
			level.player.rotation.y = 0.65
			level.player.camera.rotation.x = -0.1
			level.hotel.update_visibility(level.player.position, true)
			await settle()
			await capture(level, "room%d_q%d" % [id, quality])
			var frames := await sample(level, viewport_rid, STILL_FRAMES, Callable())
			peak_memory = maxf(peak_memory, Performance.get_monitor(Performance.MEMORY_STATIC))
			var still: Dictionary = summary("still_room%d" % id, quality, frames)
			# Its room's type: floors built differently are compared by role, not id.
			still["type"] = int(room.type)
			results.append(still)
			all_frames.append_array(frames)
		# Arriving somewhere the run has not drawn yet, with no settling: this
		# is where a pipeline that has never been built shows up, and it is
		# what a player feels walking into a room for the first time.
		var arrivals: Array = []
		for id in fresh_rooms(level, quality, ARRIVALS):
			var room: Dictionary = level.manifest.rooms[id]
			level.player.position = FLOOR.position_of(room) + Vector3(0, 0.04, 0)
			level.player.rotation.y = 0.65
			level.player.camera.rotation.x = -0.1
			level.hotel.update_visibility(level.player.position, true)
			arrivals.append_array(await sample(level, viewport_rid, ARRIVAL_FRAMES, Callable()))
		if not arrivals.is_empty():
			results.append(summary("arrival", quality, arrivals))
			all_frames.append_array(arrivals)
		# Walking: the body moves every frame, as in play.
		level.player.position = route[0] if route.size() > 0 else from
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
	var report := {"label": label, "floor": level.session.floor_number, "seed": seed_value, "difficulty": String(level.settings.values.difficulty), "walk_points": route.size(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "viewport": str(root.size), "pixels": pixels, "rooms": level.manifest.rooms.size(), "floor_load_ms": load_ms, "node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "memory": memory, "results": results}
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

## The room of the first planta furthest from the start by doors (a planta
## of the offices: the lift is the only way to the others).
static func farthest_on_first(manifest: Dictionary) -> int:
	var hops: Array = preload("res://game/world/generation/map_generator.gd").distance_map(manifest.adjacency, int(manifest.start))
	var best := int(manifest.start)
	for room in manifest.rooms:
		if int(room.wing) == 0 and int(hops[int(room.id)]) > int(hops[best]): best = int(room.id)
	return best

## Point at a distance along a polyline (its end past the last point).
static func along(line: PackedVector3Array, distance: float) -> Vector3:
	if line.is_empty(): return Vector3.ZERO
	var travelled := 0.0
	for i in range(1, line.size()):
		var segment := line[i].distance_to(line[i - 1])
		if travelled + segment >= distance: return line[i - 1].lerp(line[i], (distance - travelled) / maxf(segment, 0.0001))
		travelled += segment
	return line[line.size() - 1]

## Pipelines Godot has built since it started (its monitors are running
## totals): a frame's own count is the difference from the frame before.
static func pipelines_built() -> Vector2:
	var draw := Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)
	var all := draw + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE) + Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION)
	return Vector2(draw, all)

func sample(level: Node, viewport_rid: RID, count: int, step: Callable) -> Array:
	var frames: Array = []
	var before := pipelines_built()
	for frame in count:
		if step.is_valid(): step.call(frame)
		var started := Time.get_ticks_usec()
		ticks_spent = 0
		ticks_count = 0
		await RenderingServer.frame_pre_draw
		var drawing := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		var drawn := Time.get_ticks_usec() - drawing
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
			# Pipelines built this frame: what a stall is usually made of.
			# "draw" are the ones built because something was about to be
			# drawn with them, the ones that make a frame wait.
			"pipelines_draw": pipelines_built().x - before.x,
			"pipelines_all": pipelines_built().y - before.y,
			"process_ms": process_spent / 1000.0,
			"draw_ms": drawn / 1000.0,
			"ticks": ticks_count,
			"ticks_ms": ticks_spent / 1000.0,
			"passes": frame_passes() if passes else {},
		})
		before = pipelines_built()
	return frames

## A mark in the GPU's timeline at one stage of the 3D render. Godot's own
## frame profile (the editor's visual profiler) cannot be read from a script,
## but a compositor effect is called at fixed stages and may leave a timestamp
## there, and those can be read back. What lies between two marks:
##   viewport  -> opaque       culling, shadow maps, depth prepass, SSAO/SSIL,
##                             volumetric fog, the light clusters
##   opaque    -> sky          the opaque pass: every surface shaded and lit
##   sky       -> transparent  background, SSR, resolves
##   transparent -> camera     glass, particles, labels
##   camera    -> post         the game's own effects (motion blur, camcorder)
##   post      -> (end)        glow, upscale, tonemap, FXAA, and the canvas
##                             (lens, tape filter, OSD)
class Mark extends CompositorEffect:
	var title := ""
	func _render_callback(_type: int, _data: RenderData) -> void:
		RenderingServer.get_rendering_device().capture_timestamp("mark:" + title)

func add_marks(level: Node) -> void:
	var compositor: Compositor = level.get_node("Presentation/WorldEnvironment").compositor
	if compositor == null: return
	var effects: Array[CompositorEffect] = []
	for stage in [["opaque", CompositorEffect.EFFECT_CALLBACK_TYPE_PRE_OPAQUE], ["sky", CompositorEffect.EFFECT_CALLBACK_TYPE_POST_OPAQUE], ["transparent", CompositorEffect.EFFECT_CALLBACK_TYPE_PRE_TRANSPARENT], ["camera", CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT]]:
		var mark := Mark.new()
		mark.title = stage[0]
		mark.effect_callback_type = stage[1]
		effects.append(mark)
	effects.append_array(compositor.compositor_effects)
	var last := Mark.new()
	last.title = "post"
	last.effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	effects.append(last)
	compositor.compositor_effects = effects

## The stages of the last frame the GPU has finished, by the mark they start
## at: [gpu ms, cpu ms]. A stage lasts until the next mark.
func frame_passes() -> Dictionary:
	var out := {}
	var device := RenderingServer.get_rendering_device()
	if device == null: return out
	var count := device.get_captured_timestamps_count()
	for i in count - 1:
		var name := device.get_captured_timestamp_name(i)
		if name.begins_with("vp_end"): continue
		name = name.trim_prefix("mark:") if name.begins_with("mark:") else "viewport"
		var spent: Array = out.get(name, [0.0, 0.0])
		out[name] = [spent[0] + (device.get_captured_timestamp_gpu_time(i + 1) - device.get_captured_timestamp_gpu_time(i)) / 1000000.0, spent[1] + (device.get_captured_timestamp_cpu_time(i + 1) - device.get_captured_timestamp_cpu_time(i)) / 1000.0]
	return out

## Rooms this quality has not drawn yet, spread over the floor: the stills
## and the walk keep their own, so an arrival really is a first one.
var drawn := {}

func fresh_rooms(level: Node, quality: int, count: int) -> Array:
	var out: Array = []
	var ids: Array = range(level.manifest.rooms.size())
	# Evenly spaced through the list, so they are not all in one wing.
	var stride := maxi(1, ids.size() / (count * 2))
	for i in range(0, ids.size(), stride):
		var id: int = ids[i]
		if drawn.has("%d:%d" % [quality, id]): continue
		if level.hotel.dark_room(level.manifest.rooms[id]): continue
		# Floor 2: only rooms of its first planta (no void cells, nor the plantas without power).
		if level.session.floor_number != 1 and (FLOOR.is_void(level.manifest.rooms[id]) or int(level.manifest.rooms[id].get("wing", 0)) != 0): continue
		drawn["%d:%d" % [quality, id]] = true
		out.append(id)
		if out.size() >= count: break
	return out

static func mean(values: Array) -> float:
	var total := 0.0
	for value in values: total += float(value)
	return total / maxf(1.0, values.size())

static func percentile(sorted: Array, share: float) -> float:
	return float(sorted[mini(sorted.size() - 1, int(sorted.size() * share))])

func summary(view: String, quality: int, frames: Array) -> Dictionary:
	var entry := {"view": view, "quality": quality, "samples": frames.size()}
	if passes:
		var totals := {}
		for frame in frames:
			for name in frame.passes:
				var spent: Array = totals.get(name, [0.0, 0.0])
				totals[name] = [spent[0] + frame.passes[name][0], spent[1] + frame.passes[name][1]]
		var names: Array = totals.keys()
		names.sort_custom(func(a, b): return totals[a][0] > totals[b][0])
		entry["passes"] = names.map(func(name): return {"pass": name, "gpu_ms": snappedf(totals[name][0] / frames.size(), 0.001), "cpu_ms": snappedf(totals[name][1] / frames.size(), 0.001)})
	for key in ["frame_ms", "gpu_ms", "render_cpu_ms"]:
		var values: Array = frames.map(func(f): return f[key])
		values.sort()
		entry[key] = {"mean": snappedf(mean(values), 0.001), "p95": snappedf(percentile(values, 0.95), 0.001), "p99": snappedf(percentile(values, 0.99), 0.001), "max": snappedf(values[-1], 0.001)}
	# The main thread: a tick, a frame's scripts, a frame's drawing.
	var tick_times: Array = []
	for frame in frames:
		if int(frame.ticks) > 0: tick_times.append(float(frame.ticks_ms) / float(frame.ticks))
	tick_times.sort()
	var cpu := {"ticks": tick_times.size()}
	if not tick_times.is_empty(): cpu["tick_ms"] = {"mean": snappedf(mean(tick_times), 0.001), "p95": snappedf(percentile(tick_times, 0.95), 0.001), "max": snappedf(tick_times[-1], 0.001)}
	for key in ["process_ms", "draw_ms"]:
		var values: Array = frames.map(func(f): return f[key])
		values.sort()
		cpu[key] = {"mean": snappedf(mean(values), 0.001), "p95": snappedf(percentile(values, 0.95), 0.001), "max": snappedf(values[-1], 0.001)}
	cpu["at_60"] = {"mean": snappedf(float(cpu.get("tick_ms", {}).get("mean", 0.0)) + cpu.process_ms.mean + cpu.draw_ms.mean, 0.001), "p95": snappedf(float(cpu.get("tick_ms", {}).get("p95", 0.0)) + cpu.process_ms.p95 + cpu.draw_ms.p95, 0.001)}
	entry["cpu"] = cpu
	# Hitches: frames that took far longer than this view's own normal frame,
	# which is what a stall looks like from the player's seat.
	var times: Array = frames.map(func(f): return f.frame_ms)
	times.sort()
	var middle: float = percentile(times, 0.5)
	var hitches := {"over_twice_median": 0, "over_20ms": 0, "over_33ms": 0, "worst": []}
	for value in times:
		if value > middle * 2.0: hitches.over_twice_median += 1
		if value > 20.0: hitches.over_20ms += 1
		if value > 33.0: hitches.over_33ms += 1
	for i in range(times.size() - 1, maxi(times.size() - 4, -1), -1): hitches.worst.append(snappedf(times[i], 0.001))
	entry["hitches"] = hitches
	for key in ["pipelines_draw", "pipelines_all"]:
		var built: Array = frames.map(func(f): return f[key])
		var total := 0.0
		for value in built: total += float(value)
		entry[key] = {"sum": int(total), "max": int(built.max())}
	for key in ["draws", "objects", "primitives", "shadow_draws", "shadow_primitives"]:
		var values: Array = frames.map(func(f): return f[key])
		values.sort()
		entry[key] = {"mean": int(mean(values)), "max": int(values[-1])}
	return entry

## The same view without the camera's lens, sensor and tape (stable, for pixel
## comparison) and with them (as played).
func capture(level: Node, name: String) -> void:
	if pixels > 1.0: return
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
