# res://scripts/engine/actions/LeaveRewardAction.gd
class_name LeaveRewardAction
extends GameAction

func _init() -> void:
	super._init(&"LeaveRewardAction")

func validate() -> bool:
	return true

func execute() -> void:
	var reward = Engine.get_main_loop().root.find_child("Reward", true, false)
	if not is_instance_valid(reward):
		reward = Engine.get_main_loop().root.find_child("RewardElite", true, false)
	
	if is_instance_valid(reward) and not ActionQueue.is_headless_mode() and reward.has_method("execute_leave_visuals"):
		reward.execute_leave_visuals()
	else:
		# Auto collect remaining capsule rewards in headless mode if any
		if is_instance_valid(GameManager._temporary_reward_container):
			var uuids = GameManager._temporary_reward_container.get_all_non_empty_uuids()
			for uuid in uuids:
				var payload := {"type": "gachaball", "instance_uuid": uuid}
				SignalBus.emit_signal("reward_chosen", payload)
		
		if is_instance_valid(GameManager.run_state):
			GameManager.run_state.reset_room_tokens()
			GameManager.run_state.current_boss_level = 0
			GameManager.run_state.current_elite_level = 0
			
		SignalBus.emit_signal("path_choice_scene_requested")

func yields_for_visuals() -> bool:
	return true

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
