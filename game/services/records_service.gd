extends Node
## The tapes that got out, and everything else a player keeps between games
## that is not a setting, a checkpoint or the archive of documents:
##
## - the boards: one line per floor finished, written once and never edited;
##   each table is those same lines sorted its own way (TABLES);
## - the career: what this player has done over every floor, won or lost;
## - the milestones of each floor, with the day each was first reached;
## - the cards of the people played with, to set beside one's own.
##
## Alone and together are different games -- a team lights more sets and has
## to get more people out -- and so is a floor with a player as the creature:
## they are three boards, and each floor keeps its own. A floor played by
## other rules goes on a fourth.
signal changed
const FLOOR := preload("res://game/world/generation/floor_definition.gd")
const SCORE := preload("res://game/services/run_score.gd")
const FLOORS := preload("res://game/floors/floor_index.gd")
var save_path := "user://records.json"
const VERSION := 2
## Lines a table shows. A board keeps the ones that are in any of its tables.
const KEPT := 24
## How a run is played: on your own, with anybody else on the floor, or with
## one of the players as The Locust.
const SOLO := "solo"
const COOP := "coop"
const VERSUS := "versus"
## And a fourth board for every floor played by other rules than the game's
## own (game/floors/match_rules.gd), whoever played it: each line says which.
const CUSTOM := "custom"
const COMPANIES := [SOLO, COOP, VERSUS, CUSTOM]
const COMPANY_NAMES := {SOLO: "EN SOLITARIO", COOP: "ACOMPAÑADO", VERSUS: "CONTRA EL CAZADOR", CUSTOM: "CON OTRAS REGLAS"}
const RULES := preload("res://game/floors/match_rules.gd")
const DIFFICULTY := preload("res://game/floors/difficulty.gd")
var runs: Array = []
## What this player has added up over every floor (tally()).
var career := {}
## "floor:id" -> the day it was first reached.
var milestones := {}
## The cards of the people played with, by their own id (keep_card()).
var rivals := {}
const RIVALS_KEPT := 24
## Who this file belongs to, said to the others with the card: a name can be
## changed and two people can share one, so it is not what tells them apart.
var id := ""

## What each table sorts by and which runs it takes in. A table only shows a
## run that earned its place: nobody appears in "sin bajas" having lost
## somebody, so the list is a claim and not a filter of the same list.
const TABLES := [
	{"id": "time", "title": "MÁS RÁPIDOS", "note": "El piso entero, de la primera puerta al último ascensor."},
	{"id": "score", "title": "MAYOR PUNTAJE", "note": "Lo que hizo cada uno y lo que ganó el equipo junto."},
	{"id": "clean", "title": "SIN BAJAS", "note": "Nadie cayó en todo el piso: ni una muerte, ni un reinicio."},
	{"id": "brave", "title": "SIN ESCONDERSE", "note": "Nadie se metió en un armario en todo el piso."},
]

func _ready() -> void: load_records()

func load_records() -> void:
	runs.clear()
	career = {}
	milestones = {}
	rivals = {}
	id = ""
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path)) if FileAccess.file_exists(save_path) else null
	if data is Dictionary:
		if data.get("runs") is Array:
			for entry in data.runs:
				if entry is Dictionary and entry.has("time"): runs.append(entry)
		if data.get("career") is Dictionary: career = data.career
		if data.get("milestones") is Dictionary: milestones = data.milestones
		if data.get("rivals") is Dictionary:
			for key in data.rivals:
				if data.rivals[key] is Dictionary: rivals[String(key)] = data.rivals[key]
		id = String(data.get("id", ""))
		# A file from before there was a career: what its lines can still say.
		if int(data.get("version", 1)) < 2:
			for line in runs:
				tally(line, 0)
				reach(line, 0)
	if id.is_empty():
		var draw := RandomNumberGenerator.new()
		draw.randomize()
		id = "%08x%08x" % [draw.randi(), draw.randi()]

## A floor finished and got out. Returns the places it took, table id -> place
## (1 is the top), so the screen at the end can say what it just did.
func record(run: Dictionary) -> Dictionary:
	var line := clean(run)
	if not line.has("score"): SCORE.settle(line)
	line["generator"] = FLOOR.VERSION
	line["date"] = Time.get_datetime_string_from_system(false, true)
	runs.append(line)
	trim()
	save()
	changed.emit()
	return places_of(line)

## Where a line stands in each table of its board.
func places_of(line: Dictionary) -> Dictionary:
	var places := {}
	for table in TABLES:
		var place := table_of(String(table.id), int(line.floor), String(line.company)).find(line)
		if place >= 0: places[table.id] = place + 1
	return places

