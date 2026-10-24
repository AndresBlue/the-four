extends Node
## The blood of a capture (docs/EXECUTION.md, 8.7): what leaves whoever the
## creature runs through, where it goes and what it leaves on the place. It
## springs out of their back as the blade holding them goes in; it drips
## under them while they are held, from higher as they are lifted; the blow
## through the face throws it across the room behind them, and the blade
## coming back out lays a line of it on the wall or the ceiling; let go, the
## wound in the chest wells a few times, weaker each; and where they come to
## lie a pool spreads for half a minute after the scene is over. On walls,
## what landed thick runs.
##
## All of it is worked out once, as the capture starts, from what the host
## decided about it (its seed, where the creature stands and which way it
## faces) and from the place itself, with rays: every drop, where it lands
## and when. Nothing of it is sent to anybody and nothing of it is a matter
## of chance on any machine, so it is the same blood on all of them
## (camera_fall.gd is the same idea). Each stain is there from the first
## frame and draws nothing until the blood's clock reaches the second it
## lands at (presentation/shaders/blood.gdshader); the clock is the scene's
## while there is one and this node's own after it, because the scene is
## gone long before a pool has finished spreading.
##
## What it leaves is the floor's until the stage changes, like the camcorder
## (executions.clear_leavings); a capture let go alive leaves none (release).
## Owned by executions.gd (`level.executions.blood`).
const SCORE := preload("res://game/app/capture_score.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const STAIN := preload("res://game/presentation/shaders/blood.gdshader")
const POOL := preload("res://game/presentation/shaders/blood_pool.gdshader")
const ATLAS := preload("res://assets/decals/blood_atlas.png")
## What it sounds like (docs/AUDIO.md): a wet rag wrung out, four takes of it
## -- what leaves the back at the grab, and each welling of the chest --, and
## an artery let go, a spray that ends in spurts, for the blow. Both recorded
## for this and given to the public domain (freesound.org: "Blood Gush",
## FlaxGod; "Blood Gush / Spray", clif_creates), cut by the author.
const GUSHES := ["res://assets/audio/sfx/blood/blood-gush-1.ogg", "res://assets/audio/sfx/blood/blood-gush-2.ogg", "res://assets/audio/sfx/blood/blood-gush-3.ogg", "res://assets/audio/sfx/blood/blood-gush-4.ogg"]
const SPRAY := "res://assets/audio/sfx/blood/hemorrhage.ogg"
## How loud: the grab's under the scream that is on top of it, the blow's as
## loud as the blow, and each welling quieter than the last (dB).
const GRAB_DB := -12.5
const SPRAY_DB := -6.0
const WELL_DB := -10.0
const WELL_FADE := 3.5
var level
## The score of the scene being played (executions.score()): its creature's
## capture style's.
func score(): return level.executions.score() if level != null and level.get("executions") != null else SCORE

## What stops a drop: walls, floors, ceilings and furniture. Not doors or the
## leaves of wardrobes, which move; not bodies.
const SOLID := 1
const GRAVITY := 9.8
## How long a drop is followed before it is given up, and how finely.
const FLIGHT := 1.5
const STEP := 0.04
## The stains of the atlas (tools/textures/bake_blood.py): fallen straight,
## come in at an angle, and runs.
const ROUND := [0, 1, 2, 3, 4, 5, 6, 7]
const SLANTED := [8, 9, 10, 11, 12, 13]
const RUNS := [14, 15]
## A drop that meets a surface at less than this sine of an angle was coming
## along it: drawn out, and never more than MOST_DRAWN times its width.
const SLANT := 0.8
const MOST_DRAWN := 3.2
## How fast what landed thick on a wall runs down it (m/s).
const RUN_PACE := 0.07
## The pool: how wide the quad that carries it, how far it gets on a hard
## floor (metres, drawn between the two), how long it takes, and how long
## after the body is let go the first of it is on the floor.
const POOL_SPAN := 1.5
const POOL_RADIUS := Vector2(0.36, 0.5)
const POOL_TIME := 30.0
## After this long nothing of a capture's blood changes any more.
const SETTLED := 70.0
## A camcorder lying nearer than this to where its owner was held, in front
## of the creature, has some of it on its lens.
const LENS_REACH := 1.7

## What each capture left: {id, clock, nodes, materials, pool, air, flying,
## still, scene, stains}. The one in hand is the last. `stains` is every
## stain as it was worked out ({room, transform, born, ...}): what the tests
## read, since what is handed to the renderer cannot be asked back of it
## where there is none.
var records: Array = []

func _ready() -> void:
	process_priority = 90

## Whether this machine draws any of it (Ajustes, «Sangre»).
func wanted() -> bool:
	return level != null and bool(level.settings.values.get("gore", true))

## Everything a capture will spill, from the moment it starts.
func begin(execution: Dictionary) -> void:
	if not wanted() or not is_instance_valid(level.hotel) or execution.is_empty(): return
	release(int(execution.get("id", -1)))
	var scene := snapshot(execution)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(scene.seed) ^ 0xb100d
	var sparing: bool = bool(level.settings.values.get("reduced", false))
	var drops: Array = []
	spill(scene, rng, drops, sparing)
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var stains: Array = []
	for drop in drops: land(space, scene, rng, drop, stains)
	var record := {"id": int(execution.get("id", -1)), "clock": 0.0, "nodes": [], "materials": [], "pool": null, "air": null, "flying": [], "still": false, "scene": scene, "stains": stains, "sounds": sounds(scene, rng, sparing)}
	lay(record, stains)
	pool(record, space, scene, rng)
	if not sparing: fly(record, drops)
	records.append(record)

## What is heard of it, and when: [{time, path, at, db}], played as the
## clock gets to each (heard), from where the wound is by then.
func sounds(scene: Dictionary, rng: RandomNumberGenerator, sparing: bool) -> Array:
	var said: Array = [
		{"time": 0.04, "path": GUSHES[rng.randi_range(0, GUSHES.size() - 1)], "at": chest_at(scene, 0.04), "db": GRAB_DB},
		{"time": score().KILL_TIME + 0.02, "path": SPRAY, "at": face_at(scene, score().KILL_TIME), "db": SPRAY_DB},
	]
	if sparing: return said
	var first := rng.randi_range(0, GUSHES.size() - 1)
	for pulse in 4:
		var at: float = score().DROP_TIME + 0.04 + 0.21 * float(pulse)
		said.append({"time": at, "path": GUSHES[(first + pulse) % GUSHES.size()], "at": chest_at(scene, at), "db": WELL_DB - WELL_FADE * float(pulse)})
	return said

func heard(record: Dictionary, clock: float) -> void:
	var left: Array = record.sounds
	while not left.is_empty() and clock >= float(left[0].time):
		var cue: Dictionary = left.pop_front()
		# Late by more than a moment (a capture taken up half way), it is not
		# played at all: a spray that started a second ago is not starting now.
		if clock - float(cue.time) < 0.25 and level.world_audio.enabled: level.world_audio.play_at(String(cue.path), cue.at, float(cue.db), RID(), 0.0)

## What of the scene the blood needs, kept: the scene itself will be gone.
func snapshot(execution: Dictionary) -> Dictionary:
	var yaw := float(execution.yaw)
	# Where the creature stands and which way it faces: its capture style's.
	var staged = level.executions.style()
	var forward: Vector3 = staged.creature_forward(execution)
	var point: Vector3 = staged.creature_point(execution)
	var exclude: Array = level.executions.scene_bodies()
	var straight: bool = bool(execution.get("straight", false)) or bool(execution.get("slump", false))
	return {
		"seed": int(execution.get("seed", 0)), "point": point, "forward": forward, "right": forward.cross(Vector3.UP),
		"far": float(execution.get("far", score().HOLD_FAR.y)), "crouched": bool(execution.get("crouched", false)),
		"side": float(execution.get("side", 1.0)), "exclude": exclude,
		"fall": level.executions.fall_way(yaw, 0.0 if straight else float(execution.get("side", 1.0))),
		"room": float(execution.get("room", score().LIE_ROOM)), "sill": level.executions.seat_floor(),
	}

## Where the body is held at a second of the scene (the capture style's
## victim_hold_point, The Locust's, from what was kept of it).
func held_at(scene: Dictionary, time: float) -> Vector3:
	var reach := lerpf(float(scene.far), score().HOLD_NEAR, score().closing(time))
	return (scene.point as Vector3) + (scene.forward as Vector3) * reach + Vector3.UP * (score().HOLD_STAND * (1.0 - score().fall(time)) + score().lift(time) * score().LIFT_HEIGHT)

## The wound in its chest at a second of the scene: where the blade holds it,
## and once it is let go, down and back with it.
func chest_at(scene: Dictionary, time: float) -> Vector3:
	var falling: float = score().fall(time)
	var low: float = (1.0 - score().lift(time)) if bool(scene.crouched) else 0.0
	var up := lerpf(lerpf(1.2, 0.68, low), 0.3, score().sunk(falling))
	return held_at(scene, time) + Vector3.UP * up + (scene.fall as Vector3) * score().seat_back(float(scene.room)) * score().sunk(falling)

func face_at(scene: Dictionary, time: float) -> Vector3:
	var low: float = (1.0 - score().lift(time)) if bool(scene.crouched) else 0.0
	return held_at(scene, time) + Vector3.UP * lerpf(1.58, 0.88, low)

## A direction within `spread` radians of another.
func scattered(rng: RandomNumberGenerator, towards: Vector3, spread: float) -> Vector3:
	var aside := towards.cross(Vector3.UP)
	if aside.length() < 0.01: aside = Vector3.RIGHT
	aside = aside.normalized()
	var off := spread * sqrt(rng.randf())
	return (Basis(towards.normalized(), rng.randf() * TAU) * (Basis(aside, off) * towards.normalized())).normalized()

func drop(drops: Array, time: float, from: Vector3, velocity: Vector3, size: float) -> void:
	drops.append({"time": time, "from": from, "velocity": velocity, "size": size})

## Every drop of the capture: when it leaves, from where, how fast and how
## big a stain it will make (metres across the quad that carries it).
func spill(scene: Dictionary, rng: RandomNumberGenerator, drops: Array, sparing: bool) -> void:
	var forward: Vector3 = scene.forward
	var right: Vector3 = scene.right
	# The grab: the blade that holds it goes in at the chest and what it
	# pushes ahead of it leaves by the back, away from the creature.
	var back := chest_at(scene, 0.03) + forward * 0.14
	for index in 16:
		drop(drops, 0.03 + rng.randf() * 0.09, back + Vector3(rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03), rng.randf_range(-0.03, 0.03)), scattered(rng, (forward + Vector3.UP * 0.15).normalized(), 0.6) * rng.randf_range(1.6, 4.6), rng.randf_range(0.07, 0.16))
	# Held: it runs down the blade and off the body, a drop at a time and
	# then faster, from wherever the body is by then.
	var when := 0.35
	while when < score().DROP_TIME:
		var from := chest_at(scene, when) - forward * rng.randf_range(0.02, 0.2) + right * rng.randf_range(-0.1, 0.1) - Vector3.UP * rng.randf_range(0.1, 0.5)
		drop(drops, when, from, Vector3(rng.randf_range(-0.15, 0.15), 0.0, rng.randf_range(-0.15, 0.15)), rng.randf_range(0.11, 0.2))
		when += rng.randf_range(0.16, 0.42) * lerpf(1.0, 0.55, score().ramp(when, 0.0, score().KILL_TIME))
	# The blow: through the face and out behind, the way the arm was going --
	# from the creature's shoulder, above, so most of it goes down the room.
	var face := face_at(scene, score().KILL_TIME)
	var struck := (face - ((scene.point as Vector3) + Vector3.UP * (face.y - (scene.point as Vector3).y + 0.35) - right * 0.3)).normalized()
	var behind := face + struck * 0.13
	for index in 54:
		var fast := rng.randf()
		drop(drops, score().KILL_TIME + rng.randf() * 0.1, behind + Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04), rng.randf_range(-0.04, 0.04)), scattered(rng, struck, lerpf(0.75, 0.3, fast)) * lerpf(1.2, 7.5, fast * fast), lerpf(0.24, 0.07, fast) * rng.randf_range(0.8, 1.25))
	# And the blade comes back out and up: what is on it leaves it in a line.
	var swing := Basis(right, 0.0)
	for index in 9:
		var along := float(index) / 8.0
		swing = Basis(-right, lerpf(0.5, 2.1, along))
		drop(drops, score().KILL_TIME + 0.2 + 0.12 * along, face - struck * 0.25 * along + Vector3.UP * 0.1, (swing * forward + right * rng.randf_range(-0.08, 0.08)).normalized() * rng.randf_range(4.5, 6.0), rng.randf_range(0.06, 0.1))
	if sparing: return
	# Let go: the wound in the chest is open, and it wells -- a few times,
	# each weaker than the last, as the body goes down.
	for pulse in 4:
		var at: float = score().DROP_TIME + 0.04 + 0.21 * float(pulse)
		var strength := 1.0 - 0.24 * float(pulse)
		for index in 7 - pulse:
			drop(drops, at + rng.randf() * 0.07, chest_at(scene, at) - forward * 0.12, scattered(rng, (-forward * 0.6 + Vector3.UP).normalized(), 0.75) * rng.randf_range(0.8, 2.3) * strength, rng.randf_range(0.09, 0.18))

