extends Node
signal changed
## CUTSCENE: the opening scene of a new game, before its floor is built.
enum State { MENU, LOADING, PLAYING, PAUSED, TRANSITION, WON, FAILED, CUTSCENE }
enum Life { EXPLORING, REFUGE, DEAD }
const GENERATOR_VERSION := preload("res://game/world/generation/floor_definition.gd").VERSION
var state := State.MENU
## A floor is three chained stages. Each one is closed by its own condition and
## opens the way to the next; only the last one ends the floor. The condition
## of stage 1 is the refuge as it always was; the other two get theirs as they
## are built, and until then they use the same one, so a floor can always be
## finished.
const STAGES := 3
var stage := 1
## What the stage in hand needs, how far along it is and whether it is already
## met, for the interface and for the other machines. `ready` is what unlocks
## the door on: from then on anyone can open it, and crossing it is what
## carries the floor to the next stage.
var goal := {"kind": "refuge", "done": 0, "needed": 1, "ready": false}
var participants := {1: Life.EXPLORING}
var roster_count := 1
var run_seed := 0
var map_fallback := false
## Seconds the last stage has been met for: the floor ends after a moment,
## until the door with the code lock is built and crossing it does that.
var leaving := 0.0
var elapsed := 0.0
var transition_time := 0.0
var message := ""
var checkpoint_path := "user://hotel_checkpoint.json"
## An online floor: the single-player checkpoint is left alone.
var online := false

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS

func set_state(next: State) -> void:
	state = next
	changed.emit()

## slots: participant keys of the survivors on this floor (1 alone offline).
func start(seed_value: int, used_fallback := false, slots: Array = [1]) -> void:
	run_seed = seed_value
	map_fallback = used_fallback
	participants = {}
	for slot in slots: participants[int(slot)] = Life.EXPLORING
	roster_count = slots.size()
	leaving = 0
	elapsed = 0
	transition_time = 0
	message = ""
	stage = 1
	goal = {"kind": "refuge", "done": 0, "needed": 1, "ready": false}
	if not online: write_checkpoint()
	set_state(State.PLAYING)

func minimum_survivors() -> int: return maxi(1, int(ceil(roster_count / 2.0)))

func set_refuge(id: int, inside: bool) -> void:
	if not participants.has(id) or participants[id] == Life.DEAD: return
	var next: int = Life.REFUGE if inside else Life.EXPLORING
	if participants[id] != next:
		participants[id] = next
		changed.emit()

func can_depart() -> bool:
	var alive := 0
	for life in participants.values():
		if life == Life.EXPLORING: return false
		if life == Life.REFUGE: alive += 1
	return alive >= minimum_survivors()

## The refuge closes a stage only while that is the stage's condition.
func refuge_stage() -> bool: return true

## The authority, every frame: whether the stage in hand is met. While it is,
## the door on is unlocked; crossing it is what closes the stage (hotel_main).
## On the last stage there is no wing beyond yet, so being met for a few
## seconds is what ends the floor, until its door has its code lock.
func update_goal(delta: float, met: bool) -> void:
	if state != State.PLAYING: return
	# A change here opens or shuts the door on, so everyone is told at once.
	if bool(goal.get("ready", false)) != met:
		goal["ready"] = met
		changed.emit()
	if more_stages() or not met:
		leaving = 0.0
		return
	leaving += delta
	if leaving >= LEAVING_TIME: finish_stage()

const LEAVING_TIME := 3.0

## The condition of the stage in hand is met (the authority decides). The beat
## of State.TRANSITION carries either into the next stage or out of the floor.
func finish_stage() -> void:
	if state != State.PLAYING: return
	transition_time = 0
	set_state(State.TRANSITION)

## True while the floor goes on: the last stage is the one that ends it.
func more_stages() -> bool: return stage < STAGES

func capture(id: int) -> bool:
	if state != State.PLAYING or not participants.has(id) or participants[id] != Life.EXPLORING: return false
	participants[id] = Life.DEAD
	return check_quota()

## A player who dropped out of an online floor and never came back: lost for
## this floor, and the minimum does not drop with them.
func drop(id: int) -> void:
	if state != State.PLAYING or not participants.has(id) or participants[id] == Life.DEAD: return
	participants[id] = Life.DEAD
	leaving = 0.0
	check_quota()

func check_quota() -> bool:
	var alive := 0
	for life in participants.values():
		if life != Life.DEAD: alive += 1
	if alive < minimum_survivors():
		message = "No quedan suficientes supervivientes."
		set_state(State.FAILED)
	else: changed.emit()
	return true

func pause() -> void:
	if state == State.PLAYING:
		leaving = 0.0
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
			if more_stages():
				stage += 1
				leaving = 0.0
				goal = {"kind": "refuge", "done": 0, "needed": 1, "ready": false}
				set_state(State.PLAYING)
				return
			if FileAccess.file_exists(checkpoint_path) and not online: DirAccess.remove_absolute(checkpoint_path)
			set_state(State.WON)
