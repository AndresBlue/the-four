extends Node
## The television sets of a floor: which ones each stage is played on, putting
## them in the hotel, switching them on (with their static and the noise it
## makes), counting them, and the creature travelling through the lit ones.
## Split out of hotel_main.gd, which owns it (`level.tvs`); the level keeps
## delegates of what the network, the bots and the tests reach through it.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const TELEVISION := preload("res://game/world/interactables/hotel_television.gd")
const NOISE := preload("res://game/audio/noise_kinds.gd")
var level

## The sets of the stage in hand, in build order: the index is their name on
## the wire, like doors and wardrobes.
var televisions: Array = []

## The sets each stage is played on, chosen when the floor was built
## (TV_PLACEMENT.settle), by stage.
var tv_sets := {}

## The sets of the stages that ask for them, each lot in the wing its stage
## opens. Everyone works out the same list from the seed and the number of
## survivors, so nothing has to be sent: only which ones are on travels. They
## go into one array, stage by stage, so an index means the same set on every
## machine; each one remembers which stage it belongs to.
func place_televisions() -> void:
	televisions.clear()
	if level.manifest.get("gates", []).is_empty(): return
	for stage in level.kind.stages_asking("televisions"):
		for spot in tv_sets.get(stage, []):
			var set := TELEVISION.new()
			set.name = "Television_%d" % televisions.size()
			set.stage = stage
			set.position = spot.position
			set.rotation.y = spot.yaw
			# As big as the set it switches on: a socket that shrinks its
			# furniture shrank the set and left the lit screen floating over it.
			set.scale = Vector3.ONE * float(spot.get("scale", 1.0))
			level.hotel.add_child(set)
			televisions.append(set)

## The sets a stage is played on, by index into `televisions`. A stage lights
## its own wing's sets and nobody else's: what was left on behind you neither
## counts for the wing you are in nor is anywhere the creature could step out.
func stage_televisions(stage := -1) -> Array:
	var wanted: int = level.session.stage if stage < 0 else stage
	var result: Array = []
	for index in televisions.size():
		if is_instance_valid(televisions[index]) and int(televisions[index].stage) == wanted: result.append(index)
	return result

## Switching one on: the host decides, and the noise is made once, there.
func switch_television(set: Node3D) -> void:
	if not is_instance_valid(set) or set.on: return
	level.match_net.use_television(set)

## A set coming to life plays the whole dead channel the blackout plays, from
## its screen, and then hisses softly for as long as it stays on
## (world_audio.update_tv_hiss). It used to be a door's latch, louder than a
## door shutting, so every set switched on sounded like somebody slamming one.
const TV_BURST := "res://assets/audio/events/execution_static.ogg"

const TV_BURST_GAIN := -6.0

## Applied everywhere, whoever decided it. quiet: a returning player is told
## the set is on, not made to hear it come on.
func apply_television(index: int, value: bool, quiet := false) -> void:
	if index < 0 or index >= televisions.size(): return
	var set = televisions[index]
	if not is_instance_valid(set) or not set.set_on(value): return
	if not value:
		# The static may have played out and freed itself long ago.
		if is_instance_valid(set.burst): level.world_audio.stop_long(set.burst)
		set.burst = null
		return
	var now := Time.get_ticks_msec() / 1000.0
	set.hiss_after = now
	if quiet: return
	# Not twice: the blackout it trips plays the same static, and on a guest the
	# two can arrive in either order.
	var stream: AudioStream = load(TV_BURST)
	if level.world_audio.enabled and not level.world_audio.long_playing(TV_BURST, 1.5, "warp"):
		set.burst = level.world_audio.play_long(TV_BURST, set.screen_point(), TV_BURST_GAIN)
	set.hiss_after = now + stream.get_length()
	if not level.net.is_client(): level.on_noise(set.global_position + Vector3(0, 1.4, 0), set.click_radius(), NOISE.Kind.DOOR)

## Travelling by television: a lit set is a way in and a way out. The creature
## steps out of another lit one, wherever it is, which is why lighting them is
## a risk and not only an errand.
const WARP_REACH := 3.4

const WARP_SOUND := "res://assets/audio/events/execution_static.ogg"

## The sets it could step out of, by index, from the one it is standing at:
## the ones of the stage in hand, so it never travels into a wing that is
## already behind everybody.
func lit_televisions() -> Array:
	var result: Array = []
	for index in stage_televisions():
		if televisions[index].on: result.append(index)
	return result

## The lit set the creature is standing at, or -1. `reach`: the host judging
## a hunter's request allows for its copy of the creature running behind.
func creature_at_television(reach := WARP_REACH) -> int:
	if not is_instance_valid(level.locust): return -1
	for index in stage_televisions():
		var set = televisions[index]
		if set.on and set.global_position.distance_to(level.locust.global_position) < reach: return index
	return -1