## Where a drop lands, and the stain it makes there.
func land(space: PhysicsDirectSpaceState3D, scene: Dictionary, rng: RandomNumberGenerator, drop: Dictionary, stains: Array) -> void:
	var from: Vector3 = drop.from
	var velocity: Vector3 = drop.velocity
	var at := from
	var flown := 0.0
	while flown < FLIGHT:
		var next_time := flown + STEP
		var next := from + velocity * next_time + Vector3.DOWN * 0.5 * GRAVITY * next_time * next_time
		var query := PhysicsRayQueryParameters3D.create(at, next, SOLID)
		query.exclude = scene.exclude
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var along := at.distance_to(hit.position) / maxf(at.distance_to(next), 0.0001)
			drop["lands"] = float(drop.time) + flown + STEP * along
			stain(space, scene, rng, drop, hit.position, hit.normal, (velocity + Vector3.DOWN * GRAVITY * (flown + STEP * along)).normalized(), stains)
			return
		at = next
		flown = next_time
	drop["lands"] = float(drop.time) + FLIGHT

func stain(space: PhysicsDirectSpaceState3D, scene: Dictionary, rng: RandomNumberGenerator, drop: Dictionary, point: Vector3, normal: Vector3, going: Vector3, stains: Array) -> void:
	# Nothing lands where the creature is standing: it is in the way.
	var feet: Vector3 = scene.point
	if Vector2(point.x - feet.x, point.z - feet.z).length() < 0.4 and absf(point.y - feet.y) < 0.3 and (point - feet).dot(scene.forward as Vector3) < 0.25: return
	normal = normal.normalized()
	var steep := absf(going.dot(normal))
	# Along the surface, the way it was going; straight down on to it, any way.
	var along := going - normal * going.dot(normal)
	if along.length() < 0.05 or steep >= SLANT:
		along = normal.cross(Vector3.RIGHT if absf(normal.x) < 0.9 else Vector3.FORWARD)
		along = Basis(normal, rng.randf() * TAU) * along
	along = along.normalized()
	var across := normal.cross(along).normalized()
	var wide := float(drop.size)
	var drawn := 1.0 if steep >= SLANT else minf(MOST_DRAWN, 1.0 / maxf(steep, 0.05))
	var long := wide * drawn
	# The body of a drawn-out stain is at its near end.
	var middle := point + along * (long * 0.2 if drawn > 1.0 else 0.0)
	# Wholly on what it hit: a corner over an edge or round a corner, smaller,
	# and if it still is, not at all.
	var fits := false
	for attempt in 3:
		fits = true
		for corner in [Vector2(-0.38, -0.38), Vector2(0.38, -0.38), Vector2(-0.38, 0.38), Vector2(0.38, 0.38)]:
			var spot: Vector3 = middle + across * wide * (corner as Vector2).x + along * long * (corner as Vector2).y
			var query := PhysicsRayQueryParameters3D.create(spot + normal * 0.03, spot - normal * 0.03, SOLID)
			query.exclude = scene.exclude
			if space.intersect_ray(query).is_empty():
				fits = false
				break
		if fits: break
		wide *= 0.6
		long *= 0.6
		middle = point + along * (long * 0.2 if drawn > 1.0 else 0.0)
	if not fits: return
	var cells: Array = ROUND if drawn <= 1.0 else SLANTED
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, point)
	if room.is_empty(): return
	# Carpet drinks it; everything else it lies on.
	var floor_y: float = FLOOR.position_of(room).y
	var soaked := 1.0 if normal.y > 0.7 and absf(point.y - floor_y) < 0.08 and not FLOOR.palette(level.manifest).hard_floor(room) else 0.0
	var lands := float(drop.lands)
	stains.append({"room": int(room.id), "transform": Transform3D(Basis(across * wide, normal * 0.01, along * long), middle + normal * 0.002), "cell": float(cells[rng.randi_range(0, cells.size() - 1)]), "born": lands, "run": 0.0, "soak": soaked})
	# On a wall, what landed thick does not stay: it runs.
	if absf(normal.y) < 0.35 and wide > 0.11 and rng.randf() < 0.75:
		var down := (Vector3.DOWN - normal * Vector3.DOWN.dot(normal)).normalized()
		var length := minf(rng.randf_range(0.07, 0.24), maxf(0.0, point.y - floor_y - 0.02))
		if length > 0.04:
			var thread := wide * 0.3
			stains.append({"room": int(room.id), "transform": Transform3D(Basis(normal.cross(down).normalized() * thread, normal * 0.01, down * length), point + down * length * 0.5 + normal * 0.0025), "cell": float(RUNS[rng.randi_range(0, RUNS.size() - 1)]), "born": lands + rng.randf_range(0.15, 0.5), "run": length / RUN_PACE, "soak": 0.0})

