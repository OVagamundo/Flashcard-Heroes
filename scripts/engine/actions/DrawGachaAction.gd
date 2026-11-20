# res://scripts/engine/actions/DrawGachaAction.gd
class_name DrawGachaAction
extends GameAction

var tier: int = 1

func _init(p_tier: int = 1) -> void:
	super._init(&"DrawGachaAction")
	tier = p_tier

func validate() -> bool:
	var battle: BattleManager = GameManager.get_battle_manager() as BattleManager
	return battle != null and tier >= 1 and tier <= 3 and battle.can_draw_gacha_instance(tier)

func execute() -> void:
	var battle: BattleManager = GameManager.get_battle_manager() as BattleManager
	battle.execute_machine_draw(tier, self)

func yields_for_visuals() -> bool:
	var main_node = GameManager.get_main_node()
	return is_instance_valid(main_node) and not ActionQueue.is_headless_mode()

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["tier"] = tier
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	tier = int(data.get("tier", 1))
