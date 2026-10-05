extends Node
signal changed
## Everybody is back on their feet: between stages, or because the floor gave
## the survivors one more go at the stage they lost.
signal revived(restart: bool)
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
## A floor forgives one collapse: the stage starts again with everyone alive.
## The second time there is nobody left to start it again for. Alone, the
## game as it was forgave nothing -- one person caught was the end of that
## floor -- and the easier difficulties give the stage back alone too
## (solo_restarts, game/floors/difficulty.gd).
const RESTARTS := 1
## How many this floor forgives (a rule of the room, game/floors/match_rules.gd);
## negative, as many as it takes.
var restarts_allowed := RESTARTS
var solo_restarts := 0
## The difficulty the floor is played on (game/floors/difficulty.gd), kept with
## the checkpoint so "Continuar" plays it again.
var difficulty := "desafiante"
var restarts := 0
## Seconds between the floor collapsing and everybody getting up again: long
## enough for the last death to be seen and heard.
const RESTART_WAIT := 4.0
var restart_wait := 0.0
## What the stage in hand needs, how far along it is and whether it is already
## met, for the interface and for the other machines. `ready` is what unlocks
## the door on: from then on anyone can open it, and crossing it is what
## carries the floor to the next stage.
var goal := {"kind": "refuge", "done": 0, "needed": 1, "ready": false}
var participants := {1: Life.EXPLORING}
## Seats lost for this floor (dropped out and never back within the grace).
## Nobody raises them: a new stage revived them as bodies nobody drove, alive
## for the quota and with no grace left to lose them again.
var dropped := {}
var roster_count := 1
var run_seed := 0
var map_fallback := false
var elapsed := 0.0
var transition_time := 0.0
var message := ""
var checkpoint_path := "user://hotel_checkpoint.json"
## An online floor: the single-player checkpoint is left alone.
var online := false
## Off for the observer (hotel_main.begin_observing): the floors it builds to
## look at leave the checkpoint alone as well.
var keeps_checkpoint := true
## Whether this machine moves the floor on by itself: offline and on the host.
## A guest's session is a copy of the host's and only changes when told; left
## to its own clock it advanced the stage a second time from a transition timer
## nobody reset, and the host pulled it back, over and over, lights and all.
var authority := true

func _ready() -> void: process_mode = Node.PROCESS_MODE_ALWAYS

func set_state(next: State) -> void:
	state = next
	changed.emit()

## slots: participant keys of the survivors on this floor (1 alone offline).
func start(seed_value: int, used_fallback := false, slots: Array = [1]) -> void:
	run_seed = seed_value
	map_fallback = used_fallback
	participants = {}
	dropped = {}
	for slot in slots: participants[int(slot)] = Life.EXPLORING
	roster_count = slots.size()
	elapsed = 0
	transition_time = 0
	message = ""
	stage = 1
	restarts = 0
	restart_wait = 0.0
	goal = {"kind": "refuge", "done": 0, "needed": 1, "ready": false}
	if not online and keeps_checkpoint:
		# A floor begun has nothing kept of it yet: what was kept of the one
		# before is not this one's (hotel_main.continue_floor reads it first).
		forget_state()
		write_checkpoint()
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

## The condition of the stage in hand is met (the authority decides). The beat
## of State.TRANSITION carries either into the next stage or out of the floor.
func finish_stage() -> void:
	if state != State.PLAYING: return
	transition_time = 0
	# A restart counting down when the stage is closed anyway (the last one
	# standing rode the car) would have gone off in the next stage.
	restart_wait = 0.0
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
	dropped[id] = true
	check_quota()

## Back after all, too late for this stage: from the next one on, they count.
func returned(id: int) -> void:
	dropped.erase(id)

func check_quota() -> bool:
	var alive := 0
	for life in participants.values():
		if life != Life.DEAD: alive += 1
	if alive >= minimum_survivors():
		changed.emit()
		return true
	# The restart is already on its way: a death during its countdown belongs
	# to the same collapse. Counted as a second one, it ended the floor with
	# everybody about to get up again.
	if restart_wait > 0.0 and state == State.PLAYING:
		changed.emit()
		return true
	# Up again, the ones lost for the floor stay lost: if even then there are
	# too few, a restart would only leave them stuck in a stage they cannot
	# close (the refuge asks for the quota).
	var could_rise := 0
	for id in participants:
		if not dropped.has(id): could_rise += 1
	var allowed: int = restarts_allowed if roster_count > 1 else solo_restarts
	if (restarts < allowed or allowed < 0) and state == State.PLAYING and could_rise >= minimum_survivors():
		# One more go at this stage, with everybody on their feet again -- but
		# not this instant: the last one down has earned its own death first.
		restarts += 1
		restart_wait = RESTART_WAIT
		changed.emit()
		return true
	message = "No quedan suficientes supervivientes."
	# A floor that is lost is not played again: Continuar has nothing left to
	# go back to, and Reintentar makes another one.
	forget_checkpoint()
	set_state(State.FAILED)
	return true

