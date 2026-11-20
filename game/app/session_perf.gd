extends RefCounted
## Opt-in trace of a real game. Producers only queue data. The writer keeps
## flushing even when the main thread is stuck in the middle of a frame.
## tools/benchmarks/perf_report.py reads what it writes (docs/PERFORMANCE.md 14).
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const PRESETS := preload("res://game/presentation/graphics_presets.gd")
const SLOW_US := 50_000
const DETAIL_US := 2_000
const SAMPLE_US := 250_000
const HEARTBEAT_US := 500_000
const MAX_PENDING := 8192
## The main loop's parts, in its order: physics ticks, _process, drawing, and
## the rest (the OS's events, input, the wait of the FPS cap).
enum Phase { PHYSICS, PROCESS, DRAW, OTHER }
const COMPILES := [Performance.PIPELINE_COMPILATIONS_CANVAS, Performance.PIPELINE_COMPILATIONS_MESH, Performance.PIPELINE_COMPILATIONS_SURFACE, Performance.PIPELINE_COMPILATIONS_DRAW, Performance.PIPELINE_COMPILATIONS_SPECIALIZATION]

var writer := Thread.new()
var lock := Mutex.new()
var pending: Array[Dictionary] = []
var dropped := 0
var stopping := false
var last_frame_us := 0
var last_sample_us := 0
var last_physics := 0
var last_state := ""
var timings := {}
var viewport: RID
var measures_render := false
var tree: SceneTree
var phase := Phase.OTHER
var physics_started := 0
var process_started := 0
var draw_started := 0
var process_us := 0
var draw_us := 0
## Own time of the named work in this frame, by phase: what the phase spent
## less this is what nothing names.
var named_us := PackedInt64Array([0, 0, 0, 0])
## Start and length of the spans closed this frame and not yet inside another.
var closed := PackedInt64Array()
var compiled := 0.0
## Every lamp of the floor in hand, gathered once per floor (lights_of).
var lights: Array[Node] = []
var lights_of = null


## Where --perf-log= writes: the .jsonl it names, or one named by the time in
## the folder it names (user://perf when it names nothing).
static func path_for(asked: String) -> String:
	var path := asked.replace("\\", "/")
	if path.get_extension() == "jsonl": return path
	if path.is_empty(): path = "user://perf"
	DirAccess.make_dir_recursive_absolute(path)
	return path.path_join(Time.get_datetime_string_from_system().replace(":", "-") + ".jsonl")


func start(path: String, window: Window) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Performance trace could not open %s (error %s)" % [path, FileAccess.get_open_error()])
		return false
	var hitches_path := path.get_basename() + ".hitches.jsonl"
	var hitches := FileAccess.open(hitches_path, FileAccess.WRITE)
	if hitches == null:
		push_error("Performance trace could not open %s (error %s)" % [hitches_path, FileAccess.get_open_error()])
		return false
	viewport = window.get_viewport_rid()
	measures_render = DisplayServer.get_name() != "headless"
	if writer.start(write_trace.bind(file, hitches)) != OK:
		push_error("Performance trace writer could not start")
		return false
	if measures_render: RenderingServer.viewport_set_measure_render_time(viewport, true)
	last_physics = Engine.get_physics_frames()
	compiled = compilations()
	tree = window.get_tree()
	tree.physics_frame.connect(on_physics_tick)
	RenderingServer.frame_pre_draw.connect(on_pre_draw)
	RenderingServer.frame_post_draw.connect(on_post_draw)
	print("Performance trace: ", ProjectSettings.globalize_path(path))
	var screen := DisplayServer.screen_get_size() if DisplayServer.get_name() != "headless" else Vector2i.ZERO
	event(&"session_start", {
		"format": 2, "unix_time": Time.get_unix_time_from_system(),
		"version": ProjectSettings.get_setting("application/config/version"),
		"os": OS.get_name(), "cpu": OS.get_processor_name(), "cores": OS.get_processor_count(),
		"screen": [screen.x, screen.y],
		"pid": OS.get_process_id(), "main_thread": OS.get_main_thread_id(),
		"godot": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"gpu": RenderingServer.get_video_adapter_name(), "slow_us": SLOW_US,
	})
	return true


func stop() -> void:
	event(&"session_end")
	lock.lock()
	stopping = true
	lock.unlock()
	writer.wait_to_finish()
	if measures_render: RenderingServer.viewport_set_measure_render_time(viewport, false)
	tree.physics_frame.disconnect(on_physics_tick)
	RenderingServer.frame_pre_draw.disconnect(on_pre_draw)
	RenderingServer.frame_post_draw.disconnect(on_post_draw)


func event(name: StringName, detail := {}) -> void:
	enqueue({"event": name, "at_us": Time.get_ticks_usec(), "tid": OS.get_thread_caller_id(), "detail": detail})


