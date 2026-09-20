extends RefCounted
## The four numbers of the code, and where they are: in drawers, shelves and
## cupboards of the wing the last stage is played in, each in a different
## sector and never in its refuge. Deterministic per seed, like the documents
## and the televisions, so every machine hides them in the same places without
## sending anything.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const COUNT := 4
## Route metres from the wing's entrance below which a number is too easy.
const MIN_FROM_ENTRANCE := 12.0

## The code itself: four digits, in the order they are read into the lock.
static func code(manifest: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([manifest.seed, "code"])
	var digits: Array = []
	for slot in COUNT: digits.append(rng.randi_range(0, 9))
	return digits

## Returns [{container (index into the floor's containers), slot, digit}].
static func choose(manifest: Dictionary, containers: Array, stage := 3) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([manifest.seed, "digits", stage])
	var wing := stage - 1
	var entrance: Vector3 = FLOOR.position_of(manifest.rooms[int(manifest.gates[wing - 1].beyond)]) if wing > 0 and manifest.gates.size() >= wing else Vector3.ZERO
	var spots: Array = []
	for index in containers.size():
		var spot: Dictionary = containers[index]
		var room: Dictionary = manifest.rooms[int(spot.room)]
		if int(room.get("wing", 0)) != wing or int(manifest.refuges[wing]) == int(room.id): continue
		if Vector3(spot.position).distance_to(entrance) < MIN_FROM_ENTRANCE: continue
		spots.append({"index": index, "sector": int(room.sector), "room": int(room.id)})
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Dictionary = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var digits := code(manifest)
	var chosen: Array = []
	var used_rooms := {}
	var used_sectors := {}
	for pass_index in 3:
		for spot in spots:
			if chosen.size() >= COUNT: break
			if used_rooms.has(spot.room): continue
			# One per sector while that lasts, then one per room, then whatever
			# is left: a floor is never so poor that the code cannot be hidden.
			if pass_index == 0 and used_sectors.has(spot.sector): continue
			used_sectors[spot.sector] = true
			used_rooms[spot.room] = true
			chosen.append({"container": int(spot.index), "slot": chosen.size() + 1, "digit": int(digits[chosen.size()])})
	return chosen
