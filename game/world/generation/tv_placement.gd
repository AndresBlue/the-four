extends RefCounted
## Which televisions a floor's second stage is played on: the sets that sit in
## the wing that stage opens, spread across it, away from the door everyone
## comes in by. Deterministic per seed and per number of survivors, and
## independent of the map generator's own random sequence, so every machine
## picks the same ones without sending a list.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
## Two more than the stage asks for, so there is always a choice of which one
## to go for and one that nobody has to reach.
const SPARE := 2
## However few play, a stage of one television would be a corridor with a
## light switch.
const LEAST := 2
## Route metres from the wing's entrance below which a set is too easy.
const MIN_FROM_ENTRANCE := 14.0

## How many have to be on for the stage to be met.
static func needed(survivors: int) -> int: return maxi(LEAST, survivors)

## Returns [{room, position (world), yaw}] for the wing of a stage, as many as
## needed plus the spares.
static func choose(manifest: Dictionary, survivors: int, stage := 2) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([manifest.seed, "televisions", survivors, stage])
	var wing := stage - 1
	var entrance: Vector3 = FLOOR.position_of(manifest.rooms[int(manifest.entries[wing])]) if wing > 0 and manifest.get("entries", []).size() > wing else Vector3.ZERO
	var spots: Array = []
	for room in manifest.rooms:
		if int(room.get("wing", 0)) != wing or int(manifest.refuges[wing]) == int(room.id) or bool(room.get("landing", false)): continue
		if FLOOR.position_of(room).distance_to(entrance) < MIN_FROM_ENTRANCE: continue
		for prop in room.props:
			if prop.kind != "tv": continue
			var socket := GEOMETRY.prop_transform(room, prop)
			spots.append({"room": int(room.id), "sector": int(room.sector), "position": FLOOR.position_of(room) + socket.origin, "yaw": socket.basis.get_euler().y})
	# Shuffled with its own generator, then taken one per sector while that
	# lasts: the stage should not be four sets in the same corner.
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Dictionary = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var wanted := needed(survivors) + SPARE
	var chosen: Array = []
	var used := {}
	for pass_index in 2:
		for spot in spots:
			if chosen.size() >= wanted: break
			if chosen.has(spot): continue
			if pass_index == 0 and used.has(spot.sector): continue
			used[spot.sector] = true
			chosen.append(spot)
	return chosen
