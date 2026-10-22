extends RefCounted
## The four numbers of the code, and where they are: in drawers, shelves and
## cupboards of the planta the last stage is played on, each in a different
## zone, well in from the lobby, one of them past four fifths of the way to
## the refuge, and never in the refuge. Deterministic per seed, like the
## documents and the televisions, so every machine hides them in the same
## places without sending anything.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const COUNT := 4
## How far in a number has to be, walking from the lobby: this many metres,
## or this share of the way to the farthest room if that is more.
const MIN_FROM_ENTRANCE := 30.0
const SHARE_IN := 0.25
## One of them is this far along the way to the refuge, or further.
const DEEP := 0.8

## The code itself: four digits, in the order they are read into the lock.
static func code(manifest: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([manifest.seed, "code"])
	var digits: Array = []
	for slot in COUNT: digits.append(rng.randi_range(0, 9))
	return digits

## The pieces of furniture that never hold a page of the code.
const NO_PAGES := ["luggage"]

## Returns [{container (index into the floor's containers), slot, digit}].
static func choose(manifest: Dictionary, containers: Array, stage := 3) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([manifest.seed, "digits", stage])
	var wing := stage - 1
	var metres := FLOOR.route_metres(manifest, FLOOR.entry_of(manifest, wing))
	var deepest := 0.0
	for id in metres: deepest = maxf(deepest, float(metres[id]))
	var least := maxf(MIN_FROM_ENTRANCE, deepest * SHARE_IN)
	var refuge_at: float = float(metres.get(int(manifest.refuges[wing]), deepest))
	var spots: Array = []
	for index in containers.size():
		var spot: Dictionary = containers[index]
		var room: Dictionary = manifest.rooms[int(spot.room)]
		if int(room.get("wing", 0)) != wing or int(manifest.refuges[wing]) == int(room.id) or bool(room.get("landing", false)): continue
		# A suitcase holds only what is not needed (the author's word, 21
		# October 2026): never a number.
		if NO_PAGES.has(String(spot.get("kind", ""))): continue
		spots.append({"index": index, "sector": int(room.sector), "room": int(room.id), "metres": float(metres.get(int(room.id), 0.0))})
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Dictionary = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	var digits := code(manifest)
	var chosen: Array = []
	var used_rooms := {}
	var used_sectors := {}
	var take := func(spot: Dictionary) -> void:
		used_sectors[spot.sector] = true
		used_rooms[spot.room] = true
		chosen.append({"container": int(spot.index), "slot": chosen.size() + 1, "digit": int(digits[chosen.size()])})
	# The first one deep: past four fifths of the way to the refuge.
	for spot in spots:
		if float(spot.metres) >= refuge_at * DEEP:
			take.call(spot)
			break
	for pass_index in 4:
		for spot in spots:
			if chosen.size() >= COUNT: break
			if used_rooms.has(spot.room): continue
			# One per zone well in while that lasts, then one per room well in,
			# then one per room anywhere: a floor is never so poor that the
			# code cannot be hidden.
			if pass_index == 0 and (used_sectors.has(spot.sector) or float(spot.metres) < least): continue
			if pass_index == 1 and float(spot.metres) < least: continue
			take.call(spot)
	return chosen
