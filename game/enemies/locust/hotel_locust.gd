extends CharacterBody3D
@export var sound_profile: Resource = preload("res://game/audio/profiles/locust.tres")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const THREAD := preload("res://game/enemies/locust/door_threading.gd")
enum Mode { PATROL, INVESTIGATE, CHASE, SEARCH, WINDUP, RECOVER, ALERT, WARDROBE, EXECUTE, LURK }
## Perception and pacing. Distances in metres, speeds in m/s.
## It perceives the player from much farther than the player can sense it:
## anything in its wide view with a clear line is noticed, however far.
const SIGHT_RANGE := 70.0
## Onslaught (a rule of the room): how much further it sees and hears, and
## whether it keeps its full pace after losing sight of whoever it hunts.
const ONSLAUGHT_REACH := 1.25
var reach_scale := 1.0
var relentless := false

## The numbers this creature plays by: the constants of this script are the
## game as it was (the difficulty "desafiante"), and the floor's difficulty
## writes these over them as it starts (game/floors/difficulty.gd,
## hotel_main.arm_creature). Everything that decides what it does reads these.
var sight_range := SIGHT_RANGE
var notice := 1.0
var hearing := 1.0
var torch_range := TORCH_NOTICE_RANGE
var alert_time := ALERT_TIME
var chase_start := CHASE_START_SPEED
var chase_accel := CHASE_ACCELERATION
var chase_speed := CHASE_SPEED
var track_speed := TRACK_SPEED
var lose_after := LOSE_AFTER
var give_up := GIVE_UP
var give_up_hard := GIVE_UP_HARD
var peek_chance := SEARCH_PEEK_CHANCE
var attack_range := ATTACK_RANGE
var recover_time := RECOVER_TIME
var wardrobe_scale := 1.0
## Its mind (docs/DIFFICULTY.md, section 4): all off for "desafiante".
var doubt_time := 0.0
var chase_tire := 0.0
var lost_cry := false
var guess_hides := true
## The feint (docs/EXECUTION.md, 13.3): with somebody it SAW get into a
## wardrobe, how often it waits for them to come out instead of opening it
## (0: never, as the game was), and for how long it will (seconds, drawn
## between the two).
var feint := 0.0
var feint_wait := Vector2(9.0, 13.0)

## The doubt: the first moment it makes somebody out (DOUBT_FROM) it stops,
## turns its head to them and chitters, and nothing comes of what it sees
## (DOUBT_CAP) until the doubt is over -- whoever ducks out of sight by then
## was not seen. DOUBT_REST before it doubts again.
const DOUBT_FROM := 0.05
const DOUBT_CAP := 0.95
const DOUBT_REST := 6.0
var doubting := 0.0
var doubt_rest := 0.0
## Tiring of a chase: how long this one has lasted, and until when it will not
## take any notice of anybody -- the few seconds it takes to turn its back
## and be off. After them it is as it ever is: whoever it sees, it is after
## again (the author's word, 13 October 2026; it used to be blind and deaf
## for ten to twenty seconds, standing by whoever had outrun it, and that
## read as the creature broken).
const TIRED_FOR := 3.0
## This floor's (the difficulty's "tired").
var tired_for := TIRED_FOR
## How much of its hearing it has at the moment, 0 to 1: the director dulls
## it while it is resting somebody who has earned it (pacing_director), so
## that being left alone is not undone by the first footstep.
var dull := 1.0
var chase_time := 0.0
var tired_until := -INF
## It has been after somebody since it last gave up: giving up now is losing
## them, and it says so (lost_cry).
var had_quarry := false
const LOST_PITCH := 0.66
const CHITTERS := ["res://assets/audio/dread/chitter_0.wav", "res://assets/audio/dread/chitter_1.wav", "res://assets/audio/dread/chitter_2.wav"]

## A profile of the difficulties (the creature's part of it).
func tune(profile: Dictionary) -> void:
	sight_range = float(profile.sight_range)
	notice = float(profile.notice)
	hearing = float(profile.hearing)
	torch_range = float(profile.torch_range)
	alert_time = float(profile.alert_time)
	chase_start = float(profile.chase_start)
	chase_accel = float(profile.chase_accel)
	chase_speed = float(profile.chase_speed)
	track_speed = float(profile.track_speed)
	lose_after = float(profile.lose_after)
	give_up = float(profile.give_up[0])
	give_up_hard = float(profile.give_up[1])
	peek_chance = float(profile.peek_chance)
	attack_range = float(profile.attack_range)
	recover_time = float(profile.recover)
	wardrobe_scale = float(profile.wardrobe)
	doubt_time = float(profile.doubt)
	chase_tire = float(profile.chase_tire)
	lost_cry = bool(profile.lost_cry)
	guess_hides = bool(profile.guess_hides)
	feint = float(profile.get("feint", 0.0))
	var waits: Array = profile.get("feint_wait", [9.0, 13.0])
	feint_wait = Vector2(float(waits[0]), float(waits[1]))
	tired_for = float(profile.get("tired", TIRED_FOR))
	sight_half_angle = float(profile.get("sight_angle", SIGHT_HALF_ANGLE))
	cover = float(profile.get("cover", 0.0))
	glimpse = float(profile.get("glimpse", 0.0))

## How sharp its eyes are (the difficulty writes them; the game as it was sees
## in SIGHT_HALF_ANGLE to either side and takes any part of a body in view
## for somebody at once). `sight_half_angle`: degrees to either side of where
## it faces. `cover`: the share of a body that has to show for it to take it
## for somebody straight away; less than that -- a head and a shoulder round
## a door frame -- and it has to be left in view for `glimpse` seconds before
## it notices. Only while it is not after anybody: once it hunts, half a body
## is as good as a whole one.
var sight_half_angle := SIGHT_HALF_ANGLE
var cover := 0.0
var glimpse := 0.0
## Seat -> seconds that survivor has been in view, partly covered.
var peeked := {}
## The points of a body it looks for besides the eyes, as [share of the eyes'
## height, metres to one side]: both shoulders, both hips, both knees.
const BODY_POINTS := [[0.86, 0.2], [0.86, -0.2], [0.56, 0.18], [0.56, -0.18], [0.28, 0.16], [0.28, -0.16]]

## How much of a survivor it has in plain sight, 0 to 1: the eyes (which
## sees() has already found) and BODY_POINTS, each one a ray of its own.
func shown(player: Node3D) -> float:
	var eyes: Vector3 = player.camera.global_position
	var feet: Vector3 = player.global_position
	var height: float = maxf(0.5, eyes.y - feet.y)
	var away: Vector3 = eyes - (global_position + Vector3(0, EYE_HEIGHT, 0))
	var side := Vector3(-away.z, 0.0, away.x)
	if side.length() < 0.01: side = Vector3.RIGHT
	side = side.normalized()
	var count := 1
	for point in BODY_POINTS:
		if clear_sight(Vector3(eyes.x, feet.y + height * float(point[0]), eyes.z) + side * float(point[1])): count += 1
	return float(count) / float(BODY_POINTS.size() + 1)

## Whether somebody it can see goes unnoticed for now: mostly behind
## something, and not there long enough yet. Counted while it lasts.
func overlooks(player: Node3D, delta: float) -> bool:
	if cover <= 0.0 or mode not in [Mode.PATROL, Mode.SEARCH, Mode.INVESTIGATE] or player.hidden: return false
	var seat := int(player.slot) if "slot" in player else 0
	if shown(player) >= cover:
		peeked.erase(seat)
		return false
	peeked[seat] = float(peeked.get(seat, 0.0)) + delta
	return float(peeked[seat]) < glimpse

## The survivor it takes notice of this frame: seen_survivor(), unless they
## are one it overlooks -- then the nearest it can see and does not.
func noticed_survivor(delta: float) -> Node3D:
	var seen := seen_survivor()
	if seen == null or cover <= 0.0:
		if seen == null and not peeked.is_empty():
			# Out of view: what it had half seen fades at the rate it came.
			for seat in peeked.keys():
				peeked[seat] = float(peeked[seat]) - delta
				if peeked[seat] <= 0.0: peeked.erase(seat)
		return seen
	if not overlooks(seen, delta): return seen
	var best: Node3D = null
	var best_distance := INF
	for player in level.survivors():
		if player == seen or not sees(player) or overlooks(player, delta): continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best

## The beats of searching a wardrobe, at this creature's pace.
func wardrobe_steps() -> Dictionary:
	var burst := float(WARDROBE_TIME.burst) * wardrobe_scale
	return {"burst": burst, "reach": burst + float(WARDROBE_TIME.reach), "done": float(WARDROBE_TIME.done) * wardrobe_scale}
const SIGHT_HALF_ANGLE := 60.0
## Suspicion gained per second with the player in view, near and far.
const NOTICE_NEAR := 3.2
const NOTICE_FAR := 0.9
const NOTICE_DECAY := 0.12
## Suspicion at which it stops wandering and goes to look.
const SUSPICION := 0.2
## Player noises carry this many times their base radius, along walkable routes.
const NOISE_TABLE := preload("res://game/audio/noise_kinds.gd")
const HEARING_SCALE := NOISE_TABLE.HEARING_SCALE
## Closest to itself that a noise heard round a corner is ever placed.
const APPARENT_NEAREST := 3.5
## Lost sight for longer than this, the chase becomes a search.
const LOSE_AFTER := 7.0
## Its rounds. It walks to a room PATROL_NEAR..PATROL_FAR metres of walking
## away, not to the next one: one room at a time, drawn at random with no
## memory, it went into a bedroom and straight back out, round and round the
## same few cells, and only seemed to wake up when something else sent it
## further. It prefers the rooms it has not seen for longest (STALE_FULL
## seconds is as stale as a room gets) over those it has just searched or just
## walked through, and a bedroom with a single door only now and then.
const PATROL_NEAR := 20.0
const PATROL_FAR := 60.0
const STALE_FULL := 150.0
const DEAD_END_PEEK := 0.35
const RECENT_ROOMS := 6
## Seconds it stands looking round a room it has walked to.
const SCAN_TIME := Vector2(1.0, 2.5)
## Its search, once it has lost somebody or found nobody where it heard them:
## where they were, the doorway they were heading for, the room beyond it and
## one more room next door -- a look, not a siege. GIVE_UP seconds without a
## clue once it has looked (GIVE_UP_HARD whatever is left to look at) and it
## gives the place up: the rooms within SEARCHED_RADIUS count as searched for
## SEARCHED_FOR seconds, and it walks off at LEAVE_PACE to somewhere at least
## LEAVE_MIN metres away. It used to pace a ring round the last place it knew
## for ten seconds and then wander off from there one room at a time, so
## whoever hid near by had it walking past their wardrobe for minutes.
const GIVE_UP := 8.0
const GIVE_UP_HARD := 10.0
const SEARCHED_RADIUS := 18.0
const SEARCHED_FOR := 75.0
const LEAVE_MIN := 38.0
const LEAVE_PACE := 2.6
## How often a search opens a wardrobe in the room the quarry was heading for.
const SEARCH_PEEK_CHANCE := 0.2
## However noisy a place, it spends no more than AREA_CAP seconds there: after
## that only seeing somebody or a loud noise (heard LOUD metres off and more:
## a run, a jump, a door flung open) is worth staying for. Two points within
## AREA_SAME metres are the same place.
const AREA_CAP := 40.0
const AREA_SAME := 15.0
const LOUD := 30.0
## Faster than a sprinting player: breaking line of sight is the only escape.
const CHASE_SPEED := 6.4
## Speed while heading to the last place it saw or heard the player.
const TRACK_SPEED := 5.2
## Making for the lift the survivors took: a lope, not a chase. A whole
## planta is a couple of hundred metres of rooms and corridors to the car,
## which walking took it two minutes and more.
const LIFT_PACE := 4.0
## On first spotting the player it freezes, turns and shrieks before it runs:
## the moment the player hears it is the moment to break line of sight.
const ALERT_TIME := 1.2
## A chase starts from this speed and builds up at CHASE_ACCELERATION.
const CHASE_START_SPEED := 2.5
const CHASE_ACCELERATION := 3.2
const TORCH_NOTICE_RANGE := 45.0
## The cone it notices a torch in, whatever the beam is drawn as: the drawn
## beam is narrower on Compatibility (hotel_player.PLAIN_BEAM), and reading it
## made a torch harder to be seen by on some machines than on others.
const TORCH_NOTICE_ANGLE := 32.0
## Within ATTACK_RANGE of somebody it can see, it has them: that instant, with
## nothing drawn back first (seize). It used to lunge for a third of a second
## and take whoever was still within STRIKE_REACH at the end of it, which is
## what a player who drives it still does (locust_player.strike, WINDUP_TIME).
const ATTACK_RANGE := 2.4
const STRIKE_REACH := 3.2
const WINDUP_TIME := 0.3
const RECOVER_TIME := 0.6
## Eye height of the creature for line-of-sight checks.
const EYE_HEIGHT := 2.4
const GRUNTS := preload("res://game/audio/grunt_segments.gd")
const CRY_SOUND := "res://assets/audio/sfx/chase/grunts.ogg"
## Grunts at least this long are the full, aggressive ones; shorter pieces of
## the recording are breaths and clicks, not used as calls.
const AGGRESSIVE_GRUNT := 1.4
## Searching a wardrobe: it plants itself in front, throws both leaves open
## at once -- as fast as it does after waiting beside one (POUNCE_BURST) --
## and has whoever is in it as they hit their stops; with nobody there it
## looks in a moment and moves on. Seconds from the start (`burst` and `done`
## at the difficulty's pace; `reach` is that long after the doors go, at
## any). It used to pull one leaf open and then the other, and a second and a
## half of doors opening is a second and a half to get ready for the scream.
const WARDROBE_TIME := {"burst": 0.55, "reach": 0.15, "done": 1.7}
## An execution: it grabs you, holds you up while it brings its mask slowly to
## your face, and then buries its arm in it. Seconds from the grab, and when
## the killing blow lands (see hotel_main.apply_execution).
const EXECUTION_TIME := 4.7
const EXECUTION_KILL := 3.3
var level
var mode := Mode.PATROL
var destination := Vector3.ZERO
var last_known := Vector3.ZERO
## The wardrobe it means to open: one it has reason to search (it lost
## somebody beside it, or heard them there) or one it knows somebody is in.
## `certain` is the second: it saw them get in, or saw them through a leaf
## left ajar. Only that is worth a feint; both are forgotten together.
var observed_hide: Node3D:
	set(value):
		observed_hide = value
		if value == null: certain = false
