# res://scripts/Title.gd
extends Control

@onready var start_run_button: Button = %StartRunButton
@onready var options_button: Button = %OptionsButton
@onready var exit_button: Button = %ExitButton
@onready var continue_button: Button = %ContinueButton
@onready var replays_button: Button = %ReplaysButton
@onready var background: TextureRect = $Background

const REPLAY_BROWSER_SCENE := preload("res://scenes/ui/ReplayBrowser.tscn")

func _input(event: InputEvent) -> void:
	# Debug Header: Reset tutorials with Shift+T
	if event is InputEventKey and event.pressed and event.keycode == KEY_T and event.shift_pressed:
		TutorialManager.reset_all_tutorials()

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
	
	# The Title screen transitions to the Loadout scene
	start_run_button.pressed.connect(func():
		SignalBus.emit_signal("loadout_scene_requested")
	)
	options_button.pressed.connect(_on_options_pressed)
	replays_button.pressed.connect(_on_replays_pressed)
	
	exit_button.pressed.connect(func():
		get_tree().quit()
	)
	
	# Connect to locale changes to update button text
	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()

func _update_localized_text() -> void:
	start_run_button.text = tr("ui.play")
	options_button.text = tr("ui.options")
	exit_button.text = tr("ui.exit_game")
	if continue_button:
		continue_button.text = tr("ui.continue")
	replays_button.text = "Replays"

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
