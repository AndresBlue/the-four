extends RefCounted
## One thing a stage can ask of the survivors (docs/OFICINAS.md 11.2): the
## floor's kind lists them by name (kind.OBJECTIVES) and each stage names the
## ones it asks (kind.STAGES[n].objectives). The level builds one of each with
## the floor and asks them rather than naming each: host_gate() whether the
## stage is met, the lifts the lines of the pause screen, the director where
## the team is going. The hotel's two wrap what they always were
## (televisions.gd and code_lock.gd), whose state, RPCs and saving stay theirs.

## The level that owns it (hotel_main.gd).
var level

## Before the floor is built, the same on every machine: what it fixes of the
## manifest, and what it hands the level to keep. Nothing, for one with
## nothing to choose.
static func settle(_manifest: Dictionary, _survivors: int, _kind: GDScript) -> Dictionary: return {}

func setup(owner_level) -> void: level = owner_level

## Put on the floor just built (hotel_main.populate_floor()).
func place() -> void: pass

## What a stage given back (a restart) takes back of it. Nobody calls it yet:
## revival.gd still puts the hotel's sets back itself, and the office's
## handlers wire it into revival.apply_revival() when they arrive (step 1e).
func reset() -> void: pass

## How it stands on that stage: {ready, done, needed, kind, lines, extra}. No
## kind: it does not apply there (not asked, or nothing of it on this floor),
## so it neither holds the stage's door nor names its goal; its lines are
## still the pause screen's. `extra`: keys it keeps in the session's goal.
func progress(_stage: int) -> Dictionary: return idle()

## Not applying, with whatever lines it still shows.
func idle(lines: Array = []) -> Dictionary:
	return {"ready": true, "done": 0, "needed": 0, "kind": "", "lines": lines, "extra": {}}

## Where what the stage still asks of it stands, for the director.
func goal_points(_stage: int) -> Array[Vector3]:
	var points: Array[Vector3] = []
	return points

## Once a frame on the machine in charge, whatever the stage.
func tick(_delta: float) -> void: pass

## What a floor kept to be continued holds of it (floor_save.gd still writes
## the same keys itself, in its own order), and putting it back.
func snapshot() -> Dictionary: return {}

func restore(_data: Dictionary) -> void: pass
