extends RefCounted
## Which televisions a stage is played on: the sets that sit on the planta that
## stage opens, spread across its zones, well in from the lobby everyone comes
## out of the lift into. The second and third stages each get their own,
## counted apart -- lighting the sets of one planta says nothing about the
## next. Deterministic per seed, per stage and per number of survivors, and
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
## How far in a set has to be, walking from the lobby: this many metres, or
## this share of the way to the farthest room of the planta if that is more.
const MIN_FROM_ENTRANCE := 25.0
const SHARE_IN := 0.2

## How many have to be on for the stage to be met.
static func needed(survivors: int) -> int: return maxi(LEAST, survivors)

## The floor keeps only the sets it is played on. Every other "tv" of the
## hotel -- the first planta's, the refuges', the ones no stage chose -- is
## built as the cabinet it stood on (prop_factory's "tv_stand"), with no set on
## top: a dead set on a floor that asks for sets to be switched on was taken
## for a bug ("why does this one not come on?"). Done to the manifest before
## the hotel is built, the same on every machine (the seed and the number of
## survivors). Returns the sets of each stage, {2: [...], 3: [...]}, for
## hotel_main.place_televisions().
static func settle(manifest: Dictionary, survivors: int) -> Dictionary:
	var chosen := {}
	var kept := {}
	if not manifest.get("gates", []).is_empty():
		for stage in [2, 3]:
			chosen[stage] = choose(manifest, survivors, stage)
			for spot in chosen[stage]: kept["%d:%d" % [int(spot.room), int(spot.slot)]] = true
	for room in manifest.rooms:
		for prop in room.props:
			if prop.kind == "tv" and not kept.has("%d:%d" % [int(room.id), int(prop.slot)]): prop.kind = "tv_stand"
	return chosen

## Returns [{room, slot, position (world), yaw}] for the planta of a stage, as
## many as needed plus the spares. Stage 2 is the second planta, stage 3 the third.
static func choose(manifest: Dictionary, survivors: int, stage := 2) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([manifest.seed, "televisions", survivors, stage])
	var wing := stage - 1
	var metres := FLOOR.route_metres(manifest, FLOOR.entry_of(manifest, wing))
	var deepest := 0.0
	for id in metres: deepest = maxf(deepest, float(metres[id]))
	var least := maxf(MIN_FROM_ENTRANCE, deepest * SHARE_IN)
	var spots: Array = []
	var near: Array = []
	for room in manifest.rooms:
		if int(room.get("wing", 0)) != wing or int(manifest.refuges[wing]) == int(room.id) or bool(room.get("landing", false)): continue
		for prop in room.props:
			if prop.kind != "tv": continue
			var socket := GEOMETRY.prop_transform(room, prop)
			var spot := {"room": int(room.id), "slot": int(prop.slot), "sector": int(room.sector), "position": FLOOR.position_of(room) + socket.origin, "yaw": socket.basis.get_euler().y, "scale": socket.basis.get_scale().x, "metres": float(metres.get(int(room.id), 0.0))}
			if float(spot.metres) >= least: spots.append(spot)
			else: near.append(spot)
	# Shuffled with its own generator, then taken one per zone while that
	# lasts: the stage should not be four sets in the same corner.
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Dictionary = spots[i]
		spots[i] = spots[j]
		spots[j] = swap
	# A planta that had to put a set near the lobby still has its stage: the
	# farthest of those come after all the rest.
	near.sort_custom(func(one, two): return float(one.metres) > float(two.metres))
	spots.append_array(near)
	var wanted := needed(survivors) + SPARE
	var chosen: Array = []
	var used := {}
	for pass_index in 2:
		for spot in spots:
			if chosen.size() >= wanted: break
			if chosen.has(spot): continue
			if pass_index == 0 and (used.has(spot.sector) or float(spot.metres) < least): continue
			used[spot.sector] = true
			chosen.append(spot)
	for spot in chosen: spot.erase("metres")
	return chosen
