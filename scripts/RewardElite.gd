# res://scripts/RewardElite.gd
extends EncounterBase

@onready var title_label: Label = %TitleLabel
@onready var choices_container: HBoxContainer = %RewardChoicesContainer
@onready var gold_button: Button = %TakeGoldButton
@onready var reroll_button: Button = %RerollButton
@onready var back_to_path_button: Button = %BackToPathButton

var _reward_instances: Array = []
var _gold_amount: int = 10
var _current_reroll_cost: int = 5
var _action_in_progress: bool = false


func _ready() -> void:
	add_to_group("reward_scene")
	Audio.play_music(SoundRegistry.BGM_REWARD)

	SignalBus.reward_stock_refreshed.connect(populate)
	SignalBus.reward_collect_zone_activated.connect(_on_collect_pressed)
	SignalBus.reward_sell_zone_activated.connect(_on_sell_pressed)

	gold_button.visible = false # Replaced by Sell drop zone
	back_to_path_button.visible = false
	back_to_path_button.disabled = true
	back_to_path_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reroll_button.pressed.connect(_on_reroll_pressed)
	back_to_path_button.pressed.connect(_on_back_to_path_pressed)
	gui_input.connect(_handle_window_background_click)

	SignalBus.locale_changed.connect(_update_localized_text)
	_update_localized_text()
	_mark_action_buttons_for_avoidance([gold_button, reroll_button, back_to_path_button], &"Rewards")
	_show_initial_instruction()


func _show_initial_instruction() -> void:
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.show_action_instruction(tr("ui.reward_elite_instruction"))


func _exit_tree() -> void:
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_action_instruction()
		main_node.hide_reward_drop_zones()
		main_node.hide_empty_trinket_slots()


func _process(_delta: float) -> void:
	_sync_reward_inventory_overlay("ui.reward_elite_instruction", not back_to_path_button.visible)


func _get_reroll_cost() -> int:
	if is_instance_valid(GameManager.run_state):
		return GameManager.run_state.get_elite_reward_reroll_cost()
	return 5


func _update_localized_text() -> void:
	var locale: String = TranslationServer.get_locale().left(2)
	if locale == "pt":
		title_label.text = "Escolha seu Amuleto"
		back_to_path_button.text = "Voltar ao Caminho"
	else:
		title_label.text = "Choose Your Trinket"
		back_to_path_button.text = tr("ui.back_to_path")

	gold_button.text = tr("ui.take_gold_amount") % _gold_amount
	reroll_button.text = tr("ui.reroll_gold") % _current_reroll_cost


func populate(context: Dictionary) -> void:
	_reward_instances = context.get("reward_instances", [])
	_gold_amount = context.get("gold_amount", 10)
	_current_reroll_cost = context.get("reroll_cost", _get_reroll_cost())

	_update_localized_text()
	reroll_button.visible = true
	reroll_button.disabled = false

	var created_views: Array[GachaBallView] = []
	var slot_nodes: Array[Node] = choices_container.get_children()
	for i: int in range(slot_nodes.size()):
		var slot_view: SlotView = slot_nodes[i] as SlotView
		if i < _reward_instances.size():
			var inst: GachaBallInstance = _reward_instances[i] as GachaBallInstance
			if is_instance_valid(inst):
				slot_view.populate(LocationIdentifier.new(&"Rewards", i))
				var ball_view: GachaBallView = slot_view.set_content(VisualDataAdapter.create_visual_data(inst), true, false)
				if is_instance_valid(ball_view):
					ball_view.visible = false
					ball_view.scale = Vector2.ONE
					created_views.append(ball_view)
				slot_view.set_interaction_context(&"FULLY_INTERACTIVE", 0)
				slot_view.set_size_scale(2.0)
				slot_view.visible = true
			else:
				slot_view.visible = false

	back_to_path_button.visible = false
	back_to_path_button.modulate.a = 0.0
	back_to_path_button.disabled = true
	back_to_path_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(GameManager._active_main_node):
		GameManager._active_main_node.show_empty_trinket_slots()

	_animate_staggered_slot_entry(choices_container, created_views)


