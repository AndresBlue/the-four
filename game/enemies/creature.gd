extends CharacterBody3D
## What every creature of the game is to the rest of it (docs/OFICINAS.md,
## 11.1): what the level, the director, the lifts, the sets, the net, the mind
## and the observer may ask a creature without knowing which one it is. A base
## class and not an adapter, so that get_rid(), global_position and the
## signals of the body stay what they are; The Locust (locust/hotel_locust.gd)
## extends it, and the floor's creature is hotel_main.creature (`locust` is
## the same body under its old name).
##
## Each creature says what it is doing in the words of activity(), and the
## questions the game asks with lists of The Locust's modes are answered here
## from those words, the same for any creature: each predicate is one of those
## lists (tests/hotel/creature_contract_test.gd holds them to it). The
## director, the dread aura, the world's sound, the mind and its phantoms ask
## the creature only through this; the rest of the game still reads The
## Locust until it moves over too. Everything else here is a default for a
## creature that has nothing of the kind: one that does overrides it.

## Hostile: anybody near it has reason to be afraid (pacing_director.hostile).
const HOSTILE: Array[StringName] = [&"alert", &"chase", &"strike", &"recover", &"capture", &"wait"]
## Attacking: on to somebody, or holding them (phantom_sight.allowed).
const ATTACKING: Array[StringName] = [&"alert", &"chase", &"strike", &"recover", &"capture"]
## Hunting: after somebody it has seen (dread_aura's worst).
const HUNTING: Array[StringName] = [&"chase", &"strike", &"recover", &"alert"]
## Engaged: busy with somebody or a hiding place where it stands, not to be
## taken off it by a set or a lift (match_net.warp_busy, lifts.creature_crossing).
const ENGAGED: Array[StringName] = [&"strike", &"recover", &"capture", &"open", &"wait"]
## Roaming: going about the floor on its own account (lifts.aim_at_lift).
const ROAMING: Array[StringName] = [&"roam", &"search", &"investigate"]
## What the director may send it somewhere from (pacing_director.update).
const LEADABLE: Array[StringName] = [&"roam", &"search"]
## Wary: looking for somebody, nobody found yet (dread_aura's lesser).
const WARY: Array[StringName] = [&"investigate", &"search"]

# --- Identity and control ------------------------------------------------------

## Who decides what it does. "ai": its own behaviour (offline, or the host of a
## co-op match). "puppet": it follows the state sent by the machine in charge.
## "player": a player drives it (versus).
var control := "ai"
## Seconds before it starts: nobody is hunted, seen or felt meanwhile. The
## floor's difficulty gives it (hotel_main.spawn_creature), a stage given back
## gives it some more (revival).
var grace := 15.0
## How much of its hearing it has at the moment, 0 to 1: the director dulls
## it while it is resting somebody who has earned it (pacing_director), so
## that being left alone is not undone by the first footstep.
var dull := 1.0

## Which creature this is (&"locust", &"lurker"...).
func kind_id() -> StringName: return &""

## Whether it does this at all: &"lifts", &"tv_travel", &"ducts",
## &"wardrobes", &"shriek".
func can(_ability: StringName) -> bool: return false

## Who decides what it does (`control`).
func set_control(kind: String) -> void: control = kind

## The numbers of the floor's difficulty (game/floors/difficulty.gd).
func tune(_profile: Dictionary) -> void: pass

# --- What it is doing ----------------------------------------------------------

## What it is doing, one of:
##   roam         its rounds, nobody in mind
##   investigate  going to look at something it heard
##   search       looking round where it lost somebody, or found nobody
##   alert        it has made somebody out and turns to them
##   chase        after somebody
##   strike       drawing back to hit whoever is in reach
##   recover      the moment after a strike
##   capture      holding somebody: the capture is being played
##   open         throwing a hiding place open
##   wait         waiting by a hiding place for whoever is in it to come out
func activity() -> StringName: return &"roam"

## The name of its own state, for logs and the observer.
func mode_name() -> String: return String(activity())

func is_hostile() -> bool: return activity() in HOSTILE
func is_attacking() -> bool: return activity() in ATTACKING
func is_hunting() -> bool: return activity() in HUNTING
func is_engaged() -> bool: return activity() in ENGAGED
func is_roaming() -> bool: return activity() in ROAMING
func accepts_leads() -> bool: return activity() in LEADABLE