func material_of(record: Dictionary) -> ShaderMaterial:
	if not (record.materials as Array).is_empty(): return record.materials[0]
	var material := ShaderMaterial.new()
	material.shader = STAIN
	material.set_shader_parameter("atlas", ATLAS)
	material.set_shader_parameter("clock", 0.0)
	material.render_priority = 2
	(record.materials as Array).append(material)
	return material

static func quad() -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE
	return mesh

## The stains, laid: one mesh of them for each room they are in, under that
## room's own node, so its lamps light them and they go with it.
func lay(record: Dictionary, stains: Array) -> void:
	var by_room := {}
	for entry in stains:
		if not by_room.has(entry.room): by_room[entry.room] = []
		(by_room[entry.room] as Array).append(entry)
	for id in by_room:
		if int(id) < 0 or int(id) >= level.hotel.room_nodes.size() or not is_instance_valid(level.hotel.room_nodes[int(id)]): continue
		var parent: Node3D = level.hotel.room_nodes[int(id)]
		var list: Array = by_room[id]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = quad()
		multi.instance_count = list.size()
		var holder := MultiMeshInstance3D.new()
		holder.name = "Blood"
		holder.multimesh = multi
		holder.material_override = material_of(record)
		holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(holder)
		var inverse := holder.global_transform.affine_inverse()
		var bounds := AABB()
		for index in list.size():
			var entry: Dictionary = list[index]
			var local: Transform3D = inverse * (entry.transform as Transform3D)
			multi.set_instance_transform(index, local)
			multi.set_instance_custom_data(index, Color(float(entry.cell), float(entry.born), float(entry.run), float(entry.soak)))
			bounds = AABB(local.origin, Vector3.ZERO) if index == 0 else bounds.expand(local.origin)
		holder.custom_aabb = bounds.grow(0.5)
		(record.nodes as Array).append(holder)