var certain := false
## 0..1+ suspicion; 1 starts a chase.
var detection := 0.0
var lost_time := 0.0
var state_time := 0.0
var grace := 15.0
var repath := 0.0
var path := PackedVector3Array()
var path_index := 0
var rng := RandomNumberGenerator.new()
var signal_player: AudioStreamPlayer3D
var visual: Node3D
var patrol_room := 0
var footstep: AudioStreamPlayer3D
## Current ground speed; accelerates toward the speed each behaviour wants.
var speed := 0.0
## Making for the car of the lift the survivors took (lifts.aim_at_lift):
## until anything else sets its mode.
var lift_bound := false
var pause_time := 0.0
var light_exposure := 0.0
var wander_clock := 0.0
## Chase vocalisations: one grunt segment at a time from the creature.
var voice: AudioStreamPlayer3D
var grunt_clock := 0.0
var grunt_left := 0.0
## Seconds between chase grunts, and the short wait after one that nobody
## could hear: out of earshot it tries again soon, so it calls the moment it
## comes round the corner instead of staying mute for another five seconds.
const GRUNT_WAIT := Vector2(2.5, 5.0)
const GRUNT_RETRY := 0.7
## No two calls closer together than this, whatever asks for them: a hunter
## tapping the sprint key restarts the chase over and over, and without this
## the creature would gabble.
const GRUNT_MIN := 1.6
## The voice is shaped by what it is saying. A shriek is brutal close up and
## then stops: past what it buys the hunter (match_net.SHRIEK_RANGE, 26 m of
## listening) it should be no use as a bearing. A chase grunt is never that
## loud but carries further, because it is meant to be heard coming.
const VOICE_SHRIEK := {"unit": 5.5, "reach": 32.0, "level": 3.0}
const VOICE_GRUNT := {"unit": 7.0, "reach": 40.0, "level": 0.0}
## A chase grunt meant for the one who hears it. In the din of a creature
## running at you -- claws, breath, drone, chitter, heart -- a grunt at the
## level of any other call was one more layer. When it is after you it is
## louder, falls off less with distance (so it sounds close, not across the
## room), keeps its top end unless a wall is in the way, and everything else
## it brings steps back while it lasts (world_audio.duck_under), so it takes
## the scene. After you means: the AI chasing this machine's survivor, or --
## where somebody else runs the creature -- it being close with you in plain
## sight.
const AIMED_GAIN := 7.0
const AIMED_UNIT := 13.0
const AIMED_REACH := 24.0
const AIMED_CUTOFF := 12000.0
var grunt_rest := 0.0
## The cry it lets out when its grace runs out and the hunt starts -- at the
## start of a floor, and again after a stage given back: heard over the whole
## floor, like a death, so everybody knows it is on its feet -- only not
## where, past the reach of an ordinary sound. The longest calls of the
## recording (CRY_LONGEST), pitched down. The machine and a player hunting
## alike, cried where it is driven (count_grace) and told to everyone else.
const CRY_LONGEST := 2.0
const CRY_PITCH := Vector2(0.78, 0.88)
const CRY_GAIN := 0.0
## The last grunt was aimed at this machine's survivor.
var aimed := false
## Seconds left of the bark that announces a strike (it lives inside the same
## long recording, so it has to be stopped where it ends).
var warn_left := 0.0
## How long it can go without seeing its prey before finding it again is worth
## another grunt.
const GRUNT_REGAIN := 1.5
var sight_gap := 0.0
## The hunter's shriek: aggressive grunts chained back to back for as long as
## its red lasts, then faded out with it (howl()). Seconds left including the
## fade, how long that fade is, and the level the current grunt was routed at.
var howl_left := 0.0
var howl_fade := 1.0
var howl_db := 0.0
var last_grunt := -1
## A clock of its own, for how long ago it saw each room.
var clock := 0.0
## Room id -> clock when it last stood in it or looked into it.
var room_seen := {}
## Room id -> clock until which it keeps away: the rooms round a place it gave up.
var searched_until := {}
## The last few rooms it stood in, oldest first.
var recent_rooms: Array = []
## Metres of walking from a room to every room of its planta, by room.
var walks := {}
var mark_clock := 0.0
## How long this leg of its rounds may take before it picks another.
var patrol_limit := 14.0
## Walking off from a place it gave up: brisk, and not turning back for anything
## short of a clue.
var leaving := false
## The search: what is left to look at ({point, hide}), the wardrobe it is on
## its way to open, where the place it is searching is, how long since the
## last clue, how long it has spent on the place, and the way its quarry was
## last going.
var search_plan: Array = []
var search_hide: Node3D
var search_origin := Vector3.INF
var clue_idle := 0.0
var area_spent := 0.0
var last_heading := Vector3.ZERO
## A part of the floor the pacing director has sent it to go round, for a
## while: {point, radius, until, kind, rooms, once, sniff}. Its rounds keep to
## those rooms until then (once: until it gets to one; sniff: it opens one of
## their wardrobes, drawn). It is never told where anybody is: that is the
## director's to know.
var lead := {}
## The wardrobe a sniffing lead has it going to open.
var sniff_hide: Node3D

## The survivor it is watching or hunting (see level.survivors()); several
## players can be on the floor, it only ever pursues one at a time.
var focus: Node3D
## Who decides what it does. "ai": its own behaviour (offline, or the host of a
## co-op match). "puppet": it follows the state sent by the machine in charge.
## "player": a player drives it (versus, see locust_player.gd).
var control := "ai"
## Versus: the controller that reads the local player's input, and its camera.
var driver: Node
var camera: Camera3D
## The wardrobe it is searching (Mode.WARDROBE).
var wardrobe: Node3D
## Puppet: received states {time, position, yaw, velocity} and a local clock.
var net_states: Array = []
var net_clock := 0.0
var net_look := Vector3.INF
## Calls replayed here from the machine in charge (tests check they arrive),
## the kind of the last one, and how many calls this machine has made itself.
var calls_heard := 0
var last_call := ""
var calls_made := 0

func _ready() -> void:
	add_to_group("hotel_actors")
	visual = $Visual
	signal_player = $Warning
	# The tell before a strike is its own voice, a short bark out of the same
	# recording: the synthesised sweep it used to be was a rising whoosh that
	# belonged to no animal.
	signal_player.stream = load("res://assets/audio/sfx/chase/grunts.ogg")
	footstep = $Footsteps
	footstep.stream = claw_sound()
	if visual.has_signal("footfall"): visual.footfall.connect(on_footfall)
	voice = AudioStreamPlayer3D.new()
	voice.name = "Voice"
	voice.bus = "Threat"
	voice.stream = load("res://assets/audio/sfx/chase/grunts.ogg")
	voice.unit_size = 7.0
	voice.max_distance = 40.0
	voice.max_db = 4.0
	voice.area_mask = 512
	# Hung where the route leaves it, like world_audio's presence: as a child of
	# the creature it dragged the call along for the rest of the segment, so a
	# grunt heard through a doorway walked away from that doorway.
	if level != null and is_instance_valid(level.world_audio): level.world_audio.add_child(voice)
	else: add_child(voice)
	if level == null:
		set_physics_process(false)
		return
	rng.seed = level.manifest.seed + 71013
	destination = position
	wander_clock = rng.randf() * 100.0

## Its voice hangs under world_audio, which outlives the floor: it has to go
## when the creature does, or the next floor starts with a mute leftover.
func _exit_tree() -> void:
	if is_instance_valid(voice) and voice.get_parent() != self: voice.queue_free()

## The short pieces of the recording, the ones too short to be calls: barks and
## breaths. One of them is the tell that a strike is coming.
func warn() -> void:
	var choices: Array = []
	for index in GRUNTS.SEGMENTS.size():
		if GRUNTS.SEGMENTS[index][1] < AGGRESSIVE_GRUNT: choices.append(index)
	if choices.is_empty() or signal_player.stream == null: return
	var segment: Array = GRUNTS.SEGMENTS[choices[rng.randi_range(0, choices.size() - 1)]]
	signal_player.pitch_scale = rng.randf_range(0.78, 0.9)
	# Routed like its grunts and its feet: behind a wall the bark comes round
	# through the doorway, or does not come at all. It used to go straight
	# through walls, the only one of its sounds that did.
	if level != null and level.world_audio.enabled:
		var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
		if route.audible: level.world_audio.apply_route(signal_player, route, 0.0, "Threat", true)
		else: signal_player.volume_db = -80.0
	signal_player.play(segment[0])
	warn_left = segment[1] / signal_player.pitch_scale

## A pointed leg striking the floor: a hard tick over a hollow knock.
static func claw_sound() -> AudioStreamWAV:
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = 22050
	var count := 5512
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 4401
	for i in count:
		var t := float(i) / 22050.0
		var tick := sin(TAU * 3100.0 * t) * exp(-t * 320.0) + (noise.randf() - 0.5) * exp(-t * 500.0) * 0.8
		var knock := sin(TAU * 118.0 * t) * exp(-t * 34.0) * minf(1.0, t * 900.0)
		bytes.encode_s16(i * 2, int(clampf(tick * 0.7 + knock * 0.8, -1.0, 1.0) * 30000.0))
	audio.data = bytes
	return audio

## Each pointed foot strikes the floor where the animation plants it.
func on_footfall(point: Vector3, strength: float) -> void:
	if level == null or level.session.state != level.session.State.PLAYING or not level.world_audio.enabled: return
	# Heard directly, or from the doorway it would come through; never through walls.
	var route: Dictionary = level.world_audio.route_source(point + Vector3.UP * 0.2, get_rid())
	if not route.audible: return
	# Its own feet, right under the hunter's ear, would wear it out: quieter still.
	var level_db := lerpf(-9.0, -1.0, strength) - (6.0 if control == "player" else 0.0)
	level.world_audio.apply_route(footstep, route, level_db + level.world_audio.duck_db(), "Threat", true)
	footstep.pitch_scale = rng.randf_range(0.82, 1.08)
	footstep.play()

## Plays one aggressive grunt from the recording, never the same one twice in
## a row, routed like every other creature sound. Returns how long it lasts.
func grunt() -> float:
	if level == null: return 0.0
	var choices: Array = []
	for index in GRUNTS.SEGMENTS.size():
		if GRUNTS.SEGMENTS[index][1] >= AGGRESSIVE_GRUNT and index != last_grunt: choices.append(index)
	last_grunt = choices[rng.randi_range(0, choices.size() - 1)]
	calls_made += 1
	var segment: Array = GRUNTS.SEGMENTS[last_grunt]
	var pitch := rng.randf_range(0.85, 1.0)
	# Everyone else hears the same call from their own place.
	if "match_net" in level and level.match_net != null: level.match_net.creature_call("grunt", last_grunt, pitch)
	aimed = aimed_at_local()
	# Silent runs (tests, captures) keep the cadence: the call counts as made.
	if not level.world_audio.enabled: return segment[1] / pitch
	var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
	if not route.audible: return 0.0
	# Its own throat, right under the hunter's ear, would wear it out: quieter
	# for whoever is carrying the creature, like its feet.
	level.world_audio.apply_route(voice, route, shape_voice(false) - (6.0 if control == "player" else 0.0), "Threat", true)
	voice.pitch_scale = pitch
	voice.play(segment[0])
	# A lower pitch plays the segment slower: stop when it really ends.
	grunt_left = segment[1] / voice.pitch_scale
	aim_voice(route, grunt_left)
	return grunt_left

