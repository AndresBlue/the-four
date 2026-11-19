extends SceneTree
## The offices' paper filled in (game/ui/office_memo.gd), to look at: each
## memorandum below on the author's sheet, at the sheet's own size. With a
## window:
##   godot --path . --script res://tools/capture/memo_capture.gd --log-file <log> -- --automation --test-profile --silent
## Writes evidence/planta/papeles/<name>.png. The words are the proposal of
## .claude/specs/piso2_documentos.md: not the game's until the author says.
const MEMO := preload("res://game/ui/office_memo.gd")
const OUT := "res://evidence/planta/papeles"
const SHEETS := {
	"memo_1_mantencion": {"date": "14.03.19__", "to": "Servicios Generales", "from": "T. Requena, Mantención", "subject": "Ductos sobre la sala R-214", "cc": "Jefatura de planta", "seed": 214,
		"lines": ["Tercera vez este mes con los ductos de encima de la R-214. La climatizadora lleva parada desde el martes y siguen sonando. Suenan cuando alguien habla debajo de la rejilla y callan cuando se calla.", "", "Pido sellar esa rejilla y las dos de al lado."],
		"note": ["No. Las rejillas se quedan abiertas."]},
	"memo_4_medico": {"date": "02.06.19__", "to": "Personal", "from": "Dr. A. Campos, Servicio Médico", "subject": "Solicitud de traslado de I. Barral", "cc": "Registro", "seed": 406,
		"lines": ["La empleada dice ver una cara en el techo de su despacho. Solo cuando levanta la vista. Dice que la cara la mira mientras ella la mire, y que cuanto más la mira peor se encuentra después.", "", "Le he indicado que no mire. Refiere que solo se le pasa con el café de la máquina del pasillo.", "", "Solicita traslado a otra planta."],
		"stamp": "DENEGADO"},
}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for title in SHEETS:
		var view := SubViewport.new()
		view.size = Vector2i(MEMO.CARD)
		view.transparent_bg = true
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(view)
		var sheet := MEMO.new()
		view.add_child(sheet)
		sheet.setup(SHEETS[title])
		for i in 6: await process_frame
		await RenderingServer.frame_post_draw
		view.get_texture().get_image().save_png(OUT + "/" + String(title) + ".png")
		print("MEMO_SHOT " + String(title))
		view.queue_free()
	quit(0)
