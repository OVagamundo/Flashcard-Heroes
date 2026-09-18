# res://scripts/engine/actions/TrainUnitStatAction.gd
class_name TrainUnitStatAction
extends GameAction

var token_cost: int = 1

func _init(p_token_cost: int = 1) -> void:
	super._init(&"TrainUnitStatAction")
	token_cost = p_token_cost

func validate() -> bool:
	if token_cost < 1 or token_cost > 3:
		return false
	if not is_instance_valid(GameManager.run_state):
		return false
	return GameManager.run_state.get_room_tokens() >= token_cost

func execute() -> void:
	var roll = RNGManager.reward_rng.randi_range(0, token_cost)
	if is_instance_valid(GameManager.run_state):
		GameManager.run_state.spend_room_tokens(token_cost)
		var uuid = GameManager.run_state.training_unit_uuid
		if uuid != "" and roll > 0:
			var hp_delta = roll if GameManager.run_state.training_stat == "hp" else 0
			var pwr_delta = roll if GameManager.run_state.training_stat == "pwr" else 0
			GameManager.run_state.modify_unit_base_stats(uuid, hp_delta, pwr_delta)
			
	var utg = Engine.get_main_loop().root.find_child("UnitTrainingGround", true, false)
	if is_instance_valid(utg) and not ActionQueue.is_headless_mode() and utg.has_method("execute_train_visuals"):
		utg.execute_train_visuals(token_cost, roll)

func yields_for_visuals() -> bool:
	var utg = Engine.get_main_loop().root.find_child("UnitTrainingGround", true, false)
	return is_instance_valid(utg) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["token_cost"] = token_cost
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	token_cost = int(data.get("token_cost", 1))
