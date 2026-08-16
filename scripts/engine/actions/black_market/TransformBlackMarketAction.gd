extends GameAction
class_name TransformBlackMarketAction

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
	var def = instance.get_definition()
	if GameManager.get_transform_result(def) == null:
		return false
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	var instance = GameManager.get_instance_from_location(item_loc)
	var source_definition = instance.get_definition()
	var result_definition = GameManager.get_transform_result(source_definition)
	var source_level = instance.level
	
	SignalBus.emit_signal("black_market_action_requested", {
		"type": "transform",
		"cost": cost,
		"instance_uuid": item_uuid,
		"source_location": item_loc,
		"result_definition": result_definition,
		"source_level": source_level
	})

func _trigger_animations() -> void:
	var bm = GameManager.get_tree().get_first_node_in_group("black_market_controller")
		
	var instance = GameManager.get_instance_from_location(item_loc)
	if instance == null:
		_perform_mutation()
		finish_visuals()
		return
		
	var source_definition = instance.get_definition()
	var result_definition = GameManager.get_transform_result(source_definition)
	
	var target_slot_view = WindowManager.find_view_for_location(item_loc)
	if target_slot_view != null:
		target_slot_view.modulate.a = 0.0

	SignalBus.emit_signal("hide_slot_indicators")
	SignalBus.emit_signal("selection_clear_requested")

	var visual_data = VisualDataAdapter.create_visual_data(instance)
	var vfx_ball = null
	if bm.has_method("_create_vfx_gachaball"):
		vfx_ball = bm._create_vfx_gachaball(visual_data, interaction_pos)

	var cb = func():
		_perform_mutation()
		
		var start_pos = interaction_pos
		var temp_new_instance := GachaBallInstance.new()
		temp_new_instance.initialize(result_definition)
		var new_visual_data = VisualDataAdapter.create_visual_data(temp_new_instance)
		
		if vfx_ball != null:
			vfx_ball.populate(null, new_visual_data, false)
			
		if bm.has_method("_prepare_transform_target_view"):
			var target_view = await bm._prepare_transform_target_view(item_loc)
			if start_pos != Vector2.ZERO and target_view != null and bm.has_method("_animate_transform_to_slot_vfx"):
				await bm._animate_transform_to_slot_vfx(vfx_ball, new_visual_data, start_pos, target_view)
			else:
				if vfx_ball != null: vfx_ball.queue_free()
				if target_view != null:
					target_view.visible = true
					target_view.modulate.a = 1.0
					if target_view.has_method("play_landing_bounce"):
						target_view.play_landing_bounce()
		else:
			if vfx_ball != null: vfx_ball.queue_free()
			
		finish_visuals()
		
	_run_transform_anim(bm, cb)

func _run_transform_anim(bm: Node, cb: Callable) -> void:
	if bm.has_method("_animate_gold_spend"):
		bm._animate_gold_spend(cost, interaction_pos, cb)
	else:
		cb.call()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "TransformBlackMarketAction",
		"item_loc": item_loc.to_dict(),
		"item_uuid": item_uuid,
		"cost": cost,
		"interaction_pos": {"x": interaction_pos.x, "y": interaction_pos.y}
	}