## Beginnings are written separately so a task blocked indefinitely is visible.
func begin(name: StringName, detail := {}) -> int:
	var at := Time.get_ticks_usec()
	enqueue({"event": &"begin", "name": name, "at_us": at, "tid": OS.get_thread_caller_id(), "detail": detail})
	return at


func end(name: StringName, started: int, detail := {}) -> void:
	var at := Time.get_ticks_usec()
	enqueue({
		"event": &"end", "name": name, "at_us": at, "start_us": started,
		"us": at - started, "tid": OS.get_thread_caller_id(), "detail": detail,
	})
	# Main-thread work begun and ended in this frame is part of it, like timed().
	if OS.get_thread_caller_id() == OS.get_main_thread_id() and started >= last_frame_us: count(name, started, at)


## Frequent main-thread work is counted per frame. Slow calls also get their
## own timestamp, so nested costs can be matched without adding them together.
func timed(name: StringName, started: int) -> void:
	var at := Time.get_ticks_usec()
	count(name, started, at)
	if at - started >= DETAIL_US:
		enqueue({
			"event": &"span", "name": name, "at_us": at, "start_us": started,
			"us": at - started, "tid": OS.get_main_thread_id(),
		})


## Per name and frame: calls, time, longest call, own time (less the named
## work that ran inside it) and the phase it ran in.
func count(name: StringName, started: int, at: int) -> void:
	var elapsed := at - started
	var own := elapsed - nested(started, elapsed)
	named_us[phase] += own
	var total = timings.get(name)
	if total == null: timings[name] = [1, elapsed, elapsed, own, phase]
	else:
		total[0] += 1
		total[1] += elapsed
		total[2] = maxi(total[2], elapsed)
		total[3] += own


## A span closes after the ones inside it, so those still listed that started
## at or after it are its children: they leave the list, it takes their place,
## and what they took is returned.
func nested(started: int, elapsed: int) -> int:
	var inner := 0
	while not closed.is_empty() and closed[closed.size() - 2] >= started:
		inner += closed[closed.size() - 1]
		closed.resize(closed.size() - 2)
	closed.append(started)
	closed.append(elapsed)
	return inner


func on_physics_tick() -> void:
	if phase == Phase.PHYSICS: return
	phase = Phase.PHYSICS
	physics_started = Time.get_ticks_usec()


func on_pre_draw() -> void:
	draw_started = Time.get_ticks_usec()
	process_us = draw_started - process_started
	phase = Phase.DRAW


func on_post_draw() -> void:
	draw_us = Time.get_ticks_usec() - draw_started
	phase = Phase.OTHER


func compilations() -> float:
	var total := 0.0
	for monitor in COMPILES: total += Performance.get_monitor(monitor)
	return total