## Where the body comes to lie, the pool: under its trunk, as far each way as
## nothing stops it.
func pool(record: Dictionary, space: PhysicsDirectSpaceState3D, scene: Dictionary, rng: RandomNumberGenerator) -> void:
	var lean: float = score().seat_lean(float(scene.room))
	var back: float = score().seat_back(float(scene.room))
	var feet: Vector3 = (scene.point as Vector3) + (scene.forward as Vector3) * score().HOLD_NEAR
	# Under its head and its chest, and a little to the side its head lolls to.
	var middle := feet + (scene.fall as Vector3) * (back + 0.6 * sin(lean)) + (scene.right as Vector3) * float(scene.side) * rng.randf_range(0.05, 0.16)
	var room: Dictionary = FLOOR.room_at(level.manifest.rooms, middle)
	if room.is_empty() or int(room.id) >= level.hotel.room_nodes.size() or not is_instance_valid(level.hotel.room_nodes[int(room.id)]): return
	var floor_y: float = (scene.point as Vector3).y - 0.04 + float(scene.sill)
	middle.y = floor_y
	var radius := rng.randf_range(POOL_RADIUS.x, POOL_RADIUS.y)
	# Each way round: as far as the first thing standing on the floor, and no
	# further than the room it is in (a ray goes through an open doorway).
	var rect: Rect2 = Rect2(FLOOR.position_of(room).x - FLOOR.size_of(room).x * 0.5, FLOOR.position_of(room).z - FLOOR.size_of(room).y * 0.5, FLOOR.size_of(room).x, FLOOR.size_of(room).y).grow(-0.06)
	var reach: PackedFloat32Array = []
	for index in 16:
		var angle := TAU * float(index) / 16.0
		var way := Vector3(cos(angle), 0.0, sin(angle))
		var far := POOL_SPAN * 0.5
		var query := PhysicsRayQueryParameters3D.create(middle + Vector3.UP * 0.03, middle + Vector3.UP * 0.03 + way * far, SOLID)
		query.exclude = scene.exclude
		var hit := space.intersect_ray(query)
		if not hit.is_empty(): far = minf(far, Vector2(hit.position.x - middle.x, hit.position.z - middle.z).length())
		if absf(way.x) > 0.001: far = minf(far, maxf(0.0, ((rect.end.x if way.x > 0.0 else rect.position.x) - middle.x) / way.x))
		if absf(way.z) > 0.001: far = minf(far, maxf(0.0, ((rect.end.y if way.z > 0.0 else rect.position.y) - middle.z) / way.z))
		reach.append(far)
	var material := ShaderMaterial.new()
	material.shader = POOL
	material.render_priority = 1
	material.set_shader_parameter("age", -1.0)
	material.set_shader_parameter("span", POOL_SPAN)
	material.set_shader_parameter("radius", radius)
	material.set_shader_parameter("spread_time", POOL_TIME)
	material.set_shader_parameter("reach", reach)
	material.set_shader_parameter("soak", 0.0 if FLOOR.palette(level.manifest).hard_floor(room) or float(scene.sill) > 0.0 else 1.0)
	material.set_shader_parameter("seed", float(int(scene.seed) % 997))
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(POOL_SPAN, POOL_SPAN)
	var holder := MeshInstance3D.new()
	holder.name = "BloodPool"
	holder.mesh = mesh
	holder.material_override = material
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	level.hotel.room_nodes[int(room.id)].add_child(holder)
	holder.global_transform = Transform3D(Basis.IDENTITY, middle + Vector3.UP * 0.003)
	(record.nodes as Array).append(holder)
	record["pool"] = material
	record["pool_from"] = score().DROP_TIME + score().FALL_LENGTH * 0.8
	record["pool_at"] = middle

