extends Control

@onready var battle_button: Button = $VBoxContainer/ButtonContainer/BattleButton
@onready var back_button: Button = $VBoxContainer/ButtonContainer/BackButton

func _ready() -> void:
	# Connect signals
	battle_button.pressed.connect(_on_battle_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Set focus to battle button for keyboard/gamepad navigation
	battle_button.grab_focus()

func _on_battle_button_pressed() -> void:
	# Transition to battle scene
	GameManager.change_scene("battle")

func _on_back_button_pressed() -> void:
	# Return to title screen
	GameManager.change_scene("title")

# Handle gamepad/controller input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Return to title screen when pressing back/cancel
		_on_back_button_pressed()
