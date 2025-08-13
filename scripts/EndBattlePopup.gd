# res://scripts/EndBattlePopup.gd
extends Control
class_name EndBattlePopup

@onready var title_label: Label = %TitleLabel
@onready var return_button: Button = %ReturnButton

var _is_victory: bool = false

func _ready() -> void:
	return_button.pressed.connect(_on_return_button_pressed)

func populate(context: Dictionary) -> void:
	var is_victory: bool = context.get("is_victory", false)
	_is_victory = is_victory
	if is_victory:
		title_label.text = "VICTORY!"
		return_button.text = "Continue"
	else:
		title_label.text = "DEFEAT"
		return_button.text = "Return to Title"

func _on_return_button_pressed() -> void:
	if _is_victory:
		SignalBus.emit_signal("battle_victory_acknowledged")
	else:
		SignalBus.emit_signal("title_scene_requested")
	queue_free()