## The cry of the hunt starting (see CRY_LONGEST), here and on every other
## machine. Returns how long it lasts.
func cry() -> float:
	if level == null: return 0.0
	var choices: Array = []
	for index in GRUNTS.SEGMENTS.size():
		if GRUNTS.SEGMENTS[index][1] >= CRY_LONGEST: choices.append(index)
	var segment := int(choices[rng.randi_range(0, choices.size() - 1)])
	var pitch := rng.randf_range(CRY_PITCH.x, CRY_PITCH.y)
	calls_made += 1
	if "match_net" in level and level.match_net != null: level.match_net.creature_call("cry", segment, pitch)
	play_cry(segment, pitch)
	return GRUNTS.SEGMENTS[segment][1] / pitch

func play_cry(segment: int, pitch: float) -> void:
	if segment < 0 or segment >= GRUNTS.SEGMENTS.size(): return
	var take: Array = GRUNTS.SEGMENTS[segment]
	level.world_audio.play_everywhere(CRY_SOUND, global_position + Vector3.UP * 2.2, CRY_GAIN, take[0], pitch, take[1])

## Its grace, counted where it is driven (here for the machine, in the
## driver for a player hunting): when it runs out, the hunt starts with a cry.
func count_grace(delta: float) -> void:
	if grace <= 0.0: return
	grace = maxf(0.0, grace - delta)
	if grace <= 0.0: cry()

## Whether this machine's survivor is the one being called at.
func aimed_at_local() -> bool:
	if level == null or control == "player" or level.match_net.local_is_locust() or not level.local_alive(): return false
	var me: Node3D = level.player
	if control == "ai": return mode == Mode.CHASE and focus == me
	return global_position.distance_to(me.global_position) < AIMED_REACH and clear_sight(me.camera.global_position)

## The grunt that has just been routed, made the one that is about you.
func aim_voice(route: Dictionary, seconds: float) -> void:
	aimed = aimed_at_local()
	if not aimed: return
	voice.unit_size = AIMED_UNIT
	voice.volume_db += AIMED_GAIN
	if not route.get("echo", false): voice.attenuation_filter_cutoff_hz = maxf(voice.attenuation_filter_cutoff_hz, AIMED_CUTOFF)
	level.world_audio.duck_under(seconds)

## How far the voice carries and how loud it starts, by what it is saying.
## Returns the level to route it at.
func shape_voice(shriek: bool) -> float:
	var shape: Dictionary = VOICE_SHRIEK if shriek else VOICE_GRUNT
	voice.unit_size = shape.unit
	voice.max_distance = shape.reach
	return shape.level

## The chase has a voice, whether the AI or a player is driving: a grunt every
## few seconds while it is after someone. A shriek takes over the throat, and
## a call nobody could hear is retried soon instead of spending the whole wait.
func chase_voice(delta: float) -> void:
	if howl_left > 0.0 or grunt_left > 0.0 or grunt_rest > 0.0: return
	grunt_clock -= delta
	if grunt_clock > 0.0: return
	grunt_rest = GRUNT_MIN
	grunt_clock = rng.randf_range(GRUNT_WAIT.x, GRUNT_WAIT.y) if grunt() > 0.0 else GRUNT_RETRY

## The shriek of a player hunting: it cries for `hold` seconds and fades over
## `fade`, the same curve as the red of its acoustic view, one grunt after
## another. A second howl while one lasts would stretch it; the hunter's own
## cooldown (locust_player.SHRIEK_COOLDOWN, longer than the cry) keeps that
## from happening. `tell` sends it to the other machines, which replay it at
## their own place.
func howl(hold: float, fade: float, tell := true) -> void:
	howl_fade = maxf(fade, 0.05)
	howl_left = maxf(howl_left, hold + howl_fade)
	if tell and "match_net" in level and level.match_net != null: level.match_net.creature_call("howl", int(round(hold * 100.0)), howl_fade)
	howl_next()

## The next grunt of the chain, never the one just heard.
func howl_next() -> void:
	var choices: Array = []
	for index in GRUNTS.SEGMENTS.size():
		if GRUNTS.SEGMENTS[index][1] >= AGGRESSIVE_GRUNT and index != last_grunt: choices.append(index)
	last_grunt = choices[rng.randi_range(0, choices.size() - 1)]
	var segment: Array = GRUNTS.SEGMENTS[last_grunt]
	var pitch := rng.randf_range(0.85, 1.0)
	# Out of earshot it still keeps time, so the chain stays in step.
	grunt_left = segment[1] / pitch
	if level == null or not level.world_audio.enabled: return
	var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
	if not route.audible: return
	level.world_audio.apply_route(voice, route, shape_voice(true), "Threat", true)
	howl_db = voice.volume_db
	voice.pitch_scale = pitch
	voice.play(segment[0])
	update_voice(0.0)

## Stops each grunt where it ends (the file holds them all in a row), chains
## the next one while a shriek lasts, and fades the shriek out at its end.
func update_voice(delta: float) -> void:
	grunt_rest = maxf(0.0, grunt_rest - delta)
	if warn_left > 0.0:
		warn_left -= delta
		if warn_left <= 0.0: signal_player.stop()
	if howl_left > 0.0:
		howl_left -= delta
		if howl_left <= 0.0:
			howl_left = 0.0
			grunt_left = 0.0
			voice.stop()
			return
		voice.volume_db = howl_db + linear_to_db(maxf(clampf(howl_left / howl_fade, 0.0, 1.0), 0.001))
	if grunt_left > 0.0:
		grunt_left -= delta
		if grunt_left <= 0.0:
			if howl_left > 0.2: howl_next()
			else: voice.stop()

func clear_sight(point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, EYE_HEIGHT, 0), point, 1 | 8 | 64)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

## Whether it can see this survivor right now.
func sees(player: Node3D, ignore_concealment := false) -> bool:
	if not is_instance_valid(player) or not level.survivor_active(player): return false
	var offset: Vector3 = player.global_position - global_position
	if offset.length() > sight_range * reach_scale: return false
	# It knows which wardrobe the player went into, doors shut or not.
	if player.hidden and not ignore_concealment and observed_hide == player.hiding_place: return true
	var facing := -global_basis.z
	if offset.length() > 1.5 and facing.dot(offset.normalized()) < cos(deg_to_rad(sight_half_angle)): return false
	if not clear_sight(player.camera.global_position): return false
	# Shut doors block the line above; peeking through a gap is visible.
	if player.hidden and not ignore_concealment: return player.hiding_place.ajar()
	return true

## The survivor it would react to: the one it already follows if still in
## view, otherwise the nearest one it can see. Null when nobody is in view.
func seen_survivor(ignore_concealment := false) -> Node3D:
	if sees(focus, ignore_concealment): return focus
	var best: Node3D = null
	var best_distance := INF
	for player in level.survivors():
		if not sees(player, ignore_concealment): continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best

func sees_player(ignore_concealment := false) -> bool:
	return seen_survivor(ignore_concealment) != null

## Survivor to aim an attack at: the one it hunts, else the nearest one.
func target() -> Node3D:
	if is_instance_valid(focus) and level.survivor_active(focus): return focus
	var best: Node3D = null
	var best_distance := INF
	for player in level.survivors():
		if not level.survivor_active(player): continue
		var distance: float = player.global_position.distance_to(global_position)
		if distance < best_distance:
			best = player
			best_distance = distance
	return best

## How quickly a visible player is noticed: close, lit and running players
## stand out; crouching and distance buy time to break line of sight.
func notice_rate(player: Node3D) -> float:
	var distance: float = player.global_position.distance_to(global_position)
	var rate := lerpf(NOTICE_NEAR, NOTICE_FAR, clampf((distance - 4.0) / (sight_range * reach_scale - 4.0), 0.0, 1.0)) * notice
	if player.crouched: rate *= 0.55
	if Vector2(player.velocity.x, player.velocity.z).length() > 4.6: rate *= 1.35
	if player.torch.visible: rate *= 1.4
	return rate

## The survivor whose torch beam falls on the creature from afar, if any.
func lit_by_torch() -> Node3D:
	for player in level.survivors():
		if not level.survivor_active(player): continue
		var torch: SpotLight3D = player.torch
		if not torch.visible or player.hidden: continue
		var chest := global_position + Vector3(0, 1.6, 0)
		var offset := chest - torch.global_position
		if offset.length() > torch_range * reach_scale or offset.length() < 5.0: continue
		if (-torch.global_basis.z).angle_to(offset) > deg_to_rad(TORCH_NOTICE_ANGLE * 0.85): continue
		var ray := PhysicsRayQueryParameters3D.create(torch.global_position, chest, 1 | 8 | 64)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return player
	return null

## Whether a noise reaches it: within its (long) hearing, along a walkable
## route through rooms and doorways, never through walls.
func can_hear(point: Vector3, radius: float) -> bool:
	return hear_route(point, radius).audible

## How a noise reaches it. With nothing solid in between it comes straight from
## the source. Otherwise it follows the walkable route and arrives through the
## last opening the creature can see, quieter and duller for the detour. This
## is the one measurement of its hearing: can_hear() is this, and the player who
## drives it paints its acoustic image from the same numbers.
##  audible   - it reaches the creature at all
##  apparent  - where it is heard from: the source, or the opening it came in by
##  distance  - straight line when direct, metres of route when it came around
##  muffle    - 0 direct, towards 1 as the detour grows
func hear_route(point: Vector3, radius: float) -> Dictionary:
	var missed := {"audible": false, "apparent": point, "distance": INF, "muffle": 1.0}
	if level.point_protected(point): return missed
	var reach := radius * HEARING_SCALE * hearing * reach_scale * dull
	var straight := global_position.distance_to(point)
	if straight > reach: return missed
	if clear_sight(point + Vector3(0, 1, 0)):
		return {"audible": true, "apparent": point, "distance": straight, "muffle": 0.0}
	var route := FLOOR.navigation_path(get_world_3d().navigation_map, position, point)
	if route.size() < 2: return missed
	# A route that stops short of the noise does not carry it: the mesh gives
	# the way to the nearest point it can reach, and from a scrap of floor cut
	# off from the rest that was where it stood, a noise five metres away
	# heard as if at its feet.
	var end := route[route.size() - 1]
	var near := FLOOR.floor_point(point)
	if Vector2(end.x - near.x, end.z - near.z).length() > 1.5: return missed
	var length := 0.0
	for i in range(1, route.size()): length += route[i].distance_to(route[i - 1])
	if length > reach: return missed
	# Walk the route outwards and keep the last waypoint still in plain sight:
	# that doorway or corner is the direction the sound arrives from.
	var apparent: Vector3 = route[0] + Vector3.UP * 1.5
	for i in range(1, route.size()):
		var probe: Vector3 = route[i] + Vector3.UP * 1.5
		if not clear_sight(probe): break
		apparent = probe
	# Nothing along the route in sight, not even the first turn: the opening
	# it arrives through is right here, and a contact placed on its own head
	# would swallow the camera. Put it a few metres off, the way it comes.
	var start: Vector3 = route[0] + Vector3.UP * 1.5
	if apparent.distance_to(start) < APPARENT_NEAREST:
		var way: Vector3 = route[1] - route[0]
		way.y = 0.0
		if way.length() > 0.01: apparent = start + way.normalized() * APPARENT_NEAREST
	var detour := maxf(0.0, length - global_position.distance_to(apparent))
	return {"audible": true, "apparent": apparent, "distance": length, "muffle": clampf(detour / 25.0, 0.0, 1.0)}

## How far from where it last knew its quarry to be a noise can be and still
## be taken for that quarry, mid-chase.
const CHASE_EARSHOT := 9.0
func hear(point: Vector3, radius: float) -> void:
	if control != "ai": return
	# Holding a victim or pulling a wardrobe open, it finishes what it is doing:
	# a noise used to send it off mid-kill with the victim dragged behind it.
	if grace > 0 or mode in [Mode.WINDUP, Mode.RECOVER, Mode.EXECUTE, Mode.WARDROBE, Mode.LURK]: return
	# Turning its back on a chase it has tired of, it is not called back by
	# the feet it has just given up on.
	if clock < tired_until: return
	if not can_hear(point, radius): return
	# A place it has given long enough: only something loud keeps it there.
	if area_spent > AREA_CAP and search_origin != Vector3.INF and point.distance_to(search_origin) < AREA_SAME and radius * HEARING_SCALE < LOUD: return
	clue()
	var going := point - last_known
	going.y = 0.0
	if going.length() > 1.0: last_heading = going.normalized()
	if mode == Mode.CHASE:
		# While hunting, a noise near the one it is after tells it where they
		# went. Any noise at all used to: two survivors walking about kept a
		# chase alive for ever, bounced between them, after nobody.
		if point.distance_to(last_known) <= CHASE_EARSHOT:
			last_known = point
			lost_time = minf(lost_time, 1.0)
		return
	if mode == Mode.ALERT:
		# Already turning to hunt: the noise only says where. Sending it to
		# investigate restarted the alert, so a survivor who kept walking in
		# sight was never chased -- every step put it back to square one.
		last_known = point
		return
	last_known = point
	set_mode(Mode.INVESTIGATE)
	destination = standing_point(point)

