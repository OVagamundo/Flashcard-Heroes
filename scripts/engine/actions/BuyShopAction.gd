# res://scripts/engine/actions/BuyShopAction.gd
class_name BuyShopAction
extends GameAction

var slot_index: int = -1
var cost: int = 0

func _init(p_slot_index: int = -1, p_cost: int = 0) -> void:
	super._init(&"BuyShopAction")
	slot_index = p_slot_index
	cost = p_cost

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
	GameManager._on_shop_purchase_requested(uuid, effective_cost)

	if is_instance_valid(shop) and not ActionQueue.is_headless_mode() and shop.has_method("execute_buy_visuals"):
		shop.execute_buy_visuals(slot_index, effective_cost, inst)

func yields_for_visuals() -> bool:
	var shop = Engine.get_main_loop().root.find_child("Shop", true, false)
	return is_instance_valid(shop) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["slot_index"] = slot_index
	d["cost"] = cost
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	slot_index = int(data.get("slot_index", -1))
	cost = int(data.get("cost", 0))