## A floor is over, won or lost, and `seat` is where this machine's player sat
## in it (0: nowhere, a line that is only kept). The line goes on the board if
## it got out and `listed` (a floor that is nobody's game leaves no line); the
## career and the milestones take it either way. Returns what the screen at the
## end says about it: {places, milestones (the new ones), previous (the best
## time and points of the board before it, -1 without any, and its best
## sectors)}.
func file(run: Dictionary, seat: int, listed := true) -> Dictionary:
	var floor_number := int(run.get("floor", 1))
	var company := String(run.get("company", SOLO))
	var previous := {"time": best(floor_number, company, "time"), "score": best(floor_number, company, "score"), "splits": best_splits(floor_number, company)}
	var outcome := {"places": {}, "milestones": [], "previous": previous}
	if not listed: return outcome
	var line := clean(run)
	if not line.has("score"): SCORE.settle(line)
	tally(line, seat)
	outcome.milestones = reach(line, seat)
	if SCORE.won(line): outcome.places = record(run)
	else:
		save()
		changed.emit()
	return outcome

## The line as it is kept: only what a line has, each thing of its own kind
## and no longer than it can be. What a guest files is what its host sent, and
## what is read back went through a text file.
static func clean(run: Dictionary) -> Dictionary:
	var line := {
		"floor": clampi(int(run.get("floor", 1)), 1, FLOORS.COUNT),
		"company": String(run.get("company", SOLO)) if String(run.get("company", SOLO)) in COMPANIES else SOLO,
		"mode": String(run.get("mode", "")).left(12),
		"result": "lost" if String(run.get("result", "won")) == "lost" else "won",
		"players": clampi(int(run.get("players", 1)), 1, 8),
		"time": clampf(number(run.get("time", 0.0)), 0.0, 360000.0),
		"par": clampf(number(run.get("par", 0.0)), 0.0, 360000.0),
		"stage": clampi(int(number(run.get("stage", 1))), 1, 16),
		"sectors": [],
		"deaths": maxi(int(number(run.get("deaths", 0))), 0),
		"hides": maxi(int(number(run.get("hides", 0))), 0),
		"restarts": maxi(int(number(run.get("restarts", 0))), 0),
		"escaped": maxi(int(number(run.get("escaped", 1))), 0),
		"seed": int(number(run.get("seed", 0))),
		# A tape from before there were difficulties was played on this one.
		"difficulty": DIFFICULTY.valid(run.get("difficulty")),
		"team": [],
		"events": [],
	}
	if run.get("sectors") is Array:
		for value in (run.sectors as Array).slice(0, 16): line.sectors.append(number(value))
	if run.get("team") is Array:
		for member in (run.team as Array).slice(0, 8):
			if member is Dictionary: line.team.append(clean_member(member))
	if run.get("events") is Array:
		for event in (run.events as Array).slice(0, EVENTS_KEPT):
			if not event is Dictionary: continue
			var entry := {"t": number(event.get("t", 0.0)), "k": String(event.get("k", "")).left(12), "s": int(number(event.get("s", 0))), "st": int(number(event.get("st", 1)))}
			if event.has("n"): entry["n"] = int(number(event.n))
			if event.has("of"): entry["of"] = int(number(event.of))
			if event.has("w"): entry["w"] = String(event.w).left(40)
			line.events.append(entry)
	var differs := RULES.changed(run.get("rules", {}))
	if not differs.is_empty(): line["rules"] = differs
	if run.get("hunter") is Dictionary: line["hunter"] = {"seat": int(number(run.hunter.get("seat", 0))), "name": String(run.hunter.get("name", "")).left(24)}
	# Settled by whoever ran the floor: kept as it was said.
	if run.has("score"):
		line["score"] = maxi(int(number(run.score)), 0)
		line["grade"] = String(run.get("grade", "")).left(1)
		line["mvp"] = int(number(run.get("mvp", 0)))
	for key in ["generator", "date"]:
		if run.has(key): line[key] = run[key]
	return line
const EVENTS_KEPT := 120
## What a survivor's line may carry that is a count.
const MEMBER_COUNTS := ["digits", "tvs", "code", "searched", "rooms", "escapes", "chases", "chased", "sectors", "deaths", "hides", "hidden", "metres", "run", "low", "burnt", "lifts", "encounters", "quiet", "score"]

static func clean_member(member: Dictionary) -> Dictionary:
	var out := {"seat": int(number(member.get("seat", 0))), "name": String(member.get("name", "")).left(24), "escaped": bool(member.get("escaped", true))}
	for key in MEMBER_COUNTS:
		if member.has(key): out[key] = maxi(int(number(member[key])), 0)
	if member.has("closest"): out["closest"] = snappedf(number(member.closest), 0.1)
	for key in ["title", "why"]:
		if member.has(key): out[key] = String(member[key]).left(60)
	return out