## Sent by the pacing director to go round the rooms within `radius` of
## `point` for `seconds` (once: until it reaches one of them; sniff: and open
## one of their wardrobes). Only on its rounds and only where it drives
## itself; never a refuge, a lift lobby or a room in `avoid`, and only in the
## wing it is in. False when it cannot take the lead.
func lead_to(point: Vector3, radius: float, seconds: float, kind: String, once := false, avoid: Array = [], sniff := false) -> bool:
	if control != "ai" or mode != Mode.PATROL or lift_bound: return false
	var here := FLOOR.room_at(level.manifest.rooms, global_position)
	var wing: int = int(here.get("wing", level.manifest.rooms[patrol_room].get("wing", 0)))
	var planta := FLOOR.planta_of(point.y)
	var shut_out: Array = level.off_limits_rooms()
	var rooms: Array = []
	for room in level.manifest.rooms:
		if FLOOR.is_void(room) or shut_out.has(int(room.id)) or avoid.has(int(room.id)) or int(room.get("wing", -1)) != wing: continue
		var centre := FLOOR.position_of(room)
		if FLOOR.planta_of(centre.y) == planta and centre.distance_to(point) <= maxf(radius, 0.5): rooms.append(int(room.id))
	if rooms.is_empty(): return false
	lead = {"point": point, "radius": radius, "until": clock + seconds, "kind": kind, "rooms": rooms, "once": once, "sniff": sniff}
	sniff_hide = null
	leaving = false
	pause_time = 0.0
	state_time = 0.0
	choose_patrol()
	return true

## On a sniffing lead (a burnt-out mind somewhere about): once in the lead's
## rooms, to one of their wardrobes, drawn -- occupied or not, it does not
## know -- and open it. True while that is what it is doing.
func sniffing() -> bool:
	if not lead_active() or not bool(lead.get("sniff", false)): return false
	if is_instance_valid(sniff_hide):
		destination = sniff_hide.to_global(sniff_hide.exit_offset)
		if pause_time <= 0.0 and global_position.distance_to(destination) < 0.9:
			var hide := sniff_hide
			sniff_hide = null
			lead.sniff = false
			last_known = hide.global_position
			begin_wardrobe(hide)
		return true
	var here := FLOOR.room_at(level.manifest.rooms, global_position)
	if here.is_empty() or not lead.rooms.has(int(here.id)): return false
	var found: Array = []
	for hide in get_tree().get_nodes_in_group("hotel_hides"):
		if lead.rooms.has(int(FLOOR.room_at(level.manifest.rooms, hide.global_position).get("id", -1))): found.append(hide)
	if found.is_empty():
		lead.sniff = false
		return false
	sniff_hide = found[rng.randi_range(0, found.size() - 1)]
	repath = 0
	return true

func lead_active() -> bool:
	return not lead.is_empty() and clock < float(lead.until)

## Put somewhere else at once, having forgotten everybody, with `rest` seconds
## before it moves again. A stage given back after the team fell raises
## everybody at the stage's door, and it used to be left wherever it had last
## killed -- a metre from them, and the stage was lost again in two seconds.
func relocate(point: Vector3, rest: float) -> void:
	global_position = point
	velocity = Vector3.ZERO
	speed = 0.0
	forget_route()
	wardrobe = null
	focus = null
	detection = 0.0
	light_exposure = 0.0
	last_known = point
	var here := FLOOR.room_at(level.manifest.rooms, point)
	if not here.is_empty(): patrol_room = int(here.id)
	set_mode(Mode.PATROL)
	destination = point
	grace = maxf(grace, rest)
	had_quarry = false
	doubting = 0.0

## Nothing of the way it was walking survives being put somewhere else (a
## stage given back, a set it stepped out of): the route, a doorway it was
## half through -- which kept the old route for up to 2.5 s (passing_door) --
## a step aside, and the stuck count of the old place.
func forget_route() -> void:
	path = PackedVector3Array()
	path_index = 0
	crossings = []
	rounds = {}
	passing_time = 0.0
	dodge_left = 0.0
	stuck_clock = 0.0
	stuck_linger = 0.0
	stuck_level = 0
	stuck_origin = Vector3.INF
	linger_goal = Vector3.INF
	linger_best = INF
	repath = 0

## Where it can stand to look at something heard: a set, a drawer or a lamp
## is heard from above the floor, often from against a wall, and 0.7 m from
## that point was a spot it never reached -- it stood beside it the whole
## twelve seconds an investigation lasts.
func standing_point(point: Vector3) -> Vector3:
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0: return point
	return FLOOR.closest(map, point)

## A sound it did not have to hear through the player: something fell, it goes
## to look. Ignored while it is already hunting.
func investigate(point: Vector3) -> void:
	if control != "ai": return
	if mode in [Mode.CHASE, Mode.ALERT, Mode.WINDUP, Mode.RECOVER, Mode.EXECUTE, Mode.WARDROBE, Mode.LURK]: return
	last_known = point
	set_mode(Mode.INVESTIGATE)
	destination = point

func set_mode(next: Mode) -> void:
	var previous := mode
	mode = next
	state_time = 0
	leaving = false
	# Anything that takes it off its rounds ends the director's lead with them.
	if next != Mode.PATROL: lead = {}
	lift_bound = false
	repath = 0
	pause_time = 0
	# Back on its rounds it has forgotten the wardrobe it was looking at: kept,
	# whoever hid there later was "seen" through the walls from across the floor.
	if next == Mode.PATROL: observed_hide = null
	# Whatever it was waiting by a wardrobe for is over with the waiting.
	if next != Mode.LURK:
		lurk = {}
		if next not in [Mode.EXECUTE, Mode.WINDUP]: pouncing = false
	if next in [Mode.ALERT, Mode.CHASE]: had_quarry = true
	if next == Mode.CHASE and previous not in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER]: chase_time = 0.0
	if next == Mode.CHASE and previous != Mode.CHASE:
		# It sets off from a stride and builds up to full speed.
		speed = maxf(speed, chase_start)
		# Coming out of the alert, the next call waits for the first to finish.
		grunt_clock = grunt_left + rng.randf_range(0.8, 1.8) if previous == Mode.ALERT else 0.0
	# Lost them, or found nobody: a search of its own, from where it last knew.
	# Out of a wardrobe it opened on the way, the same search goes on.
	if next == Mode.SEARCH and control == "ai": begin_search(last_known, last_heading, previous != Mode.WARDROBE)
	# Spotting the player: an aggressive grunt as it turns to hunt.
	if next == Mode.ALERT: grunt()
	if next == Mode.WINDUP:
		warn()
		if "match_net" in level and level.match_net != null: level.match_net.creature_call("warning", 0, 1.0)

## The next leg of its rounds (see PATROL_NEAR): among the rooms of its wing
## at a walk's distance, the ones it has not seen for longest, drawn among the
## best few so it is not predictable. On a lead, the lead's rooms whatever the
## distance. Walking off from `away_from` (a place it gave up), the rooms at
## least LEAVE_MIN from there. Never through a gate it cannot open, into a
## refuge -- it would stand at the door and wait -- or into a lift lobby,
## whose only door is the refuge's.
func choose_patrol(away_from := Vector3.INF) -> void:
	var standing := FLOOR.room_at(level.manifest.rooms, global_position)
	var here: int = int(standing.id) if not standing.is_empty() else patrol_room
	var wing: int = int(level.manifest.rooms[here].get("wing", 0))
	var shut_out: Array = level.off_limits_rooms()
	var metres := walk_from(here)
	var in_lead := lead_active()
	var scored: Array = []
	var spare: Array = []
	for key in metres:
		var id := int(key)
		if shut_out.has(id) or (id == here and not in_lead): continue
		var room: Dictionary = level.manifest.rooms[id]
		if FLOOR.is_void(room) or int(room.get("wing", -1)) != wing: continue
		var walk := float(metres[key])
		if in_lead:
			if not lead.rooms.has(id): continue
		elif away_from != Vector3.INF:
			var off := FLOOR.position_of(room).distance_to(away_from)
			if off < LEAVE_MIN or walk > PATROL_FAR * 1.5:
				spare.append([off, id])
				continue
		elif walk < PATROL_NEAR or walk > PATROL_FAR:
			if walk >= 8.0: spare.append([rng.randf(), id])
			continue
		var weight := clampf((clock - float(room_seen.get(id, -INF))) / STALE_FULL, 0.05, 1.0)
		if not in_lead and float(searched_until.get(id, -INF)) > clock: weight *= 0.05
		if recent_rooms.has(id): weight *= 0.3
		if level.manifest.adjacency[id].size() <= 1 and not bool(room.get("corridor", false)): weight *= DEAD_END_PEEK
		scored.append([weight * rng.randf_range(0.7, 1.3), id])
	# A small wing, or nowhere far enough: the best of what there is (for a
	# place given up, the farthest from it).
	if scored.is_empty(): scored = spare
	if scored.is_empty():
		var near: Array = level.manifest.adjacency[here].filter(func(id): return not shut_out.has(int(id)) and int(level.manifest.rooms[id].get("wing", -1)) == wing)
		if near.is_empty(): return
		scored = near.map(func(id): return [rng.randf(), int(id)])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var pick: Array = scored[rng.randi_range(0, mini(4, scored.size() - 1))]
	patrol_room = int(pick[1])
	destination = FLOOR.position_of(level.manifest.rooms[patrol_room])
	patrol_limit = float(metres.get(patrol_room, 30.0)) / 1.4 + 10.0
	repath = 0

## Metres of walking from a room to every room of its planta (kept: the plan
## of the floor does not change under it).
func walk_from(room_id: int) -> Dictionary:
	if not walks.has(room_id): walks[room_id] = FLOOR.route_metres(level.manifest, room_id)
	return walks[room_id]

## Twice a second: the room it stands in, and the rooms next door it can see
## into, count as seen now.
func mark_rooms(delta: float) -> void:
	mark_clock -= delta
	if mark_clock > 0.0: return
	mark_clock = 0.5
	var here := FLOOR.room_at(level.manifest.rooms, global_position)
	if here.is_empty(): return
	var id := int(here.id)
	room_seen[id] = clock
	if recent_rooms.is_empty() or int(recent_rooms[-1]) != id:
		recent_rooms.append(id)
		if recent_rooms.size() > RECENT_ROOMS: recent_rooms.pop_front()
	for other in level.manifest.adjacency[id]:
		var centre := FLOOR.position_of(level.manifest.rooms[int(other)])
		if centre.distance_to(global_position) < 16.0 and clear_sight(centre + Vector3(0, 1.2, 0)): room_seen[int(other)] = clock

## Something to go on: seen, heard, a torch on it. The search starts over.
func clue() -> void:
	clue_idle = 0.0

## A search from `origin` (see GIVE_UP). The same place again (within
## AREA_SAME) keeps the time already given to it; `fresh` false carries on
## with what was left to look at (it opened a wardrobe on the way).
func begin_search(origin: Vector3, heading: Vector3, fresh := true) -> void:
	if search_origin == Vector3.INF or origin.distance_to(search_origin) >= AREA_SAME:
		search_origin = origin
		area_spent = 0.0
	if not fresh and not search_plan.is_empty():
		next_search_point()
		return
	# A new look starts the clock over, unless the place has had its time.
	if area_spent < AREA_CAP: clue_idle = 0.0
	search_plan = plan_search(origin, heading)
	next_search_point()

func next_search_point() -> void:
	search_hide = null
	if search_plan.is_empty():
		destination = global_position
		return
	var item: Dictionary = search_plan.pop_front()
	destination = item.point
	search_hide = item.get("hide")
	repath = 0

