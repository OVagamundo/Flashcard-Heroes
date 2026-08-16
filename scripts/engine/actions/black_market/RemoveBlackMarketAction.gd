extends GameAction
class_name RemoveBlackMarketAction

var item_loc: LocationIdentifier
var item_uuid: String
var cost: int
var interaction_pos: Vector2

func _init(p_item_loc: LocationIdentifier, p_item_uuid: String, p_cost: int, p_interaction_pos: Vector2) -> void:
	item_loc = p_item_loc
	item_uuid = p_item_uuid
	cost = p_cost
	interaction_pos = p_interaction_pos

func is_valid() -> bool:
	if item_loc == null:
		return false
	var current_gold = GameManager.run_state.gold
	if current_gold < cost:
		return false
	var instance = GameManager.get_instance_from_location(item_loc)
	if instance == null or instance.ball_uuid != item_uuid:
		return false
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	SignalBus.emit_signal("black_market_action_requested", {
		"type": "remove",
		"cost": cost,
		"instance_uuid": item_uuid
	})

func _trigger_animations() -> void:
	var bm = GameManager.get_tree().get_first_node_in_group("black_market_controller")
		
	var instance = GameManager.get_instance_from_location(item_loc)
	if instance == null:
		_perform_mutation()
		finish_visuals()
		return
		
	var source_anchor = WindowManager.find_view_for_location(item_loc)
	if source_anchor != null:
		for child in source_anchor.get_children():
			if child.has_method("play_landing_bounce"):
				child.modulate.a = 0.0
				child.visible = false
				
	var visual_data = VisualDataAdapter.create_visual_data(instance)
	var vfx_ball = null
	if bm.has_method("_create_vfx_gachaball"):
		vfx_ball = bm._create_vfx_gachaball(visual_data, interaction_pos)
		
	var cb = func():
		_perform_mutation()
		
		if bm.has_method("_animate_gachaball_removal_vfx"):
			await bm._animate_gachaball_removal_vfx(vfx_ball)
		elif vfx_ball != null:
			vfx_ball.queue_free()
			
		var main_node = GameManager._active_main_node
		if main_node != null:
			if main_node.has_method("set_action_zone_texts") and bm.has_method("_get_remove_cost"):
				var transform_text = tr("ui.bm_drop_transform").format({"cost": str(GameManager.get_black_market_transform_cost())})
				var remove_text = tr("ui.bm_drop_remove").format({"cost": str(bm._get_remove_cost())})
				main_node.set_action_zone_texts(transform_text, remove_text)
			if main_node.has_method("show_split_action_drop_zones"):
				main_node.show_split_action_drop_zones()
				
		SignalBus.emit_signal("selection_clear_requested")
		Audio.play_sfx("ui_drag_drop")
		finish_visuals()
		
	_run_remove_anim(bm, cb)

func _run_remove_anim(bm: Node, cb: Callable) -> void:
	if bm.has_method("_animate_gold_spend"):
		bm._animate_gold_spend(cost, interaction_pos, cb)
	else:
		cb.call()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "RemoveBlackMarketAction",
		"item_loc": item_loc.to_dict(),
		"item_uuid": item_uuid,
		"cost": cost,
		"interaction_pos": {"x": interaction_pos.x, "y": interaction_pos.y}
	}
