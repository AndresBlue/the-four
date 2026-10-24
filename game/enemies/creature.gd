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
## director, the dread aura, the world's sound, the mind and its phantoms, the
## lifts, the sets, coming back, the floor kept to be continued, the capture
## (executions.gd, its tape and its blood, with the creature's own part in its
## capture style), the net (match_net.gd, its RPCs as they were), the
## observer, the floor's ledger and the bots (through the threat model of its
## kind, tools/bots/bot_threats.gd) ask the creature only through this; what
## still reads The Locust itself, and why, is in docs/DEVELOPMENT.md.
## Everything else here is a default for a creature that has nothing of the
## kind: one that does overrides it.
const WORLD_AUDIO := preload("res://game/audio/world_audio.gd")

## Hostile: anybody near it has reason to be afraid (pacing_director.hostile).
const HOSTILE: Array[StringName] = [&"alert", &"chase", &"strike", &"recover", &"capture", &"wait", &"stalk"]
## Attacking: on to somebody, or holding them (phantom_sight.allowed).
const ATTACKING: Array[StringName] = [&"alert", &"chase", &"strike", &"recover", &"capture"]
## Hunting: after somebody it has seen (dread_aura's worst).
const HUNTING: Array[StringName] = [&"chase", &"strike", &"recover", &"alert"]
## Chasing: running somebody down, or striking at them (run_ledger's chase).
const CHASING: Array[StringName] = [&"chase", &"strike", &"recover"]
## Engaged: busy with somebody or a hiding place where it stands, not to be
## taken off it by a set or a lift (match_net.warp_busy, lifts.creature_busy).
const ENGAGED: Array[StringName] = [&"strike", &"recover", &"capture", &"open", &"wait"]
## Roaming: going about the floor on its own account (lifts.apply_locust_ride,
## and The Locust's aim_at_lift).
const ROAMING: Array[StringName] = [&"roam", &"search", &"investigate"]
## What the director may send it somewhere from (pacing_director.update).
const LEADABLE: Array[StringName] = [&"roam", &"search"]
## Wary: looking for somebody, nobody found yet (dread_aura's lesser, and
## televisions.creature_channel_hop: looking for nobody at a set).
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
## Its own draws, seeded with the floor by the creature itself: whatever
## chooses something for it (the set it steps out of:
## televisions.creature_channel_hop) draws from them, in the order it always
## has.
var rng := RandomNumberGenerator.new()

## Which creature this is (&"locust", &"lurker"..., &"none" the null one).
func kind_id() -> StringName: return &""

## Whether it does this at all: &"lifts", &"tv_travel", &"ducts",
## &"wardrobes", &"shriek" (its hunter's cry), &"echo" (its hunter reads the
## floor by ear, echo_view.gd, which the observer's V shows too).
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
##   idle         does nothing at all (the null creature, null_creature.gd)
##   stalk        following somebody out of their sight, keeping its distance
##                (the Lurker's stalking: hostile, not hunting nor chasing)
##   withdraw     drawing off after a fright, nobody in mind, not to be led
##                (the Lurker's flight to a duct)
func activity() -> StringName: return &"roam"

## The name of its own state, for logs and the observer.
func mode_name() -> String: return String(activity())

func is_hostile() -> bool: return activity() in HOSTILE
func is_attacking() -> bool: return activity() in ATTACKING
func is_hunting() -> bool: return activity() in HUNTING
func is_chasing() -> bool: return activity() in CHASING
func is_engaged() -> bool: return activity() in ENGAGED
func is_roaming() -> bool: return activity() in ROAMING
func accepts_leads() -> bool: return activity() in LEADABLE
func is_wary() -> bool: return activity() in WARY

## How alarming what it does is, to whoever feels it coming (the dread): 2
## hunting, 1 looking for somebody, 0 anything else.
func alarm_level() -> int:
	if is_hunting(): return 2
	return 1 if is_wary() else 0

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

## Whoever it has in mind: the survivor it is making out, after or holding.
## Null: nobody.
func quarry() -> Node3D: return null

## Somebody was seen getting into this hiding place (interaction.gd,
## match_net.request_hide). `sure`: it saw them, and knows somebody is in
## there; not sure, it only has a reason to search it (a bot getting in,
## bot_body.enter_wardrobe, as it always has).
func saw_enter(_hide: Node3D, _sure := true) -> void: pass

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

## Where it is on its way to another planta without the lifts (the Lurker's
## ducts): &"" when not.
func transit_phase() -> StringName: return &""

## Whether it keeps away from a room for now, having just searched round it:
## no lead is given there.
func searched_lately(_room_id: int) -> bool: return false

## Whether it has begun to make somebody out: the director does not distract
## a creature that has.
func noticing() -> bool: return false