static func number(value: Variant) -> float:
	return float(value) if (value is float or value is int) and is_finite(float(value)) else 0.0

## The lines of one table, best first: every run of that floor and company that
## belongs in it, in the table's own order, and no more than it shows. Only the
## floors this generator makes: the lines of an older one stay in the file and
## off the board.
func table_of(table: String, floor_number: int, company: String) -> Array:
	var board: Array = runs.filter(func(line): return current(line) and SCORE.won(line) and int(line.get("floor", 1)) == floor_number and String(line.get("company", SOLO)) == company and belongs(table, line))
	if table == "score": board.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)) or (int(a.get("score", 0)) == int(b.get("score", 0)) and float(a.time) < float(b.time)))
	else: board.sort_custom(func(a, b): return float(a.time) < float(b.time))
	return board.slice(0, KEPT)

static func belongs(table: String, line: Dictionary) -> bool:
	match table:
		"clean": return int(line.get("deaths", 0)) == 0 and int(line.get("escaped", 0)) >= int(line.get("players", 1))
		"brave": return int(line.get("hides", 0)) == 0
	return true

## The best of a board so far: its quickest time or its most points; -1 on a
## board nobody is on yet.
func best(floor_number: int, company: String, what: String) -> float:
	var board := table_of(what, floor_number, company)
	return float(board[0].get(what, 0.0)) if not board.is_empty() else -1.0

## The quickest each sector of a floor has been closed on a board, one by one
## (not the sectors of its quickest tape): what a sector is measured against.
func best_splits(floor_number: int, company: String) -> Array:
	var quickest: Array = []
	for line in table_of("time", floor_number, company):
		var before := 0.0
		var marks: Array = line.get("sectors", [])
		for index in marks.size():
			var took := float(marks[index]) - before
			before = float(marks[index])
			if index >= quickest.size(): quickest.append(took)
			elif took < float(quickest[index]): quickest[index] = took
	return quickest

## The distinctions a run carries, for the line and for the screen at the end.
static func badges(line: Dictionary) -> Array:
	var marks: Array = []
	if not SCORE.won(line): return marks
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

## Off the file goes every line of this generator that is in none of its
## board's tables any more.
func trim() -> void:
	var kept := {}
	for floor_number in range(1, FLOORS.COUNT + 1):
		for company in COMPANIES:
			for table in TABLES:
				for line in table_of(String(table.id), floor_number, company): kept[line] = true
	runs = runs.filter(func(line): return not current(line) or kept.has(line))

# --- The career -------------------------------------------------------------------

## What the career counts out of the line of whoever sat in `seat`.
const CAREER_COUNTS := ["tvs", "digits", "code", "searched", "escapes", "hides", "hidden", "metres", "deaths"]

## A floor added to the career: the floor itself whoever it was, and what the
## one in `seat` did in it (nothing more with seat 0, a line read from an old
## file).
func tally(line: Dictionary, seat: int) -> void:
	var won := SCORE.won(line)
	var hunter := seat != 0 and int(line.get("hunter", {}).get("seat", 0)) == seat
	if hunter:
		bump("hunts", 1)
		bump("catches", int(line.get("deaths", 0)))
		if not won: bump("hunts_won", 1)
		return
	bump("floors" if won else "lost", 1)
	bump("time", int(line.get("time", 0.0)))
	var me := SCORE.member_of(line, seat)
	if me.is_empty(): return
	for key in CAREER_COUNTS: bump(key, int(me.get(key, 0)))
	if won and bool(me.get("escaped", false)): bump("escaped", 1)
	if won and int(line.get("mvp", 0)) == seat: bump("mvps", 1)
	if won and not line.has("rules"):
		career["best_score"] = maxi(int(career.get("best_score", 0)), int(line.get("score", 0)))
		var grade := String(line.get("grade", ""))
		if not grade.is_empty() and (String(career.get("best_grade", "")).is_empty() or SCORE.grade_at_least(grade, String(career.get("best_grade", "")))): career["best_grade"] = grade
	var part := String(me.get("title", ""))
	if not part.is_empty():
		var parts: Dictionary = career.get("titles", {})
		parts[part] = int(parts.get(part, 0)) + 1
		career["titles"] = parts

func bump(key: String, amount: int) -> void:
	career[key] = int(career.get(key, 0)) + amount

## The part played most often, or "" before any.
func usual_part() -> String:
	var parts: Dictionary = career.get("titles", {})
	var usual := ""
	for part in parts:
		if usual.is_empty() or int(parts[part]) > int(parts[usual]): usual = String(part)
	return usual

