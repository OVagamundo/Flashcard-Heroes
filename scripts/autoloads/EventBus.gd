extends Node

# Battle Events
signal battle_started()
signal battle_ended(victory: bool)
signal turn_started(turn_owner: String)  # "player" or "enemy"
signal turn_ended(turn_owner: String)

# Unit Events
signal unit_spawned(unit: Node2D)
signal unit_damaged(unit: Node2D, amount: int)
signal unit_healed(unit: Node2D, amount: int)
signal unit_died(unit: Node2D)

# Flashcard Events
signal flashcard_presented(question: String, answers: Array)
signal flashcard_answered(correct: bool)

# Gacha Events
signal gacha_pull_requested(cost: int)
signal gacha_result_received(rewards: Array)

# UI Events
signal ui_button_pressed(button_name: String)
signal tooltip_shown(content: String, position: Vector2)
signal tooltip_hidden()

# System Events
signal game_saved()
signal game_loaded()
signal error_occurred(message: String, is_critical: bool)

# Helper function to emit errors
func emit_error(message: String, is_critical: bool = false) -> void:
	push_error(message)
	emit_signal("error_occurred", message, is_critical)
