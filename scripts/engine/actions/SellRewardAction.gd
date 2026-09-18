# res://scripts/engine/actions/SellRewardAction.gd
class_name SellRewardAction
extends GameAction

var instance_uuid: String = ""

func _init(p_instance_uuid: String = "") -> void:
	super._init(&"SellRewardAction")
	instance_uuid = p_instance_uuid

func validate() -> bool:
	if instance_uuid.is_empty():
		return false
	if not is_instance_valid(GameManager):
		return false
	return GameManager._temporary_reward_master_dict.has(instance_uuid)

func execute() -> void:
	var reward_view = Engine.get_main_loop().root.find_child("Reward", true, false)
	if not is_instance_valid(reward_view):
		reward_view = Engine.get_main_loop().root.find_child("RewardElite", true, false)
		
	if is_instance_valid(reward_view) and not ActionQueue.is_headless_mode() and reward_view.has_method("execute_sell_visuals"):
		reward_view.execute_sell_visuals(instance_uuid)
	else:
		# Authoritative data mutation in headless or decoupled mode
		GameManager.sell_reward_instance(instance_uuid)

func yields_for_visuals() -> bool:
	var reward_view = Engine.get_main_loop().root.find_child("Reward", true, false)
	if not is_instance_valid(reward_view):
		reward_view = Engine.get_main_loop().root.find_child("RewardElite", true, false)
	return is_instance_valid(reward_view) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["instance_uuid"] = instance_uuid
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	instance_uuid = String(data.get("instance_uuid", ""))
