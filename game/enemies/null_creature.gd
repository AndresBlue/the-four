extends "res://game/enemies/creature.gd"
## The creature of a floor whose own is not made yet (docs/OFICINAS.md 15,
## phase 1: floor 2's until The Lurker). It answers the whole contract
## (creature.gd) and does nothing: it stands where nobody gets to, is never
## felt, heard or seen, and takes nobody. Its scene is this script on a bare
## CharacterBody3D: no shape, no mesh, no sound.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
## How many noises `heard` keeps, the newest last.
const HEARD_MOST := 64

## The level that put it down (hotel_main.spawn_creature()).
var level
## [point, radius] of every noise it was told of (hear()): what the systems'
## tests read to know a noise reached the creature.
var heard: Array = []

## Out of every body's way and out of sight, and nothing to run.
func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	set_process(false)
	visible = false

func kind_id() -> StringName: return &"none"

## In none of creature.gd's lists, so every predicate is false: nobody is
## hunted, led or warned by it.
func activity() -> StringName: return &"idle"

func mode_name() -> String: return "nula"

## Kept, and nothing else done about it.
func hear(point: Vector3, radius: float) -> void:
	heard.append([point, radius])
	if heard.size() > HEARD_MOST: heard.pop_front()

## Nothing tells of it.
func hushed() -> bool: return true

## Where it waits on the planta of `stage`: its den_room() on the floor in
## play; INF with no floor or no room.
func den_point(stage: int) -> Vector3:
	if level == null or level.manifest.is_empty(): return Vector3.INF
	var room := den_room(level.manifest, stage)
	if room < 0: return Vector3.INF
	return FLOOR.position_of(level.manifest.rooms[room]) + Vector3(0, 0.04, 0)

## The survivors have gone on: it is put in its den on their planta at once,
## with no ride.
func follow_to_planta(stage: int, _fresh := false) -> void:
	var point := den_point(stage)
	if point.is_finite(): teleport(point, NAN, &"lift")

## Its den on the planta of `stage`: the room farthest from where that planta
## is walked into (FLOOR.route_metres()), never void nor off-limits, the
## lowest id on a tie. No draw: the same floor, the same den.
static func den_room(manifest: Dictionary, stage: int) -> int:
	var planta := stage - 1
	var rooms: Array = manifest.get("rooms", [])
	var entry := FLOOR.entry_of(manifest, planta)
	if entry < 0 or entry >= rooms.size(): return -1
	var metres := FLOOR.route_metres(manifest, entry)
	var shut: Array = FLOOR.palette(manifest).off_limits_rooms(manifest)
	var best := -1
	for id in rooms.size():
		var room: Dictionary = rooms[id]
		if not metres.has(id) or int(room.get("wing", -1)) != planta or FLOOR.is_void(room) or shut.has(id): continue
		if best < 0 or float(metres[id]) > float(metres[best]): best = id
	return best

func debug_lines() -> Array[String]: return ["criatura nula: no hace nada"]