# --- Moving ----------------------------------------------------------------------

## The one way a creature is put somewhere without walking there: a lift
## (lifts.apply_locust_ride), a set it steps out of
## (televisions.warp_creature), a stage given back (revival.relocate_creature)
## (`reason`: &"lift", &"television", &"revival", or anything else). It
## arrives still, facing `yaw` (NAN: the way it was facing), and
## forget_journey() drops what it carried of the way it was going: what each
## of those three dropped by hand before there was one teleport, and all of it
## for any other reason. Neither what it is doing nor its grace is touched:
## what it does once there is for whoever moved it to say.
func teleport(point: Vector3, yaw: float, reason := &"") -> void:
	global_position = point
	if not is_nan(yaw): rotation.y = yaw
	velocity = Vector3.ZERO
	forget_journey(point, reason)

## Everything of the way it was going that teleport() must not carry over,
## beyond its place and its momentum, by how it was moved.
func forget_journey(_point: Vector3, _reason: StringName) -> void: pass

## Put somewhere at once, having forgotten everybody, with `rest` seconds
## before it moves again (grace, at least): a stage given back, a floor
## continued. What it knew of anybody, and what it was in the middle of, goes
## here; what it carried of the way it was going is teleport()'s
## (revival.relocate_creature does both). The default only puts it there to
## wait.
func relocate(point: Vector3, rest: float) -> void:
	global_position = point
	grace = maxf(grace, rest)

## It looks round from `point` (first the way of `heading`, or none in
## particular) and then goes about the planta: where a car or a set has just
## let it out.
func search_from(_point: Vector3, _heading: Vector3) -> void: pass

## The survivors have gone on to the planta of `stage` and it is behind them:
## it makes for the way they took, without being taken off anything it is
## already doing. `fresh`: they have only just gone (lifts.follow_players),
## not a reminder while it is still behind (lifts.creature_crossing).
func follow_to_planta(_stage: int, _fresh := false) -> void: pass

## Where it starts a stage, and goes back to when that stage is given back.
## INF: nowhere of its own, and whoever puts it there finds it a place far
## enough from everybody (revival.den_away).
func den_point(_stage: int) -> Vector3: return Vector3.INF

## The room it starts a stage in, on the floor in play; -1 for none (the
## level then puts it in the floor's start).
func start_room(_stage: int) -> int: return -1

## Put in a room at the start of the run: where its round begins.
func place_at(_room_id: int) -> void: pass

## Armed for the run by the difficulty's rules: onslaught, it reaches further
## and does not ease off.
func arm(_onslaught: bool) -> void: pass

## The profile its presence plays through world_audio; null for none.
func presence_sound() -> Resource: return null

## The camera its hunter sees through in versus; null when it has none.
func hunter_camera() -> Camera3D: return null

## The lights went out: its hunter's view is told.
func blackout() -> void: pass

## What of it is kept with a floor left to be continued (floor_save), in a
## form the session can write (no objects).
func save_state() -> Dictionary: return {}

## That put back on the floor built again, having forgotten everybody, with
## `rest` seconds before it moves.
func restore_state(_state: Dictionary, _rest: float) -> void: pass

# --- The net ---------------------------------------------------------------------

## What the machine in charge sends about fifteen times a second.
func pack_state() -> Array: return []

## The same, received.
func push_state(_data: Array) -> void: pass

## A call decided where it is controlled, replayed here.
func play_call(_kind: String, _segment: int, _pitch: float) -> void: pass

## A moment of it every machine must hear of, told reliably by whoever drives
## it (docs/OFICINAS.md 11.6) and applied here on the others.
func on_event(_kind: String, _data: Array) -> void: pass

## The same, received by the machine of its hunter coming back into a match
## (match_net.restore): it stands where it was left, facing that way, with
## the grace it had; the rest is the hunter's to drive again.
func resume_state(_data: Array) -> void: pass

## The host's verdict on a strike its hunter claims, from `origin` facing
## `facing` (match_net.resolve_strike), against one survivor: the metres to
## them when it reaches them, INF when it does not. Of everybody it reaches,
## the nearest is taken.
func validate_strike(_origin: Vector3, _facing: Vector3, _body: Node3D) -> float: return INF

# --- Its hunter (versus) -----------------------------------------------------------

## How much further than its own measures it sees and hears for now (a room's
## onslaught): what its hunter's cry reaches is stretched as much
## (match_net.update_shriek).
func sense_scale() -> float: return 1.0

## On its hunter's machine, where its cry found somebody moving.
func hunter_reveal(_points: PackedVector3Array) -> void: pass

