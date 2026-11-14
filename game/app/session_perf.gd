extends RefCounted
## Opt-in trace of a real game. Producers only queue data. The writer keeps
## flushing even when the main thread is stuck in the middle of a frame.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SLOW_US := 50_000
const DETAIL_US := 2_000
const SAMPLE_US := 250_000
const HEARTBEAT_US := 500_000
const MAX_PENDING := 8192

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
	event(&"session_start", {
		"format": 1, "unix_time": Time.get_unix_time_from_system(),
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


## Frequent main-thread work is counted per frame. Slow calls also get their
## own timestamp, so nested costs can be matched without adding them together.
func timed(name: StringName, started: int) -> void:
	var at := Time.get_ticks_usec()
	var elapsed := at - started
	var total = timings.get(name)
	if total == null: timings[name] = [1, elapsed, elapsed]
	else:
		total[0] += 1
		total[1] += elapsed
		total[2] = maxi(total[2], elapsed)
	if elapsed >= DETAIL_US:
		enqueue({
			"event": &"span", "name": name, "at_us": at, "start_us": started,
			"us": elapsed, "tid": OS.get_main_thread_id(),
		})


## process_frame is an idle-loop boundary. Physics ticks and other activity
## since the previous boundary share the same wall clock as the task records.
func frame(level) -> void:
	var at := Time.get_ticks_usec()
	var physics := Engine.get_physics_frames()
	var elapsed := at - last_frame_us
	var slow := last_frame_us > 0 and elapsed >= SLOW_US
	var state: String = level.session.State.keys()[level.session.state]
	var row := {
		"event": &"frame", "at_us": at, "start_us": last_frame_us,
		"frame": Engine.get_process_frames(), "us": elapsed if last_frame_us > 0 else 0,
		"slow": slow, "physics_ticks": physics - last_physics,
		"state": state, "floor": level.session.floor_number,
		"stage": level.session.stage, "focused": level.get_window().has_focus(),
		"timings": timings,
	}
	var phase_changed := last_state != state
	if not last_state.is_empty() and phase_changed: row["previous_state"] = last_state
	last_state = state
	timings = {}
	last_physics = physics
	if slow or phase_changed or at - last_sample_us >= SAMPLE_US:
		last_sample_us = at
		row["sample"] = sample(level)
	enqueue(row, at)


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
	if not level.manifest.is_empty() and level.session.state == level.session.State.PLAYING:
		var room := FLOOR.room_at(level.manifest.rooms, point)
		data["room"] = room.get("id", -1)
		if is_instance_valid(level.creature) and level.creature.has_method("beat_now"):
			data["creature_beat"] = level.creature.beat_now()
	if is_instance_valid(level.hotel):
		data["probes"] = level.hotel.probes_made
		data["bounce_active"] = level.hotel.bounce.baking()
	return data


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
