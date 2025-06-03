extends Node

# ===== BATTLE EVENTS =====
signal battle_started()
signal battle_ended(victory: bool)
signal turn_started(turn_owner: String)  # "player" or "enemy"
signal turn_ended(turn_owner: String)
signal end_turn_pressed()  # When the end turn button is pressed

# ===== UNIT EVENTS =====
signal unit_spawned(unit: Node2D)
signal unit_damaged(unit: Node2D, amount: int)
signal unit_healed(unit: Node2D, amount: int)
signal unit_died(unit: Node2D)
signal unit_health_changed(unit: Object, new_health: int, old_health: int, max_health: int)  # unit is Object to match Unit.gd
signal unit_action_initiated(unit: Object, action_type: String, target: Object)  # unit and target are Objects
signal unit_action_completed(unit: Object, action_type: String, details: Dictionary)  # unit is Object
signal units_merged(unit1: Object, unit2: Object, result_unit: Object)  # Emitted when two units are merged

# ===== INPUT EVENTS =====
# Unit interaction
signal unit_inspection_requested(unit: Object)  # When a unit is right-clicked or inspected via hotkey
signal unit_selection_requested(unit: Object)   # When a unit is left-clicked for selection
signal slot_selected(slot: Object)              # When a slot is selected
signal hovered_unit_changed(unit: Object)       # When mouse hovers over a unit
signal hovered_slot_changed(slot: Object)       # When mouse hovers over a slot

# ===== UI EVENTS =====
signal ui_button_pressed(button_name: String)
signal tooltip_shown(content: String, position: Vector2)
signal tooltip_hidden()
signal ui_element_opened(element: Control)     # When a UI element is opened
signal ui_element_closed(element: Control)     # When a UI element is closed

# ===== FLASHCARD EVENTS =====
signal flashcard_presented(question: String, answers: Array)
signal flashcard_answered(correct: bool)

# ===== GACHA EVENTS =====
signal gacha_pull_requested(cost: int)
signal gacha_result_received(rewards: Array)

# ===== SYSTEM EVENTS =====
signal game_saved()
signal game_loaded()
signal error_occurred(message: String, is_critical: bool)

# Helper function to emit errors
func emit_error(message: String, is_critical: bool = false) -> void:
	push_error(message)
	emit_signal("error_occurred", message, is_critical)
