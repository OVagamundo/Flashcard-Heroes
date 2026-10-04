# res://scripts/engine/actions/SellRewardAction.gd
class_name SellRewardAction
extends GameAction

var instance_uuid: String = ""
var interaction_type: String = "CLICK"
var drop_pos: Vector2 = Vector2.ZERO

func _init(p_instance_uuid: String = "", p_interaction_type: String = "CLICK", p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	super._init(&"SellRewardAction")
	instance_uuid = p_instance_uuid
	interaction_type = p_interaction_type
	drop_pos = p_drop_pos

func validate() -> bool:
	if instance_uuid.is_empty():
		return false
	if not is_instance_valid(GameManager):
		return false
	return GameManager._temporary_reward_master_dict.has(instance_uuid)

func execute() -> void:
	# Synchronous authoritative data mutation
	var gold_yield := GameManager.sell_reward_instance(instance_uuid)

	var reward_view = Engine.get_main_loop().root.find_child("Reward", true, false)
	if not is_instance_valid(reward_view):
		reward_view = Engine.get_main_loop().root.find_child("RewardElite", true, false)
		
	if is_instance_valid(reward_view) and not ActionQueue.is_headless_mode() and reward_view.has_method("execute_sell_visuals"):
		reward_view.execute_sell_visuals(instance_uuid, gold_yield, drop_pos)

func yields_for_visuals() -> bool:
	var reward_view = Engine.get_main_loop().root.find_child("Reward", true, false)
	if not is_instance_valid(reward_view):
		reward_view = Engine.get_main_loop().root.find_child("RewardElite", true, false)
	return is_instance_valid(reward_view) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["instance_uuid"] = instance_uuid
	d["interaction_type"] = interaction_type
	d["drop_pos"] = [drop_pos.x, drop_pos.y]
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	instance_uuid = String(data.get("instance_uuid", ""))
	interaction_type = String(data.get("interaction_type", "CLICK"))
	if data.has("drop_pos") and data["drop_pos"] is Array and data["drop_pos"].size() == 2:
		drop_pos = Vector2(data["drop_pos"][0], data["drop_pos"][1])