## On its hunter's machine, a noise it hears as it hears it (hear_route()'s
## apparent spot, metres and muffle): match_net.tell_hunter.
func hunter_contact(_point: Vector3, _apparent: Vector3, _distance: float, _strength: float, _kind: int, _muffle: float) -> void: pass

## Its hunter has dropped out of a versus match and the machine in charge
## drives it meanwhile (set_control("ai") has been said): it takes the floor
## up from where it stands (match_net.seat_dropped).
func hunter_gone() -> void: pass

## The graphics settings changed (presentation_rig.apply_settings): whatever
## of it is drawn by them follows (its hunter's view).
func apply_quality() -> void: pass

# --- The capture -----------------------------------------------------------------

## How it plays a capture out (game/app/capture_styles/): a script that
## executions.gd makes one of, with `level` set, and asks where it stands to
## its victim, how they were caught, the room for the body to go down in and
## where everything of the scene is at each second; death_tape.gd frames its
## picture in the face it gives, blood.gd takes where it stands and faces
## from it. Null: it catches nobody.
func capture_style() -> Variant: return null

## It has hold of somebody: the capture the host staged (executions'
## `execution`) starts, on every machine.
func begin_capture(_data: Dictionary) -> void: pass

## The capture is cut short, its victim let go alive
## (executions.release_execution): it leaves it. Played to its end, it lets
## go by itself, after capture_length().
func end_capture() -> void: pass

## Seconds a capture of its lasts, from the grab.
func capture_length() -> float: return 0.0

## Turned to its victim for the capture (executions.apply_execution()); a
## creature whose capture places it some other way leaves itself as it is.
func turn_for_capture(yaw: float) -> void: rotation.y = yaw

## Whether it may take this survivor now, asked by executions.capture_survivor()
## at the last moment, on the machine that decides. The Lurker only at the end
## of her warning behind them (docs/OFICINAS.md 11.5, lurker_warning.gd);
## every other creature: yes.
func may_capture(_body: Node3D) -> bool: return true

## The warning a capture of this survivor answers (its id in capture_log()),
## -1 for none: executions.stage_capture() keeps it with the capture.
func cue_of(_body: Node3D) -> int: return -1

## Every warning it has given this floor, and what came of each
## (lurker_warning.gd ledger): what the tests and the bots' watcher check.
func capture_log() -> Array: return []

## Its warning behind `seat`, decided on the machine in charge, played here
## from `point`, where it really is (match_net.send_cue).
func play_cue(_seat: int, _cue_id: int, _point: Vector3, _hold: float) -> void: pass

## That warning is over (taken, saved, given up): whatever of it is still
## held on this machine lets go.
func cue_over(_cue_id: int, _outcome: String) -> void: pass

## The beats of throwing a hiding place open (match_net.update_wardrobe_jobs),
## seconds from its start: the leaves burst, it reaches in, it is done.
func wardrobe_steps() -> Dictionary: return {"burst": 0.55, "reach": 0.7, "done": 1.7}

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

## Where its presence and its voice sound from (world_audio).
func voice_point() -> Vector3: return global_position + WORLD_AUDIO.PRESENCE_RISE

## Whether its presence loop may play now (world_audio).
func presence_on() -> bool: return true

## The script of its own lies to a mind that is going: a Node that sanity.gd
## makes under itself and keeps, with setup(level), false_call(point),
## walk_past() (true when it starts walking), walk_start() (where that walk
## began, Vector3.INF when none is on), quiet(delta), and the model and poses
## phantom_sight shows it in. Null: the floor lies with its own doors and wardrobes, and nothing of
## the creature.
func hallucinations() -> Variant: return null

# --- The observer ----------------------------------------------------------------

## What it did on the floor, for the bots' summary (bot_match.finish());
## empty: nothing of its own to count.
func tally() -> Dictionary: return {}

## Its part of the observer's panel (observer_view.report): a few lines on
## what it is doing and where, the first one its name.
func debug_lines() -> Array[String]:
	return ["%s (%s)" % [String(kind_id()).to_upper(), control], "  %s, gracia %0.1f, %0.0f, %0.0f" % [mode_name(), grace, global_position.x, global_position.z]]

## The same, as values: what the observer's log watches ("modo", what it is
## doing in the panel's words) and its dump (F5) keeps of it.
func debug_state() -> Dictionary:
	return {"modo": mode_name(), "mando": control, "donde": [global_position.x, global_position.y, global_position.z]}

## Its marks over the floor (observer_gizmos.gd), on the layer `g` is drawing
## now (g.layer): &"path", where it is going; &"sight", what it sees. Drawn
## with g.line(), g.mark() and g.ring() in g.COLOURS, only where g.here().
func draw_gizmos(_g) -> void: pass
