extends GameAction
class_name DrawGachaAction

var tier: int

func _init(p_tier: int) -> void:
	tier = p_tier

func is_valid() -> bool:
	if not GameManager.is_in_battle:
		return false
		
	var bm = GameManager.get_tree().get_first_node_in_group("battle_manager")
	if bm == null or not bm.has_method("can_draw_gacha_instance"):
		return false
		
	return bm.can_draw_gacha_instance(tier)

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	var bm = GameManager.get_tree().get_first_node_in_group("battle_manager")
	if bm == null: return
	var chain_events = bm.bm_draw_gacha_instance(tier)
	
	if not chain_events.is_empty():
		# This enqueues battle animations, but we still need to wait for them.
		# However, `enqueue_management_animation` handles its own blocking.
		# For this action's specific block, we wait for the token animation below.
		bm.enqueue_management_animation(bm.get_board_snapshot(), chain_events)

func _trigger_animations() -> void:
	# First, the token toss animation
	var main_node = GameManager._active_main_node
	if is_instance_valid(main_node) and main_node.has_method("_animate_token_spend"):
		var bm = GameManager.get_tree().get_first_node_in_group("battle_manager")
		var effective_cost = tier
		if is_instance_valid(bm) and bm.has_method("get_gacha_draw_cost"):
			effective_cost = bm.get_gacha_draw_cost(tier)
			
		# This will run the visual token toss, then call our callback to actually mutate
		main_node._animate_token_spend(tier, effective_cost, _on_token_spend_completed)
	else:
		_on_token_spend_completed()

func _on_token_spend_completed() -> void:
	_perform_mutation()
	finish_visuals()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "DrawGachaAction",
		"tier": tier
	}
