# res://scripts/Title.gd
extends Control

@onready var start_run_button: Button = %StartRunButton

@onready var inspection_test_button: Button = %InspectionTestButton

func _ready():
	start_run_button.pressed.connect(func(): EventBus.emit_signal("start_run_requested"))
	inspection_test_button.pressed.connect(func(): EventBus.emit_signal("inspection_test_scene_requested"))

