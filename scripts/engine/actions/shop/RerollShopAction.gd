extends GameAction
class_name RerollShopAction

var cost: int
var interaction_pos: Vector2

func _init(p_cost: int, p_interaction_pos: Vector2) -> void:
	cost = p_cost
	interaction_pos = p_interaction_pos

func is_valid() -> bool:
	var current_gold: int = GameManager.run_state.gold
	if current_gold < cost:
		return false
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	SignalBus.emit_signal("shop_reroll_requested")

func _trigger_animations() -> void:
	var shop_view = GameManager._active_main_node._current_content_node
	shop_view._animate_gold_spend(cost, interaction_pos, func():
		_perform_mutation()
		Audio.play_sfx("shop_reroll")
		finish_visuals()
	)

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "RerollShopAction",
		"cost": cost,
		"interaction_pos": {"x": interaction_pos.x, "y": interaction_pos.y}
	}
