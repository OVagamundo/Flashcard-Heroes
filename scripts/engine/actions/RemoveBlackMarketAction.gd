# res://scripts/engine/actions/RemoveBlackMarketAction.gd
class_name RemoveBlackMarketAction
extends GameAction

var target_uuid: String = ""
var cost: int = 5

func _init(p_target_uuid: String = "", p_cost: int = 5) -> void:
	super._init(&"RemoveBlackMarketAction")
	target_uuid = p_target_uuid
	cost = p_cost

func validate() -> bool:
	if target_uuid.is_empty():
		return false
	if not is_instance_valid(GameManager.run_state):
		return false
	if GameManager.run_state.gold < cost:
		return false
	return GameManager.run_state.get_instance_by_uuid(target_uuid) != null

func execute() -> void:
	var bm = Engine.get_main_loop().root.find_child("BlackMarket", true, false)
	if is_instance_valid(bm) and not ActionQueue.is_headless_mode() and bm.has_method("execute_remove_visuals"):
		bm.execute_remove_visuals(target_uuid, cost)
	else:
		# Direct data mutation
		SignalBus.emit_signal("black_market_action_requested", {
			"type": "remove",
			"cost": cost,
			"instance_uuid": target_uuid
		})

func yields_for_visuals() -> bool:
	var bm = Engine.get_main_loop().root.find_child("BlackMarket", true, false)
	return is_instance_valid(bm) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["target_uuid"] = target_uuid
	d["cost"] = cost
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	target_uuid = String(data.get("target_uuid", ""))
	cost = int(data.get("cost", 5))
