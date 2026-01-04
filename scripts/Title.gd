# res://scripts/Title.gd
extends Control

@onready var start_run_button: Button = %StartRunButton
@onready var options_button: Button = %OptionsButton

func _ready() -> void:
	# The Title screen should now transition to the Loadout scene, not start a run directly.
	start_run_button.pressed.connect(func(): SignalBus.emit_signal("loadout_scene_requested"))
	options_button.pressed.connect(_on_options_pressed)
	
	# Connect to locale changes to update button text
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()

func _update_localized_text() -> void:
	start_run_button.text = tr("ui.start_run")
	options_button.text = tr("ui.options")

func _on_options_pressed() -> void:
	# Open the options window via WindowManager
	var context: Dictionary = {
		"window_type": &"Options",
		"populate_context": {}
	}
	WindowManager._open_contextual_window(context)
