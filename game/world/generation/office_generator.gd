extends "res://game/world/generation/map_generator.gd"
## The offices' generator (docs/OFICINAS.md 11.3), as step 1a leaves it: the
## hotel's, drawn with the office palette, so that floor 2 has a manifest its
## validator, its kind and its tests stand on. Step 1b gives it its own
## (furnish(), the systems in the manifest). It never preloads
## office_floor.gd, which preloads it.
const OFFICE_PALETTE := preload("res://game/floors/palettes/office_palette.gd")
const OFFICE_VALIDATOR := preload("res://game/world/generation/office_validator.gd")

func _init() -> void: palette = OFFICE_PALETTE

func validator() -> RefCounted: return OFFICE_VALIDATOR.new()

## The hotel's try, said to be floor 2's: FLOOR.palette() and every reader in
## play pick the office palette by "floor", and a checkpoint or a match
## compares "version" with office_floor.GENERATOR_VERSION.
func candidate(run_seed: int, attempt: int, standby := false) -> Dictionary:
	var result := super.candidate(run_seed, attempt, standby)
	if not result.is_empty():
		result["floor"] = 2
		result["version"] = OFFICE_PALETTE.VERSION
	return result
