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
	
	var flashcard_progress: Dictionary = context.get("flashcard_progress", {})
	var mastery_counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	var mastered_total = 0
	for card_id in flashcard_progress:
		var prog = flashcard_progress[card_id]
		var level = prog.mastery_level
		if level >= 1 and level <= 5:
			mastery_counts[level] += 1
			if level > 1:
				mastered_total += 1
				
	stats_label.text = """[center][b]%s[/b]

%s

[b]%s[/b]

%s: %d
%s: %d
%s: %d
%s: %d
%s: %d
%s: %d

[b]%s[/b]
%s: %d
%s: %d
%s: %d
%s: %d
%s: %d[/center]""" % [
		tr("ui.congratulations"),
		tr("ui.run_complete_message") % bosses,
		tr("ui.final_statistics"),
		tr("ui.days_survived"), days,
		tr("ui.bosses_defeated"), bosses,
		tr("ui.elites_defeated"), context.get("elites_defeated", 0),
		tr("ui.enemies_slain"), enemies,
		tr("ui.gold_earned"), gold_earned,
		tr("ui.tokens_earned"), context.get("tokens_earned", 0),
		tr("ui.mastery_breakdown"),
		tr("ui.flashcards_mastered"), mastered_total,
		tr("ui.mastery_level_2"), mastery_counts[2],
		tr("ui.mastery_level_3"), mastery_counts[3],
		tr("ui.mastery_level_4"), mastery_counts[4],
		tr("ui.mastery_level_5"), mastery_counts[5]
	]

func _on_return_button_pressed() -> void:
	# Clear save on run completion (victory)
	SaveManager.clear_save()
	SignalBus.emit_signal("title_scene_requested")
	queue_free()

func get_window_to_animate() -> Control:
	return $CenterContainer/PanelContainer
