extends Node3D
## Her doubles (the author's Doppelganger, 18 November 2026): whoever drives
## her in Versus leaves one (lurker_double, every DOUBLE_EVERY s, as many as
## she likes up to MOST alive), her own body upside down in a corner of the
## room she is in or over, lying in wait. Somebody who comes within
## POUNCE_REACH of it without having made it out is leapt at: her face in
## theirs for POUNCE_TIME, her shriek, MIND.double off their mind (less each
## time on the same survivor, as her parries), and it is gone. Made out first
## (in view SEEN_FOR s on end, lit or by a torch within SEEN_LIT, or within
## SEEN_DARK in the dark), it bolts up into the ceiling and costs whoever saw
## it MIND.double_seen. It never takes anybody.
##
## On every machine from her "double" events (lurker.on_event()): "set" puts
## one where she left it, "pounce" and "flee" end it. Only the machine in
## charge judges (judge()). A mind gone (SIGHT.spent()) makes nothing out.
const VISUAL := preload("res://game/enemies/lurker/lurker.tscn")
const POSER := preload("res://game/app/hallucinations/lurker_poser.gd")
const SIGHT := preload("res://game/enemies/creature_sight.gd")
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const BRAIN := preload("res://game/enemies/lurker/lurker_brain.gd")
const MOST := 12
const POUNCE_REACH := 3.5
const SEEN_FOR := 0.3
const SEEN_LIT := 10.0
const SEEN_DARK := 4.0
## How near the middle of a view it must be to be made out (sanity sees her
## within the same), and a torch's beam on it.
const SEEN_DOT := 0.72
const TORCH_ANGLE := 25.0
## In from the corner's two walls, its head this far under the ceiling.
const CORNER_IN := 0.45
const UNDER_CEILING := 0.55
## Its leap at a face, and its bolt up.
const POUNCE_TIME := 0.5
const FLEE_TIME := 0.35
const FLEE_UP := 0.9
## The head bone the hallucinations pose by (lurker_hallucinations.HEAD).
const HEAD := "head"

var creature
var level
## id -> {node, poser, room, state ("wait", "pounce", "flee"), clock, seen
## {seat: s}, from, seat}.
var doubles := {}
var next_id := 1
## For the tests and the bots' count: pounces and bolts so far.
var pounces := 0
var bolts := 0

func setup(owner) -> void:
	creature = owner
	level = owner.level
	name = "Doubles"
	top_level = true

## Where a double of hers would wait in `room`, the corner nearest `near`:
## {point (her origin), yaw}; {} for a room that takes none.
func corner_of(room: int, near: Vector3) -> Dictionary:
	if room < 0: return {}
	var data: Dictionary = level.manifest.rooms[room]
	if FLOOR.is_void(data) or level.point_protected(FLOOR.position_of(data)): return {}
	var centre := FLOOR.position_of(data)
	var half := FLOOR.size_of(data) * 0.5 - Vector2(CORNER_IN, CORNER_IN)
	if half.x <= 0.2 or half.y <= 0.2: return {}
	var top := float(data.get("py", centre.y)) + float(data.get("height", 2.95))
	var best := {}
	var best_gap := INF
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at := Vector3(centre.x + corner.x * half.x, top, centre.z + corner.y * half.y)
		var gap := Vector2(at.x - near.x, at.z - near.z).length()
		if gap < best_gap:
			best_gap = gap
			var inward := Vector3(centre.x - at.x, 0, centre.z - at.z).normalized()
			best = {"point": at, "yaw": atan2(inward.x, inward.z)}
	return best

## One put where she left it (event "set"): her body upside down, still.
func put(id: int, room: int, point: Vector3, yaw: float) -> void:
	if doubles.has(id): return
	var model: Node3D = VISUAL.instantiate()
	model.name = "Double_%d" % id
	add_child(model)
	model.set("crawling", false)
	model.set("look_point", Vector3.INF)
	var facing := Vector3(sin(yaw), 0, cos(yaw))
	model.global_transform = Transform3D(Basis.looking_at(-facing, Vector3.DOWN), point)
	var poser = POSER.new(model)
	poser.pose_stare(0.0)
	# Its head where hers would be, a hand under the ceiling.
	model.global_position.y += (point.y - UNDER_CEILING) - poser.point(HEAD).y
	poser.pose_stare(0.0)
	doubles[id] = {"node": model, "poser": poser, "room": room, "state": "wait", "clock": 0.0, "seen": {}, "from": model.global_position, "seat": -1}
	next_id = maxi(next_id, id + 1)

## Its head now.
func head_of(id: int) -> Vector3:
	var one: Dictionary = doubles[id]
	return one.poser.point(HEAD) if is_instance_valid(one.node) else Vector3.INF

## The events, on every machine.
func on_event(data: Array) -> void:
	if data.size() < 2: return
	var id := int(data[0])
	match String(data[1]):
		"set":
			if data.size() >= 5: put(id, int(data[2]), data[3], float(data[4]))
		"pounce":
			if doubles.has(id): pounce(id, int(data[2]) if data.size() >= 3 else -1)
		"flee":
			if doubles.has(id): flee(id)
		"gone":
			drop(id)

