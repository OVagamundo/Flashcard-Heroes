extends GameAction
class_name UpgradeRestSiteAction

var prize_index: int

func _init(p_prize_index: int) -> void:
	prize_index = p_prize_index

func is_valid() -> bool:
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	if not is_instance_valid(GameManager.run_state): return
	var rest_site = GameManager._active_main_node._current_content_node
	if rest_site and rest_site.has_method("consume_prize_data"):
		var prize_data = rest_site.consume_prize_data(prize_index)
		if prize_data.is_empty(): return
		
		if rest_site.site_type == 2: # SiteType.GOLD
			GameManager.run_state.add_gold(prize_data.gold_value)
		elif is_instance_valid(GameManager.run_state.hero_instance):
			var hero_uuid = GameManager.run_state.hero_instance.ball_uuid
			GameManager.run_state.modify_unit_base_stats(hero_uuid, prize_data.hp_value, prize_data.pwr_value)

func _trigger_animations() -> void:
	var rest_site = GameManager._active_main_node._current_content_node
	var cb = func():
		_perform_mutation()
		finish_visuals()
		
	_run_upgrade_anim(rest_site, cb)

func _run_upgrade_anim(rest_site: Node, cb: Callable) -> void:
	if rest_site.has_method("_apply_prize_visuals"):
		await rest_site._apply_prize_visuals(prize_index)
	cb.call()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "UpgradeRestSiteAction",
		"prize_index": prize_index
	}
