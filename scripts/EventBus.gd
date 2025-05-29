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
signal unit_health_changed(unit: Object, new_health: int, old_health: int, max_health: int) # unit is Object to match Unit.gd
signal unit_action_initiated(unit: Object, action_type: String, target: Object) # unit and target are Objects
signal unit_action_completed(unit: Object, action_type: String, details: Dictionary) # unit is Object
signal unit_selected_for_action(unit: Object) # Signal emitted when a unit is selected for an action
signal slot_clicked_for_action(slot: Object) # Signal emitted when a slot is clicked for an action

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