func pounce(id: int, seat: int) -> void:
	var one: Dictionary = doubles[id]
	one.state = "pounce"
	one.clock = 0.0
	one.seat = seat
	one.from = (one.node as Node3D).global_position
	pounces += 1
	var head := head_of(id)
	var audio = level.get("world_audio")
	var path: String = BRAIN.SCARE_SOUNDS[next_id % BRAIN.SCARE_SOUNDS.size()]
	if audio != null and audio.has_method("play_at"): audio.play_at(path, head, BRAIN.SCARE_GAIN)
	# The tape jolts on the machine of whoever it leapt at.
	var player = level.get("player")
	if player != null and "slot" in player and int(player.slot) == seat and level.get("sanity") != null: level.sanity.glitch = 1.0

func flee(id: int) -> void:
	var one: Dictionary = doubles[id]
	one.state = "flee"
	one.clock = 0.0
	one.from = (one.node as Node3D).global_position
	bolts += 1

func drop(id: int) -> void:
	if not doubles.has(id): return
	var one: Dictionary = doubles[id]
	if is_instance_valid(one.node): one.node.queue_free()
	doubles.erase(id)

## Every one gone (a stage given back, a floor ended).
func clear() -> void:
	for id in doubles.keys(): drop(int(id))

func _process(delta: float) -> void:
	for id in doubles.keys():
		var one: Dictionary = doubles[id]
		if String(one.state) == "wait" or not is_instance_valid(one.node): continue
		one.clock = float(one.clock) + delta
		var node: Node3D = one.node
		if String(one.state) == "pounce":
			var body = creature.senses.body_of(int(one.seat)) if creature.senses != null else null
			var share := clampf(float(one.clock) / POUNCE_TIME, 0.0, 1.0)
			if body != null:
				var face: Vector3 = body.camera.global_position - body.camera.global_basis.z * 0.45
				node.global_position = (one.from as Vector3).lerp(face - (head_of(int(id)) - node.global_position), share * share)
			if share >= 1.0: drop(int(id))
		else:
			var share := clampf(float(one.clock) / FLEE_TIME, 0.0, 1.0)
			node.global_position = (one.from as Vector3) + Vector3.UP * FLEE_UP * share
			if share >= 1.0: drop(int(id))

## On the machine in charge, every tick: who makes each out, who walks into
## one. Told to every machine through her events.
func judge(delta: float) -> void:
	for id in doubles.keys():
		var one: Dictionary = doubles[id]
		if String(one.state) != "wait": continue
		var head := head_of(int(id))
		if head == Vector3.INF: continue
		var planta := FLOOR.planta_of(head.y - 1.5)
		var pounce_on := -1
		for body in level.survivors():
			if not is_instance_valid(body) or not "slot" in body or not SIGHT.alive(level, body) or not level.survivor_active(body) or bool(body.get("hidden")): continue
			var eye: Vector3 = body.camera.global_position
			if FLOOR.planta_of(eye.y - 1.0) != planta: continue
			var seat := int(body.slot)
			var seen: Dictionary = one.seen
			if makes_out(body, head): seen[seat] = float(seen.get(seat, 0.0)) + delta
			else: seen[seat] = 0.0
			if float(seen[seat]) >= SEEN_FOR:
				creature.tell_all("double", [int(id), "flee", seat])
				var mind = level.get("sanity")
				if mind != null and mind.has_method("fright"): mind.fright(body, float(creature.MIND.double_seen))
				pounce_on = -2
				break
			if pounce_on == -1 and eye.distance_to(head) <= POUNCE_REACH and not level.point_protected(body.global_position): pounce_on = seat
		if pounce_on >= 0:
			creature.tell_all("double", [int(id), "pounce", pounce_on])
			var mind = level.get("sanity")
			var victim = creature.senses.body_of(pounce_on)
			if mind != null and mind.has_method("fright") and victim != null: mind.fright(victim, creature.double_cost(pounce_on))

## Whether `body` makes out a head here now: in the middle of its view, nothing
## between, and lit (the room, or its torch on it within SEEN_LIT), or within
## SEEN_DARK. A mind gone makes nothing out.
func makes_out(body, head: Vector3) -> bool:
	if SIGHT.spent(level, body): return false
	var eye: Vector3 = body.camera.global_position
	var to := head - eye
	var gap := to.length()
	if gap > SEEN_LIT or gap < 0.05: return false
	var ahead: Vector3 = -body.camera.global_basis.z
	if ahead.dot(to / gap) < SEEN_DOT: return false
	if not SIGHT.clear(level, eye, head, [body.get_rid(), creature.get_rid()]): return false
	if gap <= SEEN_DARK or SIGHT.lit_point(level, head): return true
	var torch = body.get("torch")
	return is_instance_valid(torch) and torch.visible and rad_to_deg(ahead.angle_to(to)) <= TORCH_ANGLE
