# res://scripts/Title.gd
extends Control

@onready var start_run_button: Button = %StartRunButton
@onready var options_button: Button = %OptionsButton
@onready var exit_button: Button = %ExitButton
@onready var tutorial_checkbox: CheckBox = %TutorialCheckbox
@onready var continue_button: Button = %ContinueButton
@onready var replays_button: Button = %ReplaysButton
@onready var background: TextureRect = $Background

const REPLAY_BROWSER_SCENE := preload("res://scenes/ui/ReplayBrowser.tscn")

func _input(event: InputEvent) -> void:
	# Debug Header: Reset tutorials with Shift+T
	if event is InputEventKey and event.pressed and event.keycode == KEY_T and event.shift_pressed:
		if TutorialManager:
			TutorialManager.reset_all_tutorials()
			if tutorial_checkbox:
				tutorial_checkbox.button_pressed = true # Auto-enable

func _ready() -> void:
	# AUDIO HOOK: Title BGM
	Audio.play_music(SoundRegistry.BGM_TITLE)
	
	if background and background.texture:
		var original_bg: Texture2D = background.texture
		background.texture = ArtStyleManager.get_themed_texture(original_bg)
		ArtStyleManager.style_changed.connect(func():
			if background and is_instance_valid(original_bg):
				background.texture = ArtStyleManager.get_themed_texture(original_bg)
		)
	
	# Continue button - only visible if save exists
	if SaveManager.has_save():
		continue_button.visible = true
		continue_button.pressed.connect(_on_continue_pressed)
	else:
		continue_button.visible = false
	
	# The Title screen should now transition to the Loadout scene, not start a run directly.
	start_run_button.pressed.connect(func():
		# Reset tutorials for the new run flow so loadout_intro shows
		if TutorialManager and TutorialManager.tutorials_enabled:
			TutorialManager.reset_all_tutorials()
		SignalBus.emit_signal("loadout_scene_requested")
	)
	options_button.pressed.connect(_on_options_pressed)
	if is_instance_valid(replays_button):
		replays_button.pressed.connect(_on_replays_pressed)
	
	if exit_button:
		exit_button.pressed.connect(func():
			get_tree().quit()
		)
	
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
	start_run_button.text = tr("ui.play")
	options_button.text = tr("ui.options")
	if exit_button:
		exit_button.text = tr("ui.exit_game")
	if continue_button:
		continue_button.text = tr("ui.continue")
	if replays_button:
		replays_button.text = "Replays"
	if tutorial_checkbox:
		tutorial_checkbox.text = tr("ui.show_tutorials")

func _on_options_pressed() -> void:
	# Open the options window via WindowManager
	var context: Dictionary = {
		"window_type": &"Options",
		"populate_context": {}
	}
	WindowManager._open_contextual_window(context)

func _on_replays_pressed() -> void:
	var browser := REPLAY_BROWSER_SCENE.instantiate()
	add_child(browser)

func _on_continue_pressed() -> void:
	var loaded_state: RunState = SaveManager.load_run()
	if is_instance_valid(loaded_state):
		GameManager.resume_saved_run(loaded_state)
	else:
		push_error("[Title] Failed to load saved run")
		continue_button.visible = false
