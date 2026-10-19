# res://scripts/engine/actions/RerollRewardAction.gd
class_name RerollRewardAction
extends GameAction

func _init() -> void:
	super._init(&"RerollRewardAction")

func validate() -> bool:
	if not is_instance_valid(GameManager) or not is_instance_valid(GameManager.run_state):
		return false
	var cost := 5
	if GameManager.run_state.has_method("get_elite_reward_reroll_cost"):
		cost = GameManager.run_state.get_elite_reward_reroll_cost()
	return GameManager.run_state.gold >= cost

func execute() -> void:
	var current_cost := 5
	if is_instance_valid(GameManager.run_state) and GameManager.run_state.has_method("get_elite_reward_reroll_cost"):
		current_cost = GameManager.run_state.get_elite_reward_reroll_cost()
	# Synchronous authoritative data mutation
	GameManager._on_reward_reroll_requested()

	var reward_view = _get_reward_view()
	if is_instance_valid(reward_view) and not ActionQueue.is_headless_mode() and reward_view.has_method("execute_reroll_visuals"):
		reward_view.execute_reroll_visuals(current_cost)

func yields_for_visuals() -> bool:
	var reward_view = _get_reward_view()
	return is_instance_valid(reward_view) and not ActionQueue.is_headless_mode()

func _get_reward_view() -> Node:
	if is_instance_valid(GameManager) and is_instance_valid(GameManager._active_main_node):
		var curr = GameManager._active_main_node.get("_current_content_node")
		if is_instance_valid(curr) and (curr.name == "RewardElite" or curr.name == "Reward" or curr.is_in_group("reward_scene")):
			return curr
	var reward_view = Engine.get_main_loop().root.find_child("RewardElite", true, false)
	if not is_instance_valid(reward_view):
		reward_view = Engine.get_main_loop().root.find_child("Reward", true, false)
	return reward_view

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