## Everyone back among the living (the authority decides when).
func raise_everyone(announce := true) -> void:
	for id in participants:
		if not dropped.has(id): participants[id] = Life.EXPLORING
	if announce: changed.emit()

## The floor's checkpoint gone: it was won, or lost.
func forget_checkpoint() -> void:
	if FileAccess.file_exists(checkpoint_path) and not online and keeps_checkpoint: DirAccess.remove_absolute(checkpoint_path)
	forget_state()

## Alone or not, whether being caught now is the end of the floor: no stage
## left to be given back.
func last_fall() -> bool:
	var allowed: int = restarts_allowed if roster_count > 1 else solo_restarts
	return allowed >= 0 and restarts >= allowed

# --- The floor as it was left -----------------------------------------------------
#
# Beside the checkpoint (which says which floor): what had changed in it when
# it was last left, taken and given back by game/app/floor_save.gd. Binary,
# because it holds vectors and tables keyed by seat; read without objects.
const STATE_FORMAT := 1

func state_path() -> String: return checkpoint_path.get_basename() + ".state"

func write_state(state: Dictionary) -> bool:
	if online or not keeps_checkpoint: return false
	# A floor still being played has its checkpoint: a capture that was let
	# go (the stage closing under it) had taken it away, and the floor went
	# on with nothing for Continuar to open.
	if not FileAccess.file_exists(checkpoint_path) and not write_checkpoint(): return false
	var temp := state_path() + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if not file: return false
	file.store_var({"format": STATE_FORMAT, "generator": GENERATOR_VERSION, "seed": run_seed, "state": state})
	file.close()
	# The one before stays until the whole new one exists.
	if FileAccess.file_exists(state_path()): DirAccess.remove_absolute(state_path())
	return DirAccess.rename_absolute(temp, state_path()) == OK

## What was kept of the floor with this seed, or nothing: another floor's, an
## older version's or a file that cannot be read are all nothing, and the
## floor is then gone on with from its beginning.
func read_state(seed_value: int) -> Dictionary:
	if not FileAccess.file_exists(state_path()): return {}
	var file := FileAccess.open(state_path(), FileAccess.READ)
	if not file or file.get_length() < 8: return {}
	var data = file.get_var()
	if not data is Dictionary or data.get("format") != STATE_FORMAT or data.get("generator") != GENERATOR_VERSION: return {}
	if int(data.get("seed", -1)) != seed_value or not data.get("state") is Dictionary: return {}
	return data.state

func forget_state() -> void:
	if FileAccess.file_exists(state_path()) and not online and keeps_checkpoint: DirAccess.remove_absolute(state_path())

func pause() -> void:
	if state == State.PLAYING: set_state(State.PAUSED)

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
	file.store_string(JSON.stringify({"format": 1, "generator": GENERATOR_VERSION, "seed": run_seed, "floor": 1, "fallback": map_fallback, "difficulty": difficulty}))
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
	if not authority: return
	if restart_wait > 0.0 and state == State.PLAYING:
		restart_wait -= delta
		if restart_wait <= 0.0:
			restart_wait = 0.0
			raise_everyone()
			revived.emit(true)
	if state == State.TRANSITION:
		transition_time += delta
		if transition_time >= 1.2:
			if more_stages():
				stage += 1
				# A clean goal for the wing ahead, the blackout included: the
				# power that went in the wing behind is not this one's. Set
				# before anything is announced: raising the dead used to tell
				# everybody first, with the new stage and the old goal still
				# met, and the door of the stage ahead opened on its own.
				goal = {"kind": "refuge", "done": 0, "needed": 1, "ready": false}
				# Whoever died in the wing left behind comes back for the next.
				var dead: bool = participants.values().has(Life.DEAD)
				if dead: raise_everyone(false)
				set_state(State.PLAYING)
				if dead: revived.emit(false)
				return
			forget_checkpoint()
			set_state(State.WON)
