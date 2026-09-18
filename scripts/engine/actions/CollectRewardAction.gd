# res://scripts/engine/actions/CollectRewardAction.gd
class_name CollectRewardAction
extends GameAction

var instance_uuid: String = ""

func _init(p_instance_uuid: String = "") -> void:
	super._init(&"CollectRewardAction")
	instance_uuid = p_instance_uuid

func validate() -> bool:
	return not instance_uuid.is_empty()

func execute() -> void:
	var reward_view = Engine.get_main_loop().root.find_child("Reward", true, false)
	if not is_instance_valid(reward_view):
		reward_view = Engine.get_main_loop().root.find_child("RewardElite", true, false)
	
	if is_instance_valid(reward_view) and not ActionQueue.is_headless_mode() and reward_view.has_method("execute_collect_visuals"):
		reward_view.execute_collect_visuals(instance_uuid)
	else:
		# Direct data mutation
		var payload := {"type": "gachaball", "instance_uuid": instance_uuid}
		SignalBus.emit_signal("reward_chosen", payload)

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
