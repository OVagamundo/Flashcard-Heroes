# res://scripts/engine/actions/BuyShopAction.gd
class_name BuyShopAction
extends GameAction

var slot_index: int = -1
var cost: int = 0
var expected_definition_id: String = ""
var interaction_type: String = "CLICK"
var drop_pos: Vector2 = Vector2.ZERO

func _init(p_slot_index: int = -1, p_cost: int = 0, p_expected_definition_id: String = "", p_interaction_type: String = "CLICK", p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	super._init(&"BuyShopAction")
	slot_index = p_slot_index
	cost = p_cost
	expected_definition_id = p_expected_definition_id
	interaction_type = p_interaction_type
	drop_pos = p_drop_pos

func validate() -> bool:
	if slot_index < 0:
		return false
	if not is_instance_valid(GameManager) or not is_instance_valid(GameManager.run_state):
		return false
	if not is_instance_valid(GameManager._temporary_shop_container):
		return false
	var uuid = GameManager._temporary_shop_container.get_uuid(slot_index)
	if uuid.is_empty() or not GameManager._temporary_shop_master_dict.has(uuid):
		return false
	var inst = GameManager._temporary_shop_master_dict.get(uuid)
	if not expected_definition_id.is_empty():
		if not is_instance_valid(inst) or String(inst.definition_id) != expected_definition_id:
			return false
	var effective_cost = cost
	if effective_cost <= 0 and is_instance_valid(inst):
		effective_cost = GameManager.get_item_cost(inst.get_definition())
	return GameManager.run_state.gold >= effective_cost

func execute() -> void:
	var shop = Engine.get_main_loop().root.find_child("Shop", true, false)
	var effective_cost = cost
	var uuid: String = ""
	var inst: GachaBallInstance = null
	if is_instance_valid(GameManager._temporary_shop_container):
		uuid = GameManager._temporary_shop_container.get_uuid(slot_index)
		if GameManager._temporary_shop_master_dict.has(uuid):
			inst = GameManager._temporary_shop_master_dict.get(uuid)
			if effective_cost <= 0 and is_instance_valid(inst):
				effective_cost = GameManager.get_item_cost(inst.get_definition())

	# Synchronous authoritative data mutation
	var event_log: Dictionary = GameManager.simulate_shop_purchase(uuid, effective_cost)
	if event_log.get("slot_index", -1) == -1:
		event_log["slot_index"] = slot_index
	if not event_log.has("purchased_instance") and is_instance_valid(inst):
		event_log["purchased_instance"] = inst
	event_log["interaction_type"] = interaction_type
	event_log["drop_pos"] = drop_pos

	if is_instance_valid(shop) and not ActionQueue.is_headless_mode():
		if shop.has_method("play_transaction_log"):
			shop.play_transaction_log(event_log)
		elif shop.has_method("execute_buy_visuals"):
			shop.execute_buy_visuals(slot_index, effective_cost, inst, drop_pos)

func yields_for_visuals() -> bool:
	var shop = Engine.get_main_loop().root.find_child("Shop", true, false)
	return is_instance_valid(shop) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["slot_index"] = slot_index
	d["cost"] = cost
	d["expected_definition_id"] = expected_definition_id
	d["interaction_type"] = interaction_type
	if not drop_pos.is_zero_approx():
		d["drop_pos_x"] = drop_pos.x
		d["drop_pos_y"] = drop_pos.y
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	slot_index = int(data.get("slot_index", -1))
	cost = int(data.get("cost", 0))
	expected_definition_id = String(data.get("expected_definition_id", ""))
	interaction_type = String(data.get("interaction_type", "CLICK"))
	if data.has("drop_pos_x") and data.has("drop_pos_y"):
		drop_pos = Vector2(float(data["drop_pos_x"]), float(data["drop_pos_y"]))
	else:
		drop_pos = Vector2.ZERO
