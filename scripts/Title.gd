# res://scripts/Title.gd
extends Control

@onready var start_run_button: Button = %StartRunButton

func _ready() -> void:
	# The Title screen should now transition to the Loadout scene, not start a run directly.
	start_run_button.pressed.connect(func(): SignalBus.emit_signal("loadout_scene_requested"))
