class_name PurchaseShelfSlotAction
extends GameAction

func _init() -> void:
	super._init(&"PurchaseShelfSlotAction")

func validate() -> bool:
	var battle_manager: BattleManager = GameManager.get_battle_manager() as BattleManager
	return is_instance_valid(battle_manager) and battle_manager.can_purchase_shelf_slot()

func execute() -> void:
	var battle_manager: BattleManager = GameManager.get_battle_manager() as BattleManager
	assert(is_instance_valid(battle_manager), "PurchaseShelfSlotAction.execute: battle manager is required")
	var slot_index: int = battle_manager.get_player_shelf_slots_unlocked()
	if not ActionQueue.is_headless_mode():
		var battle_view: BattleView = battle_manager.get_parent() as BattleView
		battle_view.prepare_shelf_purchase(slot_index)
	var purchased: bool = battle_manager.purchase_shelf_slot()
	assert(purchased, "PurchaseShelfSlotAction.execute: validated shelf purchase failed")
	if not ActionQueue.is_headless_mode():
		var battle_view: BattleView = battle_manager.get_parent() as BattleView
		battle_view.animate_shelf_purchase(slot_index, self)

func yields_for_visuals() -> bool:
	return not ActionQueue.is_headless_mode()
