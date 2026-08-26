extends GameAction
class_name StartTrainingAction

var stat: String
var unit_location: LocationIdentifier
var cost: int
var _action_in_progress: bool = false
var interaction_pos: Vector2

func _init(p_stat: String, p_unit_location: LocationIdentifier, p_cost: int, p_interaction_pos: Vector2) -> void:
	stat = p_stat
	unit_location = p_unit_location
	cost = p_cost
	interaction_pos = p_interaction_pos

func is_valid() -> bool:
	if not is_instance_valid(GameManager.run_state): return false
	if GameManager.run_state.gold < cost: return false
	
	var item_data = GameManager.get_instance_from_location(unit_location)
	if item_data == null: return false
	
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.spend_gold(cost)
		
	# Emulate the start of minigame from backend
	if is_instance_valid(GameManager.run_state) and GameManager.run_state.has_method("active_deck_ids"):
		# The visual callback handles FlashcardManager start normally, but in headless we might need to skip or simulate it.
		pass

func _trigger_animations() -> void:
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node) and main_node.has_method("_animate_gold_spend") and main_node.has_node("%UnitTrainingGround"):
		var training_node = main_node.get_node("%UnitTrainingGround")
		training_node._animate_gold_spend(cost, interaction_pos, _on_gold_spend_completed)
	else:
		_on_gold_spend_completed()

func _on_gold_spend_completed() -> void:
	_perform_mutation()
	
	# Start flashcard minigame visually
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node) and main_node.has_node("%UnitTrainingGround"):
		var training_node = main_node.get_node("%UnitTrainingGround")
		training_node._on_start_training_mutation_complete(stat, unit_location)
		
	finish_visuals()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "StartTrainingAction",
		"stat": stat,
		"cost": cost,
		"unit_location": unit_location.to_dict() if is_instance_valid(unit_location) and unit_location.has_method("to_dict") else {}
	}
