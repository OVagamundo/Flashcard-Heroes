# res://scripts/engine/actions/RerollShopAction.gd
class_name RerollShopAction
extends GameAction

func _init() -> void:
	super._init(&"RerollShopAction")

func validate() -> bool:
	if not is_instance_valid(GameManager) or not is_instance_valid(GameManager.run_state):
		return false
	return GameManager.run_state.gold >= GameManager._reroll_cost

func execute() -> void:
	var current_cost = GameManager._reroll_cost
	# Synchronous authoritative data mutation
	GameManager._on_shop_reroll_requested()

	var shop = Engine.get_main_loop().root.find_child("Shop", true, false)
	if is_instance_valid(shop) and not ActionQueue.is_headless_mode() and shop.has_method("execute_reroll_visuals"):
		shop.execute_reroll_visuals(current_cost)

func yields_for_visuals() -> bool:
	var shop = Engine.get_main_loop().root.find_child("Shop", true, false)
	return is_instance_valid(shop) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	return super.to_dict()

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
