extends RefCounted
## The Lurker's senses (docs/OFICINAS.md 4 and 11.5; spec_f2_mind 5): what
## she perceives of each survivor, worked out on the machine that drives her,
## and handed to the brain as a Percept. "Los suyos": the director never tells
## her where anybody is. What she must not do (the warning) is decided on the
## truth, which only ever holds her back. This step (2b-1) has the data the
## brain and the warning read; sight, hearing and the drain come with 2b-2.

## One survivor as she has them this tick. `seen` and the perceived fields come
## from her senses; for her prey's seat the senses also fill the truth
## (Percept.victim), which only the warning's restraints and cue_ready() read.
class Seen extends RefCounted:
	var seat := -1
	## null in a harness.
	var body: Node3D = null
	## Feet, camera, camera forward (normalised).
	var point := Vector3.ZERO
	var eye := Vector3.ZERO
	var view := Vector3.FORWARD
	## sees() this tick; brain clock of the last sight and of the last noise
	## she took for theirs.
	var seen := false
	var seen_at := -INF
	var heard_at := -INF
	## Their eye in a lit place; their torch on; hidden, and in a locker she
	## saw them get into (that locker).
	var lit := false
	var torch := false
	var hidden := false
	var hide_known := false
	var hide: Node3D = null
	## Fair game (active and exploring), protected (a refuge, a car, untouchable).
	var fair := false
	var protected := false
	var remote := false
	## s added to their window (tests, then phase 4).
	var latency := 0.0
	## Her face to their eye; whether she is behind or above them out of
	## their look; whether they look at her face and can make it out.
	var distance := INF
	var behind := false
	var above := false
	var regards := false
	## Metres to the nearest other survivor she perceives or remembers.
	var alone := INF
	## m/s across the floor: running away during the window is what saves
	## (the author, 24 October 2026), walking is not.
	var speed := 0.0

class Percept extends RefCounted:
	var grace := false
	var face := Vector3.ZERO
	## Room of her face; -1 inside a network duct.
	var room := -1
	var in_duct := false
	## Duct exit index she is at, else -1.
	var exit_here := -1
	var off_limits := false
	var regarded_by: Array[int] = []
	var torch_by: Array[int] = []
	## Anybody would see her along the motion's next stretch.
	var stretch_exposed := false
	var moving := false
	var arrived := false
	var failed := false
	## lurker.transit_phase(): &"" when not between plantas.
	var transit: StringName = &""
	var on_channel := false
	## seat -> Seen: seen now, or remembered within `forget`.
	var bodies := {}
	## The truth about the brain's prey (perceived or not); null when none or
	## the seat has no body.
	var victim: Seen = null
	## level.sound_mask(face): the fans (planta 3).
	var mask := 0.0
