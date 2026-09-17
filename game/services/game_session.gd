extends Node
signal changed
## CUTSCENE: the opening scene of a new game, before its floor is built.
enum State { MENU, LOADING, PLAYING, PAUSED, TRANSITION, WON, FAILED, CUTSCENE }
enum Life { EXPLORING, REFUGE, DEAD }
const GENERATOR_VERSION := preload("res://game/world/generation/floor_definition.gd").VERSION
var state := State.MENU
var participants := {1: Life.EXPLORING}
var roster_count := 1
var run_seed := 0
var map_fallback := false
var exit_progress := 0.0
var elapsed := 0.0
var transition_time := 0.0
var message := ""
var checkpoint_path := "user://hotel_checkpoint.json"

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS

func set_state(next: State) -> void:
	state = next
	changed.emit()

func start(seed_value: int, used_fallback := false) -> void:
	run_seed = seed_value
	map_fallback = used_fallback
	participants = {1: Life.EXPLORING}
	roster_count = 1
	exit_progress = 0
	elapsed = 0
	transition_time = 0
	message = ""
	write_checkpoint()
	set_state(State.PLAYING)

func minimum_survivors() -> int: return maxi(1, int(ceil(roster_count / 2.0)))

func set_refuge(id: int, inside: bool) -> void:
	if not participants.has(id) or participants[id] == Life.DEAD: return
	var next: int = Life.REFUGE if inside else Life.EXPLORING
	if participants[id] != next:
		participants[id] = next
		exit_progress = 0
		changed.emit()

func can_depart() -> bool:
	var alive := 0
	for life in participants.values():
		if life == Life.EXPLORING: return false
		if life == Life.REFUGE: alive += 1
	return alive >= minimum_survivors()

func hold_exit(delta: float, held: bool) -> void:
	if state != State.PLAYING: return
	if not held or not can_depart():
		exit_progress = 0
		return
	exit_progress += delta
	if exit_progress >= 3:
		transition_time = 0
		set_state(State.TRANSITION)

func capture(id: int) -> bool:
	if state != State.PLAYING or not participants.has(id) or participants[id] != Life.EXPLORING: return false
	participants[id] = Life.DEAD
	var alive := 0
	for life in participants.values():
		if life != Life.DEAD: alive += 1
	if alive < minimum_survivors():
		message = "No quedan suficientes supervivientes."
		set_state(State.FAILED)
	return true

func pause() -> void:
	if state == State.PLAYING:
		exit_progress = 0
		set_state(State.PAUSED)

func checkpoint() -> Dictionary:
	message = ""
	if not FileAccess.file_exists(checkpoint_path): return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path))
	if not data is Dictionary or not data.has_all(["format", "generator", "seed", "floor"]):
		message = "El checkpoint no se puede leer. Puedes iniciar una partida nueva."
		return {}
	if data.format != 1 or data.generator != GENERATOR_VERSION or data.floor != 1:
		message = "Checkpoint incompatible con esta versión. Se conserva el archivo original."
		return {}
	if not (data.seed is float or data.seed is int) or not is_finite(float(data.seed)) or data.seed < 0 or data.seed > 2147483647:
		message = "El checkpoint contiene una semilla inválida."
		return {}
	return data

func write_checkpoint() -> bool:
	var temp := checkpoint_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if not file:
		message = "No se pudo guardar el inicio del piso."
		return false
	file.store_string(JSON.stringify({"format": 1, "generator": GENERATOR_VERSION, "seed": run_seed, "floor": 1, "fallback": map_fallback}))
	file.close()
	# Preserve the previous valid checkpoint until the complete replacement exists.
	var backup := checkpoint_path + ".bak"
	if FileAccess.file_exists(backup): DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(checkpoint_path): DirAccess.rename_absolute(checkpoint_path, backup)
	var error := DirAccess.rename_absolute(temp, checkpoint_path)
	if error != OK:
		if FileAccess.file_exists(backup): DirAccess.rename_absolute(backup, checkpoint_path)
		message = "No se pudo guardar el inicio del piso."
		return false
	return true

func _process(delta: float) -> void:
	if state == State.PLAYING: elapsed += delta
	if state == State.TRANSITION:
		transition_time += delta
		if transition_time >= 1.2:
			if FileAccess.file_exists(checkpoint_path): DirAccess.remove_absolute(checkpoint_path)
			set_state(State.WON)