## The drops while they are in the air: a streak each, as long as the frame
## it is caught in.
func fly(record: Dictionary, drops: Array) -> void:
	var flying: Array = []
	for entry in drops:
		if float(entry.get("lands", 0.0)) - float(entry.time) > 0.03: flying.append(entry)
	if flying.is_empty(): return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad()
	multi.instance_count = flying.size()
	for index in flying.size():
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
		multi.set_instance_custom_data(index, Color(float(SLANTED[index % SLANTED.size()]), 0.0, 0.0, 0.0))
	var holder := MultiMeshInstance3D.new()
	holder.name = "BloodInTheAir"
	holder.multimesh = multi
	holder.material_override = material_of(record)
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3(-6, -3, -6), Vector3(12, 8, 12))
	level.hotel.add_child(holder)
	holder.global_position = (record.scene.point as Vector3) + Vector3.UP * 0.5
	(record.nodes as Array).append(holder)
	record["air"] = holder
	record["flying"] = flying

func _process(delta: float) -> void:
	if records.is_empty() or level == null: return
	var playing: bool = level.session.state == level.session.State.PLAYING
	var eye := Vector3.ZERO
	var camera := get_viewport().get_camera_3d()
	if camera != null: eye = camera.global_position
	for record in records:
		if bool(record.still): continue
		# The scene's clock while it is this capture's; this one's own after.
		if not level.execution.is_empty() and int(level.execution.get("id", -2)) == int(record.id): record.clock = float(level.execution.time)
		elif playing: record.clock = float(record.clock) + delta
		var clock := float(record.clock)
		for material in record.materials: (material as ShaderMaterial).set_shader_parameter("clock", clock)
		if record.pool != null: (record.pool as ShaderMaterial).set_shader_parameter("age", clock - float(record.pool_from))
		if is_instance_valid(record.air): streak(record, clock, eye)
		heard(record, clock)
		if clock > SETTLED: record.still = true

