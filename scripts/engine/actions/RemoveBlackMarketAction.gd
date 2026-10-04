# res://scripts/engine/actions/RemoveBlackMarketAction.gd
class_name RemoveBlackMarketAction
extends GameAction

var target_uuid: String = ""
var cost: int = 5
var interaction_type: String = "CLICK"
var drop_pos: Vector2 = Vector2.ZERO

func _init(p_target_uuid: String = "", p_cost: int = 5, p_interaction_type: String = "CLICK", p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	super._init(&"RemoveBlackMarketAction")
	target_uuid = p_target_uuid
	cost = p_cost
	interaction_type = p_interaction_type
	drop_pos = p_drop_pos

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
		bm.execute_remove_visuals(target_uuid, cost, drop_pos)
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
	d["interaction_type"] = interaction_type
	d["drop_pos"] = [drop_pos.x, drop_pos.y]
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	target_uuid = String(data.get("target_uuid", ""))
	cost = int(data.get("cost", 5))
	interaction_type = String(data.get("interaction_type", "CLICK"))
	if data.has("drop_pos") and data["drop_pos"] is Array and data["drop_pos"].size() == 2:
		drop_pos = Vector2(data["drop_pos"][0], data["drop_pos"][1])