## Where to look: the spot itself, the doorway of that room most along the
## way the quarry was going, the room beyond it (and now and then a wardrobe
## in it), and one other room next door. Room middles and doorways, on the
## floor: points round the spot itself snapped to the other side of a wall,
## and it walked round and back for each of them.
func plan_search(origin: Vector3, heading: Vector3) -> Array:
	var map: RID = get_world_3d().navigation_map
	var plan: Array = [{"point": FLOOR.closest(map, origin)}]
	var room := FLOOR.room_at(level.manifest.rooms, origin)
	if room.is_empty(): return plan
	var shut_out: Array = level.off_limits_rooms()
	var ways: Array = []
	for other in level.manifest.adjacency[room.id]:
		var id := int(other)
		var next: Dictionary = level.manifest.rooms[id]
		if shut_out.has(id) or FLOOR.is_void(next) or int(next.get("wing", -1)) != int(room.get("wing", -2)): continue
		var portal := FLOOR.portal_between(room, next)
		var way := portal - origin
		way.y = 0.0
		var score := rng.randf() * 0.5
		if heading.length() > 0.1 and way.length() > 0.1: score += heading.dot(way.normalized())
		ways.append([score, id, portal])
	if ways.is_empty(): return plan
	ways.sort_custom(func(a, b): return a[0] > b[0])
	var beyond: Dictionary = level.manifest.rooms[int(ways[0][1])]
	plan.append({"point": FLOOR.closest(map, ways[0][2])})
	plan.append({"point": FLOOR.closest(map, FLOOR.position_of(beyond))})
	if rng.randf() < peek_chance:
		var hide := wardrobe_in(beyond)
		if hide != null: plan.append({"point": hide.to_global(hide.exit_offset), "hide": hide})
	if ways.size() > 1:
		var aside: Array = ways[rng.randi_range(1, ways.size() - 1)]
		plan.append({"point": FLOOR.closest(map, FLOOR.position_of(level.manifest.rooms[int(aside[1])]))})
	return plan

## One of the wardrobes of a room, drawn; null when it has none.
func wardrobe_in(room: Dictionary) -> Node3D:
	var found: Array = []
	for hide in get_tree().get_nodes_in_group("hotel_hides"):
		if int(FLOOR.room_at(level.manifest.rooms, hide.global_position).get("id", -1)) == int(room.id): found.append(hide)
	return null if found.is_empty() else found[rng.randi_range(0, found.size() - 1)]

## Nothing there: it gives the place up and goes somewhere else (see
## GIVE_UP). Whatever it thought it had seen is forgotten with it.
signal area_abandoned(origin: Vector3, next: Vector3)
func give_up_area() -> void:
	# It had somebody, and has lost them: a low growl says so.
	if had_quarry and lost_cry: frustrated()
	had_quarry = false
	var origin: Vector3 = search_origin if search_origin != Vector3.INF else global_position
	var planta := FLOOR.planta_of(origin.y)
	for room in level.manifest.rooms:
		if FLOOR.is_void(room): continue
		var centre := FLOOR.position_of(room)
		if FLOOR.planta_of(centre.y) == planta and centre.distance_to(origin) <= SEARCHED_RADIUS: searched_until[int(room.id)] = clock + SEARCHED_FOR
	observed_hide = null
	detection = minf(detection, 0.1)
	search_plan.clear()
	search_hide = null
	lead = {}
	patrol_room = nearest_room()
	set_mode(Mode.PATROL)
	leaving = true
	choose_patrol(origin)
	search_origin = Vector3.INF
	area_spent = 0.0
	area_abandoned.emit(origin, destination)

## The first moment it makes somebody out: it stands, looks and chitters.
func start_doubt() -> void:
	doubting = doubt_time
	doubt_rest = clock + DOUBT_REST
	pause_time = maxf(pause_time, doubt_time)
	var which := rng.randi_range(0, CHITTERS.size() - 1)
	var pitch := rng.randf_range(0.9, 1.1)
	if "match_net" in level and level.match_net != null: level.match_net.creature_call("doubt", which, pitch)
	play_doubt(which, pitch)

func play_doubt(which: int, pitch: float) -> void:
	if level == null or not level.world_audio.enabled or which < 0 or which >= CHITTERS.size(): return
	level.world_audio.play_at(CHITTERS[which], global_position + Vector3.UP * 2.2, -4.0, get_rid())

## Tired of running after somebody it can still see: it lets go and goes off
## somewhere else, taking no notice of anybody for the tired_for it takes to
## turn away. Whoever it sees after that, it chases again.
func tire() -> void:
	tired_until = clock + tired_for
	detection = 0.0
	focus = null
	give_up_area()

## The growl of having lost somebody: the shortest of its grunts, low.
func frustrated() -> void:
	var shortest := 0
	for index in GRUNTS.SEGMENTS.size():
		if float(GRUNTS.SEGMENTS[index][1]) < float(GRUNTS.SEGMENTS[shortest][1]): shortest = index
	calls_made += 1
	if "match_net" in level and level.match_net != null: level.match_net.creature_call("lost", shortest, LOST_PITCH)
	play_lost(shortest, LOST_PITCH)

func play_lost(segment: int, pitch: float) -> void:
	if level == null or not level.world_audio.enabled or segment < 0 or segment >= GRUNTS.SEGMENTS.size(): return
	var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
	if not route.audible: return
	level.world_audio.apply_route(voice, route, shape_voice(false), "Threat", true)
	voice.pitch_scale = pitch
	var take: Array = GRUNTS.SEGMENTS[segment]
	voice.play(float(take[0]))
	grunt_left = float(take[1]) / pitch

func can_attack(reach := -1.0) -> bool:
	if reach < 0.0: reach = attack_range
	var player := target()
	if player == null or global_position.distance_to(player.global_position) >= reach: return false
	if not clear_sight(player.camera.global_position): return false
	return not player.hidden or observed_hide == player.hiding_place or sees(player)

## In reach of somebody: the capture starts now (the level stages it and
## takes over both bodies). Refused -- somebody the floor protects, or on
## their way into a lift -- it is left standing a moment before it goes on.
func seize() -> void:
	level.capture_survivor(target())
	if mode != Mode.EXECUTE: set_mode(Mode.RECOVER)

## A wardrobe it has reason to search: occupied and near where the noise was.
func suspect_hide(point: Vector3) -> Node3D:
	for hide in get_tree().get_nodes_in_group("hotel_hides"):
		if is_instance_valid(hide.occupant) and hide.global_position.distance_to(point) < 2.5: return hide
	return null

## Ground speed each behaviour aims for; patrol drifts between slow and brisk.
func desired_speed() -> float:
	if doubting > 0.0: return 0.0
	match mode:
		Mode.PATROL:
			if pause_time > 0: return 0.0
			return LEAVE_PACE if leaving else 1.9 + sin(wander_clock * 0.37) * 0.5 + sin(wander_clock * 1.13) * 0.2
		Mode.INVESTIGATE:
			# Cautious when close to what it heard; loping to a lift.
			return lerpf(1.2, LIFT_PACE if lift_bound else 2.9, clampf((position.distance_to(destination) - 1.5) / 5.0, 0.0, 1.0))
		Mode.CHASE:
			return chase_speed if lost_time < 0.4 or relentless else track_speed
		Mode.SEARCH:
			return 0.0 if pause_time > 0 else 1.5
		Mode.LURK:
			# A step or two aside at a walk; back for whoever shows, at a run.
			match String(lurk.get("phase", "")):
				"aside": return 1.9
				"pounce": return chase_speed
			return 0.0
	return 0.0

func set_control(kind: String) -> void:
	control = kind
	net_states.clear()
	if kind == "player" and driver == null:
		driver = preload("res://game/enemies/locust/locust_player.gd").new()
		add_child(driver)
		driver.setup(self)
	# Only the player who drives it sees through its ears.
	if driver != null and is_instance_valid(driver.echo):
		# Unless the room lets its hunter see like a person.
		if kind == "player" and level.rule("plain_sight") == 0: driver.echo.enable()
		else: driver.echo.disable()

## What the machine in charge sends about fifteen times a second.
func pack_state() -> Array:
	return [global_position, rotation.y, velocity, mode, grace, visual.look_point if is_instance_valid(visual) and "look_point" in visual else Vector3.INF]

## Carried by a lift on this machine: the hunter's own machine still sends
## where it stood by the old car for a moment, and those states would pull it
## back there and slide it across the floor (see remote_player.ride_to).
var ride_hold := 0.0
var ride_point := Vector3.ZERO
func push_state(data: Array) -> void:
	if data.size() < 6: return
	if ride_hold > 0.0:
		if (data[0] as Vector3).distance_to(ride_point) > 3.0: return
		ride_hold = 0.0
	net_states.append({"time": net_clock, "position": data[0], "yaw": data[1], "velocity": data[2]})
	while net_states.size() > 10: net_states.pop_front()
	var next: int = data[3]
	if next != mode:
		mode = next
		state_time = 0.0
	grace = data[4]
	net_look = data[5]

## Puppet: smoothed onto the received states, animated like the real thing.
func follow_state(delta: float) -> void:
	net_clock += delta
	ride_hold = maxf(0.0, ride_hold - delta)
	state_time += delta
	if net_states.is_empty():
		update_visual(delta)
		return
	var wanted := net_clock - 0.1
	var before: Dictionary = net_states[0]
	var after: Dictionary = net_states[net_states.size() - 1]
	for i in range(net_states.size() - 1):
		if net_states[i].time <= wanted and net_states[i + 1].time >= wanted:
			before = net_states[i]
			after = net_states[i + 1]
			break
	var t := clampf((wanted - before.time) / maxf(after.time - before.time, 0.001), 0.0, 1.0)
	global_position = before.position.lerp(after.position, t)
	rotation.y = lerp_angle(before.yaw, after.yaw, t)
	velocity = before.velocity.lerp(after.velocity, t)
	# Holding somebody it is a piece of that scene, on every machine: where the
	# host said it caught them and turned to them, whatever states are still on
	# their way from before.
	if level != null and not level.execution.is_empty():
		global_position = level.execution.point
		rotation.y = float(level.execution.yaw)
		velocity = Vector3.ZERO
	update_voice(delta)
	update_visual(delta)

## It saw somebody get into this wardrobe (or sees them in it): it knows.
func saw_enter(hide: Node3D) -> void:
	observed_hide = hide
	certain = true

# --- The feint (docs/EXECUTION.md, 13.3) -------------------------------------------
#
# Sure of who is in a wardrobe, it does not always open it. Sometimes it
# looks, steps aside and waits: still, facing the doors, without a sound,
# while what tells a survivor it is near (dread_aura, the presence) dies away
# as if it had gone. Whoever trusts that and comes out, comes out in front of
# it; so does whoever opens a leaf far enough to be seen. What it never does
# is fake its feet: it did not walk away, and nobody heard it walk away. The
# way out is to wait: after `feint_wait` it tires and goes, on foot, heard.

## How near the spot in front of a wardrobe it gets before it deals with it.
const WARDROBE_STAND := 0.9
## How long it stands looking at the doors before it steps aside, how long it
## may take over the step, and how long after starting all this what gives it
## away has died down (hushed, the same on every machine).
const LURK_LOOK := Vector2(1.0, 1.4)
const LURK_STEP := 2.5
const LURK_HUSH := 2.4
## A leaf has to stand open this long for it to take it for somebody showing.
const LURK_AJAR := 0.3
## The doors go, and then it has them: the time between.
const POUNCE_BURST := 0.15
## How near the spot in front of the doors it throws them open from, and how
## long it tries to get there before it does it from wherever it is.
const POUNCE_REACH := 0.5
const POUNCE_PATIENCE := 1.5
## How fast it squares itself up in front of a wardrobe it is about to open.
const WARDROBE_SETTLE := 2.4
## The run back to the doors is a burst from standing, whatever a chase of
## the floor's difficulty takes to get going, and it turns on the spot.
const POUNCE_ACCELERATION := 10.0
const POUNCE_TURN := 12.0
## What it is doing by a wardrobe: {hide, who, phase, until, spot, ajar}.
var lurk := {}
## It is going for somebody it waited for (executions.choose_entry).
var pouncing := false
var stood := 0.0

## Whether this is one of the times it waits. Never with somebody else to go
## after in plain view: a feint is for one.
func feints(player: Node3D) -> bool:
	if control != "ai" or feint <= 0.0 or rng.randf() >= feint: return false
	for other in level.survivors():
		if other != player and sees(other): return false
	return true

## A place to wait by a wardrobe, its doors in view: against the wall it
## stands on, to one side of them, where a leaf barely ajar shows nothing of
## it. With no room there (an alcove, a corner, a bed against it): to one
## side in front of them, then straight in front; and with nowhere to step
## to at all, where it is -- before the doors, for whoever opens one to see.
func lurk_spot(hide: Node3D) -> Vector3:
	var map: RID = get_world_3d().navigation_map
	var first := 1.0 if rng.randf() < 0.5 else -1.0
	var front := float(hide.hinge.z)
	var places: Array = []
	for side in [first, -first]: places.append(Vector3(float(side) * (float(hide.width) * 0.5 + 1.5), 0.04, 0.75))
	for side in [first, -first]: places.append(Vector3(float(side) * 1.9, 0.04, front + 2.0))
	places.append(Vector3(0, 0.04, front + 2.5))
	for place in places:
		var wanted: Vector3 = hide.to_global(place)
		var floor_there := FLOOR.closest(map, wanted)
		if Vector2(floor_there.x - wanted.x, floor_there.z - wanted.z).length() > 0.5 or absf(floor_there.y - wanted.y) > 0.5: continue
		if not body_fits(floor_there) or not doors_seen_from(hide, floor_there): continue
		# A step or two away, on foot: with something in between (a chair, a
		# bed's corner) the way round was longer than the time it gives the
		# step, and it was left standing in the middle of the room.
		var way := FLOOR.navigation_path(map, global_position, floor_there)
		var walked := 0.0
		for index in range(1, way.size()): walked += way[index - 1].distance_to(way[index])
		var straight := Vector2(floor_there.x - global_position.x, floor_there.z - global_position.z).length()
		if way.is_empty() or walked > straight * 1.4 + 0.5 or walked > LURK_STEP * 1.9 * 0.8: continue
		return floor_there
	return global_position

