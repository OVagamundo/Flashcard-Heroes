extends GameAction
class_name CollectRewardAction

var reward_loc: LocationIdentifier
var start_pos: Vector2
var elite_mode: bool

func _init(p_reward_loc: LocationIdentifier, p_start_pos: Vector2, p_elite_mode: bool = false) -> void:
	reward_loc = p_reward_loc
	start_pos = p_start_pos
	elite_mode = p_elite_mode

func is_valid() -> bool:
	if reward_loc == null or reward_loc.container != &"Rewards":
		return false
	
	var instance = GameManager._temporary_reward_container.get_uuid(reward_loc.index)
	if instance.is_empty():
		return false
	
	return true

func execute() -> void:
	if Engine.is_editor_hint() or ActionQueue.is_headless_mode():
		_perform_mutation()
		finish_visuals()
	else:
		_trigger_animations()

func _perform_mutation() -> void:
	var uuid = GameManager._temporary_reward_container.get_uuid(reward_loc.index)
	if not uuid.is_empty():
		SignalBus.emit_signal("selection_clear_requested")
		SignalBus.emit_signal("reward_chosen", {"type": "gachaball", "instance_uuid": uuid})
		if elite_mode:
			SignalBus.emit_signal("reward_chosen", {"type": "elite_choice_complete"})

func _trigger_animations() -> void:
	var reward_scene = GameManager.get_tree().get_first_node_in_group("reward_scene")
	
	# Clear slot visually
	if reward_scene.has_method("_clear_prize_slot"):
		reward_scene._clear_prize_slot(reward_loc.index)
	elif reward_scene.has_method("_clear_reward_slot"):
		reward_scene._clear_reward_slot(reward_loc.index)
		
	var mn = GameManager._active_main_node
	if mn != null:
		if mn.has_method("hide_reward_drop_zones"):
			mn.hide_reward_drop_zones()
		if not WindowManager.is_run_inventory_window_open() and mn.has_method("show_action_instruction"):
			mn.show_action_instruction(tr("ui.reward_instruction"))
	
	var uuid = GameManager._temporary_reward_container.get_uuid(reward_loc.index)
	var instance = GameManager._temporary_reward_master_dict.get(uuid)
	if instance == null:
		_perform_mutation()
		finish_visuals()
		return
		
	var visual_data = VisualDataAdapter.create_visual_data(instance)
	var def = instance.get_definition()
	var tier: int = 1
	var target_trinket_slot: int = -1
	
	if def is GachaBallDefinition: tier = int(def.tier)
	if def != null and def.category == &"TRINKET":
		tier = -1
		var trinket_container = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_TRINKETS)
		if trinket_container != null and trinket_container.has_method("find_first_empty_slot"):
			target_trinket_slot = max(0, trinket_container.find_first_empty_slot())
			
	var cb = func():
		_perform_mutation()
		if reward_scene.has_method("_complete_choice"):
			reward_scene._complete_choice()
		finish_visuals()
		
	_run_collect_anim(reward_scene, visual_data, tier, target_trinket_slot, uuid, cb)

func _run_collect_anim(reward_scene: Node, visual_data: Dictionary, tier: int, target_trinket_slot: int, uuid: String, cb: Callable) -> void:
	if tier != -1:
		if reward_scene.has_method("_animate_gachaball_to_machine"):
			await reward_scene._animate_gachaball_to_machine(start_pos, visual_data, tier)
	else:
		if reward_scene.has_method("_animate_gachaball_to_trinket_bar"):
			await reward_scene._animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, uuid)
	cb.call()

func yields_for_visuals() -> bool:
	return not (Engine.is_editor_hint() or ActionQueue.is_headless_mode())

func serialize() -> Dictionary:
	return {
		"action_type": "CollectRewardAction",
		"reward_loc": reward_loc.to_dict(),
		"start_pos": {"x": start_pos.x, "y": start_pos.y},
		"elite_mode": elite_mode
	}