# --- The milestones ---------------------------------------------------------------

## The milestones of its floor a line reaches for the first time, written
## down with today's date: their ids.
func reach(line: Dictionary, seat: int) -> Array:
	var floor_number := int(line.get("floor", 1))
	var fresh: Array = []
	# A milestone is reached by the game's own rules, or it says nothing.
	if line.has("rules"): return fresh
	for milestone in SCORE.earned(FLOORS.milestones(floor_number), line, seat):
		var key := "%d:%s" % [floor_number, milestone]
		if milestones.has(key): continue
		milestones[key] = String(line.get("date", Time.get_datetime_string_from_system(false, true))).left(10)
		fresh.append(milestone)
	return fresh

## The day a milestone was reached, or "" if it has not been.
func reached(floor_number: int, milestone: String) -> String:
	return String(milestones.get("%d:%s" % [floor_number, milestone], ""))

func reached_count(floor_number := 0) -> int:
	if floor_number == 0: return milestones.size()
	return milestones.keys().filter(func(key): return String(key).begins_with("%d:" % floor_number)).size()

# --- The cards --------------------------------------------------------------------

## What the card says, in the order it is read: [key, what it is called, how
## it is written ("count", "time", "clock": the less the better, "grade") and
## whether more of it is better].
const CARD_ROWS := [
	["floors", "PISOS SUPERADOS", "count", true],
	["lost", "CINTAS PERDIDAS", "count", false],
	["solo_time", "MEJOR TIEMPO A SOLAS", "clock", false],
	["coop_time", "MEJOR TIEMPO EN EQUIPO", "clock", false],
	["best_score", "MEJOR PUNTAJE", "count", true],
	["best_grade", "MEJOR NOTA", "grade", true],
	["mvps", "VECES MÁS VALIOSO", "count", true],
	["tvs", "TELEVISORES", "count", true],
	["digits", "NÚMEROS DEL CÓDIGO", "count", true],
	["escapes", "HUIDAS", "count", true],
	["deaths", "CAÍDAS", "count", false],
	["time", "TIEMPO GRABADO", "time", true],
	["milestones", "HITOS", "count", true],
]

## This player's card: who it is and what its career comes to, to be read
## beside somebody else's.
func card(player_name: String) -> Dictionary:
	var out := {"id": id, "name": player_name.strip_edges().left(18), "part": usual_part()}
	for row in CARD_ROWS:
		match String(row[0]):
			"solo_time": out["solo_time"] = int(best(1, SOLO, "time"))
			"coop_time": out["coop_time"] = int(best(1, COOP, "time"))
			"best_grade": out["best_grade"] = String(career.get("best_grade", ""))
			"milestones": out["milestones"] = milestones.size()
			_: out[row[0]] = int(career.get(row[0], 0))
	return out

## Somebody else's card, kept as it was last said: every floor played with
## them brings a newer one. What arrives is taken as words from a stranger --
## the right keys, of the right kind, and nothing else.
func keep_card(said: Dictionary) -> void:
	var who := String(said.get("id", "")).left(32)
	if who.is_empty() or who == id: return
	var kept := {"id": who, "name": String(said.get("name", "")).strip_edges().replace("\n", " ").left(18), "part": String(said.get("part", "")).left(24)}
	if String(kept.name).is_empty(): kept.name = "Jugador"
	for row in CARD_ROWS:
		var key := String(row[0])
		if String(row[2]) == "grade": kept[key] = String(said.get(key, "")).left(1)
		else: kept[key] = clampi(int(number(said.get(key, 0))), -1, 99999999)
	kept["seen"] = Time.get_datetime_string_from_system(false, true)
	kept["together"] = int(rivals.get(who, {}).get("together", 0))
	rivals[who] = kept
	# Past what is kept, whoever was seen longest ago goes.
	while rivals.size() > RIVALS_KEPT:
		var oldest := ""
		for key in rivals:
			if oldest.is_empty() or String(rivals[key].get("seen", "")) < String(rivals[oldest].get("seen", "")): oldest = String(key)
		rivals.erase(oldest)
	save()
	changed.emit()

## One more floor ended with them on it.
func played_with(who: String) -> void:
	if rivals.has(who): rivals[who]["together"] = int(rivals[who].get("together", 0)) + 1

## The cards kept, whoever was seen last first.
func rival_cards() -> Array:
	var cards: Array = rivals.values()
	cards.sort_custom(func(a, b): return String(a.get("seen", "")) > String(b.get("seen", "")))
	return cards

func save() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"version": VERSION, "id": id, "runs": runs, "career": career, "milestones": milestones, "rivals": rivals}, "\t"))
	file.close()