func begin_lurk(hide: Node3D, who: Node3D) -> void:
	if not is_instance_valid(hide) or mode in [Mode.WARDROBE, Mode.EXECUTE]: return
	set_mode(Mode.LURK)
	lurk = {"hide": hide, "who": who, "phase": "look", "until": clock + rng.randf_range(LURK_LOOK.x, LURK_LOOK.y), "spot": lurk_spot(hide), "ajar": 0.0}
	speed = 0.0
	velocity = Vector3.ZERO
	# It lets them know it is there, once: a click of the tongue at the doors.
	var which := rng.randi_range(0, CHITTERS.size() - 1)
	var pitch := rng.randf_range(0.9, 1.05)
	if "match_net" in level and level.match_net != null: level.match_net.creature_call("doubt", which, pitch)
	play_doubt(which, pitch)

## Whether what tells of it is dying away: the same on every machine, from
## how long it has been at it.
func hushed() -> bool:
	return mode == Mode.LURK and state_time >= LURK_HUSH and String(lurk.get("phase", "wait")) != "pounce"

func update_lurk(delta: float) -> void:
	var hide: Node3D = lurk.get("hide")
	var who: Node3D = lurk.get("who")
	if not is_instance_valid(hide) or not is_instance_valid(who) or not level.survivor_active(who):
		set_mode(Mode.SEARCH)
		return
	var phase := String(lurk.phase)
	if phase == "pounce":
		pounce(delta, hide, who)
		return
	# Somebody else walks into view: the one in the wardrobe can wait.
	for other in level.survivors():
		if other == who or not sees(other): continue
		focus = other
		last_known = other.global_position
		detection = 1.0
		set_mode(Mode.ALERT)
		return
	# Out of the wardrobe: that is what it was waiting for, and they are a
	# step away.
	if not who.hidden or who.hiding_place != hide:
		focus = who
		# Where they step out to: still inside the wardrobe for a moment,
		# the nearest floor to them could be the room behind its wall.
		last_known = hide.to_global(hide.exit_of(who))
		detection = 1.5
		lost_time = 0.0
		set_mode(Mode.CHASE)
		return
	# A leaf standing open is somebody showing themselves: it goes in for them.
	lurk.ajar = float(lurk.ajar) + delta if hide.ajar() and doors_seen_from(hide, global_position) else 0.0
	if float(lurk.ajar) >= LURK_AJAR:
		lurk.phase = "pounce"
		lurk.until = -1.0
		lurk.since = clock
		pouncing = true
		destination = hide.to_global(hide.exit_offset)
		repath = 0.0
		return
	match phase:
		"look":
			face_toward(hide.global_position, delta, 6.0)
			if clock >= float(lurk.until):
				lurk.phase = "aside"
				lurk.until = clock + LURK_STEP
				destination = lurk.spot
				repath = 0.0
		"aside":
			# On the floor: the spot is a point of the mesh, which lies over it.
			var short := Vector2(lurk.spot.x - global_position.x, lurk.spot.z - global_position.z).length()
			if short < 0.35 or clock >= float(lurk.until):
				lurk.phase = "wait"
				lurk.until = clock + rng.randf_range(feint_wait.x, feint_wait.y)
				destination = global_position
		"wait":
			face_toward(hide.global_position, delta, 3.0)
			# Nobody came out. It is not sure any more, and it goes -- on its
			# feet, heard, a long way (give_up_area).
			if clock >= float(lurk.until):
				observed_hide = null
				focus = null
				detection = 0.0
				search_origin = hide.global_position
				give_up_area()

## Whether the doors of a wardrobe are in view from a spot on the floor. An
## open leaf does not count against it (the leaf is what it sees): from
## beside the wardrobe, the one on its side stood between it and any point
## behind the doors, and a leaf opened in its face told it nothing.
func doors_seen_from(hide: Node3D, from: Vector3) -> bool:
	var front: Vector3 = hide.to_global(Vector3(0, 1.3, float(hide.hinge.z) + 0.1))
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3(0, EYE_HEIGHT, 0), front, 1 | 8)
	ray.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

## Squarely in front of a wardrobe's doors, a step back from where its leaves
## swing: where it opens one from and takes whoever is in it. It reaches a
## wardrobe from wherever the room lets it, and what it stopped at was any
## spot within a pace of this one: beside the doors, a leaf opened through it
## and it took its victim through that leaf.
func settle_before(hide: Node3D, delta: float, pace := WARDROBE_SETTLE) -> void:
	var spot: Vector3 = hide.to_global(hide.exit_offset)
	var off := Vector3(spot.x - global_position.x, 0.0, spot.z - global_position.z)
	var most := pace * delta
	var step := off if off.length() <= most else off.normalized() * most
	speed = 0.0
	velocity = Vector3(step.x / maxf(delta, 0.001), -2.0, step.z / maxf(delta, 0.001))
	move_and_slide()

## Back to the doors at a run; they burst open, and a moment later it has
## whoever is behind them -- or is after them, if they got out in time.
func pounce(_delta: float, hide: Node3D, who: Node3D) -> void:
	destination = hide.to_global(hide.exit_offset)
	if float(lurk.until) < 0.0:
		# In front of them first: thrown open from one side, the leaf on that
		# side swung into it.
		if global_position.distance_to(destination) > POUNCE_REACH and clock - float(lurk.get("since", clock)) < POUNCE_PATIENCE: return
		level.burst_wardrobe(hide)
		lurk.until = clock + POUNCE_BURST
		return
	if clock < float(lurk.until): return
	if who.hidden and who.hiding_place == hide and global_position.distance_to(hide.global_position) < 3.4:
		level.capture_survivor(who)
		if mode == Mode.EXECUTE: return
	focus = who
	last_known = who.global_position
	detection = 1.5
	lost_time = 0.0
	set_mode(Mode.CHASE)

## Plants itself in front of a wardrobe and searches it, which takes a while.
func begin_wardrobe(hide: Node3D) -> void:
	if not is_instance_valid(hide) or mode in [Mode.WARDROBE, Mode.EXECUTE]: return
	wardrobe = hide
	set_mode(Mode.WARDROBE)
	speed = 0.0
	if control == "ai": level.open_wardrobe(hide)

## Standing still while the ritual plays out; the leaves and whoever is inside
## are handled by the host (level.open_wardrobe).
func update_wardrobe(delta: float) -> void:
	speed = 0.0
	# It plants itself in front of the doors (settle_before) while it looks
	# at them; elsewhere it is put where whoever moves it says.
	if is_instance_valid(wardrobe) and control != "puppet": settle_before(wardrobe, delta)
	else:
		velocity = Vector3(0, -2.0, 0)
		move_and_slide()
	if is_instance_valid(wardrobe): face_toward(wardrobe.global_position, delta, 7.0)
	if state_time >= float(WARDROBE_TIME.done) * wardrobe_scale and control != "puppet":
		wardrobe = null
		set_mode(Mode.SEARCH if control == "ai" else Mode.PATROL)

## Holding a victim up and stabbing: it cannot move or turn away.
func begin_execution() -> void:
	set_mode(Mode.EXECUTE)
	speed = 0.0

func update_execution(delta: float) -> void:
	speed = 0.0
	velocity = Vector3(0, -2.0, 0)
	move_and_slide()
	# Once the level has let the body fall and counted the death (it holds the
	# victim 0.3 s past EXECUTION_TIME): let go earlier, it saw its still
	# living victim and roared at the corpse.
	if state_time >= EXECUTION_TIME + 0.35 and control != "puppet":
		if control == "ai":
			# Done with that one. What it half noticed of the others while it
			# held it is gone too: it used to turn from the body already
			# certain of the next one in view, and a team fell one after
			# another in the same room.
			detection = 0.0
			focus = null
			last_known = global_position
			last_heading = Vector3.ZERO
		set_mode(Mode.SEARCH if control == "ai" else Mode.PATROL)

## A call decided where the creature is controlled, replayed here.
func play_call(kind: String, segment: int, pitch: float) -> void:
	calls_heard += 1
	last_call = kind
	if kind == "warning":
		warn()
		return
	if kind == "howl":
		howl(segment / 100.0, pitch, false)
		return
	if kind == "cry":
		play_cry(segment, pitch)
		return
	if kind == "doubt":
		play_doubt(segment, pitch)
		return
	if kind == "lost":
		play_lost(segment, pitch)
		return
	if kind != "grunt" or segment < 0 or segment >= GRUNTS.SEGMENTS.size() or not level.world_audio.enabled: return
	var route: Dictionary = level.world_audio.route_source(global_position + Vector3.UP * 2.2, get_rid())
	if not route.audible: return
	level.world_audio.apply_route(voice, route, shape_voice(false), "Threat", true)
	voice.pitch_scale = pitch
	voice.play(GRUNTS.SEGMENTS[segment][0])
	grunt_left = GRUNTS.SEGMENTS[segment][1] / pitch
	aim_voice(route, grunt_left)

