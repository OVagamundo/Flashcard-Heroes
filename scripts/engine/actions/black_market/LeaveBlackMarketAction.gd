extends GameAction
class_name LeaveBlackMarketAction

func _init() -> void:
	pass

func is_valid() -> bool:
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	SignalBus.emit_signal("path_choice_scene_requested")

func _trigger_animations() -> void:
	var bm = GameManager.get_tree().get_first_node_in_group("black_market_controller")
		
	var main_node = GameManager._active_main_node
	if main_node != null:
		if main_node.has_method("hide_action_instruction"):
			main_node.hide_action_instruction()
		if main_node.has_method("hide_split_action_drop_zones"):
			main_node.hide_split_action_drop_zones()
			
	_perform_mutation()
	finish_visuals()

func yields_for_visuals() -> bool:
	return false

func serialize() -> Dictionary:
	return {
		"action_type": "LeaveBlackMarketAction"
	}
