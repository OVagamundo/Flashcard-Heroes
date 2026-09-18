# res://scripts/engine/actions/DrawGachaAction.gd
class_name DrawGachaAction
extends GameAction

var tier: int = 1

func _init(p_tier: int = 1) -> void:
	super._init(&"DrawGachaAction")
	tier = p_tier

func validate() -> bool:
	if tier < 1 or tier > 3:
		return false
	var bm = GameManager.get_battle_manager()
	if not is_instance_valid(bm):
		return false
	if bm.has_method("can_draw_gacha_instance"):
		return bm.can_draw_gacha_instance(tier)
	return true

func execute() -> void:
	var main_node = GameManager.get_main_node()
	if is_instance_valid(main_node) and not ActionQueue.is_headless_mode() and main_node.has_method("execute_draw_gacha_visuals"):
		var button = main_node.get_knob_button(tier)
		main_node.execute_draw_gacha_visuals(button, tier)
	else:
		var bm = GameManager.get_battle_manager()
		if is_instance_valid(bm) and bm.has_method("_on_draw_gacha_requested"):
			bm._on_draw_gacha_requested(tier)

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
