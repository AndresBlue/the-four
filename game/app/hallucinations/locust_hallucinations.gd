extends Node
## The Locust's lies to a mind that is going (creature.hallucinations(); the
## floor's own, its doors and wardrobes, are sanity.gd's): its call from
## somewhere it is not, it walking past a room or two away (phantom_passage),
## and the one model of it, with its poses, that phantom_sight shows where it
## is not. sanity.gd makes this under itself the first time a lie of it is
## told, and keeps it: whatever plays them is this machine's alone.
##
## Moved here as it was in sanity.gd and phantom_sight.gd: the same calls,
## the same clip, the same random numbers drawn in the same order.
const GRUNTS := preload("res://game/audio/grunt_segments.gd")
const LOCUST := preload("res://game/enemies/locust/hotel_locust.gd")
const PHANTOM_CLIP := "res://assets/audio/sfx/chase/grunts.ogg"
const PASSAGE := preload("res://game/app/phantom_passage.gd")
const LOOK := preload("res://game/enemies/locust/locust_look.gd")
const POSER := preload("res://game/enemies/locust/locust_poser.gd")
const MODEL := preload("res://assets/enemies/locust.glb")
## The model at the creature's size.
const SIGHT_SCALE := 1.95
## The bone its face is looked at by, and those that must stay behind the
## jamb of a door it peeks round: its middle, its hips and its hanging arms.
const HEAD := "Head1"
const BODY_BONES := ["Spine", "Spine2", "Pelvis", "L_Forearm", "R_Forearm", "L_Hand", "R_Hand"]
var level
## Its voice from where it is not: a player of its own, so the real call is
## never cut short by a made-up one; and how much of it is left to play.
var phantom: AudioStreamPlayer3D
var phantom_left := 0.0
## It walking past (phantom_passage), made the first time.
var passage

func setup(owner_level) -> void:
	level = owner_level
	name = "LocustHallucinations"

## Its voice, from where it is not. A call, never one of the short barks:
## those are the tell of a strike (hotel_locust.warn), and the floor lies
## about where it is, not about that. And heard the way a real one would be,
## round through a doorway: it used to come straight through the walls.
func false_call(point: Vector3) -> void:
	if not is_instance_valid(phantom):
		phantom = AudioStreamPlayer3D.new()
		phantom.name = "Phantom"
		phantom.bus = "Threat"
		phantom.stream = load(PHANTOM_CLIP)
		phantom.unit_size = 7.0
		phantom.max_distance = 40.0
		add_child(phantom)
	var calls: Array = []
	for segment in GRUNTS.SEGMENTS:
		if float(segment[1]) >= LOCUST.AGGRESSIVE_GRUNT: calls.append(segment)
	if calls.is_empty(): return
	var segment: Array = calls[randi() % calls.size()]
	var route: Dictionary = level.world_audio.route_source(point + Vector3(0, 1.6, 0))
	if not route.audible: return
	level.world_audio.apply_route(phantom, route, -4.0, "Threat")
	phantom.pitch_scale = randf_range(0.8, 0.95)
	phantom.play(segment[0])
	phantom_left = float(segment[1]) / phantom.pitch_scale

## A made-up call lasts as long as the piece of the recording it came from.
func quiet(delta: float) -> void:
	if not is_instance_valid(phantom) or not phantom.playing: return
	phantom_left -= delta
	if phantom_left <= 0.0: phantom.stop()

## Starts it walking past; false when it cannot now (phantom_passage.begin).
func walk_past() -> bool:
	if not is_instance_valid(passage):
		passage = PASSAGE.new()
		add_child(passage)
		passage.setup(level)
	return passage.begin()

## Where the walk it is on began, the lie's point; Vector3.INF when it is not
## walking.
func walk_start() -> Vector3:
	if not is_instance_valid(passage) or not passage.walking(): return Vector3.INF
	return passage.path[0]

## The one model a sight of it is made of, under `host`: named, at its size
## and in its own look.
func sight_model(host: Node) -> Node3D:
	var model: Node3D = MODEL.instantiate()
	model.name = "Phantom"
	model.scale = Vector3.ONE * SIGHT_SCALE
	host.add_child(model)
	LOOK.apply(model)
	return model

## What poses that model (locust_poser): point(bone), pose_peek(lean, twitch,
## side) round a jamb, pose_stare(twitch) standing, the title screen's.
func sight_poser(model: Node3D):
	return POSER.new(model)
