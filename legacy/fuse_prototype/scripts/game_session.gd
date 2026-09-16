extends Node

signal state_changed(state: int)
signal objectives_changed
signal run_reset

enum State { MENU, PLAYING, PAUSED, DYING, DEAD, EXITING, WON }
const FUSE_IDS := ["fuse_a", "fuse_b", "fuse_c"]
const EXIT_HOLD_SECONDS := 3.0
var state := State.MENU
var carried: Array[String] = []
var installed: Array[String] = []
var death_cause := ""
var exit_progress := 0.0
var transition_time := 0.0
var elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func start_run() -> void:
	carried.clear()
	installed.clear()
	death_cause = ""
	exit_progress = 0.0
	transition_time = 0.0
	elapsed = 0.0
	run_reset.emit()
	_set_state(State.PLAYING)
	objectives_changed.emit()

func collect_fuse(item_id: String) -> bool:
	if state != State.PLAYING or item_id not in FUSE_IDS or item_id in carried or item_id in installed:
		return false
	carried.append(item_id)
	objectives_changed.emit()
	return true

func install_fuse() -> bool:
	if state != State.PLAYING or carried.is_empty() or installed.size() >= FUSE_IDS.size():
		return false
	installed.append(carried.pop_front())
	objectives_changed.emit()
	return true

func advance_exit(delta: float, eligible: bool) -> void:
	if state != State.PLAYING:
		return
	if not eligible or installed.size() != FUSE_IDS.size():
		exit_progress = 0.0
		return
	exit_progress = minf(exit_progress + delta, EXIT_HOLD_SECONDS)
	if exit_progress >= EXIT_HOLD_SECONDS:
		transition_time = 0.0
		_set_state(State.EXITING)

func capture(cause: String) -> bool:
	if state != State.PLAYING:
		return false
	death_cause = cause
	exit_progress = 0.0
	transition_time = 0.0
	_set_state(State.DYING)
	return true

func pause_run() -> void:
	if state == State.PLAYING:
		exit_progress = 0.0
		_set_state(State.PAUSED)

func resume_run() -> void:
	if state == State.PAUSED:
		_set_state(State.PLAYING)

func return_to_menu() -> void:
	exit_progress = 0.0
	_set_state(State.MENU)

func _set_state(value: int) -> void:
	state = value
	state_changed.emit(state)

func _process(delta: float) -> void:
	if state == State.PLAYING:
		elapsed += delta
	elif state == State.DYING or state == State.EXITING:
		transition_time += delta
		if transition_time >= 1.2:
			_set_state(State.DEAD if state == State.DYING else State.WON)