func _on_collect_pressed(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress:
		return
	var prize_data: Dictionary = _get_selected_reward_entry(_reward_instances)
	if prize_data.is_empty():
		return
	var drop: Dictionary = _resolve_drop_interaction(is_drag, mouse_pos)
	ActionQueue.request(CollectRewardAction.new(prize_data["uuid"], drop["interaction_type"], drop["drop_pos"]))


func execute_collect_visuals(uuid: String, p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	var prize_data: Dictionary = _resolve_reward_entry_by_uuid(_reward_instances, uuid)
	if prize_data.is_empty():
		_finish_active_action()
		return

	_action_in_progress = true
	var loc: LocationIdentifier = prize_data["location"] as LocationIdentifier
	var instance: GachaBallInstance = prize_data["instance"] as GachaBallInstance

	_clear_reward_slot(loc.index)
	SignalBus.selection_clear_requested.emit()

	var raw_pos: Vector2 = _consume_animation_start_pos(_get_slot_global_center(loc.index), p_drop_pos)
	var visual_data: Dictionary = VisualDataAdapter.create_visual_data(instance)
	var target_trinket_slot: int = _find_first_empty_trinket_slot()

	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_reward_drop_zones()
		main_node.hide_action_instruction()

	var start_pos: Vector2 = _map_screen_to_vfx_viewport(_get_absolute_screen_pos(raw_pos))
	await _animate_gachaball_to_trinket_bar(start_pos, visual_data, target_trinket_slot, 2.0, true, false)

	SignalBus.reward_chosen.emit({"type": "gachaball", "instance_uuid": instance.ball_uuid})
	_complete_choice()
	_action_in_progress = false
	_finish_active_action()


func _on_sell_pressed(is_drag: bool = false, mouse_pos: Vector2 = Vector2.ZERO) -> void:
	if _action_in_progress:
		return
	var prize_data: Dictionary = _get_selected_reward_entry(_reward_instances)
	if prize_data.is_empty():
		return
	var drop: Dictionary = _resolve_drop_interaction(is_drag, mouse_pos)
	ActionQueue.request(SellRewardAction.new(prize_data["uuid"], drop["interaction_type"], drop["drop_pos"]))


func execute_sell_visuals(uuid: String, gold_yield: int = -1, p_drop_pos: Vector2 = Vector2.ZERO) -> void:
	var prize_data: Dictionary = _resolve_reward_entry_by_uuid(_reward_instances, uuid)
	if prize_data.is_empty():
		_finish_active_action()
		return

	_action_in_progress = true
	var loc: LocationIdentifier = prize_data["location"] as LocationIdentifier

	_clear_reward_slot(loc.index)
	SignalBus.selection_clear_requested.emit()

	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_reward_drop_zones()
		main_node.hide_action_instruction()

	var raw_pos: Vector2 = _consume_animation_start_pos(_get_slot_global_center(loc.index), p_drop_pos)
	var vfx_start_pos: Vector2 = _map_screen_to_vfx_viewport(_get_absolute_screen_pos(raw_pos))
	var amt: int = gold_yield if gold_yield > 0 else _gold_amount
	await CurrencyAnimator.animate_gold_gain(amt, vfx_start_pos)

	_complete_choice()
	_action_in_progress = false
	_finish_active_action()


func _on_reroll_pressed() -> void:
	if _action_in_progress:
		return
	var current_gold: int = GameManager.run_state.gold if is_instance_valid(GameManager.run_state) else 0
	if current_gold < _current_reroll_cost:
		var main_node: Node = GameManager._active_main_node
		var gold_group: Control = main_node.get_node_or_null("%GoldGroup") as Control if is_instance_valid(main_node) else null
		RejectionFeedbackScript.play_rejection_with_counter(reroll_button, gold_group, get_tree())
		return
	ActionQueue.request(RerollRewardAction.new())


func execute_reroll_visuals(cost: int = -1) -> void:
	_action_in_progress = true
	reroll_button.disabled = true
	var target_pos: Vector2 = reroll_button.get_global_rect().get_center()
	var spend_cost: int = cost if cost >= 0 else _current_reroll_cost

	var on_complete := func() -> void:
		SignalBus.selection_clear_requested.emit()
		var main_node: Node = GameManager._active_main_node
		if is_instance_valid(main_node):
			main_node.hide_reward_drop_zones()
		_show_initial_instruction()
		Audio.play_sfx("shop_reroll")
		reroll_button.disabled = false
		_action_in_progress = false
		_finish_active_action()

	if is_instance_valid(GameManager._active_main_node):
		CurrencyAnimator.animate_gold_spend(spend_cost, target_pos, on_complete)
	else:
		on_complete.call()


func _complete_choice() -> void:
	SignalBus.reward_chosen.emit({"type": "elite_choice_complete"})
	gold_button.visible = false
	reroll_button.visible = false
	reroll_button.disabled = true
	reroll_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	back_to_path_button.visible = true
	back_to_path_button.modulate.a = 1.0
	back_to_path_button.disabled = false
	back_to_path_button.mouse_filter = Control.MOUSE_FILTER_STOP

	var slot_nodes: Array[Node] = choices_container.get_children()
	for i: int in range(slot_nodes.size()):
		var ball: Control = null
		for child in slot_nodes[i].get_children():
			if child is GachaBallView:
				ball = child as Control
				break
		if is_instance_valid(ball) and ball.visible and ball.modulate.a > 0.1:
			var ball_tween: Tween = create_tween()
			ball_tween.tween_interval(i * 0.1)
			ball_tween.tween_property(ball, "position:y", ball.position.y - 120.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			ball_tween.parallel().tween_property(ball, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			ball_tween.tween_callback(ball.queue_free)

	_reward_instances.clear()
	if is_instance_valid(GameManager._active_main_node):
		GameManager._active_main_node.hide_empty_trinket_slots()


func _clear_reward_slot(index: int) -> void:
	var slot_nodes: Array[Node] = choices_container.get_children()
	if index >= 0 and index < slot_nodes.size():
		(slot_nodes[index] as SlotView).set_content({}, false)


func _get_slot_global_center(index: int) -> Vector2:
	var slot_nodes: Array[Node] = choices_container.get_children()
	if index >= 0 and index < slot_nodes.size() and is_instance_valid(slot_nodes[index]):
		return (slot_nodes[index] as Control).get_global_rect().get_center()
	return Vector2.ZERO


func _on_back_to_path_pressed() -> void:
	ActionQueue.request(LeaveRewardAction.new())


func execute_leave_visuals() -> void:
	var main_node: Node = GameManager._active_main_node
	if is_instance_valid(main_node):
		main_node.hide_reward_drop_zones()
		main_node.hide_empty_trinket_slots()
	SignalBus.path_choice_scene_requested.emit()
	queue_free()
