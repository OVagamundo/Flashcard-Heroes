extends GameAction
class_name BuyShopAction

var shop_loc: LocationIdentifier
var cost: int
var interaction_pos: Vector2

func _init(p_shop_loc: LocationIdentifier, p_cost: int, p_interaction_pos: Vector2) -> void:
	shop_loc = p_shop_loc
	cost = p_cost
	interaction_pos = p_interaction_pos

func is_valid() -> bool:
	if shop_loc == null or shop_loc.container != &"Shop":
		return false
	
	var current_gold: int = GameManager.run_state.gold
	if current_gold < cost:
		return false
	
	var instance = _find_instance_for_slot(shop_loc.index)
	if instance == null:
		return false
		
	return true

func execute() -> void:
	var instance = _find_instance_for_slot(shop_loc.index)
	
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation(instance)
		finish_visuals()
	else:
		_trigger_animations(instance)

func _perform_mutation(instance: GachaBallInstance) -> void:
	SignalBus.emit_signal("shop_purchase_requested", instance.ball_uuid, cost)

func _trigger_animations(instance: GachaBallInstance) -> void:
	# Convert logic from Shop.gd
	var visual_data = VisualDataAdapter.create_visual_data(instance)
	var def = instance.get_definition()
	var tier: int = 1
	if "tier" in def:
		tier = int(def.tier)
	if def.category == &"TRINKET":
		tier = 3
		
	var source_anchor = WindowManager.find_view_for_location(shop_loc)
	for child in source_anchor.get_children():
		# Assume Shop script or node has a way to identify GachaBallView without strict casting
		if child.has_method("play_landing_bounce"): 
			child.modulate.a = 0.0
			child.visible = false
	
	var shop_view = GameManager._active_main_node._current_content_node
	var vfx_ball = shop_view._create_vfx_gachaball(visual_data, interaction_pos)
	
	shop_view._animate_gold_spend(cost, interaction_pos, func():
		_perform_mutation(instance)
		
		Audio.play_sfx("shop_buy")
		shop_view._animate_gachaball_to_machine_vfx(vfx_ball, interaction_pos, tier)
		
		var mn = GameManager._active_main_node
		if mn.has_method("hide_confirm_drop_zone"):
			mn.hide_confirm_drop_zone()
			
		finish_visuals()
	)

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func _find_instance_for_slot(slot_index: int) -> GachaBallInstance:
	for inst in GameManager._temporary_shop_master_dict.values():
		if inst.get_location().index == slot_index:
			return inst
	return null

func serialize() -> Dictionary:
	return {
		"action_type": "BuyShopAction",
		"shop_loc": shop_loc.to_dict(),
		"cost": cost,
		"interaction_pos": {"x": interaction_pos.x, "y": interaction_pos.y}
	}
