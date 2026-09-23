extends Logger
## Every error the engine or a script reports during a bot match, caught as it
## happens so it goes into the run's record with the simulated second it came
## at -- a line in a log file says that something broke, not when in the floor
## nor what the bots were doing. Called from any thread, hence the lock; the
## match takes what has gathered once a frame (drain()).
var mutex := Mutex.new()
var queue: Array = []

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	# Where in the scripts it came from, when a script is behind it: the
	# engine's own place (variant_utility.cpp for a push_error) says little.
	for trace in script_backtraces:
		if trace.get_frame_count() > 0:
			file = trace.get_frame_file(0)
			line = trace.get_frame_line(0)
			function = trace.get_frame_function(0)
			break
	mutex.lock()
	queue.append({"function": function, "file": file, "line": line, "code": code, "rationale": rationale, "type": ["error", "warning", "script", "shader"][clampi(error_type, 0, 3)]})
	mutex.unlock()

func _log_message(_message: String, _error: bool) -> void: pass

func drain() -> Array:
	mutex.lock()
	var out := queue
	queue = []
	mutex.unlock()
	return out
