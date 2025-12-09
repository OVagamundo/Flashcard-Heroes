# res://scripts/RunCompletePopup.gd
extends Control
class_name RunCompletePopup

@onready var title_label: Label = %TitleLabel
@onready var stats_label: RichTextLabel = %StatsLabel
@onready var return_button: Button = %ReturnButton

func _ready() -> void:
	return_button.pressed.connect(_on_return_button_pressed)

func populate(context: Dictionary) -> void:
	title_label.text = "RUN COMPLETE!"
	
	var days: int = context.get("days", 0)
	var bosses: int = context.get("bosses_defeated", 5)
	var enemies: int = context.get("enemies_defeated", 0)
	var gold_earned: int = context.get("gold_earned", 0)
	
	stats_label.text = """[center][b]Congratulations![/b]

You have defeated all 5 bosses and completed your run!

[b]Final Statistics[/b]

Days Survived: %d
Bosses Defeated: %d
Enemies Slain: %d
Gold Earned: %d[/center]""" % [days, bosses, enemies, gold_earned]

func _on_return_button_pressed() -> void:
	SignalBus.emit_signal("title_scene_requested")
	queue_free()