## The drops in the air at a second of the clock, put where they are.
func streak(record: Dictionary, clock: float, eye: Vector3) -> void:
	var holder: MultiMeshInstance3D = record.air
	var flying: Array = record.flying
	var inverse := holder.global_transform.affine_inverse()
	var any := false
	for index in flying.size():
		var entry: Dictionary = flying[index]
		var since := clock - float(entry.time)
		if since < 0.0 or clock >= float(entry.lands):
			holder.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
			if since < 0.0: any = true
			continue
		any = true
		var velocity: Vector3 = (entry.velocity as Vector3) + Vector3.DOWN * GRAVITY * since
		var at: Vector3 = (entry.from as Vector3) + (entry.velocity as Vector3) * since + Vector3.DOWN * 0.5 * GRAVITY * since * since
		var going := velocity.normalized() if velocity.length() > 0.01 else Vector3.DOWN
		# Facing whoever looks, drawn out along its way by what it covers in
		# the sixtieth of a second a frame is open.
		var facing := (eye - at) - going * (eye - at).dot(going)
		facing = facing.normalized() if facing.length() > 0.001 else Vector3.UP
		var wide := float(entry.size) * 0.45
		var long := maxf(wide, velocity.length() / 60.0 * 1.6)
		holder.multimesh.set_instance_transform(index, inverse * Transform3D(Basis(facing.cross(going).normalized() * wide, facing * 0.01, going * long), at))
	if not any:
		(record.nodes as Array).erase(holder)
		holder.queue_free()
		record.air = null