## process_frame is an idle-loop boundary. Physics ticks and other activity
## since the previous boundary share the same wall clock as the task records.
## The interval holds the previous frame's _process and drawing, the rest, and
## this frame's physics ticks: phys_us + proc_us + draw_us and what is left.
func frame(level) -> void:
	var at := Time.get_ticks_usec()
	var physics := Engine.get_physics_frames()
	var elapsed := at - last_frame_us
	var slow := last_frame_us > 0 and elapsed >= SLOW_US
	var state: String = level.session.State.keys()[level.session.state]
	var compiled_now := compilations()
	var row := {
		"event": &"frame", "at_us": at, "start_us": last_frame_us,
		"frame": Engine.get_process_frames(), "us": elapsed if last_frame_us > 0 else 0,
		"slow": slow, "physics_ticks": physics - last_physics,
		"state": state, "floor": level.session.floor_number,
		"stage": level.session.stage, "focused": level.get_window().has_focus(),
		"phys_us": at - physics_started if phase == Phase.PHYSICS else 0,
		"proc_us": process_us, "draw_us": draw_us, "named_us": named_us,
		"timings": timings,
	}
	if measures_render: row["gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(viewport)
	if compiled_now > compiled: row["compiles"] = int(compiled_now - compiled)
	compiled = compiled_now
	phase = Phase.PROCESS
	process_started = at
	process_us = 0
	draw_us = 0
	named_us = PackedInt64Array([0, 0, 0, 0])
	closed.clear()
	var phase_changed := last_state != state
	if not last_state.is_empty() and phase_changed: row["previous_state"] = last_state
	last_state = state
	timings = {}
	last_physics = physics
	if slow or phase_changed or at - last_sample_us >= SAMPLE_US:
		last_sample_us = at
		row["sample"] = sample(level)
	enqueue(row, at)
	# What the trace itself costs, counted in the next frame.
	timed(&"trace", at)


func sample(level) -> Dictionary:
	var point: Vector3 = level.player.global_position
	var data := {
		"position": [point.x, point.y, point.z], "planta": FLOOR.planta_of(point.y) + 1,
		"seed": level.manifest.get("seed"), "requested_seed": level.manifest.get("requested_seed"),
		"quality": level.settings.values.quality, "difficulty": level.settings.values.difficulty,
		"online": level.session.online, "authority": level.session.authority,
		"fps_cap": Engine.max_fps, "vsync": level.settings.values.vsync,
		"fps_monitor": Performance.get_monitor(Performance.TIME_FPS),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"navigation_ms": Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0,
		"physics_pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS),
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"window_mode": level.get_window().mode,
	}
	if measures_render:
		data["render_cpu_ms"] = RenderingServer.viewport_get_measured_render_time_cpu(viewport)
		data["render_setup_ms"] = RenderingServer.get_frame_setup_time_cpu()
		data["gpu_ms"] = RenderingServer.viewport_get_measured_render_time_gpu(viewport)
		data["draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		data["primitives"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		data["vram_bytes"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
		data["pipelines"] = [
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW),
			Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION),
		]
		var rect: Rect2 = level.get_viewport().get_visible_rect()
		data["viewport"] = [rect.size.x, rect.size.y, level.get_viewport().scaling_3d_scale]
		data["objects"] = RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME)
		data["shadow_draw_calls"] = RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
		data["shadow_primitives"] = RenderingServer.viewport_get_render_info(viewport, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
	data["preset"] = PRESETS.NAMES[level.settings.values.quality] if level.settings.values.quality >= 0 and level.settings.values.quality < PRESETS.NAMES.size() else str(level.settings.values.quality)
	if not level.manifest.is_empty() and level.session.state == level.session.State.PLAYING:
		var room := FLOOR.room_at(level.manifest.rooms, point)
		data["room"] = room.get("id", -1)
		if not room.is_empty(): data["room_name"] = FLOOR.palette(level.manifest).label(room)
		if is_instance_valid(level.creature) and level.creature.has_method("beat_now"):
			data["creature_beat"] = level.creature.beat_now()
		data["lights"] = lamps_on(level)
	if is_instance_valid(level.hotel):
		data["probes"] = level.hotel.probes_made
		data["bounce_active"] = level.hotel.bounce.baking()
		data["blackout"] = level.hotel.dark
	return data


## Lamps shown and, of those, the ones casting shadows. The list is taken once
## per floor (a walk of the whole tree, some milliseconds, counted as "trace").
## shortcut: a lamp made after the first sample of a floor is not counted;
## gather again on a signal of the geometry if one ever is.
func lamps_on(level) -> Array:
	if not is_same(lights_of, level.manifest):
		lights_of = level.manifest
		lights = level.find_children("*", "Light3D", true, false)
	var on := 0
	var shadowed := 0
	for light in lights:
		if not is_instance_valid(light) or not (light as Light3D).is_visible_in_tree(): continue
		on += 1
		if (light as Light3D).shadow_enabled: shadowed += 1
	return [on, shadowed]


func enqueue(row: Dictionary, frame_at := 0) -> void:
	lock.lock()
	if frame_at > 0: last_frame_us = frame_at
	if pending.size() < MAX_PENDING: pending.append(row)
	else: dropped += 1
	lock.unlock()


func write_trace(file: FileAccess, hitches: FileAccess) -> void:
	var last_heartbeat := 0
	while true:
		lock.lock()
		var batch := pending
		pending = []
		var lost := dropped
		dropped = 0
		var done := stopping
		var last_frame := last_frame_us
		lock.unlock()
		var now := Time.get_ticks_usec()
		if lost > 0: batch.append({"event": &"dropped", "at_us": now, "count": lost})
		if not done and last_frame > 0 and now - last_frame >= HEARTBEAT_US and now - last_heartbeat >= HEARTBEAT_US:
			batch.append({"event": &"main_stall", "at_us": now, "last_frame_us": last_frame, "us": now - last_frame})
			last_heartbeat = now
		if not batch.is_empty():
			var lines := PackedStringArray()
			var slow_lines := PackedStringArray()
			for row in batch:
				var line := JSON.stringify(row, "", false)
				lines.append(line)
				if row.get("slow", false) or row.event in [&"main_stall", &"player_mark", &"dropped"]:
					slow_lines.append(line)
			if not file.store_string("\n".join(lines) + "\n"):
				push_error("Performance trace could not write to disk")
				break
			file.flush()
			if not slow_lines.is_empty():
				if not hitches.store_string("\n".join(slow_lines) + "\n"):
					push_error("Performance trace could not write the hitch index")
				hitches.flush()
		if done: break
		OS.delay_msec(100)
	file.close()
	hitches.close()
