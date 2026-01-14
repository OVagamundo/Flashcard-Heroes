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
		title_label.text = tr("ui.victory")
		return_button.text = tr("ui.continue")
	else:
		title_label.text = tr("ui.defeat")
		return_button.text = tr("ui.return_to_title")

func _on_return_button_pressed() -> void:
	if _is_victory:
		SignalBus.emit_signal("battle_victory_acknowledged")
	else:
		# Clear save on game over (defeat)
		SaveManager.clear_save()
		SignalBus.emit_signal("title_scene_requested")
	queue_free()

func get_window_to_animate() -> Control:
	return $CenterContainer/PanelContainer