## Whether the camcorder of whoever dies has some of it on its lens: lying
## near where they were held, in front of the creature (death_tape.gd).
func on_lens(id: int, lens: Vector3) -> bool:
	for record in records:
		if int(record.id) != id: continue
		var scene: Dictionary = record.scene
		var held: Vector3 = (scene.point as Vector3) + (scene.forward as Vector3) * score().HOLD_NEAR
		return Vector2(lens.x - held.x, lens.z - held.z).length() < LENS_REACH and (lens - (scene.point as Vector3)).dot(scene.forward as Vector3) > 0.1
	return false

func drop_record(record: Dictionary) -> void:
	for node in record.nodes:
		if is_instance_valid(node): node.queue_free()
	record.nodes = []
	record.air = null

## A capture let go alive: none of it happened.
func release(id: int) -> void:
	for record in records.duplicate():
		if int(record.id) != id: continue
		drop_record(record)
		records.erase(record)

## The stage is over: the floor is clean again.
func clear() -> void:
	for record in records: drop_record(record)
	records.clear()

## Something of each kind to be drawn once on the loading screen
## (executions.warmup_props): a stain and a pool, both there.
func warmup_props() -> Array:
	var props: Array = []
	var stain_material := ShaderMaterial.new()
	stain_material.shader = STAIN
	stain_material.set_shader_parameter("atlas", ATLAS)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = quad()
	multi.instance_count = 1
	multi.set_instance_transform(0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.2, 0.01, 0.2)), Vector3.ZERO))
	multi.set_instance_custom_data(0, Color(0.0, 0.0, 0.0, 0.0))
	var stained := MultiMeshInstance3D.new()
	stained.multimesh = multi
	stained.material_override = stain_material
	props.append(stained)
	var pool_material := ShaderMaterial.new()
	pool_material.shader = POOL
	var reach: PackedFloat32Array = []
	for index in 16: reach.append(0.5)
	pool_material.set_shader_parameter("reach", reach)
	var pooled := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.4, 0.4)
	pooled.mesh = mesh
	pooled.material_override = pool_material
	props.append(pooled)
	return props
