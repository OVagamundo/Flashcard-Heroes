# res://scripts/engine/actions/DrawRewardAction.gd
class_name DrawRewardAction
extends GameAction

var tier: int = 1

func _init(p_tier: int = 1) -> void:
	super._init(&"DrawRewardAction")
	tier = p_tier

func validate() -> bool:
	if tier < 1 or tier > 3:
		return false
	if not is_instance_valid(GameManager.run_state):
		return false
	var cost = GameManager.get_gacha_token_cost(tier)
	return GameManager.run_state.get_room_tokens() >= cost

func execute() -> void:
	var drawn_instance = GameManager.create_reward_draw(tier)
	var reward_view = Engine.get_main_loop().root.find_child("Reward", true, false)
	if is_instance_valid(reward_view) and not ActionQueue.is_headless_mode() and reward_view.has_method("execute_draw_tier_visuals"):
		reward_view.execute_draw_tier_visuals(tier, drawn_instance)

func yields_for_visuals() -> bool:
	var reward_view = Engine.get_main_loop().root.find_child("Reward", true, false)
	return is_instance_valid(reward_view) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["tier"] = tier
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	tier = int(data.get("tier", 1))
