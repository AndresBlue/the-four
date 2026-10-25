extends "res://tests/office/office_test.gd"
## office_test's first part, on its own (verify.ps1 runs its three parts side
## by side): the palette, the office kind, the 64 floors of the generator and
## the texts.

func _initialize() -> void:
	part = "generator"
	super()
