extends RefCounted
## Every family of the offices' pieces made in code (spec_rediseno.md 5.1,
## area 4a), for the piece sheet (tools/capture/office_pieces_sheet.gd), its
## test and the rooms that will place them.
const FAMILIES := [
	preload("res://game/world/office/pieces/desks.gd"),
	preload("res://game/world/office/pieces/cabinets.gd"),
	preload("res://game/world/office/pieces/storage.gd"),
	preload("res://game/world/office/pieces/machines.gd"),
	preload("res://game/world/office/pieces/movables.gd"),
	preload("res://game/world/office/pieces/stationery.gd"),
	preload("res://game/world/office/pieces/wall.gd"),
	preload("res://game/world/office/pieces/fixtures.gd"),
	preload("res://game/world/office/pieces/mail_equipment.gd"),
	preload("res://game/world/office/pieces/power_equipment.gd"),
	preload("res://game/world/office/pieces/air_equipment.gd"),
]

## Every sample of every family, in that order: [name, mesh] pairs.
static func samples(builder: Node3D) -> Array:
	var all: Array = []
	for family in FAMILIES: all.append_array(family.samples(builder))
	return all