## How alarming what it does is, to whoever feels it coming (the dread): 2
## hunting, 1 looking for somebody, 0 anything else.
func alarm_level() -> int:
	if is_hunting(): return 2
	return 1 if activity() in WARY else 0

# --- Senses ----------------------------------------------------------------------

## Where it looks from.
func eye_point() -> Vector3: return global_position + Vector3.UP * 1.7

## Where its face is, for whoever looks at it.
func face_point() -> Vector3: return eye_point()

## The way it is looking (not normalised).
func gaze() -> Vector3: return -global_basis.z

func sees(_player: Node3D, _ignore_concealment := false) -> bool: return false

## A noise: whatever it does about it.
func hear(_point: Vector3, _radius: float) -> void: pass

## How a noise reaches it: {audible, apparent, distance, muffle}.
func hear_route(point: Vector3, _radius: float) -> Dictionary:
	return {"audible": false, "apparent": point, "distance": INF, "muffle": 1.0}

## Whether any survivor has this spot in view.
func watched(_point: Vector3) -> bool: return false

# --- The director ----------------------------------------------------------------

## Sent to go round a part of the floor for a while. False when it cannot
## take the lead.
func lead_to(_point: Vector3, _radius: float, _seconds: float, _kind: String, _once := false, _avoid: Array = [], _sniff := false) -> bool: return false

## Something it did not hear through anybody: it goes to look.
func investigate(_point: Vector3) -> void: pass

## Metres of its own travel from a room to every room it can get to.
func travel_metres(_room_id: int) -> Dictionary: return {}

## On its way somewhere the director should leave it alone (a lift).
func in_transit() -> bool: return false

## Whether it keeps away from a room for now, having just searched round it:
## no lead is given there.
func searched_lately(_room_id: int) -> bool: return false

## Whether it has begun to make somebody out: the director does not distract
## a creature that has.
func noticing() -> bool: return false

# --- Moving ----------------------------------------------------------------------

## The one way a creature is put somewhere without walking there: a lift, a
## set it steps out of, a stage given back (`reason`: &"lift", &"television",
## &"revival", or anything else). It arrives still, facing `yaw` (NAN: the
## way it was facing), and forget_journey() drops what it carried of the way
## it was going. What it does once there is for whoever moved it to say.
func teleport(point: Vector3, yaw: float, reason := &"") -> void:
	global_position = point
	if not is_nan(yaw): rotation.y = yaw
	velocity = Vector3.ZERO
	forget_journey(point, reason)

## Everything of the way it was going that teleport() must not carry over,
## beyond its place and its momentum.
func forget_journey(_point: Vector3, _reason: StringName) -> void: pass

# --- The net ---------------------------------------------------------------------

## What the machine in charge sends about fifteen times a second.
func pack_state() -> Array: return []

## The same, received.
func push_state(_data: Array) -> void: pass

## A call decided where it is controlled, replayed here.
func play_call(_kind: String, _segment: int, _pitch: float) -> void: pass

# --- The capture -----------------------------------------------------------------

## Seconds a capture of its lasts, from the grab.
func capture_length() -> float: return 0.0

# --- Sound and mind --------------------------------------------------------------

## Whether what tells of it is dying away.
func hushed() -> bool: return false

## How it is felt coming by somebody at `listener` (the dread aura): [metres
## of its way to them, where the cues of it sit]. [INF, INF]: not at all.
func presence_route(_listener: Vector3) -> Array: return [INF, Vector3.INF]

## How its own sound, the presence it carries, reaches the listener: a route
## as world_audio.route_source() gives one ({audible, position, gain, cutoff,
## echo, distance}).
func sound_route(_listener: Vector3) -> Dictionary: return {"audible": false, "distance": INF}

## The script of its own lies to a mind that is going: a Node that sanity.gd
## makes under itself and keeps, with setup(level), false_call(point),
## walk_past() (true when it starts walking), walk_start() (where that walk
## began, Vector3.INF when none is on), quiet(delta), and the model and poses
## phantom_sight shows it in. Null: the floor lies with its own doors and wardrobes, and nothing of
## the creature.
func hallucinations() -> Variant: return null

# --- The observer ----------------------------------------------------------------

## A few lines on what it is doing, for whoever watches.
func debug_lines() -> Array[String]:
	return ["%s, %s, %0.0f, %0.0f" % [String(kind_id()), mode_name(), global_position.x, global_position.z]]

## The same, as values.
func debug_state() -> Dictionary:
	return {"kind": kind_id(), "activity": activity(), "mode": mode_name(), "position": global_position}
