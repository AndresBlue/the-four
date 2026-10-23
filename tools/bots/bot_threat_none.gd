extends "res://tools/bots/bot_threat.gd"
## The model of a floor whose creature is the null one (the offices before
## The Lurker, game/enemies/null_creature.gd): nothing to mind, ever, and
## nothing of it in a recording.

func refresh() -> void:
	creature = null
	active = false
	path_rooms.clear()
	danger.clear()
	vantages.clear()
	future.clear()
	search_points.clear()
	sight_cache.clear()
	landing = Vector3.INF

func leaving() -> bool: return false

func recorded_row() -> Array: return []

func recorded_route() -> Variant: return null

func recorded_watch() -> Dictionary: return {}

func recorded_mode_change() -> Dictionary: return {}

func on_gave_up(_heard: Callable) -> void: pass

func on_stuck(_it, _escalated: Callable, _abandoned: Callable) -> void: pass
