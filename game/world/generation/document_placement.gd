extends RefCounted
## Where a floor's documents lie: on tables, desks and nightstands, one to a
## planta at most, well in from where that planta is walked into, never in a
## refuge or a lift lobby. Deterministic per seed and independent of the map
## generator's own random sequence.
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const GEOMETRY := preload("res://game/world/hotel/hotel_geometry.gd")
const CATALOG := preload("res://game/discovery/discovery_catalog.gd")
const SURFACES := {"table": 0.84, "desk": 0.84, "nightstand": 0.84, "phone": 0.84}
const PER_FLOOR := 2
## How far in a document has to be, walking from the planta's entrance: this
## many metres, or this share of the way to its farthest room if that is more.
const MIN_FROM_START := 25.0
const SHARE_IN := 0.2

## Returns [{entry, position (world), yaw, room}] for the creature's floor.
static func choose(manifest: Dictionary, creature: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([manifest.seed, "documents"])
	var refuges: Array = manifest.get("refuges", [manifest.exit])
	var plantas := {}
	for room in manifest.rooms: plantas[int(room.get("wing", 0))] = true
	var reach := {}
	var least := {}
	for planta in plantas:
		var metres := FLOOR.route_metres(manifest, FLOOR.entry_of(manifest, planta))
		var deepest := 0.0
		for id in metres: deepest = maxf(deepest, float(metres[id]))
		reach[planta] = metres
		least[planta] = maxf(MIN_FROM_START, deepest * SHARE_IN)
	var spots: Array = []
	for room in manifest.rooms:
		var planta := int(room.get("wing", 0))
		if refuges.has(int(room.id)) or bool(room.get("landing", false)): continue
		if float(reach[planta].get(int(room.id), 0.0)) < float(least[planta]): continue
		for prop in room.props:
			if not SURFACES.has(prop.kind): continue
			var socket := GEOMETRY.prop_transform(room, prop)
			# Slightly off-centre on the top, turned a little, as if put down.
			var local := Vector3(rng.randf_range(-0.2, 0.2), SURFACES[prop.kind], rng.randf_range(-0.2, 0.1))
			var point: Vector3 = FLOOR.position_of(room) + socket * local
			spots.append({"room": room.id, "planta": planta, "position": point, "yaw": socket.basis.get_euler().y + rng.randf_range(-0.5, 0.5)})
	var entries: Array = CATALOG.for_creature(creature)
	var order := range(entries.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: int = order[i]
		order[i] = order[j]
		order[j] = swap
	var result: Array = []
	var used := {}
	for attempt in spots.size() * 2:
		if result.size() >= mini(PER_FLOOR, entries.size()) or spots.is_empty(): break
		var spot: Dictionary = spots[rng.randi_range(0, spots.size() - 1)]
		spots.erase(spot)
		if used.has(spot.planta): continue
		used[spot.planta] = true
		spot["entry"] = entries[order[result.size()]].id
		result.append(spot)
	return result