func _physics_process(delta: float) -> void:
	# Between stages, and on an online end screen, the voice still counts
	# down: left alone, a grunt ran on through the rest of its recording.
	if level.session.state != level.session.State.PLAYING:
		update_voice(delta)
		return
	if control == "puppet":
		follow_state(delta)
		return
	if control == "player":
		if is_instance_valid(driver): driver.drive(delta)
		update_voice(delta)
		return
	count_grace(delta)
	state_time += delta
	wander_clock += delta
	clock += delta
	if grace > 0:
		update_visual(delta)
		return
	mark_rooms(delta)
	var seen := noticed_survivor(delta)
	var visible_player := seen != null
	if visible_player:
		# Which way they were going, for the search if it loses them.
		var going: Vector3 = seen.velocity if "velocity" in seen else Vector3.ZERO
		going.y = 0.0
		if going.length() < 0.5:
			going = seen.global_position - last_known
			going.y = 0.0
		if going.length() > 0.3: last_heading = going.normalized()
		clue()
		focus = seen
		var before := detection
		detection = minf(1.5, detection + delta * notice_rate(seen))
		if doubt_time > 0.0 and before < DOUBT_FROM and detection >= DOUBT_FROM and mode in [Mode.PATROL, Mode.SEARCH, Mode.INVESTIGATE] and clock >= doubt_rest: start_doubt()
		if doubting > 0.0: detection = minf(detection, DOUBT_CAP)
		last_known = seen.global_position
		lost_time = 0
		# Finding them again after losing them is worth its own call.
		if mode == Mode.CHASE and sight_gap >= GRUNT_REGAIN: grunt_clock = 0.0
		sight_gap = 0.0
	else:
		detection = maxf(0.0, detection - delta * NOTICE_DECAY)
		lost_time += delta
		sight_gap += delta
	# Tired of a chase: for a while it takes no notice of anybody.
	if clock < tired_until: detection = minf(detection, SUSPICION * 0.9)
	# Standing there making somebody out, it turns to face them: left facing
	# the way it had been walking, eyes that see less to either side lost
	# them while it stared.
	if doubting > 0.0 and visible_player: face_toward(last_known, delta, 5.0)
	doubting = maxf(0.0, doubting - delta)
	if mode in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER]:
		chase_time += delta
		if chase_tire > 0.0 and chase_time >= chase_tire and mode == Mode.CHASE:
			tire()
			return
	# Only a player it can currently see starts a chase; memory alone does not.
	# Busy modes are left out on purpose: holding a victim or pulling a
	# wardrobe open, it used to re-alert on the very next frame -- it can see
	# the person it is already killing -- and walk out of its own execution.
	if visible_player and detection >= 1.0 and mode not in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER, Mode.ALERT, Mode.EXECUTE, Mode.WARDROBE, Mode.LURK]:
		set_mode(Mode.ALERT)
	elif visible_player and detection >= SUSPICION and mode in [Mode.PATROL, Mode.SEARCH]:
		# Something moved: stop wandering and go look, before committing.
		set_mode(Mode.INVESTIGATE)
		destination = last_known
	# A torch beam seen from afar gives away where the player is standing.
	var lit_by := lit_by_torch()
	light_exposure = light_exposure + delta if lit_by != null else maxf(0.0, light_exposure - delta * 0.5)
	if light_exposure > 0.35 and mode in [Mode.PATROL, Mode.SEARCH, Mode.INVESTIGATE] and lit_by != null:
		clue()
		focus = lit_by
		last_known = lit_by.global_position
		if mode != Mode.INVESTIGATE or destination.distance_to(last_known) > 2.0:
			set_mode(Mode.INVESTIGATE)
			destination = last_known
		detection = maxf(detection, 0.3)
	pause_time = maxf(0.0, pause_time - delta)
	# The time it gives a place: looking and going to look, not hunting.
	if mode in [Mode.INVESTIGATE, Mode.SEARCH] and search_origin != Vector3.INF: area_spent += delta
	match mode:
		Mode.PATROL:
			if sniffing(): pass
			elif pause_time <= 0 and (position.distance_to(destination) < 0.6 or state_time > patrol_limit):
				var arrived := position.distance_to(destination) < 0.6
				leaving = false
				if arrived and lead_active() and bool(lead.get("once", false)): lead = {}
				# It stands and looks round a room it has walked to.
				if arrived: pause_time = rng.randf_range(SCAN_TIME.x, SCAN_TIME.y)
				choose_patrol()
				state_time = 0
		Mode.INVESTIGATE:
			if position.distance_to(destination) < 0.7 or state_time > 12:
				# Someone hiding right where the noise came from is found.
				var suspect := suspect_hide(destination) if guess_hides else null
				if suspect != null:
					observed_hide = suspect
					last_known = suspect.global_position
					lost_time = 0.0
					set_mode(Mode.CHASE)
				else:
					set_mode(Mode.SEARCH)
					pause_time = rng.randf_range(0.6, 1.4)
		Mode.CHASE:
			destination = last_known
			var player := focus
			# Reaching where it last saw or heard the player, it checks the wardrobes there.
			if lost_time > 0.5 and observed_hide == null and global_position.distance_to(last_known) < 2.5:
				observed_hide = suspect_hide(last_known) if guess_hides else null
			if is_instance_valid(player) and player.hidden and observed_hide == player.hiding_place:
				# Goes to the wardrobe and pulls the doors open -- or, sure of
				# who is in it, now and then waits for them to come out.
				destination = observed_hide.to_global(observed_hide.exit_offset)
				var short := global_position.distance_to(destination)
				stood = stood + delta if short < 2.0 and speed < 0.4 else 0.0
				# Right in front of it; from further off only if it cannot get nearer.
				if short < WARDROBE_STAND or stood > 0.7:
					stood = 0.0
					if certain and feints(player): begin_lurk(observed_hide, player)
					else: begin_wardrobe(observed_hide)
			else: stood = 0.0
			chase_voice(delta)
			if not is_instance_valid(player) or not level.survivor_active(player) or lost_time > lose_after: set_mode(Mode.SEARCH)
			elif can_attack(): seize()
		Mode.SEARCH:
			clue_idle += delta
			if (search_plan.is_empty() and clue_idle >= give_up) or clue_idle >= give_up_hard:
				give_up_area()
			elif pause_time <= 0 and position.distance_to(destination) < 0.7:
				if is_instance_valid(search_hide):
					var hide := search_hide
					search_hide = null
					begin_wardrobe(hide)
				elif not search_plan.is_empty():
					next_search_point()
					pause_time = rng.randf_range(0.6, 1.4)
				else: pause_time = 1.0
		Mode.WINDUP:
			# The lunge is a player's (locust_player.gd): left in the middle of
			# one, it goes on with the hunt.
			set_mode(Mode.CHASE)
		Mode.RECOVER:
			if state_time >= recover_time: set_mode(Mode.CHASE if visible_player else Mode.SEARCH)
		Mode.ALERT:
			# Even if the player ducks out of view it heads for where it saw them.
			if state_time >= alert_time: set_mode(Mode.CHASE)
		Mode.LURK:
			update_lurk(delta)
	# Whoever it makes out inside a wardrobe -- through a leaf left ajar -- it
	# is as sure of as of somebody it saw get in.
	if visible_player and detection >= 1.0 and bool(seen.hidden) and is_instance_valid(seen.hiding_place) and seen.hiding_place.ajar() and clear_sight(seen.camera.global_position): saw_enter(seen.hiding_place)
	update_voice(delta)
	if mode == Mode.WARDROBE:
		update_wardrobe(delta)
	elif mode == Mode.EXECUTE:
		update_execution(delta)
	elif mode == Mode.ALERT:
		speed = move_toward(speed, 0.0, 12.0 * delta)
		velocity = Vector3(-global_basis.z.x * speed, -2.0, -global_basis.z.z * speed)
		move_and_slide()
		face_toward(last_known, delta, 5.0)
	elif mode == Mode.RECOVER:
		velocity = Vector3.ZERO
		speed = 0.0
		if is_instance_valid(focus): face_toward(focus.global_position, delta, 6.0)
	elif mode == Mode.LURK and String(lurk.get("phase", "")) in ["look", "wait"]:
		# Still: a step now would be heard, and that is the one thing it
		# does not fake.
		speed = 0.0
		velocity = Vector3(0, -2.0, 0)
		move_and_slide()
	elif mode == Mode.LURK and String(lurk.get("phase", "")) == "pounce" and float(lurk.get("until", -1.0)) >= 0.0 and is_instance_valid(lurk.get("hide")):
		# The doors are going: the last of the way, and round to face them.
		settle_before(lurk.hide, delta, chase_speed)
		face_toward((lurk.hide as Node3D).global_position, delta, 14.0)
	else:
		move_on_path(delta)
	update_visual(delta)

func face_toward(point: Vector3, delta: float, rate: float) -> void:
	var offset := point - global_position
	if Vector2(offset.x, offset.z).length() < 0.05: return
	rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), minf(1.0, delta * rate))

func update_visual(delta: float) -> void:
	if not is_instance_valid(visual) or not "move_velocity" in visual: return
	if control == "puppet":
		visual.move_velocity = velocity
		visual.execute = clampf(state_time / EXECUTION_TIME, 0.0, 1.0) if mode == Mode.EXECUTE else 0.0
		visual.searching = clampf(state_time / (float(WARDROBE_TIME.done) * wardrobe_scale), 0.0, 1.0) if mode == Mode.WARDROBE else 0.0
		visual.aggression = move_toward(visual.aggression, 1.0 if mode in [Mode.CHASE, Mode.ALERT, Mode.EXECUTE] else 0.0, delta * 2.5)
		visual.attack = clampf(state_time / WINDUP_TIME, 0.0, 1.0) if mode == Mode.WINDUP else move_toward(visual.attack, 0.0, delta * 8.0)
		visual.recovering = 1.0 if mode == Mode.RECOVER and state_time < 0.5 else move_toward(visual.recovering, 0.0, delta * 2.0)
		visual.duck = move_toward(visual.duck, 1.0 if near_doorway() else 0.0, delta * 3.0)
		visual.look_point = net_look
		return
	visual.move_velocity = velocity
	visual.execute = clampf(state_time / EXECUTION_TIME, 0.0, 1.0) if mode == Mode.EXECUTE else 0.0
	visual.searching = clampf(state_time / (float(WARDROBE_TIME.done) * wardrobe_scale), 0.0, 1.0) if mode == Mode.WARDROBE else 0.0
	visual.aggression = move_toward(visual.aggression, 1.0 if mode in [Mode.CHASE, Mode.ALERT, Mode.EXECUTE] else 0.0, delta * 2.5)
	visual.attack = clampf(state_time / WINDUP_TIME, 0.0, 1.0) if mode == Mode.WINDUP else move_toward(visual.attack, 0.0, delta * 8.0)
	# Stoops under door lintels; it is taller than the doorways.
	visual.duck = move_toward(visual.duck, 1.0 if near_doorway() else 0.0, delta * 3.0)
	visual.recovering = 1.0 if mode == Mode.RECOVER and state_time < 0.5 else move_toward(visual.recovering, 0.0, delta * 2.0)
	var player := focus
	# During an execution it stares at the face it is bringing in to its own.
	if mode == Mode.WARDROBE and is_instance_valid(wardrobe):
		# Its face goes to the gap between the leaves before its arms do.
		visual.look_point = wardrobe.to_global(Vector3(0, 1.45, float(wardrobe.hinge.z) - 0.25))
	elif mode == Mode.LURK and lurk.has("hide") and is_instance_valid(lurk.hide):
		visual.look_point = (lurk.hide as Node3D).to_global(Vector3(0, 1.45, float(lurk.hide.hinge.z)))
	elif (mode in [Mode.CHASE, Mode.WINDUP, Mode.RECOVER, Mode.ALERT, Mode.EXECUTE] or detection > 0.2 or light_exposure > 0.2 or doubting > 0.0) and is_instance_valid(player):
		visual.look_point = player.camera.global_position if lost_time < 0.5 else last_known + Vector3.UP * 1.5
	elif mode in [Mode.SEARCH, Mode.PATROL] and pause_time > 0:
		# Scans the room while standing still.
		visual.look_point = global_position - global_basis.z * 4.0 + global_basis.x * sin(wander_clock * 0.9) * 4.0 + Vector3.UP * 1.6
	else:
		visual.look_point = Vector3.INF

func near_doorway() -> bool:
	for door in level.hotel.doors:
		if door.doorway.distance_to(global_position) < 2.6: return true
	return false

func nearest_room() -> int:
	# The room it stands in, when it stands in one; otherwise the nearest on its
	# own planta. By distance alone the room under its feet on the planta below
	# could be nearer than the middle of a big room it is in.
	var here: Dictionary = FLOOR.room_at(level.manifest.rooms, global_position)
	if not here.is_empty() and here.id != level.manifest.exit: return int(here.id)
	var best := 0
	var distance := INF
	var planta := FLOOR.planta_of(global_position.y)
	for room in level.manifest.rooms:
		if room.id == level.manifest.exit or FLOOR.is_void(room): continue
		if FLOOR.planta_of(FLOOR.position_of(room).y) != planta: continue
		var d := position.distance_squared_to(FLOOR.position_of(room))
		if d < distance:
			distance = d
			best = room.id
	return best

## The doorways on its route and where it lines up with each and comes out of
## it: {door, enter, exit}, indices into `path` (door_threading.thread).
var crossings: Array = []
## The points of the route that go round an open leaf: reached, never cut.
## Taken as passed from a metre off, the corner it cut took it through the
## end of the leaf.
var rounds := {}
## How long it has been between lining up with a doorway and coming out.
var passing_time := 0.0
## A point of the route counts as reached this close to it, or once walked
## past: exactly on it (the six centimetres it used to be) was a target it
## could slide round against a corner for as long as the mode lasted.
const REACHED := 0.3
## Longest it keeps to a doorway it has started through before it lets a new
## route take over anyway.
const PASSING_MOST := 2.5

func move_on_path(delta: float) -> void:
	repath -= delta
	passing_time = passing_time + delta if passing_door() else 0.0
	if passing_time > PASSING_MOST: crossings = []
	# Half way through a doorway it finishes going through before it looks for
	# a new way: a route found from inside the frame lined it up again from
	# wherever it stood, back towards the leaf.
	if repath <= 0 and not passing_door():
		var map: RID = get_world_3d().navigation_map
		var raw := FLOOR.navigation_path(map, position, destination)
		var threaded: Dictionary = THREAD.thread(raw, level.hotel.doors, map)
		path = threaded.path
		crossings = threaded.crossings
		rounds.clear()
		for index in threaded.get("rounds", []): rounds[int(index)] = true
		path_index = 0
		repath = 0.45
		# Nowhere it can walk to (the way is another wing's, or behind a
		# locked door): it used to walk to the nearest wall and stand there
		# until the mode ran out. It gives up where it is instead.
		if not raw.is_empty() and raw[raw.size() - 1].distance_to(destination) > UNREACHABLE: give_up_route()
	advance_path()
	var direction := Vector3.ZERO
	if path_index < path.size():
		direction = path[path_index] - position
		direction.y = 0
		direction = direction.normalized()
	# Stepping round whatever it was pressed against (see watch_progress): for
	# as long as the step lasts, that is where it is going.
	if dodge_left > 0.0:
		dodge_left -= delta
		if direction.length() > 0.1 or dodge_left > 0.0: direction = dodge
	# The refuge is excluded even when the shortest path would cross it.
	if level.point_in_refuge(position + direction * 0.8):
		patrol_room = nearest_room()
		set_mode(Mode.PATROL)
		choose_patrol()
		direction = Vector3.ZERO
	# The door its route goes through, never one it merely passes: in a
	# corridor every door along it was near enough to stop for. Hunting, it
	# slams it open; otherwise it eases it and waits.
	var hunting := mode == Mode.CHASE
	var at_door := false
	var ahead = door_ahead()
	if ahead != null and Vector2(ahead.doorway.x - position.x, ahead.doorway.z - position.z).length() < (2.4 if hunting else 1.8):
		if ahead.locked:
			# A lock on its way: the mesh does not know doors and goes through,
			# but there is no way on here. A chase stands and loses the scent.
			if not hunting: give_up_route()
			direction = Vector3.ZERO
		else:
			if not ahead.moving: ahead.toggle(not hunting, false, hunting)
			direction = Vector3.ZERO
			at_door = true
	# Waiting at a door it stops there, instead of coasting on through the
	# leaf for the two metres it takes to brake.
	if at_door: speed = 0.0
	var wanted := desired_speed() if direction.length() > 0.1 else 0.0
	# Sharp turns cost speed: it has to swing its stilt legs around.
	if direction.length() > 0.1:
		wanted *= lerpf(0.35, 1.0, clampf((-global_basis.z).dot(direction) * 0.5 + 0.5, 0.0, 1.0))
	var bursting := mode == Mode.LURK and pouncing
	var acceleration := POUNCE_ACCELERATION if bursting else chase_accel if mode == Mode.CHASE else 3.5
	speed = move_toward(speed, wanted, (acceleration if wanted > speed else 9.0) * delta)
	var heading := direction if direction.length() > 0.1 else -global_basis.z
	velocity.x = heading.x * speed
	velocity.z = heading.z * speed
	velocity.y = -2 if is_on_floor() else velocity.y - 20 * delta
	if direction.length() > 0.1: rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1, delta * (POUNCE_TURN if bursting else 8.0 if mode == Mode.CHASE else 4.5)))
	move_and_slide()
	watch_progress(delta, direction, 0.0 if at_door else wanted)

