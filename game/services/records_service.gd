extends Node
## The tapes that got out: one line per floor finished, kept between games and
## apart from everything else (settings, checkpoints, the archive of
## documents). What a run was is written once, when the floor ends, and never
## edited: the board is read out of these lines, sorted differently for each
## table.
##
## Alone and together are two different games -- a team lights more sets and
## has to get more people out -- so they are two boards, and a floor keeps its
## own (this hotel is floor 1; the other three will use the same shelf).
signal changed
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
var save_path := "user://records.json"
const VERSION := 1
## Lines kept per floor and company. Past this the slowest of them falls off,
## and a table is never longer than what a screen holds anyway.
const KEPT := 24
## How a run is played: on your own, or with anybody else on the floor.
const SOLO := "solo"
const COOP := "coop"
var runs: Array = []

## What each table sorts by and which runs it takes in. A table only shows a
## run that earned its place: nobody appears in "sin bajas" having lost
## somebody, so the list is a claim and not a filter of the same list.
const TABLES := [
	{"id": "time", "title": "MÁS RÁPIDOS", "note": "El piso entero, de la primera puerta al último ascensor."},
	{"id": "clean", "title": "SIN BAJAS", "note": "Nadie cayó en todo el piso: ni una muerte, ni un reinicio."},
	{"id": "brave", "title": "SIN ESCONDERSE", "note": "Nadie se metió en un armario en todo el piso."},
]

func _ready() -> void: load_records()

func load_records() -> void:
	runs.clear()
	if not FileAccess.file_exists(save_path): return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary or not data.get("runs") is Array: return
	for entry in data.runs:
		if entry is Dictionary and entry.has("time"): runs.append(entry)

## A floor finished. Returns the places it took, table id -> place (1 is the
## top), so the screen at the end can say what it just did.
func record(run: Dictionary) -> Dictionary:
	var line := {
		"floor": int(run.get("floor", 1)),
		"company": String(run.get("company", SOLO)),
		"players": int(run.get("players", 1)),
		"time": maxf(float(run.get("time", 0.0)), 0.0),
		"sectors": run.get("sectors", []),
		"deaths": int(run.get("deaths", 0)),
		"hides": int(run.get("hides", 0)),
		"escaped": int(run.get("escaped", 1)),
		"seed": int(run.get("seed", 0)),
		# The same seed is another floor under another generator, and a floor of
		# three plantas is not timed against one of three wings side by side.
		"generator": FLOOR.VERSION,
		"date": Time.get_datetime_string_from_system(false, true),
		"team": run.get("team", []),
	}
	runs.append(line)
	trim()
	save()
	changed.emit()
	var places := {}
	for table in TABLES:
		var board := table_of(String(table.id), line.floor, line.company)
		var place := board.find(line)
		if place >= 0: places[table.id] = place + 1
	return places

## The lines of one table, best first: every run of that floor and company that
## belongs in it, by time. Only the floors this generator makes: the lines of an
## older one stay in the file and off the board.
func table_of(id: String, floor_number: int, company: String) -> Array:
	var board: Array = runs.filter(func(line): return current(line) and int(line.get("floor", 1)) == floor_number and String(line.get("company", SOLO)) == company and belongs(id, line))
	board.sort_custom(func(a, b): return float(a.time) < float(b.time))
	return board

static func belongs(id: String, line: Dictionary) -> bool:
	match id:
		"clean": return int(line.get("deaths", 0)) == 0 and int(line.get("escaped", 0)) >= int(line.get("players", 1))
		"brave": return int(line.get("hides", 0)) == 0
	return true

## The distinctions a run carries, for the line and for the screen at the end.
static func badges(line: Dictionary) -> Array:
	var marks: Array = []
	if belongs("clean", line): marks.append("SIN BAJAS")
	if belongs("brave", line): marks.append("SIN ESCONDERSE")
	if int(line.get("players", 1)) > 1 and int(line.get("escaped", 0)) >= int(line.get("players", 1)): marks.append("EQUIPO ENTERO")
	return marks

## Whether anything has been written down for a floor at all.
func any(floor_number := 1) -> bool:
	return runs.any(func(line): return current(line) and int(line.get("floor", 1)) == floor_number)

## A line of the floors this generator makes (lines from before it was written
## down were generator 4).
static func current(line: Dictionary) -> bool:
	return int(line.get("generator", 4)) == FLOOR.VERSION

func trim() -> void:
	for floor_number in [1, 2, 3, 4]:
		for company in [SOLO, COOP]:
			var board := table_of("time", floor_number, company)
			for index in range(KEPT, board.size()): runs.erase(board[index])

func save() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"version": VERSION, "runs": runs}, "\t"))
	file.close()