## Where the creature comes out of a set: a step in front of it, on floor it
## can stand on -- in a suite the set is in the alcove, and 1.6 m straight out
## was inside the partition.
func television_exit(index: int) -> Vector3:
	var set = televisions[index]
	var out: Vector3 = set.global_position + Vector3(sin(set.rotation.y), 0, cos(set.rotation.y)) * 1.6
	var map: RID = level.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0: out = FLOOR.closest(map, out)
	return out

## It comes out of the set at `index`, a step in front of it, looking into the
## room. Applied on every machine, whoever decided it.
func warp_creature(index: int) -> void:
	if index < 0 or index >= televisions.size() or not is_instance_valid(level.locust): return
	var set = televisions[index]
	if not is_instance_valid(set) or not set.on: return
	var from: Vector3 = level.locust.global_position
	level.locust.global_position = television_exit(index) + Vector3(0, 0.04, 0)
	# Facing the room it came out into, not back at the screen.
	level.locust.rotation.y = set.rotation.y + PI
	# A puppet ignores the states still on their way from beside the old set.
	if level.locust.control == "puppet":
		level.locust.ride_point = level.locust.global_position
		level.locust.ride_hold = 2.0
	level.locust.velocity = Vector3.ZERO
	level.locust.speed = 0.0
	# A puppet interpolates between the states it is sent: without this it
	# would slide across the floor instead of stepping out of a screen.
	level.locust.net_states.clear()
	level.locust.net_clock = 0.0
	if is_instance_valid(level.locust.driver): level.locust.driver.channel_open = false
	# The machine looks round the room it came out into, and then goes about
	# the wing. Nothing of the old place comes with it: it used to hear its own
	# arrival -- a noise 1.4 m over its head it never reached -- and stood
	# twelve seconds where it stepped out, and a wardrobe beside the set was
	# opened on the strength of it.
	if level.locust.control == "ai":
		level.locust.forget_route()
		level.locust.last_known = level.locust.global_position
		level.locust.last_heading = -level.locust.global_basis.z
		level.locust.set_mode(level.locust.Mode.SEARCH)
	# On players of their own: in the pool of short cues the next doors cut
	# fourteen seconds of static off after one or two. What the survivors hear
	# is this static, from both sets; the creature hears nothing of itself.
	if level.world_audio.enabled:
		level.world_audio.play_long(WARP_SOUND, from + Vector3(0, 1.4, 0), -6.0, RID(), false, 0.0, "warp")
		level.world_audio.play_long(WARP_SOUND, level.locust.global_position + Vector3(0, 1.4, 0), -4.0, RID(), false, 0.0, "warp")

## How many of the stage's own sets are on. What burns in another wing is not
## counted: every stage from the second starts its tally at nothing.
func televisions_on() -> int:
	var count := 0
	for index in stage_televisions():
		if televisions[index].on: count += 1
	return count

## The authority, every frame: whether the stage in hand is met -- which
## unlocks the door on -- and whether somebody has already crossed it, which
## is what carries the floor to the next stage. Nothing is held down any more.
## The AI travels by television too, so a lit set is never safe just because
## the creature is far: looking for nobody at one -- come to see who switched
## it on, or searching round it -- for HOP_PATIENCE, it steps out of another.
## It used to need eight seconds of one search, and a search now gives up in
## eight to ten and walks off: it all but never did. Seconds left before it
## may do that again, and how long it has been looking at this one.
## It comes out of a set with nobody active within HOP_CLEAR of where it
## steps out and nobody looking there: out of a set on top of somebody was a
## death nobody could do anything about.
var hop_rest := 0.0

var hop_wait := 0.0

const HOP_REST := 25.0

const HOP_PATIENCE := 4.0

const HOP_CLEAR := 12.0

func creature_channel_hop(delta: float) -> void:
	hop_rest = maxf(0.0, hop_rest - delta)
	if not is_instance_valid(level.locust) or level.locust.control != "ai": return
	var looking: bool = level.locust.mode in [level.locust.Mode.SEARCH, level.locust.Mode.INVESTIGATE] and not level.locust.lift_bound
	var here: int = creature_at_television() if looking else -1
	hop_wait = hop_wait + delta if here >= 0 else 0.0
	if hop_rest > 0.0 or hop_wait < HOP_PATIENCE: return
	var lit: Array = lit_televisions()
	if lit.size() < 2: return
	var choices: Array = lit.filter(func(index): return index != here and television_clear(index))
	if choices.is_empty(): return
	var pick: int = choices[level.locust.rng.randi_range(0, choices.size() - 1)]
	hop_wait = 0.0
	hop_rest = HOP_REST
	warp_creature(pick)
	if level.match_net.in_match(): level.match_net.warp_state.rpc(pick)

## Nobody active near where it would step out of that set, and nobody
## looking at the spot.
func television_clear(index: int) -> bool:
	var out := television_exit(index)
	for body in level.survivors():
		if level.survivor_active(body) and body.global_position.distance_to(out) < HOP_CLEAR: return false
	return not level.locust.watched(out)