## On to the next point of the route once this one is reached, or walked past.
func advance_path() -> void:
	while path_index < path.size():
		var point: Vector3 = path[path_index]
		var gap := Vector2(point.x - position.x, point.z - position.z)
		if gap.length() < REACHED:
			path_index += 1
			continue
		# Past it: further on than the point, along the stretch leading to it.
		if path_index > 0 and gap.length() < 1.0 and not rounds.has(path_index):
			var stretch: Vector3 = point - path[path_index - 1]
			if Vector2(stretch.x, stretch.z).dot(-gap) > 0.0:
				path_index += 1
				continue
		break

## Between lining up with a doorway and coming out past its leaf.
func passing_door() -> bool:
	for crossing in crossings:
		var leave := int(crossing.exit)
		if leave >= 0 and path_index > int(crossing.enter) and path_index <= leave: return true
	return false

## The first door of its route still to go through that is not simply open:
## shut, locked, or swinging. Null while the way is clear.
func door_ahead():
	for crossing in crossings:
		var leave := int(crossing.exit)
		if leave < 0 or leave < path_index: continue
		var door = crossing.door
		if not is_instance_valid(door) or (door.opened and not door.moving): continue
		return door
	return null

## No way on from here: behind a locked door, or so jammed that the steps
## below ran out. What it does instead depends on what it was at; a chase is
## never dropped, it only looks for its way again. Said to whoever watches
## (the test bots' watchdog): many in a row is a creature shut in somewhere.
signal route_abandoned(where: Vector3)
func give_up_route() -> void:
	route_abandoned.emit(global_position)
	crossings = []
	repath = 0.0
	match mode:
		Mode.INVESTIGATE: set_mode(Mode.SEARCH)
		Mode.PATROL:
			patrol_room = nearest_room()
			choose_patrol()
		Mode.SEARCH:
			if search_plan.is_empty(): give_up_area()
			else: next_search_point()

## How far short of where it was going a route may end and still count as
## going there: past this there is no way, and it stops trying.
const UNREACHABLE := 2.5
## Stuck: meaning to move and not getting anywhere. It used to step aside and
## take the same route again, straight back into whatever had stopped it,
## round and round for as long as the mode lasted -- the creature pressed into
## an open leaf that every playtest found. Now each time it is still stuck it
## goes one step further, and every step is written down (stuck_counts and the
## observer's log):
##   1  a step to whichever side has room
##   2  back off, and find the way again from there
##   3  open a shut door at hand; with none, a detour to open floor near by
##   4  another destination (a chase is kept: it only looks for the way again)
##   5  the last resort, and only where nobody is looking: a hop of up to two
##      metres along its own route
## Seconds without moving STUCK_GAIN before each next step.
const STUCK_STEPS := [0.6, 0.9, 1.5, 2.0, 3.0]
const STUCK_GAIN := 0.3
## Getting no nearer the end of its route is stuck too, whatever it does on
## the way: this long wanting to move without the route left to walk getting
## LINGER_GAIN shorter is another step. Rocking back and forth moves it more
## than STUCK_GAIN each swing, so the clock above never sees it (a route bent
## back and forth under a door on the planta above kept it at it for good);
## and it is not how far it wanders that tells, since going round a leaf is
## a few metres there and back in the same corner. Further than STUCK_FREE
## from where it got stuck, it is over.
const STUCK_LINGER := 5.0
const LINGER_GAIN := 0.5
const STUCK_FREE := 2.5
## How long a step aside lasts, and backing off.
const DODGE_TIME := 0.5
const BACK_TIME := 0.6
## The longest hop, and how near a shut door it may not land.
const HOP := 2.0
var dodge := Vector3.ZERO
var dodge_left := 0.0
var stuck_clock := 0.0
var stuck_linger := 0.0
var stuck_level := 0
var stuck_anchor := Vector3.ZERO
var stuck_origin := Vector3.INF
## Where the route it is measured on goes, and the least it has had left to
## walk of it.
var linger_goal := Vector3.INF
var linger_best := INF
## Which way it stepped last time, so when both sides look alike a second
## attempt tries the other one instead of rocking against the same edge.
var stuck_side := 1.0
## How many times each step (1 to 5) was reached this floor.
var stuck_counts := [0, 0, 0, 0, 0, 0]
signal stuck_escalated(step: int, where: Vector3)

func watch_progress(delta: float, direction: Vector3, wanted: float) -> void:
	if stuck_origin != Vector3.INF and position.distance_to(stuck_origin) > STUCK_FREE:
		stuck_level = 0
		stuck_origin = Vector3.INF
		stuck_linger = 0.0
	# Standing to listen, waiting at a door, or already stepping round: not
	# stuck, and nothing counts.
	if direction.length() < 0.1 or wanted < 0.05 or dodge_left > 0.0:
		stuck_clock = 0.0
		stuck_anchor = position
		return
	# A long frame is not a long time stuck: one hitch (or a test stepping it
	# seven seconds at once) counted whole took it straight to backing off.
	var step := minf(delta, 0.1)
	if position.distance_to(stuck_anchor) >= STUCK_GAIN:
		stuck_anchor = position
		stuck_clock = 0.0
	else: stuck_clock += step
	var left := route_left()
	if destination.distance_to(linger_goal) > 1.0 or left < linger_best - LINGER_GAIN:
		linger_goal = destination
		linger_best = left
		stuck_linger = 0.0
	else: stuck_linger += step
	if stuck_clock >= float(STUCK_STEPS[mini(stuck_level, STUCK_STEPS.size() - 1)]) or stuck_linger >= STUCK_LINGER: escalate(direction)

## How far it still has to go along its route, from where it stands.
func route_left() -> float:
	if path_index >= path.size(): return 0.0
	var left := Vector2(path[path_index].x - position.x, path[path_index].z - position.z).length()
	for index in range(path_index + 1, path.size()):
		left += Vector2(path[index].x - path[index - 1].x, path[index].z - path[index - 1].z).length()
	return left

func escalate(direction: Vector3) -> void:
	stuck_level = mini(stuck_level + 1, 5)
	stuck_counts[stuck_level] += 1
	if stuck_origin == Vector3.INF: stuck_origin = position
	stuck_clock = 0.0
	stuck_linger = 0.0
	stuck_anchor = position
	stuck_escalated.emit(stuck_level, global_position)
	var view = level.get("observer_view") if level != null else null
	if view != null and is_instance_valid(view): view.note("atasco · paso %d · %0.0f, %0.0f · %s" % [stuck_level, position.x, position.z, Mode.keys()[mode]])
	match stuck_level:
		1:
			dodge = (free_side(direction) + direction * 0.45).normalized()
			dodge_left = DODGE_TIME
		2:
			dodge = -direction
			dodge_left = BACK_TIME
			crossings = []
			repath = BACK_TIME
		3:
			var door = shut_door_at_hand()
			if door != null: door.toggle(mode != Mode.CHASE, false, mode == Mode.CHASE)
			else: detour(direction)
		4:
			if mode == Mode.CHASE:
				crossings = []
				repath = 0.0
			else: give_up_route()
		_:
			hop()
			stuck_level = 0
			stuck_origin = Vector3.INF

## The side with more room before a wall or a shut leaf; when there is no
## telling them apart, the other side from last time.
func free_side(direction: Vector3) -> Vector3:
	var right := Vector3(-direction.z, 0, direction.x)
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP
	var room := {}
	for side in [1.0, -1.0]:
		var query := PhysicsRayQueryParameters3D.create(from, from + right * side * 1.5, 1 | 8)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)
		room[side] = 1.5 if hit.is_empty() else from.distance_to(hit.position)
	if absf(float(room[1.0]) - float(room[-1.0])) < 0.2: stuck_side = -stuck_side
	else: stuck_side = 1.0 if float(room[1.0]) > float(room[-1.0]) else -1.0
	return right * stuck_side

func shut_door_at_hand():
	for door in level.hotel.doors:
		if door.locked or door.opened or door.moving: continue
		if absf(door.doorway.y - position.y) < 2.0 and Vector2(door.doorway.x - position.x, door.doorway.z - position.z).length() < 1.6: return door
	return null

## Open floor a couple of metres off, not the way it was pushing: it walks
## there, and looks for its way again from a new place.
func detour(direction: Vector3) -> bool:
	var map: RID = get_world_3d().navigation_map
	var space := get_world_3d().direct_space_state
	for attempt in 10:
		var angle := rng.randf() * TAU
		var way := Vector3(cos(angle), 0, sin(angle))
		if way.dot(direction) > 0.3: continue
		var point: Vector3 = FLOOR.closest(map, position + way * rng.randf_range(2.0, 3.0))
		if point.distance_to(position) < 1.2 or absf(point.y - position.y) > 1.0: continue
		var query := PhysicsRayQueryParameters3D.create(position + Vector3.UP, point + Vector3.UP, 1 | 8)
		query.exclude = [get_rid()]
		if not space.intersect_ray(query).is_empty(): continue
		path = PackedVector3Array([position, point])
		path_index = 1
		crossings = []
		rounds.clear()
		repath = 1.5
		return true
	return false

## The last resort: up to HOP metres along its own route, onto open floor,
## never through a shut door, into the refuge or onto another planta, and only
## where no survivor can see where it was or where it lands. Only the machine
## that runs it does this; the others see it move the way they see any move.
func hop() -> bool:
	if control != "ai" or path_index >= path.size(): return false
	var line := PackedVector3Array([position])
	var left := HOP
	for i in range(path_index, path.size()):
		var from: Vector3 = line[line.size() - 1]
		var step: float = from.distance_to(path[i])
		if step >= left:
			line.append(from + (path[i] - from).normalized() * left)
			break
		left -= step
		line.append(path[i])
	var target: Vector3 = FLOOR.closest(get_world_3d().navigation_map, line[line.size() - 1])
	if target.distance_to(position) < 0.5 or absf(target.y - position.y) > 1.0 or level.point_in_refuge(target): return false
	for door in level.hotel.doors:
		if door.opened and not door.moving: continue
		for i in range(1, line.size()):
			if THREAD.crossing(door, line[i - 1], line[i]) >= 0.0: return false
	if not body_fits(target) or watched(position) or watched(target): return false
	global_position = target + Vector3(0, 0.04, 0)
	velocity = Vector3.ZERO
	speed = 0.0
	crossings = []
	repath = 0.0
	return true

func body_fits(point: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 2.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3(0, 1.26, 0))
	query.collision_mask = 1 | 8
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

## Whether any survivor, from where its eyes are and the way it is looking,
## has this spot in view.
func watched(point: Vector3) -> bool:
	for body in level.survivors():
		if not is_instance_valid(body) or not level.survivor_active(body) or not "camera" in body or not is_instance_valid(body.camera): continue
		var eye: Vector3 = body.camera.global_position
		var towards: Vector3 = point + Vector3(0, 1.2, 0) - eye
		var gap := towards.length()
		if gap > SIGHT_RANGE or gap < 0.01: continue
		if -body.camera.global_basis.z.dot(towards / gap) < 0.35: continue
		var query := PhysicsRayQueryParameters3D.create(eye, eye + towards, 1 | 8 | 64)
		query.exclude = [body.get_rid(), get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return true
	return false
