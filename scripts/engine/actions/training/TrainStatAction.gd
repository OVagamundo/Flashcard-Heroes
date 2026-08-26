extends GameAction
class_name TrainStatAction

var unit_uuid: String
var stat: String
var token_cost: int
var roll: int

func _init(p_unit_uuid: String, p_stat: String, p_token_cost: int) -> void:
	unit_uuid = p_unit_uuid
	stat = p_stat
	token_cost = p_token_cost
	roll = -1

func is_valid() -> bool:
	if not is_instance_valid(GameManager.run_state): return false
	
	# The action assumes tokens are tracked by the UI currently, but if we wanted full state tracking
	# we'd check token balance here. For now, UI validates it.
	return true

func execute() -> void:
	# Roll is done at execution time to preserve RNG stream order determinism
	roll = RNGManager.reward_rng.randi_range(0, token_cost)
	
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	if roll > 0:
		var hp_delta = roll if stat == "hp" else 0
		var pwr_delta = roll if stat == "pwr" else 0
		GameManager.run_state.modify_unit_base_stats(unit_uuid, hp_delta, pwr_delta)

func _trigger_animations() -> void:
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node) and main_node.has_node("%UnitTrainingGround"):
		var training_node = main_node.get_node("%UnitTrainingGround")
		training_node._animate_stat_buff(roll, stat, _on_animation_completed)
	else:
		_on_animation_completed()

func _on_animation_completed() -> void:
	_perform_mutation()
	finish_visuals()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "TrainStatAction",
		"unit_uuid": unit_uuid,
		"stat": stat,
		"token_cost": token_cost,
		"roll": roll
	}
