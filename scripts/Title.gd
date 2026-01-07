# res://scripts/Title.gd
extends Control

@onready var start_run_button: Button = %StartRunButton
@onready var options_button: Button = %OptionsButton
@onready var tutorial_checkbox: CheckBox = %TutorialCheckbox

func _input(event: InputEvent) -> void:
	# Debug Header: Reset tutorials with Shift+T
	if event is InputEventKey and event.pressed and event.keycode == KEY_T and event.shift_pressed:
		print("[Title] Debug: Resetting all tutorials request.")
		if TutorialManager:
			TutorialManager.reset_all_tutorials()
			print("[Title] Tutorials reset.")
			if tutorial_checkbox:
				tutorial_checkbox.button_pressed = true # Auto-enable

func _ready() -> void:
	print("[Title] Ready. TutorialManager.tutorials_enabled: ", TutorialManager.tutorials_enabled)
	# AUDIO HOOK: Title BGM
	Audio.play_music(SoundRegistry.BGM_TITLE)
	
	# The Title screen should now transition to the Loadout scene, not start a run directly.
	start_run_button.pressed.connect(func():
		# Reset tutorials for the new run flow so loadout_intro shows
		if TutorialManager and TutorialManager.tutorials_enabled:
			TutorialManager.reset_all_tutorials()
		SignalBus.emit_signal("loadout_scene_requested")
	)
	options_button.pressed.connect(_on_options_pressed)
	
	if tutorial_checkbox:
		tutorial_checkbox.button_pressed = TutorialManager.tutorials_enabled
		tutorial_checkbox.toggled.connect(func(enabled: bool):
			TutorialManager.tutorials_enabled = enabled
			TutorialManager.save_settings()
		)
	
	# Connect to locale changes to update button text
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()

func _update_localized_text() -> void:
	start_run_button.text = tr("ui.start_run")
	options_button.text = tr("ui.options")
	if tutorial_checkbox:
		tutorial_checkbox.text = tr("ui.show_tutorials")

func _on_options_pressed() -> void:
	# Open the options window via WindowManager
	var context: Dictionary = {
		"window_type": &"Options",
		"populate_context": {}
	}
	WindowManager._open_contextual_window(context)
