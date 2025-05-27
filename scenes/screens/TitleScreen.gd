extends Control

@onready var start_button: Button = $VBoxContainer/ButtonContainer/StartButton
@onready var load_button: Button = $VBoxContainer/ButtonContainer/LoadButton
@onready var quit_button: Button = $VBoxContainer/ButtonContainer/QuitButton

func _ready() -> void:
	# Connect signals
	start_button.pressed.connect(_on_start_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Set focus to start button for keyboard/gamepad navigation
	start_button.grab_focus()
	
	# Check if there's a save file to enable load button
	# TODO: Implement save file checking
	load_button.disabled = true

func _on_start_button_pressed() -> void:
	# Start a new game
	PlayerData.start_new_run()
	GameManager.change_scene("path_choice")

func _on_load_button_pressed() -> void:
	# Load game
	# TODO: Implement game loading
	pass

func _on_quit_button_pressed() -> void:
	# Quit the game
	get_tree().quit()

# Handle gamepad/controller input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# If on a sub-menu, handle back action
		# For now, just quit the game
		get_tree().quit()
