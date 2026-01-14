# res://scripts/RunCompletePopup.gd
extends Control
class_name RunCompletePopup

@onready var title_label: Label = %TitleLabel
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var return_button: Button = %ReturnButton

func _ready() -> void:
	return_button.pressed.connect(_on_return_button_pressed)

func populate(context: Dictionary) -> void:
	title_label.text = tr("ui.run_complete")
	return_button.text = tr("ui.return_to_title")
	
	var days: int = context.get("days", 0)
	var bosses: int = context.get("bosses_defeated", 5)
	var enemies: int = context.get("enemies_defeated", 0)
	var gold_earned: int = context.get("gold_earned", 0)
	
	stats_label.text = """[center][b]%s[/b]

%s

[b]%s[/b]

%s: %d
%s: %d
%s: %d
%s: %d[/center]""" % [
		tr("ui.congratulations"),
		tr("ui.run_complete_message"),
		tr("ui.final_statistics"),
		tr("ui.days_survived"), days,
		tr("ui.bosses_defeated"), bosses,
		tr("ui.enemies_slain"), enemies,
		tr("ui.gold_earned"), gold_earned
	]

func _on_return_button_pressed() -> void:
	# Clear save on run completion (victory)
	SaveManager.clear_save()
	SignalBus.emit_signal("title_scene_requested")
	queue_free()

func get_window_to_animate() -> Control:
	return $CenterContainer/PanelContainer
