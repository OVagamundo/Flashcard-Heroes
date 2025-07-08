# res://scripts/EndBattlePopup.gd
extends Control
class_name EndBattlePopup

@onready var title_label: Label = %TitleLabel
@onready var return_button: Button = %ReturnButton

func _ready():
	return_button.pressed.connect(_on_return_button_pressed)

func populate(is_victory: bool):
	if is_victory:
		title_label.text = "VICTORY!"
	else:
		title_label.text = "DEFEAT"

func _on_return_button_pressed():
	# We need a new signal and handler to go back to the title screen.
	EventBus.emit_signal("title_scene_requested")
