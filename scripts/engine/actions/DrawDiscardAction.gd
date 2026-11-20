# res://scripts/engine/actions/DrawDiscardAction.gd
class_name DrawDiscardAction
extends GameAction

func _init() -> void:
	super._init(&"DrawDiscardAction")

func validate() -> bool:
	var battle: BattleManager = GameManager.get_battle_manager() as BattleManager
	return battle != null and battle.can_draw_from_discard()

func execute() -> void:
	var battle: BattleManager = GameManager.get_battle_manager() as BattleManager
	battle.execute_machine_draw(4, self)

func yields_for_visuals() -> bool:
	var main_node = GameManager.get_main_node()
	return is_instance_valid(main_node) and not ActionQueue.is_headless_mode()
